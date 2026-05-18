# Raspberry Pi Imager Manifest

Raspberry Pi Imager zeigt die OS-Anpassungen bei `Use custom` nicht an, weil einer lokal ausgewaehlten `.img` oder `.zip` die Metadaten fehlen. Fuer Autodarts Pi OS muss Imager wissen, dass das Image die klassische Raspberry-Pi-OS-First-Run-Anpassung unterstuetzt.

Der wichtige Wert ist:

```json
"init_format": "systemd"
```

Damit bietet Imager wieder Hostname, Benutzer, WLAN und SSH an und schreibt die passende `firstrun.sh` auf die Boot-Partition.

## Lokales Manifest erzeugen

Unter Windows/PowerShell im Repository:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\create-imager-manifest.ps1 `
  -ImagePath "C:\Pfad\zu\AutodartsPiOS-lite.zip" `
  -OutputPath ".\imager\autodarts-pi-os-local.rpi-imager-manifest"
```

Dann die erzeugte Datei `imager\autodarts-pi-os-local.rpi-imager-manifest` per Doppelklick oeffnen oder im Raspberry Pi Imager unter:

```text
App Options -> Content Repository -> Use custom file
```

auswaehlen.

Danach erscheint `Autodarts Pi OS Lite` in der OS-Liste. Wenn du dieses Image ueber die Liste waehlst, ist der Bereich fuer WLAN, Hostname und SSH nicht mehr ausgegraut.

## Wichtig

Nicht ueber `Use custom` direkt die ZIP/IMG auswaehlen. Dann fehlen Imager weiterhin die Metadaten und die Anpassungen bleiben ausgegraut.
