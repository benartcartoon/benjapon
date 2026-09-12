#!/usr/bin/env bash
set -e

apt-get update -qq
apt-get install -y -qq ffmpeg
python -m pip install -U pip

# Core pipeline
python -m pip install openai-whisper transformers sentencepiece

# XTTS-v2 voice cloning. Pin setuptools for current Colab/PyTorch compatibility.
python -m pip install 'setuptools<82'
python -m pip install TTS

# Accept Coqui model license non-interactively when XTTS downloads.
export COQUI_TOS_AGREED=1

echo 'Voice cloning dependencies ready.'
