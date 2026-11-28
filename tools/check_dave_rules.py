#!/usr/bin/env python3
"""Dave's rulings as plain-number checks on the game's data (docs/RULINGS.md). No Godot: runs in merge_check.

Each check names its R- key. GODOT lists the Godot tests that guard rulings these checks cannot read from data;
the check fails if one of those test files is gone. A check on a ruling marked unverified only warns; a check on a suggestion only
prints a NOTE (Dave 26 Nov 2026, R-CORE-RULES-VS-SUGGESTIONS: only his explicit rules block; play-testing may show a suggestion wrong,
then the game follows play-testing and the line is changed by its procedure). Rule and unclear lines block. A failing check is a found bug: fix the game, or replace the
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
    "R-HUD-INSPECT-PLUS": ["test_inspect_reticle"],
    "R-HUD-JOURNAL-BOOK": ["test_goal_ui"],
    "R-HUD-HINT-BOX": ["test_hint_card"],
    "R-CTRL-E-CLOSEST": ["test_e_priority"],
    "R-CRAFT-KEPT-TOOL": ["test_server_items"],
    "R-CRAFT-SMALL-BY-HAND": ["test_campfire_both"],
    "R-HUNT-SNARE-CATCH": ["test_traps", "test_trap_collect_prompt"],
    "R-PLAYER-CRAWL": ["test_crawl", "test_crawl_server", "test_animal_senses", "test_remote_players"],
    "R-HUNT-DEAD-NAME": ["test_carcass_look", "test_trap_collect_prompt"],
    "R-ANIMAL-SEEN-FAR": ["test_animals"],
    "R-SLEEP-NIGHT-SKIP": ["test_night_skip"],
    "R-WATER-SEA": ["test_drinking_water"],
    "R-JOIN-PASSWORD-ONCE": ["test_server_auth"],
    "R-SOUND-MENU-MUSIC": ["test_title_music"],
    "R-MOVE-RUN-FEET": ["test_run_speed"],
    "R-RES-BOULDER-PHYSICS": ["test_boulder_fall", "test_rock_fields"],
    "R-RES-BOULDER-HARM": ["test_boulder_fall"],
    "R-ANIMAL-ALLIGATOR": ["test_tail_drag"],
    "R-HUD-INVENTORY-WORN": ["test_you_column"],
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


def sign_sound():
    """R-HUNT-SIGN-SOUND: the sign spot sound is much quieter and plays only with a hunting weapon, snare or trap in hand."""
    signs = data("data/look/trail_signs.json")
    slots = data("data/sound/batch3_slots.json")
    slot = slots.get("slots", slots)["sign_spot"]
    items = set()
    todo = [data("data/items/items.json")]
    while todo:   # every item row, at any depth (weapons sit in their own section)
        node = todo.pop()
        for k, v in node.items():
            if isinstance(v, dict):
                if "name" in v:
                    items.add(k)
                todo.append(v)
    gear = signs["sound_with"]
    check("R-HUNT-SIGN-SOUND", float(slot.get("play_db", 0.0)) <= -10.0, f"the sign sound plays at least 10 dB under its file (play_db {slot.get('play_db')})")
    check("R-HUNT-SIGN-SOUND", all(g in items for g in gear) and {"wooden_spear", "wooden_bow", "snare"} <= set(gear), f"sound_with names real hunting weapons, snares and traps ({len(gear)})")
    check("R-HUNT-SIGN-SOUND", not any(g in gear for g in ("fishing_spear", "fish_trap", "stone_axe", "torch")), "a fishing spear, fish trap, axe or torch does not sound signs")
    client = (ROOT / "scenes/terrain_client/terrain_client.gd").read_text(encoding="utf-8")
    on_spot = client[client.index("trail_signs.on_spot = func"):][:600]
    check("R-HUNT-SIGN-SOUND", "TrailSignsScript.sounds_with(trail_signs.cfg" in on_spot and on_spot.index("sounds_with") < on_spot.index('play("sign_spot"'), "the spot sound asks what is in hand first")


def pass_out():
    """R-CORE-PASS-OUT: passing out takes the body at once; a faint wakes calm."""
    ex = data("data/items/exertion.json")
    check("R-CORE-PASS-OUT", float(ex["blackout"]["fall_s"]) <= 3.0, f"passing out reaches full black within 3 s ({ex['blackout']['fall_s']} s)")
    check("R-CORE-PASS-OUT", float(ex["wake_strain"]) < float(ex["over_off"]), f"a faint wakes calm, not over-exerted (wake_strain {ex['wake_strain']} under over_off {ex['over_off']})")
    check("R-CORE-PASS-OUT", float(ex["faint_bpm"]["wake"]) <= 100, f"the heart is calm on waking ({ex['faint_bpm']['wake']} bpm)")
    inv = (ROOT / "src/client/inventory_view.gd").read_text(encoding="utf-8")
    check("R-CORE-PASS-OUT", "return strain_state >= 2 or passing_out" in inv and "if body_out() or forced_sleep:" in inv, "the client takes movement away while passing out, fainted or waking")
    client = (ROOT / "scenes/terrain_client/terrain_client.gd").read_text(encoding="utf-8")
    check("R-CORE-PASS-OUT", "items.body_out() and not (event is InputEventMouseMotion) and event.is_pressed()" in client, "no key or button reaches the world while passing out")
    check("R-CORE-PASS-OUT", "moving = false   # passing out" in client, "no footsteps while passing out, fainted or waking")
    held = (ROOT / "src/client/held_item.gd").read_text(encoding="utf-8")
    check("R-CORE-PASS-OUT", all(t in held for t in ("_right_held() or _body_out()", "func _start_swing() -> void:\n\tif _body_out():", "_swing_t >= 0.0 and _body_out()", 'hoe_mode != "smooth" or _body_out()')),
          "no swing, strike, drawn bow or hoe levelling while passing out")
    server = (ROOT / "src/stream/server_items.gd").read_text(encoding="utf-8")
    check("R-CORE-PASS-OUT", '(16 if strain_going(peer) else 0)' in server and "and not strain_going(peer):" in server, "the server tells the client and refuses a stance while passing out")
    check("R-CORE-PASS-OUT", '_strain[peer] = {"s": 0.0, "state": 3, "t": 0.0, "rescued": true}' in server and 'if cause != "cave-in" and cause != "passed out":' in inv,
          "a cold or water pass-out wakes lying until the sight is back (waking stage, no fade of its own)")


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
    # 26 Nov 2026 "witness tree looks great" on the pass 5 picture: keep that look (colours and the vein mask's lit share).
    for want in ('set_shader_parameter("glow", Color(0.6, 0.04, 1.0))', 'set_shader_parameter("glow_core", Color(0.92, 0.78, 1.0))', 'set_shader_parameter("core_boost", 1.6)'):
        check("R-FLORA-WITNESS-GLOW", want in src, f"the approved witness night look is kept ({want})")
    try:
        from PIL import Image
        px = Image.open(ROOT / "assets/trees/leaf_witness_veins.png").convert("L").tobytes()
        lit = sum(1 for v in px if v >= 120) / len(px)
        check("R-FLORA-WITNESS-GLOW", 0.05 <= lit <= 0.075, f"the vein mask's lit share stays near the approved 0.063 ({lit:.3f})")
    except ImportError:
        pass
    for f in ("leaf_witness_veins.png", "leaf_witness_veins.png.import"):
        check("R-FLORA-WITNESS-GLOW", (ROOT / "assets/trees" / f).is_file() and (ROOT / "assets/trees" / f).stat().st_size > 1000 if f.endswith(".png") else (ROOT / "assets/trees" / f).is_file(), f"the witness leaf's vein mask is there ({f})")


def stealth():
    sen = data("data/animals/animals.json")["senses"]
    crouch, lie = float(sen["crouch_factor"]), float(sen["lie_factor"])
    check("R-PLAYER-CRAWL", 0.0 < lie < crouch <= 0.5, f"crouching ({crouch}) and crawling ({lie}) drastically cut how far animals sense you, crawling most")
    check("R-PLAYER-CRAWL", float(sen["brush_crawl_share"]) <= float(sen["brush_crouch_share"]) < 1.0, "crawling through brush is no louder than crouching, both quieter than walking")
    check("R-PLAYER-CRAWL", float(sen["lie_eye_m"]) < float(sen["low_eye_m"]) < 1.6, "a crawler is looked for lower than a croucher, a croucher lower than a stander")
    stance = (ROOT / "src/client/stance.gd").read_text(encoding="utf-8")
    check("R-PLAYER-CRAWL", re.search(r"^const SPEED := \[1\.0, [0-9.]+, 0\.0, CRAWL_MPS / 3\.2\]", stance, re.M), "lying off a bed moves (the crawl), sitting does not")


def dead_names():
    """R-HUNT-DEAD-NAME: every animal kind has a name for its body ("Dead " + name, carcass_look.gd dead_name), so none falls back to "Dead animal"
    or a bare "Carcass"; the duck's flock name ("Ducks") has its one-animal name."""
    species = data("data/animals/animals.json")["species"]
    for sid, row in species.items():
        one = str(row.get("one", row.get("name", "")))
        check("R-HUNT-DEAD-NAME", one != "" and "carcass" not in one.lower(), f"{sid} has a name for its body ({one!r})")
    check("R-HUNT-DEAD-NAME", species["duck"].get("one") == "Duck", "a dead duck is one duck, not \"Dead ducks\"")
    check("R-HUNT-DEAD-NAME", len(species) >= 40, f"the species were read ({len(species)})")


