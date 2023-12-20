REM - this CMD file checks the platform (x86/64) and then runs the correct PS command line


PUSHD %~dp0
If "%PROCESSOR_ARCHITEW6432%"=="AMD64" GOTO 64bit
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -Command ".\StifleR_Client_Installer.ps1 -Defaults .\StifleRDefaults.ini -DebugPreference Continue"
GOTO END
:64bit
"%WinDir%\Sysnative\windowsPowershell\v1.0\Powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command ".\StifleR_Client_Installer.ps1 -Defaults .\StifleRDefaults.ini -DebugPreference Continue"
:END
POPD

