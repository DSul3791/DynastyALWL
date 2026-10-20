"""Writes the sound pack manifest: assets/audio/SOUND_PACK.md and assets/audio/sound_manifest.json.

Run: python3 assets/audio/make_manifest.py
Every sound slot the game plays is in SLOTS below: where it is used, what it is for, what the
owner could supply, and how wanted a real recording is (1 = most). The script looks in the folders
to see whether each slot is a recording (assets/audio/recorded/...), a generated placeholder, or
still empty, and counts the variants (name_N or name_left_N / name_right_N). Add a line to SLOTS
whenever a sound slot is added; then run the script and commit both files.
"""
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))

# (name, folder under assets/audio (generated) and recorded/, where it plays, what to supply, priority)
SLOTS = [
    ("wind_low", "", "sound_stage.gd: the steady wind bed, louder with height and open ground, softer in trees", "A calm open-field wind loop, 20 s or more, seamless, no gusts (low rumble layer)", 1),
    ("wind_gust", "", "sound_stage.gd: the swelling gust layer on top of the bed", "A leaf-and-grass rustling wind loop with soft swells, seamless", 1),
    ("wind_storm", "weather", "weather_sounds.gd: gale howl in storms and blizzards", "A howling gale loop, seamless", 2),
    ("rain_light", "weather", "weather_sounds.gd: drizzle and light rain loop", "A light rain on open ground loop, seamless", 1),
    ("rain_heavy", "weather", "weather_sounds.gd: heavy rain and storm loop", "A heavy downpour loop, seamless", 1),
    ("rain_leaves", "weather", "weather_sounds.gd: rain pattering on leaves under trees", "Rain on forest canopy loop, seamless", 2),
    ("rain_water", "weather", "weather_sounds.gd: rain falling on ponds and rivers near the player", "Rain on a lake surface loop, seamless", 3),
    ("thunder", "weather", "weather_sounds.gd: a mid-distance thunder roll", "2 to 3 rolling thunder claps, 5 to 9 s", 1),
    ("thunder_near", "weather", "weather_sounds.gd: a close strike (under 500 m): sharp crack and thud", "2 to 3 close, sharp thunder cracks, 2 to 4 s", 2),
    ("thunder_far", "weather", "weather_sounds.gd: a far strike (over 1800 m): a low grumble", "2 to 3 distant low rumbles, 8 to 12 s", 2),
    ("rain_drip", "weather", "weather_sounds.gd: a drop falling from a leaf near you, under trees in rain", "3 to 4 single drops falling from leaves onto leaves or ground, 0.3 s", 3),
    ("water_brook", "water", "water_sounds.gd: a fast shallow stream, positional loop", "A babbling brook loop, seamless", 1),
    ("water_river", "water", "water_sounds.gd: a wide slow river, positional loop", "A broad river flow loop, seamless", 1),
    ("water_pond", "water", "water_sounds.gd: gentle lapping at a pond shore", "A calm lake shore lapping loop, seamless", 2),
    ("water_fall", "water", "water_sounds.gd: a waterfall roar", "A waterfall loop, seamless", 2),
    ("bird_whistle", "ambient", "ambient_life.gd: forest bird, by day", "2 to 4 clear songbird whistles, 1 to 2 s", 2),
    ("bird_feebee", "ambient", "ambient_life.gd: forest bird, by day", "2 chickadee-style two-note calls", 3),
    ("bird_trill", "ambient", "ambient_life.gd: meadow bird, by day", "2 to 3 trilling songs, about 1 s", 2),
    ("bird_chirp", "ambient", "ambient_life.gd: meadow, water-edge and forest, the most frequent call", "3 to 5 short sparrow-like chirps, 0.5 s", 1),
    ("crow_caw", "ambient", "ambient_life.gd: forest and highland, by day", "have: Dave's crow calls", 5),
    ("crow_alarm", "ambient", "ambient_life.gd: alarm(at): a crow scolds when the player runs through crow country, and the danger warning hook", "have: Dave's angry crow", 5),
    ("wing_flap", "ambient", "ambient_life.gd: flush(at): a bird bursts out of cover and flies off", "have: Dave's wing flaps", 5),
    ("woodpecker", "ambient", "ambient_life.gd: forest, by day", "2 to 3 woodpecker drumming runs, about 1 s", 3),
    ("owl_hoot", "ambient", "ambient_life.gd: forest at night", "2 to 3 owl hoots (tawny or barred), 2 to 3 s", 2),
    ("hawk_screech", "ambient", "ambient_life.gd: highland, by day", "2 to 3 hawk screeches", 3),
    ("cricket_chirp", "ambient", "ambient_life.gd: meadow and water edge at dusk and night, summer and autumn", "2 to 3 cricket chirps runs, 2 s (one species)", 1),
    ("frog_croak", "ambient", "ambient_life.gd: ponds and rivers, spring to autumn, more at night and in rain", "have: Dave's frogs (mostly small trillers); a deep bullfrog croak is still missing", 4),
    ("tree_frog_peep", "ambient", "ambient_life.gd: water edge and forest, spring to autumn", "have: Dave's frogs (short peeps)", 5),
    ("fish_splash", "ambient", "ambient_life.gd: a fish jumps at the water edge, rare", "have: Dave's fish jumping clip, played whole", 5),
    ("bed_forest", "ambient", "ambient_life.gd (optional bed): a quiet forest background that fades in with forest cover", "A quiet forest background loop, 30 s or more, no clear single calls", 3),
    ("bed_meadow", "ambient", "ambient_life.gd (optional bed): a meadow background", "A meadow background loop (insects, distant birds), seamless", 3),
    ("bed_water", "ambient", "ambient_life.gd (optional bed): a water-edge background", "A quiet marsh or lake edge background loop", 3),
    ("bed_highland", "ambient", "ambient_life.gd (optional bed): highland wind and space", "A thin high-altitude background loop", 3),
    ("cave_drip", "cave", "cave_sounds.gd: water drops in caves and tunnels", "3 to 6 single water drips in a stone room, 1 to 2 s each", 2),
    ("dig_soil", "dig", "dig_sounds.gd: digging dirt and humus", "3 spade or shovel scoops into earth", 2),
    ("dig_clay", "dig", "dig_sounds.gd: digging clay, mud and peat", "3 wet sticky digs", 3),
    ("dig_sand", "dig", "dig_sounds.gd: digging sand and snow", "3 sand shovelling sounds", 3),
    ("dig_gravel", "dig", "dig_sounds.gd: digging gravel", "3 gravel shovelling sounds", 3),
    ("dig_rock", "dig", "dig_sounds.gd: breaking rock", "3 pickaxe on rock or rock breaking sounds", 2),
    ("dig_ore", "dig", "dig_sounds.gd: digging out ore (metal clink on rock)", "3 pick on ore sounds", 3),
    ("hit_axe_wood", "hits", "hit_sounds.gd: an axe blow on wood (felling, chopping)", "3 axe chops into a log or tree", 2),
    ("hit_axe_stone", "hits", "hit_sounds.gd: an axe blow on stone", "3 axe strikes on rock", 4),
    ("hit_axe_soil", "hits", "hit_sounds.gd: an axe blow on soil", "3 axe thuds into earth", 4),
    ("hit_pick_wood", "hits", "hit_sounds.gd: a pickaxe blow on wood", "3 pick strikes into wood", 4),
    ("hit_pick_stone", "hits", "hit_sounds.gd: a pickaxe blow on rock (mining)", "3 pickaxe strikes on rock", 2),
    ("hit_pick_soil", "hits", "hit_sounds.gd: a pickaxe blow on soil", "3 pick strikes into hard earth", 3),
    ("hit_hammer_wood", "hits", "hit_sounds.gd: a hammer blow on wood (building)", "3 hammer knocks on timber, or nails driven", 2),
    ("hit_hammer_stone", "hits", "hit_sounds.gd: a hammer blow on stone (chiselling, smithing)", "3 hammer clanks on stone", 3),
    ("hit_hammer_soil", "hits", "hit_sounds.gd: a hammer blow on soil (driving stakes)", "3 mallet thumps into earth", 4),
    ("hit_spade_wood", "hits", "hit_sounds.gd: a spade strike on wood", "3 spade knocks and scrapes on wood", 4),
    ("hit_spade_stone", "hits", "hit_sounds.gd: a spade scraping on stone", "3 spade scrapes on stone", 4),
    ("hit_spade_soil", "hits", "hit_sounds.gd: a spade strike into soil", "3 spade thuds into earth", 3),
    ("swim_splash_small", "swim", "swim_sounds.gd: the body enters water slowly (under 4 m/s)", "3 small body-into-water splashes, 0.5 to 1 s", 2),
    ("swim_splash_big", "swim", "swim_sounds.gd: a jump or fall into water (4 m/s and up)", "3 big splashes of a person falling in, 1 to 2 s", 2),
    ("swim_stroke", "swim", "swim_sounds.gd: an arm stroke while swimming, one every 0.6 to 1.4 s", "3 breaststroke or crawl arm pulls through water, 0.5 s", 3),
    ("swim_dive", "swim", "swim_sounds.gd: the head goes under", "3 bubbling gulps of going under, 1 s", 3),
    ("swim_surface", "swim", "swim_sounds.gd: the head comes out of the water", "3 breaths and running water on surfacing, 1 s", 3),
    ("swim_under", "swim", "swim_sounds.gd: the hum of being underwater (loop while the eyes are under)", "A muffled underwater ambience loop, seamless", 3),
    ("town_bell", "town", "town_sounds.gd: a tower bell tolling the hour or on call (ring_bell)", "2 to 3 bell strikes with a long ring, 4 to 6 s each", 3),
    ("town_hammering", "town", "town_sounds.gd: a smith or builder working nearby (loop)", "A seamless loop of hammer on anvil, 8 to 15 s", 2),
    ("town_fire", "town", "town_sounds.gd: a hearth or forge fire (loop)", "A seamless crackling fire loop", 2),
    ("town_crowd", "town", "town_sounds.gd: a busy square murmur (loop)", "A seamless crowd murmur loop, no clear words", 3),
    ("dig_water", "dig", "dig_sounds.gd: water pouring into a new hole", "3 water splashing into a pit", 3),
]

