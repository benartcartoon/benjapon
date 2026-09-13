#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/engines/MuseTalk"

if [[ ! -d "$DIR/.git" ]]; then
  git clone --depth 1 https://github.com/TMElyralab/MuseTalk.git "$DIR"
fi

# MuseTalk: Python 3.10 + torch 2.0.1/cu118.
# MMLab paketlerini pip ile sabitliyoruz; mim'in eski chumpy build zincirinden kaciniyoruz.
if [[ ! -x "$DIR/.venv/bin/python" ]]; then
  uv python install 3.10
  uv venv --seed --python 3.10 "$DIR/.venv"
fi
P="$DIR/.venv/bin/python"
"$P" -m pip install -q -U pip wheel setuptools
"$P" -m pip install -q "numpy==1.23.5"
"$P" -m pip install -q torch==2.0.1 torchvision==0.15.2 torchaudio==2.0.2 --index-url https://download.pytorch.org/whl/cu118
"$P" -m pip install -q -r "$DIR/requirements.txt"
"$P" -m pip install -q "openmim==0.3.9"
"$DIR/.venv/bin/mim" install mmengine
"$DIR/.venv/bin/mim" install "mmcv==2.0.1"
"$P" -m pip install -q "mmdet==3.1.0"
# chumpy'nin eski build izolasyonu Colab'da kiriliyor. Once modern kurulum araclarini verip
# chumpy'yi izolasyonsuz kuruyor, sonra mmpose'u dependency cozumunu yeniden tetiklemeden kuruyoruz.
"$P" -m pip install -q "setuptools<81" "six>=1.16"
"$P" -m pip install -q --no-build-isolation "chumpy==0.70"
"$P" -m pip install -q --no-deps "mmpose==1.1.0"

if [[ ! -f "$DIR/models/musetalkV15/unet.pth" ]]; then
  (cd "$DIR" && bash download_weights.sh)
fi

"$P" - <<'PY'
import torch
import mmpose
print('MuseTalk ortam OK | CUDA:', torch.cuda.is_available(), '| Torch:', torch.__version__, '| mmpose:', mmpose.__version__)
if not torch.cuda.is_available():
    raise SystemExit('HATA: MuseTalk CUDA GPU goremedi')
PY
