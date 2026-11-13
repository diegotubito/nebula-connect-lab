& {
    $ErrorActionPreference = 'Stop'
    if ($env:OS -ne 'Windows_NT' -or ![Environment]::Is64BitProcess) { throw 'Se requiere Windows PowerShell de 64 bits.' }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    if (!(New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Abri Windows PowerShell como administrador.'
    }
    $root = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'NebulaConnectLab'
    if (!(Test-Path -LiteralPath $root)) { Write-Output 'Connect de laboratorio ya esta ausente.'; return }

    function Require-Plain($path, $directory) {
        $item = Get-Item -LiteralPath $path -Force
        if ($item.PSIsContainer -ne $directory -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Ruta no reconocida: $path"
        }
    }
    function Check-Hash($path, $digest) {
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $digest) { throw "Archivo no reconocido: $path" }
    }
    $manifests = @{
        '0.2.0' = 'c6f4dda0304360256decba43efa35663825ba3f0c9f1d5e201451a65ce0e489b'
        '0.2.1' = 'fd19f21aeec38e7be5543885eafa40aeb950d682565212136c1a691440270cf7'
        '0.2.2' = 'e6dffcb775a32c39eeeb4529fa3b8d68cd3c25d5441ec00bd84a13763ff28507'
        '0.2.3' = '414748c244fa67c6185b12e00d25f5639c8c63f65444c653f24d2e1a21cfab81'
    }
    Require-Plain $root $true
    $lockFile = Join-Path $root 'lock'
    Require-Plain $lockFile $false
    $lock = [IO.File]::Open($lockFile, 'Open', 'ReadWrite', 'None')
    try {
        if ($lock.Length -ne 0) { throw 'Lock desconocido.' }
        $allowed = @('lock','base','manage.ps1','active.txt','previous.txt','nebula.cmd')
        $versions = @()
        foreach ($entry in Get-ChildItem -LiteralPath $root -Force) {
            if ($manifests.ContainsKey($entry.Name)) {
                Require-Plain $entry.FullName $true
                $versions += $entry.Name
                $manifest = Join-Path $entry.FullName 'manifest.json'
                Require-Plain $manifest $false
                Check-Hash $manifest $manifests[$entry.Name]
                $files = (Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json).hashes.PSObject.Properties
                foreach ($file in $files) {
                    $path = Join-Path $entry.FullName $file.Name
                    Require-Plain $path $false
                    Check-Hash $path $file.Value
                }
                if (@(Get-ChildItem -LiteralPath $entry.FullName -Force).Count -ne (@($files).Count + 1)) { throw 'Contenido adicional en la version.' }
            } else {
                if ($entry.Name -notin $allowed) { throw "Contenido ajeno: $($entry.Name)" }
                Require-Plain $entry.FullName $false
            }
        }
        $manager = (Get-FileHash -LiteralPath (Join-Path $root 'manage.ps1')).Hash
        if ($manager -notin @('e733ef2426f5ccaa41640d259384d7f30f592d23826d748ea5f670540e973813','5f5e4d4afe9a0d7c772dd6646e326262f12cf0e1045f817533f539ed6f99b991')) { throw 'Gestor de laboratorio desconocido.' }
        Check-Hash (Join-Path $root 'nebula.cmd') '1cd4bad86134c5ea7a6b83c80afe0787e1d85d7ffd10b175e99a61f32dab999a'
        if ([IO.File]::ReadAllText((Join-Path $root 'base')) -ne 'https://github.com/diegotubito/nebula-connect-lab/releases/download') { throw 'Origen desconocido.' }
        foreach ($name in 'active.txt','previous.txt') {
            $pointer = Join-Path $root $name
            if ($name -eq 'previous.txt' -and !(Test-Path -LiteralPath $pointer)) { continue }
            if ([IO.File]::ReadAllText($pointer) -notin $versions) { throw "Version desconocida en $name" }
        }
        # Preserve registry type and unexpanded entries, including %SystemRoot%.
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment', $true)
        try {
            $raw = $key.GetValue('Path', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            if ($null -eq $raw) { throw 'No se pudo leer el PATH de maquina.' }
            $parts = $raw.Split(';')
            $retained = @($parts | Where-Object { $_ -ne $root })
            if ($parts.Count - $retained.Count -gt 1) { throw 'PATH ambiguo.' }
            if ($parts.Count -ne $retained.Count) { $key.SetValue('Path', ($retained -join ';'), $key.GetValueKind('Path')) }
        } finally { if ($key) { $key.Dispose() } }
        foreach ($version in $versions) {
            $folder = Join-Path $root $version
            $manifest = Join-Path $folder 'manifest.json'
            foreach ($file in (Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json).hashes.PSObject.Properties) {
                [IO.File]::Delete((Join-Path $folder $file.Name))
            }
            [IO.File]::Delete($manifest)
            [IO.Directory]::Delete($folder)
        }
        foreach ($name in $allowed) { if ($name -ne 'lock') { [IO.File]::Delete((Join-Path $root $name)) } }
    } finally { $lock.Dispose() }
    [IO.File]::Delete($lockFile)
    [IO.Directory]::Delete($root)
    Write-Output 'Nebula Connect de laboratorio desinstalado. Cerra la terminal.'
}
