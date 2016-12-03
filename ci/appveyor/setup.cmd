  curl -SLO https://openstudio-resources.s3.amazonaws.com/pat-dependencies/OpenStudio2-1.13.0.fb588cc683-win32.zip
  mkdir c:\projects\openstudio
  7z x OpenStudio2-1.13.0.fb588cc683-win32.zip -oc:\projects\openstudio
  set RUBYLIB=C:\projects\openstudio\Ruby
  set PATH=C:\Ruby%RUBY_VERSION%\bin;C:\Mongodb\bin;%PATH%
  C:\Ruby%RUBY_VERSION%\bin\ruby C:\Ruby%RUBY_VERSION%\bin\gem update --system
  C:\Ruby%RUBY_VERSION%\bin\ruby c:\projects\openstudio-server\bin\openstudio_meta install_gems --with_test_develop --debug --verbose
  C:\Ruby%RUBY_VERSION%\bin\bundle install --gemfile=C:\projects\openstudio-server\Gemfile
