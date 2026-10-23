"""Folk and world instruments.

Peg instruments (erhu, shamisen, pipa, oud, Appalachian dulcimer) rotate peg_<anchor> about its
local X like the violin family. Zithers (koto, gayageum, guzheng) tune with movable bridges:
each bridge is a slide node whose local X points toward a longer vibrating length.
"""
import math
from dataclasses import dataclass, field

from mathutils import Vector

from blendkit import (catmull_rom, cube, cylinder, disc, ellipsoid, empty, fit_uv, mirrored_outline, palette, prism,
                      ring, segment, to_usd, tube, world)


@dataclass
class FolkSpec:
    id: str
    kind: str
    strings: list = field(default_factory=list)
    head_view: float = 0.2
    deg_per_cent: float = 1.6


def peg_entry(anchor, name, saddle, nut, radius, peg, head_offset, tighten=1):
    c = world(peg, head_offset)
    return {"anchor": anchor, "saddle": to_usd(saddle), "nut": to_usd(nut), "radius": round(radius, 6), "wound": False,
            "peg": peg.name, "post": peg.name, "node": f"string_{name}", "pegCenter": to_usd(c),
            "pegAxis": to_usd((world(peg, (1, 0, 0)) - world(peg)).normalized()), "tighten": tighten}


def friction_peg(name, parent, location, side, shaft, head_len, material, tip=None, P=None):
    """Peg through a neck or pegbox; local X points to the head (thumb piece)."""
    peg = empty(name, location, parent)
    peg.rotation_euler = (0, 0, 0 if side > 0 else math.pi)
    cylinder(name + "_shaft", 0.0035, shaft, material, peg, location=(shaft / 2 - 0.01, 0, 0), rotation=(0, math.pi / 2, 0), radius_top=0.0048, vertices=16)
    ellipsoid(name + "_head", (head_len, 0.006, 0.0075), material, peg, location=(shaft - 0.01 + head_len * 0.9, 0, 0))
    if tip is not None:
        ellipsoid(name + "_tip", (0.003, 0.003, 0.003), tip, peg, location=(shaft - 0.01 + head_len * 1.85, 0, 0))
    return peg


# ---------------------------------------------------------------- erhu

def build_erhu(spec):
    P = palette()
    root = empty(spec.id)
    hexagon = [(0.05 * math.cos(math.pi / 3 * k + math.pi / 6), 0.06 + 0.05 * math.sin(math.pi / 3 * k + math.pi / 6)) for k in range(6)]
    prism("resonator", hexagon, -0.065, 0.065, P["rosewood"], root, bevel=0.003)
    inner = [(0.043 * math.cos(math.pi / 3 * k + math.pi / 6), 0.06 + 0.043 * math.sin(math.pi / 3 * k + math.pi / 6)) for k in range(6)]
    prism("skin", inner, -0.0665, -0.064, P["tortoise"], root, uv=fit_uv(((-0.045, 0.015), (0.045, 0.105))))
    neck_y = 0.035
    cylinder("neck", 0.0105, 0.76, P["rosewood"], root, location=(0, neck_y, 0.47), vertices=24)
    cylinder("foot", 0.012, 0.03, P["rosewood"], root, location=(0, neck_y, 0.0), vertices=24)
    tube("head", [(0, neck_y, 0.85), (0, neck_y + 0.01, 0.88), (0, neck_y + 0.03, 0.9), (0, neck_y + 0.05, 0.9)], [0.011, 0.01, 0.009, 0.007], P["rosewood"], root)
    bridge_top = Vector((0, -0.066 - 0.011, 0.045))
    cube("bridge", (0.016, 0.011, 0.006), P["bridge_maple"], root, location=(0, -0.066 - 0.0055, 0.045), bevel=0.001)
    qian_z = 0.6
    tube("qianjin", [Vector((0.014 * math.cos(a), neck_y - 0.014 + 0.012 * math.sin(a), qian_z)) for a in [2 * math.pi * k / 24 for k in range(25)]],
         0.0012, P["gut"], root, sides=8)
    rig = {"model": spec.id, "rig": "FRICTION_PEG", "degPerCent": spec.deg_per_cent, "strings": []}
    for i, (anchor, x, z, radius) in enumerate((("s2", -0.0035, 0.74, 0.0004), ("s1", 0.0035, 0.78, 0.0003))):
        peg = friction_peg(f"peg_{anchor}", root, (0, neck_y, z), -1, 0.05, 0.016, P["ebony"])
        saddle = bridge_top + Vector((x, 0, 0))
        nut = Vector((x, neck_y - 0.0125, qian_z))
        segment(f"string_{anchor}", saddle, nut, radius, P["steel"], root)
        segment(f"string_{anchor}_head", nut, Vector((x * 0.4, neck_y - 0.008, z)), radius, P["steel"], root)
        segment(f"string_{anchor}_tail", saddle, Vector((x, neck_y - 0.01, 0.005)), radius, P["steel"], root)
        rig["strings"].append(peg_entry(anchor, anchor, saddle, nut, radius, peg, (0.055, 0, 0)))
    # Bow resting between the strings.
    tube("bow_stick", [(-0.25, -0.09, 0.2), (0.0, -0.095, 0.17), (0.28, -0.09, 0.14)], 0.0032, P["maple"], root, sides=10)
    tube("bow_hair", [(-0.24, -0.08, 0.195), (0.27, -0.08, 0.137)], 0.0018, P["bone"], root, sides=8)
    rig["headCenter"] = to_usd(Vector((0, neck_y, 0.76)))
    rig["bodyCenter"] = to_usd(Vector((0, 0, 0.45)))
    rig["length"] = 0.92
    return root, rig


