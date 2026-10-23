"""Violin family (friction-peg rig): violin, viola, cello, double bass.

Same conventions as instruments.py: Blender X right, -Y toward the player, Z up, body
bottom at z = 0. Animated nodes: peg_<anchor> (rotates about its local X, the shaft
axis), string_<anchor> (speaking length, bridge -> nut).
"""
import math
from dataclasses import dataclass, field

from mathutils import Vector

from blendkit import (catmull_rom, cube, cylinder, disc, ellipsoid, empty, fit_uv, loft, mirrored_outline,
                      offset_outline, palette, prism, ring, segment, to_usd, world)

# Half outline of a 356 mm violin body, (x >= 0, z) in millimetres from the bottom centre.
VIOLIN_HALF = [(0, 0), (30, 2), (60, 10), (85, 28), (100, 55), (104, 90), (101, 115), (97, 127), (93, 137),
               (90, 146), (88.5, 151.5), (86.5, 153.2), (82, 153.4), (74, 155), (66, 161), (60, 171), (56.8, 183),
               (56, 192), (57, 203), (61, 214), (68, 224), (76, 230.5), (81, 233.5), (82.2, 235.5), (81.2, 238.5),
               (81.5, 246), (84, 258), (85, 270), (83, 290), (76, 310), (62, 330), (41, 347), (20, 354), (0, 356)]


@dataclass
class BowedSpec:
    id: str
    strings: list            # anchors, low (viewer's left) to high
    gauges: list             # radius, metres
    scale: float             # vibrating length nut -> bridge
    size: float              # body length / 0.356
    rib: float               # rib depth
    arch: float              # top arching height
    neck: float              # nut -> body edge
    stop: float              # body top edge -> bridge
    bridge_h: float
    board_len: float
    peg_z: list              # peg positions along the pegbox per string (same order as strings)
    peg_side: list           # -1 head on the viewer's left, +1 right
    pegbox_len: float
    kind: str = "bowed"
    chinrest: bool = False
    endpin: float = 0.0
    fine_tuners: list = field(default_factory=list)  # anchors with a fine tuner
    deg_per_cent: float = 1.6
    machines: bool = False
    head_view: float = 0.16


def contour_scale(outline, center, x, z):
    """How far (x, z) sits between the centre (0) and the outline (1) along its ray."""
    d = Vector((x - center[0], z - center[1]))
    if d.length < 1e-9:
        return 0.0
    best = None
    n = len(outline)
    for i in range(n):
        a, b = Vector(outline[i]) - Vector(center), Vector(outline[(i + 1) % n]) - Vector(center)
        e = b - a
        den = d.x * e.y - d.y * e.x
        if abs(den) < 1e-12:
            continue
        t = (a.x * e.y - a.y * e.x) / den       # along the ray
        u = (a.x * d.y - a.y * d.x) / den       # along the edge
        if t > 0 and 0 <= u <= 1:
            best = t if best is None else min(best, t)
    return 1.0 / best if best else 1.0


def arch_profile(s):
    s = min(1.0, max(0.0, s))
    return math.sin(math.pi / 2 * (1 - s)) ** 1.4


def drape(obj, height):
    """Move every vertex toward the player by height(x, z) (decals on an arched plate)."""
    for v in obj.data.vertices:
        co = obj.matrix_basis @ v.co
        v.co.y -= height(co.x, co.z)


