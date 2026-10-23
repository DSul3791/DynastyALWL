#!/usr/bin/env python3
"""Cheap pre-merge parse scan for GDScript (no Godot needed). Finds what broke our merge checks:

  DUP     a local declared twice in the same or an enclosing block of one function (Godot: "already declared")
  CLASH   a function with the same name as a member var/const/signal in the file (the water_debug clash)
  NATIVE  a const/var/class_name named like a native Godot class (TileData shadows the engine class)
  FUNCDUP the same function name defined twice in a file
  SHADOW  a local named like a member var (warning only, counted by local_check)

Usage: tools/parse_scan.py [paths...]     (default: every .gd under src, scenes, tools)
Exit 1 when any DUP, CLASH, NATIVE or FUNCDUP is found. SHADOW is listed with --shadow.
It reads text only, so it can miss things (inline lambdas, multi-line expressions); a hit is worth a look, no hit is not a proof.
"""
import os
import re
import sys

NATIVE = set("""AABB Animation AnimationPlayer AnimationTree Area2D Area3D Array ArrayMesh AudioBusLayout AudioEffect AudioServer AudioStream
AudioStreamPlayer AudioStreamPlayer2D AudioStreamPlayer3D BoxMesh BoxShape3D Button Callable Camera2D Camera3D CanvasItem CanvasLayer
CapsuleMesh CapsuleShape3D CharacterBody2D CharacterBody3D CollisionShape3D Color ColorRect Control ConvexPolygonShape3D Crypto Curve
Curve2D Curve3D CylinderMesh DirAccess DirectionalLight3D DisplayServer Dictionary Engine Environment FileAccess Font Gradient GPUParticles3D
GridContainer HBoxContainer HTTPRequest Image ImageTexture Input InputEvent InputMap Label Light3D Line2D Marker3D Material Mesh MeshInstance3D
MultiMesh MultiMeshInstance3D Mutex NavigationServer3D Node Node2D Node3D Noise OS Object PackedByteArray PackedFloat32Array PackedInt32Array
PackedScene PackedStringArray PackedVector2Array PackedVector3Array Panel PanelContainer PhysicsServer3D PlaneMesh Plane Projection Quaternion
RandomNumberGenerator Range RayCast3D Rect2 Rect2i RefCounted Resource ResourceLoader RichTextLabel RigidBody3D SceneTree Script
ScrollContainer Semaphore Shader ShaderMaterial Shape3D Signal Skeleton3D Skin Sky SphereMesh SphereShape3D SpotLight3D Sprite2D Sprite3D
StaticBody3D StandardMaterial3D String StringName SubViewport TextEdit TextServer Texture Texture2D Thread TileData TileMap TileMapLayer TileSet
Time Timer Transform2D Transform3D Tween Variant Vector2 Vector2i Vector3 Vector3i Vector4 VBoxContainer Viewport VoxelBuffer VoxelGenerator
VoxelMesher VoxelStream VoxelTerrain VoxelTool Window WorldEnvironment XRServer Expression Geometry3D GDScript JSON Marshalls Performance
ProjectSettings Basis Octree Path3D PathFollow3D Decal FogVolume Fog GraphNode Tree TreeItem Container Joint3D Occluder3D Lightmap""".split())

DECL = re.compile(r"^(\t*)(var|const)\s+(\w+)")
FUNC = re.compile(r"^(\t*)(static\s+)?func\s+(\w+)\s*\(([^)]*)")
MEMBER = re.compile(r"^(var|const|signal|enum)\s+(\w+)")
CLASSN = re.compile(r"^class_name\s+(\w+)")


def scan(path, shadow):
    problems = []
    members = {}
    funcs = {}
    lines = open(path, encoding="utf-8", errors="replace").read().split("\n")

    for n, text in enumerate(lines, 1):
        m = MEMBER.match(text) or re.match(r"^@\w+(?:\([^)]*\))?\s+(var)\s+(\w+)", text)
        if m:
            members[m.group(2)] = n
            if m.group(2) in NATIVE:
                problems.append((path, n, "NATIVE", "%s is the name of a native Godot class" % m.group(2)))
        c = CLASSN.match(text)
        if c and c.group(1) in NATIVE:
            problems.append((path, n, "NATIVE", "class_name %s is a native Godot class" % c.group(1)))
        f = FUNC.match(text)
        if f and not f.group(1):
            if f.group(3) in funcs:
                problems.append((path, n, "FUNCDUP", "func %s also defined at line %d" % (f.group(3), funcs[f.group(3)])))
            funcs[f.group(3)] = n
            if f.group(3) in members:
                problems.append((path, n, "CLASH", "func %s has the same name as the member declared at line %d" % (f.group(3), members[f.group(3)])))

    # Locals: a stack of (indent, {name: line}) per function.
    stack = []
    in_func = False
    params = set()

    for n, text in enumerate(lines, 1):
        if not text.strip() or text.lstrip().startswith("#"):
            continue
        indent = len(text) - len(text.lstrip("\t"))

        if indent == 0:
            in_func = bool(FUNC.match(text))
            stack = [(0, {})] if in_func else []
            params = set()
            f = FUNC.match(text)
            if f:
                for p in f.group(4).split(","):
                    name = p.strip().split(":")[0].split("=")[0].strip()
                    if name:
                        params.add(name)
                        stack[0][1][name] = n
            continue

        if not in_func:
            continue

        while len(stack) > 1 and stack[-1][0] > indent:
            stack.pop()

        if stack[-1][0] < indent:
            stack.append((indent, {}))

        d = DECL.match(text)
        if d and len(d.group(1)) == indent:
            name = d.group(3)
            if name in NATIVE:
                problems.append((path, n, "NATIVE", "local %s is a native Godot class name" % name))
            for _, scope in stack[:-1]:
                if name in scope:
                    problems.append((path, n, "DUP", "%s already declared at line %d" % (name, scope[name])))
                    break
            else:
                if name in stack[-1][1]:
                    problems.append((path, n, "DUP", "%s already declared at line %d" % (name, stack[-1][1][name])))
                elif shadow and name in members:
                    problems.append((path, n, "SHADOW", "%s shadows the member at line %d" % (name, members[name])))
            stack[-1][1][name] = n

    return problems


def main(argv):
    shadow = "--shadow" in argv
    paths = [a for a in argv if not a.startswith("--")]
    if not paths:
        root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        paths = [root + "/" + d for d in ("src", "scenes", "tools")]
    files = []
    for p in paths:
        if os.path.isdir(p):
            for base, _, names in os.walk(p):
                files += [os.path.join(base, x) for x in names if x.endswith(".gd")]
        else:
            files.append(p)
    found = []
    for f in sorted(files):
        found += scan(f, shadow)
    for path, n, kind, what in found:
        print("%s:%d: %s %s" % (path, n, kind, what))
    print("parse_scan: %d files, %d problems" % (len(files), len(found)))
    return 1 if any(k != "SHADOW" for _, _, k, _ in found) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
