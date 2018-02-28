set RUBYLIB=C:\projects\openstudio\Ruby
set PATH=C:\Ruby%RUBY_VERSION%\bin;C:\Mongodb\bin;%PATH%
cd c:\projects\openstudio-server
echo Running unit tests against local server
mkdir C:\projects\openstudio-server\spec\unit-test\
gem install bundler -v 1.14.4
bundle install --with default development test
ruby bundle exec rspec -e 'unit tests'
