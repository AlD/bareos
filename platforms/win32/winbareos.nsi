;
;   BAREOS?? - Backup Archiving REcovery Open Sourced
;
;   Copyright (C) 2012-2013 Bareos GmbH & Co. KG
;
;   This program is Free Software; you can redistribute it and/or
;   modify it under the terms of version three of the GNU Affero General Public
;   License as published by the Free Software Foundation and included
;   in the file LICENSE.
;
;   This program is distributed in the hope that it will be useful, but
;   WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
;   Affero General Public License for more details.
;
;   You should have received a copy of the GNU Affero General Public License
;   along with this program; if not, write to the Free Software
;   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
;   02110-1301, USA.

RequestExecutionLevel admin

!addplugindir ../nsisplugins



; HM NIS Edit Wizard helper defines
!define PRODUCT_NAME "Bareos"
#!define PRODUCT_VERSION "1.0"
!define PRODUCT_PUBLISHER "Bareos GmbH & Co.KG"
!define PRODUCT_WEB_SITE "http://www.bareos.com"
!define PRODUCT_DIR_REGKEY "Software\Microsoft\Windows\CurrentVersion\App Paths\bareos-fd.exe"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
!define PRODUCT_UNINST_ROOT_KEY "HKLM"

SetCompressor lzma


# variable definitions
Var LocalHostAddress
Var HostName

# Config Parameters Dialog

# Needed for Configuring client config file
Var ClientName            #XXX_REPLACE_WITH_HOSTNAME_XXX
Var ClientPassword        #XXX_REPLACE_WITH_FD_PASSWORD_XXX
Var ClientMonitorPassword #XXX_REPLACE_WITH_FD_MONITOR_PASSWORD_XXX
Var ClientAddress         #XXX_REPLACE_WITH_FD_MONITOR_PASSWORD_XXX

# Needed for bconsole and bat:
Var DirectorAddress       #XXX_REPLACE_WITH_HOSTNAME_XXX
Var DirectorPassword      #XXX_REPLACE_WITH_DIRECTOR_PASSWORD_XXX
Var DirectorName

# Needed for tray monitor:

# can stay like it is if we dont monitor any director -> Default
Var DirectorMonitorPassword #XXX_REPLACE_WITH_DIRECTOR_MONITOR_PASSWORD_XXX

# this is the one we need to make sure it is the same like configured in the fd
#Var ClientMonitorPassword   #XXX_REPLACE_WITH_FD_MONITOR_PASSWORD_XXX


# generated configuration snippet for bareos director config  (client ressource)
Var ConfigSnippet


Var dialog
Var hwnd

!include "LogicLib.nsh"
!include "FileFunc.nsh"
!include "Sections.nsh"
!include "StrFunc.nsh"
!include "WinMessages.nsh"
!include "nsDialogs.nsh"

# call functions once to have them included
${StrCase}
${StrTrimNewLines}




; MUI 1.67 compatible ------
!include "MUI.nsh"

; MUI Settings
!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"


!insertmacro GetParameters
!insertmacro GetOptions

; Welcome page
!insertmacro MUI_PAGE_WELCOME

; License
!insertmacro MUI_PAGE_LICENSE "LICENSE"

; Directory page
!insertmacro MUI_PAGE_DIRECTORY

; Components page
!insertmacro MUI_PAGE_COMPONENTS

; Custom für Abfragen benötigter Parameter für den Client
Page custom getClientParameters

; Custom für Abfragen benötigter Parameter für den Zugriff auf director
Page custom getDirectorParameters

; Instfiles page
!insertmacro MUI_PAGE_INSTFILES
; Finish page


; Custom page shows director config snippet
Page custom displayDirconfSnippet


#!define MUI_FINISHPAGE_RUN "$INSTDIR\bareos-fd.exe"

!insertmacro MUI_PAGE_FINISH

; Uninstaller pages
!insertmacro MUI_UNPAGE_INSTFILES

; Language files
!insertmacro MUI_LANGUAGE "English"

