#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PI_GEN_DIR="${PI_GEN_DIR:-/opt/pi-gen}"
BUNDLE_AUTODARTS_INSTALLER="${BUNDLE_AUTODARTS_INSTALLER:-true}"
RELEASE_VERSION="${RELEASE_VERSION:-}"
GITHUB_REPO="${GITHUB_REPO:-TCD-QuoteOne/AutodartsOS}"
RELEASE_IMAGE_FORMAT="${RELEASE_IMAGE_FORMAT:-xz}"

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

LATEST_SOURCE="$(
  find "$PI_GEN_DIR/deploy" -maxdepth 1 -type f \( -name '*AutodartsPiOS*.zip' -o -name '*AutodartsPiOS*.img' \) \
    -printf '%T@ %p\n' | sort -nr | awk 'NR == 1 { $1=""; sub(/^ /, ""); print }'
)"

if [[ -z "$LATEST_SOURCE" ]]; then
  echo "No Autodarts Pi OS image found in $PI_GEN_DIR/deploy" >&2
  exit 1
fi

LATEST_IMAGE="$LATEST_SOURCE"
if [[ "$RELEASE_IMAGE_FORMAT" == "xz" ]]; then
  need() {
    command -v "$1" >/dev/null 2>&1 || {
      echo "Missing required command for xz release: $1" >&2
      exit 1
    }
  }
  need python3
  need unzip
  need xz

  if [[ "$LATEST_SOURCE" == *.zip ]]; then
    IMG_MEMBER="$(python3 - "$LATEST_SOURCE" <<'PY'
import pathlib
import sys
import zipfile

with zipfile.ZipFile(pathlib.Path(sys.argv[1])) as archive:
    img_members = [m for m in archive.infolist() if not m.is_dir() and m.filename.lower().endswith(".img")]
    if not img_members:
        raise SystemExit("ZIP does not contain a .img file")
    print(max(img_members, key=lambda item: item.file_size).filename)
PY
)"
    XZ_IMAGE="${LATEST_SOURCE%.zip}.img.xz"
    echo "Creating Raspberry Pi Imager friendly xz artifact: $XZ_IMAGE"
    unzip -p "$LATEST_SOURCE" "$IMG_MEMBER" | xz -T0 -9 -c > "$XZ_IMAGE"
    LATEST_IMAGE="$XZ_IMAGE"
  elif [[ "$LATEST_SOURCE" == *.img ]]; then
    XZ_IMAGE="${LATEST_SOURCE}.xz"
    echo "Creating Raspberry Pi Imager friendly xz artifact: $XZ_IMAGE"
    xz -T0 -9 -c "$LATEST_SOURCE" > "$XZ_IMAGE"
    LATEST_IMAGE="$XZ_IMAGE"
  fi
fi

MANIFEST_PATH="${LATEST_IMAGE%.*}.rpi-imager-manifest"
MANIFEST_ARGS=(--image "$LATEST_IMAGE" --output "$MANIFEST_PATH")
if [[ -n "$RELEASE_VERSION" ]]; then
  IMAGE_BASENAME="$(basename "$LATEST_IMAGE")"
  MANIFEST_ARGS+=(--url "https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_VERSION}/${IMAGE_BASENAME}")
fi
"$ROOT_DIR/tools/create-imager-manifest.sh" "${MANIFEST_ARGS[@]}"

cat <<EOF

Build complete.
Image:
  $LATEST_IMAGE
Manifest for Raspberry Pi Imager customisation:
  $MANIFEST_PATH

Open the .rpi-imager-manifest file with Raspberry Pi Imager and select Autodarts Pi OS Lite from the OS list.
EOF
