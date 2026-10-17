# Test for Format-Size: sizes in the log and the progress bars.
# Whole bytes below 1 KiB, then KiB, MiB, GiB and TiB with 2 decimals.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\FormatSize.Test.ps1

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

Assert ($null -ne (Get-Command Format-Size)) "precondition, Format-Size exists"

# The decimal separator and the thousands separator follow the culture, as the other numbers of the log
$sep = [System.Globalization.CultureInfo]::CurrentCulture.NumberFormat.NumberDecimalSeparator
$grp = [System.Globalization.CultureInfo]::CurrentCulture.NumberFormat.NumberGroupSeparator

$cases = @(
	@(0,                         "0 B"),
	@(1,                         "1 B"),
	@(1023,                      "1023 B"),
	@(1024,                      "1${sep}00 KiB"),
	@(1536,                      "1${sep}50 KiB"),
	@(1048575,                   "1${sep}00 MiB"),
	@(1048576,                   "1${sep}00 MiB"),
	@(5242880,                   "5${sep}00 MiB"),
	@(1073741824,                "1${sep}00 GiB"),
	@([int64]3 * 1099511627776,  "3${sep}00 TiB"),
	@([int64]2048 * 1099511627776, "2${grp}048${sep}00 TiB"),
	@(-1536,                     "-1${sep}50 KiB")
)
foreach ($case in $cases) {
	$text = Format-Size $case[0]
	Assert ($text -ceq $case[1]) "$($case[0]) bytes: '$($case[1])' [$text]"
}

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
