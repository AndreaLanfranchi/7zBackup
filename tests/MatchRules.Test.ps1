# Test for Read-MatchRule: the "match*=regex" selection file lines are joined
# with "|" into one script variable, and the criteria are written to the log.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\MatchRules.Test.ps1

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

Function New-Context { $script:MyContext = [hashtable]::Synchronized(@{ Logger = (New-Object System.Text.StringBuilder) }) }
Function Get-Log { $MyContext.Logger.ToString() }

$lines = @("includesource=C:\x|alias=X", "matchexcludefiles=\.tmp$", "matchexcludefiles=  ^~  ", "matchexcludefiles=", "matchstoprecurse=^\.git$")

Write-Host "`n Case: several lines are joined, trimmed, empty values skipped"
New-Context; Remove-Variable matchexcludefiles -Scope Script -ErrorAction SilentlyContinue
Read-MatchRule $lines "matchexcludefiles" "Files Exclusion Criteria" " - Regex : " "NOT INCLUDED"
Assert ($matchexcludefiles -eq '\.tmp$|^~')                 "regexes joined with | [$matchexcludefiles]"
$log = Get-Log
Assert ($log.Contains("Files Exclusion Criteria"))           "title is logged"
Assert ($log.Contains(" - Regex : ^~"))                      "each regex is logged, trimmed"
Assert ($log.Contains("NOT INCLUDED"))                       "footer is logged"

Write-Host "`n Case: no line for the rule"
New-Context; Remove-Variable matchstoprecurse -Scope Script -ErrorAction SilentlyContinue
Read-MatchRule @("maxdepth=3") "matchstoprecurse" "Stop Recursion Criteria" " -match " "NOT RECURSED"
Assert (!(Test-Path variable:script:matchstoprecurse))       "variable is not created"
Assert ((Get-Log) -eq "")                                    "nothing is logged"

Write-Host "`n Case: -Always with no line prints title and empty text"
New-Context; Remove-Variable matchincludefiles -Scope Script -ErrorAction SilentlyContinue
Read-MatchRule @() "matchincludefiles" "Files Inclusion Criteria" " + Regex : " "" " + Any file name " -Always
Assert (!(Test-Path variable:script:matchincludefiles))      "variable is not created"
Assert ((Get-Log).Contains("Files Inclusion Criteria"))      "title is logged"
Assert ((Get-Log).Contains("Any file name"))                 "empty text is logged"

Write-Host "`n Case: a rule only matches its own name"
New-Context; Remove-Variable matchexcludepath -Scope Script -ErrorAction SilentlyContinue
Read-MatchRule @("matchexcludepathology=x") "matchexcludepath" "Exclude Paths Criteria" " -match " "NOT INCLUDED"
Assert (!(Test-Path variable:script:matchexcludepath))       "prefix of another name is ignored"

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
