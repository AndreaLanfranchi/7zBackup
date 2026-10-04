# Integration test for the catalog check in Complete-Archiving.
# A selected item missing from the finished archive must be logged as
# NOT ARCHIVED and counted, for every backup type, unless 7-Zip already
# reported it. Items really stored (files, empty folders, support files)
# must not be reported.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\NotArchived.Test.ps1

$ErrorActionPreference = "SilentlyContinue"   # same as 7zBackup.ps1

# Load function definitions only: the script body is not executed
$scriptFile = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\7zBackup.ps1"))
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile, [ref]$null, [ref]$null)
foreach ($fn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $False)) {
	. ([scriptblock]::Create($fn.Extent.Text))
}

$Bk7ZipBin = @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
If(!$Bk7ZipBin) { Write-Host " 7z.exe not found"; exit 1 }
$SevenZipMajor = [int](Get-Item $Bk7ZipBin).VersionInfo.ProductVersion.Split(".")[0]
If($SevenZipMajor -lt 15) { Write-Host " This test needs 7-Zip 15 or newer"; exit 1 }

$Failures = 0
Function Assert ([bool]$condition, [string]$message) {
	If($condition) { Write-Host " PASS : $message" -ForegroundColor Green }
	Else { Write-Host " FAIL : $message" -ForegroundColor Red; $script:Failures++ }
}

Function Test-ArchiveBit ([string]$path) {
	Write-Output ([int]((Get-Item -LiteralPath $path -Force).Attributes -band [System.IO.FileAttributes]::Archive) -ne 0)
}

Function Invoke-Case {
	param([string]$label, [string]$type, [bool]$clearBit, [string[]]$reported = @(), [string[]]$expectNotArchived = @(), [int]$expectWarnings)

	Write-Host "`n Case: $label"
	$work  = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
	$root  = Join-Path $work "root"
	$alias = Join-Path $root "Alias"
	New-Item -ItemType Directory (Join-Path $alias "sub"), (Join-Path $alias "empty") -Force | Out-Null

	$nonAscii = "perch" + [char]0x00E9 + ".txt"
	$files = @("ok.txt", $nonAscii, "sub\deep.txt", "locked.txt")
	foreach ($name in $files) {
		Set-Content -LiteralPath (Join-Path $alias $name) -Value $name
		(Get-Item -LiteralPath (Join-Path $alias $name)).Attributes = [System.IO.FileAttributes]::Archive
	}
	# Same kinds of lines 7zBackup.ps1 writes: files, an empty folder, a support file in the root dir
	$list = Join-Path $root "Catalog-Include.txt"
	$catalog = @($files | ForEach-Object { "Alias\$_" }) + @("Alias\empty", "Catalog-Include.txt")
	[System.IO.File]::WriteAllLines($list, [string[]]$catalog, (New-Object System.Text.UTF8Encoding $True))

	# State Complete-Archiving reads from script scope
	$script:BkType           = $type
	$script:BkClearBit       = $clearBit
	$script:BkDryRun         = $False
	$script:BkRootDir        = $root
	$script:BkCatalogInclude = $list
	$script:BkCompressDetail = Join-Path $root "Compress-Detail.txt"
	$script:BkDestFile       = Join-Path $work "$type.7z"
	$script:Counters         = @{ Warnings = 0; PlaceHolders = @() }
	$script:MyContext        = [hashtable]::Synchronized(@{ Cancelling = $False; Logger = (New-Object System.Text.StringBuilder); SevenZBinVersionInfo = @{ Major = "$SevenZipMajor" } })
	Remove-Variable -Name BkArchivePassword -Scope Script
	# Items 7-Zip reported while adding: the same table the script body builds from its warning lines
	Remove-Variable -Name warningItems -Scope Script
	If($reported) { $script:warningItems = @{}; foreach ($item in $reported) { $script:warningItems[$item] = $True } }

	# Same switches as 7zBackup.ps1 for 7-Zip 15+, with locked.txt locked and no read sharing: it is not stored
	$lock = [System.IO.File]::Open((Join-Path $alias "locked.txt"), 'Open', 'ReadWrite', 'None')
	Push-Location $root
	$sevenZipArgs = @("a", "-ssw", "-slp", "-scsUTF-8", "-sccDOS", "-bd", "-bb1", "-bsp0", "-bso1", "-bse2", "-mtm=on", "-mtc=on", "-mta=on", "-t7z", $script:BkDestFile, "@$list")
	& $Bk7ZipBin $sevenZipArgs 2>$null | Out-File $script:BkCompressDetail -Encoding UTF8
	$exitCode = $LASTEXITCODE
	Pop-Location
	$lock.Close()

	Assert ($exitCode -eq 1) "${label}: precondition, 7-Zip exits with 1 (locked file not stored)"

	Complete-Archiving $script:warningItems

	$log = $script:MyContext.Logger.ToString()
	$notArchived = @([regex]::Matches($log, 'NOT ARCHIVED : ([^\r\n]+)') | ForEach-Object { $_.Groups[1].Value.Trim() })
	Assert (($notArchived -join "|") -eq ($expectNotArchived -join "|")) "${label}: NOT ARCHIVED lists [$($expectNotArchived -join ', ')] [got: $($notArchived -join ', ')]"
	Assert ($script:Counters.Warnings -eq $expectWarnings)                "${label}: $expectWarnings warning(s) counted [got: $($script:Counters.Warnings)]"

	# The check must not change what each type does with archived files
	$ok = Join-Path $alias "ok.txt"
	If($type -eq "move")  { Assert (!(Test-Path -LiteralPath $ok))  "${label}: archived ok.txt is deleted" }
	ElseIf($clearBit)     { Assert (!(Test-ArchiveBit $ok))         "${label}: archived ok.txt has Archive bit cleared" }
	Else                  { Assert (Test-ArchiveBit $ok)            "${label}: ok.txt keeps Archive bit (no clearbit)" }

	Remove-Item -LiteralPath $work -Recurse -Force
}

Invoke-Case -label "full, silent miss"         -type "full" -clearBit $False -expectNotArchived @("Alias\locked.txt") -expectWarnings 1
Invoke-Case -label "move, silent miss"         -type "move" -clearBit $False -expectNotArchived @("Alias\locked.txt") -expectWarnings 1
Invoke-Case -label "incr, reported by 7-Zip"   -type "incr" -clearBit $True  -reported @("Alias\locked.txt")          -expectWarnings 0

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