def seen_far():
    """R-ANIMAL-SEEN-FAR: big game (deer, elk, moose, bears, boar, pronghorn, horses) is sent out to 200 m, every other kind to 120 m."""
    cfg = data("data/animals/animals.json")
    check("R-ANIMAL-SEEN-FAR", float(cfg["big_game_send_m"]) == 200.0, f"big game is sent out to {cfg['big_game_send_m']} m (\"Let's try 200 m.\")")
    check("R-ANIMAL-SEEN-FAR", float(cfg["send_radius_m"]) == 120.0, f"every other kind to {cfg['send_radius_m']} m")
    want = {"deer", "elk", "moose", "bear", "black_bear", "boar", "pronghorn", "horse"}
    check("R-ANIMAL-SEEN-FAR", set(cfg["big_game"]) == want, f"the big game kinds are {sorted(cfg['big_game'])}")
    check("R-ANIMAL-SEEN-FAR", all(k in cfg["species"] for k in cfg["big_game"]), "every big game kind is a species")


def run_feet():
    """R-MOVE-RUN-FEET: the run clip plays faster past its 6 m/s, and the footsteps take the clip's own 1.7 m step."""
    drv = (ROOT / "src/client/character/avatar_driver.gd").read_text(encoding="utf-8")
    check("R-MOVE-RUN-FEET", "return clampf(pace / RUN_CLIP_PACE, 0.8, 1.6)" in drv, "the run clip plays at pace / 6 m/s, up to 1.6x (1.5x at the 9 m/s run)")
    for rel in ("scenes/terrain_client/terrain_client.gd", "src/client/player_view.gd"):
        m = re.search(r"^const STEP_M := \[([0-9.]+), ([0-9.]+)\]", (ROOT / rel).read_text(encoding="utf-8"), re.M)
        check("R-MOVE-RUN-FEET", m is not None and abs(float(m.group(2)) - 1.7) < 0.05, f"{rel} run footstep is the clip's 1.7 m step ({m.group(2) if m else 'missing'})")


