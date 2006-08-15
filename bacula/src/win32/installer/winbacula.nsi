; winbacula.nsi
;
; Began as a version written by Michel Meyers (michel@tcnnet.dyndns.org)
;
; Adapted by Kern Sibbald for native Win32 Bacula
;    added a number of elements from Christopher Hull's installer
;
; D. Scott Barninger Nov 13 2004
; added configuration editing for bconsole.conf and wx-console.conf
; better explanation in dialog boxes for editing config files
; added Start Menu items
; fix uninstall of config files to do all not just bacula-fd.conf
;
; D. Scott Barninger Dec 05 2004
; added specification of default permissions for bacula-fd.conf
;   - thanks to Jamie Ffolliott for pointing me at cacls
; added removal of working-dir files if user selects to remove config
; uninstall is now 100% clean
;
; D. Scott Barninger Apr 17 2005
; 1.36.3 release docs update
; add pdf manual and menu shortcut
;
; Robert Nelson May 15 2006
; Pretty much rewritten
; Use LogicLib.nsh
; Added Bacula-SD and Bacula-DIR
; Replaced ParameterGiven with standard GetOptions

;
; Command line options:
;
; /cygwin     -  do cygwin install into c:\cygwin\bacula
; /service    - 
; /start

!define PRODUCT "Bacula"
!define BUILD_TOOLS "MinGW"

;
; Include the Modern UI
;
!include "MUI.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"

;
; Basics
;
  Name "Bacula"
  OutFile "winbacula-${VERSION}.exe"
  SetCompressor lzma
  InstallDir "$PROGRAMFILES\Bacula"
  InstallDirRegKey HKLM Software\Bacula InstallLocation

  InstType "Client"
  InstType "Server"
  InstType "Full"

;
; Pull in pages
;

 !insertmacro MUI_PAGE_WELCOME
;  !insertmacro MUI_PAGE_LICENSE "..\..\LICENSE"
 !insertmacro MUI_PAGE_COMPONENTS
 !insertmacro MUI_PAGE_DIRECTORY
 Page custom EnterClientConfig LeaveClientConfig
 Page custom EnterOptions
 !insertmacro MUI_PAGE_INSTFILES
 !insertmacro MUI_PAGE_FINISH

 !insertmacro MUI_UNPAGE_WELCOME
 !insertmacro MUI_UNPAGE_CONFIRM
 !insertmacro MUI_UNPAGE_INSTFILES
 !insertmacro MUI_UNPAGE_FINISH

 !define      MUI_ABORTWARNING

 !insertmacro MUI_LANGUAGE "English"

 !insertmacro GetParameters
 !insertmacro GetOptions

DirText "Setup will install Bacula ${VERSION} to the directory specified below. To install in a different folder, click Browse and select another folder.$\n$\nNote to CYGWIN users: please choose your CYGWIN root directory."

;
; Reserve Files
;
 ReserveFile "ClientConfig.ini"
 !insertmacro MUI_RESERVEFILE_INSTALLOPTIONS
;
; Global Variables
;
Var OptCygwin
Var OptService
Var OptStart
Var OptSilent

Var DependenciesDone
Var DatabaseDone

Var OsIsNT

Var ConfigClientName
Var ConfigClientPort
Var ConfigMaxJobs
Var ConfigDirectorName
Var ConfigDirectorPW
Var ConfigMonitorName
Var ConfigMonitorPW

Var OptionsClientService
Var OptionsClientStart
Var OptionsStorageService
Var OptionsStorageStart
Var OptionsDirectorService
Var OptionsDirectorStart
Var OptionsDirectorDB

Var HDLG
Var HCTL

Function .onInit
  Push $R0
  Push $R1
  
  ; Process Command Line Options
  StrCpy $OptCygwin 0
  StrCpy $OptService 0
  StrCpy $OptStart 0
  StrCpy $OptSilent 0
  StrCpy $DependenciesDone 0
  StrCpy $DatabaseDone 0
  StrCpy $OsIsNT 0
  
  ${GetParameters} $R0
  
  ClearErrors
  ${GetOptions} $R0 "/cygwin" $R1
  IfErrors +2
    StrCpy $OptCygwin 1
  
  ClearErrors
  ${GetOptions} $R0 "/service" $R1
  IfErrors +2
    StrCpy $OptService 1

  ClearErrors
  ${GetOptions} $R0 "/start" $R1
  IfErrors +2
    StrCpy $OptStart 1

  IfSilent 0 +2
    StrCpy $OptSilent 1
    
  ${If} $OptCygwin = 1
    StrCpy $INSTDIR "C:\cygwin\bacula"
  ${EndIf}

  ReadRegStr $R0 HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion" CurrentVersion
  ${If} $R0 != ""
    StrCpy $OsIsNT 1
  ${EndIf}

  !insertmacro MUI_INSTALLOPTIONS_EXTRACT "ClientConfig.ini"
  
  Pop $R1
  Pop $R0
