"""Turn an imported artist model into a Timbre stage asset: oriented, scaled, rigged, exported.

blender -b --factory-startup --python tools/models/sketchfab/convert.py -- build/import tools/models/sketchfab/rigs build/convert [model,model]

Each rigs/<model>.json names its download folder and how to read it:
  {"model": "violin", "source": "violin_queenrose", "length": 0.59, "headEnd": "A", "face": "back",
   "separate": true (split merged meshes into loose parts), "tilt": degrees about the face normal,
   "remove": [objects deleted (bows, stands)], "hide": [objects hidden],
   "materials": {name: {"metallic": 0, ...}}, "coat": [object name prefixes given a clear coat],
   "retouch": [{"material", "rects" (ink to remove) | "multiply" (tint)}] edits base colour images,
   "decimate": [{"re", "ratio", "minVerts"}] thins out needlessly dense parts,
   "rig": "FRICTION_PEG", "degPerCent": 1.2, "stringKind": "steel" | "bronze" | "nylon" | "gut",
   "nutZ" / "saddleZ": a height or parts whose mean height it is, "stringEnds": "rings" (low-poly strings),
   "nutEven" / "saddleEven": {"span", "pairGap"} to space bunched-up strings evenly,
   "originalStrings": "cut" (delete their speaking length) | "hide" (rebuild them thin) | "keep",
   "routeHeads": bend rebuilt strings in front of the other pegs on their way to their own,
   "strings": [{"anchor": "s4", "string": [original string parts], "peg": parts, "post": parts,
                "pegAxis": "post" | "pca" | [x,y,z], "postAxis": "front" | "pca" | [x,y,z], "tighten": 1,
                "head": parts (where a rebuilt string ends: its peg's winding), "hide": parts,
                "nut": [x, z], "saddle": [x, z] (when there is no "string"), "gauge": 0.0008, "wound": true}]}
Parts are a list of object names or a filter {"re", "box": [x0,x1,y0,y1,z0,z1], "maxExtent", "exclude"}.
Coordinates are metres in the normalised frame (head up +Z, face toward -Y, centred on the model): read
them off the calibration renders (centimetre grid) or the <model>.parts.npz dump. "auto" instead of
"strings" rigs machine heads modelled as named parts (see guitar_acoustic.json). Without either the run
only calibrates. Outputs per model: <model>.usdz, <model>.rig.json (with card2D: saddle, nut and peg of
each string on the hero render), <model>_hero.png and <model>_head.png, calibration renders + json.
"""
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector


def args():
    argv = sys.argv[sys.argv.index("--") + 1:]
    only = set(argv[3].split(",")) if len(argv) > 3 and argv[3] else set()
    return Path(argv[0]), Path(argv[1]), Path(argv[2]), only


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    try:
        scene.view_settings.view_transform = "AgX"
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    return scene


def import_model(folder: Path):
    source = next(iter(sorted(folder.glob("**/*.gltf"))), None) or next(iter(sorted(folder.glob("**/*.glb"))), None)
    bpy.ops.import_scene.gltf(filepath=str(source))
    bpy.context.view_layer.update()


def separate_loose():
    """Split merged meshes into their loose parts so pegs modelled inside one object can turn."""
    for obj in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.separate(type="LOOSE")
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()


