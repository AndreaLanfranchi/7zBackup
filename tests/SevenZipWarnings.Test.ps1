# Integration test for 7-Zip warnings.
# Runs the 7zBackup.ps1 archiving block with real 7-Zip: files 7-Zip can not
# read (missing, locked) must be logged and counted as warnings, and a clean
# run must report none.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\SevenZipWarnings.Test.ps1

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

$Bk7ZipBin = @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
If(!$Bk7ZipBin) { Write-Host " 7z.exe not found"; exit 1 }
$SevenZipVersion = (Get-Item $Bk7ZipBin).VersionInfo.ProductVersion
If([int]$SevenZipVersion.Split(".")[0] -lt 15) { Write-Host " This test needs 7-Zip 15 or newer"; exit 1 }

foreach ($withFailures in $True, $False) {
	Write-Host "`n Case: files 7-Zip can not read = $withFailures"
	$work      = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
	$BkRootDir = Join-Path $work "root"
	$alias     = Join-Path $BkRootDir "Alias"
	New-Item -ItemType Directory $alias, "$work\dest" -Force | Out-Null
	Set-Content -LiteralPath "$alias\ok.txt" -Value "ok"
	$items = @("Alias\ok.txt")
	If($withFailures) {
		Set-Content -LiteralPath "$alias\locked.txt" -Value "locked"
		$items += "Alias\missing.txt", "Alias\locked.txt"
	}
	$BkCatalogInclude = Join-Path $BkRootDir "Catalog-Include.txt"
	[System.IO.File]::WriteAllLines($BkCatalogInclude, [string[]]$items, (New-Object System.Text.UTF8Encoding $True))
	$BkCompressDetail = Join-Path $BkRootDir "Compress-Detail.txt"
	New-Item -ItemType File $BkCompressDetail -Force | Out-Null

	# State the script body has prepared before the archiving block
	$BkDryRun        = $False
	$BkType          = "copy"
	$BkClearBit      = $False
	$BkDestPath      = "$work\dest"
	$BkArchivePrefix = "test"
	$BkArchiveType   = "7z"
	$BkArchiveName   = "test-copy-20260912-120000.7z"
	$totalBytes      = [int64]0
	$Counters        = @{ Exclusions = 0; Warnings = 0; Exceptions = 0; Criticals = 0; FoldersDone = 1; FilesProcessed = $items.Count; FilesSelected = $items.Count; BytesSelected = [int64]1; BytesAvailable = [int64]0; PlaceHolders = @() }
	$SWriters        = @{}
	$MyContext       = [hashtable]::Synchronized(@{ Cancelling = $False; Logger = (New-Object System.Text.StringBuilder); StartDir = $env:TEMP; SelectionStart = (Get-Date); SevenZBinVersionInfo = @{ ProductVersion = $SevenZipVersion; Major = $SevenZipVersion.Split(".")[0] } })
	Set-Location -Path $BkRootDir

	$lock = $null
	If($withFailures) { $lock = [System.IO.File]::Open("$alias\locked.txt", 'Open', 'ReadWrite', 'None') }
	. ([scriptblock]::Create($archivingBlock.Extent.Text))
	If($lock) { $lock.Close() }
	Set-Location -Path $env:TEMP

	$log = $MyContext.Logger.ToString()
	If($withFailures) {
		Assert ($Bk7ZipRetc -eq 1)                               "precondition, 7-Zip exits with 1"
		Assert ($log -match '(?m)^ Alias\\missing\.txt : ')      "missing file is listed under 7-Zip warnings"
		Assert ($log -match '(?m)^ Alias\\locked\.txt : ')       "locked file is listed under 7-Zip warnings"
		Assert ($Counters.Warnings -eq 2)                        "missing and locked files count as 2 warnings"
	} Else {
		Assert ($Bk7ZipRetc -eq 0)                               "precondition, 7-Zip exits with 0"
		Assert (!$log.Contains("7-Zip completed with warnings")) "no 7-Zip warnings section"
		Assert ($Counters.Warnings -eq 0)                        "no warning is counted"
	}

	Remove-Item -LiteralPath $work -Recurse -Force
}

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
