# Integration test for selection file directives read by Assert-Variables.
# maxfilesize, minfilesize, maxfileage, minfileage, compression, threads and
# solid set in the selection file must reach the script, and take precedence
# over command line values.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\SelectionDirectives.Test.ps1

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
Set-Content -LiteralPath $selection -Value @(
	"includesource=$work\source|alias=Source",
	"maxfilesize=1000",
	"minfilesize=10",
	"maxfileage=10",
	"minfileage=1.5",
	"compression=3",
	"threads=1",
	"solid=0"
)

# State as after Assert-Arguments, with compression also given on the command line
$MyContext            = [hashtable]::Synchronized(@{ PSVer = [int]$PSVersionTable.PSVersion.Major; Logger = (New-Object System.Text.StringBuilder) })
$BkType               = "full"
$BkSelection          = $selection
$BkDestPath           = "$work\dest"
$BkArchivePrefix      = "test"
$BkArchiveCompression = "9"

$errors = @(Assert-Variables)

Assert ($errors.Count -eq 0)             "no validation errors [$($errors -join ' | ')]"
Assert ($BkMaxFileSize -eq 1000)         "maxfilesize=1000 is applied"
Assert ($BkMinFileSize -eq 10)           "minfilesize=10 is applied"
Assert ($BkMaxFileAge -eq 10)            "maxfileage=10 (no decimals) is applied"
Assert ($BkMinFileAge -eq 1.5)           "minfileage=1.5 is applied"
Assert ($BkArchiveCompression -eq 3)     "compression=3 is applied and overrides command line 9"
Assert ($BkArchiveThreads -eq 1)         "threads=1 is applied"
Assert ($BkArchiveSolid -eq $False)      "solid=0 turns solid mode off"

Remove-Item -LiteralPath $work -Recurse -Force

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
