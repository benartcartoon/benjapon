#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/engines/MuseTalk"

if [[ ! -d "$DIR/.git" ]]; then git clone --depth 1 https://github.com/TMElyralab/MuseTalk.git "$DIR"; fi
if [[ ! -x "$DIR/.venv/bin/python" ]]; then uv python install 3.10; uv venv --seed --python 3.10 "$DIR/.venv"; fi
P="$DIR/.venv/bin/python"

if "$P" -c 'import torch, mmpose, mmcv, mmengine, mmdet' >/dev/null 2>&1; then
  echo "MuseTalk paketleri hazir; tekrar kurulum atlandi."
else
  "$P" -m pip install -q -U pip wheel setuptools
  "$P" -m pip install -q "numpy==1.23.5"
  "$P" -m pip install -q torch==2.0.1 torchvision==0.15.2 torchaudio==2.0.2 --index-url https://download.pytorch.org/whl/cu118
  "$P" -m pip install -q -r "$DIR/requirements.txt"
  "$P" -m pip install -q "openmim==0.3.9"
  "$DIR/.venv/bin/mim" install mmengine
  "$DIR/.venv/bin/mim" install "mmcv==2.0.1"
  "$P" -m pip install -q "mmdet==3.1.0" "setuptools<81" "six>=1.16"
  "$P" -m pip install -q --no-build-isolation "chumpy==0.70"
  "$P" -m pip install -q --no-deps "mmpose==1.1.0"
fi

# Resmi betik eski huggingface-cli/gdown sozdizimi kullaniyor. Onu sadece MuseTalk venv'inde calistir.
if [[ ! -f "$DIR/models/musetalkV15/unet.pth" ]]; then
  "$P" -m pip install -q "huggingface-hub==0.36.0" "gdown==5.2.0"
  (cd "$DIR" && PATH="$DIR/.venv/bin:$PATH" bash download_weights.sh)
else
  echo "MuseTalk agirliklari mevcut; indirme atlandi."
fi

# Kritik dosyalar gercekten var mi kontrol et; sahte 'success' mesaji ile devam etme.
for f in \
  "$DIR/models/musetalkV15/unet.pth" \
  "$DIR/models/musetalkV15/musetalk.json" \
  "$DIR/models/sd-vae/config.json" \
  "$DIR/models/sd-vae/diffusion_pytorch_model.bin" \
  "$DIR/models/whisper/config.json" \
  "$DIR/models/whisper/pytorch_model.bin" \
  "$DIR/models/whisper/preprocessor_config.json" \
  "$DIR/models/dwpose/dw-ll_ucoco_384.pth" \
  "$DIR/models/face-parse-bisent/79999_iter.pth" \
  "$DIR/models/face-parse-bisent/resnet18-5c106cde.pth"; do
  [[ -s "$f" ]] || { echo "HATA: MuseTalk agirligi eksik: $f"; exit 8; }
done

"$P" - <<'PY'
import torch, mmpose
print('MuseTalk ortam OK | CUDA:', torch.cuda.is_available(), '| Torch:', torch.__version__, '| mmpose:', mmpose.__version__)
if not torch.cuda.is_available(): raise SystemExit('HATA: MuseTalk CUDA GPU goremedi')
PY
