//                              -*- Mode: C++ -*-
// vss.cpp -- Interface to Volume Shadow Copies (VSS)
//
// Copyright transferred from MATRIX-Computer GmbH to
//   Kern Sibbald by express permission.
//
// Copyright (C) 2004-2005 Kern Sibbald
//
//   This program is free software; you can redistribute it and/or
//   modify it under the terms of the GNU General Public License as
//   published by the Free Software Foundation; either version 2 of
//   the License, or (at your option) any later version.
//
//   This program is distributed in the hope that it will be useful,
//   but WITHOUT ANY WARRANTY; without even the implied warranty of
//   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//   General Public License for more details.
//
//   You should have received a copy of the GNU General Public
//   License along with this program; if not, write to the Free
//   Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
//   MA 02111-1307, USA.
//
// Author          : Thorsten Engel
// Created On      : Fri May 06 21:44:00 2006


#include <stdio.h>
#include <basetsd.h>
#include <stdarg.h>
#include <sys/types.h>
#include <process.h>
#include <direct.h>
#include <winsock2.h>
#include <windows.h>
#include <wincon.h>
#include <winbase.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <conio.h>
#include <process.h>
#include <errno.h>
#include <string.h>
#include <time.h>
#include <signal.h>
#include <malloc.h>
#include <setjmp.h>
#include <direct.h>
#include <ctype.h>
#include <fcntl.h>
#include <io.h>


// STL includes
#include <vector>
#include <algorithm>
#include <string>
#include <fstream>
using namespace std;   

#include <atlcomcli.h>
#include <objbase.h>


// Used for safe string manipulation
#include <strsafe.h>
#include "vss.h"


#pragma comment(lib,"atlsd.lib")



// Constructor
VSSClient::VSSClient()
{
    m_bCoInitializeCalled = false;
    m_dwContext = 0; // VSS_CTX_BACKUP;
    m_bDuringRestore = false;
    m_bBackupIsInitialized = false;
    m_pVssObject = NULL;
    memset (m_wszUniqueVolumeName,0,sizeof (m_wszUniqueVolumeName));
    memset (m_szShadowCopyName,0,sizeof (m_szShadowCopyName));
}

// Destructor
VSSClient::~VSSClient()
{
   // Release the IVssBackupComponents interface 
   // WARNING: this must be done BEFORE calling CoUninitialize()
   if (m_pVssObject) {
      m_pVssObject->Release();
      m_pVssObject = NULL;
   }

   // Call CoUninitialize if the CoInitialize was performed sucesfully
   if (m_bCoInitializeCalled)
      CoUninitialize();
}

BOOL VSSClient::InitializeForBackup()
{
    //return Initialize (VSS_CTX_BACKUP);
   return Initialize (0);
}




BOOL VSSClient::GetShadowPath (const char* szFilePath, char* szShadowPath, int nBuflen)
{
   if (!m_bBackupIsInitialized)
      return FALSE;

   /* check for valid pathname */
   BOOL bIsValidName;
   
   bIsValidName = strlen (szFilePath) > 3;
   if (bIsValidName)
      bIsValidName &= isalpha (szFilePath[0]) &&
                      szFilePath[1]==':' && 
                      szFilePath[2]=='\\';

   if (bIsValidName) {
      int nDriveIndex = toupper(szFilePath[0])-'A';
      if (m_szShadowCopyName[nDriveIndex][0] != 0) {
         strncpy (szShadowPath, m_szShadowCopyName[nDriveIndex], nBuflen);
         nBuflen -= (int) strlen (m_szShadowCopyName[nDriveIndex]);
         strncat (szShadowPath, szFilePath+2,nBuflen);

         return TRUE;
      }
   }
   
   strncpy (szShadowPath,  szFilePath, nBuflen);
   return FALSE;   
}