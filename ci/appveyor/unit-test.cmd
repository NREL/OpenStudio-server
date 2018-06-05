set RUBYLIB=C:\projects\openstudio\Ruby
set PATH=C:\Ruby%RUBY_VERSION%\bin;C:\Mongodb\bin;%PATH%
cd c:\projects\openstudio-server
echo Running unit tests against local server
mkdir C:\projects\openstudio-server\spec\unit-test\
ruby "C:/projects/openstudio-server/bin/openstudio_meta" run_rspec --debug --verbose --mongo-dir="C:\Mongodb\bin" "C:/projects/openstudio-server/spec/unit-test"
