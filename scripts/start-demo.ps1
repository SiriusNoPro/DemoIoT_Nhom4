$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

docker compose up -d
if ($LASTEXITCODE -ne 0) { throw 'Docker Compose startup failed.' }

Write-Host ''
docker compose ps
Write-Host ''
Write-Host 'EcoSense demo is ready:' -ForegroundColor Green
Write-Host '  Web:     http://localhost:3000'
Write-Host '  Swagger: http://localhost:8080/swagger-ui/index.html'
Write-Host '  EMQX:    http://localhost:18084 (admin / public)'
Write-Host '  Login:   operator / Operator@123'
Write-Host ''
Write-Host 'Smoke test: powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\smoke-test.ps1'
