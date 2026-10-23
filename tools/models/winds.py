"""Winds and brass on the slide rig: the tuning slide, head joint, barrel or mouthpiece is a
slide node (peg_<anchor>) that moves along its local X, which points "out" (longer, lower).

Instruments are modelled upright (Z up) so they frame like the strings in a portrait stage.
"""
import math
from dataclasses import dataclass

from mathutils import Vector

from blendkit import arc_xz, cube, cylinder, disc, ellipsoid, empty, palette, to_usd, tube, world


@dataclass
class WindSpec:
    id: str
    kind: str
    anchors: tuple
    per_cent: float = 0.0004
    head_view: float = 0.22


def slide_node(name, location, out, parent):
    """Empty whose local X points along `out` (a unit axis in the parent's frame)."""
    node = empty(name, location, parent)
    out = Vector(out).normalized()
    node.rotation_mode = "QUATERNION"
    node.rotation_quaternion = Vector((1, 0, 0)).rotation_difference(out)
    return node


def entry(anchor, node, center, per_cent):
    c = world(node, center)
    axis = (world(node, (1, 0, 0)) - world(node)).normalized()
    return {"anchor": anchor, "saddle": to_usd(c), "nut": to_usd(c), "radius": 0.0, "wound": False,
            "peg": node.name, "post": node.name, "node": node.name, "pegCenter": to_usd(c), "pegAxis": to_usd(axis),
            "tighten": 1, "motion": "slide", "perCent": per_cent}


def flare(length, mouth, throat, steps=28, power=3.2):
    """Bell radii from mouth to throat (Bessel-like horn)."""
    return [throat + (mouth - throat) * (1 - k / steps) ** power for k in range(steps + 1)]


def bell(name, start, axis, length, mouth, throat, material, inner, parent, steps=28, power=3.2):
    """Flared bell with an open mouth: lacquered outside, darker throat inside."""
    axis = Vector(axis).normalized()
    pts = [Vector(start) + axis * (length * k / steps) for k in range(steps + 1)]
    radii = flare(length, mouth, throat, steps, power)
    tube(name, pts, radii, material, parent, sides=40, caps=False)
    tube(name + "_inside", pts, [r * 0.94 for r in radii], inner, parent, sides=40, caps=False, flip=True)
    tube(name + "_rim", [Vector(start) - axis * 0.0015, Vector(start) + axis * 0.0015], radii[0] * 1.012, material, parent, sides=48)


def u_bend(name, a, b, bulge_dir, radius, material, parent, steps=14):
    """Semicircular crook joining a and b, bulging toward bulge_dir."""
    a, b = Vector(a), Vector(b)
    center = (a + b) / 2
    r = (b - a).length / 2
    side = (a - center).normalized()
    out = Vector(bulge_dir).normalized()
    pts = [center + side * (r * math.cos(math.pi * k / steps)) + out * (r * math.sin(math.pi * k / steps)) for k in range(steps + 1)]
    tube(name, pts, radius, material, parent, sides=20)


# ---------------------------------------------------------------- brass

