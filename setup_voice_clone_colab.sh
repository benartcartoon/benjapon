#!/usr/bin/env bash
set -euo pipefail

apt-get update -qq
apt-get install -y -qq ffmpeg

# XTTS gets its own package layer but can see Colab's preinstalled
# CUDA-enabled torch/torchaudio. --without-pip avoids Colab ensurepip failure.
VENV="/content/xtts_env"
rm -rf "$VENV"
python -m venv --without-pip --system-site-packages "$VENV"

# Bootstrap pip into the venv using Colab's working pip module.
python -m pip --python "$VENV/bin/python" install -U pip setuptools wheel

# Install Coqui only in the venv. Do not replace Colab's CUDA torch stack.
python -m pip --python "$VENV/bin/python" install 'coqui-tts[ja]==0.27.5'

export COQUI_TOS_AGREED=1

"$VENV/bin/python" - <<'PY'
import torch, torchaudio
from TTS.api import TTS
print('Torch:', torch.__version__, 'CUDA:', torch.cuda.is_available())
print('XTTS isolated environment: OK')
PY

echo 'Voice cloning environment ready: /content/xtts_env'
