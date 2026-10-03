# Integration test for archive rotation.
# Rotation must only touch archives of the same job (prefix and type), even
# when another job's prefix ends with this job's prefix.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\Rotation.Test.ps1

$ErrorActionPreference = "SilentlyContinue"   # same as 7zBackup.ps1

# Load function definitions and the rotation block only: the script body is not executed
$scriptFile = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\7zBackup.ps1"))
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile, [ref]$null, [ref]$null)
foreach ($fn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $False)) {
	. ([scriptblock]::Create($fn.Extent.Text))
}
$rotationBlock = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] -and $n.Clauses[0].Item1.Extent.Text -eq '($BkRotate -ge 1)' }, $True)

$Failures = 0
Function Assert ([bool]$condition, [string]$message) {
	If($condition) { Write-Host " PASS : $message" -ForegroundColor Green }
	Else { Write-Host " FAIL : $message" -ForegroundColor Red; $script:Failures++ }
}

Assert ($null -ne $rotationBlock) "precondition, rotation block found in 7zBackup.ps1"

$work = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory $work -Force | Out-Null
$newArchive   = "srv-full-20260102-120000.7z"
$oldArchive   = "srv-full-20260101-120000.7z"
$otherArchive = "backupsrv-full-20250101-120000.7z"   # another job, same destination
$renamedCopy  = "srv-full-20250101-120000.7z.bak"     # not an archive name: a user's copy
foreach ($name in $newArchive, $oldArchive, $otherArchive, $renamedCopy) { Set-Content -LiteralPath (Join-Path $work $name) -Value $name }

# State the rotation block reads from script scope
$BkDestPath      = $work
$BkArchivePrefix = "srv"
$BkType          = "full"
$BkArchiveName   = $newArchive
$BkRotate        = 1
$MyContext       = [hashtable]::Synchronized(@{ Logger = (New-Object System.Text.StringBuilder) })

. ([scriptblock]::Create($rotationBlock.Extent.Text))

Assert (Test-Path -LiteralPath (Join-Path $work $newArchive))    "new archive of this job is kept"
Assert (!(Test-Path -LiteralPath (Join-Path $work $oldArchive))) "old archive of this job is removed"
Assert (Test-Path -LiteralPath (Join-Path $work $otherArchive))  "archive of job 'backupsrv' is not touched"
Assert (Test-Path -LiteralPath (Join-Path $work $renamedCopy))   "renamed copy '*.7z.bak' is not touched"

Write-Host "`n Case: volumes count as one archive (rotate 2)"
$volWork = Join-Path $work "vol"
New-Item -ItemType Directory $volWork -Force | Out-Null
$volNew = "srv-full-20260103-120000.7z"
foreach ($name in "$volNew.001", "$volNew.002", "$volNew.003", "srv-full-20260102-120000.7z.001", "srv-full-20260102-120000.7z.002", "srv-full-20260101-120000.7z.001", "srv-full-20260101-120000.7z.002") {
	Set-Content -LiteralPath (Join-Path $volWork $name) -Value $name
}
$BkDestPath    = $volWork
$BkArchiveName = $volNew
$BkRotate      = 2
$MyContext     = [hashtable]::Synchronized(@{ Logger = (New-Object System.Text.StringBuilder) })
. ([scriptblock]::Create($rotationBlock.Extent.Text))
Assert (@($MyContext.Logger.ToString().Split("`n") | Where-Object { $_ -match "^ New " }).Count -eq 3) "the 3 parts of the new archive are labelled New"
Assert ((Test-Path -LiteralPath "$volWork\$volNew.003"))                               "all parts of the new archive are kept"
Assert ((Test-Path -LiteralPath "$volWork\srv-full-20260102-120000.7z.002"))           "all parts of the previous archive are kept"
Assert (!(Test-Path -LiteralPath "$volWork\srv-full-20260101-120000.7z.001"))          "first part of the oldest archive is removed"
Assert (!(Test-Path -LiteralPath "$volWork\srv-full-20260101-120000.7z.002"))          "second part of the oldest archive is removed"

Remove-Item -LiteralPath $work -Recurse -Force

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