; Reserve files
!insertmacro MUI_RESERVEFILE_INSTALLOPTIONS

; MUI end ------


#
# move existing conf files to .old
# and install new ones in original place
# also, install a shortcut to edit
# the conf file
#
!macro InstallConfFile fname

# This is important to have $APPDATA variable
# point to ProgramData folder
# instead of current user's Roaming folder
 SetShellVarContext all

  ${If} ${FileExists} "$APPDATA\${PRODUCT_NAME}\${fname}"
  IfSilent +2
  MessageBox MB_OK|MB_ICONEXCLAMATION \
    "Existing config file found: $APPDATA\${PRODUCT_NAME}\${fname}$\r$\nmoving to $APPDATA\${PRODUCT_NAME}\${fname}.old"
    Rename "$APPDATA\${PRODUCT_NAME}\${fname}" "$APPDATA\${PRODUCT_NAME}\${fname}.old"
  ${EndIf}
 Rename "$PLUGINSDIR\${fname}" "$APPDATA\${PRODUCT_NAME}\${fname}"
 CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\Edit ${fname}.lnk" "write.exe" '"$APPDATA\${PRODUCT_NAME}\${fname}"'
!macroend



Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "${PRODUCT_NAME}-${PRODUCT_VERSION}.exe"
InstallDir "$PROGRAMFILES\${PRODUCT_NAME}"
InstallDirRegKey HKLM "${PRODUCT_DIR_REGKEY}" ""
ShowInstDetails show
ShowUnInstDetails show

InstType "Standard"
InstType "Full"
InstType "Minimal"


Section -StopDaemon
#  nsExec::ExecToLog "net stop bareos-fd"
# looks like this does not work on win7 sp1
# if the service doesnt exist, it fails and the installation
# cannot start
# so we use the shotgun:
  KillProcWMI::KillProc "bareos-fd.exe"
  KillProcWMI::KillProc "bareos-tray-monitor.exe"
SectionEnd


Section -SetPasswords
  SetShellVarContext all
# Write sed file to replace the preconfigured variables by the configured values
#
# File Daemon and Tray Monitor configs
#
  FileOpen $R1 $PLUGINSDIR\config.sed w
  #FileOpen $R1 config.sed w

  FileWrite $R1 "s#@VERSION@#${PRODUCT_VERSION}#g$\r$\n"
  FileWrite $R1 "s#@DATE@#${__DATE__}#g$\r$\n"
  FileWrite $R1 "s#@DISTNAME@#Windows#g$\r$\n"

  FileWrite $R1 "s#XXX_REPLACE_WITH_DIRECTOR_PASSWORD_XXX#$DirectorPassword#g$\r$\n"
  FileWrite $R1 "s#XXX_REPLACE_WITH_CLIENT_PASSWORD_XXX#$ClientPassword#g$\r$\n"
  FileWrite $R1 "s#XXX_REPLACE_WITH_CLIENT_MONITOR_PASSWORD_XXX#$ClientMonitorPassword#g$\r$\n"

  FileWrite $R1 "s#XXX_REPLACE_WITH_HOSTNAME_XXX#$HostName#g$\r$\n"

  FileWrite $R1 "s#XXX_REPLACE_WITH_BASENAME_XXX-fd#$ClientName#g$\r$\n"
  FileWrite $R1 "s#XXX_REPLACE_WITH_BASENAME_XXX-dir#$DirectorName#g$\r$\n"
  FileWrite $R1 "s#XXX_REPLACE_WITH_BASENAME_XXX-mon#$HostName-mon#g$\r$\n"

  FileClose $R1

  nsExec::ExecToLog '$PLUGINSDIR\sed.exe -f "$PLUGINSDIR\config.sed" -i-template "$PLUGINSDIR\bareos-fd.conf"'
  nsExec::ExecToLog '$PLUGINSDIR\sed.exe -f "$PLUGINSDIR\config.sed" -i-template "$PLUGINSDIR\tray-monitor.conf"'

  #Delete config.sed


