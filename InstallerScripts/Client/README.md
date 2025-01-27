Stifler Client Install script changelog:

    2.1.0.0 : 27/01/2025  : Major rewrite of logic
                                - Changed from sc.exe to PowerShell Native Get-service/.Net method to support localized OS
                                - Added Support for comments in StiflerDefaults.ini
                                - Dynammicaly read settings under the [Config] section of StiflerDefaults.ini
                                - Removed obsolete code
    
    2.0.0.7 : 11/27/2024  : Added support for configuring DefaultNonRedLeaderDOPolicy, DefaultNonRedLeaderBITSPolicy, DefaultDisconnectedDOPolicy, DefaultDisconnectedBITSPolicy Thanks @pc222
    2.0.0.6 : 12/15/2023  : Added custom hook for detecting between production and preproduction environments
    2.0.0.5 : 12/15/2023  : Added support for configuring BranchCache Ports
    2.0.0.4 : 08/09/2023  : Bugfix
    2.0.0.3 : 05/06/2023  : Bugfixes + Removed Install Stifler ETW Logic, handle by installer. 
    2.0.0.2 : 26/10/2022  : Bugfixes + check if the client is installed under C:\Windows\temp during OSD and skip eventlog queries.
    2.0.0.1 : 26/10/2022  : Creates subfolder(s) to logfile if they are missing
    2.0.0.0 : 15/09/2021  : Updated for V2.7 Client Install. Supports upgrade from 2.6.x to 2.7.x
    1.0.2.2 : 06/06/2020  : Added Uninstall option EXAMPLE: .\StifleR_Client_Installer.ps1 -Uninstall 1 -DebugPreference Continue
    1.0.2.1 : 30/05/2020  : Stops if the svc is marked for deletion - checks in 2 places. Only tries to remove logs etc if there is an old version installed
    1.0.2.0 : 27/05/2020  : changed the svc stop to using Net Stop and added a check for the service state, backup the .config file, better error checking for service stop/start
                            Checks for running MSI installs
    1.0.1.5 : 12/05/2020  : Added support for adding new Features via the settings .ini -EnableBetaFeatures (default is false/0)
    1.0.1.4 : 16/04/2020  : Added support for ForceVPN in the settings .ini and app config. Removed -VerbosePreference switch
    1.0.1.3 : 25/01/2020  : Added support for 'VPNStrings' and custom install folder, 
                            now uses defaults.ini for install settings (required on cmd line) new cmd line params -FullDebugMode (true/false) and Debug option
    1.0.1.2 : 26/11/2019  : Enabled MSI logging by default, set default debuglevel to 0, set rules interval to 86400, and added check for elevation
    1.0.1.1 : 25/10/2019  : Minor tweaks to logging
    1.0.1.0 : 11/10/2019  : Discovers the install path and if installed gets values from the .config for data/logs folders etc
    1.0.0.9 : 30/08/2019  : Removed the warning during service stop, cleaned up logging
    1.0.0.8 : 30/08/2019  : Added better MSI error handling and logging. Only exit with 0 if install is a success
    1.0.0.7 : 22/08/2019  : Minor changes to pre-install cleanup
    1.0.0.6 : 21/05/2019  : Removed reg cleanup as that causes duplicate client instances in 2.x client
    1.0.0.5 : 10/12/2018  : Removed local policy check, fixed a couple of bugs, changed order of things
    1.0.0.4 : 02/05/2018  : Included local policy check    
    1.0.0.3 : 28/04/2018  : Added more cleanup & logging                            
    1.0.0.2 : 27/04/2018  : Changed the uninstall detection and execution 
    1.0.0.0 : 22/02/2018  : Initial version of script 