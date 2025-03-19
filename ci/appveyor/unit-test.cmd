set RUBYLIB=C:\projects\openstudio\Ruby
set PATH=C:\Ruby32-x64\bin;C:\Mongodb\bin;%PATH%
cd c:\projects\openstudio-server
echo Running unit tests against local server
mkdir C:\projects\openstudio-server\spec\unit-test\
ruby "C:/projects/openstudio-server/bin/openstudio_meta" run_rspec --debug --verbose --mongo-dir="C:\Mongodb\bin" --openstudio-exe-path="C:\projects\openstudio\bin\openstudio.exe" "C:/projects/openstudio-server/spec/unit-test"
if %ERRORLEVEL% neq 0 (
    echo Unit tests failed.
    exit 1
) else (
    echo Unit tests passed.  Killing hanging ruby.exe
    taskkill /IM ruby.exe /F /T
    exit 0
)
