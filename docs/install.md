# Install

This project is not yet publishing ready-made images.

Planned install flow:

1. Build image with `pi-gen`.
2. Flash image to microSD or SSD.
3. Optionally place `autodarts-config.toml` on the boot partition.
4. Boot Raspberry Pi.
5. First boot prepares services and applies configuration.
6. Open the local web panel at port `8080`.

## First Boot Seed Config

Example:

```toml
hostname = "autodarts-pi"
mode = "webpanel"
profile = "pi5-usb-camera"
autodarts_command = "/usr/local/bin/autodarts-runtime"
```

