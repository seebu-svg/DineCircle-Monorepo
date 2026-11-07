#!/usr/bin/env python3
"""Regenerate every launcher, adaptive and splash asset from the Partner badge.

    usage: python3 tool/generate_icons.py [path/to/partner_icon_source.png]

The source is the official 1254x1254 artwork: one rounded-square badge on a
light mockup canvas with a soft drop shadow. The badge's bounds are measured
from the pixels rather than hardcoded, because the shadow band sits right where
a hardcoded crop would end — leaving it in bakes a pale fringe along the bottom
edge of every icon that ships.

Three masters are derived, all at the badge's own resolution:

  full   - full-bleed square: the badge with the area outside its rounded shape
           filled with the brand navy. Used where the platform applies its own
           mask (iOS AppIcon, Android legacy ic_launcher, PWA icons), so the
           rounding must not be baked in.
  badge  - the badge with its original rounded corners, everything outside made
           transparent. Used for splash branding and as the adaptive-icon
           foreground, where the shape itself is the design.
  field  - flat brand navy. The adaptive-icon background layer and the
           maskable backdrop, so whatever a launcher masks away is only ever
           brand colour, never artwork.

The adaptive foreground places the badge at 0.52 of the 108dp viewport. The
safe zone is a 66dp circle, and the widest element in the design is the PARTNER
pill (~0.43 of the side from centre at ~0.38 below centre), which solves to a
side of 0.57; 0.52 keeps the whole badge inside every launcher shape with margin.

This script writes bitmaps only. The adaptive-icon XML, the splash drawables and
the iOS launch storyboard are checked into the project and are not touched here.
"""

from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC_DEFAULT = ROOT / "tool" / "assets" / "partner_icon_source.png"

# A pixel belongs to the badge below this luminance. The mockup canvas measures
# ~253 and the darkest part of its shadow band stays above 205.
ARTWORK_LUM = 200
EDGE_INSET = 1  # drop the antialiased rim so no shadow survives the crop
NAVY = (8, 25, 44)  # brand navy, sampled from the badge's own outer field

ANDROID_LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ANDROID_ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
IOS = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}
IOS_LAUNCH = {"LaunchImage.png": 200, "LaunchImage@2x.png": 400, "LaunchImage@3x.png": 600}
ANDROID_SPLASH = {"mdpi": 128, "hdpi": 192, "xhdpi": 256, "xxhdpi": 384, "xxxhdpi": 512}
SAFE_RATIO = 0.52


def luminescence(rgb: np.ndarray) -> np.ndarray:
    return 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]


def badge_bounds(rgb: np.ndarray) -> tuple[int, int, int, int]:
    """Tight left, upper, right, lower bounds of the badge, shadow excluded.

    The badge is row-convex, so the outermost artwork pixel on each row traces
    its exact outline, corner arcs included.
    """
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
    """Alpha for the badge as it is actually drawn, corner arcs measured.

    A geometric rounded rectangle is deliberately not used: the source badge is
    0.8% wider than tall, so a mask fitted to the square canvas drifts a few
    pixels off the artwork at the top and bottom corners and leaves pale
    mockup pixels showing through inside the shape.
    """
    art = luminescence(rgb) < ARTWORK_LUM
    left, top, right, bottom = bounds
    h, w = bottom - top, right - left
    sil = np.zeros((h, w), dtype=np.uint8)
    for y in range(h):
        xs = np.where(art[y + top, left:right])[0]
        if xs.size:
            sil[y, xs[0] : xs[-1] + 1] = 255
    # Feather 1px so the traced outline keeps the source's antialiased edge.
    return np.asarray(
        Image.fromarray(sil).filter(ImageFilter.GaussianBlur(0.6)), dtype=np.uint8
    )


