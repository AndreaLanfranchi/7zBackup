# Test for the 7-Zip command line built by the archiving block.
# A fake 7-Zip writes the arguments it received to a file. Each case sets the
# variables the script body has prepared and compares the whole argument line.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\ArchiveArguments.Test.ps1

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
$argsFile = Join-Path $work "args.txt"
$fake7z   = Join-Path $work "7z-fake.cmd"
Set-Content -LiteralPath $fake7z -Encoding Ascii -Value @('@echo off', ('echo %*> "{0}"' -f $argsFile), 'exit /b 0')

$BkDestPath = "$work\dest"
$dest       = "`"$BkDestPath\test.7z`""
$catalog    = "@`"$BkCatalogInclude`""

# Setting: variables of the case. Absent variables are removed. Expected: the argument line
$cases = @(
	@{ Name = "7-Zip 19, 7z, compression, threads, solid";  Version = 19; Type = "7z"; Vars = @{ BkArchiveCompression = 5; BkArchiveThreads = 4; BkArchiveSolid = $True }
	   Expected = "a -ssw -slp -mx5 -scsUTF-8 -sccUTF-8 -bd -bb1 -bsp0 -bso1 -bse2 -mtm=on -mtc=on -mta=on -mmt=4 -t7z $dest $catalog" },
	@{ Name = "7-Zip 19, 7z, threads off, not solid";       Version = 19; Type = "7z"; Vars = @{ BkArchiveThreads = 0; BkArchiveSolid = $False }
	   Expected = "a -ssw -slp -scsUTF-8 -sccUTF-8 -bd -bb1 -bsp0 -bso1 -bse2 -mtm=on -mtc=on -mta=on -mmt=off -ms=off -t7z $dest $catalog" },
	@{ Name = "7-Zip 9, zip, volumes, password and headers"; Version = 9;  Type = "zip"; Vars = @{ BkArchiveCompression = 9; BkArchiveVolumes = @("10m", "1g"); BkArchivePassword = "x"; BkEncryptHeaders = $True }
	   Expected = "a -ssw -slp -mx9 -scsUTF-8 -sccUTF-8 -bd -v10m -v1g -tzip -p -mhe $dest $catalog" },
	@{ Name = "7-Zip 19, tar ignores compression";           Version = 19; Type = "tar"; Vars = @{ BkArchiveCompression = 9 }
	   Expected = "a -ssw -slp -scsUTF-8 -sccUTF-8 -bd -bb1 -bsp0 -bso1 -bse2 -ttar $dest $catalog" }
)
$allVars = "BkArchiveCompression", "BkArchiveThreads", "BkArchiveSolid", "BkArchiveVolumes", "BkArchivePassword", "BkEncryptHeaders"

foreach ($case in $cases) {
	Write-Host "`n Case: $($case.Name)"
	foreach ($v in $allVars) { Remove-Variable -Name $v -Scope Script }
	foreach ($v in $case.Vars.Keys) { Set-Variable -Name $v -Value $case.Vars[$v] -Scope Script }
	Remove-Item -LiteralPath $argsFile -Force
	Set-Content -LiteralPath $BkCompressDetail -Value ""

	$Bk7ZipBin       = $fake7z
	$BkDryRun        = $False
	$BkType          = "copy"
	$BkClearBit      = $False
	$BkArchiveType   = $case.Type
	$BkArchiveName   = "test.7z"
	$totalBytes      = [int64]0
	$Counters        = @{ Exclusions = 0; Warnings = 0; Exceptions = 0; Criticals = 0; FoldersDone = 1; FilesProcessed = 1; FilesSelected = 1; BytesSelected = [int64]1; BytesAvailable = [int64]0; PlaceHolders = @(); Extensions = @{} }
	$SWriters        = @{}
	$MyContext       = [hashtable]::Synchronized(@{ Cancelling = $False; Logger = (New-Object System.Text.StringBuilder); StartDir = $env:TEMP; WinVer = @("10"); SelectionStart = (Get-Date); SevenZBinVersionInfo = @{ ProductVersion = "$($case.Version).00"; Major = "$($case.Version)" } })
	Set-Location -Path $BkRootDir
	. ([scriptblock]::Create($archivingBlock.Extent.Text))
	Set-Location -Path $env:TEMP

	$actual = (Get-Content -LiteralPath $argsFile -ErrorAction SilentlyContinue | Select-Object -First 1)
	Assert ($actual -eq $case.Expected) "argument line [$actual]"
}

Remove-Item -LiteralPath $work -Recurse -Force
Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
