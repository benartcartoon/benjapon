#!/usr/bin/env bash
set -euo pipefail

DRIVE_ROOT="${BENJAPON_DRIVE:-/content/drive/MyDrive/BenJapon}"
INPUT_DIR="$DRIVE_ROOT/input"
OUTPUT_DIR="$DRIVE_ROOT/output"
CACHE_DIR="$DRIVE_ROOT/cache"
MODEL_DIR="$DRIVE_ROOT/models"
MT_DRIVE="$MODEL_DIR/MuseTalk"
ENV_CACHE="$DRIVE_ROOT/env_cache"
WORK="/content/benjapon_work"
MT_CODE="/content/MuseTalk"
MT_ENV="/content/musetalk_env"
XTTS_ENV="/content/xtts_env"
MT_ARCHIVE="$ENV_CACHE/musetalk_env_v15.tar.zst"
XTTS_ARCHIVE="$ENV_CACHE/xtts_env_v2.tar.zst"

[[ -d /content/drive/MyDrive ]] || { echo "HATA: Google Drive bagli degil."; exit 1; }
command -v nvidia-smi >/dev/null 2>&1 || { echo "HATA: GPU acik degil."; exit 2; }
mkdir -p "$INPUT_DIR" "$OUTPUT_DIR" "$CACHE_DIR" "$MODEL_DIR" "$ENV_CACHE" "$WORK"

