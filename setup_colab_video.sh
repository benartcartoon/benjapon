#!/usr/bin/env bash
set -e

# Google Colab / modern Python compatible setup.
apt-get update -qq
apt-get install -y -qq ffmpeg
python -m pip install --upgrade pip setuptools wheel
python -m pip install -r requirements.txt

# Wav2Lip upstream requirements pin very old NumPy/OpenCV versions that do not
# install on modern Colab Python. Clone the inference code, but deliberately do
# NOT install its legacy requirements.txt. Install compatible runtime packages.
if [ ! -d Wav2Lip ]; then
  git clone https://github.com/Rudrabha/Wav2Lip.git
fi

python -m pip install \
  "numpy>=2.0" \
  "opencv-python-headless>=4.10" \
  "scipy>=1.14" \
  "tqdm>=4.66" \
  "numba>=0.61" \
  "librosa>=0.10.2" \
  "soundfile>=0.12.1"

mkdir -p checkpoints input output work

echo "Modern Colab kurulumu tamamlandı."
echo "Sonraki adım: Wav2Lip model checkpoint dosyasını checkpoints/wav2lip_gan.pth konumuna eklemek."
