/*
   BAREOS® - Backup Archiving REcovery Open Sourced

   Copyright (C) 2000-2011 Free Software Foundation Europe e.V.
   Copyright (C) 2011-2012 Planets Communications B.V.
   Copyright (C) 2013-2013 Bareos GmbH & Co. KG

   This program is Free Software; you can redistribute it and/or
   modify it under the terms of version three of the GNU Affero General Public
   License as published by the Free Software Foundation and included
   in the file LICENSE.

   This program is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
   Affero General Public License for more details.

   You should have received a copy of the GNU Affero General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
   02110-1301, USA.
*/
/*
 * Dumb program to extract files from a Bareos backup.
 *
 * Kern E. Sibbald, MM
 */

#include "bareos.h"
#include "stored.h"
#include "ch.h"
#include "lib/crypto_cache.h"
#include "findlib/find.h"

#ifdef HAVE_LZO
#include <lzo/lzoconf.h>
#include <lzo/lzo1x.h>
#endif

/*
 * Don't allow the uncompressed data buffer to grow larger then this amount of bytes.
 */
#define MAX_UNCOMPRESSED_SIZE 10000000

extern bool parse_sd_config(CONFIG *config, const char *configfile, int exit_code);

static void do_extract(char *devname);
static bool record_cb(DCR *dcr, DEV_RECORD *rec);

static DEVICE *dev = NULL;
static DCR *dcr;
static BFILE bfd;
static JCR *jcr;
static FF_PKT *ff;
static BSR *bsr = NULL;
static bool extract = false;
static int non_support_data = 0;
static long total = 0;
static ATTR *attr;
static char *where;
static uint32_t num_files = 0;
static uint32_t compress_buf_size = 70000;
static POOLMEM *compress_buf;
static int prog_name_msg = 0;
static int win32_data_msg = 0;
static char *VolumeName = NULL;
static char *DirectorName = NULL;
static DIRRES *director = NULL;

static struct acl_data_t acl_data;
static struct xattr_data_t xattr_data;

static char *wbuf;                    /* write buffer address */
static uint32_t wsize;                /* write size */
static uint64_t fileAddr = 0;         /* file write address */

static CONFIG *config;
#define CONFIG_FILE "bareos-sd.conf"
char *configfile = NULL;
STORES *me = NULL;                    /* our Global resource */
bool forge_on = false;
pthread_mutex_t device_release_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t wait_device_release = PTHREAD_COND_INITIALIZER;

static void usage()
{
   fprintf(stderr, _(
PROG_COPYRIGHT
"\nVersion: %s (%s)\n\n"
"Usage: bextract <options> <bareos-archive-device-name> <directory-to-store-files>\n"
"       -b <file>       specify a bootstrap file\n"
"       -c <file>       specify a Storage configuration file\n"
"       -D <director>   specify a director name specified in the Storage\n"
"                       configuration file for the Key Encryption Key selection\n"
"       -d <nn>         set debug level to <nn>\n"
"       -dt             print timestamp in debug output\n"
"       -e <file>       exclude list\n"
"       -i <file>       include list\n"
"       -p              proceed inspite of I/O errors\n"
"       -v              verbose\n"
"       -V <volumes>    specify Volume names (separated by |)\n"
"       -?              print this message\n\n"), 2000, VERSION, BDATE);
   exit(1);
}


