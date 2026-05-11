#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PI_GEN_DIR="${PI_GEN_DIR:-}"
STAGE_NAME="stage6-autodarts-pi-os"

if [[ -z "$PI_GEN_DIR" ]]; then
  echo "PI_GEN_DIR must point to an existing pi-gen checkout." >&2
  exit 1
fi

if [[ ! -d "$PI_GEN_DIR" ]]; then
  echo "PI_GEN_DIR does not exist: $PI_GEN_DIR" >&2
  exit 1
fi

STAGE_DIR="$PI_GEN_DIR/$STAGE_NAME"
mkdir -p "$STAGE_DIR/00-install/files"
mkdir -p "$STAGE_DIR/00-install/files/usr/share/autodarts-pi-os"

cp -R "$ROOT_DIR/image/overlays/." "$STAGE_DIR/00-install/files/"
cp "$ROOT_DIR/assets/boot/autodarts-pi-os-splash.png" "$STAGE_DIR/00-install/files/usr/share/autodarts-pi-os/splash.png"
cp "$ROOT_DIR/image/packages" "$STAGE_DIR/00-packages"

cat > "$STAGE_DIR/00-install/00-run.sh" <<'SCRIPT'
#!/bin/bash
set -e
install -d "${ROOTFS_DIR}/etc/systemd/system"
install -m 0644 files/etc/systemd/system/*.service "${ROOTFS_DIR}/etc/systemd/system/"
install -d "${ROOTFS_DIR}/etc/autodarts-pi-os"
install -m 0644 files/etc/autodarts-pi-os/config.toml "${ROOTFS_DIR}/etc/autodarts-pi-os/config.toml"
install -d "${ROOTFS_DIR}/usr/local/bin"
install -m 0755 files/usr/local/bin/* "${ROOTFS_DIR}/usr/local/bin/"
install -d "${ROOTFS_DIR}/usr/share/autodarts-pi-os"
install -m 0644 files/usr/share/autodarts-pi-os/splash.png "${ROOTFS_DIR}/usr/share/autodarts-pi-os/splash.png"
install -d "${ROOTFS_DIR}/usr/share/plymouth/themes/autodarts-pi-os"
install -m 0644 files/usr/share/plymouth/themes/autodarts-pi-os/* "${ROOTFS_DIR}/usr/share/plymouth/themes/autodarts-pi-os/"
install -m 0644 files/usr/share/autodarts-pi-os/splash.png "${ROOTFS_DIR}/usr/share/plymouth/themes/autodarts-pi-os/splash.png"
install -d "${ROOTFS_DIR}/proc" "${ROOTFS_DIR}/sys" "${ROOTFS_DIR}/dev" "${ROOTFS_DIR}/run"
on_chroot <<'CHROOT'
id autodarts >/dev/null 2>&1 || useradd --system --create-home --groups video,input,render,gpio autodarts
plymouth-set-default-theme autodarts-pi-os || true
systemctl enable autodarts-firstboot.service
systemctl enable autodarts-runtime.service
systemctl enable autodarts-watchdog.service
systemctl enable autodarts-webpanel.service
CHROOT
SCRIPT

chmod +x "$STAGE_DIR/00-install/00-run.sh"
echo "Created pi-gen stage at $STAGE_DIR"
