# BenJapon

Türkçe ↔ Japonca çeviri için Python tabanlı sistem. Google Colab üzerinde GPU varsa otomatik CUDA kullanır; yoksa CPU ile çalışır.

## Özellikler

- Türkçeden Japoncaya çeviri (`tr-ja`)
- Japoncadan Türkçeye çeviri (`ja-tr`)
- Hugging Face Transformers tabanlı model çalıştırma
- CUDA/CPU otomatik seçimi
- Python fonksiyonu, komut satırı ve FastAPI arayüzü
- Google Colab'a hazır kurulum

## Colab kurulumu

```python
!git clone https://github.com/benartcartoon/benjapon.git
%cd benjapon
!pip install -r requirements.txt
```

```python
from translator import translate
print(translate("Gözler kalbin aynasıdır.", "tr-ja").text)
```

## Terminal

```bash
python translator.py "Merhaba, nasılsın?" --direction tr-ja
```

## API

```bash
uvicorn app:app --host 0.0.0.0 --port 8000
```

`POST /translate` gövdesi:

```json
{
  "text": "Merhaba, nasılsın?",
  "direction": "tr-ja"
}
```

## Dosyalar

- `translator.py`: çeviri motoru
- `app.py`: HTTP API
- `colab_setup.py`: Colab/GPU ortam kontrolü
- `requirements.txt`: bağımlılıklar

Not: İlk çalıştırmada seçilen model indirilir; bu yüzden ilk başlangıç sonraki çalıştırmalardan daha uzun sürebilir.
