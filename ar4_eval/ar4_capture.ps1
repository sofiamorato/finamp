# Uso: .\ar4_capture.ps1 -Variant before|after -Scenario S3|S4|S5 -Run 1
param(
  [Parameter(Mandatory)][ValidateSet('before','after')][string]$Variant,
  [Parameter(Mandatory)][ValidateSet('S3','S4','S5')][string]$Scenario,
  [Parameter(Mandatory)][int]$Run
)
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$dir = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Force $dir | Out-Null
$out = Join-Path $dir "${Variant}_${Scenario}_r${Run}.txt"
& $adb logcat -c
Write-Host "Grabando $out. Haz el escenario en el telefono y presiona ENTER al terminar."
$job = Start-Job { param($a) & $a logcat -v raw -s flutter } -ArgumentList $adb
[void][Console]::ReadLine()
Start-Sleep -Seconds 1
Receive-Job $job | Where-Object { $_ -match '\[AR4\]' } | Set-Content -Encoding utf8 $out
Stop-Job $job; Remove-Job $job
Write-Host "Listo: $((Get-Content $out | Measure-Object -Line).Lines) lineas AR4 en $out"
