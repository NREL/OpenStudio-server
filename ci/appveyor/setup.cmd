set PATH=C:\Program Files\Git\mingw64\bin;%PATH%
echo Downloading and Installing OpenStudio (%OPENSTUDIO_VERSION%.%OPENSTUDIO_VERSION_SHA%)
curl -SLO --insecure https://s3.amazonaws.com/openstudio-builds/%OPENSTUDIO_VERSION%/OpenStudio-%OPENSTUDIO_VERSION%.%OPENSTUDIO_VERSION_SHA%-Windows.exe
OpenStudio-%OPENSTUDIO_VERSION%.%OPENSTUDIO_VERSION_SHA%-Windows.exe --script ci/appveyor/install-windows.qs
move C:\openstudio C:\projects\openstudio
dir C:\projects\openstudio
dir C:\projects\openstudio\Ruby

echo Downloading and Installing Ruby
curl -SLO https://dl.bintray.com/oneclick/rubyinstaller/ruby-2.2.4-x64-mingw32.7z
mkdir c:\Ruby224-x64
7z x ruby-2.2.4-x64-mingw32.7z -oc:\Ruby224-x64
robocopy c:\Ruby224-x64\ruby-2.2.4-x64-mingw32\ c:\Ruby224-x64\ /E /MOVE /LOG:C:\projects\openstudio-server\spec\files\logs\robocopy-ruby.log /NFL /NDL
copy /y c:\projects\openstudio-server\ci\appveyor\config.yml c:\Ruby23-x64\DevKit\config.yml
cd c:\Ruby23-x64\DevKit
ruby dk.rb install
cd c:\projects\openstudio-server

REM If you change RUBYLIB here, make sure to change it in integration-test.ps1 and unit-test.cmd too
set RUBYLIB=C:\projects\openstudio\Ruby
set PATH=C:\Ruby%RUBY_VERSION%\bin;C:\Mongodb\bin;%PATH%
cd c:\
curl -SLO https://rubygems.org/downloads/rubygems-update-2.6.7.gem
C:\Ruby%RUBY_VERSION%\bin\ruby C:\Ruby%RUBY_VERSION%\bin\gem install --local C:\rubygems-update-2.6.7.gem
C:\Ruby%RUBY_VERSION%\bin\ruby C:\Ruby%RUBY_VERSION%\bin\update_rubygems --no-ri --no-rdoc
C:\Ruby%RUBY_VERSION%\bin\ruby C:\Ruby%RUBY_VERSION%\bin\gem update --system
C:\Ruby%RUBY_VERSION%\bin\ruby C:\Ruby%RUBY_VERSION%\bin\gem uninstall rubygems-update -x -v 2.6.7
C:\Ruby%RUBY_VERSION%\bin\ruby C:\projects\openstudio-server\bin\openstudio_meta install_gems --with_test_develop --debug --verbose
cd c:\projects\openstudio-server
C:\Ruby%RUBY_VERSION%\bin\ruby C:\Ruby%RUBY_VERSION%\bin\bundle install

echo List out the test Directory
dir C:\projects\openstudio-server\spec\files\