def f_hole(name, side, bottom, top, width, material, parent, y, height):
    """S-shaped sound hole with round eyes, draped on the arching."""
    pts_l, pts_r = [], []
    steps = 28
    bend = side * 1.5 * width
    for k in range(steps + 1):
        s = k / steps
        cx = bottom[0] + (top[0] - bottom[0]) * s + bend * math.sin(2 * math.pi * s)
        cz = bottom[1] + (top[1] - bottom[1]) * s
        w = width * (0.35 + 0.65 * math.sin(math.pi * s) ** 1.2)
        dx = (top[0] - bottom[0]) + bend * 2 * math.pi * math.cos(2 * math.pi * s)
        dz = top[1] - bottom[1]
        length = math.hypot(dx, dz)
        nx, nz = -dz / length, dx / length
        pts_l.append((cx + nx * w / 2, cz + nz * w / 2))
        pts_r.append((cx - nx * w / 2, cz - nz * w / 2))
    stroke = pts_l + list(reversed(pts_r))
    hole = prism(name, stroke, y - 0.0004, y + 0.0004, material, parent)
    drape(hole, height)
    for tag, (cx, cz), r in (("lo", bottom, width * 1.25), ("hi", top, width * 0.95)):
        eye = disc(f"{name}_{tag}", r, y - 0.0004, (cx, cz), material, parent, segments=24)
        drape(eye, height)
    return hole


