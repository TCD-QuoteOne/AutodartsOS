# Development

## Prerequisites

- Linux or WSL
- Git
- `pi-gen` checkout
- Raspberry Pi OS Lite build dependencies required by `pi-gen`

## Validate The Repository

PowerShell:

```powershell
.\tools\validate.ps1
```

Bash:

```bash
./tools/validate.sh
```

## Build Prototype Image

Clone `pi-gen` beside or inside your working area, then run:

```bash
export PI_GEN_DIR=/path/to/pi-gen
./image/build.sh
```

The script creates a custom stage named `stage2-autodarts-pi-os` inside the `pi-gen` checkout and copies overlays from this repository. It also configures `pi-gen` to skip the stock stage2 image export plus the desktop/full stages so only the Autodarts Pi OS Lite appliance image is exported. The actual image build is still delegated to `pi-gen`.

## Development Principles

- Keep the image reproducible.
- Avoid manual post-flash changes wherever possible.
- Prefer systemd services over shell startup hacks.
- Keep user configuration in a small number of predictable files.
- Make diagnostics visible through the local web panel.
