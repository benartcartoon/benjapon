# BenJapon — tek komut Japonca dublaj

Amaç: Türkçe konuşulan bir videoyu al, konuşmayı yazıya dök, Japoncaya çevir, aynı konuşmacının sesini Qwen3-TTS ile klonla ve videoyu yeni Japonca sese göre dudak senkronla.

## Tek komut

GPU sunucusunda:

```bash
git clone https://github.com/benartcartoon/benjapon.git && cd benjapon && bash oneclick.sh /path/video.mp4
```

İlk çalıştırmada ortam ve model dosyaları indirilir. Sonraki videolarda aynı önbellek kullanılır.

Çıktı: `outputs/<video_adi>_JA.mp4`

## Kalite seçimi
- 18 GB ve üzeri VRAM: LatentSync 1.6, 512px, 30 inference step.
- 8–17 GB VRAM: MuseTalk 1.5.
- 8 GB altı: bilinçli olarak durur; düşük kaliteli minimum kurulum yapılmaz.

## Ana bileşenler
- ASR: faster-whisper large-v3
- Çeviri: NLLB-200 distilled 1.3B (Türkçe -> Japonca)
- Ses klonlama: Qwen/Qwen3-TTS-12Hz-1.7B-Base
- Lip-sync: ByteDance LatentSync 1.6 veya MuseTalk 1.5
- Video/audio: FFmpeg

## Not
En iyi ses klonu için videoda tek konuşmacı, temiz ses ve en az birkaç saniyelik net konuşma bulunması gerekir.
