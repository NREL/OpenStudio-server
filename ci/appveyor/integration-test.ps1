$env:Path = "C:\Ruby$env:RUBY_VERSION\bin;C:\Mongodb\bin;$env:Path"
$env:RUBYLIB = "C:\projects\openstudio\Ruby"
Write-Host "RUBYLIB is: $env:RUBYLIB and the PATH is: $env:Path"
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
