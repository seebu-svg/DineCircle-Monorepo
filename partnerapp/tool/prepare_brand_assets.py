#!/usr/bin/env python3
"""Derive Flutter-ready brand assets from the two source PNGs at the repo root.

    usage: python3 tool/prepare_brand_assets.py

Reads:
    dineCircle Dining Logo.png   — the horizontal wordmark on a white canvas
    DC Partner App Badge.png     — the rounded-square partner badge on a
                                   mockup canvas with a soft drop shadow

Writes into assets/branding/ (committed, not generated at build time):
    wordmark_light.png  — transparent bg, dark text recolored to the dark-theme
                          surface colour (#F5F3F0), orange kept as-is
    wordmark_dark.png   — the original wordmark for light surfaces (login card,
                          print, splash)
    partner_badge.png   — silhouette-masked transparent crop of the badge at
                          512px, ready to drop into any dark surface

The script is idempotent and self-contained: it does not import from
generate_icons.py so the two derivation pipelines can evolve independently.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC_WORDMARK = ROOT / "dineCircle Dining Logo.png"
SRC_BADGE = ROOT / "DC Partner App Badge.png"
OUT_DIR = ROOT / "assets" / "branding"

# ── constants ────────────────────────────────────────────────────────────────

# The near-black of the wordmark's "dine" letters (sampled from the source).
TEXT_DARK = (26, 26, 26)
# The recolored value for dark-theme surfaces.
TEXT_LIGHT = (245, 243, 240)
# The badge's own dark field; used as the fill when padding the silhouette.
BADGE_NAVY = (8, 25, 44)
# Pixels below this luminance are considered "artwork" (excludes the mockup
# canvas and the soft drop-shadow band).
ARTWORK_LUM = 200
EDGE_INSET = 1  # drop the antialiased rim so no shadow survives the crop
BADGE_OUT = 512
WORDMARK_OUT = 1200  # 2x of a 600px logical width, good for phones + desktop


# ── helpers ──────────────────────────────────────────────────────────────────


def luminescence(rgb: np.ndarray) -> np.ndarray:
    return 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]


def badge_bounds(rgb: np.ndarray) -> tuple[int, int, int, int]:
    """Tight bounds of the badge, shadow excluded (row-convex artwork)."""
    art = luminescence(rgb) < ARTWORK_LUM
    rows = np.where(art.any(axis=1))[0]
    cols = np.where(art.any(axis=0))[0]
    return (
        int(cols.min()) + EDGE_INSET,
        int(rows.min()) + EDGE_INSET,
        int(cols.max()) + 1 - EDGE_INSET,
        int(rows.max()) + 1 - EDGE_INSET,
    )


def badge_silhouette(rgb: np.ndarray, bounds: tuple[int, int, int, int]) -> np.ndarray:
    """Alpha for the badge as it is actually drawn, corner arcs measured."""
    art = luminescence(rgb) < ARTWORK_LUM
    left, top, right, bottom = bounds
    h, w = bottom - top, right - left
    sil = np.zeros((h, w), dtype=np.uint8)
    for y in range(h):
        xs = np.where(art[y + top, left:right])[0]
        if xs.size:
            sil[y, xs[0] : xs[-1] + 1] = 255
    return np.asarray(
        Image.fromarray(sil).filter(ImageFilter.GaussianBlur(0.6)), dtype=np.uint8
    )


def pad_to_square(crop: np.ndarray, mask: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Pad the badge and its mask to a square together, by edge replication."""
    h, w = crop.shape[:2]
    side = max(h, w)
    pad_v, pad_h = (side - h) / 2, (side - w) / 2
    widths = (
        (int(np.floor(pad_v)), int(np.ceil(pad_v))),
        (int(np.floor(pad_h)), int(np.ceil(pad_h))),
    )
    return (
        np.pad(crop, (*widths, (0, 0)), mode="edge"),
        np.pad(mask, widths, mode="edge"),
    )


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    print(f"  wrote {path.relative_to(ROOT)} {img.size[0]}x{img.size[1]}")


