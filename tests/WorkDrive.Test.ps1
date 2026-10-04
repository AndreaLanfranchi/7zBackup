# Integration test for the work drive check in Assert-Variables.
# A drive letter without a drive must be rejected; a writable NTFS drive must
# be accepted.
# Note: the accepted case creates and removes a test folder in the root of the
# TEMP drive, as 7zBackup.ps1 itself does.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\WorkDrive.Test.ps1

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

$work = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory "$work\dest", "$work\source" -Force | Out-Null
$selection = Join-Path $work "selection.txt"
Set-Content -LiteralPath $selection -Value "includesource=$work\source|alias=Source"

# Runs Assert-Variables with an otherwise valid setup; returns the work drive errors only
Function Get-WorkDriveErrors ([string]$drive) {
	$script:MyContext       = [hashtable]::Synchronized(@{ PSVer = [int]$PSVersionTable.PSVersion.Major; Logger = (New-Object System.Text.StringBuilder) })
	$script:BkType          = "full"
	$script:BkSelection     = $selection
	$script:BkDestPath      = "$work\dest"
	$script:BkArchivePrefix = "test"
	$script:BkWorkDrive     = $drive
	Write-Output @(Assert-Variables | Where-Object { $_ -match "--workdrive" })
}

$missingDrive = [char[]](67..90) | Where-Object { -not (Test-Path "$($_):\") } | Select-Object -First 1
Assert ($null -ne $missingDrive) "precondition, a drive letter without a drive exists"
Write-Host "`n Case: drive letter without a drive ($missingDrive)"
Assert (@(Get-WorkDriveErrors "$missingDrive").Count -eq 1) "work drive is rejected"

$tempDrive = $env:TEMP.Substring(0, 1)
Assert ((New-Object System.IO.DriveInfo($tempDrive)).DriveFormat -eq "NTFS") "precondition, TEMP drive $tempDrive is NTFS"
Write-Host "`n Case: writable NTFS drive ($tempDrive)"
Assert (@(Get-WorkDriveErrors $tempDrive).Count -eq 0) "work drive is accepted"

Remove-Item -LiteralPath $work -Recurse -Force

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
