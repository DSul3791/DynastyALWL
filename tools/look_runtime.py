#!/usr/bin/env python3
"""Run the building-piece looks of src/client/piece_look.gd in Python, for icons and for bounds checks without Godot (Kathleen, 10 Nov 2026).

The looks are short GDScript builders that stack boxes, cylinders, domes and rods on a Node3D (look_table.gd names the builder and its arguments).
This reads piece_look.gd and look_table.gd, turns each builder into Python line by line (typed vars, match blocks, int ranges, Vector3 and Color),
and runs it on a small stand-in for the Node3D tree: _box, _box_rot, _cyl, _dome, _torus_at, _rod and the log meshes are drawn here as faceted
faces with the same sizes, sides and transforms as the game's meshes (Godot's rotation order, YXZ). Materials become flat colours.

    from look_runtime import build, faces_of, bounds, triangles
    root = build("kiln")                  # the look's node tree
    faces = faces_of(root)                # [(points, (r, g, b)), ...] in the look's own space, for paint_structure_icons.render
    lo, hi = bounds(root); n = triangles(root)

    python3 tools/look_runtime.py kiln smoker      # prints each look's bounds and triangle count
"""
import math
import os
import re
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PIECE_LOOK = os.path.join(ROOT, "src", "client", "piece_look.gd")
LOOK_TABLE = os.path.join(ROOT, "src", "client", "look_table.gd")


# ---------------------------------------------------------------- Godot stand-ins
class Vector3:
    __slots__ = ("x", "y", "z")

    def __init__(self, x=0.0, y=0.0, z=0.0):
        self.x, self.y, self.z = float(x), float(y), float(z)

    def a(self):
        return np.array([self.x, self.y, self.z])

    @staticmethod
    def of(v):
        return Vector3(v[0], v[1], v[2])

    def _o(self, other):
        return other.a() if isinstance(other, Vector3) else other

    def __add__(self, o):
        return Vector3.of(self.a() + self._o(o))

    def __sub__(self, o):
        return Vector3.of(self.a() - self._o(o))

    def __mul__(self, o):
        return Vector3.of(self.a() * self._o(o))

    __rmul__ = __mul__

    def __truediv__(self, o):
        return Vector3.of(self.a() / self._o(o))

    def __neg__(self):
        return Vector3(-self.x, -self.y, -self.z)

    def __getitem__(self, i):
        return (self.x, self.y, self.z)[i]

    def length(self):
        return float(np.linalg.norm(self.a()))

    def normalized(self):
        n = self.length()
        return Vector3.of(self.a() / n) if n > 0 else Vector3()

    def distance_to(self, o):
        return float(np.linalg.norm(self.a() - o.a()))

    def lerp(self, o, t):
        return Vector3.of(self.a() + (o.a() - self.a()) * t)

    def cross(self, o):
        return Vector3.of(np.cross(self.a(), o.a()))

    def dot(self, o):
        return float(np.dot(self.a(), o.a()))

    def angle_to(self, o):
        return math.atan2(np.linalg.norm(np.cross(self.a(), o.a())), np.dot(self.a(), o.a()))

    def rotated(self, axis, angle):
        return Vector3.of(_axis_angle(axis.a(), angle) @ self.a())


Vector3.UP = Vector3(0, 1, 0)
Vector3.ZERO = Vector3()
Vector3.ONE = Vector3(1, 1, 1)
Vector3.RIGHT = Vector3(1, 0, 0)
Vector3.FORWARD = Vector3(0, 0, -1)
Vector3.BACK = Vector3(0, 0, 1)


class Vector2:
    def __init__(self, x=0.0, y=0.0):
        self.x, self.y = float(x), float(y)


