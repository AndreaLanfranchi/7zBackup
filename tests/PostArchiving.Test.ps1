# Integration test for Complete-Archiving.
# Only files really stored in the archive may be deleted (move) or have
# their Archive bit cleared (full / incr).
# 7-Zip prints "+ file" for a file it cannot open, exits with code 1 and
# does not store it: the locked file below reproduces that case.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\PostArchiving.Test.ps1

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
	param([string]$label, [string]$type, [bool]$clearBit, [string[]]$extraSwitches = @(), [string]$password, [switch]$corruptArchive)

	Write-Host "`n Case: $label"
	$work  = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
	$alias = Join-Path $work "root\Alias"
	New-Item -ItemType Directory $alias -Force | Out-Null

	$nonAscii = "perch" + [char]0x00E9 + ".txt"
	$names = @("ok.txt", $nonAscii, "locked.txt", "br[1].txt", "noindex.txt", "readonly.txt")
	foreach ($name in $names) {
		Set-Content -LiteralPath (Join-Path $alias $name) -Value $name
		(Get-Item -LiteralPath (Join-Path $alias $name)).Attributes = [System.IO.FileAttributes]::Archive
	}
	# An attribute Set-ItemProperty refuses to write back, like those of OneDrive files (issue #13)
	(Get-Item -LiteralPath (Join-Path $alias "noindex.txt")).Attributes = [System.IO.FileAttributes]"Archive, NotContentIndexed"
	# A read-only file: move must still delete it
	(Get-Item -LiteralPath (Join-Path $alias "readonly.txt")).Attributes = [System.IO.FileAttributes]"Archive, ReadOnly"
	$list = Join-Path $work "root\Catalog-Include.txt"
	[System.IO.File]::WriteAllLines($list, [string[]]($names | ForEach-Object { "Alias\$_" }), (New-Object System.Text.UTF8Encoding $True))

	# State Complete-Archiving reads from script scope
	$script:BkType           = $type
	$script:BkClearBit       = $clearBit
	$script:BkDryRun         = $False
	$script:BkRootDir        = Join-Path $work "root"
	$script:BkCatalogInclude = $list
	$script:BkCompressDetail = Join-Path $work "root\Compress-Detail.txt"
	$script:BkDestFile       = Join-Path $work "$label.7z"
	$script:Counters         = @{ Warnings = 0; PlaceHolders = @() }
	$script:MyContext        = [hashtable]::Synchronized(@{ Cancelling = $False; Logger = (New-Object System.Text.StringBuilder); SevenZBinVersionInfo = @{ Major = "$SevenZipMajor" } })
	# Same as 7zBackup.ps1: encrypted headers are used only together with a password
	If($password) { $script:BkArchivePassword = $password; $extraSwitches += @("-p$password", "-mhe") }
	Else { Remove-Variable -Name BkArchivePassword -Scope Script }

	# Same switches as 7zBackup.ps1 for 7-Zip 15+, with the file locked and no read sharing
	$lock = [System.IO.File]::Open((Join-Path $alias "locked.txt"), 'Open', 'ReadWrite', 'None')
	Push-Location $script:BkRootDir
	$sevenZipArgs = @("a", "-ssw", "-slp", "-scsUTF-8", "-sccDOS", "-bd", "-bb1", "-bsp0", "-bso1", "-bse2", "-mtm=on", "-mtc=on", "-mta=on") + $extraSwitches + @("-t7z", $script:BkDestFile, "@$list")
	& $Bk7ZipBin $sevenZipArgs 2>$null | Out-File $script:BkCompressDetail -Encoding UTF8
	$exitCode = $LASTEXITCODE
	Pop-Location
	$lock.Close()   # lock released before post-archiving: worst case

	Assert ($exitCode -eq 1) "${label}: precondition, 7-Zip exits with 1 (locked file not stored)"

	If($corruptArchive) { Set-Content -LiteralPath $script:BkDestFile -Value "not an archive" }

	$Error.Clear()
	Complete-Archiving

	If(!$corruptArchive) {
		$performance = [regex]::Match($script:MyContext.Logger.ToString(), 'Performance\s+:\s+([0-9.,]+) files/sec').Groups[1].Value
		Assert ($performance -match '[1-9]')                                          "${label}: performance line shows a non-zero files/sec [$performance]"
		Assert (@($Error | Where-Object { "$_" -match 'PercentComplete' }).Count -eq 0) "${label}: progress percent stays within 0-100"
	}

	$locked = Join-Path $alias "locked.txt"
	If($corruptArchive) {
		Assert (Test-Path -LiteralPath (Join-Path $alias "ok.txt")) "${label}: ok.txt is kept when the archive can not be listed"
		Assert (Test-Path -LiteralPath $locked)                     "${label}: locked.txt is kept when the archive can not be listed"
		Assert ($script:Counters.Warnings -ge 1)                    "${label}: a warning is counted"
	} ElseIf($type -eq "move") {
		Assert (!(Test-Path -LiteralPath (Join-Path $alias "ok.txt")))  "${label}: archived ok.txt is deleted"
		Assert (!(Test-Path -LiteralPath (Join-Path $alias $nonAscii))) "${label}: archived non-ASCII file is deleted"
		Assert (Test-Path -LiteralPath $locked)                         "${label}: locked.txt (not in archive) is kept"
		Assert (!(Test-Path -LiteralPath (Join-Path $alias "br[1].txt"))) "${label}: archived name with brackets is deleted"
		Assert (!(Test-Path -LiteralPath (Join-Path $alias "noindex.txt"))) "${label}: archived NotContentIndexed file is deleted"
		Assert (!(Test-Path -LiteralPath (Join-Path $alias "readonly.txt"))) "${label}: archived read-only file is deleted"
	} Else {
		Assert (!(Test-ArchiveBit (Join-Path $alias "ok.txt")))  "${label}: archived ok.txt has Archive bit cleared"
		Assert (!(Test-ArchiveBit (Join-Path $alias $nonAscii))) "${label}: archived non-ASCII file has Archive bit cleared"
		Assert (Test-ArchiveBit $locked)                         "${label}: locked.txt (not in archive) keeps Archive bit"
		Assert (!(Test-ArchiveBit (Join-Path $alias "br[1].txt")))   "${label}: archived name with brackets has Archive bit cleared"
		Assert (!(Test-ArchiveBit (Join-Path $alias "noindex.txt"))) "${label}: archived NotContentIndexed file has Archive bit cleared"
		$readOnly = (Get-Item -LiteralPath (Join-Path $alias "readonly.txt") -Force).Attributes
		Assert (!($readOnly -band [System.IO.FileAttributes]::Archive) -and ($readOnly -band [System.IO.FileAttributes]::ReadOnly)) "${label}: archived read-only file has Archive bit cleared and stays read-only [$readOnly]"
		Assert ($script:Counters.Warnings -eq 1)                     "${label}: only locked.txt is a warning, no FAILED [got: $($script:Counters.Warnings)]"
	}

	Remove-Item -LiteralPath $work -Recurse -Force
}

Invoke-Case -label "move"          -type "move" -clearBit $False
Invoke-Case -label "incr"          -type "incr" -clearBit $True
Invoke-Case -label "move-volumes"  -type "move" -clearBit $False -extraSwitches @("-v1m")
Invoke-Case -label "move-password" -type "move" -clearBit $False -password "Secret1"
Invoke-Case -label "move-corrupt"  -type "move" -clearBit $False -corruptArchive

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
