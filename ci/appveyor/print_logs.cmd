cd C:\projects\openstudio-server\spec\
echo Current directory is %cd%
echo.
echo === SPEC FOLDER TREE STRUCTURE ===
tree /f
echo.
echo.
echo === PRINTING ERROR LOG REPORTS ===
echo.

:: for %%i in (C:\projects\openstudio-server\spec\files\logs\*.log) do (
::   echo ======================================================
::    echo %%i
::    echo ======================================================
::    type %%i
::    echo.
::)

::for %%i in (C:\projects\openstudio-server\spec\unit-test\logs\*.log) do (
::    echo ======================================================
::    echo %%i
::    echo ======================================================
::    type %%i
::    echo.
::)

:: Single command to recursively search for and print all .log files
:: starting from the current directory (spec)
for /r %%i in (*.log) do (
    echo ======================================================
    echo %%i
    echo ======================================================
    type "%%i"
    echo.
)
