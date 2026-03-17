#!/usr/bin/env bash
# Demo script for hypr-vogix shader themes
# Records the screen while cycling through themes with wf-recorder

set -euo pipefail

DELAY=2
MP4="hypr-vogix-demo.mp4"
GIF="docs/hypr-vogix-demo.gif"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "Starting screen recording → $MP4"
wf-recorder -f "$MP4" -c libx264 -p crf=20 -p preset=slow &
REC_PID=$!
sleep 1

run() {
  echo "→ hypr-vogix $*"
  hypr-vogix "$@"
  sleep "$DELAY"
}

# Theme showcase
run -t white
run -t green
run -t amber
run -t cyber
run -t military

# Inversion demos
run -t military -o 0.7
run -t military -o 0.7 -i oklab
run -t cyber -o 0.7 -i oklab
run -t amber -o 0.7 -i oklab
run -t green -o 0.7 -i oklab
run -t white -o 0.7 -i oklab
run -t walnut -i oklab
run -t walnut

kill "$REC_PID"
wait "$REC_PID" 2>/dev/null || true
echo "Recording done → $MP4"

echo "Converting to GIF..."
ffmpeg -y -i "$MP4" \
  -vf "fps=10,scale=800:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
  "$REPO_DIR/$GIF"
rm "$MP4"
echo "Done → $REPO_DIR/$GIF"
