# Integration tests for log messages that expanded variables wrongly
# ("$_.Exception.Message", "$_.Name", undefined $cmdLine).
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\LogMessages.Test.ps1

$ErrorActionPreference = "SilentlyContinue"   # same as 7zBackup.ps1

# Load function definitions and the needed script body blocks only: the script body is not executed
$scriptFile = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\7zBackup.ps1"))
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile, [ref]$null, [ref]$null)
foreach ($fn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $False)) {
	. ([scriptblock]::Create($fn.Extent.Text))
}
Function Find-IfBlock ([string]$condition) {
	$ast.Find({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] -and $n.Clauses[0].Item1.Extent.Text -eq $condition }, $True)
}
$preActionBlock = Find-IfBlock 'Test-Variable "BkPreAction"'

$Failures = 0
Function Assert ([bool]$condition, [string]$message) {
	If($condition) { Write-Host " PASS : $message" -ForegroundColor Green }
	Else { Write-Host " FAIL : $message" -ForegroundColor Red; $script:Failures++ }
}

Assert (($null -ne $preActionBlock) -and ($null -ne (Get-Command Invoke-Rotation -ErrorAction SilentlyContinue)) -and ($null -ne (Get-Command Invoke-Archiving -ErrorAction SilentlyContinue))) "precondition, script body block and functions found"

Function Reset-Context {
	$script:MyContext = [hashtable]::Synchronized(@{ Cancelling = $False; Logger = (New-Object System.Text.StringBuilder); StartDir = $env:TEMP; SelectionStart = (Get-Date) })
	$script:Counters  = @{ Exclusions = 0; Warnings = 0; Exceptions = 0; Criticals = 0; FoldersDone = 1; FilesProcessed = 1; FilesSelected = 1; BytesSelected = [int64]1; BytesAvailable = [int64]0; PlaceHolders = @() }
}

# -----------------------------------------------------------------------------
Write-Host "`n Case: failing post action"
Reset-Context
$BkPostAction = { throw "post action failed" }
Invoke-PostAction
$log = $MyContext.Logger.ToString()
Assert ($log.Contains("post action failed"))    "the error message is logged"
Assert (!$log.Contains(".Exception.Message"))  "no unexpanded property text [$(($log -split "`r?`n" | Where-Object { $_ -match 'failed' }) -join ' | ')]"
Remove-Variable -Name BkPostAction

# -----------------------------------------------------------------------------
Write-Host "`n Case: failing pre action"
Reset-Context
$BkPreAction = { throw "pre action failed" }
. ([scriptblock]::Create($preActionBlock.Extent.Text))
$log = $MyContext.Logger.ToString()
Assert ($log.Contains("pre action failed"))     "the error message is logged"
Assert (!$log.Contains(".Exception.Message"))  "no unexpanded property text [$(($log -split "`r?`n" | Where-Object { $_ -match 'failed' }) -join ' | ')]"
Remove-Variable -Name BkPreAction

# -----------------------------------------------------------------------------
Write-Host "`n Case: rotation can not remove an old archive (file locked)"
Reset-Context
$work = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory $work -Force | Out-Null
$newArchive = "srv-full-20260102-120000.7z"
$oldArchive = "srv-full-20260101-120000.7z"
foreach ($name in $newArchive, $oldArchive) { Set-Content -LiteralPath (Join-Path $work $name) -Value $name }
$BkDestPath = $work; $BkArchivePrefix = "srv"; $BkType = "full"; $BkArchiveName = $newArchive; $BkRotate = 1
$lock = [System.IO.File]::Open((Join-Path $work $oldArchive), 'Open', 'ReadWrite', 'None')
Invoke-Rotation
$lock.Close()
$log = $MyContext.Logger.ToString()
Assert (Test-Path -LiteralPath (Join-Path $work $oldArchive))                              "precondition, the locked archive is still there"
Assert ($log -match "(?m)^ WARNING Failed to remove $([Regex]::Escape($oldArchive))\r?$")  "the failed removal names the archive [$(($log -split "`r?`n" | Where-Object { $_ -match $oldArchive }) -join ' | ')]"
Remove-Item -LiteralPath $work -Recurse -Force

# -----------------------------------------------------------------------------
Write-Host "`n Case: 7-Zip rejects the command line (exit code 7)"
Reset-Context
$real7z = @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
$SevenZipVersion = (Get-Item $real7z).VersionInfo.ProductVersion
$MyContext.SevenZBinVersionInfo = @{ ProductVersion = $SevenZipVersion; Major = $SevenZipVersion.Split(".")[0] }
$work      = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
$BkRootDir = Join-Path $work "root"
New-Item -ItemType Directory "$BkRootDir\Alias", "$work\dest" -Force | Out-Null
Set-Content -LiteralPath "$BkRootDir\Alias\ok.txt" -Value "ok"
$BkCatalogInclude = Join-Path $BkRootDir "Catalog-Include.txt"
[System.IO.File]::WriteAllLines($BkCatalogInclude, [string[]]@("Alias\ok.txt"), (New-Object System.Text.UTF8Encoding $True))
$BkCompressDetail = Join-Path $BkRootDir "Compress-Detail.txt"
New-Item -ItemType File $BkCompressDetail -Force | Out-Null
$Bk7ZipBin = $real7z; $BkDryRun = $False; $BkType = "copy"; $BkClearBit = $False
$BkDestPath = "$work\dest"; $BkArchivePrefix = "test"; $BkArchiveType = "7z"; $BkArchiveName = "test-copy-20260912-120000.7z"
$SWriters = @{}
$BkArchiveVolumes = @("abc")   # invalid volume size: 7-Zip reports a command line error
Set-Location -Path $BkRootDir
Invoke-Archiving
Set-Location -Path $env:TEMP
$log = $MyContext.Logger.ToString()
Assert ($Bk7ZipRetc -eq 7)          "precondition, 7-Zip exits with 7"
Assert ($log.Contains("-vabc"))     "the rejected 7-Zip arguments are logged"
Remove-Variable -Name BkArchiveVolumes
Remove-Item -LiteralPath $work -Recurse -Force

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
