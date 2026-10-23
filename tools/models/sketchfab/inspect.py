"""Inspect downloaded models so each can be rigged by hand: object inventory plus renders.

blender -b --factory-startup --python tools/models/sketchfab/inspect.py -- build/import build/inspect [id,id]
For every model: a textured 3/4 view, a textured front view, and for both ends of the
instrument's long axis a textured close-up and an "ids" close-up where each object is a flat
colour. inventory.json lists objects (name, vertices, bounds, materials), the principal axes,
and which objects (with their id colours) sit in each end region; legend.py draws the keys.
"""
import colorsys
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector


def args():
    argv = sys.argv[sys.argv.index("--") + 1:]
    return Path(argv[0]), Path(argv[1]), set(argv[2].split(",")) if len(argv) > 2 and argv[2] else set()


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    return scene


def import_model(folder: Path):
    source = next(iter(sorted(folder.glob("**/*.gltf"))), None) or next(iter(sorted(folder.glob("**/*.glb"))), None)
    if source is None:
        raise FileNotFoundError(f"no glTF in {folder}")
    bpy.ops.import_scene.gltf(filepath=str(source))
    bpy.context.view_layer.update()
    return source


def mesh_objects():
    return [o for o in bpy.context.scene.objects if o.type == "MESH" and o.visible_get()]


def world_vertices(obj, limit=40000):
    mesh = obj.data
    n = len(mesh.vertices)
    co = np.empty(n * 3, dtype=np.float64)
    mesh.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    if n > limit:
        co = co[:: max(1, n // limit)]
    m = np.array(obj.matrix_world)
    return co @ m[:3, :3].T + m[:3, 3]


def color_for(index: int):
    h = (index * 0.61803398875) % 1.0
    s = 0.85 if index % 2 == 0 else 0.6
    v = 1.0 if index % 3 != 2 else 0.7
    return colorsys.hsv_to_rgb(h, s, v)


def camera(scene, center, look_dir, up, scale=None, perspective_dist=None, lens=60):
    data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", data)
    scene.collection.objects.link(cam)
    z = -Vector(look_dir).normalized()           # camera looks along -Z
    y = (Vector(up) - z * Vector(up).dot(z)).normalized()
    x = y.cross(z)
    rot = Matrix((x, y, z)).transposed()
    if scale is not None:
        data.type = "ORTHO"
        data.ortho_scale = scale
        cam.location = Vector(center) + z * (scale * 4)
        data.clip_end = scale * 20
    else:
        data.lens = lens
        cam.location = Vector(center) + z * perspective_dist
        data.clip_end = perspective_dist * 10
    cam.matrix_world = Matrix.Translation(cam.location) @ rot.to_4x4()
    scene.camera = cam
    return cam


def lights(scene, center, size):
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.32, 0.32, 0.34, 1)
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(30))
    scene.collection.objects.link(sun)


def render(scene, path, res, samples, ids=False):
    scene.render.resolution_x = scene.render.resolution_y = res
    scene.cycles.samples = samples
    scene.cycles.use_denoising = not ids
    scene.render.filter_size = 0.01 if ids else 1.5
    layer = scene.view_layers[0]
    layer.material_override = id_material() if ids else None
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    layer.material_override = None


def id_material():
    mat = bpy.data.materials.get("ids") or bpy.data.materials.new("ids")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    info = nodes.new("ShaderNodeObjectInfo")
    emit = nodes.new("ShaderNodeEmission")
    out = nodes.new("ShaderNodeOutputMaterial")
    links.new(info.outputs["Color"], emit.inputs["Color"])
    links.new(emit.outputs["Emission"], out.inputs["Surface"])
    return mat


