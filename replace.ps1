& {
$ErrorActionPreference = 'Stop'
$admin = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (!$admin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Open PowerShell as administrator.' }
if (![Environment]::Is64BitProcess -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64') { throw 'Use Windows x64 PowerShell.' }
$temp = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) ("NebulaReplaceTemp-" + [guid]::NewGuid())
New-Item -ItemType Directory $temp | Out-Null
try {
    $zip = Join-Path $temp 'windows.zip'
    Invoke-WebRequest -UseBasicParsing 'https://github.com/diegotubito/nebula-connect-lab/releases/download/replace.1/windows.zip' -OutFile $zip
    if ((Get-FileHash $zip).Hash -ine '28942b07107f74a4d514a88e2502217b3f666211965f0eee267e9f9bd2650398') { throw 'Package checksum mismatch.' }
    Expand-Archive -LiteralPath $zip -DestinationPath "$temp/kit"
    & "$env:SystemRoot/System32/WindowsPowerShell/v1.0/powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$temp/kit/windows.ps1"
    if ($LASTEXITCODE) { throw 'Replacement did not complete.' }
} finally { Remove-Item -LiteralPath $temp -Recurse -Force }
}
