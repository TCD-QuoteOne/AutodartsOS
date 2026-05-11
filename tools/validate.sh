#!/usr/bin/env bash
set -euo pipefail

required=(
  "README.md"
  "assets/boot/autodarts-pi-os-splash.png"
  "image/build.sh"
  "image/overlays/etc/autodarts-pi-os/config.toml"
  "image/overlays/etc/systemd/system/autodarts-firstboot.service"
  "image/overlays/etc/systemd/system/autodarts-install.service"
  "image/overlays/etc/systemd/system/autodarts-runtime.service"
  "image/overlays/etc/systemd/system/autodarts-watchdog.service"
  "image/overlays/etc/systemd/system/autodarts-webpanel.service"
  "image/overlays/etc/systemd/system/autodarts-kiosk.service"
  "image/overlays/usr/local/bin/autodarts-firstboot"
  "image/overlays/usr/local/bin/autodarts-install"
  "image/overlays/usr/local/bin/autodarts-runtime"
  "image/overlays/usr/local/bin/autodarts-watchdog"
  "image/overlays/usr/local/bin/autodarts-webpanel"
  "image/overlays/usr/local/bin/autodarts-kiosk"
  "image/overlays/usr/local/bin/autodarts-kiosk-session"
  "image/overlays/usr/share/plymouth/themes/autodarts-pi-os/autodarts-pi-os.plymouth"
  "image/overlays/usr/share/plymouth/themes/autodarts-pi-os/autodarts-pi-os.script"
  "image/overlays/etc/plymouth/plymouthd.conf"
  "image/overlays/usr/lib/sysusers.d/autodarts-pi-os.conf"
  "image/overlays/usr/lib/tmpfiles.d/autodarts-pi-os.conf"
  "image/packages"
)

for path in "${required[@]}"; do
  [[ -e "$path" ]] || { echo "Missing required file: $path" >&2; exit 1; }
done

size="$(wc -c < assets/boot/autodarts-pi-os-splash.png)"
if [[ "$size" -lt 100000 ]]; then
  echo "Splash image looks too small: $size bytes" >&2
  exit 1
fi

for unit in image/overlays/etc/systemd/system/*.service; do
  grep -q "^\[Unit\]" "$unit"
  grep -q "^\[Service\]" "$unit"
  grep -q "^\[Install\]" "$unit"
done

echo "Validation passed."
