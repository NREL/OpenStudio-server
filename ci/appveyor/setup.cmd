  curl -SLO https://openstudio-resources.s3.amazonaws.com/pat-dependencies/OpenStudio-2.0.3.40f61c64a3-win32.zip
  mkdir c:\projects\openstudio
  7z x OpenStudio-2.0.3.40f61c64a3-win32.zip -oc:\projects\openstudio
  curl -SLO https://dl.bintray.com/oneclick/rubyinstaller/ruby-2.2.4-x64-mingw32.7z
  mkdir c:\Ruby224-x64
  7z x ruby-2.2.4-x64-mingw32.7z -oc:\Ruby224-x64
  robocopy c:\Ruby224-x64\ruby-2.2.4-x64-mingw32\ c:\Ruby224-x64\ /E /MOVE /LOG:C:\projects\openstudio-server\spec\files\logs\robocopy.log /NFL /NDL
  copy /y c:\projects\openstudio-server\ci\appveyor\config.yml c:\Ruby23-x64\DevKit\config.yml
  cd c:\Ruby23-x64\DevKit
  ruby dk.rb install
  cd c:\projects\openstudio-server
  set RUBYLIB=C:\projects\openstudio\Ruby
  set PATH=C:\Ruby%RUBY_VERSION%\bin;C:\Mongodb\bin;%PATH%
  C:\Ruby%RUBY_VERSION%\bin\ruby C:\Ruby%RUBY_VERSION%\bin\gem update --system
  C:\Ruby%RUBY_VERSION%\bin\ruby c:\projects\openstudio-server\bin\openstudio_meta install_gems --with_test_develop --debug --verbose
  C:\Ruby%RUBY_VERSION%\bin\bundle install --gemfile=C:\projects\openstudio-server\Gemfile