FunctionEnd

Function CopyDependencies
  SetOutPath "$INSTDIR\bin"

  ${If} $DependenciesDone = 0
!if "${BUILD_TOOLS}" == "VC8"
    File "${VC_REDIST_DIR}\msvcm80.dll"
    File "${VC_REDIST_DIR}\msvcp80.dll"
    File "${VC_REDIST_DIR}\msvcr80.dll"
    File "${VC_REDIST_DIR}\Microsoft.VC80.CRT.manifest"
!endif
!if "${BUILD_TOOLS}" == "MinGW"
    File "${MINGW_BIN}\..\mingw32\bin\mingwm10.dll"
!endif
    File "libeay32.dll"
    File "pthreadGCE.dll"
    File "ssleay32.dll"
    File "zlib1.dll"
    File "openssl.exe"
    File "bacula.dll"
    StrCpy $DependenciesDone 1
  ${EndIf}
FunctionEnd

Function InstallDatabase
  ${If} $DatabaseDone = 0
    ${If} $OptionsDirectorDB = 1
      File /oname=bacula_cats.dll "cats_mysql.dll"
      File "libmysql.dll"
    ${ElseIf} $OptionsDirectorDB = 2
      File /oname=bacula_cats.dll "cats_pgsql.dll"
      File "libpq.dll"
!if "${BUILD_TOOLS}" == "VC8"
      File "comerr32.dll"
      File "libintl-2.dll"
      File "libiconv-2.dll"
      File "krb5_32.dll"
!endif
    ${ElseIf} $OptionsDirectorDB = 3
      File /oname=bacula_cats.dll "cats_bdb.dll"
    ${EndIf}

    StrCpy $DatabaseDone 1
  ${EndIf}
FunctionEnd

Section "-Initialize"
  ; Create Start Menu Directory

  WriteRegStr HKLM Software\Bacula InstallLocation "$INSTDIR"

  SetShellVarContext all
  CreateDirectory "$SMPROGRAMS\Bacula"

  CreateDirectory "$INSTDIR"
  CreateDirectory "$INSTDIR\bin"
  CreateDirectory "$APPDATA\Bacula"

  File "..\..\..\LICENSE"
  Delete /REBOOTOK "$INSTDIR\bin\License.txt"
SectionEnd

SectionGroup "Client"

Section "File Service" SecFileDaemon
  SectionIn 1 2 3

  SetOutPath "$INSTDIR\bin"
  File "bacula-fd.exe"

  StrCpy $R0 0
  StrCpy $R1 "$APPDATA\Bacula\bacula-fd.conf"
  IfFileExists $R1 0 +3
    StrCpy $R0 1
    StrCpy $R1 "$R1.new"
    
  File /oname=$R1 ..\filed\bacula-fd.conf.in
  
  ${If} $OptSilent <> 1
  ${AndIf} $R0 <> 1
    MessageBox MB_OK \
        "Please edit the configuration file $R1 to fit your installation. When you click the OK button Wordpad will open to allow you to do this. Be sure to save your changes before closing Wordpad."
    Exec 'write "$R1"'  ; spawn wordpad with the file to be edited
  ${EndIf}
  ${If} $OsIsNT = 1
    ExecWait 'cmd.exe /C echo Y|cacls "$R1" /G SYSTEM:F Administrators:F'
  ${EndIf}

  StrCpy $0 bacula-fd
  StrCpy $1 "File Service"
  StrCpy $2 $OptionsClientService
  StrCpy $3 $OptionsClientStart
  
  Call InstallDaemon

  CreateShortCut "$SMPROGRAMS\Bacula\Edit Client Configuration.lnk" "write.exe" '"$APPDATA\Bacula\bacula-fd.conf"'
SectionEnd

SectionGroupEnd

SectionGroup "Server"