def meshes():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def verts(obj, limit=60000):
    n = len(obj.data.vertices)
    co = np.empty(n * 3)
    obj.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    if n > limit:
        co = co[:: max(1, n // limit)]
    m = np.array(obj.matrix_world)
    return co @ m[:3, :3].T + m[:3, 3]


def matching(prefix):
    prefixes = prefix if isinstance(prefix, list) else [prefix]
    return [o for o in meshes() if any(o.name.startswith(p) for p in prefixes)]


def centre(obj):
    return verts(obj).mean(0)


def principal(points):
    _, vecs = np.linalg.eigh(np.cov((points - points.mean(0)).T))
    return vecs[:, 2]


def pivot(scene, name, root, center, local_axis, axis):
    """Empty at center whose given local axis points along axis, parented under root."""
    node = bpy.data.objects.new(name, None)
    scene.collection.objects.link(node)
    node.parent = root
    node.matrix_world = Matrix.Translation(Vector(center)) @ Vector(local_axis).rotation_difference(Vector(axis)).to_matrix().to_4x4()
    bpy.context.view_layer.update()
    return node


def adopt(node, objs):
    for obj in objs:
        world = obj.matrix_world.copy()
        obj.parent = node
        obj.matrix_world = world


def cut_speaking_length(obj, z_low, z_high):
    """Delete the faces of an original string between saddle and nut: the stage draws that part."""
    import bmesh
    mw = obj.matrix_world
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    doomed = [f for f in bm.faces if z_low < (mw @ f.calc_center_median()).z < z_high]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bm.to_mesh(obj.data)
    bm.free()


def crossing(obj, z):
    """Where a mesh crosses the plane at height z: the points on its edges (a string's ring)."""
    mw = np.array(obj.matrix_world)
    n = len(obj.data.vertices)
    co = np.empty(n * 3)
    obj.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
    e = np.empty(len(obj.data.edges) * 2, dtype=np.int64)
    obj.data.edges.foreach_get("vertices", e)
    e = e.reshape(-1, 2)
    a, b = co[e[:, 0]], co[e[:, 1]]
    da, db = a[:, 2] - z, b[:, 2] - z
    m = (da * db) < 0
    t = da[m] / (da[m] - db[m])
    return a[m] + (b[m] - a[m]) * t[:, None]


def auto_rig(scene, root, cfg, lo, hi, pts):
    """Machine heads modelled as separate parts: posts, keys, strings, nut and saddle by name."""
    auto = cfg["auto"]
    nut_z = float(np.concatenate([verts(o) for o in matching(auto["nut"])])[:, 2].mean())
    saddle_pts = np.concatenate([verts(o) for o in matching(auto["saddle"])])
    saddle_z = float(saddle_pts[:, 2].max()) if auto.get("saddleTop", True) else float(saddle_pts[:, 2].mean())
    posts = matching(auto["posts"])
    post_c = {o.name: centre(o) for o in posts}
    peg_parts = {prefix: matching(prefix) for prefix in auto["pegs"]}
    span = nut_z - saddle_z
    rows = []
    for obj in matching(auto["strings"]):
        v = verts(obj, limit=200000)
        rings = [crossing(obj, z) for z in (nut_z - span * 0.006, saddle_z + span * 0.006, (nut_z + saddle_z) / 2)]
        if any(len(r) == 0 for r in rings):
            print("string without a speaking length:", obj.name)
            continue
        nut, saddle = rings[0].mean(0), rings[1].mean(0)
        top = v[v[:, 2].argmax()]
        post = min(posts, key=lambda o: np.linalg.norm(post_c[o.name] - top))
        mid = rings[2]
        radius = float(np.linalg.norm(mid[:, [0, 1]] - mid[:, [0, 1]].mean(0), axis=1).mean())
        rows.append({"obj": obj, "nut": nut, "saddle": saddle, "post": post, "radius": radius})
    rows.sort(key=lambda r: r["nut"][0])
    anchors = cfg["anchors"]
    if len(rows) != len(anchors):
        raise ValueError(f"found {len(rows)} strings, rig expects {len(anchors)}")
    names = [a + "ab"[anchors[:i].count(a)] if anchors.count(a) > 1 else a for i, a in enumerate(anchors)]
    strings = []
    for row, anchor, name, k in zip(rows, anchors, names, range(len(rows))):
        pc = post_c[row["post"].name]
        post_axis = principal(verts(row["post"]))
        if post_axis @ np.array([0, -1, 0]) < 0:
            post_axis = -post_axis
        parts = [min(objs, key=lambda o: np.linalg.norm(centre(o) - pc)) for objs in peg_parts.values() if objs]
        key = parts[0]
        kc = centre(key)
        shaft = kc - pc
        shaft = shaft - post_axis * (shaft @ post_axis)
        shaft = shaft / np.linalg.norm(shaft)
        peg = pivot(scene, f"peg_{name}", root, kc, (1, 0, 0), shaft)
        adopt(peg, parts)
        post = pivot(scene, f"post_{name}", root, pc, (0, 0, 1), post_axis)
        adopt(post, [row["post"]])
        mat = row["obj"].material_slots[0].material if row["obj"].material_slots else string_material()
        cut_speaking_length(row["obj"], saddle_z + span * 0.004, nut_z - span * 0.004)
        r = max(row["radius"], 0.00025)
        cylinder_between(f"string_{name}", row["saddle"], row["nut"], r, mat, root)
        # The shaft axis points outward on both sides, so one sign tightens every machine.
        tighten = cfg.get("tighten", {}).get(anchor, 1)
        strings.append({"anchor": anchor, "saddle": to_usd(row["saddle"]), "nut": to_usd(row["nut"]), "radius": round(r, 6),
                        "wound": bool(cfg.get("wound", [False] * len(anchors))[k]), "peg": f"peg_{name}", "post": f"post_{name}",
                        "node": f"string_{name}", "pegCenter": to_usd(kc), "pegAxis": to_usd(shaft), "tighten": tighten})
    hc, hs = head_region(pts)
    rig = {"model": cfg["model"], "rig": cfg.get("rig", "MACHINE_HEAD"), "degPerCent": cfg.get("degPerCent", 1.4),
           "strings": strings, "headCenter": to_usd(hc), "bodyCenter": to_usd((lo + hi) / 2), "length": cfg["length"],
           "boundsMin": [min(a, b) for a, b in zip(to_usd(lo), to_usd(hi))], "boundsMax": [max(a, b) for a, b in zip(to_usd(lo), to_usd(hi))],
           "credit": cfg.get("credit")}
    return rig, hc, hs


def normalise(cfg):
    """Rotate/scale/centre everything under one root so the head points +Z and the face looks at -Y."""
    for name in cfg.get("remove", []):
        obj = bpy.data.objects.get(name)
        if obj:
            bpy.data.objects.remove(obj, do_unlink=True)
    for name in cfg.get("hide", []):
        obj = bpy.data.objects.get(name)
        if obj:
            obj.hide_render = True
            obj.hide_viewport = True
    visible = [o for o in meshes() if not o.hide_render]
    pts = np.concatenate([verts(o) for o in visible])
    mean = pts.mean(0)
    _, vecs = np.linalg.eigh(np.cov((pts - mean).T))
    long_axis, thin_axis = vecs[:, 2], vecs[:, 0]
    up = long_axis * (1 if cfg.get("headEnd", "A") == "A" else -1)
    # inspect.py's "front" renders look from +thin: a face seen there points along +thin.
    face = thin_axis * (1 if cfg.get("face", "front") == "front" else -1)
    auto = cfg.get("auto")
    if auto:  # the head is where the posts are; the face is the side the strings run on
        posts = np.concatenate([verts(o) for o in matching(auto["posts"])])
        strings = np.concatenate([verts(o) for o in matching(auto["strings"])])
        up = long_axis * (1 if (posts.mean(0) - mean) @ long_axis > 0 else -1)
        face = thin_axis * (1 if (strings.mean(0) - mean) @ thin_axis > 0 else -1)
    z = Vector(up).normalized()
    y = -Vector(face)
    y = (y - z * y.dot(z)).normalized()
    x = y.cross(z).normalized()
    rot = Matrix((x, y, z))  # rows: new axes expressed in old coordinates
    if cfg.get("tilt"):  # degrees about the face normal, to stand a lopsided outline's strings upright
        rot = Matrix.Rotation(math.radians(cfg["tilt"]), 3, "Y") @ rot
    up = np.array(rot[2])
    extent = float(((pts - mean) @ up).max() - ((pts - mean) @ up).min())
    scale = cfg["length"] / extent
    root = bpy.data.objects.new("Instrument", None)
    bpy.context.scene.collection.objects.link(root)
    for obj in list(bpy.context.scene.objects):
        if obj is not root and obj.parent is None:
            obj.parent = root
    root.matrix_world = Matrix.Diagonal((scale, scale, scale, 1.0)) @ rot.to_4x4() @ Matrix.Translation(-Vector(mean))
    bpy.context.view_layer.update()
    # Re-centre: the model's bounds centre on the origin in X/Y, its foot at z = 0.
    pts = np.concatenate([verts(o) for o in visible])
    lo, hi = pts.min(0), pts.max(0)
    root.matrix_world = Matrix.Translation(Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))) @ root.matrix_world
    bpy.context.view_layer.update()
    pts = np.concatenate([verts(o) for o in visible])
    return root, pts.min(0), pts.max(0)


