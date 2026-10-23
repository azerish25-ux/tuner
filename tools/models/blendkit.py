"""Small geometry/material toolkit for Timbre's procedural instruments (Blender 4.x).

Coordinates: Blender Z-up. Instruments stand along +Z, their playing face looks
toward -Y (Blender front view), +X is the viewer's right. Units are metres.
"""
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

TEXTURES = Path(__file__).parent / "textures"
_materials: dict = {}


# ---------------------------------------------------------------- scene

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _materials.clear()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    return scene


def link(obj, parent=None):
    bpy.context.scene.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
    return obj


def empty(name, location=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    obj.location = location
    return link(obj, parent)


# ---------------------------------------------------------------- curves

def catmull_rom(points, samples=12, closed=False):
    """Smooth polyline through 2D points."""
    pts = [Vector((p[0], p[1])) for p in points]
    if closed:
        ext = [pts[-1]] + pts + [pts[0], pts[1]]
    else:
        ext = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    out = []
    count = len(pts) if closed else len(pts) - 1
    for i in range(count):
        p0, p1, p2, p3 = ext[i], ext[i + 1], ext[i + 2], ext[i + 3]
        for s in range(samples):
            t = s / samples
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    if not closed:
        out.append(pts[-1])
    return [(v.x, v.y) for v in out]


def mirrored_outline(half, samples=14):
    """half: [(x>=0, z)] from bottom centre (x=0) up to top centre (x=0).
    Returns a closed counter-clockwise outline [(x, z)]."""
    right = catmull_rom(half, samples)
    left = [(-x, z) for x, z in reversed(right[1:-1])]
    outline = right + left
    # Remove duplicate consecutive points.
    clean = [outline[0]]
    for p in outline[1:]:
        if (Vector(p) - Vector(clean[-1])).length > 1e-5:
            clean.append(p)
    return clean


def offset_outline(points, distance):
    """Offset a closed CCW outline outward by distance (negative = inward)."""
    n = len(points)
    out = []
    for i in range(n):
        p_prev, p, p_next = Vector(points[i - 1]), Vector(points[i]), Vector(points[(i + 1) % n])
        tangent = (p_next - p_prev).normalized()
        normal = Vector((tangent.y, -tangent.x))  # outward for CCW
        out.append(tuple(p + normal * distance))
    return out


def polygon_area(points):
    return 0.5 * sum(points[i][0] * points[(i + 1) % len(points)][1] - points[(i + 1) % len(points)][0] * points[i][1] for i in range(len(points)))


# ---------------------------------------------------------------- meshes

def _finish(bm, name, material, parent=None, smooth=True, sharp_angle=35.0, uv=None):
    mesh = bpy.data.meshes.new(name)
    if uv is not None:
        layer = bm.loops.layers.uv.verify()
        for face in bm.faces:
            for loop in face.loops:
                loop[layer].uv = uv(loop.vert.co, face.normal)
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    link(obj, parent)
    if material is not None:
        mesh.materials.append(material)
    if smooth:
        mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
        if hasattr(mesh, "set_sharpness_by_angle"):
            mesh.set_sharpness_by_angle(angle=math.radians(sharp_angle))
    return obj


def box_uv(scale=1.0, offset=(0.0, 0.0)):
    """Box projection: grain runs along Z on front/back faces."""
    def uv(co, normal):
        ax, ay, az = abs(normal.x), abs(normal.y), abs(normal.z)
        if ay >= ax and ay >= az:
            u, v = co.x, co.z
        elif ax >= az:
            u, v = co.y, co.z
        else:
            u, v = co.x, co.y
        return ((u + offset[0]) * scale, (v + offset[1]) * scale)
    return uv


def fit_uv(bounds):
    """Map the XZ bounding box of a face plate to 0..1 (for sunbursts and decals)."""
    (x0, z0), (x1, z1) = bounds
    def uv(co, normal):
        return ((co.x - x0) / (x1 - x0), (co.z - z0) / (z1 - z0))
    return uv


def prism(name, outline, y_front, y_back, material, parent=None, bevel=0.0, segments=3, uv=None, holes=()):
    """Extrude a closed XZ outline between two Y planes (front = smaller y)."""
    bm = bmesh.new()
    front = [bm.verts.new((x, y_front, z)) for x, z in outline]
    back = [bm.verts.new((x, y_back, z)) for x, z in outline]
    n = len(outline)
    ccw = polygon_area(outline) > 0
    # Front face looks toward -Y: vertex order must be clockwise when seen from -Y.
    f = bm.faces.new(front if ccw else list(reversed(front)))
    b = bm.faces.new(list(reversed(back)) if ccw else back)
    for i in range(n):
        j = (i + 1) % n
        quad = [front[i], front[j], back[j], back[i]] if ccw else [front[j], front[i], back[i], back[j]]
        bm.faces.new(quad)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=[f, b], quad_method="BEAUTY", ngon_method="BEAUTY")
    obj = _finish(bm, name, material, parent, uv=uv or box_uv())
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(40)
        mod.harden_normals = False
    return obj


