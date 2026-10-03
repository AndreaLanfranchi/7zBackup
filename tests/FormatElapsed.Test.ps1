# Test for Format-Elapsed: days, hours, minutes and seconds of a time span.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\FormatElapsed.Test.ps1

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

[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture

$text = Format-Elapsed (New-Object System.TimeSpan(2, 3, 4, 5, 678))
Assert ($text -eq "2 d : 3 h : 4 m : 5.678 s")  "all parts [$text]"

$text = Format-Elapsed ([System.TimeSpan]::Zero)
Assert ($text -eq "0 d : 0 h : 0 m : 0.000 s")  "zero [$text]"

$text = Format-Elapsed (New-Object System.TimeSpan(0, 0, 0, 59, 999))
Assert ($text -eq "0 d : 0 h : 0 m : 59.999 s") "just below a minute [$text]"

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