# ---------------------------------------------------------------- shamisen

def build_shamisen(spec):
    P = palette()
    root = empty(spec.id)
    w, h = 0.2, 0.21
    body = catmull_rom([(-w / 2, 0.0), (0.0, -0.006), (w / 2, 0.0), (w / 2 + 0.006, h / 2), (w / 2, h), (0.0, h + 0.006), (-w / 2, h), (-w / 2 - 0.006, h / 2)], 6, closed=True)
    prism("do", body, -0.045, 0.045, P["rosewood"], root, bevel=0.004)
    prism("skin", [(x * 0.93, h / 2 + (z - h / 2) * 0.93) for x, z in body], -0.047, -0.044, P["drumhead"], root)
    neck_y = -0.03
    cube("sao", (0.026, 0.024, 0.66), P["rosewood"], root, location=(0, neck_y, h + 0.33), bevel=0.002)
    head = empty("tenjin_frame", (0, neck_y, h + 0.66), root)
    head.rotation_euler = (-math.radians(18), 0, 0)
    cube("tenjin", (0.03, 0.03, 0.14), P["rosewood"], head, location=(0, 0.006, 0.07), bevel=0.003)
    cube("tenjin_slot", (0.016, 0.002, 0.11), P["hole"], head, location=(0, -0.0092, 0.075))
    bridge_top = Vector((0, -0.047 - 0.008, 0.045))
    cube("koma", (0.04, 0.008, 0.004), P["bone"], root, location=(0, -0.047 - 0.004, 0.045), bevel=0.0008)
    nut_z = h + 0.64
    rig = {"model": spec.id, "rig": "FRICTION_PEG", "degPerCent": spec.deg_per_cent, "strings": []}
    for i, (anchor, x, z, side, radius) in enumerate((("s3", -0.008, 0.03, -1, 0.0005), ("s2", 0.0, 0.065, 1, 0.0004), ("s1", 0.008, 0.1, -1, 0.0003))):
        peg = friction_peg(f"peg_{anchor}", head, (0, 0.006, z), side, 0.05, 0.02, P["bone"])
        saddle = bridge_top + Vector((x, 0, 0))
        nut = Vector((x * 0.6, neck_y - 0.0125, nut_z))
        segment(f"string_{anchor}", saddle, nut, radius, P["nylon"], root)
        segment(f"string_{anchor}_head", nut, world(head, (0, -0.004, z)), radius, P["nylon"], root)
        segment(f"string_{anchor}_tail", saddle, Vector((x * 0.5, -0.05, 0.004)), radius, P["nylon"], root)
        rig["strings"].append(peg_entry(anchor, anchor, saddle, nut, radius, peg, (0.06, 0, 0), tighten=side))
    rig["headCenter"] = to_usd(world(head, (0, 0, 0.06)))
    rig["bodyCenter"] = to_usd(Vector((0, 0, 0.4)))
    rig["length"] = h + 0.8
    return root, rig


