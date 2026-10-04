# Integration test for the archive size shown while 7-Zip compresses.
# A folder listing reports the size an open file had when the listing was last
# updated, often 0 while 7-Zip writes. A fake 7-Zip writes 5 MB and keeps the
# archive open for 8 seconds: the progress, polled every 2.5 seconds, must show
# the size while the file is open, not keep saying "Waiting for archive".
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\ArchiveProgress.Test.ps1

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

# A function shadows the cmdlet of the same name: this records every progress status
$ProgressStatus = New-Object System.Collections.ArrayList
Function Write-Progress { param($Activity, $Status, $CurrentOperation, $PercentComplete, [switch]$Completed) If($Status) { [void]$script:ProgressStatus.Add([string]$Status) } }

Assert ($null -ne $archivingBlock) "precondition, archiving block found in 7zBackup.ps1"

Write-Host "`n Case: archive kept open by 7-Zip while it grows"
$work      = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
$BkRootDir = Join-Path $work "root"
New-Item -ItemType Directory $BkRootDir, "$work\dest" -Force | Out-Null
$BkCatalogInclude = Join-Path $BkRootDir "Catalog-Include.txt"
New-Item -ItemType File $BkCatalogInclude -Force | Out-Null
$BkCompressDetail = Join-Path $BkRootDir "Compress-Detail.txt"
New-Item -ItemType File $BkCompressDetail -Force | Out-Null
$BkArchiveName = "test-copy-20260913-120000.7z"

# Fake 7-Zip: writes 5 MB into the archive and keeps it open for 8 seconds, like 7-Zip does while compressing
$writer = Join-Path $work "writer.ps1"
Set-Content -LiteralPath $writer -Encoding Ascii -Value @(
	('$file = [System.IO.File]::Open("{0}", "Create", "Write", "Read")' -f "$work\dest\$BkArchiveName"),
	'$bytes = New-Object byte[] (5MB)',
	'$file.Write($bytes, 0, $bytes.Length)',
	'$file.Flush()',
	'Start-Sleep -Seconds 8',
	'$file.Close()'
)
$fake7z = Join-Path $work "7z-fake.cmd"
Set-Content -LiteralPath $fake7z -Encoding Ascii -Value @(
	'@echo off',
	('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $writer),
	'exit /b 0'
)

# State the script body has prepared before the archiving block
$Bk7ZipBin       = $fake7z
$BkDryRun        = $False
$BkType          = "copy"
$BkClearBit      = $False
$BkDestPath      = "$work\dest"
$BkArchivePrefix = "test"
$BkArchiveType   = "7z"
$totalBytes      = [int64]0
$Counters        = @{ Exclusions = 0; Warnings = 0; Exceptions = 0; Criticals = 0; FoldersDone = 1; FilesProcessed = 1; FilesSelected = 1; BytesSelected = [int64]1; BytesAvailable = [int64]0; PlaceHolders = @(); Extensions = @{} }
$SWriters        = @{}
$MyContext       = [hashtable]::Synchronized(@{ Cancelling = $False; Logger = (New-Object System.Text.StringBuilder); StartDir = $env:TEMP; SelectionStart = (Get-Date); SevenZBinVersionInfo = @{ ProductVersion = "19.00"; Major = "19" } })
Set-Location -Path $BkRootDir

. ([scriptblock]::Create($archivingBlock.Extent.Text))
Set-Location -Path $env:TEMP

# At most one poll can come after the file is closed: 2 or more sizes mean the open file was measured
$polls = @($ProgressStatus | Where-Object { $_ -match '^(Waiting for archive|Archive Size)' })
$sizes = @($polls | Where-Object { $_ -match '^Archive Size [1-9]' })
Assert ($polls.Count -ge 3) "precondition, the polling loop ran while the archive was open [$($polls.Count) polls]"
Assert ($sizes.Count -ge 2) "the progress shows the size of the open archive [$($polls -join ' | ')]"

Remove-Item -LiteralPath $work -Recurse -Force

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
