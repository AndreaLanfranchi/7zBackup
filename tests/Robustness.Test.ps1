# Test for robustness fixes:
# - an invalid regular expression in the selection file is an error, not silently ignored
# - New-LockFile creates the lock file only when it does not exist
# - --help is the exact argument, not a part of another one
# - an option without a value (last argument, or followed by another option) is an error
# - the sources are scanned in the order of the selection file
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\Robustness.Test.ps1

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
New-Item -ItemType Directory "$work\dest", "$work\source" -Force | Out-Null
$selection = Join-Path $work "selection.txt"

# Runs Assert-Variables on a selection file with the given lines; returns the errors
Function Invoke-Validation ([string[]]$lines) {
	Set-Content -LiteralPath $selection -Value $lines
	$script:MyContext       = [hashtable]::Synchronized(@{ PSVer = [int]$PSVersionTable.PSVersion.Major; WinVer = @("10"); Logger = (New-Object System.Text.StringBuilder) })
	$script:BkType          = "full"
	$script:BkSelection     = $selection
	$script:BkDestPath      = "$work\dest"
	$script:BkArchivePrefix = "test"
	Write-Output @(Assert-Variables)
}

Write-Host "`n Case: regular expressions in the selection file"
$source = "includesource=$work\source|alias=Source"
foreach ($rule in "matchexcludefiles", "matchincludefiles", "matchcleanupfiles", "matchcleanupdirs", "matchexcludepath", "matchstoprecurse") {
	$errors = @(Invoke-Validation @($source, "$rule=(unclosed") | Where-Object { $_ -match $rule })
	Assert ($errors.Count -eq 1) "invalid $rule is reported [$($errors -join ' | ')]"
}
$errors = @(Invoke-Validation @($source, "matchexcludefiles=\.tmp$", "matchexcludefiles=^~", "matchexcludefiles=", "matchstoprecurse=^\.git$") | Where-Object { $_ -match "match" })
Assert ($errors.Count -eq 0) "valid and empty expressions are accepted [$($errors -join ' | ')]"

Write-Host "`n Case: lock file creation"
Assert ($null -ne (Get-Command New-LockFile -ErrorAction SilentlyContinue)) "precondition, New-LockFile exists"
$BkLockFile = Join-Path $work "7zBackup.lock"
$BkRootDir  = Join-Path $work "root"
$MyContext  = [hashtable]::Synchronized(@{})
Assert ((New-LockFile) -eq $True)                                       "the first run creates the lock"
$content = @(Get-Content -LiteralPath $BkLockFile)
Assert ($content -contains "PID=$PID" -and $content -contains "Root=$BkRootDir") "the lock holds the PID and the root dir"
Set-Content -LiteralPath $BkLockFile -Value "PID=1"
Assert ((New-LockFile) -eq $False)                                      "a second run does not replace an existing lock"
Assert ((Get-Content -LiteralPath $BkLockFile) -eq "PID=1")              "the existing lock is untouched"

Write-Host "`n Case: --help"
Function Invoke-Script ([string[]]$arguments) {
	@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptFile @arguments 2>&1) -join "`n"
}
Assert ((Invoke-Script "--help") -match "Usage :")                       "--help prints the help"
Assert ((Invoke-Script "--HELP") -match "Usage :")                       "--HELP prints the help"
Assert ((Invoke-Script "--prefix", "my--helpful") -notmatch "Usage :")   "an argument containing --help does not print the help"

Write-Host "`n Case: options without a value"
Function Invoke-Parser ([string[]]$arguments) {
	Get-Variable -Name "Bk*" -Scope Script | ForEach-Object { Remove-Variable -Name $_.Name -Scope Script }
	$script:BkArguments = $arguments
	Write-Output @(Assert-Arguments)
}
$messages = @(Invoke-Parser "--destpath")
Assert ($messages.Count -eq 1 -and $messages[0] -match "--destpath")                 "an option as last argument is reported [$($messages -join ' | ')]"
$messages = @(Invoke-Parser "--type", "--dry")
Assert ($messages.Count -eq 1 -and $messages[0] -match "--type" -and $BkDryRun -eq $True) "an option followed by an option is reported, the second one is still read [$($messages -join ' | ')]"
$messages = @(Invoke-Parser "--password", "--secret")
Assert ($messages.Count -eq 0 -and $BkArchivePassword -ceq "--secret")               "a value starting with -- which is not an option is accepted"

Write-Host "`n Case: sources are scanned in the order of the selection file"
$aliases = "Zulu", "Alpha", "Mike", "Bravo", "Yankee", "Charlie", "Xray", "Delta"
$lines = @()
foreach ($alias in $aliases) {
	New-Item -ItemType Directory "$work\src-$alias" -Force | Out-Null
	Set-Content -LiteralPath "$work\src-$alias\file.txt" -Value $alias
	$lines += "includesource=$work\src-$alias|alias=$alias"
}
Set-Content -LiteralPath "$work\order.txt" -Value $lines
$catalogCopy = Join-Path $work "catalog.txt"
Set-Content -LiteralPath "$work\post.ps1" -Value ('Copy-Item -LiteralPath "Catalog-Include.txt" -Destination "{0}"' -f $catalogCopy)
$null = Invoke-Script "--type", "copy", "--selection", "$work\order.txt", "--destpath", "$work\dest", "--prefix", "order", "--dry", "--post", "$work\post.ps1"
$scanned = @(Get-Content -LiteralPath $catalogCopy | Where-Object { $_ -match "file\.txt" } | ForEach-Object { $_.Split("\")[0] })
Assert (($scanned -join ",") -eq ($aliases -join ","))                   "catalog order follows the selection file [$($scanned -join ',')]"

Remove-Item -LiteralPath $work -Recurse -Force
Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
