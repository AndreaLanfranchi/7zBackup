# ********************************************************************
# IMPORTANT: This script is not Officially supported in any way !
#            Use it at your own risk !!!
# ********************************************************************
# NAME			: 7zBackup.ps1
# DESCRIPTION	: This script will help you automate the backup process
#				  of your data using 7zip compression program.
#				  When job is done a detailed report is produced.
# OS			: Microsoft Windows 2000 	(NOT tested)
#				  Microsoft Windows XP 		(tested)
#				  Microsoft Windows 2003	(tested)
#				  Microsoft Windows Vista	(tested)
#				  Microsoft Windows 7    	(tested)
#				  Microsoft Windows 2008	(tested)
#				  Microsoft Windows 8    	(tested)
#				  Microsoft Windows 8.1    	(tested)
#				  Microsoft Windows 10    	(tested)
#				  Microsoft Windows 2008   	(tested)
#				  Microsoft Windows 2012   	(tested)
# REQUIREMENTS	: 7zip (http://www.7-Zip.org/download.html)
#				  Junction v1.05 (http://technet.microsoft.com/en-us/sysinternals/bb896768.aspx)
#				  NTFS File System with support for junctions or 
#                 symbolic links
# --------------------------------------------------------------------
# Give credit to the following contributors:
# (please do not remove - add your name if you contribute)
#
#  * Andrea Lanfranchi - Anlan (http://www.anlan.com)
#
# Version history: see CHANGELOG.md (newest first). For a new version, update
# $version below and add its entry at the top of CHANGELOG.md
$version = "2.1.5-Stable"
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
#
# Those who do not know how to use snail mail: The GPL is here:
# http://www.gnu.org/licenses/gpl.html

# --------------------------------------------------------------------           --------------------------------------------------------------------
# DO NOT CHANGE ANYTHING BELOW THIS POINT UNLESS YOU'RE A DEVELOPER    I Repeat  DO NOT CHANGE ANYTHING BELOW THIS POINT UNLESS YOU'RE A DEVELOPER
# AND EXACTLY KNOW WHAT YOU'RE DOING                                   I Repeat  AND EXACTLY KNOW WHAT YOU'RE DOING
# --------------------------------------------------------------------           --------------------------------------------------------------------

# --------------------------------------------------------------------
# Init Some Vars to be used globally in the script
# --------------------------------------------------------------------
$Error.Clear()
$ErrorActionPreference = "SilentlyContinue"

Set-Variable -Name "MyContext" -Value ([hashtable]::Synchronized(@{})) -Scope Script
$MyContext.Name       = $MyInvocation.MyCommand.Name
$MyContext.Definition = $MyInvocation.MyCommand.Definition
$MyContext.Directory  = (Split-Path (Resolve-Path $MyInvocation.MyCommand.Definition) -Parent)
$MyContext.StartDir   = (Get-Location -PSProvider FileSystem).ProviderPath
$MyContext.WinVer     = (Get-CimInstance -ClassName Win32_OperatingSystem).Version.Split(".")
$MyContext.PSVer      = [int]$PSVersionTable.PSVersion.Major
$MyContext.Cancelling = $False
$MyContext.DummyFile  = ".7zb"
$MyContext.Logger     = New-Object -TypeName System.Text.StringBuilder