def build_bowed(spec: BowedSpec):
    P = palette()
    root = empty(spec.id)
    k = spec.size
    outline = mirrored_outline([(x * k / 1000, z * k / 1000) for x, z in VIOLIN_HALF], 10)
    body_len = 0.356 * k
    center = (0.0, 0.53 * body_len)
    rib = spec.rib
    y_top, y_back = -rib / 2, rib / 2
    H = spec.arch

    def arch(x, z):
        return H * arch_profile(contour_scale(outline, center, x, z))

    rig = {"model": spec.id, "rig": "FRICTION_PEG", "strings": [], "degPerCent": spec.deg_per_cent}

    # ---------------------------------------------------------------- body
    prism("ribs", offset_outline(outline, -0.0025 * k ** 0.5), y_top + 0.002, y_back - 0.002, P["varnish_maple"], root, bevel=0.0015)
    prism("back", outline, y_back - 0.004, y_back + 0.0015, P["varnish_maple"], root, bevel=0.002)
    stations = [[(x, y_top + 0.004, z) for x, z in outline], [(x, y_top, z) for x, z in outline]]
    for s in [0.985, 0.96, 0.93, 0.89, 0.84, 0.78, 0.71, 0.63, 0.54, 0.44, 0.33, 0.22, 0.12, 0.04]:
        h = H * arch_profile(s)
        stations.append([(center[0] + (x - center[0]) * s, y_top - h, center[1] + (z - center[1]) * s) for x, z in outline])
    xs = [x for x, _ in outline]; zs = [z for _, z in outline]
    loft("top", stations, P["violin_top"], root, sharp_angle=80, uv=fit_uv(((min(xs), min(zs)), (max(xs), max(zs)))))
    purf = ring("purfling", offset_outline(outline, -0.0035 * k ** 0.5), offset_outline(outline, -0.0047 * k ** 0.5),
                y_top - 0.0006, y_top - 0.0002, P["black"], root)
    drape(purf, arch)

    # ---------------------------------------------------------------- string line
    bridge_z = body_len - spec.stop
    nut_z = body_len + spec.neck
    y_bridge = y_top - arch(0, bridge_z) - spec.bridge_h
    board_t = 0.0055 * k ** 0.6
    overstand = 0.0065 * k ** 0.7
    board_end = nut_z - spec.board_len
    gap_nut, gap_end = 0.0007 * k ** 0.5, 0.0045 * k ** 0.6

    def gap(z):
        return gap_nut + (gap_end - gap_nut) * (nut_z - z) / (nut_z - board_end)

    # String at the body joint sits board_t + overstand + gap above the plate edge.
    y_joint = y_top - overstand - board_t - gap(body_len)
    slope = (y_joint - y_bridge) / (body_len - bridge_z)

    def y_string(z):
        return y_bridge + (z - bridge_z) * slope

    def y_board(z):
        return y_string(z) + gap(z)

    nut_w, end_w = 0.0235 * k ** 0.75, 0.042 * k ** 0.75
    spread_bridge = 0.034 * k ** 0.75

    def board_w(z):
        return nut_w + (end_w - nut_w) * (nut_z - z) / spec.board_len

    # ---------------------------------------------------------------- neck and fingerboard
    neck_stations = []
    for i in range(9):
        z = body_len - 0.004 + (nut_z + 0.002 - body_len + 0.004) * i / 8
        w = board_w(z) - 0.0008
        top = y_board(z) + board_t
        depth = (0.019 + 0.002 * (1 - i / 8)) * k ** 0.75
        neck_stations.append([(w / 2 * math.cos(math.pi * a / 16), top + depth * math.sin(math.pi * a / 16), z) for a in range(17)])
    loft("neck", neck_stations, P["varnish_maple"], root)
    board_stations = []
    for z in (board_end, nut_z):
        w = board_w(z)
        radius = w * 1.7
        top = [(w / 2 * (1 - 2 * a / 12), y_board(z) + (radius - math.sqrt(max(0.0, radius * radius - (w / 2 * (1 - 2 * a / 12)) ** 2))), z)
               for a in range(13)]
        board_stations.append(top + [(-w / 2, y_board(z) + board_t, z), (w / 2, y_board(z) + board_t, z)])
    loft("fingerboard", board_stations, P["ebony"], root, sharp_angle=25)
    cube("nut", (nut_w + 0.001, 0.006 * k ** 0.6, 0.004 * k ** 0.6), P["ebony"], root,
         location=(0, y_board(nut_z) + 0.0012, nut_z + 0.002 * k ** 0.6), bevel=0.0008)

    # ---------------------------------------------------------------- bridge (arched maple, feet on the plate)
    bw = spread_bridge * 1.22
    bh = spec.bridge_h

    def bridge_top(x):
        return bh * (1 - 0.16 * (2 * x / bw) ** 2)

    legs = [(-bw * 0.44, bh * 0.2), (-bw / 2, 0), (-bw * 0.2, 0), (-bw * 0.14, bh * 0.16), (bw * 0.14, bh * 0.16), (bw * 0.2, 0),
            (bw / 2, 0), (bw * 0.44, bh * 0.2), (bw * 0.38, bh * 0.5)]
    arc = [(bw * 0.44 * (1 - 2 * a / 16), bridge_top(bw * 0.44 * (1 - 2 * a / 16))) for a in range(17)]
    bridge_outline = legs + arc + [(-bw * 0.38, bh * 0.5)]
    bridge = prism("bridge", bridge_outline, -0.0016 * k ** 0.6, 0.0016 * k ** 0.6, P["bridge_maple"], root, bevel=0.0004)
    bridge.rotation_euler = (math.pi / 2, 0, 0)
    bridge.location = (0, y_top - arch(0, bridge_z) + 0.0004, bridge_z)

    # ---------------------------------------------------------------- tailpiece, chinrest, endpin
    tail_top_z = bridge_z - (spec.scale / 6.2)
    tail_bot_z = 0.012 * k
    tail_w_top, tail_w_bot = spread_bridge * 1.15, spread_bridge * 0.55
    tail_stations = []
    for i in range(7):
        t = i / 6
        z = tail_top_z + (tail_bot_z - tail_top_z) * t
        w = tail_w_top + (tail_w_bot - tail_w_top) * t ** 1.3
        lift = (0.011 + (0.004 - 0.011) * t) * k ** 0.7
        y0 = y_top - arch(0, z) - lift
        th = 0.0045 * k ** 0.6
        tail_stations.append([(w / 2 * math.cos(math.pi * a / 12), y0 - th * 0.35 * math.sin(math.pi * a / 12) + th * 0.4, z) for a in range(13)]
                             + [(-w / 2, y0 + th, z), (w / 2, y0 + th, z)])
    loft("tailpiece", tail_stations, P["ebony"], root)
    segment("tailgut", (0, y_top - arch(0, tail_bot_z) - 0.003 * k ** 0.7, tail_bot_z), (0, y_top + 0.002, -0.002 * k), 0.0011 * k ** 0.6, P["satin_black"], root)
    ellipsoid("end_button", (0.004 * k ** 0.6, 0.004 * k ** 0.6, 0.003 * k ** 0.6), P["ebony"], root, location=(0, 0, -0.002 * k))
    if spec.chinrest:
        cr_z = 0.035 * k
        cr = ellipsoid("chinrest", (0.034 * k, 0.006 * k, 0.026 * k), P["ebony"], root,
                       location=(-0.045 * k, y_top - arch(-0.045 * k, cr_z) - 0.012 * k, cr_z))
        cylinder("chinrest_bracket", 0.0018, 0.012 * k, P["nickel"], root, location=(-0.03 * k, y_top - 0.004, 0.006 * k), vertices=10)
    if spec.endpin:
        segment("endpin_socket", (0, 0, 0.002), (0, 0, -0.03 * k ** 0.5), 0.009 * k ** 0.5, P["ebony"], root, vertices=20)
        segment("endpin", (0, 0, -0.03 * k ** 0.5), (0, 0, -spec.endpin), 0.0045 * k ** 0.4, P["chrome"], root, vertices=16)

    # ---------------------------------------------------------------- f-holes
    fy = y_top
    for side in (-1, 1):
        f_hole(f"fhole_{'l' if side < 0 else 'r'}", side, (side * 0.046 * k, bridge_z - 0.046 * k), (side * 0.034 * k, bridge_z + 0.03 * k),
               0.0028 * k ** 0.8, P["hole"], root, fy, arch)

    # ---------------------------------------------------------------- pegbox, scroll, pegs
    tilt = math.radians(15)
    head = empty("pegbox_frame", (0, y_board(nut_z) + 0.001, nut_z + 0.004 * k ** 0.6), root)
    head.rotation_euler = (-tilt, 0, 0)
    L = spec.pegbox_len
    pb_w0, pb_w1 = nut_w + 0.0015, nut_w * 0.86
    depth = 0.021 * k ** 0.75
    wall = 0.0026 * k ** 0.6
    for side in (-1, 1):
        cheek = [(0.0, 0.0), (0.0, L), (depth, L), (depth, 0.0)]
        c = prism(f"pegbox_cheek_{'l' if side < 0 else 'r'}", cheek, -wall / 2, wall / 2, P["varnish_maple"], head, bevel=0.0008)
        c.rotation_euler = (0, 0, math.pi / 2)  # outline (u, v) -> (y, z); thickness along x
        c.location = (side * (pb_w0 / 2 - wall / 2), 0, 0)
    cube("pegbox_back", (pb_w0, wall, L), P["varnish_maple"], head, location=(0, depth - wall / 2, L / 2), bevel=0.0006)
    cube("pegbox_throat", (pb_w0, depth, 0.008 * k ** 0.6), P["varnish_maple"], head, location=(0, depth / 2, 0.004 * k ** 0.6), bevel=0.0006)
    cube("pegbox_shadow", (pb_w0 - 2 * wall, 0.0008, L - 0.01 * k ** 0.6), P["hole"], head, location=(0, depth - wall - 0.0006, L / 2 + 0.003))
    # Scroll: a tapering square section swept along an inward spiral, in the head's YZ plane.
    c_y, c_z = depth * 0.42, L + 0.017 * k ** 0.75
    R0 = 0.0195 * k ** 0.75
    turns = 1.7
    sweep = []
    steps = 70
    for i in range(steps + 1):
        t = i / steps
        theta = math.radians(-90) + t * turns * 2 * math.pi
        r = R0 * (1 - 0.78 * t)
        w = (0.023 - 0.012 * t) * k ** 0.75
        thick = min(R0 * 0.78 / turns * (0.92 - 0.2 * t), r * 0.8)
        radial = Vector((0, math.cos(theta), math.sin(theta)))
        pts = []
        for a in range(16):
            ang = 2 * math.pi * a / 16
            u = math.copysign(abs(math.cos(ang)) ** 0.5, math.cos(ang)) * w / 2
            v = (math.copysign(abs(math.sin(ang)) ** 0.5, math.sin(ang)) * 0.5 - 0.5) * thick
            p = Vector((0, c_y, c_z)) + radial * (r + v) + Vector((u, 0, 0))
            pts.append(tuple(p))
        sweep.append(pts)
    loft("scroll", sweep, P["varnish_maple"], head, sharp_angle=60)
    eye_r = R0 * 0.22
    cylinder("scroll_eye", eye_r, (0.011 * k ** 0.75), P["varnish_maple"], head, location=(0, c_y, c_z), rotation=(0, math.pi / 2, 0), vertices=24)

    n = len(spec.strings)
    for i, anchor in enumerate(spec.strings):
        side = spec.peg_side[i]
        pz = spec.peg_z[i] * L
        w_here = pb_w0 + (pb_w1 - pb_w0) * pz / L
        peg = empty(f"peg_{anchor}", (0, depth * 0.45, pz), head)
        peg.rotation_euler = (0, 0, 0 if side > 0 else math.pi)
        shaft_len = w_here + 0.008 * k ** 0.6
        wood = P["gold"] if spec.machines else P["ebony"]
        cylinder(f"peg_shaft_{anchor}", 0.0028 * k ** 0.6, shaft_len, wood, peg, location=(shaft_len / 2 - w_here / 2 - 0.002, 0, 0),
                 rotation=(0, math.pi / 2, 0), radius_top=0.0036 * k ** 0.6, vertices=16)
        if spec.machines:
            cube(f"peg_gear_{anchor}", (0.006 * k ** 0.6, 0.016 * k ** 0.6, 0.016 * k ** 0.6), P["gold"], peg,
                 location=(w_here / 2 + 0.003 * k ** 0.6, 0, 0), bevel=0.001)
        else:
            cylinder(f"peg_collar_{anchor}", 0.0048 * k ** 0.6, 0.0025 * k ** 0.6, P["ebony"], peg,
                     location=(w_here / 2 + 0.005 * k ** 0.6, 0, 0), rotation=(0, math.pi / 2, 0), vertices=24)
        hx = w_here / 2 + 0.0135 * k ** 0.6
        ellipsoid(f"peg_head_{anchor}", (0.0078 * k ** 0.6, 0.0032 * k ** 0.6, 0.0088 * k ** 0.6), P["ebony"], peg, location=(hx, 0, 0))
        ellipsoid(f"peg_pip_{anchor}", (0.0016 * k ** 0.6, 0.0019 * k ** 0.6, 0.0016 * k ** 0.6), P["gold" if spec.machines else "bone"], peg,
                  location=(hx + 0.0085 * k ** 0.6, 0, 0))
        wound_x = (-1 if side > 0 else 1) * w_here * 0.18
        cylinder(f"peg_winding_{anchor}", 0.0036 * k ** 0.6, 0.0045 * k ** 0.6, P["gut"], peg, location=(wound_x * (1 if side > 0 else -1), 0, 0),
                 rotation=(0, math.pi / 2, 0), vertices=14)

        # String path: tailpiece -> bridge (speaking length) -> nut -> peg winding.
        x_bridge = -spread_bridge / 2 + spread_bridge * i / (n - 1)
        x_nut = -(nut_w - 0.006 * k ** 0.6) / 2 + (nut_w - 0.006 * k ** 0.6) * i / (n - 1)
        radius = spec.gauges[i]
        b_pt = Vector((x_bridge, y_top - arch(0, bridge_z) + 0.0004 - bridge_top(x_bridge) - radius, bridge_z))
        n_pt = Vector((x_nut, y_board(nut_z) - 0.0012 * k ** 0.5 - radius, nut_z + 0.0005))
        tail_pt = Vector((x_bridge * 0.72, y_top - arch(0, tail_top_z) - 0.011 * k ** 0.7 - 0.002, tail_top_z))
        mat = P["silver"] if i == 0 or (i == 1 and spec.size > 1.5) else (P["steel"] if i == n - 1 else P["gut"])
        segment(f"string_{anchor}", b_pt, n_pt, radius, mat, root, vertices=10)
        segment(f"string_{anchor}_tail", b_pt, tail_pt, radius, mat, root, vertices=8)
        peg_wind = world(peg, (wound_x * (1 if side > 0 else -1), 0, 0))
        segment(f"string_{anchor}_head", n_pt, peg_wind, radius, mat, root, vertices=8)
        if anchor in spec.fine_tuners:
            cube(f"fine_tuner_{anchor}", (0.006 * k ** 0.6, 0.006 * k ** 0.6, 0.012 * k ** 0.6), P["nickel"], root,
                 location=(tail_pt.x, tail_pt.y - 0.002, tail_pt.z - 0.006 * k ** 0.6), bevel=0.0008)
            cylinder(f"fine_tuner_screw_{anchor}", 0.0018 * k ** 0.6, 0.008 * k ** 0.6, P["gold"], root,
                     location=(tail_pt.x, tail_pt.y - 0.007 * k ** 0.6, tail_pt.z - 0.009 * k ** 0.6), rotation=(math.pi / 2, 0, 0), vertices=14)

        peg_world = world(peg)
        axis_world = (world(peg, (1, 0, 0)) - peg_world).normalized()
        rig["strings"].append({
            "anchor": anchor, "saddle": to_usd(b_pt), "nut": to_usd(n_pt), "radius": round(radius, 6),
            "wound": i == 0, "peg": f"peg_{anchor}", "post": f"peg_winding_{anchor}",
            "pegCenter": to_usd(world(peg, (w_here / 2 + 0.0135 * k ** 0.6, 0, 0))), "pegAxis": to_usd(axis_world),
            "tighten": -side,
        })

    rig["headCenter"] = to_usd(world(head, (0, depth * 0.3, L * 0.62)))
    rig["bodyCenter"] = to_usd(Vector((0, 0, body_len * 0.5)))
    rig["length"] = round(nut_z + L + 0.04 * k, 4)
    return root, rig


