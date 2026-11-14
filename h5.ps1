& {
    $ErrorActionPreference = 'Stop'
    if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64' -or ![Environment]::Is64BitProcess) { throw 'Se requiere Windows x64.' }
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Abri PowerShell como administrador.' }
    $root = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'NebulaConnectServiceLab'
    if (!(Test-Path "$root/runtime/uface-sync-windows-host.mjs") -or !(Test-Path "$env:ProgramData/NebulaConnectServiceLab/config.json")) { throw 'Se requiere Connect H3 ya vinculado.' }
# Enroll the existing home PC for H5. Display only the public fingerprint.
& {
    $ErrorActionPreference = 'Stop'
    $name = 'NebulaConnectServiceLab'
    $root = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) $name
    $data = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) $name
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    if (!(New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Abri PowerShell como administrador.' }
    $service = Get-CimInstance Win32_Service -Filter "Name='$name'"
    if ($service.State -ne 'Running' -or $service.StartName -ine "NT SERVICE\$name" -or $service.PathName -ine ('"' + (Join-Path $root "$name.exe") + '"')) { throw 'Se requiere el servicio de Casa en ejecucion.' }
    $config = Get-Content -LiteralPath "$data/config.json" -Raw | ConvertFrom-Json
    $hash = [Security.Cryptography.SHA256]::Create()
    try {
        $reader = @($config.readers | Where-Object { [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes([string]$_.serial))).Replace('-','') -ceq 'D96D563765D111CD9A9EE3499B53CA418A3E6B6A49D7786D9DF396E7FAD62285' })
        if ($config.mode -cne 'photo_only' -or $config.origin -cne 'https://nebulacontrol.cloud' -or $reader.Count -ne 1) { throw 'No se encontro el lector vinculado de Casa.' }
        Add-Type -AssemblyName System.Security
        $file = Join-Path $data 'machine-identity.dpapi'
        $scope = [Security.Cryptography.DataProtectionScope]::LocalMachine
        if (!(Test-Path -LiteralPath $file)) {
            $secret = New-Object byte[] 32
            $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
            $temp = "$file.$([Guid]::NewGuid()).tmp"
            try {
                $rng.GetBytes($secret)
                [IO.File]::WriteAllBytes($temp,[Security.Cryptography.ProtectedData]::Protect($secret,$null,$scope))
                try { [IO.File]::Move($temp,$file) } catch [IO.IOException] { if (![IO.File]::Exists($file)) { throw } }
            } finally { $rng.Dispose(); [Array]::Clear($secret,0,$secret.Length); [IO.File]::Delete($temp) }
        }
        $secret = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($file),$null,$scope)
        try {
            if ($secret.Length -ne 32) { throw 'Identidad local invalida.' }
            $fingerprint = [BitConverter]::ToString($hash.ComputeHash($secret)).Replace('-','').ToLowerInvariant()
            Write-Output "Casa H5 | $fingerprint"
        } finally { [Array]::Clear($secret,0,$secret.Length) }
    } finally { $hash.Dispose() }
}

    $temp = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) ('NebulaH4Temp-' + [guid]::NewGuid())
    New-Item -ItemType Directory $temp | Out-Null
    try {
        $zip = Join-Path $temp 'kit.zip'
        Invoke-WebRequest -UseBasicParsing 'https://github.com/diegotubito/nebula-connect-lab/releases/download/h4-rc.6/Nebula-Connect-configurar.zip' -OutFile $zip
        if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne 'a99aebb020f913873e2ad09c54c989d22ab38a3f08dd190043e544aebfe50aa8') { throw 'Descarga incorrecta. No se instalo.' }
        Unblock-File -LiteralPath $zip
        Expand-Archive -LiteralPath $zip -DestinationPath "$temp/kit"
        & "$env:SystemRoot/System32/WindowsPowerShell/v1.0/powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "$temp/kit/install-cli.ps1"
        if ($LASTEXITCODE) { throw 'No se pudo preparar H4. No reinicies para esta prueba.' }
        $statusFile = Join-Path $env:ProgramData 'NebulaConnectServiceLab/state/status.json'
        $until = [DateTime]::UtcNow.AddSeconds(60)
        do {
            $status = $null
            try { $status = Get-Content -LiteralPath $statusFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop } catch { }
            if ($status.workerVersion -ceq 'h4-rc.6' -and $status.state -in @('available','unavailable') -and $status.at -and ([DateTimeOffset]::Parse($status.at)).UtcDateTime -gt [DateTime]::UtcNow.AddSeconds(-45)) { break }
            if ([DateTime]::UtcNow -ge $until) { throw 'Connect no pudo confirmar la version del servicio en ejecucion.' }
            Start-Sleep -Milliseconds 500
        } while ($true)
        $version = & "$root/nebula.exe" --version
        $task = Get-ScheduledTask -TaskPath '\' -TaskName 'NebulaConnectServiceLab-ApprovedUpdate' -ErrorAction Stop
        $service = Get-Service NebulaConnectServiceLab
        if ($version -cne 'h4-rc.6' -or $task.State -in @('Disabled','Unknown') -or $service.Status -ne 'Running') { throw 'Connect no pudo confirmar el servicio, la version y la tarea de actualizacion.' }
        Write-Output 'H5 Casa listo. Servicio activo.'
    } finally { Remove-Item $temp -Recurse -Force }
}
