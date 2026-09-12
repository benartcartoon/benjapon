from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
from typing import Literal

import torch
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer

Direction = Literal["tr-ja", "ja-tr"]

MODEL_NAME = "facebook/nllb-200-distilled-600M"
LANGS = {
    "tr-ja": ("tur_Latn", "jpn_Jpan"),
    "ja-tr": ("jpn_Jpan", "tur_Latn"),
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
def _load(src_lang: str):
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME, src_lang=src_lang)
    model = AutoModelForSeq2SeqLM.from_pretrained(MODEL_NAME)
    device = _device()
    model.to(device)
    model.eval()
    return tokenizer, model, device


def translate(text: str, direction: Direction = "tr-ja", max_new_tokens: int = 256) -> TranslationResult:
    text = text.strip()
    if not text:
        raise ValueError("Metin boş olamaz.")
    if direction not in LANGS:
        raise ValueError("direction 'tr-ja' veya 'ja-tr' olmalıdır.")

    src_lang, tgt_lang = LANGS[direction]
    tokenizer, model, device = _load(src_lang)
    tokenizer.src_lang = src_lang

    batch = tokenizer(text, return_tensors="pt", truncation=True, max_length=512)
    batch = {k: v.to(device) for k, v in batch.items()}

    forced_bos_token_id = tokenizer.convert_tokens_to_ids(tgt_lang)
    with torch.inference_mode():
        output = model.generate(
            **batch,
            forced_bos_token_id=forced_bos_token_id,
            max_new_tokens=max_new_tokens,
            num_beams=4,
        )

    translated = tokenizer.decode(output[0], skip_special_tokens=True).strip()
    return TranslationResult(translated, direction, MODEL_NAME, device)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Türkçe ↔ Japonca çeviri")
    parser.add_argument("text")
    parser.add_argument("--direction", choices=list(LANGS), default="tr-ja")
    args = parser.parse_args()
    print(translate(args.text, args.direction).text)
