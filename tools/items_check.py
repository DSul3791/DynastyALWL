#!/usr/bin/env python3
"""Headless regression check for items, crafting, fire, chests, hunger and exertion.

Run: python3 tools/items_check.py [--only NAME[,NAME]] [--godot PATH] [--list] [--verbose]

Two kinds of step. UNIT steps run a headless GDScript test from src/worldgen/tools and need its last
line to report 0 failures (tool gating, wear and repair, chest put/take, placement caps, felling to
firewood, save and reload, hunger, carrying, exertion, stance). CLIENT steps start a fresh server (own
port and store), run the client headless with the step's test flag and check the lines it prints.
Exit status 1 when anything fails. Needs the Godot binary (default /root/bin/godot, or $GODOT).
To add a step: add a row to UNITS or CLIENTS. A client check is (label, regex with ONE capture group,
min, max); the group is read as a number, or use a regex that simply must match (min=max=None).
"""
import os
import re
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", "/root/bin/godot")
PORT_BASE = 7950
NUM = r"(-?\d+(?:\.\d+)?)"

UNITS = [
    ("validate_items", "src/worldgen/tools/validate_items.gd"),
    ("inventory", "src/worldgen/tools/test_inventory.gd"),
    ("server_items", "src/worldgen/tools/test_server_items.gd"),
    ("death", "src/worldgen/tools/test_death.gd"),
    ("stations", "src/worldgen/tools/test_stations.gd"),
    ("fishing", "src/worldgen/tools/test_fishing.gd"),
    ("spoilage", "src/worldgen/tools/test_spoilage.gd"),
    ("warmth", "src/worldgen/tools/test_warmth.gd"),
    ("skills", "src/worldgen/tools/test_skills.gd"),
    ("sickness", "src/worldgen/tools/test_sickness.gd"),
    ("persistence", "src/worldgen/tools/test_items_persistence.gd"),
    ("drills", "src/worldgen/tools/test_persistence_drills.gd"),
    ("npcs", "src/worldgen/tools/test_npcs.gd"),
    ("npc view", "src/worldgen/tools/test_npc_view.gd"),
    ("faint smooth", "src/worldgen/tools/test_faint_smooth.gd"),
    ("placed clearing", "src/worldgen/tools/test_placed_clearing.gd"),
    ("dialogue", "src/worldgen/tools/test_dialogue.gd"),
    ("animals", "src/worldgen/tools/test_animals.gd"),
    ("animal_senses", "src/worldgen/tools/test_animal_senses.gd"),
    ("wolves", "src/worldgen/tools/test_wolves.gd"),
    ("big_game", "src/worldgen/tools/test_big_game.gd"),
    ("thieves", "src/worldgen/tools/test_thieves.gd"),
    ("trade", "src/worldgen/tools/test_trade.gd"),
    ("flocks", "src/worldgen/tools/test_flocks.gd"),
    ("ai_contract", "src/worldgen/tools/test_ai_contract.gd"),
    ("block_roundtrip", "src/worldgen/tools/test_block_roundtrip.gd"),
    ("forge_models", "src/worldgen/tools/test_forge_models.gd"),
    ("soak", "src/worldgen/tools/soak_server.gd"),
    ("new_player_day", "src/worldgen/tools/test_new_player_day.gd"),
    ("placement_rules", "src/worldgen/tools/test_placement_rules.gd"),
    ("save_compat", "src/worldgen/tools/test_save_compat.gd"),
    ("first_hour", "src/worldgen/tools/test_first_hour.gd"),
]

