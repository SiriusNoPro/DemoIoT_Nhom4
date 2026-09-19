param(
    [switch]$FlashEsp32,
    [string]$Port = 'COM3',
    [string]$Emulator = 'Pixel_7'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$firmware = Join-Path $root 'esp32-firmware'
$mobile = Join-Path $root 'mobile-flutter'
$adb = 'D:\Android\Sdk\platform-tools\adb.exe'

Push-Location $root
try {
    Write-Host 'Resetting Docker services...'
    docker compose down
    docker compose up -d postgres emqx backend web

    Write-Host 'Waiting for backend...'
    $backendReady = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:8080/swagger-ui/index.html' -TimeoutSec 2
            if ($response.StatusCode -eq 200) { $backendReady = $true; break }
        } catch {}
        Start-Sleep -Seconds 2
    }
    if (-not $backendReady) { throw 'Backend did not become ready.' }

    if ($FlashEsp32) {
        Write-Host "Building and flashing ESP32-S3 on $Port..."
        Push-Location $firmware
        try {
            & 'C:\Windows\system32\cmd.exe' /c "call C:\esp\v5.5.5\esp-idf\export.bat && idf.py -p $Port build flash"
            if ($LASTEXITCODE -ne 0) { throw 'ESP32 build or flash failed.' }
        } finally {
            Pop-Location
        }
    }

    Write-Host 'Opening web dashboard...'
    Start-Process -FilePath 'http://localhost:3000'

    if (-not (Test-Path -LiteralPath $adb)) { throw "ADB was not found at $adb" }
    $deviceLines = & $adb devices
    if (-not ($deviceLines -match '^emulator-\d+\s+device$')) {
        Write-Host "Starting Android emulator $Emulator..."
        Push-Location $mobile
        try { flutter emulators --launch $Emulator } finally { Pop-Location }
    }

    Write-Host 'Waiting for Android...'
    $androidReady = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        $serial = (& $adb devices | Select-String '^emulator-\d+\s+device$' | Select-Object -First 1).Line
        if ($serial) {
            $deviceId = ($serial -split '\s+')[0]
            $booted = & $adb -s $deviceId shell getprop sys.boot_completed 2>$null
            if ($booted.Trim() -eq '1') { $androidReady = $true; break }
        }
        Start-Sleep -Seconds 2
    }
    if (-not $androidReady) { throw 'Android emulator did not become ready.' }

    Write-Host "Installing and opening EcoSense on $deviceId..."
    Push-Location $mobile
    try {
        flutter pub get
        flutter run -d $deviceId --release --no-resident
        if ($LASTEXITCODE -ne 0) { throw 'Flutter launch failed.' }
    } finally {
        Pop-Location
    }

    docker compose ps
    Write-Host ''
    Write-Host 'Demo ready: http://localhost:3000'
    Write-Host 'Login: operator / Operator@123'
    Write-Host 'Simulator remains stopped; ESP32 is the device source.'
} finally {
    Pop-Location
}
