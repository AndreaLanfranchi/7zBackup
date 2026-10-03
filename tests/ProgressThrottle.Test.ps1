# Unit test for Trace-Progress, the throttled Write-Progress.
# Write-Progress costs some milliseconds per call and the scan calls it for
# every folder: it must write at most once every 500 ms, unless forced.
# ProcessFolder must not call Write-Progress directly any more.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\ProgressThrottle.Test.ps1

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

# A function shadows the cmdlet of the same name: this counts the real writes
$ProgressCalls = 0
Function Write-Progress { $script:ProgressCalls++ }

$MyContext = [hashtable]::Synchronized(@{ Logger = (New-Object System.Text.StringBuilder) })

Write-Host "`n Case: repeated calls write once"
Assert ($null -ne (Get-Command Trace-Progress)) "Trace-Progress exists"
$ProgressCalls = 0
for ($i = 0; $i -lt 200; $i++) { Trace-Progress "Folder x" "Checking ... " "Selected 1 file" }
Assert ($ProgressCalls -eq 1) "200 calls in a row write once [$ProgressCalls]"

Write-Host "`n Case: a call after the interval writes again"
$MyContext.Remove("ProgressWatch")   # the previous case wrote less than 500 ms ago
$ProgressCalls = 0
Trace-Progress "Folder x" "Checking ... " "Selected 1 file"
Start-Sleep -Milliseconds 600
Trace-Progress "Folder x" "Checking ... " "Selected 1 file"
Assert ($ProgressCalls -eq 2) "one write before and one after the wait [$ProgressCalls]"

Write-Host "`n Case: ProcessFolder goes through Trace-Progress (via Trace-ScanProgress)"
$processFolder = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq "ProcessFolder" }, $False)[0]
$commands = @($processFolder.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $True) | ForEach-Object { $_.GetCommandName() })
Assert (@($commands | Where-Object { $_ -eq "Write-Progress" }).Count -eq 0) "ProcessFolder calls no Write-Progress directly"
Assert (@($commands | Where-Object { $_ -eq "Trace-ScanProgress" }).Count -ge 1) "ProcessFolder calls Trace-ScanProgress"
$scanProgress = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq "Trace-ScanProgress" }, $False)[0]
$scanCommands = @($scanProgress.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $True) | ForEach-Object { $_.GetCommandName() })
Assert (@($scanCommands | Where-Object { $_ -eq "Write-Progress" }).Count -eq 0) "Trace-ScanProgress calls no Write-Progress directly"
Assert (@($scanCommands | Where-Object { $_ -eq "Trace-Progress" }).Count -ge 1) "Trace-ScanProgress calls Trace-Progress"

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