class Color:
    def __init__(self, r=0.0, g=0.0, b=0.0, a=1.0):
        self.r, self.g, self.b, self.a = float(r), float(g), float(b), float(a)

    def lightened(self, k):
        return Color(self.r + (1 - self.r) * k, self.g + (1 - self.g) * k, self.b + (1 - self.b) * k, self.a)

    def darkened(self, k):
        return Color(self.r * (1 - k), self.g * (1 - k), self.b * (1 - k), self.a)

    def lerp(self, o, t):
        return Color(*(u + (v - u) * t for u, v in zip((self.r, self.g, self.b, self.a), (o.r, o.g, o.b, o.a))))

    def to_html(self, *_):
        return "%02x%02x%02x" % tuple(int(c * 255) for c in (self.r, self.g, self.b))


def _axis_angle(axis, angle):
    axis = axis / np.linalg.norm(axis)
    x, y, z = axis
    c, s, t = math.cos(angle), math.sin(angle), 1 - math.cos(angle)
    return np.array([[t * x * x + c, t * x * y - s * z, t * x * z + s * y], [t * x * y + s * z, t * y * y + c, t * y * z - s * x],
                     [t * x * z - s * y, t * y * z + s * x, t * z * z + c]])


def _euler_yxz(r):
    cx, sx, cy, sy, cz, sz = math.cos(r.x), math.sin(r.x), math.cos(r.y), math.sin(r.y), math.cos(r.z), math.sin(r.z)
    rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return ry @ rx @ rz


class Basis:
    def __init__(self, axis=None, angle=0.0):
        self.m = np.eye(3) if axis is None else _axis_angle(axis.a(), angle)


class Material:
    def __init__(self, colour, name=""):
        self.albedo_color = colour
        self.name = name

    def duplicate(self, *_):
        return Material(self.albedo_color, self.name)

    def __setattr__(self, key, value):   # transparency, metallic, emission and the rest: accepted, not drawn
        object.__setattr__(self, key, value)


class _AnyType(type):
    def __getattr__(cls, key):   # Mesh.PRIMITIVE_TRIANGLES and other class constants
        return 0


class Callable:
    """Godot's Callable: an empty one (Callable()) is not valid; one made from a Python function calls it."""

    def __init__(self, fn=None):
        self._fn = fn

    def is_valid(self):
        return self._fn is not None

    def call(self, *args):
        return self._fn(*args)


class Anything(metaclass=_AnyType):
    """Any other Godot object a builder makes (bodies, shapes, lights, timers): takes any attribute, any call, draws nothing."""

    def __init__(self, *args, **kwargs):
        object.__setattr__(self, "_attrs", {})

    @classmethod
    def new(cls, *args):
        return cls()

    def __getattr__(self, key):
        attrs = object.__getattribute__(self, "_attrs")
        return attrs[key] if key in attrs else (lambda *a, **k: Anything())

    def __setattr__(self, key, value):
        object.__getattribute__(self, "_attrs")[key] = value


class Node3D:
    def __init__(self):
        self.position = Vector3()
        self.rotation = Vector3()
        self.scale = Vector3(1, 1, 1)
        self._basis = None
        self.children = []
        self.visible = True
        self.name = ""

    @classmethod
    def new(cls):
        return cls()

    @property
    def basis(self):
        return self._basis

    @basis.setter
    def basis(self, b):
        self._basis = b

    @property
    def rotation_degrees(self):
        return self.rotation * (180.0 / math.pi)

    @rotation_degrees.setter
    def rotation_degrees(self, v):
        self.rotation = v * (math.pi / 180.0)

    def add_child(self, node, *_):
        self.children.append(node)

    def set_meta(self, *_):
        pass

    def get_children(self):
        return list(self.children)

    def local(self):
        turn = self._basis.m if self._basis is not None else _euler_yxz(self.rotation)
        return turn @ np.diag(self.scale.a()), self.position.a()


class MeshInstance3D(Node3D):
    def __init__(self):
        super().__init__()
        self.mesh = None
        self.material_override = None


class StandardMaterial3D(Material):
    def __init__(self):
        super().__init__(Color(1.0, 1.0, 1.0))

    @classmethod
    def new(cls):
        return cls()


