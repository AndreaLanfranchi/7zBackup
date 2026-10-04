# Test for the 7-Zip exit code handling of the archiving block.
# A fake 7-Zip exits with a given code and, for some cases, leaves a partial
# archive behind. Fatal codes must be logged, counted as critical, and the
# partial archive removed.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\ExitCodes.Test.ps1

$ErrorActionPreference = "SilentlyContinue"   # same as 7zBackup.ps1

# Load function definitions and the archiving block only: the script body is not executed
$scriptFile = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\7zBackup.ps1"))
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile, [ref]$null, [ref]$null)
foreach ($fn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $False)) {
	. ([scriptblock]::Create($fn.Extent.Text))
}
$archivingBlock = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] -and $n.Clauses[0].Item1.Extent.Text -eq '$BkDryRun -ne $True' }, $False)

$Failures = 0
Function Assert ([bool]$condition, [string]$message) {
	If($condition) { Write-Host " PASS : $message" -ForegroundColor Green }
	Else { Write-Host " FAIL : $message" -ForegroundColor Red; $script:Failures++ }
}

Assert ($null -ne $archivingBlock) "precondition, archiving block found in 7zBackup.ps1"

$work      = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
$BkRootDir = Join-Path $work "root"
New-Item -ItemType Directory $BkRootDir, "$work\dest" -Force | Out-Null
$BkCatalogInclude = Join-Path $BkRootDir "Catalog-Include.txt"
New-Item -ItemType File $BkCatalogInclude -Force | Out-Null
$BkCompressDetail = Join-Path $BkRootDir "Compress-Detail.txt"
$BkDestPath = "$work\dest"
$archive    = "$BkDestPath\test.7z"

# Code: exit code of the fake. Text: what the log must contain. Critical: expected critical count
$cases = @(
	@{ Code = 255; Text = "User has stopped 7-Zip archiving process"; Critical = 1; Left = $False },
	@{ Code = 2;   Text = "7-Zip reported a fatal error";             Critical = 1; Left = $False },
	@{ Code = 7;   Text = "wrong command line";                      Critical = 1; Left = $False; Extra = "-t7z" },
	@{ Code = 8;   Text = "not enough memory";                       Critical = 1; Left = $False },
	@{ Code = 3;   Text = "NO ARCHIVE HAS BEEN CREATED";             Critical = 1; Left = $False; Leave = $False },
	@{ Code = 1;   Text = "";                                        Critical = 0; Left = $True;  Leave = $True }
)

foreach ($case in $cases) {
	Write-Host "`n Case: 7-Zip exit code $($case.Code)"
	$fake7z = Join-Path $work "7z-fake.cmd"
	$lines = @('@echo off')
	If($case.Code -ne 3) { $lines += ('echo partial> "{0}"' -f $archive) }
	$lines += ('exit /b {0}' -f $case.Code)
	Set-Content -LiteralPath $fake7z -Encoding Ascii -Value $lines
	Remove-Item -LiteralPath $archive -Force
	Set-Content -LiteralPath $BkCompressDetail -Value ""

	$Bk7ZipBin       = $fake7z
	$BkDryRun        = $False
	$BkType          = "copy"
	$BkClearBit      = $False
	$BkArchiveType   = "7z"
	$BkArchiveName   = "test.7z"
	$totalBytes      = [int64]0
	$Counters        = @{ Exclusions = 0; Warnings = 0; Exceptions = 0; Criticals = 0; FoldersDone = 1; FilesProcessed = 1; FilesSelected = 1; BytesSelected = [int64]1; BytesAvailable = [int64]0; PlaceHolders = @(); Extensions = @{} }
	$SWriters        = @{}
	$MyContext       = [hashtable]::Synchronized(@{ Cancelling = $False; Logger = (New-Object System.Text.StringBuilder); StartDir = $env:TEMP; SelectionStart = (Get-Date); SevenZBinVersionInfo = @{ ProductVersion = "19.00"; Major = "19" } })
	Remove-Variable -Name Bk7ZipRetc -Scope Script
	Set-Location -Path $BkRootDir
	. ([scriptblock]::Create($archivingBlock.Extent.Text))
	Set-Location -Path $env:TEMP
	$log = $MyContext.Logger.ToString()

	Assert ($Bk7ZipRetc -eq $case.Code)                          "precondition, exit code is $($case.Code)"
	Assert ($log.Contains($case.Text))                           "log says [$($case.Text)]"
	Assert ($Counters.Criticals -eq $case.Critical)              "critical count is $($case.Critical) [$($Counters.Criticals)]"
	Assert ((Test-Path -LiteralPath $archive) -eq $case.Left)    "partial archive left on disk: $($case.Left)"
	If($case.Extra) { Assert ($log.Contains($case.Extra))        "log shows the command line [$($case.Extra)]" }
}

Remove-Item -LiteralPath $work -Recurse -Force
Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
