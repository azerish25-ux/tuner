#!/usr/bin/env python3
"""Procedural, original material textures for Timbre's 3D instruments.

Run: python3 tools/models/textures.py [output_dir]
Every texture is generated from code (no third-party images), so the assets
are owned by the project. Maps are tileable along the grain axis (v).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, map_coordinates

RNG = np.random.default_rng(7)
SIZE = 1024


def noise(shape, sigma, seed):
    rng = np.random.default_rng(seed)
    field = gaussian_filter(rng.standard_normal(shape), sigma, mode="wrap")
    field -= field.min()
    return field / (field.max() + 1e-9)


def fbm(shape, base_sigma, octaves, seed):
    total = np.zeros(shape)
    amp, weight = 1.0, 0.0
    for octave in range(octaves):
        total += amp * noise(shape, max(0.6, base_sigma / (2 ** octave)), seed + octave)
        weight += amp
        amp *= 0.55
    return total / weight


def ramp(t, stops):
    """t in [0,1] -> RGB using [(pos, (r,g,b)), ...] stops."""
    t = np.clip(t, 0, 1)
    positions = np.array([p for p, _ in stops])
    colors = np.array([c for _, c in stops], dtype=float) / 255.0
    out = np.zeros(t.shape + (3,))
    for channel in range(3):
        out[..., channel] = np.interp(t, positions, colors[:, channel])
    return out


def grain(width, height, spacing, warp, seed, ray_strength=0.0):
    """Straight-grain growth rings running along v (height)."""
    y, x = np.mgrid[0:height, 0:width].astype(float)
    warp_field = (fbm((height, width), 60, 4, seed) - 0.5) * warp
    ring_jitter = (fbm((1, width), 3, 3, seed + 11)[0] - 0.5) * spacing * 0.6
    u = x + warp_field + ring_jitter[None, :]
    phase = (u / spacing) % 1.0
    # Latewood: sharp dark line, earlywood: soft fade.
    late = np.exp(-((phase - 0.15) ** 2) / 0.004) * 0.9 + np.exp(-((phase - 0.15) ** 2) / 0.05) * 0.35
    late *= 0.75 + 0.5 * fbm((height, width), 8, 3, seed + 3)
    if ray_strength:
        rays = (noise((height, width), 1.2, seed + 5) > 0.82).astype(float)
        rays = gaussian_filter(rays, (0.6, 5.0)) * ray_strength
        late = late - rays
    return np.clip(late, 0, 1.2)


def save(rgb, path, quality=92):
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8))
    img.save(path, quality=quality, subsampling=0) if path.suffix == ".jpg" else img.save(path)


def gray(values, path):
    Image.fromarray((np.clip(values, 0, 1) * 255).astype(np.uint8), "L").save(path)


def spruce(out):
    g = grain(SIZE, SIZE, 9.0, 18.0, 1, ray_strength=0.35)
    tone = fbm((SIZE, SIZE), 120, 3, 2)
    base = ramp(0.25 + 0.5 * tone, [(0, (222, 182, 120)), (1, (196, 150, 88))])
    dark = np.array([150, 102, 52]) / 255.0
    rgb = base * (1 - 0.7 * g[..., None]) + dark * (0.7 * g[..., None])
    save(rgb, out / "spruce_color.jpg")
    gray(0.32 + 0.12 * g, out / "spruce_rough.png")


def rosewood(out):
    g = grain(SIZE, SIZE, 14.0, 60.0, 21)
    streak = fbm((SIZE, SIZE), 25, 5, 22)
    streak = np.clip((streak - 0.35) * 2.2, 0, 1)
    rgb = ramp(0.2 + 0.6 * streak - 0.25 * g, [(0, (28, 14, 9)), (0.45, (66, 34, 20)), (0.8, (104, 56, 32)), (1, (128, 74, 42))])
    pores = (noise((SIZE, SIZE), 0.7, 23) > 0.86).astype(float)
    pores = gaussian_filter(pores, (0.4, 2.5))
    rgb *= (1 - 0.45 * pores[..., None])
    save(rgb, out / "rosewood_color.jpg")
    gray(0.42 + 0.2 * pores, out / "rosewood_rough.png")


def mahogany(out):
    g = grain(SIZE, SIZE, 7.0, 25.0, 31)
    ribbon = 0.5 + 0.5 * np.sin(np.linspace(0, 26, SIZE))[None, :] * fbm((SIZE, SIZE), 80, 2, 32)
    rgb = ramp(0.35 + 0.35 * ribbon - 0.3 * g, [(0, (60, 22, 10)), (0.5, (118, 52, 26)), (1, (156, 78, 40))])
    save(rgb, out / "mahogany_color.jpg")
    gray(0.3 + 0.1 * g, out / "mahogany_rough.png")


def ebony(out):
    g = grain(SIZE, SIZE, 11.0, 30.0, 41)
    tone = fbm((SIZE, SIZE), 30, 4, 42)
    rgb = ramp(0.2 * tone + 0.15 * g, [(0, (12, 10, 9)), (1, (46, 36, 30))])
    save(rgb, out / "ebony_color.jpg")
    gray(0.28 + 0.08 * tone, out / "ebony_rough.png")


def maple_flame(out):
    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(float)
    warp = (fbm((SIZE, SIZE), 50, 4, 51) - 0.5) * 40
    flame = 0.5 + 0.5 * np.sin((y + warp + 0.15 * x) / 7.0)
    flame = flame ** 3
    g = grain(SIZE, SIZE, 10.0, 15.0, 52) * 0.35
    rgb = ramp(0.55 + 0.25 * fbm((SIZE, SIZE), 90, 2, 53) - 0.35 * flame - 0.2 * g,
               [(0, (138, 92, 44)), (0.6, (214, 168, 106)), (1, (240, 214, 168))])
    save(rgb, out / "maple_color.jpg")


def sunburst(out, name, wood_seed, inner, outer):
    """Radial burst over alder/ash grain; u,v mapped across the body face."""
    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(float) / SIZE
    r = np.sqrt(((x - 0.5) / 0.46) ** 2 + ((y - 0.56) / 0.5) ** 2)
    g = grain(SIZE, SIZE, 16.0, 40.0, wood_seed)
    burst = np.clip((r - 0.45) / 0.55, 0, 1) ** 1.6
    base = ramp(0.6 - 0.35 * g, [(0, inner[0]), (1, inner[1])])
    edge = np.array(outer) / 255.0
    rgb = base * (1 - burst[..., None]) + edge * burst[..., None]
    save(rgb, out / f"{name}_color.jpg")


def tortoise(out):
    blobs = fbm((SIZE, SIZE), 18, 5, 61)
    rgb = ramp(blobs, [(0, (18, 8, 4)), (0.45, (52, 20, 8)), (0.62, (128, 58, 18)), (0.8, (176, 98, 34)), (1, (196, 128, 52))])
    save(rgb, out / "tortoise_color.jpg")


def rosette(out):
    """Concentric herringbone-style soundhole rosette, alpha masked to a ring."""
    n = 1024
    y, x = np.mgrid[0:n, 0:n].astype(float) / n - 0.5
    r = np.sqrt(x * x + y * y) * 2  # 0 centre, 1 edge
    a = np.arctan2(y, x)
    rgb = np.zeros((n, n, 3))
    alpha = np.zeros((n, n))
    # Ring fills the disc edge to edge; the centre stays black like the soundhole,
    # so the decal reads correctly even where the renderer ignores alpha.
    rings = [(0.80, 0.83, (238, 228, 205)), (0.83, 0.845, (20, 14, 10)), (0.845, 0.93, None), (0.93, 0.945, (20, 14, 10)), (0.945, 1.01, (238, 228, 205))]
    for lo, hi, color in rings:
        band = (r >= lo) & (r < hi)
        if color is None:
            herring = ((np.floor(a * 60 / np.pi) + np.floor((r - lo) / (hi - lo) * 4)) % 2)
            c = np.where(herring[..., None] > 0, np.array([196, 150, 92]) / 255.0, np.array([58, 30, 16]) / 255.0)
            rgb[band] = c[band]
        else:
            rgb[band] = np.array(color) / 255.0
        alpha[band] = 1
    rgb = gaussian_filter(rgb, (0.5, 0.5, 0))
    Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB").save(out / "rosette.png")


def pearl(out):
    t = fbm((512, 512), 6, 5, 71)
    hue = fbm((512, 512), 20, 3, 72)
    rgb = ramp(t, [(0, (196, 186, 168)), (0.5, (226, 216, 196)), (1, (242, 234, 218))])
    tint = ramp(hue, [(0, (255, 214, 230)), (0.5, (214, 240, 255)), (1, (230, 255, 220))])
    rgb = rgb * 0.8 + tint * 0.2
    save(rgb, out / "pearl_color.jpg")


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent / "textures"
    out.mkdir(parents=True, exist_ok=True)
    spruce(out); rosewood(out); mahogany(out); ebony(out); maple_flame(out)
    sunburst(out, "sunburst_3tone", 81, [(150, 70, 18), (232, 170, 52)], (18, 10, 6))
    sunburst(out, "sunburst_cherry", 82, [(150, 26, 18), (204, 70, 40)], (36, 6, 6))
    tortoise(out); rosette(out); pearl(out)
    print("textures written to", out)


if __name__ == "__main__":
    main()