class RandomNumberGenerator:
    """Godot's generator, seeded the same way; the numbers differ from Godot's, so a look's random tones and lengths differ a little."""

    def __init__(self):
        import random
        object.__setattr__(self, "_r", random.Random(0))

    def __setattr__(self, key, value):
        if key == "seed":
            self._r.seed(value)
        object.__setattr__(self, key, value)

    def randf(self):
        return self._r.random()

    def randf_range(self, a, b):
        return self._r.uniform(a, b)

    def randi_range(self, a, b):
        return self._r.randint(int(a), int(b))

    def randi(self):
        return self._r.getrandbits(32)


class TriMesh:
    def __init__(self, tris):
        self.tris = tris


class SurfaceTool:
    """Collects triangles as Godot's SurfaceTool does (clockwise from the front)."""

    def __init__(self):
        self.verts = []

    def add_vertex(self, v):
        self.verts.append(v.a())

    def commit(self, *_):
        return TriMesh([[self.verts[i], self.verts[i + 2], self.verts[i + 1]] for i in range(0, len(self.verts) - 2, 3)])   # counter-clockwise, as the faces here

    def __getattr__(self, key):
        return lambda *a, **k: None


class BoxMesh(Anything):
    pass


class CylinderMesh(Anything):
    pass


class SphereMesh(Anything):
    pass


class TorusMesh(Anything):
    pass


# ---------------------------------------------------------------- meshes as faces (in the mesh's own space)
def _box_faces(size):
    h = size.a() / 2.0
    c = {(sx, sy, sz): h * np.array([sx, sy, sz]) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)}
    quads = [[(1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)], [(-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)],
             [(-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)], [(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)],
             [(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)], [(-1, -1, -1), (-1, 1, -1), (1, 1, -1), (1, -1, -1)]]
    return [[c[k] for k in q] for q in quads], 12


def _cyl_faces(bottom, top, height, sides, rings=1):
    faces = []
    y0, y1 = -height / 2.0, height / 2.0
    ring = lambda r, y: [np.array([r * math.sin(2 * math.pi * i / sides), y, r * math.cos(2 * math.pi * i / sides)]) for i in range(sides)]
    lo, hi = ring(bottom, y0), ring(top, y1)

    for i in range(sides):
        j = (i + 1) % sides
        if bottom > 1e-6 or top > 1e-6:
            faces.append([lo[i], lo[j], hi[j], hi[i]] if bottom > 1e-6 and top > 1e-6 else ([lo[i], lo[j], hi[i]] if top <= 1e-6 else [lo[i], hi[j], hi[i]]))

    if top > 1e-6:
        faces.append(hi[::-1])
    if bottom > 1e-6:
        faces.append(lo)

    return faces, sides * (2 * (rings + 1)) + (sides if top > 1e-6 else 0) + (sides if bottom > 1e-6 else 0)


def _dome_faces(radius, height, segments, rings):
    faces = []
    rows = []

    for k in range(rings + 1):
        a = (math.pi / 2.0) * k / rings
        r, y = radius * math.cos(a), height * math.sin(a)
        rows.append([np.array([r * math.sin(2 * math.pi * i / segments), y, r * math.cos(2 * math.pi * i / segments)]) for i in range(segments)])

    for k in range(rings):
        for i in range(segments):
            j = (i + 1) % segments
            faces.append([rows[k][i], rows[k][j], rows[k + 1][j], rows[k + 1][i]] if k < rings - 1 else [rows[k][i], rows[k][j], rows[k + 1][i]])

    faces.append(rows[0])
    return faces, 2 * segments * (rings + 1)


def _torus_faces(inner, outer, rings, segments):
    faces = []
    ring_r, tube = (inner + outer) / 2.0, (outer - inner) / 2.0
    pts = [[np.array([(ring_r + tube * math.cos(2 * math.pi * j / segments)) * math.sin(2 * math.pi * i / rings), tube * math.sin(2 * math.pi * j / segments),
                      (ring_r + tube * math.cos(2 * math.pi * j / segments)) * math.cos(2 * math.pi * i / rings)]) for j in range(segments)] for i in range(rings)]

    for i in range(rings):
        for j in range(segments):
            i2, j2 = (i + 1) % rings, (j + 1) % segments
            faces.append([pts[i][j], pts[i2][j], pts[i2][j2], pts[i][j2]])

    return faces, 2 * rings * segments


