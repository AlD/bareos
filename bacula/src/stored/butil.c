/*
 *
 *  Utility routines for "tool" programs such as bscan, bls,
 *    bextract, ...  
 * 
 *  Normally nothing in this file is called by the Storage   
 *    daemon because we interact more directly with the user
 *    i.e. printf, ...
 *
 *   Version $Id$
 */
/*
   Copyright (C) 2000, 2001, 2002 Kern Sibbald and John Walker

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License as
   published by the Free Software Foundation; either version 2 of
   the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this program; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
   MA 02111-1307, USA.

 */

#include "bacula.h"
#include "stored.h"

/* Imported variables -- eliminate some day */
extern char *configfile;

#ifdef DEBUG
char *rec_state_to_str(DEV_RECORD *rec)
{
   static char buf[200]; 
   buf[0] = 0;
   if (rec->state & REC_NO_HEADER) {
      strcat(buf, "Nohdr,");
   }
   if (is_partial_record(rec)) {
      strcat(buf, "partial,");
   }
   if (rec->state & REC_BLOCK_EMPTY) {
      strcat(buf, "empty,");
   }
   if (rec->state & REC_NO_MATCH) {
      strcat(buf, "Nomatch,");
   }
   if (rec->state & REC_CONTINUATION) {
      strcat(buf, "cont,");
   }
   if (buf[0]) {
      buf[strlen(buf)-1] = 0;
   }
   return buf;
}
#endif


/*
 * Setup device, jcr, and prepare to access device.
 *   If the caller wants read access, acquire the device, otherwise,
 *     the caller will do it.
 */
DEVICE *setup_to_access_device(JCR *jcr, int read_access)
{
   DEVICE *dev;
   DEV_BLOCK *block;
   char *p;
   DEVRES *device;

   jcr->VolumeName[0] = 0;
   if (strncmp(jcr->dev_name, "/dev/", 5) != 0) {
      /* Try stripping file part */
      p = jcr->dev_name + strlen(jcr->dev_name);
      while (p >= jcr->dev_name && *p != '/')
	 p--;
      if (*p == '/') {
	 strcpy(jcr->VolumeName, p+1);
	 *p = 0;
      }
   }

   if ((device=find_device_res(jcr->dev_name, read_access)) == NULL) {
      Jmsg2(jcr, M_FATAL, 0, _("Cannot find device %s in config file %s.\n"), 
	   jcr->dev_name, configfile);
      return NULL;
   }
   
   dev = init_dev(NULL, device);
   if (!dev || !open_device(dev)) {
      Jmsg1(jcr, M_FATAL, 0, _("Cannot open %s\n"), jcr->dev_name);
      return NULL;
   }
   Dmsg0(90, "Device opened for read.\n");

   block = new_block(dev);

   create_vol_list(jcr);

   if (read_access) {
      if (!acquire_device_for_read(jcr, dev, block)) {
	 free_block(block);
	 return NULL;
      }
   }
   free_block(block);
   return dev;
}


/*
 * Search for device resource that corresponds to 
 * device name on command line (or default).
 *	 
 * Returns: NULL on failure
 *	    Device resource pointer on success
 */
DEVRES *find_device_res(char *device_name, int read_access)
{
   int found = 0;
   DEVRES *device;

   LockRes();
   for (device=NULL; (device=(DEVRES *)GetNextRes(R_DEVICE, (RES *)device)); ) {
      if (strcmp(device->device_name, device_name) == 0) {
	 found = 1;
	 break;
      }
   } 
   UnlockRes();
   if (!found) {
      Pmsg2(0, _("Could not find device %s in config file %s.\n"), device_name,
	    configfile);
      return NULL;
   }
   Pmsg2(0, _("Using device: %s for %s.\n"), device_name,
             read_access?"reading":"writing");
   return device;
}



/*
 * Called here when freeing JCR so that we can get rid 
 *  of "daemon" specific memory allocated.
 */
static void my_free_jcr(JCR *jcr)
{
   if (jcr->pool_name) {
      free_pool_memory(jcr->pool_name);
      jcr->pool_name = NULL;
   }
   if (jcr->pool_type) {
      free_pool_memory(jcr->pool_type);
      jcr->pool_type = NULL;
   }
   if (jcr->job_name) {
      free_pool_memory(jcr->job_name);
      jcr->job_name = NULL;
   }
   if (jcr->client_name) {
      free_pool_memory(jcr->client_name);
      jcr->client_name = NULL;
   }
   if (jcr->fileset_name) {
      free_pool_memory(jcr->fileset_name);
      jcr->fileset_name = NULL;
   }
   if (jcr->fileset_md5) {
      free_pool_memory(jcr->fileset_md5);
      jcr->fileset_md5 = NULL;
   }
   if (jcr->dev_name) {
      free_pool_memory(jcr->dev_name);
      jcr->dev_name = NULL;
   }
   if (jcr->VolList) {
      free_vol_list(jcr);
   }  
     
   return;
}

