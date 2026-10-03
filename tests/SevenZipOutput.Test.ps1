# Integration test for reading 7-Zip output in the archiving block.
# A fake 7-Zip prints 20,000 lines on stdout and 3 lines on stderr at once, then
# exits: every stdout line must reach Compress-Detail.txt in order, and every
# stderr line must be logged once, as its own line, in order.
# A second fake 7-Zip exits at once while a child writes its last lines later:
# they must still reach Compress-Detail.txt and the log.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\SevenZipOutput.Test.ps1

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

Write-Host "`n Case: 20,000 stdout lines and 3 stderr lines, printed at once"
$work      = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
$BkRootDir = Join-Path $work "root"
New-Item -ItemType Directory $BkRootDir, "$work\dest" -Force | Out-Null
$BkCatalogInclude = Join-Path $BkRootDir "Catalog-Include.txt"
New-Item -ItemType File $BkCatalogInclude -Force | Out-Null
$BkCompressDetail = Join-Path $BkRootDir "Compress-Detail.txt"
New-Item -ItemType File $BkCompressDetail -Force | Out-Null

# Fake 7-Zip: prints prepared files on stdout and stderr, then exits with 1 (warnings)
$outLines = @(1..20000 | ForEach-Object { "+ Alias\file{0:d5}.txt" -f $_ })
$errLines = @("err line 1", "err line 2", "err line 3")
[System.IO.File]::WriteAllLines("$work\out.txt", [string[]]$outLines)
[System.IO.File]::WriteAllLines("$work\err.txt", [string[]]$errLines)
$fake7z = Join-Path $work "7z-fake.cmd"
Set-Content -LiteralPath $fake7z -Encoding Ascii -Value @(
	'@echo off',
	('type "{0}"' -f "$work\out.txt"),
	('type "{0}" 1>&2' -f "$work\err.txt"),
	'exit /b 1'
)

# State the script body has prepared before the archiving block
$Bk7ZipBin       = $fake7z
$BkDryRun        = $False
$BkType          = "copy"
$BkClearBit      = $False
$BkDestPath      = "$work\dest"
$BkArchivePrefix = "test"
$BkArchiveType   = "7z"
$BkArchiveName   = "test-copy-20260913-120000.7z"
$totalBytes      = [int64]0
$Counters        = @{ Exclusions = 0; Warnings = 0; Exceptions = 0; Criticals = 0; FoldersDone = 1; FilesProcessed = 1; FilesSelected = 1; BytesSelected = [int64]1; BytesAvailable = [int64]0; PlaceHolders = @(); Extensions = @{} }
$SWriters        = @{}
$MyContext       = [hashtable]::Synchronized(@{ Cancelling = $False; Logger = (New-Object System.Text.StringBuilder); StartDir = $env:TEMP; WinVer = @("10"); SelectionStart = (Get-Date); SevenZBinVersionInfo = @{ ProductVersion = "19.00"; Major = "19" } })
Set-Location -Path $BkRootDir

. ([scriptblock]::Create($archivingBlock.Extent.Text))
Set-Location -Path $env:TEMP

$detail = @([System.IO.File]::ReadAllLines($BkCompressDetail))
$firstDifference = -1
for ($i = 0; $i -lt [Math]::Min($detail.Count, $outLines.Count); $i++) { If($detail[$i] -ne $outLines[$i]) { $firstDifference = $i; break } }
$logLines = @($MyContext.Logger.ToString().Split("`n") | ForEach-Object { $_.TrimEnd() } | Where-Object { $_.StartsWith(" !") })

Assert ($Bk7ZipRetc -eq 1)                                   "precondition, the fake 7-Zip exits with 1"
Assert ($detail.Count -eq $outLines.Count)                   "Compress-Detail.txt has all 20,000 stdout lines [$($detail.Count)]"
Assert ($firstDifference -eq -1)                             "stdout lines are in order [first difference at $firstDifference]"
Assert (($logLines -join "|") -eq " !err line 1| !err line 2| !err line 3") "each stderr line is logged once, in order [$($logLines -join ' | ')]"

Remove-Item -LiteralPath $work -Recurse -Force

Write-Host "`n Case: last lines arrive after 7-Zip is seen as exited"
# A background child keeps the output pipes open: the fake 7-Zip exits at once, its last lines
# (the very last one without a newline) arrive about 4 seconds later. The test checks the order of events, not elapsed time
$work      = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
$BkRootDir = Join-Path $work "root"
New-Item -ItemType Directory $BkRootDir, "$work\dest" -Force | Out-Null
$BkCatalogInclude = Join-Path $BkRootDir "Catalog-Include.txt"
New-Item -ItemType File $BkCatalogInclude -Force | Out-Null
$BkCompressDetail = Join-Path $BkRootDir "Compress-Detail.txt"
New-Item -ItemType File $BkCompressDetail -Force | Out-Null
[System.IO.File]::WriteAllText("$work\late-out.txt", "+ Alias\late.txt`r`n")
[System.IO.File]::WriteAllText("$work\late-err.txt", "late err 1`r`nlate err 2")
$lateCmd = Join-Path $work "late.cmd"
Set-Content -LiteralPath $lateCmd -Encoding Ascii -Value @(
	'@echo off',
	'ping -n 5 127.0.0.1 >nul',
	('echo late> "{0}"' -f "$work\late-start.txt"),   # marks the moment the late lines are written
	('type "{0}"' -f "$work\late-out.txt"),
	('type "{0}" 1>&2' -f "$work\late-err.txt")
)
$fake7z = Join-Path $work "7z-fake.cmd"
Set-Content -LiteralPath $fake7z -Encoding Ascii -Value @(
	'@echo off',
	'echo + Alias\early.txt',
	'1>&2 echo early err',
	('start /b "" cmd /c "{0}"' -f $lateCmd),
	'exit /b 1'
)

$Bk7ZipBin  = $fake7z
$BkDestPath = "$work\dest"
$SWriters   = @{}
$MyContext  = [hashtable]::Synchronized(@{ Cancelling = $False; Logger = (New-Object System.Text.StringBuilder); StartDir = $env:TEMP; WinVer = @("10"); SelectionStart = (Get-Date); SevenZBinVersionInfo = @{ ProductVersion = "19.00"; Major = "19" } })
Set-Location -Path $BkRootDir

. ([scriptblock]::Create($archivingBlock.Extent.Text))
Set-Location -Path $env:TEMP

$detail   = @([System.IO.File]::ReadAllLines($BkCompressDetail))
$logLines = @($MyContext.Logger.ToString().Split("`n") | ForEach-Object { $_.TrimEnd() } | Where-Object { $_.StartsWith(" !") })

Assert ($Bk7ZipRetc -eq 1)                                                          "precondition, the fake 7-Zip exits with 1"
$lateStart = (Get-Item -LiteralPath "$work\late-start.txt").LastWriteTime
Assert ($oProcess.ExitTime -lt $lateStart)                                          "precondition, the fake 7-Zip exited before the late lines were written [exit $($oProcess.ExitTime.ToString('HH:mm:ss.fff')), late $($lateStart.ToString('HH:mm:ss.fff'))]"
Assert (($detail -join "|") -eq "+ Alias\early.txt|+ Alias\late.txt")               "Compress-Detail.txt has the late stdout line [$($detail -join ' | ')]"
Assert (($logLines -join "|") -eq " !early err| !late err 1| !late err 2")          "late stderr lines are logged, the last one without a newline too [$($logLines -join ' | ')]"

Remove-Item -LiteralPath $work -Recurse -Force

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
