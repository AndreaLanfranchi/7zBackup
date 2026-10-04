# Integration test for Remove-RootDir / Remove-SymLink.
# The root dir must be removed together with its links, whatever the alias
# name (spaces, square brackets), and the data behind a link must survive.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\RemoveRootDir.Test.ps1

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

foreach ($linkName in "Plain", "My Alias", "Alias[1]") {
	Write-Host "`n Case: link named '$linkName'"
	$work = Join-Path $env:TEMP ("7zb-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
	$root = Join-Path $work "root"
	$data = Join-Path $work "data"
	New-Item -ItemType Directory $root, $data -Force | Out-Null
	Set-Content -LiteralPath "$data\precious.txt" -Value "data"
	# cmd.exe resolves relative names against the process directory: keep it inside the test folder
	[System.Environment]::CurrentDirectory = $work
	# 7zBackup.ps1 links each source into the root dir: a junction does the same without admin rights
	cmd /c "mklink /J `"$root\$linkName`" `"$data`"" | Out-Null
	Assert (Test-Path -LiteralPath "$root\$linkName") "precondition, link created"

	$result = Remove-RootDir $root

	Assert ($result -eq $True)                           "Remove-RootDir reports success"
	Assert (!(Test-Path -LiteralPath $root))              "root dir and its link are removed"
	Assert (Test-Path -LiteralPath "$data\precious.txt")  "data behind the link is untouched"

	[System.Environment]::CurrentDirectory = $env:TEMP
	If(Test-Path -LiteralPath "$root\$linkName") { cmd /c "rd `"$root\$linkName`"" }
	Remove-Item -LiteralPath $work -Recurse -Force
}

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
