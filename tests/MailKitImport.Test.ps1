# Integration test for loading MailKit in Assert-Variables (--mailkitpath).
# A folder that can not be loaded must give a warning, drop the setting and keep
# the job running (SmtpClient is used). A valid folder must load MailKit,
# including dependencies built against older versions of System.Memory.
#
# Downloads the MailKit packages from NuGet once (see MailKitCache.ps1);
# without network access the valid folder case is skipped.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\MailKitImport.Test.ps1

$ErrorActionPreference = "SilentlyContinue"   # same as 7zBackup.ps1

# Load function definitions only: the script body is not executed
$scriptFile = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\7zBackup.ps1"))
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile, [ref]$null, [ref]$null)
foreach ($fn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $False)) {
	. ([scriptblock]::Create($fn.Extent.Text))
}
. (Join-Path $PSScriptRoot "MailKitCache.ps1")

$Failures = 0
Function Assert ([bool]$condition, [string]$message) {
	If($condition) { Write-Host " PASS : $message" -ForegroundColor Green }
	Else { Write-Host " FAIL : $message" -ForegroundColor Red; $script:Failures++ }
}

$work = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory "$work\dest", "$work\source", "$work\broken" -Force | Out-Null
$selection = Join-Path $work "selection.txt"
Set-Content -LiteralPath $selection -Value "includesource=$work\source|alias=Source"

# Runs Assert-Variables with an otherwise valid notification setup and the given MailKit folder; returns the errors
Function Invoke-Validation ([string]$mailKitPath) {
	foreach ($name in "BkNotifyLog", "BkNotifyLogCc", "BkNotifyLogBcc", "BkMailKitPath") { Remove-Variable -Name $name -Scope Script }
	$script:MyContext       = [hashtable]::Synchronized(@{ PSVer = [int]$PSVersionTable.PSVersion.Major; Logger = (New-Object System.Text.StringBuilder) })
	$script:Counters        = @{ Warnings = 0 }
	$script:BkType          = "full"
	$script:BkSelection     = $selection
	$script:BkDestPath      = "$work\dest"
	$script:BkArchivePrefix = "test"
	$script:BkNotifyLog     = "ok@example.com"
	$script:BkSmtpFrom      = "backup@example.com"
	$script:BkSmtpRelay     = "smtp.example.com"
	$script:BkMailKitPath   = $mailKitPath
	Write-Output @(Assert-Variables)
}

Function Assert-Fallback ([string]$label, $errors, [string]$reasonPattern) {
	$log = $MyContext.Logger.ToString().Trim() -replace '\s+', ' '
	Assert ($errors.Count -eq 0)                                                          "${label}: no validation error, the job runs [$($errors -join ' | ')]"
	Assert ($Counters.Warnings -eq 1)                                                     "${label}: one warning is counted [got: $($Counters.Warnings)]"
	Assert ($log -match "Warning : MailKit not loaded \($reasonPattern.*\), using SmtpClient") "${label}: the log gives the reason and says SmtpClient is used [$log]"
	Assert (!(Test-Variable "BkMailKitPath"))                                             "${label}: the setting is dropped"
}

Write-Host "`n Case: folder does not exist"
Assert-Fallback "missing folder" @(Invoke-Validation "$work\no-such-folder") "MimeKit\.dll"

Write-Host "`n Case: folder with DLLs that are not assemblies"
foreach ($name in "MimeKit.dll", "MailKit.dll") { Set-Content -LiteralPath "$work\broken\$name" -Value "not an assembly" }
Assert-Fallback "broken DLLs" @(Invoke-Validation "$work\broken") ""

Write-Host "`n Case: valid folder"
$mailKitLib = Get-MailKitLib
If(!$mailKitLib) {
	Write-Host " SKIP : MailKit packages not available (offline?)" -ForegroundColor Yellow
} Else {
	$errors = @(Invoke-Validation $mailKitLib)
	Assert ($errors.Count -eq 0)                                  "no validation error [$($errors -join ' | ')]"
	Assert ($Counters.Warnings -eq 0)                             "no warning [$($MyContext.Logger.ToString().Trim())]"
	Assert (Test-Variable "BkMailKitPath")                        "the setting is kept"
	Assert ($null -ne ("MailKit.Net.Smtp.SmtpClient" -as [type])) "MailKit types are available"
	# MailKit loads System.Formats.Asn1 by name when it needs it; that assembly is built
	# against System.Memory 4.0.1.2 and the folder has 4.0.5.0
	$asn1Name = [System.Reflection.AssemblyName]::GetAssemblyName((Join-Path $mailKitLib "System.Formats.Asn1.dll")).FullName
	$asn1 = $(Try { [void][System.Reflection.Assembly]::Load($asn1Name); $writer = New-Object System.Formats.Asn1.AsnWriter([System.Formats.Asn1.AsnEncodingRules]::DER); $writer.WriteInteger([long]42); $writer.Encode().Length } Catch { $_.Exception.GetBaseException().Message })
	Assert ($asn1 -eq 3)                                          "a dependency built against an older System.Memory works [$asn1]"
}

Remove-Item -LiteralPath $work -Recurse -Force

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
