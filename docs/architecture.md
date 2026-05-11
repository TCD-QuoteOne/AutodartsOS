# Architecture

Autodarts Pi OS is built as an appliance layer on top of Raspberry Pi OS Lite.

## Runtime Layers

1. Raspberry Pi OS Lite provides the base operating system.
2. The image overlay installs Autodarts Pi OS configuration, scripts, services, and assets.
3. A first-boot service applies user configuration and prepares the runtime.
4. The Autodarts runtime service starts the board software.
5. The local web panel exposes health, logs, and basic maintenance actions.

## System Services

- `autodarts-firstboot.service`: runs once, applies defaults, prepares folders, and disables itself.
- `autodarts-runtime.service`: owns the Autodarts application process.
- `autodarts-watchdog.service`: lightweight health loop for future recovery actions.
- `autodarts-webpanel.service`: local HTTP status and setup panel.

## Configuration

Main config:

```text
/etc/autodarts-pi-os/config.toml
```

Optional boot-partition seed config:

```text
/boot/firmware/autodarts-config.toml
```

If the seed file exists at first boot, it is copied into `/etc/autodarts-pi-os/config.toml`.

## Public Release Risk

The name should be checked before public distribution. A safe public phrasing is "Autodarts Pi OS: an unofficial Raspberry Pi OS image for Autodarts" unless upstream grants clearer permission.

