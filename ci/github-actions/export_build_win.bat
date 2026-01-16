@echo off
setlocal

REM Create export directory
if not exist "C:\export" mkdir C:\export

REM Install Bundler
call gem install bundler -v %BUNDLE_VERSION% --no-document
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

REM Run Build
call ruby bin\openstudio_meta install_gems --export="C:\export" --debug
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

REM Move export to workspace for upload
if not exist "build\NREL" mkdir build\NREL
move C:\export build\NREL\export
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

endlocal