# name, client flags, frames, checks
CLIENTS = [
    ("chest", ["--chest"], 3500, [
        ("chest screen opens", r"screen open (true)", None, None),
        ("stones taken out", r"after taking out, stones in chest \d+, in pack " + NUM, 10, 10),
    ]),
    ("gather", ["--gather"], 12000, [
        ("harvest prompt shown", r"prompt \"(Press E to gather)\"", None, None),
        ("sticks gathered", r"sticks 0 -> " + NUM, 1, 100),
        ("prompt only for what you look toward", r"Hold test: looking east, stone to the east in view (true), stone to the west in view false, prompt \"Press E to gather\"", None, None),
        ("held E takes one item per step", r"Hold test: most in one step " + NUM, 1, 1),
        ("held E gets all four stones", r"Hold test: most in one step \d+, total " + NUM, 3, 12),
        ("held E stops when nothing is in reach", r"last two steps " + NUM, 0, 0),
        ("stones use the real meshes", r"Natural look: stone uses " + NUM + " real meshes", 6, 6),
        ("stones stand out (1 m and up, three times the old size)", r"Natural size: stone lies " + NUM + " to", 0.9, 1.8),
        ("sticks stand out (1.8 m and up, 75 percent of the old size, Dave 2026-10-21)", r"Natural size: stick lies " + NUM + " to", 1.6, 3.8),
        ("sticks use the real meshes", r"Natural look: stick uses " + NUM + " real meshes", 3, 3),
        ("driftwood uses the real meshes", r"Natural look: driftwood uses " + NUM + " real meshes", 3, 3),
    ]),
    ("arrival", ["--arrival"], 2600, [
        ("ground appears and the body is set down", r"Arrival test: ground found (true)", None, None),
        ("set down within a metre of the ground", r"set down " + NUM + " m above it", 0.0, 1.5),
        ("arriving does not hurt", r"health " + NUM + r", strain state", 100, 100),
        ("and does not faint", r"strain state " + NUM, 0, 0),
    ]),
    ("strainrun", ["--walk", "--runspeed=24", "--strainrun"], 9000, [
        ("the body really ran", r"Strain test: ran " + NUM + " m", 150, 650),
        ("running raises the strain the server sends", r"strain [\d.]+ -> " + NUM, 0.08, 3.0),
        ("normal pace is full speed, no cap", r"0: pace x1.0 cap 0.0 \|", None, None),
        ("over-exerted is 10 percent slower, not capped", r"1: pace x0.9 cap 0.0 \|", None, None),
        ("fainted locks movement", r"2: pace x1.0 cap -1.0", None, None),
    ]),
    ("plantpick", ["--plantpick"], 6000, [
        ("plants were picked", r"tried (\d+), gone", 3, 20),
        ("none left standing", r"still standing (\d+)", 0, 0),
    ]),
    ("leanto", ["--leanto"], 4000, [
        ("roof gives cover", r"cover under it " + NUM, 0.9, 1.0),
    ]),
    ("texttest", ["--texttest"], 3000, [
        ("slot buttons stay valid", r"all valid (true)", None, None),
        ("every item still shown", r"every item shown (true)", None, None),
        ("window size never changes", r"window sizes seen " + NUM, 1, 1),
        ("contents fit the window", r"contents fit (true)", None, None),
        ("fonts at least 24 px at 1080", r"Audit: smallest font " + NUM + " px", 24, 200),
        ("tooltips at least 24 px", r"tooltip font " + NUM + " px", 24, 200),
        ("six sort options", r"sort options " + NUM + ",", 6, 6),
        ("action buttons carry their keys", r"key buttons missing (\[\])", None, None),
        ("six bars at the top of the inventory screen (health, exertion, energy, food, water, warmth)", r"panel bars " + NUM, 6, 6),
        ("no bars on the main screen", r"main-screen bars " + NUM, 0, 0),
        ("Tab opens the character screen", r"Character screen: open (true)", None, None),
        ("character screen: six bars", r"bars " + NUM + r", luck row", 6, 6),
        ("character screen: luck and skills listed", r"luck row (true), skills section (true)", None, None),
        ("character screen fonts at least 24 px", r"Character screen: .*smallest font " + NUM + " px", 24, 200),
        ("carry bar on the inventory screen", r"carry bar (true)", None, None),
        ("character screen: heart beats at a rate", r"heart label '(\d+ bpm)'", None, None),
        ("30 slot buttons", r"scale [\d.]+, " + NUM + r" slot buttons", 30, 30),
    ]),
    ("quickkeys", ["--quickkeys"], 3500, [
        ("S splits the stack", r"stacks of stone 1 -> " + NUM, 2, 2),
        ("Shift+D drops one", r"Shift\+D dropped one, stones \d+ -> " + NUM, 5, 5),
        ("E eats", r"E ate, roasts \d+ -> " + NUM, 1, 1),
    ]),
    ("eat", ["--eat"], 7000, [
        ("food is edible", r"edible slot 0 (true)", None, None),
        ("roast eaten", r"roasts left " + NUM, 1, 1),
        ("craft queue shows the entry", r"Queue test: entries 1, fibre \d+ -> \d+, buttons shown " + NUM, 1, 1),
        ("cancel empties the queue and refunds", r"after cancel entries " + NUM + r", fibre", 0, 0),
        ("queue strip hides again", r"queue strip hidden (true)", None, None),
        ("Use holds a tool", r"matches (true)\), strip boxes 10", None, None),
        ("the axe is drawn in the arms' hand", r"Arms test: axe model in the right hand (true), arms shown true", None, None),
        ("every tool and weapon can be held and has a model", r"Tools test: (\d+) tools and weapons, held \1, with a model \1", None, None),
        ("a boulder is drawn full size", r"Boulder test: radius " + NUM + ",", 0.99, 1.01),
        ("and shrinks to the cube root of what is left (an eighth: half)", r"at an eighth of the stones " + NUM + ",", 0.49, 0.51),
        ("a strike finds it and a ray hits it", r"found by a strike true, solid to a ray true", None, None),
        ("and it goes when the server drops it", r"gone when the server drops it true", None, None),
        ("Use again puts it away", r"Use again, hand slot " + NUM, -1, -1),
        ("a tool deep in the pack moves to the hotbar and is held", r"Use moved it to slot \d+ and holds it \((true)\), on hotbar true", None, None),
    ]),
]


