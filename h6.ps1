& {
    $ErrorActionPreference = 'Stop'
    if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64' -or ![Environment]::Is64BitProcess) { throw 'Windows x64 required.' }
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Open PowerShell as administrator.' }
    $dir = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) ('NebulaH6Temp-' + [guid]::NewGuid())
    New-Item -ItemType Directory $dir -ErrorAction Stop | Out-Null
    try {
        $zip = Join-Path $dir 'rehearsal.zip'
        Invoke-WebRequest -UseBasicParsing 'https://github.com/diegotubito/nebula-connect-lab/releases/download/h6-lab.1/rehearsal.zip' -OutFile $zip
        if ((Get-FileHash -LiteralPath $zip).Hash -ine '0d3419824d6e2f17e4befb1c675cea33cef5a9ba1541113f4f9067901a6f0461') { throw 'H6 package hash mismatch.' }
        Unblock-File -LiteralPath $zip
        Expand-Archive -LiteralPath $zip -DestinationPath "$dir/kit"
        & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$dir/kit/lab.ps1"
        if ($LASTEXITCODE) { throw 'Windows rehearsal did not complete.' }
    } finally { Remove-Item -LiteralPath $dir -Recurse -Force }
}
