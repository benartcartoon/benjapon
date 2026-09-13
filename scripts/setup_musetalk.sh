#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/engines/MuseTalk"

if [[ ! -d "$DIR/.git" ]]; then
  git clone --depth 1 https://github.com/TMElyralab/MuseTalk.git "$DIR"
fi

# MuseTalk resmi stack: Python 3.10 + torch 2.0.1/cu118 + MMLab.
# Colab sistem Python'una hic dokunmuyoruz.
if [[ ! -x "$DIR/.venv/bin/python" ]]; then
  uv python install 3.10
  uv venv --seed --python 3.10 "$DIR/.venv"
  P="$DIR/.venv/bin/python"
  "$P" -m pip install -q -U pip wheel setuptools
  "$P" -m pip install -q "numpy==1.23.5"
  "$P" -m pip install -q torch==2.0.1 torchvision==0.15.2 torchaudio==2.0.2 --index-url https://download.pytorch.org/whl/cu118
  "$P" -m pip install -q -r "$DIR/requirements.txt"
  "$P" -m pip install -q "openmim==0.3.9"
  "$DIR/.venv/bin/mim" install mmengine
  "$DIR/.venv/bin/mim" install "mmcv==2.0.1"
  "$DIR/.venv/bin/mim" install "mmdet==3.1.0"
  "$DIR/.venv/bin/mim" install "mmpose==1.1.0"
fi

if [[ ! -f "$DIR/models/musetalkV15/unet.pth" ]]; then
  (cd "$DIR" && bash download_weights.sh)
fi

"$DIR/.venv/bin/python" - <<'PY'
import torch
print('MuseTalk ortam OK | CUDA:', torch.cuda.is_available(), '| Torch:', torch.__version__)
if not torch.cuda.is_available():
    raise SystemExit('HATA: MuseTalk CUDA GPU goremedi')
PY