def campfire_both():
    recipes = data("data/items/recipes.json")["recipes"]
    bps = data("data/items/blueprints.json")["blueprints"]
    items = data("data/items/items.json")["items"]
    by_hand = [rid for rid, r in recipes.items() if not r.get("retired") and r.get("gives", [None])[0] == "campfire_kit" and not r.get("station")]
    check("R-CRAFT-MAKING", by_hand, "the Campfire is crafted by hand in the pack (a live recipe with no station gives it)")
    hammer = [b for b in bps.values() if not b.get("retired") and b.get("known", True) and b.get("lays") == "campfire_kit"]
    check("R-CRAFT-MAKING", len(hammer) == 1 and int(hammer[0].get("hammer", 1)) == 1, "the Campfire is also a known hammer blueprint any hammer builds")
    check("R-CRAFT-MAKING", "kit" not in items["campfire_kit"]["name"].lower(), "the Campfire's name never says kit")


def iron_look():
    """R-ITEM-IRON-LOOK: worn iron and mail are matt drab grey (little metallic, rough); steel stays shiny metal."""
    src = (ROOT / "src/client/worn_look.gd").read_text(encoding="utf-8")
    looks = {k: [float(x) for x in v.split(",")] for k, v in re.findall(r'"(\w+)": \[([0-9., ]+)\]', src)}
    check("R-ITEM-IRON-LOOK", '["iron", "iron"]' in src and '["mail", "iron"]' in src and '["steel", "metal"]' in src, "worn iron and mail use the iron look, steel the metal look")
    check("R-ITEM-IRON-LOOK", looks["iron"][2] >= 0.6 and looks["iron"][4] <= 0.4, f"the iron look is matt (roughness {looks['iron'][2]}, metallic {looks['iron'][4]})")
    check("R-ITEM-IRON-LOOK", looks["metal"][4] >= 0.6, f"steel's look is shiny metal (metallic {looks['metal'][4]})")


