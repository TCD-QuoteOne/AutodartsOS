$ErrorActionPreference = "Stop"

$required = @(
  "README.md",
  "assets/boot/autodarts-pi-os-splash.png",
  "image/build.sh",
  "image/overlays/etc/autodarts-pi-os/config.toml",
  "image/overlays/etc/systemd/system/autodarts-firstboot.service",
  "image/overlays/etc/systemd/system/autodarts-runtime.service",
  "image/overlays/etc/systemd/system/autodarts-watchdog.service",
  "image/overlays/etc/systemd/system/autodarts-webpanel.service",
  "image/overlays/usr/local/bin/autodarts-firstboot",
  "image/overlays/usr/local/bin/autodarts-runtime",
  "image/overlays/usr/local/bin/autodarts-watchdog",
  "image/overlays/usr/local/bin/autodarts-webpanel",
  "image/overlays/usr/share/plymouth/themes/autodarts-pi-os/autodarts-pi-os.plymouth",
  "image/overlays/usr/share/plymouth/themes/autodarts-pi-os/autodarts-pi-os.script",
  "image/packages"
)

foreach ($path in $required) {
  if (!(Test-Path -LiteralPath $path)) {
    throw "Missing required file: $path"
  }
}

$image = Get-Item -LiteralPath "assets/boot/autodarts-pi-os-splash.png"
if ($image.Length -lt 100000) {
  throw "Splash image looks too small: $($image.Length) bytes"
}

Get-ChildItem -Path "image/overlays/etc/systemd/system" -Filter "*.service" | ForEach-Object {
  $content = Get-Content -LiteralPath $_.FullName -Raw
  foreach ($section in @("[Unit]", "[Service]", "[Install]")) {
    if ($content -notlike "*$section*") {
      throw "Service file $($_.Name) is missing $section"
    }
  }
}

Write-Host "Validation passed."
