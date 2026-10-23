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
    kind: str                 # acoustic | ukulele | mandolin | electric | electric_bass
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
    pickups: str = "p"        # p (split coil) | jj (two single coils) | hh (humbuckers) | none
    soundhole: str = "round"  # round | oval
    pot_r: float = 0.14       # banjo pot radius
    tuner_scale: float = 1.0  # tuner hardware size relative to a guitar's


def fret_distance(scale, n):
    return scale * (1 - 2 ** (-n / 12))


def guard_outline(outline, inset, cut_treble, cut_bass, lower):
    """Pickguard: the body outline inset by `inset` above two cut heights (treble side x > 0,
    bass side x <= 0), closed below by `lower` points listed from the bass side to the treble side."""
    pts = offset_outline(outline, -inset)
    keep = [(x > 0 and z >= cut_treble) or (x <= 0 and z >= cut_bass) for x, z in pts]
    n = len(pts)
    start = next(i for i in range(n) if keep[i] and not keep[i - 1])
    chain, i = [], start
    while keep[i % n] and len(chain) < n:
        chain.append(pts[i % n]); i += 1
    tail = lower if chain[0][0] > 0 else list(reversed(lower))
    return catmull_rom(chain[::3] + tail, 4, closed=True)


def build(spec: Spec):
    P = palette()
    root = empty(spec.id)
    depth = spec.body_depth
    y_top = -depth / 2
    small = spec.kind in ("ukulele", "mandolin")
    board_t = 0.006 if not small else 0.005
    y_board = y_top - board_t
    nut_z = spec.body_len + fret_distance(spec.scale, spec.body_fret)
    saddle_z = nut_z - spec.scale - 0.0015
    rig = {"model": spec.id, "rig": "MACHINE_HEAD", "strings": [], "degPerCent": spec.deg_per_cent}

    # ---------------------------------------------------------------- body
    outline = mirrored_outline(spec.body_half) if spec.body_half else catmull_rom(spec.body_full, 10, closed=True)
    xs = [p[0] for p in outline]; zs = [p[1] for p in outline]
    bounds = ((min(xs), min(zs)), (max(xs), max(zs)))
    hollow = spec.kind in ("acoustic", "ukulele", "mandolin")
    if hollow:
        prism("body_shell", offset_outline(outline, -0.0006), y_top + 0.003, -y_top, P[spec.back_wood], root, bevel=0.004)
        burst = spec.finish in ("sunburst", "cherry")
        prism("body_top", outline, y_top, y_top + 0.0035, P[spec.finish], root, bevel=0.0012, uv=fit_uv(bounds) if burst else box_uv(4.0))
        ring("binding_front", offset_outline(outline, 0.0011), offset_outline(outline, -0.0004), y_top - 0.0002, y_top + 0.004, P["cream"], root)
        ring("binding_back", offset_outline(outline, 0.0011), offset_outline(outline, -0.0004), -y_top - 0.004, -y_top + 0.0002, P["cream"], root)
        if spec.soundhole == "oval":
            def oval(rx, rz):
                return [(rx * math.cos(a), spec.soundhole_z + rz * math.sin(a)) for a in [2 * math.pi * k / 64 for k in range(64)]]
            r = spec.soundhole_r
            ring("rosette", oval(r * 0.62 + 0.004, r + 0.004), oval(r * 0.62, r), y_top - 0.0005, y_top + 0.0005, P["cream"], root)
            prism("soundhole", oval(r * 0.62, r), y_top - 0.0004, y_top + 0.0002, P["hole"], root)
        else:
            disc("soundhole", spec.soundhole_r, y_top - 0.0004, (0, spec.soundhole_z), P["hole"], root)
            disc("rosette", spec.soundhole_r / 0.8, y_top - 0.0003, (0, spec.soundhole_z), P["rosette"], root)
        if spec.guard:
            r, cz = spec.soundhole_r, spec.soundhole_z
            guard = catmull_rom([(r * 0.35, cz - r * 1.12), (r * 1.05, cz - r * 0.6), (r * 1.32, cz + r * 0.25), (r * 1.62, cz - r * 0.5),
                                 (r * 1.72, cz - r * 1.5), (r * 1.25, cz - r * 2.1), (r * 0.6, cz - r * 1.9)], 10, closed=True)
            prism("pickguard", guard, y_top - 0.0009, y_top - 0.0001, P[spec.guard], root, bevel=0.0004)
    elif spec.kind == "banjo":
        # Pot: maple rim behind a frosted head, chrome tension hoop and hooks, flange, resonator.
        r, cz = spec.pot_r, spec.pot_r
        def circ(radius, n=96):
            return [(radius * math.cos(a), cz + radius * math.sin(a)) for a in [2 * math.pi * k / n for k in range(n)]]
        prism("rim", circ(r), y_top + 0.004, y_top + 0.068, P["maple"], root, bevel=0.002)
        prism("flange", circ(r + 0.016), y_top + 0.05, y_top + 0.057, P["chrome"], root, bevel=0.001)
        prism("resonator", circ(r + 0.013), y_top + 0.057, y_top + 0.1, P[spec.back_wood], root, bevel=0.012, segments=4)
        disc("drumhead", r - 0.002, y_top, (0, cz), P["drumhead"], root, segments=128)
        ring("tension_hoop", circ(r + 0.003), circ(r - 0.005), y_top - 0.005, y_top + 0.003, P["chrome"], root)
        for k in range(24):
            a = 2 * math.pi * (k + 0.5) / 24
            ca, sa = math.cos(a), math.sin(a)
            segment(f"hook_{k:02d}", (ca * (r + 0.004), y_top - 0.003, cz + sa * (r + 0.004)), (ca * (r + 0.011), y_top + 0.05, cz + sa * (r + 0.011)),
                    0.0016, P["chrome"], root, vertices=8)
    else:
        prism("body", outline, y_top, -y_top, P[spec.finish], root, bevel=0.009, segments=4, uv=fit_uv(bounds))

    # ---------------------------------------------------------------- neck and fretboard
    heel_z = spec.body_len - (0.012 if hollow else 0.07)
    board_end_z = nut_z - fret_distance(spec.scale, spec.frets) - 0.006
    width_at = lambda z: spec.nut_width + (spec.saddle_width + 0.006 - spec.nut_width) * (nut_z - z) / spec.scale
    stations = []
    neck_depth_nut, neck_depth_heel = (0.020, 0.023) if not small else (0.015, 0.017)
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
    marks = [3, 5, 7, 9, 15, 17, 19] if spec.kind not in ("ukulele",) else [5, 7, 10, 12]
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
    saddle_top_y = y_top - (0.0115 if hollow else 0.012 if spec.kind == "banjo" else 0.0105)
    if spec.kind == "acoustic":
        cube("bridge", (spec.saddle_width + 0.09, 0.008, 0.028), P[spec.board], root, location=(0, y_top - 0.004, saddle_z - 0.004), bevel=0.003)
        cube("saddle", (spec.saddle_width + 0.012, 0.004, 0.003), P["bone"], root, location=(0, saddle_top_y + 0.0022, saddle_z))
    elif spec.kind == "ukulele":
        cube("bridge", (spec.saddle_width + 0.04, 0.008, 0.02), P[spec.board], root, location=(0, y_top - 0.004, saddle_z - 0.003), bevel=0.002)
        cube("saddle", (spec.saddle_width + 0.008, 0.004, 0.0028), P["bone"], root, location=(0, saddle_top_y + 0.0022, saddle_z))
    elif spec.kind == "banjo":
        cube("bridge", (spec.saddle_width + 0.022, 0.012, 0.0032), P["bridge_maple"], root, location=(0, y_top - 0.006, saddle_z), bevel=0.0006)
        tail = [(-0.016, 0.006), (0.016, 0.006), (0.024, 0.075), (-0.024, 0.075)]
        prism("tailpiece", catmull_rom(tail, 3, closed=True), y_top - 0.006, y_top - 0.002, P["chrome"], root, bevel=0.001)
    elif spec.kind == "mandolin":
        # Floating bridge: ebony foot and adjustable saddle; strings anchor at a cover tailpiece.
        cube("bridge", (spec.saddle_width + 0.03, 0.006, 0.012), P[spec.board], root, location=(0, y_top - 0.003, saddle_z - 0.001), bevel=0.0015)
        cube("saddle", (spec.saddle_width + 0.012, 0.006, 0.004), P["ebony"], root, location=(0, saddle_top_y + 0.003, saddle_z), bevel=0.001)
        bottom = min(zs)
        cover = [(-spec.saddle_width * 0.55, bottom + 0.012), (spec.saddle_width * 0.55, bottom + 0.012),
                 (spec.saddle_width * 0.42, bottom + 0.075), (-spec.saddle_width * 0.42, bottom + 0.075)]
        prism("tailpiece", catmull_rom(cover, 3, closed=True), y_top - 0.0045, y_top - 0.0015, P["nickel"], root, bevel=0.0015)
    else:
        cube("bridge_plate", (spec.saddle_width + 0.022, 0.003, 0.075), P["chrome"], root, location=(0, y_top - 0.0015, saddle_z - 0.02), bevel=0.002)
        for i in range(n_strings):
            x = -spec.saddle_width / 2 + spec.saddle_width * i / max(1, n_strings - 1)
            cube(f"bridge_saddle_{i}", (spec.saddle_width / n_strings * 0.85, 0.007, 0.012), P["chrome"], root, location=(x, saddle_top_y + 0.0035, saddle_z - 0.004), bevel=0.001)

    # ---------------------------------------------------------------- electric hardware
    if spec.kind == "electric":
        # Humbuckers in cream-edged rings, master knobs and a pickup selector.
        k = spec.scale / 0.648
        for idx, dz in enumerate((0.04 * k, 0.125 * k)):
            cube(f"pickup_ring_{idx}", (spec.saddle_width + 0.026, 0.004, 0.046), P["satin_black"], root, location=(0, y_top - 0.0018, saddle_z + dz), bevel=0.003)
            cube(f"pickup_{idx}", (spec.saddle_width + 0.016, 0.009, 0.038), P["pickup_black"], root, location=(0, y_top - 0.005, saddle_z + dz), bevel=0.003)
            for row in (-1, 1):
                for i in range(len(set(spec.strings))):
                    x = -spec.saddle_width / 2 + spec.saddle_width * (i + 0.5) / len(set(spec.strings))
                    disc(f"pole_{idx}_{row}_{i}", 0.0022, y_top - 0.0096, (x, saddle_z + dz + row * 0.0095), P["nickel"], root, segments=16)
        for idx, (dx, dz) in enumerate(((0.09, -0.01), (0.105, 0.03), (0.088, 0.07))):
            cylinder(f"knob_{idx}", 0.0095, 0.015, P["satin_black"], root, location=(dx, y_top - 0.008, saddle_z + dz), rotation=(math.pi / 2, 0, 0), vertices=32)
        cylinder("selector", 0.0025, 0.022, P["chrome"], root, location=(-0.11, y_top - 0.011, saddle_z + 0.21 * k), rotation=(math.pi / 2, 0, 0), vertices=12)
    if spec.kind == "electric_bass":
        guard_pts = guard_outline(outline, 0.011, cut_treble=0.235, cut_bass=0.175,
                                  lower=[(-0.128, 0.168), (-0.09, 0.156), (-0.035, 0.158), (0.02, 0.17), (0.07, 0.192), (0.11, 0.222)])
        prism("pickguard", guard_pts, y_top - 0.0025, y_top + 0.0002, P[spec.guard or "white_guard"], root, bevel=0.0012)
        spread = spec.saddle_width
        if spec.pickups == "p":
            # Split coil: the E/A half sits nearer the neck than the D/G half.
            z_pick = saddle_z + 0.13
            for k, dx in enumerate((-0.019, 0.019)):
                cube(f"pickup_{k}", (0.04, 0.012, 0.021), P["pickup_black"], root,
                     location=(dx, y_top - 0.006, z_pick + (0.011 if k == 0 else -0.011)), bevel=0.004)
        else:
            for k, dz in enumerate((0.045, 0.135)):
                cube(f"pickup_{k}", (spread + 0.024, 0.012, 0.019), P["pickup_black"], root,
                     location=(0, y_top - 0.006, saddle_z + dz), bevel=0.005)
        knobs = 2 if spec.pickups == "p" else 3
        plate_len = 0.03 + 0.035 * knobs
        plate_z = saddle_z + 0.02
        plate = [(0.1 + 0.017 * math.cos(a), plate_z + (plate_len / 2 - 0.017) * (1 if math.sin(a) > 0 else -1) + 0.017 * math.sin(a))
                 for a in [math.pi * 2 * k / 48 for k in range(48)]]
        prism("control_plate", plate, y_top - 0.0014, y_top + 0.0002, P["chrome"], root, bevel=0.0006)
        for k in range(knobs):
            z = plate_z - plate_len / 2 + 0.032 + 0.035 * k
            cylinder(f"knob_{k}", 0.0105, 0.017, P["chrome"], root, location=(0.1, y_top - 0.0095, z), rotation=(math.pi / 2, 0, 0), vertices=40)

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
    prism("head_veneer", offset_outline(head_outline, -0.0006), -0.0016, 0.0004, P[spec.neck_wood if spec.kind == "electric_bass" else "ebony_satin"], head, bevel=0.0004, segments=2)

    # ---------------------------------------------------------------- strings, posts, tuners
    # Course pairs (mandolin, 12-string): strings sharing an anchor sit close together and
    # are named <anchor>a / <anchor>b; single strings keep the bare anchor.
    courses = list(dict.fromkeys(spec.strings))
    occurrence = [spec.strings[:i].count(a) for i, a in enumerate(spec.strings)]
    names = [a + "ab"[occurrence[i]] if spec.strings.count(a) > 1 else a for i, a in enumerate(spec.strings)]

    def string_x(i, width):
        c = courses.index(spec.strings[i])
        center = -width / 2 + width * (c + 0.5) / len(courses)
        if spec.strings.count(spec.strings[i]) > 1:
            center += (occurrence[i] - 0.5) * width / len(courses) * 0.36
        return center

    # A banjo's short fifth string tunes at a peg by the fifth fret; the head holds the other four.
    fifth = spec.kind == "banjo"
    head_strings = list(range(1, n_strings)) if fifth else list(range(n_strings))
    post_locals = {}
    # Strings never cross at the head: on split heads the outermost string runs to the
    # farthest post; on Fender-style inline heads the low string takes the post nearest the nut.
    if spec.head == "inline":
        for j, i in enumerate(head_strings):
            post_locals[i] = (-hw0 - 0.012, spec.post_s[j], -1)
    else:
        half_n = len(head_strings) // 2
        for j, i in enumerate(head_strings):
            if j < half_n:
                post_locals[i] = (-hw0 + 0.006 - 0.01, spec.post_s[half_n - 1 - j], -1)
            else:
                post_locals[i] = (hw0 - 0.006 + 0.01, spec.post_s[j - half_n], 1)

    ts = spec.tuner_scale
    for i, anchor in enumerate(spec.strings):
        name = names[i]
        radius = spec.gauges[i] * 1.25
        if fifth and i == 0:
            z5 = nut_z - fret_distance(spec.scale, 5)
            edge = -width_at(z5) / 2
            post = cylinder(f"post_{name}", 0.0028, 0.012, P["nickel"], root, location=(edge - 0.004, y_top + 0.004, z5), rotation=(0, math.pi / 2, 0), vertices=16)
            peg = empty(f"peg_{name}", (edge - 0.01, y_top + 0.004, z5), root)
            peg.rotation_euler = (0, 0, math.pi)
            cylinder(f"shaft_{name}", 0.0017, 0.01, P["nickel"], peg, location=(0.005, 0, 0), rotation=(0, math.pi / 2, 0), vertices=12)
            ellipsoid(f"button_{name}", (0.0075, 0.0032, 0.0065), P["button_pearl"], peg, location=(0.016, 0, 0))
            sx = string_x(0, spec.saddle_width)
            saddle_pt = Vector((sx, saddle_top_y - radius, saddle_z))
            nut_pt = Vector((edge + 0.003, y_board - 0.003 - radius, z5))
            cylinder(f"spike_{name}", 0.0011, 0.003, P["nickel"], root, location=(nut_pt.x, y_board - 0.0015, z5), rotation=(math.pi / 2, 0, 0), vertices=10)
            mat = P[spec.wound_material if spec.wound[i] else spec.string_material]
            segment(f"string_{name}", saddle_pt, nut_pt, radius, mat, root, vertices=10)
            segment(f"string_{name}_head", nut_pt, world(post, (0, 0, 0)), radius, mat, root, vertices=8)
            segment(f"string_{name}_tail", saddle_pt, Vector((sx * 0.6, y_top - 0.004, 0.07)), radius, mat, root, vertices=8)
            peg_world = world(peg)
            rig["strings"].append({
                "anchor": anchor, "saddle": to_usd(saddle_pt), "nut": to_usd(nut_pt), "radius": round(radius, 6),
                "wound": spec.wound[i], "peg": f"peg_{name}", "post": f"post_{name}", "node": f"string_{name}",
                "pegCenter": to_usd(peg_world), "pegAxis": to_usd((world(peg, (1, 0, 0)) - peg_world).normalized()), "tighten": 1,
            })
            continue
        px, ps, side = post_locals[i]
        post = cylinder(f"post_{name}", (0.0031 if spec.kind != "electric_bass" else 0.0045) * ts, 0.026, P["nickel"], head,
                        location=(px, -0.004, ps), rotation=(math.pi / 2, 0, 0), vertices=20)
        cylinder(f"bushing_{name}", (0.0046 if spec.kind != "electric_bass" else 0.007) * ts, 0.0028, P["nickel"], head,
                 location=(px, -0.0012, ps), rotation=(math.pi / 2, 0, 0), vertices=24)
        # Machine body on the back, shaft and button pointing outward.
        peg = empty(f"peg_{name}", (px + side * 0.008 * ts, head_t + 0.0055, ps + (0.0 if spec.head == "inline" else 0.004 * ts)), head)
        peg.rotation_euler = (0, 0, 0 if side > 0 else math.pi)
        cube(f"housing_{name}", (0.016 * ts, 0.009 * ts, 0.013 * ts), P["nickel"], head, location=(px + side * 0.001, head_t + 0.0055, ps + 0.002 * ts), bevel=0.0015 * ts)
        shaft_len = (0.016 if spec.head != "inline" else 0.022) * ts
        cylinder(f"shaft_{name}", 0.0017 * ts, shaft_len, P["nickel"], peg, location=(shaft_len / 2, 0, 0), rotation=(0, math.pi / 2, 0), vertices=12)
        if spec.button == "clover":
            for k in range(4):
                a = k * math.pi / 2 + math.pi / 4
                ellipsoid(f"button_{name}_{k}", (0.0028, 0.0055, 0.0055), P["nickel"], peg,
                          location=(shaft_len + 0.011, 0.007 * math.cos(a), 0.007 * math.sin(a)))
            ellipsoid(f"button_{name}", (0.003, 0.006, 0.006), P["nickel"], peg, location=(shaft_len + 0.011, 0, 0))
        else:
            mat = {"pearl": P["button_pearl"], "white": P["bone"], "metal": P["nickel"], "black": P["satin_black"]}[spec.button]
            size = (0.0085, 0.0034, 0.0072) if spec.kind != "ukulele" else (0.007, 0.003, 0.006)
            size = tuple(v * ts for v in size)
            ellipsoid(f"button_{name}", size, mat, peg, location=(shaft_len + size[0] * 0.9, 0, 0))

        # String path: saddle -> nut (speaking length, vibrates) -> post.
        sx = string_x(i, spec.saddle_width)
        nx = string_x(i, spec.nut_width - 0.006)
        saddle_pt = Vector((sx, saddle_top_y - radius, saddle_z))
        nut_pt = Vector((nx, y_board - 0.0035 - radius, nut_z + 0.0025))
        post_world = world(post, (0, 0, 0))
        toward_center = -1 if post_world.x > nx else 1
        head_pt = world(head, (px + toward_center * 0.0033, -0.009, ps))
        mat = P[spec.wound_material if spec.wound[i] else spec.string_material]
        segment(f"string_{name}", saddle_pt, nut_pt, radius, mat, root, vertices=10)
        segment(f"string_{name}_head", nut_pt, head_pt, radius, mat, root, vertices=8)
        if spec.kind == "mandolin":
            tail_pt = Vector((sx * 0.7, y_top - 0.005, min(zs) + 0.07))
        elif spec.kind == "banjo":
            tail_pt = Vector((sx * 0.6, y_top - 0.004, 0.07))
        else:
            tail_pt = saddle_pt + Vector((0, 0.004, -0.012 if spec.kind == "acoustic" else -0.025))
        segment(f"string_{name}_tail", saddle_pt, tail_pt, radius, mat, root, vertices=8)
        if spec.kind == "acoustic":
            pin = cylinder(f"pin_{name}", 0.0024, 0.006, P["bone"], root, location=(sx, y_top - 0.008, saddle_z - 0.013), rotation=(math.pi / 2, 0, 0), vertices=16)
            disc(f"pin_dot_{name}", 0.0011, y_top - 0.0112, (sx, saddle_z - 0.013), P["pearl"], root, segments=16)

        peg_world = world(peg)
        axis_world = (world(peg, (1, 0, 0)) - peg_world).normalized()
        rig["strings"].append({
            "anchor": anchor,
            "saddle": to_usd(saddle_pt),
            "nut": to_usd(nut_pt),
            "radius": round(radius, 6),
            "wound": spec.wound[i],
            "peg": f"peg_{name}",
            "post": f"post_{name}",
            "node": f"string_{name}",
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
# Offset-waist bass bodies, x > 0 is the treble side, listed counter-clockwise from the
# bottom centre. The neck pocket sits at the 17th fret; the bass horn reaches the 12th.
PBASS = [(0.0, 0.0), (0.08, 0.004), (0.13, 0.022), (0.158, 0.055), (0.168, 0.1), (0.166, 0.15), (0.152, 0.2),
         (0.136, 0.238), (0.13, 0.268), (0.134, 0.298), (0.141, 0.33), (0.144, 0.365), (0.142, 0.395), (0.134, 0.42),
         (0.121, 0.435), (0.106, 0.432), (0.092, 0.418), (0.075, 0.405), (0.055, 0.403), (0.034, 0.405),
         (-0.034, 0.405), (-0.052, 0.41), (-0.068, 0.425), (-0.08, 0.452), (-0.092, 0.482), (-0.104, 0.502),
         (-0.118, 0.508), (-0.132, 0.498), (-0.143, 0.47), (-0.15, 0.425), (-0.152, 0.375), (-0.146, 0.325),
         (-0.139, 0.285), (-0.142, 0.248), (-0.156, 0.2), (-0.166, 0.15), (-0.168, 0.1), (-0.158, 0.055),
         (-0.13, 0.022), (-0.08, 0.004)]
# Jazz: narrower, more offset waist and slimmer horns.
JBASS = [(0.0, 0.0), (0.08, 0.004), (0.128, 0.022), (0.155, 0.055), (0.165, 0.1), (0.162, 0.145), (0.146, 0.188),
         (0.128, 0.222), (0.12, 0.252), (0.123, 0.285), (0.132, 0.32), (0.138, 0.36), (0.137, 0.392), (0.13, 0.418),
         (0.118, 0.433), (0.104, 0.431), (0.09, 0.417), (0.074, 0.405), (0.054, 0.402), (0.034, 0.405),
         (-0.034, 0.405), (-0.052, 0.41), (-0.067, 0.426), (-0.079, 0.454), (-0.09, 0.485), (-0.101, 0.505),
         (-0.115, 0.511), (-0.129, 0.501), (-0.139, 0.472), (-0.144, 0.428), (-0.144, 0.38), (-0.137, 0.335),
         (-0.129, 0.3), (-0.131, 0.262), (-0.147, 0.212), (-0.16, 0.16), (-0.165, 0.105), (-0.156, 0.056),
         (-0.128, 0.022), (-0.08, 0.004)]


# Superstrat solid body (7-string, baritone): offset double cutaway, neck pocket at the 22nd fret.
SUPER = [(0.0, 0.0), (0.08, 0.004), (0.13, 0.025), (0.158, 0.06), (0.166, 0.105), (0.16, 0.15), (0.146, 0.19), (0.128, 0.222),
         (0.12, 0.25), (0.124, 0.28), (0.134, 0.31), (0.14, 0.345), (0.138, 0.38), (0.13, 0.41), (0.12, 0.435), (0.108, 0.447),
         (0.096, 0.44), (0.086, 0.42), (0.072, 0.405), (0.054, 0.398), (0.03, 0.402), (-0.03, 0.402), (-0.05, 0.408), (-0.066, 0.425),
         (-0.08, 0.452), (-0.093, 0.475), (-0.108, 0.488), (-0.124, 0.484), (-0.138, 0.462), (-0.147, 0.425), (-0.148, 0.38),
         (-0.141, 0.335), (-0.132, 0.3), (-0.132, 0.265), (-0.145, 0.222), (-0.16, 0.17), (-0.166, 0.115), (-0.158, 0.06),
         (-0.13, 0.025), (-0.08, 0.004)]
# A-style mandolin teardrop.
MANDO = [(0.0, 0.0), (0.06, 0.006), (0.1, 0.03), (0.122, 0.07), (0.126, 0.115), (0.118, 0.16), (0.1, 0.205), (0.076, 0.248),
         (0.05, 0.285), (0.03, 0.31), (0.018, 0.322), (0.0, 0.326)]
# Irish bouzouki: broad, round-shouldered.
BOUZ = [(0.0, 0.0), (0.08, 0.007), (0.13, 0.035), (0.158, 0.085), (0.165, 0.14), (0.155, 0.2), (0.13, 0.255), (0.095, 0.3),
        (0.055, 0.33), (0.024, 0.344), (0.0, 0.347)]
# Balalaika: the triangle.
BALA = [(0.0, 0.0), (0.2, 0.0), (0.212, 0.016), (0.13, 0.19), (0.05, 0.345), (0.022, 0.37), (0.0, 0.372)]
# Domra: round.
DOMRA = [(0.13 * math.sin(math.pi * k / 16), 0.13 - 0.13 * math.cos(math.pi * k / 16)) for k in range(17)]


def scaled(points, sx, sz):
    return [(x * sx, z * sz) for x, z in points]


def uke(id, scale, body_scale, frets):
    return Spec(id=id, kind="ukulele", strings=["s4", "s3", "s2", "s1"], gauges=[0.00035, 0.00042, 0.00038, 0.0003],
                wound=[False] * 4, scale=scale, nut_width=0.035, saddle_width=0.042, frets=frets, body_fret=12,
                body_len=0.24 * body_scale, body_depth=0.06 * body_scale, body_half=scaled(UKE, body_scale, body_scale),
                head="2+2", head_tilt=12, head_len=0.12, post_s=[0.035, 0.075], finish="mahogany", back_wood="mahogany",
                neck_wood="mahogany", board="rosewood", soundhole_z=0.15 * body_scale, soundhole_r=0.025 * body_scale,
                string_material="nylon", wound_material="nylon", button="white", deg_per_cent=2.0)


def mando(id, scale, body_scale, frets, gauges, wound, finish="sunburst", soundhole="oval", body=MANDO, head_len=0.13,
          body_fret=12, hole_at=0.74):
    k = body_scale
    return Spec(id=id, kind="mandolin", strings=["c4", "c4", "c3", "c3", "c2", "c2", "c1", "c1"], gauges=gauges, wound=wound,
                scale=scale, nut_width=0.029 * k ** 0.5, saddle_width=0.036 * k ** 0.5, frets=frets, body_fret=body_fret,
                body_len=body[-1][1] * k, body_depth=0.045 * k ** 0.7, body_half=scaled(body, k, k), head="4+4", head_tilt=15,
                head_len=head_len * k ** 0.6, post_s=[v * k ** 0.6 for v in (0.028, 0.054, 0.08, 0.106)], finish=finish,
                back_wood="maple", neck_wood="mahogany", board="rosewood", soundhole=soundhole,
                soundhole_z=body[-1][1] * k * hole_at, soundhole_r=0.032 * k, string_material="steel", wound_material="bronze",
                button="pearl", tuner_scale=0.8, deg_per_cent=1.6)


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
        finish="sunburst", neck_wood="maple_neck", board="rosewood", string_material="nickel_wound", wound_material="nickel_wound",
        button="clover", guard="white_guard", deg_per_cent=1.0),
    "bass_j5": Spec(
        id="bass_j5", kind="electric_bass", strings=["s5", "s4", "s3", "s2", "s1"], gauges=[0.0016, 0.00133, 0.00108, 0.00083, 0.00057],
        wound=[True] * 5, scale=0.864, nut_width=0.047, saddle_width=0.09, frets=20, body_fret=21, body_len=0.335,
        body_depth=0.045, body_full=JBASS, head="inline", head_tilt=0, head_len=0.235, post_s=[0.05, 0.085, 0.12, 0.155, 0.19],
        finish="cherry", neck_wood="maple_neck", board="rosewood", string_material="nickel_wound", wound_material="nickel_wound",
        button="clover", guard="black_guard", pickups="jj", deg_per_cent=1.0),
    "guitar_12": Spec(
        id="guitar_12", kind="acoustic", strings=["c6", "c6", "c5", "c5", "c4", "c4", "c3", "c3", "c2", "c2", "c1", "c1"],
        gauges=[0.00066, 0.00015, 0.00053, 0.00019, 0.00041, 0.00025, 0.00032, 0.00015, 0.0002, 0.0002, 0.00015, 0.00015],
        wound=[True, False, True, False, True, False, True, False, False, False, False, False],
        scale=0.645, nut_width=0.047, saddle_width=0.056, frets=20, body_fret=14, body_len=0.506, body_depth=0.105,
        body_half=DREAD, head="3+3", head_len=0.235, post_s=[0.03, 0.065, 0.1, 0.135, 0.17, 0.205], soundhole_z=0.355,
        soundhole_r=0.05, finish="spruce", back_wood="rosewood", guard="tortoise", button="metal", tuner_scale=0.8),
    "guitar_tenor": Spec(
        id="guitar_tenor", kind="acoustic", strings=["s4", "s3", "s2", "s1"], gauges=[0.0004, 0.00032, 0.0002, 0.00015],
        wound=[True, True, False, False], scale=0.58, nut_width=0.033, saddle_width=0.044, frets=19, body_fret=14,
        body_len=0.506 * 0.82, body_depth=0.09, body_half=scaled(DREAD, 0.8, 0.82), head="2+2", head_len=0.15, post_s=[0.045, 0.095],
        soundhole_z=0.355 * 0.82, soundhole_r=0.043, finish="mahogany", back_wood="mahogany", guard="tortoise"),
    "guitar_7": Spec(
        id="guitar_7", kind="electric", strings=["s7", "s6", "s5", "s4", "s3", "s2", "s1"],
        gauges=[0.0007, 0.00058, 0.00046, 0.00036, 0.00024, 0.00017, 0.00013], wound=[True, True, True, True, False, False, False],
        scale=0.648, nut_width=0.048, saddle_width=0.07, frets=24, body_fret=22, body_len=0.39, body_depth=0.04,
        body_full=SUPER, head="inline", head_tilt=0, head_len=0.2, post_s=[0.035 + 0.024 * i for i in range(7)],
        finish="black", neck_wood="maple_neck", board="ebony", string_material="steel", wound_material="nickel_wound",
        button="metal", pickups="hh", deg_per_cent=1.4),
    "guitar_baritone": Spec(
        id="guitar_baritone", kind="electric", strings=["s6", "s5", "s4", "s3", "s2", "s1"],
        gauges=[0.00084, 0.00066, 0.00051, 0.00038, 0.00025, 0.00018], wound=[True, True, True, True, False, False],
        scale=0.686, nut_width=0.043, saddle_width=0.054, frets=24, body_fret=22, body_len=0.39, body_depth=0.04,
        body_full=SUPER, head="inline", head_tilt=0, head_len=0.19, post_s=[0.035 + 0.026 * i for i in range(6)],
        finish="sunburst", neck_wood="maple_neck", board="rosewood", string_material="steel", wound_material="nickel_wound",
        button="metal", pickups="hh", deg_per_cent=1.3),
    "guitalele": Spec(
        id="guitalele", kind="ukulele", strings=["s6", "s5", "s4", "s3", "s2", "s1"],
        gauges=[0.00052, 0.00045, 0.00038, 0.00046, 0.00038, 0.00031], wound=[True, True, True, False, False, False],
        scale=0.43, nut_width=0.046, saddle_width=0.052, frets=18, body_fret=12, body_len=0.24 * 1.3, body_depth=0.07,
        body_half=scaled(UKE, 1.35, 1.3), head="3+3", head_tilt=12, head_len=0.14, post_s=[0.03, 0.065, 0.1],
        finish="spruce", back_wood="mahogany", neck_wood="mahogany", board="rosewood", soundhole_z=0.15 * 1.3,
        soundhole_r=0.034, string_material="nylon", wound_material="nylon_wound", button="white", deg_per_cent=1.8),
    "ukulele_baritone": Spec(
        id="ukulele_baritone", kind="ukulele", strings=["s4", "s3", "s2", "s1"], gauges=[0.00045, 0.00038, 0.00045, 0.00036],
        wound=[True, True, False, False], scale=0.48, nut_width=0.036, saddle_width=0.044, frets=19, body_fret=14,
        body_len=0.24 * 1.42, body_depth=0.078, body_half=scaled(UKE, 1.42, 1.42), head="2+2", head_tilt=12, head_len=0.13,
        post_s=[0.038, 0.08], finish="mahogany", back_wood="mahogany", neck_wood="mahogany", board="rosewood",
        soundhole_z=0.15 * 1.42, soundhole_r=0.035, string_material="nylon", wound_material="nylon_wound", button="white", deg_per_cent=1.8),
    "ukulele_bass": Spec(
        id="ukulele_bass", kind="ukulele", strings=["s4", "s3", "s2", "s1"], gauges=[0.0016, 0.0014, 0.0012, 0.001],
        wound=[False] * 4, scale=0.53, nut_width=0.04, saddle_width=0.05, frets=16, body_fret=14,
        body_len=0.24 * 1.55, body_depth=0.09, body_half=scaled(UKE, 1.55, 1.55), head="2+2", head_tilt=12, head_len=0.15,
        post_s=[0.04, 0.09], finish="spruce", back_wood="mahogany", neck_wood="mahogany", board="rosewood",
        soundhole_z=0.15 * 1.55, soundhole_r=0.038, string_material="satin_black", wound_material="satin_black",
        button="metal", tuner_scale=1.35, deg_per_cent=1.2),
    "mandolin": mando("mandolin", 0.35, 1.0, 17, [0.0005, 0.0005, 0.00033, 0.00033, 0.00019, 0.00019, 0.00014, 0.00014],
                      [True, True, True, True, False, False, False, False]),
    "mandola": mando("mandola", 0.42, 1.15, 17, [0.0006, 0.0006, 0.0004, 0.0004, 0.00025, 0.00025, 0.00017, 0.00017],
                     [True, True, True, True, False, False, False, False]),
    "mandolin_octave": mando("mandolin_octave", 0.53, 1.32, 17, [0.0007, 0.0007, 0.0005, 0.0005, 0.00033, 0.00033, 0.00023, 0.00023],
                             [True, True, True, True, True, True, False, False], finish="spruce", soundhole="round", hole_at=0.68),
    "mandocello": mando("mandocello", 0.63, 1.6, 17, [0.0010, 0.0010, 0.0007, 0.0007, 0.00048, 0.00048, 0.00033, 0.00033],
                        [True, True, True, True, True, True, False, False], soundhole="round", hole_at=0.68),
    "bouzouki_irish": mando("bouzouki_irish", 0.635, 1.1, 19, [0.0007, 0.0007, 0.0005, 0.0005, 0.00033, 0.00033, 0.00023, 0.00023],
                            [True, True, True, True, False, False, False, False], finish="spruce", soundhole="round", body=BOUZ,
                            head_len=0.17, body_fret=14, hole_at=0.68),
    "balalaika": Spec(
        id="balalaika", kind="mandolin", strings=["c2", "c2", "c1"], gauges=[0.00022, 0.00022, 0.00016], wound=[False] * 3,
        scale=0.44, nut_width=0.026, saddle_width=0.03, frets=20, body_fret=12, body_len=0.372, body_depth=0.11,
        body_half=BALA, head="2+1", head_tilt=12, head_len=0.12, post_s=[0.035, 0.075], finish="spruce", back_wood="maple",
        neck_wood="mahogany", board="rosewood", soundhole_z=0.24, soundhole_r=0.022, string_material="nylon",
        wound_material="nylon", button="pearl", tuner_scale=0.85, deg_per_cent=1.8),
    "domra": Spec(
        id="domra", kind="mandolin", strings=["s3", "s2", "s1"], gauges=[0.00028, 0.00022, 0.00016], wound=[True, False, False],
        scale=0.555, nut_width=0.026, saddle_width=0.03, frets=22, body_fret=17, body_len=0.26, body_depth=0.11,
        body_half=DOMRA, head="2+1", head_tilt=12, head_len=0.12, post_s=[0.035, 0.075], finish="spruce", back_wood="maple",
        neck_wood="mahogany", board="rosewood", soundhole_z=0.16, soundhole_r=0.026, string_material="steel",
        wound_material="bronze", button="pearl", tuner_scale=0.85, deg_per_cent=1.6),
    "banjo": Spec(
        id="banjo", kind="banjo", strings=["s5", "s4", "s3", "s2", "s1"], gauges=[0.00013, 0.00033, 0.00016, 0.00019, 0.00013],
        wound=[False, True, False, False, False], scale=0.67, nut_width=0.032, saddle_width=0.04, frets=22, body_fret=22,
        body_len=0.28, body_depth=0.1, body_half=[(0.0, 0.0), (0.154, 0.0), (0.154, 0.28), (0.0, 0.28)], head="2+2",
        head_tilt=13, head_len=0.15, post_s=[0.04, 0.09], neck_wood="maple_neck", back_wood="mahogany", board="rosewood",
        string_material="steel", wound_material="nickel_wound", button="pearl", deg_per_cent=1.5),
    "ukulele_soprano": uke("ukulele_soprano", 0.33, 1.0, 15),
    "ukulele_concert": uke("ukulele_concert", 0.38, 1.12, 18),
    "ukulele_tenor": uke("ukulele_tenor", 0.43, 1.26, 18),
}

