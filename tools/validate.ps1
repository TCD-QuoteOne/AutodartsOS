$ErrorActionPreference = "Stop"

$required = @(
  "README.md",
  "assets/boot/autodarts-pi-os-splash.png",
  "image/build.sh",
  "image/overlays/etc/autodarts-pi-os/config.toml",
  "image/overlays/etc/systemd/system/autodarts-firstboot.service",
  "image/overlays/etc/systemd/system/autodarts-bootctl.service",
  "image/overlays/etc/systemd/system/autodarts-install.service",
  "image/overlays/etc/systemd/system/autodarts-runtime.service",
  "image/overlays/etc/systemd/system/autodarts-watchdog.service",
  "image/overlays/etc/systemd/system/autodarts-webpanel.service",
  "image/overlays/etc/systemd/system/autodarts-network.service",
  "image/overlays/etc/systemd/system/autodarts-kiosk.service",
  "image/overlays/etc/systemd/system/getty@tty1.service.d/autodarts-autologin.conf",
  "image/overlays/etc/autodarts-pi-os/bash_profile",
  "image/overlays/usr/local/bin/autodarts-firstboot",
  "image/overlays/usr/local/bin/autodarts-bootctl",
  "image/overlays/usr/local/bin/autodarts-install",
  "image/overlays/usr/local/bin/autodarts-runtime",
  "image/overlays/usr/local/bin/autodarts-watchdog",
  "image/overlays/usr/local/bin/autodarts-webpanel",
  "image/overlays/usr/local/bin/autodarts-network",
  "image/overlays/usr/local/bin/autodarts-kiosk",
  "image/overlays/usr/local/bin/autodarts-kiosk-session",
  "image/overlays/usr/share/plymouth/themes/autodarts-pi-os/autodarts-pi-os.plymouth",
  "image/overlays/usr/share/plymouth/themes/autodarts-pi-os/autodarts-pi-os.script",
  "image/overlays/etc/plymouth/plymouthd.conf",
  "image/overlays/etc/lightdm/lightdm.conf.d/50-autodarts-autologin.conf",
  "image/overlays/etc/NetworkManager/dnsmasq-shared.d/autodarts-setup.conf",
  "image/overlays/etc/NetworkManager/dnsmasq.d/autodarts-setup.conf",
  "image/overlays/usr/lib/sysusers.d/autodarts-pi-os.conf",
  "image/overlays/usr/lib/tmpfiles.d/autodarts-pi-os.conf",
  "image/packages",
  "image/pi-gen-config.example"
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
