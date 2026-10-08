"""Copia os FBX completos e texturas do pacote para importação nativa do Godot."""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "raw/carros_abertos"
OUT = ROOT / "game/assets/models/cenario/carros"
TEXTURES = OUT / "texturas_abertos"
FBX_TEXTURES = ROOT / "game/assets/models/Texture/Base"
OUT.mkdir(parents=True, exist_ok=True)
TEXTURES.mkdir(parents=True, exist_ok=True)
FBX_TEXTURES.mkdir(parents=True, exist_ok=True)

for source, target in (
    ("Car.fbx", "carro_sedan_aberto.fbx"),
    ("Police.fbx", "carro_policia_aberto.fbx"),
    ("Taxi.fbx", "carro_taxi_aberto.fbx"),
):
    shutil.copy2(SOURCE / "Assets" / source, OUT / target)

for image in (SOURCE / "Texture").glob("*.png"):
    shutil.copy2(image, TEXTURES / image.name)
    shutil.copy2(image, FBX_TEXTURES / image.name)

# O FBX do sedã referencia este nome antigo dentro do pacote.
shutil.copy2(SOURCE / "Texture/Car_color.png", FBX_TEXTURES / "Car_base_color.png")

print("FBX completos e texturas preparados em", OUT)