#
# config files for bconsole and bat to access remote director
#
  FileOpen $R1 $PLUGINSDIR\bconsole.sed w

  FileWrite $R1 "s#XXX_REPLACE_WITH_BASENAME_XXX-dir#$DirectorName#g$\r$\n"
  FileWrite $R1 "s#XXX_REPLACE_WITH_HOSTNAME_XXX#$DirectorAddress#g$\r$\n"
  FileWrite $R1 "s#XXX_REPLACE_WITH_DIRECTOR_PASSWORD_XXX#$DirectorPassword#g$\r$\n"

  FileClose $R1


  nsExec::ExecToLog '$PLUGINSDIR\sed.exe -f "$PLUGINSDIR\bconsole.sed" -i-template "$PLUGINSDIR\bconsole.conf"'
  nsExec::ExecToLog '$PLUGINSDIR\sed.exe -f "$PLUGINSDIR\bconsole.sed" -i-template "$PLUGINSDIR\bat.conf"'

  #Delete bconsole.sed

#
#  write client config snippet for director
#
#
#  FileOpen $R1 import_this_file_into_your_director_config.txt w
#
#  FileWrite $R1 'Client {$\n'
#  FileWrite $R1 '  Name = $ClientName$\n'
#  FileWrite $R1 '  Address = $ClientAddress$\n'
#  FileWrite $R1 '  Password = "$ClientPassword"$\n'
#  FileWrite $R1 '  Catalog = "MyCatalog"$\n'
#  FileWrite $R1 '}$\n'
#
#  FileClose $R1
#


SectionEnd



Section "Bareos Client (FileDaemon) and base libs" SEC_CLIENT
SectionIn 1 2 3


  SetShellVarContext all
# TODO: only do this if the file exists
#  nsExec::ExecToLog '"$INSTDIR\bareos-fd.exe" /kill'
#  sleep 3000
#  nsExec::ExecToLog '"$INSTDIR\bareos-fd.exe" /remove'

  SetOutPath "$INSTDIR"
  SetOverwrite ifnewer
  CreateDirectory "$SMPROGRAMS\${PRODUCT_NAME}"
  CreateDirectory "$APPDATA\${PRODUCT_NAME}"
  File "bareos-fd.exe"
  File "bpipe-fd.dll"
  File "libbareos.dll"
  File "libbareosfind.dll"
  File "libcrypto-8.dll"
  File "libgcc_s_sjlj-1.dll"
  File "libssl-8.dll"
  File "libstdc++-6.dll"
  File "pthreadGCE2.dll"
  File "zlib1.dll"
  File "liblzo2-2.dll"

# for password generation
  File "openssl.exe"
  File "sed.exe"

  !insertmacro InstallConfFile bareos-fd.conf
#  File "bareos-fd.conf"

SectionEnd

Section /o "Text Console (bconsole)" SEC_BCONSOLE
SectionIn 2

  SetShellVarContext all
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\bconsole.lnk" "$INSTDIR\bconsole.exe" '-c "$APPDATA\${PRODUCT_NAME}\bconsole.conf"'

  File "bconsole.exe"
#  File "libbareos.dll"
#  File "libcrypto-8.dll"
#  File "libgcc_s_sjlj-1.dll"
  File "libhistory6.dll"
  File "libreadline6.dll"
#  File "libssl-8.dll"
#  File "libstdc++-6.dll"
  File "libtermcap-0.dll"
#  File "pthreadGCE2.dll"
#  File "zlib1.dll"
#
 !insertmacro InstallConfFile "bconsole.conf"
#  File "bconsole.conf

SectionEnd

#Section /o "Tray-Monitor" SEC_TRAYMON
#SectionIn 1 2
#
#
#  SetShellVarContext all
#  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\bareos-tray-monitor.lnk" "$INSTDIR\bareos-tray-monitor.exe" '-c "$APPDATA\${PRODUCT_NAME}\tray-monitor.conf"'
#
#  File "bareos-tray-monitor.exe"
##  File "libbareos.dll"
##  File "libcrypto-8.dll"
##  File "libgcc_s_sjlj-1.dll"
#  File "libpng15-15.dll"
##  File "libssl-8.dll"
##  File "libstdc++-6.dll"
##  File "pthreadGCE2.dll"
#  File "QtCore4.dll"
#  File "QtGui4.dll"
##  File "zlib1.dll"
#
#
#  !insertmacro InstallConfFile "tray-monitor.conf"
##  File "tray-monitor.conf"
#
#SectionEnd


