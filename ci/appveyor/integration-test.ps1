$env:Path = "C:\Ruby32-x64\bin;C:\Mongodb\bin;$env:Path"
$env:RUBYLIB = "C:\projects\openstudio\Ruby"
$env:OPENSTUDIO_TEST_EXE = "C:\projects\openstudio\bin\openstudio.exe"
$env:GEM_HOME = "C:\projects\openstudio-server\gems"
$env:GEM_PATH = "C:\projects\openstudio-server\gems;C:\projects\openstudio-server\gems\gems\bundler\gems"
# Integration tests that run algo can only run on docker deployments. Setting BUILD_TYPE=test below skip algo tests. Only linux docker runs these tests  

Write-Host "RUBYLIB is: $env:RUBYLIB ; the PATH is: $env:Path ; the OPENSTUDIO_TEST_EXE is: $env:OPENSTUDIO_TEST_EXE"

Function Stop-ProcessTree {
    Param (
        [Parameter(Mandatory=$true)]
        [int]$PID
    )

    # Get all child processes of the process we want to stop
    $processes = Get-WmiObject Win32_Process -Filter "ParentProcessId = $PID"

    # Recursively call this function for each child process
    foreach ($process in $processes) {
        Stop-ProcessTree -PID $process.ProcessId
    }

    # Stop the main process after all its children have been stopped
    $process = Get-Process -Id $PID -ErrorAction SilentlyContinue
    if ($process) {
        Write-Host "Stopping process $PID"
        Stop-Process -Id $PID -Force
    }
}

$iteration = 0
:retry While ($iteration -lt 3)
    {
    Write-Host "Attempting to run rspec test; attempt $iteration"
    $tests = Start-Process -PassThru -WorkingDirectory "C:\projects\openstudio-server" -FilePath "bundle" -ArgumentList "exec rspec -e 'analysis'" -RedirectStandardOutput "C:\projects\openstudio-server\spec\files\logs\win-stdout.log" -RedirectStandardError "C:\projects\openstudio-server\spec\files\logs\win-stderr.log"
    $handle = $tests.Handle # See http://stackoverflow.com/a/23797762/1479211
    $timeout = new-timespan -Minutes 15
    $sw = [diagnostics.stopwatch]::StartNew()
    While ($sw.elapsed -lt $timeout)
        {
        If ($tests.HasExited)
            {
            If ($tests.ExitCode -ne 0)
                {
                $TestsExitCode = $tests.ExitCode
                Write-Host "Process exited with non-zero exit code $TestsExitCode"
                $iteration += 1
                Continue retry
                }
            Else
                {
                Write-Host "Process completed successfully"
                Get-ChildItem "C:\projects\openstudio-server\spec\files\logs" -Filter *.log |
                Foreach-Object {
                    Write-Host "Deleting file $_.FullName after successful integration test completion"
                    Remove-Item -path $_.FullName
                    }
                taskkill /T /F /PID $tests.ID
                Exit 0
                }
           }
        start-sleep -seconds 1
        }
    Write-Host "Process has not completed after 300 seconds. Invoking timeout"
    taskkill /T /F /PID $tests.ID
    Exit 1
    }
Write-Host "After 3 attempts assuming broken"
Exit 1
