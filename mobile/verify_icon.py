"""Compare two PNGs by decoded RGBA pixels.

Android's AAPT2 recompresses packaged PNGs, so the bytes of the launcher
icon inside the APK differ from the brand source even when the artwork is
unchanged. This script decodes both files and compares their pixels, using
only the standard library so CI does not need extra packages.

Usage: python3 verify_icon.py BRAND.png PACKAGED.png
"""

import struct
import sys
import zlib

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
CHANNELS = {2: 3, 6: 4}


def read_chunks(path):
    with open(path, "rb") as handle:
        data = handle.read()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError(f"{path} is not a PNG file")
    offset, chunks = len(PNG_SIGNATURE), []
    while offset < len(data):
        (length,) = struct.unpack(">I", data[offset : offset + 4])
        kind = data[offset + 4 : offset + 8]
        body = data[offset + 8 : offset + 8 + length]
        chunks.append((kind, body))
        offset += 12 + length
        if kind == b"IEND":
            break
    return chunks


def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def decode(path):
    chunks = read_chunks(path)
    header = next(body for kind, body in chunks if kind == b"IHDR")
    width, height, depth, color_type, compression, filtering, interlace = struct.unpack(
        ">IIBBBBB", header
    )
    if depth != 8 or color_type not in CHANNELS:
        raise ValueError(
            f"{path} uses unsupported PNG format (depth {depth}, color type {color_type})"
        )
    if compression != 0 or filtering != 0 or interlace != 0:
        raise ValueError(f"{path} uses an unsupported PNG variant")
    channels = CHANNELS[color_type]
    raw = zlib.decompress(b"".join(body for kind, body in chunks if kind == b"IDAT"))
    stride = width * channels
    previous = bytearray(stride)
    pixels = bytearray()
    offset = 0
    for _ in range(height):
        filter_type = raw[offset]
        offset += 1
        row = bytearray(raw[offset : offset + stride])
        offset += stride
        for index in range(stride):
            left = row[index - channels] if index >= channels else 0
            above = previous[index]
            upper_left = previous[index - channels] if index >= channels else 0
            if filter_type == 1:
                row[index] = (row[index] + left) & 0xFF
            elif filter_type == 2:
                row[index] = (row[index] + above) & 0xFF
            elif filter_type == 3:
                row[index] = (row[index] + (left + above) // 2) & 0xFF
            elif filter_type == 4:
                row[index] = (row[index] + paeth(left, above, upper_left)) & 0xFF
            elif filter_type != 0:
                raise ValueError(f"{path} uses unknown PNG filter {filter_type}")
        if channels == 4:
            pixels.extend(row)
        else:
            for index in range(0, stride, 3):
                pixels.extend(row[index : index + 3])
                pixels.append(255)
        previous = row
    return width, height, bytes(pixels)


def main():
    if len(sys.argv) != 3:
        raise SystemExit("Usage: verify_icon.py BRAND.png PACKAGED.png")
    brand_width, brand_height, brand_pixels = decode(sys.argv[1])
    packaged_width, packaged_height, packaged_pixels = decode(sys.argv[2])
    brand_size = (brand_width, brand_height)
    packaged_size = (packaged_width, packaged_height)
    if brand_size != packaged_size:
        raise SystemExit(
            f"Packaged launcher icon size {packaged_size} does not match brand {brand_size}."
        )
    if brand_pixels != packaged_pixels:
        raise SystemExit("Packaged launcher icon pixels do not match the Peo Yame brand asset.")
    print(
        f"Packaged launcher icon pixels match the brand asset "
        f"({brand_size[0]}x{brand_size[1]})."
    )


if __name__ == "__main__":
    main()
