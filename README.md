# Autodarts Pi OS

![Autodarts Pi OS boot splash](assets/boot/autodarts-pi-os-splash.png)

Autodarts Pi OS ist ein Open-Source-Projekt für ein Raspberry-Pi-OS-Lite-basiertes Appliance-Image, das ein Autodarts-Setup möglichst direkt nach dem Flashen startklar macht.

Ziel ist kein einmalig manuell eingerichteter Pi, sondern ein reproduzierbares System:

- eigener Boot-Screen mit Autodarts-Pi-OS-Splash
- Kiosk-Ausgabe auf angeschlossenem Monitor mit lokalem Autodarts-Status und Weiterleitung zum Autodarts-Konfigurationsmodus
- automatische Autodarts-Installation beim ersten Boot über den offiziellen Installer
- lokaler Setup-Hub beim ersten Start statt Raspberry-Pi-OS-Userdialog
- Setup-Hotspot `Autodarts-Setup` mit `http://auto.setup.go`
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

Der Linux-Nutzer ist ein interner Appliance-User. Die eigentliche Einrichtung laeuft nicht ueber den Linux-Login, sondern ueber die lokale Weboberflaeche. Im Setup-Hotspot ist sie unter `http://auto.setup.go` erreichbar. Im normalen Netzwerk ist sie unter `http://autodarts-pi.local` oder `http://<pi-ip>` erreichbar.

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
5. Runtime-, Watchdog-, Network- und Webpanel-Service starten automatisch.
6. Wenn kein Ethernet und kein funktionierendes WLAN verbunden ist, startet der Setup-Hotspot.

## Setup-Ablauf Für Nutzer

### Vorab: Raspberry Pi Imager

Autodarts Pi OS ist mit den normalen Raspberry-Pi-Imager-Anpassungen kompatibel. Du kannst im Imager also bereits WLAN, Hostname und SSH hinterlegen. Beim ersten Boot uebernimmt Raspberry Pi OS diese Werte wie beim Standard-Image. Autodarts Pi OS fuehrt eine vorhandene Imager-`firstrun.sh` notfalls selbst aus, aktiviert SSH bei vorhandener `ssh`/`ssh.txt`-Bootdatei und erkennt anschliessend eine funktionierende vorkonfigurierte Netzwerkverbindung. Dann wird der lokale Setup-Modus automatisch abgeschlossen.

Wichtig: Wenn du im Imager direkt `Use custom` und danach die Autodarts-Pi-OS-ZIP/IMG waehlst, sind die Anpassungen ausgegraut. Das ist ein Imager-Metadaten-Thema. Erzeuge stattdessen ein Manifest:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\create-imager-manifest.ps1 -ImagePath "C:\Pfad\zu\AutodartsPiOS-lite.zip"
```

Dann:

1. Raspberry Pi Imager schliessen.
2. Die erzeugte Datei `imager\autodarts-pi-os-local.rpi-imager-manifest` per Doppelklick oeffnen.
3. Falls Windows fragt, mit `Raspberry Pi Imager` oeffnen.
4. Im Imager `Autodarts Pi OS Lite` aus der OS-Liste waehlen.
5. Erst danach Speicherkarte waehlen und unter `Anpassung` WLAN, Hostname und SSH setzen.

Nicht die ZIP direkt ueber `Use custom` auswaehlen. Dann fehlen die Metadaten und die Anpassungen bleiben ausgegraut.

Wenn die im Imager eingetragenen WLAN-Daten falsch sind oder das WLAN nicht erreichbar ist, bleibt Autodarts Pi OS im Factory-Setup und startet den Hotspot `Autodarts-Setup`. Dann kannst du die Daten wie unten beschrieben ueber `http://auto.setup.go` korrigieren.

### Variante A: Einrichtung per Handy oder Laptop über Setup-Hotspot

Wenn der Raspberry Pi noch kein Netzwerk hat, öffnet Autodarts Pi OS automatisch ein eigenes WLAN:

```text
WLAN-Name: Autodarts-Setup
Passwort: autodarts
```

Danach:

1. Am Handy oder Laptop mit `Autodarts-Setup` verbinden.
2. Browser öffnen.
3. Diese Adresse aufrufen:

```text
http://auto.setup.go
```

Falls die Adresse am Handy nicht sofort aufloest, diese feste Hotspot-IP verwenden:

```text
http://10.42.0.1
```

4. Mit dem Setup-Passwort einloggen:

```text
autodarts
```

5. Hostname, neues Setup-Passwort und optional WLAN-Daten eintragen.
6. `Speichern und anwenden` drücken.
7. Danach wird die Verbindung zur Setup-Seite eventuell kurz getrennt. Das ist normal: Der Pi schaltet den Setup-Hotspot kurz aus und testet das eingetragene Heim-WLAN.
8. Wenn das WLAN erfolgreich verbunden wurde, bleibt der Setup-Hotspot aus und das Setup wird dauerhaft abgeschlossen. Verbinde dein Handy oder deinen Laptop dann mit demselben Heim-WLAN und öffne `http://autodarts-pi.local` oder die IP-Adresse des Pi.
9. Wenn WLAN-Name oder Passwort falsch sind oder keine Verbindung zustande kommt, startet der Hotspot `Autodarts-Setup` automatisch wieder. Verbinde dich erneut damit, öffne `http://auto.setup.go` und korrigiere die Daten.
10. Sobald Ethernet oder WLAN verbunden ist, kann `Setup abschließen` zusätzlich manuell gedrückt werden, falls die automatische Übernahme noch nicht erfolgt ist.
11. Danach startet der Kiosk auf einer lokalen Autodarts-Pi-OS-Portal-Seite. Diese Seite zeigt IP, Dienste und Installationsstatus. Sobald der lokale Autodarts-Dienst bereit ist, erscheint dort der Button `Kameras / Autodarts oeffnen`.

