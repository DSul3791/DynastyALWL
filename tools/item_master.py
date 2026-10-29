#!/usr/bin/env python3
"""Master item list with gaps (goal 2).

  python3 tools/item_master.py [out.md]   write the list (stdout without a file)
  python3 tools/item_master.py --check    exit 1 when tech/ITEM_MASTER.md in the project folder is stale

Deterministic: the same data gives a byte-identical file. Reads data/items/items.json, recipes.json and
design_names.json (exact id or alias match only, no guessing), plus the item sheet (source, cost, inspect text, use, look, weight, value),
item_uses.json, gathered.json and the poison check against flora.json. --check also exits 1 when a poison text disagrees with the server's harm list."""
import glob
import json
import os
import re
import sys
import collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MASTER = "/mnt/project-files/tech/ITEM_MASTER.md"


def load(name):
    with open(os.path.join(ROOT, "data/items", name)) as f:
        return json.load(f)


CODE_LOOKS = ("stick", "log", "driftwood", "plant_fibre", "firewood")   # drawn by inventory_view.gd as a log shape


def sheet(items, recipes):
    """The item sheet: one row per live item, the empty cells, the gathered items and the poison check. Returns (lines, poison_gaps)."""
    structures = load("structures.json")["structures"]
    looks = load("looks.json").get("items", {})
    weights = load("weights.json").get("by_id", {})
    uses_note = load("item_uses.json")["uses"]
    text_all = "\n".join(open(p).read() for p in sorted(glob.glob(os.path.join(ROOT, "data/items/*.json")))
                         if os.path.basename(p) not in ("items.json", "recipes.json", "weights.json", "looks.json", "structures.json", "item_uses.json"))
    made_by, used_in = {}, {}
    for rid, r in recipes.items():
        if r.get("retired"):
            continue
        made_by.setdefault(r["gives"][0], []).append(rid)
        for need in r["needs"]:
            used_in.setdefault(need[0], []).append(rid)
    struct_items = {}
    for kind, st in structures.items():
        for field in ("kit", "item"):
            if st.get(field):
                struct_items.setdefault(st[field], []).append(kind)

    def use_of(item):
        kind = item.get("kind")
        if item.get("tool_class"):
            return "tool: %s tier %s" % (item["tool_class"], item.get("tier", 1))
        if kind == "food":
            return "food"
        if item["id"] in uses_note:
            return uses_note[item["id"]]
        if kind in ("placeable", "structure"):
            return "placed: " + ", ".join(struct_items.get(item["id"], [])) if struct_items.get(item["id"]) else ""
        if kind in ("clothing", "gear"):
            return "worn: slot %s" % item.get("slot", "?")
        if kind == "weapon":
            return "weapon: %s" % item.get("weapon_class", "?")
        if kind in ("container", "coin", "medicine"):
            return kind
        if item["id"] in used_in:
            return "ingredient of " + ", ".join(used_in[item["id"]][:3])
        return ""

    rows, gaps = [], {}
    for iid, item in items.items():
        if item.get("retired"):
            continue
        item = dict(item, id=iid)
        source = ", ".join("recipe " + r for r in made_by.get(iid, []))
        if not source and re.search(r'"%s"' % re.escape(iid), text_all):
            source = "world (gathered, dropped, caught or cooked: see data/items)"
        if not source and iid in struct_items:
            source = "placed piece"
        cost = ""
        if iid in made_by:
            cost = ", ".join("%d %s" % (n[1], n[0]) for n in recipes[made_by[iid][0]]["needs"])
        look = "looks.json" if iid in looks or iid in CODE_LOOKS or iid.startswith("log_") else ("pile" if "pile" in item else ("structure look" if iid in struct_items else ""))
        weight = weights.get(iid)
        row = {"number": item["number"], "id": iid, "name": item["name"], "kind": item["kind"], "source": source, "cost": cost,
               "inspect": item.get("description", ""), "use": use_of(item), "look": look,
               "status": "future" if item.get("future") else "live", "weight": "" if weight is None else str(weight), "value": str(item.get("value", ""))}
        rows.append(row)
        for cell in ("source", "inspect", "use", "look", "value"):
            if not row[cell] and not (cell == "value" and item["kind"] == "structure") and not (cell == "source" and item.get("future")):
                gaps.setdefault(cell, []).append(iid)
    gathered = load("gathered.json")["items"]
    gathered_gaps = [gid for gid, g in gathered.items() if not g.get("description")]
    # The server's harm list (server_items.gd): every yield of a flora entry whose uses has "poison" is never food; their texts must say so, and no other text may.
    with open(os.path.join(ROOT, "data/tables/flora.json")) as f:
        flora = json.load(f)["entries"]
    unfit = set(y for e in flora if "poison" in (e.get("uses") or []) for y in e["yields"])
    poison_text = set(gid for gid, g in gathered.items() if "oisonous" in (g.get("description") or ""))
    poison_gaps = sorted((unfit - poison_text) | (poison_text - unfit))
    rows.sort(key=lambda r: r["number"])
    out = ["## Item sheet", "%d items (%d live, %d future). Empty cells: %s." % (len(rows), sum(1 for r in rows if r["status"] == "live"), sum(1 for r in rows if r["status"] == "future"),
                                                                              ", ".join("%s %d" % (k, len(v)) for k, v in sorted(gaps.items())) or "none"), "",
           "| # | id | name | kind | status | source | cost | use | look | kg | value |", "|---|---|---|---|---|---|---|---|---|---|---|"]
    for r in rows:
        out.append("| %d | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (r["number"], r["id"], r["name"], r["kind"], r["status"], r["source"] or ("not yet" if r["status"] == "future" else "**?**"),
                                                                             r["cost"], r["use"] or "**?**", r["look"] or "**?**", r["weight"] or "default", r["value"] or "**?**"))
    out += ["", "### Gathered items (data/items/gathered.json): %d, %d without an inspect text" % (len(gathered), len(gathered_gaps))]
    if gathered_gaps:
        out.append(", ".join(gathered_gaps))
    out.append("")
    out.append("### Poison text vs the server's harm list: %s" % (", ".join(poison_gaps) if poison_gaps else "all match"))
    out.append("")
    for cell, ids in sorted(gaps.items()):
        out.append("### Empty %s (%d)\n%s\n" % (cell, len(ids), ", ".join(ids)))
    return out, poison_gaps