def build_trumpet(spec):
    P = palette()
    root = empty(spec.id)
    holder = empty("trumpet_frame", (0, 0, 0), root)
    # Modelled lying along X (bell at -X), then stood on its bell.
    holder.rotation_euler = (0, -math.pi / 2, 0)
    bore = 0.0058
    lq, inner = P["lacquer"], P["brass_throat"]
    bell("bell", (-0.25, 0, 0.02), (1, 0, 0), 0.2, 0.0615, 0.0068, lq, inner, holder)
    tube("bell_pipe", [(-0.05, 0, 0.02), (0.15, 0, 0.02)], bore, lq, holder)
    u_bend("bell_bow", (0.15, 0, 0.02), (0.15, 0, -0.04), (1, 0, 0), bore, lq, holder)
    tube("bell_return", [(0.15, 0, -0.04), (0.06, 0, -0.04)], bore, lq, holder)
    # Valves: three casings with caps, stems and pearl buttons (valve 1 nearest the player).
    for k, x in enumerate((0.0, 0.026, 0.052)):
        cylinder(f"valve_casing_{3 - k}", 0.0088, 0.09, lq, holder, location=(x, 0, -0.025), vertices=32)
        for z, h in ((0.022, 0.006), (-0.072, 0.008)):
            cylinder(f"valve_cap_{3 - k}_{'top' if z > 0 else 'bottom'}", 0.0098, h, lq, holder, location=(x, 0, z), vertices=32)
        cylinder(f"valve_stem_{3 - k}", 0.0022, 0.03, P["silver_plate"], holder, location=(x, 0, 0.04), vertices=12)
        cylinder(f"valve_button_{3 - k}", 0.0078, 0.004, P["pearl"], holder, location=(x, 0, 0.057), vertices=32)
    # Leadpipe from the mouthpiece to the main slide.
    tube("leadpipe", [(0.27, 0, -0.012), (0.12, 0, -0.02), (-0.03, 0, -0.04)], [0.0042, 0.0052, bore], lq, holder)
    tube("mouthpiece_shank", [(0.27, 0, -0.012), (0.31, 0, -0.01)], [0.0045, 0.0042], P["silver_plate"], holder)
    tube("mouthpiece_cup", [(0.31, 0, -0.01), (0.325, 0, -0.0095), (0.332, 0, -0.0093)], [0.0042, 0.012, 0.0128], P["silver_plate"], holder, sides=32)
    tube("bottom_pipe", [(-0.03, 0, -0.075), (0.0, 0, -0.075)], bore, lq, holder)
    # Main tuning slide: legs and crook move together toward the bell (out).
    main = slide_node("peg_main", (-0.03, 0, -0.0575), (-1, 0, 0), holder)
    tube("main_slide_upper", [(0, 0, 0.0175), (0.075, 0, 0.0175)], bore + 0.0006, lq, main)
    tube("main_slide_lower", [(0, 0, -0.0175), (0.075, 0, -0.0175)], bore + 0.0006, lq, main)
    u_bend("main_slide_crook", (0.075, 0, 0.0175), (0.075, 0, -0.0175), (1, 0, 0), bore + 0.0006, lq, main)
    cylinder("main_slide_water_key", 0.003, 0.012, P["silver_plate"], main, location=(0.09, 0, -0.026), rotation=(0, math.pi / 2, 0), vertices=12)
    # First valve slide (toward the mouthpiece) and third valve slide (toward the bell, with ring).
    v1 = slide_node("peg_valve_1", (0.06, 0, 0.045), (1, 0, 0), holder)
    tube("valve1_upper", [(0, 0, 0.008), (0.045, 0, 0.008)], bore, lq, v1)
    tube("valve1_lower", [(0, 0, -0.008), (0.045, 0, -0.008)], bore, lq, v1)
    u_bend("valve1_crook", (0.045, 0, 0.008), (0.045, 0, -0.008), (1, 0, 0), bore, lq, v1)
    v3 = slide_node("peg_valve_3", (-0.004, 0, -0.1), (-1, 0, 0), holder)
    tube("valve3_upper", [(0, 0, 0.009), (0.05, 0, 0.009)], bore, lq, v3)
    tube("valve3_lower", [(0, 0, -0.009), (0.05, 0, -0.009)], bore, lq, v3)
    u_bend("valve3_crook", (0.05, 0, 0.009), (0.05, 0, -0.009), (1, 0, 0), bore, lq, v3)
    tube("valve3_ring", [Vector((0.028, 0, -0.009)) + Vector((0.008 * math.cos(a), 0, -0.008 + 0.008 * math.sin(a)))
                         for a in [2 * math.pi * k / 24 for k in range(25)]], 0.0012, lq, v3, sides=10)
    tube("valve_connector", [(-0.004, 0, -0.091), (-0.004, 0, -0.072)], bore, lq, holder)
    tube("brace_bell", [(0.09, 0, 0.02), (0.09, 0, -0.015)], 0.0018, lq, holder)
    rig = {"model": spec.id, "rig": "VALVE_SLIDE", "degPerCent": 1.0,
           "strings": [entry("main", main, (0.07, 0, 0), spec.per_cent), entry("valve_1", v1, (0.04, 0, 0), spec.per_cent),
                       entry("valve_3", v3, (0.04, 0, 0), spec.per_cent)]}
    rig["headCenter"] = to_usd(world(holder, (0.0, 0, -0.03)))
    rig["bodyCenter"] = to_usd(world(holder, (0.0, 0, 0)))
    rig["length"] = 0.58
    return root, rig


