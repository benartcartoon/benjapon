#!/usr/bin/env bash
set -e

apt-get update -qq
apt-get install -y -qq ffmpeg
python -m pip install -U pip setuptools wheel

# Coqui XTTS 0.27.5 currently breaks with Transformers 5.x because
# isin_mps_friendly was removed. 4.57.6 works with both XTTS and our
# direct NLLB translation code.
python -m pip install --force-reinstall --no-deps 'transformers==4.57.6'
python -m pip install -U sentencepiece openai-whisper

# Maintained Coqui package (Python 3.13 compatible).
python -m pip uninstall -y TTS >/dev/null 2>&1 || true
python -m pip install -U 'coqui-tts[ja]==0.27.5'

# Re-assert the compatible Transformers version in case dependency
# resolution changed it while installing Coqui.
python -m pip install --force-reinstall --no-deps 'transformers==4.57.6'

export COQUI_TOS_AGREED=1

python - <<'PY'
import transformers
from TTS.api import TTS
print('Transformers:', transformers.__version__)
print('Coqui TTS import: OK')
PY

echo 'Voice cloning dependencies ready.'