def ortho_camera(scene, center, scale, from_front=True):
    data = bpy.data.cameras.new("cam")
    data.type = "ORTHO"
    data.ortho_scale = scale
    cam = bpy.data.objects.new("cam", data)
    scene.collection.objects.link(cam)
    direction = Vector((0, -1, 0)) if from_front else Vector((0, 1, 0))
    cam.location = Vector(center) + direction * 5
    cam.rotation_euler = (math.radians(90), 0, 0) if from_front else (math.radians(90), 0, math.radians(180))
    data.clip_end = 20
    scene.camera = cam
    return cam


def lacquer(prefixes):
    """Gloss finish: a clear coat over the named parts' materials (bodies and necks are lacquered)."""
    done = set()
    for obj in meshes():
        if not any(obj.name.startswith(p) for p in prefixes):
            continue
        for slot in obj.material_slots:
            mat = slot.material
            if not mat or mat.name in done or not mat.use_nodes:
                continue
            bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if bsdf and "Coat Weight" in bsdf.inputs:
                bsdf.inputs["Coat Weight"].default_value = 1.0
                bsdf.inputs["Coat Roughness"].default_value = 0.05
                done.add(mat.name)


def fix_materials(fixes):
    """Per-material corrections, e.g. {"wood": {"metallic": 0, "roughness": 0.4}} for wood exported as metal."""
    keys = {"metallic": "Metallic", "roughness": "Roughness", "baseColor": "Base Color", "coat": "Coat Weight", "alpha": "Alpha"}
    for name, values in fixes.items():
        mat = bpy.data.materials.get(name)
        bsdf = mat and mat.use_nodes and next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if not bsdf:
            print("no such material to fix:", name, flush=True)
            continue
        for key, value in values.items():
            socket = bsdf.inputs[keys[key]]
            for link in list(socket.links):  # a texture driving the value would override it
                mat.node_tree.links.remove(link)
            socket.default_value = (*value, 1) if key == "baseColor" else value
        if "alpha" in values and values["alpha"] >= 1 and hasattr(mat, "surface_render_method"):
            mat.surface_render_method = "DITHERED"


def decimate(rules):
    """Thin out needlessly dense parts (some artists model each fret with 30k vertices):
    [{"re": name pattern, "ratio": 0.04, "minVerts": 1000}]."""
    import re
    graph = bpy.context.evaluated_depsgraph_get()
    for rule in rules:
        rx = re.compile(rule["re"])
        dense = [o for o in meshes() if rx.search(o.name) and len(o.data.vertices) >= rule.get("minVerts", 1000)]
        before = sum(len(o.data.vertices) for o in dense)
        for obj in dense:
            mod = obj.modifiers.new("decimate", "DECIMATE")
            mod.ratio = rule["ratio"]
        graph.update()
        for obj in dense:
            mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(graph))
            obj.modifiers.clear()
            obj.data = mesh
        print(f"decimated {len(dense)} parts: {before} -> {sum(len(o.data.vertices) for o in dense)} vertices", flush=True)


def box_mean(a, r):
    """Mean over a (2r+1)^2 window, edges clamped (cumulative sums: fast on whole textures)."""
    p = np.pad(a, ((r + 1, r), (r + 1, r)) + ((0, 0),) * (a.ndim - 2), mode="edge")
    c = p.cumsum(0).cumsum(1)
    k = 2 * r + 1
    return (c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]) / (k * k)


