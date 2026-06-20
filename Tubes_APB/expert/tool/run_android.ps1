param(
  [string]$AvdName = "Medium_Phone_API_36.1",
  [string]$DeviceId = "",
  [string]$DnsServer = "8.8.8.8,1.1.1.1",
  [int]$TimeoutSeconds = 180,
  [switch]$NoLaunchEmulator
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$AndroidSdk = Join-Path $env:LOCALAPPDATA "Android\sdk"
$Adb = Join-Path $AndroidSdk "platform-tools\adb.exe"
$Emulator = Join-Path $AndroidSdk "emulator\emulator.exe"
$Flutter = "C:\src\flutter\bin\flutter.bat"

if (-not (Test-Path -LiteralPath $Flutter)) {
  $Flutter = "flutter"
}

if (-not (Test-Path -LiteralPath $Adb)) {
  throw "adb.exe tidak ditemukan di $Adb"
}

if (-not (Test-Path -LiteralPath $Emulator)) {
  throw "emulator.exe tidak ditemukan di $Emulator"
}

function Get-ReadyAndroidDevices {
  $devices = @()
  $output = & $Adb devices
  foreach ($line in $output) {
    if ($line -match "^(\S+)\s+device$") {
      $devices += $Matches[1]
    }
  }
  return $devices
}

function Select-AndroidDevice {
  param([string[]]$Devices)

  if ($DeviceId) {
    return $DeviceId
  }

  $physicalDevice = @($Devices | Where-Object { $_ -notlike "emulator-*" } | Select-Object -First 1)
  if ($physicalDevice.Count -gt 0) {
    return $physicalDevice[0]
  }

  $emulatorDevice = @($Devices | Where-Object { $_ -like "emulator-*" } | Select-Object -First 1)
  if ($emulatorDevice.Count -gt 0) {
    return $emulatorDevice[0]
  }

  return "emulator-5554"
}

function Start-AndroidEmulator {
  $logDir = Join-Path $ProjectRoot "build\emulator"
  New-Item -ItemType Directory -Force -Path $logDir | Out-Null

  $stdoutLog = Join-Path $logDir "stdout.log"
  $stderrLog = Join-Path $logDir "stderr.log"

  Write-Host "Menyalakan emulator $AvdName..."
  Start-Process `
    -FilePath $Emulator `
    -ArgumentList @("-avd", $AvdName, "-dns-server", $DnsServer) `
    -RedirectStandardOutput $stdoutLog `
    -RedirectStandardError $stderrLog `
    -PassThru | Out-Null
}

function Wait-AndroidBoot {
  param([string]$TargetDevice)

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  Write-Host "Menunggu device $TargetDevice siap..."

  while ((Get-Date) -lt $deadline) {
    $devices = @(Get-ReadyAndroidDevices)
    if ($devices -contains $TargetDevice) {
      $bootCompleted = (& $Adb -s $TargetDevice shell getprop sys.boot_completed 2>$null).Trim()
      if ($bootCompleted -eq "1") {
        return
      }
    }

    Start-Sleep -Seconds 3
  }

  throw "Timeout menunggu $TargetDevice boot. Coba buka emulator dari Android Studio lalu jalankan script ini lagi."
}

Set-Location -LiteralPath $ProjectRoot

$readyDevices = @(Get-ReadyAndroidDevices)
$targetDevice = Select-AndroidDevice -Devices $readyDevices

if (($readyDevices -notcontains $targetDevice) -and (-not $NoLaunchEmulator)) {
  Start-AndroidEmulator
}

Wait-AndroidBoot -TargetDevice $targetDevice

Write-Host "Menjalankan Flutter di $targetDevice..."
& $Flutter --suppress-analytics run -d $targetDevice
