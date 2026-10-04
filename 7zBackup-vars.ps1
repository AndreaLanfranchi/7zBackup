# ====================================================================
#  This is the 7zBackup Default Vars Script File
# ====================================================================
# VARIABLES - You can hardcode values here if you do not want to
#             to pass them by command line. 
# --------------------------------------------------------------------
#  Variable       : BkType 
#  Argument Name  : --type
#  Description    : Type of backup to perform. 
#  Values         : full | diff | incr | copy
#  Comments   
#  -------------------------------------------------------------------
#  full : This option performs the archiving of all files in the 
#         selection paths regardless the state of their archive attribute.
#         At successfull archiving operation all archive attributes
#         for all archived files are lowered.
#  diff : This option is generally used to perform the archiving of
#         files in the selection paths that have changed after a previous
#         full backup or any backup with option to lower Archive bit
#         At successfull completion of archiving operation no changes
#         are set on Archive bit
#  incr : This option is generally used to perform the archiving of
#         files in the selection paths that have changed after a previous
#         full backup or any backup with option to lower Archive bit
#         At successfull completion of archiving operation all files
#         archived have their Archive bit lowered.
#  copy : Like FULL backup but leaves archive attribute unchanged
#  -------------------------------------------------------------------
#  Uncomment the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
# Set-Variable -Name BkType -Value "<value>" -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkWorkDrive 
#  Argument Name  : --workdrive
#  Description    : Drive unit to use for making root junction points
#  Values         : Any valid drive letter
#  Comments   
#  -------------------------------------------------------------------
#  This value holds the drive letter to use for the creation of the root
#  junction directory. Default setting is "auto"
#  which means the script will try to use the drive letter associated
#  to the %TEMP% variable
#  Of course, you can change this value using proper command line argument
#  -------------------------------------------------------------------
#  Uncomment the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
# Set-Variable -Name BkWorkDrive -Value "<value>" -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkSelection 
#  Argument Name  : --selection
#  Description    : Full path to the file holding selection directives
#  Values         : 
#  Comments   
#  -------------------------------------------------------------------
#  Generally speaking you should not hardcode this value as you will
#  likely pass different selection file names using command line.
#  -------------------------------------------------------------------
#  Uncomment the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
# Set-Variable -Name BkSelection -Value "<value>" -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkDestPath 
#  Argument Name  : --destpath
#  Description    : Full path to directory
#  Values         : 
#  Comments   
#  -------------------------------------------------------------------
#  This is the target folder that will contain the backup archive. Consider this path
#  as a sort of library that will contain all of your backups. The real archive name
#  will be generated automatically. Can be a UNC path
#  -------------------------------------------------------------------
#  Uncomment the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
# Set-Variable -Name BkDestPath -Value "<value>" -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkArchivePrefix 
#  Argument Name  : --prefix
#  Description    : Prefix to assign to generated archive
#  Values         : 
#  Comments   
#  -------------------------------------------------------------------
#  This variable contains the prefix to use in archive name generation. 
#  By default this is equal to the COMPUTERNAME environment variable but
#  you can choose whichever value you want with no spaces and no quotes.
#  The suffix can help you mantain groups of backups and to handle
#  retain/rotation policy, as described later.
#  Archive name creation template is the following:
#  $BkArchivePrefix-$BkType-YYYYMMDD-HH-mm.$BkArchiveType
#  -------------------------------------------------------------------
#  Uncomment the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
Set-Variable -Name BkArchivePrefix -Value ($Env:Computername) -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkArchiveType 
#  Argument Name  : --archivetype
#  Description    : Type of archive to create
#  Values         : 7z | zip | tar
#  Comments   
#  -------------------------------------------------------------------
#  This variable contains the type of archive you want to create.
#  Value can be any of the supported values by 7zip for the -t switch
#  except for bzip2 (which is not an archiver)
#
#  7z   : default format with better compression
#  zip  : very compatible with other programs
#  tar  : Unix and linux compatible but only archiving (no compression)
#
#  Archive name creation template is the following:
#  $BkArchivePrefix-$BkType-YYYYMMDD-HHmmss.$BkArchiveType
#  -------------------------------------------------------------------
#  Uncomment the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
Set-Variable -Name BkArchiveType -Value "7z" -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkArchivePassword 
#  Argument Name  : --password
#  Description    : Any valid password
#  Values         : 
#  Comments   
#  -------------------------------------------------------------------
#  Set this if you want to password protect your archive
#  -------------------------------------------------------------------
#  Uncomment the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  Please read 7-zip help info for useful informations about password
#  complexity
#  -------------------------------------------------------------------
# Set-Variable -Name BkArchivePassword -Value "<yourpassword>" -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkArchiveCompression 
#  Argument Name  : --compression
#  Description    : Any valid value among 0 1 3 5 7 9
#  Values         : 
#  Comments   
#  -------------------------------------------------------------------
#  Set this to calibrate speed vs space reduction
#  -------------------------------------------------------------------
#  Uncomment the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  Please read 7-zip help info for useful informations about password
#  complexity
#  -------------------------------------------------------------------
# Set-Variable -Name BkArchiveCompression -Value "< 0 | 1 | 3 | 5 | 7 | 9>" -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkArchiveThreads 
#  Argument Name  : --threads
#  Description    : An integer number greater than 0
#  Values         : <default not set>
#  Comments   
#  -------------------------------------------------------------------
#  This variable sets the number of threads 7-zip should be allowed
#  to use. By default 7-zip uses one thread for each available core
#  therefore eating up most of computational resources.
#  You can limit this behavior by limiting the number of threads
#  to be uses therefore keeping your computer responsive.
#  Please note that the number of threads can not exceed the number
#  of installed cores.
#  -------------------------------------------------------------------
#  Uncomment the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
# Set-Variable -Name BkArchiveThreads -Value ([int]4) -Scope 1
#
# - or do a calc, say, to use only 50% of cores -
#
# Set-Variable -Name "tmpNumCores" -Value([int]0) -Scope Local
# Get-CimInstance -ClassName Win32_Processor | ForEach-Object {
	# If($_.NumberOfLogicalProcessors) {
		# $tmpNumCores += [int]$_.NumberOfLogicalProcessors
	# } 
	# ElseIf($_.NumberOfCores) {
		# $tmpNumCores += [int]$_.NumberOfCores
	# }
	# Else {
		# $tmpNumCores ++
	# }
