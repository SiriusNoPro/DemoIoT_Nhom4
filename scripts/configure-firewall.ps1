# Run this script from an Administrator PowerShell terminal.
$ErrorActionPreference = 'Stop'
$rules = @(
    @{ Name = 'EcoSense-MQTT-1884'; Port = 1884 },
    @{ Name = 'EcoSense-API-8080'; Port = 8080 }
)
foreach ($rule in $rules) {
    if (-not (Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName $rule.Name -Direction Inbound -Action Allow `
            -Protocol TCP -LocalPort $rule.Port -Profile Private | Out-Null
        Write-Host "Created $($rule.Name)"
    } else {
        Write-Host "Exists $($rule.Name)"
    }
}
