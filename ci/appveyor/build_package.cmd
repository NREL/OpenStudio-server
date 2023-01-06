REM set PATH=C:\projects\ruby\bin;C:\Program Files\Git\mingw64\bin;C:\projects\openstudio\bin;%PATH%
set PATH=C:\Ruby27-x64\bin;C:\Program Files\Git\mingw64\bin;C:\projects\openstudio\bin;%PATH%
set BUNDLE_VERSION=2.1.4
set GEM_HOME=C:\projects\openstudio-server\gems
set GEM_PATH=C:\projects\openstudio-server\gems;C:\projects\openstudio-server\gems\gems\bundler\gems
set RUBYLIB=C:\projects\openstudio\Ruby
set OPENSTUDIO_TEST_EXE=C:\projects\openstudio\bin\openstudio

REM set mongo_dir??
cd c:\
mkdir export
ruby C:\projects\openstudio-server\bin\openstudio_meta install_gems --export="C:\export"
mv C:\export C:\projects\openstudio-server\export
dir C:\projects\openstudio-server\export
