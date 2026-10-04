# Integration test for the command line parser (Assert-Arguments).
# The parser is table driven: this test lists every option on its own, so a missing,
# mistyped or mis-aliased row in the tables is caught.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\Arguments.Test.ps1

$ErrorActionPreference = "SilentlyContinue"   # same as 7zBackup.ps1

# Load function definitions only: the script body is not executed
$scriptFile = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\7zBackup.ps1"))
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile, [ref]$null, [ref]$null)
foreach ($fn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $False)) {
	. ([scriptblock]::Create($fn.Extent.Text))
}

$Failures = 0
Function Assert ([bool]$condition, [string]$message) {
	If($condition) { Write-Host " PASS : $message" -ForegroundColor Green }
	Else { Write-Host " FAIL : $message" -ForegroundColor Red; $script:Failures++ }
}

# Runs the parser on the given command line. Returns its messages
Function Invoke-Parser ([string[]]$arguments) {
	Get-Variable -Name "Bk*" -Scope Script | ForEach-Object { Remove-Variable -Name $_.Name -Scope Script }
	$script:BkArguments = $arguments
	Write-Output @(Assert-Arguments)
}

# Options followed by a value: argument, variable ($null: the value is accepted and ignored)
$valueOptions = @(
	@("--type", "BkType"), @("--workdir", "BkWorkDir"), @("--workdrive", "BkWorkDrive"),
	@("--selection", "BkSelection"), @("--destpath", "BkDestPath"),
	@("--archiveprefix", "BkArchivePrefix"), @("--prefix", "BkArchivePrefix"),
	@("--archivetype", "BkArchiveType"), @("--compression", "BkArchiveCompression"),
	@("--threads", "BkArchiveThreads"), @("--solid", "BkArchiveSolid"), @("--volumes", "BkArchiveVolumes"),
	@("--archivepassword", "BkArchivePassword"), @("--password", "BkArchivePassword"),
	@("--rotate", "BkRotate"), @("--maxdepth", "BkMaxDepth"),
	@("--maxfileage", "BkMaxFileAge"), @("--minfileage", "BkMinFileAge"),
	@("--maxfilesize", "BkMaxFileSize"), @("--minfilesize", "BkMinFileSize"),
	@("--clearbit", "BkClearBit"), @("--logfile", $null),
	@("--notify", "BkNotifyLog"), @("--notifyto", "BkNotifyLog"),
	@("--notifytoCc", "BkNotifyLogCc"), @("--notifytoBcc", "BkNotifyLogBcc"),
	@("--notifyfrom", "BkSmtpFrom"), @("--notifyextra", "BkNotifyExtra"),
	@("--smtpserver", "BkSmtpRelay"), @("--smtpport", "BkSmtpPort"),
	@("--smtpuser", "BkSmtpUser"), @("--smtppass", "BkSmtpPass"), @("--mailkitpath", "BkMailKitPath"),
	@("--7zbin", "Bk7ZipBin"), @("--7zipbin", "Bk7ZipBin"), @("--jbin", $null),
	@("--pre", "BkPreAction"), @("--post", "BkPostAction")
)
# Switches without a value: argument, variable
$switchOptions = @(
	@("--encryptheaders", "BkEncryptHeaders"), @("--emptydirs", "BkKeepEmptyDirs"),
	@("--smtpssl", "BkSmtpSSL"), @("--dry", "BkDryRun")
)

Write-Host "`n Case: every option with a value sets its variable and consumes exactly one argument"
foreach ($option in $valueOptions) {
	$name, $variable = $option
	# --dry after the option proves the parser went on with the right argument
	$messages = @(Invoke-Parser @($name, "some value", "--dry"))
	$set = If($variable) { (Get-Variable -Name $variable -Scope Script -ErrorAction SilentlyContinue).Value -ceq "some value" } Else { $True }
	Assert ($messages.Count -eq 0 -and $set -and $BkDryRun -eq $True) "$name -> $(If($variable) { $variable } Else { 'ignored' })"
}

