/*
 * Append code for Storage daemon
 *  Kern Sibbald, May MM
 *
 *  Version $Id$
 */
/*
   Copyright (C) 2000-2003 Kern Sibbald and John Walker

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


/* Responses sent to the File daemon */
static char OK_data[]    = "3000 OK data\n";

/* Forward referenced functions */
static bool are_attributes_spooled(JCR *jcr);
static int begin_attribute_spool(JCR *jcr);
static int discard_attribute_spool(JCR *jcr);
static int commit_attribute_spool(JCR *jcr);
static int open_data_spool_file(JCR *jcr);
static int close_data_spool_file(JCR *jcr);
static int begin_data_spool(JCR *jcr);
static int discard_data_spool(JCR *jcr);
static int commit_data_spool(JCR *jcr);


/* 
 *  Append Data sent from File daemon	
 *
 */
int do_append_data(JCR *jcr) 
{
   int32_t n;
   int32_t file_index, stream, last_file_index;
   BSOCK *ds;
   BSOCK *fd_sock = jcr->file_bsock;
   bool ok = true;
   DEVICE *dev;
   DEV_RECORD rec;
   DEV_BLOCK  *block;
   DCR *dcr;
   
   Dmsg0(10, "Start append data.\n");

   ds = fd_sock;

   if (!bnet_set_buffer_size(ds, jcr->device->max_network_buffer_size, BNET_SETBUF_WRITE)) {
      set_jcr_job_status(jcr, JS_ErrorTerminated);
      Jmsg(jcr, M_FATAL, 0, _("Unable to set network buffer size.\n"));
      return 0;
   }

   /* 
    * Acquire output device for writing.  Note, after acquiring a
    *	device, we MUST release it, which is done at the end of this
    *	subroutine.
    */
   Dmsg0(100, "just before acquire_device\n");
   if (!(dcr=acquire_device_for_append(jcr))) {
      set_jcr_job_status(jcr, JS_ErrorTerminated);
      return 0;
   }
   dev = dcr->dev;
   block = dcr->block;

   Dmsg1(20, "Begin append device=%s\n", dev_name(dev));

   begin_data_spool(jcr);
   begin_attribute_spool(jcr);

   Dmsg0(100, "Just after acquire_device_for_append\n");
   /*
    * Write Begin Session Record
    */
   if (!write_session_label(jcr, block, SOS_LABEL)) {
      Jmsg1(jcr, M_FATAL, 0, _("Write session label failed. ERR=%s\n"),
	 strerror_dev(dev));
      set_jcr_job_status(jcr, JS_ErrorTerminated);
      ok = false;
   }

   /* Tell File daemon to send data */
   bnet_fsend(fd_sock, OK_data);

   /* 
    * Get Data from File daemon, write to device.  To clarify what is
    *	going on here.	We expect:	  
    *	  - A stream header
    *	  - Multiple records of data
    *	  - EOD record
    *
    *	 The Stream header is just used to sychronize things, and
    *	 none of the stream header is written to tape.
    *	 The Multiple records of data, contain first the Attributes,
    *	 then after another stream header, the file data, then
    *	 after another stream header, the MD5 data if any.  
    *
    *	So we get the (stream header, data, EOD) three time for each
    *	file. 1. for the Attributes, 2. for the file data if any, 
    *	and 3. for the MD5 if any.
    */
   dcr->VolFirstIndex = dcr->VolLastIndex = 0;
   jcr->run_time = time(NULL);		    /* start counting time for rates */
   for (last_file_index = 0; ok && !job_canceled(jcr); ) {

      /* Read Stream header from the File daemon.
       *  The stream header consists of the following:
       *    file_index (sequential Bacula file index, base 1)
       *    stream     (Bacula number to distinguish parts of data)
       *    info       (Info for Storage daemon -- compressed, encryped, ...)
       *       info is not currently used, so is read, but ignored!
       */
     if ((n=bget_msg(ds)) <= 0) {
	 if (n == BNET_SIGNAL && ds->msglen == BNET_EOD) {
	    break;		      /* end of data */
	 }
         Jmsg1(jcr, M_FATAL, 0, _("Error reading data header from FD. ERR=%s\n"),
	    bnet_strerror(ds));
	 ok = false;
	 break;
      }
	
      /* 
       * This hand scanning is a bit more complicated than a simple
       *   sscanf, but it allows us to handle any size integer up to
       *   int64_t without worrying about whether %d, %ld, %lld, or %q 
       *   is the correct format for each different architecture.
       * It is a real pity that sscanf() is not portable.
       */
      char *p = ds->msg;
      while (B_ISSPACE(*p)) {
	 p++;
      }
      file_index = (int32_t)str_to_int64(p);
      while (B_ISDIGIT(*p)) {
	 p++;
      }
      if (!B_ISSPACE(*p) || !B_ISDIGIT(*(p+1))) {
         Jmsg1(jcr, M_FATAL, 0, _("Malformed data header from FD: %s\n"), ds->msg);
	 ok = false;
	 break;
      }
      stream = (int32_t)str_to_int64(p);

      Dmsg2(190, "<filed: Header FilInx=%d stream=%d\n", file_index, stream);

      if (!(file_index > 0 && (file_index == last_file_index ||
	  file_index == last_file_index + 1))) {
         Jmsg0(jcr, M_FATAL, 0, _("File index from FD not positive or sequential\n"));
	 ok = false;
	 break;
      }
      if (file_index != last_file_index) {
	 jcr->JobFiles = file_index;
	 last_file_index = file_index;
      }
      
      /* Read data stream from the File daemon.
       *  The data stream is just raw bytes
       */
      while ((n=bget_msg(ds)) > 0 && !job_canceled(jcr)) {
	 rec.VolSessionId = jcr->VolSessionId;
	 rec.VolSessionTime = jcr->VolSessionTime;
	 rec.FileIndex = file_index;
	 rec.Stream = stream;
	 rec.data_len = ds->msglen;
	 rec.data = ds->msg;		/* use message buffer */

         Dmsg4(250, "before writ_rec FI=%d SessId=%d Strm=%s len=%d\n",
	    rec.FileIndex, rec.VolSessionId, stream_to_ascii(rec.Stream,rec.FileIndex), 
	    rec.data_len);
	  
	 while (!write_record_to_block(block, &rec)) {
            Dmsg2(150, "!write_record_to_block data_len=%d rem=%d\n", rec.data_len,
		       rec.remainder);
	    if (!write_block_to_device(jcr, dev, block)) {
               Dmsg2(90, "Got write_block_to_dev error on device %s. %s\n",
		  dev_name(dev), strerror_dev(dev));
               Jmsg(jcr, M_FATAL, 0, _("Cannot fixup device error. %s\n"),
		     strerror_dev(dev));
	       ok = false;
	       break;
	    }
	 }
	 if (!ok) {
            Dmsg0(400, "Not OK\n");
	    break;
	 }
	 jcr->JobBytes += rec.data_len;   /* increment bytes this job */
         Dmsg4(200, "write_record FI=%s SessId=%d Strm=%s len=%d\n",
	    FI_to_ascii(rec.FileIndex), rec.VolSessionId, 
	    stream_to_ascii(rec.Stream, rec.FileIndex), rec.data_len);

	 /* Send attributes and MD5 to Director for Catalog */
	 if (stream == STREAM_UNIX_ATTRIBUTES	 || stream == STREAM_MD5_SIGNATURE ||
	     stream == STREAM_UNIX_ATTRIBUTES_EX || stream == STREAM_SHA1_SIGNATURE) { 
	    if (!jcr->no_attributes) {
	       if (are_attributes_spooled(jcr)) {
		  jcr->dir_bsock->spool = 1;
	       }
               Dmsg0(200, "Send attributes.\n");
	       if (!dir_update_file_attributes(jcr, &rec)) {
                  Jmsg(jcr, M_FATAL, 0, _("Error updating file attributes. ERR=%s\n"),
		     bnet_strerror(jcr->dir_bsock));
		  ok = false;
		  jcr->dir_bsock->spool = 0;
		  break;
	       }
	       jcr->dir_bsock->spool = 0;
	    }
	 }
      }
      if (is_bnet_error(ds)) {
         Jmsg1(jcr, M_FATAL, 0, _("Network error on data channel. ERR=%s\n"),
	    bnet_strerror(ds));
	 ok = false;
	 break;
      }
   }

   /* Create Job status for end of session label */
   set_jcr_job_status(jcr, ok?JS_Terminated:JS_ErrorTerminated);

   Dmsg1(200, "Write session label JobStatus=%d\n", jcr->JobStatus);

   /*
    * If !OK, check if we can still write. This may not be the case
    *  if we are at the end of the tape or we got a fatal I/O error.
    */
   if (ok || dev_can_write(dev)) {
      if (!write_session_label(jcr, block, EOS_LABEL)) {
         Jmsg1(jcr, M_FATAL, 0, _("Error writting end session label. ERR=%s\n"),
	     strerror_dev(dev));
	 set_jcr_job_status(jcr, JS_ErrorTerminated);
	 ok = false;
      }
      Dmsg0(90, "back from write_end_session_label()\n");
      /* Flush out final partial block of this session */
      if (!write_block_to_device(jcr, dev, block)) {
         Dmsg0(100, _("Set ok=FALSE after write_block_to_device.\n"));
	 set_jcr_job_status(jcr, JS_ErrorTerminated);
	 ok = false;
      }
   }

   if (!ok) {
      discard_data_spool(jcr);
   } else {
      commit_data_spool(jcr);
   }

   Dmsg1(200, "calling release device JobStatus=%d\n", jcr->JobStatus);
   /* Release the device */
   if (!release_device(jcr)) {
      Pmsg0(000, _("Error in release_device\n"));
      set_jcr_job_status(jcr, JS_ErrorTerminated);
      ok = false;
   }

   if (!ok) {
      discard_attribute_spool(jcr);
   } else {
      commit_attribute_spool(jcr);
   }

   dir_send_job_status(jcr);	      /* update director */

   Dmsg1(100, "return from do_append_data() stat=%d\n", ok);
   return ok ? 1 : 0;
}