# ---------------------------------------------------------------- zithers (movable bridges)

def build_zither(spec, length, width, n, start_midi_order, wood, bridge_mat, string_mat, pins=False):
    """Long arched board, strings along Z, one movable bridge per string on a diagonal."""
    P = palette()
    root = empty(spec.id)
    arch = 0.025
    stations = []
    for z in (0.0, length):
        top = [(width / 2 * (1 - 2 * k / 16), -0.03 - arch * math.sin(math.pi * k / 16), z) for k in range(17)]
        stations.append(top + [(-width / 2, 0.04, z), (width / 2, 0.04, z)])
    from blendkit import loft
    loft("board", stations, P[wood], root, sharp_angle=30)
    cube("head_cap", (width + 0.01, 0.09, 0.05), P["rosewood"], root, location=(0, 0.0, length - 0.02), bevel=0.006)
    cube("tail_cap", (width + 0.01, 0.09, 0.04), P["rosewood"], root, location=(0, 0.0, 0.02), bevel=0.006)
    fixed_z = length - 0.09
    cube("fixed_bridge", (width * 0.9, 0.012, 0.012), P["bone"], root, location=(0, -0.03 - arch - 0.006, fixed_z), bevel=0.002)
    rig = {"model": spec.id, "rig": "FRET_POSITION", "degPerCent": 1.0, "strings": []}
    for i, anchor in enumerate(spec.strings):
        k = start_midi_order[i]
        x = -width * 0.42 + width * 0.84 * i / max(1, n - 1)
        surface = -0.03 - arch * math.sin(math.pi * (0.5 - x / width))
        y = surface - 0.022
        radius = 0.0006 - 0.0003 * k / max(1, n - 1)
        # Low strings keep a long vibrating length (bridge far from the fixed end), high strings short.
        z_bridge = 0.25 + 0.5625 * (length - 0.4) * k / max(1, n - 1)
        top = Vector((x, y, fixed_z))
        bottom = Vector((x, y + 0.012, 0.06))
        segment(f"string_{anchor}", Vector((x, y, z_bridge)), top, radius, P[string_mat], root, vertices=8)
        segment(f"string_{anchor}_tail", Vector((x, y, z_bridge)), bottom, radius, P[string_mat], root, vertices=8)
        node = empty(f"peg_{anchor}", (x, surface, z_bridge), root)
        node.rotation_euler = (0, math.pi / 2, 0)  # local X points down the string: longer and lower
        # Node frame: local X runs down the string, Y toward the board, Z across.
        cube(f"ji_{anchor}", (0.006, 0.022, 0.022), P[bridge_mat], node, location=(0, -0.011, 0), bevel=0.0015)
        cube(f"ji_foot_{anchor}", (0.008, 0.004, 0.028), P[bridge_mat], node, location=(0, -0.002, 0), bevel=0.001)
        if pins:
            cylinder(f"pin_{anchor}", 0.0025, 0.03, P["nickel"], root, location=(x, -0.02, length - 0.04), rotation=(math.pi / 2, 0, 0), vertices=12)
        c = world(node, (0, 0, 0))
        rig["strings"].append({"anchor": anchor, "saddle": to_usd(Vector((x, y, z_bridge))), "nut": to_usd(top), "radius": round(radius, 6),
                               "wound": False, "peg": node.name, "post": node.name, "node": f"string_{anchor}",
                               "pegCenter": to_usd(c), "pegAxis": to_usd(Vector((0, 0, -1))), "tighten": 1,
                               "motion": "slide", "perCent": 0.0006})
    rig["headCenter"] = to_usd(Vector((0, -0.05, length * 0.45)))
    rig["bodyCenter"] = to_usd(Vector((0, 0, length / 2)))
    rig["length"] = length
    return root, rig


