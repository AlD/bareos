/*
 *
 *  Program to test cache path
 *
 *   Eric Bollengier, March 2007
 *
 *
 *   Version $Id$
 */
/*
   Bacula® - The Network Backup Solution

   Copyright (C) 2001-2006 Free Software Foundation Europe e.V.

   The main author of Bacula is Kern Sibbald, with contributions from
   many others, a complete list can be found in the file AUTHORS.
   This program is Free Software; you can redistribute it and/or
   modify it under the terms of version two of the GNU General Public
   License as published by the Free Software Foundation and included
   in the file LICENSE.

   This program is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
   02110-1301, USA.

   Bacula® is a registered trademark of Kern Sibbald.
   The licensor of Bacula is the Free Software Foundation Europe
   (FSFE), Fiduciary Program, Sumatrastrasse 25, 8006 Zürich,
   Switzerland, email:ftf@fsfeurope.org.
*/

#include "bacula.h"
#include "cats/cats.h"
#include "cats/bvfs.h"
#include "findlib/find.h"
 
/* Local variables */
static B_DB *db;

static const char *db_name = "regress";
static const char *db_user = "regress";
static const char *db_password = "";
static const char *db_host = NULL;

static void usage()
{
   fprintf(stderr, _(
PROG_COPYRIGHT
"\nVersion: %s (%s)\n"
"       -d <nn>           set debug level to <nn>\n"
"       -dt               print timestamp in debug output\n"
"       -n <name>         specify the database name (default bacula)\n"
"       -u <user>         specify database user name (default bacula)\n"
"       -P <password      specify database password (default none)\n"
"       -h <host>         specify database host (default NULL)\n"
"       -w <working>      specify working directory\n"
"       -j <jobids>       specify jobids\n"
"       -p <path>         specify path\n"
"       -f <file>         specify file\n"
"       -v                verbose\n"
"       -?                print this message\n\n"), 2001, VERSION, BDATE);
   exit(1);
}

static int result_handler(void *ctx, int fields, char **row)
{
   Bvfs *vfs = (Bvfs *)ctx;
   ATTR *attr = vfs->get_attr();
   char *empty = "";

   if (fields == BVFS_DIR_RECORD || fields == BVFS_FILE_RECORD) {
      decode_stat((row[BVFS_LStat])?row[BVFS_LStat]:empty,
                  &attr->statp, &attr->LinkFI);
      if (fields == BVFS_DIR_RECORD) {
         pm_strcpy(attr->ofname, bvfs_basename_dir(row[BVFS_Name]));   
      } else {
         pm_strcpy(attr->ofname, row[BVFS_Name]);   
      }
      print_ls_output(vfs->get_jcr(), attr);

   } else {
      Pmsg6(0, "%s\t%s\t%s\t%s\t%s\t%s",
            row[0], row[1], row[2], row[3], row[4], row[5]);
   }
   return 0;
}


/* number of thread started */