Section /o "Qt Console (BAT)" SEC_BAT
SectionIn 2

  SetShellVarContext all
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\BAT.lnk" "$INSTDIR\bat.exe" '-c "$APPDATA\${PRODUCT_NAME}\bat.conf"'
  CreateShortCut "$DESKTOP\BAT.lnk" "$INSTDIR\bat.exe" '-c "$APPDATA\${PRODUCT_NAME}\bat.conf"'

  File "bat.exe"
#  File "libbareos.dll"
#  File "libcrypto-8.dll"
#  File "libgcc_s_sjlj-1.dll"
  File "libpng15-15.dll"
#  File "libssl-8.dll"
#  File "libstdc++-6.dll"
#  File "pthreadGCE2.dll"
  File "QtCore4.dll"
  File "QtGui4.dll"
#  File "zlib1.dll"

  !insertmacro InstallConfFile "bat.conf"
#  File "bat.conf"

SectionEnd

; Section descriptions
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_CLIENT} "Installs the Bareos File Daemon and required Files"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_BCONSOLE} "Installs the CLI client console (bconsole)"
#  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_TRAYMON} "Installs the tray Icon to monitor the Bareos client"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_BAT} "Installs the Qt Console (BAT)"
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Section -AdditionalIcons
  SetShellVarContext all
  WriteIniStr "$INSTDIR\${PRODUCT_NAME}.url" "InternetShortcut" "URL" "${PRODUCT_WEB_SITE}"
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\Website.lnk" "$INSTDIR\${PRODUCT_NAME}.url"
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\Uninstall.lnk" "$INSTDIR\uninst.exe"
SectionEnd

Section -Post
  SetShellVarContext all
  WriteUninstaller "$INSTDIR\uninst.exe"
  WriteRegStr HKLM "${PRODUCT_DIR_REGKEY}" "" "$INSTDIR\bareos-fd.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayName" "$(^Name)"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "UninstallString" "$INSTDIR\uninst.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayIcon" "$INSTDIR\bareos-fd.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"

# install service
  nsExec::ExecToLog '"$INSTDIR\bareos-fd.exe" /kill'
  sleep 3000
  nsExec::ExecToLog '"$INSTDIR\bareos-fd.exe" /remove'
  nsExec::ExecToLog '"$INSTDIR\bareos-fd.exe" /install -c "$APPDATA\${PRODUCT_NAME}\bareos-fd.conf"'

SectionEnd


Section -StartDaemon
  nsExec::ExecToLog "net start bareos-fd"
SectionEnd


# helper functions to find out computer name
Function GetComputerName
  Push $R0
  Push $R1
  Push $R2

  System::Call "kernel32::GetComputerNameA(t .R0, *i ${NSIS_MAX_STRLEN} R1) i.R2"

  ${StrCase} $R0 $R0 "L"

  Pop $R2
  Pop $R1
  Exch $R0
FunctionEnd

!define ComputerNameDnsFullyQualified   3

Function GetHostName
  Push $R0
  Push $R1
  Push $R2

  ${If} $OsIsNT = 1
    System::Call "kernel32::GetComputerNameExA(i ${ComputerNameDnsFullyQualified}, t .R0, *i ${NSIS_MAX_STRLEN} R1) i.R2 ?e"
    ${If} $R2 = 0
      Pop $R2
      DetailPrint "GetComputerNameExA failed - LastError = $R2"
      Call GetComputerName
      Pop $R0
    ${Else}
      Pop $R2
    ${EndIf}
  ${Else}
    Call GetComputerName
    Pop $R0
  ${EndIf}

  Pop $R2
  Pop $R1
  Exch $R0