def violin_like(id, size, scale, rib, arch, neck, stop, bridge_h, board_len, pegbox_len, gauges, **extra):
    return BowedSpec(id=id, strings=["s4", "s3", "s2", "s1"], gauges=gauges, scale=scale, size=size, rib=rib, arch=arch,
                     neck=neck, stop=stop, bridge_h=bridge_h, board_len=board_len, peg_z=[0.78, 0.36, 0.2, 0.62],
                     peg_side=[-1, -1, 1, 1], pegbox_len=pegbox_len, **extra)


BOWED = {
    "violin": violin_like("violin", 1.0, 0.328, 0.031, 0.016, 0.13, 0.195, 0.033, 0.27, 0.072,
                          [0.0004, 0.00036, 0.00033, 0.00013], chinrest=True, fine_tuners=["s1"], head_view=0.13),
    "viola": violin_like("viola", 1.14, 0.37, 0.038, 0.018, 0.148, 0.22, 0.036, 0.3, 0.08,
                         [0.00052, 0.00042, 0.00037, 0.00031], chinrest=True, fine_tuners=["s1"], head_view=0.15),
    "cello": violin_like("cello", 2.12, 0.69, 0.12, 0.026, 0.28, 0.4, 0.09, 0.58, 0.16,
                         [0.00085, 0.00068, 0.00055, 0.00045], endpin=0.2, fine_tuners=["s1", "s2", "s3", "s4"],
                         deg_per_cent=1.4, head_view=0.28),
    "double_bass": violin_like("double_bass", 3.1, 1.06, 0.2, 0.03, 0.43, 0.59, 0.15, 0.86, 0.24,
                               [0.0013, 0.0011, 0.0009, 0.0007], endpin=0.25, machines=True, deg_per_cent=1.2, head_view=0.4),
}

BOWED_PHOTOS = {
    "17_bowed_strings_violin": "violin",
    "18_bowed_strings_viola": "viola",
    "19_bowed_strings_cello": "cello",
    "20_bowed_strings_double_bass_4_string": "double_bass",
}
