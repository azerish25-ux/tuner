"""Parametric fretted instruments (machine-head rig family).

Each build returns (root_object, rig_dict). Nodes the app animates are named
after the catalogue anchor ids: peg_<anchor>, post_<anchor>, string_<anchor>.
"""
import math
from dataclasses import dataclass, field

from mathutils import Vector

from blendkit import (box_uv, catmull_rom, cube, cylinder, disc, ellipsoid, empty, fit_uv, loft,
                      mirrored_outline, offset_outline, palette, prism, ring, segment, to_usd, world)


@dataclass
class Spec:
    id: str
    kind: str                 # acoustic | ukulele | electric_bass | electric
    strings: list             # anchor ids, low (viewer's left) to high
    gauges: list              # string radius in metres
    wound: list               # bool per string
    scale: float
    nut_width: float
    saddle_width: float
    frets: int
    body_fret: int            # fret where the neck meets the body
    body_len: float
    body_depth: float
    body_half: list = field(default_factory=list)   # symmetric outline (half)
    body_full: list = field(default_factory=list)   # asymmetric closed outline
    head: str = "3+3"         # 3+3 | 2+2 | inline
    head_tilt: float = 14.0
    head_len: float = 0.19
    post_s: list = field(default_factory=list)      # distances from nut per post (per side for split heads)
    finish: str = "spruce"
    back_wood: str = "mahogany"
    neck_wood: str = "mahogany"
    board: str = "rosewood"
    soundhole_z: float = 0.0
    soundhole_r: float = 0.0
    bridge_z_offset: float = 0.0
    string_material: str = "steel"
    wound_material: str = "bronze"
    button: str = "pearl"     # pearl | metal | white | clover
    guard: str = ""           # tortoise | white | black
    deg_per_cent: float = 1.4


def fret_distance(scale, n):
    return scale * (1 - 2 ** (-n / 12))


