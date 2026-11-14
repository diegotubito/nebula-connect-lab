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