FunctionEnd



Function .onInit

  ClearErrors
  ReadRegStr $2 ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayName"
  ReadRegStr $0 ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayVersion"
  StrCmp $2 "" +3
  MessageBox MB_OK|MB_ICONQUESTION "${PRODUCT_NAME} version $0 seems to be already installed on your system.$\r$\n Please uninstall first."
  Abort




# Parameters:
# Needed for Client and Tray-Mon:
#
#   Client Name
#
#   Director Name
#   Client Password
#   Client Network Address
#
#   Client Monitor Password
#
# Needed for Bconsole/Bat:
#
#   Director Network Address
#   Director Password
#

  var /GLOBAL cmdLineParams

# Installer Options
  ${GetParameters} $cmdLineParams
  ClearErrors


#  /? param (help)
  ClearErrors
  ${GetOptions} $cmdLineParams '/?' $R0
  IfErrors +3 0
  MessageBox MB_OK "[/CLIENTNAME=Name of the client ressource] $\r$\n\
                    [/CLIENTPASSWORD=Password to access the client]  $\r$\n\
                    [/DIRECTORNAME=Name of Director to access the client and of the Director accessed by bconsole/BAT]  $\r$\n\
                    [/CLIENTADDRESS=Network Address of the client] $\r$\n\
                    [/CLIENTMONITORPASSWORD=Password for monitor access] $\r$\n\
                    $\r$\n\
                    [/DIRECTORADDRESS=Network Address of the Director (for bconsole or BAT)] $\r$\n\
                    [/DIRECTORPASSWORD=Password to access Director]"
#                   [/DIRECTORNAME=Name of the Director to be accessed from bconsole/BAT]"
  Abort

  ${GetOptions} $cmdLineParams "/CLIENTNAME="  $ClientName
  ClearErrors

  ${GetOptions} $cmdLineParams "/CLIENTPASSWORD=" $ClientPassword
  ClearErrors

#  ${GetOptions} $cmdLineParams "/CLIENTDIRECTORNAME=" $DirectorName
#  ClearErrors

  ${GetOptions} $cmdLineParams "/CLIENTADDRESS=" $ClientAddress
  ClearErrors

  ${GetOptions} $cmdLineParams "/CLIENTMONITORPASSWORD=" $ClientMonitorPassword
  ClearErrors

  ${GetOptions} $cmdLineParams "/DIRECTORADDRESS=" $DirectorAddress
  ClearErrors

  ${GetOptions} $cmdLineParams "/DIRECTORPASSWORD=" $DirectorPassword
  ClearErrors

  ${GetOptions} $cmdLineParams "/DIRECTORNAME=" $DirectorName
  ClearErrors


  InitPluginsDir
  File "/oname=$PLUGINSDIR\clientdialog.ini"    "clientdialog.ini"
  File "/oname=$PLUGINSDIR\directordialog.ini"  "directordialog.ini"
  File "/oname=$PLUGINSDIR\openssl.exe"  	      "openssl.exe"
  File "/oname=$PLUGINSDIR\sed.exe"  	         "sed.exe"
  File "/oname=$PLUGINSDIR\libcrypto-8.dll" 	   "libcrypto-8.dll"
  File "/oname=$PLUGINSDIR\libgcc_s_sjlj-1.dll" "libgcc_s_sjlj-1.dll"
  File "/oname=$PLUGINSDIR\libssl-8.dll" 	      "libssl-8.dll"
  File "/oname=$PLUGINSDIR\libstdc++-6.dll" 	   "libstdc++-6.dll"
  File "/oname=$PLUGINSDIR\zlib1.dll" 	         "zlib1.dll"

  File "/oname=$PLUGINSDIR\bareos-fd.conf"     "bareos-fd.conf"
  File "/oname=$PLUGINSDIR\bconsole.conf"      "bconsole.conf"
  File "/oname=$PLUGINSDIR\bat.conf"           "bat.conf"
  File "/oname=$PLUGINSDIR\tray-monitor.conf"  "tray-monitor.conf"