def build(spec: Spec):
    P = palette()
    root = empty(spec.id)
    depth = spec.body_depth
    y_top = -depth / 2
    board_t = 0.006 if spec.kind != "ukulele" else 0.005
    y_board = y_top - board_t
    nut_z = spec.body_len + fret_distance(spec.scale, spec.body_fret)
    saddle_z = nut_z - spec.scale - 0.0015
    rig = {"model": spec.id, "rig": "MACHINE_HEAD", "strings": [], "degPerCent": spec.deg_per_cent}

    # ---------------------------------------------------------------- body
    outline = mirrored_outline(spec.body_half) if spec.body_half else catmull_rom(spec.body_full, 10, closed=True)
    xs = [p[0] for p in outline]; zs = [p[1] for p in outline]
    bounds = ((min(xs), min(zs)), (max(xs), max(zs)))
    hollow = spec.kind in ("acoustic", "ukulele")
    if hollow:
        prism("body_shell", offset_outline(outline, -0.0006), y_top + 0.003, -y_top, P[spec.back_wood], root, bevel=0.004)
        prism("body_top", outline, y_top, y_top + 0.0035, P[spec.finish], root, bevel=0.0012, uv=box_uv(4.0))
        ring("binding_front", offset_outline(outline, 0.0011), offset_outline(outline, -0.0004), y_top - 0.0002, y_top + 0.004, P["cream"], root)
        ring("binding_back", offset_outline(outline, 0.0011), offset_outline(outline, -0.0004), -y_top - 0.004, -y_top + 0.0002, P["cream"], root)
        disc("soundhole", spec.soundhole_r, y_top - 0.0004, (0, spec.soundhole_z), P["hole"], root)
        disc("rosette", spec.soundhole_r / 0.8, y_top - 0.0003, (0, spec.soundhole_z), P["rosette"], root)
        if spec.guard:
            r, cz = spec.soundhole_r, spec.soundhole_z
            guard = catmull_rom([(r * 0.35, cz - r * 1.12), (r * 1.05, cz - r * 0.6), (r * 1.32, cz + r * 0.25), (r * 1.62, cz - r * 0.5),
                                 (r * 1.72, cz - r * 1.5), (r * 1.25, cz - r * 2.1), (r * 0.6, cz - r * 1.9)], 10, closed=True)
            prism("pickguard", guard, y_top - 0.0009, y_top - 0.0001, P[spec.guard], root, bevel=0.0004)
    else:
        prism("body", outline, y_top, -y_top, P[spec.finish], root, bevel=0.009, segments=4, uv=fit_uv(bounds))

    # ---------------------------------------------------------------- neck and fretboard
    heel_z = spec.body_len - (0.012 if hollow else 0.07)
    board_end_z = nut_z - fret_distance(spec.scale, spec.frets) - 0.006
    width_at = lambda z: spec.nut_width + (spec.saddle_width + 0.006 - spec.nut_width) * (nut_z - z) / spec.scale
    stations = []
    neck_depth_nut, neck_depth_heel = (0.020, 0.023) if spec.kind != "ukulele" else (0.015, 0.017)
    for i in range(9):
        z = heel_z + (nut_z + 0.003 - heel_z) * i / 8
        w = width_at(z) + 0.001
        d = neck_depth_heel + (neck_depth_nut - neck_depth_heel) * i / 8
        ring_pts = []
        for k in range(17):
            a = math.pi * k / 16
            ring_pts.append((w / 2 * math.cos(a), y_top + d * math.sin(a), z))
        stations.append(ring_pts)
    loft("neck", stations, P[spec.neck_wood], root)

    board_stations = []
    for z in (board_end_z, nut_z):
        w = width_at(z)
        board_stations.append([(-w / 2, y_top + 0.0005, z), (w / 2, y_top + 0.0005, z), (w / 2, y_board, z), (-w / 2, y_board, z)])
    loft("fretboard", board_stations, P[spec.board], root, sharp_angle=20)

    for n in range(1, spec.frets + 1):
        z = nut_z - fret_distance(spec.scale, n)
        w = width_at(z)
        segment(f"fret_{n:02d}", (-w / 2, y_board + 0.0003, z), (w / 2, y_board + 0.0003, z), 0.0011, P["fret"], root, vertices=8)
    marks = [3, 5, 7, 9, 15, 17, 19] if spec.kind != "ukulele" else [5, 7, 10, 12]
    for n in marks:
        if n > spec.frets:
            continue
        z = nut_z - (fret_distance(spec.scale, n) + fret_distance(spec.scale, n - 1)) / 2
        disc(f"inlay_{n:02d}", 0.003 if spec.kind != "electric_bass" else 0.0045, y_board - 0.0001, (0, z), P["pearl"], root, segments=24)
    if spec.frets >= 12 and spec.kind != "ukulele":
        z = nut_z - (fret_distance(spec.scale, 12) + fret_distance(spec.scale, 11)) / 2
        for x in (-width_at(z) / 4, width_at(z) / 4):
            d = disc("inlay_12", 0.003, y_board - 0.0001, (x, z), P["pearl"], root, segments=24)
            d.name = f"inlay_12_{'l' if x < 0 else 'r'}"
    cube("nut", (spec.nut_width + 0.0005, 0.0055, 0.0048), P["bone"], root, location=(0, y_board - 0.0012, nut_z + 0.0024), bevel=0.0006)

    # ---------------------------------------------------------------- bridge
    n_strings = len(spec.strings)
    saddle_top_y = y_top - (0.0115 if hollow else 0.0105)
    if spec.kind == "acoustic":
        cube("bridge", (spec.saddle_width + 0.09, 0.008, 0.028), P[spec.board], root, location=(0, y_top - 0.004, saddle_z - 0.004), bevel=0.003)
        cube("saddle", (spec.saddle_width + 0.012, 0.004, 0.003), P["bone"], root, location=(0, saddle_top_y + 0.0022, saddle_z))
    elif spec.kind == "ukulele":
        cube("bridge", (spec.saddle_width + 0.04, 0.008, 0.02), P[spec.board], root, location=(0, y_top - 0.004, saddle_z - 0.003), bevel=0.002)
        cube("saddle", (spec.saddle_width + 0.008, 0.004, 0.0028), P["bone"], root, location=(0, saddle_top_y + 0.0022, saddle_z))
    else:
        cube("bridge_plate", (spec.saddle_width + 0.022, 0.003, 0.075), P["chrome"], root, location=(0, y_top - 0.0015, saddle_z - 0.02), bevel=0.002)
        for i in range(n_strings):
            x = -spec.saddle_width / 2 + spec.saddle_width * i / max(1, n_strings - 1)
            cube(f"bridge_saddle_{i}", (spec.saddle_width / n_strings * 0.85, 0.007, 0.012), P["chrome"], root, location=(x, saddle_top_y + 0.0035, saddle_z - 0.004), bevel=0.001)

    # ---------------------------------------------------------------- electric hardware
    if spec.kind == "electric_bass":
        z_pick = saddle_z + 0.13
        guard_pts = catmull_rom([(-0.115, 0.22), (-0.125, 0.3), (-0.12, 0.37), (-0.1, 0.415), (-0.078, 0.398), (-0.056, 0.35),
                                 (-0.03, 0.336), (0.036, 0.334), (0.062, 0.346), (0.088, 0.372), (0.108, 0.37), (0.118, 0.32),
                                 (0.104, 0.24), (0.07, 0.19), (0.0, 0.17), (-0.07, 0.18)], 8, closed=True)
        prism("pickguard", guard_pts, y_top - 0.0025, y_top + 0.0002, P[spec.guard or "white_guard"], root, bevel=0.0012)
        for k, dx in enumerate((-0.018, 0.018)):
            cube(f"pickup_{k}", (0.036, 0.012, 0.022), P["pickup_black"], root, location=(dx - 0.004 + 0.008 * k, y_top - 0.006, z_pick + (0.01 if k else -0.01)), bevel=0.004)
        for k in range(2):
            cylinder(f"knob_{k}", 0.010, 0.016, P["chrome"], root, location=(0.10, y_top - 0.009, saddle_z + 0.015 + 0.04 * k), rotation=(math.pi / 2, 0, 0), vertices=32)

    # ---------------------------------------------------------------- headstock
    tilt = math.radians(spec.head_tilt)
    head_pivot = Vector((0, y_board + 0.002, nut_z + 0.005))
    head = empty("headstock_frame", tuple(head_pivot), root)
    head.rotation_euler = (-tilt, 0, 0)
    head_t = 0.014 if spec.kind != "ukulele" else 0.012
    hw0 = spec.nut_width / 2 + 0.003
    L = spec.head_len
    if spec.head == "inline":
        half = [(hw0, 0.0), (hw0 + 0.004, L * 0.25), (hw0 + 0.012, L * 0.55), (hw0 + 0.02, L * 0.8), (hw0 + 0.012, L * 0.97), (0.0, L * 1.0),
                (-hw0 - 0.03, L * 0.93), (-hw0 - 0.036, L * 0.75), (-hw0 - 0.03, L * 0.35), (-hw0 - 0.008, L * 0.08), (-hw0, 0.0)]
        head_outline = catmull_rom(half, 10, closed=True)
    else:
        head_half = [(0.0, 0.0), (hw0, 0.0), (hw0 + 0.006, L * 0.3), (hw0 + 0.012, L * 0.75), (hw0 + 0.01, L * 0.95), (hw0 * 0.5, L * 1.02), (0.0, L * 0.98)]
        head_outline = mirrored_outline(head_half, 10)
    prism("headstock", head_outline, 0.0, head_t, P[spec.neck_wood], head, bevel=0.0025)
    prism("head_veneer", head_outline, -0.0009, 0.0002, P["black" if spec.kind == "electric_bass" else spec.board], head, bevel=0.0006)

    # ---------------------------------------------------------------- strings, posts, tuners
    def string_x(i, width):
        return -width / 2 + width * (i + 0.5) / n_strings

    post_locals = []
    if spec.head == "inline":
        for i, anchor in enumerate(spec.strings):
            order = (n_strings - 1 - i) if spec.kind == "electric_bass" else i
            post_locals.append((-hw0 - 0.012, spec.post_s[order], -1))
    else:
        half_n = n_strings // 2
        for i, anchor in enumerate(spec.strings):
            if i < half_n:
                post_locals.append((-hw0 + 0.006 - 0.01, spec.post_s[i], -1))
            else:
                post_locals.append((hw0 - 0.006 + 0.01, spec.post_s[n_strings - 1 - i], 1))

    for i, anchor in enumerate(spec.strings):
        radius = spec.gauges[i] * 1.25
        px, ps, side = post_locals[i]
        post = cylinder(f"post_{anchor}", 0.0031 if spec.kind != "electric_bass" else 0.0045, 0.026, P["nickel"], head,
                        location=(px, -0.004, ps), rotation=(math.pi / 2, 0, 0), vertices=20)
        cylinder(f"bushing_{anchor}", 0.0046 if spec.kind != "electric_bass" else 0.007, 0.0028, P["nickel"], head,
                 location=(px, -0.0012, ps), rotation=(math.pi / 2, 0, 0), vertices=24)
        # Machine body on the back, shaft and button pointing outward.
        peg = empty(f"peg_{anchor}", (px + side * 0.008, head_t + 0.0055, ps + (0.0 if spec.head == "inline" else 0.004)), head)
        peg.rotation_euler = (0, 0, 0 if side > 0 else math.pi)
        cube(f"housing_{anchor}", (0.016, 0.009, 0.013), P["nickel"], head, location=(px + side * 0.001, head_t + 0.0055, ps + 0.002), bevel=0.0015)
        shaft_len = 0.016 if spec.head != "inline" else 0.022
        cylinder(f"shaft_{anchor}", 0.0017, shaft_len, P["nickel"], peg, location=(shaft_len / 2, 0, 0), rotation=(0, math.pi / 2, 0), vertices=12)
        if spec.button == "clover":
            for k in range(4):
                a = k * math.pi / 2 + math.pi / 4
                ellipsoid(f"button_{anchor}_{k}", (0.0028, 0.0055, 0.0055), P["nickel"], peg,
                          location=(shaft_len + 0.011, 0.007 * math.cos(a), 0.007 * math.sin(a)))
            ellipsoid(f"button_{anchor}", (0.003, 0.006, 0.006), P["nickel"], peg, location=(shaft_len + 0.011, 0, 0))
        else:
            mat = {"pearl": P["button_pearl"], "white": P["bone"], "metal": P["nickel"]}[spec.button]
            size = (0.0085, 0.0034, 0.0072) if spec.kind != "ukulele" else (0.007, 0.003, 0.006)
            ellipsoid(f"button_{anchor}", size, mat, peg, location=(shaft_len + size[0] * 0.9, 0, 0))

        # String path: saddle -> nut (speaking length, vibrates) -> post.
        sx = string_x(i, spec.saddle_width)
        nx = string_x(i, spec.nut_width - 0.006)
        saddle_pt = Vector((sx, saddle_top_y - radius, saddle_z))
        nut_pt = Vector((nx, y_board - 0.0035 - radius, nut_z + 0.0025))
        post_world = world(post, (0, 0, 0))
        toward_center = -1 if post_world.x > nx else 1
        head_pt = world(head, (px + toward_center * 0.0033, -0.009, ps))
        mat = P[spec.wound_material if spec.wound[i] else spec.string_material]
        segment(f"string_{anchor}", saddle_pt, nut_pt, radius, mat, root, vertices=10)
        segment(f"string_{anchor}_head", nut_pt, head_pt, radius, mat, root, vertices=8)
        tail_pt = saddle_pt + Vector((0, 0.004, -0.012 if spec.kind == "acoustic" else -0.025))
        segment(f"string_{anchor}_tail", saddle_pt, tail_pt, radius, mat, root, vertices=8)
        if spec.kind == "acoustic":
            pin = cylinder(f"pin_{anchor}", 0.0024, 0.006, P["bone"], root, location=(sx, y_top - 0.008, saddle_z - 0.013), rotation=(math.pi / 2, 0, 0), vertices=16)
            disc(f"pin_dot_{anchor}", 0.0011, y_top - 0.0112, (sx, saddle_z - 0.013), P["pearl"], root, segments=16)

        peg_world = world(peg)
        axis_world = (world(peg, (1, 0, 0)) - peg_world).normalized()
        rig["strings"].append({
            "anchor": anchor,
            "saddle": to_usd(saddle_pt),
            "nut": to_usd(nut_pt),
            "radius": round(radius, 6),
            "wound": spec.wound[i],
            "peg": f"peg_{anchor}",
            "post": f"post_{anchor}",
            "pegCenter": to_usd(peg_world),
            "pegAxis": to_usd(axis_world),
            "tighten": -side,
        })

    rig["headCenter"] = to_usd(world(head, (0, head_t / 2, L * 0.5)))
    rig["bodyCenter"] = to_usd(Vector((0, 0, spec.body_len * 0.5)))
    rig["length"] = round(nut_z + L, 4)
    return root, rig


