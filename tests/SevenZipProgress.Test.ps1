# Test for the progress 7-Zip reports with -bsp1.
# 7-Zip writes progress frames to stdout: "  50%", ended by a bare CR, then a
# frame of spaces which erases it. They must reach Write-Progress as a percent
# and must not end up in Compress-Detail.txt, which keeps only the "+ file" lines
# and the messages. A fake 7-Zip writes the same frames as the real one; the real
# 7-Zip is used too, when it is installed.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\SevenZipProgress.Test.ps1

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

# A function shadows the cmdlet of the same name: this records every progress percent and status
$ProgressPercents = New-Object System.Collections.ArrayList
$ProgressStatus   = New-Object System.Collections.ArrayList
Function Write-Progress { param($Activity, $Status, $CurrentOperation, $PercentComplete, [switch]$Completed)
	If($Status) { [void]$script:ProgressStatus.Add([string]$Status) }
	If($null -ne $PercentComplete) { [void]$script:ProgressPercents.Add([int]$PercentComplete) } }

Assert ($null -ne (Get-Command Invoke-Archiving -ErrorAction SilentlyContinue)) "precondition, Invoke-Archiving found in 7zBackup.ps1"

# Runs Invoke-Archiving with the given 7-Zip, in a new work folder with the files of $files in the root dir
Function Invoke-Case ([string]$bin, [string[]]$files, [int]$major) {
	$script:work      = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
	$script:BkRootDir = Join-Path $work "root"
	New-Item -ItemType Directory $BkRootDir, "$work\dest" -Force | Out-Null
	$script:BkCatalogInclude = Join-Path $BkRootDir "Catalog-Include.txt"
	[System.IO.File]::WriteAllLines($BkCatalogInclude, $files)
	$script:BkCompressDetail = Join-Path $BkRootDir "Compress-Detail.txt"
	New-Item -ItemType File $BkCompressDetail -Force | Out-Null
	$rnd = New-Object System.Random 1
	foreach ($file in $files) { $bytes = New-Object byte[] (6MB); $rnd.NextBytes($bytes); [System.IO.File]::WriteAllBytes((Join-Path $BkRootDir $file), $bytes) }
	$script:Bk7ZipBin       = $bin
	$script:BkDryRun        = $False
	$script:BkType          = "copy"
	$script:BkClearBit      = $False
	$script:BkDestPath      = "$work\dest"
	$script:BkArchivePrefix = "test"
	$script:BkArchiveType   = "7z"
	$script:BkArchiveName   = "test-copy-20260913-120000.7z"
	$script:BkArchiveCompression = 1
	$script:Counters        = @{ Exclusions = 0; Warnings = 0; Exceptions = 0; Criticals = 0; FoldersDone = 1; FilesProcessed = 1; FilesSelected = $files.Count; BytesSelected = [int64]($files.Count * 6MB); BytesAvailable = [int64]0; PlaceHolders = @(); Extensions = @{} }
	$script:SWriters        = @{}
	$script:MyContext       = [hashtable]::Synchronized(@{ Cancelling = $False; Logger = (New-Object System.Text.StringBuilder); StartDir = $env:TEMP; SelectionStart = (Get-Date); SevenZBinVersionInfo = @{ ProductVersion = "$major.00"; Major = "$major" } })
	$script:ProgressPercents.Clear(); $script:ProgressStatus.Clear()
	Set-Location -Path $BkRootDir
	Invoke-Archiving
	Set-Location -Path $env:TEMP
}

Write-Host "`n Case: fake 7-Zip writing progress frames"
# Frames as the real 7-Zip writes them: percent, CR, spaces, CR. Kept running 3 s, so the polling loop sees them
$writer = Join-Path $env:TEMP ("7zb-fake-" + [guid]::NewGuid().ToString("N").Substring(0, 8) + ".ps1")
Set-Content -LiteralPath $writer -Encoding Ascii -Value @(
	'$out = [Console]::Out',
	'$out.Write("`r`n7-Zip fake`r`n`r`n  0M Scan  C:\data\`r                       `r")',
	'$out.Write("  0%`r    `r+ a.bin`r`n")',
	'$out.Write(" 25%`r    `r 50%`r    `r+ b.bin`r`n")',
	'$out.Write(" 75% 1`r      `r")',
	'$out.Flush()',
	'Start-Sleep -Seconds 3',
	'$out.Write(" 99% 2`r      `r`r`nEverything is Ok`r`n")'
)
$fake = Join-Path $env:TEMP ("7zb-fake-" + [guid]::NewGuid().ToString("N").Substring(0, 8) + ".cmd")
Set-Content -LiteralPath $fake -Encoding Ascii -Value @('@echo off', ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $writer), 'exit /b 0')
Invoke-Case $fake @("a.bin", "b.bin") 19
$detail = @([System.IO.File]::ReadAllLines($BkCompressDetail))
Assert (($detail -join "|") -eq "7-Zip fake|+ a.bin|+ b.bin|Everything is Ok") "Compress-Detail.txt has the messages and files only, no progress frame [$($detail -join ' | ')]"
Assert ($ProgressPercents -contains 75)                                  "the percent reaches Write-Progress [$($ProgressPercents -join ',')]"
Assert (($ProgressPercents | Where-Object { $_ -ge 0 } | Select-Object -Last 1) -ge 75) "the last percent is not lost [$($ProgressPercents -join ',')]"
Assert (@($ProgressStatus | Where-Object { $_ -match '^Progress 7[0-9]% - ([1-9]|Waiting)' }).Count -ge 1)  "the status text shows the percent and the size [$(($ProgressStatus | Select-Object -Unique) -join ' | ')]"
Remove-Item -LiteralPath $work, $writer, $fake -Recurse -Force

Write-Host "`n Case: real 7-Zip"
$real = Join-Path $env:ProgramFiles "7-Zip\7z.exe"
If(Test-Path -LiteralPath $real) {
	$version = [int](Get-Item -LiteralPath $real).VersionInfo.ProductVersion.Split(".")[0]
	Invoke-Case $real @("a.bin", "b.bin", "c.bin") $version
	$detail = @([System.IO.File]::ReadAllLines($BkCompressDetail))
	Assert (@($detail | Where-Object { $_ -match '%' -or $_ -match '^\s+$' }).Count -eq 0) "Compress-Detail.txt has no progress frame [$(@($detail | Where-Object { $_ -match '%' -or $_ -match '^\s+$' }).Count) found]"
	Assert (@($detail | Where-Object { $_ -match '^\+ [abc]\.bin$' }).Count -eq 3)           "Compress-Detail.txt lists the 3 files"
	Assert ($Bk7ZipRetc -eq 0 -and (Get-ChildItem -LiteralPath "$work\dest").Count -eq 1)    "the archive was created [exit $Bk7ZipRetc]"
	Assert (@($ProgressPercents | Where-Object { $_ -gt 0 -and $_ -lt 100 }).Count -ge 1)    "the real percent reaches Write-Progress [$($ProgressPercents -join ',')]"
	Assert (@($ProgressStatus | Where-Object { $_ -match '^Progress [0-9]+% - [0-9][0-9.,]* (B|KiB|MiB)$' }).Count -ge 1) "the status shows the percent and the formatted size [$(($ProgressStatus | Select-Object -Unique) -join ' | ')]"
	Remove-Item -LiteralPath $work -Recurse -Force
} Else {
	Write-Host " SKIP : $real not found"
}

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
