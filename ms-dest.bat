@echo off
setlocal

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
echo -- Setup run as Administrator.
echo(

@REM Check if SSH is installed
@REM where: prints location of command, and returns non-zero if not found
where ssh >nul 2>&1
if %errorLevel% == 0 (
    echo -- SSH is installed.
    goto modeSelect
)

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
@REM First of all, to instal SSH we need to run a powershell webrequest (wget).
@REM Invoke-WebRequest exists only in PowerShell 3.0+, which by default comes with Windows Server 2012
echo(

:installSSH_checkPowershellExists
@REM Make sure powershell is installed in the first place
where powershell >nul 2>&1
if %errorLevel% NEQ 0 (
    echo PowerShell could not be found on this machine!
    echo It's only necessary for automatically installing SSH.
    echo You may install PowerShell version 3.0 or higher, or install OpenSSH and re-run this tool.
    goto exit
)
echo -- PowerShell exists on machine

:installSSH_checkWgetExists
@REM Make sure Invoke-WebRequest exists (meaning powershell is version 3.0 or above)
powershell Get-Command Invoke-WebRequest -errorAction SilentlyContinue >nul 2>&1
if %errorLevel% NEQ 0 (
    echo PowerShell version not supported.
    echo Please install PowerShell version 3.0 or higher, and re-run the installer.
    goto exit
)
echo -- PowerShell version supported
echo( 

:installSSH_downloadInstalller
echo -- Downloading SSH installer...
powershell Invoke-WebRequest -outFile C:/Users/%USERNAME%/openSSHInstaller.msi https://github.com/PowerShell/Win32-OpenSSH/releases/download/v9.2.2.0p1-Beta/OpenSSH-Win64-v9.2.2.0.msi
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
echo -- SSH download successful
echo -- Running SSH installer...
C:/Users/%USERNAME%/openSSHInstaller.msi
echo -- OpenSSH installed
echo -- Cleaning up installer
del C:/Users/%USERNAME%/openSSHInstaller.msi 2>nul
echo -- Installation complete!
echo(
echo Please re-open this tool ^(in a new window^) to refresh.
goto exit








@REM =======================================================
@REM                       Mode select
@REM =======================================================

@REM Mode select between installing, uninstalling or changing IP
:modeSelect
@REM echo You can choose a mode to run, or quit.
@REM echo ^(1^) Install Dicovery Engine
@REM echo ^(3^) Update Management IP
@REM echo ^(5^) Uninstall Discovery Engine
@REM echo ^(0^) Close tool
@REM echo(

@REM set /p "SelectedMode=Selected mode (default: 1): "
@REM if /i "%SelectedMode%" == "0" goto instantExit
@REM if /i "%SelectedMode%" == "1" goto installMode










@REM =======================================================
@REM                       Install mode
@REM =======================================================

@REM Enter install mode
:installMode
echo(
echo -- Entering install mode
echo(

:instmode_enterIP
set /p "IP=Enter Management server's IP: "
echo Please make sure the IP is correct by navigating to
echo https://%IP%/
set /p "IPConfirm=Did the GAiA login page show up (y/n)? "
if /i "%IPConfirm%" == "y" goto instmode_enterIP_IPCorrect
if /i "%IPConfirm%" == "Y" goto instmode_enterIP_IPCorrect

:instmode_enterIP_IPWrong
echo Make sure the Management server has been properly set up, or try inputting the
echo correct IP address.
goto instmode_enterIP

:instmode_enterIP_IPCorrect
echo -- Setting up discovery engine for server %IP%
echo(

:instmode_generateRSA
echo -- Generating RSA key pair...
cd C:/Users/%USERNAME%/
mkdir .cp-ssh 2>nul
cd .cp-ssh
del id_rsa id_rsa.pub 2>nul
ssh-keygen -N "" -q -f id_rsa
echo -- Key pair generated.
echo(

@REM Generate a "Read me!" file
:instmode_generateReadme
cd C:/Users/%USERNAME%/.cp-ssh
echo Do not delete this folder! > "Read me first!.txt"
echo It's necessary for Checkpoint's MS-DHCP discovery engine to properly function. >> "Read me first!.txt"
echo( >> "Read me first!.txt"
echo If you want to properly uninstall the MS-DHCP discovery engine, use the supplied uninstaller. >> "Read me first!.txt"
echo for doing so safely. >> "Read me first!.txt"

@REM This step may be removed if the setup script is added to the MS-DHCP agent
:instmode_prepareMGMT
echo -- Preparing Management environment for password-less SSH
echo Please enter your Management server's password. Don't worry when not seeing as you type.
echo If you've made a mistake, press backspace sufficiently and retry.
:instmode_prepareMGMT_runCmd
ssh -q -o StrictHostKeyChecking=no admin@%IP% "mkdir -p /var/log/nanoagent/ms-dhcp-logs && cd /home/admin && mkdir -p .ssh && chmod 700 .ssh && cd .ssh && touch authorized_keys && chmod 644 authorized_keys && sed -i 's/^[ ]*\#\?[ ]*PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config && sed -i 's/^[ ]*\#\?[ ]*PasswordAuthentication.*/PasswordAuthentication no/g' /etc/ssh/sshd_config && sed -i 's/^[ ]*\#\?[ ]*AuthorizedKeysFile.*/AuthorizedKeysFile \/home\/admin\/.ssh\/authorized_keys/g' /etc/ssh/sshd_config && /etc/init.d/sshd restart"
if %errorLevel% NEQ 0 (
    echo Authentication failed. Please make sure you type the correct password.
    echo If it helps, you can try typing the password somewhere, copying it
    echo and pasting into the prompt ^(by right-clicking^).
    goto instmode_prepareMGMT_runCmd
)
echo -- Management environment set up.
echo(

:instmode_copyPublicKey
echo -- Copying public key into the Management server
echo Please enter your password again.
:instmode_copyPublicKey_runCmd
scp -q -o StrictHostKeyChecking=no C:/Users/%USERNAME%/.cp-ssh/id_rsa.pub admin@%IP%:/home/admin/.ssh/authorized_keys
if %errorLevel% NEQ 0 (
    echo Authentication failed. Please make sure you type the correct password.
    echo If it helps, you can try typing the password somewhere, copying it
    echo and pasting into the prompt ^(by right-clicking^).
    goto instmode_copyPublicKey_runCmd
)
echo -- Public key copied
echo(

:instmode_changeRSAPerms
echo -- Setting permissions of private key to SYSTEM only
icacls C:/Users/%USERNAME%/.cp-ssh/id_rsa /setowner SYSTEM >nul
icacls C:/Users/%USERNAME%/.cp-ssh/id_rsa /remove %USERNAME% >nul
echo -- Permissions set
echo(

:instmode_createCopyJob
echo -- Creating copy job to upload logs into Management server
echo(
:instmode_createCopyJob_genBatch
echo -- Generating batch file with copy command
echo scp -i C:/Users/%USERNAME%/.cp-ssh/id_rsa -o StrictHostKeyChecking=no -r "C:/Windows/System32/dhcp/*DhcpSrvLog*.log" admin@%IP%:/var/log/nanoagent/ms-dhcp-logs > C:/Users/%USERNAME%/.cp-ssh/copy-job.bat
echo -- Batch generated
echo(
:instmode_createCopyJob_scheduleTask
echo -- Scheduling task with administrator privileges to copy every 1 minute
schtasks /create /tn "Checkpoint DHCP Discovery" /sc MINUTE /mo 1 /tr "C:/Users/%USERNAME%/.cp-ssh/copy-job.bat" /ru System /rl HIGHEST >nul
echo -- Task scheduling done
echo(

:instmode_successful
echo Discovery engine setup successful.
echo Make sure to select MS-DHCP as your discovery engine in Infinity Portal.
echo(

:exit
endlocal
echo(
echo Press any key to close this setup tool...
pause >nul
exit 0

:instantExit
endlocal
exit 0