# ---------------------------------------------------------------- catalogue of models

DREAD = [(0.0, 0.0), (0.105, 0.008), (0.168, 0.043), (0.196, 0.11), (0.191, 0.18), (0.163, 0.245), (0.137, 0.292),
         (0.141, 0.345), (0.149, 0.4), (0.133, 0.455), (0.094, 0.492), (0.042, 0.505), (0.0, 0.506)]
UKE = [(0.0, 0.0), (0.05, 0.005), (0.078, 0.034), (0.083, 0.072), (0.072, 0.11), (0.06, 0.132), (0.063, 0.162),
       (0.066, 0.196), (0.051, 0.226), (0.022, 0.239), (0.0, 0.24)]
PBASS = [(0.0, 0.0), (0.09, 0.008), (0.145, 0.04), (0.168, 0.10), (0.165, 0.165), (0.145, 0.215), (0.128, 0.255),
         (0.133, 0.295), (0.138, 0.335), (0.128, 0.37), (0.112, 0.388), (0.094, 0.38), (0.078, 0.352), (0.06, 0.332),
         (0.034, 0.326), (-0.034, 0.326), (-0.052, 0.34), (-0.068, 0.372), (-0.082, 0.41), (-0.096, 0.438),
         (-0.112, 0.448), (-0.128, 0.44), (-0.138, 0.41), (-0.14, 0.36), (-0.134, 0.30), (-0.128, 0.255),
         (-0.148, 0.21), (-0.168, 0.15), (-0.168, 0.095), (-0.146, 0.04), (-0.09, 0.008)]


