#!/usr/bin/env bash
set -euo pipefail

DRIVE_ROOT="${BENJAPON_DRIVE:-/content/drive/MyDrive/BenJapon}"
INPUT_DIR="$DRIVE_ROOT/input"
OUTPUT_DIR="$DRIVE_ROOT/output"
CACHE_DIR="$DRIVE_ROOT/cache"
MODEL_DIR="$DRIVE_ROOT/models"
LS_DRIVE="$DRIVE_ROOT/engines/LatentSync"
WORK="/content/benjapon_work"
LS_CODE="/content/LatentSync"
LS_ENV="/content/latentsync_env"
XTTS_ENV="/content/xtts_env"

[[ -d /content/drive/MyDrive ]] || { echo "HATA: Google Drive bagli degil."; exit 1; }
command -v nvidia-smi >/dev/null 2>&1 || { echo "HATA: T4 GPU acik degil."; exit 2; }
mkdir -p "$INPUT_DIR" "$OUTPUT_DIR" "$CACHE_DIR" "$MODEL_DIR" "$LS_DRIVE/checkpoints/whisper" "$WORK"

INPUT=$(find "$INPUT_DIR" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.mkv' -o -iname '*.webm' \) -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2- || true)
[[ -n "${INPUT:-}" && -f "$INPUT" ]] || { echo "HATA: $INPUT_DIR icinde video yok."; exit 3; }
STEM="$(basename "$INPUT")"; STEM="${STEM%.*}"
SRC_WAV="$WORK/${STEM}_tr.wav"
TR_TXT="$WORK/${STEM}_tr.txt"
JA_TXT="$WORK/${STEM}_ja.txt"
JA_WAV="$WORK/${STEM}_ja.wav"
FINAL="$OUTPUT_DIR/${STEM}_JA.mp4"

echo "=============================================="
echo "BenJapon ONE CLICK"
echo "VIDEO: $INPUT"
echo "CIKTI: $FINAL"
echo "=============================================="

export HF_HOME="$CACHE_DIR/huggingface"
export TRANSFORMERS_CACHE="$HF_HOME"
# uv ve pip gecici cache'lerini Google Drive'a koyma; Drive chmod/rename islemlerinde hata verebiliyor.
export UV_CACHE_DIR="/content/.cache/uv"
export PIP_CACHE_DIR="/content/.cache/pip"
export TTS_HOME="$CACHE_DIR/tts"
export MPLBACKEND=Agg
export COQUI_TOS_AGREED=1
mkdir -p "$HF_HOME" "$UV_CACHE_DIR" "$PIP_CACHE_DIR" "$TTS_HOME"

LOCAL_XTTS="/root/.local/share/tts/tts_models--multilingual--multi-dataset--xtts_v2"
DRIVE_XTTS="$TTS_HOME/tts_models--multilingual--multi-dataset--xtts_v2"
if [[ -d "$LOCAL_XTTS" && ! -d "$DRIVE_XTTS" ]]; then
  echo "Mevcut XTTS modeli Drive cache'ine aliniyor..."
  cp -a "$LOCAL_XTTS" "$DRIVE_XTTS"
fi

apt-get update -qq
apt-get install -y -qq ffmpeg git curl libgl1 libglib2.0-0 build-essential >/dev/null
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
fi

rm -rf "$LS_CODE"
git clone -q --depth 1 https://github.com/bytedance/LatentSync.git "$LS_CODE"

if [[ ! -s "$LS_DRIVE/checkpoints/latentsync_unet.pt" ]]; then
  echo "LatentSync UNet ilk kez indiriliyor..."
  wget -q --show-progress -c "https://huggingface.co/ByteDance/LatentSync-1.5/resolve/main/latentsync_unet.pt" -O "$LS_DRIVE/checkpoints/latentsync_unet.pt"
fi
if [[ ! -s "$LS_DRIVE/checkpoints/whisper/tiny.pt" ]]; then
  echo "LatentSync Whisper ilk kez indiriliyor..."
  wget -q --show-progress -c "https://huggingface.co/ByteDance/LatentSync-1.5/resolve/main/whisper/tiny.pt" -O "$LS_DRIVE/checkpoints/whisper/tiny.pt"
fi
rm -rf "$LS_CODE/checkpoints"
ln -s "$LS_DRIVE/checkpoints" "$LS_CODE/checkpoints"

rm -rf "$LS_ENV"
uv python install 3.10 >/dev/null
uv venv --seed --python 3.10 "$LS_ENV" >/dev/null
"$LS_ENV/bin/python" -m pip install -q -r "$LS_CODE/requirements.txt"

rm -rf "$XTTS_ENV"
uv python install 3.11 >/dev/null
uv venv --seed --python 3.11 "$XTTS_ENV" >/dev/null
"$XTTS_ENV/bin/pip" install -q "TTS==0.22.0"
"$XTTS_ENV/bin/pip" install -q --force-reinstall "transformers==4.40.2" "tokenizers==0.19.1"
"$XTTS_ENV/bin/pip" install -q --force-reinstall "torch==2.5.1" "torchaudio==2.5.1"
"$XTTS_ENV/bin/pip" install -q --force-reinstall "numpy==1.26.4"
"$XTTS_ENV/bin/pip" install -q cutlet unidic-lite openai-whisper sentencepiece

echo "[1/5] Ses cikariliyor..."
ffmpeg -y -i "$INPUT" -vn -ac 1 -ar 16000 "$SRC_WAV" -loglevel error

echo "[2/5] Turkce konusma yaziliyor..."
WHISPER_DIR="$MODEL_DIR/whisper"
mkdir -p "$WHISPER_DIR" "$WORK/whisper_out"
"$XTTS_ENV/bin/whisper" "$SRC_WAV" --model small --model_dir "$WHISPER_DIR" --language Turkish --task transcribe --output_dir "$WORK/whisper_out" --output_format txt >/dev/null
WHISPER_TXT="$WORK/whisper_out/$(basename "${SRC_WAV%.*}").txt"
cp "$WHISPER_TXT" "$TR_TXT"
TR_TEXT=$(cat "$TR_TXT")
[[ -n "$TR_TEXT" ]] || { echo "HATA: Turkce konusma algilanamadi."; exit 10; }
echo "TR: $TR_TEXT"

echo "[3/5] Japoncaya cevriliyor..."
TR_INPUT="$TR_TXT" JA_OUTPUT="$JA_TXT" "$XTTS_ENV/bin/python" - <<'PY'
import os, torch
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
src=open(os.environ['TR_INPUT'],encoding='utf-8').read().strip()
model_id='facebook/nllb-200-distilled-600M'
tok=AutoTokenizer.from_pretrained(model_id, src_lang='tur_Latn')
model=AutoModelForSeq2SeqLM.from_pretrained(model_id, torch_dtype=torch.float16).to('cuda')
x=tok(src, return_tensors='pt', truncation=True, max_length=512).to('cuda')
y=model.generate(**x, forced_bos_token_id=tok.convert_tokens_to_ids('jpn_Jpan'), max_new_tokens=512, num_beams=4)
ja=tok.batch_decode(y, skip_special_tokens=True)[0].strip()
open(os.environ['JA_OUTPUT'],'w',encoding='utf-8').write(ja)
print('JA:',ja)
PY

echo "[4/5] Japonca ses klonlaniyor..."
JA_INPUT="$JA_TXT" REF_WAV="$SRC_WAV" JA_WAV="$JA_WAV" "$XTTS_ENV/bin/python" - <<'PY'
import os
os.environ['MPLBACKEND']='Agg'
from TTS.api import TTS
text=open(os.environ['JA_INPUT'],encoding='utf-8').read().strip()
tts=TTS('tts_models/multilingual/multi-dataset/xtts_v2').to('cuda')
tts.tts_to_file(text=text, speaker_wav=os.environ['REF_WAV'], language='ja', file_path=os.environ['JA_WAV'])
print('Japonca ses hazir:',os.environ['JA_WAV'])
PY

echo "[5/5] LatentSync video olusturuyor..."
(cd "$LS_CODE" && MPLBACKEND=Agg "$LS_ENV/bin/python" -m scripts.inference \
  --unet_config_path configs/unet/stage2.yaml \
  --inference_ckpt_path checkpoints/latentsync_unet.pt \
  --video_path "$INPUT" \
  --audio_path "$JA_WAV" \
  --video_out_path "$FINAL")

[[ -s "$FINAL" ]] || { echo "HATA: Final video olusmadi."; exit 20; }
cp -f "$TR_TXT" "$OUTPUT_DIR/${STEM}_TR.txt"
cp -f "$JA_TXT" "$OUTPUT_DIR/${STEM}_JA.txt"
echo ""
echo "=============================================="
echo "HAZIR: $FINAL"
echo "=============================================="
