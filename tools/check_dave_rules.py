#!/usr/bin/env python3
"""Dave's rulings as plain-number checks on the game's data (docs/RULINGS.md). No Godot: runs in merge_check.

Each check names its R- key. GODOT lists the Godot tests that guard rulings these checks cannot read from data;
the check fails if one of those test files is gone. A check on a ruling marked unverified only warns. A failing check is a found bug: fix the game, or replace the
ruling by its procedure. Never loosen a check to make it pass. KNOWN_OPEN holds found bugs not fixed yet: they print
as OPEN and do not fail the merge; take a key out once its fix is in.
    python3 tools/check_dave_rules.py
"""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
KNOWN_OPEN = {}
GODOT = {   # rulings checked by behaviour, not data: the test that guards each
    "R-ANIMAL-BEAR": ["test_bear_threat"],
    "R-ANIMAL-FIRE": ["test_big_game", "test_wolf_pups"],
    "R-CORE-NO-DEATH": ["test_death"],
    "R-CORE-COLD": ["test_cold_pass_out"],
    "R-HUD-STATUS": ["test_status_strip"],
    "R-CTRL-E-CLOSEST": ["test_e_priority"],
    "R-CRAFT-KEPT-TOOL": ["test_server_items"],
    "R-HUNT-SNARE-CATCH": ["test_traps", "test_trap_collect_prompt"],
    "R-HUNT-DEAD-NAME": ["test_carcass_look", "test_trap_collect_prompt"],
    "R-SLEEP-NIGHT-SKIP": ["test_night_skip"],
    "R-WATER-SEA": ["test_drinking_water"],
    "R-JOIN-PASSWORD-ONCE": ["test_server_auth"],
    "R-SOUND-MENU-MUSIC": ["test_title_music"],
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
        lope = max(flee * float(b.get("trot_share", 0.5)), float(b.get("lope_mps", 0.0)))   # as server_animals.gd after the burst
        check("R-ANIMAL-BEAR", flee > run, f"{sid} flees at {flee} m/s, faster than the player's {run} m/s run")
        check("R-ANIMAL-BEAR", lope > run, f"{sid} lopes at {lope:.1f} m/s after its burst, still faster than {run} m/s (\"out run me\")")
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
    found = [iid for iid in items if re.search(r"_seeds?$", iid)]
    check("R-ITEM-WEIGHTS", len(found) > 50, f"the seed items are found ({len(found)})")
    for iid in found:
        check("R-ITEM-WEIGHTS", iid in by_id, f"{iid} has its own real-world weight (not the default)")
        check("R-ITEM-WEIGHTS", float(by_id.get(iid, 0.0)) <= 1.0, f"{iid} weighs no more than a coconut ({by_id.get(iid)} kg)")


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
    check("R-STORE", len(chests) >= 4, f"the chests are found ({len(chests)})")
    for cid, slots in chests.items():
        check("R-STORE", slots % 6 == 0, f"{cid} holds whole rows of 6 ({slots} slots)")


def godot_guards():
    rulings = (ROOT / "docs/RULINGS.md").read_text(encoding="utf-8")
    for key, tests in GODOT.items():
        check(key, f"**{key}**" in rulings, f"{key} is a live ruling")
        for t in tests:
            check(key, (ROOT / f"src/worldgen/tools/{t}.gd").is_file(), f"guarded by {t}")


def e_prompts():
    """R-HUD-PROMPTS: every E action the client offers (an interactable's {"tap": ...}) carries a "prompt", and a written prompt names its key (E,
    or F for the F-key actions); a tap that only tells the player what to do instead (show_notice) is not an E action."""
    files = [p for p in list((ROOT / "src").rglob("*.gd")) + list((ROOT / "scenes").rglob("*.gd")) if "worldgen/tools" not in p.as_posix()]
    taps = 0
    for path in files:
        for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for m in re.finditer(r'\{[^{}]*"tap"\s*:', line):
                taps += 1
                seg = line[m.start():]
                where = f"{path.relative_to(ROOT).as_posix()}:{n}"
                if '"prompt"' not in seg:
                    check("R-HUD-PROMPTS", False, f"{where}: an E action with no prompt")
                    continue
                text = re.search(r'"prompt"\s*:\s*(?:\(\s*)?"((?:[^"\\]|\\.)*)"', seg)
                if text and "show_notice" not in seg and not re.search(r"\b[EF]\b", text.group(1)):
                    check("R-HUD-PROMPTS", False, f"{where}: the prompt \"{text.group(1)}\" does not say which key")
    check("R-HUD-PROMPTS", taps >= 20, f"the E actions were found ({taps})")


def witness_glow():
    """R-FLORA-WITNESS-GLOW: only the violet veins of the witness tree's leaves glow; the canopy does not, and the tree sends no light."""
    rows = data("data/tables/flora.json")
    rows = rows.get("species", rows.get("entries")) if isinstance(rows, dict) else rows
    tree = next(e for e in rows if e.get("name") == "witness_tree")
    check("R-FLORA-WITNESS-GLOW", tree.get("leaf_glow") is True, "the witness tree's leaves glow at night (leaf_glow)")
    check("R-FLORA-WITNESS-GLOW", "glow" not in tree and "glow_energy" not in tree, "the witness tree sends no light of its own (no glow colour or energy: a light in the crown lit the whole canopy violet)")
    src = (ROOT / "src/flora/flora_view.gd").read_text(encoding="utf-8")
    foliage = src[src.index("const FOLIAGE_SHADER"):src.index("const BARK_SHADER")]
    emission = re.findall(r"^\s*EMISSION = (.+);", foliage, re.M)
    check("R-FLORA-WITNESS-GLOW", len(emission) == 1 and "* vein_mask" in emission[0] and "glow_energy" in emission[0], f"the leaf glow is masked to the veins (EMISSION = {emission})")
    check("R-FLORA-WITNESS-GLOW", re.search(r"uniform float glow_energy = 0\.0;", foliage), "every other species has no leaf glow (glow_energy 0 unless set)")
    check("R-FLORA-WITNESS-GLOW", 'set_shader_parameter("veins", _load_texture("res://assets/trees/leaf_witness_veins.png"))' in src, "the witness leaves get their vein mask")
    night = float(re.search(r"^const WITNESS_GLOW_NIGHT := ([0-9.]+)", src, re.M).group(1))
    day = float(re.search(r"^const WITNESS_GLOW_DAY := ([0-9.]+)", src, re.M).group(1))
    check("R-FLORA-WITNESS-GLOW", 0.0 < day <= 0.1 * night, f"the veins are barely seen by day ({day}) and glow at night ({night})")
    check("R-FLORA-WITNESS-GLOW", "set_shader_parameter(\"glow_energy\", lerpf(WITNESS_GLOW_NIGHT, WITNESS_GLOW_DAY" in src, "the vein glow follows the daylight")
    check("R-FLORA-WITNESS-GLOW", re.search(r"^\s*float vein_mask = texture\(veins, UV\)\.r;", foliage, re.M) and "uniform sampler2D veins : hint_default_black" in foliage,
          "the mask is the painted vein texture, black (no glow) where none is set")
    for f in ("leaf_witness_veins.png", "leaf_witness_veins.png.import"):
        check("R-FLORA-WITNESS-GLOW", (ROOT / "assets/trees" / f).is_file() and (ROOT / "assets/trees" / f).stat().st_size > 1000 if f.endswith(".png") else (ROOT / "assets/trees" / f).is_file(), f"the witness leaf's vein mask is there ({f})")


def dead_names():
    """R-HUNT-DEAD-NAME: every animal kind has a name for its body ("Dead " + name, carcass_look.gd dead_name), so none falls back to "Dead animal"
    or a bare "Carcass"; the duck's flock name ("Ducks") has its one-animal name."""
    species = data("data/animals/animals.json")["species"]
    for sid, row in species.items():
        one = str(row.get("one", row.get("name", "")))
        check("R-HUNT-DEAD-NAME", one != "" and "carcass" not in one.lower(), f"{sid} has a name for its body ({one!r})")
    check("R-HUNT-DEAD-NAME", species["duck"].get("one") == "Duck", "a dead duck is one duck, not \"Dead ducks\"")
    check("R-HUNT-DEAD-NAME", len(species) >= 40, f"the species were read ({len(species)})")


def ruling_lines():
    out = {}
    for line in (ROOT / "docs/RULINGS.md").read_text(encoding="utf-8").splitlines():
        m = re.match(r"^- \*\*(R-[A-Z0-9-]+)\*\*", line)
        if m:
            out[m.group(1)] = line
    return out


def main():
    steps = {"R-ANIMAL-BEAR": lambda: bears(player_run_mps()), "R-HUD-STATUS": status_strip, "R-HUNT-TRAILS-MAP": tracking, "R-ITEM-WEIGHTS": seeds,
             "R-STORE": names_and_storage, "R-CORE-NEWER-WINS": godot_guards, "R-HUD-PROMPTS": e_prompts,
             "R-FLORA-WITNESS-GLOW": witness_glow, "R-HUNT-DEAD-NAME": dead_names}
    for key, step in steps.items():
        try:
            step()
        except (KeyError, TypeError, ValueError, AttributeError, OSError, StopIteration) as e:   # a row or key the check reads is gone: a failure, not a crash
            check(key, False, f"the data this check reads is missing or changed shape ({type(e).__name__}: {e})")
    rulings = ruling_lines()
    for key in {k for k, _, _ in results}:
        check(key, key in rulings, f"{key} is in docs/RULINGS.md")
    failed = 0
    for key in KNOWN_OPEN:
        if key not in rulings:
            failed += 1
            print(f"FAIL {key} is in KNOWN_OPEN but not in docs/RULINGS.md: settle it, then take it out")
    for key, ok, what in results:
        if ok:
            continue
        if "unverified" in rulings.get(key, ""):
            print(f"WARN {key}: {what} [the ruling is marked unverified: tell the coordinator, do not block]")
        elif key in KNOWN_OPEN:
            print(f"OPEN {key}: {what} [{KNOWN_OPEN[key]}]")
        else:
            failed += 1
            print(f"FAIL {key}: {what}")
    passed = sum(1 for _, ok, _ in results if ok)
    print(f"dave rules: {passed} pass, {failed} fail, {sum(1 for k, ok, _ in results if not ok and k in KNOWN_OPEN)} open (FAIL blocks a merge; OPEN and WARN do not)")
    for key in KNOWN_OPEN:
        if all(ok for k, ok, _ in results if k == key):
            failed += 1
            print(f"FAIL {key} now passes: take it out of KNOWN_OPEN")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
