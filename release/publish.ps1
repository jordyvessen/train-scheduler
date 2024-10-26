
param (
    [string]$publishDir,
    [string]$modName = "train_scheduler_0.1.0"
)

if (-not (Test-Path $publishDir)) {
    Write-Host "Directory $publishDir does not exist" -ForegroundColor Red
    exit 1
}

Write-Host "Publishing to $publishDir" -ForegroundColor Green

Compress-Archive -Path "..\src" -DestinationPath "$modName.zip" -Force
Copy-Item -Path "$modName.zip" -Destination $publishDir