def retouch(entries, folder):
    """Retouch a material's base colour image. "rects": remove ink baked into it (autographs, scribbles):
    inside each [x0, x1, y0, y1] (0...1 from the top left) pixels much darker than their surroundings are
    rebuilt by interpolating along the wood grain ("along": "y" when the grain runs down the image).
    "multiply": [r, g, b] tints the whole image (a flat orange varnish toward amber brown)."""
    for entry in entries:
        mat = bpy.data.materials[entry["material"]]
        bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        img = next(link.from_node.image for link in bsdf.inputs["Base Color"].links if link.from_node.type == "TEX_IMAGE")
        w, h = img.size
        flat = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(flat)
        px = flat.reshape(h, w, 4)[::-1].copy()  # Blender stores rows bottom up
        if entry.get("multiply"):
            px[..., :3] *= np.array(entry["multiply"], dtype=np.float32)
        r = max(3, int(round(w / 1024 * 10)))
        for rect in entry.get("rects", []):
            x0, x1, y0, y1 = int(rect[0] * w), int(rect[1] * w), int(rect[2] * h), int(rect[3] * h)
            cx0, cx1, cy0, cy1 = max(0, x0 - 2 * r), min(w, x1 + 2 * r), max(0, y0 - 2 * r), min(h, y1 + 2 * r)
            crop = px[cy0:cy1, cx0:cx1]
            lum = crop[..., :3] @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
            ink = np.zeros(lum.shape, bool)
            ink[y0 - cy0:y1 - cy0, x0 - cx0:x1 - cx0] = True
            ink &= lum < entry.get("darker", 0.7) * box_mean(lum, r)
            ink = box_mean(ink.astype(np.float32), max(1, r // 4)) > 0  # catch anti-aliased edges
            grain = crop if entry.get("along", "y") == "y" else crop.transpose(1, 0, 2)
            mask = ink if entry.get("along", "y") == "y" else ink.T
            for c in np.flatnonzero(mask.any(0)):
                idx = np.flatnonzero(mask[:, c])
                for run in np.split(idx, np.flatnonzero(np.diff(idx) > 1) + 1):
                    lo, hi = run[0] - 1, run[-1] + 1
                    if lo >= 0 and hi < grain.shape[0]:
                        t = ((run - lo) / (hi - lo))[:, None]
                        grain[run, c] = grain[lo, c] * (1 - t) + grain[hi, c] * t
            print(f"retouched {int(ink.sum())} ink px in {img.name}", flush=True)
        img.pixels.foreach_set(px[::-1].ravel())
        folder.mkdir(parents=True, exist_ok=True)  # save it, so the USD export copies the cleaned texture
        img.filepath_raw = str((folder / f"{Path(img.name).stem}_clean.png").resolve())
        img.file_format = "PNG"
        img.save()


def persp_camera(scene, target, height, azimuth, elevation, lens, fill=1.08, focus=None, fstop=None):
    data = bpy.data.cameras.new("cam")
    data.lens = lens
    data.sensor_fit = "VERTICAL"
    data.sensor_height = 24.0
    cam = bpy.data.objects.new("cam", data)
    scene.collection.objects.link(cam)
    fov = 2 * math.atan(12.0 / lens)
    dist = (height * fill / 2) / math.tan(fov / 2)
    az, el = math.radians(azimuth), math.radians(elevation)
    d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
    cam.location = Vector(target) + d * dist
    look = (Vector(target) - cam.location).normalized()
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    data.clip_end = dist * 10
    if focus is not None:
        data.dof.use_dof = True
        data.dof.focus_distance = (Vector(focus) - cam.location).length
        data.dof.aperture_fstop = fstop or 4.0
    scene.camera = cam
    return cam


HDRI = Path("build/hdri/studio.hdr")


def studio(scene, lo, hi):
    """Photographic studio: a real HDRI for reflections plus warm key and cool rim softboxes."""
    world = bpy.data.worlds.new("Stage")
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    background = nodes["Background"]
    if HDRI.exists():
        env = nodes.new("ShaderNodeTexEnvironment")
        env.image = bpy.data.images.load(str(HDRI.resolve()))
        mapping, coords = nodes.new("ShaderNodeMapping"), nodes.new("ShaderNodeTexCoord")
        mapping.inputs["Rotation"].default_value = (0, 0, math.radians(200))
        links.new(coords.outputs["Generated"], mapping.inputs["Vector"])
        links.new(mapping.outputs["Vector"], env.inputs["Vector"])
        links.new(env.outputs["Color"], background.inputs["Color"])
        background.inputs["Strength"].default_value = 0.55
    else:
        background.inputs["Color"].default_value = (0.02, 0.02, 0.022, 1)
    scene.world = world
    center = Vector((lo + hi) / 2)
    k = float(np.linalg.norm(hi - lo))
    for name, offset, size, energy, color in (
        ("Key", (-0.9, -1.1, 0.9), 1.0, 70, (1.0, 0.88, 0.76)),
        ("Rim", (1.0, 0.9, 0.6), 0.8, 110, (0.74, 0.85, 1.0)),
        ("Kicker", (-1.0, 0.8, 0.3), 0.5, 60, (1.0, 0.8, 0.6)),
        ("Top", (0.0, -0.3, 1.4), 0.6, 22, (1.0, 0.93, 0.84)),
    ):
        light = bpy.data.lights.new(name, "AREA")
        light.shape = "RECTANGLE"
        light.size, light.size_y = size * k, size * k * 0.6
        light.energy, light.color = energy * k * k, color
        obj = bpy.data.objects.new(name, light)
        scene.collection.objects.link(obj)
        obj.location = center + Vector(offset) * k
        obj.rotation_euler = (center - obj.location).to_track_quat("-Z", "Y").to_euler()


def render(scene, path, res, samples, transparent=True, aspect=1.0):
    scene.render.resolution_x, scene.render.resolution_y = int(res * aspect), res
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.film_transparent = transparent
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def head_region(pts, fraction=0.3):
    lo, hi = pts.min(0), pts.max(0)
    top = hi[2] - (hi[2] - lo[2]) * fraction
    region = pts[pts[:, 2] > top]
    rlo, rhi = region.min(0), region.max(0)
    return (rlo + rhi) / 2, float(max(rhi[0] - rlo[0], rhi[2] - rlo[2])) * 1.1


def calibrate(scene, out, model, lo, hi, pts):
    """Front ortho views (whole and head) with the mapping a grid overlay needs."""
    calib = {}
    whole_center = (lo + hi) / 2
    whole_scale = float(max(hi[0] - lo[0], hi[2] - lo[2])) * 1.06
    ortho_camera(scene, whole_center, whole_scale)
    render(scene, out / f"{model}_calib_whole.png", 1200, 16, transparent=False)
    calib["whole"] = {"center": whole_center.round(5).tolist(), "scale": whole_scale, "res": 1200}
    hc, hs = head_region(pts)
    ortho_camera(scene, hc, hs)
    render(scene, out / f"{model}_calib_head.png", 1200, 16, transparent=False)
    calib["head"] = {"center": hc.round(5).tolist(), "scale": hs, "res": 1200}
    # Identification: every object in the head view a flat colour, listed with its name.
    import colorsys
    members = []
    half = hs / 2
    for k, obj in enumerate(sorted((o for o in meshes() if not o.hide_render), key=lambda o: o.name)):
        c = verts(obj).mean(0)
        if abs(c[0] - hc[0]) < half and abs(c[2] - hc[2]) < half:
            rgb = colorsys.hsv_to_rgb((len(members) * 0.61803398875) % 1, 0.9 if len(members) % 2 else 0.6, 1.0 if len(members) % 3 else 0.75)
            obj.color = (*rgb, 1)
            members.append({"name": obj.name, "color": [round(x, 3) for x in rgb], "vertices": len(obj.data.vertices),
                            "center": c.round(4).tolist()})
    calib["headObjects"] = members
    mat = bpy.data.materials.new("ids")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    info, emit, outn = nodes.new("ShaderNodeObjectInfo"), nodes.new("ShaderNodeEmission"), nodes.new("ShaderNodeOutputMaterial")
    links.new(info.outputs["Color"], emit.inputs["Color"])
    links.new(emit.outputs["Emission"], outn.inputs["Surface"])
    layer = scene.view_layers[0]
    layer.material_override = mat
    look = scene.view_settings.view_transform
    scene.view_settings.view_transform = "Standard"
    render(scene, out / f"{model}_calib_ids.png", 1200, 1, transparent=False)
    scene.view_settings.view_transform = look
    layer.material_override = None
    (out / f"{model}.calib.json").write_text(json.dumps(calib, indent=1))


def dump_textures(out, model, wanted):
    """Small copies of the named materials' images, to judge decals and baked-in marks."""
    for mat in bpy.data.materials:
        if mat.users == 0 or not mat.use_nodes or (wanted is not True and mat.name not in wanted):
            continue
        for node in mat.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image and node.image.size[0]:
                img = node.image.copy()
                w, h = img.size
                k = min(1.0, 1024 / max(w, h))
                img.scale(max(1, int(w * k)), max(1, int(h * k)))
                img.filepath_raw = str(out / f"{model}_tex_{node.image.name.rsplit('.', 1)[0]}.png")
                img.file_format = "PNG"
                img.save()


def dump_parts(out, model, per_object=160):
    """Every visible part in the normalised frame, for rigging by hand: <model>.parts.npz holds names,
    vertex counts, bounds and a vertex sample per part; <model>.materials.json the materials' textures."""
    rng = np.random.default_rng(0)
    names, counts, mats, samples, owner = [], [], [], [], []
    for k, obj in enumerate(sorted((o for o in meshes() if not o.hide_render), key=lambda o: o.name)):
        v = verts(obj, limit=200000)
        names.append(obj.name)
        counts.append(len(obj.data.vertices))
        mats.append("|".join(s.material.name for s in obj.material_slots if s.material))
        pick = v if len(v) <= per_object else v[rng.choice(len(v), per_object, replace=False)]
        lo, hi = v.min(0), v.max(0)
        samples.append(np.concatenate([pick, [lo, hi]]))
        owner.append(np.full(len(pick) + 2, k))
    np.savez_compressed(out / f"{model}.parts.npz", names=np.array(names), counts=np.array(counts), materials=np.array(mats),
                        points=np.concatenate(samples).astype(np.float32), owner=np.concatenate(owner).astype(np.int32))
    info = {}
    for mat in bpy.data.materials:
        if not mat.use_nodes or mat.users == 0:
            continue
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        info[mat.name] = {
            "images": sorted({n.image.name for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image}),
            "baseColor": [round(x, 3) for x in bsdf.inputs["Base Color"].default_value] if bsdf else None,
            "metallic": round(bsdf.inputs["Metallic"].default_value, 3) if bsdf else None,
            "roughness": round(bsdf.inputs["Roughness"].default_value, 3) if bsdf else None,
            "alpha": round(bsdf.inputs["Alpha"].default_value, 3) if bsdf else None,
            "blend": getattr(mat, "surface_render_method", ""),
        }
    (out / f"{model}.materials.json").write_text(json.dumps(info, indent=1))


def to_usd(v):
    return [round(float(v[0]), 5), round(float(v[2]), 5), round(float(-v[1]), 5)]


def string_material():
    mat = bpy.data.materials.new("timbre_string")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.86, 0.84, 0.8, 1)
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.28
    return mat


def cylinder_between(name, a, b, radius, material, parent):
    a, b = Vector(a), Vector(b)
    length = (b - a).length
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=radius, depth=length, location=(a + b) / 2)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    obj.data.materials.append(material)
    obj.parent = parent
    obj.matrix_parent_inverse = parent.matrix_world.inverted()
    return obj


