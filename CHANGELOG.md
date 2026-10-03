# Changelog

Changes to 7zBackup.ps1, newest version first. Categories: Bug, Feat (feature), Code, Speed, Sec (security),
Ui (user interface). Some old entries use Minor or New, or have no category.

## Unreleased

- Code: 14 Write-Output followed by Return became a single Return with the value
- Code: Format-Elapsed writes the four phase times of the log, and the unused SelectionEnd, CompressionEnd and PostProcessFilesEnd values are gone. Task time now shows seconds with decimals like the other times
- Code: The six match* selection blocks are read by one function (Read-MatchRule). matchincludefiles values are now trimmed like the others
- Bug: New-RootDir error messages named an undefined variable instead of the root directory
- Bug: --type FULL named the archive with FULL and --type full with full: the validated type is now kept in lower case (#16)
- Code: Command line arguments are read from two tables (options with a value, switches) instead of a 42-case switch (#16)
- Code: Assert-Variables checks use helpers: Set-DefaultVariable, Resolve-Choice, Resolve-BooleanVariable, Resolve-IntegerVariable and Resolve-AddressList (one copy for --notify, --notifyCc and --notifyBcc, was three). Test-Variable is a single quiet Get-Variable call (#16)
- Code: Close-Writers and Get-NotificationExtras are shared by the cleanup and both email paths, and Send-Notification no longer branches on single value or array (#16)
- Code: ProcessFolder uses foreach, FileAttributes names instead of 1024 and 32, and Trace-ScanProgress for the status line it repeated 3 times (#16)
- Code: IsValidEmailAddress, IsValidHostName, IsValidIPAddress and Test-FsAttribute return their value directly (#16)
- Code: Selection file directives are read in one pass from a table (Read-SelectionDirectives) and the size and age limits are checked by one loop (ConvertTo-Limit) (#15)
- Code: ProcessFolder writes exclusions and exceptions through Add-Exclusion and Add-ScanException, replacing 13 repeated log lines (#15)
- Bug: PostArchiving printed a stray "+" when an archived item was no longer on disk: Write-Host got it as an argument (#15)
- Code: The help and log header link to the new repository address https://github.com/AndreaLanfranchi/7zBackup

## 2.1.5-Stable (2026-09-12, Anlan)

- Bug: Move and clear archive bit acted also on files 7-Zip failed to store. Processed items are now read from the finished archive
- Bug: With nofollowjunctions, folders enumerated after a skipped junction could be silently left out of the scan
- Bug: Rotation could delete archives of other jobs sharing the prefix end or renamed copies. Archive name regex is now anchored
- Bug: matchcleanupfiles tested an undefined variable: cleanup never ran, or deleted every file with a regex matching empty text. Cleaned files were archived
- Bug: A refused run deleted the running instance's lock file and stale locks were never detected. Locks are now checked by process id and start time
- Bug: Selection exceptions (e.g. access denied) were never logged nor counted as warnings: their writer used an undefined variable
- Bug: 7-Zip warnings (missing or unreadable files) were never logged nor counted: the match expected drive paths. Items are now matched against the catalog
- Bug: Selection file directives maxfilesize, minfilesize, maxfileage, minfileage, compression, threads and solid were ignored. File ages accept integers
- Bug: With a lowercase work drive letter subfolder paths became absolute: the archive lost its folder structure and path directives stopped matching
- Bug: Work drive check never ran (a parameter binding error aborted it) and its NTFS test was inverted
- Bug: Links with spaces or square brackets in the alias were not removed at cleanup but reported as removed: the root dir and its links stayed on disk
- Bug: Notification addresses: valid ones (a@x.com, name+tag@, 1user@) were rejected, invalid ones were not reported and still used. Now warned and dropped
- Bug: A failed notification email showed an empty reason: now the underlying error
- Sec: The archive password was visible in the process list and verbose output: it now goes to 7-Zip input. 7-Zip console charset is UTF-8
- Bug: Archive prefix accepted path separators (e.g. ..\x): the archive could be written outside the destination path. Now rejected
- Bug: Post archive statistics: files/sec was always 0 (undefined variable) and the progress percent went over 100, hiding the progress bar
- Bug: Pre-Vista junctions: Make-Junction passed an undefined target and Remove-Junction had a broken Start-Sleep call
- Bug: Logged real paths were wrong when a folder name contained the alias, and the nofollowjunctions log named the parent instead of the skipped junction
- Bug: Scan counted one folder too many (extra call without a folder) and the empty Compress-Detail.txt was added to the archive (misspelled name filter)
- Bug: Log messages printed ".Exception.Message" and ".Name" literally, and a 7-Zip command line error printed an undefined variable instead of the arguments
- Bug: Directive names matched longer names (prefixes=, includesourcex=, ...): the regexes used =* (zero or more =)
- Bug: Size and age checks never ran: invalid maxfilesize, minfilesize, maxfileage and minfileage values were silently ignored. Now they stop the job with an error
- Bug: A size or age value of 0 stayed set (removal missed the script scope): the log listed a 0 bytes or 0 days filter that did nothing
- Bug: An invalid smtpuser / smtppass pair was reported but kept: the error email could authenticate with a blank password
- Code: Help for --clearbit said FULL or DIFF clear the Archive attribute: FULL or INCR
- Code: Removed unused functions Clear-FsAttribute and Pause and other dead code
- Code: PostArchiving removed BkCompressDetailItems from the wrong scope (had no effect)
- Feat: Selected items missing from the archive and not reported by 7-Zip are now logged as NOT ARCHIVED warnings, for every backup type
- Bug: Clearing the Archive bit failed on files with other attributes (e.g. OneDrive, issue #13) and silently did nothing on names with square brackets
- Feat: New --mailkitpath: MailKit and its dependencies are loaded from that folder at startup (issue #14). If loading fails, a warning is logged and SmtpClient is kept
- Feat: Notification emails are sent with MailKit when --mailkitpath is set (issue #14). Port 465 uses TLS on connect, --smtpssl requires STARTTLS on other ports
- Bug: A sender given as an array (e.g. @(...) in the vars file) passed the check, but the email failed: the joined value was a local copy, the script kept the array
- Bug: The relay (--smtpserver) given as an array had the same problem: the joined value was checked, the array was used
- Speed: Scan progress is updated at most every 500 ms: Write-Progress took milliseconds per call and the scan called it 3 times per folder
- Speed: Paths built once per file use [IO.Path]::Combine instead of Join-Path (90 to 3 us)
- Speed: PostArchiving deletes and clears files with .NET calls, not Get-Item / Remove-Item (about 360 to 65 us per file), and keeps listing entries as plain strings
- Speed: File age filters subtract dates instead of calling New-Timespan per file, and the NOT ARCHIVED check loops over the catalog instead of piping it
- Speed: Selection statistics are summed during the scan: Catalog-Stats.csv and its Import-Csv / Group-Object pass (about 36 us per file) are gone
- Bug: 7-Zip output was read by PowerShell events: lines came out of order, stderr lines were joined into one and lines still queued when 7-Zip exited were lost
- Speed: Folders are listed with DirectoryInfo instead of Get-ChildItem (about 27 to 1 us per item)
- Code: Get-CimInstance instead of Get-WmiObject, which PowerShell 7 does not have
- Feat: Local sources are linked with junctions, which need no admin rights. Network sources (UNC paths, network drives) still get symbolic links
- Bug: While 7-Zip wrote the archive, progress read its size from the folder listing, which lags for open files: it kept showing "Waiting for archive ..."
- Bug: The log numbered selection exceptions one above their id in Selection-Excpt.csv
- Bug: A cleanup folder that could not be removed wrote System.Object[] in Selection-Excpt.csv. Now it writes the first error and the real path of the folder
- Bug: A cleanup file that could not be removed was written in Selection-Excpt.csv with its path through the root dir link, removed after the job: now its real path, as in the log
- Bug: Cleanup files and folders that could not be removed for access denied were logged as ArgumentException (PowerShell 5.1 Remove-Item): .NET deletes now name the real error. Read-only flags are cleared first
- Code: Full cmdlet names (Where-Object, Select-Object, Sort-Object) instead of the aliases ?, select and sort
- Code: Functions renamed to approved verbs: Invoke-PostAction, Test-CtrlCRequest, Test-FsAttribute, New-Junction, New-SymLink, Assert-Arguments, Assert-Variables (were Do-, Check-, Make-, Validate-)

## 2.1.4-Stable (2020-08-24, Anlan)

- Code: Speed up PostArchiving a little bit using a range iterator

## 2.1.3-Stable (2020-05-14, Anlan)

- Code: Enclosed [console]::TreatControlCAsInput in Try Catch block as it may throw is console is launched with stdin redirection

## 2.1.2-Stable (2018-03-22, Anlan)

- Feat: Adjusted clear archive bit

## 2.1.1-Stable (2017-11-28, Anlan)

- Feat: Added some useful about archives occupation on target
- Feat: Addedd support for notify addresses in CC and BCC
- Feat: Better organization of output

## 2.1.0-Stable (2017-11-27, Anlan)

- Code: Adjusted calc of threads over cores
- Feat: Added matchcleanupdirs directive in selection to remove unwanted or temporary directories during scan USE WITH GREAT CARE !!!!
- Code: Amended some typos about Bytes and Mbytes

## 2.0.8-Stable (2017-11-21, Anlan)

- Feat: Logger has been embedded as internal string builder. This helps notifying for parameters errors

## 2.0.7-Stable (2017-11-13, Anlan)

- Feat: Emission of warning on low space for destpath directory
- Code: Adjusted emission message on presence of lock file
- Code: Adjusted calculation of cores/threads
- Code: Cleanup

## 2.0.6-Stable (2017-11-05, Anlan)

- Code: Adjusted lowering of Archive Bits for non ASCII characters

## 2.0.5-Stable (2017-11-02, PWalker)

- Code: Forced clear Archive bit for Hidden files
- Feat: Some Debug info

## 2.0.4-Stable (2016-11-11, Anlan)

- Code: Minor code fixes
- Feat: Added support for volumized archives

## 2.0.3-Stable (2016-08-09, Anlan)

- Code: Reimplemented Set-Alias for Junction.exe binary
- Code: Parsing of directives from selection file now takes precedence over switches and parameters

## 2.0.2-Stable (2016-07-22, Anlan)

- Bug: Improper output when Send-Notification is invoked
- Feat: added --solid switch to enable or disable solid archives
- Feat: compression / solid mode / threads can be also set in selection file
- Code: adjusted checks on removal of reparse points
- Code: adjusted count of maximum threads on single core sockets
- Feat: added switch -mhe for password protected archives

## 2.0.1-Stable (2016-06-08, Anlan)

- Code: Since version 15.x of 7-zip it can now save natively emtpy dirs therefore no need to create dummy files
- Code: Removed the check for pairs of command arguments. Now the parser checks properly also for switch arguments
- Code: Refactored Main Scanning Routine to eliminate Stack Overflow
- Feat: Removed the limit of 100 for maxdepth
- Feat: Added new command line switch --dry. This causes the script to go through all scanning directives but no compression or archiving is perfomed.
- Bug: rotation of archives might delete directories with same name. Included check for "is not a PSContainer"
- Feat: --emptydirs is now a switch argument
- Feat: addedd --compression argument
- Feat: Removed the parsing of BkSwitches
- Feat: addedd --pre and --post action switches to enable the execution of personalized scripts before and after the archiving process
- Bug: MaxFileAge and MinFileAge are fixed as double
- Feat: Archive name gets composed with trailing seconds
- Feat: Refactored writing of logs and details with StreamWriters instead of Out-File. Now scanning speed is 5x up to 20x
- Code: Refactored async launch of 7-zip process to get proper return core
- Feat: --maxfileage and --minfileage can now be passed as switches
- Feat: --maxfilesize and --minfilesize can now be passed as switches
- Feat: --pre and --post switches can invoke pws actions
- Feat: --threads switch can control resource usage by 7-zip

## 1.10.3-Stable (2016-04-25, Anlan)

- Code: Typo in LasWriteTime instead of LastWriteTime
- Feat: MaxFileAge and MinFileAge now support Decimal
- Feat: MaxFileAge and MinFileAge can be passed by CLI

## 1.10.2-Stable (2015-12-10, Anlan)

- Code: Some code refactoring to improve speed

## 1.10.1-Stable (2015-11-30, Anlan)

- Bug: Wrong parsing of output files
- Code: Some code refactoring

## 1.10.0-Stable (2015-11-22, Anlan)

- Feat: Added support for 7zip 15.x
- Code: Some code refactoring

## 1.9.11-Stable (2015-10-22, Anlan)

- Bug: For Windows 10 the statement $Host.UI.RawUI.FlushInputBuffer should be $Host.UI.RawUI.FlushInputBuffer()

## 1.9.10-Stable (2015-02-17, Anlan)

- Bug: Argument --notifyextra incorrectly values variable BkArchiveType

## 1.9.9-Stable (2014-11-14, Anlan)

- Bug: Parameter --7zbin should be --7zipbin. Added both for backwards compatibility.
- Bug: includeSource directives should not be processed if in wrong format
- Feat: try to include empty directories (if writable)

## 1.9.8-Stable (2014-08-14, Anlan)

- Feat: Now lock file holds process id and RootDir. Subsequent launches of script will check if "old" process is still running and responding or if it is stuck.

## 1.9.7-Stable (2014-02-05, Anlan)

- Bug: Get-ChildItem in ProcessFolder routine now uses -LiteralPath to allow processing of folder names with square brackets in it.

## 1.9.6-Stable (2013-11-26, Anlan)

- Bug: Typo in variable naming smtpPass which caused authenticated SMTP to fail

## 1.9.5-Stable (2013-10-18, Anlan)

- Feat: Rewritten the launcher of 7zip with *old* fashioned batch. Better monitoring of exit codes. Now works ok with PWS 2.0
- Feat: New argument --notifyextra to drive the way extra information is delivered with the notification log
- Bug: NoFollowJunctions switch was inverted
- Feat: Added new directive maxfilesize and minfilesize to enhance file selection based upon their size

## 1.9.0-Stable (2013-01-12, Anlan)

- Feat: Rewritten the launcher of 7zip with Start-Process. Now you can monitor the progress of 7zip's job.
- Code: Improved the effectiveness of interception of CTRL+C so you can safely interrupt the execution of the script even while 7zip is running.
- Code: Workdrive is checked for NTFS filesystem

## 1.8.4-Stable (2013-01-07, Anlan)

- Code: Removed DoTry function in favour of native Try-Catch-Finally Statement
- Bug: Function SendNotificationMail do not properly dispose objects so root directory can not be safely deleted

## 1.8.3-Stable (2012-10-18, Anlan)

- Code: new smtpssl to enable Ssl over smtp transport

## 1.8.2-Stable (2012-08-25, Anlan)

- Code: Email report now has Exceptions Include and Exlude lists as attachments.

## 1.8.1-Stable (2012-08-19, Anlan)

- Code: New work switch maxrecursionlevel to limit recursion depth in searching files.
- Code: rotate argument switch can now be set in selection file too
- Code: prefix argument switch can now be set in selection file too
- Code: prefix argument switch is checked against invalid file name chars

## 1.8.0-Stable (2012-04-19, Anlan)

- Code: Added support for Symbolic Links (MKLINK) for Windows Vista / 7 / 2008 +. Now it supports remote UNC paths as source for backups

## 1.7.7-Stable (2011-11-29, Anlan)

- Code: Correct assumption of rotation criteria
- Code: Email messages are sent even if backup is locked by previous operation.
- Code: Email priority and Suffix changed on Critical Conditions
- Bug: Log file does not get deleted if operation fails

## 1.7.6-Stable (2011-09-08, Anlan)

- Code: Changed IsValidIp function so it can properly handle IpV6 and IpV4 addresses type.
- Code: Added datetimeStamp to autogenerated logfile name so it will not mess with other logs working

## 1.7.5-Stable (2011-08-30, Anlan)

- Code: Implemented support for smtpUser and smtpPass switches to allow smtp authentication against relay server. Credit to marek vita (http://www.codeplex.com/site/users/view/marek_vita)

## 1.7.4-Stable (2011-06-09, Anlan)

- Code: Inserted by default /accepteula switch for junction.exe

## 1.7.3-Stable (2010-12-07, Anlan)

- Bug: Reading back compressed files from 7zip standard output caused non ASCII chars to be mismatched. Fixed. Changed the population of $BkCompressDetails with a stdout redirection in UTF8 following Igor Pavolv suggestion

## 1.7.2-Stable (2010-12-06, Anlan)

- Bug: Routine Clear-FsAttribute rewritten due to errors by by cmdlet Get-Item while handling long paths with many escape chars (like brackets and so on ...)
- Bug: If lock file detected then script aborts leaving root backup directory in place.

## 1.7.1-Stable (2010-04-26, Anlan)

- Bug: Presence of junction.exe is wrongly referred to 7z.exe

## 1.7.0-Stable (2010-01-18, Anlan)

- Bug: Test-Path-Writable fails on root of system drive on Windows 7. Therefore the function now accepts an optional parameter to specify if the write test has to be performed with a directory or a file.
- Feat: Now you can specify "move" as backup type. It will remove source files after successful archiving.
- Feat: Added new directive matchcleanupfiles into selections file. This will allow the deletion of unuseful/unwanted files during the selection phase.
- Feat: CTRL+C is now intercepted by the script to allow a smooth close of the procedure avoiding the ugly case to leave unwanted junctions on disk.

## 1.6.1-Stable (2010-01-18, Anlan)

- Bug: Clearing of archive bit did not catch errors properly
- Bug: Try function does not work on PWS 2.0 as it's a statement changed name to DoTry so we can run on both 1.0 and 2.0
- Bug: Log file was not created correctly with .log extension
- Feat: Now implements a VERY rudimental lock system to prevent more than one instance of the script.

## 1.6.0-Stable (2010-01-17, Anlan)

- Code: Complete rewrite of the main code
- Feat: Added some more sophisticated error handling
- Feat: All formal errors within the command line are now dropped in a single shot.
- Feat: All sensitive variables are now in a separated file so you can replace the script with new version/relase without the need to re-edit hardcoded values
- Feat: Exceptions on selection are now included in log file
- Feat: Sending of notification email now implements Try/Catch
- Feat: Information about sender/recipient address for notification email with the addition of the host to use as smtp relay can now be passed by cli using new arguments.
- Feat: You can specify location of either 7z.exe and Junction.exe by cli using proper arguments

## 1.5.7-Stable (2010-01-14, Anlan)

- Bug: Wrong encoding in 7-Zip output causes incorrect translation on file names therefore making impossible for the script to go and clear "A" attribute on it. Solved by encoding in UTF8 output from 7-Zip
- Ui: Statistics on selection now include Absolute and Increasing percent of overall file sizes

## 1.5.6-Stable (2010-01-13, Anlan)

- Bug: Incorrect assumption on Clear Archive Bit logic. The clearing of archive bit is executed on FULL or INCR backups. This is not correct. *It should be on FULL or DIFF backups*

## 1.5.5-Stable (2010-01-11, Anlan)

- Bug: Late clearing of archive bit after compression may fail if the file does not exist anymore. In addition the list of selected files has been encoded in UTF8 to allow selection of file names with accented letters.

## 1.5.4-Stable (2010-01-11, Anlan)

- Bug: The clearing of archive bit did not work.

## 1.5.3-Stable (2010-01-01, Anlan)

- Speed: Removed "late" addition of info files to archive as this causes a sensible delay on huge archives.
- Ui: Log file now includes exceptions from 7-Zip (e.g file not found)
- Speed: Get-Content of selection file is now in one single pass
- Feat: Added support for --maxfileage and --minfileafe directives in selection file
- Feat: New argument --clearbit to enforce clearing of "Archive" attribute on archived files

## 1.5.2-Stable (2009-12-31, Anlan)

- Minor: Revised error handling in ProcessFolder Function
- Minor: ProcessFolder now Silently Continues
- New: Added support for matchincludefiles directive
- New: Detailed catch of 7-Zip exit codes
- New: Added control --rotate does not pass a negative number
- Ui: More detailed output log with performance indicator
- Speed: Adjusted default 7-Zip switches to a less aggressive compression rate in favour of processing speed.

## 1.5.1-Stable (2009-12-29, Anlan)

- Minor Fixes: $totalBytes strongly typed to [int64]
- Get-ChildItem in ProcessFolder now with -ErrorAction Stop

## 1.5-Stable (2009-12-29, Anlan)

- --workdir switch has been dismissed
- To prevent the occurrence of PathTooLong Exception as much as possible now the script will generate a short randomly named directory in the root of the drive specified by the --workdrive switch which has now become mandatory
- Complete rewrite of the selection process to speed it up and new directives to stop recursion and to honor (or not) junctions during scanning process

## 01.002-beta (2009-12-24, Anlan)

- Clear Archive Bit now uses Set-ItemProperty
- ProcessFolder now implements -force switch to discover hidden files

## 01.001-beta (2009-12-08, Anlan)

- Minor Fixes

## 01.000-beta (2009-11-04, Anlan)

- First release
