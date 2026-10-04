# Integration test for selection exceptions (e.g. access denied folders).
# Runs the 7zBackup.ps1 script body from the creation of the catalog files to
# the report of selection exceptions: exceptions must be logged with the real
# path and counted as warnings, and a clean scan must report none.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\SelectionExceptions.Test.ps1

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

# Script body statements: from the catalog files creation to the selection exceptions report
$body = @($ast.EndBlock.Statements)
$first = -1; $last = -1
for ($stmtIndex = 0; $stmtIndex -lt $body.Count; $stmtIndex++) {
	If(($first -lt 0) -and $body[$stmtIndex].Extent.Text.StartsWith('$BkSelectionInfo')) { $first = $stmtIndex }
	If(($first -ge 0) -and $body[$stmtIndex].Extent.Text.Contains('Exceptions during selection process')) { $last = $stmtIndex; break }
}
Assert (($first -ge 0) -and ($last -gt $first)) "precondition, script body range found"

$userSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value

# The denied folder name contains the alias (Docs / MyDocs): the logged real path must stay intact
foreach ($withDenied in $True, $False) {
	Write-Host "`n Case: scan with an access denied folder = $withDenied"
	$work      = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
	$source    = Join-Path $work "source"
	$BkRootDir = Join-Path $work "root"
	New-Item -ItemType Directory "$source\MyDocs", $BkRootDir -Force | Out-Null
	Set-Content -LiteralPath "$source\ok.txt" -Value "ok"
	Set-Content -LiteralPath "$source\MyDocs\secret.txt" -Value "secret"
	If($withDenied) { icacls "$source\MyDocs" /deny "*${userSid}:(OI)(CI)(RX)" | Out-Null }
	# 7zBackup.ps1 links each source into the root dir: a junction does the same without admin rights
	cmd /c "mklink /J `"$BkRootDir\Docs`" `"$source`"" | Out-Null
	$BkSelection = Join-Path $work "selection.txt"
	Set-Content -LiteralPath $BkSelection -Value "includesource=$source|alias=Docs"

	# State the script body has prepared before this range
	$BkType    = "full"
	$BkSources = @{ Docs = $source }
	$Counters  = @{ Exclusions = 0; Warnings = 0; Exceptions = 0; Criticals = 0; FoldersDone = 0; FilesProcessed = 0; FilesSelected = 0; BytesSelected = [int64]0; BytesAvailable = [int64]0; PlaceHolders = @(); Extensions = @{} }
	$SWriters  = @{}
	$MyContext = [hashtable]::Synchronized(@{ Cancelling = $False; Logger = (New-Object System.Text.StringBuilder); StartDir = $env:TEMP })
	Set-Location -Path $BkRootDir

	for ($stmtIndex = $first; $stmtIndex -le $last; $stmtIndex++) { . ([scriptblock]::Create($body[$stmtIndex].Extent.Text)) }
	Set-Location -Path $env:TEMP

	$log = $MyContext.Logger.ToString()
	$exceptionLines = @(Get-Content -LiteralPath (Join-Path $BkRootDir "Selection-Excpt.csv") | Select-Object -Skip 1)
	If($withDenied) {
		Assert (@($exceptionLines | Where-Object { $_.EndsWith("`t$source\MyDocs") }).Count -eq 1) "exception is written with the real path of the denied folder [$($exceptionLines -join ' | ')]"
		Assert ($log.Contains("Exceptions during selection process")) "exceptions are reported in the log"
		Assert ($Counters.Warnings -eq 1)                              "the exception is counted as one warning"
		icacls "$source\MyDocs" /remove:d "*$userSid" | Out-Null
	} Else {
		Assert ($exceptionLines.Count -eq 0)                             "no exception is written"
		Assert (!$log.Contains("Exceptions during selection process"))   "no exceptions section in the log"
		Assert ($Counters.Warnings -eq 0)                                "no warning is counted"
		Assert ($Counters.FoldersDone -eq 2)                             "each folder is counted once, Docs and MyDocs [$($Counters.FoldersDone)]"
		$catalog = @(Get-Content -LiteralPath (Join-Path $BkRootDir "Catalog-Include.txt") -Encoding UTF8)
		Assert (!($catalog -contains "Compress-Detail.txt"))             "the 7-Zip output file is not added to the archive catalog"
	}

	cmd /c "rd `"$BkRootDir\Docs`""
	Remove-Item -LiteralPath $work -Recurse -Force
}

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
