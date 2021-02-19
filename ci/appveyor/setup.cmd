set PATH=C:\projects\ruby\bin;C:\Program Files\Git\mingw64\bin;C:\projects\openstudio\bin;%PATH%
set GEM_HOME=C:\projects\openstudio-server\gems
set GEM_PATH=C:\projects\openstudio-server\gems;C:\projects\openstudio-server\gems\gems\bundler\gems
echo Downloading and Installing OpenStudio (develop branch, %OPENSTUDIO_VERSION%%OPENSTUDIO_VERSION_EXT%+%OPENSTUDIO_VERSION_SHA%)
REM install develop build
set OS_INSTALL_NAME=OpenStudio-%OPENSTUDIO_VERSION%%OPENSTUDIO_VERSION_EXT%%%2B%OPENSTUDIO_VERSION_SHA%-Windows.exe
echo Install name is %OS_INSTALL_NAME%
curl -SLO --insecure https://openstudio-builds.s3.amazonaws.com/%OPENSTUDIO_VERSION%/%OS_INSTALL_NAME%
dir .
REM Install OpenStudio
%OS_INSTALL_NAME% --script ci/appveyor/install-windows.qs
move C:\openstudio C:\projects\openstudio
dir C:\projects\openstudio
dir C:\projects\openstudio\Ruby
rm %OS_INSTALL_NAME%
REM install portable ruby
curl -SLO https://openstudio-resources.s3.amazonaws.com/pat-dependencies3/ruby-2.5.5-win32.tar.gz
tar -xvzf ruby-2.5.5-win32.tar.gz -C C:\projects
rm ruby-2.5.5-win32.tar.gz
cd c:\projects\openstudio-server
ruby -v
openstudio openstudio_version

REM If you change RUBYLIB here, make sure to change it in integration-test.ps1 and unit-test.cmd too
set RUBYLIB=C:\projects\openstudio\Ruby
ruby C:\projects\openstudio-server\bin\openstudio_meta install_gems --with_test_develop --debug --verbose
REM dying over next 2 lines w/ "system cannot find path specified" - maybe just ruby.exe?
cd c:\projects\openstudio-server
which bundle
bundle install
REM echo List out the test Directory
REM dir C:\projects\openstudio-server\spec\files\
