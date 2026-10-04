# Integration tests for Invoke-FolderScan (selection scan).
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\ProcessFolder.Test.ps1

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

# The script body loop that walks catalogFolders: the scan runs it, not a copy that could drift from it
$scanLoop = @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.WhileStatementAst] -and $_.Extent.Text.Contains('Invoke-FolderScan $catalogFolders') })
Assert ($scanLoop.Count -eq 1) "precondition, scan loop found in the script body"

Function New-WorkDir {
	$work = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
	New-Item -ItemType Directory $work -Force | Out-Null
	Write-Output $work
}

# Scans $source aliased as $aliasName the way the 7zBackup.ps1 script body does.
# Returns the lines written to the inclusion catalog; exclusions are left in $work\Exclusions.txt.
Function Invoke-Scan ([string]$work, [string]$source, [switch]$lowerCaseDrive, [string]$aliasName = "Alias") {
	$script:BkRootDir = Join-Path $work "root"
	# --workdrive accepts a lowercase letter: the root dir path then differs in case from paths PowerShell returns
	If($lowerCaseDrive) { $script:BkRootDir = $script:BkRootDir.Substring(0, 1).ToLower() + $script:BkRootDir.Substring(1) }
	New-Item -ItemType Directory $script:BkRootDir -Force | Out-Null
	# 7zBackup.ps1 links each source into the root dir: a junction does the same without admin rights
	cmd /c "mklink /J `"$script:BkRootDir\$aliasName`" `"$source`"" | Out-Null

	$script:BkSources = @{ $aliasName = $source }
	$script:Counters  = @{ Exclusions = 0; Exceptions = 0; FoldersDone = 0; FilesProcessed = 0; FilesSelected = 0; BytesSelected = [int64]0; PlaceHolders = @(); Extensions = @{} }
	$script:MyContext = [hashtable]::Synchronized(@{ Cancelling = $False; Logger = (New-Object System.Text.StringBuilder); SelectionStart = (Get-Date); SevenZBinVersionInfo = @{ Major = 24 } })
	$inclusions      = Join-Path $work "Catalog-Include.txt"
	$script:SWriters  = @{ Inclusions = (New-Object System.IO.StreamWriter($inclusions, $False, [System.Text.Encoding]::UTF8)) }
	foreach ($name in "Exclusions", "Exceptions") { $script:SWriters[$name] = New-Object System.IO.StreamWriter((Join-Path $work "$name.txt"), $False, [System.Text.Encoding]::ASCII) }

	$script:catalogFolders      = New-Object System.Collections.ArrayList
	$script:catalogFoldersIndex = 0
	[void]$script:catalogFolders.Add(@{ Name = $aliasName; FullName = "$script:BkRootDir\$aliasName"; RelativeName = $aliasName; ContainerAlias = $aliasName; RealName = $source; Depth = 0 })
	Set-Location -Path $script:BkRootDir
	# Dot-sourced in this function, the loop increments a local copy of catalogFoldersIndex: it starts from 0 all the same
	. ([scriptblock]::Create($scanLoop[0].Extent.Text))
	Set-Location -Path $env:TEMP
	$script:SWriters.Values | ForEach-Object { $_.Close() }
	cmd /c "rd `"$script:BkRootDir\$aliasName`""
	Write-Output @(Get-Content -LiteralPath $inclusions -Encoding UTF8)
}

# -----------------------------------------------------------------------------
Write-Host "`n Case: nofollowjunctions must not drop folders enumerated after a skipped junction"
$work   = New-WorkDir
$source = Join-Path $work "source"
# source\Parent holds AJunction (enumerated first, points outside), B and C
New-Item -ItemType Directory "$source\Parent\B", "$source\Parent\C", "$work\elsewhere" -Force | Out-Null
Set-Content -LiteralPath "$source\Parent\B\b.txt" -Value "b"
Set-Content -LiteralPath "$source\Parent\C\c.txt" -Value "c"
Set-Content -LiteralPath "$work\elsewhere\e.txt" -Value "e"
cmd /c "mklink /J `"$source\Parent\AJunction`" `"$work\elsewhere`"" | Out-Null
Assert ([int]((Get-Item -LiteralPath "$source\Parent\AJunction" -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) "precondition, AJunction is a junction"

$BkType = "full"; $BkNoFollowJunctions = $True; $BkDryRun = $False; $matchcleanupfiles = $null
$included = @(Invoke-Scan $work $source)
$excluded = @(Get-Content -LiteralPath "$work\Exclusions.txt")
Assert ($included -contains "Alias\Parent\B\b.txt") "file in B (after the skipped junction) is selected"
Assert ($included -contains "Alias\Parent\C\c.txt") "file in C (after the skipped junction) is selected"
Assert (@($included -like "*e.txt").Count -eq 0)    "file behind the skipped junction is not selected"
Assert (@($excluded | Where-Object { $_.EndsWith("`tnofollowjunctions`tD`t$source\Parent\AJunction") }).Count -eq 1) "the skipped junction itself is named in the exclusion log"

cmd /c "rd `"$source\Parent\AJunction`""
Remove-Item -LiteralPath $work -Recurse -Force

# -----------------------------------------------------------------------------
foreach ($dryRun in $False, $True) {
	Write-Host "`n Case: matchcleanupfiles (dry run = $dryRun)"
	$work   = New-WorkDir
	$source = Join-Path $work "source"
	New-Item -ItemType Directory $source -Force | Out-Null
	Set-Content -LiteralPath "$source\junk.tmp" -Value "junk"
	Set-Content -LiteralPath "$source\junk[1].tmp" -Value "junk"
	Set-Content -LiteralPath "$source\keep.txt" -Value "keep"
	Set-Content -LiteralPath "$source\keep2.txt" -Value "keep two"

	$BkType = "full"; $BkNoFollowJunctions = $False; $BkDryRun = $dryRun; $matchcleanupfiles = '\.tmp$'
	$included = @(Invoke-Scan $work $source)
	If($dryRun) {
		Assert (Test-Path -LiteralPath "$source\junk.tmp")  "dry run: matching file stays on disk"
	} Else {
		Assert (!(Test-Path -LiteralPath "$source\junk.tmp")) "matching file is deleted from source"
		Assert (!(Test-Path -LiteralPath "$source\junk[1].tmp")) "matching file with [ ] in its name is deleted from source"
	}
	Assert (!($included -contains "Alias\junk.tmp"))  "matching file is not selected for the archive"
	Assert (!($included -contains "Alias\junk[1].tmp")) "matching file with [ ] in its name is not selected"
	Assert (Test-Path -LiteralPath "$source\keep.txt") "other file stays on disk"
	Assert ($included -contains "Alias\keep.txt")      "other file is selected"
	Assert ($Counters.FoldersDone -eq 1)               "the only folder is scanned once [$($Counters.FoldersDone)]"
	# @(): with no totals, indexing $null would throw and skip the Assert silently
	$txtTotals = @($Counters.Extensions[".txt"])
	$txtBytes = (Get-Item -LiteralPath "$source\keep.txt").Length + (Get-Item -LiteralPath "$source\keep2.txt").Length
	Assert (($txtTotals.Count -eq 2) -and ($txtTotals[0] -eq 2) -and ($txtTotals[1] -eq $txtBytes)) "statistics count the 2 .txt files and their $txtBytes bytes [$($txtTotals -join ', ')]"

	Remove-Item -LiteralPath $work -Recurse -Force
}

# -----------------------------------------------------------------------------
Write-Host "`n Case: root dir on a lowercase drive letter (--workdrive c)"
$work   = New-WorkDir
$source = Join-Path $work "source"
New-Item -ItemType Directory "$source\sub", "$source\skip" -Force | Out-Null
Set-Content -LiteralPath "$source\sub\deep.txt" -Value "deep"
Set-Content -LiteralPath "$source\skip\skipped.txt" -Value "skipped"

$BkType = "full"; $BkNoFollowJunctions = $False; $BkDryRun = $False; $matchcleanupfiles = $null; $matchexcludepath = '^Alias\\skip$'
$included = @(Invoke-Scan $work $source -lowerCaseDrive)
Assert ($included -contains "Alias\sub\deep.txt")      "file in a subfolder is selected with its path relative to the root dir"
Assert (@($included -like "*skipped.txt").Count -eq 0) "matchexcludepath anchored on the alias still excludes its folder"

Remove-Item -LiteralPath $work -Recurse -Force

# -----------------------------------------------------------------------------
Write-Host "`n Case: an empty folder matching matchexcludepath is not kept as an empty folder"
$work   = New-WorkDir
$source = Join-Path $work "source"
New-Item -ItemType Directory "$source\skip", "$source\emptyok" -Force | Out-Null
Set-Content -LiteralPath "$source\keep.txt" -Value "keep"

$BkType = "full"; $BkNoFollowJunctions = $False; $BkDryRun = $False; $matchcleanupfiles = $null; $matchexcludepath = '^Alias\\skip$'; $BkKeepEmptyDirs = $True
$included = @(Invoke-Scan $work $source)
Assert ($included -contains "Alias\emptyok")  "precondition, an empty folder not matching is kept [$($included -join ', ')]"
Assert (!($included -contains "Alias\skip"))  "the empty excluded folder is not selected [$($included -join ', ')]"

$BkKeepEmptyDirs = $null
Remove-Item -LiteralPath $work -Recurse -Force

# -----------------------------------------------------------------------------
Write-Host "`n Case: real path in the exclusion log when a folder name contains the alias (alias Docs, folder MyDocs)"
$work   = New-WorkDir
$source = Join-Path $work "source"
New-Item -ItemType Directory "$source\MyDocs\sub" -Force | Out-Null
Set-Content -LiteralPath "$source\MyDocs\sub\f.txt" -Value "f"

$BkType = "full"; $BkNoFollowJunctions = $False; $BkDryRun = $False; $matchcleanupfiles = $null; $matchexcludepath = '^Docs\\MyDocs\\sub$'
$included = @(Invoke-Scan $work $source -aliasName "Docs")
$excluded = @(Get-Content -LiteralPath "$work\Exclusions.txt")
Assert (@($excluded | Where-Object { $_.EndsWith("`tmatchexcludepath`tD`t$source\MyDocs\sub") }).Count -eq 1) "excluded folder is logged with its real path [$($excluded -join ' | ')]"

Remove-Item -LiteralPath $work -Recurse -Force

# -----------------------------------------------------------------------------
foreach ($filter in "maxfileage", "minfileage") {
	Write-Host "`n Case: $filter 5 with a 10 days old file and a new file"
	$work   = New-WorkDir
	$source = Join-Path $work "source"
	New-Item -ItemType Directory $source -Force | Out-Null
	Set-Content -LiteralPath "$source\old.txt" -Value "old"
	Set-Content -LiteralPath "$source\new.txt" -Value "new"
	(Get-Item -LiteralPath "$source\old.txt").LastWriteTime = (Get-Date).AddDays(-10)

	$BkType = "full"; $BkNoFollowJunctions = $False; $BkDryRun = $False; $matchcleanupfiles = $null; $matchexcludepath = $null
	$BkMaxFileAge = $null; $BkMinFileAge = $null
	If($filter -eq "maxfileage") { $BkMaxFileAge = 5; $kept = "new.txt"; $dropped = "old.txt" } Else { $BkMinFileAge = 5; $kept = "old.txt"; $dropped = "new.txt" }
	$included = @(Invoke-Scan $work $source)
	$excluded = @(Get-Content -LiteralPath "$work\Exclusions.txt")
	Assert (($included -contains "Alias\$kept") -and !($included -contains "Alias\$dropped")) "${filter}: $kept is selected, $dropped is not [$($included -join ', ')]"
	Assert (@($excluded | Where-Object { $_.EndsWith("`t$filter`tF`t$source\$dropped") }).Count -eq 1) "${filter}: the exclusion log names $dropped [$($excluded -join ' | ')]"

	$BkMaxFileAge = $null; $BkMinFileAge = $null
	Remove-Item -LiteralPath $work -Recurse -Force
}

# -----------------------------------------------------------------------------
Write-Host "`n Case: unreadable entries (denied folder, denied file, path over 260 characters) do not drop readable ones"
$work   = New-WorkDir
$source = Join-Path $work "source"
New-Item -ItemType Directory "$source\Parent\ADenied", "$source\Parent\B", "$source\Parent\C" -Force | Out-Null
Set-Content -LiteralPath "$source\Parent\ADenied\inside.txt" -Value "inside"
Set-Content -LiteralPath "$source\Parent\B\b.txt" -Value "b"
Set-Content -LiteralPath "$source\Parent\denied.txt" -Value "denied"
Set-Content -LiteralPath "$source\Parent\ok.txt" -Value "ok"
Set-Content -LiteralPath "$source\Parent\C\short.txt" -Value "short"
$longName = ("L" * 240) + ".txt"
[System.IO.File]::WriteAllText("\\?\$source\Parent\C\$longName", "long")
# The owner can always change the permissions again: no admin rights needed to deny and restore
icacls "$source\Parent\ADenied" /deny "${env:USERNAME}:(RD)" | Out-Null
icacls "$source\Parent\denied.txt" /deny "${env:USERNAME}:(R)" | Out-Null
$deniedFolderThrows = $False
Try { [void]([System.IO.DirectoryInfo]"$source\Parent\ADenied").GetFileSystemInfos() } Catch { $deniedFolderThrows = $True }
Assert $deniedFolderThrows "precondition, ADenied cannot be listed"
Assert ([System.IO.File]::Exists("\\?\$source\Parent\C\$longName") -and ("$work\root\Alias\Parent\C\$longName".Length -gt 260)) "precondition, long file exists with a path over 260 characters"

$BkType = "full"; $BkNoFollowJunctions = $False; $BkDryRun = $False; $matchcleanupfiles = $null; $matchexcludepath = $null
$included   = @(Invoke-Scan $work $source)
$exceptions = @(Get-Content -LiteralPath "$work\Exceptions.txt")
Assert ($included -contains "Alias\Parent\ok.txt")         "readable file next to the denied folder is selected [$($included -join ', ')]"
Assert ($included -contains "Alias\Parent\B\b.txt")        "file in the folder after the denied one is selected"
Assert ($included -contains "Alias\Parent\denied.txt")     "denied file is still listed: 7-Zip reports it when it cannot read it"
Assert ($included -contains "Alias\Parent\C\short.txt")    "short file next to the long one is selected"
Assert ($included -contains "Alias\Parent\C\$longName")    "file with a path over 260 characters is selected"
Assert (@($included -like "*inside.txt").Count -eq 0)      "file inside the denied folder is not selected"
Assert (($exceptions.Count -eq 1) -and ($exceptions[0] -eq "0`tUnauthorizedAccessException`t$source\Parent\ADenied")) "the denied folder is logged once as an exception [$($exceptions -join ' | ')]"

icacls "$source\Parent\ADenied" /remove:d "$env:USERNAME" | Out-Null
icacls "$source\Parent\denied.txt" /remove:d "$env:USERNAME" | Out-Null
[System.IO.File]::Delete("\\?\$source\Parent\C\$longName")
Remove-Item -LiteralPath $work -Recurse -Force

# -----------------------------------------------------------------------------
Write-Host "`n Case: exception ids in the log match the ids in the exceptions file"
$work   = New-WorkDir
$source = Join-Path $work "source"
New-Item -ItemType Directory "$source\ADenied", "$source\CleanDir", "$source\Files" -Force | Out-Null
Set-Content -LiteralPath "$source\locked.tmp" -Value "locked"
Set-Content -LiteralPath "$source\CleanDir\denied.txt" -Value "denied"
Set-Content -LiteralPath "$source\Files\denied.tmp" -Value "denied"
icacls "$source\ADenied" /deny "${env:USERNAME}:(RD)" | Out-Null
# A file open without sharing cannot be deleted: matchcleanupfiles fails on it
$lockedFile = [System.IO.File]::Open("$source\locked.tmp", "Open", "Read", "None")
# Deleting a file is allowed by DELETE on the file or DELETE_CHILD on its folder: deny both, matchcleanupdirs and matchcleanupfiles fail
foreach ($deniedFile in "$source\CleanDir\denied.txt", "$source\Files\denied.tmp") {
	icacls (Split-Path $deniedFile) /deny "${env:USERNAME}:(DC)" | Out-Null
	icacls $deniedFile /deny "${env:USERNAME}:(D)" | Out-Null
}

$BkType = "full"; $BkNoFollowJunctions = $False; $BkDryRun = $False; $matchcleanupfiles = '\.tmp$'; $matchcleanupdirs = '\\CleanDir$'; $matchexcludepath = $null
$included   = @(Invoke-Scan $work $source)
$lockedFile.Close()
$fileIds = @(Get-Content -LiteralPath "$work\Exceptions.txt" | ForEach-Object { $_.Split("`t")[0] })
$logIds  = @($MyContext.Logger.ToString().Split("`n") | Where-Object { $_ -match '^ Exception id (\d+) on ' } | ForEach-Object { $_ -replace '^ Exception id (\d+) on .*$', '$1' })
Assert (($fileIds -join ",") -eq "0,1,2,3") "precondition, removal of a file, listing of a folder, removal of a folder and of a denied file fail [$($fileIds -join ',')]"
Assert (($logIds -join ",") -eq ($fileIds -join ",")) "log ids match the exceptions file ids [log $($logIds -join ',') / file $($fileIds -join ',')]"
# denied.txt cannot be deleted: the line names the real error, not the ArgumentException of Remove-Item in PowerShell 5.1
$cleanDirLine = @(Get-Content -LiteralPath "$work\Exceptions.txt")[2]
Assert ($cleanDirLine -eq "2`tUnauthorizedAccessException`t$source\CleanDir") "failed folder removal is one line with the real error and the real path [$cleanDirLine]"
# The error names the file through the root dir link, which is removed after the job: the line has the real path
$lockedFileLine = @(Get-Content -LiteralPath "$work\Exceptions.txt")[0]
Assert ($lockedFileLine -eq "0`tIOException`t$source\locked.tmp") "failed file removal has the real path [$lockedFileLine]"
$deniedFileLine = @(Get-Content -LiteralPath "$work\Exceptions.txt")[3]
Assert ($deniedFileLine -eq "3`tUnauthorizedAccessException`t$source\Files\denied.tmp") "denied file removal names the real error [$deniedFileLine]"

$matchcleanupfiles = $null; $matchcleanupdirs = $null
icacls "$source\ADenied" /remove:d "$env:USERNAME" | Out-Null
foreach ($deniedFile in "$source\CleanDir\denied.txt", "$source\Files\denied.tmp") {
	icacls $deniedFile /remove:d "$env:USERNAME" | Out-Null
	icacls (Split-Path $deniedFile) /remove:d "$env:USERNAME" | Out-Null
}
Remove-Item -LiteralPath $work -Recurse -Force

# -----------------------------------------------------------------------------
Write-Host "`n Case: cleanup removes read-only, hidden and system items and does not enter links"
$work   = New-WorkDir
$source = Join-Path $work "source"
New-Item -ItemType Directory "$source\Junk\RoSub", "$work\outside" -Force | Out-Null
Set-Content -LiteralPath "$source\keep.txt" -Value "keep"
Set-Content -LiteralPath "$source\old.tmp" -Value "old"
Set-Content -LiteralPath "$source\hidden.tmp" -Value "hidden"
Set-Content -LiteralPath "$source\Junk\ro.txt" -Value "ro"
Set-Content -LiteralPath "$source\Junk\hs.txt" -Value "hs"
Set-Content -LiteralPath "$source\Junk\RoSub\inner.txt" -Value "inner"
Set-Content -LiteralPath "$work\outside\target.txt" -Value "target"
cmd /c "mklink /J `"$source\Junk\link`" `"$work\outside`"" | Out-Null
foreach ($readOnlyFile in "$source\old.tmp", "$source\Junk\ro.txt", "$source\Junk\RoSub\inner.txt", "$work\outside\target.txt") { [System.IO.File]::SetAttributes($readOnlyFile, "ReadOnly") }
foreach ($hiddenFile in "$source\hidden.tmp", "$source\Junk\hs.txt") { [System.IO.File]::SetAttributes($hiddenFile, "Hidden, System") }
foreach ($readOnlyFolder in "$source\Junk", "$source\Junk\RoSub", "$work\outside") { [System.IO.File]::SetAttributes($readOnlyFolder, "Directory, ReadOnly") }

$BkType = "full"; $BkNoFollowJunctions = $False; $BkDryRun = $False; $matchcleanupfiles = '\.tmp$'; $matchcleanupdirs = '\\Junk$'; $matchexcludepath = $null
$included   = @(Invoke-Scan $work $source)
$exceptions = @(Get-Content -LiteralPath "$work\Exceptions.txt")
Assert ($exceptions.Count -eq 0) "no exception [$($exceptions -join ' | ')]"
Assert (!(Test-Path -LiteralPath "$source\old.tmp") -and !(Test-Path -LiteralPath "$source\hidden.tmp")) "read-only and hidden system cleanup files are removed"
Assert (!(Test-Path -LiteralPath "$source\Junk")) "read-only cleanup folder is removed with its read-only, hidden, system items and link"
Assert ($included -contains "Alias\keep.txt") "other file is selected [$($included -join ', ')]"
Assert (Test-Path -LiteralPath "$work\outside\target.txt") "the file behind the link survives"
Assert ((([int][System.IO.File]::GetAttributes("$work\outside\target.txt") -band 1) -ne 0) -and (([int][System.IO.File]::GetAttributes("$work\outside") -band 1) -ne 0)) "the link target and its file keep their read-only flag"

$matchcleanupfiles = $null; $matchcleanupdirs = $null
If(Test-Path -LiteralPath "$source\Junk\link") { cmd /c "rd `"$source\Junk\link`"" }
cmd /c "attrib -r -h -s `"$work\*`" /s /d" | Out-Null
Remove-Item -LiteralPath $work -Recurse -Force

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
