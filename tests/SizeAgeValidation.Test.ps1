# Integration test for the size and age checks in Assert-Variables.
# An invalid value must be reported with the name of the setting that has it;
# valid values must still be accepted.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\SizeAgeValidation.Test.ps1

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

# Runs Assert-Variables with an otherwise valid setup and one size / age value, as set by the command line
Function Get-Errors ([string]$variable, [string]$value) {
	foreach ($name in "BkMaxFileSize", "BkMinFileSize", "BkMaxFileAge", "BkMinFileAge") { Remove-Variable -Name $name -Scope Script }
	$script:MyContext       = [hashtable]::Synchronized(@{ PSVer = [int]$PSVersionTable.PSVersion.Major; Logger = (New-Object System.Text.StringBuilder) })
	$script:BkType          = "full"
	$script:BkSelection     = $selection
	$script:BkDestPath      = "$work\dest"
	$script:BkArchivePrefix = "test"
	Set-Variable -Name $variable -Value $value -Scope Script
	Write-Output @(Assert-Variables)
}

Write-Host "`n Case: invalid values are reported with the right name"
foreach ($case in @(
	@{ Variable = "BkMaxFileSize"; Name = "maxfilesize" },
	@{ Variable = "BkMinFileSize"; Name = "minfilesize" },
	@{ Variable = "BkMaxFileAge";  Name = "maxfileage" },
	@{ Variable = "BkMinFileAge";  Name = "minfileage" }
)) {
	$errors = @(Get-Errors $case.Variable "abc")
	Assert (@($errors | Where-Object { $_ -match "\b$($case.Name)\b" }).Count -eq 1) "invalid $($case.Name) is reported as $($case.Name) [$($errors -join ' | ')]"
}

Write-Host "`n Case: valid values are accepted"
# The value must become a number, not stay text that only compares equal
$errors = @(Get-Errors "BkMaxFileSize" "1048576")
Assert (($errors.Count -eq 0) -and ($BkMaxFileSize -is [int64]) -and ($BkMaxFileSize -eq 1048576)) "maxfilesize 1048576 becomes a number [$($errors -join ' | ')] [$($BkMaxFileSize.GetType().Name)]"
$errors = @(Get-Errors "BkMinFileSize" "10")
Assert (($errors.Count -eq 0) -and ($BkMinFileSize -is [int64]) -and ($BkMinFileSize -eq 10))      "minfilesize 10 becomes a number [$($errors -join ' | ')] [$($BkMinFileSize.GetType().Name)]"
$errors = @(Get-Errors "BkMaxFileAge" "10")
Assert (($errors.Count -eq 0) -and ($BkMaxFileAge -is [double]) -and ($BkMaxFileAge -eq 10))       "maxfileage 10 becomes a number [$($errors -join ' | ')] [$($BkMaxFileAge.GetType().Name)]"
$errors = @(Get-Errors "BkMinFileAge" "1.5")
Assert (($errors.Count -eq 0) -and ($BkMinFileAge -is [double]) -and ($BkMinFileAge -eq 1.5))      "minfileage 1.5 becomes a number [$($errors -join ' | ')] [$($BkMinFileAge.GetType().Name)]"

Write-Host "`n Case: zero turns the filter off"
# The setting must be removed, not left at 0 (the log would list a filter that does nothing)
foreach ($variable in "BkMaxFileSize", "BkMinFileSize", "BkMaxFileAge", "BkMinFileAge") {
	$errors = @(Get-Errors $variable "0")
	Assert (($errors.Count -eq 0) -and !(Test-Variable $variable)) "$variable 0 is removed [$($errors -join ' | ')]"
}

Remove-Item -LiteralPath $work -Recurse -Force

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