int main (int argc, char *argv[])
{
   int ch;
   FILE *fd;
   char line[1000];
   bool got_inc = false;

   setlocale(LC_ALL, "");
   bindtextdomain("bareos", LOCALEDIR);
   textdomain("bareos");
   init_stack_dump();
   lmgr_init_thread();

   working_directory = "/tmp";
   my_name_is(argc, argv, "bextract");
   init_msg(NULL, NULL);              /* setup message handler */

   OSDependentInit();

   ff = init_find_files();
   binit(&bfd);

   while ((ch = getopt(argc, argv, "b:c:D:d:e:i:pvV:?")) != -1) {
      switch (ch) {
      case 'b':                    /* bootstrap file */
         bsr = parse_bsr(NULL, optarg);
//       dump_bsr(bsr, true);
         break;

      case 'c':                    /* specify config file */
         if (configfile != NULL) {
            free(configfile);
         }
         configfile = bstrdup(optarg);
         break;

      case 'D':                    /* specify director name */
         if (DirectorName != NULL) {
            free(DirectorName);
         }
         DirectorName = bstrdup(optarg);
         break;

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

      case 'e':                    /* exclude list */
         if ((fd = fopen(optarg, "rb")) == NULL) {
            berrno be;
            Pmsg2(0, _("Could not open exclude file: %s, ERR=%s\n"),
               optarg, be.bstrerror());
            exit(1);
         }
         while (fgets(line, sizeof(line), fd) != NULL) {
            strip_trailing_junk(line);
            Dmsg1(900, "add_exclude %s\n", line);
            add_fname_to_exclude_list(ff, line);
         }
         fclose(fd);
         break;

      case 'i':                    /* include list */
         if ((fd = fopen(optarg, "rb")) == NULL) {
            berrno be;
            Pmsg2(0, _("Could not open include file: %s, ERR=%s\n"),
               optarg, be.bstrerror());
            exit(1);
         }
         while (fgets(line, sizeof(line), fd) != NULL) {
            strip_trailing_junk(line);
            Dmsg1(900, "add_include %s\n", line);
            add_fname_to_include_list(ff, 0, line);
         }
         fclose(fd);
         got_inc = true;
         break;

      case 'p':
         forge_on = true;
         break;

      case 'v':
         verbose++;
         break;

      case 'V':                    /* Volume name */
         VolumeName = optarg;
         break;

      case '?':
      default:
         usage();

      } /* end switch */
   } /* end while */
   argc -= optind;
   argv += optind;

   if (argc != 2) {
      Pmsg0(0, _("Wrong number of arguments: \n"));
      usage();
   }

   if (configfile == NULL) {
      configfile = bstrdup(CONFIG_FILE);
   }

   config = new_config_parser();
   parse_sd_config(config, configfile, M_ERROR_TERM);

   LockRes();
   me = (STORES *)GetNextRes(R_STORAGE, NULL);
   if (!me) {
      UnlockRes();
      Emsg1(M_ERROR_TERM, 0, _("No Storage resource defined in %s. Cannot continue.\n"),
         configfile);
   }
   UnlockRes();

  if (DirectorName) {
      foreach_res(director, R_DIRECTOR) {
         if (bstrcmp(director->hdr.name, DirectorName)) {
            break;
         }
      }
      if (!director) {
         Emsg2(M_ERROR_TERM, 0, _("No Director resource named %s defined in %s. Cannot continue.\n"),
               DirectorName, configfile);
      }
   }

   load_sd_plugins(me->plugin_directory);

   read_crypto_cache(me->working_directory, "bareos-sd",
                     get_first_port_host_order(me->SDaddrs));

   if (!got_inc) {                            /* If no include file, */
      add_fname_to_include_list(ff, 0, "/");  /*   include everything */
   }

   where = argv[1];
   do_extract(argv[0]);

   if (bsr) {
      free_bsr(bsr);
   }
   if (prog_name_msg) {
      Pmsg1(000, _("%d Program Name and/or Program Data Stream records ignored.\n"),
         prog_name_msg);
   }
   if (win32_data_msg) {
      Pmsg1(000, _("%d Win32 data or Win32 gzip data stream records. Ignored.\n"),
         win32_data_msg);
   }
   term_include_exclude_files(ff);
   term_find_files(ff);
   return 0;
}

static void do_extract(char *devname)
{
   struct stat statp;

   enable_backup_privileges(NULL, 1);

   jcr = setup_jcr("bextract", devname, bsr, director, VolumeName, 1); /* acquire for read */
   if (!jcr) {
      exit(1);
   }
   dev = jcr->read_dcr->dev;
   if (!dev) {
      exit(1);
   }
   dcr = jcr->read_dcr;

   /* Make sure where directory exists and that it is a directory */
   if (stat(where, &statp) < 0) {
      berrno be;
      Emsg2(M_ERROR_TERM, 0, _("Cannot stat %s. It must exist. ERR=%s\n"),
         where, be.bstrerror());
   }
   if (!S_ISDIR(statp.st_mode)) {
      Emsg1(M_ERROR_TERM, 0, _("%s must be a directory.\n"), where);
   }

   free(jcr->where);
   jcr->where = bstrdup(where);
   attr = new_attr(jcr);

   compress_buf = get_memory(compress_buf_size);

   acl_data.last_fname = get_pool_memory(PM_FNAME);
   xattr_data.last_fname = get_pool_memory(PM_FNAME);

   read_records(dcr, record_cb, mount_next_read_volume);
   /* If output file is still open, it was the last one in the
    * archive since we just hit an end of file, so close the file.
    */
   if (is_bopen(&bfd)) {
      set_attributes(jcr, attr, &bfd);
   }
   free_attr(attr);

   free_pool_memory(acl_data.last_fname);
   free_pool_memory(xattr_data.last_fname);

   clean_device(jcr->dcr);
   dev->term();
   free_dcr(dcr);
   free_jcr(jcr);

   printf(_("%u files restored.\n"), num_files);
   return;
}