# make first section mandatory
  SectionSetFlags ${SEC_CLIENT}  17 # SF_SELECTED & SF_RO
#  SectionSetFlags ${SEC_BCONSOLE}  ${SF_SELECTED} # SF_SELECTED
#SectionSetFlags ${SEC_TRAYMON}  ${SF_SELECTED} # SF_SELECTED

# find out the computer name
  Call GetComputerName
  Pop $HostName

  Call GetHostName
  Pop $LocalHostAddress

#  MessageBox MB_OK "Hostname: $HostName"
#  MessageBox MB_OK "LocalHostAddress: $LocalHostAddress"

  SetPluginUnload alwaysoff

# check if password is set by cmdline. If so, skip creation
  strcmp $ClientPassword "" genclientpassword skipclientpassword
  genclientpassword:
    nsExec::Exec '"$PLUGINSDIR\openssl.exe" rand -base64 -out $PLUGINSDIR\pw.txt 33'
    pop $R0
    ${If} $R0 = 0
     FileOpen $R1 "$PLUGINSDIR\pw.txt" r
     IfErrors +4
       FileRead $R1 $R0
       ${StrTrimNewLines} $ClientPassword $R0
       FileClose $R1
    ${EndIf}
  skipclientpassword:

  strcmp $ClientMonitorPassword "" genclientmonpassword skipclientmonpassword
  genclientmonpassword:
    nsExec::Exec '"$PLUGINSDIR\openssl.exe" rand -base64 -out $PLUGINSDIR\pw.txt 33'
    pop $R0
    ${If} $R0 = 0
     FileOpen $R1 "$PLUGINSDIR\pw.txt" r
     IfErrors +4
       FileRead $R1 $R0
       ${StrTrimNewLines} $ClientMonitorPassword $R0
       FileClose $R1
    ${EndIf}
  skipclientmonpassword:



#  MessageBox MB_OK "RandomPassword: $ClientPassword"
#  MessageBox MB_OK "RandomPassword: $ClientMonitorPassword"



# if the variables are not empty (because of cmdline params),
# dont set them with our own logic but leave them as they are
  strcmp $ClientName     "" +1 +2
  StrCpy $ClientName    "$HostName-fd"
  strcmp $ClientAddress "" +1 +2
  StrCpy $ClientAddress "$HostName"
  strcmp $DirectorName   "" +1 +2
  StrCpy $DirectorName  "bareos-dir"
  strcmp $DirectorAddress  "" +1 +2
  StrCpy $DirectorAddress  "bareos-dir.example.com"
  strcmp $DirectorPassword "" +1 +2
  StrCpy $DirectorPassword "DIRECTORPASSWORD"
FunctionEnd




#
# Client Configuration Dialog
#
Function getClientParameters
  Push $R0

# prefill the dialog fields with our passwords and other
# information

  WriteINIStr "$PLUGINSDIR\clientdialog.ini" "Field 2" "state" $ClientName

  WriteINIStr "$PLUGINSDIR\clientdialog.ini" "Field 3" "state" $DirectorName

  WriteINIStr "$PLUGINSDIR\clientdialog.ini" "Field 4" "state" $ClientPassword

  WriteINIStr "$PLUGINSDIR\clientdialog.ini" "Field 14" "state" $ClientMonitorPassword

  WriteINIStr "$PLUGINSDIR\clientdialog.ini" "Field 5" "state" $ClientAddress

#  WriteINIStr "$PLUGINSDIR\clientdialog.ini" "Field 7" "state" "Director console password"


${If} ${SectionIsSelected} ${SEC_CLIENT}
  InstallOptions::dialog $PLUGINSDIR\clientdialog.ini
  Pop $R0
  ReadINIStr  $ClientName             "$PLUGINSDIR\clientdialog.ini" "Field 2" "state"

  ReadINIStr  $DirectorName            "$PLUGINSDIR\clientdialog.ini" "Field 3" "state"

  ReadINIStr  $ClientPassword          "$PLUGINSDIR\clientdialog.ini" "Field 4" "state"

  ReadINIStr  $ClientMonitorPassword   "$PLUGINSDIR\clientdialog.ini" "Field 14" "state"

  ReadINIStr  $ClientAddress           "$PLUGINSDIR\clientdialog.ini" "Field 5" "state"