Section "Storage Service" SecStorageDaemon
  SectionIn 2 3
  
  SetOutPath "$INSTDIR\bin"
  Call InstallDatabase
  File "loaderinfo.exe"
  File "mt.exe"
  File "mtx.exe"
  File "scsitape.exe"
  File "tapeinfo.exe"
  File "bacula-sd.exe"
  File "bcopy.exe"
  File "bextract.exe"
  File "bls.exe"
  File "bscan.exe"
  File "btape.exe"
  File ..\scripts\mtx-changer.cmd

  StrCpy $R0 0
  StrCpy $R1 "$APPDATA\Bacula\bacula-sd.conf"
  IfFileExists $R1 0 +3
    StrCpy $R0 1
    StrCpy $R1 "$R1.new"
    
  File /oname=$R1 "..\..\stored\bacula-sd.conf.in"
  
  ${If} $OptSilent <> 1
  ${AndIf} $R0 <> 1
    MessageBox MB_OK \
        "Please edit the configuration file $R1 to fit your installation. When you click the OK button Wordpad will open to allow you to do this. Be sure to save your changes before closing Wordpad."
    Exec 'write "$R1"'  ; spawn wordpad with the file to be edited
  ${EndIf}
  ${If} $OsIsNT = 1
    ExecWait 'cmd.exe /C echo Y|cacls "$R1" /G SYSTEM:F Administrators:F'
  ${EndIf}

  StrCpy $0 bacula-sd
  StrCpy $1 "Storage Service"
  StrCpy $2 $OptionsStorageService
  StrCpy $3 $OptionsStorageStart
  Call InstallDaemon

  CreateShortCut "$SMPROGRAMS\Bacula\Edit Storage Configuration.lnk" "write.exe" '"$APPDATA\Bacula\bacula-sd.conf"'
SectionEnd

Section "Director Service" SecDirectorDaemon
  SectionIn 2 3

  SetOutPath "$INSTDIR\bin"
  Call InstallDatabase
  File "bacula-dir.exe"
  File "dbcheck.exe"

  ${If} $OptionsDirectorDB = 1
    File /oname=create_database.cmd ..\cats\create_mysql_database.cmd
    File /oname=drop_database.cmd ..\cats\drop_mysql_database.cmd
    File /oname=make_tables.cmd ..\cats\make_mysql_tables.cmd
    File ..\cats\make_mysql_tables.sql
    File /oname=drop_tables.cmd ..\cats\drop_mysql_tables.cmd
    File ..\cats\drop_mysql_tables.sql
    File /oname=update_tables.cmd ..\cats\update_mysql_tables.cmd
    File ..\cats\update_mysql_tables.sql
    File /oname=grant_privileges.cmd ..\cats\grant_mysql_privileges.cmd
    File ..\cats\grant_mysql_privileges.sql
  ${ElseIf} $OptionsDirectorDB = 2
    File /oname=create_database.cmd ..\cats\create_postgresql_database.cmd
    File /oname=drop_database.cmd ..\cats\drop_postgresql_database.cmd
    File /oname=make_tables.cmd ..\cats\make_postgresql_tables.cmd
    File ..\cats\make_postgresql_tables.sql
    File /oname=drop_tables.cmd ..\cats\drop_postgresql_tables.cmd
    File ..\cats\drop_postgresql_tables.sql
    File /oname=update_tables.cmd ..\cats\update_postgresql_tables.cmd
    File ..\cats\update_postgresql_tables.sql
    File /oname=grant_privileges.cmd ..\cats\grant_postgresql_privileges.cmd
    File ..\cats\grant_postgresql_privileges.sql
  ${ElseIf} $OptionsDirectorDB = 3
    File /oname=create_database.cmd ../cats/create_bdb_database.cmd
    File /oname=drop_database.cmd ../cats/drop_bdb_database.cmd
    File /oname=make_tables.cmd ../cats/make_bdb_tables.cmd
    File /oname=drop_tables.cmd ../cats/drop_bdb_tables.cmd
    File /oname=update_tables.cmd ../cats/update_bdb_tables.cmd
    File /oname=grant_privileges.cmd ../cats/grant_bdb_privileges.cmd
  ${EndIf}
  File ..\cats\make_catalog_backup.cmd
  File ..\cats\delete_catalog_backup.cmd

  StrCpy $R0 0
  StrCpy $R1 "$APPDATA\Bacula\bacula-dir.conf"
  IfFileExists $R1 0 +3
    StrCpy $R0 1
    StrCpy $R1 "$R1.new"
    
  File /oname=$R1 "..\..\dird\bacula-dir.conf.in"
  
  ${If} $OptSilent <> 1
  ${AndIf} $R0 <> 1
    MessageBox MB_OK \
        "Please edit the configuration file $R1 to fit your installation. When you click the OK button Wordpad will open to allow you to do this. Be sure to save your changes before closing Wordpad."
    Exec 'write "$R1"'  ; spawn wordpad with the file to be edited
  ${EndIf}
  ${If} $OsIsNT = 1
    ExecWait 'cmd.exe /C echo Y|cacls "$R1" /G SYSTEM:F Administrators:F'
  ${EndIf}

  StrCpy $0 bacula-dir
  StrCpy $1 "Director Service"
  StrCpy $2 $OptionsDirectorService
  StrCpy $3 $OptionsDirectorStart
  Call InstallDaemon

  CreateShortCut "$SMPROGRAMS\Bacula\Edit Director Configuration.lnk" "write.exe" '"$APPDATA\Bacula\bacula-dir.conf"'
