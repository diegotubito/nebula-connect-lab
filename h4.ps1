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
        Invoke-WebRequest -UseBasicParsing 'https://github.com/diegotubito/nebula-connect-lab/releases/download/h4-rc.3/Nebula-Connect-configurar.zip' -OutFile $zip
        if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne '3fd99d705404dc9280a43e4469ac2f0b0891835822e2defd6f098d93fcc6f137') { throw 'Descarga incorrecta. No se instalo.' }
        Unblock-File -LiteralPath $zip
        Expand-Archive -LiteralPath $zip -DestinationPath "$temp/kit"
        & "$env:SystemRoot/System32/WindowsPowerShell/v1.0/powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "$temp/kit/install-cli.ps1"
        if ($LASTEXITCODE) { throw 'No se pudo preparar H4. No reinicies para esta prueba.' }
        $version = & "$root/nebula.exe" --version
        $task = Get-ScheduledTask -TaskPath '\' -TaskName 'NebulaConnectServiceLab-ApprovedUpdate' -ErrorAction Stop
        $service = Get-Service NebulaConnectServiceLab
        if ($version -cne 'h4-rc.3' -or $task.State -in @('Disabled','Unknown') -or $service.Status -ne 'Running') { throw 'Connect no pudo confirmar el servicio, la version y la tarea de actualizacion.' }
        Write-Output 'H4 rc.3 listo. Servicio activo y actualizaciones automaticas habilitadas.'
    } finally { Remove-Item $temp -Recurse -Force }
}
