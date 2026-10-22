"""Build Timbre's 3D instruments headless.

blender -b --factory-startup --python tools/models/build_assets.py -- --out build/assets [--models a,b] [--samples 64] [--res 1024] [--no-render]

Outputs per model: <id>.usdz (app runtime), <id>.rig.json (animation anchors),
<id>_hero.png (studio render, transparent), <id>_head.png (headstock close-up).
"""
import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).parent))
import blendkit  # noqa: E402
from instruments import MODELS, PHOTO_MODELS, build  # noqa: E402


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="build/assets")
    parser.add_argument("--models", default="")
    parser.add_argument("--samples", type=int, default=64)
    parser.add_argument("--res", type=int, default=1024)
    parser.add_argument("--no-render", action="store_true")
    return parser.parse_args(argv)


def instrument_objects(root):
    return [root] + list(root.children_recursive)


def export_usdz(root, path):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in instrument_objects(root):
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    wanted = {
        "filepath": str(path), "selected_objects_only": True, "export_materials": True,
        "generate_preview_surface": True, "export_textures": True, "export_textures_mode": "NEW",
        "overwrite_textures": True, "export_uvmaps": True, "export_normals": True,
        "convert_orientation": True, "export_global_forward_selection": "NEGATIVE_Z",
        "export_global_up_selection": "Y", "export_animation": False, "export_lights": False,
        "export_cameras": False, "evaluation_mode": "RENDER", "root_prim_path": "/Instrument",
        "triangulate_meshes": True, "usdz_downscale_size": "2048",
    }
    available = set(bpy.ops.wm.usd_export.get_rna_type().properties.keys())
    kwargs = {k: v for k, v in wanted.items() if k in available}
    print("usd_export options:", sorted(kwargs))
    bpy.ops.wm.usd_export(**kwargs)


def bounds(root):
    bpy.context.view_layer.update()
    pts = []
    for obj in instrument_objects(root):
        if obj.type == "MESH":
            pts += [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def area_light(name, location, target, size, energy, color):
    data = bpy.data.lights.new(name, "AREA")
    data.shape = "RECTANGLE"
    data.size, data.size_y = size, size * 0.6
    data.energy, data.color = energy, color
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    blendkit.look_at(obj, target)
    return obj


def stage(scene, lo, hi):
    """Warm key, cool rim, faint fill: the 'Still Point' studio."""
    center = (lo + hi) / 2
    size = (hi - lo).length
    world = bpy.data.worlds.new("Stage")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.018, 0.016, 0.015, 1)
    bg.inputs["Strength"].default_value = 1.0
    scene.world = world
    k = size
    area_light("Key", center + Vector((-0.9 * k, -1.1 * k, 0.9 * k)), center, 1.1 * k, 110 * k * k, (1.0, 0.86, 0.72))
    area_light("Rim", center + Vector((1.0 * k, 0.9 * k, 0.6 * k)), center, 0.8 * k, 90 * k * k, (0.72, 0.84, 1.0))
    area_light("Fill", center + Vector((1.1 * k, -1.0 * k, -0.2 * k)), center, 1.4 * k, 16 * k * k, (1.0, 0.95, 0.9))
    area_light("Top", center + Vector((0.0, -0.3 * k, 1.4 * k)), center, 0.6 * k, 28 * k * k, (1.0, 0.92, 0.82))


def render(scene, path, target, height, res, samples, azimuth=24.0, elevation=6.0, lens=85.0, fill=1.1, aspect=1.0, points=None):
    cam_data = bpy.data.cameras.new("Camera")
    cam_data.lens = lens
    cam_data.sensor_fit = "VERTICAL"
    cam_data.sensor_height = 24.0
    cam = bpy.data.objects.new("Camera", cam_data)
    scene.collection.objects.link(cam)
    fov = 2 * math.atan(cam_data.sensor_height / 2 / lens)
    dist = (height * fill / 2) / math.tan(fov / 2)
    az, el = math.radians(azimuth), math.radians(elevation)
    direction = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
    cam.location = Vector(target) + direction * dist
    blendkit.look_at(cam, target)
    scene.camera = cam
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 6
    scene.render.film_transparent = True
    scene.render.resolution_x = int(res * aspect)
    scene.render.resolution_y = res
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    try:
        scene.view_settings.view_transform = "AgX"
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    projected = {}
    for name, point in (points or {}).items():
        co = world_to_camera_view(scene, cam, Vector(point))
        projected[name] = [round(co.x, 5), round(1 - co.y, 5)]
    bpy.data.objects.remove(cam)
    return projected


def main():
    args = parse()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    selected = [m for m in args.models.split(",") if m] or list(MODELS)
    manifest = {"models": {}, "photos": PHOTO_MODELS}
    for model_id in selected:
        spec = MODELS[model_id]
        scene = blendkit.reset_scene()
        root, rig = build(spec)
        export_usdz(root, out / f"{model_id}.usdz")
        lo, hi = bounds(root)
        a, b = blendkit.to_usd(lo), blendkit.to_usd(hi)
        rig["boundsMin"], rig["boundsMax"] = [min(x, y) for x, y in zip(a, b)], [max(x, y) for x, y in zip(a, b)]
        (out / f"{model_id}.rig.json").write_text(json.dumps(rig, indent=1))
        manifest["models"][model_id] = {"strings": [s["anchor"] for s in rig["strings"]], "length": rig["length"]}
        if not args.no_render:
            stage(scene, lo, hi)
            center = (lo + hi) / 2
            height = (hi - lo).z
            def blender_point(p):
                return (p[0], -p[2], p[1])
            points = {}
            for s in rig["strings"]:
                points[f"{s['anchor']}.saddle"] = blender_point(s["saddle"])
                points[f"{s['anchor']}.nut"] = blender_point(s["nut"])
                points[f"{s['anchor']}.peg"] = blender_point(s["pegCenter"])
            rig["hero2D"] = render(scene, out / f"{model_id}_hero.png", center, height, args.res, args.samples, points=points)
            (out / f"{model_id}.rig.json").write_text(json.dumps(rig, indent=1))
            head = Vector((rig["headCenter"][0], -rig["headCenter"][2], rig["headCenter"][1]))
            render(scene, out / f"{model_id}_head.png", head, 0.26 if spec.kind != "ukulele" else 0.17,
                   args.res // 2, args.samples, azimuth=18, elevation=10, lens=100, fill=1.0)
        print("built", model_id)
    (out / "manifest.json").write_text(json.dumps(manifest, indent=1))


main()