def _orient(faces, ref):
    out = []

    for pts in faces:
        n = np.cross(pts[1] - pts[0], pts[2] - pts[0])
        r = ref(pts) if callable(ref) else ref
        out.append(pts if np.dot(n, np.mean(pts, axis=0) - r) >= 0.0 else pts[::-1])

    return out


def mesh_faces(mesh):
    """The faces (each wound to face out) and the triangle count of a stand-in mesh."""
    faces, count = _mesh_faces(mesh)

    if isinstance(mesh, TorusMesh):
        attrs = object.__getattribute__(mesh, "_attrs")
        ring_r = (attrs.get("inner_radius", 0.5) + attrs.get("outer_radius", 1.0)) / 2.0

        def centre(pts):
            c = np.mean(pts, axis=0)
            a = math.atan2(c[0], c[2])
            return np.array([ring_r * math.sin(a), 0.0, ring_r * math.cos(a)])

        return _orient(faces, centre), count

    if isinstance(mesh, SphereMesh):
        return _orient(faces, np.array([0.0, 0.01, 0.0])), count

    if isinstance(mesh, TriMesh):
        return faces, count

    return _orient(faces, np.zeros(3)), count


def _mesh_faces(mesh):
    if isinstance(mesh, TriMesh):
        return [list(t) for t in mesh.tris], len(mesh.tris)
    if isinstance(mesh, BoxMesh):
        return _box_faces(mesh.size)
    if isinstance(mesh, CylinderMesh):
        attrs = object.__getattribute__(mesh, "_attrs")
        return _cyl_faces(attrs.get("bottom_radius", 0.5), attrs.get("top_radius", 0.5), attrs.get("height", 2.0), attrs.get("radial_segments", 64), attrs.get("rings", 4))
    if isinstance(mesh, SphereMesh):
        attrs = object.__getattribute__(mesh, "_attrs")
        return _dome_faces(attrs.get("radius", 0.5), attrs.get("height", 1.0) if attrs.get("is_hemisphere") else attrs.get("radius", 0.5), attrs.get("radial_segments", 64), attrs.get("rings", 32))
    if isinstance(mesh, TorusMesh):
        attrs = object.__getattribute__(mesh, "_attrs")
        return _torus_faces(attrs.get("inner_radius", 0.5), attrs.get("outer_radius", 1.0), attrs.get("rings", 64), attrs.get("ring_segments", 32))
    return [], 0


# ---------------------------------------------------------------- the look's materials, in the painted icons' palette
# Godot albedo (sRGB) as the flat colour the icon rig lights. The rig is darker than the game's sky, so every colour is lifted the same way
# (LIFT); a few base surfaces use the painted icons' own colours, so a B-batch wall sits beside the painted walls (paint_structure_icons.py).
LIFT = 1.55
PALETTE = {
    "_planks": (184, 140, 92), "_frame": (128, 90, 54), "_roof": (138, 98, 62), "_log": (122, 88, 56), "_logs": (122, 88, 56), "_stone": (168, 160, 148),
    "_blocks": (168, 160, 148), "_flag": (182, 174, 160), "_mortar": (206, 196, 176), "_bricks": (170, 82, 54), "_brick": (170, 82, 54), "_tile": (186, 98, 62),
    "_slate": (104, 108, 112), "_thatch": (214, 182, 104), "_clay": (176, 132, 92), "_daub": (196, 172, 130), "_pot": (58, 52, 48), "_earth": (120, 92, 62),
    "_tar": (40, 38, 36), "_steel": (176, 182, 190), "_iron": (88, 88, 96), "_horn": (222, 178, 104), "_soil": (92, 66, 44), "_water": (86, 132, 150),
    "_concrete": (176, 174, 166),
}