def scaled(points, sx, sz):
    return [(x * sx, z * sz) for x, z in points]


def uke(id, scale, body_scale, frets):
    return Spec(id=id, kind="ukulele", strings=["s4", "s3", "s2", "s1"], gauges=[0.00035, 0.00042, 0.00038, 0.0003],
                wound=[False] * 4, scale=scale, nut_width=0.035, saddle_width=0.042, frets=frets, body_fret=12,
                body_len=0.24 * body_scale, body_depth=0.06 * body_scale, body_half=scaled(UKE, body_scale, body_scale),
                head="2+2", head_tilt=12, head_len=0.12, post_s=[0.035, 0.075], finish="mahogany", back_wood="mahogany",
                neck_wood="mahogany", board="rosewood", soundhole_z=0.15 * body_scale, soundhole_r=0.025 * body_scale,
                string_material="nylon", wound_material="nylon", button="white", deg_per_cent=2.0)


MODELS = {
    "guitar_acoustic": Spec(
        id="guitar_acoustic", kind="acoustic", strings=["s6", "s5", "s4", "s3", "s2", "s1"],
        gauges=[0.00066, 0.00053, 0.00041, 0.00031, 0.00029, 0.00015], wound=[True, True, True, True, False, False],
        scale=0.645, nut_width=0.043, saddle_width=0.054, frets=20, body_fret=14, body_len=0.506, body_depth=0.105,
        body_half=DREAD, head="3+3", post_s=[0.048, 0.093, 0.138], soundhole_z=0.355, soundhole_r=0.05,
        guard="tortoise"),
    "bass_p4": Spec(
        id="bass_p4", kind="electric_bass", strings=["s4", "s3", "s2", "s1"], gauges=[0.00133, 0.00108, 0.00083, 0.00057],
        wound=[True] * 4, scale=0.864, nut_width=0.042, saddle_width=0.076, frets=20, body_fret=21, body_len=0.335,
        body_depth=0.045, body_full=PBASS, head="inline", head_tilt=0, head_len=0.2, post_s=[0.05, 0.088, 0.126, 0.164],
        finish="sunburst", neck_wood="maple", board="rosewood", string_material="nickel_wound", wound_material="nickel_wound",
        button="clover", guard="tortoise", deg_per_cent=1.0),
    "bass_j5": Spec(
        id="bass_j5", kind="electric_bass", strings=["s5", "s4", "s3", "s2", "s1"], gauges=[0.0016, 0.00133, 0.00108, 0.00083, 0.00057],
        wound=[True] * 5, scale=0.864, nut_width=0.047, saddle_width=0.09, frets=20, body_fret=21, body_len=0.335,
        body_depth=0.045, body_full=PBASS, head="inline", head_tilt=0, head_len=0.235, post_s=[0.05, 0.085, 0.12, 0.155, 0.19],
        finish="cherry", neck_wood="maple", board="rosewood", string_material="nickel_wound", wound_material="nickel_wound",
        button="clover", guard="white_guard", deg_per_cent=1.0),
    "ukulele_soprano": uke("ukulele_soprano", 0.33, 1.0, 15),
    "ukulele_concert": uke("ukulele_concert", 0.38, 1.12, 18),
    "ukulele_tenor": uke("ukulele_tenor", 0.43, 1.26, 18),
}

# App photo asset -> model id (for thumbnails/hero renders).
PHOTO_MODELS = {
    "01_guitar_acoustic_guitar": "guitar_acoustic",
    "06_bass_4_string_p_bass": "bass_p4",
    "07_bass_5_string_j_bass": "bass_j5",
    "10_ukulele_soprano_ukulele": "ukulele_soprano",
    "11_ukulele_concert_ukulele": "ukulele_concert",
    "12_ukulele_tenor_ukulele": "ukulele_tenor",
}
