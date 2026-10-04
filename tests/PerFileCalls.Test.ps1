# Static test for the per-file loops of Invoke-FolderScan and Complete-Archiving.
# Cmdlets cost tens of microseconds per call: loops that run once per file must
# use .NET calls instead. The behavior is covered by Invoke-FolderScan, Complete-Archiving
# and NotArchived tests.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\PerFileCalls.Test.ps1

$ErrorActionPreference = "SilentlyContinue"   # same as 7zBackup.ps1

$scriptFile = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\7zBackup.ps1"))
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFile, [ref]$null, [ref]$null)

$Failures = 0
Function Assert ([bool]$condition, [string]$message) {
	If($condition) { Write-Host " PASS : $message" -ForegroundColor Green }
	Else { Write-Host " FAIL : $message" -ForegroundColor Red; $script:Failures++ }
}

Function Get-Function ([string]$name) {
	$ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $False)[0]
}

# Command names called inside the first loop of $function whose header contains $headerText
Function Get-LoopCommands ([string]$function, [type]$loopType, [string]$headerText) {
	$loop = (Get-Function $function).FindAll({ param($n) $n -is $loopType -and $n.Extent.Text.Split("`n")[0].Contains($headerText) }, $True)[0]
	If(!$loop) { Return $null }
	# -NoEnumerate: a loop without commands returns an empty list, not $null
	Write-Output -NoEnumerate @($loop.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $True) | ForEach-Object { $_.GetCommandName() })
}

Write-Host "`n Case: Invoke-FolderScan, loop over the files of a folder"
$commands = Get-LoopCommands "Invoke-FolderScan" ([System.Management.Automation.Language.ForEachStatementAst]) '[System.IO.FileInfo]'
Assert ($null -ne $commands)                                              "precondition, loop found"
Assert (@($commands | Where-Object { $_ -eq "Join-Path" }).Count -eq 0)   "no Join-Path per file [$(($commands | Sort-Object -Unique) -join ', ')]"
Assert (@($commands | Where-Object { $_ -eq "New-Timespan" }).Count -eq 0) "no New-Timespan per file [$(($commands | Sort-Object -Unique) -join ', ')]"

Write-Host "`n Case: Complete-Archiving, loop over the archived items"
$commands = Get-LoopCommands "Complete-Archiving" ([System.Management.Automation.Language.ForEachStatementAst]) '$BkCompressDetailItems'
Assert ($null -ne $commands)                                              "precondition, loop found"
Assert (@($commands | Where-Object { $_ -eq "Join-Path" }).Count -eq 0)   "no Join-Path per item [$(($commands | Sort-Object -Unique) -join ', ')]"
Assert (@($commands | Where-Object { $_ -in "Get-Item", "Remove-Item" }).Count -eq 0) "no Get-Item or Remove-Item per item [$(($commands | Sort-Object -Unique) -join ', ')]"

Write-Host "`n Case: Complete-Archiving, loop over the archive listing lines"
$commands = Get-LoopCommands "Complete-Archiving" ([System.Management.Automation.Language.WhileStatementAst]) 'StandardOutput.ReadLine()'
Assert ($null -ne $commands)                                              "precondition, loop found"
Assert (@($commands | Where-Object { $_ -eq "New-Object" }).Count -eq 0)  "no New-Object per listing line [$(($commands | Sort-Object -Unique) -join ', ')]"

Write-Host "`n Case: Complete-Archiving, catalog check (NOT ARCHIVED)"
$assignments = @((Get-Function "Complete-Archiving").FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$notArchived' }, $True))
$commands = @($assignments | ForEach-Object { $_.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $True) } | ForEach-Object { $_.GetCommandName() })
Assert ($assignments.Count -ge 1)                                         "precondition, notArchived assignment found"
Assert (@($commands | Where-Object { $_ -eq "Where-Object" }).Count -eq 0) "no Where-Object pipeline over the catalog [$(($commands | Sort-Object -Unique) -join ', ')]"

Write-Host "`n Case: Invoke-FolderScan, folder listing"
$commands = @((Get-Function "Invoke-FolderScan").FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $True) | ForEach-Object { $_.GetCommandName() })
Assert (@($commands | Where-Object { $_ -eq "Get-ChildItem" }).Count -eq 0) "no Get-ChildItem: about 27 us per listed item [$(($commands | Sort-Object -Unique) -join ', ')]"

Write-Host ""
If($Failures -gt 0) { Write-Host " $Failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host " All assertions passed" -ForegroundColor Green
exit 0