Nach einem erfolgreichen Setup merkt sich Autodarts Pi OS den Zustand `configured`. Ein späterer Internet- oder WLAN-Ausfall startet den Setup-Hotspot dann nicht automatisch erneut.

Hinweis: Bei erfolgreicher WLAN-Uebernahme startet der Pi automatisch neu, damit der Kiosk danach mit dem finalen Netzwerkzustand und dem lokalen Autodarts-Konfigurationsmodus startet.

### Variante B: Einrichtung per Netzwerkkabel

Wenn ein LAN-Kabel angeschlossen ist, bekommt der Pi normalerweise automatisch eine IP-Adresse per DHCP.

Dann im Browser aufrufen:

```text
http://autodarts-pi.local
```

Falls `.local` im Netzwerk nicht auflöst, die IP aus dem Router verwenden:

```text
http://<pi-ip>
```

WLAN kann in diesem Fall leer bleiben. Wenn Ethernet verbunden ist, wird das Setup beim Speichern automatisch dauerhaft abgeschlossen. Danach startet der Kiosk auf der lokalen Autodarts-Pi-OS-Portal-Seite.

### Variante C: Einrichtung direkt am Monitor

Wenn Monitor und Tastatur angeschlossen sind, startet der Pi lokal in den Setup-Kiosk:

```text
http://localhost/setup
```

Das ist hilfreich, wenn weder Handy-Hotspot-Setup noch Ethernet verfügbar sind.

## Admin-Oberfläche Und Recovery

Nach abgeschlossenem Setup ist die Weboberfläche im normalen Netzwerk erreichbar:

```text
http://autodarts-pi.local
```

oder per IP-Adresse:

```text
http://<pi-ip>
```

Die Startseite fuehrt dann in das lokale Portal. Dort sind IP, Dienste, Installationsstatus und der Button zur Autodarts-/Kamera-Einrichtung sichtbar. Der Adminbereich bleibt erreichbar.

Direkte Adressen:

```text
http://autodarts-pi.local/kiosk
http://autodarts-pi.local/admin
http://autodarts-pi.local/health.json
```

Wenn `.local` nicht aufloest, verwende die IP-Adresse des Pi:

```text
http://<pi-ip>/kiosk
```

Am angeschlossenen Bildschirm wird dieselbe Portal-Seite angezeigt. Sie bleibt sichtbar, auch wenn Autodarts noch installiert oder noch nicht erreichbar ist.

### Recovery-Hotspot

Wenn das Gerät bereits eingerichtet ist, startet der Setup-Hotspot bei normalem Netzwerkausfall nicht automatisch. Für eine bewusste Neueinrichtung gibt es drei Wege:

1. Im Adminbereich `Recovery-Hotspot starten` wählen.
2. Auf der Boot-Partition eine leere Datei anlegen:

```text
autodarts-recovery
```

3. Neu starten.

Danach öffnet der Pi wieder den Hotspot:

```text
Autodarts-Setup
```

und die Setup-Seite ist erreichbar unter:

```text
http://auto.setup.go
```

### Factory Reset

Für einen Reset auf die Image-Defaults:

1. Im Adminbereich `Factory Reset vorbereiten` wählen, oder
2. auf der Boot-Partition eine leere Datei anlegen:

```text
autodarts-factory-reset
```

Beim nächsten Boot wird die Default-Konfiguration wiederhergestellt und der Setup-Zustand auf `factory` gesetzt.

Beispiel für eine spätere Boot-Seed-Konfiguration:

```toml
hostname = "autodarts-pi"
mode = "webpanel"
profile = "pi5-usb-camera"
autodarts_command = "/usr/local/bin/autodarts-runtime"
autodarts_install_enabled = true
autodarts_version = "latest"
autodarts_installer_url = "https://get.autodarts.io"
webpanel_port = 80
setup_mode = true
setup_admin_user = "admin"
setup_admin_password = "autodarts"
setup_url = "http://localhost/setup"
setup_hotspot_enabled = true
setup_hotspot_ssid = "Autodarts-Setup"
setup_hotspot_password = "autodarts"
setup_hotspot_address = "10.42.0.1/24"
setup_hotspot_host = "auto.setup.go"
reboot_after_wifi = true
kiosk_enabled = true
play_url = "https://play.autodarts.io"
kiosk_url = "http://localhost/kiosk"
autodarts_local_url = "http://localhost:3180"
autodarts_config_url = "http://localhost:3180"
autodarts_fallback_url = "https://play.autodarts.io"
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
