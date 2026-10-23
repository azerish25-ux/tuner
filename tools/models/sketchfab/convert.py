"""Turn an imported artist model into a Timbre stage asset: oriented, scaled, rigged, exported.

blender -b --factory-startup --python tools/models/sketchfab/convert.py -- build/import tools/models/sketchfab/rigs build/convert [model,model]

Each rigs/<model>.json names its download folder and how to read it:
  {"model": "violin", "source": "violin_museum", "length": 0.59, "headEnd": "A", "face": "front",
   "remove": [objects deleted (stands, cases)], "hide": [original strings, hidden],
   "rig": "FRICTION_PEG", "degPerCent": 1.2,
   "strings": [{"anchor": "s4", "peg": [object names], "axis": null | [x,y,z], "tighten": 1,
                "nut": [x, z], "saddle": [x, z], "gauge": 0.0008, "wound": true}]}
Coordinates in "nut"/"saddle" are metres in the normalised frame (head up +Z, face toward -Y,
centred on the model): read them off the calibration renders, which carry a centimetre grid.
Without "strings" the run only calibrates. Outputs per model: <model>.usdz, <model>.rig.json,
<model>_hero.png and <model>_head.png (transparent studio renders), calibration renders + json.
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


def wound_material():
    mat = bpy.data.materials.new("timbre_string_wound")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.78, 0.6, 0.38, 1)
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.38
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


def rig_model(scene, root, cfg, lo, hi, pts):
    plain, wound = string_material(), wound_material()
    strings = []
    front_y = {}  # strings sit just in front of the board: take the nearest geometry at each end
    for item in cfg["strings"]:
        anchor = item["anchor"]
        name = item.get("name", anchor)
        peg_objs = [bpy.data.objects[n] for n in item["peg"]]
        pv = np.concatenate([verts(o) for o in peg_objs])
        center = pv.mean(0)
        if item.get("axis"):
            axis = Vector(item["axis"]).normalized()
        else:
            _, vecs = np.linalg.eigh(np.cov((pv - center).T))
            axis = Vector(vecs[:, 2]).normalized()
        if item.get("flipAxis"):
            axis = -axis
        pivot = bpy.data.objects.new(f"peg_{name}", None)
        scene.collection.objects.link(pivot)
        pivot.parent = root
        pivot.matrix_parent_inverse = root.matrix_world.inverted()
        pivot.matrix_world = Matrix.Translation(Vector(center)) @ Vector((1, 0, 0)).rotation_difference(axis).to_matrix().to_4x4()
        bpy.context.view_layer.update()
        for obj in peg_objs:
            world = obj.matrix_world.copy()
            obj.parent = pivot
            obj.matrix_world = world
        post = bpy.data.objects.new(f"post_{name}", None)
        scene.collection.objects.link(post)
        post.parent = pivot
        bpy.context.view_layer.update()
        nx, nz = item["nut"]
        sx, sz = item["saddle"]
        y = item.get("y")
        if y is None:
            near = pts[(np.abs(pts[:, 0] - nx) < 0.004) & (np.abs(pts[:, 2] - nz) < 0.004)]
            y = float(near[:, 1].min()) - 0.002 if len(near) else float(lo[1]) * 0.5
        ys = item.get("ySaddle", y)
        radius = item.get("gauge", 0.0005) * 0.5 * 1.25
        nut, saddle = Vector((nx, y, nz)), Vector((sx, ys, sz))
        cylinder_between(f"string_{name}", saddle, nut, radius, wound if item.get("wound") else plain, root)
        strings.append({"anchor": anchor, "saddle": to_usd(saddle), "nut": to_usd(nut), "radius": round(radius, 6),
                        "wound": bool(item.get("wound")), "peg": f"peg_{name}", "post": f"post_{name}", "node": f"string_{name}",
                        "pegCenter": to_usd(center), "pegAxis": to_usd(axis), "tighten": item.get("tighten", 1)})
    hc, hs = head_region(pts)
    rig = {"model": cfg["model"], "rig": cfg.get("rig", "MACHINE_HEAD"), "degPerCent": cfg.get("degPerCent", 1.4),
           "strings": strings, "headCenter": to_usd(hc), "bodyCenter": to_usd((lo + hi) / 2), "length": cfg["length"],
           "boundsMin": [min(a, b) for a, b in zip(to_usd(lo), to_usd(hi))], "boundsMax": [max(a, b) for a, b in zip(to_usd(lo), to_usd(hi))],
           "credit": cfg.get("credit")}
    return rig, hc, hs


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
    import_model(src / cfg["source"])
    if cfg.get("separate"):
        separate_loose()
    root, lo, hi = normalise(cfg)
    lacquer(cfg.get("coat", []))
    visible = [o for o in meshes() if not o.hide_render]
    pts = np.concatenate([verts(o) for o in visible])
    studio(scene, lo, hi)
    model = cfg["model"]
    dump_parts(out, model)
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
    (out / f"{model}.rig.json").write_text(json.dumps(rig, indent=1))
    persp_camera(scene, (lo + hi) / 2, float(hi[2] - lo[2]), 24, 6, 85)
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
