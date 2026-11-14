# Read-only diagnostic for the paired Windows x64 lab service.
& {
    $ErrorActionPreference = 'Stop'
    $name = 'NebulaConnectServiceLab'
    $root = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) $name
    $data = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) $name

    function Read-State($path) {
        if (!(Test-Path -LiteralPath $path)) { return }
        try { Get-Content -LiteralPath $path -Raw | ConvertFrom-Json }
        catch { Write-Warning "Could not read $([IO.Path]::GetFileName($path))." }
    }
    function Format-Time($value) {
        if ($null -eq $value) { return '-' }
        return ([DateTimeOffset]$value).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ssZ')
    }

    $service = Get-CimInstance Win32_Service -Filter "Name='$name'"
    if (!$service) { throw 'Connect lab service was not found.' }
    $receipt = Read-State (Join-Path $root 'approved-update.json')
    $status = Read-State (Join-Path $data 'state/status.json')
    $task = Get-ScheduledTask -TaskPath '\' -TaskName "$name-ApprovedUpdate" -ErrorAction SilentlyContinue
    $version = Get-Content -LiteralPath (Join-Path $root 'connect-version.txt') -Raw
    Write-Output ("CLI {0} | worker {1} ({2}) | service {3}, PID {4}" -f $version.Trim(), $status.workerVersion, $status.state, $service.State, $service.ProcessId)
    $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $started = if ($service.ProcessId) { (Get-Process -Id $service.ProcessId -ErrorAction SilentlyContinue).StartTime }
    Write-Output ("Windows boot {0} | service start {1}" -f (Format-Time $boot), (Format-Time $started))
    if ($task) {
        $run = $task | Get-ScheduledTaskInfo
        Write-Output ("Update task {0} | last {1} | result {2} | next {3}" -f $task.State, (Format-Time $run.LastRunTime), $run.LastTaskResult, (Format-Time $run.NextRunTime))
    } else { Write-Output 'Update task unavailable' }
    if ($receipt) {
        Write-Output ("Approval {0} | {1} | {2}" -f $receipt.version, $receipt.status, (Format-Time $receipt.at))
    } else { Write-Output 'No approval receipt yet' }
}