Write-Host "`n Case: every switch sets its variable and consumes no argument"
foreach ($option in $switchOptions) {
	$name, $variable = $option
	$messages = @(Invoke-Parser @($name, "--type", "full"))
	Assert ($messages.Count -eq 0 -and (Get-Variable -Name $variable -Scope Script).Value -eq $True -and $BkType -ceq "full") "$name -> $variable"
}

Write-Host "`n Case: the value of an option is taken as is, even when it looks like an option"
$messages = @(Invoke-Parser @("--logfile", "--dry", "--prefix", "--type"))
Assert ($messages.Count -eq 0 -and $null -eq $BkDryRun -and $BkArchivePrefix -ceq "--type") "--logfile --dry swallows --dry; --prefix --type takes '--type' as prefix"

Write-Host "`n Case: aliases give the same result"
foreach ($alias in @(@("--prefix", "--archiveprefix"), @("--password", "--archivepassword"), @("--notify", "--notifyto"), @("--7zbin", "--7zipbin"))) {
	$null = Invoke-Parser @($alias[0], "x")
	$first = Get-Variable -Name "Bk*" -Scope Script | Where-Object { $_.Name -ne "BkArguments" } | ForEach-Object { "$($_.Name)=$($_.Value)" }
	$null = Invoke-Parser @($alias[1], "x")
	$second = Get-Variable -Name "Bk*" -Scope Script | Where-Object { $_.Name -ne "BkArguments" } | ForEach-Object { "$($_.Name)=$($_.Value)" }
	Assert (@($first).Count -eq 1 -and "$first" -ceq "$second") "$($alias[0]) = $($alias[1]) [$first]"
}

Write-Host "`n Case: option names are matched in any letter case"
$messages = @(Invoke-Parser @("--DEST", "--DestPath", "d", "--DRY"))
Assert ($messages.Count -eq 1 -and $BkDestPath -ceq "d" -and $BkDryRun -eq $True) "--DestPath and --DRY are accepted; --DEST is unknown [$($messages -join ' | ')]"

Write-Host "`n Case: unknown arguments are reported one by one and parsing goes on"
$messages = @(Invoke-Parser @("bogus", "--type", "full", "--nope", "-x", "--dry"))
Assert ($messages.Count -eq 3 -and $messages[0] -ceq "Unknown argument bogus" -and $messages[1] -ceq "Unknown argument --nope" -and $messages[2] -ceq "Unknown argument -x") "3 messages [$($messages -join ' | ')]"
Assert ($BkType -ceq "full" -and $BkDryRun -eq $True) "known arguments around them are still applied"

Write-Host "`n Case: an empty command line sets nothing"
$messages = @(Invoke-Parser @())
Assert ($messages.Count -eq 0 -and @(Get-Variable -Name "Bk*" -Scope Script | Where-Object { $_.Name -ne "BkArguments" }).Count -eq 0) "no message, no variable"

Write-Host "`n Case: an option at the end of the line without its value does not fail"
$messages = @(Invoke-Parser @("--type"))
Assert ($messages.Count -eq 0 -and $null -eq $BkType) "--type alone is left unset"

Write-Host "`n Case: --jbin is accepted and ignored, with a warning"
$script:MyContext = [hashtable]::Synchronized(@{ Logger = (New-Object System.Text.StringBuilder) })
$script:Counters  = @{ Warnings = 0 }
$messages = @(Invoke-Parser @("--jbin", "C:\Tools\Junction.exe", "--dry"))
Assert ($messages.Count -eq 0 -and $null -eq $BkJunctionBin -and $BkDryRun -eq $True) "--jbin takes its value and sets nothing"
$null = Trace-ObsoleteArguments 6>&1
Assert ($Counters.Warnings -eq 1 -and $MyContext.Logger.ToString().Contains("--jbin is obsolete")) "the warning is logged and counted once [$($Counters.Warnings)]"
$script:Counters = @{ Warnings = 0 }
$null = Invoke-Parser @("--type", "full")
$null = Trace-ObsoleteArguments 6>&1
Assert ($Counters.Warnings -eq 0) "no warning without --jbin"

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
