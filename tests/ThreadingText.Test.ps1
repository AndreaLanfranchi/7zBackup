# Test for Format-Threading: the threading text of the run header.
# 0 and 1 threads are passed to 7-Zip as -mmt=off, the header must say so.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\ThreadingText.Test.ps1

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

Assert ($null -ne (Get-Command Format-Threading)) "precondition, Format-Threading exists"

Write-Host "`n Case: --threads not set"
Remove-Variable -Name BkArchiveThreads -Scope Script
Assert ((Format-Threading) -ceq "Auto") "Auto"

foreach ($case in @(@(0, "off"), @(1, "off"), @(2, "2 threads"), @(8, "8 threads"))) {
	Write-Host "`n Case: --threads $($case[0])"
	$script:BkArchiveThreads = [int]$case[0]
	$text = Format-Threading
	Assert ($text -ceq $case[1]) "shows '$($case[1])' [$text]"
}

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
