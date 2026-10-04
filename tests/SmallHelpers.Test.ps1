# Tests for small helpers: Trace-Warning, Test-Path-Writable and the 7-Zip binary lookup in Assert-Variables.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\SmallHelpers.Test.ps1

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
New-Item -ItemType Directory "$work\dest", "$work\source", "$work\pf\7-Zip", "$work\pf86\7-Zip", "$work\none" -Force | Out-Null

Write-Host "`n Case: Trace-Warning"
$MyContext = [hashtable]::Synchronized(@{ Logger = (New-Object System.Text.StringBuilder) })
$Counters  = @{ Warnings = 0 }
$output = (Trace-Warning " first" 6>&1 | Out-String) + (Trace-Warning " second" 6>&1 | Out-String)
Assert ($Counters.Warnings -eq 2)                                                               "each message counts as one warning [$($Counters.Warnings)]"
Assert ($MyContext.Logger.ToString().Contains(" first") -and $MyContext.Logger.ToString().Contains(" second")) "and is logged"
Assert ($output.Contains("first") -and $output.Contains("second"))                              "and shown on the console"

Write-Host "`n Case: Test-Path-Writable"
Assert ((Test-Path-Writable $work "File") -eq $True)                       "a writable folder is accepted with a file test"
Assert ((Test-Path-Writable $work "Directory") -eq $True)                  "and with a directory test"
Assert (@(Get-ChildItem -LiteralPath $work -Force | Where-Object { $_.Name -match "^[0-9a-f]{8}-" }).Count -eq 0) "the test item is removed"
Assert ((Test-Path-Writable "$work\missing" "File") -eq $False)            "a missing folder is refused"
Assert ((Test-Path-Writable "$work\dest\none.txt" "Directory") -eq $False) "a path which is not a folder is refused"

# A real binary with a version, standing in for 7z.exe
$exe = [System.Management.Automation.PSObject].Assembly.Location
$exeVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($exe).ProductVersion

# Runs Assert-Variables with an otherwise valid setup; returns the errors
$selection = Join-Path $work "selection.txt"
Set-Content -LiteralPath $selection -Value "includesource=$work\source|alias=Source"
Function Invoke-Validation {
	$script:MyContext       = [hashtable]::Synchronized(@{ PSVer = [int]$PSVersionTable.PSVersion.Major; Logger = (New-Object System.Text.StringBuilder) })
	$script:BkType          = "full"
	$script:BkSelection     = $selection
	$script:BkDestPath      = "$work\dest"
	$script:BkArchivePrefix = "test"
	Write-Output @(Assert-Variables)
}

Write-Host "`n Case: 7-Zip version is read from the binary"
Remove-Variable -Name Bk7ZipBin -Scope Script
$script:Bk7ZipBin = $exe
$errors = @(Invoke-Validation | Where-Object { $_ -match "7zipbin" })
$parts = $exeVersion.Split(".")
$info = $MyContext.SevenZBinVersionInfo
Assert ($errors.Count -eq 0)                                                   "the binary is accepted [$($errors -join ' | ')]"
Assert ($info.ProductVersion -eq $exeVersion -and $info.Major -eq $parts[0] -and $info.Minor -eq $parts[1]) "product version, major and minor are read [$($info.ProductVersion) $($info.Major) $($info.Minor) / $exeVersion]"

Write-Host "`n Case: 7-Zip is looked for in the Program Files folders"
$savedPf = $env:ProgramFiles; $savedPf86 = ${env:ProgramFiles(x86)}
Remove-Variable -Name Bk7ZipBin -Scope Script
$env:ProgramFiles = "$work\none"; ${env:ProgramFiles(x86)} = "$work\none"
$errors = @(Invoke-Validation | Where-Object { $_ -match "7zipbin" })
Assert ($errors.Count -eq 1) "not found anywhere: reported [$($errors -join ' | ')]"

Copy-Item -LiteralPath $exe -Destination "$work\pf\7-Zip\7z.exe"
Remove-Variable -Name Bk7ZipBin -Scope Script
$env:ProgramFiles = "$work\pf"
$errors = @(Invoke-Validation | Where-Object { $_ -match "7zipbin" })
Assert ($errors.Count -eq 0 -and $Bk7ZipBin -eq (Join-Path "$work\pf" "\7-Zip\7z.exe")) "found in Program Files [$Bk7ZipBin]"

Copy-Item -LiteralPath $exe -Destination "$work\pf86\7-Zip\7z.exe"
Remove-Variable -Name Bk7ZipBin -Scope Script
${env:ProgramFiles(x86)} = "$work\pf86"
$errors = @(Invoke-Validation | Where-Object { $_ -match "7zipbin" })
Assert ($errors.Count -eq 0 -and $Bk7ZipBin -eq (Join-Path "$work\pf" "\7-Zip\7z.exe")) "found in both: the native one wins [$Bk7ZipBin]"

Remove-Variable -Name Bk7ZipBin -Scope Script
$env:ProgramFiles = "$work\none"; ${env:ProgramFiles(x86)} = $null
$errors = @(Invoke-Validation | Where-Object { $_ -match "7zipbin" })
Assert ($errors.Count -eq 1) "no Program Files (x86) folder (32-bit Windows): no failure, just reported [$($errors -join ' | ')]"
$env:ProgramFiles = $savedPf; ${env:ProgramFiles(x86)} = $savedPf86

Remove-Item -LiteralPath $work -Recurse -Force

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