int main (int argc, char *argv[])
{
   int ch;
   char *jobids="1", *path=NULL, *file=NULL;
   setlocale(LC_ALL, "");
   bindtextdomain("bacula", LOCALEDIR);
   textdomain("bacula");
   init_stack_dump();

   Dmsg0(0, "Starting bvfs_test tool\n");
   
   my_name_is(argc, argv, "bvfs_test");
   init_msg(NULL, NULL);

   OSDependentInit();

   while ((ch = getopt(argc, argv, "h:c:d:n:P:Su:vf:w:?j:p:f:")) != -1) {
      switch (ch) {
      case 'd':                    /* debug level */
         if (*optarg == 't') {
            dbg_timestamp = true;
         } else {
            debug_level = atoi(optarg);
            if (debug_level <= 0) {
               debug_level = 1;
            }
         }
         break;

      case 'h':
         db_host = optarg;
         break;

      case 'n':
         db_name = optarg;
         break;

      case 'w':
         working_directory = optarg;
         break;

      case 'u':
         db_user = optarg;
         break;

      case 'P':
         db_password = optarg;
         break;

      case 'v':
         verbose++;
         break;

      case 'p':
         path = optarg;
         break;

      case 'f':
         path = optarg;
         break;

      case 'j':
         jobids = optarg;
         break;

      case '?':
      default:
         usage();

      }
   }
   argc -= optind;
   argv += optind;

   if (argc != 0) {
      Pmsg0(0, _("Wrong number of arguments: \n"));
      usage();
   }
   JCR *bjcr = new_jcr(sizeof(JCR), NULL);
   bjcr->JobId = getpid();
   bjcr->set_JobType(JT_CONSOLE);
   bjcr->set_JobLevel(L_FULL);
   bjcr->JobStatus = JS_Running;
   bjcr->client_name = get_pool_memory(PM_FNAME);
   pm_strcpy(bjcr->client_name, "Dummy.Client.Name");
   bstrncpy(bjcr->Job, "bvfs_test", sizeof(bjcr->Job));
   
   if ((db=db_init_database(NULL, db_name, db_user, db_password,
                            db_host, 0, NULL, 0)) == NULL) {
      Emsg0(M_ERROR_TERM, 0, _("Could not init Bacula database\n"));
   }
   Dmsg1(0, "db_type=%s\n", db_get_type());

   if (!db_open_database(NULL, db)) {
      Emsg0(M_ERROR_TERM, 0, db_strerror(db));
   }
   Dmsg0(200, "Database opened\n");
   if (verbose) {
      Pmsg2(000, _("Using Database: %s, User: %s\n"), db_name, db_user);
   }
   
   bjcr->db = db;
   
   db_sql_query(db, "DELETE FROM brestore_pathhierarchy", NULL, NULL);
   db_sql_query(db, "DELETE FROM brestore_knownjobid", NULL, NULL);
   db_sql_query(db, "DELETE FROM brestore_pathvisibility", NULL, NULL);

   bvfs_update_cache(bjcr, db);
   Bvfs fs(bjcr, db);
   fs.set_handler(result_handler, &fs);

   fs.set_jobids(jobids);
   fs.update_cache();

   if (path) {
      fs.ch_dir(path);
      fs.ls_special_dirs();
      fs.ls_dirs();
      fs.ls_files();
      exit (0);
   }

   
   Pmsg0(0, "list /\n");
   fs.ch_dir("/");
   fs.ls_special_dirs();
   fs.ls_dirs();
   fs.ls_files();

   Pmsg0(0, "list /tmp/\n");
   fs.ch_dir("/tmp/");
   fs.ls_special_dirs();
   fs.ls_dirs();
   fs.ls_files();

   Pmsg0(0, "list /tmp/regress/\n");
   fs.ch_dir("/tmp/regress/");
   fs.ls_special_dirs();
   fs.ls_files();
   fs.ls_dirs();

   Pmsg0(0, "list /tmp/regress/build/\n");
   fs.ch_dir("/tmp/regress/build/");
   fs.ls_special_dirs();
   fs.ls_dirs();
   fs.ls_files();

   fs.get_all_file_versions(1, 347, "zog4-fd");

   char p[200];
   strcpy(p, "/tmp/toto/rep/");
   bvfs_parent_dir(p);
   if(strcmp(p, "/tmp/toto/")) {
      Pmsg0(000, "Error in bvfs_parent_dir\n");
   }
   bvfs_parent_dir(p);
   if(strcmp(p, "/tmp/")) {
      Pmsg0(000, "Error in bvfs_parent_dir\n");
   }
   bvfs_parent_dir(p);
   if(strcmp(p, "/")) {
      Pmsg0(000, "Error in bvfs_parent_dir\n");
   }
   bvfs_parent_dir(p);
   if(strcmp(p, "")) {
      Pmsg0(000, "Error in bvfs_parent_dir\n");
   }
   bvfs_parent_dir(p);
   if(strcmp(p, "")) {
      Pmsg0(000, "Error in bvfs_parent_dir\n");
   }

   return 0;
}