def build_trombone(spec):
    P = palette()
    root = empty(spec.id)
    lq, inner = P["lacquer"], P["brass_throat"]
    bore = 0.0068
    # Bell section: bell down, neck up to the tuning slide, gooseneck over to the hand slide.
    bell("bell", (0.07, 0, 0.0), (0, 0, 1), 0.46, 0.108, 0.0068, lq, inner, root)
    tube("bell_neck", [(0.07, 0, 0.46), (0.07, 0, 0.74)], bore, lq, root)
    tube("tuning_inner_right", [(0.13, 0, 0.74), (0.13, 0, 0.62)], bore, lq, root)
    tune = slide_node("peg_main", (0.1, 0, 0.74), (0, 0, 1), root)
    tube("tuning_slide_left", [(0.0, 0, 0.03), (0.07, 0, 0.03)], bore + 0.0007, lq, tune)
    tube("tuning_slide_right", [(0.0, 0, -0.03), (0.07, 0, -0.03)], bore + 0.0007, lq, tune)
    u_bend("tuning_bow", (0.07, 0, 0.03), (0.07, 0, -0.03), (1, 0, 0), bore + 0.0007, lq, tune)
    tube("gooseneck", [(0.13, 0, 0.62), (0.13, 0, 0.6)] + arc_xz((0.065, 0.6), 0.065, 0, -180, 14)[1:], bore, lq, root)
    # Hand slide: two long tubes and the bottom crook, braced, with the mouthpiece on top.
    for x in (0.0, -0.045):
        tube(f"slide_inner_{'l' if x < 0 else 'r'}", [(x, 0, 0.6), (x, 0, 0.48)], bore, lq, root)
        tube(f"slide_outer_{'l' if x < 0 else 'r'}", [(x, 0, 0.48), (x, 0, -0.22)], bore + 0.0012, lq, root)
        cylinder(f"slide_stocking_{'l' if x < 0 else 'r'}", bore + 0.0022, 0.03, lq, root, location=(x, 0, -0.205), vertices=24)
    u_bend("slide_crook", (0.0, 0, -0.22), (-0.045, 0, -0.22), (0, 0, -1), bore + 0.0012, lq, root)
    tube("slide_brace_top", [(0.0, 0, 0.44), (-0.045, 0, 0.44)], 0.0026, lq, root)
    tube("slide_brace_bottom", [(0.0, 0, -0.17), (-0.045, 0, -0.17)], 0.0026, lq, root)
    tube("bell_brace", [(0.0, 0, 0.5), (0.07, 0, 0.5)], 0.0026, lq, root)
    tube("mouthpiece_shank", [(-0.045, 0, 0.6), (-0.045, 0, 0.64)], [0.0055, 0.0052], P["silver_plate"], root)
    tube("mouthpiece_cup", [(-0.045, 0, 0.64), (-0.045, 0, 0.66), (-0.045, 0, 0.668)], [0.0052, 0.0145, 0.0155], P["silver_plate"], root, sides=32)
    rig = {"model": spec.id, "rig": "MAIN_SLIDE", "degPerCent": 1.0, "strings": [entry("main", tune, (0.06, 0, 0), spec.per_cent)]}
    rig["headCenter"] = to_usd(Vector((0.08, 0, 0.72)))
    rig["bodyCenter"] = to_usd(Vector((0.03, 0, 0.25)))
    rig["length"] = 0.9
    return root, rig


