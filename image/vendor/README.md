# Optional vendored Autodarts installer

By default Autodarts Pi OS downloads the Autodarts installer from `https://get.autodarts.io` during first boot.

For a more self-contained test image, place a trusted installer script here:

```text
image/vendor/autodarts-installer.sh
```

When present, `image/build.sh` embeds it into the image at:

```text
/usr/share/autodarts-pi-os/autodarts-installer.sh
```

The first-boot installer then uses this bundled script instead of downloading `https://get.autodarts.io`.

Do not commit third-party installer code here unless its license and redistribution terms allow it.
