/*
   Bacula® - The Network Backup Solution

   Copyright (C) 2000-2008 Free Software Foundation Europe e.V.

   The main author of Bacula is Kern Sibbald, with contributions from
   many others, a complete list can be found in the file AUTHORS.
   This program is Free Software; you can redistribute it and/or
   modify it under the terms of version three of the GNU Affero General Public
   License as published by the Free Software Foundation and included
   in the file LICENSE.

   This program is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
   General Public License for more details.

   You should have received a copy of the GNU Affero General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
   02110-1301, USA.

   Bacula® is a registered trademark of Kern Sibbald.
   The licensor of Bacula is the Free Software Foundation Europe
   (FSFE), Fiduciary Program, Sumatrastrasse 25, 8006 Zürich,
   Switzerland, email:ftf@fsfeurope.org.
*/
/*
 * Includes specific to the Director
 *
 *     Kern Sibbald, December MM
 *
 *    Version $Id$
 */

#include "lib/runscript.h"
#include "lib/breg.h"
#include "lib/bsr.h"
#include "dird_conf.h"

#define DIRECTOR_DAEMON 1

#include "dir_plugins.h"
#include "cats/cats.h"
#include "cats/sql_glue.h"

#include "jcr.h"
#include "bsr.h"
#include "ua.h"
#include "jobq.h"

/* Globals that dird.c exports */
extern DIRRES *director;                     /* Director resource */
extern int FDConnectTimeout;
extern int SDConnectTimeout;

/* Used in ua_prune.c and ua_purge.c */

struct s_count_ctx {
   int count;
};

#define MAX_DEL_LIST_LEN 2000000

struct del_ctx {
   JobId_t *JobId;                    /* array of JobIds */
   char *PurgedFiles;                 /* Array of PurgedFile flags */
   int num_ids;                       /* ids stored */
   int max_ids;                       /* size of array */
   int num_del;                       /* number deleted */
   int tot_ids;                       /* total to process */
};

/* Flags for find_next_volume_for_append() */
enum {
  fnv_create_vol    = true,
  fnv_no_create_vol = false,
  fnv_prune         = true,
  fnv_no_prune      = false
};

enum e_prtmsg {
   DISPLAY_ERROR,
   NO_DISPLAY
};

enum e_pool_op {
   POOL_OP_UPDATE,
   POOL_OP_CREATE
};

enum e_move_op {
   VOLUME_IMPORT,
   VOLUME_EXPORT,
   VOLUME_MOVE
};

typedef enum {
   slot_type_unknown,     /* unknown slot type */
   slot_type_drive,       /* drive slot */
   slot_type_normal,      /* normal slot */
   slot_type_import       /* import/export slot */
} slot_type;

typedef enum {
   slot_content_unknown,  /* slot content is unknown */
   slot_content_empty,    /* slot is empty */
   slot_content_full      /* slot is full */
} slot_content;

/* Slot list definition */
typedef struct s_vol_list {
   dlink link;            /* link for list */
   int Index;             /* Unique index */
   slot_type Type;        /* See slot_type_* */
   slot_content Content;  /* See slot_content_* */
   int Slot;              /* Drive number when slot_type_drive or actual slot number */
   int Loaded;            /* Volume loaded in drive when slot_type_drive */
   char *VolName;         /* Actual Volume Name */
} vol_list_t;

#define INDEX_DRIVE_OFFSET 0
#define INDEX_MAX_DRIVES 100
#define INDEX_SLOT_OFFSET 100

#include "protos.h"