static bool store_data(BFILE *bfd, char *data, const int32_t length)
{
   if (is_win32_stream(attr->data_stream) && !have_win32_api()) {
      set_portable_backup(bfd);
      if (!processWin32BackupAPIBlock(bfd, data, length)) {
         berrno be;
         Emsg2(M_ERROR_TERM, 0, _("Write error on %s: %s\n"),
               attr->ofname, be.bstrerror());
         return false;
      }
   } else if (bwrite(bfd, data, length) != (ssize_t)length) {
      berrno be;
      Emsg2(M_ERROR_TERM, 0, _("Write error on %s: %s\n"),
            attr->ofname, be.bstrerror());
      return false;
   }

   return true;
}

#ifdef HAVE_LIBZ
static bool decompress_with_zlib(DEV_RECORD *rec, bool with_header)
{
   uLong compress_len = compress_buf_size;
   const unsigned char *cbuf;
   int real_compress_len;
   int status = Z_BUF_ERROR;

   compress_len = compress_buf_size;

   /*
    * See if this is a compressed stream with the new compression header or an old one.
    */
   if (with_header) {
      cbuf = (const unsigned char*) wbuf + sizeof(comp_stream_header);
      real_compress_len = wsize - sizeof(comp_stream_header);
   } else {
      cbuf = (const unsigned char*) wbuf;
      real_compress_len = wsize;
   }

   Dmsg2(200, "Comp_len=%d msglen=%d\n", compress_len, wsize);

   while (compress_len < MAX_UNCOMPRESSED_SIZE &&
         (status = uncompress((Byte *)compress_buf, &compress_len,
                              (const Byte *)cbuf, (uLong)real_compress_len)) == Z_BUF_ERROR) {
      /*
       * The buffer size is too small, try with a bigger one
       */
      compress_len = 2 * compress_len;
      compress_buf = check_pool_memory_size(compress_buf, compress_len);
   }

   if (status != Z_OK) {
      Emsg1(M_ERROR, 0, _("Uncompression error. ERR=%d\n"), status);
      extract = false;
      return false;
   }

   Dmsg2(100, "Write uncompressed %d bytes, total before write=%d\n", compress_len, total);
   store_data(&bfd, compress_buf, compress_len);
   total += compress_len;
   fileAddr += compress_len;
   Dmsg2(100, "Compress len=%d uncompressed=%d\n", rec->data_len, compress_len);

   return true;
}
#endif

#ifdef HAVE_LZO
static bool decompress_with_lzo(DEV_RECORD *rec)
{
   lzo_uint compress_len;
   const unsigned char *cbuf;
   int real_compress_len;
   int status = LZO_E_ERROR;

   compress_len = compress_buf_size;
   cbuf = (const unsigned char*) wbuf + sizeof(comp_stream_header);
   real_compress_len = wsize - sizeof(comp_stream_header);
   Dmsg2(200, "Comp_len=%d msglen=%d\n", compress_len, wsize);

   while (compress_len < MAX_UNCOMPRESSED_SIZE &&
         (status = lzo1x_decompress_safe(cbuf, real_compress_len,
                                         (unsigned char *)compress_buf,
                                         &compress_len, NULL)) == LZO_E_OUTPUT_OVERRUN) {
      /*
       * The buffer size is too small, try with a bigger one
       */
      compress_len = 2 * compress_len;
      compress_buf = check_pool_memory_size(compress_buf, compress_len);
   }

   if (status != LZO_E_OK) {
      Emsg1(M_ERROR, 0, _("LZO uncompression error. ERR=%d\n"), status);
      extract = false;
      return false;
   }

   Dmsg2(100, "Write uncompressed %d bytes, total before write=%d\n", compress_len, total);
   store_data(&bfd, compress_buf, compress_len);
   total += compress_len;
   fileAddr += compress_len;
   Dmsg2(100, "Compress len=%d uncompressed=%d\n", rec->data_len, compress_len);

   return true;
}
#endif

