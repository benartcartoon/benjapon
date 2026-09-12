#!/usr/bin/env bash
set -euo pipefail

apt-get update -qq
apt-get install -y -qq ffmpeg python3-venv

# Keep the Colab/main environment untouched: NLLB/Whisper run there.
# XTTS gets its own environment so its Transformers dependency cannot
# break the translation stack.
VENV="/content/xtts_env"
python -m venv --system-site-packages "$VENV"
"$VENV/bin/python" -m pip install -U pip setuptools wheel
"$VENV/bin/python" -m pip uninstall -y TTS >/dev/null 2>&1 || true
"$VENV/bin/python" -m pip install -U 'coqui-tts[ja]==0.27.5'

export COQUI_TOS_AGREED=1

"$VENV/bin/python" - <<'PY'
from TTS.api import TTS
print('XTTS isolated environment: OK')
PY

echo 'Voice cloning environment ready: /content/xtts_env'
