set PATH=C:\Program Files\Git\mingw64\bin;C:\projects\openstudio\bin;%PATH%
set GEM_HOME=C:\projects\openstudio-server\gems
set GEM_PATH=C:\projects\openstudio-server\gems;C:\projects\openstudio-server\gems\gems\bundler\gems
echo Downloading and Installing OpenStudio (develop branch, %OPENSTUDIO_VERSION%%OPENSTUDIO_VERSION_EXT%.%OPENSTUDIO_VERSION_SHA%)
REM install  develop build
curl -SLO --insecure https://openstudio-builds.s3.amazonaws.com/3.0.0/OpenStudio-3.0.0-rc2%%2Bc1a45f4753-Windows.exe
OpenStudio-3.0.0-rc1%%2Bc1a45f4753-Windows.exe --script ci/appveyor/install-windows.qs
move C:\openstudio C:\projects\openstudio
dir C:\projects\openstudio
dir C:\projects\openstudio\Ruby

cd c:\projects\openstudio-server
ruby -v
openstudio openstudio_version

REM If you change RUBYLIB here, make sure to change it in integration-test.ps1 and unit-test.cmd too
set RUBYLIB=C:\projects\openstudio\Ruby
ruby C:\projects\openstudio-server\bin\openstudio_meta install_gems --with_test_develop --debug --verbose
REM dying over next 2 lines w/ "system cannot find path specified" - maybe just ruby.exe?
cd c:\projects\openstudio-server
C:\Ruby%RUBY_VERSION%\bin\ruby C:\Ruby%RUBY_VERSION%\bin\bundle install
REM echo List out the test Directory
REM dir C:\projects\openstudio-server\spec\files\