def build_koto(spec):
    order = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
    return build_zither(spec, 1.82, 0.25, 13, order, "spruce", "bone", "nylon")


def build_gayageum(spec):
    return build_zither(spec, 1.6, 0.28, 12, list(range(12)), "spruce", "rosewood", "gut")


def build_guzheng(spec):
    return build_zither(spec, 1.63, 0.32, 21, list(range(21)), "mahogany", "bone", "steel", pins=True)


# ---------------------------------------------------------------- oud and pipa (bent-back pegboxes)

def build_lute_like(spec, half, depth, scale, body_len, pegbox_tilt, pegbox_len, rosettes, frets=0, finish="spruce", pairs=True):
    P = palette()
    root = empty(spec.id)
    outline = mirrored_outline(half, 12)
    y_top = -depth * 0.25
    prism("bowl", outline, y_top + 0.002, y_top + depth, P["mahogany"], root, bevel=depth * 0.42, segments=6)
    prism("top", outline, y_top - 0.003, y_top + 0.004, P[finish], root, bevel=0.002)
    for k, (z, r) in enumerate(rosettes):
        disc(f"rosette_{k}", r, y_top - 0.0034, (0, z), P["rosette"], root)
        disc(f"rosette_hole_{k}", r * 0.75, y_top - 0.0036, (0, z), P["hole"], root)
    nut_z = body_len + scale * (0.25 if frets == 0 else 0.33)
    saddle_z = nut_z - scale
    width_nut, width_body = 0.04, 0.06
    stations = []
    for z in (body_len - 0.03, nut_z):
        w = width_body + (width_nut - width_body) * (z - body_len) / (nut_z - body_len)
        stations.append([(-w / 2, y_top - 0.004, z), (w / 2, y_top - 0.004, z), (w / 2, y_top + 0.025, z), (-w / 2, y_top + 0.025, z)])
    from blendkit import loft
    loft("neck", stations, P["ebony" if frets == 0 else "mahogany"], root, sharp_angle=20)
    for f in range(1, frets + 1):
        z = nut_z - scale * (1 - 2 ** (-f / 12)) * (1.0 if f < 5 else 1.0)
        if z < body_len - 0.02:
            break
        cube(f"fret_{f:02d}", (0.05, 0.012 if f <= 4 else 0.004, 0.006), P["bone"], root, location=(0, y_top - 0.01, z), bevel=0.001)
    cube("bridge", (0.11, 0.008, 0.012), P["ebony"], root, location=(0, y_top - 0.007, saddle_z - 0.004), bevel=0.002)
    head = empty("pegbox_frame", (0, y_top - 0.002, nut_z + 0.004), root)
    head.rotation_euler = (-math.radians(pegbox_tilt), 0, 0)
    cube("pegbox", (0.042, 0.03, pegbox_len), P["mahogany"], head, location=(0, 0.015, pegbox_len / 2), bevel=0.003)
    cube("pegbox_slot", (0.026, 0.002, pegbox_len - 0.02), P["hole"], head, location=(0, -0.0002, pegbox_len / 2))
    cube("nut", (0.044, 0.006, 0.004), P["bone"], root, location=(0, y_top - 0.012, nut_z + 0.002), bevel=0.0008)
    rig = {"model": spec.id, "rig": "STRING_PEG", "degPerCent": spec.deg_per_cent, "strings": []}
    courses = list(dict.fromkeys(spec.strings))
    n = len(spec.strings)
    for i, anchor in enumerate(spec.strings):
        occ = spec.strings[:i].count(anchor)
        name = anchor + "ab"[occ] if spec.strings.count(anchor) > 1 else anchor
        c = courses.index(anchor)
        x_bridge = -0.04 + 0.08 * (c + 0.5) / len(courses) + (occ - 0.5) * 0.004 * (spec.strings.count(anchor) > 1)
        x_nut = x_bridge * 0.5
        side = -1 if i % 2 == 0 else 1
        z_peg = 0.018 + (pegbox_len - 0.03) * (i // 2) / max(1, (n - 1) // 2)
        peg = friction_peg(f"peg_{name}", head, (0, 0.015, z_peg), side, 0.05, 0.014, P["ebony"])
        radius = 0.0006 - 0.00035 * c / max(1, len(courses) - 1)
        saddle = Vector((x_bridge, y_top - 0.013 - radius, saddle_z))
        nut = Vector((x_nut, y_top - 0.014 - radius, nut_z + 0.002))
        mat = P["gut"] if c < 2 else P["nylon"]
        segment(f"string_{name}", saddle, nut, radius, mat, root, vertices=8)
        segment(f"string_{name}_head", nut, world(head, (x_nut * 0.3, 0.004, z_peg)), radius, mat, root, vertices=6)
        segment(f"string_{name}_tail", saddle, saddle + Vector((0, 0.004, -0.008)), radius, mat, root, vertices=6)
        rig["strings"].append(peg_entry(anchor, name, saddle, nut, radius, peg, (0.055, 0, 0), tighten=side))
    rig["headCenter"] = to_usd(world(head, (0, 0.01, pegbox_len * 0.5)))
    rig["bodyCenter"] = to_usd(Vector((0, 0, body_len / 2)))
    rig["length"] = nut_z + pegbox_len
    return root, rig


OUD_HALF = [(0.0, 0.0), (0.09, 0.012), (0.155, 0.06), (0.18, 0.13), (0.175, 0.2), (0.15, 0.27), (0.11, 0.33), (0.06, 0.37), (0.028, 0.385), (0.0, 0.39)]
PIPA_HALF = [(0.0, 0.0), (0.1, 0.015), (0.145, 0.07), (0.15, 0.14), (0.13, 0.22), (0.095, 0.29), (0.055, 0.34), (0.026, 0.365), (0.0, 0.37)]


def build_oud(spec):
    return build_lute_like(spec, OUD_HALF, 0.17, 0.6, 0.39, 62, 0.19, [(0.24, 0.04), (0.15, 0.022), (0.33, 0.016)])


def build_pipa(spec):
    return build_lute_like(spec, PIPA_HALF, 0.06, 0.69, 0.37, 30, 0.14, [], frets=24, finish="mahogany")


FOLK = {
    "erhu": FolkSpec("erhu", "erhu", ["s2", "s1"], head_view=0.16, deg_per_cent=1.4),
    "shamisen": FolkSpec("shamisen", "shamisen", ["s3", "s2", "s1"], head_view=0.2),
    "koto": FolkSpec("koto", "koto", [f"bridge_{k}" for k in range(1, 14)], head_view=0.5),
    "gayageum": FolkSpec("gayageum", "gayageum", [f"bridge_{k}" for k in range(1, 13)], head_view=0.5),
    "guzheng": FolkSpec("guzheng", "guzheng", [f"s{k}" for k in range(21, 0, -1)], head_view=0.5),
    "oud": FolkSpec("oud", "oud", ["c6", "c5", "c5", "c4", "c4", "c3", "c3", "c2", "c2", "c1", "c1"], head_view=0.24, deg_per_cent=1.4),
    "pipa": FolkSpec("pipa", "pipa", ["s4", "s3", "s2", "s1"], head_view=0.2),
}
FOLK_BUILDERS = {"erhu": build_erhu, "shamisen": build_shamisen, "koto": build_koto, "gayageum": build_gayageum,
                 "guzheng": build_guzheng, "oud": build_oud, "pipa": build_pipa}
FOLK_PHOTOS = {
    "37_folk_world_strings_erhu": "erhu",
    "38_folk_world_strings_shamisen": "shamisen",
    "39_folk_world_strings_koto": "koto",
    "40_folk_world_strings_gayageum": "gayageum",
    "35_folk_world_strings_guzheng": "guzheng",
    "33_folk_world_strings_oud_arabic": "oud",
    "36_folk_world_strings_pipa": "pipa",
}
