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
        Invoke-WebRequest -UseBasicParsing 'https://github.com/diegotubito/nebula-connect-lab/releases/download/h6-accounts.1/accounts.zip' -OutFile $zip
        if ((Get-FileHash -LiteralPath $zip).Hash -ine 'b141226230638c3b934c7dbefc2e3ccfa5f5788d1aa8e050697315e081afe5f2') { throw 'H6 package hash mismatch.' }
        Unblock-File -LiteralPath $zip
        Expand-Archive -LiteralPath $zip -DestinationPath "$dir/kit"
        & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$dir/kit/lab.ps1"
        if ($LASTEXITCODE) { throw 'Windows rehearsal did not complete.' }
    } finally { Remove-Item -LiteralPath $dir -Recurse -Force }
    Write-Output 'H6 ACCOUNTS OK | distinct accounts | service verified | legacy verified | fixture removed'
}
