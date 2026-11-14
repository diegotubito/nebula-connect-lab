# Run interactively on the enrolled home lab PC. All paths belong to the Windows lab service.
& {
    $ErrorActionPreference = 'Stop'
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Abri PowerShell como administrador.' }
    $name = 'NebulaConnectServiceLab'
    $root = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) $name
    $data = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) $name
    $releaseHash = 'A1618344CE2D0CABD384CF1B78B92B983AD45337867FFA49DAEA7CE9AC310460'
    $base = Join-Path $root "recovery-$releaseHash"
    $library = Join-Path $base 'upgrade-recovery.ps1'
    if ((Get-FileHash $library).Hash -ne 'F5EAEE239F3A8A268F681426115CB2628DDFEF81C6BA2939BEF14E0AFCC68E2B' -or (Get-FileHash "$base/upgrade.json").Hash -ne $releaseHash) { throw 'Se requiere el kit de recuperacion rc.5 original.' }
    . $library
    $lock = Enter-UpgradeLock
    $drainHandle = $null
    $kitRoot = $null
    try {
        $config = Get-Content "$data/config.json" -Raw | ConvertFrom-Json
        $hash = [Security.Cryptography.SHA256]::Create()
        try { $serial = [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes([string]$config.readers[0].serial))).Replace('-','') } finally { $hash.Dispose() }
        if ($config.mode -cne 'photo_only' -or @($config.readers).Count -ne 1 -or $serial -ne 'D96D563765D111CD9A9EE3499B53CA418A3E6B6A49D7786D9DF396E7FAD62285') { throw 'La prueba requiere el unico lector de Casa.' }
        $before = Get-CimInstance Win32_Service -Filter "Name='$name'"
        if ($before.State -ne 'Running' -or $before.StartMode -ne 'Auto' -or $before.StartName -ine "NT SERVICE\$name" -or $before.PathName -ine ('"' + (Join-Path $root "$name.exe") + '"')) { throw 'Servicio de laboratorio no reconocido.' }
        $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        $original = Get-Content "$base/upgrade.json" -Raw | ConvertFrom-Json
        $allowed = @($original.PSObject.Properties.Name)
        foreach ($file in $allowed) {
            if ((Get-FileHash (Assert-KitPath $root $file $allowed)).Hash -ne $original.$file.current) { throw "No coincide rc.5: $file" }
        }
        $workerFile = 'runtime/uface-sync-windows-host.mjs'
        $changed = @($workerFile,'connect-version.txt')
        $stage = Join-Path $root 'upgrade-preparing'
        $journal = Join-Path $root 'upgrade-pending'
        $garbage = Join-Path $root 'upgrade-finished'
        foreach ($path in @($stage,$journal,$garbage,"$root/h3-transition.previous")) { if (Test-Path $path) { throw 'Hay una actualizacion pendiente.' } }
        $configHash = (Get-FileHash "$data/config.json").Hash
        $credentialHash = (Get-FileHash "$data/credentials.dpapi").Hash
        Wait-UpgradeWorker ([DateTime]::UtcNow) 'h4-rc.5'
        $kitRoot = Join-Path $root ('rollback-test-' + [guid]::NewGuid())
        [void][IO.Directory]::CreateDirectory("$kitRoot/runtime")
        $source = [IO.File]::ReadAllText((Join-Path $root $workerFile))
        $source = $source.Replace("workerVersion: 'h4-rc.5'", "workerVersion: 'rollback-probe'")
        if (!$source.Contains("workerVersion: 'rollback-probe'")) { throw 'Worker de prueba no reconocido.' }
        [IO.File]::WriteAllText((Join-Path $kitRoot $workerFile),$source)
        [IO.File]::WriteAllText("$kitRoot/connect-version.txt",'rollback-test')
        $receipt = @{}
        foreach ($file in $changed) { $receipt[$file] = @{current=(Get-FileHash (Join-Path $kitRoot $file)).Hash} }
        $runtimeChange = $true
        $Approved = $false
        Write-Output 'Probando recuperacion. Espera a que termine antes de consultar la foto.'
        $drainHandle = Enter-UpgradeDrain
        [void][IO.Directory]::CreateDirectory($stage)
        try { Apply-Upgrade; throw 'El candidato de prueba fue aceptado.' }
        catch { if ($_.Exception.Message -cne 'Unexpected worker version.') { throw } }
        $after = Get-CimInstance Win32_Service -Filter "Name='$name'"
        if ((Test-Path $journal) -or $after.State -ne 'Running' -or !$after.ProcessId -or $after.ProcessId -eq $before.ProcessId -or $after.StartMode -ne 'Auto' -or (Get-CimInstance Win32_OperatingSystem).LastBootUpTime -ne $boot) { throw 'No se pudo verificar el reinicio del servicio.' }
        foreach ($file in $changed) { if ((Get-FileHash (Join-Path $root $file)).Hash -ne $original.$file.current) { throw "No se restauro $file." } }
        if ((Get-FileHash "$data/config.json").Hash -ne $configHash -or (Get-FileHash "$data/credentials.dpapi").Hash -ne $credentialHash -or (& "$root/nebula.exe" --version) -cne 'h4-rc.5') { throw 'Verificacion final de rc.5 o su vinculacion fallida.' }
        Wait-UpgradeWorker ([DateTime]::UtcNow) 'h4-rc.5'
        Write-Output "ROLLBACK OK | h4-rc.5 | Running | PID $($before.ProcessId) -> $($after.ProcessId) | mismo arranque de Windows | vinculacion conservada"
    } finally {
        if ($drainHandle) { $drainHandle.Dispose() }
        try { if ($kitRoot -and (Test-Path $kitRoot)) { Remove-Item -LiteralPath $kitRoot -Recurse -Force } } finally { $lock.Dispose() }
    }
}
