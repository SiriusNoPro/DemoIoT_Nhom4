$ErrorActionPreference = 'Stop'
$baseUrl = 'http://127.0.0.1:8080/api/v1'

function Login($username, $password) {
    $body = @{ username = $username; password = $password } | ConvertTo-Json
    return Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method Post -ContentType 'application/json' -Body $body
}

function Get-CommandStatus($headers, $id) {
    $response = Invoke-RestMethod -Uri "$baseUrl/devices/esp32-001/commands?size=10" -Headers $headers
    return $response.content | Where-Object { $_.id -eq $id } | Select-Object -First 1
}

$operator = Login 'operator' 'Operator@123'
$operatorHeaders = @{ Authorization = "Bearer $($operator.accessToken)" }
$device = Invoke-RestMethod -Uri "$baseUrl/devices/esp32-001" -Headers $operatorHeaders
$latest = Invoke-RestMethod -Uri "$baseUrl/devices/esp32-001/telemetry/latest" -Headers $operatorHeaders
if ($device.status -ne 'ONLINE' -or $null -eq $latest.temperature -or $null -eq $latest.humidity -or
    $null -eq $latest.soilMoisture -or $null -eq $latest.illuminance) {
    throw 'Device telemetry for temperature, humidity, soil moisture, light, or ONLINE status is missing.'
}
if ($latest.illuminance -notin @(80, 255)) {
    throw "Light level must be 80 (dark) or 255 (bright), got $($latest.illuminance)."
}

foreach ($action in @('LED_ON', 'LED_OFF')) {
    $body = @{ action = $action } | ConvertTo-Json
    $sent = Invoke-RestMethod -Uri "$baseUrl/devices/esp32-001/commands" -Method Post -Headers $operatorHeaders -ContentType 'application/json' -Body $body
    $ack = $null
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        Start-Sleep -Seconds 1
        $ack = Get-CommandStatus $operatorHeaders $sent.id
        if ($ack.status -eq 'ACKNOWLEDGED') { break }
    }
    if ($ack.status -ne 'ACKNOWLEDGED') { throw "No ACK for $action ($($sent.id))." }
    $device = Invoke-RestMethod -Uri "$baseUrl/devices/esp32-001" -Headers $operatorHeaders
    if ($device.ledState -ne ($action -eq 'LED_ON')) { throw "Device LED state did not follow $action." }
}

foreach ($action in @('BUZZER_ON', 'BUZZER_OFF')) {
    $body = @{ action = $action } | ConvertTo-Json
    $sent = Invoke-RestMethod -Uri "$baseUrl/devices/esp32-001/commands" -Method Post -Headers $operatorHeaders -ContentType 'application/json' -Body $body
    $ack = $null
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        Start-Sleep -Seconds 1
        $ack = Get-CommandStatus $operatorHeaders $sent.id
        if ($ack.status -eq 'ACKNOWLEDGED') { break }
    }
    if ($ack.status -ne 'ACKNOWLEDGED') { throw "No ACK for $action ($($sent.id))." }
    $device = Invoke-RestMethod -Uri "$baseUrl/devices/esp32-001" -Headers $operatorHeaders
    if ($device.buzzerState -ne ($action -eq 'BUZZER_ON')) { throw "Device buzzer state did not follow $action." }
}

$viewer = Login 'viewer' 'Viewer@123'
$viewerHeaders = @{ Authorization = "Bearer $($viewer.accessToken)" }
$viewerRejected = $false
try {
    Invoke-RestMethod -Uri "$baseUrl/devices/esp32-001/commands" -Method Post -Headers $viewerHeaders -ContentType 'application/json' -Body '{"action":"LED_ON"}' | Out-Null
} catch {
    $viewerRejected = [int]$_.Exception.Response.StatusCode -eq 403
}
if (-not $viewerRejected) { throw 'Viewer command was not rejected with HTTP 403.' }

$web = Invoke-WebRequest -Uri 'http://127.0.0.1:3000/' -UseBasicParsing
$logs = Invoke-WebRequest -Uri 'http://127.0.0.1:3000/logs' -UseBasicParsing
if ($web.StatusCode -ne 200 -or $logs.StatusCode -ne 200 -or $web.Content -notmatch 'EcoSense') {
    throw 'Web page or SPA history route is unavailable.'
}

[pscustomobject]@{
    Device = $device.deviceId
    Status = $device.status
    Temperature = $latest.temperature
    Humidity = $latest.humidity
    SoilMoisture = $latest.soilMoisture
    LightLevel = $latest.illuminance
    LedAfterTest = $device.ledState
    LedOnAck = 'ACKNOWLEDGED'
    LedOffAck = 'ACKNOWLEDGED'
    BuzzerOnAck = 'ACKNOWLEDGED'
    BuzzerOffAck = 'ACKNOWLEDGED'
    ViewerCommand = 'HTTP 403'
    Web = 'HTTP 200'
    HistoryRoute = 'HTTP 200'
} | Format-List
