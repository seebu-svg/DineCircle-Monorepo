"""Regenerates the website's structured-data logo from the branding master.

Organization JSON-LD needs a raster logo at least 112x112 (search engines do
not reliably accept the SVG favicon), so the master artwork is flattened onto
the brand cream and saved at 600x600. Run from anywhere:

    python3 website/tool/brand_assets.py
"""
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[2]
SOURCE = REPO / "DineCircle-master" / "assets" / "branding" / "dinecircle_logo.png"
OUT_DIR = REPO / "website" / "assets" / "images"
SIZE = 600
BACKGROUND = (255, 248, 242)  # --cream, so the mark reads the same on any surface


def build():
    master = Image.open(SOURCE).convert("RGBA")
    pad = round(master.width * 0.06)
    canvas = Image.new("RGBA", (master.width + pad * 2, master.height + pad * 2), BACKGROUND + (255,))
    canvas.paste(master, (pad, pad), master)
    logo = canvas.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    target = OUT_DIR / "logo.png"
    logo.save(target, "PNG", optimize=True)
    print(f"{target.name}: {logo.size[0]}x{logo.size[1]}, {target.stat().st_size // 1024} KB")


if __name__ == "__main__":
    build()
