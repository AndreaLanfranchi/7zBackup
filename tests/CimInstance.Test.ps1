# Test for WMI calls in 7zBackup.ps1.
# Get-WmiObject does not exist in PowerShell 7: the script must use Get-CimInstance.
# The --threads check, which counts the logical processors, must keep working.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\CimInstance.Test.ps1

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

Write-Host "`n Case: no Get-WmiObject"
$commands = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $True) | ForEach-Object { $_.GetCommandName() })
Assert (@($commands | Where-Object { $_ -eq "Get-WmiObject" }).Count -eq 0) "7zBackup.ps1 calls no Get-WmiObject [$(@($commands | Where-Object { $_ -match 'Wmi|Cim' }) -join ', ')]"

$work = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory "$work\dest", "$work\source" -Force | Out-Null
$selection = Join-Path $work "selection.txt"
Set-Content -LiteralPath $selection -Value "includesource=$work\source|alias=Source"

# Runs Assert-Variables with an otherwise valid setup and the given --threads; returns the errors
Function Invoke-Validation ($threads) {
	$script:MyContext        = [hashtable]::Synchronized(@{ PSVer = [int]$PSVersionTable.PSVersion.Major; Logger = (New-Object System.Text.StringBuilder) })
	$script:Counters         = @{ Warnings = 0 }
	$script:BkType           = "full"
	$script:BkSelection      = $selection
	$script:BkDestPath       = "$work\dest"
	$script:BkArchivePrefix  = "test"
	$script:BkArchiveThreads = $threads
	Write-Output @(Assert-Variables)
}

Write-Host "`n Case: --threads larger than the logical processors"
$cores = [Environment]::ProcessorCount
$errors = @(Invoke-Validation 9999)
Assert (@($errors | Where-Object { $_ -match "--threads \[9999\] argument\. Must not exceed $cores$" }).Count -eq 1) "rejected, naming the $cores logical processors [$($errors -join ' | ')]"

Write-Host "`n Case: --threads 1"
$errors = @(Invoke-Validation 1)
Assert (@($errors | Where-Object { $_ -match "--threads" }).Count -eq 0) "accepted [$($errors -join ' | ')]"

Remove-Item -LiteralPath $work -Recurse -Force

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
