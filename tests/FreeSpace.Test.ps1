# Test for GetDestPathFreeSpace: free bytes of the drive or share holding a path.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\FreeSpace.Test.ps1

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

$drive    = [System.IO.Path]::GetPathRoot($env:TEMP)
$expected = ([System.IO.DriveInfo]$drive).AvailableFreeSpace

Write-Host "`n Case: local path"
$free = GetDestPathFreeSpace -target $env:TEMP
Assert ($free -is [int64])                                  "returns an int64"
Assert ([math]::Abs($free - $expected) -lt 100MB)           "matches the drive free space [$free ~ $expected]"

Write-Host "`n Case: drive root"
Assert ([math]::Abs((GetDestPathFreeSpace -target $drive) - $expected) -lt 100MB) "drive root works [$drive]"

Write-Host "`n Case: UNC path (administrative share of this PC)"
$unc = "\localhost\" + $drive.Substring(0, 1) + "$\Windows"
If(Test-Path -LiteralPath $unc) {
	Assert ([math]::Abs((GetDestPathFreeSpace -target $unc) - $expected) -lt 100MB) "UNC path works [$unc]"
} Else {
	Write-Host " SKIP : $unc is not reachable"
}

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
