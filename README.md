# Autodarts Pi OS

![Autodarts Pi OS boot splash](assets/boot/autodarts-pi-os-splash.png)

Autodarts Pi OS ist ein Open-Source-Projekt für ein Raspberry-Pi-OS-Lite-basiertes Appliance-Image, das ein Autodarts-Setup möglichst direkt nach dem Flashen startklar macht.

Ziel ist kein einmalig manuell eingerichteter Pi, sondern ein reproduzierbares System:

- eigener Boot-Screen mit Autodarts-Pi-OS-Splash
- Kiosk-Ausgabe auf angeschlossenem Monitor mit `https://play.autodarts.io`
- automatische Autodarts-Installation beim ersten Boot über den offiziellen Installer
- lokaler Setup-Hub beim ersten Start statt Raspberry-Pi-OS-Userdialog
- Konsolen-Autologin auf `tty1`, das den Kiosk im Lite-Image startet
- `systemd`-Services für First Boot, Runtime, Watchdog und Webpanel
- lokale Konfiguration über einfache TOML-Dateien
- Hardwareprofile für Raspberry Pi 4/5 mit USB-Kamera
- Image-Overlay für `pi-gen`
- Validierungsskripte für schnelle Smoke-Tests

## Status

Das Projekt ist aktuell eine erste, saubere Grundlage. Es enthält noch kein final gebautes Raspberry-Pi-Image und installiert noch nicht automatisch die eigentliche Autodarts-Anwendung. Der nächste technische Schritt ist ein echter `pi-gen`-Build unter Linux oder WSL.

## Schnellstart Für Entwickler

### 1. Repository prüfen

Unter Windows/PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\validate.ps1
```

Unter Linux/WSL:

```bash
./tools/validate.sh
```

### 2. pi-gen vorbereiten

`pi-gen` muss auf einem Linux-Host oder in WSL vorhanden sein:

```bash
git clone https://github.com/RPi-Distro/pi-gen.git
export PI_GEN_DIR="$PWD/pi-gen"
```

### 3. Autodarts-Pi-OS-Stage erzeugen

Im Autodarts-Pi-OS-Repository:

```bash
./image/build.sh
```

Das Skript legt in `pi-gen` eine zusätzliche Stage namens `stage2-autodarts-pi-os` an. Sie baut direkt auf Raspberry Pi OS Lite auf, kopiert Services, Konfiguration, Webpanel und Boot-Screen in das Root-Dateisystem-Overlay und exportiert nur das Autodarts-Pi-OS-Lite-Appliance-Image.

### 4. pi-gen konfigurieren

```bash
cp /opt/AutodartsOS/image/pi-gen-config.example /opt/pi-gen/config
```

Die Beispielkonfiguration setzt einen temporären Appliance-User:

```text
FIRST_USER_NAME=autodarts
FIRST_USER_PASS=autodarts
DISABLE_FIRST_BOOT_USER_RENAME=1
```

Der Linux-Nutzer ist ein interner Appliance-User. Die eigentliche Einrichtung laeuft nicht ueber den Linux-Login, sondern ueber die lokale Weboberflaeche unter `http://autodarts-pi.local:8080` oder `http://<pi-ip>:8080`.

Die Beispielkonfiguration begrenzt den Build auf:

```text
STAGE_LIST="stage0 stage1 stage2 stage2-autodarts-pi-os"
```

Dadurch werden keine normalen Desktop- oder Full-Images erzeugt.

### 5. Image bauen

Danach wird der eigentliche Image-Build wie üblich über `pi-gen` ausgeführt. Die genaue `pi-gen`-Konfiguration wird im nächsten Projektschritt festgezurrt.

## Geplanter Out-of-the-box-Ablauf

1. Image auf microSD oder SSD flashen.
2. Optional `autodarts-config.toml` auf die Boot-Partition legen.
3. Raspberry Pi starten.
4. First-Boot-Service übernimmt Hostname und Grundkonfiguration.
5. Runtime-, Watchdog- und Webpanel-Service starten automatisch.
6. Webpanel ist lokal auf Port `8080` erreichbar.

Beispiel für eine spätere Boot-Seed-Konfiguration:

```toml
hostname = "autodarts-pi"
mode = "webpanel"
profile = "pi5-usb-camera"
autodarts_command = "/usr/local/bin/autodarts-runtime"
autodarts_install_enabled = true
autodarts_version = "latest"
autodarts_installer_url = "https://get.autodarts.io"
webpanel_port = 8080
setup_mode = true
setup_admin_user = "admin"
setup_admin_password = "autodarts"
setup_url = "http://localhost:8080/setup"
kiosk_enabled = true
play_url = "https://play.autodarts.io"
kiosk_url = "https://play.autodarts.io"
```

## Projektstruktur

```text
assets/        Boot screen and visual assets
docs/          Architecture, install, hardware, and development notes
image/         pi-gen stage and root filesystem overlay
profiles/     Hardware profile defaults
services/     Source service unit files mirrored into image overlays
tools/         Local helper and validation scripts
webpanel/      Minimal local web panel implementation
```

## Wichtige Pfade

- Boot-Splash: `assets/boot/autodarts-pi-os-splash.png`
- Default-Konfiguration: `image/overlays/etc/autodarts-pi-os/config.toml`
- Services: `image/overlays/etc/systemd/system/`
- Runtime-Skripte: `image/overlays/usr/local/bin/`
- Autodarts-Installer: `image/overlays/usr/local/bin/autodarts-install`
- Plymouth-Theme: `image/overlays/usr/share/plymouth/themes/autodarts-pi-os/`
- Kiosk-Service: `image/overlays/etc/systemd/system/autodarts-kiosk.service`

## Rechtlicher Hinweis Zum Namen

`Autodarts Pi OS` ist als beschreibender Projektname für ein Raspberry-Pi-Image gedacht, das für Autodarts-Setups gebaut wird. Vor einer öffentlichen Release-Kommunikation sollte die Branding- oder Trademark-Situation mit dem Autodarts-Projekt geklärt werden. Bis dahin ist eine Formulierung wie „unofficial Raspberry Pi OS image for Autodarts“ am sichersten.

## Lizenz

Dieses Projekt steht unter der Apache-2.0-Lizenz. Siehe [LICENSE](LICENSE).

## Weitere Dokumentation

- [Architektur](docs/architecture.md)
- [Installation](docs/install.md)
- [Hardware](docs/hardware.md)
- [Entwicklung](docs/development.md)
