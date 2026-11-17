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
        Invoke-WebRequest -UseBasicParsing 'https://github.com/diegotubito/nebula-connect-lab/releases/download/adopted-lab.1/update-lab.zip' -OutFile $zip
        if ((Get-FileHash -LiteralPath $zip).Hash -ine '6c20c19a4440d1d955c9949093d5628ca8d0a9e8dd074c26735157b630ca4392') { throw 'Update manager checksum mismatch.' }
        Unblock-File -LiteralPath $zip
        $kit = Join-Path $dir 'kit'
        Expand-Archive -LiteralPath $zip -DestinationPath $kit
        $entry = (Get-Item -LiteralPath (Join-Path $kit 'native.ps1')).FullName
        & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File $entry
        if ($LASTEXITCODE) { throw 'Update rehearsal failed. Read the preceding diagnostic.' }
    } finally { Remove-Item -LiteralPath $dir -Recurse -Force }
}
