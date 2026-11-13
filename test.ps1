& {
    $ErrorActionPreference = 'Stop'
    $name = 'NebulaConnectServiceLab'
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Abri Windows PowerShell como administrador.' }
    $data = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) $name
    if (!(Test-Path -LiteralPath $data -PathType Container) -or (Test-Path "$data/config.json") -or (Test-Path "$data/credentials.dpapi")) { throw 'Solo se admite el piloto sin aprovisionar.' }
    $exe = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) "$name\$name.exe"
    $filter = "Name='$name'"
    $before = Get-CimInstance Win32_Service -Filter $filter
    if ($before.State -ne 'Running' -or $before.StartName -ne "NT SERVICE\$name" -or $before.PathName -ne ('"' + $exe + '"')) { throw 'Servicio no reconocido.' }
    $process = Get-Process -Id $before.ProcessId
    try {
        $null = $process.Handle
        if ($process.Path -ne $exe -or $process.HasExited) { throw 'Proceso no reconocido.' }
        $old = $process.Id
        $process.Kill()
    } finally { $process.Dispose() }
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        Start-Sleep -Seconds 2
        $now = Get-CimInstance Win32_Service -Filter $filter
        if ($now.State -eq 'Running' -and $now.ProcessId -gt 0 -and $now.ProcessId -ne $old) {
            Write-Output "OK: recuperacion automatica. PID anterior $old, nuevo $($now.ProcessId)."
            return
        }
    } while ($timer.Elapsed.TotalSeconds -lt 75)
    throw "Recuperacion no confirmada. Estado: $($now.State), PID: $($now.ProcessId)."
}
