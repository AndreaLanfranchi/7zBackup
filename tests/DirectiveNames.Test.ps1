# Integration test for selection directive names.
# A directive is its exact name followed by "=": longer names such as
# prefixes=, includesourcex= or matchexcludefilesx= are not that directive.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\DirectiveNames.Test.ps1

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

# Runs Assert-Variables on a selection file with the given lines; returns the errors
Function Invoke-Validation ([string[]]$lines) {
	Set-Content -LiteralPath $selection -Value $lines
	$script:MyContext       = [hashtable]::Synchronized(@{ PSVer = [int]$PSVersionTable.PSVersion.Major; Logger = (New-Object System.Text.StringBuilder) })
	$script:BkType          = "full"
	$script:BkSelection     = $selection
	$script:BkDestPath      = "$work\dest"
	$script:BkArchivePrefix = "test"
	Write-Output @(Assert-Variables)
}

# -----------------------------------------------------------------------------
Write-Host "`n Case: prefixes= is not prefix="
$errors = @(Invoke-Validation @("includesource=$work\source|alias=Source", "prefixes=wrong"))
Assert ($errors.Count -eq 0)          "no validation error [$($errors -join ' | ')]"
Assert ($BkArchivePrefix -eq "test")  "the prefix is unchanged [$BkArchivePrefix]"

# -----------------------------------------------------------------------------
Write-Host "`n Case: includesourcex= is not includesource="
$errors = @(Invoke-Validation @("includesourcex=$work\source|alias=Source"))
Assert (@($errors | Where-Object { $_ -match 'includesource' }).Count -eq 1) "a selection without includesource is reported [$($errors -join ' | ')]"

# -----------------------------------------------------------------------------
Write-Host "`n Case: longer names are not matchexcludefiles= / matchexcludepath= / matchstoprecurse="
$MyContext = [hashtable]::Synchronized(@{ Logger = (New-Object System.Text.StringBuilder) })
$BkSelectionContents = @("matchexcludefilesx=abc", "matchexcludepathx=abc", "matchstoprecursex=abc")
foreach ($name in "matchexcludefiles", "matchexcludepath", "matchstoprecurse") {
	Remove-Variable -Name $name -Scope Script
	Read-MatchRule $BkSelectionContents $name $name "" ""
	Assert ($null -eq (Get-Variable -Name $name -Scope Script -ValueOnly)) "$name stays unset"
}

Remove-Item -LiteralPath $work -Recurse -Force

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