SectionEnd

SectionGroupEnd

SectionGroup "Consoles"

Section "Command Console" SecConsole
  SectionIn 3

  File "bconsole.exe"
  Call CopyDependencies

  StrCpy $R0 0
  StrCpy $R1 "$APPDATA\Bacula\bconsole.conf"
  IfFileExists $R1 0 +3
    StrCpy $R0 1
    StrCpy $R1 "$R1.new"
    
  File /oname=$R1 "..\..\console\bconsole.conf.in"
  
  ${If} $OptSilent <> 1
  ${AndIf} $R0 <> 1
    MessageBox MB_OK \
        "Please edit the configuration file $R1 to fit your installation. When you click the OK button Wordpad will open to allow you to do this. Be sure to save your changes before closing Wordpad."
    Exec 'write "$R1"'  ; spawn wordpad with the file to be edited
  ${EndIf}
  ${If} $OsIsNT = 1
    ExecWait 'cmd.exe /C echo Y|cacls "$R1" /G SYSTEM:F Administrators:F'
  ${EndIf}

  CreateShortCut "$SMPROGRAMS\Bacula\Edit Command Console Configuration.lnk" "write.exe" '"$APPDATA\Bacula\bconsole.conf"'

SectionEnd

Section "Graphical Console" SecWxConsole
  SectionIn 1 2 3
  
  Call CopyDependencies
  File "wxbase26_gcc_bacula.dll"
  File "wxmsw26_core_gcc_bacula.dll"
  File "wx-console.exe"

  StrCpy $R0 0
  StrCpy $R1 "$APPDATA\Bacula\wx-console.conf"
  IfFileExists $R1 0 +3
    StrCpy $R0 1
    StrCpy $R1 "$R1.new"
    
  File /oname=$R1 "..\..\wx-console\wx-console.conf.in"
  
  ${If} $OptSilent <> 1
  ${AndIf} $R0 <> 1
    MessageBox MB_OK \
        "Please edit the configuration file $R1 to fit your installation. When you click the OK button Wordpad will open to allow you to do this. Be sure to save your changes before closing Wordpad."
    Exec 'write "$R1"'  ; spawn wordpad with the file to be edited
  ${EndIf}
  ${If} $OsIsNT = 1
    ExecWait 'cmd.exe /C echo Y|cacls "$R1" /G SYSTEM:F Administrators:F'
  ${EndIf}

  ; Create Start Menu entry
  CreateShortCut "$SMPROGRAMS\Bacula\Console.lnk" "$INSTDIR\bin\wx-console.exe" '-c "$APPDATA\Bacula\wx-console.conf"' "$INSTDIR\bin\wx-console.exe" 0
  CreateShortCut "$SMPROGRAMS\Bacula\Edit Graphical Console Configuration.lnk" "write.exe" '"$APPDATA\Bacula\wx-console.conf"'
SectionEnd

SectionGroupEnd

SectionGroup "Documentation"

Section "Documentation (Acrobat Format)" SecDocPdf
  SectionIn 1 2 3

  SetOutPath "$INSTDIR\doc"
  CreateDirectory "$INSTDIR\doc"
  File "${DOCDIR}\manual\bacula.pdf"
  CreateShortCut "$SMPROGRAMS\Bacula\Manual.lnk" '"$INSTDIR\doc\bacula.pdf"'
SectionEnd

Section "Documentation (HTML Format)" SecDocHtml
  SectionIn 3

  SetOutPath "$INSTDIR\doc"
  CreateDirectory "$INSTDIR\doc"
  File "${DOCDIR}\manual\bacula\*.html"
  File "${DOCDIR}\manual\bacula\*.png"
  File "${DOCDIR}\manual\bacula\*.css"
  CreateShortCut "$SMPROGRAMS\Bacula\Manual (HTML).lnk" '"$INSTDIR\doc\bacula.html"'
SectionEnd

SectionGroupEnd

Section "-Write Installer"
  ; Write the uninstall keys for Windows & create Start Menu entry
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Bacula" "DisplayName" "Bacula"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Bacula" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateShortCut "$SMPROGRAMS\Bacula\Uninstall Bacula.lnk" "$INSTDIR\Uninstall.exe" "" "$INSTDIR\Uninstall.exe" 0
SectionEnd

