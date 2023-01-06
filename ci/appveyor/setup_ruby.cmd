REM Setup supported bundler on windows 
set PATH=C:\Ruby27-x64\bin;C:\Program Files\Git\mingw64\bin;
set BUNDLE_VERSION=2.1.4

REM  uninstall versions of bundler that cause problems 
call gem uninstall -s --force bundler
del C:\Ruby27-x64\lib\ruby\gems\2.7.0\specifications\bundler*
call gem install bundler -v %BUNDLE_VERSION%
which bundle
call bundle --version