static int begin_data_spool(JCR *jcr)
{
   if (jcr->dcr->spool_data) {
      return open_data_spool_file(jcr);
   }
   return 1;
}

static int discard_data_spool(JCR *jcr)
{
   if (jcr->dcr->spool_data && jcr->dcr->spool_fd >= 0) {
      return close_data_spool_file(jcr);
   }
   return 1;
}

static int commit_data_spool(JCR *jcr)
{
   if (jcr->dcr->spool_data && jcr->dcr->spool_fd >= 0) {
//	despool_data(jcr);
      return close_data_spool_file(jcr);
   }
   return 1;
}

static void make_unique_data_spool_filename(JCR *jcr, POOLMEM **name)
{
   Mmsg(name, "%s/%s.data.spool.%s.%s", working_directory, my_name,
      jcr->Job, jcr->device->hdr.name);
}


static int open_data_spool_file(JCR *jcr)
{
   POOLMEM *name  = get_pool_memory(PM_MESSAGE);
   int spool_fd;

   make_unique_data_spool_filename(jcr, &name);
   if ((spool_fd = open(name, O_CREAT|O_TRUNC|O_RDWR|O_BINARY, 0640)) >= 0) {
      jcr->dcr->spool_fd = spool_fd;
      jcr->spool_attributes = true;
   } else {
      Jmsg(jcr, M_ERROR, 0, "open data spool file %s failed: ERR=%s\n", name, strerror(errno));
      free_pool_memory(name);
      return 0;
    }
    free_pool_memory(name);
    return 1;
}

static int close_data_spool_file(JCR *jcr)
{
    POOLMEM *name  = get_pool_memory(PM_MESSAGE);

    make_unique_data_spool_filename(jcr, &name);
    close(jcr->dcr->spool_fd);
    jcr->dcr->spool_fd = -1;
    unlink(name);
    free_pool_memory(name);
    return 1;
}


static bool are_attributes_spooled(JCR *jcr)
{
   return jcr->spool_attributes && jcr->dir_bsock->spool_fd;
}

static int begin_attribute_spool(JCR *jcr)
{
   if (!jcr->no_attributes && jcr->spool_attributes) {
      return open_spool_file(jcr, jcr->dir_bsock);
   }
   return 1;
}

static int discard_attribute_spool(JCR *jcr)
{
   if (are_attributes_spooled(jcr)) {
      return close_spool_file(jcr, jcr->dir_bsock);
   }
   return 1;
}

static int commit_attribute_spool(JCR *jcr)
{
   if (are_attributes_spooled(jcr)) {
      bnet_despool_to_bsock(jcr->dir_bsock);
      return close_spool_file(jcr, jcr->dir_bsock);
   }
   return 1;
}
