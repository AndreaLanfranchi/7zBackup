# Integration tests for the lock file (Test-Lock and Clear-Script).
# A running instance's lock must never be removed by another run.
# A stale lock (crashed run, reused process id) must not block the next run.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\Lock.Test.ps1

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
New-Item -ItemType Directory $work -Force | Out-Null
$BkLockFile = Join-Path $work "7zBackup.lock"
$BkRootDir  = Join-Path $work "newroot"
$ownTicks   = (Get-Process -Id $PID).StartTime.ToUniversalTime().Ticks

Function Reset-Context { $script:MyContext = [hashtable]::Synchronized(@{ StartDir = $env:TEMP }) }
Function Write-Lock ([string]$procId, [string]$ticks, [string]$root) {
	Set-Content -LiteralPath $BkLockFile -Value @("PID=$procId", "Start=$ticks", "Root=$root") -Encoding Ascii
}
Function Test-OwnLock {
	$content = @(Get-Content -LiteralPath $BkLockFile)
	Write-Output (($content -contains "PID=$PID") -and ($content -contains "Start=$ownTicks") -and ($content -contains "Root=$BkRootDir"))
}

# A second process that stays alive while the lock cases run
$child = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList "-NoProfile", "-Command", "Start-Sleep 120" -WindowStyle Hidden -PassThru
$childTicks = $child.StartTime.ToUniversalTime().Ticks

Write-Host "`n Case: no lock file"
Reset-Context
$out = @(Test-Lock)
Assert ($out.Count -eq 0) "run proceeds"
Assert (Test-OwnLock)     "lock file holds this run's PID, start time and root dir"
Clear-Script
Assert (!(Test-Path -LiteralPath $BkLockFile)) "Clear-Script removes the lock this run created"

Write-Host "`n Case: lock of a running instance"
Reset-Context
New-Item -ItemType Directory "$work\childroot" -Force | Out-Null
Write-Lock $child.Id $childTicks "$work\childroot"
$out = @(Test-Lock)
Assert ($out.Count -gt 0)                                                "run refuses to start"
Assert ((Get-Content -LiteralPath $BkLockFile) -contains "PID=$($child.Id)") "lock file is untouched"
Assert (Test-Path -LiteralPath "$work\childroot")                        "root dir of the running instance is untouched"
Clear-Script
Assert ((Get-Content -LiteralPath $BkLockFile) -contains "PID=$($child.Id)") "Clear-Script of the refused run keeps the running instance's lock"

Write-Host "`n Case: process id now used by another process (different start time)"
Reset-Context
Write-Lock $child.Id "1" ""
$out = @(Test-Lock)
Assert ($out.Count -eq 0) "run proceeds"
Assert (Test-OwnLock)     "lock file is replaced by this run's lock"

Write-Host "`n Case: lock left by a crashed run, with its root dir"
Reset-Context
$staleRoot = "$work\staleroot"
New-Item -ItemType Directory $staleRoot, "$work\data" -Force | Out-Null
Set-Content -LiteralPath "$work\data\precious.txt" -Value "data"
cmd /c "mklink /J `"$staleRoot\Alias`" `"$work\data`"" | Out-Null
Stop-Process -Id $child.Id -Force; $child.WaitForExit()
Write-Lock $child.Id $childTicks $staleRoot
$out = @(Test-Lock)
Assert ($out.Count -eq 0)                                  "run proceeds"
Assert (Test-OwnLock)                                      "lock file is replaced by this run's lock"
Assert (!(Test-Path -LiteralPath $staleRoot))              "root dir of the crashed run is removed"
Assert (Test-Path -LiteralPath "$work\data\precious.txt")  "data behind the crashed run's link is untouched"

Write-Host "`n Case: lock left earlier by this same process"
Reset-Context
Write-Lock $PID $ownTicks ""
$out = @(Test-Lock)
Assert ($out.Count -eq 0) "run proceeds"
Assert (Test-OwnLock)     "lock file is replaced by this run's lock"

Write-Host "`n Case: process whose start time can not be read"
Reset-Context
# PowerShell returns $null (no exception) for a start time it can not read
Assert ($null -eq (Get-Process -Id 4).StartTime) "precondition, start time of System (PID 4) is not readable"
Write-Lock 4 "1" ""
$out = @(Test-Lock)
Assert ($out.Count -gt 0)                                     "run refuses to start (lock can not be proven stale)"
Assert ((Get-Content -LiteralPath $BkLockFile) -contains "PID=4") "lock file is untouched"

Stop-Process -Id $child.Id -Force
If(Test-Path -LiteralPath "$staleRoot\Alias") { cmd /c "rd `"$staleRoot\Alias`"" }
Remove-Item -LiteralPath $work -Recurse -Force

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
