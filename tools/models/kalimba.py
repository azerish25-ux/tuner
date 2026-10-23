"""Kalimba (tine rig): 17 steel tines over a hardwood box. Each tine is a slide node:
peg_<anchor> moves along its local X, which points up the tine (a longer tine sounds lower).
"""
import math
from dataclasses import dataclass

from mathutils import Vector

from blendkit import catmull_rom, cube, cylinder, disc, empty, palette, prism, to_usd, world


@dataclass
class KalimbaSpec:
    id: str
    tines: int = 17
    kind: str = "kalimba"
    per_cent: float = 0.00012
    head_view: float = 0.16


def rounded_rect(w, h, r, n=8):
    pts = []
    for cx, cz, a0 in ((w / 2 - r, h - r, 0), (-w / 2 + r, h - r, 90), (-w / 2 + r, r, 180), (w / 2 - r, r, 270)):
        for k in range(n + 1):
            a = math.radians(a0 + 90 * k / n)
            pts.append((cx + r * math.cos(a), cz + r * math.sin(a)))
    return pts


def build_kalimba(spec: KalimbaSpec):
    P = palette()
    root = empty(spec.id)
    width, height, depth = 0.14, 0.185, 0.026
    y_top = -depth / 2
    outline = rounded_rect(width, height, 0.018)
    prism("body", outline, y_top, -y_top, P["mahogany"], root, bevel=0.004, segments=4)
    disc("soundhole", 0.013, y_top - 0.0004, (0, 0.045), P["hole"], root, segments=64)
    ring_pts = [(0.0165 * math.cos(a), 0.045 + 0.0165 * math.sin(a)) for a in [2 * math.pi * k / 64 for k in range(64)]]
    prism("soundhole_ring", ring_pts, y_top - 0.0006, y_top - 0.0002, P["bone"], root)
    disc("soundhole_inner", 0.0135, y_top - 0.0008, (0, 0.045), P["hole"], root, segments=64)

    # Back bridge (rest) and front pressure bar, both across the tines.
    bridge_z, bar_z = 0.112, 0.095
    cube("bridge_saddle", (0.13, 0.006, 0.006), P["ebony"], root, location=(0, y_top - 0.003, bridge_z), bevel=0.0015)
    cylinder("bridge_rod", 0.0016, 0.128, P["chrome"], root, location=(0, y_top - 0.0068, bridge_z), rotation=(0, math.pi / 2, 0), vertices=16)
    cube("pressure_bar", (0.124, 0.003, 0.006), P["chrome"], root, location=(0, y_top - 0.0104, bar_z), bevel=0.001)
    for x in (-0.05, 0.0, 0.05):
        cylinder(f"screw_{x:+.2f}", 0.0022, 0.002, P["chrome"], root, location=(x, y_top - 0.0125, bar_z), rotation=(math.pi / 2, 0, 0), vertices=16)

    rig = {"model": spec.id, "rig": "TINE", "strings": [], "degPerCent": 1.0}
    pitch = 0.0071
    for k in range(1, spec.tines + 1):
        offset = math.ceil((k - 1) / 2) * (-1 if k % 2 == 0 else 1)
        x = offset * pitch
        length = 0.079 - 0.0021 * (k - 1)       # free length beyond the bridge, longest in the middle
        anchor = f"tine_{k}"
        peg = empty(f"peg_{anchor}", (x, y_top - 0.0085, bar_z - 0.012), root)
        peg.rotation_euler = (0, -math.pi / 2, 0)  # local X points up the tine
        total = (bridge_z - bar_z) + 0.012 + length
        tine = cube(f"tine_{anchor}", (total, 0.0012, 0.0045), P["chrome"], peg, location=(total / 2, 0, 0), bevel=0.0005)
        tip = cylinder(f"tip_{anchor}", 0.00225, 0.0012, P["chrome"], peg, location=(total, 0, 0), rotation=(math.pi / 2, 0, 0), vertices=16)
        if k in (1, 8, 15):  # engraved marker tines
            disc(f"mark_{anchor}", 0.0012, y_top - 0.0098, (x, bridge_z + length * 0.55), P["ebony"], root, segments=12)
        center = world(peg, (total * 0.7, 0, 0))
        rig["strings"].append({
            "anchor": anchor, "saddle": to_usd(center), "nut": to_usd(center), "radius": 0.0, "wound": False,
            "peg": f"peg_{anchor}", "post": f"peg_{anchor}", "node": f"tine_{anchor}",
            "pegCenter": to_usd(center), "pegAxis": to_usd(Vector((0, 0, 1))), "tighten": 1,
            "motion": "slide", "perCent": spec.per_cent,
        })
    rig["headCenter"] = to_usd(Vector((0, y_top, bridge_z + 0.035)))
    rig["bodyCenter"] = to_usd(Vector((0, 0, height / 2)))
    rig["length"] = height
    return root, rig


KALIMBA = {"kalimba": KalimbaSpec(id="kalimba")}
KALIMBA_PHOTOS = {"68_mallet_percussion_kalimba": "kalimba"}
