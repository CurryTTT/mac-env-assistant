$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
dotnet run --project Tests/CoreTests.csproj -c Release
if ($LASTEXITCODE -ne 0) { throw 'Core tests failed' }
dotnet publish EnvAssistant.Windows.csproj -c Release -r win-x64 --self-contained true -o dist
if ($LASTEXITCODE -ne 0) { throw 'Windows build failed' }
$exeName = 'EnvAssistant-v0.1.0-Windows-x64.exe'
Copy-Item 'dist/EnvAssistant-Windows.exe' "dist/$exeName" -Force
$digest = (Get-FileHash "dist/$exeName" -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -Path 'dist/SHA256SUMS-windows-v0.1.0.txt' -Value "$digest  $exeName" -Encoding ascii
Write-Host "Built dist/$exeName"