def ring(name, outer, inner, y_front, y_back, material, parent=None, uv=None):
    """Band between two closed outlines with equal vertex counts (binding, purfling)."""
    assert len(outer) == len(inner)
    bm = bmesh.new()
    loops = {}
    for key, pts, y in (("of", outer, y_front), ("ob", outer, y_back), ("if", inner, y_front), ("ib", inner, y_back)):
        loops[key] = [bm.verts.new((x, y, z)) for x, z in pts]
    n = len(outer)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([loops["of"][i], loops["if"][i], loops["if"][j], loops["of"][j]])
        bm.faces.new([loops["ob"][i], loops["ob"][j], loops["ib"][j], loops["ib"][i]])
        bm.faces.new([loops["of"][i], loops["of"][j], loops["ob"][j], loops["ob"][i]])
        bm.faces.new([loops["if"][i], loops["ib"][i], loops["ib"][j], loops["if"][j]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish(bm, name, material, parent, uv=uv or box_uv(), sharp_angle=50)


def loft(name, stations, material, parent=None, closed=True, uv=None, sharp_angle=50.0):
    """stations: list of rings (lists of 3D points, equal counts) along a path."""
    bm = bmesh.new()
    rings = [[bm.verts.new(p) for p in ring_pts] for ring_pts in stations]
    m = len(rings[0])
    for a, b in zip(rings, rings[1:]):
        for i in range(m if closed else m - 1):
            j = (i + 1) % m
            bm.faces.new([a[i], a[j], b[j], b[i]])
    if closed:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish(bm, name, material, parent, uv=uv or box_uv(), sharp_angle=sharp_angle)


def cylinder(name, radius, depth, material, parent=None, location=(0, 0, 0), rotation=(0, 0, 0), vertices=24, radius_top=None, smooth=True):
    """Cylinder along local Z, centred on its origin."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=vertices, radius1=radius,
                          radius2=radius if radius_top is None else radius_top, depth=depth)
    obj = _finish(bm, name, material, parent, smooth=smooth, sharp_angle=40, uv=box_uv(20))
    obj.location = location
    obj.rotation_euler = rotation
    return obj


def segment(name, start, end, radius, material, parent=None, vertices=10):
    """Cylinder between two world points (strings, rods)."""
    start, end = Vector(start), Vector(end)
    axis = end - start
    obj = cylinder(name, radius, axis.length, material, parent, vertices=vertices)
    obj.location = (start + end) / 2
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(axis.normalized())
    return obj


def ellipsoid(name, radii, material, parent=None, location=(0, 0, 0), segments=24, rings=12):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2]))
    obj = _finish(bm, name, material, parent, uv=box_uv(30))
    obj.location = location
    return obj


def cube(name, size, material, parent=None, location=(0, 0, 0), bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    obj = _finish(bm, name, material, parent, uv=box_uv(10), sharp_angle=30)
    obj.location = location
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    return obj


def disc(name, radius, y, center, material, parent=None, segments=64, uv_fit=True):
    """Flat disc facing -Y (decals: soundhole, rosette, inlays)."""
    bm = bmesh.new()
    verts = [bm.verts.new((center[0] + radius * math.cos(a), y, center[1] + radius * math.sin(a)))
             for a in [2 * math.pi * i / segments for i in range(segments)]]
    bm.faces.new(list(reversed(verts)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    def uv(co, normal):
        return ((co.x - center[0]) / (2 * radius) + 0.5, (co.z - center[1]) / (2 * radius) + 0.5)
    obj = _finish(bm, name, material, parent, smooth=False, uv=uv if uv_fit else None)
    return obj


# ---------------------------------------------------------------- materials

def _image(name, non_color=False):
    path = TEXTURES / name
    image = bpy.data.images.load(str(path), check_existing=True)
    if non_color:
        image.colorspace_settings.name = "Non-Color"
    return image


def material(name, color=(0.8, 0.8, 0.8), metallic=0.0, roughness=0.5, texture=None, rough_texture=None,
             coat=0.0, alpha_texture=False, emission=None):
    if name in _materials:
        return _materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if "Coat Weight" in bsdf.inputs and coat > 0:
        bsdf.inputs["Coat Weight"].default_value = coat
        bsdf.inputs["Coat Roughness"].default_value = 0.05
    if texture:
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = _image(texture)
        links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        if alpha_texture:
            links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
            if hasattr(mat, "blend_method"):
                mat.blend_method = "BLEND"
    if rough_texture:
        rtex = nodes.new("ShaderNodeTexImage")
        rtex.image = _image(rough_texture, non_color=True)
        links.new(rtex.outputs["Color"], bsdf.inputs["Roughness"])
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.0
    _materials[name] = mat
    return mat


def palette():
    """Shared material library so every instrument looks like one family."""
    return {
        "spruce": material("Spruce", texture="spruce_color.jpg", rough_texture="spruce_rough.png", coat=1.0),
        "mahogany": material("Mahogany", texture="mahogany_color.jpg", roughness=0.35, coat=1.0),
        "rosewood": material("Rosewood", texture="rosewood_color.jpg", rough_texture="rosewood_rough.png"),
        "ebony": material("Ebony", texture="ebony_color.jpg", roughness=0.3),
        "maple": material("Maple", texture="maple_color.jpg", roughness=0.25, coat=1.0),
        "sunburst": material("Sunburst", texture="sunburst_3tone_color.jpg", roughness=0.15, coat=1.0),
        "cherry": material("CherryBurst", texture="sunburst_cherry_color.jpg", roughness=0.15, coat=1.0),
        "tortoise": material("Tortoise", texture="tortoise_color.jpg", roughness=0.2),
        "pearl": material("Pearl", texture="pearl_color.jpg", roughness=0.15),
        "rosette": material("Rosette", texture="rosette.png", roughness=0.3),
        "bone": material("Bone", color=(0.88, 0.84, 0.74), roughness=0.45),
        "cream": material("Binding", color=(0.9, 0.85, 0.72), roughness=0.3),
        "black": material("Gloss Black", color=(0.012, 0.012, 0.014), roughness=0.12, coat=1.0),
        "hole": material("Soundhole", color=(0.004, 0.003, 0.002), roughness=0.9),
        "white_guard": material("White Guard", color=(0.86, 0.85, 0.8), roughness=0.25),
        "nickel": material("Nickel", color=(0.8, 0.79, 0.76), metallic=1.0, roughness=0.18),
        "chrome": material("Chrome", color=(0.9, 0.9, 0.92), metallic=1.0, roughness=0.08),
        "gold": material("Gold", color=(0.86, 0.68, 0.36), metallic=1.0, roughness=0.2),
        "steel": material("String Steel", color=(0.82, 0.82, 0.84), metallic=1.0, roughness=0.25),
        "bronze": material("String Bronze", color=(0.78, 0.56, 0.34), metallic=1.0, roughness=0.32),
        "nickel_wound": material("String Nickel", color=(0.7, 0.7, 0.7), metallic=1.0, roughness=0.38),
        "nylon": material("Nylon", color=(0.93, 0.92, 0.86), roughness=0.35),
        "nylon_wound": material("Nylon Wound", color=(0.82, 0.8, 0.76), metallic=1.0, roughness=0.35),
        "button_pearl": material("Button Pearloid", texture="pearl_color.jpg", roughness=0.2),
        "pickup_black": material("Pickup", color=(0.02, 0.02, 0.022), roughness=0.4),
        "satin_black": material("Satin Black", color=(0.03, 0.03, 0.032), roughness=0.55),
        "fret": material("Fret Wire", color=(0.86, 0.84, 0.8), metallic=1.0, roughness=0.15),
        "varnish_top": material("Varnished Spruce", texture="varnish_spruce_color.jpg", roughness=0.3, coat=1.0),
        "varnish_maple": material("Varnished Maple", texture="varnish_maple_color.jpg", roughness=0.28, coat=1.0),
        "bridge_maple": material("Bridge Maple", texture="maple_color.jpg", roughness=0.55),
        "gut": material("Synthetic Gut", color=(0.62, 0.5, 0.34), metallic=0.6, roughness=0.4),
        "silver": material("Silver Winding", color=(0.86, 0.86, 0.88), metallic=1.0, roughness=0.22),
    }


# ---------------------------------------------------------------- transforms

def to_usd(v):
    """Blender (Z-up, -Y front) to the exported USD frame (Y-up, +Z front)."""
    v = Vector(v)
    return [round(v.x, 6), round(v.z, 6), round(-v.y, 6)]


def world(obj, local=(0, 0, 0)):
    bpy.context.view_layer.update()
    return obj.matrix_world @ Vector(local)


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("-Z", "Y")
