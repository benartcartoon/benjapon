#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Kullanim: bash oneclick.sh /path/video.mp4"
  exit 1
fi
INPUT="$(readlink -f "$1")"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "HATA: NVIDIA GPU/nvidia-smi bulunamadi."
  exit 2
fi
VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | tr -d ' ')
if (( VRAM < 8000 )); then
  echo "HATA: ${VRAM} MB VRAM. Bu repo 8 GB altinda kaliteyi dusurup calistirmiyor."
  exit 3
fi

SUDO=""
if [[ "$(id -u)" != "0" ]]; then SUDO="sudo"; fi
$SUDO apt-get update -qq
$SUDO apt-get install -y -qq ffmpeg git curl libgl1 libglib2.0-0 build-essential

if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
fi

if [[ ! -x .venv/bin/python ]]; then
  uv python install 3.12
  uv venv --seed --python 3.12 .venv
fi
source .venv/bin/activate
python -m pip install -U pip wheel setuptools
python -m pip install -r requirements.txt

mkdir -p engines outputs cache work
ENGINE="musetalk"
if (( VRAM >= 18000 )); then ENGINE="latentsync"; fi

echo "GPU VRAM: ${VRAM} MB | Secilen lip-sync: ${ENGINE}"
if [[ "$ENGINE" == "latentsync" ]]; then
  bash scripts/setup_latentsync.sh
else
  bash scripts/setup_musetalk.sh
fi

python pipeline.py --input "$INPUT" --engine "$ENGINE"