# Footstep sets: (surface, where it plays). Left and right files: step_<surface>_<left|right>_N in recorded/.
STEPS = [
    ("grass", "short grass ground"), ("grass_tall", "tall grass"), ("bushes", "walking through shrubs"),
    ("dirt", "soil, forest soil, clay, stony ground"), ("leaves", "leaf litter on forest humus"),
    ("mud", "mud, peat, wet ground, soaked ground in rain"), ("sand", "sand, beach, salt flat, ash"),
    ("snow", "snow"), ("stone", "rock, outcrops, ore, ice"), ("gravel", "gravel, soft rock"),
    ("water", "wading in water"),
]

# Slots planned but not yet built: listed so the owner can supply them early.
PLANNED = [
]

EXT = ("ogg", "wav")


def variants(folder, name):
    """Files for name in a folder: name.ext or name_N.ext (not counting .import files)."""
    if not os.path.isdir(folder):
        return []
    pattern = re.compile(r"^%s(_\d+)?\.(%s)$" % (re.escape(name), "|".join(EXT)))
    return sorted(f for f in os.listdir(folder) if pattern.match(f))


def status(name, group):
    gen_dir = os.path.join(HERE, group) if group else HERE
    rec_dir = os.path.join(HERE, "recorded", group) if group else os.path.join(HERE, "recorded")
    rec = variants(rec_dir, name)
    gen = variants(gen_dir, name)
    if rec:
        return "recorded", len(rec)
    if gen:
        return "generated", len(gen)
    return "empty", 0


