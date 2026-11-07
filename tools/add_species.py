"""Add one new animal species to every place the game needs it (the donkey's recipe, design/ANIMALS_BATCHES.md).

    python tools/add_species.py spec.json        (run from the project folder)

spec.json (one species):
{
  "kind": "chamois", "number": 23, "name": "Chamois",
  "copy": "deer",                         server row to start from (data/animals/animals.json)
  "row": {...},                           keys laid over the copy; a nested dict (defend, habitat) is merged, biomes/active/herd replaced; null removes a key
  "model": {...},                         the models.json row (scene, pack, clips, materials, length_m ...)
  "carcass_look": {...},                  data/animals/carcass.json look (len, width, coat ...)
  "carcass_items": "wild_sheep" or {...}, data/items/carcass.json species row, or the kind to copy it from (skipped when one is there)
  "season": "year round",                 data/items/seasons.json game note (skipped when one is there)
  "sign": {...} or "deer",                data/animals/animal_sign.json row, or the kind to copy (skipped when one is there)
  "step": ["deer", -13],                  a <kind>_step slot borrowing that animal's step clips at that level
  "stand_in": ["_make_deer(id)", 0.6]     the code-built body drawn until the model files are there, and its scale
}
Each file is rewritten in its own style (tab JSON, or text insertion where the file is hand-formatted); run it once per species.
"""
import copy, json, re, sys

spec = json.load(open(sys.argv[1], encoding="utf8"))
kind, number = spec["kind"], int(spec["number"])


def load(p):
    return json.load(open(p, encoding="utf8"))


def save(p, d):
    open(p, "w", encoding="utf8", newline="\n").write(json.dumps(d, indent="\t", ensure_ascii=False) + "\n")


# Server row
A = "data/animals/animals.json"
a = load(A)
sp = a["species"]
assert kind not in sp, kind + " is already a species"
assert all(int(v.get("number", -1)) != number for v in sp.values() if isinstance(v, dict)), "number %d is taken" % number
row = copy.deepcopy(sp[spec["copy"]])
for k in ("note", "note_temperament", "model", "den"):
    row.pop(k, None)
row["number"] = number
row["name"] = spec["name"]
for k, v in spec.get("row", {}).items():
    if v is None:
        row.pop(k, None)
    elif isinstance(v, dict) and isinstance(row.get(k), dict) and k not in ("biomes", "active", "temperament"):
        row[k].update(v)
    else:
        row[k] = v
sp[kind] = row
save(A, a)

# Model row
if "model" in spec:
    M = "data/animals/models.json"
    m = load(M)
    m["species"][kind] = spec["model"]
    save(M, m)

# Carcass look (hand-formatted: one line per species)
if "carcass_look" in spec:
    K = "data/animals/carcass.json"
    t = open(K, encoding="utf8").read()
    if '"%s":' % kind not in t:
        line = '\t\t"%s": %s' % (kind, json.dumps(spec["carcass_look"], ensure_ascii=False))
        t = t.replace('\t\t"bear": {', line + ',\n\t\t"bear": {', 1)
        json.loads(t)
        open(K, "w", encoding="utf8", newline="\n").write(t)

# Items: carcass parts, season
C = "data/items/carcass.json"
c = load(C)
if kind not in c["species"] and "carcass_items" in spec:
    src = spec["carcass_items"]
    c["species"][kind] = copy.deepcopy(c["species"][src]) if isinstance(src, str) else src
    save(C, c)
S = "data/items/seasons.json"
s = load(S)
if kind not in s["game"]:
    s["game"][kind] = {"seasons": ["all"], "months": "all year", "note": spec.get("season", "year round")}
    save(S, s)

# Sign
G = "data/animals/animal_sign.json"
g = load(G)
if kind not in g["species"] and "sign" in spec:
    src = spec["sign"]
    g["species"][kind] = copy.deepcopy(g["species"][src]) if isinstance(src, str) else src
    save(G, g)

# Step sound (hand-formatted)
if "step" in spec:
    P = "data/sound/batch1_slots.json"
    t = open(P, encoding="utf8").read()
    if '"%s_step"' % kind not in t:
        src, db = spec["step"]
        slot = ('  "%s_step": {\n   "group": "creature step",\n   "files": [\n    "res://assets/audio/batch1/%s_step_0.ogg",\n    "res://assets/audio/batch1/%s_step_1.ogg",\n    "res://assets/audio/batch1/%s_step_2.ogg"\n   ],\n   "loop": false,\n   "peak_db": %d,\n   "status": "filled",\n   "note": "borrowed from %s"\n  },\n' % (kind, src, src, src, db, src))
        t = t.replace('  "ladder_rung": {', slot + '  "ladder_rung": {', 1)
        json.loads(t)
        open(P, "w", encoding="utf8", newline="\n").write(t)

# Animal view: the kind's number, and a code-built stand-in
V = "src/client/animal_view.gd"
t = open(V, encoding="utf8").read()
t, n = re.subn(r'(const KIND_OF_SPECIES := \{[^}]*)\}', lambda mm: mm.group(1) + ', %d: "%s"}' % (number, kind), t, count=1)
assert n == 1
if "stand_in" in spec:
    call, scale = spec["stand_in"]
    anchor = '\n\treturn null   # a species number with no model is not drawn'
    assert anchor in t
    block = '\t\t%d:\n\t\t\tvar %s: Node3D = %s      # stand-in until the model files are there\n\t\t\t%s.scale = Vector3.ONE * %s\n\t\t\treturn %s\n' % (number, kind, call, kind, scale, kind)
    head, tail = t.split(anchor, 1)
    head = head.rstrip("\n") + "\n" + block
    t = head + "\n" + anchor + tail
open(V, "w", encoding="utf8", newline="\n").write(t)

# The animal tests' newer-species lists keep their seeded counts
for f in ("test_animal_senses", "test_animals", "test_big_game", "test_flocks", "test_thieves", "test_wolves"):
    p = "src/worldgen/tools/%s.gd" % f
    t = open(p, encoding="utf8").read()
    t2, n = re.subn(r'("beaver"(?:, "[a-z_]+")*)\]', lambda mm: mm.group(1) + ', "%s"]' % kind, t, count=1)
    assert n == 1, p
    open(p, "w", encoding="utf8", newline="\n").write(t2)

print("added", kind, number)
