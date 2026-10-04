# Integration test for the selection statistics report in the script body.
# The totals by extension come from $Counters.Extensions, filled during the scan:
# the report lists each extension with its count, biggest size first, then the total.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\SelectionStats.Test.ps1

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

# The function that writes the report
Assert ($null -ne (Get-Command Write-SelectionStats -ErrorAction SilentlyContinue)) "precondition, Write-SelectionStats found in 7zBackup.ps1"

Write-Host "`n Case: totals of two extensions and files without extension"
# 2 .txt files of 1 MB in total, 1 .pdf of 2 MB, 1 empty file without extension
$Counters       = @{ Warnings = 0; Criticals = 0; FilesSelected = 4; BytesSelected = [int64]3145728; Extensions = @{ ".txt" = @(2, [int64]1048576); ".pdf" = @(1, [int64]2097152); "" = @(1, [int64]0) } }
$MyContext      = [hashtable]::Synchronized(@{ Cancelling = $False; Logger = (New-Object System.Text.StringBuilder) })
$BkCatalogStats = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N") + ".csv")   # no stats file: totals must come from the counters

Write-SelectionStats

$lines = @($MyContext.Logger.ToString().Split("`n") | ForEach-Object { $_.TrimEnd() })
$pdfRow   = [array]::IndexOf($lines, @($lines | Where-Object { $_ -match '^ \.pdf\s+1\s' })[0])
$txtRow   = [array]::IndexOf($lines, @($lines | Where-Object { $_ -match '^ \.txt\s+2\s' })[0])
$emptyRow = @($lines | Where-Object { $_ -match '^ {32}\s*1\s+0[.,]00\s' }).Count
$totalRow = @($lines | Where-Object { $_ -match '^ Total\s+4\s+3[.,]00$' }).Count
$table    = ($lines | Where-Object { $_ -match '^ (\.|Total| {20})' }) -join ' | '

Assert ($pdfRow -ge 0)                     ".pdf row with 1 file [$table]"
Assert ($txtRow -ge 0)                     ".txt row with 2 files"
Assert ($pdfRow -lt $txtRow)               ".pdf (2 MB) comes before .txt (1 MB)"
Assert ($emptyRow -eq 1)                   "row for files without extension"
Assert ($totalRow -eq 1)                   "total: 4 files, 3 MB"

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
