#!/usr/bin/env bash
set -e

apt-get update -qq
apt-get install -y -qq ffmpeg
pip install -r requirements.txt

# Lip-sync motoru ayrı açık kaynak bileşen olarak Colab'a alınır.
if [ ! -d Wav2Lip ]; then
  git clone https://github.com/Rudrabha/Wav2Lip.git
fi
pip install -r Wav2Lip/requirements.txt || true

mkdir -p checkpoints input output work

echo "Kurulum tamamlandı. Wav2Lip checkpoint dosyasını checkpoints/wav2lip_gan.pth konumuna ekleyin."