# }
# Set-Variable -Name BkArchiveThreads -Value ([int]($tmpNumCores * .5)) -Scope 1
# Remove-Variable -Name "tmpNumCores"

# --------------------------------------------------------------------
#  Variable       : BkArchiveSolid 
#  Argument Name  : --solid
#  Description    : Any boolean value
#  Values         : Default $True
#  Comments   
#  -------------------------------------------------------------------
#  This variable sets wether or not an archive should endorse solid mode
#  To understand what is solid mode please refer to 7-zip documentation
#  -------------------------------------------------------------------
#  Uncomment the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
# Set-Variable -Name BkArchiveSolid  -Value $True -Scope 1
# Set-Variable -Name BkArchiveSolid  -Value $False -Scope 1
#

# --------------------------------------------------------------------
#  Variable       : BkRotate 
#  Argument Name  : --rotate
#  Description    : An integer number greater than 0
#  Values         : 
#  Comments   
#  -------------------------------------------------------------------
#  This variable holds the number of historycal archive backups you
#  want to keep on target media. An zero value means no rotation
#  will be performed after succesful archiving and YOU will be in charge
#  to delete old backups. Pay attention or your target media
#  will run out of free space soon.
#  For example: if you set this value to 3 then it means the 3 newest
#  backups of the current type are kept on target media.
#  For a "classic" 3 week incremental scheme we suggest to :
#  $BkRotate=3 for full backups (launched once a week)
#  $BkRotate=21 for incr backups (launched once per day)
#  -------------------------------------------------------------------
#  Uncomment the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
# Set-Variable -Name BkRotate -Value ([int]3) -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkKeepEmptyDirs
#  Argument Name  : --emptydirs
#  Description    : Boolean
#  Values         : 
#  Comments   
#  -------------------------------------------------------------------
#  This variable sets weather or not archive empty directories
#  If not defined the script assumes a value of $False (default).
#
#  Empty dirs are not really archived. The script drops a dummy file
#  into empty dirs to have it archived. After archiving dummy file
#  is immediately removed.
#
#  -------------------------------------------------------------------
#  Uncomment the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
# Set-Variable -Name BkKeepEmptyDirs -Value $True -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkMaxDepth 
#  Argument Name  : --maxdepth
#  Description    : An integer number 
#  Values         : 
#  Comments   
#  -------------------------------------------------------------------
#  This variable holds the maximum level to be reached in directory
#  recursion while scanning for files to backup.
#  If not defined the script assumes no limit
#
#  The value is zero-based which means a value of zero whil stop the
#  the scanning at the first level. A value of 1 will allow 1 recursion
#  level therefore scanning the firs level of subfolders and so on
#
#  -------------------------------------------------------------------
#  Uncomment the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
# Set-Variable -Name BkMaxDepth -Value ([int]0) -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkLogFile 
#  Argument Name  : --logfile
#  Description    : Full path you want to assign to log file
#  Values         : 
#  Comments   
#  -------------------------------------------------------------------
#  This variable holds the name of the file where to log operations
#  By default it's stored in %temp% directory within a file named 
#  as the script plus ".log" extension.
#  -------------------------------------------------------------------
#  Uncomment the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
# Set-Variable -Name BkLogFile -Value "<value>" -Scope 1