def build_horn(spec):
    """French horn: coiled body, rotary valves, bell to the side; the main slide moves out."""
    P = palette()
    root = empty(spec.id)
    lq, inner = P["lacquer"], P["brass_throat"]
    bore = 0.0058
    # Two-and-a-half turns of coil around the centre, slowly widening toward the bell.
    turns, steps = 2.5, 120
    coil = []
    for k in range(steps + 1):
        t = k / steps
        a = math.radians(90) - t * turns * 2 * math.pi
        r = 0.095 + 0.03 * t
        coil.append((r * math.cos(a), (t - 0.5) * 0.03, 0.26 + r * math.sin(a)))
    tube("coil", coil, [bore + 0.004 * (k / steps) ** 2 for k in range(steps + 1)], lq, root)
    end = Vector(coil[-1])
    tube("bell_throat", [end, end + Vector((0.06, 0.01, -0.05)), end + Vector((0.11, 0.02, -0.12))], [bore + 0.004, 0.014, 0.024], lq, root)
    bell("bell", end + Vector((0.11 + 0.17, 0.02, -0.12 - 0.11)), (-0.83, 0, 0.55), 0.2, 0.152, 0.024, lq, inner, root)
    for k, z in enumerate((0.22, 0.26, 0.30)):
        cylinder(f"rotor_{k + 1}", 0.012, 0.03, lq, root, location=(-0.02, 0.02, z), rotation=(math.pi / 2, 0, 0), vertices=32)
        cube(f"lever_{k + 1}", (0.035, 0.004, 0.006), P["silver_plate"], root, location=(-0.05, -0.008, z), bevel=0.001)
    tube("leadpipe", [(-0.12, 0, 0.42), (-0.06, 0, 0.37), (-0.02, 0, 0.31)], [0.0045, 0.005, bore], lq, root)
    tube("mouthpiece", [(-0.12, 0, 0.42), (-0.15, 0, 0.45), (-0.157, 0, 0.456)], [0.0045, 0.0105, 0.0115], P["silver_plate"], root, sides=32)
    main = slide_node("peg_main", (0.02, 0, 0.12), (0, 0, -1), root)
    tube("main_slide_left", [(0, -0.015, 0), (0.05, -0.015, 0)], bore + 0.0006, lq, main)
    tube("main_slide_right", [(0, 0.015, 0), (0.05, 0.015, 0)], bore + 0.0006, lq, main)
    u_bend("main_slide_crook", (0.05, -0.015, 0), (0.05, 0.015, 0), (1, 0, 0), bore + 0.0006, lq, main)
    rig = {"model": spec.id, "rig": "VALVE_SLIDE", "degPerCent": 1.0, "strings": [entry("main", main, (0.045, 0, 0), spec.per_cent)]}
    rig["headCenter"] = to_usd(Vector((0.0, 0, 0.2)))
    rig["bodyCenter"] = to_usd(Vector((0.05, 0, 0.22)))
    rig["length"] = 0.5
    return root, rig


# ---------------------------------------------------------------- woodwinds

def keys_along(prefix, x, z0, z1, count, y, radius, material, parent, rod=True, P=None):
    for k in range(count):
        z = z0 + (z1 - z0) * k / max(1, count - 1)
        cylinder(f"{prefix}_{k:02d}", radius, 0.0025, material, parent, location=(x, y, z), rotation=(math.pi / 2, 0, 0), vertices=24)
        if P is not None:
            cylinder(f"{prefix}_pad_{k:02d}", radius * 0.75, 0.0016, P["pad"], parent, location=(x, y + 0.0008, z), rotation=(math.pi / 2, 0, 0), vertices=20)
    if rod:
        tube(f"{prefix}_rod", [(x + radius + 0.002, y + 0.003, z0 - 0.01), (x + radius + 0.002, y + 0.003, z1 + 0.01)], 0.0011, material, parent, sides=8)


