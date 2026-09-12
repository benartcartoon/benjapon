#!/usr/bin/env bash
set -e

apt-get update -qq
apt-get install -y -qq ffmpeg
python -m pip install -U pip setuptools wheel

# Core pipeline
python -m pip install openai-whisper transformers sentencepiece

# Maintained Coqui TTS package supports current Colab/Python 3.13.
# The old PyPI package named `TTS` only supports Python <3.12.
python -m pip uninstall -y TTS >/dev/null 2>&1 || true
python -m pip install -U 'coqui-tts[ja]'

# XTTS model license acceptance for non-interactive Colab runs.
export COQUI_TOS_AGREED=1

echo 'Voice cloning dependencies ready.'
