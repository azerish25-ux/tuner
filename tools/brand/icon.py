#!/usr/bin/env python3
"""Timbre app icon: a frozen standing wave inside a strobe ring (Still Point)."""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

N = 4096
y, x = np.mgrid[0:N, 0:N].astype(np.float64)
cx = cy = N / 2
dx, dy = (x - cx) / N, (y - cy) / N
r = np.sqrt(dx * dx + dy * dy)
a = np.arctan2(dy, dx)

# Warm stage: near-black with a low amber glow.
bg = np.zeros((N, N, 3))
base = np.array([14, 11, 9]) / 255.0
glow = np.array([88, 52, 22]) / 255.0
falloff = np.exp(-(r / 0.36) ** 2)
bg[:] = base + glow[None, None, :] * falloff[..., None] * 0.55

def add(img, mask, color, strength=1.0):
    img += mask[..., None] * np.array(color)[None, None, :] / 255.0 * strength

# Strobe ring: 48 segments, brightness rising toward the top (the reference point).
ring_r, ring_w = 0.335, 0.034
band = np.exp(-((r - ring_r) / (ring_w / 2)) ** 8)
segments = (np.cos(a * 36) > -0.2).astype(float)
segments = gaussian_filter(segments, 1.2)
lift = 0.35 + 0.65 * (0.5 + 0.5 * np.cos(a + np.pi / 2)) ** 1.5
ring = band * segments * lift
add(bg, ring, (216, 172, 104), 0.95)
add(bg, gaussian_filter(ring, 18), (255, 196, 120), 0.35)

# Reference tick at the top of the ring.
tick = np.exp(-((dx) / 0.0055) ** 2) * np.exp(-((dy + ring_r + 0.052) / 0.022) ** 2)
add(bg, tick, (255, 236, 200), 1.0)
add(bg, gaussian_filter(tick, 22), (255, 210, 150), 0.6)

# Frozen standing wave: a string pinned at both ends, bowed in its fundamental.
xs = np.linspace(-0.25, 0.25, 4000)
ys = -0.1 * np.sin(np.pi * (xs + 0.25) / 0.5) * 1.0
line = np.zeros((N, N))
px = ((xs + 0.5) * N).astype(int)
py = ((ys + 0.5) * N).astype(int)
for ox in range(-24, 25):
    for oy in range(-24, 25):
        if ox * ox + oy * oy <= 576:
            line[np.clip(py + oy, 0, N - 1), np.clip(px + ox, 0, N - 1)] = 1
# Its resting position, faint: where it will settle.
rest = np.exp(-((dy) / 0.004) ** 2) * (np.abs(dx) < 0.25)
add(bg, rest, (210, 170, 120), 0.28)
line = gaussian_filter(line, 2.2)
add(bg, gaussian_filter(line, 70), (255, 170, 80), 0.55)
add(bg, gaussian_filter(line, 22), (255, 214, 160), 0.7)
add(bg, line, (255, 246, 230), 1.0)
# Pins.
for px0 in (-0.25, 0.25):
    pin = np.exp(-(((dx - px0) ** 2 + dy ** 2) / 0.018 ** 2))
    add(bg, pin, (255, 236, 205), 1.0)

img = Image.fromarray((np.clip(bg, 0, 1) * 255).astype(np.uint8)).resize((1024, 1024), Image.LANCZOS)
out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("icon.png")
img.save(out)
print("wrote", out)
