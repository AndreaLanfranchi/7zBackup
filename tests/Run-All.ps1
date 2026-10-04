# Runs every *.Test.ps1 in this folder, one at a time, each in its own
# PowerShell process (the tests end with exit). The output of a failed test
# is printed, then a summary with the time of each test. Exit code 1 when
# any test failed.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\Run-All.ps1 [-Filter Archive*] [-ShowOutput]

param([string]$Filter = "*", [switch]$ShowOutput)

$results = @()
foreach ($test in @(Get-ChildItem -Path $PSScriptRoot -Filter "$Filter.Test.ps1" | Sort-Object Name)) {
	Write-Host (" {0,-36}" -f $test.Name) -NoNewline
	$watch  = [System.Diagnostics.Stopwatch]::StartNew()
	$output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $test.FullName 2>&1)
	$result = New-Object PSObject -Property @{ Name = $test.Name; Passed = ($LASTEXITCODE -eq 0); Seconds = [Math]::Round($watch.Elapsed.TotalSeconds, 1) }
	$results += $result
	If($result.Passed) { Write-Host (" PASS {0,6} s" -f $result.Seconds) -ForegroundColor Green }
	Else { Write-Host (" FAIL {0,6} s (exit code {1})" -f $result.Seconds, $LASTEXITCODE) -ForegroundColor Red }
	If($ShowOutput -or !$result.Passed) { $output | ForEach-Object { Write-Host "    $_" } }
}

$failed = @($results | Where-Object { !$_.Passed })
Write-Host ""
Write-Host (" {0} test file(s), {1} failed, {2:n1} s" -f $results.Count, $failed.Count, (($results | Measure-Object Seconds -Sum).Sum))
If($failed.Count -gt 0) { $failed | ForEach-Object { Write-Host (" FAIL : {0}" -f $_.Name) -ForegroundColor Red }; exit 1 }
exit 0
