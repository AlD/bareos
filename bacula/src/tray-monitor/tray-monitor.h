/*
 * Includes specific to the tray monitor
 *
 *     Nicolas Boichat, August MMIV
 *
 *    Version $Id$
 */
/*
   Copyright (C) 2004 Kern Sibbald and John Walker

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

#include "tray_conf.h"

#define TRAY_MONITOR 1

#include "jcr.h"

struct monitoritem {
   rescode type; /* R_CLIENT or R_STORAGE */
   void* resource; /* CLIENT* or STORE* */
};