STRING_KINDS = {  # plain and wound string finishes: (base colour, metallic, roughness)
    "steel": (((0.86, 0.84, 0.8), 1.0, 0.28), ((0.74, 0.73, 0.71), 1.0, 0.4)),
    "bronze": (((0.86, 0.84, 0.8), 1.0, 0.28), ((0.78, 0.6, 0.38), 1.0, 0.38)),
    "nylon": (((0.9, 0.88, 0.82), 0.0, 0.3), ((0.8, 0.8, 0.79), 1.0, 0.36)),
    "gut": (((0.83, 0.8, 0.74), 0.6, 0.35), ((0.74, 0.74, 0.74), 1.0, 0.38)),
}


def string_materials(kind):
    mats = []
    for label, (color, metallic, roughness) in zip(("plain", "wound"), STRING_KINDS[kind]):
        mat = bpy.data.materials.new(f"timbre_string_{label}")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*color, 1)
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        mats.append(mat)
    return mats


_SUMMARY = {}


def summary(obj):
    """Centroid and bounds of a part in world space (cached: parts only move once rigged)."""
    if obj.name not in _SUMMARY:
        v = verts(obj)
        _SUMMARY[obj.name] = (v.mean(0), v.min(0), v.max(0))
    return _SUMMARY[obj.name]


def select(spec):
    """Parts named by a list, or chosen by a filter in the normalised frame (metres, centroids):
    {"names": [...], "re": "regex", "box": [x0, x1, y0, y1, z0, z1] (null = open), "maxExtent": m, "exclude": [...]}."""
    import re
    if not spec:
        return []
    if isinstance(spec, str):
        spec = [spec]
    if isinstance(spec, list):
        missing = [n for n in spec if n not in bpy.data.objects]
        if missing:
            raise KeyError(f"no such objects: {missing}")
        return [bpy.data.objects[n] for n in spec]
    named = set(spec.get("names", []))
    rx = re.compile(spec["re"]) if spec.get("re") else None
    box, exclude, cap = spec.get("box"), set(spec.get("exclude", [])), spec.get("maxExtent")
    found = []
    for obj in meshes():
        if obj.hide_render or obj.name in exclude:
            continue
        if obj.name in named:
            found.append(obj)
            continue
        if not (rx or box) or (rx and not rx.search(obj.name)):
            continue
        c, olo, ohi = summary(obj)
        if box and not all((box[2 * k] is None or c[k] >= box[2 * k]) and (box[2 * k + 1] is None or c[k] <= box[2 * k + 1]) for k in range(3)):
            continue
        if cap and float((ohi - olo).max()) > cap:
            continue
        found.append(obj)
    return found


