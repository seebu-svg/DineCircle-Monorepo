"""Independently decode the PNG exports from verify_qr_studio.dart.

Requires Pillow and the system libzbar library. Never substitutes a QR encoder
for the decoder: the actual lossless exported image is scanned.
"""
import ctypes as c
from pathlib import Path

from PIL import Image

zbar = c.CDLL("libzbar.so.0")
zbar.zbar_image_scanner_create.restype = c.c_void_p
zbar.zbar_image_create.restype = c.c_void_p
zbar.zbar_image_set_format.argtypes = [c.c_void_p, c.c_ulong]
zbar.zbar_image_set_size.argtypes = [c.c_void_p, c.c_uint, c.c_uint]
zbar.zbar_image_set_data.argtypes = [c.c_void_p, c.c_void_p, c.c_ulong, c.c_void_p]
zbar.zbar_scan_image.argtypes = [c.c_void_p, c.c_void_p]
zbar.zbar_image_first_symbol.argtypes = [c.c_void_p]
zbar.zbar_image_first_symbol.restype = c.c_void_p
zbar.zbar_symbol_get_data.argtypes = [c.c_void_p]
zbar.zbar_symbol_get_data.restype = c.c_char_p
zbar.zbar_image_destroy.argtypes = [c.c_void_p]
zbar.zbar_image_scanner_destroy.argtypes = [c.c_void_p]

files = sorted(Path("/tmp/dinecircle-qr-verification").glob("*.png"))
assert len(files) == 6, "Render all three styles at both text scales first."
for path in files:
    with Image.open(path) as png:
        width, height = png.size
        gray = png.convert("L").tobytes()
    buffer = c.create_string_buffer(gray)
    image = zbar.zbar_image_create()
    scanner = zbar.zbar_image_scanner_create()
    try:
        zbar.zbar_image_set_format(image, int.from_bytes(b"Y800", "little"))
        zbar.zbar_image_set_size(image, width, height)
        zbar.zbar_image_set_data(image, buffer, len(gray), None)
        zbar.zbar_scan_image(scanner, image)
        symbol = zbar.zbar_image_first_symbol(image)
        payload = zbar.zbar_symbol_get_data(symbol).decode() if symbol else None
        assert payload == "https://dinecircle.app/menu/ven_123", (path.name, payload)
        print(f"{path.stem}: decoded {payload}")
    finally:
        zbar.zbar_image_destroy(image)
        zbar.zbar_image_scanner_destroy(scanner)
