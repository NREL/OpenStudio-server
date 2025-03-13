# Define a function to kill a process and its children recursively.
function Stop-ProcessTree {
    param (
        [Parameter(Mandatory=$true)]
        [int]$ProcessId
    )

    # Get all child processes using CIM. (Requires admin privileges.)
    $children = Get-CimInstance Win32_Process -Filter "ParentProcessId = $ProcessId" -ErrorAction SilentlyContinue
    foreach ($child in $children) {
        Stop-ProcessTree -ProcessId $child.ProcessId
    }
    # Kill the process if it's still running.
    try {
        Stop-Process -Id $ProcessId -Force -ErrorAction Stop
        Write-Output "Killed process with PID $($ProcessId)"
    }
    catch {
        Write-Output "Failed to kill process with PID $($ProcessId): $($_)"
    }
}

# Set GEM_HOME variable (if not already set)
$gemHome = $env:GEM_HOME

# Loop over processes and check for modules loaded from GEM_HOME.
Get-Process | ForEach-Object {
    try {
        foreach ($mod in $_.Modules) {
            if ($mod.FileName -like "*$gemHome*") {
                Write-Output "Process $($_.Name) (PID: $($_.Id)) has loaded module: $($mod.FileName)"
                # Kill the process tree.
                Stop-ProcessTree -ProcessId $_.Id
                # Once we kill a process, break out of the inner loop.
                break
            }
        }
    }
    catch {
        # Skip processes that do not allow module inspection.
    }
}