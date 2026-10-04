# Integration test for the SMTP authentication checks in Assert-Variables.
# An incomplete or blank user / password pair must be reported and dropped, so
# the notification never authenticates with a blank credential.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\SmtpCredentials.Test.ps1

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
Set-Content -LiteralPath $selection -Value "includesource=$work\source|alias=Source"

# Runs Assert-Variables with an otherwise valid notification setup and the given user / password; returns the errors
Function Invoke-Validation ([hashtable]$credentials) {
	foreach ($name in "BkNotifyLog", "BkNotifyLogCc", "BkNotifyLogBcc", "BkSmtpUser", "BkSmtpPass") { Remove-Variable -Name $name -Scope Script }
	$script:MyContext       = [hashtable]::Synchronized(@{ PSVer = [int]$PSVersionTable.PSVersion.Major; Logger = (New-Object System.Text.StringBuilder) })
	$script:Counters        = @{ Warnings = 0 }
	$script:BkType          = "full"
	$script:BkSelection     = $selection
	$script:BkDestPath      = "$work\dest"
	$script:BkArchivePrefix = "test"
	$script:BkNotifyLog     = "ok@example.com"
	$script:BkSmtpFrom      = "backup@example.com"
	$script:BkSmtpRelay     = "smtp.example.com"
	foreach ($name in $credentials.Keys) { Set-Variable -Name $name -Value $credentials[$name] -Scope Script }
	Write-Output @(Assert-Variables)
}

Function Count-CredentialErrors ($errors) { @($errors | Where-Object { $_ -match "--smtpuser or --smtppass" }).Count }

Write-Host "`n Case: blank password"
$errors = @(Invoke-Validation @{ BkSmtpUser = "backup"; BkSmtpPass = "   " })
Assert ((Count-CredentialErrors $errors) -eq 1)                          "reported [$($errors -join ' | ')]"
Assert (!(Test-Variable "BkSmtpUser") -and !(Test-Variable "BkSmtpPass")) "user and password are dropped"

Write-Host "`n Case: user without password"
$errors = @(Invoke-Validation @{ BkSmtpUser = "backup" })
Assert ((Count-CredentialErrors $errors) -eq 1) "reported [$($errors -join ' | ')]"
Assert (!(Test-Variable "BkSmtpUser"))          "user is dropped"

Write-Host "`n Case: password without user"
$errors = @(Invoke-Validation @{ BkSmtpPass = "secret" })
Assert ((Count-CredentialErrors $errors) -eq 1) "reported [$($errors -join ' | ')]"
Assert (!(Test-Variable "BkSmtpPass"))          "password is dropped"

Write-Host "`n Case: user and password"
$errors = @(Invoke-Validation @{ BkSmtpUser = "backup"; BkSmtpPass = "secret" })
Assert ((Count-CredentialErrors $errors) -eq 0)                                   "not reported [$($errors -join ' | ')]"
Assert (($BkSmtpUser -eq "backup") -and ($BkSmtpPass -eq "secret"))              "user and password are kept"

Remove-Item -LiteralPath $work -Recurse -Force

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
