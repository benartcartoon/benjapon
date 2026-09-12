from __future__ import annotations

import asyncio
import subprocess
from pathlib import Path

import edge_tts
import torch
import whisper

from translator import translate


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def extract_audio(video: str, audio: str) -> None:
    run(["ffmpeg", "-y", "-i", video, "-vn", "-ac", "1", "-ar", "16000", audio])


def transcribe_turkish(audio: str, model_size: str = "small") -> str:
    device = "cuda" if torch.cuda.is_available() else "cpu"
    model = whisper.load_model(model_size, device=device)
    result = model.transcribe(audio, language="tr", fp16=(device == "cuda"))
    return result["text"].strip()


async def _tts(text: str, output: str, voice: str) -> None:
    await edge_tts.Communicate(text=text, voice=voice).save(output)


def japanese_voice(text: str, output: str, voice: str = "ja-JP-NanamiNeural") -> None:
    asyncio.run(_tts(text, output, voice))


def replace_audio(video: str, audio: str, output: str) -> None:
    run([
        "ffmpeg", "-y", "-i", video, "-i", audio,
        "-map", "0:v:0", "-map", "1:a:0", "-c:v", "copy",
        "-c:a", "aac", "-shortest", output,
    ])


def wav2lip(video: str, audio: str, output: str, wav2lip_dir: str, checkpoint: str) -> None:
    inference = str(Path(wav2lip_dir) / "inference.py")
    run([
        "python", inference,
        "--checkpoint_path", checkpoint,
        "--face", video,
        "--audio", audio,
        "--outfile", output,
    ])


def dub_video(
    input_video: str,
    output_video: str = "output_japanese.mp4",
    workdir: str = "work",
    voice: str = "ja-JP-NanamiNeural",
    wav2lip_dir: str | None = None,
    wav2lip_checkpoint: str | None = None,
) -> dict:
    """Türkçe videoyu yazıya çevirir, Japoncaya çevirir, Japonca ses üretir ve videoya uygular.

    Wav2Lip yolu ve checkpoint verilirse ağız hareketleri yeni Japonca sese göre senkronlanır.
    """
    work = Path(workdir)
    work.mkdir(parents=True, exist_ok=True)
    source_audio = str(work / "source_tr.wav")
    japanese_audio = str(work / "japanese.mp3")

    extract_audio(input_video, source_audio)
    turkish_text = transcribe_turkish(source_audio)
    japanese_text = translate(turkish_text, "tr-ja").text
    japanese_voice(japanese_text, japanese_audio, voice)

    if wav2lip_dir and wav2lip_checkpoint:
        wav2lip(input_video, japanese_audio, output_video, wav2lip_dir, wav2lip_checkpoint)
        lip_sync = True
    else:
        replace_audio(input_video, japanese_audio, output_video)
        lip_sync = False

    return {
        "turkish_text": turkish_text,
        "japanese_text": japanese_text,
        "output_video": output_video,
        "lip_sync": lip_sync,
    }


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Türkçe videoyu Japonca dublajla yeniden üret")
    parser.add_argument("input_video")
    parser.add_argument("--output", default="output_japanese.mp4")
    parser.add_argument("--wav2lip-dir")
    parser.add_argument("--wav2lip-checkpoint")
    args = parser.parse_args()
    print(dub_video(args.input_video, args.output, wav2lip_dir=args.wav2lip_dir, wav2lip_checkpoint=args.wav2lip_checkpoint))
