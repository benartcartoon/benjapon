#!/usr/bin/env python3
import argparse, gc, os, subprocess, shutil
from pathlib import Path

import soundfile as sf
import torch
from faster_whisper import WhisperModel
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer
from qwen_tts import Qwen3TTSModel

ROOT = Path(__file__).resolve().parent
WORK = ROOT / "work"
OUT = ROOT / "outputs"
WORK.mkdir(exist_ok=True)
OUT.mkdir(exist_ok=True)


def run(cmd, cwd=None):
    print("+", " ".join(map(str, cmd)), flush=True)
    subprocess.run([str(x) for x in cmd], cwd=cwd, check=True)


def extract_audio(video, wav):
    run(["ffmpeg", "-y", "-i", video, "-vn", "-ac", "1", "-ar", "24000", wav])


def transcribe(wav):
    model = WhisperModel("large-v3", device="cuda", compute_type="float16")
    segs, info = model.transcribe(str(wav), language="tr", vad_filter=True, beam_size=5)
    items = list(segs)
    text = " ".join(s.text.strip() for s in items).strip()
    if not text:
        raise RuntimeError("Konusma algilanamadi.")
    ref = text
    del model
    gc.collect(); torch.cuda.empty_cache()
    return text, ref


def translate_tr_ja(text):
    model_id = "facebook/nllb-200-distilled-1.3B"
    tok = AutoTokenizer.from_pretrained(model_id, src_lang="tur_Latn")
    model = AutoModelForSeq2SeqLM.from_pretrained(model_id, dtype=torch.float16).to("cuda")
    chunks, cur = [], ""
    for sent in text.replace("?", "?.").replace("!", "!.").split("."):
        sent = sent.strip()
        if not sent: continue
        if len(cur) + len(sent) < 700: cur += (" " if cur else "") + sent + "."
        else: chunks.append(cur); cur = sent + "."
    if cur: chunks.append(cur)
    out=[]
    for ch in chunks:
        x=tok(ch, return_tensors="pt", truncation=True, max_length=1024).to("cuda")
        y=model.generate(**x, forced_bos_token_id=tok.convert_tokens_to_ids("jpn_Jpan"), max_new_tokens=1024, num_beams=5)
        out.append(tok.batch_decode(y, skip_special_tokens=True)[0])
    del model
    gc.collect(); torch.cuda.empty_cache()
    return " ".join(out)


def make_reference(full_wav, ref_wav):
    run(["ffmpeg", "-y", "-i", full_wav, "-t", "10", "-ac", "1", "-ar", "24000", ref_wav])


def _qwen_cache_is_broken():
    hub = Path(os.environ.get("HF_HOME", ROOT / "cache/huggingface"))
    model_dir = hub / "hub" / "models--Qwen--Qwen3-TTS-12Hz-1.7B-Base"
    if not model_dir.exists():
        model_dir = hub / "models--Qwen--Qwen3-TTS-12Hz-1.7B-Base"
    if not model_dir.exists():
        return False
    snapshots = model_dir / "snapshots"
    if not snapshots.exists():
        return False
    for snap in snapshots.iterdir():
        tok = snap / "speech_tokenizer"
        if tok.exists() and not (tok / "preprocessor_config.json").exists():
            return True
    return False


def _clear_qwen_cache():
    hub = Path(os.environ.get("HF_HOME", ROOT / "cache/huggingface"))
    for p in [hub / "hub" / "models--Qwen--Qwen3-TTS-12Hz-1.7B-Base",
              hub / "models--Qwen--Qwen3-TTS-12Hz-1.7B-Base"]:
        if p.exists():
            print("Eksik Qwen3-TTS onbellegi temizleniyor:", p, flush=True)
            shutil.rmtree(p, ignore_errors=True)


def tts_clone(text_ja, ref_wav, ref_text, out_wav):
    # T4 Turing GPU: FP16 kullan. FlashAttention zorlamiyoruz; kurulu degilse normal PyTorch attention calisir.
    if _qwen_cache_is_broken():
        _clear_qwen_cache()
    kwargs = dict(device_map="cuda:0", dtype=torch.float16)
    try:
        model = Qwen3TTSModel.from_pretrained("Qwen/Qwen3-TTS-12Hz-1.7B-Base", **kwargs)
    except OSError as e:
        # Onceki yarim/bozuk model indirmesini tek sefer otomatik onar.
        if "feature extractor" not in str(e).lower() and "preprocessor_config.json" not in str(e):
            raise
        _clear_qwen_cache()
        model = Qwen3TTSModel.from_pretrained("Qwen/Qwen3-TTS-12Hz-1.7B-Base", **kwargs)
    wavs, sr = model.generate_voice_clone(text=text_ja, language="Japanese", ref_audio=str(ref_wav), ref_text=ref_text, non_streaming_mode=True)
    sf.write(out_wav, wavs[0], sr)
    del model
    gc.collect(); torch.cuda.empty_cache()


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--engine", choices=["latentsync","musetalk"], required=True)
    a=ap.parse_args()
    video=Path(a.input).resolve()
    stem=video.stem
    src=WORK/f"{stem}_src.wav"
    ref=WORK/f"{stem}_ref.wav"
    ja=WORK/f"{stem}_ja.wav"
    final=OUT/f"{stem}_JA.mp4"

    extract_audio(video, src)
    tr_text, ref_text = transcribe(src)
    print("TR:", tr_text)
    ja_text = translate_tr_ja(tr_text)
    print("JA:", ja_text)
    make_reference(src, ref)
    tts_clone(ja_text, ref, ref_text, ja)
    run(["bash", str(ROOT/"scripts/run_lipsync.sh"), a.engine, str(video), str(ja), str(final)])
    print(f"\nHAZIR: {final}")

if __name__ == "__main__": main()
