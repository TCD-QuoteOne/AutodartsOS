#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PI_GEN_DIR="${PI_GEN_DIR:-}"
STAGE_NAME="stage2-autodarts-pi-os"
OLD_STAGE_NAME="stage6-autodarts-pi-os"

if [[ -z "$PI_GEN_DIR" ]]; then
  echo "PI_GEN_DIR must point to an existing pi-gen checkout." >&2
  exit 1
fi

if [[ ! -d "$PI_GEN_DIR" ]]; then
  echo "PI_GEN_DIR does not exist: $PI_GEN_DIR" >&2
  exit 1
fi

OLD_STAGE_DIR="$PI_GEN_DIR/$OLD_STAGE_NAME"
if [[ -d "$OLD_STAGE_DIR" ]]; then
  rm -rf "$OLD_STAGE_DIR"
fi

touch "$PI_GEN_DIR/stage2/SKIP_IMAGES"
for stage in stage3 stage4 stage5; do
  if [[ -d "$PI_GEN_DIR/$stage" ]]; then
    touch "$PI_GEN_DIR/$stage/SKIP" "$PI_GEN_DIR/$stage/SKIP_IMAGES"
  fi
done

STAGE_DIR="$PI_GEN_DIR/$STAGE_NAME"
mkdir -p "$STAGE_DIR/00-install/files"
mkdir -p "$STAGE_DIR/00-install/files/usr/share/autodarts-pi-os"

cp -R "$ROOT_DIR/image/overlays/." "$STAGE_DIR/00-install/files/"
cp "$ROOT_DIR/assets/boot/autodarts-pi-os-splash.png" "$STAGE_DIR/00-install/files/usr/share/autodarts-pi-os/splash.png"
rm -f "$STAGE_DIR/00-packages"
cp "$ROOT_DIR/image/packages" "$STAGE_DIR/00-install/00-packages"

cat > "$STAGE_DIR/prerun.sh" <<'SCRIPT'
#!/bin/bash -e
if [[ ! -d "${ROOTFS_DIR}" ]]; then
  copy_previous
fi
SCRIPT

cat > "$STAGE_DIR/EXPORT_IMAGE" <<'SCRIPT'
IMG_SUFFIX="-lite"
if [ "${USE_QEMU}" = "1" ]; then
  export IMG_SUFFIX="${IMG_SUFFIX}-qemu"
fi
SCRIPT

cat > "$STAGE_DIR/00-install/00-run.sh" <<'SCRIPT'
#!/bin/bash
set -e
install -d "${ROOTFS_DIR}/etc/systemd/system"
install -m 0644 files/etc/systemd/system/*.service "${ROOTFS_DIR}/etc/systemd/system/"
install -d "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants"
ln -sf ../autodarts-firstboot.service "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/autodarts-firstboot.service"
ln -sf ../autodarts-install.service "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/autodarts-install.service"
ln -sf ../autodarts-runtime.service "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/autodarts-runtime.service"
ln -sf ../autodarts-watchdog.service "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/autodarts-watchdog.service"
ln -sf ../autodarts-webpanel.service "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/autodarts-webpanel.service"
install -d "${ROOTFS_DIR}/etc/autodarts-pi-os"
install -m 0644 files/etc/autodarts-pi-os/config.toml "${ROOTFS_DIR}/etc/autodarts-pi-os/config.toml"
install -m 0644 files/etc/autodarts-pi-os/bash_profile "${ROOTFS_DIR}/etc/autodarts-pi-os/bash_profile"
install -d "${ROOTFS_DIR}/etc/systemd/system/getty@tty1.service.d"
install -m 0644 files/etc/systemd/system/getty@tty1.service.d/autodarts-autologin.conf "${ROOTFS_DIR}/etc/systemd/system/getty@tty1.service.d/autodarts-autologin.conf"
install -d "${ROOTFS_DIR}/usr/local/bin"
install -m 0755 files/usr/local/bin/* "${ROOTFS_DIR}/usr/local/bin/"
install -d "${ROOTFS_DIR}/usr/lib/sysusers.d"
install -m 0644 files/usr/lib/sysusers.d/autodarts-pi-os.conf "${ROOTFS_DIR}/usr/lib/sysusers.d/autodarts-pi-os.conf"
install -d "${ROOTFS_DIR}/usr/lib/tmpfiles.d"
install -m 0644 files/usr/lib/tmpfiles.d/autodarts-pi-os.conf "${ROOTFS_DIR}/usr/lib/tmpfiles.d/autodarts-pi-os.conf"
install -d "${ROOTFS_DIR}/usr/share/autodarts-pi-os"
install -m 0644 files/usr/share/autodarts-pi-os/splash.png "${ROOTFS_DIR}/usr/share/autodarts-pi-os/splash.png"
install -d "${ROOTFS_DIR}/usr/share/plymouth/themes/autodarts-pi-os"
install -m 0644 files/usr/share/plymouth/themes/autodarts-pi-os/* "${ROOTFS_DIR}/usr/share/plymouth/themes/autodarts-pi-os/"
install -m 0644 files/usr/share/autodarts-pi-os/splash.png "${ROOTFS_DIR}/usr/share/plymouth/themes/autodarts-pi-os/splash.png"
install -d "${ROOTFS_DIR}/etc/plymouth"
install -m 0644 files/etc/plymouth/plymouthd.conf "${ROOTFS_DIR}/etc/plymouth/plymouthd.conf"
install -d "${ROOTFS_DIR}/etc/lightdm/lightdm.conf.d"
install -m 0644 files/etc/lightdm/lightdm.conf.d/50-autodarts-autologin.conf "${ROOTFS_DIR}/etc/lightdm/lightdm.conf.d/50-autodarts-autologin.conf"
install -d "${ROOTFS_DIR}/home/autodarts"
install -m 0644 files/etc/autodarts-pi-os/bash_profile "${ROOTFS_DIR}/home/autodarts/.bash_profile"
chown 1000:1000 "${ROOTFS_DIR}/home/autodarts" "${ROOTFS_DIR}/home/autodarts/.bash_profile" || true
rm -f "${ROOTFS_DIR}/etc/xdg/autostart/piwiz.desktop"
SCRIPT

chmod +x "$STAGE_DIR/prerun.sh"
chmod +x "$STAGE_DIR/00-install/00-run.sh"
echo "Created pi-gen stage at $STAGE_DIR"
echo "Configured pi-gen to export only the Autodarts Pi OS Lite appliance image."
