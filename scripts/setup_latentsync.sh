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

if [[ ! -f "$DIR/checkpoints/latentsync_unet.pt" ]]; then
  mkdir -p "$DIR/checkpoints"
  "$DIR/.venv/bin/python" -m pip install -U huggingface-hub
  "$DIR/.venv/bin/huggingface-cli" download ByteDance/LatentSync-1.6 whisper/tiny.pt --local-dir "$DIR/checkpoints"
  "$DIR/.venv/bin/huggingface-cli" download ByteDance/LatentSync-1.6 latentsync_unet.pt --local-dir "$DIR/checkpoints"
fi
