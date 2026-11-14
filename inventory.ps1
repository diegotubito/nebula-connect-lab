& {
    $ErrorActionPreference = 'Stop'
    if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64' -or ![Environment]::Is64BitProcess) { throw 'Windows x64 required.' }
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('NebulaH6Temp-' + [guid]::NewGuid())
    New-Item -ItemType Directory $dir -ErrorAction Stop | Out-Null
    try {
        $zip = Join-Path $dir 'rehearsal.zip'
        Invoke-WebRequest -UseBasicParsing 'https://github.com/diegotubito/nebula-connect-lab/releases/download/h6-accounts.2/inventory.zip' -OutFile $zip
        if ((Get-FileHash -LiteralPath $zip).Hash -ine 'a3d39d0247a800927d60d4d8960897e989d0cee176a0189b4d0261eade23f0b7') { throw 'H6 package hash mismatch.' }
        Unblock-File -LiteralPath $zip
        $kit = Join-Path $dir 'kit'
        Expand-Archive -LiteralPath $zip -DestinationPath $kit
        $entry = (Get-Item -LiteralPath (Join-Path $kit 'inspect.ps1')).FullName
        & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $entry
        if ($LASTEXITCODE) { throw 'Legacy inventory did not complete.' }
    } finally { Remove-Item -LiteralPath $dir -Recurse -Force }
}