def build_flute(spec):
    P = palette()
    root = empty(spec.id)
    ag = P["silver_plate"]
    r = 0.0095
    tube("foot_joint", [(0, 0, 0.0), (0, 0, 0.11)], r, ag, root, sides=32)
    tube("body_joint", [(0, 0, 0.11), (0, 0, 0.5)], r, ag, root, sides=32)
    cylinder("tenon_ring", r + 0.0012, 0.008, ag, root, location=(0, 0, 0.5), vertices=32)
    keys_along("body_key", 0, 0.16, 0.45, 9, -r - 0.0012, 0.0062, ag, root, P=P)
    keys_along("foot_key", 0.002, 0.03, 0.09, 3, -r - 0.0012, 0.0055, ag, root, P=P)
    head = slide_node("peg_joint", (0, 0, 0.5), (0, 0, 1), root)
    tube("headjoint", [(-0.03, 0, 0), (0.17, 0, 0)], r + 0.0005, ag, head, sides=32)
    cylinder("crown", r + 0.0018, 0.014, ag, head, location=(0.17 + 0.007, 0, 0), rotation=(0, math.pi / 2, 0), vertices=32)
    ellipsoid("crown_cap", (0.003, r + 0.0015, r + 0.0015), ag, head, location=(0.185, 0, 0))
    ellipsoid("lip_plate", (0.017, 0.0035, 0.012), ag, head, location=(0.12, -r - 0.0015, 0))
    ellipsoid("embouchure", (0.006, 0.002, 0.0045), P["hole"], head, location=(0.12, -r - 0.004, 0))
    rig = {"model": spec.id, "rig": "BARREL_JOINT", "degPerCent": 1.0, "strings": [entry("joint", head, (0.04, 0, 0), spec.per_cent)]}
    rig["headCenter"] = to_usd(Vector((0, -r, 0.6)))
    rig["bodyCenter"] = to_usd(Vector((0, 0, 0.33)))
    rig["length"] = 0.69
    return root, rig


def build_clarinet(spec):
    P = palette()
    root = empty(spec.id)
    bk, ag = P["grenadilla"], P["silver_plate"]
    r = 0.0125
    bell("bell", (0, 0, 0.0), (0, 0, 1), 0.11, 0.034, r, bk, P["hole"], root, steps=20)
    cylinder("bell_ring", 0.0345, 0.004, ag, root, location=(0, 0, 0.002), vertices=48)
    tube("lower_joint", [(0, 0, 0.11), (0, 0, 0.33)], r, bk, root, sides=32)
    tube("upper_joint", [(0, 0, 0.33), (0, 0, 0.56)], r, bk, root, sides=32)
    for z in (0.11, 0.33, 0.56):
        cylinder(f"ring_{int(z * 100)}", r + 0.0014, 0.005, ag, root, location=(0, 0, z), vertices=32)
    keys_along("lower_key", 0.0, 0.14, 0.31, 5, -r - 0.001, 0.0045, ag, root)
    keys_along("upper_key", 0.0, 0.36, 0.53, 6, -r - 0.001, 0.0045, ag, root)
    for k, z in enumerate((0.17, 0.21, 0.4, 0.44, 0.48)):
        cylinder(f"tone_ring_{k}", 0.0055, 0.0018, ag, root, location=(0.0, -r - 0.0005, z), rotation=(math.pi / 2, 0, 0), vertices=24)
    barrel = slide_node("peg_joint", (0, 0, 0.56), (0, 0, 1), root)
    tube("barrel", [(0.0, 0, 0), (0.065, 0, 0)], [r + 0.0035, r + 0.0025], bk, barrel, sides=32)
    cylinder("barrel_ring", r + 0.004, 0.004, ag, barrel, location=(0.002, 0, 0), rotation=(0, math.pi / 2, 0), vertices=32)
    tube("mouthpiece", [(0.065, 0, 0), (0.1, 0, 0), (0.125, 0, 0), (0.135, 0, 0)], [r, r - 0.0005, r - 0.004, r - 0.007], bk, barrel, sides=32)
    tube("ligature", [(0.075, 0, 0), (0.09, 0, 0)], r + 0.0009, ag, barrel, sides=32)
    cube("reed", (0.07, 0.0018, 0.013), P["cork"], barrel, location=(0.105, r - 0.001, 0), bevel=0.0005)
    rig = {"model": spec.id, "rig": "BARREL_JOINT", "degPerCent": 1.0, "strings": [entry("joint", barrel, (0.03, 0, 0), spec.per_cent)]}
    rig["headCenter"] = to_usd(Vector((0, -r, 0.6)))
    rig["bodyCenter"] = to_usd(Vector((0, 0, 0.34)))
    rig["length"] = 0.7
    return root, rig


