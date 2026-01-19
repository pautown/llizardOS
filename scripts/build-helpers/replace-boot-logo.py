#!/usr/bin/env python3
"""
Replace boot logo in Amlogic logo.dump file
Usage: replace-boot-logo.py <input.png> <logo.dump> <output.dump>
"""

import sys
import struct
from PIL import Image

def rgb888_to_rgb565(r, g, b):
    """Convert 8-bit RGB to 16-bit RGB565"""
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)

def create_rgb565_bmp(img, width, height):
    """Create a 16-bit RGB565 BMP from PIL Image"""
    # BMP header (14 bytes)
    bmp_header = struct.pack('<2sIHHI',
        b'BM',           # Magic
        0,               # File size (filled later)
        0,               # Reserved
        0,               # Reserved
        138              # Pixel data offset (header + DIB + color masks)
    )

    # DIB header (BITMAPV4HEADER - 124 bytes for RGB565)
    row_size = ((width * 16 + 31) // 32) * 4  # Row size padded to 4 bytes
    pixel_data_size = row_size * height

    dib_header = struct.pack('<IIIHHIIIIIIIIIIIIIIIIIIIIIIII',
        124,             # DIB header size
        width,           # Width
        height,          # Height (positive = bottom-up)
        1,               # Color planes
        16,              # Bits per pixel
        3,               # Compression (BI_BITFIELDS)
        pixel_data_size, # Image size
        2835,            # X pixels per meter
        2835,            # Y pixels per meter
        0,               # Colors in color table
        0,               # Important colors
        0xF800,          # Red mask (RGB565)
        0x07E0,          # Green mask
        0x001F,          # Blue mask
        0,               # Alpha mask
        0x73524742,      # Color space ('BGRs')
        0, 0, 0, 0, 0, 0, 0, 0, 0,  # Color space endpoints (36 bytes = 9 ints)
        0, 0, 0, 0       # Gamma values
    )

    # Update file size in header
    file_size = 14 + 124 + pixel_data_size
    bmp_header = struct.pack('<2sIHHI', b'BM', file_size, 0, 0, 138)

    # Create pixel data (bottom-up)
    pixels = img.load()
    pixel_data = bytearray()

    for y in range(height - 1, -1, -1):  # Bottom to top
        row = bytearray()
        for x in range(width):
            px = pixels[x, y]
            if len(px) == 4:
                r, g, b, a = px
            else:
                r, g, b = px
            rgb565 = rgb888_to_rgb565(r, g, b)
            row.extend(struct.pack('<H', rgb565))
        # Pad row to 4-byte boundary
        while len(row) % 4 != 0:
            row.append(0)
        pixel_data.extend(row)

    return bmp_header + dib_header + bytes(pixel_data)

def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <input.png> <logo.dump> <output.dump>")
        sys.exit(1)

    input_png = sys.argv[1]
    logo_dump = sys.argv[2]
    output_dump = sys.argv[3]

    # Load and prepare image
    img = Image.open(input_png)

    # Car Thing display is 800x480, but boot logo is stored as 480x800 (portrait)
    # Rotate if needed
    if img.width == 800 and img.height == 480:
        print("Rotating image 90° clockwise for portrait orientation")
        img = img.rotate(-90, expand=True)

    # Resize to 480x800 if needed
    if img.size != (480, 800):
        print(f"Resizing from {img.size} to 480x800")
        img = img.resize((480, 800), Image.LANCZOS)

    # Convert to RGB
    img = img.convert('RGB')

    # Create BMP data
    bmp_data = create_rgb565_bmp(img, 480, 800)
    print(f"Created BMP: {len(bmp_data)} bytes")

    # Read original logo.dump
    with open(logo_dump, 'rb') as f:
        logo_data = bytearray(f.read())

    # Find "bootup_spotify" entry and get BMP offset
    # The BMP starts at offset 0xC0 based on the header analysis
    bmp_offset = 0xC0

    # Verify BMP magic at offset
    if logo_data[bmp_offset:bmp_offset+2] != b'BM':
        print(f"Error: No BMP found at offset 0x{bmp_offset:X}")
        sys.exit(1)

    # Get original BMP size from header
    orig_bmp_size = struct.unpack_from('<I', logo_data, bmp_offset + 2)[0]
    print(f"Original BMP size: {orig_bmp_size} bytes")

    if len(bmp_data) != orig_bmp_size:
        print(f"Warning: New BMP size ({len(bmp_data)}) differs from original ({orig_bmp_size})")
        print("Sizes must match for simple replacement. Adjusting...")
        # For now, we'll just replace in place, truncating or padding as needed
        if len(bmp_data) > orig_bmp_size:
            print("Error: New image is too large!")
            sys.exit(1)

    # Replace BMP data
    logo_data[bmp_offset:bmp_offset + len(bmp_data)] = bmp_data

    # Write output
    with open(output_dump, 'wb') as f:
        f.write(logo_data)

    print(f"Successfully wrote {output_dump}")

if __name__ == '__main__':
    main()