;
; Extra Page descriptions
;

  LangString DESC_SecFileDaemon ${LANG_ENGLISH} "Install Bacula File Daemon on this system."
  LangString DESC_SecStorageDaemon ${LANG_ENGLISH} "Install Bacula Storage Daemon on this system."
  LangString DESC_SecDirectorDaemon ${LANG_ENGLISH} "Install Bacula Director Daemon on this system."
  LangString DESC_SecConsole ${LANG_ENGLISH} "Install command console program on this system."
  LangString DESC_SecWxConsole ${LANG_ENGLISH} "Install graphical console program on this system."
  LangString DESC_SecDocPdf ${LANG_ENGLISH} "Install documentation in Acrobat format on this system."
  LangString DESC_SecDocHtml ${LANG_ENGLISH} "Install documentation in HTML format on this system."

  LangString TITLE_ClientConfig ${LANG_ENGLISH} "Configure Client"
  LangString SUBTITLE_ClientConfig ${LANG_ENGLISH} "Create initial configuration for Client."

  LangString TITLE_Options ${LANG_ENGLISH} "Options"
  LangString SUBTITLE_Options ${LANG_ENGLISH} "Set installation options."

  !insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${SecFileDaemon} $(DESC_SecFileDaemon)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecStorageDaemon} $(DESC_SecStorageDaemon)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecDirectorDaemon} $(DESC_SecDirectorDaemon)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecConsole} $(DESC_SecConsole)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecWxConsole} $(DESC_SecWxConsole)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecDocPdf} $(DESC_SecDocPdf)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecDocHtml} $(DESC_SecDocHtml)
  !insertmacro MUI_FUNCTION_DESCRIPTION_END

; Uninstall section

UninstallText "This will uninstall Bacula. Hit next to continue."

Section "Uninstall"
  ; Shutdown any baculum that could be running
  ExecWait '"$INSTDIR\bin\bacula-fd.exe" /kill'
  ExecWait '"$INSTDIR\bin\bacula-sd.exe" /kill'
  ExecWait '"$INSTDIR\bin\bacula-dir.exe" /kill'

  ReadRegDWORD $R0 HKLM "Software\Bacula" "Installed_Bacula-fd"
  ${If} $R0 = 1
    ; Remove bacula service
    ExecWait '"$INSTDIR\bin\bacula-fd.exe" /remove'
  ${EndIf}
  
  ReadRegDWORD $R0 HKLM "Software\Bacula" "Installed_Bacula-sd"
  ${If} $R0 = 1
    ; Remove bacula service
    ExecWait '"$INSTDIR\bin\bacula-sd.exe" /remove'
  ${EndIf}
  
  ReadRegDWORD $R0 HKLM "Software\Bacula" "Installed_Bacula-dir"
  ${If} $R0 = 1
    ; Remove bacula service
    ExecWait '"$INSTDIR\bin\bacula-dir.exe" /remove'
  ${EndIf}
  
  ; remove registry keys
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Bacula"
  DeleteRegKey HKLM "Software\Bacula"

  ; remove start menu items
  SetShellVarContext all
  Delete /REBOOTOK "$SMPROGRAMS\Bacula\*"
  RMDir "$SMPROGRAMS\Bacula"

  ; remove files and uninstaller (preserving config for now)
  Delete /REBOOTOK "$INSTDIR\bin\*.*"
  Delete /REBOOTOK "$INSTDIR\doc\*.*"
  Delete /REBOOTOK "$INSTDIR\Uninstall.exe"

  ; Check for existing installation
  MessageBox MB_YESNO|MB_ICONQUESTION \
  "Would you like to delete the current configuration files and the working state file?" IDNO +3
    Delete /REBOOTOK "$APPDATA\Bacula\*"
    RMDir "$APPDATA\Bacula"

  ; remove directories used
  RMDir "$INSTDIR\bin"
  RMDir "$INSTDIR\doc"
  RMDir "$INSTDIR"
SectionEnd

