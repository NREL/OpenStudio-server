@echo off
setlocal

REM --- Install OpenStudio ---
set "InstallerName=OpenStudio-%OPENSTUDIO_VERSION%%OPENSTUDIO_VERSION_EXT%+%OPENSTUDIO_VERSION_SHA%-Windows.exe"
set "Url=https://github.com/NREL/OpenStudio/releases/download/v%OPENSTUDIO_VERSION%%OPENSTUDIO_VERSION_EXT%/%InstallerName%"

echo Downloading %Url%...
powershell -Command "Invoke-WebRequest -Uri '%Url%' -OutFile '%InstallerName%'"
if %ERRORLEVEL% neq 0 (
    echo Error downloading OpenStudio
    exit /b %ERRORLEVEL%
)

echo Installing OpenStudio...
start /wait "" ".\%InstallerName%" /S /D=C:\projects\openstudio
if %ERRORLEVEL% neq 0 (
    echo Error installing OpenStudio
    exit /b %ERRORLEVEL%
)

REM Verify OpenStudio
set "PATH=C:\projects\openstudio\bin;%PATH%"
call openstudio openstudio_version
if %ERRORLEVEL% neq 0 (
    echo Error verifying OpenStudio
    exit /b %ERRORLEVEL%
)

REM --- Setup MSYS2 and Dependencies ---
call ridk install 2 3
if %ERRORLEVEL% neq 0 (
    echo Error running ridk install
    exit /b %ERRORLEVEL%
)

call gcc --version

endlocal
