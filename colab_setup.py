"""Google Colab başlangıç yardımcısı.

Colab hücresinde:
    !git clone https://github.com/benartcartoon/benjapon.git
    %cd benjapon
    !pip install -r requirements.txt

Sonra:
    from translator import translate
    print(translate("Gözler kalbin aynasıdır.", "tr-ja").text)
"""

import torch


def environment_info():
    return {
        "cuda_available": torch.cuda.is_available(),
        "gpu": torch.cuda.get_device_name(0) if torch.cuda.is_available() else None,
    }


if __name__ == "__main__":
    print(environment_info())
