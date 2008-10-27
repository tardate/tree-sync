@echo off
echo A very simple tree-sync.pl test script for Windows
echo Tests most of the tree-sync functions assuming an ActivePerl environment
echo This should probably be a Perl script itself ... but hey, so many hours in the day only!
echo ----------------------------------------------------------------

setlocal

rem CUSTOMISATION NOTE: this will call an external script to set perl environment
rem                     If you have Perl env already setup, you can ignore this
call setPerlEnv
set PATH=%PATH%;D:\bin\cygwin\bin
set TEMP=c:\temp
rem END CUSTOMISATION NOTE

rem CUSTOMISATION NOTE: to perform tests between different drives, modify the
rem                     srcDir and destDir paths here
set srcDir=%TEMP%
set destDir=%TEMP%
rem                     Also, set scriptDrive and srcDrive if the srcDir is on 
rem                     different drive from where this script is executed
set scriptDrive=d:
set srcDrive=c:
rem END CUSTOMISATION NOTE

set scriptName=tree-sync.pl
set srcFolder=ts-test-src
set destFolder=ts-test-dest
set srcRoot=%srcDir%\%srcFolder%
set destRoot=%destDir%\%destFolder%
set runner="%TEMP%\sync-now.pl"
set log=%TEMP%\tree-sync.log
set optsByCmdFile=-width=130 -cmd=%runner%
set opts=-width=130 -run

echo Output logged to: %log%

rem Check grep availability
grep 2> nul
set grepstatus=%errorlevel%
if %grepstatus% == 2 goto grepok
echo NOTE: grep command not available. File update tests may not be checked fully.
goto prep
:grepok
set grepstatus=0
goto prep


:prep
echo ============ Prepare source test files
echo ============ Prepare source test files >> %log%
rmdir /s/q %srcRoot% 2> nul
rmdir /s/q %destRoot% 2> nul

mkdir %srcRoot%
echo "test" > "%srcRoot%\file 1.txt"
echo "test" > "%srcRoot%\file 2.txt"
rem this tests for special characters
echo "test" > "%srcRoot%\a @.txt"
echo "test" > "%srcRoot%\b $.txt"
rem this tests for regex special characters
echo "test" > "%srcRoot%\=A - (B) - C - (D,.txt"
mkdir "%srcRoot%\dir 1"
echo "test" > "%srcRoot%\dir 1\file 1.txt"
echo "test" > "%srcRoot%\dir 1\file 2.txt"
echo "test" > "%srcRoot%\dir 1\file 3.txt"
mkdir "%srcRoot%\dir 2"
echo "test" > "%srcRoot%\dir 2\file 1.txt"
echo "test" > "%srcRoot%\dir 2\file 2.txt"
rem this tests for quotes in names
mkdir "%srcRoot%\dir Q"
echo "test" > "%srcRoot%\dir Q\file 1'.txt"
mkdir "%srcRoot%\dir Q 'A"
echo "test" > "%srcRoot%\dir Q 'A\file 1.txt"

:test1
echo ============ Test 1: Initial full sync
echo              Expected behaviour: dest files created during sync
echo ============ Test 1: Initial full sync > %log%
echo              Expected behaviour: dest files created during sync >> %log%
perl %scriptName% %opts% %srcRoot% %destRoot% >> %log%

if not exist "%destRoot%\dir 2\file 2.txt" goto fail1
if not exist "%destRoot%\dir Q\file 1'.txt" goto fail1
if not exist "%destRoot%\dir Q 'A\file 1.txt" goto fail1
echo              ... pass
echo              ... pass >> %log%
goto test2
:fail1
echo              ... fail. Error in sync: Check results
echo              ... fail. Error in sync: Check results >> %log%
goto end

:test2
echo ============ Test 2: Add dir + files to source and full sync
echo              Expected behaviour: dest files added during sync
echo ============ Test 2: Add dir + files to source and full sync >> %log%
echo              Expected behaviour: dest files added during sync >> %log%
mkdir "%srcRoot%\dir 3"
echo "test" > "%srcRoot%\dir 3\file 1.txt"
echo "test" > "%srcRoot%\dir 3\file 2.txt"
perl %scriptName% %opts% %srcRoot%\ %destRoot%\ >> %log% 