# --------------------------------------------------------------------
#  Variable       : Bk7ZipBin
#  Argument Name  : --7zipbin
#  Description    : Full path to 7z.exe
#  Values         : 
#  Comments
#  -------------------------------------------------------------------
#  7-zip executable path. 
#  If you have installed 7zip using standard path, then you do not need to
#  change this.
#  -------------------------------------------------------------------
#  Uncomment the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
# Set-Variable -Name Bk7ZipBin -Value (Join-Path $Env:ProgramFiles "\7-zip\7z.exe") -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkJunctionBin   (OBSOLETE)
#  Argument Name  : --jbin
#  -------------------------------------------------------------------
#  Not used anymore: it was the full path to Junction.exe, needed only
#  by Windows XP and 2003, which are not supported anymore. MKLINK
#  creates junctions (symbolic links for network sources).
#  A value left here from an older version is simply ignored. The
#  --jbin command line argument is accepted but ignored, with a warning.
#  -------------------------------------------------------------------

# --------------------------------------------------------------------
#  Variable       : BkNotifyLog
#  Argument Name  : --notify or --notifyto
#  Description    : Holds the email address(es) to send the report
#                   of operations to.
#  Comments   
#  -------------------------------------------------------------------
#  Use this argument to set a single email address, or a list of email
#  addresses, which will receive the detailed report of operations.
#  If you mean to address the report to a single email address then
#  you will want to set the variable as a normal string.
#  If you mean to have multiple addresses to send the report to, then
#  you will have to set the variable as an array.
#
#  PLEASE NOTE 
#  Each email address undergoes a check to verify it is properly
#  formatted.
#  -------------------------------------------------------------------
#  Uncomment the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
#  Set-Variable -Name BkNotifyLog -Value "someemail@somedomain.com" -Scope 1
# - or -
#  Set-Variable -Name BkNotifyLog -Value @("someemail@somedomain.com", "someotheremail@somedomain.com") -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkNotifyLogCc
#  Argument Name  : --notifyCc
#  Description    : Holds the email address(es) to send the report
#                   of operations in Cc.
#  Comments   
#  -------------------------------------------------------------------
#  Use this argument to set a single email address, or a list of email
#  addresses, which will receive the detailed report of operations.
#  If you mean to address the report to a single email address then
#  you will want to set the variable as a normal string.
#  If you mean to have multiple addresses to send the report to, then
#  you will have to set the variable as an array.
#
#  PLEASE NOTE 
#  Each email address undergoes a check to verify it is properly
#  formatted.
#  -------------------------------------------------------------------
#  Uncomment the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
#  Set-Variable -Name BkNotifyLogCc -Value "someemail@somedomain.com" -Scope 1
# - or -
#  Set-Variable -Name BkNotifyLogCc -Value @("someemail@somedomain.com", "someotheremail@somedomain.com") -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkNotifyLogBcc
#  Argument Name  : --notifyBcc
#  Description    : Holds the email address(es) to send the report
#                   of operations in Bcc.
#  Comments   
#  -------------------------------------------------------------------
#  Use this argument to set a single email address, or a list of email
#  addresses, which will receive the detailed report of operations.
#  If you mean to address the report to a single email address then
#  you will want to set the variable as a normal string.
#  If you mean to have multiple addresses to send the report to, then
#  you will have to set the variable as an array.
#
#  PLEASE NOTE 
#  Each email address undergoes a check to verify it is properly
#  formatted.
#  -------------------------------------------------------------------
#  Uncomment the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
#  Set-Variable -Name BkNotifyLogBcc -Value "someemail@somedomain.com" -Scope 1
# - or -
#  Set-Variable -Name BkNotifyLogBcc -Value @("someemail@somedomain.com", "someotheremail@somedomain.com") -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkNotifyExtra
#  Argument Name  : --notifyextra 
#  Description    : Specifies if you want extra info in the notification
#                   log
#  Comments   
#  -------------------------------------------------------------------
#  Use this argument to set your option about having or not extra
#  informations in your notification log.
#  ExtraInfos are : the complete list of inclusions, the complete
#  list of exclusions and the list of exceptions (if any). In addition
#  the complete selection file will be sent.
#  Extra info delivery mode options are:
#  none   : no extra info will be sent (default)
#  inline : all extra info will be written in the message body
#  attach : all extra info will be attached as separate files
#
#  -------------------------------------------------------------------
#  Uncomment the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
#  Set-Variable -Name BkNotifyExtra -Value "< none | inline | attach >" -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkmailSubject
#  Argument Name  : None (you can't pass it from cli)
#  Description    : String to use as subject for notification email
#  Values         : 
#  Comments   
#  -------------------------------------------------------------------
#  Self explanatory ... isn't it ?
#  -------------------------------------------------------------------
#  Uncomment one of the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
# Set-Variable -Name BkMailSubject -Value "7zBackup Report Host $Env:ComputerName.$Env:USERDNSDOMAIN" -Scope 1
# - or -
Set-Variable -Name BkMailSubject -Value "7zBackup Report Host $Env:ComputerName" -Scope 1
# - or -
# Set-Variable -Name BkMailSubject -Value "7zBackup Report" -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkSmtpFrom
#  Argument Name  : --notifyfrom
#  Description    : Email address to send email notifications from
#  Values         : 
#  Comments   
#  -------------------------------------------------------------------
#  Self explanatory ... isn't it ?
#  -------------------------------------------------------------------
#  Uncomment one of the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
# Set-Variable -Name BkSmtpFrom -Value ($Env:UserName + "@" + $Env:UserDNSDomain) -Scope 1
# - or -
# Set-Variable -Name BkSmtpFrom -Value "<value>" -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkSmtpRelay
#  Argument Name  : --smtpserver
#  Description    : The name of the smtp server to use when sending
#                   notification emails.
#  Values         : Host name or ip address
#  Comments   
#  -------------------------------------------------------------------
#  Self explanatory ... isn't it ?
#  -------------------------------------------------------------------
#  Uncomment one of the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
# Set-Variable -Name BkSmtpRelay -Value "<yourmailserverDNSName_or_IP_address>" -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkSmtpPort
#  Argument Name  : --smtpport
#  Description    : The port to contact smtp server on
#  Values         : integer number (default 25)
#  Comments   
#  -------------------------------------------------------------------
#  Self explanatory ... isn't it ?
#  -------------------------------------------------------------------
#  Uncomment one of the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
Set-Variable -Name BkSmtpPort -Value ([int]25) -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkSmtpUser
#  Argument Name  : --smtpuser
#  Description    : The user to access authenticated smtp
#  Values         : String
#  Comments       : If you set this remember to set smtpPass also
#  -------------------------------------------------------------------
#  Uncomment one of the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
# Set-Variable -Name BkSmtpUser -Value "<authuser>" -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkSmtpPass
#  Argument Name  : --smtppass
#  Description    : The password to use for authenticated smtp
#  Values         : String
#  Comments       : If you set this remember to set smtpUser also
#  -------------------------------------------------------------------
#  Uncomment one of the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
# Set-Variable -Name BkSmtpPass -Value "<password>" -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkSmtpSsl
#  Argument Name  : --smtpssl
#  Description    : Whether or not to enable Ssl over smtp
#  Values         : True or False
#  Comments   
#  -------------------------------------------------------------------
#  Self explanatory ... isn't it ?
#  -------------------------------------------------------------------
#  Uncomment one of the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
# Set-Variable -Name BkSmtpSsl -Value ($False) -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkMailKitPath
#  Argument Name  : --mailkitpath
#  Description    : Folder holding MailKit.dll, MimeKit.dll and their
#                   dependency DLLs
#  Values         : Full path to a folder
#  Comments
#  -------------------------------------------------------------------
#  When set, notification emails are sent with MailKit instead of
#  System.Net.Mail.SmtpClient. Port 465 uses TLS on connect; with
#  BkSmtpSsl other ports require STARTTLS.
#  Take each DLL from the lib\net48 folder (or the closest older .NET
#  Framework folder) of the MailKit NuGet package and of every package
#  it depends on. See README.md.
#  If MailKit can not be loaded, a warning is logged and SmtpClient
#  is used.
#  -------------------------------------------------------------------
#  Uncomment the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
# Set-Variable -Name BkMailKitPath -Value "C:\Tools\MailKit" -Scope 1