def build_saxophone(spec):
    P = palette()
    root = empty(spec.id)
    lq, inner = P["lacquer"], P["brass_throat"]
    # Body: conical tube down to the bow, then up to the bell.
    body = [(0, 0, 0.58 - 0.46 * k / 20) for k in range(21)]
    tube("body", body, [0.012 + 0.016 * k / 20 for k in range(21)], lq, root, sides=36)
    bow = arc_xz((0.045, 0.12), 0.045, 180, 360, 18)
    tube("bow", bow, [0.028 + 0.006 * k / 18 for k in range(19)], lq, root, sides=36)
    # Bell: a long cone that turns out sharply at the rim, its mouth tipped toward the player's front.
    axis = Vector((-0.08, 0.12, -1)).normalized()  # camera sits on -Y, so the mouth leans toward it
    throat = Vector((0.09, 0, 0.126))
    bell("bell", throat - axis * 0.27, axis, 0.27, 0.066, 0.033, lq, inner, root, steps=36, power=5.5)
    tube("bell_bottom", [(0.09, 0, 0.118), (0.09, 0, 0.128)], 0.0335, lq, root, sides=36)
    for k in range(14):
        z = 0.53 - k * 0.028
        rr = 0.012 + 0.016 * (0.58 - z) / 0.46
        cylinder(f"key_cup_{k:02d}", 0.0085, 0.006, lq, root, location=(0.0, -rr - 0.004, z), rotation=(math.pi / 2, 0, 0), vertices=24)
        if k % 2 == 0:
            cylinder(f"key_pearl_{k:02d}", 0.006, 0.003, P["pearl"], root, location=(0.0, -rr - 0.0085, z), rotation=(math.pi / 2, 0, 0), vertices=24)
    tube("key_rod", [(0.016, -0.02, 0.56), (0.03, -0.035, 0.18)], 0.0014, lq, root, sides=8)
    # Neck: rising curve to the cork, the mouthpiece sits on it.
    neck = [(0, 0, 0.58), (-0.005, 0, 0.62), (-0.025, 0, 0.655), (-0.06, 0, 0.675), (-0.09, 0, 0.68)]
    tube("neck", neck, [0.012, 0.0105, 0.0095, 0.0085, 0.0078], lq, root, sides=28)
    cylinder("octave_key", 0.0045, 0.012, lq, root, location=(-0.03, -0.01, 0.655), rotation=(0, math.pi / 2, 0), vertices=16)
    tube("neck_cork", [(-0.09, 0, 0.68), (-0.115, 0, 0.681)], 0.0079, P["cork"], root, sides=24)
    # Pushing the mouthpiece further onto the cork (toward the body) raises pitch, so "out" is away from it.
    mp = slide_node("peg_key_1", (-0.105, 0, 0.6805), (-1, 0, 0), root)
    tube("mouthpiece", [(-0.045, 0, 0), (0.005, 0, 0), (0.025, 0, 0.002)], [0.0105, 0.0095, 0.006], P["grenadilla"], mp, sides=28)
    tube("ligature", [(-0.03, 0, 0), (-0.012, 0, 0)], 0.0108, P["silver_plate"], mp, sides=28)
    rig = {"model": spec.id, "rig": "KEY_TONEHOLE", "degPerCent": 1.0, "strings": [entry("key_1", mp, (-0.02, 0, 0), spec.per_cent)]}
    rig["headCenter"] = to_usd(Vector((-0.07, 0, 0.66)))
    rig["bodyCenter"] = to_usd(Vector((0.03, 0, 0.36)))
    rig["length"] = 0.7
    return root, rig