if not exist "%destRoot%\dir 3\file 2.txt" goto fail2
echo              ... pass
echo              ... pass >> %log%
goto test3
:fail2
echo              ... fail. Error in sync: Check results
echo              ... fail. Error in sync: Check results >> %log%
goto end

:test3
echo ============ Test 3: Remove dir + files from source and full sync
echo              Expected behaviour: dest files removed during sync
echo ============ Test 3: Remove dir + files from source and full sync >> %log%
echo              Expected behaviour: dest files removed during sync >> %log%
rmdir /s/q "%srcRoot%\dir 3"
rmdir /s/q "%srcRoot%\dir Q"
rmdir /s/q "%srcRoot%\dir Q 'A"

perl %scriptName% %opts% %srcRoot%/ %destRoot%/ >> %log%

if exist "%destRoot%\dir 3" goto fail3
if exist "%destRoot%\dir Q" goto fail3
if exist "%destRoot%\dir Q 'A" goto fail3
echo              ... pass
goto test4
:fail3
echo              ... fail. Error in sync: Check results
echo              ... fail. Error in sync: Check results >> %log%
goto end


:test4
echo ============ Test 4: Remove dir + files from dest and full sync
echo              Expected behaviour: dest files restored during sync
echo ============ Test 4: Remove dir + files from dest and full sync >> %log%
echo              Expected behaviour: dest files restored during sync >> %log%
rmdir /s/q "%destRoot%\dir 2"
perl %scriptName% %opts% %srcRoot%/ %destRoot%/ >> %log%

if not exist "%destRoot%\dir 2" goto fail4
echo              ... pass
echo              ... pass >> %log%
goto test5
:fail4
echo              ... fail. Error in sync: Check results
echo              ... fail. Error in sync: Check results >> %log%
goto end


:test5
echo ============ Test 5: Add dir + files to dest and fwdonly sync
echo              Expected behaviour: dest files remain during sync
echo ============ Test 5: Add dir + files to dest and fwdonly sync >> %log%
echo              Expected behaviour: dest files remain during sync >> %log%
mkdir "%destRoot%\dir 4"
echo "test" > "%destRoot%\dir 4\file 1.txt"
echo "test" > "%destRoot%\dir 4\file 2.txt"
perl %scriptName% %opts% -syncmode=fwdonly %srcRoot%\ %destRoot%\ >> %log%

if not exist "%destRoot%\dir 4" goto fail5
echo              ... pass
echo              ... pass >> %log%
goto test6
:fail5
echo              ... fail. Error in sync: Check results
echo              ... fail. Error in sync: Check results >> %log%
goto end


:test6
echo ============ Test 6: Add dir + files to dest and full sync
echo              Expected behaviour: dest files removed during sync
echo ============ Test 6: Add dir + files to dest and full sync >> %log%
echo              Expected behaviour: dest files removed during sync >> %log%
rem files added during test 5
perl %scriptName% %opts% %srcRoot%\ %destRoot%\ >> %log%

if exist "%destRoot%\dir 4" goto fail6
echo              ... pass
echo              ... pass >> %log%
goto test7
:fail6
echo              ... fail. Error in sync: Check results
echo              ... fail. Error in sync: Check results >> %log%
goto end


:test7
sleep 3
echo ============ Test 7: Update files on source and full sync
echo              Expected behaviour: dest files updated during sync
echo ============ Test 7: Update files on source and full sync >> %log%
echo              Expected behaviour: dest files updated during sync >> %log%
echo "modified on source" >> "%srcRoot%\file 1.txt"
echo "modified on source" >> "%srcRoot%\dir 1\file 1.txt"
perl %scriptName% %opts% %srcRoot%\ %destRoot%\ >> %log% 

if %grepstatus% == 0 goto grepcheck7
echo              (not checking file explicitly with grep)
if not exist "%destRoot%\dir 1\file 1.txt" goto fail7
echo              ... pass
echo              ... pass >> %log%
goto test8
:grepcheck7
echo              (checking file explicitly with grep)
grep -c "modified on source" "%destRoot%\dir 1\file 1.txt" > nul
if %errorlevel% == 1 goto fail7
echo              ... pass
goto test8
:fail7
echo              ... fail. Error in sync: Check results
echo              ... fail. Error in sync: Check results >> %log%
goto end