# App photo asset -> model id (for thumbnails/hero renders).
PHOTO_MODELS = {
    "02_guitar_7_string_electric_guitar": "guitar_7",
    "03_guitar_12_string_acoustic_guitar": "guitar_12",
    "04_guitar_baritone_guitar": "guitar_baritone",
    "05_guitar_tenor_guitar": "guitar_tenor",
    "08_guitar_guitalele": "guitalele",
    "13_mandolin_mandolin": "mandolin",
    "14_mandolin_octave_mandolin": "mandolin_octave",
    "15_mandolin_mandola": "mandola",
    "16_mandolin_mandocello": "mandocello",
    "24_folk_world_strings_irish_bouzouki": "bouzouki_irish",
    "41_folk_world_strings_balalaika_prima": "balalaika",
    "42_folk_world_strings_domra": "domra",
    "baritone_ukulele": "ukulele_baritone",
    "22_folk_world_strings_banjo_5_string": "banjo",
    "bass_ukulele": "ukulele_bass",
    "01_guitar_acoustic_guitar": "guitar_acoustic",
    "06_bass_4_string_p_bass": "bass_p4",
    "07_bass_5_string_j_bass": "bass_j5",
    "10_ukulele_soprano_ukulele": "ukulele_soprano",
    "11_ukulele_concert_ukulele": "ukulele_concert",
    "12_ukulele_tenor_ukulele": "ukulele_tenor",
}