def build():
    items = [dict(v, id=k) for k, v in load("items.json")["items"].items()]
    recipes = load("recipes.json")["recipes"]
    design = load("design_names.json")
    made = collections.defaultdict(list)
    used = collections.defaultdict(list)

    for rid, r in recipes.items():
        if r.get("retired"):
            continue
        made[r["gives"][0]].append(rid)
        for n in r.get("needs", []):
            used[n[0]].append(rid)

    live = [i for i in items if not i.get("retired")]
    retired = [i for i in items if i.get("retired")]
    ids = {i["id"] for i in live}
    rows = []
    gaps = collections.Counter()

    for i in live:
        k = i["id"]
        m = len(made.get(k, []))
        u = len(used.get(k, []))
        gap = []
        if not m and i["kind"] in ("tool", "clothing", "structure", "placeable", "weapon", "container", "gear") and not i.get("future"):
            gap.append("no recipe")
        if i.get("value") is None and i["kind"] != "structure":
            gap.append("no value")
        if i["kind"] == "material" and not u and not i.get("future"):
            gap.append("not used")
        if i.get("future"):
            gap.append("future")
        for g in gap:
            gaps[g] += 1
        rows.append((i["kind"], i["number"], i["name"], i.get("value", ""), m, u, ", ".join(gap)))

    covered = []
    missing = []
    for name, category in sorted(design["names"].items()):
        ways = [name] if name in ids else [a for a in design["aliases"].get(name, []) if a in ids]
        (covered if ways else missing).append((name, category, ", ".join(ways)))

    out = ["<!-- GENERATED by tools/item_master.py; do not edit. Rerun the tool (python3 tools/item_master.py tech/ITEM_MASTER.md), --check fails when stale. -->",
           "# Item master list", "",
           "## Gap rules",
           "| Gap | Rule |", "|---|---|",
           "| no recipe | tool, clothing, structure, placeable, weapon, container or gear with no live recipe and not marked future (structures are built by blueprint, so expected) |",
           "| no value | priced items only; placed structures are exempt (kits carry the price) |",
           "| not used | material no live recipe consumes and not marked future |",
           "| future | exists in data, not yet reachable |", "",
           "## Counts",
           "| What | Count |", "|---|---|",
           "| items in items.json (validate_items 'core', must equal) | %d |" % len(items),
           "| live items (minus retired) | %d |" % len(live),
           "| retired items (own section) | %d |" % len(retired)]
    out += ["| gap: %s | %d |" % kv for kv in sorted(gaps.items())]
    out += ["| design names matched / missing | %d / %d |" % (len(covered), len(missing)), ""]

    out += ["## Design needs", "Matched by exact id or alias in data/items/design_names.json.", "",
            "| design name | category | covered by |", "|---|---|---|"]
    out += ["| %s | %s | %s |" % c for c in covered]
    out += ["", "### Missing from the data", "| design name | category |", "|---|---|"]
    out += ["| %s | %s |" % (m[0], m[1]) for m in missing]
    out += [""]

    for kind in sorted({r[0] for r in rows}):
        out += ["## %s" % kind, "| # | item | value | recipes making it | recipes using it | gaps |", "|---|---|---|---|---|---|"]
        out += ["| %d | %s | %s | %d | %d | %s |" % r[1:] for r in sorted(x for x in rows if x[0] == kind)]
        out.append("")

    out += ["## Retired", "Kept so numbers are never reused and old saves still load; not gaps.", "", "| # | item |", "|---|---|"]
    out += ["| %d | %s |" % (i["number"], i["name"]) for i in sorted(retired, key=lambda x: x["number"])]
    sheet_lines, poison_gaps = sheet(dict((i["id"], i) for i in items), recipes)
    out += [""] + sheet_lines
    return "\n".join(out) + "\n", len(live), poison_gaps


def main():
    text, live, poison_gaps = build()
    if poison_gaps:
        print("item_master: poison text disagrees with the harm list: %s" % ", ".join(poison_gaps))
        return 1
    if len(sys.argv) > 1 and sys.argv[1] == "--check":
        if not os.path.exists(MASTER):
            print("item_master: %s not found, nothing to compare (warning only)" % MASTER)
            return 0
        if open(MASTER).read() != text:
            print("item_master: tech/ITEM_MASTER.md is stale; rerun python3 tools/item_master.py %s" % MASTER)
            return 1
        print("item_master: up to date, %d live items" % live)
        return 0
    if len(sys.argv) > 1:
        with open(sys.argv[1], "w") as f:
            f.write(text)
    else:
        sys.stdout.write(text)
    return 0


sys.exit(main())