Function EnterClientConfig
  SectionGetFlags ${SecFileDaemon} $R0
  IntOp $R0 $R0 & 1
  
  SectionGetFlags ${SecStorageDaemon} $R1
  IntOp $R1 $R1 & 1
  
  SectionGetFlags ${SecDirectorDaemon} $R2
  IntOp $R2 $R2 & 1
  
  ${If} $R0 = 0
  ${OrIf} $R1 = 1
  ${OrIf} $R2 = 1
    Abort
  ${EndIf}
  
  !insertmacro MUI_HEADER_TEXT "$(TITLE_ClientConfig)" "$(SUBTITLE_ClientConfig)"
  !insertmacro MUI_INSTALLOPTIONS_INITDIALOG "ClientConfig.ini"
  Pop $HDLG ;HWND of dialog

  ; Initialize Controls
  ; Client Name
  !insertmacro MUI_INSTALLOPTIONS_READ $HCTL "ClientConfig.ini" "Field 3" "HWND"
  SendMessage $HCTL ${EM_LIMITTEXT} 30 0
  
  ; Client Port Number
  !insertmacro MUI_INSTALLOPTIONS_READ $HCTL "ClientConfig.ini" "Field 6" "HWND"
  SendMessage $HCTL ${EM_LIMITTEXT} 5 0
  SendMessage $HCTL ${WM_SETTEXT} 0 "STR:9102"

  ; Max Jobs
  !insertmacro MUI_INSTALLOPTIONS_READ $HCTL "ClientConfig.ini" "Field 8" "HWND"
  SendMessage $HCTL ${EM_LIMITTEXT} 2 0
  SendMessage $HCTL ${WM_SETTEXT} 0 "STR:20"

  ; Director Name
  !insertmacro MUI_INSTALLOPTIONS_READ $HCTL "ClientConfig.ini" "Field 11" "HWND"
  SendMessage $HCTL ${EM_LIMITTEXT} 30 0

  ; Director Password
  !insertmacro MUI_INSTALLOPTIONS_READ $HCTL "ClientConfig.ini" "Field 14" "HWND"
  SendMessage $HCTL ${EM_LIMITTEXT} 60 0

  ; Monitor Name
  !insertmacro MUI_INSTALLOPTIONS_READ $HCTL "ClientConfig.ini" "Field 17" "HWND"
  SendMessage $HCTL ${EM_LIMITTEXT} 30 0

  ; Monitor Password
  !insertmacro MUI_INSTALLOPTIONS_READ $HCTL "ClientConfig.ini" "Field 20" "HWND"
  SendMessage $HCTL ${EM_LIMITTEXT} 60 0

  !insertmacro MUI_INSTALLOPTIONS_SHOW
  
  ;
  ; Process results
  ;
  ; Client Name
  !insertmacro MUI_INSTALLOPTIONS_READ $ConfigClientName "ClientConfig.ini" "Field 3" "State"
  ; Client Port Number
  !insertmacro MUI_INSTALLOPTIONS_READ $ConfigClientPort "ClientConfig.ini" "Field 6" "State"
  ; Max Jobs
  !insertmacro MUI_INSTALLOPTIONS_READ $ConfigMaxJobs "ClientConfig.ini" "Field 8" "State"

  ; Director Name
  !insertmacro MUI_INSTALLOPTIONS_READ $ConfigDirectorName "ClientConfig.ini" "Field 11" "State"
  ; Director Password
  !insertmacro MUI_INSTALLOPTIONS_READ $ConfigDirectorPW "ClientConfig.ini" "Field 14" "State"

  ; Monitor Name
  !insertmacro MUI_INSTALLOPTIONS_READ $ConfigMonitorName "ClientConfig.ini" "Field 17" "State"
  ; Monitor Password
  !insertmacro MUI_INSTALLOPTIONS_READ $ConfigMonitorPW "ClientConfig.ini" "Field 20" "State"
FunctionEnd

Function LeaveClientConfig
  ; Client Port Number
  !insertmacro MUI_INSTALLOPTIONS_READ $R0 "ClientConfig.ini" "Field 6" "State"
  ${If} $R0 < 1024
  ${OrIf} $R0 > 65535
    MessageBox MB_OK "Port must be between 1024 and 65535 inclusive."
    Abort
  ${EndIf}
  
  ; Max Jobs
  !insertmacro MUI_INSTALLOPTIONS_READ $R0 "ClientConfig.ini" "Field 8" "State"
  ${If} $R0 < 1
  ${OrIf} $R0 > 99
    MessageBox MB_OK "Max Jobs must be between 1 and 99 inclusive."
    Abort
  ${EndIf}
FunctionEnd