# --------------------------------------------------------------------
#  Variable       : BkPreAction
#  Argument Name  : --pre
#  Description    : Sets the action to invoke before scanning process
#                   takes place. Can be, for example, used to create
#                   additional data to backup
#  Values         : Either a pws file or a script block
#
#  Comments   
#  -------------------------------------------------------------------
#  Please take into account that this code must return output to the
#  calling script if you want the action to be logged properly.
#
#  -------------------------------------------------------------------
#  Uncomment one of the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
# Set-Variable -Name BkPreAction -Value "C:\MyScripts\SomeOtherScript.ps1" -Scope 1
# - or, say for example you want to backup your sql express databases -
  # Set-Variable -Name BkPreAction -Value {

	# [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ConnectionInfo');            
	# [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Management.Sdk.Sfc');            
	# [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO');            
	# # Required for SQL Server 2008 (SMO 10.0).            
	# [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMOExtended');            
	# $Server = ".\SQLEXPRESS";  
	# $Dest = "D:\somepath\";   
	# $srv = New-Object Microsoft.SqlServer.Management.Smo.Server $Server;            
	# # If missing set default backup directory.            
	# If ($Dest -eq "") { $Dest = $server.Settings.BackupDirectory + "\" };

	# # Clean Dest directory from any previous backup
	# Remove-Item $Dest -Recurse -Force -ErrorAction SilentlyContinue
	# Start-Sleep 5
	# New-Item $Dest -ItemType Directory | Out-Null

	# Write-Output ("Started at: " + (Get-Date -format yyyy-MM-dd-HH:mm:ss));            
	# # Full-backup for every database            
	# foreach ($db in $srv.Databases)            
	# {            
		# If($db.Name -ne "tempdb")  # Non need to backup TempDB            
		# {   
			# Write-Output ("Backup of $db started")
			# $timestamp = Get-Date -format yyyy-MM-dd-HH-mm-ss;            
			# $backup = New-Object ("Microsoft.SqlServer.Management.Smo.Backup");            
			# $backup.Action = "Database";            
			# $backup.Database = $db.Name;            
			# $backup.Devices.AddDevice($Dest + $db.Name + "_full_" + $timestamp + ".bak", "File");            
			# $backup.BackupSetDescription = "Full backup of " + $db.Name + " " + $timestamp;            
			# $backup.Incremental = 0;            
			# # Starting full backup process.            
			# $backup.SqlBackup($srv);     
			# # For db with recovery mode <> simple: Log backup.            
			# If ($db.RecoveryModel -ne 3)            
			# {            
				# $timestamp = Get-Date -format yyyy-MM-dd-HH-mm-ss;            
				# $backup = New-Object ("Microsoft.SqlServer.Management.Smo.Backup");            
				# $backup.Action = "Log";            
				# $backup.Database = $db.Name;            
				# $backup.Devices.AddDevice($Dest + $db.Name + "_log_" + $timestamp + ".trn", "File");            
				# $backup.BackupSetDescription = "Log backup of " + $db.Name + " " + $timestamp;            
				# #Specify that the log must be truncated after the backup is complete.            
				# $backup.LogTruncation = "Truncate";
				# # Starting log backup process            
				# $backup.SqlBackup($srv);            
			# };            
		# };            
	# };            
	# Write-Output ("Finished at: " + (Get-Date -format  yyyy-MM-dd-HH:mm:ss));