def rocks_at_rest():
    """R-RES-BOULDER-PHYSICS: rocks are laid where they have long since settled, so no loose rock lies on ground steeper than loose rock
    rests on (about 35 degrees, rise 0.7 a metre); steeper ground takes only crags (bedrock)."""
    fields = data("data/items/boulders.json")["rock_fields"]
    check("R-RES-BOULDER-PHYSICS", float(fields["steepest"]) <= 0.71 and float(fields["scree_flat_max"]) <= 0.71, f"loose rock only on ground of rise 0.7 or less (steepest {fields['steepest']}, scree_flat_max {fields['scree_flat_max']})")


def lane_on_c():
    """R-TEAM-LANE-C-DRIVE: test tools default to C:\\DynastyLane and its own Godot, never to E: or the shared editor in GodotInstaller
    (Dave 26 Nov 2026: "only test from there"). Scans tools/ (top level) and art/playthrough/ (.sh .ps1 .py .gd .cmd, no extension).
    nightly_backup.py (its E: destination and its Godot default) is backup, not testing, and is left alone."""
    hits = []
    for f in sorted(list((ROOT / "tools").glob("*")) + list((ROOT / "art/playthrough").rglob("*"))):
        if not f.is_file() or f.suffix not in {".sh", ".ps1", ".py", ".gd", ".cmd", ""} or f.name in {"nightly_backup.py", "check_dave_rules.py"}:
            continue
        text = f.read_text(encoding="utf-8", errors="ignore")
        hits += [f"{f.relative_to(ROOT)}:{n}" for n, line in enumerate(text.splitlines(), 1) if re.search(r"\b[Ee]:[/\\]|(?<![\w.])/[Ee]/|GodotInstaller", line)]
    check("R-TEAM-LANE-C-DRIVE", not hits, "no test tool points at E: " + (str(hits[:5]) if hits else "(C:\\DynastyLane)"))


def alligator():
    """R-ANIMAL-ALLIGATOR: Dave's alligator model never plays the dog walk ("ignore the dog walk its terrible"), drags its tail in every clip, crawls low with its legs bent out, and crawls slowly."""
    row = data("data/animals/models.json")["species"]["alligator"]
    clips = [c for look in [row] + row.get("variants", []) for v in look.get("clips", {}).values() for c in (v if isinstance(v, list) else [v])]
    check("R-ANIMAL-ALLIGATOR", "Walking" not in clips, f"no role plays the dog's Walking clip ({sorted(set(clips))})")
    check("R-ANIMAL-ALLIGATOR", len(row.get("tail_drag", [])) >= 2, f"the tail drags on the ground in every clip (tail_drag: {row.get('tail_drag')})")
    crawl = row.get("crawl", {})
    check("R-ANIMAL-ALLIGATOR", len(crawl.get("legs", [])) == 4 and "cat_walk" in crawl.get("clips", []), "the walk lets the body down with all four legs bent out (\"bend his legs more like a real alligator\")")
    walk = float(data("data/animals/animals.json")["species"]["alligator"]["walk_mps"])
    check("R-ANIMAL-ALLIGATOR", walk <= 0.5, f"it crawls at a real alligator's pace ({walk} m/s, \"slow down his walk\")")