${EndIf}
#  MessageBox MB_OK "$ClientName$\r$\n$ClientPassword$\r$\n$ClientMonitorPassword "



  Pop $R0
FunctionEnd

#
# Director Configuration Dialog (for bconsole and bat configuration)
#
Function getDirectorParameters
  Push $R0
# prefill the dialog fields

  WriteINIStr "$PLUGINSDIR\directordialog.ini" "Field 2" "state" $DirectorAddress

  WriteINIStr "$PLUGINSDIR\directordialog.ini" "Field 3" "state" $DirectorPassword

#TODO: also do this if BAT is selected alone
${If} ${SectionIsSelected} ${SEC_BCONSOLE}
  InstallOptions::dialog $PLUGINSDIR\directordialog.ini
  Pop $R0

  ReadINIStr  $DirectorAddress        "$PLUGINSDIR\directordialog.ini" "Field 2" "state"

  ReadINIStr  $DirectorPassword       "$PLUGINSDIR\directordialog.ini" "Field 3" "state"

#  MessageBox MB_OK "$DirectorAddress$\r$\n$DirectorPassword"
${EndIf}
  Pop $R0
FunctionEnd

#
# Display auto-created snippet to be added to director config
#
Function displayDirconfSnippet

#
# write client config snippet for director
#
# Multiline text edits cannot be created before but have to be created at runtime.
# see http://nsis.sourceforge.net/NsDialogs_FAQ#How_to_create_a_multi-line_edit_.28text.29_control

  StrCpy $ConfigSnippet "Client {$\r$\n  \
                              Name = $ClientName$\r$\n  \
                              Address = $ClientAddress$\r$\n  \
                              Password = $\"$ClientPassword$\"$\r$\n  \
                              Catalog = $\"MyCatalog$\"$\r$\n  \
                           }$\r$\n"



  nsDialogs::Create 1018
  Pop $dialog
  ${NSD_CreateGroupBox} 0 0 100% 100% "Add this Client Ressource to your Bareos Director Configuration"
      Pop $hwnd

  nsDialogs::CreateControl EDIT \
      "${__NSD_Text_STYLE}|${WS_VSCROLL}|${ES_MULTILINE}|${ES_WANTRETURN}" \
      "${__NSD_Text_EXSTYLE}" \
      10 15 95% 90% \
      $ConfigSnippet
      Pop $hwnd

  nsDialogs::Show

FunctionEnd



Function un.onUninstSuccess
  HideWindow
  MessageBox MB_ICONINFORMATION|MB_OK "$(^Name) was successfully uninstalled." /SD IDYES
FunctionEnd

Function un.onInit
  MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 "Do you want to uninstall $(^Name) and all its components?" /SD IDYES IDYES +2
  Abort
FunctionEnd

Section Uninstall
  SetShellVarContext all
# uninstall service
  nsExec::ExecToLog '"$INSTDIR\bareos-fd.exe" /kill'
  sleep 3000
  nsExec::ExecToLog '"$INSTDIR\bareos-fd.exe" /remove'


# ask if existing config files should be kept
  IfSilent +2
  MessageBox MB_YESNO|MB_ICONQUESTION \
    "Do you want to delete the existing configuration files?" /SD IDYES IDNO ConfDeleteSkip

  Delete "$APPDATA\${PRODUCT_NAME}\bareos-fd.conf"
  Delete "$APPDATA\${PRODUCT_NAME}\tray-monitor.conf"
  Delete "$APPDATA\${PRODUCT_NAME}\bconsole.conf"
  Delete "$APPDATA\${PRODUCT_NAME}\bat.conf"

