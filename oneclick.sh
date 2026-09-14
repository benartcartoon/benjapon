#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Kullanim: bash oneclick.sh /content/drive/MyDrive/BenJapon/input/video.mp4"
  exit 1
fi
INPUT="$(readlink -f "$1")"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRIVE_ROOT="${BENJAPON_DRIVE:-/content/drive/MyDrive/BenJapon}"
cd "$ROOT"

[[ -d /content/drive/MyDrive ]] || { echo "HATA: Google Drive bagli degil."; exit 1; }
[[ -f "$INPUT" ]] || { echo "HATA: Video bulunamadi: $INPUT"; exit 1; }
command -v nvidia-smi >/dev/null 2>&1 || { echo "HATA: NVIDIA GPU yok. Colab > Calisma zamani > T4 GPU sec."; exit 2; }
VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | tr -d ' ')
(( VRAM >= 12000 )) || { echo "HATA: En az 12 GB VRAM gerekiyor. Bulunan: ${VRAM} MB"; exit 3; }

echo "=== BenJapon | GPU ${VRAM} MB | LatentSync 1.5 | Drive kalici depo ==="
apt-get update -qq
apt-get install -y -qq ffmpeg git curl libgl1 libglib2.0-0 build-essential

if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
fi

mkdir -p "$DRIVE_ROOT"/{models,cache,engines,input,output}

# Buyuk model/cache/engine dosyalari Drive'da kalici dursun.
rm -rf "$ROOT/models" "$ROOT/cache"
ln -s "$DRIVE_ROOT/models" "$ROOT/models"
ln -s "$DRIVE_ROOT/cache" "$ROOT/cache"
mkdir -p "$ROOT/engines"

if [[ ! -x .venv/bin/python ]]; then
  uv python install 3.12
  uv venv --seed --python 3.12 .venv
fi
source .venv/bin/activate
python -m pip install -q -U pip wheel setuptools
python -m pip install -q -r requirements.txt

mkdir -p outputs work
export HF_HOME="$DRIVE_ROOT/cache/huggingface"
export TRANSFORMERS_CACHE="$HF_HOME"
export BENJAPON_ENGINE_STORE="$DRIVE_ROOT/engines"
export BENJAPON_OUTPUT_DIR="$DRIVE_ROOT/output"

bash scripts/setup_latentsync.sh

python -m pip install -q --upgrade --force-reinstall "huggingface-hub>=0.34.0,<1.0"
python - <<'PY'
import huggingface_hub, transformers
print('Ana ortam OK | huggingface-hub:', huggingface_hub.__version__, '| transformers:', transformers.__version__)
PY

python pipeline.py --input "$INPUT" --engine latentsync

# Pipeline'in ciktisini Drive'a kalici kaydet.
LATEST=$(find "$ROOT/outputs" -maxdepth 1 -type f -name '*.mp4' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2- || true)
if [[ -n "$LATEST" && -f "$LATEST" ]]; then
  cp -f "$LATEST" "$DRIVE_ROOT/output/$(basename "$LATEST")"
  echo "DRIVE HAZIR: $DRIVE_ROOT/output/$(basename "$LATEST")"
fi