:test8
echo ============ Test 8: Update files on dest and full sync
echo              Expected behaviour: src files updated during sync
echo ============ Test 8: Update files on dest and full sync >> %log%
echo              Expected behaviour: src files updated during sync >> %log%
echo "modified on dest" >> "%destRoot%\file 2.txt"
echo "modified on dest" >> "%destRoot%\dir 1\file 2.txt"
perl %scriptName% %opts% %srcRoot%\ %destRoot%\ >> %log%

if %grepstatus% == 0 goto grepcheck8
echo              (not checking file explicitly with grep)
if not exist "%srcRoot%\dir 1\file 2.txt" goto fail8
echo              ... pass
echo              ... pass >> %log%
goto test9
:grepcheck8
echo              (checking file explicitly with grep)
grep -c "modified on dest" "%srcRoot%\dir 1\file 2.txt" > nul
if %errorlevel% == 1 goto fail8
echo              ... pass
echo              ... pass >> %log%
goto test9
:fail8
echo              ... fail. Error in sync: Check results
echo              ... fail. Error in sync: Check results >> %log%
goto end


:test9
echo ============ Test 9: Update files on dest and fwdonly sync
echo              Expected behaviour: src + dest files not updated during sync
echo ============ Test 9: Update files on dest and fwdonly sync >> %log%
echo              Expected behaviour: src + dest files not updated during sync >> %log%
echo "test9 modified on dest" >> "%destRoot%\dir 1\file 3.txt"
perl %scriptName% %opts% -syncmode=fwdonly %srcRoot%\ %destRoot%\ >> %log%

if %grepstatus% == 0 goto grepcheck9
echo              (not checking file explicitly with grep)
if not exist "%srcRoot%\dir 1\file 3.txt" goto fail9
echo              ... pass
echo              ... pass >> %log%
goto test10
:grepcheck9
echo              (checking file explicitly with grep)
grep -c "test9 modified on dest" "%srcRoot%\dir 1\file 3.txt" > nul
if %errorlevel% == 0 goto fail9
echo              ... pass
echo              ... pass >> %log%
goto test10
:fail9
echo              ... fail. Error in sync: Check results
echo              ... fail. Error in sync: Check results >> %log%
goto end

:test10
echo ============ Test 10: Update files on dest and Sync using relative path for source and dest
echo              Expected behaviour: source updated ok
echo ============ Test 10: Update files on dest and Sync using relative path for source and dest >> %log%
echo              Expected behaviour: source updated ok >> %log%
echo "test9+10 modified on dest" >> "%destRoot%\dir 1\file 3.txt"
rem change drive/directory
%srcDrive%
cd %srcRoot%
perl %scriptDrive%%scriptName% %opts% .\ ..\%destFolder%\ >> %log%

if %grepstatus% == 0 goto grepcheck10
echo              (not checking file explicitly with grep)
if not exist "%srcRoot%\dir 1\file 3.txt" goto fail10
echo              ... pass
echo              ... pass >> %log%
goto endtest10
:grepcheck10
echo              (checking file explicitly with grep)
grep -c "test9+10 modified on dest" "%srcRoot%\dir 1\file 3.txt" > nul
if %errorlevel% == 1 goto fail10
echo              ... pass
echo              ... pass >> %log%
goto endtest10
:fail10
%scriptDrive%
echo              ... fail. Error in sync: Check results
echo              ... fail. Error in sync: Check results >> %log%
goto end
:endtest10
%scriptDrive%

:test11
echo ============ Test 11: Ignore ".csv" files
echo              Expected behaviour: dest files not include .csv files after sync
echo ============ Test 11: Ignore ".csv" files >> %log%
echo              Expected behaviour: dest files not include .csv files after sync >> %log%
echo "modified on source" >> "%srcRoot%\file 1.csv"
echo "modified on source" >> "%destRoot%\dir 1\file 1.csv"
perl %scriptName% %opts% -ignore csv %srcRoot%\ %destRoot%\ >> %log% 

if exist "%destRoot%\file 1.csv" goto fail11
if exist "%srcRoot%\dir 1\file 1.csv" goto fail11
echo              ... pass
echo              ... pass >> %log%
del "%srcRoot%\file 1.csv"
del "%destRoot%\dir 1\file 1.csv"
goto test12
:fail11
echo              ... fail. Error in sync: Check results
echo              ... fail. Error in sync: Check results >> %log%
goto end