$headerText = @"

 ------------------------------------------------------------------------------
 
  7zBackup.ps1 ver. $version (https://github.com/AndreaLanfranchi/7zBackup)
  
 ------------------------------------------------------------------------------
 
"@

$helpText = @"
 Usage : .\7zBackup.ps1 --type < full | incr | diff | copy | move >
                        --selection < full path to file name >
                        --destpath < destination path >
                       [--jbin < path to Junction.exe > ]
					   
                       -- Job specific switches --					  
                       [--dry]						
                       [--workdrive < working drive letter >]
                       [--rotate < number >]
                       [--logfile < filename >] IGNORED since 2.0.8
                       [--pre < filename | `{scriptblock`} >]
					   [--post < filename | `{scriptblock`} >]
					   
                       -- Selection specific switches --					   
                       [--maxdepth < number > ]
                       [--maxfileage < double > ]
                       [--minfileage < double > ]
                       [--maxfilesize < long > ]
                       [--minfilesize < long > ]
                       [--clearbit < True | False >]
                       [--emptydirs]

                       -- Archive (7-zip) specific switches --
                       [--prefix < string >]					   
                       [--7zipbin < path to 7z.exe > ]					   
                       [--archivetype < 7z | zip | tar >]
                       [--compression < 0 | 1 | 3 | 5 | 7 | 9 >]
                       [--threads < number >]
                       [--solid < True | False >]					   
                       [--volumes {Size}[b | k | m | g]]					   					   
                       [--password < string >]
                       [--encryptheaders]
                       [--workdir < working directory > OBSOLETE]
					   
                       -- Notification specific switches --
                       [--notifyto < email1@domain`[,email2@domain`[..`]`] >]
                       [--notifytoCc < email1@domain`[,email2@domain`[..`]`] >]
                       [--notifytoBcc < email1@domain`[,email2@domain`[..`]`] >]
                       [--notifyfrom < sender@domain >]
                       [--notifyextra < none | inline | attach >]
                       [--smtpserver < host or ip address >]
                       [--smtpport < default 25 >]					  
                       [--smtpuser < SMTPAuth's user >]					  
                       [--smtppass < SMTPAuth's password >]					  
                       [--smtpssl]	
                       [--mailkitpath < folder with MailKit.dll >]


 ------------------------------------------------------------------------------

 --type        Type of backup to perform:
               full : All files and archive bit cleared after archiving
               diff : Files with archive bit set.
                      Archive bit left unchanged after backup.
               incr : Files with archive bit set.
                      Archive bit cleared after backup.					 
               copy : Same as FULL but leave archive bits unchanged
               move : All files matching selection criteria regardless
                      their Archive bit status. After succesful operation
                      archived files are deleted from their original
                      location. Use with great care.

 --selection   Full path to file containing the selection criteria

 --destpath    Full path to destination media which will contain the archive.
               Ensure it will be on a drive with sufficient space to
               contain all the data. Can be a UNC path.
                  
 --workdrive   Drive letter to use for creation of root junction point.
               If not set the script will use the drive associated to
               the TEMP environment variable. It MUST be a valid
               drive letter with the exclusion of A and B. Drive associated
               to this letter must have NTFS file system and it`'s root
               must be writable.

 --archivetype The type of archive you want to create.
               7z   : default format with better compression
               zip  : very compatible with other programs
               tar  : unix and linux compatible but only archiving (no compression)

 --compression The level of compression you want to achieve.
               Possible values are [0 | 1 | 3 | 5 | 7 | 9 ].
               where lower values mean almost no compression and fast
               archiving while higher values mean the opposite.
               If omitted 7zip will use default settings			   

 --threads     Number of threads 7zip is allowed to use. If not set then
               7zip will try to adopt one thread per core. Set this value
               to 1 or 0 to disable multithreading.
			   
 --solid       Sets wether or not 7z archives should endorse solid format
               By default 7z archives endorse solid format. Refer to
               7-zip documentation to understand what are solid archives.

 --volumes     This command switch implements the -v switch provided by
               7-zip. You can pass a single value or a list of values
			   comma separated.
  
 --rotate      This value must be a number and indicates the number of
               archives that should remain on disk after successful
               archiving. For example if you set --rotation 3 on a 
               full archiving operation it means that the newest 3 full
               archives will be kept on disk while the oldest (if any)
               will be deleted. If this value is NOT set then ALL the
               generated archives will be kept on disk. Please be advised
               that in such case your target media will be likely get
               out of space soon. It can be specified either as command argument,
               or in the hardcoded vars file, or in the selection file. 

 --maxdepth    This value si a zero-based index limiting the depth of recursion
               while scanning in search of files to backup. Valid values are
               positive integers. It can be specified either as command argument
               or in the hardcoded vars file, or in the selection file.

 --clearbit    In backup operations of type FULL or INCR the Archive attribute
               of backupped files is cleared. If you do not want the script
               to do this simply pass --clearbit False. On the other hand
               if you do want to clear the attribute even in other backup
               types then pass --clearbit True

 --emptydirs   By design an archive will hold only files, not directories.
               Therefore the script will simply not find anything to backup
               in an empty directory. If you wish the archive to have the
               indication of empty directories also simply enable this switch.
               It will drop a dummy placeholder file in the empty dir therefore
               allowing the compressor to select it.
               This is a switch argument
 
 --password    Use this switch if you want to password protect your
               archive. No spaces in passwords please.

 --prefix      The prefix to use to generate the archive name.

 --workdir     SUPERSEDED (will be simply ignored)
               Directory which will be used as working area. 
               Must be on an NTFS file system. If none is given then
               the procedure will try to use the one in environment's
               TEMP variable.

 --7zipbin     Specify full path to 7z.exe. 
               If the argument is not provided the script will try to
               locate 7z.exe in program files folders
			   
 --jbin        Specify full path to Junction.exe. 
               If the argument is not provided the script will try to
               locate Junction.exe in program files folders
               This parameter is optional when the script is invoked
               on Windows systems which support MKLINK.
			  
 --logfile     Where to log backup operations. If empty will be
               generated automatically.

 --notifyto    Use this argument to set a list of email addresses who
               will receive an email with a copy of the logfile.
               You can specify multiple addresses separated by commas.
               If you set this switch be sure to edit the script and
               insert propervalues in variables `$smtpFrom `$smtpRelay and `$smtpPort

 --notifytoCc  As notifyto but in Carbon Copy
 
 --notifytoBcc As notifyto but in Blind Carbon Copy
 
 --notifyfrom  Use this argument to set the proper address to use as 
               sender address when sending out email notifications

 --notifyextra Use this argument to set the way this script will include
               extra informations in the notification message.
               none   : no extra informations
               inline : extra informations in the body of the message
               attach : extra informations attached to the message

 --smtpserver  Host name or IP address of the server to use

 --smtpport    Port number of the smtp server (Default is 25)

 --smtpuser    Smtp's authenticated user (if smtpauth required)

 --smtppass    Smtp's authenticated password (if smtpauth required)

 --smtpssl     Wheather or not smtp transport requires ssl
               This is a switch argument

 --mailkitpath Folder holding MailKit.dll, MimeKit.dll and their dependency
               DLLs. When set, notification emails are sent with MailKit
               instead of System.Net.Mail.SmtpClient. Port 465 uses TLS
               on connect. If MailKit can not be loaded, a warning is
               logged and SmtpClient is used

 --dry         Complete the process without creating any archive file
               nor changing/deleting/clearing any file

 --pre         Pointer to a pws script or a script block to be execute 
               before scanning process starts
			   
 --post        Pointer to a pws script or a script block to be execute 
               after archiving procedure completes regardless it's been
               succesfull or not
 -----------------------------------------------------------------------
 
"@

# ====================================================================
# Start Functions Library
# ====================================================================

# Legend for Attributes bits on files
# - Normal ....... (n) ==> 0
# - Hidden ....... (h) ==> 2
# - ReadOnly ..... (r) ==> 1
# - System ....... (s) ==> 4
# - Directory .... (d) ==> 16
# - Archive ...... (a) ==> 32
# - ReparsePoint . (j) ==> 1024

# Load Attributes Names in array for usage in functions
#$attrNames = [enum]::getNames([System.IO.FileAttributes]);

# -----------------------------------------------------------------------------
# Function 		: Invoke-PostAction
# -----------------------------------------------------------------------------
# Description	: Executes a job after execution
# Returns       : 
# Credits       : 
# -----------------------------------------------------------------------------
Function Invoke-PostAction {

	# --------------------------------------------------------------------------------
	# Execute post Action if we have any 
	# --------------------------------------------------------------------------------
	If(Test-Variable "BkPostAction") {

		Trace " Invoking Post-Action (Output follows if any)"
		Trace " ------------------------------------------------------------------------------"
		Try {
			& $BkPostAction 2>&1 | Set-Variable -Name "postActionOutput" -Scope Script
			$postActionOutput | ForEach-Object {
				Trace " $_"
			}
		} Catch {
			Trace (" {0}" -f $_.Exception.Message)
		}
		Trace " ------------------------------------------------------------------------------"
		Trace " "
		
	}

}

# -----------------------------------------------------------------------------
# Function 		: Test-CtrlCRequest
# -----------------------------------------------------------------------------
# Description	: Checks whether or not the user hit CTRL + C to request
#                 script cancel
# Parameters    : 
# Returns       : $True / $False
# Credits       : 
# -----------------------------------------------------------------------------
Function Test-CtrlCRequest {

	If($MyContext.Cancelling -ne $True) {
		If($Host.UI.RawUI.KeyAvailable -and [int]$Host.UI.RawUI.ReadKey("AllowCtrlC,IncludeKeyUp,NoEcho").Character -eq 3) {
			$MyContext.Cancelling = $True
			Trace " " 
			Trace " User requested to abort ... "
			Trace " " 
		} 
	}
	$Host.UI.RawUI.FlushInputBuffer()
	Write-Output ($MyContext.Cancelling)
}


# -----------------------------------------------------------------------------
# Function 		: Close-Writers
# -----------------------------------------------------------------------------
# Description	: Flushes and closes the file stream writers of the script
# Parameters    : -
# Returns       : Nothing
# -----------------------------------------------------------------------------
Function Close-Writers {
	$SWriters.GetEnumerator() | ForEach-Object {
		Try {
			$_.Value.Flush()
			$_.Value.Close()
			$_.Value.Dispose()
		} Catch {}
	}
}

# -----------------------------------------------------------------------------
# Function 		: Get-NotificationExtras
# -----------------------------------------------------------------------------
# Description	: Lists the report files of the run which a notification email
#				  can carry along (not empty, no stats, no README)
# Parameters    : -
# Returns       : The files
# -----------------------------------------------------------------------------
Function Get-NotificationExtras {
	Get-ChildItem -Path $BkRootDir -Force | Where-Object { !$_.PSIsContainer -and ($_.Length -gt 0) -and ($_.Name -notmatch "stats|README") }
}

# -----------------------------------------------------------------------------
# Function 		: Clear-Script
# -----------------------------------------------------------------------------
# Description	: Cleans all files created by the script and leaves the system
#                 in a state which allows another go.
# Parameters    : -
# Returns       : Nothing
# -----------------------------------------------------------------------------
Function Clear-Script {

	Close-Writers

	
	# Only the run that created the lock may remove it
	If ((Test-Variable "BkLockFile") -and ($MyContext.LockOwned)) {if ((Test-Path ($BkLockFile))) { Remove-Item -LiteralPath $BkLockFile | Out-Null }}
	Set-Location ($MyContext.StartDir)
	If ((Test-Path -Path ($BkRootDir) -PathType Container)) { Remove-RootDir $BkRootDir | Out-Null }
	
	Try {
		[console]::TreatControlCAsInput = $False
	} Catch {}
	
}


# -----------------------------------------------------------------------------
# Function 		: IsValidEmailAddress
# -----------------------------------------------------------------------------
# Description	: This function is used to check if a given string is an email
#                 address.
# Parameters    : [string]emailAddress - The string to check
# Returns       : $True / $False
# -----------------------------------------------------------------------------
Function IsValidEmailAddress { 
	param([string]$emailAddress = $(throw "You must provide an address"))
	$emailAddress -match "^[a-zA-Z0-9]([\w\.+-]*[a-zA-Z0-9])?@[a-zA-Z0-9]([\w\.-]*[a-zA-Z0-9])?\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z]$"
}	

# -----------------------------------------------------------------------------
# Function 		: IsValidHostName
# -----------------------------------------------------------------------------
# Description	: This function is used to check if a given string is a
#                 valid host name.
# Parameters    : [string]hostName - The string to check
# Returns       : $True / $False
# -----------------------------------------------------------------------------
Function IsValidHostName { 
	param([string]$hostName = $(throw "You must provide an host name"))
	$hostName -match "^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])$"
}	

# -----------------------------------------------------------------------------
# Function 		: GetDestPathFreeSpace
# -----------------------------------------------------------------------------
# Description	: This function is used to check how much available space is
#                 available on destpath.
# Parameters    : [string]DestPath - The Path To Check
# Returns       : Long Integer
# -----------------------------------------------------------------------------
Function GetDestPathFreeSpace {
	param([string]$target = $(throw "You must provide a location to check"))
	
	Return [int64]((New-Object -ComObject Scripting.FileSystemObject).GetDrive([System.IO.Path]::GetPathRoot($target)).AvailableSpace)
}

# -----------------------------------------------------------------------------
# Function 		: IsValidIPAddress
# -----------------------------------------------------------------------------
# Description	: This function is used to check if a given string is an IP
#                 address.
# Parameters    : [string]ipAddress - The string to check
# Returns       : $True / $False
# -----------------------------------------------------------------------------
Function IsValidIPAddress { 
	param([string]$ipAddress = $(throw "You must provide an address"))
	[System.Net.IPAddress]::TryParse($ipAddress, [ref]$null)
}	

# -----------------------------------------------------------------------------
# Function 		: New-Junction
# -----------------------------------------------------------------------------
# Description	: Creates a Junction by the means of SysInternals' Junction.exe
# Parameters    : [string]jPath    - Full path to the name of the junction
#				  [string]jTarget  - Full path to the target 
# Returns       : $True / $False
# -----------------------------------------------------------------------------
Function New-Junction {
	param(
		[string]$jPath = $(throw "You must provide a path where to create the Junction"), 
		[string]$jTarget = $(throw "You must provide a path to target")
	)
	
	# Before we make any junction we have to test target
	# path exist
	If(Test-Path -Path $jTarget) {
	
		# Junction it (from alias)
		Invoke-Expression (('& "{0}" /accepteula "{1}" "{2}"') -f $BkJunctionBin, $jPath, $jTarget) 
		Start-Sleep -Milliseconds 10
		
		# Test is present
		Return (Test-Path -Path $jPath)

		
	}
	Write-Output $False
}

# -----------------------------------------------------------------------------
# Function 		: Test-NetworkPath
# -----------------------------------------------------------------------------
# Description	: Tells whether a path is on the network: UNC path or network drive
# Parameters    : [string]$path - Full path
# Returns       : $True / $False
# -----------------------------------------------------------------------------
Function Test-NetworkPath ([string]$path) {
	If($path.StartsWith("\\")) { Return $True }
	Try { Return ((New-Object System.IO.DriveInfo([System.IO.Path]::GetPathRoot($path))).DriveType -eq [System.IO.DriveType]::Network) } Catch { Return $False }
}

# -----------------------------------------------------------------------------
# Function 		: New-SymLink
# -----------------------------------------------------------------------------
# Description	: Links a path to Target: a junction for a local target, a symbolic
#				  link for a network target (only available for WinVer 6+)
# Parameters    : [string]jPath    - Full path to the name of the junction
#				  [string]jTarget  - Full path to the target 
# Returns       : $True / $False
# -----------------------------------------------------------------------------
Function New-SymLink {
	param(
		[string]$jPath = $(throw "You must provide a path where to create the Link"), 
		[string]$jTarget = $(throw "You must provide a path to target")
	)
	
	# Before we make any junction we have to test target
	# path exist
	If(Test-Path $jTarget) {
	
		# Create Link
		# Junctions need no admin rights, but can only point to local volumes
		$linkType = If(Test-NetworkPath $jTarget) { "/D" } Else { "/J" }
		cmd /c ("MKLINK {0} `"{1}`" `"{2}`"" -f $linkType, $jPath, $jTarget) | Out-Null
		Start-Sleep -Milliseconds 10
		
		# Test is present
		Return (Test-Path -Path $jPath)
		
	}
	Write-Output $False
}

# -----------------------------------------------------------------------------
# Function 		: New-RootDir
# -----------------------------------------------------------------------------
# Description	: This function creates a new randomly named root dir
#				  where all junctions will be created
# Parameters    : [string]rootPath - The name of the directory to remove
# Returns       : $True / $False
# -----------------------------------------------------------------------------
Function New-RootDir {

	# Create Root Directory and place a huge README.TXT
	New-Item -Path $BkRootDir -ItemType Directory | Out-Null
	If(!$?) { 
		Return ("Unable to create directory {0}. Check permissions." -f $BkRootDir)
	} Else {
		If([int]$MyContext.WinVer[0] -lt 6 ) {
			New-Item (Join-Path -Path $BkRootDir -ChildPath "__README__PLEASE__README__.txt") -type File -value "This directory contains Junctions.`nDO NOT DELETE THIS DIRECTORY AND IT'S CONTENTS USING WINDOWS EXPLORER.`nUse Junction -d to delete junctions and then safely delete the directory." | Out-Null
		} Else {
			New-Item (Join-Path -Path $BkRootDir -ChildPath "__README__PLEASE__README__.txt") -type File -value "This directory contains junctions or symbolic links.`nDO NOT DELETE THIS DIRECTORY AND IT'S CONTENTS USING WINDOWS EXPLORER.`nUse the RD command to delete the links and then safely delete the directory, use cmd /c rmdir <thesymlink'sname> in case of using Powershell." | Out-Null
		}
		If(!$?) {
			Return ("Can't write into {0}. Check permissions." -f $BkRootDir)
		}
	}
	
}

# -----------------------------------------------------------------------------
# Function 		: PostArchiving
# -----------------------------------------------------------------------------
# Description	: This routine reprocess succesfully archived files
# Parameters    : 
# Returns       : 
# -----------------------------------------------------------------------------
Function PostArchiving {
	
	Try {
		[console]::TreatControlCAsInput = $True
	} Catch {}
	# -----------------------------------------------------------
	# Remove created placeholders if any
	# -----------------------------------------------------------
	if ($Counters.PlaceHolders.count -gt 0) {
		Write-Progress -Activity  "Performing post archive operations" -Status "Please wait ..." -CurrentOperation "Removing Placeholders for Empty Directories"
		$Counters.PlaceHolders | Remove-Item -Force | Out-Null
		Write-Progress -Activity "." -Status "." -Completed
	}
	If(
		(Test-CtrlCRequest) -Or
		($BkDryRun)
	) { Return; }

	# Take the processed items from the finished archive, not from the "+ file"
	# lines 7-Zip prints while adding: a file 7-Zip fails to open (e.g. locked)
	# still gets a "+" line, but it is not stored in the archive
	If(Test-Variable "BkCompressDetailItems") { Remove-Variable -Name BkCompressDetailItems -Scope Script}
	$archiveToList = $BkDestFile
	If(!(Test-Path -LiteralPath $archiveToList -PathType Leaf)) { $archiveToList = "$BkDestFile.001" }
	$oListStartInfo = New-Object -TypeName System.Diagnostics.ProcessStartInfo
	$oListStartInfo.FileName = $Bk7ZipBin
	$oListStartInfo.Arguments = "l -slt -sccUTF-8 `"$archiveToList`""
	$oListStartInfo.RedirectStandardInput = (Test-Variable "BkArchivePassword")   # no -p: 7-Zip asks the password on its input when it needs it
	$oListStartInfo.RedirectStandardOutput = $True
	$oListStartInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
	$oListStartInfo.UseShellExecute = $False
	$oListStartInfo.CreateNoWindow = $True
	# .NET Framework puts a BOM before redirected input in a UTF-8 console: start with UTF-8 without BOM
	$savedInputEncoding = [Console]::InputEncoding
	If(Test-Variable "BkArchivePassword") { Try { [Console]::InputEncoding = New-Object System.Text.UTF8Encoding $False } Catch {} }
	Try { $oListProcess = [System.Diagnostics.Process]::Start($oListStartInfo) } Finally { Try { [Console]::InputEncoding = $savedInputEncoding } Catch {} }
	If(Test-Variable "BkArchivePassword") {
		$passwordBytes = (New-Object System.Text.UTF8Encoding $False).GetBytes($BkArchivePassword + "`r`n")
		$oListProcess.StandardInput.BaseStream.Write($passwordBytes, 0, $passwordBytes.Length)
		$oListProcess.StandardInput.Close()
	}
	# Read line by line: -slt prints about ten lines per item, too much for a single string
	# Entries follow the "----------" line. The "Path = " line above it is the archive itself
	$archivedItems = New-Object System.Collections.Generic.List[string]
	$listingEntries = $False
	While($null -ne ($listLine = $oListProcess.StandardOutput.ReadLine())) {
		If($listLine -eq "----------") { $listingEntries = $True }
		ElseIf($listingEntries -and $listLine.StartsWith("Path = ")) { $archivedItems.Add($listLine.Substring(7)) }
	}
	$oListProcess.WaitForExit()
	If($oListProcess.ExitCode -ne 0) {
		Trace (" WARNING : Could not list archive {0}. Post archive operations skipped`n" -f $archiveToList)
		$Counters.Warnings++
		Return
	}
	Set-Variable -Name "BkCompressDetailItems" -Value $archivedItems -Scope Script

	# Selected items not in the archive. Items 7-Zip reported while adding ($warningItems, filled by
	# the caller) are already logged with their reason: only silent misses are listed here
	$archivedPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
	foreach ($entry in $archivedItems) { [void]$archivedPaths.Add($entry) }
	$notArchived = New-Object System.Collections.Generic.List[string]
	foreach ($line in [System.IO.File]::ReadLines($BkCatalogInclude)) { If(!$archivedPaths.Contains($line) -and !($warningItems -and $warningItems[$line])) { $notArchived.Add($line) } }
	If($notArchived.Count -gt 0) {
		Trace " Selected items not in archive"
		Trace " ------------------------------------------------------------------------------"
		$notArchived | ForEach-Object { Trace " NOT ARCHIVED : $_"; $Counters.Warnings++ }
		Trace " "
	}
	If(($BkType -ne "move") -And !($BkClearBit)) { Return }
	
	If( !($BkCompressDetailItems) -Or
	    ($BkCompressDetailItems.Count -eq 0) -Or
		(Test-CtrlCRequest)
	) { Return }
	
	# Remove  or clear files successfully archived if necessary
	$MyContext.PostProcessFilesStart = Get-Date
	Set-Variable -Name "ArchivedItemsCount" -Value ($BkCompressDetailItems.Count) -Scope Local
	Set-Variable -Name "ItemsBatchSize" -Value ($ArchivedItemsCount / 100) -Scope Local
	Set-Variable -Name "ItemsCountDown" -Value ($ItemsBatchSize) -Scope Local
	Set-Variable -Name "ItemsDone" -Value 0 -Scope Local
	
	If($BkType -eq "move") {
		Set-Variable -Name "OperationType" -Value "Removing" -Scope Local
		Trace " Deleting Successfully Archived Files"
	} Else {
		Set-Variable -Name "OperationType" -Value "Clearing" -Scope Local
		Trace " Clearing Archive bit for Archived Files"
	}
	Trace " -------------------------------------------"
	
	$archiveAttr = [System.IO.FileAttributes]::Archive
	$readOnlyAttr = [System.IO.FileAttributes]::ReadOnly
	foreach ($entry in $BkCompressDetailItems) {
		If(Test-CtrlCRequest) { break; }

		# .NET calls, not Get-Item / Remove-Item: this loop runs once per archived item
		$path = [System.IO.Path]::Combine($BkRootDir, $entry)
		If([System.IO.File]::Exists($path) -or [System.IO.Directory]::Exists($path)) {
			Try {
				$attributes = [System.IO.File]::GetAttributes($path)
				If($BkType -eq "move") {
					# Folders are kept. Remove-Item -Force deleted read-only files, File.Delete does not
					If(!($attributes -band [System.IO.FileAttributes]::Directory)) {
						If($attributes -band $readOnlyAttr) { [System.IO.File]::SetAttributes($path, $attributes -bXOR $readOnlyAttr) }
						[System.IO.File]::Delete($path)
					}
				} ElseIf($attributes -band $archiveAttr) {
					# Not Set-ItemProperty: it rejects attributes like those of OneDrive files and reads [ ] in names as wildcards
					[System.IO.File]::SetAttributes($path, $attributes -bXOR $archiveAttr)
				}
			} Catch {
				Trace (" FAILED : {0}" -f $entry); $Counters.Warnings++
			}
		} Else {
			Write-Host (" ? " + $path)
		}

		$ItemsDone++
		$ItemsCountDown--
		If($ItemsCountDown -le 0) {
			$ItemsCountDown = $ItemsBatchSize
			Write-Progress -Activity  "Performing post archive operations" -Status "Please wait ..." -CurrentOperation ("{0} successfully archived files" -f $OperationType)  -PercentComplete ([int]($ItemsDone * 100 / $ArchivedItemsCount))
		}
	}
	
	Write-Progress -Activity "." -Status "." -Completed
	$MyContext.PostProcessFilesElapsed = (Get-Date) - $MyContext.PostProcessFilesStart
	Trace (" Phase time   : {0}" -f (Format-Elapsed $MyContext.PostProcessFilesElapsed))
	Trace (" Performance  : {0,0:n2} files/sec`n" -f ($ItemsDone / $MyContext.PostProcessFilesElapsed.TotalSeconds ) )
	
}

# -----------------------------------------------------------------------------
# Function 		: Add-Exclusion
# -----------------------------------------------------------------------------
# Description	: Records an item left out of the selection in the exclusions list
# Parameters    : [string]$rule - The rule which excluded the item
#                 [string]$kind - "F" for a file, "D" for a directory
#                 [string]$name - Real name of the item
# Returns       : --
# -----------------------------------------------------------------------------
Function Add-Exclusion ([string]$rule, [string]$kind, [string]$name) {
	$SWriters.Exclusions.WriteLine(("{0}`t{1}`t{2}`t{3}" -f $Counters.Exclusions++, $rule, $kind, $name))
}

# -----------------------------------------------------------------------------
# Function 		: Add-ScanException
# -----------------------------------------------------------------------------
# Description	: Records an error met while scanning or cleaning up an item
#				  in the exceptions list and traces its id
# Parameters    : $errorObject  - The error caught
#                 [string]$name - Real name of the item
# Returns       : --
# -----------------------------------------------------------------------------
Function Add-ScanException ($errorObject, [string]$name) {
	$id = $Counters.Exceptions++
	$SWriters.Exceptions.WriteLine(("{0}`t{1}`t{2}" -f $id, $errorObject.GetType().Name, $name))
	Trace (" Exception id {0} on {1} " -f $id, $name)
}

# -----------------------------------------------------------------------------
# Function 		: Trace-ScanProgress
# -----------------------------------------------------------------------------
# Description	: Shows what the selection scan is doing in a folder and how
#				  much it has selected so far (see Trace-Progress)
# Parameters    : $folder             - The folder being scanned
#                 [string]$operation  - What is being done
# Returns       : --
# -----------------------------------------------------------------------------
Function Trace-ScanProgress ($folder, [string]$operation) {
	Trace-Progress ("Folder {0}" -f $folder.RealName) $operation ("Selected {0,0:n0} out of {1,0:n0} files in {2,0:n0} folders. {3,0:n2} MBytes to backup" -f $Counters.FilesSelected, $Counters.FilesProcessed, $Counters.FoldersDone, ($Counters.BytesSelected / 1MB))
}

# -----------------------------------------------------------------------------
# Function 		: ProcessFolder
# -----------------------------------------------------------------------------
# Description	: This is the main scanning/selection routine.
#				  It's purpouse is to recurse all the folders below the 
#                 given root in search of files to backup
# Parameters    : [string]$folderPath - The name of the directory to scan
#                 [int]$depth - Depth level reached
# Returns       : $True / $False
# -----------------------------------------------------------------------------
Function ProcessFolder ($thisFolder) {

	Try {
		[console]::TreatControlCAsInput = $True
	} Catch {}
	# Increment number of processed folders
	$Counters.FoldersDone++
	
	# Status
	Trace-ScanProgress $thisFolder "Checking ... "
	
	# Verify wether or not we have to scan this folder for files or stop recursion due to regexp or maxdepth reached
	$scanThisPathForFiles = $True
	$scanThisPathForRecursion = $True
	If(($matchcleanupdirs) -and ($thisFolder.RelativeName -imatch $matchcleanupdirs)) {
		$scanThisPathForFiles = $False 
		$scanThisPathForRecursion = $False
		$folderToBeNuked = (Get-Item -LiteralPath $thisFolder.RelativeName -Force | Where-Object { $_.PSISContainer -eq $true -and -not ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) })
		If($folderToBeNuked) {
			If(!$BkDryRun) {
				Trace (" Removing D {0} " -f $thisFolder.RealName)
				# .NET deletes name the real error: Remove-Item in PowerShell 5.1 reports access denied as ArgumentException.
				# Directory.Delete refuses read-only items: clear the flag first, never through links (their targets are elsewhere)
				# It also fails on junctions inside: folder links are removed first, a non-recursive delete removes only the link
				$childDirRemoveError = $null
				Try {
					$foldersToClear = New-Object System.Collections.Stack
					$foldersToClear.Push($folderToBeNuked)
					While($foldersToClear.Count) {
						$folderToClear = $foldersToClear.Pop()
						If($folderToClear.Attributes -band [System.IO.FileAttributes]::ReadOnly) { $folderToClear.Attributes = $folderToClear.Attributes -bXOR [System.IO.FileAttributes]::ReadOnly }
						foreach ($item in $folderToClear.GetFileSystemInfos()) {
							If($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { If($item -is [System.IO.DirectoryInfo]) { $item.Delete() }; continue }
							If($item -is [System.IO.DirectoryInfo]) { $foldersToClear.Push($item) }
							ElseIf($item.Attributes -band [System.IO.FileAttributes]::ReadOnly) { $item.Attributes = $item.Attributes -bXOR [System.IO.FileAttributes]::ReadOnly }
						}
					}
					[System.IO.Directory]::Delete($folderToBeNuked.FullName, $True)
				} Catch { $childDirRemoveError = $_.Exception.GetBaseException() }
				If($childDirRemoveError) {
					Add-ScanException $childDirRemoveError $thisFolder.RealName
				}
			} Else {
				Trace (" Would remove {0} " -f $thisFolder.RealName)
			}
		}
		Return
	}
	If(($matchexcludepath) -and ($thisFolder.RelativeName -imatch $matchexcludepath)) {
		$scanThisPathForFiles = $False 
		Add-Exclusion "matchexcludepath" "D" $thisFolder.RealName
	}
	If((Test-Variable "BkMaxDepth") -and ($thisFolder.Depth -eq [int]$BkMaxDepth)) {
		$scanThisPathForRecursion = $False
		Add-Exclusion "maxdepth" "D" $thisFolder.RealName
	}
	If( ($scanThisPathForRecursion) -and (($matchstoprecurse) -and ($thisFolder.RelativeName -imatch $matchstoprecurse )) ) {
		$scanThisPathForRecursion = $False
		Add-Exclusion "matchstoprecurse" "D" $thisFolder.RealName
	}
	
	If(Test-CtrlCRequest) { return }
	# Early exit if we do not have to scan anything
	If(!$scanThisPathForFiles -and !$scanThisPathForRecursion) { return }
	
	# Get-ChildItems in folder
	# Status
	Trace-ScanProgress $thisFolder "Loading ... "
	
	# DirectoryInfo, not Get-ChildItem (about 27 us per listed item). It needs a full path: the process
	# directory is not the PowerShell location. An access error fails the whole folder, as before
	$childItems = @()
	$childItemsScanError = $null
	Try { $childItems = @(([System.IO.DirectoryInfo]([System.IO.Path]::Combine($BkRootDir, $thisFolder.RelativeName))).GetFileSystemInfos()) }
	Catch { $childItemsScanError = $_.Exception.GetBaseException() }
	If($childItemsScanError) {
		Add-ScanException $childItemsScanError $thisFolder.RealName
	}

	# Status
	Trace-ScanProgress $thisFolder "Scanning ... "
	
	# If it is an empty directory
	If($scanThisPathForFiles -and $scanThisPathForRecursion -and (!$childItems.Count) -and ($BkKeepEmptyDirs -eq $True) -and !($childItemsScanError)) {
		
		# Older versions of 7zip require at least one file to save a folder
		# Newer versions will simply create the folder
		If ([int]$MyContext.SevenZBinVersionInfo.Major -le 9) {	
			# Try to drop a placeholder file and reload child items
			$childFile = New-Item (Join-Path -Path $thisFolder.RelativeName -ChildPath $MyContext.DummyFile) -type File
			If($?) { 
				$Counters.PlaceHolders += $childFile
				$SWriters.Inclusions.WriteLine([string](Join-Path -Path $thisFolder.RelativeName -ChildPath $childFile.Name))
			}
			Return
		} Else {
			$SWriters.Inclusions.WriteLine([string]$thisFolder.RelativeName)
			Return
		}
	
	}
	
	# Process Files Within The Container
	If($scanThisPathForFiles) {
		foreach ($childFile in @($childItems | Where-Object { $_ -is [System.IO.FileInfo] })) {
			
			$Counters.FilesProcessed++
			
			$childFileRealName = [System.IO.Path]::Combine($thisFolder.RealName, $childFile.Name)

			# >>> Clean up files ?
			If(($matchcleanupfiles) -and ($childFile.Name -match $matchcleanupfiles)) {
				If(!$BkDryRun) {
					Trace (" Removing F {0} " -f $childFileRealName)
					# File.Delete names the real error (Remove-Item in PowerShell 5.1 reports access denied as ArgumentException). It refuses read-only files
					$childFileRemoveError = $null
					Try {
						If($childFile.Attributes -band [System.IO.FileAttributes]::ReadOnly) { $childFile.Attributes = $childFile.Attributes -bXOR [System.IO.FileAttributes]::ReadOnly }
						[System.IO.File]::Delete($childFile.FullName)
					} Catch { $childFileRemoveError = $_.Exception.GetBaseException() }
					If($childFileRemoveError) {
						Add-ScanException $childFileRemoveError $childFileRealName
						continue
					}
				} Else {
					Trace (" Would remove {0} " -f $childFileRealName)
				}
				# A cleaned up file must never be selected for the archive
				continue
			}
			# <<<

			# Archive Attribute : is it set as we need it ?
			If((($BkType -ieq "incr") -or ($BkType -ieq "diff")) -and !($childFile.Attributes -band [System.IO.FileAttributes]::Archive)) { 
				continue
			}
			
			# Match Include ?
			If(($matchincludefiles) -and ($childFile.Name -notmatch $matchincludefiles) ) { 
				Add-Exclusion "matchincludefiles" "F" $childFileRealName
				continue
			}
			
			# Match Exclude ?
			If(($matchexcludefiles) -and ($childFile.Name -match $matchexcludefiles) ) { 
				Add-Exclusion "matchexcludefiles" "F" $childFileRealName
				continue
			}

			# Check the file falls into MaxFileAge
			If(($BkMaxFileAge) -and (($MyContext.SelectionStart - $childFile.LastWriteTime).TotalDays -gt $BkMaxFileAge) ) {
				Add-Exclusion "maxfileage" "F" $childFileRealName
				continue
			}

			# Check the file falls into MinFileAge
			If(($BkMinFileAge) -and (($MyContext.SelectionStart - $childFile.LastWriteTime).TotalDays -lt $BkMinFileAge) ) {
				Add-Exclusion "minfileage" "F" $childFileRealName
				continue
			}

			# Check the file falls into MaxFileSize
			If(($BkMaxFileSize) -and ($childFile.Length -gt $BkMaxFileSize) ) {
				Add-Exclusion "maxfilesize" "F" $childFileRealName
				continue
			}

			# Check the file falls into MinFileSize
			If(($BkMinFileSize) -and ($childFile.Length -lt $BkMinFileSize) ) {
				Add-Exclusion "minfilesize" "F" $childFileRealName
				continue
			}

			# Update counters
			$Counters.FilesSelected++ ; 
			$Counters.BytesSelected += $childFile.Length ;
			$SWriters.Inclusions.WriteLine([System.IO.Path]::Combine($thisFolder.RelativeName, $childFile.Name))
			# Selection statistics by extension: files and bytes
			$extensionTotals = $Counters.Extensions[$childFile.Extension]
			If($extensionTotals) { $extensionTotals[0]++; $extensionTotals[1] += $childFile.Length } Else { $Counters.Extensions[$childFile.Extension] = @(1, [int64]$childFile.Length) }
			
			
		}
	}
	
	# Process Directories Within The Container
	If($scanThisPathForRecursion -And (!(Test-CtrlCRequest))) {
		# Queue children right after this folder, in order. Skipped junctions take no slot
		$insertAt = $catalogFoldersIndex + 1
		foreach ($childFolder in @($childItems | Where-Object { $_ -is [System.IO.DirectoryInfo] })) {

			$childFolderItem = @{}
			$childFolderItem.Name = $childFolder.Name
			$childFolderItem.FullName = $childFolder.FullName
			# Built from the parent: FullName may differ in case from $BkRootDir (e.g. lowercase --workdrive)
			$childFolderItem.RelativeName = $thisFolder.RelativeName + "\" + $childFolder.Name
			$childFolderItem.ContainerAlias = $thisFolder.ContainerAlias
			$childFolderItem.RealName = Join-Path -Path $BkSources[$thisFolder.ContainerAlias] -ChildPath ($childFolderItem.RelativeName.Substring($thisFolder.ContainerAlias.Length))
			$childFolderItem.Depth = ($thisFolder.Depth + 1);
			
			# Check subdir against recursion in junctions
			If(($BkNoFollowJunctions) -and ($childFolder.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
				Add-Exclusion "nofollowjunctions" "D" $childFolderItem.RealName
				continue
			}
			
			[void] $catalogFolders.Insert($insertAt++, $childFolderItem)
		}
	}
	
}

# -----------------------------------------------------------------------------
# Function 		: Remove-Junction
# -----------------------------------------------------------------------------
# Description	: Removes a Junction by the means of SysInternals' Junction.exe
# Parameters    : [string]jPath    - Full path to the name of the junction
# Returns       : $True / $False
# -----------------------------------------------------------------------------
Function Remove-Junction  {
	param([string]$jPath = $(throw "You must provide a path to the junction")) 

	# Check Junction Path exist otherwise we have nothing to unJunction
	If((Test-Path $jPath)) {

		# UnJunction it
		Invoke-Expression (('& "{0}" /accepteula -d "{1}"') -f $BkJunctionBin, $jPath) 
		Start-Sleep -Milliseconds 10
		
		# Test is no more present !!
		Return ((Test-Path -Path $jPath) -eq $False)
		
	}
	Write-Output $False
}

# -----------------------------------------------------------------------------
# Function 		: Remove-RootDir
# -----------------------------------------------------------------------------
# Description	: This function safely removes the Root Directory generated for
#				  the purpouse of holding junction points to included sources.
#				  Before it deletes the directory itself, each reparse point
#				  is removed using Junction with the -d switch.
# Parameters    : [string]rootPath - The name of the directory to remove
# Returns       : $True / $False
# -----------------------------------------------------------------------------
Function Remove-RootDir {
	param([string]$rootPath = $(throw "You must provide a path to the directory")) 
	
	Write-Debug "About to remove root-dir"
	
	If (Test-Path -Path $rootPath -PathType Container) {
		Set-Variable -Name "junctionsRemoved" -Value $True -Scope Private | Out-Null
		Get-ChildItem -Path $rootPath | Where-Object { $_.Attributes -band [System.IO.FileAttributes]::ReparsePoint } | ForEach-Object {
			If([int]$MyContext.WinVer[0] -lt 6) {
				$junctionsRemoved = Remove-Junction $_.FullName
				If(!$junctionsRemoved) {Return}
			} Else {
				$junctionsRemoved = Remove-SymLink $_.FullName
				If(!$junctionsRemoved) {Return}
			}
		}
		If($junctionsRemoved -And (@(Get-ChildItem -Path $rootPath | Where-Object {$_.PsIsContainer}).Count -eq 0) ) {
			Remove-Item -Path $rootPath -Recurse -Force | Out-Null
			Return $?
		}
	}
	Write-Output $False
	
}

# -----------------------------------------------------------------------------
# Function 		: Remove-SymLink
# -----------------------------------------------------------------------------
# Description	: Removes a Symbolic Link
# Parameters    : [string]jPath    - Full path to the name of the Link
# Returns       : $True / $False
# -----------------------------------------------------------------------------
Function Remove-SymLink  {
	param([string]$jPath = $(throw "You must provide a path to the Link")) 

	# Check Junction Path exist otherwise we have nothing to delete
	If((Test-Path -LiteralPath $jPath)) {
		
		# Remove the Link
		cmd /c ("RD `"{0}`"" -f $jPath)
		Start-Sleep -Milliseconds 10
		
		# Test is no more present !!
		Return ((Test-Path -LiteralPath $jPath) -eq $False)
		
	}
	Write-Output $False
}

# -----------------------------------------------------------------------------
# Function 		: Import-MailKit
# -----------------------------------------------------------------------------
# Description	: Loads MimeKit and MailKit from the given folder. Their
#				  dependencies are resolved from the same folder, whatever
#				  version they were built against
# Parameters    : [string]$folder - Folder holding MailKit.dll and its dependencies
# Returns       : $null when loaded, otherwise the reason
# -----------------------------------------------------------------------------
Function Import-MailKit {
	param([string]$folder)

	foreach ($name in "MimeKit", "MailKit") {
		If(!(Test-Path -LiteralPath (Join-Path $folder "$name.dll") -PathType Leaf)) { Return ("{0}.dll not found in {1}" -f $name, $folder) }
	}
	Try {
		# C#: a PowerShell script block as AssemblyResolve handler overflows the stack
		If(!("MailKitFolderResolver" -as [type])) {
			Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Reflection;
public static class MailKitFolderResolver {
	static string folder;
	public static void Register(string path) {
		if (folder == null) { AppDomain.CurrentDomain.AssemblyResolve += Resolve; }
		folder = path;
	}
	static Assembly Resolve(object sender, ResolveEventArgs e) {
		string file = Path.Combine(folder, new AssemblyName(e.Name).Name + ".dll");
		return File.Exists(file) ? Assembly.LoadFrom(file) : null;
	}
}
"@
		}
		[MailKitFolderResolver]::Register($folder)
		foreach ($name in "MimeKit", "MailKit") { [void][System.Reflection.Assembly]::LoadFrom((Join-Path $folder "$name.dll")) }
		Return $null
	} Catch {
		Return $_.Exception.GetBaseException().Message
	}
}

# -----------------------------------------------------------------------------
# Function 		: Get-MailKitSocketOption
# -----------------------------------------------------------------------------
# Description	: Chooses how MailKit secures the SMTP connection
# Parameters    : [int]$port - The SMTP port
#                 $ssl - Whether --smtpssl is set ($null when it is not)
# Returns       : "SslOnConnect" for port 465, else "StartTls" with --smtpssl,
#                 else "None" (same as SmtpClient)
# -----------------------------------------------------------------------------
Function Get-MailKitSocketOption {
	param([int]$port, $ssl)
	If($port -eq 465) { Return "SslOnConnect" }
	If($ssl) { Return "StartTls" }
	Return "None"
}

# -----------------------------------------------------------------------------
# Function 		: Send-MailKitNotification
# -----------------------------------------------------------------------------
# Description	: Sends the notification email with MailKit (see Import-MailKit)
#				  Same content as the SmtpClient path of Send-Notification
# Parameters    : None
# Returns       : --
# -----------------------------------------------------------------------------
Function Send-MailKitNotification {

	$message = New-Object MimeKit.MimeMessage
	$message.From.Add([MimeKit.MailboxAddress]::Parse($BkSmtpFrom))
	foreach ($address in @($BkNotifyLog))    { $message.To.Add([MimeKit.MailboxAddress]::Parse($address)) }
	foreach ($address in @($BkNotifyLogCc))  { If($address) { $message.Cc.Add([MimeKit.MailboxAddress]::Parse($address)) } }
	foreach ($address in @($BkNotifyLogBcc)) { If($address) { $message.Bcc.Add([MimeKit.MailboxAddress]::Parse($address)) } }
	$message.Subject = $BkMailSubject
	If(($Counters.Criticals -gt 0)) { $message.Subject = "Critical ! $BkMailSubject" }
	If(($Counters.Warnings -gt 0) -Or ($Counters.Criticals -gt 0)) { $message.Priority = [MimeKit.MessagePriority]::Urgent }

	$body = New-Object MimeKit.BodyBuilder
	$body.TextBody = $MyContext.Logger.ToString()
	If ($BkNotifyExtra -ne "none") {
		foreach ($file in Get-NotificationExtras) {
			If($BkNotifyExtra -ieq "attach") { [void]$body.Attachments.Add($file.FullName) }
			Else { $body.TextBody += ("`n`n{0}`n" -f $file.Name) + (Get-Content $file) }
		}
	}
	$message.Body = $body.ToMessageBody()

	$client = New-Object MailKit.Net.Smtp.SmtpClient
	Try {
		$client.Connect($BkSmtpRelay, $BkSmtpPort, [MailKit.Security.SecureSocketOptions](Get-MailKitSocketOption $BkSmtpPort $BkSmtpSSL))
		If((Test-Variable "BkSmtpUser") -and (Test-Variable "BkSmtpPass")) { $client.Authenticate($BkSmtpUser, $BkSmtpPass) }
		[void]$client.Send($message)
		$client.Disconnect($True)
	} Finally {
		$client.Dispose()
		$message.Dispose()
	}
}

# -----------------------------------------------------------------------------
# Function 		: Send-Notification
# -----------------------------------------------------------------------------
# Description	: Sends the notification email to given adressee
# Parameters    : None
# Returns       : $True / $False 
# -----------------------------------------------------------------------------
Function Send-Notification {

		Try {
			[console]::TreatControlCAsInput = $True
		} Catch {}
		
		Close-Writers

		# Do nothing if we have no-one to notify
		# Or we do not have enough info to issue the email
		If(!($BkNotifyLog)) { return; }
		If(!($BkSmtpFrom))  { return; }
		If(!($BkSmtpRelay)) { return; }
		If(!($BkSmtpPort))  { return; }
		
		Write-Host "`n Sending notification email ..."

		$MailMessage = $null
		
		Try {
		
			Set-DefaultVariable "BkMailSubject" ("7zBackup Report Host $Env:ComputerName")
			If(Test-Variable "BkMailKitPath") {
				Send-MailKitNotification
				Write-Host " Done`n " -ForeGroundColor Green
				Return
			}
			$SmtpClient = New-Object system.net.mail.smtpClient
			$MailMessage = New-Object system.net.mail.mailmessage
			
			$SmtpClient.Host = $BkSmtpRelay
			$SmtpClient.Port = $BkSmtpPort
			$SmtpClient.EnableSsl = ($BkSmtpSSL)

			# If we have both smtpuser and smtppass then we need to authenticate
			if ((Test-Variable "BkSmtpUser") -and (Test-Variable "BkSmtpPass")) {
				$SmtpUserInfo = New-Object System.Net.NetworkCredential($BkSmtpUser, $BkSmtpPass)
				$SmtpClient.UseDefaultCredentials = $False
				$SmtpClient.Credentials = $SmtpUserInfo
			}

			If(($Counters.Warnings -gt 0)) { $MailMessage.Priority = [System.Net.Mail.MailPriority]::High }
			If(($Counters.Criticals -gt 0)) { $MailMessage.Priority = [System.Net.Mail.MailPriority]::High; $BkMailSubject = "Critical ! $BkMailSubject" }
			$MailMessage.From = $BkSmtpFrom
			
			foreach ($address in @($BkNotifyLog)) { $MailMessage.To.Add($address) }
			If($BkNotifyLogCc)  { foreach ($address in @($BkNotifyLogCc))  { $MailMessage.Cc.Add($address) } }
			If($BkNotifyLogBcc) { foreach ($address in @($BkNotifyLogBcc)) { $MailMessage.Bcc.Add($address) } }

			$MailMessage.Subject = $BkMailSubject
			$MailMessage.Body = ($MyContext.Logger.ToString())
			
			# Do we have to include extra informations ?
			If ($BkNotifyExtra -ne "none") {

				foreach ($file in Get-NotificationExtras) {
					If($BkNotifyExtra -ieq "attach") {
						$MailAttachment = New-Object System.Net.Mail.Attachment($file.FullName)
						$MailAttachment.Name = $file.Name
						$MailMessage.Attachments.Add($MailAttachment)
					} Else {
						$MailMessage.Body += ("`n`n{0}`n" -f $file.Name)
						$MailMessage.Body += (Get-Content $file)
					}
				}
				
			}
			
			[void] $SmtpClient.Send($MailMessage) 
			Write-Host " Done`n " -ForeGroundColor Green
			
			} 
			
		Catch {
			Write-Host (" Unable to send notification email : {0} `n " -f $_.Exception.GetBaseException().Message ) -ForeGroundColor Red
			}
			
		Finally {
			If ($MailMessage) { $MailMessage.Dispose() }
		}

}

# -----------------------------------------------------------------------------
# Function 		: Test-Lock
# -----------------------------------------------------------------------------
# Description	: This function is used to check if a previous lock file exists
# Returns       : []
# -----------------------------------------------------------------------------
Function Test-Lock { 

	If(Test-Path -LiteralPath $BkLockFile -pathType Leaf) {

		# A previously executed script has left it's lock file
		$lock = @{}
		foreach ($line in @(Get-Content $BkLockFile -Encoding Ascii)) {
			$name, $value = $line -split "=", 2
			$lock[$name] = $value
		}
		$OldPid = $lock.PID; $OldStart = $lock.Start; $OldRoot = $lock.Root

		If ($OldPid) {

			# Same process id and same start time: the previous run is still active.
			# A reused process id has another start time. An unreadable start time
			# (e.g. elevated process) can not prove the lock is stale
			$OldProcess = Get-Process -Id $OldPid
			If (($OldProcess) -And ($OldPid -ne $PID)) {
				If (($null -eq $OldProcess.StartTime) -Or ($OldProcess.StartTime.ToUniversalTime().Ticks -eq $OldStart)) {
					Return ("A previous operation is running with process id {0}`n Quitting ...`n " -f $OldPid)
				}
			}

			# Stale lock: the previous run ended abnormally
			If(($OldRoot) -And (Test-Path -LiteralPath $OldRoot -PathType Container)) { Remove-RootDir $OldRoot | Out-Null }
			Remove-Item -LiteralPath $BkLockFile -Force | Out-Null
			If(!($?)) {
				Return ("Could not remove a previous lock file`n Quitting ...`n ")
			}
		} Else {
		
			If ((New-TimeSpan -End (Get-Date) -Start (Get-Item -LiteralPath $BkLockFile).LastWriteTime).TotalHours -gt 72) { 
			
				Remove-Item -LiteralPath $BkLockFile | Out-Null  
				If(!($?)) {
					Write-Output ("Could not remove a previous lock file")
					Write-Output ("Check lock file {0}" -f $BkLockFile )
					Return ("Quitting ...")
				}
				
			} Else {
				
				Write-Output ("A previous operation is running or has stopped abnormally")
				Write-Output ("Check lock file {0}" -f $BkLockFile )
				Write-Output ("Quitting ...")
				return
			
			}
		}

	} 
	
	# Drop a new lock file in place
	New-Item -Path $BkLockFile -ItemType File -Force | Out-Null
	If ($?) {("PID={0}`nStart={1}`nRoot={2}" -f [System.Diagnostics.Process]::GetCurrentProcess().Id, [System.Diagnostics.Process]::GetCurrentProcess().StartTime.ToUniversalTime().Ticks, $BkRootDir) | Out-File $BkLockFile -encoding ASCII -append }
	If(!($?)) {
		Return ("Could not write lock file`n Quitting ...`n ")
	}
	$MyContext.LockOwned = $True

}

# -----------------------------------------------------------------------------
# Function 		: Test-Path-Writable
# -----------------------------------------------------------------------------
# Description	: Checks a given path is writable
# Parameters    : [string]targetPath - Full path to the directory to test
# Returns       : $True / $False 
# -----------------------------------------------------------------------------
Function Test-Path-Writable {
	param([string]$testPath = $(throw "You must provide a path to test"),
	      [string]$testType = $(throw "You must provide a test item type")) 

	# Check Path Exist
	If(Test-Path -Path $testPath -PathType Container) {
	
		# Generate a dummy file name with a Guid
		$dummyItem = Join-Path $testPath ( [System.Guid]::NewGuid().ToString() )
		
		# Try to create new file in tested path
		if (( $testType -ieq "file" )) {
			New-Item $dummyItem -type File -force -value "This is only a test file. You can delete it safely." | Out-Null
		} Else {
			New-Item $dummyItem -type Directory -force | Out-Null
		}
		If ($?) {
			Remove-Item $dummyItem | Out-Null
			Return $?
		} Else { 
			Return $?
		}
		
	}
	Write-Output $False
}

# -----------------------------------------------------------------------------
# Function 		: Test-Variable
# -----------------------------------------------------------------------------
# Description	: This function is used to check if a variables name exist
#				  in the Variables scope
# Parameters    : [string]varName - The name of the Variable to test for
# Returns       : $True / $False
# -----------------------------------------------------------------------------
Function Test-Variable { 
	param([string]$varName = $(throw "You must provide a variable name"))
	$null -ne (Get-Variable -Name $varName -Scope Script -ErrorAction SilentlyContinue)
}

# -----------------------------------------------------------------------------
# Function 		: Set-DefaultVariable
# -----------------------------------------------------------------------------
# Description	: Sets a script variable unless it has already been set
# Parameters    : [string]$name - The name of the variable
#                 $value        - The default value
# Returns       : --
# -----------------------------------------------------------------------------
Function Set-DefaultVariable ([string]$name, $value) {
	If(!(Test-Variable $name)) { Set-Variable -Name $name -Value $value -Scope Script }
}

# -----------------------------------------------------------------------------
# Function 		: Resolve-Choice
# -----------------------------------------------------------------------------
# Description	: Finds a value among the allowed ones, ignoring case
# Parameters    : [string]$value     - The value to look for
#                 [string[]]$choices - The allowed values
# Returns       : The allowed value as spelled in $choices, or $null
# -----------------------------------------------------------------------------
Function Resolve-Choice ([string]$value, [string[]]$choices) {
	$choices | Where-Object { $_ -ieq $value } | Select-Object -First 1
}

# -----------------------------------------------------------------------------
# Function 		: Resolve-BooleanVariable
# -----------------------------------------------------------------------------
# Description	: Turns a script variable, if set, into a boolean. When it is
#				  not a valid boolean the variable is removed
# Parameters    : [string]$name         - The name of the variable
#                 [string]$errorMessage - What to report when it is not valid
# Returns       : The error message if any
# -----------------------------------------------------------------------------
Function Resolve-BooleanVariable ([string]$name, [string]$errorMessage) {
	If(!(Test-Variable $name)) { Return }
	$boolean = $False
	If([bool]::TryParse((Get-Variable -Name $name -Scope Script -ValueOnly), [ref]$boolean)) {
		Set-Variable -Name $name -Value $boolean -Scope Script
	} Else {
		Write-Output $errorMessage
		Remove-Variable -Name $name -Scope Script
	}
}

# -----------------------------------------------------------------------------
# Function 		: Resolve-IntegerVariable
# -----------------------------------------------------------------------------
# Description	: Turns a script variable, if set, into an integer within the
#				  given range. When it is not valid the variable is removed
# Parameters    : [string]$name         - The name of the variable
#                 [int64]$minimum       - Lowest valid value
#                 [int64]$maximum       - Highest valid value
#                 [string]$errorMessage - What to report when it is not valid
# Returns       : The error message if any
# -----------------------------------------------------------------------------
Function Resolve-IntegerVariable ([string]$name, [int64]$minimum, [int64]$maximum, [string]$errorMessage) {
	If(!(Test-Variable $name)) { Return }
	$number = [int64]0
	$valid = [int64]::TryParse((Get-Variable -Name $name -Scope Script -ValueOnly), [ref]$number)
	If($valid) {
		Set-Variable -Name $name -Value $number -Scope Script
		$valid = ($number -ge $minimum) -and ($number -le $maximum)
	}
	If(!$valid) {
		Write-Output $errorMessage
		Remove-Variable -Name $name -Scope Script
	}
}

# -----------------------------------------------------------------------------
# Function 		: Resolve-AddressList
# -----------------------------------------------------------------------------
# Description	: Keeps the valid email addresses of a script variable (a
#				  single address or a list). Invalid ones are reported as
#				  warnings. When none is left the variable is removed
# Parameters    : [string]$name  - The name of the variable
#                 [string]$label - The command line argument it comes from
# Returns       : --
# -----------------------------------------------------------------------------
Function Resolve-AddressList ([string]$name, [string]$label) {
	$addresses = @((Get-Variable -Name $name -Scope Script -ErrorAction SilentlyContinue).Value)
	$addresses | Where-Object {$_ -and !(IsValidEmailAddress $_)} | ForEach-Object { Trace (" Warning : Invalid {0} address {1} ignored" -f $label, $_); $Counters.Warnings++ }
	$valid = @($addresses | Where-Object {IsValidEmailAddress $_})
	If($valid.Count -gt 0) { Set-Variable -Name $name -Value $valid -Scope Script } Else { Remove-Variable -Name $name -Scope Script -ErrorAction SilentlyContinue }
}

# -----------------------------------------------------------------------------
# Function 		: Trace
# -----------------------------------------------------------------------------
# Description	: Outputs message to console and to logfile
# Parameters    : [string]$message  - The message to output
# Returns       : --
# -----------------------------------------------------------------------------
Function Trace ($message) {
	Write-Host ($message) 
	[void]$MyContext.Logger.AppendLine($message)
}

# -----------------------------------------------------------------------------
# Function 		: Format-Elapsed
# -----------------------------------------------------------------------------
# Description	: Formats a time span as "d : h : m : s" for the log
# Parameters    : [timespan]$span - The time span to format
# Returns       : [string]
# -----------------------------------------------------------------------------
Function Format-Elapsed ([timespan]$span) {
	"{0,0:n0} d : {1,0:n0} h : {2,0:n0} m : {3,0:n3} s" -f $span.Days, $span.Hours, $span.Minutes, ($span.Seconds + $span.Milliseconds / 1000)
}

# -----------------------------------------------------------------------------
# Function 		: Trace-Progress
# -----------------------------------------------------------------------------
# Description	: Write-Progress at most once every 500 ms. Each Write-Progress
#				  costs milliseconds and the scan calls this for every folder
# Parameters    : [string]$activity  - The progress activity
#                 [string]$operation - The current operation
#                 [string]$status    - The progress status
# Returns       : --
# -----------------------------------------------------------------------------
Function Trace-Progress ([string]$activity, [string]$operation, [string]$status) {
	If($MyContext.ProgressWatch -and ($MyContext.ProgressWatch.ElapsedMilliseconds -lt 500)) { Return }
	$MyContext.ProgressWatch = [System.Diagnostics.Stopwatch]::StartNew()
	Write-Progress -Activity $activity -CurrentOperation $operation -Status $status
}

# -----------------------------------------------------------------------------
# Function 		: ConvertTo-Limit
# -----------------------------------------------------------------------------
# Description	: Reads a size or age limit as its absolute value, always with
#				  en-US number format (the selection file uses "." for decimals)
# Parameters    : $value - The text to convert
#                 [bool]$integer - $True for an int64 size, $False for a double age
# Returns       : The number, or $null when the text is not valid
# -----------------------------------------------------------------------------
Function ConvertTo-Limit ($value, [bool]$integer) {
	$culture = [System.Globalization.CultureInfo]::CreateSpecificCulture("en-US")
	If($integer) { $number = [int64]0; $valid = [int64]::TryParse($value, [System.Globalization.NumberStyles]::Number, $culture, [ref]$number) }
	Else { $number = [double]0; $valid = [double]::TryParse($value, [System.Globalization.NumberStyles]::AllowDecimalPoint, $culture, [ref]$number) }
	If($valid) { [Math]::Abs($number) }
}

# -----------------------------------------------------------------------------
# Function 		: Read-SelectionDirectives
# -----------------------------------------------------------------------------
# Description	: Applies the "name=value" and flag directives of the selection
#				  file. They take precedence over command line values. When a
#				  directive is repeated the last one wins
# Parameters    : [string[]]$lines - The selection file lines (no comments)
# Returns       : --
# -----------------------------------------------------------------------------
Function Read-SelectionDirectives ([string[]]$lines) {
	# Valid: pattern the value must match. Decimal: "," is accepted as decimal separator
	$valueDirectives = @{
		maxdepth    = @{ Variable = "BkMaxDepth";           Valid = "^[0-9]" }
		rotate      = @{ Variable = "BkRotate";             Valid = "^[0-9]" }
		prefix      = @{ Variable = "BkArchivePrefix" }
		maxfilesize = @{ Variable = "BkMaxFileSize";        Valid = "^\d"; Decimal = $True }
		minfilesize = @{ Variable = "BkMinFileSize";        Valid = "^\d"; Decimal = $True }
		maxfileage  = @{ Variable = "BkMaxFileAge";         Valid = "^\d"; Decimal = $True }
		minfileage  = @{ Variable = "BkMinFileAge";         Valid = "^\d"; Decimal = $True }
		compression = @{ Variable = "BkArchiveCompression"; Valid = "^\d"; Decimal = $True }
		threads     = @{ Variable = "BkArchiveThreads";     Valid = "^\d"; Decimal = $True }
		solid       = @{ Variable = "BkArchiveSolid";       Valid = "^[01]$"; Convert = { $args[0] -eq "1" } }   # solid=0 turns it off, solid=1 on
	}
	$flagDirectives = @{ emptydirs = "BkKeepEmptyDirs"; nofollowjunctions = "BkNoFollowJunctions" }

	foreach ($line in $lines) {
		If($flagDirectives.ContainsKey($line)) { Set-Variable -Name $flagDirectives[$line] -Value $True -Scope Script; continue }
		If($line -notmatch "^(?<name>[^=]+)=(?<value>.*)$") { continue }
		$directive = $valueDirectives[$Matches.name]
		$value = $Matches.value
		If(!$directive -or ($directive.Valid -and ($value -notmatch $directive.Valid))) { continue }
		If($directive.Decimal) { $value = $value.Replace(",", ".") }
		If($directive.Convert) { $value = & $directive.Convert $value }
		Set-Variable -Name $directive.Variable -Value $value -Scope Script
	}
}

# -----------------------------------------------------------------------------
# Function 		: Read-MatchRule
# -----------------------------------------------------------------------------
# Description	: Reads the "name=regex" lines of the selection file into the
#				  script variable "name": all regexes joined by "|". The
#				  criteria are written to the log
# Parameters    : [string[]]$lines - The selection file lines (no comments)
#                 [string]$name - The rule name, also the variable name
#                 [string]$title - The log title
#                 [string]$bullet - The text before each regex in the log
#                 [string]$footer - The log text after the regexes
#                 [string]$emptyText - The log text when there is no regex
#                 [switch]$Always - Log the title also when there is no line
# Returns       : --
# -----------------------------------------------------------------------------
Function Read-MatchRule ([string[]]$lines, [string]$name, [string]$title, [string]$bullet, [string]$footer, [string]$emptyText, [switch]$Always) {
	$prefix = "$name="
	$rules = @($lines | Where-Object { $_.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) })
	If(!$rules -and !$Always) { Return }

	Trace "`n $title"
	Trace " ------------------------------------------------------------------------------"
	$regexes = @($rules | ForEach-Object { $_.Substring($prefix.Length).Trim() } | Where-Object { $_ })
	$regexes | ForEach-Object { Trace "$bullet$_" }
	If($regexes) { Set-Variable -Name $name -Value ($regexes -join "|") -Scope Script }
	ElseIf($emptyText) { Trace $emptyText }
	If($footer) { Trace "`n $footer" }
}

# -----------------------------------------------------------------------------
# Function 		: Assert-Arguments
# -----------------------------------------------------------------------------
# Description	: This function is used to check input arguments
# Parameters    : None
# Returns       : An array of error messages (if any)
# -----------------------------------------------------------------------------
Function Assert-Arguments {

	# Options followed by a value: argument -> variable ($null: value accepted and ignored)
	$valueArguments = @{
		'--type'             = 'BkType'
		'--workdir'          = 'BkWorkDir'
		'--workdrive'        = 'BkWorkDrive'
		'--selection'        = 'BkSelection'
		'--destpath'         = 'BkDestPath'
		'--archiveprefix'    = 'BkArchivePrefix'
		'--prefix'           = 'BkArchivePrefix'
		'--archivetype'      = 'BkArchiveType'
		'--compression'      = 'BkArchiveCompression'
		'--threads'          = 'BkArchiveThreads'
		'--solid'            = 'BkArchiveSolid'
		'--volumes'          = 'BkArchiveVolumes'
		'--archivepassword'  = 'BkArchivePassword'
		'--password'         = 'BkArchivePassword'
		'--rotate'           = 'BkRotate'
		'--maxdepth'         = 'BkMaxDepth'
		'--maxfileage'       = 'BkMaxFileAge'
		'--minfileage'       = 'BkMinFileAge'
		'--maxfilesize'      = 'BkMaxFileSize'
		'--minfilesize'      = 'BkMinFileSize'
		'--clearbit'         = 'BkClearBit'
		'--logfile'          = $null
		'--notify'           = 'BkNotifyLog'
		'--notifyto'         = 'BkNotifyLog'
		'--notifytoCc'       = 'BkNotifyLogCc'
		'--notifytoBcc'      = 'BkNotifyLogBcc'
		'--notifyfrom'       = 'BkSmtpFrom'
		'--notifyextra'      = 'BkNotifyExtra'
		'--smtpserver'       = 'BkSmtpRelay'
		'--smtpport'         = 'BkSmtpPort'
		'--smtpuser'         = 'BkSmtpUser'
		'--smtppass'         = 'BkSmtpPass'
		'--mailkitpath'      = 'BkMailKitPath'
		'--7zbin'            = 'Bk7ZipBin'
		'--7zipbin'          = 'Bk7ZipBin'
		'--jbin'             = 'BkJunctionBin'
		'--pre'              = 'BkPreAction'
		'--post'             = 'BkPostAction'
	}
	# Switches without a value: argument -> variable set to $True
	$switchArguments = @{
		'--encryptheaders'  = 'BkEncryptHeaders'
		'--emptydirs'       = 'BkKeepEmptyDirs'
		'--smtpssl'         = 'BkSmtpSSL'
		'--dry'             = 'BkDryRun'
	}

	for ($i = 0; $i -lt $BkArguments.Length; $i++) {
		$argument = [string]$BkArguments[$i]
		If($switchArguments.ContainsKey($argument)) {
			Set-Variable -Name $switchArguments[$argument] -Value $True -Scope Script
		} ElseIf($valueArguments.ContainsKey($argument)) {
			$i++
			If($valueArguments[$argument]) { Set-Variable -Name $valueArguments[$argument] -Value $BkArguments[$i] -Scope Script }
		} Else {
			Write-Output ("Unknown argument {0}" -f $argument)
		}
	}
}

# -----------------------------------------------------------------------------
# Function 		: Assert-Variables
# -----------------------------------------------------------------------------
# Description	: This function is used to check variables needed to execute
#				  the script.
# Parameters    : None
# Returns       : An array of error messages (if any)
# -----------------------------------------------------------------------------
Function Assert-Variables {

	# --------------------------------------------------------------------------------------------------------------------------
	# Environment - Checks
	# --------------------------------------------------------------------------------------------------------------------------
	# Check we're on Powershell 3.x. If not early exit.
	If($MyContext.PSVer -lt 2) {
		Return ("You must be on PowerShell 2.x (or better) to run this script. You're on {0}" -f $MyContext.PSVer)
	}

	# --------------------------------------------------------------------------------------------------------------------------
	# Clear Archive Bit Policy - Checks
	# --------------------------------------------------------------------------------------------------------------------------
	Resolve-BooleanVariable "BkClearBit" "Value $BkClearBit for --clearbit argument is not valid boolean value."
	
	# --------------------------------------------------------------------------------------------------------------------------
	# Backup Type - Checks
	# --------------------------------------------------------------------------------------------------------------------------
	# Each backup type clears the archive bit by default, or not
	$clearBitDefaults = @{ full = $True; incr = $True; diff = $False; copy = $False; move = $False }
	If(!(Test-Variable "BkType") -Or !$clearBitDefaults.ContainsKey([string]$BkType)) {
		Write-Output  "Missing or invalid --type argument"
	} Else {
		Set-DefaultVariable "BkClearBit" $clearBitDefaults[[string]$BkType]
		# The archive name is built from it: --type FULL gives the same name as --type full
		Set-Variable -Name BkType -Value ([string]$BkType).ToLowerInvariant() -Scope Script
	}

	# --------------------------------------------------------------------------------------------------------------------------
	# Work drive - Checks
	# --------------------------------------------------------------------------------------------------------------------------
	# If missing or set to "auto" we will assume drive letter for TEMP path.
	# If passed from command line arguments we have to check is a valid drive letter
	# and path is writable and, of course, is NTFS filesystem
	Set-DefaultVariable "BkWorkDrive" "auto"
	If($BkWorkDrive -ieq "auto") { Set-Variable -name BkWorkDrive -value ($Env:Temp).Substring(0,1) -scope Script }
	If (
		($BkWorkDrive -ieq "") -or
		($BkWorkDrive -is [array]) -or
		($BkWorkDrive -notmatch "^[C-Z]{1}$") -or
		((Test-Path ($BkWorkDrive + ":\")) -eq $False) -or
		((Test-Path-Writable ($BkWorkDrive + ":\") "Directory") -eq $False) -or
		((New-Object System.Io.DriveInfo($BkWorkDrive)).DriveFormat -ine "NTFS")
	)	{ Write-Output "Missing or invalid --workdrive argument. Must be writable NTFS drive" }
	
	# --------------------------------------------------------------------------------------------------------------------------
	# Selection file - Checks
	# --------------------------------------------------------------------------------------------------------------------------
	If (
		((Test-Variable "BkSelection") -eq $False) -or
		($BkSelection -match "^\s*$") -or
		((Test-Path $BkSelection -pathType Leaf) -eq $False)
	)	{ Write-Output "Missing or invalid --selection argument. Must be an existent file" } 
	Else 
	{
		
		# Resolve full name to file
		Set-Variable -name BkSelection -value ((Get-Item $BkSelection).FullName) -Scope Script
		
		# Try to load Selection Directives (if any)
		# Load all rows except comments and empty lines.
		Remove-Variable -name BkSelectionContents -scope Script 
		Set-Variable -name BkSelectionContents -scope Script -Value @(Get-Content $BkSelection | Where-Object {$_ -notmatch "^#|^\s*$"})
		
		# If we have no directive from selection then handle the error
		If(
			((Test-Variable "BkSelectionContents") -eq $False) -Or 
			($BkSelectionContents.Count -eq 0) -Or
			!(($BkSelectionContents | Where-Object {$_ -match "^includesource="}).Length -gt 0)
		) { Write-Output "Missing or invalid --selection argument: file does not contain any `"includesource`" directive" } 
		Else 
		{
				
			Read-SelectionDirectives $BkSelectionContents

		}
	}

	# --------------------------------------------------------------------------------------------------------------------------
	# Directives - Checks
	# --------------------------------------------------------------------------------------------------------------------------
	
	# Size and age limits: positive numbers; zero turns the filter off
	foreach ($limit in @(
		@{ Name = "maxfilesize"; Variable = "BkMaxFileSize"; Integer = $True;  Expected = "an integer" },
		@{ Name = "minfilesize"; Variable = "BkMinFileSize"; Integer = $True;  Expected = "an integer" },
		@{ Name = "maxfileage";  Variable = "BkMaxFileAge";  Integer = $False; Expected = "a valid number" },
		@{ Name = "minfileage";  Variable = "BkMinFileAge";  Integer = $False; Expected = "a valid number" }
	)) {
		If(!(Test-Variable $limit.Variable)) { continue }
		$number = ConvertTo-Limit (Get-Variable -Name $limit.Variable -Scope Script -ValueOnly) $limit.Integer
		If($null -eq $number) { Write-Output ("Missing or invalid {0} directive. Must be {1}" -f $limit.Name, $limit.Expected) }
		Else { Set-Variable -Name $limit.Variable -Value $number -Scope Script }
		If(!((Get-Variable -Name $limit.Variable -Scope Script -ValueOnly) -gt 0)) { Remove-Variable -Name $limit.Variable -Scope Script }
	}
	
	
	# --------------------------------------------------------------------------------------------------------------------------
	# Destination Path - Checks
	# --------------------------------------------------------------------------------------------------------------------------
	# Destination path given and existent
	If(
		!($BkDestPath) -Or
		($BkDestPath -match "^\s*$") -Or
		!(Test-Path $BkDestPath -pathType Container) -Or
		!(Test-Path-Writable $BkDestPath "File")
	) { 
		Write-Output ("Missing or invalid --destpath {0}." -f $BkDestPath) 
		Write-Output ("Ensure above path is reachable and writable")
	}
	
	# --------------------------------------------------------------------------------------------------------------------------
	# Archive Prefix - Checks
	# --------------------------------------------------------------------------------------------------------------------------
	# Check Archive Prefix does not contain unallowed chars
	If(
		!(Test-Variable "BkArchivePrefix") -Or
		($BkArchivePrefix -match "^\s*$") -Or
		(([string]$BkArchivePrefix).IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0)
	) { Write-Output "Missing or invalid --prefix argument" }

	# --------------------------------------------------------------------------------------------------------------------------
	# Archive Type - Checks
	# --------------------------------------------------------------------------------------------------------------------------
	Set-DefaultVariable "BkArchiveType" "7z"
	$archiveType = Resolve-Choice $BkArchiveType "7z", "zip", "tar"
	If($archiveType) { Set-Variable -Name BkArchiveType -Value $archiveType -Scope Script } Else { Write-Output "Missing or invalid --archivetype argument" }

	# --------------------------------------------------------------------------------------------------------------------------
	# Archive Compression - Checks
	# --------------------------------------------------------------------------------------------------------------------------
	If(Test-Variable "BkArchiveCompression") { 
		If ($BkArchiveCompression -notmatch "^0$|^1$|^3$|^5$|^7$|^9$") {
			Write-Output "Missing or invalid --compression argument"
		} Else {
			Set-Variable -Name BkArchiveCompression -Value ([int]$BkArchiveCompression) -Scope Script
		}
	}

	# --------------------------------------------------------------------------------------------------------------------------
	# Solid archive policy - Checks
	# --------------------------------------------------------------------------------------------------------------------------
	Set-DefaultVariable "BkArchiveSolid" $True
	Resolve-BooleanVariable "BkArchiveSolid" "Provided value for --solid argument is not valid boolean value."
	
	# --------------------------------------------------------------------------------------------------------------------------
	# Volumes archive policy - Checks
	# --------------------------------------------------------------------------------------------------------------------------
	If((Test-Variable "BkArchiveVolumes") -eq $True) {
		If(!($BkArchiveVolumes -is [array])) { $BkArchiveVolumes = @($BkArchiveVolumes) }
		$BkArchiveVolumes | ForEach-Object { If($_ -notmatch "^\d+[bkmg]\z") { Write-Output ("Missing or invalid --volumes argument {0} " -f $_) } }
	} 

	# --------------------------------------------------------------------------------------------------------------------------
	# Threading - Checks
	# --------------------------------------------------------------------------------------------------------------------------
	If(Test-Variable "BkArchiveThreads") { 
		If ($BkArchiveThreads -notmatch "^\d*$") {
			Write-Output "Missing or invalid --threads argument"
		} Else {
			Set-Variable -Name "BkArchiveThreads" -Value ([int]$BkArchiveThreads) -Scope Script
			Set-Variable -Name "tmpNumCores" -Value([int]0) -Scope Local
			
			# Check number of threads does not exceed number of available (logical) cores
			Get-CimInstance -ClassName Win32_Processor | ForEach-Object {
				If($_.NumberOfLogicalProcessors) {
					$tmpNumCores += [int]$_.NumberOfLogicalProcessors
				} 
				ElseIf($_.NumberOfCores) {
					$tmpNumCores += [int]$_.NumberOfCores
				}
				Else {
					$tmpNumCores ++
				}
			}
			If($BkArchiveThreads -gt $tmpNumCores) {
				Write-Output ("Missing or invalid --threads [{0}] argument. Must not exceed {1}" -f $BkArchiveThreads, $tmpNumCores)
			}
			Remove-Variable -Name "tmpNumCores"
		}
	}
	
	
	# --------------------------------------------------------------------------------------------------------------------------
	# Archive Rotation Policy - Checks
	# --------------------------------------------------------------------------------------------------------------------------
	Resolve-IntegerVariable "BkRotate" 1 ([int64]::MaxValue) "Missing or invalid --rotate argument. Must be positive integer"

	# --------------------------------------------------------------------------------------------------------------------------
	# Max Recursion Depth Policy - Checks
	# --------------------------------------------------------------------------------------------------------------------------
	# Max depth to honor while scanning
	Resolve-IntegerVariable "BkMaxDepth" 0 ([int64]::MaxValue) "Missing or invalid --maxdepth argument. Must be positive integer"

	# --------------------------------------------------------------------------------------------------------------------------
	# Email Notification - Checks
	# --------------------------------------------------------------------------------------------------------------------------
	If(Test-Variable "BkNotifyLog") {

		# ----------------------------------------------------------------------------------------------------------------------
		# To Email Address(es) - Checks
		# ----------------------------------------------------------------------------------------------------------------------
		Resolve-AddressList "BkNotifyLog" "--notify"
		If(!(Test-Variable "BkNotifyLog")) { Trace " Warning : No valid --notify address left: no notification will be sent"; $Counters.Warnings++ }

		# ----------------------------------------------------------------------------------------------------------------------
		# To CC Email Address(es) - Checks
		# ----------------------------------------------------------------------------------------------------------------------
		Resolve-AddressList "BkNotifyLogCc" "--notifyCc"

		# ----------------------------------------------------------------------------------------------------------------------
		# To BCC Email Address(es) - Checks
		# ----------------------------------------------------------------------------------------------------------------------
		Resolve-AddressList "BkNotifyLogBcc" "--notifyBcc"

		# ----------------------------------------------------------------------------------------------------------------------
		# From Email Addresses - Checks
		# ----------------------------------------------------------------------------------------------------------------------
		If(!(Test-Variable "BkSmtpFrom"))  { 
			Write-Output "Missing or invalid --notifyfrom argument" 
		} Else {
			If($BkSmtpFrom -is [array]) { Set-Variable -Name BkSmtpFrom -Value ($BkSmtpFrom -join "") -Scope Script }
			If(!(IsValidEmailAddress $BkSmtpFrom)) { 
				Write-Output ("Missing or invalid --notifyfrom argument. {0} is not a valid email address" -f $BkSmtpFrom) 
				Remove-Variable -Name BkSmtpFrom -Scope Script
			}
		}

		# ----------------------------------------------------------------------------------------------------------------------
		# Email info - Checks
		# ----------------------------------------------------------------------------------------------------------------------
		Set-DefaultVariable "BkNotifyExtra" "none"
		$notifyExtra = Resolve-Choice $BkNotifyExtra "none", "inline", "attach"
		If(!$notifyExtra) { Write-Output "Missing or invalid --notifyextra argument"; $notifyExtra = "none" }
		Set-Variable -Name BkNotifyExtra -Value $notifyExtra -Scope Script

		# ----------------------------------------------------------------------------------------------------------------------
		# Relay server - Checks
		# ----------------------------------------------------------------------------------------------------------------------
		If($BkSmtpRelay -is [array]) { Set-Variable -Name BkSmtpRelay -Value ($BkSmtpRelay -join "") -Scope Script }
		If(
			!(Test-Variable "BkSmtpRelay") -Or
			(!(IsValidHostName $BkSmtpRelay) -And !(IsValidIPAddress $BkSmtpRelay))
		) { 
			Write-Output "Missing or invalid --smtpserver argument" 
			Remove-Variable -Name BkSmtpRelay -Scope Script
		}

		# ----------------------------------------------------------------------------------------------------------------------
		# Relay server authentication - Checks
		# ----------------------------------------------------------------------------------------------------------------------
		If ( (Test-Variable "BkSmtpUser") -Or (Test-Variable "BkSmtpPass") ) {
			If (
				!(Test-Variable "BkSmtpUser") -Or
				!(Test-Variable "BkSmtpPass") -Or
				($BkSmtpUser -match "^\s*$") -Or
				($BkSmtpPass -match "^\s*$")
			) { 
				Write-Output "Missing or invalid --smtpuser or --smtppass argument" 
				Remove-Variable -Name BkSmtpUser -Scope Script
				Remove-Variable -Name BkSmtpPass -Scope Script
			}
		}

		# ----------------------------------------------------------------------------------------------------------------------
		# Relay server port - Checks
		# ----------------------------------------------------------------------------------------------------------------------
		If(!(Test-Variable "BkSmtpPort")) { Set-Variable -Name BkSmtpPort -Value ([int]25) -Scope Script }
		Else { Resolve-IntegerVariable "BkSmtpPort" 1 65535 "Provided value for --smtpPort argument is not valid. Must be a number [1-65535]." }

		# ----------------------------------------------------------------------------------------------------------------------
		# MailKit (optional) - Checks
		# ----------------------------------------------------------------------------------------------------------------------
		If(Test-Variable "BkMailKitPath") {
			$mailKitError = Import-MailKit $BkMailKitPath
			If($mailKitError) {
				Trace (" Warning : MailKit not loaded ({0}), using SmtpClient" -f $mailKitError); $Counters.Warnings++
				Remove-Variable -Name BkMailKitPath -Scope Script
			}
		}
	
	}

	# --------------------------------------------------------------------------------------------------------------------------
	# 7z.exe binary - Checks
	# --------------------------------------------------------------------------------------------------------------------------
	If(!(Test-Variable "Bk7ZipBin")) { 
		If(Test-Path -Path (Join-Path -Path ${Env:ProgramFiles} -ChildPath "\7-Zip\7z.exe") -PathType Leaf) { Set-Variable -Name Bk7ZipBin -value (Join-Path -Path ${Env:ProgramFiles} -ChildPath "\7-Zip\7z.exe") -scope Script}
		If(Test-Path -Path (Join-Path -Path ${Env:ProgramFiles(x86)} -ChildPath "\7-Zip\7z.exe") -PathType Leaf) { Set-Variable -Name Bk7ZipBin -value (Join-Path -Path ${Env:ProgramFiles(x86)} -ChildPath "\7-Zip\7z.exe") -scope Script}
	}
	If(
		!(Test-Variable "Bk7ZipBin") -Or
		($Bk7ZipBin -match "^\s*$") -Or
		!(Test-Path -Path $Bk7ZipBin -pathType Leaf)
	) { Write-Output "Missing or invalid --7zipbin argument" }
	Else 
	{
		$MyContext.SevenZBinVersionInfo = @{}
		Get-Item -Path $Bk7ZipBin | ForEach-Object {
			$MyContext.SevenZBinVersionInfo.ProductVersion = $_.VersionInfo.ProductVersion.ToString()
			$MyContext.SevenZBinVersionInfo.Major = $_.VersionInfo.ProductVersion.ToString().Split(".")[0]
			$MyContext.SevenZBinVersionInfo.Minor = $_.VersionInfo.ProductVersion.ToString().Split(".")[1]
		}
	}

	# --------------------------------------------------------------------------------------------------------------------------
	# Junction.exe binary - Checks
	# --------------------------------------------------------------------------------------------------------------------------
	# On Vista / 7 / 2008 native MKLINK is used instead
	If([int]$MyContext.WinVer[0] -lt 6) {

		If(!(Test-Variable "BkJunctionBin")) { 
			${Env:ProgramFiles}, ${Env:ProgramFiles(x86)} | ForEach-Object {
				If(Test-Path -Path (Join-Path -Path $_ -ChildPath "\SysInternalsSuite\junction.exe") -PathType Leaf) {
				Set-Variable -Name BkJunctionBin -value  (Join-Path -Path $_ -ChildPath "\SysInternalsSuite\junction.exe") -scope Script
				}
			}
		}
	
		If(
			!(Test-Variable "BkJunctionBin") -Or
			($BkJunctionBin -match "^\s*$") -Or
			!(Test-Path -Path $BkJunctionBin -pathType Leaf)
		) 
			{ Write-Output "Missing or invalid --jbin argument" }
	}
	
}

# ====================================================================
# End Functions Library
# ====================================================================
# Start Script Flow Here
# ====================================================================

# This will prevent unhandled exit from the script
Try {
	[console]::TreatControlCAsInput = $False
} Catch {}

# Clean all script scoped variables beginning with "Bk" and "match"
Get-ChildItem variable:script:Bk* | Remove-Variable | Out-Null
Get-ChildItem variable:script:match* | Remove-Variable | Out-Null

# --------------------------------------------------------------------
# Initialize script scoped hashes 
# --------------------------------------------------------------------
Set-Variable -Name Counters -Value @{} -Scope Script
Set-Variable -Name SWriters -Value @{} -Scope Script

$Counters.Exclusions = 0
$Counters.Warnings = 0
$Counters.Exceptions = 0
$Counters.Criticals = 0
$Counters.FoldersDone = 0
$Counters.Extensions = @{}
$Counters.FilesProcessed = 0
$Counters.FilesSelected = 0
$Counters.BytesSelected = [int64]0
$Counters.BytesAvailable = [int64]0
$Counters.PlaceHolders = @()

# Output Header Text
Trace $headerText

# Check For the presence of "--help" argument switch
If($args.length -ne 0) { 
	switch -wildcard ($args) { "*--help*" {Trace $helpText ; Try {[console]::TreatControlCAsInput = $False} Catch{} ; Return} }
} 

# Import hard coded variables if present -vars.ps1 script
Set-Variable -name BkVarsImportScript -value (Join-Path $MyContext.Directory $MyContext.Name.Replace(".ps1", "-vars.ps1")) -scope Script
If((Test-Path $BkVarsImportScript -pathType Leaf )) {
	Try { & $BkVarsImportScript }
	Catch {
		Trace ("{0} reports an error thus has not been parsed" -f $BkVarsImportScript)
	}
}

Set-Variable -Name hasErrors -Value $False -Scope Script
Set-Variable -Name BkArguments -Value $args -Scope Script

Assert-Arguments | ForEach-Object { $hasErrors = $True; Trace " Err : $_" }
Assert-Variables | ForEach-Object { $hasErrors = $True; Trace " Err : $_" }
If($hasErrors) { Trace ("`n Try .\{0} --help `n" -f $MyInvocation.MyCommand.Name); $Counters.Criticals = 1; Send-Notification; Return }


# --------------------------------------------------------------------
# Do compose names
# --------------------------------------------------------------------
Set-Variable -Name BkArchiveName -Value ($BkArchivePrefix + "-" + $BkType + "-" + (Get-Date -format "yyyyMMdd-HHmmss") + "." + $BkArchiveType) -Scope Script
Set-Variable -Name BkRootDir     -Value ($BkWorkDrive + ":\~" + ([System.Guid]::NewGuid().ToString().Split("-")[1])) -Scope Script
Set-Variable -Name BkLockFile    -Value (Join-Path $Env:Temp ($MyContext.Name.Substring(0, ($MyContext.Name.LastIndexOf("."))) + ".lock")) -scope Script
Set-Variable -Name BkSources     -Value @{} -Scope Script

Test-Lock | ForEach-Object { $hasErrors = $True; Trace " Err : $_" }
New-RootDir | ForEach-Object { $hasErrors = $True; Trace " Err : $_" }
Test-CtrlCRequest | Out-Null

If($hasErrors) { 
	If(!($MyContext.Cancelling)) {
		Invoke-PostAction
		Send-Notification 
	}
	Clear-Script
	Return 
}

# --------------------------------------------------------------------------------
# Execute pre Action if we have any (It may create directories we have to archive
# --------------------------------------------------------------------------------
If(Test-Variable "BkPreAction") {

	Trace " Invoking Pre-Action (Output follows if any)"
	Trace " ------------------------------------------------------------------------------"
	Try {
		& $BkPreAction 2>&1 | Set-Variable -Name preActionOutput -Scope Script
		$preActionOutput | ForEach-Object {
			Trace " $_"
		}
	} Catch {
		Trace (" {0}" -f $_.Exception.Message)
	}
	Trace " ------------------------------------------------------------------------------"
	Trace " "
	
}


# Initalize Operations
# Output all running context informations
Trace " Started on ........ :  $((Get-Date -f "MMM dd, yyyy hh:mm:ss"))"
Trace " Backup Type ....... :  $BkType"
If($BkClearBit -eq $True)    { Trace " Files' Archive attr :  Will be cleared" } Else { Trace " Files' Archive attr :  Will stay unchanged" }
Trace " Selection File .... :  $BkSelection"
If(Test-Variable "BkMaxDepth") { Trace " Recursion Depth ... :  $BkMaxDepth" }
If($BkNoFollowJunctions) {Trace " Reparse points .... :  Will NOT be followed" }
Trace " Destination ....... :  $BkDestPath"
Trace " Archive Name ...... :  $BkArchiveName"
Trace " Archive Type ...... :  $BkArchiveType"
If((Test-Variable "BkRotate")) { Trace " Rotation policy ... :  Keep last $BkRotate archive(s) " } Else { Trace " Rotation policy ... :  Keep all archive(s) " }
Trace (" 7zip binary ....... :  {0} (ver. {1}) " -f $Bk7zipBin,$MyContext.SevenZBinVersionInfo.ProductVersion)
Trace (" 7zip threading .... :  {0} " -f ( & { If(Test-Variable "BkArchiveThreads") { Write-Output "$BkArchiveThreads threads" } Else { Write-Output "Auto"}   }))
If(Test-Variable "BkArchiveCompression") { Trace " 7zip Compression .. :  $BkArchiveCompression" } Else { Trace " 7zip Compression .. :  Auto" }
Trace " "
Trace " ------------------------------------------------------------------------------"

Trace " Backup From Sources   "
Trace " ------------------------------------------------------------------------------"
# --------------------------------------------------------------------
# Read the contents of selection file and create a junction for each one 
# --------------------------------------------------------------------

$BkSelectionContents | Where-Object {$_ -imatch "^includesource=(.*)\|alias=(.*)"} | ForEach-Object {
	
	$directiveLine=[string]$_
	$directiveParts = $directiveLine.split("|", [System.StringSplitOptions]::RemoveEmptyEntries)
	$target = $directiveParts[0].Split("=")[1]
	$alias  = $directiveParts[1].Split("=")[1]
	
	# Trace the selection
	Trace " + $alias <== $Target"
	
	# Check target exist
	If(!(Test-Path $target -pathType Container)) { 
		Trace "   Selection directory $target does not exist. Skipping "
	} Else {
		
		# Check alias is not already in use
		If((Test-Path (Join-Path $BkRootDir $alias))) {
			Trace "   Alias $alias already in use. Skipping selection of $target"
		} Else {
			
			If([int]$MyContext.WinVer[0] -lt 6 ) { 
				# Create the new junction for Windows previous to vista
				If(!(New-Junction (Join-Path -Path $BkRootDir -ChildPath $alias) $target)) { Trace "   Failed to create Junction [$alias] to [$target]"} Else { $BkSources.Add($alias, $target) }
			} Else {
				# Create the link for Windows Vista or newer: a junction for a local target
				If(!(New-SymLink (Join-Path -Path $BkRootDir -ChildPath $alias) $target)) { Trace "   Failed to create link [$alias] to [$target]"} Else { $BkSources.Add($alias, $target) }
			}
			
		}
		
	}
}

# --------------------------------------------------------------------
# Check we have at least one directory alias to backup 
# --------------------------------------------------------------------
If(( $BkSources.Count -eq 0 )) {
	Trace "   There are no selectable sources to backup. Quitting"
	If(!($MyContext.Cancelling)) { 
		Invoke-PostAction
		Send-Notification 
	}
	Clear-Script
	Return
}  Else {
	Trace " "
}

# --------------------------------------------------------------------
# Read the regular expression criteria
# --------------------------------------------------------------------
Read-MatchRule $BkSelectionContents "matchcleanupdirs" "Remove Directories Criteria" " + Regex : " "All directories matching the above listed regular expressions will be deleted !!!"
Read-MatchRule $BkSelectionContents "matchcleanupfiles" "Remove Files Criteria" " + Regex : " "All files matching the above listed regular expressions will be deleted !!!"
Read-MatchRule $BkSelectionContents "matchincludefiles" "Files Inclusion Criteria" " + Regex : " "" " + Any file name " -Always

# --------------------------------------------------------------------
# Check we have max/min fileage to honor
# --------------------------------------------------------------------
If (Test-Variable "BkMaxFileAge") { Trace " + Max File Age : $BkMaxFileAge days" }
If (Test-Variable "BkMinFileAge") { Trace " + Min File Age : $BkMinFileAge days" }

# --------------------------------------------------------------------
# Check we have max/min filesize to honor
# --------------------------------------------------------------------
If (Test-Variable "BkMaxFileSize") { Trace " + Max File Size : $BkMaxFileSize bytes" }
If (Test-Variable "BkMinFileSize") { Trace " + Min File Size : $BkMinFileSize bytes" }

Read-MatchRule $BkSelectionContents "matchexcludefiles" "Files Exclusion Criteria" " - Regex : " "All files matching the above listed regular expressions `n WILL NOT BE INCLUDED IN BACKUP !!!" " None "
Read-MatchRule $BkSelectionContents "matchexcludepath" "Exclude Paths Criteria" " -match " "All directories matching the above listed regular expressions `n WILL NOT BE INCLUDED IN BACKUP !!!" " None "
Read-MatchRule $BkSelectionContents "matchstoprecurse" "Stop Recursion Criteria" " -match " "All directories matching the above listed regular expressions `n WILL NOT BE RECURSED !!!" " None "

# --------------------------------------------------------------------
# Move to the $BkRootDir and make it current
# --------------------------------------------------------------------
Set-Location -path $BkRootDir 

# --------------------------------------------------------------------
# Let's drop into $BkRootDir a few files which will contain useful 
# information in case you want to examine the contents of an archive
# and how it's been generated.
# --------------------------------------------------------------------
$BkSelectionInfo  = Join-Path $BkRootDir "Selection-Info.txt" ; New-Item $BkSelectionInfo  -type File -Force -value ([string]::join([environment]::newline, (Get-Content -path $BkSelection -encoding ASCII))) | Out-Null
$BkSelectionExcpt = Join-Path $BkRootDir "Selection-Excpt.csv"; New-Item $BkSelectionExcpt -type File -Force | Out-Null; "Id`tException`tTarget" | Out-File $BkSelectionExcpt -encoding ASCII -append
$BkCatalogInclude = Join-Path $BkRootDir "Catalog-Include.txt"; New-Item $BkCatalogInclude -type File -Force | Out-Null
$BkCatalogExclude = Join-Path $BkRootDir "Catalog-Exclude.csv"; New-Item $BkCatalogExclude -type File -Force | Out-Null; "Id`tDirective`tType`tTarget" | Out-File $BkCatalogExclude -encoding ASCII -append
$BkCompressDetail = Join-Path $BkRootDir "Compress-Detail.txt"; New-Item $BkCompressDetail -type File -Force | Out-Null

# --------------------------------------------------------------------
# Open StreamWriters for optimize performance. 
# Out-File and Add-Content are rubbish and cause the selection to be
# up to 20x slower
# --------------------------------------------------------------------
$SWriters.Inclusions = New-Object -TypeName System.IO.StreamWriter($BkCatalogInclude, [String]$True, [System.Text.Encoding]::UTF8)
$SWriters.Exclusions = New-Object -TypeName System.IO.StreamWriter($BkCatalogExclude, [String]$True, [System.Text.Encoding]::ASCII)
$SWriters.Exceptions = New-Object -TypeName System.IO.StreamWriter($BkSelectionExcpt, [String]$True, [System.Text.Encoding]::ASCII)
$SWriters.GetEnumerator() | ForEach-Object { $_.Value.AutoFlush = $True }

Trace " "
Trace " Scanning Directories and Files ..."
Trace " ------------------------------------------------------------------------------"

# Begin the processing of the root folder to build up the catalogs and start counting elapsed time
$MyContext.SelectionStart = Get-Date

# Look-up for the folders (which are junctions) in the Root Folder
Set-Variable -Name catalogFolders -value (New-Object System.Collections.ArrayList) -scope Script
Set-Variable -Name catalogFoldersIndex -value ([int]0) -scope Script
$BkSources.GetEnumerator() | ForEach-Object {
	
	$itemFolder = @{}
    $itemFolder.Name = $_.Name
	$itemFolder.FullName = Join-Path -Path $BkRootDir -ChildPath $_.Value
    $itemFolder.RelativeName = $_.Name
	$itemFolder.ContainerAlias = $_.Name
	$itemFolder.RealName = Join-Path -Path $BkSources[$itemFolder.ContainerAlias] -ChildPath ($itemFolder.RelativeName.Replace($itemFolder.ContainerAlias, ""))
    $itemFolder.Depth = 0;
	[void] $catalogFolders.Add($itemFolder)
	
}

# Walk through catalogFolders to process each one
While ($True) {
	If(Test-CtrlCRequest) {break}
	ProcessFolder $catalogFolders[$catalogFoldersIndex] | Out-Null
	If (!(++$catalogFoldersIndex -lt $catalogFolders.Count)) {Write-Progress -Activity "." -Status "." -Completed; break}
}
If($MyContext.Cancelling) {
	Clear-Script
	Return 
}

# Add Support Files to archive selection 
If($Counters.FilesSelected -gt 0) {
	Get-ChildItem -Path $BkRootDir -Force | Where-Object {!$_.PSIsContainer} | ForEach-Object {
		if(	
			($_.Name -notmatch "stats") -And
			($_.Name -notmatch "README") -And
			($_.Name -notmatch "^Compress-Detail\.txt$")
		) {
			$Counters.FilesSelected++ ; 
			$Counters.BytesSelected += $_.Length ;
			$SWriters.Inclusions.WriteLine($_.Name)
			$extensionTotals = $Counters.Extensions[$_.Extension]
			If($extensionTotals) { $extensionTotals[0]++; $extensionTotals[1] += $_.Length } Else { $Counters.Extensions[$_.Extension] = @(1, [int64]$_.Length) }
		}
	}
}

# Include non existent file
# $SWriters.Inclusions.WriteLine("qwerty.txt")

# --------------------------------------------------------------------
# Close StreamWriters letting enough time to flush buffers
# --------------------------------------------------------------------
$SWriters.GetEnumerator() | ForEach-Object { 
	$_.Value.Flush()
	If($_.Name -notmatch "^Log$") {$_.Value.Close()} 
} -End { Start-Sleep -Milliseconds 500 }


# Calc of elapsed time for selection process
$MyContext.SelectionElapsed = (Get-Date) - $MyContext.SelectionStart

# Trace informations about what is selected
Trace (" Phase time   : {0}" -f (Format-Elapsed $MyContext.SelectionElapsed))
Trace (" Selected     : {0,0:n0} out of {1,0:n0} files in {2,0:n0} folders. {3,0:n2} MBytes to backup" -f  $Counters.FilesSelected, $Counters.FilesProcessed, $Counters.FoldersDone, ($Counters.BytesSelected/1mb))
Trace (" Performance  : {0,0:n2} files/sec " -f ( $Counters.FilesProcessed / $MyContext.SelectionElapsed.TotalSeconds ) )


# Early exit from the process if user cancel or there is nothingto backup
If(($Counters.FilesSelected -lt 1) -or (Test-CtrlCRequest)) {

	# Trace we have not selected anything to backup
	Trace " "
	Trace " There are no files matching the selection criteria. Possible reasons: "
	Trace " - All source directories are empty and choose not to keep them"
	Trace " - No file match selection criteria"
	Trace " - User Cancel Request (CTRL+C)"
	Trace " "

	If(!($MyContext.Cancelling)) { 
		Invoke-PostAction
		Send-Notification 
	}
	Clear-Script
	Return 
	
}

	# Adjust at least 1byte selected (in case all files are zero length)
	# This will prevent division by zero errors
	If(($Counters.BytesSelected -lt 1)) { $Counters.BytesSelected = 1 }

	
	# Maybe there has been some exceptions during the selection progress. 
	# If this is the case output them here.
	$selectionExceptions = @(Get-Content $BkSelectionExcpt | Select-Object -Skip 1)   # first line is the header
	If($selectionExceptions.Count -gt 0) {
		Trace "`n Exceptions during selection process"
		Trace " ------------------------------------------------------------------------------"
		$selectionExceptions | ForEach-Object {
		Trace (" {0} " -f $_); $Counters.Warnings++
		}
	}
	
	If(!(Test-CtrlCRequest)) {
		# Do some stats (many thanks to http://www.hanselman.com/blog/ParsingCSVsAndPoorMansWebLogAnalysisWithPowerShell.aspx)
		Write-Progress -Activity "Calculating Stats on Selection" -Status "Running ..." -CurrentOperation "Please Wait ..."
		$statsByExtension = $Counters.Extensions.GetEnumerator() | Select-Object @{Name="Name";Expression={$_.Key}}, @{Name="Count";Expression={$_.Value[0]}}, @{Name="Size";Expression={$_.Value[1]}} | Sort-Object Size -desc
		Write-Progress -Activity "." -Status "." -Completed
		
		# Output summarized data
		Trace " "
		Trace " Selection Details"
		Trace " ------------------------------------------------------------------------------"
		Trace " Extension                              Count          Total MB  Abs %   Inc % "
		Trace " -------------------------------  ----------- ----------------- ------- -------"
		$totalCount = 0; [int64]$totalBytes = 0
		$statsByExtension | ForEach-Object {
		$totalCount += $_.Count ; $totalBytes += $_.Size
		Trace (" {0,-31} {1,11:n0} {2,17:n2}  {3,6:n2}  {4,6:n2}" -f $_.Name, $_.Count, ($_.Size/1MB), ($_.Size/ $Counters.BytesSelected * 100), ($totalBytes / $Counters.BytesSelected * 100))
		}
		Trace "                                  ----------- ----------------- "
		Trace (" {0,-31} {1,11:n0} {2,17:n2}" -f "Total", $totalCount, ($totalBytes/1MB))
		Trace "                                  =========== ================= `n"
		

	}
	
	
	If($BkDryRun -ne $True) {

		# Check we have enough disk space available on target path
		$Counters.BytesAvailable = ([int64](GetDestPathFreeSpace -target $BkDestPath))
		If($Counters.BytesAvailable -lt ($totalBytes * 1)) {
			Trace (" Warning !! ... you're low on space on target ")
			Trace (" {0,-31} {1,17:n2}" -f " Required Max..............", ($totalBytes/1MB))
			Trace (" {0,-31} {1,17:n2}" -f " Available  ...............", ($Counters.BytesAvailable/1MB))
			Trace (" If 7zip cannot compress enough it will fail `n")
		}

	
		$BkDestFile = (Join-Path -Path $BkDestPath -ChildPath $BkArchiveName)
		Write-Progress -Activity "Archiving into $BkDestFile" -Status "Please wait ..." -CurrentOperation "Initializing ..."	

		# Compose arguments which will be passed to command line
		$Bk7ZipArgs = @("a", "-ssw", "-slp")												# Add and update, archive files open for writing, large memory pages
		If((Test-Variable "BkArchiveCompression") -And ($BkArchiveType -ne "tar")) { $Bk7ZipArgs += "-mx$BkArchiveCompression" }
		# Charset for list files and for console input/output (password input, output decoding) is UTF-8. -bd disables the progress indicator
		$Bk7ZipArgs += "-scsUTF-8", "-sccUTF-8", "-bd"
		
		# If 7zip is beyond version 9.2 then add some more switches
		If ([int]$MyContext.SevenZBinVersionInfo.Major -ge 15) {
			$Bk7ZipArgs += "-bb1", "-bsp0", "-bso1", "-bse2"
			If($BkArchiveType -eq "7z") { $Bk7ZipArgs += "-mtm=on", "-mtc=on", "-mta=on" }		# Store modified, creation and access timestamps
		}
		
		# Control Threading
		If(Test-Variable "BkArchiveThreads") {
			If($BkArchiveThreads -lt 1) { $Bk7ZipArgs += "-mmt=off" } Else { $Bk7ZipArgs += "-mmt=$BkArchiveThreads" }
		}
		
		# Control solid archives and volumes
		If(($BkArchiveType -eq "7z") -And !($BkArchiveSolid)) { $Bk7ZipArgs += "-ms=off" }
		If(Test-Variable "BkArchiveVolumes") { $Bk7ZipArgs += @($BkArchiveVolumes | ForEach-Object { "-v$_" }) }
	
		$Bk7ZipArgs += "-t$BkArchiveType"
		If(Test-Variable "BkArchivePassword") { 
			$Bk7ZipArgs += "-p" 											# Password prompt: the password goes to 7-Zip input, never on the command line
			If($BkEncryptHeaders) { $Bk7ZipArgs += "-mhe" }
		}
		$Bk7ZipArgs += "`"$BkDestFile`"", "`@`"$BkCatalogInclude`""								# The destination file and the catalog input file
		
		# Create Process
		If(Test-Variable "Bk7ZipRetc") { Remove-Variable -Name Bk7ZipRetc }
		$oProcessStartInfo = New-Object -TypeName System.Diagnostics.ProcessStartInfo
		$oProcessStartInfo.FileName = $Bk7ZipBin
		$oProcessStartInfo.WorkingDirectory = $BkRootDir
		$oProcessStartInfo.RedirectStandardError = $true
		$oProcessStartInfo.RedirectStandardOutput = $true
		$oProcessStartInfo.UseShellExecute = $false
		$oProcessStartInfo.CreateNoWindow = $true
		$oProcessStartInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
		$oProcessStartInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8
		$oProcessStartInfo.RedirectStandardInput = (Test-Variable "BkArchivePassword")
		$oProcessStartInfo.Arguments = ($Bk7ZipArgs -join " ")
		Write-Verbose "7z arguments:  $($Bk7ZipArgs -join ' ')"
		$oProcess = New-Object -Typename System.Diagnostics.Process
		$oProcess.StartInfo = $oProcessStartInfo
		
		# Initialize StreamWriter for Compress Details
		$SWriters.CompressDetail = New-Object -TypeName System.IO.StreamWriter($BkCompressDetail, [String]$True, [System.Text.Encoding]::UTF8)
		$SWriters.CompressDetail.AutoFlush = $True
		
		# 7-Zip output is read by C# handlers. PowerShell event actions ran out of order, and actions
		# still queued when 7-Zip exited were lost. Stdout goes to Compress-Detail, stderr to a queue
		If(!("SevenZipOutput" -as [type])) {
			Add-Type -TypeDefinition @"
using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.IO;
public class SevenZipOutput {
	readonly ConcurrentQueue<string> errors = new ConcurrentQueue<string>();
	public SevenZipOutput(Process process, StreamWriter detail) {
		process.OutputDataReceived += (sender, e) => { if (!String.IsNullOrEmpty(e.Data)) { detail.WriteLine(e.Data); } };
		process.ErrorDataReceived += (sender, e) => { if (!String.IsNullOrEmpty(e.Data)) { errors.Enqueue(e.Data); } };
	}
	public bool TryGetError(out string line) { return errors.TryDequeue(out line); }
}
"@
		}
		$sevenZipOutput = New-Object SevenZipOutput($oProcess, $SWriters.CompressDetail)
		
		# Start the clocks
		$MyContext.CompressionStart = Get-Date
		
		# Start Process
		# .NET Framework opens redirected input with Console.InputEncoding: in a UTF-8 console it puts
		# a BOM before the password. Start with UTF-8 without BOM, then restore the console encoding
		$savedInputEncoding = [Console]::InputEncoding
		If(Test-Variable "BkArchivePassword") { Try { [Console]::InputEncoding = New-Object System.Text.UTF8Encoding $False } Catch {} }
		Try { [void]$oProcess.Start() } Finally { Try { [Console]::InputEncoding = $savedInputEncoding } Catch {} }
		If(Test-Variable "BkArchivePassword") {
			# 7-Zip asks the password twice (enter and verify), reading UTF-8 (-sccUTF-8)
			$passwordBytes = (New-Object System.Text.UTF8Encoding $False).GetBytes($BkArchivePassword + "`r`n" + $BkArchivePassword + "`r`n")
			$oProcess.StandardInput.BaseStream.Write($passwordBytes, 0, $passwordBytes.Length)
			$oProcess.StandardInput.Close()
		}
		[void]$oProcess.BeginOutputReadLine()
		[void]$oProcess.BeginErrorReadLine()		
		
		# Begin polling Process
		While (!($oProcess.HasExited)) {
			Start-Sleep -Milliseconds 2500
			$Status = "Waiting for archive ..."
			$ArchiveSize = 0
			# The listing has the size an open file had when the folder entry was last updated, often 0 while
			# 7-Zip writes: Refresh reads the current size of each archive file (and volume)
			Get-ChildItem -Path $BkDestPath -Filter ("{0}*" -f $BkArchiveName) | Where-Object { !$_.PSIscontainer } | ForEach-Object { $_.Refresh(); $ArchiveSize += $_.Length }
			If ( $ArchiveSize -gt 0 ) { $Status = "Archive Size {0,0:n2} MByte. so far ..." -f ($ArchiveSize / 1Mb) }
			
			# Log the 7-Zip error lines received so far, in order
			$stdErrLine = $null
			While($sevenZipOutput.TryGetError([ref]$stdErrLine)) { Trace (" !{0}" -f $stdErrLine) }
			
			
			Write-Progress -Activity "Archiving into $BkDestFile" -Status $Status -CurrentOperation "Please wait ..."
			If(Test-CtrlCRequest) {
				[void]$oProcess.Kill()
				While (!($oProcess.HasExited)) { Start-Sleep -Milliseconds 100 }
				Set-Variable -Name Bk7ZipRetc -value ([int]255) -scope Script				# Force return code to 255
				Start-Sleep -Milliseconds 500
				# Delete the destination file
				If(Test-Path -Path $BkDestFile -PathType Leaf) { Remove-Item -LiteralPath $BkDestFile -Force | Out-Null }
				break
			}
		}
		
		# HasExited can be true before the last output events ran: WaitForExit() without a timeout waits for them
		$oProcess.WaitForExit()
		Write-Progress -Activity "." -Status "." -Completed
		$stdErrLine = $null
		While($sevenZipOutput.TryGetError([ref]$stdErrLine)) { Trace (" !{0}" -f $stdErrLine) }

		# Retrieve ExitCode if not already defined
		Set-DefaultVariable "Bk7ZipRetc" $oProcess.ExitCode
		
		# Stop the clock
		$MyContext.CompressionElapsed = (Get-Date) - $MyContext.CompressionStart
		
		
		# Close StreamWriter for Compress Details
		$SWriters.CompressDetail.Flush()
		$SWriters.CompressDetail.Close()
		$SWriters.CompressDetail.Dispose()
		
		# Version 9.x  and 15.x of 7zip have different outputs
		# Look inside $BkCompressDetail in search of any file which may have been skipped
		# e.g. 7-Zip could not find one or more selected files 
		If ([int]$MyContext.SevenZBinVersionInfo.Major -le 9) {
			$relevantMessages = Get-Content $BkCompressDetail -encoding UTF8 | Where-Object {$_ -match "\ WARNING:\ |\ :\ "}
		} else {
			# 7-Zip 15+ prints "item : message" for each item it could not add. Output events
			# may arrive out of order, so match items listed in the catalog, not positions
			$relevantMessages = @()
			$warningLines = @(Get-Content $BkCompressDetail -encoding UTF8 | Where-Object {$_.Contains(" : ")})
			If($warningLines.Count -gt 0) {
				$warningItems = @{}
				$warningLines | ForEach-Object { $warningItems[$_.Substring(0, $_.IndexOf(" : "))] = $False }
				Get-Content $BkCatalogInclude -encoding UTF8 | Where-Object { $warningItems.ContainsKey($_) } | ForEach-Object { $warningItems[$_] = $True }
				$relevantMessages = @($warningLines | Where-Object { $warningItems[$_.Substring(0, $_.IndexOf(" : "))] })
			}
		}
		
		#If any relevant message then output
		If(!($Bk7ZipRetc -eq 255) -and $relevantMessages) {
			Trace " 7-Zip completed with warnings "
			Trace " ------------------------------------------------------------------------------"
			$relevantMessages | ForEach-Object {
				Trace " $_"; $Counters.Warnings++
			}
			Trace " "
		}
		
		# Check overall size of archive (including volumes if present)
		$ArchiveSize = 0
		Get-ChildItem -Path $BkDestPath -Filter ("{0}*" -f $BkArchiveName) | Where-Object { !$_.PSIscontainer } | ForEach-Object { $ArchiveSize += $_.Length }

		# Check exit code by 7zip - If ErrorLevel is <2 then we assume backup
		# process completed successfully
		If(($Bk7ZipRetc -lt 2) -and ($ArchiveSize -gt 0) -and !(Test-CtrlCRequest)) {
			
			# Output informations in log file 
			Trace (" Created      : {1} in {0} " -f $BkDestPath, $BkArchiveName)
			Trace (" Archive Size : {0,0:n2} MB = {1,2:n2}% of original size" -f ($ArchiveSize / 1Mb), ((($ArchiveSize / $Counters.BytesSelected)) * 100))
			Trace (" 7zip time    : {0}" -f (Format-Elapsed $MyContext.CompressionElapsed))
			Trace (" Performance  : {0,0:n2} files/sec" -f ($Counters.FilesSelected / $MyContext.CompressionElapsed.TotalSeconds) )
			Trace (" IO Avg Speed : Read {0,0:n2} MB/Sec / Write {1,0:n2} MB/Sec" -f (($Counters.BytesSelected / $MyContext.CompressionElapsed.TotalSeconds) / 1MB), (($ArchiveSize / $MyContext.CompressionElapsed.TotalSeconds) / 1MB) )
			Trace " "
				
			
			# Do Post Archiving
			If(!(Test-CtrlCRequest)) { PostArchiving ; }
			
			# Do rotation over backup files
			# We have to list all files in the destination directory matching the same prefix and the same type
			# list all items descending (by their creation date) and then delete the oldest out of
			# the rotation range. If no rotation is defined then assume rotation period is 999 so we
			# can easily have an output of archives on target media.
			If(!(Test-CtrlCRequest)) {
				Set-DefaultVariable "BkRotate" ([int]9999)
				If(($BkRotate -ge 1)) {
					$totalArchiveBytes = [int64]0
					$fileNameRgx = ("^$([Regex]::Escape($BkArchivePrefix))-$BkType-[0-9]{8}-[0-9]{4,6}\.(7z|zip|tar)(\.\d{3})?$")
					Trace " Archives in $BkDestPath"
					Trace " ------------------------------------------------------------------------------"
					Get-ChildItem $BkDestPath | Where-Object { $_.Name -match $fileNameRgx -and !$_.PSIscontainer } | Sort-Object @{expression={$_.Name};Descending=$true} | foreach-object {
						If(!($BkRotate -le 0)) { 
							If ($_.Name.StartsWith($BkArchiveName, [StringComparison]::OrdinalIgnoreCase)) {
								Trace (" New      : {0,-48} {1,15:n2} MB " -f $_.Name, $($_.Length / 1MB) ); $totalArchiveBytes += [int64]$_.Length
							} Else {
								Trace (" Kept     : {0,-48} {1,15:n2} MB " -f $_.Name, $($_.Length / 1MB) ); $totalArchiveBytes += [int64]$_.Length
							}
							
							# Check is volumized archive
							If ($_.Name -match "\.(7z|zip|tar)(\.001)?$") { $BkRotate += -1 }
							
						} Else {
							Remove-Item -LiteralPath (Join-Path $BkDestPath $_.Name) -ErrorAction "SilentlyContinue" | Out-Null
							if ($?) { Trace (" Removed  : {0,-48} {1,15:n2} MB " -f $_.Name, $($_.Length / 1MB) ) } Else { Trace (" WARNING Failed to remove {0}" -f $_.Name)}
						}
					}
					Trace " ------------------------------------------------------------------------------"
					Trace (" {0,-59} {1,15:n2} MB" -f "Used space by listed archives (New and Kept)", $($totalArchiveBytes / 1MB) )
					Trace (" {0,-59} {1,15:n2} MB" -f "Remaining Free space on target", $((([int64](GetDestPathFreeSpace -target $BkDestPath))) / 1MB) )
					Trace " ------------------------------------------------------------------------------`n"
					
				}
			}
		
			If(($Counters.Warnings -gt 0)) {
				Trace (" Task status : Done with : " + $Counters.Warnings + " warnings. Check logs!")
			} Else {
				Trace " Task status : All Done !! Yuppieee"
			}
			$MyContext.TotalElapsed = (Get-Date) - $MyContext.SelectionStart
			Trace (" Task time   : {0}" -f (Format-Elapsed $MyContext.TotalElapsed))
			Trace (" Task end    : {0}`n" -f (Get-Date -f "MMM dd, yyyy hh:mm:ss") )
			
		} Else {
		
			# Uncomment this line if you want to read the details of 7-Zip log of operations
			#[string]::join([environment]::newline, (Get-Content -path $BkCompressDetail -encoding ASCII)) 
		
			# If we fall down here the 7z.exe has exited with a high error level
			# According to 7-Zip manual the possibilities are:
			# 0   - No error
			# 1   - Warning (Non fatal error(s)). For example, one or more files were locked by some other application, so they were not compressed
			# 2   - Fatal error
			# 7   - Command line error
			# 8   - Not Enough memory to complete operation
			# 255 - User stopped the process
			$fatalMessages = @{
				255 = @(" Cancelled ! User has stopped 7-Zip archiving process", " NO ARCHIVE HAS BEEN CREATED")
				2   = @(" Cancelled ! 7-Zip reported a fatal error.", " NO VALID ARCHIVE HAS BEEN CREATED")
				7   = @(" Cancelled ! 7-Zip has been invoked with a wrong command line.", (" {0}" -f $oProcessStartInfo.Arguments), " NO VALID ARCHIVE HAS BEEN CREATED")
				8   = @(" Cancelled ! 7-Zip reports not enough memory.", " NO VALID ARCHIVE HAS BEEN CREATED")
			}
			If ($fatalMessages.ContainsKey([int]$Bk7ZipRetc)) {
				$Counters.Criticals += 1
				Trace " "
				$fatalMessages[[int]$Bk7ZipRetc] | ForEach-Object { Trace $_ }
				If(Test-Path -Path $BkDestFile -PathType Leaf) { Remove-Item -LiteralPath $BkDestFile -Force | Out-Null }
			} ElseIf (!(Test-Path -Path "$BkDestPath\$BkArchiveName" -PathType Leaf)) {
				$Counters.Criticals += 1
				Trace " " 
				Trace " Error !" 
				Trace " NO ARCHIVE HAS BEEN CREATED" 
			}
			
			
		}
	}
	Else {
		Trace " Dry Run Selected ! No Archive creation."
	}
	
# If is set a list of notification addresses then proceed with email here
if (!(Test-CtrlCRequest)) { 
	Invoke-PostAction
	Send-Notification
}

# Clean Up 
Clear-Script
