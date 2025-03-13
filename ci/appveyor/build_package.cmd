REM set PATH=C:\projects\ruby\bin;C:\Program Files\Git\mingw64\bin;C:\projects\openstudio\bin;%PATH%
set PATH=C:\Ruby32-x64\bin;C:\Program Files\Git\mingw64\bin;C:\projects\openstudio\bin;%PATH%
set BUNDLE_VERSION=2.4.10
set GEM_HOME=C:\projects\openstudio-server\gems
set GEM_PATH=C:\projects\openstudio-server\gems;C:\projects\openstudio-server\gems\gems\bundler\gems
set RUBYLIB=C:\projects\openstudio\Ruby
set OPENSTUDIO_TEST_EXE=C:\projects\openstudio\bin\openstudio

REM set mongo_dir??
echo kill any hanging ruby.exe processes
taskkill /IM ruby.exe /F
echo timeout 60s
echo Downloading Handle...
curl -L -o handle.zip https://download.sysinternals.com/files/Handle.zip
tar -xf handle.zip -C %TEMP%
echo Checking for file locks...
REM %TEMP%\handle.exe C:\projects\openstudio-server\gems\gems\json-2.10.1 > %TEMP%\handle_output.txt
REM type %TEMP%\handle_output.txt
REM echo generator.so
REM %TEMP%\handle.exe C:\projects\openstudio-server\gems\gems\json-2.10.1\lib\json\ext\generator.so > %TEMP%\handle_output2.txt
REM type %TEMP%\handle_output2.txt
cd c:\
mkdir export
echo openstudio_meta install_gems --export
ruby C:\projects\openstudio-server\bin\openstudio_meta install_gems --use_cached_gems --export="C:\export" --debug
mv C:\export C:\projects\openstudio-server\export
dir C:\projects\openstudio-server\export
