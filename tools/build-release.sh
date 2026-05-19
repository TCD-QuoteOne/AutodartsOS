#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PI_GEN_DIR="${PI_GEN_DIR:-/opt/pi-gen}"
BUNDLE_AUTODARTS_INSTALLER="${BUNDLE_AUTODARTS_INSTALLER:-true}"

if [[ ! -d "$PI_GEN_DIR" ]]; then
  echo "PI_GEN_DIR does not exist: $PI_GEN_DIR" >&2
  exit 1
fi

export PI_GEN_DIR
export BUNDLE_AUTODARTS_INSTALLER

cd "$ROOT_DIR"
./image/build.sh

cd "$PI_GEN_DIR"
./build.sh

LATEST_IMAGE="$(
  find "$PI_GEN_DIR/deploy" -maxdepth 1 -type f \( -name '*AutodartsPiOS*.zip' -o -name '*AutodartsPiOS*.img' \) \
    -printf '%T@ %p\n' | sort -nr | awk 'NR == 1 { $1=""; sub(/^ /, ""); print }'
)"

if [[ -z "$LATEST_IMAGE" ]]; then
  echo "No Autodarts Pi OS image found in $PI_GEN_DIR/deploy" >&2
  exit 1
fi

MANIFEST_PATH="${LATEST_IMAGE%.*}.rpi-imager-manifest"
"$ROOT_DIR/tools/create-imager-manifest.sh" --image "$LATEST_IMAGE" --output "$MANIFEST_PATH"

cat <<EOF

Build complete.
Image:
  $LATEST_IMAGE
Manifest for Raspberry Pi Imager customisation:
  $MANIFEST_PATH

Open the .rpi-imager-manifest file with Raspberry Pi Imager and select Autodarts Pi OS Lite from the OS list.
EOF