def level(spec, at="mean"):
    """A height: a number, or the mean / top / bottom z of the selected parts."""
    if isinstance(spec, (int, float)):
        return float(spec)
    z = np.concatenate([verts(o) for o in select(spec)])[:, 2]
    return float({"mean": z.mean(), "top": z.max(), "bottom": z.min()}[at])


def along(objs, z_a, z_b, z):
    """The point at height z on the straight line through the string's centres at heights z_a and z_b."""
    pa, pb = (np.concatenate([crossing(o, h) for o in objs]).mean(0) for h in (z_a, z_b))
    return pa + (pb - pa) * (z - pa[2]) / (pb[2] - pa[2])


def speaking_ends(objs, gap=0.003):
    """Low-poly strings only have vertices where they bend: the longest straight run between two
    rings of vertices is the speaking length. Returns (nut, saddle)."""
    v = np.concatenate([verts(o, limit=200000) for o in objs])
    v = v[np.argsort(v[:, 2])]
    rings = [g.mean(0) for g in np.split(v, np.where(np.diff(v[:, 2]) > gap)[0] + 1)]
    k = max(range(len(rings) - 1), key=lambda i: np.linalg.norm(rings[i + 1] - rings[i]))
    return rings[k + 1], rings[k]


def string_end(objs, top=True):
    """Where the original string ends: the centre of its last few millimetres (post or tailpiece)."""
    v = np.concatenate([verts(o, limit=200000) for o in objs])
    edge = v[:, 2].max() if top else v[:, 2].min()
    return v[np.abs(v[:, 2] - edge) < 0.002].mean(0)


def anchor_point(spec, radius):
    """A point given as [x, y, z], or the centre of some parts ({"parts": [...], "front": true} puts it on
    their front face, where a string winding onto them touches)."""
    if isinstance(spec, list) and len(spec) == 3 and all(isinstance(v, (int, float)) for v in spec):
        return np.array(spec, dtype=float)
    parts = spec["parts"] if isinstance(spec, dict) else spec
    v = np.concatenate([verts(o) for o in select(parts)])
    point = v.mean(0)
    if isinstance(spec, dict) and spec.get("front"):
        point[1] = v[:, 1].min() - radius
    return point


def obstacle_tree(objs):
    """One BVH over the given parts in world space."""
    from mathutils.bvhtree import BVHTree
    points, polys = [], []
    for obj in objs:
        mw = obj.matrix_world
        base = len(points)
        points.extend(mw @ v.co for v in obj.data.vertices)
        polys.extend([base + i for i in p.vertices] for p in obj.data.polygons)
    return BVHTree.FromPolygons(points, polys) if polys else None


def route(a, b, radius, tree, depth=0):
    """Bends that keep the string a→b in front of the pegs it passes on its way to its own (a string to a
    peg near the scroll runs over the shafts of the pegs nearer the nut)."""
    if tree is None or depth > 3:
        return []
    d = Vector(b - a)
    hit = None
    for lift in (0.0, radius + 0.0005):  # the string's centre line and its back
        origin = Vector(a) + Vector((0, lift, 0))
        found = tree.ray_cast(origin, d.normalized(), d.length)
        if found[0] is not None and (hit is None or (found[0] - origin).length < (hit - Vector(a)).length):
            hit = found[0]
    if hit is None:
        return []
    t = (hit - Vector(a)).length / d.length
    p = a + (b - a) * t
    fronts = []
    for dz in np.linspace(-0.005, 0.005, 11):  # the obstacle's front face around the crossing
        found = tree.ray_cast(Vector((p[0], p[1] - 0.2, p[2] + dz)), Vector((0, 1, 0)), 0.4)
        if found[0] is not None:
            fronts.append(found[0].y)
    if not fronts:
        return []
    via = np.array([p[0], min(fronts) - radius - 0.001, p[2]])
    return route(a, via, radius, tree, depth + 1) + [via] + route(via, b, radius, tree, depth + 1)


def even_out(rows, key, layout):
    """Space the strings evenly across the nut or saddle (some artists' strings bunch up): courses evenly
    between the outer ones, the two strings of a paired course "pairGap" apart, outer string to outer
    string "span" (default: as modelled). Heights and depths stay as modelled."""
    courses = []
    for row in rows:
        if not courses or courses[-1][0] != row["item"]["anchor"]:
            courses.append((row["item"]["anchor"], []))
        courses[-1][1].append(row)
    xs = [r[key][0] for r in rows]
    gap = layout.get("pairGap", 0.0) if any(len(c[1]) > 1 for c in courses) else 0.0
    span = layout.get("span", max(xs) - min(xs))
    mid = (max(xs) + min(xs)) / 2
    first, last = mid - (span - gap) / 2, mid + (span - gap) / 2
    for k, (_, course) in enumerate(courses):
        c = first + (last - first) * k / max(1, len(courses) - 1)
        for j, row in enumerate(course):
            row[key] = row[key].copy()
            row[key][0] = c + (j - (len(course) - 1) / 2) * gap


def principal_axis(points, which=2):
    _, vecs = np.linalg.eigh(np.cov((points - points.mean(0)).T))
    return vecs[:, which] / np.linalg.norm(vecs[:, which])


