#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRIVE_ROOT="${BENJAPON_DRIVE:-/content/drive/MyDrive/BenJapon}"
INPUT_DIR="$DRIVE_ROOT/input"
OUTPUT_DIR="$DRIVE_ROOT/output"
cd "$ROOT"

[[ -d /content/drive/MyDrive ]] || { echo "HATA: Google Drive bagli degil."; exit 1; }
command -v nvidia-smi >/dev/null 2>&1 || { echo "HATA: NVIDIA GPU yok. Colab > Calisma zamani > T4 GPU sec."; exit 2; }
VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | tr -d ' ')
(( VRAM >= 12000 )) || { echo "HATA: En az 12 GB VRAM gerekiyor. Bulunan: ${VRAM} MB"; exit 3; }

mkdir -p "$DRIVE_ROOT"/{models,cache,engines,input,output}

# Video yolu verilirse onu kullan; verilmezse Drive/input icindeki en yeni videoyu otomatik sec.
if [[ $# -ge 1 && -n "${1:-}" ]]; then
  INPUT="$(readlink -f "$1")"
else
  INPUT=$(find "$INPUT_DIR" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.mkv' -o -iname '*.webm' \) -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2- || true)
fi
[[ -n "${INPUT:-}" && -f "$INPUT" ]] || { echo "HATA: $INPUT_DIR icinde video bulunamadi."; exit 1; }

echo "=== BenJapon | GPU ${VRAM} MB | LatentSync 1.5 | Drive kalici depo ==="
echo "VIDEO: $INPUT"
apt-get update -qq
apt-get install -y -qq ffmpeg git curl libgl1 libglib2.0-0 build-essential

if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
fi

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

mkdir -p outputs work "$OUTPUT_DIR"
export HF_HOME="$DRIVE_ROOT/cache/huggingface"
export TRANSFORMERS_CACHE="$HF_HOME"
export BENJAPON_ENGINE_STORE="$DRIVE_ROOT/engines"

bash scripts/setup_latentsync.sh
python -m pip install -q --upgrade --force-reinstall "huggingface-hub>=0.34.0,<1.0"

# Tek akis: Turkce ses -> yazi -> Japonca ceviri -> ses klonlama -> LatentSync -> MP4
python pipeline.py --input "$INPUT" --engine latentsync

STEM="$(basename "$INPUT")"; STEM="${STEM%.*}"
LATEST="$ROOT/outputs/${STEM}_JA.mp4"
[[ -f "$LATEST" ]] || { echo "HATA: Final video olusmadi: $LATEST"; exit 20; }
cp -f "$LATEST" "$OUTPUT_DIR/$(basename "$LATEST")"
echo ""
echo "=============================================="
echo "HAZIR: $OUTPUT_DIR/$(basename "$LATEST")"
echo "=============================================="
