#!/usr/bin/env python3
"""Dave's rulings as plain-number checks on the game's data (docs/RULINGS.md). No Godot: runs in merge_check.

Each check names its R- key. GODOT lists the Godot tests that guard rulings these checks cannot read from data;
the check fails if one of those test files is gone. A failing check is a found bug: fix the game, or replace the
ruling by its procedure. Never loosen a check to make it pass. KNOWN_OPEN holds found bugs not fixed yet: they print
as OPEN and do not fail the merge; take a key out once its fix is in.
    python3 tools/check_dave_rules.py
"""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
KNOWN_OPEN = {
    "R-HUNT-GLOW": "found 25 Nov 2026: the sign halo starts at Tracking 10, the ruling says 25; fix in the next PR",
}
GODOT = {   # rulings checked by behaviour, not data: the test that guards each
    "R-ANIMAL-BEAR": ["test_bear_threat"],
    "R-ANIMAL-FIRE": ["test_big_game", "test_wolf_pups"],
    "R-CORE-NO-DEATH": ["test_death"],
    "R-CORE-COLD": ["test_cold_pass_out"],
    "R-HUD-STATUS": ["test_status_strip"],
    "R-CTRL-E-CLOSEST": ["test_e_priority"],
    "R-CRAFT-KEPT-TOOL": ["test_server_items"],
    "R-HUNT-SNARE-CATCH": ["test_traps", "test_trap_collect_prompt"],
    "R-SLEEP-NIGHT-SKIP": ["test_night_skip"],
    "R-WATER-SEA": ["test_drinking_water"],
}

results = []   # (key, ok, what)


def data(rel):
    return json.loads((ROOT / rel).read_text(encoding="utf-8"))


def check(key, ok, what):
    results.append((key, bool(ok), what))


def player_run_mps():
    src = (ROOT / "scenes/terrain_client/terrain_client.gd").read_text(encoding="utf-8")
    return float(re.search(r"^const RUN_SPEED := ([0-9.]+)", src, re.M).group(1))


def bears(run):
    species = data("data/animals/animals.json")["species"]
    for sid in ("bear", "black_bear"):
        b = species[sid]
        flee = float(b["flee_mps"])
        lope = flee * float(b.get("trot_share", 0.5))
        check("R-ANIMAL-BEAR", flee > run, f"{sid} flees at {flee} m/s, faster than the player's {run} m/s run")
        check("R-ANIMAL-BEAR", lope > run, f"{sid} lopes at {lope:.1f} m/s after its burst, still faster than {run} m/s")
        check("R-ANIMAL-BEAR", b.get("defend", {}).get("trapped_fights") is True, f"{sid} fights when trapped or chased down")


def status_strip():
    rows = {r["id"]: r for r in data("data/ui/status_strip.json")["symbols"]}
    for rid in ("hunger", "thirst"):
        check("R-HUD-STATUS", rows[rid].get("show_below") == 10, f"{rid} shows only below 10% (show_below {rows[rid].get('show_below')})")
    comfort = [r for r in rows.values() if "comfort" in r["id"]]
    check("R-HUD-STATUS", comfort and all(r.get("always") for r in comfort), "comfort is always shown")


def tracking():
    signs = data("data/look/trail_signs.json")
    check("R-HUNT-GLOW", int(signs["halo_from"]) == 25, f"sign glow starts at Tracking 25 (halo_from {signs['halo_from']})")
    check("R-HUNT-TRAILS-MAP", int(data("data/map.json")["trails_tracking"]) == 10, "game trails go on the map at Tracking 10")


def seeds():
    items = data("data/items/items.json")["items"]
    by_id = data("data/items/weights.json")["by_id"]
    for iid, it in items.items():
        if re.search(r"_seeds?$", iid):
            check("R-ITEM-WEIGHTS", iid in by_id, f"{iid} has its own real-world weight (not the default)")


def names_and_storage():
    items = data("data/items/items.json")["items"]
    check("R-NAME-FIBRE-BACKPACK", any(it["name"] == "Fibre - Backpack" for it in items.values()), "an item is named Fibre - Backpack")
    pieces = data("data/items/structures.json")
    chests = {}

    def walk(x, key=""):
        if isinstance(x, dict):
            if "chest" in key and isinstance(x.get("slots"), int):
                chests[key] = x["slots"]
            for k, v in x.items():
                walk(v, k)

    walk(pieces)
    for cid, slots in chests.items():
        check("R-STORE", slots % 6 == 0, f"{cid} holds whole rows of 6 ({slots} slots)")


def godot_guards():
    rulings = (ROOT / "docs/RULINGS.md").read_text(encoding="utf-8")
    for key, tests in GODOT.items():
        check(key, f"**{key}**" in rulings, f"{key} is a live ruling")
        for t in tests:
            check(key, (ROOT / f"src/worldgen/tools/{t}.gd").is_file(), f"guarded by {t}")


def main():
    run = player_run_mps()
    for step in (lambda: bears(run), status_strip, tracking, seeds, names_and_storage, godot_guards):
        step()
    rulings = (ROOT / "docs/RULINGS.md").read_text(encoding="utf-8")
    for key in {k for k, _, _ in results} | set(KNOWN_OPEN):
        check(key, f"**{key}**" in rulings, f"{key} is in docs/RULINGS.md")
    failed = 0
    for key, ok, what in results:
        if ok:
            continue
        if key in KNOWN_OPEN:
            print(f"OPEN {key}: {what} [{KNOWN_OPEN[key]}]")
        else:
            failed += 1
            print(f"FAIL {key}: {what}")
    passed = sum(1 for _, ok, _ in results if ok)
    print(f"dave rules: {passed} pass, {failed} fail, {sum(1 for k, ok, _ in results if not ok and k in KNOWN_OPEN)} open")
    for key in KNOWN_OPEN:
        if all(ok for k, ok, _ in results if k == key):
            failed += 1
            print(f"FAIL {key} now passes: take it out of KNOWN_OPEN")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