ConfDeleteSkip:
  Delete "$APPDATA\${PRODUCT_NAME}\bareos-fd.conf.old"
  Delete "$APPDATA\${PRODUCT_NAME}\tray-monitor.conf.old"
  Delete "$APPDATA\${PRODUCT_NAME}\bconsole.conf.old"
  Delete "$APPDATA\${PRODUCT_NAME}\bat.conf.old"

  RMDir  "$APPDATA\${PRODUCT_NAME}"

  Delete "$INSTDIR\${PRODUCT_NAME}.url"
  Delete "$INSTDIR\uninst.exe"
  Delete "$INSTDIR\bareos-tray-monitor.exe"
  Delete "$INSTDIR\bat.exe"
  Delete "$INSTDIR\bareos-fd.exe"
  Delete "$INSTDIR\bconsole.exe"
  Delete "$INSTDIR\bpipe-fd.dll"
  Delete "$INSTDIR\libbareos.dll"
  Delete "$INSTDIR\libbareosfind.dll"
  Delete "$INSTDIR\libcrypto-8.dll"
  Delete "$INSTDIR\libgcc_s_sjlj-1.dll"
  Delete "$INSTDIR\libhistory6.dll"
  Delete "$INSTDIR\libreadline6.dll"
  Delete "$INSTDIR\libssl-8.dll"
  Delete "$INSTDIR\libstdc++-6.dll"
  Delete "$INSTDIR\libtermcap-0.dll"
  Delete "$INSTDIR\pthreadGCE2.dll"
  Delete "$INSTDIR\zlib1.dll"
  Delete "$INSTDIR\QtCore4.dll"
  Delete "$INSTDIR\QtGui4.dll"
  Delete "$INSTDIR\liblzo2-2.dll"
  Delete "$INSTDIR\libpng15-15.dll"
  Delete "$INSTDIR\openssl.exe"
  Delete "$INSTDIR\sed.exe"

  Delete "$INSTDIR\*template"

  Delete "$SMPROGRAMS\${PRODUCT_NAME}\Uninstall.lnk"
  Delete "$SMPROGRAMS\${PRODUCT_NAME}\Website.lnk"
  Delete "$DESKTOP\${PRODUCT_NAME}.lnk"
  Delete "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME}.lnk"

# shortcuts
  Delete "$SMPROGRAMS\${PRODUCT_NAME}\Edit*.lnk"
  Delete "$SMPROGRAMS\${PRODUCT_NAME}\bconsole.lnk"
  Delete "$SMPROGRAMS\${PRODUCT_NAME}\BAT.lnk"
  Delete "$DESKTOP\BAT.lnk"
  Delete "$SMPROGRAMS\${PRODUCT_NAME}\Website.lnk"
  Delete "$SMPROGRAMS\${PRODUCT_NAME}\Uninstall.lnk"
  RMDir "$SMPROGRAMS\${PRODUCT_NAME}"
  RMDir "$INSTDIR"
  DeleteRegKey ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}"
  DeleteRegKey HKLM "${PRODUCT_DIR_REGKEY}"
  SetAutoClose true
SectionEnd


Function .onSelChange
Push $R0
Push $R1

  # Check if BAT was just selected then select SEC_BCONSOLE
  SectionGetFlags ${SEC_BAT} $R0
  IntOp $R0 $R0 & ${SF_SELECTED}
  StrCmp $R0 ${SF_SELECTED} 0 +2
  SectionSetFlags ${SEC_BCONSOLE} $R0
Pop $R1
Pop $R0
FunctionEnd



# TODO:
# - access on conf files has to be limited to administrators
# - tray-monitor automatic start at login
# - tray-monitor does not work right now (why?)
# - add firewall rule for bareos-fd after installation.
# - create snippet for restricted console that is only allowed to access
#   this client
# - find out if a prior version is already installed and use that install directory or uninstall it first
# - silent installer with configurable parameters that are otherwise in the forms

#
# DONE:
# - put the config files in $APPDATA
# - add section bconsole automatically when section bat is selected
# - add license information to installer
# - kill tray monitor before installing / updateing TODO: testing
# - replace "the network backups solution" by "backup archiving recovery open sourced"