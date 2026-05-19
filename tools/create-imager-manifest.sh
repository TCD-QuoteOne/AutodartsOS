#!/usr/bin/env bash
set -euo pipefail

IMAGE_PATH=""
OUTPUT_PATH=""
NAME="Autodarts Pi OS Lite"
DESCRIPTION="Raspberry Pi OS Lite appliance image for Autodarts with setup hotspot, kiosk and first-boot customisation."
ICON_URL="https://raw.githubusercontent.com/TCD-QuoteOne/AutodartsOS/main/assets/boot/autodarts-pi-os-splash.png"
IMAGE_URL=""

usage() {
  cat <<'EOF'
Usage:
  create-imager-manifest.sh --image /path/to/AutodartsPiOS.zip [--output /path/to/manifest.rpi-imager-manifest]

Creates a Raspberry Pi Imager manifest with init_format=systemd so OS customisation
for WiFi, hostname and SSH is enabled.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      IMAGE_PATH="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_PATH="${2:-}"
      shift 2
      ;;
    --name)
      NAME="${2:-}"
      shift 2
      ;;
    --description)
      DESCRIPTION="${2:-}"
      shift 2
      ;;
    --icon)
      ICON_URL="${2:-}"
      shift 2
      ;;
    --url)
      IMAGE_URL="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$IMAGE_PATH" ]]; then
  echo "--image is required" >&2
  usage >&2
  exit 1
fi

if [[ ! -f "$IMAGE_PATH" ]]; then
  echo "Image not found: $IMAGE_PATH" >&2
  exit 1
fi

if [[ -z "$OUTPUT_PATH" ]]; then
  OUTPUT_PATH="${IMAGE_PATH%.*}.rpi-imager-manifest"
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

python3 - "$IMAGE_PATH" "$OUTPUT_PATH" "$NAME" "$DESCRIPTION" "$ICON_URL" "$IMAGE_URL" <<'PY'
import hashlib
import json
import pathlib
import sys
from datetime import date

image_path = pathlib.Path(sys.argv[1]).resolve()
output_path = pathlib.Path(sys.argv[2]).resolve()
name = sys.argv[3]
description = sys.argv[4]
icon_url = sys.argv[5]
image_url = sys.argv[6] or image_path.as_uri()

sha256 = hashlib.sha256()
with image_path.open("rb") as handle:
    for chunk in iter(lambda: handle.read(1024 * 1024), b""):
        sha256.update(chunk)

manifest = {
    "imager": {
        "latest_version": "2.0.0",
        "url": "https://www.raspberrypi.com/software/",
        "devices": [
            {
                "name": "Raspberry Pi",
                "tags": ["pi"],
                "default": True,
                "matching_type": "inclusive",
                "description": "Raspberry Pi boards supported by Raspberry Pi OS Bookworm.",
            }
        ],
    },
    "os_list": [
        {
            "name": name,
            "description": description,
            "icon": icon_url,
            "url": image_url,
            "image_download_size": image_path.stat().st_size,
            "image_download_sha256": sha256.hexdigest(),
            "release_date": date.today().isoformat(),
            "init_format": "systemd",
            "devices": ["pi"],
        }
    ],
}

output_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print(f"Created Raspberry Pi Imager manifest: {output_path}")
PY
