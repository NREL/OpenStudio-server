$env:Path = "C:\Ruby$env:RUBY_VERSION\bin;C:\Mongodb\bin;$env:Path"
$env:RUBYLIB = "C:\projects\openstudio\Ruby"
$iteration = 0
:retry While ($iteration -lt 4)
    {
    Write-Host "Attempting to run rspec test; attempt $iteration"
    $tests = Start-Process -PassThru -WorkingDirectory "C:\projects\openstudio-server" -FilePath "bundle" -ArgumentList "exec rspec" -RedirectStandardOutput "C:\projects\openstudio-server\spec\files\logs\win-stdout.log" -RedirectStandardError "C:\projects\openstudio-server\spec\files\logs\win-stderr.log"
    $handle = $tests.Handle # See http://stackoverflow.com/a/23797762/1479211
    $timeout = new-timespan -Minutes 5
    $sw = [diagnostics.stopwatch]::StartNew()
    While ($sw.elapsed -lt $timeout)
        {
        If ($tests.HasExited)
            {
            If ($tests.ExitCode -ne 0) {
            $TestsExitCode = $tests.ExitCode
                Write-Host "Process exited with non-zero exit code $TestsExitCode"
                $iteration += 1
                Continue retry
            }
            Else
            {
                Write-Host "Process completed successfully"
                Exit 0
            }
        }
        start-sleep -seconds 1
    }
    Write-Host "Process has not completed after 300 seconds. Invoking timeout"
    taskkill /T /F /PID $tests.ID
    Exit 1
}
Write-Host "After 4 attempts assuming broken"
Exit 1