def build_recorder(spec):
    P = palette()
    root = empty(spec.id)
    wood = P["maple"]
    tube("foot", [(0, 0, 0.0), (0, 0, 0.045)], [0.0125, 0.011], wood, root, sides=32)
    tube("body", [(0, 0, 0.045), (0, 0, 0.245)], [0.0105, 0.0125], wood, root, sides=32)
    for k, z in enumerate((0.07, 0.095, 0.12, 0.15, 0.175, 0.2, 0.225)):
        disc(f"hole_{k}", 0.003 if k > 1 else 0.0024, -0.0128, (0, z), P["hole"], root, segments=20)
    head = slide_node("peg_joint", (0, 0, 0.245), (0, 0, 1), root)
    tube("head", [(-0.01, 0, 0), (0.075, 0, 0)], [0.0142, 0.0145], wood, head, sides=32)
    tube("beak", [(0.075, 0, 0), (0.095, 0, 0), (0.105, 0, 0.004)], [0.0145, 0.011, 0.006], wood, head, sides=32)
    cube("window", (0.009, 0.002, 0.006), P["hole"], head, location=(0.045, -0.0146, 0), bevel=0.0004)
    rig = {"model": spec.id, "rig": "BARREL_JOINT", "degPerCent": 1.0, "strings": [entry("joint", head, (0.03, 0, 0), spec.per_cent)]}
    rig["headCenter"] = to_usd(Vector((0, -0.012, 0.28)))
    rig["bodyCenter"] = to_usd(Vector((0, 0, 0.17)))
    rig["length"] = 0.35
    return root, rig


def build_whistle(spec):
    P = palette()
    root = empty(spec.id)
    tube("tube", [(0, 0, 0.0), (0, 0, 0.23)], 0.0062, P["nickel"], root, sides=28)
    for k, z in enumerate((0.05, 0.075, 0.1, 0.135, 0.16, 0.185)):
        disc(f"hole_{k}", 0.0026, -0.0064, (0, z), P["hole"], root, segments=18)
    head = slide_node("peg_key_1", (0, 0, 0.21), (0, 0, 1), root)
    tube("fipple", [(0, 0, 0), (0.06, 0, 0), (0.08, 0, 0.002)], [0.0085, 0.0085, 0.0055], P["satin_black"], head, sides=28)
    cube("window", (0.007, 0.002, 0.005), P["hole"], head, location=(0.012, -0.0086, 0), bevel=0.0003)
    rig = {"model": spec.id, "rig": "KEY_TONEHOLE", "degPerCent": 1.0, "strings": [entry("key_1", head, (0.03, 0, 0), spec.per_cent)]}
    rig["headCenter"] = to_usd(Vector((0, -0.007, 0.24)))
    rig["bodyCenter"] = to_usd(Vector((0, 0, 0.15)))
    rig["length"] = 0.3
    return root, rig