Function EnterOptions
  SectionGetFlags ${SecFileDaemon} $R0
  IntOp $R0 $R0 & 1
  
  SectionGetFlags ${SecStorageDaemon} $R1
  IntOp $R1 $R1 & 1
  
  SectionGetFlags ${SecDirectorDaemon} $R2
  IntOp $R2 $R2 & 1
  
  ${If} $R0 = 0
  ${AndIf} $R1 = 0
  ${AndIf} $R2 = 0
    Abort
  ${EndIf}
  
  FileOpen $R3 "$PLUGINSDIR\options.ini" w

  StrCpy $R4 1  ; Field Number
  StrCpy $R5 0  ; Top
  
  ${If} $R0 = 1
    IntOp $R6 $R5 + 34

    FileWrite $R3 '[Field $R4]$\r$\n'
    FileWrite $R3 'Type="GroupBox"$\r$\nText="Client"$\r$\nLeft=0$\r$\nTop=$R5$\r$\nRight=300$\r$\nBottom=$R6$\r$\n'

    IntOp $R4 $R4 + 1
    IntOp $R5 $R5 + 8
    IntOp $R6 $R5 + 12

    FileWrite $R3 '[Field $R4]$\r$\nType="Checkbox"$\r$\nState=$OptService$\r$\nText="Install as service"$\r$\nLeft=6$\r$\nTop=$R5$\r$\nRight=280$\r$\nBottom=$R6$\r$\n'

    IntOp $R4 $R4 + 1
    StrCpy $R5 $R6
    IntOp $R6 $R5 + 12

    FileWrite $R3 '[Field $R4]$\r$\nType="Checkbox"$\r$\nState=$OptStart$\r$\nText="Start after install"$\r$\nLeft=6$\r$\nTop=$R5$\r$\nRight=280$\r$\nBottom=$R6$\r$\n'

    IntOp $R4 $R4 + 1
    IntOp $R5 $R6 + 8
  ${Endif}
  
  ${If} $R1 = 1
    IntOp $R6 $R5 + 34 

    FileWrite $R3 '[Field $R4]$\r$\n'
    FileWrite $R3 'Type="GroupBox"$\r$\nText="Storage"$\r$\nLeft=0$\r$\nTop=$R5$\r$\nRight=300$\r$\nBottom=$R6$\r$\n'

    IntOp $R4 $R4 + 1
    IntOp $R5 $R5 + 8
    IntOp $R6 $R5 + 12

    FileWrite $R3 '[Field $R4]$\r$\nType="Checkbox"$\r$\nState=$OptService$\r$\nText="Install as service"$\r$\nLeft=6$\r$\nTop=$R5$\r$\nRight=280$\r$\nBottom=$R6$\r$\n'

    IntOp $R4 $R4 + 1
    StrCpy $R5 $R6
    IntOp $R6 $R5 + 12

    FileWrite $R3 '[Field $R4]$\r$\nType="Checkbox"$\r$\nState=$OptStart$\r$\nText="Start after install"$\r$\nLeft=6$\r$\nTop=$R5$\r$\nRight=280$\r$\nBottom=$R6$\r$\n'

    IntOp $R4 $R4 + 1
    IntOp $R5 $R6 + 8
  ${Endif}
  
  ${If} $R2 = 1
    IntOp $R6 $R5 + 46

    FileWrite $R3 '[Field $R4]$\r$\n'
    FileWrite $R3 'Type="GroupBox"$\r$\nText="Director"$\r$\nLeft=0$\r$\nTop=$R5$\r$\nRight=300$\r$\nBottom=$R6$\r$\n'

    IntOp $R4 $R4 + 1
    IntOp $R5 $R5 + 8
    IntOp $R6 $R5 + 12

    FileWrite $R3 '[Field $R4]$\r$\nType="Checkbox"$\r$\nState=$OptService$\r$\nText="Install as service"$\r$\nLeft=6$\r$\nTop=$R5$\r$\nRight=280$\r$\nBottom=$R6$\r$\n'

    IntOp $R4 $R4 + 1
    StrCpy $R5 $R6
    IntOp $R6 $R5 + 12

    FileWrite $R3 '[Field $R4]$\r$\nType="Checkbox"$\r$\nState=$OptStart$\r$\nText="Start after install"$\r$\nLeft=6$\r$\nTop=$R5$\r$\nRight=280$\r$\nBottom=$R6$\r$\n'

    IntOp $R4 $R4 + 1
    IntOp $R5 $R6 + 8
  ${Endif}
 
  ${If} $R1 = 1
  ${OrIf} $R2 = 1
    IntOp $R4 $R4 + 1
    IntOp $R5 $R6 + 2
    IntOp $R6 $R5 + 8

    FileWrite $R3 '[Field $R4]$\r$\nType="Label"$\r$\nText="Database:"$\r$\nLeft=6$\r$\nTop=$R5$\r$\nRight=46$\r$\nBottom=$R6$\r$\n'

    IntOp $R4 $R4 + 1
    IntOp $R5 $R5 - 2
    IntOp $R6 $R5 + 12

    FileWrite $R3 '[Field $R4]$\r$\nType="RadioButton"$\r$\nState=1$\r$\nText="MySQL"$\r$\nFlags="GROUP"$\r$\nLeft=46$\r$\nTop=$R5$\r$\nRight=86$\r$\nBottom=$R6$\r$\n'

    IntOp $R4 $R4 + 1
    IntOp $R6 $R5 + 12

    FileWrite $R3 '[Field $R4]$\r$\nType="RadioButton"$\r$\nState=0$\r$\nText="PostgreSQL"$\r$\nFlags="NOTABSTOP"$\r$\nLeft=86$\r$\nTop=$R5$\r$\nRight=142$\r$\nBottom=$R6$\r$\n'

    IntOp $R4 $R4 + 1
    IntOp $R6 $R5 + 12

    FileWrite $R3 '[Field $R4]$\r$\nType="RadioButton"$\r$\nState=0$\r$\nText="Builtin"$\r$\nFlags="NOTABSTOP"$\r$\nLeft=142$\r$\nTop=$R5$\r$\nRight=182$\r$\nBottom=$R6$\r$\n'

  ${Endif}

  IntOp $R4 $R4 - 1
    
  FileWrite $R3 "[Settings]$\r$\nNumFields=$R4$\r$\n"
  
  FileClose $R3
   
  !insertmacro MUI_HEADER_TEXT "$(TITLE_Options)" "$(SUBTITLE_Options)"
  !insertmacro MUI_INSTALLOPTIONS_DISPLAY "Options.ini"
  
  ;
  ; Process results
  ;
  StrCpy $R4 2
  
  ${If} $R0 = 1
    ; Client
    !insertmacro MUI_INSTALLOPTIONS_READ $OptionsClientService "Options.ini" "Field $R4" "State"
    IntOp $R4 $R4 + 1
    !insertmacro MUI_INSTALLOPTIONS_READ $OptionsClientStart "Options.ini" "Field $R4" "State"
    IntOp $R4 $R4 + 2
  ${EndIf}
  
  ${If} $R0 = 1
    ; Client
    !insertmacro MUI_INSTALLOPTIONS_READ $OptionsStorageService "Options.ini" "Field $R4" "State"
    IntOp $R4 $R4 + 1
    !insertmacro MUI_INSTALLOPTIONS_READ $OptionsStorageStart "Options.ini" "Field $R4" "State"
    IntOp $R4 $R4 + 2
  ${EndIf}
  
  ${If} $R0 = 1
    ; Client
    !insertmacro MUI_INSTALLOPTIONS_READ $OptionsDirectorService "Options.ini" "Field $R4" "State"
    IntOp $R4 $R4 + 1
    !insertmacro MUI_INSTALLOPTIONS_READ $OptionsDirectorStart "Options.ini" "Field $R4" "State"
    IntOp $R4 $R4 + 2
    !insertmacro MUI_INSTALLOPTIONS_READ $R3 "Options.ini" "Field $R4" "State"
    ${If} $R3 = 1
      StrCpy $OptionsDirectorDB 1
    ${Else}
      IntOp $R4 $R4 + 1
      !insertmacro MUI_INSTALLOPTIONS_READ $R3 "Options.ini" "Field $R4" "State"
      ${If} $R3 = 1
        StrCpy $OptionsDirectorDB 2
      ${Else}
        StrCpy $OptionsDirectorDB 3
      ${Endif}
    ${Endif}
  ${EndIf}
