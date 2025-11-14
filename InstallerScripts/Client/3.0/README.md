# StifleR Client Installer Scripts for 3.0

## Overview

The StifleR Client Install Process has been simplified for 3.0 with your settings now living in a config file had you can export from an installed clients.  You then call the Client MSI calling that settings file.

## Create Settings File

The Client Configuration Editor is located here: C:\Program Files\2Pint Software\StifleR Client\TwoPint.ConfigEditor.Wpf\TwoPint.ConfigEditor.Wpf.exe

Once the editor is open, customize the settings for the environment then go to Export -> Create 2PS import file for MSI only, and save it.

![2Pint Config Editor](media/2PintConfigEditor.png)

## Install Commands

Based on your deployment method, the install strings are slightly different.

### DeployR Application

```
msiexec /i StifleR-ClientApp-x64.msi AUTOSTART=1 OPTIONS="%WorkingDir%\settings.2psImport" /quiet /l*v "C:\Windows\Temp\StifleRClientInstall.log"
```
### ConfigMgr Application

```
msiexec /i StifleR-ClientApp-x64.msi AUTOSTART=1 OPTIONS="%~dp0settings.2psImport" /quiet /l*v "C:\Windows\Temp\StifleRClientInstall.log"
```

## Source Folder

The source folder for the StifleR Client installer will contain the client MSI, the client settings file, and install.cmd file with the install string.

![2Pint Config Editor](media/SourceContentFolder.png)

## Finishing Up

Now upload into your Deployment System.  Depending on what you're using, a detection method might also be required.  For ConfigMgr, MSI code works well, similar for Intune.