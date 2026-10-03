# Integration test for the --type check in Assert-Variables.
# The type is accepted in any letter case, but kept in lower case: the archive
# name is built from it, so --type FULL must not give another name than --type full.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\BackupType.Test.ps1

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

# Runs Assert-Variables with an otherwise valid setup and the given --type, as set by the command line
Function Get-Errors ([string]$type) {
	Remove-Variable -Name BkClearBit -Scope Script
	$script:MyContext       = [hashtable]::Synchronized(@{ PSVer = [int]$PSVersionTable.PSVersion.Major; WinVer = @("10"); Logger = (New-Object System.Text.StringBuilder) })
	$script:BkType          = $type
	$script:BkSelection     = $selection
	$script:BkDestPath      = "$work\dest"
	$script:BkArchivePrefix = "test"
	Write-Output @(Assert-Variables)
}

Write-Host "`n Case: the type is kept in lower case, whatever its spelling"
foreach ($spelling in "full", "FULL", "Incr", "dIFF", "COPY", "Move") {
	$errors = @(Get-Errors $spelling)
	Assert (@($errors | Where-Object { $_ -match "--type" }).Count -eq 0 -and $BkType -ceq $spelling.ToLowerInvariant()) "--type $spelling is accepted and becomes $($spelling.ToLowerInvariant()) [$BkType]"
}

Write-Host "`n Case: the lower case does not depend on the culture (Turkish turns I into a dotless i)"
$savedCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo("tr-TR")
$errors = @(Get-Errors "INCR")
$culturePrecondition = "INCR".ToLower() -cne "incr"   # false when the system has no Turkish culture data
[System.Threading.Thread]::CurrentThread.CurrentCulture = $savedCulture
Assert (@($errors | Where-Object { $_ -match "--type" }).Count -eq 0 -and $BkType -ceq "incr") "--type INCR becomes incr under tr-TR [$BkType]$(If(!$culturePrecondition) { ' (tr-TR not available here: weak check)' })"

Write-Host "`n Case: the archive bit default follows the type, not its spelling"
foreach ($case in @(@("FULL", $True), @("Incr", $True), @("DIFF", $False), @("Copy", $False), @("MOVE", $False))) {
	$null = Get-Errors $case[0]
	Assert ($BkClearBit -eq $case[1]) "--type $($case[0]) clears the archive bit: $($case[1]) [$BkClearBit]"
}

Write-Host "`n Case: an invalid type is reported and left as given"
foreach ($invalid in "bogus", "") {
	$errors = @(Get-Errors $invalid)
	Assert (@($errors | Where-Object { $_ -match "--type" }).Count -eq 1 -and $BkType -ceq $invalid) "--type '$invalid' is reported [$($errors -join ' | ')]"
}

Remove-Item -LiteralPath $work -Recurse -Force

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