FunctionEnd

;
; $0 - Service Name (ie Bacula-FD)
; $1 - Service Description (ie Bacula File Daemon)
; $2 - Install as Service
; $3 - Start Service now
;
Function InstallDaemon
  Call CopyDependencies

  IfFileExists "$APPDATA\Bacula\$0.conf" 0 +3
    ExecWait '"$INSTDIR\bin\$0.exe" /kill' ; Shutdown any bacula that could be running
    Sleep 3000  ; give it some time to shutdown

  WriteRegDWORD HKLM "Software\Bacula" "Service_$0" $2
  
  ${If} $2 = 1
    ExecWait '"$INSTDIR\bin\$0.exe" /install'

    ${If} $OsIsNT <> 1
      File "Start.bat"
      File "Stop.bat"
    ${EndIf}

    ; Start the service? (default skipped if silent, use /start to force starting)

    ${If} $3 = 1  
      ${If} $OsIsNT = 1
        Exec 'net start bacula'
        Sleep 3000
      ${Else}
        Exec '"$INSTDIR\bin\$0.exe" -c "$APPDATA\Bacula\$0.conf"'
      ${EndIf}
    ${EndIf}
  ${Else}
    CreateShortCut "$SMPROGRAMS\Bacula\Start $1.lnk" "$INSTDIR\bin\$0.exe" '-c "$APPDATA\Bacula\$0.conf"' "$INSTDIR\bin\$0.exe" 0
  ${EndIf}
FunctionEnd
