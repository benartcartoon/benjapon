#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/engines/LatentSync"

if [[ ! -d "$DIR/.git" ]]; then
  git clone --depth 1 https://github.com/bytedance/LatentSync.git "$DIR"
fi

if [[ ! -x "$DIR/.venv/bin/python" ]]; then
  uv python install 3.10
  uv venv --seed --python 3.10 "$DIR/.venv"
  "$DIR/.venv/bin/python" -m pip install -U pip wheel setuptools
  "$DIR/.venv/bin/python" -m pip install -r "$DIR/requirements.txt"
fi

mkdir -p "$DIR/checkpoints"
"$DIR/.venv/bin/python" -m pip install -q -U "huggingface-hub>=0.34,<1"
HF="$DIR/.venv/bin/hf"

# T4 15 GB icin LatentSync 1.5 kullan. Resmi minimum inference VRAM'i 8 GB.
# 1.6 18 GB minimum istedigi icin T4'te kullanma.
if [[ ! -s "$DIR/checkpoints/latentsync_unet.pt" ]]; then
  "$HF" download ByteDance/LatentSync-1.5 latentsync_unet.pt --local-dir "$DIR/checkpoints"
fi
if [[ ! -s "$DIR/checkpoints/whisper/tiny.pt" ]]; then
  "$HF" download ByteDance/LatentSync-1.5 whisper/tiny.pt --local-dir "$DIR/checkpoints"
fi

[[ -s "$DIR/checkpoints/latentsync_unet.pt" ]] || { echo "HATA: LatentSync 1.5 UNet eksik"; exit 10; }
[[ -s "$DIR/checkpoints/whisper/tiny.pt" ]] || { echo "HATA: LatentSync Whisper eksik"; exit 11; }

echo "LatentSync 1.5 hazir."
