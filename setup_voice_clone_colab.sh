#!/usr/bin/env bash
set -euo pipefail

apt-get update -qq
apt-get install -y -qq ffmpeg

# Keep Colab's main environment untouched. Create an isolated XTTS env
# without ensurepip, which can fail in Colab's Python 3.13 image.
VENV="/content/xtts_env"
rm -rf "$VENV"
python -m venv --without-pip "$VENV"

# Bootstrap pip into the venv using Colab's working pip module.
python -m pip --python "$VENV/bin/python" install -U pip setuptools wheel

# XTTS dependencies live only in this environment.
python -m pip --python "$VENV/bin/python" install 'coqui-tts[ja]==0.27.5'

export COQUI_TOS_AGREED=1

"$VENV/bin/python" - <<'PY'
from TTS.api import TTS
print('XTTS isolated environment: OK')
PY

echo 'Voice cloning environment ready: /content/xtts_env'