def build_shakuhachi(spec):
    P = palette()
    root = empty(spec.id)
    bamboo = P["maple"]
    tube("root_end", [(0, 0, 0.0), (0, 0, 0.06)], [0.021, 0.019], bamboo, root, sides=32)
    tube("lower", [(0, 0, 0.06), (0, 0, 0.27)], [0.019, 0.0175], bamboo, root, sides=32)
    for k, z in enumerate((0.07, 0.11, 0.16, 0.21, 0.24)):
        tube(f"node_{k}", [(0, 0, z - 0.004), (0, 0, z + 0.004)], 0.0198 - 0.0005 * k, P["mahogany"], root, sides=32)
    for k, z in enumerate((0.18, 0.21, 0.24, 0.27)):
        disc(f"hole_{k}", 0.0048, -0.0185, (0, z), P["hole"], root, segments=20)
    upper = slide_node("peg_joint", (0, 0, 0.27), (0, 0, 1), root)
    tube("upper", [(-0.02, 0, 0), (0.27, 0, 0)], [0.0177, 0.0165], bamboo, upper, sides=32)
    cylinder("joint_wrap", 0.0185, 0.012, P["satin_black"], upper, location=(0.0, 0, 0), rotation=(0, math.pi / 2, 0), vertices=32)
    cube("utaguchi", (0.012, 0.004, 0.008), P["bone"], upper, location=(0.265, -0.014, 0), bevel=0.001)
    rig = {"model": spec.id, "rig": "BARREL_JOINT", "degPerCent": 1.0, "strings": [entry("joint", upper, (0.02, 0, 0), spec.per_cent)]}
    rig["headCenter"] = to_usd(Vector((0, -0.018, 0.3)))
    rig["bodyCenter"] = to_usd(Vector((0, 0, 0.27)))
    rig["length"] = 0.55
    return root, rig


WINDS = {
    "trumpet": WindSpec("trumpet", "trumpet", ("main", "valve_1", "valve_3"), per_cent=0.0006, head_view=0.3),
    "trombone": WindSpec("trombone", "trombone", ("main",), per_cent=0.0008, head_view=0.35),
    "french_horn": WindSpec("french_horn", "horn", ("main",), per_cent=0.0006, head_view=0.35),
    "flute": WindSpec("flute", "flute", ("joint",), per_cent=0.0004, head_view=0.2),
    "clarinet": WindSpec("clarinet", "clarinet", ("joint",), per_cent=0.0004, head_view=0.2),
    "saxophone": WindSpec("saxophone", "saxophone", ("key_1",), per_cent=0.0004, head_view=0.22),
    "recorder": WindSpec("recorder", "recorder", ("joint",), per_cent=0.0003, head_view=0.16),
    "tin_whistle": WindSpec("tin_whistle", "whistle", ("key_1",), per_cent=0.0003, head_view=0.14),
    "shakuhachi": WindSpec("shakuhachi", "shakuhachi", ("joint",), per_cent=0.0004, head_view=0.2),
}
WIND_BUILDERS = {"trumpet": build_trumpet, "trombone": build_trombone, "horn": build_horn, "flute": build_flute,
                 "clarinet": build_clarinet, "saxophone": build_saxophone, "recorder": build_recorder,
                 "whistle": build_whistle, "shakuhachi": build_shakuhachi}
WIND_PHOTOS = {
    "54_winds_bb_trumpet": "trumpet",
    "55_winds_bb_trombone": "trombone",
    "56_winds_french_horn_in_f": "french_horn",
    "47_winds_concert_flute": "flute",
    "50_winds_clarinet_in_bb": "clarinet",
    "51_winds_clarinet_in_a": "clarinet",
    "52_winds_alto_eb_saxophone": "saxophone",
    "53_winds_tenor_bb_saxophone": "saxophone",
    "48_winds_soprano_recorder": "recorder",
    "49_winds_alto_recorder": "recorder",
    "58_winds_tin_whistle": "tin_whistle",
    "60_winds_shakuhachi_1_8_shaku": "shakuhachi",
}
