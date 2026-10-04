# Integration test for the archive password.
# Runs the 7zBackup.ps1 archiving block with real 7-Zip, a password and
# encrypted headers: the archive must be protected by the password, and the
# password must not appear on any 7-Zip command line or in verbose output.
# 7-Zip is called through a wrapper that logs every command line.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\ArchivePassword.Test.ps1

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

$real7z = @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
If(!$real7z) { Write-Host " 7z.exe not found"; exit 1 }
$SevenZipVersion = (Get-Item $real7z).VersionInfo.ProductVersion
If([int]$SevenZipVersion.Split(".")[0] -lt 15) { Write-Host " This test needs 7-Zip 15 or newer"; exit 1 }

Write-Host "`n Case: incr backup with password and encrypted headers"
$work      = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
$BkRootDir = Join-Path $work "root"
$alias     = Join-Path $BkRootDir "Alias"
New-Item -ItemType Directory $alias, "$work\dest" -Force | Out-Null
Set-Content -LiteralPath "$alias\ok.txt" -Value "ok"
(Get-Item -LiteralPath "$alias\ok.txt").Attributes = [System.IO.FileAttributes]::Archive
$BkCatalogInclude = Join-Path $BkRootDir "Catalog-Include.txt"
[System.IO.File]::WriteAllLines($BkCatalogInclude, [string[]]@("Alias\ok.txt"), (New-Object System.Text.UTF8Encoding $True))
$BkCompressDetail = Join-Path $BkRootDir "Compress-Detail.txt"
New-Item -ItemType File $BkCompressDetail -Force | Out-Null

# Wrapper: logs the command line, then runs the real 7-Zip (stdin and exit code pass through).
# The space before >> keeps a trailing digit of the arguments from being read as a handle number.
$callsLog = Join-Path $work "calls.log"
$wrapper  = Join-Path $work "7z-wrapper.cmd"
Set-Content -LiteralPath $wrapper -Encoding Ascii -Value @(
	'@echo off',
	('echo %* >>"{0}"' -f $callsLog),
	('"{0}" %*' -f $real7z),
	'exit /b %errorlevel%'
)

# State the script body has prepared before the archiving block
# Non-ASCII part (a-umlaut, CJK) checks the input encoding; the ASCII part is searched in the command line log
$password          = "Secret1" + [char]0x00E4 + [char]0x5BC6
$asciiPart         = "Secret1"
$Bk7ZipBin         = $wrapper
$BkArchivePassword = $password
$BkEncryptHeaders  = $True
$BkDryRun          = $False
$BkType            = "incr"
$BkClearBit        = $True
$BkDestPath        = "$work\dest"
$BkArchivePrefix   = "test"
$BkArchiveType     = "7z"
$BkArchiveName     = "test-incr-20260912-120000.7z"
$totalBytes        = [int64]0
$Counters          = @{ Exclusions = 0; Warnings = 0; Exceptions = 0; Criticals = 0; FoldersDone = 1; FilesProcessed = 1; FilesSelected = 1; BytesSelected = [int64]1; BytesAvailable = [int64]0; PlaceHolders = @() }
$SWriters          = @{}
$MyContext         = [hashtable]::Synchronized(@{ Cancelling = $False; Logger = (New-Object System.Text.StringBuilder); StartDir = $env:TEMP; SelectionStart = (Get-Date); SevenZBinVersionInfo = @{ ProductVersion = $SevenZipVersion; Major = $SevenZipVersion.Split(".")[0] } })
Set-Location -Path $BkRootDir

# Worst case console on any machine: input encoding UTF-8 with BOM (as with code page 65001)
$savedInputEncoding = [Console]::InputEncoding
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$VerbosePreference = "Continue"
$verbose = (. ([scriptblock]::Create($archivingBlock.Extent.Text)) 4>&1 | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } | Out-String)
$VerbosePreference = "SilentlyContinue"
[Console]::InputEncoding = $savedInputEncoding
Set-Location -Path $env:TEMP

$archive = "$work\dest\$BkArchiveName"
$calls   = @(Get-Content -LiteralPath $callsLog)
Assert ($Bk7ZipRetc -eq 0)   "precondition, 7-Zip exits with 0"
Assert ($calls.Count -eq 2)  "precondition, 2 7-Zip calls seen: archive and listing [$($calls.Count)]"
& $real7z t "-p$password" $archive 2>&1 | Out-Null; $rightExit = $LASTEXITCODE
& $real7z t "-pWrong" $archive 2>&1 | Out-Null;    $wrongExit = $LASTEXITCODE
Assert ($rightExit -eq 0)                                                  "archive opens with the password"
Assert ($wrongExit -ne 0)                                                  "archive does not open with a wrong password"
Assert (@($calls | Where-Object { $_.Contains($asciiPart) }).Count -eq 0)  "password is not on any 7-Zip command line [$($calls -join ' || ')]"
Assert (!$verbose.Contains($asciiPart))                                    "password is not in verbose output"
Assert (!((Get-Item -LiteralPath "$alias\ok.txt" -Force).Attributes -band [System.IO.FileAttributes]::Archive)) "archived file has its Archive bit cleared (listing worked)"

Remove-Item -LiteralPath $work -Recurse -Force

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
