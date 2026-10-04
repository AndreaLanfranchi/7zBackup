# Test for New-RootDir error messages.
# When the root dir cannot be created the message must name the root dir.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\NewRootDir.Test.ps1

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

$MyContext = [hashtable]::Synchronized(@{})
$work = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory $work | Out-Null

Write-Host "`n Case: root dir created"
$BkRootDir = Join-Path $work "root"
$messages = @(New-RootDir)
Assert ($messages.Count -eq 0)                                         "no message on success"
Assert (Test-Path -LiteralPath "$BkRootDir\__README__PLEASE__README__.txt") "README written"

Write-Host "`n Case: root dir cannot be created (a file has its name)"
$BkRootDir = Join-Path $work "blocked"
Set-Content -LiteralPath $BkRootDir -Value "x"
$messages = @(New-RootDir)
Assert ($messages.Count -eq 1)                                         "one message returned"
Assert (("$messages").Contains($BkRootDir))                            "message names the root dir"

Write-Host "`n Case: README cannot be written (the root dir is created, the README fails)"
# A deny rule for new files, inherited by sub folders only: the root dir is created, the README in it is refused
$parent = Join-Path $work "parent"
New-Item -ItemType Directory $parent | Out-Null
$BkRootDir = Join-Path $parent "root"
icacls $parent /deny "$($env:USERNAME):(OI)(CI)(IO)(WD)" | Out-Null
$messages = @(New-RootDir)
icacls $parent /remove:d $env:USERNAME | Out-Null
Assert (Test-Path -LiteralPath $BkRootDir -PathType Container)         "precondition, the root dir was created"
Assert (!(Test-Path -LiteralPath "$BkRootDir\__README__PLEASE__README__.txt")) "precondition, the README was refused"
Assert ($messages.Count -eq 1)                                         "one message returned"
Assert (("$messages").StartsWith("Can't write into $BkRootDir"))       "message is the README one and names the root dir [$messages]"

Remove-Item -LiteralPath $work -Recurse -Force
Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
