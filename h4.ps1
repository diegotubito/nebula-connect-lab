& {
    $ErrorActionPreference = 'Stop'
    if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64' -or ![Environment]::Is64BitProcess) { throw 'Se requiere Windows x64.' }
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Abri PowerShell como administrador.' }
    $root = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'NebulaConnectServiceLab'
    if (!(Test-Path "$root/runtime/uface-sync-windows-host.mjs") -or !(Test-Path "$env:ProgramData/NebulaConnectServiceLab/config.json")) { throw 'Se requiere Connect H3 ya vinculado.' }
    $temp = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) ('NebulaH4Temp-' + [guid]::NewGuid())
    New-Item -ItemType Directory $temp | Out-Null
    try {
        $zip = Join-Path $temp 'kit.zip'
        Invoke-WebRequest -UseBasicParsing 'https://github.com/diegotubito/nebula-connect-lab/releases/download/h4-rc.4/Nebula-Connect-configurar.zip' -OutFile $zip
        if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne '34a76c54cff56e6c522fa9b56c344f0039a0160deefb1a54440f87606e76e779') { throw 'Descarga incorrecta. No se instalo.' }
        Unblock-File -LiteralPath $zip
        Expand-Archive -LiteralPath $zip -DestinationPath "$temp/kit"
        & "$env:SystemRoot/System32/WindowsPowerShell/v1.0/powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "$temp/kit/install-cli.ps1"
        if ($LASTEXITCODE) { throw 'No se pudo preparar H4. No reinicies para esta prueba.' }
        $statusFile = Join-Path $env:ProgramData 'NebulaConnectServiceLab/state/status.json'
        $until = [DateTime]::UtcNow.AddSeconds(60)
        do {
            $status = $null
            try { $status = Get-Content -LiteralPath $statusFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop } catch { }
            if ($status.workerVersion -ceq 'h4-rc.4' -and $status.state -in @('available','unavailable') -and $status.at -and ([DateTimeOffset]::Parse($status.at)).UtcDateTime -gt [DateTime]::UtcNow.AddSeconds(-45)) { break }
            if ([DateTime]::UtcNow -ge $until) { throw 'Connect no pudo confirmar la version del servicio en ejecucion.' }
            Start-Sleep -Milliseconds 500
        } while ($true)
        $version = & "$root/nebula.exe" --version
        $task = Get-ScheduledTask -TaskPath '\' -TaskName 'NebulaConnectServiceLab-ApprovedUpdate' -ErrorAction Stop
        $service = Get-Service NebulaConnectServiceLab
        if ($version -cne 'h4-rc.4' -or $task.State -in @('Disabled','Unknown') -or $service.Status -ne 'Running') { throw 'Connect no pudo confirmar el servicio, la version y la tarea de actualizacion.' }
        Write-Output 'H4 rc.4 listo. Servicio activo y actualizaciones automaticas habilitadas.'
    } finally { Remove-Item $temp -Recurse -Force }
}
