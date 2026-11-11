#!/usr/bin/env python3
"""Prepare Customer App screenshots for the website app showcase.

The showcase must show the real app, so every source here is a device capture
taken over ADB, not a rendered mockup. The script trims the Android status bar
(the phone frame on the site supplies its own chrome, and leaving three
different clock readings and battery levels in a row of frames reads as a
stitch job), scales to the size the frames actually display at, and writes
WebP next to the rest of the site imagery.

Sources live in DineCircle-master/.qa/shots, which holds the on-device QA
captures. Run from website/: python3 tool/app_shots.py
"""
from pathlib import Path
from PIL import Image

REPO = Path(__file__).resolve().parents[2]
SOURCE_DIR = REPO / "DineCircle-master" / ".qa" / "shots"
OUT_DIR = Path(__file__).resolve().parents[1] / "assets" / "images"

# Android status bar height on the 1080x2280 test device.
STATUS_BAR = 100
TARGET_WIDTH = 720
QUALITY = 82

# Site name to device capture. Each entry is a screen a visitor can reach in
# the shipping app: the home dashboard, the Explore tab and the Deals tab.
# Screens that show seeded demo disclaimers are deliberately left out; a
# marketing frame should not be quoting sample-content notices.
SHOTS = {
    "app_home": "h01_home.png",
    "app_explore": "h10_explore_chips.png",
    "app_deals": "h36_deals.png",
}


def prepare(name, source):
    origin = SOURCE_DIR / source
    if not origin.exists():
        raise SystemExit(f"missing device capture: {origin}")
    with Image.open(origin) as shot:
        shot = shot.convert("RGB")
        trimmed = shot.crop((0, STATUS_BAR, shot.width, shot.height))
        scale = TARGET_WIDTH / trimmed.width
        resized = trimmed.resize(
            (TARGET_WIDTH, round(trimmed.height * scale)), Image.LANCZOS
        )
        target = OUT_DIR / f"{name}.webp"
        resized.save(target, "WEBP", quality=QUALITY, method=6)
        return resized.size


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, source in SHOTS.items():
        width, height = prepare(name, source)
        print(f"{name}.webp {width}x{height}")
    print(f"Wrote {len(SHOTS)} app screenshots into {OUT_DIR}")


if __name__ == "__main__":
    main()