def rig_model(scene, root, cfg, lo, hi, pts):
    """Strings listed one by one. Each item: anchor, "peg" (parts that turn with the key), optional "post"
    (parts on the post or roller), and either "string" (the original string parts: nut and saddle points are
    where they cross the "nutZ" / "saddleZ" levels) or explicit "nut"/"saddle" [x, z]. Peg axes default to the
    key's shaft as seen from its post (machine heads) or the peg's long axis (friction pegs), pointing outward;
    "tighten" defaults to +1 on the bass (-x) side and -1 on the treble side, the mirror image."""
    plain, wound = string_materials(cfg.get("stringKind", "steel"))
    nut_z = level(cfg["nutZ"], cfg.get("nutAt", "mean")) if cfg.get("nutZ") is not None else None
    saddle_z = level(cfg["saddleZ"], cfg.get("saddleAt", "mean")) if cfg.get("saddleZ") is not None else None
    originals = cfg.get("originalStrings", "keep")
    rows = []
    for item in cfg["strings"]:
        row = {"item": item, "objs": select(item.get("string"))}
        if row["objs"] and cfg.get("stringEnds") == "rings":
            row["nut"], row["saddle"] = speaking_ends(row["objs"])
        elif row["objs"]:
            span = nut_z - saddle_z
            a, b = nut_z - span * 0.01, saddle_z + span * 0.01
            row["nut"], row["saddle"] = along(row["objs"], a, b, nut_z), along(row["objs"], a, b, saddle_z)
        else:
            (nx, nz), (sx, sz) = item["nut"], item["saddle"]
            y = item.get("y")
            if y is None:  # strings sit just in front of the board: take the nearest geometry at the nut
                near = pts[(np.abs(pts[:, 0] - nx) < 0.004) & (np.abs(pts[:, 2] - nz) < 0.004)]
                y = float(near[:, 1].min()) - 0.002 if len(near) else float(lo[1]) * 0.5
            row["nut"], row["saddle"] = np.array([nx, y, nz]), np.array([sx, item.get("ySaddle", y), sz])
        # Lift a string that runs through its saddle or nut out to rest on top of it (toward the face).
        row["saddle"] = row["saddle"] - np.array([0, item.get("saddleLift", cfg.get("saddleLift", 0)), 0])
        row["nut"] = row["nut"] - np.array([0, item.get("nutLift", cfg.get("nutLift", 0)), 0])
        rows.append(row)
    for key in ("nut", "saddle"):
        if cfg.get(f"{key}Even") is not None:
            even_out(rows, key, cfg[f"{key}Even"])
    centre_x = float(np.mean([r["nut"][0] for r in rows]))
    anchors = [r["item"]["anchor"] for r in rows]
    for row in rows:
        row["pegs"] = select(row["item"]["peg"])
    strings = []
    for k, row in enumerate(rows):
        item = row["item"]
        anchor = item["anchor"]
        # A paired course uses its anchor twice: its strings become <anchor>a and <anchor>b.
        name = item.get("name", anchor + "ab"[anchors[:k].count(anchor)] if anchors.count(anchor) > 1 else anchor)
        peg_objs, post_objs = row["pegs"], select(item.get("post"))
        if not peg_objs:
            raise ValueError(f"{name}: no peg parts selected")
        center = np.concatenate([verts(o) for o in peg_objs]).mean(0)
        post_center = np.concatenate([verts(o) for o in post_objs]).mean(0) if post_objs else None
        post_axis = item.get("postAxis", "front")
        if post_axis == "front":
            post_axis = np.array([0.0, -1.0, 0.0])
        elif post_axis == "pca":
            post_axis = principal_axis(np.concatenate([verts(o) for o in post_objs]))
            if abs(post_axis[1]) > 0.5:  # a post standing out of the head: toward the face
                post_axis = post_axis * (-1 if post_axis[1] > 0 else 1)
            elif post_axis[0] * (row["nut"][0] - centre_x) < 0:  # a roller across the head: toward its string's side
                post_axis = -post_axis
        else:
            post_axis = np.array(post_axis, dtype=float) / np.linalg.norm(post_axis)
        mode = item.get("pegAxis", "post" if post_objs else "pca")
        if mode == "post":
            shaft = center - post_center
            axis = shaft - post_axis * (shaft @ post_axis)
        elif mode == "pca":
            axis = principal_axis(np.concatenate([verts(o) for o in peg_objs]))
        else:
            axis = np.array(mode, dtype=float)
        axis = axis / np.linalg.norm(axis)
        ref = post_center if post_center is not None else np.array([centre_x, center[1], center[2]])
        if axis @ (center - ref) < 0:  # outward: from the post, or from the centre line, toward the key
            axis = -axis
        if item.get("flipAxis"):
            axis = -axis
        peg = pivot(scene, f"peg_{name}", root, center, (1, 0, 0), axis)
        adopt(peg, peg_objs)
        if post_objs:
            post = pivot(scene, f"post_{name}", root, post_center, (0, 0, 1), post_axis)
            adopt(post, post_objs)
        else:  # friction peg: the peg is its own post
            post = bpy.data.objects.new(f"post_{name}", None)
            scene.collection.objects.link(post)
            post.parent = peg
        bpy.context.view_layer.update()
        nut, saddle = row["nut"], row["saddle"]
        radius = item.get("gauge", 0.0005) * 0.5 * 1.25
        mat = wound if item.get("wound") else plain
        cylinder_between(f"string_{name}", saddle, nut, radius, mat, root)
        for obj in select(item.get("hide")):  # leftovers of the original string (end caps, scan fragments)
            obj.hide_render = obj.hide_viewport = True
        if row["objs"] and originals == "cut":
            span = nut[2] - saddle[2]
            for obj in row["objs"]:
                cut_speaking_length(obj, saddle[2] + span * 0.004, nut[2] - span * 0.004)
        elif row["objs"] and originals == "hide":  # rebuild the rest of the string too, at its true gauge
            top, bottom = string_end(row["objs"], True), string_end(row["objs"], False)
            for obj in row["objs"]:
                obj.hide_render = obj.hide_viewport = True
            head = anchor_point(item["head"], radius) if item.get("head") else top
            tail = anchor_point(item["tail"], radius) if item.get("tail") else bottom
            tree = obstacle_tree([o for r in rows if r is not row for o in r["pegs"]]) if cfg.get("routeHeads") else None
            path = [nut] + route(nut, head, radius, tree) + [head]
            for j, (a, b) in enumerate(zip(path, path[1:])):
                cylinder_between(f"wrap_{name}" + (f"_{j}" if j else ""), a, b, radius, mat, root)
            cylinder_between(f"tail_{name}", tail, saddle, radius, mat, root)
        tighten = item.get("tighten", 1 if center[0] < centre_x else -1)
        strings.append({"anchor": anchor, "saddle": to_usd(saddle), "nut": to_usd(nut), "radius": round(radius, 6),
                        "wound": bool(item.get("wound")), "peg": f"peg_{name}", "post": f"post_{name}", "node": f"string_{name}",
                        "pegCenter": to_usd(center), "pegAxis": to_usd(axis), "tighten": tighten})
        print(f"rigged {name}: peg {len(peg_objs)} parts, post {len(post_objs)} parts, scale {np.linalg.norm(nut - saddle):.4f} m, "
              f"tighten {tighten}", flush=True)
    hc, hs = head_region(pts)
    rig = {"model": cfg["model"], "rig": cfg.get("rig", "MACHINE_HEAD"), "degPerCent": cfg.get("degPerCent", 1.4),
           "strings": strings, "headCenter": to_usd(hc), "bodyCenter": to_usd((lo + hi) / 2), "length": cfg["length"],
           "boundsMin": [min(a, b) for a, b in zip(to_usd(lo), to_usd(hi))], "boundsMax": [max(a, b) for a, b in zip(to_usd(lo), to_usd(hi))],
           "credit": cfg.get("credit")}
    return rig, hc, hs