def _rgb(colour):
    return tuple(int(max(0, min(255, round(c * 255 * LIFT)))) for c in (colour.r, colour.g, colour.b))


def _mat(name):
    return Material(None, name)


def colour_of(material):
    if material is None:
        return (160, 150, 140)
    if material.name in PALETTE:
        return PALETTE[material.name]
    return _rgb(material.albedo_color) if material.albedo_color is not None else (160, 150, 140)


# ---------------------------------------------------------------- the primitives piece_look.gd draws with (the same signatures)
def _add_mesh(parent, mesh, at, material):
    node = MeshInstance3D()
    node.mesh = mesh
    node.material_override = material
    node.position = at
    parent.add_child(node)
    return node


def _box(parent, size, at, material):
    m = BoxMesh()
    m.size = size
    _add_mesh(parent, m, at, material)


def _box_rot(parent, size, at, rotation, material):
    m = BoxMesh()
    m.size = size
    _add_mesh(parent, m, at, material).rotation = rotation


def _solid(parent, size, at):
    pass


def _cyl(parent, radius, height, at, material, sides=14, top_radius=-1.0):
    m = CylinderMesh()
    m.top_radius = radius if top_radius < 0.0 else top_radius
    m.bottom_radius = radius
    m.height = height
    m.radial_segments = sides
    m.rings = 1
    return _add_mesh(parent, m, at, material)


def _dome(parent, radius, at, scale, material, segments=16, rings=6):
    m = SphereMesh()
    m.radius = radius
    m.height = radius
    m.is_hemisphere = True
    m.radial_segments = segments
    m.rings = rings
    _add_mesh(parent, m, at, material).scale = scale


def _torus_at(parent, ring, tube, at, material):
    m = TorusMesh()
    m.inner_radius = ring - tube
    m.outer_radius = ring + tube
    m.rings = 12
    m.ring_segments = 5
    _add_mesh(parent, m, at, material)


def _rod(parent, a, b, thick, material):
    m = BoxMesh()
    m.size = Vector3(thick, a.distance_to(b), thick)
    node = _add_mesh(parent, m, (a + b) * 0.5, material)
    up = (b - a).normalized()
    axis = Vector3.UP.cross(up)

    if axis.length() > 0.0001:
        node.basis = Basis(axis.normalized(), Vector3.UP.angle_to(up))


def _log_mesh(length, thick, far):
    m = CylinderMesh()
    m.top_radius = thick * 0.5
    m.bottom_radius = thick * 0.5
    m.height = length
    m.radial_segments = 5 if far else 6
    m.rings = 1
    return m


def _log_at(parent, length, thick, at, far):
    node = _add_mesh(parent, _log_mesh(length, thick, far), at, _log)
    node.rotation = Vector3(0.0, 0.0, math.pi * 0.5)


def _log_along(parent, length, thick, at, along_z):
    node = _add_mesh(parent, _log_mesh(length, thick, False), at, _log)
    node.rotation = Vector3(math.pi * 0.5, 0.0, 0.0) if along_z else Vector3(0.0, 0.0, math.pi * 0.5)


def skin(part, material):
    match = {("wall", "log"): _logs, ("wall", "daub"): _daub, ("wall", "thatch"): _daub, ("wall", "stone"): _blocks, ("wall", "brick"): _bricks,
             ("floor", "stone"): _blocks, ("floor", "brick"): _bricks, ("roof", "thatch"): _thatch, ("frame", "stone"): _blocks, ("frame", "brick"): _blocks,
             ("frame", "log"): _logs}
    return match.get((part, material), {"wall": _planks, "floor": _planks, "roof": _roof, "frame": _frame}.get(part, _planks))


_tones = {}


def _tone_mat(c):
    return _tones.setdefault(c.to_html(), Material(c))


def _noop(*_):
    pass


