#!/usr/bin/env bash
set -euo pipefail

IMAGE_FILE="${1:-}"
MANIFEST_FILE="${2:-}"

if [[ -z "$IMAGE_FILE" ]]; then
  echo "Usage: verify-deploy-image.sh /path/to/AutodartsPiOS-lite.img.xz [/path/to/manifest.rpi-imager-manifest]" >&2
  exit 1
fi

if [[ ! -f "$IMAGE_FILE" ]]; then
  echo "Image not found: $IMAGE_FILE" >&2
  exit 1
fi

if [[ -z "$MANIFEST_FILE" ]]; then
  MANIFEST_FILE="${IMAGE_FILE%.*}.rpi-imager-manifest"
fi

if [[ ! -f "$MANIFEST_FILE" ]]; then
  echo "Manifest not found: $MANIFEST_FILE" >&2
  exit 1
fi

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need python3
need fdisk
need file

TMPDIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

echo "Checking manifest metadata..."
python3 - "$IMAGE_FILE" "$MANIFEST_FILE" <<'PY'
import gzip
import hashlib
import json
import lzma
import pathlib
import sys
import zipfile

image_path = pathlib.Path(sys.argv[1]).resolve()
manifest_path = pathlib.Path(sys.argv[2]).resolve()
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
entry = manifest["os_list"][0]

download_size = image_path.stat().st_size
download_sha = hashlib.sha256(image_path.read_bytes()).hexdigest()

if int(entry.get("image_download_size", -1)) != download_size:
    raise SystemExit(f"image_download_size mismatch: manifest={entry.get('image_download_size')} actual={download_size}")
if str(entry.get("image_download_sha256", "")).lower() != download_sha:
    raise SystemExit("image_download_sha256 mismatch")
if not entry.get("url", "").startswith("https://github.com/"):
    raise SystemExit(f"manifest url is not a public GitHub URL: {entry.get('url')}")
if "extract_size" not in entry or "extract_sha256" not in entry:
    raise SystemExit("manifest is missing extract_size or extract_sha256")

def hash_stream(handle):
    digest = hashlib.sha256()
    size = 0
    for chunk in iter(lambda: handle.read(1024 * 1024), b""):
        size += len(chunk)
        digest.update(chunk)
    return size, digest.hexdigest()

if image_path.suffix.lower() == ".zip":
    with zipfile.ZipFile(image_path) as archive:
        img_members = [m for m in archive.infolist() if not m.is_dir() and m.filename.lower().endswith(".img")]
        if not img_members:
            raise SystemExit("ZIP does not contain a .img file")
        member = max(img_members, key=lambda item: item.file_size)
        with archive.open(member) as handle:
            size, digest = hash_stream(handle)
elif image_path.suffix.lower() == ".xz":
    with lzma.open(image_path, "rb") as handle:
        size, digest = hash_stream(handle)
elif image_path.suffix.lower() == ".gz":
    with gzip.open(image_path, "rb") as handle:
        size, digest = hash_stream(handle)
else:
    size, digest = image_path.stat().st_size, download_sha

if int(entry["extract_size"]) != size:
    raise SystemExit(f"extract_size mismatch: manifest={entry['extract_size']} actual={size}")
if str(entry["extract_sha256"]).lower() != digest:
    raise SystemExit("extract_sha256 mismatch")
PY

echo "Extracting image for partition check..."
python3 - "$IMAGE_FILE" "$TMPDIR/image.img" <<'PY'
import gzip
import lzma
import pathlib
import shutil
import sys
import zipfile

image_path = pathlib.Path(sys.argv[1]).resolve()
output_path = pathlib.Path(sys.argv[2]).resolve()

if image_path.suffix.lower() == ".zip":
    with zipfile.ZipFile(image_path) as archive:
        img_members = [m for m in archive.infolist() if not m.is_dir() and m.filename.lower().endswith(".img")]
        if not img_members:
            raise SystemExit("ZIP does not contain a .img file")
        member = max(img_members, key=lambda item: item.file_size)
        with archive.open(member) as source, output_path.open("wb") as target:
            shutil.copyfileobj(source, target, length=1024 * 1024)
elif image_path.suffix.lower() == ".xz":
    with lzma.open(image_path, "rb") as source, output_path.open("wb") as target:
        shutil.copyfileobj(source, target, length=1024 * 1024)
elif image_path.suffix.lower() == ".gz":
    with gzip.open(image_path, "rb") as source, output_path.open("wb") as target:
        shutil.copyfileobj(source, target, length=1024 * 1024)
else:
    shutil.copyfile(image_path, output_path)
PY

echo "Checking partition table..."
fdisk -l "$TMPDIR/image.img"

BOOT_START="$(fdisk -l "$TMPDIR/image.img" | awk '$1 ~ /image\.img1$/ { print $2; exit }')"
if [[ -z "$BOOT_START" ]]; then
  echo "Could not find first partition in image." >&2
  exit 1
fi

BOOT_OFFSET=$((BOOT_START * 512))
BOOT_SAMPLE="$TMPDIR/boot-partition.sample"
dd if="$TMPDIR/image.img" of="$BOOT_SAMPLE" bs=1 skip="$BOOT_OFFSET" count=$((4 * 1024 * 1024)) status=none

echo "Checking first partition filesystem signature..."
file "$BOOT_SAMPLE"
if ! file "$BOOT_SAMPLE" | grep -Eqi 'FAT|DOS/MBR boot sector'; then
  echo "First partition does not look like a FAT boot partition." >&2
  exit 1
fi

echo "Deploy image looks bootable and manifest metadata matches."
