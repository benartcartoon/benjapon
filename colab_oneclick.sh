#!/usr/bin/env bash
set -euo pipefail

DRIVE_ROOT="${BENJAPON_DRIVE:-/content/drive/MyDrive/BenJapon}"
INPUT_DIR="$DRIVE_ROOT/input"
OUTPUT_DIR="$DRIVE_ROOT/output"
CACHE_DIR="$DRIVE_ROOT/cache"
MODEL_DIR="$DRIVE_ROOT/models"
LS_DRIVE="$DRIVE_ROOT/engines/LatentSync"
ENV_CACHE="$DRIVE_ROOT/env_cache"
WORK="/content/benjapon_work"
LS_CODE="/content/LatentSync"
LS_ENV="/content/latentsync_env"
XTTS_ENV="/content/xtts_env"
LS_ARCHIVE="$ENV_CACHE/latentsync_env_v2.tar.zst"
XTTS_ARCHIVE="$ENV_CACHE/xtts_env_v2.tar.zst"

[[ -d /content/drive/MyDrive ]] || { echo "HATA: Google Drive bagli degil."; exit 1; }
command -v nvidia-smi >/dev/null 2>&1 || { echo "HATA: T4 GPU acik degil."; exit 2; }
mkdir -p "$INPUT_DIR" "$OUTPUT_DIR" "$CACHE_DIR" "$MODEL_DIR" "$LS_DRIVE/checkpoints/whisper" "$ENV_CACHE" "$WORK"

