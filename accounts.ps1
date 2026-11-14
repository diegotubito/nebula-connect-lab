& {
    $ErrorActionPreference = 'Stop'
    if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64' -or ![Environment]::Is64BitProcess) { throw 'Windows x64 required.' }
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Open PowerShell as administrator.' }
    $dir = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) ('NebulaH6Temp-' + [guid]::NewGuid())
    New-Item -ItemType Directory $dir -ErrorAction Stop | Out-Null
    try {
        & "$env:SystemRoot/System32/icacls.exe" $dir /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-11:(OI)(CI)RX' | Out-Null
        if ($LASTEXITCODE) { throw 'Could not secure rehearsal directory.' }
        $zip = Join-Path $dir 'rehearsal.zip'
        Invoke-WebRequest -UseBasicParsing 'https://github.com/diegotubito/nebula-connect-lab/releases/download/h6-accounts.3/accounts.zip' -OutFile $zip
        if ((Get-FileHash -LiteralPath $zip).Hash -ine '9949d0067f49bdeffd71f88a90c8f5fd28b5a0f1e3363f666f68ed8f8bbe15a7') { throw 'H6 package hash mismatch.' }
        Unblock-File -LiteralPath $zip
        $kit = Join-Path $dir 'kit'
        Expand-Archive -LiteralPath $zip -DestinationPath $kit
        $entry = (Get-Item -LiteralPath (Join-Path $kit 'lab.ps1')).FullName
        & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $entry
        if ($LASTEXITCODE) { throw 'Windows rehearsal did not complete.' }
    } finally { Remove-Item -LiteralPath $dir -Recurse -Force }
    Write-Output 'H6 ACCOUNTS OK | distinct accounts | service verified | legacy verified | fixture removed'
}