def to_square(crop: np.ndarray, mask: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Pad the badge and its mask to a square together, by edge replication.

    The source badge measures 0.8% wider than tall. Replicating the outermost
    rows/columns absorbs that difference into the background band: nothing is
    cropped, nothing is stretched, and the PARTNER pill still reaches the bottom
    edge exactly as drawn. Padding the mask the same way keeps the two aligned.
    """
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


def derive(source: Path):
    original = Image.open(source).convert("RGB")
    rgb = np.asarray(original, dtype=np.int16)
    bounds = badge_bounds(rgb)
    crop = np.asarray(original.crop(bounds), dtype=np.uint8)
    silhouette = badge_silhouette(rgb, bounds)
    print(
        f"badge bounds l{bounds[0]} t{bounds[1]} r{bounds[2]} b{bounds[3]} "
        f"-> {crop.shape[1]}x{crop.shape[0]}"
    )
    square, mask = to_square(crop, silhouette)
    side = square.shape[0]
    print(f"master {side}x{side}, measured silhouette as alpha")

    badge = Image.fromarray(square)
    badge.putalpha(Image.fromarray(mask))

    full = Image.new("RGBA", (side, side), (*NAVY, 255))
    full.paste(badge, (0, 0), badge)
    field = Image.new("RGBA", (side, side), (*NAVY, 255))
    return full.convert("RGB"), badge, field


def fit(img: Image.Image, size: int) -> Image.Image:
    return img.resize((size, size), Image.Resampling.LANCZOS)


def adaptive(master: Image.Image, size: int, ratio: float | None = None) -> Image.Image:
    """Place `master` centred in a `size` px viewport, optionally scaled down."""
    if ratio is None:
        return fit(master, size).convert("RGBA")
    inner = max(1, round(size * ratio))
    layer = fit(master, inner)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(layer, ((size - inner) // 2, (size - inner) // 2))
    return canvas


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"  wrote {path.relative_to(ROOT)} {img.size[0]}x{img.size[1]}")


def main() -> int:
    source = Path(sys.argv[1]).expanduser().resolve() if len(sys.argv) > 1 else SRC_DEFAULT
    if not source.is_file():
        print(f"source artwork not found: {source}", file=sys.stderr)
        return 1
    if not (ROOT / "pubspec.yaml").exists():
        print(f"not a Flutter project: {ROOT}", file=sys.stderr)
        return 1
    print(f"source: {source}")

    full, badge, field = derive(source)
    res = ROOT / "android" / "app" / "src" / "main" / "res"

    print("\nAndroid legacy launcher icons")
    for density, size in ANDROID_LEGACY.items():
        save(fit(full, size), res / f"mipmap-{density}" / "ic_launcher.png")

    print("\nAndroid adaptive icon layers")
    for density, size in ANDROID_ADAPTIVE.items():
        save(fit(field, size), res / f"mipmap-{density}" / "ic_launcher_background.png")
        save(adaptive(badge, size, SAFE_RATIO), res / f"mipmap-{density}" / "ic_launcher_foreground.png")

    print("\nAndroid splash logo")
    for density, size in ANDROID_SPLASH.items():
        save(fit(badge, size), res / f"drawable-{density}" / "launch_image.png")

    print("\niOS AppIcon set")
    ios = ROOT / "ios" / "Runner" / "Assets.xcassets"
    for name, size in IOS.items():
        save(fit(full, size), ios / "AppIcon.appiconset" / name)

    print("\niOS launch screen image")
    for name, size in IOS_LAUNCH.items():
        save(fit(badge, size), ios / "LaunchImage.imageset" / name)

    print("\nWeb / PWA icons")
    web = ROOT / "web"
    save(fit(full, 16), web / "favicon.png")
    for size in (192, 512):
        save(fit(full, size), web / "icons" / f"Icon-{size}.png")
        maskable = fit(field, size)
        maskable.alpha_composite(adaptive(badge, size, SAFE_RATIO))
        save(maskable, web / "icons" / f"Icon-maskable-{size}.png")

    print("\nPreviews for eyeballing (build/ is not shipped)")
    preview = ROOT / "build" / "icon_preview"
    save(fit(full, 512), preview / "full_512.png")
    save(fit(badge, 512), preview / "badge_512.png")
    composite = fit(field, 432)
    composite.alpha_composite(adaptive(badge, 432, SAFE_RATIO))
    save(composite, preview / "adaptive_composite_432.png")
    print("\nDone. Adaptive-icon XML, splash drawables and the iOS storyboard are project files.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