def inventory_worn():
    """R-HUD-INVENTORY-WORN: the inventory's You column has no character picture and a well for every worn position."""
    code = (ROOT / "src/client/ui/inventory/you_column.gd").read_text(encoding="utf-8")
    start = code.index("const GROUPS")
    groups = code[start:code.index("\n]\n", start)]
    missing = [p for p in data("data/items/clothing.json")["worn"] if f'"{p}"' not in groups]
    check("R-HUD-INVENTORY-WORN", not missing, f"every worn position has a well (missing: {missing})")
    check("R-HUD-INVENTORY-WORN", "SubViewport" not in code and "make_avatar" not in code, "no character picture in the inventory")


def dig_stones():
    """R-RES-DIG-STONES: every shovelful of soil or clay ground brings up at least one Stone, and clay is not cut for it (R-CRAFT-CLAY-DIG)."""
    dig = data("data/items/digging.json")
    grounds = {m: dig["yield"][m] for m in ("loam", "forest_humus", "silt", "alluvium", "stony_soil", "peat", "mud", "clay")}
    grounds["default"] = dig["default"]
    short = [m for m, rows in grounds.items() if not any(r[0] == "stone" and int(r[1]) >= 1 for r in rows)]
    check("R-RES-DIG-STONES", not short, f"every soil and clay dig gives at least one stone (none in: {short})")
    clay = [r for r in dig["yield"]["clay"] if r[0] == "clay"]
    check("R-RES-DIG-STONES", clay and int(clay[0][1]) >= 2 and int(clay[0][2]) >= 4, f"clay ground still gives 2 to 4 clay ({clay})")


def drink_fresh():
    """R-WATER-DRINK-FRESH: the player is told to "drink fresh water", not "drink at the water"."""
    goal = next(g for g in data("data/items/starter_goals.json")["goals"] if g["id"] == "drink")
    hint = next(h for h in data("data/items/hints.json")["hints"] if h["id"] == "drink")
    words = [goal["title"], goal["hint"], hint["text"]]
    check("R-WATER-DRINK-FRESH", all("drink fresh water" in w.lower() for w in words), f"the drink goal and hints say drink fresh water ({words})")


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
             "R-FLORA-WITNESS-GLOW": witness_glow, "R-PLAYER-CRAWL": stealth, "R-HUNT-DEAD-NAME": dead_names, "R-HUNT-SIGN-SOUND": sign_sound, "R-CORE-PASS-OUT": pass_out,
             "R-ANIMAL-SEEN-FAR": seen_far, "R-MOVE-RUN-FEET": run_feet, "R-CRAFT-MAKING": campfire_both, "R-TEAM-LANE-C-DRIVE": lane_on_c, "R-ITEM-IRON-LOOK": iron_look,
             "R-RES-BOULDER-PHYSICS": rocks_at_rest, "R-ANIMAL-ALLIGATOR": alligator, "R-HUD-INVENTORY-WORN": inventory_worn, "R-WATER-DRINK-FRESH": drink_fresh,
             "R-RES-DIG-STONES": dig_stones}
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
        kind = re.match(r"^- \*\*R-[A-Z0-9-]+\*\* · [^·]+ · (rule|suggestion|unclear) · ", rulings.get(key, ""))
        if kind and kind.group(1) == "suggestion":
            print(f"NOTE {key}: {what} [a suggestion: if play-testing showed better, change the line and tell the coordinator; does not block]")
        elif "unverified" in rulings.get(key, ""):
            print(f"WARN {key}: {what} [the ruling is marked unverified: tell the coordinator, do not block]")
        elif key in KNOWN_OPEN:
            print(f"OPEN {key}: {what} [{KNOWN_OPEN[key]}]")
        else:
            failed += 1
            print(f"FAIL {key}: {what}")
    passed = sum(1 for _, ok, _ in results if ok)
    print(f"dave rules: {passed} pass, {failed} fail, {sum(1 for k, ok, _ in results if not ok and k in KNOWN_OPEN)} open (FAIL blocks a merge; OPEN, WARN and NOTE do not)")
    for key in KNOWN_OPEN:
        if all(ok for k, ok, _ in results if k == key):
            failed += 1
            print(f"FAIL {key} now passes: take it out of KNOWN_OPEN")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
