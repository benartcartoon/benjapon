from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from translator import MODELS, Direction, translate

app = FastAPI(title="BenJapon Translation API", version="1.0.0")


class TranslationRequest(BaseModel):
    text: str = Field(min_length=1, max_length=5000)
    direction: Direction = "tr-ja"


@app.get("/")
def root():
    return {"name": "BenJapon", "status": "ok", "directions": list(MODELS)}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/translate")
def translate_endpoint(request: TranslationRequest):
    try:
        result = translate(request.text, request.direction)
        return {
            "translation": result.text,
            "direction": result.direction,
            "model": result.model,
            "device": result.device,
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