/*
 * Called here for each record from read_records()
 */
static bool record_cb(DCR *dcr, DEV_RECORD *rec)
{
   int status;
   JCR *jcr = dcr->jcr;

   if (rec->FileIndex < 0) {
      return true;                    /* we don't want labels */
   }

   /* File Attributes stream */

   switch (rec->maskedStream) {
   case STREAM_UNIX_ATTRIBUTES:
   case STREAM_UNIX_ATTRIBUTES_EX:

      /* If extracting, it was from previous stream, so
       * close the output file.
       */
      if (extract) {
         if (!is_bopen(&bfd)) {
            Emsg0(M_ERROR, 0, _("Logic error output file should be open but is not.\n"));
         }
         set_attributes(jcr, attr, &bfd);
         extract = false;
      }

      if (!unpack_attributes_record(jcr, rec->Stream, rec->data, rec->data_len, attr)) {
         Emsg0(M_ERROR_TERM, 0, _("Cannot continue.\n"));
      }

      if (file_is_included(ff, attr->fname) && !file_is_excluded(ff, attr->fname)) {
         attr->data_stream = decode_stat(attr->attr, &attr->statp, sizeof(attr->statp), &attr->LinkFI);
         if (!is_restore_stream_supported(attr->data_stream)) {
            if (!non_support_data++) {
               Jmsg(jcr, M_ERROR, 0, _("%s stream not supported on this Client.\n"),
                  stream_to_ascii(attr->data_stream));
            }
            extract = false;
            return true;
         }

         build_attr_output_fnames(jcr, attr);

         if (attr->type == FT_DELETED) { /* TODO: choose the right fname/ofname */
            Jmsg(jcr, M_INFO, 0, _("%s was deleted.\n"), attr->fname);
            extract = false;
            return true;
         }

         extract = false;
         status = create_file(jcr, attr, &bfd, REPLACE_ALWAYS);
         switch (status) {
         case CF_ERROR:
         case CF_SKIP:
            break;
         case CF_EXTRACT:
            extract = true;
            print_ls_output(jcr, attr);
            num_files++;
            fileAddr = 0;
            break;
         case CF_CREATED:
            set_attributes(jcr, attr, &bfd);
            print_ls_output(jcr, attr);
            num_files++;
            fileAddr = 0;
            break;
         }
      }
      break;

   case STREAM_RESTORE_OBJECT:
      /* nothing to do */
      break;

   /* Data stream and extracting */
   case STREAM_FILE_DATA:
   case STREAM_SPARSE_DATA:
   case STREAM_WIN32_DATA:

      if (extract) {
         if (rec->maskedStream == STREAM_SPARSE_DATA) {
            ser_declare;
            uint64_t faddr;
            wbuf = rec->data + OFFSET_FADDR_SIZE;
            wsize = rec->data_len - OFFSET_FADDR_SIZE;
            ser_begin(rec->data, OFFSET_FADDR_SIZE);
            unser_uint64(faddr);
            if (fileAddr != faddr) {
               fileAddr = faddr;
               if (blseek(&bfd, (boffset_t)fileAddr, SEEK_SET) < 0) {
                  berrno be;
                  Emsg2(M_ERROR_TERM, 0, _("Seek error on %s: %s\n"),
                     attr->ofname, be.bstrerror());
               }
            }
         } else {
            wbuf = rec->data;
            wsize = rec->data_len;
         }
         total += wsize;
         Dmsg2(8, "Write %u bytes, total=%u\n", wsize, total);
         store_data(&bfd, wbuf, wsize);
         fileAddr += wsize;
      }
      break;

   /* GZIP data stream */
   case STREAM_GZIP_DATA:
   case STREAM_SPARSE_GZIP_DATA:
   case STREAM_WIN32_GZIP_DATA:
#ifdef HAVE_LIBZ
      if (extract) {

         if (rec->maskedStream == STREAM_SPARSE_GZIP_DATA) {
            ser_declare;
            uint64_t faddr;
            char ec1[50];

            wbuf = rec->data + OFFSET_FADDR_SIZE;
            wsize = rec->data_len - OFFSET_FADDR_SIZE;

            ser_begin(rec->data, OFFSET_FADDR_SIZE);
            unser_uint64(faddr);
            ser_end(rec->data, OFFSET_FADDR_SIZE);

            if (fileAddr != faddr) {
               fileAddr = faddr;
               if (blseek(&bfd, (boffset_t)fileAddr, SEEK_SET) < 0) {
                  berrno be;
                  Emsg3(M_ERROR, 0, _("Seek to %s error on %s: ERR=%s\n"),
                     edit_uint64(fileAddr, ec1), attr->ofname, be.bstrerror());
                  extract = false;
                  return true;
               }
            }
         } else {
            wbuf = rec->data;
            wsize = rec->data_len;
         }

         if (!decompress_with_zlib(rec, false)) {
            return true;
         }
      }
#else
      if (extract) {
         Emsg0(M_ERROR, 0, _("GZIP data stream found, but GZIP not configured!\n"));
         extract = false;
         return true;
      }
#endif
      break;

   /* Compressed data stream */
   case STREAM_COMPRESSED_DATA:
   case STREAM_SPARSE_COMPRESSED_DATA:
   case STREAM_WIN32_COMPRESSED_DATA:
      if (extract) {
         uint32_t comp_magic, comp_len;
         uint16_t comp_level, comp_version;

         if (rec->maskedStream == STREAM_SPARSE_COMPRESSED_DATA) {
            ser_declare;
            uint64_t faddr;
            char ec1[50];

            wbuf = rec->data + OFFSET_FADDR_SIZE;
            wsize = rec->data_len - OFFSET_FADDR_SIZE;

            ser_begin(rec->data, OFFSET_FADDR_SIZE);
            unser_uint64(faddr);
            ser_end(rec->data, OFFSET_FADDR_SIZE);

            if (fileAddr != faddr) {
               fileAddr = faddr;
               if (blseek(&bfd, (boffset_t)fileAddr, SEEK_SET) < 0) {
                  berrno be;
                  Emsg3(M_ERROR, 0, _("Seek to %s error on %s: ERR=%s\n"),
                     edit_uint64(fileAddr, ec1), attr->ofname, be.bstrerror());
                  extract = false;
                  return true;
               }
            }
         } else {
            wbuf = rec->data;
            wsize = rec->data_len;
         }

         /*
          * Read compress header
          */
         unser_declare;
         unser_begin(wbuf, sizeof(comp_stream_header));
         unser_uint32(comp_magic);
         unser_uint32(comp_len);
         unser_uint16(comp_level);
         unser_uint16(comp_version);
         unser_end(wbuf, sizeof(comp_stream_header));

         Dmsg4(200, "Compressed data stream found: magic=0x%x, len=%d, level=%d, ver=0x%x\n",
               comp_magic, comp_len, comp_level, comp_version);

         /*
          * Version check
          */
         if (comp_version != COMP_HEAD_VERSION) {
            Emsg1(M_ERROR, 0, _("Compressed header version error. version=0x%x\n"), comp_version);
            return false;
         }
         /*
          * Size check
          */
         if (comp_len + sizeof(comp_stream_header) != wsize) {
            Emsg2(M_ERROR, 0, _("Compressed header size error. comp_len=%d, msglen=%d\n"),
                 comp_len, wsize);
            return false;
         }

          switch(comp_magic) {
#ifdef HAVE_LIBZ
            case COMPRESS_GZIP:
               if (!decompress_with_zlib(rec, true)) {
                  return true;
               }
               break;
#endif
#ifdef HAVE_LZO
            case COMPRESS_LZO1X:
               if (!decompress_with_lzo(rec)) {
                  return true;
               }
               break;
#endif
            default:
               Emsg1(M_ERROR, 0, _("Compression algorithm 0x%x found, but not supported!\n"), comp_magic);
               extract = false;
               return true;
         }

      }
      break;

   case STREAM_MD5_DIGEST:
   case STREAM_SHA1_DIGEST:
   case STREAM_SHA256_DIGEST:
   case STREAM_SHA512_DIGEST:
      break;

   case STREAM_SIGNED_DIGEST:
   case STREAM_ENCRYPTED_SESSION_DATA:
      // TODO landonf: Investigate crypto support in the storage daemon
      break;

   case STREAM_PROGRAM_NAMES:
   case STREAM_PROGRAM_DATA:
      if (!prog_name_msg) {
         Pmsg0(000, _("Got Program Name or Data Stream. Ignored.\n"));
         prog_name_msg++;
      }
      break;

   case STREAM_UNIX_ACCESS_ACL:          /* Deprecated Standard ACL attributes on UNIX */
   case STREAM_UNIX_DEFAULT_ACL:         /* Deprecated Default ACL attributes on UNIX */
   case STREAM_ACL_AIX_TEXT:
   case STREAM_ACL_DARWIN_ACCESS_ACL:
   case STREAM_ACL_FREEBSD_DEFAULT_ACL:
   case STREAM_ACL_FREEBSD_ACCESS_ACL:
   case STREAM_ACL_HPUX_ACL_ENTRY:
   case STREAM_ACL_IRIX_DEFAULT_ACL:
   case STREAM_ACL_IRIX_ACCESS_ACL:
   case STREAM_ACL_LINUX_DEFAULT_ACL:
   case STREAM_ACL_LINUX_ACCESS_ACL:
   case STREAM_ACL_TRU64_DEFAULT_ACL:
   case STREAM_ACL_TRU64_DEFAULT_DIR_ACL:
   case STREAM_ACL_TRU64_ACCESS_ACL:
   case STREAM_ACL_SOLARIS_ACLENT:
   case STREAM_ACL_SOLARIS_ACE:
   case STREAM_ACL_AFS_TEXT:
   case STREAM_ACL_AIX_AIXC:
   case STREAM_ACL_AIX_NFS4:
   case STREAM_ACL_FREEBSD_NFS4_ACL:
   case STREAM_ACL_HURD_DEFAULT_ACL:
   case STREAM_ACL_HURD_ACCESS_ACL:
      if (extract) {
         wbuf = rec->data;
         wsize = rec->data_len;
         pm_strcpy(acl_data.last_fname, attr->fname);

         parse_acl_streams(jcr, &acl_data, rec->maskedStream, wbuf, wsize);
      }
      break;

   case STREAM_XATTR_HURD:
   case STREAM_XATTR_IRIX:
   case STREAM_XATTR_TRU64:
   case STREAM_XATTR_AIX:
   case STREAM_XATTR_OPENBSD:
   case STREAM_XATTR_SOLARIS_SYS:
   case STREAM_XATTR_SOLARIS:
   case STREAM_XATTR_DARWIN:
   case STREAM_XATTR_FREEBSD:
   case STREAM_XATTR_LINUX:
   case STREAM_XATTR_NETBSD:
      if (extract) {
         wbuf = rec->data;
         wsize = rec->data_len;
         pm_strcpy(xattr_data.last_fname, attr->fname);

         parse_xattr_streams(jcr, &xattr_data, rec->maskedStream, wbuf, wsize);
      }
      break;

   case STREAM_NDMP_SEPERATOR:
      break;

   default:
      /* If extracting, weird stream (not 1 or 2), close output file anyway */
      if (extract) {
         if (!is_bopen(&bfd)) {
            Emsg0(M_ERROR, 0, _("Logic error output file should be open but is not.\n"));
         }
         set_attributes(jcr, attr, &bfd);
         extract = false;
      }
      Jmsg(jcr, M_ERROR, 0, _("Unknown stream=%d ignored. This shouldn't happen!\n"),
         rec->Stream);
      break;

   } /* end switch */
   return true;
}

/* Dummies to replace askdir.c */
bool dir_find_next_appendable_volume(DCR *dcr) { return 1;}
bool dir_update_volume_info(DCR *dcr, bool relabel, bool update_LastWritten) { return 1; }
bool dir_create_jobmedia_record(DCR *dcr, bool zero) { return 1; }
bool dir_ask_sysop_to_create_appendable_volume(DCR *dcr) { return 1; }
bool dir_update_file_attributes(DCR *dcr, DEV_RECORD *rec) { return 1;}

bool dir_ask_sysop_to_mount_volume(DCR *dcr, int /*mode*/)
{
   DEVICE *dev = dcr->dev;
   fprintf(stderr, _("Mount Volume \"%s\" on device %s and press return when ready: "),
      dcr->VolumeName, dev->print_name());
   dev->close(dcr);
   getchar();
   return true;
}

bool dir_get_volume_info(DCR *dcr, enum get_vol_info_rw  writing)
{
   Dmsg0(100, "Fake dir_get_volume_info\n");
   dcr->setVolCatName(dcr->VolumeName);
   Dmsg1(500, "Vol=%s\n", dcr->getVolCatName());
   return 1;
}
