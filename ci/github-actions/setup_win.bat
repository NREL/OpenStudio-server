@echo off
setlocal

REM --- Install OpenStudio ---
set "InstallerName=OpenStudio-%OPENSTUDIO_VERSION%%OPENSTUDIO_VERSION_EXT%+%OPENSTUDIO_VERSION_SHA%-Windows.exe"
set "Url=https://github.com/NREL/OpenStudio/releases/download/v%OPENSTUDIO_VERSION%%OPENSTUDIO_VERSION_EXT%/%InstallerName%"

echo Downloading %Url%...
powershell -Command "Invoke-WebRequest -Uri '%Url%' -OutFile '%InstallerName%'"
if %ERRORLEVEL% neq 0 (
    echo Failed to download OpenStudio from %Url% (exit code %ERRORLEVEL%)
    exit /b %ERRORLEVEL%
)

echo Installing OpenStudio...
start /wait "" ".\%InstallerName%" /S /D=C:\projects\openstudio
if %ERRORLEVEL% neq 0 (
    echo Failed to install OpenStudio from "%InstallerName%" (exit code %ERRORLEVEL%)
    exit /b %ERRORLEVEL%
)

REM Verify OpenStudio
set "PATH=C:\projects\openstudio\bin;%PATH%"
call openstudio openstudio_version
if %ERRORLEVEL% neq 0 (
    echo Failed to verify OpenStudio installation - 'openstudio openstudio_version' command failed (exit code %ERRORLEVEL%)
    exit /b %ERRORLEVEL%
)

REM --- Setup MSYS2 and Dependencies ---
call ridk install 2 3
if %ERRORLEVEL% neq 0 (
    echo Failed to install MSYS2 dependencies via ridk (exit code %ERRORLEVEL%)
    exit /b %ERRORLEVEL%
)

call gcc --version
if %ERRORLEVEL% neq 0 (
    echo Error: gcc not found
    exit /b %ERRORLEVEL%
)

endlocal
