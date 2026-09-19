$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

Push-Location $root
try {
    docker compose down
} finally {
    Pop-Location
}

$adb = 'D:\Android\Sdk\platform-tools\adb.exe'
if (Test-Path -LiteralPath $adb) {
    $devices = & $adb devices
    foreach ($line in $devices) {
        if ($line -match '^(emulator-\d+)\s+device$') {
            & $adb -s $Matches[1] emu kill | Out-Null
        }
    }
}

Write-Host 'Docker demo and Android emulator stopped.'
