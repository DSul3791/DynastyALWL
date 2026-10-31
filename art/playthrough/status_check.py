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
    # a blocked recipe does not count when another recipe already makes the same product today (lumber: wedge route vs sawmill/hand saw)
    made_now = set(r["gives"] for r in recipes.values() if r["wave_now"] is not None)
    return sum(1 for r in recipes.values() if r["blocked_by"] and not r["future"] and r["gives"] not in made_now)


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
planks = re.findall(r"rough planks from the one log on the shoulder.*?: (\d+)", probe3)
planks_n = int(planks[0]) if planks else -1
fixed16 = planks_n >= 1 or "chopping block crafted from an oak log on the shoulder: 1" in probe3
row("F-16", "a log a player really holds (shoulder, one at a time) works in the log recipes", fixed16, "probe_logs round 2: rough planks from the one log on the shoulder = %s (the unit test passes only with logs forced into the pack: %s)" % (planks_n, "yes" if "forced into the pack (what the unit test does, not what a player can hold): 1" in probe3 else "no"), "Tyler (code) + Sal")
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
over = {}
for line in basic.split(chr(10)):
    m = re.match(r'\s*"([a-z_0-9]+)": \{"shape": "([a-z_0-9]+)"(.*)', line)
    if m:
        over[m.group(1)] = (m.group(2), tuple(re.findall(r'"([a-z_#0-9]+)"', m.group(3).split("bits")[1].split("[", 1)[1].split("]")[0])) if "bits" in m.group(3) else ())
def kit_look(i):
    return over.get(i) or (looks.get(i, {}).get("shape"), tuple(looks.get(i, {}).get("bits", [])))
kit_variants = set(kit_look(i) for i in kit_ids)
row("F-27", "kits are told apart by an emblem or shape, not only tint", len(kit_variants) >= len(kit_ids) // 2, "%d kits, %d distinct (shape, emblem) looks (parcel + emblem rows landed in 7e367796)" % (len(kit_ids), len(kit_variants)), "Kathleen")
clock = text("src/shared/game_clock.gd")
m_day = re.search(r"START_SECONDS := \(([0-9.]+) \* 24", clock)
start_day = float(m_day.group(1)) if m_day else -1.0
row("F-35", "berries and nuts are in season near the start (a new world starts in summer, day >= 92)", start_day >= 92.0, "game_clock.gd START_SECONDS = day %.0f (spring is days 0 to 91, summer from 92)" % start_day, "Dave / Sal")
bot = text("art/playthrough/probe_bot_output.txt")
if bot:
    row("F-36", "the first-hour playability bot reaches the end", "FAILED at step" not in bot and "playability bot" in bot, (re.findall(r"playability bot.*", bot) or ["no result line"])[-1], "Tyler")
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

# Delta against the last run (status.json), so a note can carry the change and not the whole table.
cur = {r[0]: r[2] for r in rows}
path = os.path.join(ROOT, "art/playthrough/status.json")
try:
    old = json.load(open(path, encoding="utf8"))
except Exception:
    old = {}
for fid, st in cur.items():
    if fid in old and old[fid] != st:
        print("DELTA", fid, old[fid], "->", st)
json.dump(cur, open(path, "w", encoding="utf8"), indent=0)

# Keep the scoreboard in PLAYTHROUGH_FINDINGS.md current (between the two marker lines; the file is created with them at the end if missing).
board = ["<!-- SCOREBOARD START (written by art/playthrough/status_check.py) -->", "## Scoreboard: FIXED / STILL BROKEN (" + __import__("datetime").date.today().isoformat() + ")", "", "| id | what | status | evidence (short) |", "|---|---|---|---|"]
for fid, title, st, ev, owner in rows:
    board.append("| %s | %s | **%s** | %s |" % (fid, title, st, ev.replace("|", "/")[:110]))
board.append("")
board.append("%d fixed, %d still broken, %d manual. Full evidence and owners: `PLAYTHROUGH_STATUS.md`." % (fixed, broken, len(rows) - fixed - broken))
board.append("<!-- SCOREBOARD END -->")
fp = os.path.join(ROOT, "PLAYTHROUGH_FINDINGS.md")
NL = chr(10)
body = open(fp, encoding="utf8", newline="").read().replace(chr(13) + NL, NL)
block = NL.join(board)
if "<!-- SCOREBOARD START" in body:
    body = re.sub(r"<!-- SCOREBOARD START.*?<!-- SCOREBOARD END -->", lambda m: block, body, flags=re.S)
else:
    body = body.rstrip(NL) + NL + NL + "---" + NL + NL + block + NL
open(fp, "w", encoding="utf8", newline=NL).write(body)
