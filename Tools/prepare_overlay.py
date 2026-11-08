"""Build the default-waterline overlay once, from the C#-prepared display grid."""
from pathlib import Path
import json
import struct
from PIL import Image

root = Path(__file__).resolve().parents[1]
data = (root / "Data/survey_grid.dat").read_bytes()
assert data[:8] == b"BATHGRID"
width, height = struct.unpack_from("<ii", data, 8)
count = width * height
raw = memoryview(data)[40:40 + count * 2].cast("H")
display = memoryview(data)[40 + count * 2:40 + count * 4].cast("H")
waterline = json.loads((root / "Data/site.json").read_text(encoding="utf-8"))["waterSurfaceReferenceM"]
stops = [(0, (69, 180, 168)), (10, (37, 138, 144)), (20, (18, 93, 116)),
         (30, (10, 62, 92)), (45, (6, 37, 62))]
pixels = bytearray(count * 4)
for i, encoded in enumerate(display):
    if encoded == 65535:
        continue
    depth = max(0.0, waterline - (400.0 + encoded / 100.0))
    for (d0, c0), (d1, c1) in zip(stops, stops[1:]):
        if depth <= d1:
            t = min(1.0, max(0.0, (depth - d0) / (d1 - d0)))
            break
    else:
        c0 = c1 = stops[-1][1]
        t = 0.0
    phase = depth % 5
    shade = .83 if min(phase, 5 - phase) < .18 else 1.0
    offset = i * 4
    pixels[offset:offset + 4] = bytes([*(round((a + (b-a)*t)*shade) for a, b in zip(c0, c1)), 248])
Image.frombytes("RGBA", (width, height), bytes(pixels)).save(root / "Data/bathymetry_default.png", optimize=True)
print(f"Prepared {width}x{height} overlay; {sum(value != 65535 for value in raw)} measured cells")