/*
 * Setup a "daemon" JCR for the various standalone
 *  tools (e.g. bls, bextract, bscan, ...)
 */
JCR *setup_jcr(char *name, char *device, BSR *bsr) 
{
   JCR *jcr = new_jcr(sizeof(JCR), my_free_jcr);
   jcr->VolSessionId = 1;
   jcr->VolSessionTime = (uint32_t)time(NULL);
   jcr->bsr = bsr;
   jcr->NumVolumes = 1;
   jcr->pool_name = get_pool_memory(PM_FNAME);
   strcpy(jcr->pool_name, "Default");
   jcr->pool_type = get_pool_memory(PM_FNAME);
   strcpy(jcr->pool_type, "Backup");
   jcr->job_name = get_pool_memory(PM_FNAME);
   strcpy(jcr->job_name, "Dummy.Job.Name");
   jcr->client_name = get_pool_memory(PM_FNAME);
   strcpy(jcr->client_name, "Dummy.Client.Name");
   strcpy(jcr->Job, name);
   jcr->fileset_name = get_pool_memory(PM_FNAME);
   strcpy(jcr->fileset_name, "Dummy.fileset.name");
   jcr->fileset_md5 = get_pool_memory(PM_FNAME);
   strcpy(jcr->fileset_md5, "Dummy.fileset.md5");
   jcr->JobId = 1;
   jcr->JobType = JT_BACKUP;
   jcr->JobLevel = L_FULL;
   jcr->JobStatus = JS_Terminated;
   jcr->dev_name = get_pool_memory(PM_FNAME);
   pm_strcpy(&jcr->dev_name, device);
   return jcr;
}


/*
 * Device got an error, attempt to analyse it
 */
void display_error_status(DEVICE *dev)
{
   uint32_t status;

   Emsg0(M_ERROR, 0, dev->errmsg);
   status_dev(dev, &status);
   Dmsg1(20, "Device status: %x\n", status);
   if (status & MT_EOD)
      Emsg0(M_ERROR_TERM, 0, _("Unexpected End of Data\n"));
   else if (status & MT_EOT)
      Emsg0(M_ERROR_TERM, 0, _("Unexpected End of Tape\n"));
   else if (status & MT_EOF)
      Emsg0(M_ERROR_TERM, 0, _("Unexpected End of File\n"));
   else if (status & MT_DR_OPEN)
      Emsg0(M_ERROR_TERM, 0, _("Tape Door is Open\n"));
   else if (!(status & MT_ONLINE))
      Emsg0(M_ERROR_TERM, 0, _("Unexpected Tape is Off-line\n"));
   else
      Emsg2(M_ERROR_TERM, 0, _("Read error on Record Header %s: %s\n"), dev_name(dev), strerror(errno));
}


extern char *getuser(uid_t uid);
extern char *getgroup(gid_t gid);

void print_ls_output(char *fname, char *link, int type, struct stat *statp)
{
   char buf[1000]; 
   char ec1[30];
   char *p, *f;
   int n;

   p = encode_mode(statp->st_mode, buf);
   n = sprintf(p, "  %2d ", (uint32_t)statp->st_nlink);
   p += n;
   n = sprintf(p, "%-8.8s %-8.8s", getuser(statp->st_uid), getgroup(statp->st_gid));
   p += n;
   n = sprintf(p, "%8.8s ", edit_uint64(statp->st_size, ec1));
   p += n;
   p = encode_time(statp->st_ctime, p);
   *p++ = ' ';
   *p++ = ' ';
   /* Copy file name */
   for (f=fname; *f && (p-buf) < (int)sizeof(buf); )
      *p++ = *f++;
   if (type == FT_LNK) {
      *p++ = ' ';
      *p++ = '-';
      *p++ = '>';
      *p++ = ' ';
      /* Copy link name */
      for (f=link; *f && (p-buf) < (int)sizeof(buf); )
	 *p++ = *f++;
   }
   *p++ = '\n';
   *p = 0;
   fputs(buf, stdout);
}
