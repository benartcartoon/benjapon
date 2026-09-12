#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/engines/MuseTalk"

if [[ ! -d "$DIR/.git" ]]; then
  git clone --depth 1 https://github.com/TMElyralab/MuseTalk.git "$DIR"
fi

if [[ ! -x "$DIR/.venv/bin/python" ]]; then
  uv python install 3.10
  uv venv --python 3.10 "$DIR/.venv"
  P="$DIR/.venv/bin/python"
  "$P" -m pip install -U pip wheel setuptools
  "$P" -m pip install torch==2.0.1 torchvision==0.15.2 torchaudio==2.0.2 --index-url https://download.pytorch.org/whl/cu118
  "$P" -m pip install -r "$DIR/requirements.txt"
  "$P" -m pip install -U openmim
  "$DIR/.venv/bin/mim" install mmengine
  "$DIR/.venv/bin/mim" install "mmcv==2.0.1"
  "$DIR/.venv/bin/mim" install "mmdet==3.1.0"
  "$DIR/.venv/bin/mim" install "mmpose==1.1.0"
fi

if [[ ! -f "$DIR/models/musetalkV15/unet.pth" ]]; then
  (cd "$DIR" && bash download_weights.sh)
fi
