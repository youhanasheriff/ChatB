param([Parameter(Mandatory)][string]$Installer, [Parameter(Mandatory)][string]$Manifest)
$ErrorActionPreference = 'Stop'
$installerPath = (Resolve-Path $Installer).Path
$manifestData = Get-Content $Manifest -Raw | ConvertFrom-Json
$installed = Join-Path $env:LOCALAPPDATA 'Programs\BitChat Desktop'
$shortcut = Join-Path ([Environment]::GetFolderPath('Programs')) 'BitChat Desktop.lnk'
$registry = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{A82FAE51-8DBC-4A5E-A951-0FEC42482B18}_is1'
# Only run on an isolated CI runner: never replace someone's existing install.
if ((Test-Path $installed) -or (Test-Path $registry) -or (Test-Path $shortcut)) { throw 'Installation already exists; use a clean test runner' }
function Run-Checked([string]$Executable, [string[]]$Arguments) {
    $process = Start-Process -FilePath $Executable -ArgumentList $Arguments -PassThru
    if (-not $process.WaitForExit(60000)) { $process.Kill(); throw "Process timed out: $Executable" }
    if ($process.ExitCode -ne 0) { throw "Exit $($process.ExitCode): $Executable" }
}
try {
    # The same AppId must reinstall in place, without duplicate Apps entries.
    foreach ($pass in 1..2) {
        Run-Checked $installerPath @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-')
        foreach ($property in $manifestData.binaries.PSObject.Properties) {
            $hash = (Get-FileHash (Join-Path $installed $property.Name) -Algorithm SHA256).Hash.ToLower()
            if ($hash -ne $property.Value.sha256) { throw "Installed binary differs: $($property.Name)" }
        }
        if (-not (Test-Path $registry)) { throw 'Missing Installed apps registration' }
        if (-not (Test-Path $shortcut)) { throw 'Missing Start menu shortcut' }
        $entry = Get-ItemProperty $registry
        if ($entry.DisplayVersion -ne $manifestData.version) { throw 'Incorrect registered version' }
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($shortcut)
        if ($link.TargetPath -ne (Join-Path $installed 'bitchat-desktop-windows.exe')) { throw 'Shortcut points to wrong executable' }
        if (-not (Test-Path (Join-Path $installed 'THIRD-PARTY-NOTICES.txt'))) { throw 'Notices not installed' }
        Run-Checked (Join-Path $installed 'bitchat-desktop-windows.exe') @('--smoke-test')
        Run-Checked (Join-Path $installed 'bitchat-scan.exe') @('--version')
        Write-Host "Install/reinstall pass $pass verified"
    }
} finally {
    $uninstall = Join-Path $installed 'unins000.exe'
    if (Test-Path $uninstall) { Run-Checked $uninstall @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART') }
}
# Inno's temporary uninstaller may complete final cleanup after the process exits.
$deadline = [DateTime]::UtcNow.AddSeconds(15)
while ((Test-Path $installed) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 200 }
foreach ($path in @($installed,$registry,$shortcut)) {
    if (Test-Path $path) { throw "Uninstall left behind: $path" }
}
Write-Host 'Installed bytes, launch, Start menu, registration, reinstall and uninstall verified.'
$global:LASTEXITCODE = 0
