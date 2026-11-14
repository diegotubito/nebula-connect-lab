& {
    $ErrorActionPreference = 'Stop'
    if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64' -or ![Environment]::Is64BitProcess) { throw 'Windows x64 required.' }
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Open PowerShell as administrator.' }
    $dir = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) ('NebulaH6Temp-' + [guid]::NewGuid())
    New-Item -ItemType Directory $dir -ErrorAction Stop | Out-Null
    try {
        $zip = Join-Path $dir 'rehearsal.zip'
        Invoke-WebRequest -UseBasicParsing 'https://github.com/diegotubito/nebula-connect-lab/releases/download/h6-crash.1/crash.zip' -OutFile $zip
        if ((Get-FileHash -LiteralPath $zip).Hash -ine '883401cc01f6a317e659209f7d44f214feeb874e4c4f786b3ff2112279f799b6') { throw 'H6 package hash mismatch.' }
        Unblock-File -LiteralPath $zip
        Expand-Archive -LiteralPath $zip -DestinationPath "$dir/kit"
        & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$dir/kit/lab.ps1" -Crash
        if ($LASTEXITCODE) { throw 'Windows rehearsal did not complete.' }
    } finally { Remove-Item -LiteralPath $dir -Recurse -Force }
}
