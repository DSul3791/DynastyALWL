#!/usr/bin/env python3
"""The two release builds (server/client split step C2, Dave 18 Nov 2026: the client is a separate download; the server and the
generator stay one build): checks export_presets.cfg without exporting, since our engine's export templates do not exist yet.

  python3 tools/export_check.py            check both presets; exit 1 on a problem
  python3 tools/export_check.py --write    rewrite the client preset's generated exclude list, then check
  python3 tools/export_check.py --list P   print the files preset P ("client" or "server") would carry
  python3 tools/export_check.py --ci       for tools/merge_check.py: exit 1 only when a pack lacks a file its build loads; server-only
                                           code that crept into the client is a warning there (the release script checks in full)

What it does:
  1. Works out which tracked files each preset would put in the pack, the way Godot's "all_resources" filter does: every resource
     (scenes, scripts, shaders, imported media) plus the include_filter globs, minus the exclude_filter globs. Godot matches a glob
     against the path with and without "res://", case-insensitively, and * crosses folders.
  2. Follows what the client loads from the main scene (res:// and uid:// strings, class_name use; a res:// folder or prefix
     brings everything under it), and what the server loads from its scene. LAUNCH_ONLY lists the res:// strings that are not
     loads in the client (a scene path handed to another process, an editor-only tool).
  3. Fails when the client pack lacks a file the client loads, carries world tiles, tools, tests, docs or server-only code (scripts
     and scenes only the server loads; --write keeps that list in the client's exclude_filter), or lacks the client_only feature; or when the server pack lacks a file the server loads, the world,
     or the build stamp.

Not proven until a real export with our voxel templates (C1): that Godot's own filter picks exactly these files, that imported
media (sounds listed with DirAccess at run time) are found inside the pack, and that the game runs from it.
"""
import fnmatch
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PRESETS = os.path.join(ROOT, "export_presets.cfg")

CLIENT_ROOTS = ["project.godot"]                                        # the main scene (the launcher) and what it opens
SERVER_ROOTS = ["project.godot", "scenes/terrain_server/terrain_server.tscn"]

# res:// strings that are not loads in a client-only build: {file: [res path]}.
LAUNCH_ONLY = {
    "scenes/launcher.gd": [
        "scenes/terrain_server/terrain_server.tscn",   # Play's local server: another process (and --role=terrain_server, the server build)
        "scenes/terrain_preview/terrain_preview.tscn", # --role=terrain, a developer view
    ],
    "src/client/game_menu.gd": ["src/admin/tile_bake_launcher.gd"],   # the admin bake, editor runs only (OS.has_feature("editor"))
    "src/debug/git_stamp.gd": [".git"],                                # the checkout's own .git folder, absent in an export
}

# Never in the client pack, whatever loads them; the server pack needs the world ones (WORLD).
WORLD = ["worlds/base_world/tiles/*", "worlds/base_world/erosion_delta_v2.bin", "worlds/base_world/water/*"]
DEVELOPER = ["docs/*", "tools/*", "art/*", "deploy/*", "native/*", "proposed_removals/*", "design/*", "tech/*", "items/*", "120/*",
             ".claude/*", ".github/*", "src/worldgen/tools/*", "src/admin/*", "scenes/terrain_preview/*", "crash_reports/*",
             "*.md", "*.py", "*.sh", "*.bat", "*.ps1", "*.log", "*.out", "*.result", "*.patch", "*.bak", "INSTALL_README.txt"]
SERVER_NEEDS = ["worlds/base_world/world.json", "worlds/base_world/plan/tile_rules.json", "worlds/base_world/erosion_delta_v2.bin"]
STAMP = "build_stamp.json"   # tools/build_stamp.py writes it before an export (step A1); untracked, so checked against the filter

RESOURCE_EXT = {".tscn", ".scn", ".tres", ".res", ".gd", ".gdshader", ".gdshaderinc", ".gdextension", ".godot"}
IMPORTED_EXT = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".exr", ".hdr", ".ogg", ".wav", ".mp3", ".glb", ".gltf", ".fbx", ".obj",
                ".blend", ".ttf", ".otf", ".woff", ".woff2", ".csv"}
FOLLOW_EXT = (".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc", ".json", ".godot")
CODE_EXT = (".gd", ".tscn", ".scn", ".gdshader")

RES = re.compile(r'res://([^"\'\\\s)]*)')
UID = re.compile(r'uid://[a-z0-9]+')
WORD = re.compile(r'\b([A-Z]\w+)\b')


