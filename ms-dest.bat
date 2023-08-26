@REM The MS-DEST (Microsft DHCP Discovery Engine Setup Tool) takes care of most of the setup work
@REM regarding setting up the copy task into the Gateway server.
@REM It generates RSA keys, sets up the environment, transfers keys to GW, and schedules the task
@REM Author: roycoh@checkpoint.com

@echo off
@REM Note that all variables we set here are local, they stop existing after the corresponding 'endlocal'
setlocal
@REM Make sure we're in the C: drive. Important when script is opened from a flash drive / CD
c:

echo CheckPoint Technologies Ltd. - Quantum IoT
echo MS-DHCP Discovery Engine Setup Tool
echo(

@REM =======================================================
@REM                    Initial check-ups
@REM =======================================================

@REM Check if program has administrator privileges by running an admin-only command
fsutil dirty query %systemdrive% >nul
if %errorLevel% NEQ 0 (
    echo This setup tool must be run as Administrator.
    echo Please make sure to right click the file ^> "Run as Administrator".
    goto exit
)
echo(

@REM Check if SSH is installed
@REM where: prints location of command, and returns non-zero if not found
where ssh >nul 2>&1
if %errorLevel% == 0 goto modeSelect

@REM Situation: SSH not installed
echo SSH couldn't be found on this machine.
set /p "ShouldInstallSSH=Install SSH automatically (y/n)? "
if /i "%ShouldInstallSSH%" == "y" goto InstallSSH
if /i "%ShouldInstallSSH%" == "Y" goto InstallSSH





@REM =======================================================
@REM                 Automatic SSH installer
@REM =======================================================

@REM Situation: SSH not installed and client chose not to install automatically
echo(
echo SSH is required to proceed with the installation.
echo Please install SSH manually or choose to install automatically.
echo After that, re-run the script.
goto exit

:installSSH
@REM Situation: SSH not installed and client chose to install automatically
@REM First of all, to install SSH we need to run a powershell webrequest (wget).
@REM Invoke-WebRequest exists only in PowerShell 3.0+, which by default comes with Windows Server 2012
echo(

:installSSH_checkPowershellExists
@REM Make sure powershell is installed in the first place
echo -- Making sure machine is compatible...
where powershell >nul 2>&1
if %errorLevel% NEQ 0 (
    echo PowerShell could not be found on this machine!
    echo It's only necessary for automatically installing SSH.
    echo You may install PowerShell version 3.0 or higher, or install OpenSSH and re-run this tool.
    goto exit
)

:installSSH_checkWgetExists
@REM Make sure Invoke-WebRequest exists (meaning powershell is version 3.0 or above)
powershell Get-Command Invoke-WebRequest -errorAction SilentlyContinue >nul 2>&1
if %errorLevel% NEQ 0 (
    echo PowerShell version not supported.
    echo Please install PowerShell version 3.0 or higher, and re-run the installer.
    goto exit
)
echo -- Auto-installer supported
echo( 

:installSSH_downloadInstalller
echo -- Downloading SSH installer...
@REM This enables TLSv1.1 and TLSv1.2, which can by default be disabled.
@REM This is required in order to communicate with modern secure websites.
@REM Then, it fetches a file from an OpenSSH for windows github release.
powershell "[Net.ServicePointManager]::SecurityProtocol = 'Tls, Tls11, Tls12, Ssl3'; Invoke-WebRequest -outFile C:/Users/%USERNAME%/openSSHInstaller.msi https://github.com/PowerShell/Win32-OpenSSH/releases/download/v9.2.2.0p1-Beta/OpenSSH-Win64-v9.2.2.0.msi"
@REM Check if error occurred during download
if %errorLevel% == 0 goto installSSH_downloadSuccessful

:installSSH_downloadFailed
echo Error during download.
set /p "IsConnected=Are you sure you're connected to the internet (y/n)? "
if /i "%IsConnected%" == "y" goto installSSH_downloadFailed_internetOn
if /i "%IsConnected%" == "Y" goto installSSH_downloadFailed_internetOn

:installSSH_downloadFailed_internetOff
echo An internet connection must be present to automatically download SSH.
echo Please connect to the internet, and re-run this tool.
goto exit

:installSSH_downloadFailed_internetOn
@REM Situation: Download failed and internet works. The URL might be faulty.
@REM This is likely to NEVER happen.
echo Please download OpenSSH manually and continue the installation.
goto exit

:installSSH_downloadSuccessful
@REM Once the download is done, we need to run the .msi file.
@REM It automatically installs SSH and adds it to the path.
echo -- Download successful
echo -- Running SSH installer...
C:/Users/%USERNAME%/openSSHInstaller.msi
cd C:/Users/%USERNAME%
del openSSHInstaller.msi 2>nul
echo -- SSH installation complete
echo(
echo Please re-log into your system, and re-open this tool to refresh.
goto exit








@REM =======================================================
@REM                       Mode select
@REM =======================================================

@REM Mode select between installing, uninstalling or changing IP
:modeSelect
echo You can choose a mode to run, or quit.
echo 1^) Install Dicovery Engine
echo 2^) Update Gateway IP
echo 3^) Uninstall Discovery Engine
echo 4^) Close tool
echo(

:modeSelect_prompt
set /p "SelectedMode=Select a mode (1-4): "
if /i "%SelectedMode%" == "1" goto installMode
if /i "%SelectedMode%" == "2" goto updateIPMode
if /i "%SelectedMode%" == "3" goto uninstallMode
if /i "%SelectedMode%" == "4" goto instantExit

@REM Situation: User picked a non-existent mode. Re-display mode select
echo Please select a valid mode number ^(1-4^).
echo(
goto modeSelect_prompt








@REM =======================================================
@REM                       Install mode
@REM =======================================================

:installMode
echo Installing discovery engine
echo(

:instmode_enterIP
set /p "IP=Enter Gateway server's IP: "
echo Please make sure the IP is correct by navigating to
echo https://%IP%/
set /p "IPConfirm=Did the GAiA login page show up (y/n)? "
if /i "%IPConfirm%" == "y" goto instmode_enterIP_IPCorrect
if /i "%IPConfirm%" == "Y" goto instmode_enterIP_IPCorrect

:instmode_enterIP_IPWrong
echo Make sure the Gateway server is up and configured, or try inputting the
echo correct IP address.
goto instmode_enterIP

:instmode_enterIP_IPCorrect
echo(
echo -- Setting up discovery engine for server %IP%

:instmode_generateRSA
echo -- Generating RSA key pair...
cd C:/Users/%USERNAME%/
mkdir .cp-ssh 2>nul
cd .cp-ssh
del id_rsa id_rsa.pub 2>nul
ssh-keygen -t rsa -b 3072 -N "" -q -f id_rsa

@REM Generate a "Read me!" file
:instmode_generateReadme
echo -- Generating readme...
cd C:/Users/%USERNAME%/.cp-ssh
echo Do not delete this folder! > "Read me first!.txt"
echo It's necessary for Checkpoint's MS-DHCP discovery engine to properly function. >> "Read me first!.txt"
echo( >> "Read me first!.txt"
echo If you want to properly uninstall the MS-DHCP discovery engine, use the supplied uninstaller >> "Read me first!.txt"
echo for doing so safely. >> "Read me first!.txt"

@REM This step may be removed if the setup script is added to the MS-DHCP agent
:instmode_prepareGW
echo -- Preparing Gateway environment for password-less SSH
echo(
echo Please enter your Gateway server's password. Don't worry when not seeing as you type.
echo If you've made a mistake, press backspace sufficiently and retry.
:instmode_prepareGW_runCmd
ssh -q -o StrictHostKeyChecking=no admin@%IP% "mkdir -p /var/log/iot-discovery/ms-dhcp-logs && cd /home/admin && mkdir -p .ssh && chmod 700 .ssh && cd .ssh && touch authorized_keys && chmod 644 authorized_keys && sed -i 's/^[ ]*\#\?[ ]*PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config && sed -i 's/^[ ]*\#\?[ ]*PasswordAuthentication.*/PasswordAuthentication no/g' /etc/ssh/sshd_config && sed -i 's/^[ ]*\#\?[ ]*AuthorizedKeysFile.*/AuthorizedKeysFile \/home\/admin\/.ssh\/authorized_keys/g' /etc/ssh/sshd_config && sed -i 's/^[ ]*\#\?[ ]*StrictModes.*/StrictModes yes/g' /etc/ssh/sshd_config && /etc/init.d/sshd restart" >nul
if %errorLevel% NEQ 0 (
    echo Authentication failed. Please make sure you type the correct password.
    echo If it helps, you can try typing the password somewhere, copying it
    echo and pasting into the prompt ^(by right-clicking^).
    goto instmode_prepareGW_runCmd
)
echo(

:instmode_copyPublicKey
echo -- Copying public key into the Gateway server
echo(
echo Please enter your password again.
:instmode_copyPublicKey_runCmd
set /p PubKey=<id_rsa.pub
ssh -q -o StrictHostKeyChecking=no admin@%IP% "printf '\n%%s\n' '%PubKey%' >> /home/admin/.ssh/authorized_keys"
if %errorLevel% NEQ 0 (
    echo Authentication failed. Please make sure you type the correct password.
    echo If it helps, you can try typing the password somewhere, copying it
    echo and pasting into the prompt ^(by right-clicking^).
    goto instmode_copyPublicKey_runCmd
)
echo(

:instmode_changeRSAPerms
echo -- Setting permissions of private key to SYSTEM only
icacls C:/Users/%USERNAME%/.cp-ssh/id_rsa /setowner SYSTEM >nul
icacls C:/Users/%USERNAME%/.cp-ssh/id_rsa /remove %USERNAME% >nul

:instmode_scheduleTask
echo -- Scheduling task to copy logs every 1 minute
@REM First uninstall the task if it already exists
schtasks /end /tn "Checkpoint DHCP Discovery" >nul 2>&1
schtasks /delete /tn "Checkpoint DHCP Discovery" /f >nul 2>&1
@REM Then create a new task
schtasks /create /tn "Checkpoint DHCP Discovery" /sc MINUTE /mo 1 /tr "scp -i C:/Users/%USERNAME%/.cp-ssh/id_rsa -o StrictHostKeyChecking=no -r 'C:/Windows/System32/dhcp/*DhcpSrvLog-*.log' admin@%IP%:/var/log/iot-discovery/ms-dhcp-logs/" /ru System /rl HIGHEST >nul
echo(

:instmode_successful
echo Discovery engine setup successful.
echo Make sure to select MS-DHCP in your Quantum IoT Profile ^(in Infinity Portal^), and enforce.
echo It's crucial to enforce the profile as soon as possible.
echo(
goto exit



@REM =======================================================
@REM                     Update IP mode
@REM =======================================================

:updateIPMode
echo Updating Gateway IP
echo(

:updtmode_enterIP
set /p "IP=Enter new Gateway server's IP: "
echo Please make sure the IP is correct by navigating to
echo https://%IP%/
set /p "IPConfirm=Did the GAiA login page show up (y/n)? "
if /i "%IPConfirm%" == "y" goto updtmode_enterIP_IPCorrect
if /i "%IPConfirm%" == "Y" goto updtmode_enterIP_IPCorrect

:instmode_enterIP_IPWrong
echo Please make sure the IP is correct.
goto instmode_enterIP


:updtmode_enterIP_IPCorrect
echo(
echo -- Removing scheduled copy task
schtasks /end /tn "Checkpoint DHCP Discovery" >nul 2>&1
schtasks /delete /tn "Checkpoint DHCP Discovery" /f >nul 2>&1

echo -- Creating new task
schtasks /create /tn "Checkpoint DHCP Discovery" /sc MINUTE /mo 1 /tr "scp -i C:/Users/%USERNAME%/.cp-ssh/id_rsa -o StrictHostKeyChecking=no -r 'C:/Windows/System32/dhcp/*DhcpSrvLog-*.log' admin@%IP%:/var/log/iot-discovery/ms-dhcp-logs/" /ru System /rl HIGHEST >nul

echo(
echo IP updated successfully!
echo(
goto exit

@REM =======================================================
@REM                     Uninstall mode
@REM =======================================================

:uninstallMode

set /p "ShouldUninstall=Are you sure you want to uninstall the dicovery engine (y/n)? "
if /i "%ShouldUninstall%" == "y" goto uninmode_shouldUninstall
if /i "%ShouldUninstall%" == "Y" goto uninmode_shouldUninstall

@REM Situation: User doesn't want to uninstall. Return to mode select
echo(
goto modeSelect

:uninmode_shouldUninstall
echo Uninstalling discovery engine
echo(

:uninmode_removeTask
echo -- Removing scheduled copy task
schtasks /end /tn "Checkpoint DHCP Discovery" >nul 2>&1
schtasks /delete /tn "Checkpoint DHCP Discovery" /f >nul 2>&1

:uninmode_deleteCpSSH
echo -- Deleting checkpoint folder
cd C:/Users/%USERNAME%/
rmdir /S /Q .cp-ssh >nul 2>&1

:uninmode_successful
echo(
echo Dicovery engine successfully uninstalled.
echo(
goto exit

:exit
endlocal
echo(
echo Press any key to close this setup tool...
pause >nul
exit 0

:instantExit
endlocal
exit 0