:test12
echo ============ Test 12: Test for sync of read-only files
echo              Expected behaviour: read-only files should sync properly
echo ============ Test 12: Test for sync of read-only files >> %log%
echo              Expected behaviour: read-only files should sync properly >> %log%
set f="%srcRoot%\file 5.txt"
set fd="%destRoot%\file 5.txt"
echo "Test 12 attrib +R set on source" >> %f%
attrib +R %f%
perl %scriptName% %opts% %srcRoot%\ %destRoot%\ >> %log% 
attrib -R %f%
sleep 3
echo "Test 12 OK changed after attrib +R set on source" >> %f%
attrib +R %f%
perl %scriptName% %opts% %srcRoot%\ %destRoot%\ >> %log% 

if %grepstatus% == 0 goto grepcheck12
echo              (not checking file explicitly with grep)
if not exist %fd% goto fail12
echo              ... pass
echo              ... pass >> %log%
goto test13
:grepcheck12
echo              (checking file explicitly with grep)
grep -c "Test 12 OK" %fd% > nul
if %errorlevel% == 1 goto fail12
echo              ... pass
goto test13
:fail12
echo              ... fail. Error in sync: Check results
echo              ... fail. Error in sync: Check results >> %log%
goto end

:test13
echo ============ Test 13: Test for sync of read-write file where dest has been made read-only
echo              Expected behaviour: files should sync properly (-force by default)
echo ============ Test 13: Test for sync of read-write file where dest has been made read-only >> %log%
echo              Expected behaviour: files should sync properly (-force by default) >> %log%
set f="%srcRoot%\file 6.txt"
set fd="%destRoot%\file 6.txt"
echo "Test 13 created read-write on source" >> %f%
perl %scriptName% %opts% %srcRoot%\ %destRoot%\ >> %log% 
attrib +R %fd%
sleep 3
echo "Test 13 OK changed after attrib +R set on dest" >> %f%
perl %scriptName% %opts% %srcRoot%\ %destRoot%\ >> %log% 

if %grepstatus% == 0 goto grepcheck13
echo              (not checking file explicitly with grep)
if not exist %fd% goto fail13
echo              ... pass
echo              ... pass >> %log%
goto test14
:grepcheck13
echo              (checking file explicitly with grep)
grep -c "Test 13 OK" %fd% > nul
if %errorlevel% == 1 goto fail13
echo              ... pass
goto test14
:fail13
echo              ... fail. Error in sync: Check results
echo              ... fail. Error in sync: Check results >> %log%
goto end

:test14
echo ============ Test 14: Test for non-sync of read-write file where dest has been made read-only and -noforce specified
echo              Expected behaviour: files should not sync (-noforce)
echo ============ Test 14: Test for non-sync of read-write file where dest has been made read-only and -noforce specified >> %log%
echo              Expected behaviour: files should not sync (-noforce) >> %log%
set f="%srcRoot%\file 6.txt"
set fd="%destRoot%\file 6.txt"
echo "Test 14 created read-write on source" >> %f%
perl %scriptName% %opts% %srcRoot%\ %destRoot%\ >> %log% 
attrib +R %fd%
sleep 3
echo "Test 14 OK changed after attrib +R set on dest and -noforce" >> %f%
perl %scriptName% %opts% -noforce %srcRoot%\ %destRoot%\ >> %log% 

if %grepstatus% == 0 goto grepcheck14
echo              (not checking file explicitly with grep)
if not exist %fd% goto fail14
echo              ... pass
echo              ... pass >> %log%
goto test15
:grepcheck14
echo              (checking file explicitly with grep)
grep -c "Test 14 OK" %fd% > nul
if not %errorlevel% == 1 goto fail13
echo              ... pass
goto test15
:fail14
echo              ... fail. Error in sync: Check results
echo              ... fail. Error in sync: Check results >> %log%
goto end

:test15

:cleanup
goto end
echo ============ Cleanup test files
echo ============ Cleanup test files >> %log%
rmdir /s/q %srcRoot% 2> nul
rmdir /s/q %destRoot% 2> nul

:end
endlocal