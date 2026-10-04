# Integration test for the archive prefix check in Assert-Variables.
# The prefix becomes part of a file name: characters not allowed in file names
# (including path separators, which could put the archive outside --destpath)
# must be rejected.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\ArchivePrefix.Test.ps1

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

# Runs Assert-Variables with an otherwise valid setup; returns the prefix errors only
Function Get-PrefixErrors ([string]$prefix) {
	$script:MyContext       = [hashtable]::Synchronized(@{ PSVer = [int]$PSVersionTable.PSVersion.Major; Logger = (New-Object System.Text.StringBuilder) })
	$script:BkType          = "full"
	$script:BkSelection     = $selection
	$script:BkDestPath      = "$work\dest"
	$script:BkArchivePrefix = $prefix
	Write-Output @(Assert-Variables | Where-Object { $_ -match "--prefix" })
}

Write-Host "`n Case: valid prefixes"
foreach ($prefix in "srv", "my.server_01", "srv-a") {
	Assert (@(Get-PrefixErrors $prefix).Count -eq 0) "accepted: $prefix"
}

Write-Host "`n Case: prefixes with characters not allowed in a file name"
foreach ($prefix in "..\evil", "sub\name", "a/b", "C:x", "bad*name", "bad?name") {
	Assert (@(Get-PrefixErrors $prefix).Count -eq 1) "rejected: $prefix"
}

Remove-Item -LiteralPath $work -Recurse -Force

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
