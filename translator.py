from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
from typing import Literal

import torch
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer

Direction = Literal["tr-ja", "ja-tr"]

MODELS = {
    "tr-ja": "Helsinki-NLP/opus-mt-tr-jap",
    "ja-tr": "Helsinki-NLP/opus-mt-jap-trk",
}


@dataclass
class TranslationResult:
    text: str
    direction: Direction
    model: str
    device: str


def _device() -> str:
    return "cuda" if torch.cuda.is_available() else "cpu"


@lru_cache(maxsize=2)
def _load(direction: Direction):
    model_name = MODELS[direction]
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    model = AutoModelForSeq2SeqLM.from_pretrained(model_name)
    device = _device()
    model.to(device)
    model.eval()
    return tokenizer, model, device


def translate(text: str, direction: Direction = "tr-ja", max_new_tokens: int = 256) -> TranslationResult:
    text = text.strip()
    if not text:
        raise ValueError("Metin boş olamaz.")
    if direction not in MODELS:
        raise ValueError("direction 'tr-ja' veya 'ja-tr' olmalıdır.")

    tokenizer, model, device = _load(direction)
    batch = tokenizer(text, return_tensors="pt", truncation=True, max_length=512)
    batch = {k: v.to(device) for k, v in batch.items()}
    with torch.inference_mode():
        output = model.generate(**batch, max_new_tokens=max_new_tokens, num_beams=4)
    translated = tokenizer.decode(output[0], skip_special_tokens=True).strip()
    return TranslationResult(translated, direction, MODELS[direction], device)


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Türkçe ↔ Japonca çeviri")
    parser.add_argument("text")
    parser.add_argument("--direction", choices=list(MODELS), default="tr-ja")
    args = parser.parse_args()
    print(translate(args.text, args.direction).text)
