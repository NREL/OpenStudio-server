# $tests = Start-Process -PassThru -WorkingDirectory "C:\projects\openstudio-server" -FilePath "bundle" -ArgumentList "exec rspec" -RedirectStandardOutput "C:\projects\openstudio-server\spec\files\logs\win-stderr.log" -RedirectStandardError "C:\projects\openstudio-server\spec\files\logs\win-stdout.log"
# $tests = Start-Process -PassThru -WorkingDirectory "C:\projects\openstudio-server" -FilePath "bundle" -ArgumentList "exec rspec" -NoNewMethod
Start-Sleep -Seconds 30
If ($tests.HasExited) {
  If ($tests.ExitCode -neq 0) {
    Write-Host "Process exited with non-zero exit code " $tests.ExitCode
    Exit 1
  } Else {
    Write-Host "Process completed successfully"
    Exit 0
  }
} Else {
  Write-Host "Process has not completed after 300 seconds. Invoking timeout"
  Exit 1
}
