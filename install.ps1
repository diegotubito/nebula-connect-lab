& {
    $ErrorActionPreference = 'Stop'
    $folder = $null
    try {
        if ($env:OS -ne 'Windows_NT' -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64' -or ![Environment]::Is64BitProcess) {
            throw 'Se requiere Windows 11 x64 y PowerShell de 64 bits.'
        }
        $user = [Security.Principal.WindowsIdentity]::GetCurrent()
        if (!(New-Object Security.Principal.WindowsPrincipal($user)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'Abri Windows PowerShell como administrador.'
        }
        $base = 'https://github.com/diegotubito/nebula-connect-lab/releases/download'
        $programs = [Environment]::GetFolderPath('ProgramFiles')
        $folder = (New-Item -ItemType Directory -Path (Join-Path $programs ('NebulaLabTemp-' + [guid]::NewGuid()))).FullName
        $file = Join-Path $folder 'install.ps1'
        Invoke-WebRequest -UseBasicParsing "$base/lab-0.2.0/windows-x64-install.ps1" -OutFile $file
        if ((Get-FileHash $file -Algorithm SHA256).Hash -ne 'e733ef2426f5ccaa41640d259384d7f30f592d23826d748ea5f670540e973813') { throw 'Fallo la verificacion del instalador.' }
        & $file -Version 0.2.0 -InstallFrom $base
        $version = & (Join-Path $programs 'NebulaConnectLab\nebula.cmd') --version
        if ($LASTEXITCODE -ne 0 -or $version -notin '0.2.0','0.2.1') { throw 'No se pudo confirmar la version instalada.' }
        Write-Output "Nebula Connect $version instalado. Abri una nueva terminal para usar nebula."
    } catch {
        throw "No se pudo instalar Nebula Connect: $($_.Exception.Message)"
    } finally {
        if ($folder) { Remove-Item -LiteralPath $folder -Recurse -Force }
    }
}
