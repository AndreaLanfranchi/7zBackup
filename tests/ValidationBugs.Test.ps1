# Test for two argument checks of Assert-Variables:
# - --volumes accepts only a number and one unit letter (b, k, m or g)
# - on Windows XP / 2003 junction.exe is searched in the Program Files folders
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\ValidationBugs.Test.ps1

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
New-Item -ItemType Directory "$work\dest", "$work\source", "$work\pf\SysInternalsSuite" -Force | Out-Null
Set-Content -LiteralPath "$work\pf\SysInternalsSuite\junction.exe" -Value "fake"
$selection = Join-Path $work "selection.txt"
Set-Content -LiteralPath $selection -Value "includesource=$work\source|alias=Source"

# Runs Assert-Variables with the given variables; returns the errors
Function Invoke-Validation ([hashtable]$vars, [string]$winVer = "10") {
	$script:MyContext       = [hashtable]::Synchronized(@{ PSVer = [int]$PSVersionTable.PSVersion.Major; WinVer = @($winVer); Logger = (New-Object System.Text.StringBuilder) })
	$script:BkType          = "full"
	$script:BkSelection     = $selection
	$script:BkDestPath      = "$work\dest"
	$script:BkArchivePrefix = "test"
	Remove-Variable -Name BkArchiveVolumes, BkJunctionBin -Scope Script
	foreach ($name in $vars.Keys) { Set-Variable -Name $name -Value $vars[$name] -Scope Script }
	Write-Output @(Assert-Variables)
}

Write-Host "`n Case: volume sizes"
foreach ($size in "10m", "1G", "700k", "5b") {
	$errors = @(Invoke-Validation @{ BkArchiveVolumes = @($size) } | Where-Object { $_ -match "volumes" })
	Assert ($errors.Count -eq 0) "$size is accepted [$($errors -join ' | ')]"
}
foreach ($size in "abc10b", "10|", "10", "m", "10mb", "|", "10m`n") {
	$errors = @(Invoke-Validation @{ BkArchiveVolumes = @($size) } | Where-Object { $_ -match "volumes" })
	Assert ($errors.Count -eq 1) "$size is refused [$($errors -join ' | ')]"
}

Write-Host "`n Case: junction.exe found in Program Files on Windows XP"
$savedPf = $env:ProgramFiles; $savedPf86 = ${env:ProgramFiles(x86)}
$env:ProgramFiles = "$work\pf"; ${env:ProgramFiles(x86)} = "$work\none"
$errors = @(Invoke-Validation @{} "5" | Where-Object { $_ -match "jbin" })
Assert ($errors.Count -eq 0)                                            "no --jbin error [$($errors -join ' | ')]"
Assert ($BkJunctionBin -eq "$work\pf\SysInternalsSuite\junction.exe")   "BkJunctionBin is set [$BkJunctionBin]"
$env:ProgramFiles = $savedPf; ${env:ProgramFiles(x86)} = $savedPf86

Remove-Item -LiteralPath $work -Recurse -Force
Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
