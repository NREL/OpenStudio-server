$env:Path = "C:\Ruby$env:RUBY_VERSION\bin;C:\Mongodb\bin;$env:Path"
$env:RUBYLIB = "C:\projects\openstudio\Ruby"
$tests = Start-Process -PassThru -WorkingDirectory "C:\projects\openstudio-server" -FilePath "bundle" -ArgumentList "exec rspec" -RedirectStandardOutput "C:\projects\openstudio-server\spec\files\logs\win-stdout.log" -RedirectStandardError "C:\projects\openstudio-server\spec\files\logs\win-stderr.log"
$timeout = new-timespan -Minutes 5
$sw = [diagnostics.stopwatch]::StartNew()
while ($sw.elapsed -lt $timeout){
    If ( $tests.HasExited ) {
        If ( $tests.ExitCode -ne 0 ) {
            Write-Host "Process exited with non-zero exit code " $tests.ExitCode
            Exit 1
        } Else {
            Write-Host "Process completed successfully"
            Exit 0
        }
    }
    start-sleep -seconds 1
}
Write-Host "Process has not completed after 300 seconds. Invoking timeout"
taskkill /T /F /PID $tests.ID
Exit 1