def tracked():
    out = subprocess.run(["git", "-C", ROOT, "ls-files"], check=True, capture_output=True, text=True).stdout.split("\n")
    return [f for f in out if f and os.path.exists(os.path.join(ROOT, f))]


def read(f):
    with open(os.path.join(ROOT, f), encoding="utf-8", errors="ignore") as handle:
        return handle.read()


class Project:
    def __init__(self):
        self.files = tracked()
        self.fileset = set(self.files)
        self.uids = {}
        self.classes = {}

        for f in self.files:
            if f.endswith(".uid"):
                self.uids[read(f).strip()] = f[:-4]
            elif f.endswith((".tscn", ".tres", ".import")):
                found = re.search(r'uid="(uid://[a-z0-9]+)"', read(f)[:4000])

                if found:
                    self.uids[found.group(1)] = f[:-7] if f.endswith(".import") else f
            if f.endswith(".gd"):
                found = re.search(r'^class_name\s+(\w+)', read(f), re.M)

                if found:
                    self.classes[found.group(1)] = f

    def refs(self, f, skip):
        if not f.endswith(FOLLOW_EXT):
            return set()

        text = read(f)

        if f.endswith(".gd"):
            text = "\n".join(_code_only(line) for line in text.split("\n"))

        out = set()

        for ref in RES.findall(text):
            ref = ref.rstrip("/")

            if not ref or ref in skip.get(f, ()):
                continue

            if ref in self.fileset:
                out.add(ref)
            else:   # a folder, or the start of a path built at run time ("res://data/items/" + name)
                out.update(x for x in self.files if x.startswith(ref) and not x.endswith((".import", ".uid")))

        for uid in UID.findall(text):
            if uid in self.uids:
                out.add(self.uids[uid])

        if f.endswith(".gd"):
            out.update(self.classes[w] for w in set(WORD.findall(text)) if w in self.classes and self.classes[w] != f)

        return out

    def closure(self, roots, skip):
        seen = set()
        todo = list(roots)

        while todo:
            f = todo.pop()

            if f not in seen:
                seen.add(f)
                todo.extend(self.refs(f, skip) - seen)

        return seen


def _code_only(line):
    if line.lstrip().startswith("#"):
        return ""

    cut = line.find(" #")
    return line[:cut] if cut >= 0 and line[:cut].count('"') % 2 == 0 else line


def globs(value):
    return [g.strip() for g in value.split(",") if g.strip()]


def matches(path, patterns):
    low = path.lower()
    return any(fnmatch.fnmatchcase(low, g.lower()) or fnmatch.fnmatchcase("res://" + low, g.lower()) for g in patterns)


def is_resource(f, fileset):
    ext = os.path.splitext(f)[1].lower()
    return ext in RESOURCE_EXT or ext in IMPORTED_EXT or (f + ".import") in fileset


def pack(project, preset):
    include = globs(preset.get("include_filter", ""))
    exclude = globs(preset.get("exclude_filter", ""))
    out = set()

    for f in project.files:
        if f.endswith((".import", ".uid")):
            continue

        if (is_resource(f, project.fileset) or matches(f, include)) and not matches(f, exclude):
            out.add(f)

    return out


def load_presets():
    presets = {}
    current = None

    with open(PRESETS, encoding="utf-8") as handle:
        for line in handle:
            line = line.rstrip("\n")
            head = re.match(r'^\[(preset\.\d+)\]$', line)

            if head:
                current = presets.setdefault(head.group(1), {})
                continue

            if line.startswith("["):
                current = None
                continue

            pair = re.match(r'^([\w/]+)=(.*)$', line)

            if current is not None and pair:
                value = pair.group(2)
                current[pair.group(1)] = value[1:-1] if value.startswith('"') and value.endswith('"') else value

    by_name = {}

    for preset in presets.values():
        if "client_only" in globs(preset.get("custom_features", "")):
            by_name["client"] = preset
        else:
            by_name["server"] = preset

    return by_name


# Files a load can name that are no part of the game: notes, generator scripts and placeholders beside the media.
def game_file(f):
    return not matches(f, DEVELOPER) and not os.path.basename(f).startswith(".")


def server_only(project):
    client = project.closure(CLIENT_ROOTS, LAUNCH_ONLY)
    server = project.closure(SERVER_ROOTS, {})
    # Code and scenes only: a data file left in the client costs a few KB, and one wrongly left out (a path built at run time) breaks a feature.
    return sorted(f for f in server - client if game_file(f) and f.endswith(CODE_EXT))


