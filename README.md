# BenJapon — Türkçe videodan tek komutla Japonca dublaj

Hedef: Türkçe konuştuğun videoyu alır; konuşmayı çözer, Japoncaya çevirir, Qwen3-TTS ile senin ses karakterinden Japonca konuşma üretir ve MuseTalk 1.5 ile ağız hareketlerini yeni sese uyarlar.

## Google Colab: SADECE TEK HÜCRE

Colab çalışma zamanını **T4 GPU** yap, videonu yükle ve yalnızca şu hücreyi çalıştır. Repo daha önce indirilmişse SILMEZ; yalnızca GitHub'daki yeni kodları çeker. Böylece aynı Colab oturumunda indirilen ortamlar ve modeller korunur.

```python
!if [ -d /content/benjapon/.git ]; then cd /content/benjapon && git pull --ff-only; else git clone -q https://github.com/benartcartoon/benjapon.git /content/benjapon; fi; cd /content/benjapon && bash oneclick.sh "/content/VID_20260905_191202.mp4"
```

Başka kurulum hücresi yok. Paketler, Python ortamları, modeller ve lip-sync motoru GitHub'daki `oneclick.sh` tarafından hazırlanır.

Çıktı:

`/content/benjapon/outputs/VID_20260905_191202_JA.mp4`

## T4 mimarisi

- ASR: faster-whisper large-v3
- Çeviri: NLLB-200 distilled 1.3B (`tur_Latn` -> `jpn_Jpan`)
- Ses klonlama: Qwen/Qwen3-TTS-12Hz-1.7B-Base
- Lip-sync: MuseTalk 1.5
- Video/audio: FFmpeg
- Ana ortam: izole Python 3.12
- MuseTalk: ayrı izole Python 3.10 + kendi CUDA/PyTorch/MMLab bağımlılıkları

## Kullanım notu

İlk çalıştırma model ve paketleri indireceği için uzun sürer. Aynı runtime içinde sonraki çalıştırmalarda `/content/benjapon` silinmediği için indirilmiş dosyalar korunur. GitHub'da hata düzeltmesi yapıldığında aynı hücre tekrar çalıştırılır ve `git pull` yalnızca değişen kodu getirir.

**Colab runtime tamamen kapatılır/silinirse** `/content` geçici diski de silinebilir; bu durumda modellerin yeniden indirilmesi gerekir.

En iyi ses klonu için videoda tek konuşmacı ve birkaç saniyelik temiz konuşma bulunması önerilir.