_planks, _frame, _roof, _earth, _stone, _tar, _steel, _log, _thatch, _clay, _pot = (_mat(n) for n in ("_planks", "_frame", "_roof", "_earth", "_stone", "_tar", "_steel", "_log", "_thatch", "_clay", "_pot"))
_blocks, _bricks, _logs, _daub, _brick, _slate, _tile, _flag, _mortar = (_mat(n) for n in ("_blocks", "_bricks", "_logs", "_daub", "_brick", "_slate", "_tile", "_flag", "_mortar"))
_iron, _horn, _soil = _mat("_iron"), _mat("_horn"), _mat("_soil")
_concrete = _mat("_concrete")

RUNTIME = {
    "Vector3": Vector3, "Vector2": Vector2, "Color": Color, "Basis": Basis, "Node3D": Node3D, "MeshInstance3D": MeshInstance3D, "BoxMesh": BoxMesh,
    "CylinderMesh": CylinderMesh, "SphereMesh": SphereMesh, "TorusMesh": TorusMesh, "PI": math.pi, "TAU": 2 * math.pi, "INF": math.inf,
    "sqrt": math.sqrt, "sin": math.sin, "cos": math.cos, "tan": math.tan, "atan2": math.atan2, "atan": math.atan, "floor": math.floor, "ceil": math.ceil,
    "absf": abs, "floori": lambda v: int(math.floor(v)), "absi": abs, "abs": abs, "maxf": max, "minf": min, "maxi": max, "mini": min, "clampf": lambda v, a, b: max(a, min(b, v)),
    "clampi": lambda v, a, b: max(a, min(b, v)), "lerpf": lambda a, b, t: a + (b - a) * t, "signf": lambda v: (v > 0) - (v < 0), "sign": lambda v: (v > 0) - (v < 0),
    "deg_to_rad": math.radians, "fposmod": lambda a, b: a % b, "posmod": lambda a, b: a % b,
    "_box": _box, "_box_rot": _box_rot, "_solid": _solid, "_cyl": _cyl, "_dome": _dome, "_torus_at": _torus_at, "_rod": _rod, "_log_mesh": _log_mesh,
    "_log_at": _log_at, "_log_along": _log_along, "_tone_mat": _tone_mat, "_materials": _noop, "_tier_materials": _noop,
    "_iron_mat": lambda: _iron, "_horn_mat": lambda: _horn, "_soil_mat": lambda: _soil, "_still_water": lambda: _mat("_water"), "brick_skin": lambda: _bricks,
    "_planks": _planks, "_frame": _frame, "_roof": _roof, "_earth": _earth, "_stone": _stone, "_tar": _tar, "_steel": _steel, "_log": _log,
    "_thatch": _thatch, "_clay": _clay, "_pot": _pot, "_blocks": _blocks, "_bricks": _bricks, "_logs": _logs, "_daub": _daub, "_brick": _brick,
    "_slate": _slate, "_tile": _tile, "_flag": _flag, "_mortar": _mortar, "_concrete": _concrete, "_it": lambda v: range(v) if isinstance(v, int) else v,
    "skin": skin, "StandardMaterial3D": StandardMaterial3D, "RandomNumberGenerator": RandomNumberGenerator, "SurfaceTool": SurfaceTool, "Callable": Callable,
}
OWN = {k for k in RUNTIME if k.startswith("_")} | {"skin", "prewarm", "finish_prewarm", "prewarm_done", "use_terrain_only_decals"}


# ---------------------------------------------------------------- GDScript to Python, line by line
def _strip_types(params):
    out = []

    for p in _split_top(params):
        p = p.strip()
        if not p:
            continue
        m = re.match(r"(\w+)\s*(?::\s*[\w\[\], ]+?)?\s*(?:=\s*(.*))?$", p)
        out.append(m.group(1) + ("=" + m.group(2) if m.group(2) is not None else ""))

    return ", ".join(out)


def _split_top(text):
    parts, depth, cur = [], 0, ""

    for ch in text:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch

    parts.append(cur)
    return parts


