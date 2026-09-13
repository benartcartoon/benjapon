#!/usr/bin/env bash
set -euo pipefail
ENGINE="$1"; VIDEO="$2"; AUDIO="$3"; OUT="$4"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$(dirname "$OUT")"

if [[ "$ENGINE" == "latentsync" ]]; then
  D="$ROOT/engines/LatentSync"
  (cd "$D" && "$D/.venv/bin/python" -m scripts.inference \
    --unet_config_path configs/unet/stage2_512.yaml \
    --inference_ckpt_path checkpoints/latentsync_unet.pt \
    --inference_steps 30 \
    --guidance_scale 1.5 \
    --enable_deepcache \
    --video_path "$VIDEO" \
    --audio_path "$AUDIO" \
    --video_out_path "$OUT")
else
  D="$ROOT/engines/MuseTalk"
  CFG="$ROOT/work/musetalk_job.yaml"
  RES="$ROOT/work/musetalk_result"
  rm -rf "$RES" && mkdir -p "$RES"
  cat > "$CFG" <<EOF
task_0:
 video_path: "$VIDEO"
 audio_path: "$AUDIO"
EOF
  # Colab MPLBACKEND=module://matplotlib_inline... degerini alt surece aktarir.
  # MuseTalk venv'inde inline backend yok; headless inference icin Agg'yi burada da zorla.
  (cd "$D" && MPLBACKEND=Agg "$D/.venv/bin/python" -m scripts.inference \
    --inference_config "$CFG" \
    --result_dir "$RES" \
    --unet_model_path models/musetalkV15/unet.pth \
    --unet_config models/musetalkV15/musetalk.json \
    --version v15 \
    --ffmpeg_path "$(dirname "$(command -v ffmpeg)")")
  FOUND=$(find "$RES" -type f -name '*.mp4' | head -1)
  if [[ -z "$FOUND" ]]; then echo "HATA: MuseTalk cikti videosu bulunamadi"; exit 9; fi
  cp "$FOUND" "$OUT"
fi

echo "Lip-sync tamamlandi: $OUT"
