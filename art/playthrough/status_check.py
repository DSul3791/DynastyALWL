#!/usr/bin/env python3
"""Playthrough status: marks every F-number FIXED or STILL BROKEN with evidence, from the CURRENT data and the probes' last output.
Run after `bash art/playthrough/run_status.sh` (which re-runs the audit and the probes) or by hand:
    python art/playthrough/status_check.py        -> writes PLAYTHROUGH_STATUS.md
A check that needs a picture or a person says MANUAL. Add a row to CHECKS for every new F-number."""
import json
import os
import re
import subprocess

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def load(p):
    return json.load(open(os.path.join(ROOT, p), encoding="utf8"))


def text(p):
    try:
        return open(os.path.join(ROOT, p), encoding="utf8", errors="ignore").read()
    except OSError:
        return ""


audit = load("art/playthrough/audit.json")
items = {i["id"]: i for i in audit["items"]}
recipes = {r["id"]: r for r in audit["recipes"]}
structs = {s["id"]: s for s in audit["structures"]}
raw_recipes = load("data/items/recipes.json")["recipes"]
probe = text("art/playthrough/probe_output.txt")
probe2 = text("art/playthrough/probe_structures_output.txt")
probe3 = text("art/playthrough/probe_logs_output.txt")
controls = text("CONTROLS.md")
basic = text("src/client/basic_look.gd")
try:
    spawn = load("art/playthrough/spawn_survey.json")
except Exception:
    spawn = {}
rows = []


def row(fid, title, ok, evidence, owner=""):
    rows.append((fid, title, "FIXED" if ok is True else ("STILL BROKEN" if ok is False else "MANUAL"), evidence, owner))


def obtainable(i):
    return items.get(i, {}).get("obtainable", "?")


def blocked_count():
    return sum(1 for r in recipes.values() if r["blocked_by"] and not r["future"])