def _expr(s):
    s = re.sub(r"\btrue\b", "True", s)
    s = re.sub(r"\bfalse\b", "False", s)
    s = re.sub(r"\bnull\b", "None", s)
    s = re.sub(r"\s+as\s+[A-Z]\w*", "", s)
    s = re.sub(r"\b([A-Z]\w*)\.new\(", r"\1(", s)
    s = re.sub(r"([\w\]\)]+)\.has\(", r"_has(\1, ", s)
    s = re.sub(r"\.size\(\)", ".__len__()", s)
    s = re.sub(r"\.is_empty\(\)", ".__len__() == 0", s)
    s = re.sub(r"\.append_array\(", ".extend(", s)
    s = s.replace("&&", " and ").replace("||", " or ")
    return _kw(s)


def _kw(s):
    """GDScript names that are Python keywords (a local called `from`) get a trailing underscore."""
    return re.sub(r"\b(from|lambda|def|with|del|global|is|raise|try|yield|class|import|assert|except|finally|nonlocal)\b(?!\s*\()", r"\1_", s)


def _indent(line):
    return len(line) - len(line.lstrip("\t"))


def transpile(lines):
    """One GDScript function (its lines, from `static func`) as Python source."""
    out = []
    stack = []   # open match blocks: (indent of the match line, its variable, has an arm been written)
    counter = [0]

    for raw in lines:
        code = _uncomment(raw)

        if not code.strip():
            continue

        ind = _indent(code)
        body = code.strip()

        while stack and ind <= stack[-1][0]:
            stack.pop()

        shift = len(stack)   # each enclosing match removes one level (its arm lines become if / elif at the match's level)

        if stack and ind == stack[-1][0] + 1 and body.endswith(":") and not re.match(r"(if|elif|else|for|while|match)\b", body):
            level, var, _ = stack[-1]
            pat = body[:-1].strip()
            if pat == "_":
                test = "else:"
            else:
                test = ("if " if not stack[-1][2] else "elif ") + " or ".join("%s == %s" % (var, _expr(p.strip())) for p in _split_top(pat)) + ":"
            stack[-1] = (level, var, True)
            out.append("\t" * (level - (shift - 1)) + test)
            continue

        pad = "\t" * (ind - shift)
        m = re.match(r"static func (\w+)\((.*)\)\s*(->\s*[\w\[\]]+)?\s*:$", body)
        if m:
            out.append("def %s(%s):" % (m.group(1), _expr(_strip_types(m.group(2)))))
            continue

        m = re.match(r"match (.*):$", body)
        if m:
            counter[0] += 1
            var = "_m%d" % counter[0]
            out.append(pad + "%s = %s" % (var, _expr(m.group(1))))
            stack.append((ind, var, False))
            continue

        m = re.match(r"var (\w+)\s*(?::\s*[\w\[\], ]*)?\s*:?=\s*(.*)$", body)
        if m:
            out.append(pad + "%s = %s" % (_kw(m.group(1)), _expr(m.group(2))))
            continue

        m = re.match(r"var (\w+)\s*(?::\s*[\w\[\], ]*)?$", body)
        if m:
            out.append(pad + "%s = None" % _kw(m.group(1)))
            continue

        m = re.match(r"for (\w+)\s*(?::\s*\w+)?\s+in\s+(.*):$", body)
        if m:
            out.append(pad + "for %s in _it(%s):" % (_kw(m.group(1)), _expr(m.group(2))))
            continue

        out.append(pad + _expr(body))

    return "\n".join(out) + "\n"


def _uncomment(line):
    quote = None

    for i, ch in enumerate(line):
        if quote:
            if ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
        elif ch == "#":
            return line[:i].rstrip()

    return line.rstrip()


def _has(container, key):
    return key in container


