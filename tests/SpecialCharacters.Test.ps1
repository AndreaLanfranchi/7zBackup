# Test for paths with square brackets or an equal sign, and for the inline
# extra files of the notification email:
# - [ and ] in a path are not wildcards (destination, selection file, source,
#   link name, root dir, rotation folder, write test)
# - "includesource=path|alias=name" keeps an "=" inside the path
# - an inline extra file keeps its line breaks
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\SpecialCharacters.Test.ps1

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

$work = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -LiteralPath "$work" -Force | Out-Null
Function New-Folder ([string]$path) { [void][System.IO.Directory]::CreateDirectory($path) }

Write-Host "`n Case: Assert-Variables with [ ] in the destination and in the selection file"
New-Folder "$work\dest[1]"; New-Folder "$work\sel[1]"; New-Folder "$work\source"
$selection = "$work\sel[1]\selection.txt"
[System.IO.File]::WriteAllLines($selection, [string[]]@("includesource=$work\source|alias=Source"))
$MyContext       = [hashtable]::Synchronized(@{ PSVer = [int]$PSVersionTable.PSVersion.Major; WinVer = @("10"); Logger = (New-Object System.Text.StringBuilder) })
$BkType          = "full"
$BkSelection     = $selection
$BkDestPath      = "$work\dest[1]"
$BkArchivePrefix = "test"
$errors = @(Assert-Variables)
Assert (@($errors | Where-Object { $_ -match "destpath" }).Count -eq 0)    "destination dest[1] is accepted [$($errors -join ' | ')]"
Assert (@($errors | Where-Object { $_ -match "selection" }).Count -eq 0)   "selection file in sel[1] is accepted [$($errors -join ' | ')]"
Assert ($BkSelectionContents.Count -eq 1)                                  "selection file in sel[1] is read [$($BkSelectionContents.Count) lines]"

Write-Host "`n Case: Test-WritablePath with [ ] in the folder"
Assert ((Test-WritablePath "$work\dest[1]" "File") -eq $True)              "dest[1] is writable"
Assert (@(Get-ChildItem -LiteralPath "$work\dest[1]").Count -eq 0)         "the test file is removed again"

Write-Host "`n Case: sources and links with [ ] or = in their names"
New-Folder "$work\src[1]"; New-Folder "$work\a=b"
$BkRootDir = "$work\root[1]"; New-Folder $BkRootDir
$BkSources = @{}
$BkSelectionContents = @("includesource=$work\src[1]|alias=Al[1]", "includesource=$work\a=b|alias=Eq")
New-SourceLinks
Assert ($BkSources.ContainsKey("Al[1]") -and $BkSources["Al[1]"] -eq "$work\src[1]")   "source src[1] is linked as Al[1]"
Assert ($BkSources.ContainsKey("Eq") -and $BkSources["Eq"] -eq "$work\a=b")            "source a=b keeps its = [$($BkSources["Eq"])]"
Assert ((Get-Item -LiteralPath "$BkRootDir\Al[1]" -Force).LinkType -eq "Junction")     "the link Al[1] exists in root[1]"

Write-Host "`n Case: Remove-RootDir with [ ] in the root dir"
$removed = Remove-RootDir $BkRootDir
Assert ($removed -eq $True)                                                 "root[1] is removed [$removed]"
Assert (!(Test-Path -LiteralPath $BkRootDir))                               "root[1] is gone"
Assert (Test-Path -LiteralPath "$work\src[1]")                              "the source behind the link is untouched"

Write-Host "`n Case: rotation in a folder with [ ] in its name"
$dest = "$work\dest[1]"
foreach ($name in "srv-full-20260102-120000.7z", "srv-full-20260101-120000.7z") { [System.IO.File]::WriteAllText("$dest\$name", $name) }
$BkDestPath = $dest; $BkArchivePrefix = "srv"; $BkType = "full"; $BkArchiveName = "srv-full-20260102-120000.7z"; $BkRotate = 1
$MyContext = [hashtable]::Synchronized(@{ Logger = (New-Object System.Text.StringBuilder) })
Invoke-Rotation
Assert (Test-Path -LiteralPath "$dest\srv-full-20260102-120000.7z")          "new archive is kept"
Assert (!(Test-Path -LiteralPath "$dest\srv-full-20260101-120000.7z"))       "old archive is removed"

Write-Host "`n Case: inline extra files keep their line breaks"
$BkRootDir = "$work\extras"; New-Folder $BkRootDir
[System.IO.File]::WriteAllText("$BkRootDir\Catalog-Exclude.csv", "line one`r`nline two`r`n")
$BkNotifyLog = "a@example.com"; $BkNotifyLogCc = $null; $BkNotifyLogBcc = $null; $BkMailSubject = "s"; $BkNotifyExtra = "inline"
$Counters = @{ Warnings = 0; Criticals = 0 }
$MyContext = [hashtable]::Synchronized(@{ Logger = (New-Object System.Text.StringBuilder) })
$content = Get-NotificationContent
Assert ($content.Body.Contains("line one`nline two"))                        "the lines of the extra file are on separate lines [$($content.Body -replace "`n", '|')]"

Remove-Item -LiteralPath $work -Recurse -Force
Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