def step_status(surface):
    rec_dir = os.path.join(HERE, "recorded")
    count = len([f for f in os.listdir(rec_dir) if re.match(r"^step_%s_(left|right)_\d+\.(ogg|wav)$" % surface, f)]) if os.path.isdir(rec_dir) else 0
    return ("recorded" if count else "empty"), count


def main():
    rows = []
    for name, group, where, supply, priority in SLOTS:
        state, count = status(name, group)
        rows.append({"name": name, "state": state, "variants": count, "used_in": where, "to_supply": supply, "priority": priority})
    steps = []
    for surface, where in STEPS:
        state, count = step_status(surface)
        steps.append({"name": "step_" + surface, "state": state, "variants": count, "used_in": where})

    total = len(rows) + len(steps)
    recorded = sum(1 for r in rows + steps if r["state"] == "recorded")
    generated = sum(1 for r in rows if r["state"] == "generated")
    empty = sum(1 for r in rows + steps if r["state"] == "empty")

    with open(os.path.join(HERE, "sound_manifest.json"), "w") as f:
        json.dump({"slots": rows, "steps": steps, "planned": [{"name": n, "used_in": w, "to_supply": s} for n, w, s in PLANNED]}, f, indent=1)

    lines = ["# Sound pack manifest", "",
             "Written by `assets/audio/make_manifest.py` (run it after adding sounds; edit its SLOTS table when a slot is added). "
             "**%d slots: %d recorded, %d generated placeholders, %d empty.**" % (total, recorded, generated, empty), "",
             "Drop a recording as `assets/audio/recorded/<folder>/<name>.ogg` (or `<name>_0.ogg`, `<name>_1.ogg` for variants; WAV works too). "
             "The game uses the recording and ignores the generated sound. Priority 1 means a real recording would improve the game the most; 5 means done. "
             "Licence and source of every recording go in `README.md` (section on supplied recordings).", "",
             "## Sounds to supply, most wanted first", "",
             "| Priority | Slot | State | Variants | Where it plays | What to supply |", "|---|---|---|---|---|---|"]
    for r in sorted(rows, key=lambda r: (r["priority"], r["name"])):
        lines.append("| %d | `%s` | %s | %d | %s | %s |" % (r["priority"], r["name"], r["state"], r["variants"], r["used_in"], r["to_supply"]))
    lines += ["", "## Footsteps (recorded left and right, `step_<ground>_<left|right>_N`)", "", "| Slot | State | Files | Ground |", "|---|---|---|---|"]
    for s in steps:
        lines.append("| `%s` | %s | %d | %s |" % (s["name"], s["state"], s["variants"], s["used_in"]))
    if PLANNED:
        lines += ["", "## Planned (hooks come later; supplying them early is fine)", "", "| Slot | Where it will play | What to supply |", "|---|---|---|"]
        for n, w, s in PLANNED:
            lines.append("| `%s` | %s | %s |" % (n, w, s))
    with open(os.path.join(HERE, "SOUND_PACK.md"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print("Manifest: %d slots, %d recorded, %d generated, %d empty" % (total, recorded, generated, empty))


if __name__ == "__main__":
    main()
