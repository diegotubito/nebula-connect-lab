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
        Invoke-WebRequest -UseBasicParsing 'https://github.com/diegotubito/nebula-connect-lab/releases/download/h6-visit.1/visit.zip' -OutFile $zip
        if ((Get-FileHash -LiteralPath $zip).Hash -ine '58d6bcdd7e53f521ebc4312f079991a8a9896d87ec6b070c1b3983ddf6172789') { throw 'H6 package hash mismatch.' }
        Unblock-File -LiteralPath $zip
        $kit = Join-Path $dir 'kit'
        Expand-Archive -LiteralPath $zip -DestinationPath $kit
        $managed = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'NebulaConnectAdopted'
        $worker = 'runtime/connect-service/visit-worker.mjs'
        if ((Test-Path "$managed/$worker") -and (Get-FileHash "$managed/$worker").Hash -ieq '8552c345a99b150d01dfae7ffcdb10cdc38dc75fefd24de5b76fb1aec2402124') {
            if (Test-Path "$managed/updates/transaction.json") { throw 'Connect update recovery is pending. Wait for the scheduled checker before retrying.' }
            if ((Get-FileHash "$managed/runtime/connect-service/visit-worker.original.mjs").Hash -ine (Get-FileHash "$kit/$worker").Hash) { throw 'Baseline worker verification failed.' }
            Copy-Item "$managed/$worker" "$kit/$worker" -Force
        }
        $entry = (Get-Item -LiteralPath (Join-Path $kit 'visit.ps1')).FullName
        & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File $entry restore
        if ($LASTEXITCODE) { throw 'Visit operation did not complete. Read the preceding diagnostic.' }
    } finally { Remove-Item -LiteralPath $dir -Recurse -Force }
}
