& {
    param([string]$Version = '0.3.0-rc.1')
    if ($Version -cne '0.3.0-rc.1') { throw "Version del servicio no publicada: $Version. Disponible: 0.3.0-rc.1." }
    $Action = 'install'
    $ErrorActionPreference = 'Stop'
    if ($env:OS -ne 'Windows_NT' -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64' -or ![Environment]::Is64BitProcess) { throw 'Se requiere Windows x64 y Windows PowerShell de 64 bits.' }
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Abri Windows PowerShell como administrador.' }
    $folder = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) ('NebulaH2Temp-' + [guid]::NewGuid())
    New-Item -ItemType Directory $folder | Out-Null
    try {
        $zip = Join-Path $folder 'pilot.zip'
        $kit = Join-Path $folder 'kit'
        $url = 'https://github.com/diegotubito/nebula-connect-lab/releases/download/h2-win-pilot.1/Nebula-Connect-H2-Windows-pilot.zip'
        Invoke-WebRequest -UseBasicParsing $url -OutFile $zip
        if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne '51854de6498a34b28e9102ff81fe5ffe23c0623a756ffe7d150b3f491dbf5627') { throw 'Hash incorrecto. Descarga rechazada.' }
        Unblock-File -LiteralPath $zip
        Expand-Archive -LiteralPath $zip -DestinationPath $kit
        $name = 'NebulaConnectServiceLab'
        $root = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) $name
        $data = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) $name
        $existing = Get-CimInstance Win32_Service -Filter "Name='$name'"
        if ($existing) {
            $exe = "$name.exe"
            $expectedPath = '"' + (Join-Path $root $exe) + '"'
            if ($existing.StartName -ne "NT SERVICE\$name" -or $existing.PathName -ne $expectedPath) {
                throw 'Existe otro registro de servicio con ese nombre. Revisar cuenta y ruta.'
            }
            foreach ($dir in @($root, $data, (Join-Path $data 'state'), (Join-Path $root 'runtime'), (Join-Path $root 'runtime/connect-service'))) {
                $item = Get-Item -LiteralPath $dir -Force
                if (!$item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Directorio no reconocido: $dir" }
            }
            $payloads = @((Get-Item -LiteralPath (Join-Path $kit $exe))) + @(Get-ChildItem -LiteralPath (Join-Path $kit 'runtime') -File -Recurse)
            foreach ($payload in $payloads) {
                $relative = $payload.FullName.Substring($kit.Length + 1)
                $installed = Get-Item -LiteralPath (Join-Path $root $relative) -Force
                if ($installed.PSIsContainer -or ($installed.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
                    (Get-FileHash -LiteralPath $installed.FullName).Hash -ne (Get-FileHash -LiteralPath $payload.FullName).Hash) {
                    throw "Archivo instalado distinto del paquete solicitado: $relative"
                }
            }
            Write-Output "Nebula Connect $Version ya esta instalado. Estado: $($existing.State)."
            $existing | Select-Object Name,State,StartMode,StartName,ProcessId
            return
        }
        if ((Test-Path -LiteralPath $root) -or (Test-Path -LiteralPath $data)) {
            throw 'Hay carpetas de Nebula Connect pero falta el registro del servicio. Se requiere inspeccion.'
        }
        $file = Join-Path $kit "$Action-service.ps1"
        & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File $file
        if ($LASTEXITCODE -ne 0) { throw "Fallo la operacion $Action; revisa el error anterior." }
        if ($Action -eq 'install') {
            $service = Get-CimInstance Win32_Service -Filter "Name='NebulaConnectServiceLab'"
            if ($service.State -ne 'Running' -or $service.StartMode -ne 'Auto' -or $service.StartName -ne 'NT SERVICE\NebulaConnectServiceLab') { throw 'Estado o identidad inesperados.' }
            $service | Select-Object Name,State,StartMode,StartName,ProcessId
        }
    } finally { Remove-Item -LiteralPath $folder -Recurse -Force }
} @args