if [[ $# -ge 1 && -n "${1:-}" ]]; then
  if [[ "$1" = /* ]]; then INPUT="$1"; else INPUT="$INPUT_DIR/$1"; fi
else
  INPUT=$(find "$INPUT_DIR" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.mkv' -o -iname '*.webm' \) -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2- || true)
fi
[[ -n "${INPUT:-}" && -f "$INPUT" ]] || { echo "HATA: Video bulunamadi: ${INPUT:-bos}"; exit 3; }
STEM="$(basename "$INPUT")"; STEM="${STEM%.*}"
SRC_WAV="$WORK/${STEM}_tr.wav"
TR_TXT="$WORK/${STEM}_tr.txt"
JA_TXT="$WORK/${STEM}_ja.txt"
JA_WAV="$WORK/${STEM}_ja.wav"
FINAL="$OUTPUT_DIR/${STEM}_JA.mp4"

echo "=============================================="
echo "BenJapon ONE CLICK - FAST"
echo "VIDEO: $INPUT"
echo "CIKTI: $FINAL"
echo "=============================================="

export HF_HOME="$CACHE_DIR/huggingface"
export TRANSFORMERS_CACHE="$HF_HOME"
export PIP_CACHE_DIR="$CACHE_DIR/pip"
export TTS_HOME="$CACHE_DIR/tts"
export MPLBACKEND=Agg
export COQUI_TOS_AGREED=1
export UV_CACHE_DIR="/content/uv-cache"
mkdir -p "$HF_HOME" "$PIP_CACHE_DIR" "$TTS_HOME" "$UV_CACHE_DIR"

# Temel araclar. zstd, hazir Python ortamlarini tek buyuk dosya olarak Drive'a kaydetmek/acmak icin kullanilir.
apt-get update -qq
apt-get install -y -qq ffmpeg git curl wget libgl1 libglib2.0-0 build-essential zstd >/dev/null
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# Venv icindeki Python symlinklerinin hedefi her yeni Colab oturumunda yeniden gerekir.
uv python install 3.10 3.11 >/dev/null

# LatentSync kodu kucuk oldugu icin yerelde taze tutulur; agir modeller Drive'da kalir.
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

# -------- HIZLI ORTAM YUKLEME --------
# Ilk calismada kurulur ve Drive'a arsivlenir. Sonraki oturumlarda yuzlerce paket yeniden kurulmaz.
restore_env() {
  local archive="$1" envdir="$2" label="$3"
  rm -rf "$envdir"
  if [[ -s "$archive" ]]; then
    echo "[FAST] $label hazir ortam Drive'dan aciliyor..."
    tar --zstd -xf "$archive" -C /content
    [[ -x "$envdir/bin/python" ]] || { echo "HATA: $label ortam arsivi bozuk."; rm -f "$archive"; return 1; }
    return 0
  fi
  return 1
}

save_env() {
  local archive="$1" dirname="$2" label="$3"
  local tmp="${archive}.tmp"
  echo "[ILK KURULUM] $label ortami Drive'a kaydediliyor. Bu sadece bir kez uzun surer..."
  rm -f "$tmp"
  tar --zstd -cf "$tmp" -C /content "$dirname"
  mv -f "$tmp" "$archive"
}

if ! restore_env "$LS_ARCHIVE" "$LS_ENV" "LatentSync"; then
  echo "[ILK KURULUM] LatentSync paketleri kuruluyor..."
  uv venv --seed --python 3.10 "$LS_ENV" >/dev/null
  "$LS_ENV/bin/python" -m pip install -q -r "$LS_CODE/requirements.txt"
  save_env "$LS_ARCHIVE" "latentsync_env" "LatentSync"
fi

if ! restore_env "$XTTS_ARCHIVE" "$XTTS_ENV" "XTTS/Whisper"; then
  echo "[ILK KURULUM] XTTS/Whisper paketleri kuruluyor..."
  uv venv --seed --python 3.11 "$XTTS_ENV" >/dev/null
  "$XTTS_ENV/bin/pip" install -q "TTS==0.22.0"
  "$XTTS_ENV/bin/pip" install -q --force-reinstall "transformers==4.40.2" "tokenizers==0.19.1"
  "$XTTS_ENV/bin/pip" install -q --force-reinstall "torch==2.5.1" "torchaudio==2.5.1"
  "$XTTS_ENV/bin/pip" install -q --force-reinstall "numpy==1.26.4"
  "$XTTS_ENV/bin/pip" install -q cutlet unidic-lite openai-whisper sentencepiece deep-translator
  save_env "$XTTS_ARCHIVE" "xtts_env" "XTTS/Whisper"
fi

# LatentSync tek bir karede yuz bulamayinca normalde tum videoyu durdurur.
# Gecici yuz kaybinda son basarili landmark kullanilir.
"$LS_ENV/bin/python" - <<'PY'
from pathlib import Path
p=Path('/content/LatentSync/latentsync/utils/image_processor.py')
s=p.read_text()
s=s.replace(
"        if device == \"cpu\":\n            self.face_detector = None\n        else:\n            self.face_detector = FaceDetector(device=device)\n",
"        if device == \"cpu\":\n            self.face_detector = None\n        else:\n            self.face_detector = FaceDetector(device=device)\n        self._last_landmarks3 = None\n"
)
s=s.replace(
"        if bbox is None:\n            raise RuntimeError(\"Face not detected\")\n\n        pt_left_eye = np.mean(landmark_2d_106[[43, 48, 49, 51, 50]], axis=0)  # left eyebrow center\n        pt_right_eye = np.mean(landmark_2d_106[101:106], axis=0)  # right eyebrow center\n        pt_nose = np.mean(landmark_2d_106[[74, 77, 83, 86]], axis=0)  # nose center\n\n        landmarks3 = np.round([pt_left_eye, pt_right_eye, pt_nose])\n",
"        if bbox is None:\n            if self._last_landmarks3 is None:\n                raise RuntimeError(\"Face not detected in first usable frame\")\n            landmarks3 = self._last_landmarks3\n        else:\n            pt_left_eye = np.mean(landmark_2d_106[[43, 48, 49, 51, 50]], axis=0)\n            pt_right_eye = np.mean(landmark_2d_106[101:106], axis=0)\n            pt_nose = np.mean(landmark_2d_106[[74, 77, 83, 86]], axis=0)\n            landmarks3 = np.round([pt_left_eye, pt_right_eye, pt_nose])\n            self._last_landmarks3 = landmarks3\n"
)
p.write_text(s)
print('LatentSync yuz-kaybi korumasi aktif.')
PY

# XTTS modeli zaten Drive cache'inde kalici tutulur.
LOCAL_XTTS="/root/.local/share/tts/tts_models--multilingual--multi-dataset--xtts_v2"
DRIVE_XTTS="$TTS_HOME/tts_models--multilingual--multi-dataset--xtts_v2"
if [[ -d "$LOCAL_XTTS" && ! -d "$DRIVE_XTTS" ]]; then
  cp -a "$LOCAL_XTTS" "$DRIVE_XTTS"
fi

# -------- 1) Videodan Turkce ses --------
echo "[1/5] Ses cikariliyor..."
ffmpeg -y -i "$INPUT" -vn -ac 1 -ar 16000 "$SRC_WAV" -loglevel error

# -------- 2) Turkce yazi --------
echo "[2/5] Turkce konusma yaziliyor..."
WHISPER_DIR="$MODEL_DIR/whisper"
mkdir -p "$WHISPER_DIR" "$WORK/whisper_out"
WHISPER_HINT="${WHISPER_HINT:-Ünye, Tarık, Berkenis Aydemir}"
"$XTTS_ENV/bin/whisper" "$SRC_WAV" --model small --model_dir "$WHISPER_DIR" --language Turkish --task transcribe --initial_prompt "$WHISPER_HINT" --output_dir "$WORK/whisper_out" --output_format txt >/dev/null
WHISPER_TXT="$WORK/whisper_out/$(basename "${SRC_WAV%.*}").txt"
cp "$WHISPER_TXT" "$TR_TXT"
TR_TEXT=$(cat "$TR_TXT")
[[ -n "$TR_TEXT" ]] || { echo "HATA: Turkce konusma algilanamadi."; exit 10; }
echo "TR: $TR_TEXT"

# -------- 3) Japoncaya ceviri --------
echo "[3/5] Japoncaya cevriliyor..."
TR_INPUT="$TR_TXT" JA_OUTPUT="$JA_TXT" "$XTTS_ENV/bin/python" - <<'PY'
import os, re
src=open(os.environ['TR_INPUT'],encoding='utf-8').read().strip()
if not src: raise SystemExit('HATA: Turkce metin bos.')

def chunks(text, limit=2500):
    parts=re.split(r'(?<=[.!?])\s+|\n+', text)
    out=[]; cur=''
    for part in parts:
        part=part.strip()
        if not part: continue
        if len(cur)+len(part)+1 > limit and cur:
            out.append(cur); cur=part
        else:
            cur=(cur+' '+part).strip()
    if cur: out.append(cur)
    return out

ja=''
try:
    from deep_translator import GoogleTranslator
    tr=GoogleTranslator(source='tr', target='ja')
    ja=' '.join((tr.translate(c) or '').strip() for c in chunks(src)).strip()
    if not ja: raise RuntimeError('Bos ceviri')
    print('Ceviri motoru: Google Translate')
except Exception as e:
    print('Google ceviri kullanilamadi, NLLB yedek motoru devrede:', e)
    import torch
    from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
    model_id='facebook/nllb-200-distilled-600M'
    tok=AutoTokenizer.from_pretrained(model_id, src_lang='tur_Latn')
    model=AutoModelForSeq2SeqLM.from_pretrained(model_id, torch_dtype=torch.float16).to('cuda')
    translated=[]
    for c in chunks(src, 700):
        x=tok(c, return_tensors='pt', truncation=True, max_length=384).to('cuda')
        y=model.generate(**x, forced_bos_token_id=tok.convert_tokens_to_ids('jpn_Jpan'), max_new_tokens=220, num_beams=4, no_repeat_ngram_size=3, repetition_penalty=1.18, early_stopping=True)
        translated.append(tok.batch_decode(y, skip_special_tokens=True)[0].strip())
    ja=' '.join(translated).strip()

sents=re.split(r'(?<=[。！？!?])\s*', ja)
clean=[]
for s in sents:
    s=s.strip()
    if s and (not clean or s != clean[-1]): clean.append(s)
ja=''.join(clean).strip()
if not ja: raise SystemExit('HATA: Japonca ceviri bos.')
open(os.environ['JA_OUTPUT'],'w',encoding='utf-8').write(ja)
print('JA:',ja)
PY

# -------- 4) Japonca ses klonlama --------
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

# -------- 5) Agiz senkronu --------
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