def run_unit(name, path, godot, verbose):
    out = subprocess.run([godot, "--headless", "--path", ROOT, "-s", "res://" + path], capture_output=True, text=True, timeout=600).stdout
    if verbose:
        print(out)
    for line in out.splitlines():
        if "FAIL" in line:
            print("   ", line)
    found = re.findall(r"(\d+) (?:failures|errors)", out)
    return bool(found) and all(n == "0" for n in found), "%s failures or errors" % (found[-1] if found else "no result")


def run_client(index, flags, frames, checks, godot, verbose):
    port = PORT_BASE + index
    store = tempfile.mkdtemp(prefix="items_check_")
    server = subprocess.Popen([godot, "--headless", "--path", ROOT, "res://scenes/terrain_server/terrain_server.tscn", "--", "--port=%d" % port, "--store=" + store], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        time.sleep(40)
        out = subprocess.run([godot, "--headless", "--path", ROOT, "res://scenes/terrain_client/terrain_client.tscn", "--", "--server=127.0.0.1", "--port=%d" % port, "--frames=%d" % frames] + flags, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=400).stdout
    finally:
        server.kill()
    if verbose:
        print(out)
    if "SCRIPT ERROR" in out:
        print("    script error in the client output")
        return False, "script error"
    problems = []
    for label, pattern, low, high in checks:
        matches = list(re.finditer(pattern, out, re.M))
        match = matches[-1] if matches else None
        if not match:
            problems.append(label + ": no match")
        elif low is not None:
            value = float(match.group(1))
            if not (low <= value <= high):
                problems.append("%s: %s outside %s..%s" % (label, value, low, high))
    return not problems, "; ".join(problems) or "ok"


def main():
    args = sys.argv[1:]
    godot = GODOT
    only = None
    verbose = "--verbose" in args
    if "--godot" in args:
        godot = args[args.index("--godot") + 1]
    if "--only" in args:
        only = set(args[args.index("--only") + 1].split(","))
    if "--list" in args:
        print("\n".join([n for n, _ in UNITS] + [c[0] for c in CLIENTS]))
        return 0
    # A fresh checkout has no class cache, so the client scene fails to parse and the run hangs until it times out.
    if not os.path.exists(os.path.join(ROOT, ".godot", "global_script_class_cache.cfg")):
        subprocess.run([godot, "--headless", "--path", ROOT, "--import"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=300)
    failed = 0
    if not only or "luck" in only:
        luck = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "check_luck.py")], capture_output=True, text=True)
        print("%-16s %s  %s" % ("luck_rolls", "PASS" if luck.returncode == 0 else "FAIL", luck.stdout.strip().splitlines()[-1]))
        if luck.returncode != 0:
            print(luck.stdout)
        failed += 1 if luck.returncode else 0
    for name, path in UNITS:
        if only and name not in only:
            continue
        ok, note = run_unit(name, path, godot, verbose)
        print("%-16s %s  %s" % (name, "PASS" if ok else "FAIL", note))
        failed += 0 if ok else 1
    for index, (name, flags, frames, checks) in enumerate(CLIENTS):
        if only and name not in only:
            continue
        ok, note = run_client(index, flags, frames, checks, godot, verbose)
        print("%-16s %s  %s" % (name, "PASS" if ok else "FAIL", note))
        failed += 0 if ok else 1
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