def _chunks(path):
    """The top-level declarations of a .gd file: (kind, name, lines)."""
    lines = open(path, encoding="utf-8").read().split("\n")
    chunks = []
    i = 0

    while i < len(lines):
        line = lines[i]
        m = re.match(r"static func (\w+)", line) or re.match(r"const (\w+)", line)

        if not m:
            i += 1
            continue

        kind = "func" if line.startswith("static func") else "const"
        j = i + 1

        if kind == "func":
            while j < len(lines) and (not lines[j].strip() or lines[j].startswith("\t") or lines[j].lstrip().startswith("#") and lines[j].startswith("\t")):
                j += 1
        else:
            depth = sum(line.count(c) for c in "([{") - sum(line.count(c) for c in ")]}")
            while depth > 0 and j < len(lines):
                depth += sum(lines[j].count(c) for c in "([{") - sum(lines[j].count(c) for c in ")]}")
                j += 1

        chunks.append((kind, m.group(1), lines[i:j]))
        i = j

    return chunks


_space = None
_table = None
FAILED = {}


def _load():
    global _space, _table
    if _space is not None:
        return
    space = dict(RUNTIME)
    space["_has"] = _has

    for name in set(re.findall(r"\b([A-Z][A-Za-z0-9_]*[a-z][A-Za-z0-9_]*)\b", open(PIECE_LOOK, encoding="utf-8").read())):
        space.setdefault(name, type(name, (Anything,), {}))   # Godot classes the looks touch but nothing draws (bodies, lights, decals, noise)

    for kind, name, lines in _chunks(PIECE_LOOK):
        if name in OWN:
            continue
        try:
            if kind == "const":
                text = " ".join(_uncomment(x) for x in lines)
                m = re.match(r"const (\w+)\s*(?::\s*[\w\[\]]+)?\s*:?=\s*(.*)$", text.strip())
                space[name] = eval(_expr(m.group(2)), space)
            else:
                exec(compile(transpile(lines), "piece_look.gd:" + name, "exec"), space)
        except Exception as e:   # noqa: BLE001  (a builder this cannot run is reported, and the others still work)
            FAILED[name] = repr(e)

    _space = space
    table = {}
    text = open(LOOK_TABLE, encoding="utf-8").read()

    for m in re.finditer(r'^\t"(\w+)": \{"builder": "(\w+)", "args": \[(.*?)\]\}', text, re.M):
        table[m.group(1)] = (m.group(2), eval("[" + _expr(m.group(3)) + "]", space))

    _table = table


def looks():
    _load()
    return dict(_table)


def build(look):
    """The look's node tree, as look_table.gd builds it."""
    _load()
    builder, args = _table[look]
    if builder not in _space:
        raise KeyError("piece_look.gd %s could not be read: %s" % (builder, FAILED.get(builder, "missing")))
    return _space[builder](*args)


def _walk(node, turn=np.eye(3), shift=np.zeros(3)):
    t, p = node.local()
    turn2, shift2 = turn @ t, turn @ p + shift

    if not getattr(node, "visible", True):
        return

    if isinstance(node, MeshInstance3D) and node.mesh is not None:
        yield node, turn2, shift2

    for child in node.children:
        if isinstance(child, Node3D):
            yield from _walk(child, turn2, shift2)


def faces_of(root):
    """Every face of the look in its own space: [(points, (r, g, b))], each wound to face out."""
    out = []

    for node, turn, shift in _walk(root):
        faces, _ = mesh_faces(node.mesh)
        colour = colour_of(node.material_override)

        for pts in faces:
            world = [turn @ p + shift for p in pts]
            out.append((world, colour))

    return out


def bounds(root):
    pts = np.array([p for pts, _ in faces_of(root) for p in pts])
    return pts.min(axis=0), pts.max(axis=0)


def triangles(root):
    return sum(mesh_faces(node.mesh)[1] for node, _, _ in _walk(root))


if __name__ == "__main__":
    _load()
    for name, err in FAILED.items():
        print("could not read", name, err)
    for look in sys.argv[1:]:
        r = build(look)
        lo, hi = bounds(r)
        print("%-24s x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f  tris %d" % (look, lo[0], hi[0], lo[1], hi[1], lo[2], hi[2], triangles(r)))
