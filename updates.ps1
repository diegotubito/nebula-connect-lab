& {
    $ErrorActionPreference = 'Stop'
    if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64' -or ![Environment]::Is64BitProcess) { throw 'Windows x64 required.' }
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Open PowerShell as administrator.' }
    $dir = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) ('NebulaUpdateTemp-' + [guid]::NewGuid())
    New-Item -ItemType Directory $dir -ErrorAction Stop | Out-Null
    try {
        & "$env:SystemRoot/System32/icacls.exe" $dir /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-11:(OI)(CI)RX' | Out-Null
        if ($LASTEXITCODE) { throw 'Could not secure rehearsal directory.' }
        $zip = Join-Path $dir 'rehearsal.zip'
        Invoke-WebRequest -UseBasicParsing 'https://github.com/diegotubito/nebula-connect-lab/releases/download/adopted.1/manager.zip' -OutFile $zip
        if ((Get-FileHash -LiteralPath $zip).Hash -ine 'f967e40fbb2f60c0da36081451d565f77f1fc8b74f6c62c5eea64812e1287c8a') { throw 'Update manager checksum mismatch.' }
        Unblock-File -LiteralPath $zip
        $kit = Join-Path $dir 'kit'
        Expand-Archive -LiteralPath $zip -DestinationPath $kit
        $entry = (Get-Item -LiteralPath (Join-Path $kit 'install.ps1')).FullName
        & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File $entry
        if ($LASTEXITCODE) { throw 'Update setup failed. Read the preceding diagnostic.' }
    } finally { Remove-Item -LiteralPath $dir -Recurse -Force }
}
