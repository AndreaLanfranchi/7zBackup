# Integration test for notification addresses (IsValidEmailAddress and the
# address checks in Assert-Variables).
# Valid addresses must be accepted; an invalid address must be dropped with a
# warning, without stopping the job.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\NotifyAddresses.Test.ps1

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

# -----------------------------------------------------------------------------
Write-Host "`n Case: address syntax"
foreach ($address in "a@x.com", "john+tag@example.com", "1user@example.com", "first.last@mail.example.co.uk", "backup-admin@example.com") {
	Assert (IsValidEmailAddress $address) "valid:   $address"
}
foreach ($address in "no-at-sign.example.com", "two@@example.com", "user@nodot", "user@example.c", "user name@example.com", "@example.com", "user@") {
	Assert (!(IsValidEmailAddress $address)) "invalid: $address"
}

# -----------------------------------------------------------------------------
$work = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory "$work\dest", "$work\source" -Force | Out-Null
$selection = Join-Path $work "selection.txt"
Set-Content -LiteralPath $selection -Value "includesource=$work\source|alias=Source"

# Runs Assert-Variables with an otherwise valid setup and the given To address(es); returns the errors
Function Invoke-Validation ($notifyTo, $from = "backup@example.com", $relay = "smtp.example.com") {
	foreach ($name in "BkNotifyLog", "BkNotifyLogCc", "BkNotifyLogBcc") { Remove-Variable -Name $name -Scope Script }
	$script:MyContext       = [hashtable]::Synchronized(@{ PSVer = [int]$PSVersionTable.PSVersion.Major; Logger = (New-Object System.Text.StringBuilder) })
	$script:Counters        = @{ Warnings = 0 }
	$script:BkType          = "full"
	$script:BkSelection     = $selection
	$script:BkDestPath      = "$work\dest"
	$script:BkArchivePrefix = "test"
	$script:BkNotifyLog     = $notifyTo
	$script:BkSmtpFrom      = $from
	$script:BkSmtpRelay     = $relay
	Write-Output @(Assert-Variables)
}

Write-Host "`n Case: one valid and one invalid To address"
$errors = @(Invoke-Validation @("ok@example.com", "bad address"))
Assert ($errors.Count -eq 0)                                "no validation error: the job runs [$($errors -join ' | ')]"
Assert ((@($BkNotifyLog) -join ",") -eq "ok@example.com")   "only the valid address is kept"
Assert ($Counters.Warnings -eq 1)                           "the invalid address counts as one warning"
Assert ($MyContext.Logger.ToString().Contains("bad address")) "the invalid address is named in the log"

Write-Host "`n Case: single valid To address, no Cc and no Bcc"
$errors = @(Invoke-Validation "a@x.com")
Assert ($errors.Count -eq 0)                        "no validation error [$($errors -join ' | ')]"
Assert ((@($BkNotifyLog) -join ",") -eq "a@x.com")  "the address is kept"
Assert ($Counters.Warnings -eq 0)                   "no warning for missing Cc and Bcc"

Write-Host "`n Case: no valid To address"
$errors = @(Invoke-Validation "bad address")
Assert ($errors.Count -eq 0)                                  "no validation error: the job runs [$($errors -join ' | ')]"
Assert (!(Test-Variable "BkNotifyLog"))                       "no To address is left"
Assert ($Counters.Warnings -ge 1)                             "a warning is counted"
Assert ($MyContext.Logger.ToString().Contains("no notification")) "the log says no notification will be sent"

Write-Host "`n Case: sender given as a one-element array (e.g. @(...) in 7zBackup-vars.ps1)"
$errors = @(Invoke-Validation "ok@example.com" @("backup@example.com"))
Assert ($errors.Count -eq 0) "no validation error [$($errors -join ' | ')]"
# Send-Notification assigns the sender to MailMessage.From, which does not accept an array
$fromError = $(Try { $message = New-Object System.Net.Mail.MailMessage; $message.From = $BkSmtpFrom; "" } Catch { $_.Exception.GetBaseException().Message })
Assert ($fromError -eq "") "the checked sender can be used as MailMessage.From [$fromError]"

Write-Host "`n Case: relay given as an array"
$errors = @(Invoke-Validation "ok@example.com" "backup@example.com" @("smtp", ".example.com"))
Assert ($errors.Count -eq 0) "no validation error for the joined smtp.example.com [$($errors -join ' | ')]"
# Send-Notification assigns the relay to SmtpClient.Host: it must be the host that was checked
$client = New-Object System.Net.Mail.SmtpClient
$client.Host = $BkSmtpRelay
Assert ($client.Host -eq "smtp.example.com") "the checked relay is the host used [$($client.Host)]"

Remove-Item -LiteralPath $work -Recurse -Force

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
