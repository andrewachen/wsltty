@echo off
rem ABOUTME: wsltty ARM64 installer — copies mintty.exe and scripts, configures WSL shortcuts.
rem ABOUTME: Drop-in replacement for install.bat; no Cygwin tools (dash/regtool/zoo) required.

set refinstalldir=%%LOCALAPPDATA%%\wsltty
set refconfigdir=%%APPDATA%%\wsltty
if "%installdir%" == "" set installdir="%LOCALAPPDATA%\wsltty"
if "%configdir%" == "" set configdir="%APPDATA%\wsltty"
call dequote installdir
call dequote configdir

rem override installdir, configdir if parameters given
set arg1=%1
call dequote arg1
if "%arg1%" == "%%arg1%%" goto deploy
set refinstalldir=%arg1%
set installdir=%arg1%
set arg2=%2
call dequote arg2
if "%arg2%" == "%%arg2%%" goto deploy
set refconfigdir=%arg2%
set configdir=%arg2%

:deploy

mkdir "%installdir%" 2> nul:

rem clean up previous installation artefacts
del /Q "%installdir%\*.bat"
del /Q "%installdir%\*.lnk"

copy LICENSE.mintty "%installdir%"

copy config-distros-arm64.ps1 "%installdir%"
copy mkshortcut.vbs "%installdir%"
copy cmd2.bat "%installdir%"
copy dequote.bat "%installdir%"

rem allow persistent customization of default icon:
if not exist "%installdir%\wsl.ico" copy tux.ico "%installdir%\wsl.ico"

copy uninstall.bat "%installdir%"

if not exist "%installdir%\bin" goto instbin
rem move previous programs possibly in use out of the way
del /Q "%installdir%\bin\*.old" 2> nul:
ren "%installdir%\bin\mintty.exe" mintty.exe.old
del /Q "%installdir%\bin\*.old" 2> nul:

:instbin
mkdir "%installdir%\bin" 2> nul:
copy mintty.exe "%installdir%\bin"


rem create Start Menu Folder
set smf="%APPDATA%\Microsoft\Windows\Start Menu\Programs\WSLtty"
call dequote smf
mkdir "%smf%" 2> nul:

rem clean up previous installation
del /Q "%smf%\*.lnk"

copy "wsltty home & help.url" "%smf%"


rem create user config directory
mkdir "%configdir%" 2> nul:

rem create config file if it does not yet exist
if exist "%configdir%\config" goto appconfig
echo # To use common configuration in %%APPDATA%%\mintty, simply remove this file>"%configdir%\config"

:appconfig

rem skip configuration for WSLtty Portable
if "%3" == "/P" goto end

rem configure WSL distribution shortcuts
cd /D "%installdir%"
echo Configuring for WSL distributions
powershell -ExecutionPolicy Bypass -File config-distros-arm64.ps1

:end