# }

# --------------------------------------------------------------------
#  Variable       : BkPostAction
#  Argument Name  : --post
#  Description    : Sets the action to invoke after the archiving
#                   process completes. Can be used for example to
#                   move or upload the generated archive
#  Values         : Either a pws file or a script block
#
#  Comments   
#  -------------------------------------------------------------------
#  Please take into account that this code must return output to the
#  calling script if you want the action to be logged properly.
#
#  -------------------------------------------------------------------
#  Uncomment one of the following Set-Variable statement and set proper
#  "<value>" if you want to set the value for the 7zBackup script.
#  -------------------------------------------------------------------
# Set-Variable -Name BkPostAction -Value "C:\MyScripts\SomeOtherScript.ps1" -Scope 1
# - or, say for example you want to upload your archive via ftp -
# Set-Variable -Name BkPostAction -Value {

	# $RemoteTarget = "ftp://user:password@<hostname-or-ip>/$BkArchiveName"
	# $numTries  = 0; $maxTries = 5
	# $status    = $False
	# do {
		# Try {
			# Write-Output ("Trying to upload file {0} : attempt {1}" -f $BkArchiveName, ($numTries + 1))
			# $webclient = New-Object -TypeName System.Net.WebClient
			# $uri = New-Object -TypeName System.Uri -ArgumentList $RemoteTarget
			# $webclient.UploadFile($uri, $OutFile)
			# $status = $true
		# } Catch {
			# Write-Output $_.Exception.Message
			# $numTries++
			# Start-Sleep -s 5
		# }
	# }
	# While ($numTries -le $maxTries -and $status -eq $false)
	# If($status) {
		# Write-Output ("File {0} succesfully uploaded" -f $BkArchiveName)
	# } Else {
		# Write-Output ("Could not upload {0}" -f $BkArchiveName)
	# }
	
#}