if [[ $# -ge 1 && -n "${1:-}" ]]; then
  [[ "$1" = /* ]] && INPUT="$1" || INPUT="$INPUT_DIR/$1"
else
  INPUT=$(find "$INPUT_DIR" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.mkv' -o -iname '*.webm' \) -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2- || true)
fi
[[ -n "${INPUT:-}" && -f "$INPUT" ]] || { echo "HATA: Video bulunamadi: ${INPUT:-bos}"; exit 3; }
STEM="$(basename "$INPUT")"; STEM="${STEM%.*}"
SRC_WAV="$WORK/${STEM}_tr.wav"
TR_TXT="$WORK/${STEM}_tr.txt"
JA_TXT="$WORK/${STEM}_ja.txt"
JA_WAV="$WORK/${STEM}_ja.wav"
MT_INPUT="$WORK/${STEM}_musetalk_input.mp4"
FINAL="$OUTPUT_DIR/${STEM}_JA.mp4"

export HF_HOME="$CACHE_DIR/huggingface"
export TRANSFORMERS_CACHE="$HF_HOME"
export PIP_CACHE_DIR="$CACHE_DIR/pip"
export TTS_HOME="$CACHE_DIR/tts"
export MPLBACKEND=Agg
export COQUI_TOS_AGREED=1
mkdir -p "$HF_HOME" "$PIP_CACHE_DIR" "$TTS_HOME"

apt-get update -qq
apt-get install -y -qq ffmpeg git curl libgl1 libglib2.0-0 build-essential zstd >/dev/null
if ! command -v uv >/dev/null 2>&1; then curl -LsSf https://astral.sh/uv/install.sh | sh; fi
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
uv python install 3.10 3.11 >/dev/null

rm -rf "$MT_CODE"
git clone -q --depth 1 https://github.com/TMElyralab/MuseTalk.git "$MT_CODE"

# Drive'da bir kez indirilmis modelleri MuseTalk'in bekledigi yerlere bagla.
mkdir -p "$MT_CODE/models"
for d in musetalkV15 sd-vae whisper dwpose face-parse-bisent; do
  [[ -d "$MT_DRIVE/$d" ]] || { echo "HATA: MuseTalk model klasoru eksik: $MT_DRIVE/$d"; exit 4; }
  rm -rf "$MT_CODE/models/$d"
  ln -s "$MT_DRIVE/$d" "$MT_CODE/models/$d"
done

restore_env() {
  local archive="$1" envdir="$2" label="$3"
  rm -rf "$envdir"
  if [[ -s "$archive" ]]; then
    echo "[FAST] $label hazir ortam Drive'dan aciliyor..."
    tar --zstd -xf "$archive" -C /content
    [[ -x "$envdir/bin/python" ]] && return 0
    rm -f "$archive"
  fi
  return 1
}
save_env() {
  local archive="$1" dirname="$2" label="$3"
  echo "[ILK KURULUM] $label ortami Drive'a kaydediliyor..."
  tar --zstd -cf "${archive}.tmp" -C /content "$dirname"
  mv -f "${archive}.tmp" "$archive"
}

if ! restore_env "$MT_ARCHIVE" "$MT_ENV" "MuseTalk 1.5"; then
  echo "[ILK KURULUM] MuseTalk 1.5 paketleri kuruluyor..."
  uv venv --seed --python 3.10 "$MT_ENV" >/dev/null
  "$MT_ENV/bin/pip" install -q -r "$MT_CODE/requirements.txt"
  save_env "$MT_ARCHIVE" "musetalk_env" "MuseTalk 1.5"
fi

if ! restore_env "$XTTS_ARCHIVE" "$XTTS_ENV" "XTTS/Whisper"; then
  echo "[ILK KURULUM] XTTS/Whisper paketleri kuruluyor..."
  uv venv --seed --python 3.11 "$XTTS_ENV" >/dev/null
  "$XTTS_ENV/bin/pip" install -q "TTS==0.22.0"
  "$XTTS_ENV/bin/pip" install -q --force-reinstall "transformers==4.40.2" "tokenizers==0.19.1" "torch==2.5.1" "torchaudio==2.5.1" "numpy==1.26.4"
  "$XTTS_ENV/bin/pip" install -q cutlet unidic-lite openai-whisper sentencepiece deep-translator
  save_env "$XTTS_ARCHIVE" "xtts_env" "XTTS/Whisper"
fi

echo "=============================================="
echo "BenJapon - MuseTalk 1.5"
echo "VIDEO: $INPUT"
echo "CIKTI: $FINAL"
echo "=============================================="

echo "[1/5] Ses cikariliyor..."
ffmpeg -y -i "$INPUT" -vn -ac 1 -ar 16000 "$SRC_WAV" -loglevel error

echo "[2/5] Turkce konusma yaziliyor..."
mkdir -p "$MODEL_DIR/whisper" "$WORK/whisper_out"
WHISPER_HINT="${WHISPER_HINT:-Ünye, Tarık, Berkenis Aydemir}"
"$XTTS_ENV/bin/whisper" "$SRC_WAV" --model small --model_dir "$MODEL_DIR/whisper" --language Turkish --task transcribe --initial_prompt "$WHISPER_HINT" --output_dir "$WORK/whisper_out" --output_format txt >/dev/null
cp "$WORK/whisper_out/$(basename "${SRC_WAV%.*}").txt" "$TR_TXT"
[[ -s "$TR_TXT" ]] || { echo "HATA: Turkce konusma algilanamadi."; exit 10; }

echo "[3/5] Japoncaya cevriliyor..."
TR_INPUT="$TR_TXT" JA_OUTPUT="$JA_TXT" "$XTTS_ENV/bin/python" - <<'PY'
import os,re
src=open(os.environ['TR_INPUT'],encoding='utf-8').read().strip()
def chunks(text,limit=2500):
    parts=re.split(r'(?<=[.!?])\s+|\n+',text); out=[]; cur=''
    for p in parts:
        p=p.strip()
        if not p: continue
        if len(cur)+len(p)+1>limit and cur: out.append(cur); cur=p
        else: cur=(cur+' '+p).strip()
    if cur: out.append(cur)
    return out
ja=''
try:
    from deep_translator import GoogleTranslator
    t=GoogleTranslator(source='tr',target='ja')
    ja=' '.join((t.translate(c) or '').strip() for c in chunks(src)).strip()
    if not ja: raise RuntimeError('Bos ceviri')
except Exception as e:
    print('Google ceviri kullanilamadi, NLLB devrede:',e)
    import torch
    from transformers import AutoTokenizer,AutoModelForSeq2SeqLM
    mid='facebook/nllb-200-distilled-600M'; tok=AutoTokenizer.from_pretrained(mid,src_lang='tur_Latn')
    model=AutoModelForSeq2SeqLM.from_pretrained(mid,torch_dtype=torch.float16).to('cuda')
    out=[]
    for c in chunks(src,700):
        x=tok(c,return_tensors='pt',truncation=True,max_length=384).to('cuda')
        y=model.generate(**x,forced_bos_token_id=tok.convert_tokens_to_ids('jpn_Jpan'),max_new_tokens=220,num_beams=4,no_repeat_ngram_size=3,repetition_penalty=1.18)
        out.append(tok.batch_decode(y,skip_special_tokens=True)[0].strip())
    ja=' '.join(out).strip()
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
tts.tts_to_file(text=text,speaker_wav=os.environ['REF_WAV'],language='ja',file_path=os.environ['JA_WAV'])
PY

echo "[5/5] MuseTalk 1.5 dudak senkronu..."
ffmpeg -y -i "$INPUT" -vf "scale='min(1280,iw)':'min(720,ih)':force_original_aspect_ratio=decrease,scale=trunc(iw/2)*2:trunc(ih/2)*2,fps=25" -an -c:v libx264 -preset veryfast -crf 18 -pix_fmt yuv420p "$MT_INPUT" -loglevel error

CFG="$MT_CODE/configs/inference/benjapon.yaml"
cat > "$CFG" <<EOF
benjapon:
  video_path: "$MT_INPUT"
  audio_path: "$JA_WAV"
  result_name: "$FINAL"
EOF

(cd "$MT_CODE" && PYTHONUNBUFFERED=1 "$MT_ENV/bin/python" -u -m scripts.inference \
  --inference_config "$CFG" \
  --result_dir "$WORK/musetalk_results" \
  --unet_model_path models/musetalkV15/unet.pth \
  --unet_config models/musetalkV15/musetalk.json \
  --whisper_dir models/whisper \
  --version v15 --use_float16 --batch_size 8 --fps 25)

[[ -s "$FINAL" ]] || { echo "HATA: Final video olusmadi."; exit 20; }
cp -f "$TR_TXT" "$OUTPUT_DIR/${STEM}_TR.txt"
cp -f "$JA_TXT" "$OUTPUT_DIR/${STEM}_JA.txt"
echo "=============================================="
echo "HAZIR: $FINAL"
echo "=============================================="
