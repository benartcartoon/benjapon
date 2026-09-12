#!/usr/bin/env bash
set -euo pipefail

apt-get update -qq
apt-get install -y -qq ffmpeg

VENV="/content/xtts_env"
rm -rf "$VENV"
python -m venv --without-pip --system-site-packages "$VENV"
python -m pip --python "$VENV/bin/python" install -U pip setuptools wheel

# Coqui 0.27.5 needs Transformers 4.x for XTTS. Pin it INSIDE the venv.
# Colab's CUDA torch/torchaudio remain shared from the base environment.
python -m pip --python "$VENV/bin/python" install 'coqui-tts[ja]==0.27.5' 'transformers==4.57.6'

export COQUI_TOS_AGREED=1

"$VENV/bin/python" - <<'PY'
import torch, torchaudio, transformers
from TTS.api import TTS
print('Torch:', torch.__version__, 'CUDA:', torch.cuda.is_available())
print('Transformers:', transformers.__version__)
print('XTTS isolated environment: OK')
PY

echo 'Voice cloning environment ready: /content/xtts_env'