# The fewest globs that cover `files`: a whole folder when nothing in it is loaded by the client.
def folder_globs(project, files, client):
    out = []

    for f in files:
        parts = f.split("/")
        best = f

        for depth in range(1, len(parts)):
            folder = "/".join(parts[:depth]) + "/"

            if not any(x.startswith(folder) for x in client):
                best = folder + "*"
                break

        if best not in out:
            out.append(best)

    return sorted(set(out))


def write(project):
    client = project.closure(CLIENT_ROOTS, LAUNCH_ONLY)
    generated = folder_globs(project, server_only(project), client)
    text = open(PRESETS, encoding="utf-8").read()
    marker = re.search(r'(\[preset\.\d+\]\n(?:(?!\[preset).*\n)*?custom_features="[^"]*client_only[^"]*"\n(?:(?!\[preset).*\n)*?)'
                       r'exclude_filter="([^"]*)"', text)

    if marker is None:
        sys.exit("export_check: no client preset (custom_features client_only) with an exclude_filter in export_presets.cfg")

    fixed = ", ".join(WORLD + DEVELOPER + generated)
    text = text[:marker.start(2)] + fixed + text[marker.end(2):]

    with open(PRESETS, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)

    print("export_check: client exclude_filter written (%d globs, %d of them server-only code)" % (len(WORLD + DEVELOPER + generated), len(generated)))


def check(project):
    presets = load_presets()
    problems = []

    for name in ("client", "server"):
        if name not in presets:
            problems.append("no %s preset in export_presets.cfg" % name)

    if problems:
        return problems, {}

    client_pack = pack(project, presets["client"])
    server_pack = pack(project, presets["server"])
    client_needs = {f for f in project.closure(CLIENT_ROOTS, LAUNCH_ONLY) if game_file(f) and not f.endswith((".import", ".uid")) and f != "project.godot"}
    server_needs = {f for f in project.closure(SERVER_ROOTS, {}) if game_file(f) and not f.endswith((".import", ".uid")) and f != "project.godot"}
    forbidden = set(server_only(project))

    for f in sorted(client_needs - client_pack):
        problems.append("client pack lacks %s, which the client loads" % f)

    for f in sorted(client_pack):
        if matches(f, WORLD) or matches(f, DEVELOPER):
            problems.append("client pack carries %s (world data, tools, tests or docs)" % f)
        elif f in forbidden:
            problems.append("client pack carries server-only %s (run tools/export_check.py --write)" % f)

    for f in sorted(server_needs - server_pack):
        problems.append("server pack lacks %s, which the server loads" % f)

    for f in SERVER_NEEDS + [x for x in project.files if matches(x, WORLD)]:
        if f not in server_pack:
            problems.append("server pack lacks the world file %s" % f)

    for name in ("client", "server"):
        if not matches(STAMP, globs(presets[name].get("include_filter", ""))) or matches(STAMP, globs(presets[name].get("exclude_filter", ""))):
            problems.append("%s pack would not carry %s (the build stamp, step A1)" % (name, STAMP))

    return problems, {"client": client_pack, "server": server_pack, "client_needs": client_needs}


def size_mb(project, files):
    return sum(os.path.getsize(os.path.join(ROOT, f)) for f in files) / 1048576.0


def main(argv):
    project = Project()

    if "--write" in argv:
        write(project)

    if "--list" in argv:
        name = argv[argv.index("--list") + 1]
        problems, packs = check(project)

        for f in sorted(packs.get(name, [])):
            print(f)

        return 0

    problems, packs = check(project)

    if packs:
        client = packs["client"]
        server_code = sorted(f for f in client if f.startswith(("src/stream/server_", "src/server/", "src/worldgen/")) and f.endswith(".gd"))
        print("export_check: client pack %d files, %.0f MB of sources; server pack %d files, %.0f MB" % (
            len(client), size_mb(project, client), len(packs["server"]), size_mb(project, packs["server"])))
        print("export_check: server or generator scripts the client still loads (%d): %s" % (len(server_code), ", ".join(server_code)))

    for problem in problems:
        print("  - " + problem)

    if "--ci" in argv:
        broken = [p for p in problems if " lacks " in p]
        print("export_check: %s" % ("FAILED (%d files missing from a pack)" % len(broken) if broken else
                                    "%d warnings (python3 tools/export_check.py --write)" % len(problems) if problems else "all clear"))
        return 1 if broken else 0

    print("export_check: %s" % ("FAILED (%d problems)" % len(problems) if problems else "all clear"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
