set PATH=C:\Program Files\Git\mingw64\bin;C:\projects\openstudio\bin;%PATH%
echo Downloading and Installing OpenStudio (%OPENSTUDIO_VERSION%%OPENSTUDIO_VERSION_EXT%.%OPENSTUDIO_VERSION_SHA%)
curl -SLO --insecure https://openstudio-ci-builds.s3-us-west-2.amazonaws.com/develop3/OpenStudio-2.8.1.5f1c403208-Windows.exe
OpenStudio-%OPENSTUDIO_VERSION%%OPENSTUDIO_VERSION_EXT%.%OPENSTUDIO_VERSION_SHA%-Windows.exe --script ci/appveyor/install-windows.qs
move C:\openstudio C:\projects\openstudio
dir C:\projects\openstudio
dir C:\projects\openstudio\Ruby

cd c:\projects\openstudio-server

REM If you change RUBYLIB here, make sure to change it in integration-test.ps1 and unit-test.cmd too
set RUBYLIB=C:\projects\openstudio\Ruby
cd c:\
REM Install rubygems-update in order to fix the SSL issue. Once updated, remove the gem.
REM curl -SLO https://rubygems.org/downloads/rubygems-update-2.7.8.gem
REM C:\Ruby%RUBY_VERSION%\bin\ruby C:\Ruby%RUBY_VERSION%\bin\gem install --local C:\rubygems-update-2.7.8.gem
REM C:\Ruby%RUBY_VERSION%\bin\ruby C:\Ruby%RUBY_VERSION%\bin\update_rubygems --no-ri --no-rdoc
REM C:\Ruby%RUBY_VERSION%\bin\ruby C:\Ruby%RUBY_VERSION%\bin\gem uninstall rubygems-update -x -v 2.7.8
C:\Ruby25\bin\ruby C:\projects\openstudio-server\bin\openstudio_meta install_gems --with_test_develop --debug --verbose
cd c:\projects\openstudio-server
REM C:\Ruby%RUBY_VERSION%\bin\ruby C:\Ruby%RUBY_VERSION%\bin\bundle install
echo List out the test Directory
dir C:\projects\openstudio-server\spec\files\