def card_2d(scene, strings, res):
    """Where each string's saddle, nut and peg land on the hero render: [x, y] in 0...1 from the top left.
    A paired course gets its anchor keys (saddle and nut midway between its strings, peg of its first
    string) plus per-string keys under each string's own name."""
    from bpy_extras.object_utils import world_to_camera_view
    scene.render.resolution_x = scene.render.resolution_y = res
    bpy.context.view_layer.update()

    def project(usd):
        u, v, _ = world_to_camera_view(scene, scene.camera, Vector((usd[0], -usd[2], usd[1])))
        return [round(u, 4), round(1 - v, 4)]

    card, courses = {}, {}
    for s in strings:
        courses.setdefault(s["anchor"], []).append(s)
    for anchor, course in courses.items():
        card[f"{anchor}.saddle"] = project(np.mean([s["saddle"] for s in course], axis=0))
        card[f"{anchor}.nut"] = project(np.mean([s["nut"] for s in course], axis=0))
        card[f"{anchor}.peg"] = project(course[0]["pegCenter"])
        if len(course) > 1:
            for s in course:
                name = s["node"][len("string_"):]
                for key, field in (("saddle", "saddle"), ("nut", "nut"), ("peg", "pegCenter")):
                    card[f"{name}.{key}"] = project(s[field])
    return card


def export_usdz(root, path):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [root] + list(root.children_recursive):
        if not obj.hide_render:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    wanted = {
        "filepath": str(path), "selected_objects_only": True, "export_materials": True, "generate_preview_surface": True,
        "export_textures": True, "export_textures_mode": "NEW", "overwrite_textures": True, "export_uvmaps": True,
        "export_normals": True, "convert_orientation": True, "export_global_forward_selection": "NEGATIVE_Z",
        "export_global_up_selection": "Y", "export_animation": False, "export_lights": False, "export_cameras": False,
        "evaluation_mode": "RENDER", "root_prim_path": "/Instrument", "triangulate_meshes": True, "usdz_downscale_size": "2048",
    }
    available = set(bpy.ops.wm.usd_export.get_rna_type().properties.keys())
    bpy.ops.wm.usd_export(**{k: v for k, v in wanted.items() if k in available})


def convert(src: Path, cfg: dict, out: Path):
    scene = reset()
    _SUMMARY.clear()
    import_model(src / cfg["source"])
    if cfg.get("separate"):
        separate_loose()
    root, lo, hi = normalise(cfg)
    decimate(cfg.get("decimate", []))
    fix_materials(cfg.get("materials", {}))
    retouch(cfg.get("retouch", []), out.parent / "retouched" / cfg["model"])
    lacquer(cfg.get("coat", []))
    visible = [o for o in meshes() if not o.hide_render]
    pts = np.concatenate([verts(o) for o in visible])
    studio(scene, lo, hi)
    model = cfg["model"]
    dump_parts(out, model)
    if cfg.get("dumpTextures"):
        dump_textures(out, model, cfg["dumpTextures"])
    if cfg.get("dumpOnly"):
        print("dumped", model, flush=True)
        return
    calibrate(scene, out, model, lo, hi, pts)
    if cfg.get("auto"):
        rig, hc, hs = auto_rig(scene, root, cfg, lo, hi, pts)
    elif cfg.get("strings"):
        rig, hc, hs = rig_model(scene, root, cfg, lo, hi, pts)
    else:  # calibration only: grids plus studio renders to judge the model
        persp_camera(scene, (lo + hi) / 2, float(hi[2] - lo[2]), 24, 6, 85)
        render(scene, out / f"{model}_hero.png", 1200, 64)
        hc, hs = head_region(pts)
        persp_camera(scene, hc, hs, 18, 10, 100, fill=1.0, focus=hc, fstop=5.6)
        render(scene, out / f"{model}_head.png", 1200, 64)
        print("calibrated", model, "bounds", lo.round(3).tolist(), hi.round(3).tolist(), flush=True)
        return
    meta = src / cfg["source"] / "meta.json"
    if meta.exists():
        rig["credit"] = json.loads(meta.read_text())
    export_usdz(root, out / f"{model}.usdz")
    persp_camera(scene, (lo + hi) / 2, float(hi[2] - lo[2]), 24, 6, 85)
    rig["card2D"] = card_2d(scene, rig["strings"], 1400)
    (out / f"{model}.rig.json").write_text(json.dumps(rig, indent=1))
    render(scene, out / f"{model}_hero.png", 1400, 96)
    persp_camera(scene, hc, hs, 18, 10, 100, fill=1.0, focus=hc, fstop=5.6)
    render(scene, out / f"{model}_head.png", 1400, 96)
    print("converted", model, flush=True)


def main():
    src, rigs, out, only = args()
    out.mkdir(parents=True, exist_ok=True)
    for path in sorted(rigs.glob("*.json")):
        cfg = json.loads(path.read_text())
        if only and cfg["model"] not in only:
            continue
        try:
            convert(src, cfg, out)
        except Exception as exc:
            import traceback
            traceback.print_exc()
            print("FAILED", cfg["model"], exc, flush=True)


main()
