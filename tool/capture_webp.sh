#!/usr/bin/env bash
# Convert the PNG frame sequences captured by
# example/test/capture/capture_test.dart into animated WebPs for the README.
#
# Usage:
#   bash tool/capture_webp.sh
#
# Prereqs: ffmpeg (brew install ffmpeg) and a prior
#   (cd example && flutter test test/capture/capture_test.dart)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC_DIR="${ROOT_DIR}/example/build/screenshots"
OUT_DIR="${ROOT_DIR}/screenshots"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg not found. Install via 'brew install ffmpeg'." >&2
  exit 1
fi
if [[ ! -d "${SRC_DIR}" ]]; then
  echo "No frames at ${SRC_DIR}." >&2
  echo "Run: (cd example && flutter test test/capture/capture_test.dart)" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"

# Output width. Square scenes become 512x512; portrait scenes 512x835 (short
# side >= 512). Sources are rendered at 2x, so this is always a crisp downscale.
WIDTH=512

for demo in showcase world_cup light presets neon controller natural heatmap_turbo fantasy custom_text; do
  pattern="${SRC_DIR}/${demo}_%03d.png"
  out="${OUT_DIR}/${demo}.webp"
  if ! ls "${SRC_DIR}/${demo}_000.png" >/dev/null 2>&1; then
    echo "skip ${demo}: no frames" >&2
    continue
  fi
  echo "→ ${demo} (w=${WIDTH})"
  # q:v 85: the globe is full-frame high-frequency dots in constant motion, so
  # inter-frame compression barely helps and q100 just bloats the file ~3x with
  # no visible gain. 40 frames at 20fps = a 2s loop; frame 0 stays the hero pose
  # for the static pub.dev thumbnail.
  ffmpeg -y -loglevel error \
    -framerate 20 -i "${pattern}" \
    -frames:v 40 \
    -vf "scale=${WIDTH}:-1:flags=lanczos" \
    -loop 0 -compression_level 6 -q:v 85 \
    "${out}"
  bytes=$(wc -c <"${out}" | tr -d ' ')
  printf '  wrote %s (%s bytes)\n' "${out}" "${bytes}"
done

echo "done."