# ── derivations ──────────────────────────────────────────────────────────────


def derive_wordmark(source: Path) -> tuple[Image.Image, Image.Image]:
    """Return (light variant, dark variant) RGBA images."""
    original = Image.open(source).convert("RGB")
    rgb = np.asarray(original, dtype=np.int16)
    h, w = rgb.shape[:2]

    # Alpha: distance from white, antialiasing-friendly.
    # For white (255,255,255) → 0; for the darkest text (26,26,26) → 255.
    # Float arithmetic avoids int16 overflow on the multiplication.
    min_ch = np.minimum(np.minimum(rgb[..., 0], rgb[..., 1]), rgb[..., 2])
    alpha = np.clip((255.0 - min_ch) * 255.0 / 229.0, 0, 255).astype(np.uint8)

    # Saturation: low-saturation pixels are the near-black text; recolour them.
    max_ch = np.maximum(np.maximum(rgb[..., 0], rgb[..., 1]), rgb[..., 2])
    sat = max_ch - min_ch
    is_text = sat < 40  # neutral pixels
    is_white = min_ch > 240  # keep alpha=0 for these, colour doesn't matter

    out_rgb = np.zeros_like(rgb, dtype=np.uint8)
    # Text pixels → light theme colour
    out_rgb[is_text] = TEXT_LIGHT
    # Coloured pixels (orange rings) → keep original
    out_rgb[~is_text] = rgb[~is_text].clip(0, 255).astype(np.uint8)
    # White pixels: colour irrelevant (alpha=0), but set to white for clarity
    out_rgb[is_white] = 255

    light = Image.fromarray(out_rgb).convert("RGB")
    light.putalpha(Image.fromarray(alpha))

    # Dark variant: the original on a transparent background (white keyed out).
    dark_alpha = np.where(is_white, 0, alpha).astype(np.uint8)
    dark = Image.fromarray(np.asarray(original, dtype=np.uint8)).convert("RGB")
    dark.putalpha(Image.fromarray(dark_alpha))

    # Scale down to the target size while preserving aspect ratio.
    target_w = WORDMARK_OUT
    scale = target_w / w
    target_h = max(1, round(h * scale))
    light = light.resize((target_w, target_h), Image.Resampling.LANCZOS)
    dark = dark.resize((target_w, target_h), Image.Resampling.LANCZOS)
    return light, dark


def derive_badge(source: Path) -> Image.Image:
    """Return the badge as a transparent RGBA image, 512px square."""
    original = Image.open(source).convert("RGB")
    rgb = np.asarray(original, dtype=np.int16)
    bounds = badge_bounds(rgb)
    crop = np.asarray(original.crop(bounds), dtype=np.uint8)
    silhouette = badge_silhouette(rgb, bounds)
    square, mask = pad_to_square(crop, silhouette)
    badge = Image.fromarray(square).convert("RGB")
    badge.putalpha(Image.fromarray(mask))
    return badge.resize((BADGE_OUT, BADGE_OUT), Image.Resampling.LANCZOS)


# ── main ─────────────────────────────────────────────────────────────────────


def main() -> int:
    if not SRC_WORDMARK.is_file():
        print(f"wordmark source not found: {SRC_WORDMARK}", file=sys.stderr)
        return 1
    if not SRC_BADGE.is_file():
        print(f"badge source not found: {SRC_BADGE}", file=sys.stderr)
        return 1
    if not (ROOT / "pubspec.yaml").exists():
        print(f"not a Flutter project: {ROOT}", file=sys.stderr)
        return 1

    print(f"wordmark source: {SRC_WORDMARK.name}")
    print(f"badge source:    {SRC_BADGE.name}")

    print("\nWordmark")
    light, dark = derive_wordmark(SRC_WORDMARK)
    save(light, OUT_DIR / "wordmark_light.png")
    save(dark, OUT_DIR / "wordmark_dark.png")

    print("\nBadge")
    badge = derive_badge(SRC_BADGE)
    save(badge, OUT_DIR / "partner_badge.png")

    print("\nDone.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
