@echo off
REM Set initial PATH with Git, Ruby binaries, and DevKit
set PATH=C:\Ruby32-x64\bin;C:\DevKit\bin;C:\Program Files\Git\mingw64\bin;C:\projects\openstudio\bin;%PATH%

REM Set Bundler version and configure GEM paths
set BUNDLE_VERSION=2.4.10
set GEM_HOME=C:\projects\openstudio-server\gems
set GEM_PATH=C:\projects\openstudio-server\gems;C:\projects\openstudio-server\gems\bundler\gems

echo Downloading and Installing OpenStudio (develop branch, %OPENSTUDIO_VERSION%%OPENSTUDIO_VERSION_EXT%+%OPENSTUDIO_VERSION_SHA%)
set OS_INSTALL_NAME=OpenStudio-%OPENSTUDIO_VERSION%%OPENSTUDIO_VERSION_EXT%+%OPENSTUDIO_VERSION_SHA%-Windows.exe
echo Install name is %OS_INSTALL_NAME%

REM Download and Install OpenStudio
curl -SLO --insecure https://github.com/NREL/OpenStudio/releases/download/v%OPENSTUDIO_VERSION%%OPENSTUDIO_VERSION_EXT%/%OS_INSTALL_NAME%
dir .

REM Execute the OpenStudio installer
%OS_INSTALL_NAME% --script ci/appveyor/install-windows.qs
move C:\openstudio C:\projects\openstudio
dir C:\projects\openstudio

REM Cleanup installer
del %OS_INSTALL_NAME%

REM Show Ruby version and OpenStudio version
ruby -v
openstudio openstudio_version

REM Install essential Ruby gems needed for the environment setup
echo Installing essential gems...
call gem install rake
if %ERRORLEVEL% neq 0 (
    echo Failed to install rake
    exit /b %ERRORLEVEL%
)

REM Setup MSYS2 and MinGW toolchain
echo Setting up MSYS2 and MinGW toolchain
call ridk install 2 3

REM Upgrade everything *but* gcc, so we never bump past 14.2.0
echo Upgrading MSYS2 (but ignoring gcc)...
call ridk exec bash -lc "pacman -Syu --needed --noconfirm --ignore mingw-w64-ucrt-x86_64-gcc*,mingw-w64-i686-gcc*"


REM Uninstall any existing Bundler
echo Uninstalling existing versions of Bundler
call gem uninstall -aIx bundler

REM Install specified version of Bundler
echo Installing Bundler %BUNDLE_VERSION%
call gem install bundler -v %BUNDLE_VERSION%
if %ERRORLEVEL% neq 0 (
    echo Failed to install Bundler %BUNDLE_VERSION%
    exit /b %ERRORLEVEL%
)

REM Verify Bundler installation
call bundle --version
if %ERRORLEVEL% neq 0 (
    echo Bundler was not installed correctly.
    exit /b %ERRORLEVEL%
)

REM Set RUBYLIB environment variable
set RUBYLIB=C:\projects\openstudio\Ruby

REM Install gems as specified
echo Installing required Ruby gems...
call bundle install --verbose
if %ERRORLEVEL% neq 0 (
    echo Attempting to manually install problematic gems...
    gem install <problematic-gem-name> -- --use-system-libraries
    if %ERRORLEVEL% neq 0 (
        echo Manual gem installation also failed.
        exit /b %ERRORLEVEL%
    )
)

REM Navigate to the server directory and run the gem installation script
cd C:\projects\openstudio-server
call ruby C:\projects\openstudio-server\bin\openstudio_meta install_gems --with_test_develop --debug --verbose
if %ERRORLEVEL% neq 0 (
    echo Gem installation script failed.
    exit /b %ERRORLEVEL%
)
