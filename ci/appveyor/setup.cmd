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
curl -fSLO --insecure https://github.com/NREL/OpenStudio/releases/download/v%OPENSTUDIO_VERSION%%OPENSTUDIO_VERSION_EXT%/%OS_INSTALL_NAME%
if %ERRORLEVEL% neq 0 (
  echo ERROR: Failed to download "%OS_INSTALL_NAME%" from "https://github.com/NREL/OpenStudio/releases/download/v%OPENSTUDIO_VERSION%%OPENSTUDIO_VERSION_EXT%/%OS_INSTALL_NAME%"
  exit /b 1
)
dir .
echo Show that the file is present in the working directory
dir "%CD%\%OS_INSTALL_NAME%"

REM  “Unblock” the file so Windows does not refuse to execute it
powershell -Command "Unblock-File -Path '%CD%\%OS_INSTALL_NAME%'"

REM Execute the OpenStudio installer
REM %OS_INSTALL_NAME% --script ci/appveyor/install-windows.qs
REM  3) Run the OpenStudio installer in “quiet” mode, pointing to our QScript
echo Launching installer…
REM  Use “.\” to ensure we’re running the downloaded EXE in the current directory
.\%OS_INSTALL_NAME% --script ci/appveyor/install-windows.qs
if %ERRORLEVEL% neq 0 (
  echo.
  echo ERROR: OpenStudio installer "%OS_INSTALL_NAME%" returned error code %ERRORLEVEL%. Aborting.
  exit /b 1
)

REM move C:\openstudio C:\projects\openstudio
REM  4) Move the default “C:\openstudio” install directory into the projects dir
if exist C:\openstudio (
  move /Y C:\openstudio C:\projects\openstudio
  if %ERRORLEVEL% neq 0 (
    echo.
    echo ERROR: Could not move “C:\openstudio” to “C:\projects\openstudio”. Check permissions.
    exit /b 1
  )
) else (
  echo.
  echo ERROR: After running the installer, “C:\openstudio” was not found. Aborting.
  exit /b 1
)
dir C:\projects\openstudio

REM Cleanup installer
del %OS_INSTALL_NAME%

REM Show Ruby version and OpenStudio version
ruby -v
openstudio openstudio_version
if %ERRORLEVEL% neq 0 (
  echo.
  echo ERROR: “openstudio openstudio_version” failed. Perhaps OpenStudio wasn’t installed correctly?
  exit /b 1
)

REM Install essential Ruby gems needed for the environment setup
echo Installing essential gems...
call gem install rake
if %ERRORLEVEL% neq 0 (
    echo Failed to install rake
    REM exit /b %ERRORLEVEL%
)

REM Setup MSYS2 and MinGW toolchain
echo Setting up MSYS2 and MinGW toolchain
call ridk install 2 3

echo Downloading GCC-14.2.0 packages…
curl -LO https://github.com/ruby/setup-msys2-gcc/releases/download/msys2-packages/mingw-w64-ucrt-x86_64-gcc-14.2.0-3-any.pkg.tar.zst
curl -LO https://github.com/ruby/setup-msys2-gcc/releases/download/msys2-packages/mingw-w64-ucrt-x86_64-gcc-14.2.0-3-any.pkg.tar.zst.sig
curl -LO https://github.com/ruby/setup-msys2-gcc/releases/download/msys2-packages/mingw-w64-ucrt-x86_64-gcc-libs-14.2.0-3-any.pkg.tar.zst
curl -LO https://github.com/ruby/setup-msys2-gcc/releases/download/msys2-packages/mingw-w64-ucrt-x86_64-gcc-libs-14.2.0-3-any.pkg.tar.zst.sig

echo Installing GCC-libs 14.2.0…
call ridk exec pacman.exe -Udd --noconfirm --noprogressbar mingw-w64-ucrt-x86_64-gcc-libs-14.2.0-3-any.pkg.tar.zst
echo Installing GCC 14.2.0…
call ridk exec pacman.exe -Udd --noconfirm --noprogressbar mingw-w64-ucrt-x86_64-gcc-14.2.0-3-any.pkg.tar.zst
echo Verifying that gcc is now 14.2.0:
call ridk exec gcc --version

REM Uninstall any existing Bundler
echo Uninstalling existing versions of Bundler
call gem uninstall -aIx bundler

echo Installing Bundler inside MSYS2/RIDK environment…
call ridk exec gem install bundler -v %BUNDLE_VERSION% --no-document
if %ERRORLEVEL% neq 0 (
  echo ERROR: ridk exec gem install bundler failed
  REM exit /b %ERRORLEVEL%
)

echo Verifying Bundler via ridk exec…
call ridk exec bundle --version
if %ERRORLEVEL% neq 0 (
  echo ERROR: bundler still not found inside MSYS2 environment
  REM exit /b %ERRORLEVEL%
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
        REM exit /b %ERRORLEVEL%
    )
)

REM Navigate to the server directory and run the gem installation script
cd C:\projects\openstudio-server
call ruby C:\projects\openstudio-server\bin\openstudio_meta install_gems --with_test_develop --debug --verbose
if %ERRORLEVEL% neq 0 (
    echo Gem installation script failed.
    REM exit /b %ERRORLEVEL%
)