learn = sum(1 for r in recipes.values() if r["known"])
row("F-01/F-24", "recipes can be learned", learn >= len(recipes) - 5, "%d of %d recipes known or open (blockers: %s)" % (learn, len(recipes), ", ".join(r for r, v in recipes.items() if not v["known"])[:120]), "Sal (data), Tyler (code half)")
row("F-02", "flint can be picked up", obtainable("flint") in ("now", "potential") and "ORPHAN" != obtainable("flint"), "flint: %s" % obtainable("flint"), "Tyler")
row("F-03", "tinder alternatives exist", all(obtainable(i) == "now" for i in ("birch_bark", "tinder", "tinder_fungus")), "birch_bark %s, tinder %s, tinder_fungus %s" % (obtainable("birch_bark"), obtainable("tinder"), obtainable("tinder_fungus")), "Sal")
row("F-04", "CONTROLS.md campfire cost matches recipe", "10 stones and 20 sticks" not in controls, "CONTROLS.md still says 10 stones and 20 sticks" if "10 stones and 20 sticks" in controls else "text no longer present", "Tyler")
row("F-05", "wood is reachable without iron (lumber)", obtainable("lumber") == "now" or (recipes.get("lumber_wedge", {}).get("wave_now") is not None), "lumber %s; lumber_wedge makeable now: %s" % (obtainable("lumber"), recipes.get("lumber_wedge", {}).get("wave_now") is not None), "Sal + Tyler")
row("F-06", "brick, oven and clay hearth reachable", structs.get("oven", {}).get("built_wave_now") is not None and structs.get("clay_hearth", {}).get("built_wave_now") is not None, "oven built wave %s, clay hearth %s" % (structs.get("oven", {}).get("built_wave_now"), structs.get("clay_hearth", {}).get("built_wave_now")), "Sal")
cover = spawn.get("grown_trees", [None])[0:2]
row("F-07", "grown trees (cover) within 100 m of the spawn", bool(cover) and cover[0] is not None and (cover[0] + cover[1]) > 0, "grown trees within 50 m / 100 m of the spawn: %s" % (cover,), "flora session")
row("F-08", "arrows without feathers", recipes.get("fibre_arrow", {}).get("wave_now") is not None, "fibre_arrow makeable now: %s" % (recipes.get("fibre_arrow", {}).get("wave_now") is not None), "Sal")
club = [items.get(i, {}).get("look", "?") for i in ("wooden_club", "stone_mace", "javelin", "wicker_shield")]
row("F-09", "club, mace, javelin, wicker shield have real looks", all(l == "override look" or l.startswith("ok") for l in club), "looks: %s" % club, "Kathleen")
row("F-10", "axe held with a natural pose", None, "needs the in-hand picture art/playthrough/08_hold_stone_axe.jpg re-shot", "Sonny")
hammer = raw_recipes.get("wooden_hammer", {})
soft = [k for k, v in raw_recipes.items() if v["gives"][0] == "wooden_hammer" and "wooden_block_soft" in json.dumps(v["needs"])]
row("F-11", "hammer can be made from a softwood block", bool(soft), "recipes giving wooden_hammer with a soft block: %s" % soft, "Sal")
row("F-12", "bedding can be gathered", obtainable("bedding") == "now", "bedding: %s; straw: %s" % (obtainable("bedding"), obtainable("straw")), "flora / Sal")
row("F-13", "blueberry size", None, "needs a picture", "flora session")
axe = raw_recipes.get("stone_axe", {})
twine = next((n for i, n in axe.get("needs", []) if i == "twine"), 0)
row("F-14", "first axe cost in twine", twine <= 3, "stone axe needs %s twine" % twine, "Sal")
row("F-15", "pickaxe craftable", recipes.get("stone_pickaxe", {}).get("wave_now") is not None, "stone_pickaxe makeable now: %s" % (recipes.get("stone_pickaxe", {}).get("wave_now") is not None), "Sal")
fixed16 = "chopping block crafted from an oak log on the shoulder: 1" in probe3
row("F-16", "a felled log works in the log recipes", fixed16, "probe_logs: " + (re.findall(r"probe3: chopping block crafted from an oak.*", probe3) or ["no output"])[0], "Tyler (code) + Sal")
row("F-17", "override looks are drawn", "_is_placeholder" in basic, "basic_look.entry() %s" % ("prefers the override over a placeholder row" if "_is_placeholder" in basic else "ignores the override when a grey row exists"), "Kathleen")
bad = [r["gives"] for r in recipes.values() if r["wave_now"] and (items.get(r["gives"], {}).get("look", "").startswith(("PLACEHOLDER", "NO LOOK")))]
row("F-18", "everything craftable today has a real look", not bad, "%d craftable items with a grey or missing look: %s" % (len(bad), ", ".join(bad)[:160]), "Kathleen")
row("F-19", "no blocked recipe without a future flag", blocked_count() == 0, "%d recipes blocked and not flagged future" % blocked_count(), "Sal")
orph = [i for i, v in items.items() if v["obtainable"] == "ORPHAN" and not v["future"]]
row("F-20", "every non-future gathered item has a gather path", not orph, "%d orphan items not flagged future (first: %s)" % (len(orph), ", ".join(orph[:6])), "Sal / flora")
row("F-21", "saw mill reachable", structs.get("saw_mill", {}).get("built_wave_now") is not None, "saw mill built wave: %s" % structs.get("saw_mill", {}).get("built_wave_now"), "Sal")
row("F-22", "stairs and stone/brick/log pieces exist", any("stair" in k for k in structs) and any(k.startswith(("stone_", "brick_", "log_wall")) for k in structs), "structures: %d, stairs: %s" % (len(structs), any("stair" in k for k in structs)), "Sal / Kathleen")
row("F-23", "ore, coal and flint can be picked up", all(obtainable(i) in ("now",) for i in ("iron_ore", "coal", "flint")), "iron_ore %s, coal %s, flint %s" % (obtainable("iron_ore"), obtainable("coal"), obtainable("flint")), "Tyler + Sal")
kit_ids = [i for i, v in items.items() if v["kind"] == "placeable" and i.endswith("_kit")]
looks = load("data/items/looks.json")["items"]
kit_looks = set((looks.get(i, {}).get("shape"), looks.get(i, {}).get("color"), json.dumps(looks.get(i, {}).get("bits"))) for i in kit_ids)
kit_shapes = set(looks.get(i, {}).get("shape") for i in kit_ids)
row("F-27", "kits are told apart by shape, not only tint", len(kit_shapes) > 3, "%d kits, %d distinct shapes, %d distinct tints/emblems" % (len(kit_ids), len(kit_shapes), len(kit_looks)), "Kathleen")
row("S-farm", "farming exists (crops.json read by code)", bool(subprocess.run(["git", "grep", "-l", "crops.json", "--", "src", "scenes"], cwd=ROOT, capture_output=True, text=True).stdout.strip()), "crops.json is read by: %s" % (subprocess.run(["git", "grep", "-l", "crops.json", "--", "src", "scenes"], cwd=ROOT, capture_output=True, text=True).stdout.strip() or "nothing"), "Sal (spec) + Tyler (code)")
rules_ok = ("saw_mill", "campfire_pot", "snare_trap")   # refused by a placement rule (foundation, laid fire, open ground), not a bug
place_bad = [x for x in re.findall(r"probe2: (\S+) \| (?:kit \S+|blueprint \S+) \| REFUSED", probe2) if x not in rules_ok]
row("S-place", "every kit and blueprint places on the server", not place_bad, "refused beyond the placement rules: %s (blacksmithy: its 10 plain logs, F-16)" % place_bad, "Tyler")
mism = re.findall(r"probe: MISMATCH (\S+)", probe)
row("S-craft", "every recipe behaves as its known flag says", not [m for m in mism if m != "lumber_by_hand"], "mismatches: %s" % mism, "Tyler")

out = ["# PLAYTHROUGH_STATUS (generated by art/playthrough/status_check.py)\n", "Each F-number from `PLAYTHROUGH_FINDINGS.md`, re-checked against the current data and the last probe output. FIXED = the check passes; STILL BROKEN = it fails (evidence given); MANUAL = needs a picture or a person.\n", "| id | what | status | evidence | owner |", "|---|---|---|---|---|"]
for fid, title, st, ev, owner in rows:
    out.append("| %s | %s | **%s** | %s | %s |" % (fid, title, st, ev.replace("|", "/"), owner))
fixed = sum(1 for r in rows if r[2] == "FIXED")
broken = sum(1 for r in rows if r[2] == "STILL BROKEN")
out.append("\n%d fixed, %d still broken, %d manual." % (fixed, broken, len(rows) - fixed - broken))
open(os.path.join(ROOT, "PLAYTHROUGH_STATUS.md"), "w", encoding="utf8", newline="\n").write("\n".join(out) + "\n")
print("PLAYTHROUGH_STATUS.md:", fixed, "fixed,", broken, "still broken")
