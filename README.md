# BenJapon — Türkçe videodan tek komutla Japonca dublaj

Hedef: Türkçe konuştuğun videoyu alır; konuşmayı çözer, Japoncaya çevirir, Qwen3-TTS ile senin ses karakterinden Japonca konuşma üretir ve MuseTalk 1.5 ile ağız hareketlerini yeni sese uyarlar.

## Google Colab: SADECE TEK HÜCRE

Colab çalışma zamanını **T4 GPU** yap, videonu `/content/video.mp4` adıyla yükle ve yalnızca şu hücreyi çalıştır:

```python
!rm -rf /content/benjapon && git clone -q https://github.com/benartcartoon/benjapon.git /content/benjapon && cd /content/benjapon && bash oneclick.sh /content/video.mp4
```

Başka kurulum hücresi yok. Paketler, Python ortamları, modeller ve lip-sync motoru GitHub'daki `oneclick.sh` tarafından hazırlanır.

Çıktı:

`/content/benjapon/outputs/video_JA.mp4`

## T4 mimarisi

- ASR: faster-whisper large-v3
- Çeviri: NLLB-200 distilled 1.3B (`tur_Latn` -> `jpn_Jpan`)
- Ses klonlama: Qwen/Qwen3-TTS-12Hz-1.7B-Base
- Lip-sync: MuseTalk 1.5
- Video/audio: FFmpeg
- Ana ortam: izole Python 3.12
- MuseTalk: ayrı izole Python 3.10 + kendi CUDA/PyTorch/MMLab bağımlılıkları

Bu ayrım özellikle güncel Google Colab sistem Python'u ile MuseTalk'ın eski MMLab bağımlılıklarının çakışmasını önlemek için vardır.

## Kullanım notu

İlk çalıştırma model ve paketleri indireceği için uzun sürer. Aynı runtime içinde sonraki çalıştırmalar önbellekten yararlanır. Runtime tamamen silinirse Colab'ın geçici diskindeki modeller de silinir ve yeniden indirilir.

En iyi ses klonu için videoda tek konuşmacı ve birkaç saniyelik temiz konuşma bulunması önerilir.
