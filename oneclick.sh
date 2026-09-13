#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Kullanim: bash oneclick.sh /content/video.mp4"
  exit 1
fi
INPUT="$(readlink -f "$1")"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

[[ -f "$INPUT" ]] || { echo "HATA: Video bulunamadi: $INPUT"; exit 1; }
command -v nvidia-smi >/dev/null 2>&1 || { echo "HATA: NVIDIA GPU yok. Colab > Calisma zamani > T4 GPU sec."; exit 2; }
VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | tr -d ' ')
(( VRAM >= 12000 )) || { echo "HATA: En az 12 GB VRAM gerekiyor. Bulunan: ${VRAM} MB"; exit 3; }

echo "=== BenJapon | GPU ${VRAM} MB ==="
apt-get update -qq
apt-get install -y -qq ffmpeg git curl libgl1 libglib2.0-0 build-essential

if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
fi

# Ana AI ortami: Qwen3-TTS resmi dokumani Python 3.12 temiz ortam oneriyor.
if [[ ! -x .venv/bin/python ]]; then
  uv python install 3.12
  uv venv --seed --python 3.12 .venv
fi
source .venv/bin/activate
python -m pip install -q -U pip wheel setuptools
python -m pip install -q -r requirements.txt

mkdir -p engines outputs cache work
export HF_HOME="${HF_HOME:-$ROOT/cache/huggingface}"
export TRANSFORMERS_CACHE="$HF_HOME"

# T4 15 GB icin MuseTalk 1.5. MuseTalk kendi resmi kurulumunda Python 3.10 ister;
# bu nedenle Colab'in Python surumunden tamamen izole edilir.
bash scripts/setup_musetalk.sh

python pipeline.py --input "$INPUT" --engine musetalk
