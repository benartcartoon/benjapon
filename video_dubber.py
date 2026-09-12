from __future__ import annotations

import os
import subprocess
from pathlib import Path

import torch
import whisper

from translator import translate


def run(cmd: list[str], cwd: str | None = None, env: dict | None = None) -> None:
    subprocess.run(cmd, check=True, cwd=cwd, env=env)


def extract_audio(video: str, audio: str) -> None:
    run(["ffmpeg", "-y", "-i", video, "-vn", "-ac", "1", "-ar", "24000", audio])


def transcribe_turkish(audio: str, model_size: str = "small") -> str:
    device = "cuda" if torch.cuda.is_available() else "cpu"
    model = whisper.load_model(model_size, device=device)
    result = model.transcribe(audio, language="tr", fp16=(device == "cuda"))
    return result["text"].strip()


def clone_voice_japanese(text: str, reference_audio: str, output: str, xtts_python: str = "/content/xtts_env/bin/python") -> None:
    """Run XTTS-v2 in an isolated Python environment to avoid Transformers conflicts."""
    if not Path(xtts_python).exists():
        raise RuntimeError("XTTS ortamı yok. Önce setup_voice_clone_colab.sh çalıştırılmalı.")

    script = r'''
import sys
import torch
from TTS.api import TTS
text, reference_audio, output = sys.argv[1:4]
device = "cuda" if torch.cuda.is_available() else "cpu"
tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2").to(device)
tts.tts_to_file(text=text, speaker_wav=reference_audio, language="ja", file_path=output)
print("XTTS Japanese voice created:", output)
'''
    env = os.environ.copy()
    env["COQUI_TOS_AGREED"] = "1"
    run([xtts_python, "-c", script, text, reference_audio, output], env=env)


def wav2lip(video: str, audio: str, output: str, wav2lip_dir: str, checkpoint: str) -> None:
    inference = str(Path(wav2lip_dir) / "inference.py")
    if not Path(inference).exists():
        raise RuntimeError(f"Wav2Lip inference.py bulunamadı: {inference}")
    if not Path(checkpoint).exists():
        raise RuntimeError(f"Wav2Lip checkpoint bulunamadı: {checkpoint}")
    run([
        "python", inference,
        "--checkpoint_path", checkpoint,
        "--face", video,
        "--audio", audio,
        "--outfile", output,
    ], cwd=wav2lip_dir)


def dub_video(
    input_video: str,
    output_video: str = "japonca_final.mp4",
    workdir: str = "work",
    wav2lip_dir: str = "Wav2Lip",
    wav2lip_checkpoint: str = "checkpoints/wav2lip_gan.pth",
    xtts_python: str = "/content/xtts_env/bin/python",
) -> dict:
    """One shot: Turkish video -> Japanese -> same speaker voice -> lip-synced MP4."""
    work = Path(workdir)
    work.mkdir(parents=True, exist_ok=True)
    source_audio = str(work / "source_voice.wav")
    japanese_audio = str(work / "japanese_cloned.wav")

    extract_audio(input_video, source_audio)
    turkish_text = transcribe_turkish(source_audio)
    japanese_text = translate(turkish_text, "tr-ja").text
    clone_voice_japanese(japanese_text, source_audio, japanese_audio, xtts_python)
    wav2lip(input_video, japanese_audio, output_video, wav2lip_dir, wav2lip_checkpoint)

    return {
        "turkish_text": turkish_text,
        "japanese_text": japanese_text,
        "japanese_audio": japanese_audio,
        "output_video": output_video,
        "voice_cloned": True,
        "lip_sync": True,
    }


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Türkçe videoyu aynı konuşmacının sesiyle Japonca ve dudak senkronlu üret")
    parser.add_argument("input_video")
    parser.add_argument("--output", default="japonca_final.mp4")
    parser.add_argument("--wav2lip-dir", default="Wav2Lip")
    parser.add_argument("--wav2lip-checkpoint", default="checkpoints/wav2lip_gan.pth")
    parser.add_argument("--xtts-python", default="/content/xtts_env/bin/python")
    args = parser.parse_args()
    print(dub_video(args.input_video, args.output, wav2lip_dir=args.wav2lip_dir, wav2lip_checkpoint=args.wav2lip_checkpoint, xtts_python=args.xtts_python))