def inspect(folder: Path, out: Path, model_id: str):
    scene = reset()
    source = import_model(folder)
    objs = mesh_objects()
    inventory = {"id": model_id, "source": str(source.relative_to(folder)), "objects": []}
    pts_all = []
    for k, obj in enumerate(sorted(objs, key=lambda o: o.name)):
        pts = world_vertices(obj)
        pts_all.append(pts)
        obj.color = (*color_for(k), 1.0)
        lo, hi = pts.min(0), pts.max(0)
        inventory["objects"].append({
            "name": obj.name, "parent": obj.parent.name if obj.parent else None, "vertices": len(obj.data.vertices),
            "min": lo.round(4).tolist(), "max": hi.round(4).tolist(), "center": ((lo + hi) / 2).round(4).tolist(),
            "materials": [s.material.name for s in obj.material_slots if s.material], "color": [round(c, 3) for c in color_for(k)],
        })
    allp = np.concatenate(pts_all)
    mean = allp.mean(0)
    _, vecs = np.linalg.eigh(np.cov((allp - mean).T))
    long_axis, mid_axis, thin_axis = vecs[:, 2], vecs[:, 1], vecs[:, 0]
    proj = (allp - mean) @ np.stack([long_axis, mid_axis, thin_axis]).T
    lo, hi = proj.min(0), proj.max(0)
    inventory["axes"] = {"mean": mean.round(4).tolist(), "long": long_axis.round(4).tolist(), "mid": mid_axis.round(4).tolist(),
                         "thin": thin_axis.round(4).tolist(), "extent": (hi - lo).round(4).tolist()}
    size = float((hi - lo).max())
    lights(scene, Vector(mean), size)

    # Whole instrument: textured 3/4 and front.
    center = Vector(mean)
    camera(scene, center, -Vector(thin_axis) * 0.8 + Vector(mid_axis) * 0.35 - Vector(long_axis) * 0.2, Vector(long_axis),
           perspective_dist=size * 1.9, lens=50)
    render(scene, out / f"{model_id}_overview.png", 768, 16)
    camera(scene, center, -Vector(thin_axis), Vector(long_axis), scale=size * 1.08)
    render(scene, out / f"{model_id}_front.png", 768, 16)

    # Both ends of the long axis (one of them is the headstock / pegbox / tuning end).
    inventory["ends"] = {}
    for end, sign in (("A", 1), ("B", -1)):
        edge = hi[0] if sign > 0 else lo[0]
        span = (hi[0] - lo[0]) * 0.3
        inside = (proj[:, 0] - edge) * sign > -span
        region = proj[inside]
        rlo, rhi = region.min(0), region.max(0)
        rc = (rlo + rhi) / 2
        rcenter = mean + long_axis * rc[0] + mid_axis * rc[1] + thin_axis * rc[2]
        scale = float(max(rhi[0] - rlo[0], rhi[1] - rlo[1])) * 1.12
        members = []
        for item in inventory["objects"]:
            c = (np.array(item["center"]) - mean) @ np.stack([long_axis, mid_axis, thin_axis]).T
            if (c[0] - edge) * sign > -span:
                members.append({"name": item["name"], "color": item["color"], "vertices": item["vertices"]})
        inventory["ends"][end] = {"center": rcenter.round(4).tolist(), "scale": round(scale, 4), "objects": members}
        for side, direction in (("front", -1), ("back", 1)):
            camera(scene, Vector(rcenter), Vector(thin_axis) * direction, Vector(long_axis) * sign, scale=scale)
            render(scene, out / f"{model_id}_end{end}_{side}_ids.png", 900, 1, ids=True)
            if side == "front":
                render(scene, out / f"{model_id}_end{end}_{side}.png", 900, 16)
    (out / f"{model_id}.inventory.json").write_text(json.dumps(inventory, indent=1))
    print("inspected", model_id, len(objs), "objects", flush=True)


def main():
    src, out, only = args()
    out.mkdir(parents=True, exist_ok=True)
    for folder in sorted(p for p in src.iterdir() if p.is_dir()):
        if only and folder.name not in only:
            continue
        try:
            inspect(folder, out, folder.name)
        except Exception as exc:  # keep going: one broken archive should not hide the others
            print("FAILED", folder.name, exc, flush=True)


main()
