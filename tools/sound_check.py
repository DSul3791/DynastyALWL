#!/usr/bin/env python3
"""Headless sound regression scenarios.

Run: python3 tools/sound_check.py [--only NAME[,NAME]] [--godot PATH] [--list] [--verbose]

Each scenario starts a fresh server (own port and store), runs the client headless with the scenario's
test flags at quality 0 (Low, 24 voices) and reads the report the client prints at the end of its run
(the "sound budget", "fire sounds", "water sounds" ... lines). A scenario passes when every check on those
lines holds; the voice peak must also stay at or under the Low cap. Exit status 1 when any scenario fails.
Needs the Godot binary (default /root/bin/godot, or $GODOT) and about 1 minute per scenario; the cloud has
no audio device, so this checks what the sound code decided to play, not how it sounds.

To add a scenario: add a row to SCENARIOS (flags the client already knows, frames, checks). A check is
(label, regex with ONE capture group, min, max): the group is read as a number and must lie in [min, max].
A check with a group named "sum" in the pattern, as (label, regex, min, max, "sum") adds up all numbers
in the captured text (for a dictionary of counts).
"""
import os
import re
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", "/root/bin/godot")
LOW_VOICE_CAP = 24
VOICE_SCAN_SLACK = 2                    # the cap is enforced every 0.25 s, so a peak can pass it briefly
PORT_BASE = 7900

NUM = r"(-?\d+(?:\.\d+)?)"

# name, client flags, frames, checks
SCENARIOS = [
    ("walk", ["--walk"], 9000, [
        ("footsteps played", r"footsteps (\{[^}]*\})", 8, 1000, "sum"),
    ]),
    ("floor", ["--walk", "--floor=plank"], 9000, [
        ("plank steps", r"footsteps \{ \"plank\": " + NUM, 8, 1000),
    ]),
    ("rain", ["--weather=rain", "--walk"], 9000, [
        ("rain level", r"weather rain rain " + NUM, 0.5, 1.0),
        ("footsteps played", r"footsteps (\{[^}]*\})", 8, 1000, "sum"),
    ]),
    ("snow_hush", ["--weather=snow"], 6000, [
        ("hush builds", r"snow hush " + NUM, 0.3, 1.0),
        ("nature bus lower", r"snow hush [\d.]+ \(nature bus " + NUM, -20, -1.0),
    ]),
    ("rain_roof", ["--weather=rain", "--roofed"], 5000, [
        ("under a roof", r"roofed " + NUM + r", loops", 0.9, 1.0),
        ("roof patter plays", r"loops .*(rain_roof)", 0, 1, "text"),
        ("no leaf patter under a roof", r"loops (?!.*rain_leaves)", 0, 1, "text"),
    ]),
    ("rain_covered", ["--weather=rain", "--covered"], 5000, [
        ("under a crown", r"covered " + NUM + r",", 0.9, 1.0),
        ("leaf patter plays", r"loops .*(rain_leaves)", 0, 1, "text"),
        ("not the roof patter", r"loops (?!.*rain_roof)", 0, 1, "text"),
    ]),
    ("rain_stone", ["--weather=rain", "--rain-ground=stone"], 5000, [
        ("stone weight", r"rain ground stone \(weights \{ \"stone\": " + NUM, 0.95, 1.0),
    ]),
    ("rain_snow", ["--weather=rain", "--rain-ground=snow"], 5000, [
        ("snow weight", r"rain ground snow \(weights \{ \"stone\": [\d.]+, \"mud\": [\d.]+, \"litter\": [\d.]+, \"snow\": " + NUM, 0.95, 1.0),
    ]),
    ("storm", ["--weather=storm", "--distant"], 5000, [
        ("storm weather", r"weather storm rain " + NUM, 0.9, 1.0),
        ("heard list names sounds", r"sounds heard \(" + NUM + r"\)", 2, 40),
        ("far thunder takes the far bus", r"thunder (thunder_far 2500 m, Air_thunder_2)", 0, 1, "text"),
    ]),
    ("fire", ["--fire"], 5000, [
        ("fires lit", r"fire sounds: " + NUM + r" lit", 1, 10),
        ("fires put out", r"fire sounds: \d+ lit, " + NUM + r" put out", 1, 10),
    ]),
    ("fire_world", ["--fire-world"], 5000, [
        ("laid wood heard", r"fire world: " + NUM + r" fuel", 1, 1),
        ("lit heard", r"fire world: \d+ fuel, " + NUM + r" lit", 1, 1),
        ("put out heard", r"fire world: \d+ fuel, \d+ lit, " + NUM + r" out", 1, 2),
    ]),
    ("memory", ["--load-all-sounds", "--quality=0"], 3000, [
        ("every file loads", r"sound memory audit: " + NUM + r" files", 400, 2000),
        ("under the Low cap", r"MB read from disk, " + NUM + r" refused", 0, 0),
    ]),
    ("faint", ["--faint"], 6500, [
        ("world goes silent", r"faint run: world muted to " + NUM, 0.99, 1.0),
        ("heart fades away", r"heart gain down to " + NUM, 0, 0.01),
<<<<<<< HEAD
        ("no heavy breathing (Dave 2026-10-21)", r"gain down to [\d.]+, " + NUM + r" heaves", 0, 0),
=======
        ("heaves played (breathing is off since 2026-10-21, so none)", r"gain down to [\d.]+, " + NUM + r" heaves", 0, 0),
>>>>>>> 9fc38ac (Landing at spawn, exertion retune, smooth blackout, bars only in the inventory, no breathing noise, 80 percent carry free)
        ("run completes", r"done (true)", 0, 1, "text"),
        ("no breathing while fainted", r"breaths while fainted " + NUM, 0, 0),
        ("world returns with the vision", r"wake mute " + NUM, 0.1, 0.9),
        ("heart peaks near 175 to 200 bpm", r"bpm max " + NUM, 175, 200),
        ("heart rate never jumps (bpm per frame)", r"bpm max \d+, step " + NUM, 0, 1.5),
    ]),
    ("merge", ["--merge-check"], 3500, [
        ("falls share a voice", r"falls 6 -> " + NUM + r" voices", 2, 2),
        ("fall width adds up", r"voices, \d+ merged, widest " + NUM, 20, 20),
        ("far fires share a loop", r"fires 7 -> " + NUM + r" loops", 2, 2),
        ("fall base plays near a fall", r"fall base: playing (true)", 0, 1, "text"),
        ("fall base level", r"fall base: playing true at " + NUM + r" dB", -30, -5),
        ("five hearths merged", r"loops, " + NUM + r" merged", 5, 5),
    ]),
    ("voice_priority", ["--voice-priority"], 3000, [
        ("six cut", r"voice priority: shed " + NUM + r" of 10", 6, 6),
        ("own sounds all kept", r"own kept " + NUM + r" of 2", 2, 2),
        ("ambience cut first", r"ambience left " + NUM + r" of 6", 0, 0),
    ]),
    ("sweep", ["--sweep", "--nature-fast", "--walk"], 14000, [
        ("all cells run", r"sweep done: " + NUM + r" cells", 32, 32),
        ("peak under the Low cap", r"sweep done: \d+ cells, peak " + NUM + r" of", 1, 24),
    ]),
    ("emitters", ["--emitter-test"], 3500, [
        ("threat call plays", r"creature wolf (true)", 0, 1, "text"),
        ("rate limit 4 per second", r"burst " + NUM + r" of 6 played, " + NUM + r" dropped", 4, 4),
        ("unknown stays silent", r"unknown (false)", 0, 1, "text"),
        ("far loops merge", r"17 rows -> " + NUM + r" loops, " + NUM + r" merged", 3, 3),
        ("merged count", r"loops, " + NUM + r" merged", 13, 13),
    ]),
    ("mix", ["--hour=21", "--season=autumn", "--weather=storm", "--distant", "--nature-fast", "--cave=0.6", "--fire-world", "--creatures", "--walk", "--ui-sounds", "--mix-levels"], 14000, [
        ("Master never clips", r"mix levels: Master peak " + NUM + r" mean", -200, 0.0),
    ]),
    ("landing", ["--landing"], 3500, [
        ("a step landing", r"landing check: step " + NUM, 1, 1),
        ("a thud landing", r" thud " + NUM, 1, 1),
        ("a hard landing", r" hard " + NUM + r",", 1, 1),
        ("fall damage hook fires once", r", " + NUM + r" hurt signals", 1, 1),
        ("hard landing plays the hard sound", r"last hard from 7.0 m (land_hard_\d) \(generated\)", 0, 1, "text"),
    ]),
    ("stepfx", ["--stepfx"], 3500, [
        ("shoes wet after wading", r"stepfx check: wet " + NUM, 1, 1),
        ("squelches while wet", r" " + NUM + r" squelches in 10 steps", 4, 10),
        ("half dry after 10 s", r"after 10 s " + NUM, 0.4, 0.6),
        ("dry after 25 s", r"after 25 s " + NUM, 0, 0),
        ("no squelch when dry", r", " + NUM + r" squelches when dry", 0, 0),
        ("cloth on dry steps", r", " + NUM + r" cloth steps", 15, 25),
    ]),
    ("swing", ["--swing-test"], 3500, [
        ("one whoosh per tool", r"swing check: " + NUM + r" swings", 4, 4),
        ("unknown tool is silent", r"unknown tool (false)", 0, 1, "text"),
        ("generated whoosh", r"last spade swing (hit_swing_\d) \(generated\)", 0, 1, "text"),
    ]),
    ("insects", ["--insect-test"], 3500, [
        ("summer noon loud", r"summer noon " + NUM, 0.6, 1.0),
        ("quieter at night (job 77 night mix)", r"summer 2h " + NUM, 0.35, 0.65),
        ("silent in winter", r"winter noon " + NUM, 0, 0),
        ("thin in spring", r"spring noon " + NUM, 0.2, 0.5),
        ("no jump at sunrise edge", r"sunrise edge " + NUM, 0.3, 0.9),
        ("no jump at sunset edge", r"sunset edge " + NUM, 0.3, 0.9),
        ("none in rain", r"rain " + NUM + r", playing", 0, 0.05),
        ("the loop plays", r"playing " + NUM, 1, 1),
        ("no insect hum at a lake by day", r"lake noon " + NUM, 0, 0),
        ("the lake still hums at night in summer", r"lake 2h " + NUM, 0.2, 0.7),
        ("lake counts as full daylight at noon", r"lake day (true)", 0, 1, "text"),
    ]),
    ("variety", ["--variety-test"], 3500, [
        ("song bird: dawn loud, midday quiet, evening middling", r"whistle by hour (1.0,0.7,0.2,0.6)", 0, 1, "text"),
        ("crows are a midday bird", r"crow at noon " + NUM, 1.0, 1.0),
        ("larks stop in autumn and winter, crows peak in winter", r"by season (1.00,0.80,0.90,0.70,0.10,1.10,0.00,1.20)", 0, 1, "text"),
        ("no repeat within a minute with 20 variants", r"repeats in a minute " + NUM, 0, 0),
        ("never the same file twice running", r"back-to-back " + NUM + r",", 0, 0),
        ("also with only 3 variants", r"back-to-back of 3 " + NUM, 0, 0),
    ]),
    ("meters", ["--meters-test"], 3500, [
        ("not built while Debug details is hidden", r"calls before " + NUM, 0, 0),
        ("title, 8 buses, latency line", r"calls before 0, " + NUM + r" lines", 10, 10),
        ("Master and World are listed", r"Master line (true), World line (true)", 0, 1, "text"),
        ("output latency shown", r"latency line (true)", 0, 1, "text"),
        ("built once per call", r"calls after " + NUM, 2, 2),
        ("stable size", r"repeat same size (true)", 0, 1, "text"),
    ]),
    ("splash", ["--splash-test"], 3500, [
        ("a drop for each of the 8 grounds", r"splash check: " + NUM + r" grounds played", 8, 8),
        ("an unknown ground plays nothing", r"unknown (false)", 0, 1, "text"),
        ("a burst stops at the cap", r"burst " + NUM + r" of 40", 1, 10),
        ("live drops never over the cap", r"live " + NUM + r"\)", 0, 10),
        ("heavy rain: drops every second", r"heavy rain " + NUM, 20, 40),
        ("none under a canopy", r"covered " + NUM + r", roofed", 0, 0),
        ("none under a roof", r"roofed " + NUM + r", half", 0, 0),
        ("half rain is fewer", r"half rain " + NUM, 5, 18),
        ("rate at full rain", r"rate " + NUM + r" ", 5.9, 6.1),
        ("no drops when snow lies", r"rate [\d.]+ " + NUM + r" ", 0, 0),
        ("a drizzle under the threshold is silent", r"rate [\d.]+ [\d.]+ " + NUM + r",", 0, 0),
        ("generated", r"last \w+ rain_splash_\w+_\d \((generated)\)", 0, 1, "text"),
    ]),
    ("reverb", ["--reverb-test"], 3500, [
        ("off in open air on Low", r"t0 e0.0 (off) wet", 0, 1, "text"),
        ("off in open air on Mid", r"t1 e0.0 (off) wet", 0, 1, "text"),
        ("off in open air on High", r"t2 e0.0 (off) wet", 0, 1, "text"),
        ("Low is lighter: wet 0.15 at most", r"t0 e1.0 on wet (0.15)", 0, 1, "text"),
        ("Mid wet 0.35 in a tunnel", r"t1 e1.0 on wet (0.35)", 0, 1, "text"),
        ("High wet 0.45 in a tunnel", r"t2 e1.0 on wet (0.45) room 0.85", 0, 1, "text"),
        ("a hollow is a smaller room than a tunnel", r"t2 e0.3 on wet 0.14 (room 0.5\d)", 0, 1, "text"),
        ("exactly one reverb effect in the whole mixer", r"reverbs " + NUM, 1, 1),
        ("Foley and Nature send to World, World ahead of them", r"World sends Master, Foley sends World, Nature sends World, World before Foley (true)", 0, 1, "text"),
    ]),
    ("air", ["--air-test"], 3500, [
        ("a near fall is open, a mid one dull, a far one duller", r"open falls (Nature,Air_fall_1,Air_fall_2)", 0, 1, "text"),
        ("forest pushes the same falls one band darker", r"forest falls (Nature,Air_fall_2,Air_fall_3)", 0, 1, "text"),
        ("fires step down with distance", r"open fires (Foley,Air_fire_1,Air_fire_2,Foley)", 0, 1, "text"),
        ("forest dulls fires sooner", r"forest fires (Foley,Air_fire_2,Air_fire_3,Foley)", 0, 1, "text"),
        ("under a roof a fire 20 m away is dulled", r"roofed fire (Air_fire_\d)", 0, 1, "text"),
        ("thunder: far, mid, near", r"thunder (Air_thunder_2 Air_thunder_1 Weather)", 0, 1, "text"),
        ("a voice inside the hysteresis band stays put", r"hold 1 up 0", 0, 1, "text"),
        ("one filter per band bus (8 buses, 7 voices)", r"filters " + NUM, 8, 8),
        ("a fire's shed rank counts as Foley", r"shed parent (Foley)", 0, 1, "text"),
    ]),
    ("flush", ["--flush-test"], 3500, [
        ("small birds are the commonest", r"small " + NUM + r", medium", 135, 200),
        ("medium birds", r"medium " + NUM + r", large", 55, 125),
        ("crows are the fewest", r"large " + NUM + r", files", 18, 75),
        ("all 12 bursts get played", r"files used " + NUM + r",", 12, 12),
        ("never the same file twice running", r"repeats " + NUM + r",", 0, 0),
        ("a crow takes off with a large burst", r"crow file (wing_large_\d)", 0, 1, "text"),
        ("down among the trees birds are fully on", r"low factor " + NUM + r" then", 1, 1),
        ("high above the ground birds are off", r"then " + NUM + r", flush", 0, 0),
        ("no take-off high up", r"flush (false), alarm", 0, 1, "text"),
        ("no crow alarm high up", r"alarm (false)", 0, 1, "text"),
    ]),
    ("reject", ["--reject-test"], 3500, [
        ("first refusal knocks", r"reject check: first (true)", 0, 1, "text"),
        ("held key does not nag", r"held key (false)", 0, 1, "text"),
        ("one played", r"played " + NUM + r", last", 1, 1),
        ("generated knock", r"last (item_reject_\d) \(generated\)", 0, 1, "text"),
    ]),
    ("step_levels", ["--step-levels"], 3500, [
        ("file is read", r"step levels: source (data/sound/step_levels.json)", 0, 1, "text"),
        ("grass walk", r"grass walk " + NUM + r", stone", -40, -40),
        ("stone run", r"stone run " + NUM, -21, -21),
        ("plank walk", r"plank walk " + NUM, -34, -34),
        ("a tweaked file changes the level", r"tweaked grass walk " + NUM, -53, -53),
        ("a broken file changes nothing", r"after a broken file " + NUM, -53, -53),
    ]),
    ("night", ["--night-test"], 3500, [
        ("summer night bed", r"insects summer " + NUM, 0.35, 0.65),
        ("spring night bed thin", r"spring " + NUM + r", winter", 0.05, 0.25),
        ("winter night silent", r"winter " + NUM + r", day", 0, 0),
        ("day bed full", r"day " + NUM + r"; wolf", 0.6, 1.0),
        ("wolves howl more in winter", r"factor winter " + NUM, 1.5, 1.7),
        ("and less in summer", r"summer " + NUM + r"; owl", 0.3, 0.5),
        ("an owl is answered", r"owl answers " + NUM, 1, 1),
        ("natural far calls are on", r"wild (true)", 0, 1, "text"),
    ]),
    ("stance", ["--stance"], 6000, [
        ("posture changes heard", r"stance check: " + NUM + r" changes", 6, 6),
        ("last is the rise", r"last (stance_rise)", 0, 1, "text"),
    ]),
    ("lake", ["--lake"], 9000, [
        ("silent on a calm day", r"lake laps: " + NUM + r" laps calm", 0, 0),
        ("rare laps when windy", r" " + NUM + r" laps windy", 1, 8),
        ("brook is Dave's recording", r"brook loop (recorded)", 0, 1, "text"),
        ("laps are the slowed fish splash", r"last (lake_lap_\d)", 0, 1, "text"),
        ("head pond with a spring current is a lake", r"kinds (pond pond river pond brook);", 0, 1, "text"),
        ("river and brook next to a lake stay silent, the far river plays", r"flowing near lake kept " + NUM + r" of 3", 1, 1),
    ]),
    ("ice", ["--ice-test"], 9000, [
        ("a frozen pond bears steps", r"frozen walkable (true)", 0, 1, "text"),
        ("the ice groans from the shore", r" " + NUM + r" groans, ", 1, 8),
        ("no laps on ice even in a gale", r", " + NUM + r" laps, ", 0, 0),
        ("hard steps crack sometimes", r" " + NUM + r" cracks in 40", 5, 39),
        ("sounds are the ice files", r"last (ice_crack_\d)", 0, 1, "text"),
        ("after the thaw steps splash again", r"thaw walkable (false)", 0, 1, "text"),
        ("the thawed pond laps again and no longer groans", r" " + NUM + r" new groans, \d+ new laps", 0, 0),
    ]),
    ("windhole", ["--wind-hole"], 9000, [
        ("open air in a gale is silent", r"open (-?\d+) -?\d+,", -80, -80),
        ("a lean-to whistles", r"lean-to (-?\d+) -?\d+,", -40, -10),
        ("a cave mouth moans", r"mouth -?\d+ (-?\d+),", -40, -10),
        ("a sealed tunnel is quiet", r"tunnel (-?\d+) (-?\d+),", -80, -80),
        ("a calm day is quiet under a roof", r"calm (-?\d+) -?\d+ \(", -80, -80),
    ]),
    ("ui_sounds", ["--ui-sounds"], 6000, [
        ("a tick per changed slot", r"ui sounds: " + NUM + r" hotbar ticks", 3, 3),
        ("tick is the hotbar cue", r"last (hotbar_tick_\d)", 0, 1, "text"),
    ]),
    ("audit_night_rain", ["--hour=23", "--season=autumn", "--weather=rain", "--nature-fast", "--walk"], 9000, [
        ("under the Low voice cap", r"sounds \d+/24 playing \(peak " + NUM, 1, 24),
    ]),
    ("audit_worst", ["--hour=21", "--season=autumn", "--weather=storm", "--distant", "--nature-fast", "--cave=0.6", "--fire-world", "--creatures", "--walk"], 9000, [
        ("under the Low voice cap", r"sounds \d+/24 playing \(peak " + NUM, 1, 24),
    ]),
    ("audit_low_town", ["--hour=21", "--season=autumn", "--weather=storm", "--distant", "--nature-fast", "--cave=0.6", "--fire-world", "--creatures", "--town-sounds", "--walk"], 9000, [
        ("worst scene plus a busy town, within the Low cap plus the 0.25 s scan slack", r"sounds \d+/24 playing \(peak " + NUM, 1, 26),
    ]),
    ("audit_high", ["--quality=2", "--hour=21", "--season=autumn", "--weather=storm", "--distant", "--nature-fast", "--cave=0.6", "--fire-world", "--creatures", "--town-sounds", "--walk"], 9000, [
        ("under the High cap of 96", r"sounds \d+/96 playing \(peak " + NUM, 1, 96),
        ("High uses its room (more than Low's 24)", r"sounds \d+/96 playing \(peak " + NUM, 20, 96),
    ]),
    ("audit_ultra", ["--quality=3", "--hour=21", "--season=autumn", "--weather=storm", "--distant", "--nature-fast", "--cave=0.6", "--fire-world", "--creatures", "--town-sounds", "--walk"], 9000, [
        ("under the Ultra cap of 96", r"sounds \d+/96 playing \(peak " + NUM, 1, 96),
    ]),
    ("felling", ["--chop"], 7000, [
        ("trees fell", r"tree sounds: " + NUM + r" falls", 1, 10),
    ]),
    ("swim", ["--swim"], 6000, [
        ("splashes", r"swim sounds " + NUM + r" splashes", 1, 100000),
    ]),
    ("crafting", ["--craft-sounds"], 5000, [
        ("work sounds started", r"craft work sounds " + NUM + r", last", 1, 3),
    ]),
    ("placed", ["--placed"], 4500, [
        ("hooks played", r"placed sounds (\{[^}]*\})", 8, 20, "sum"),
        ("door, gate, hatch and chest open and close", r"structure check: " + NUM + r" uses", 8, 8),
        ("an unknown kind is refused", r"unknown (false)", 0, 1, "text"),
        ("lock, unlock and knock", r"lock and knock " + NUM, 3, 3),
        ("all of them played", r"played " + NUM + r", watched", 11, 11),
        ("a watched row plays only its flips near the player (open, close)", r"watched flips " + NUM, 2, 2),
        ("generated", r"last \w+_\d \((generated)\)", 0, 1, "text"),
    ]),
    ("workshop", ["--workshop"], 5500, [
        ("chop, split and plank", r"workshop sounds (\{[^}]*\})", 3, 3, "sum"),
        ("saw loop plays", r"saw loops " + NUM + r", last", 1, 1),
    ]),
    ("wear", ["--wear-sounds"], 4500, [
        ("tool warning, break and repair", r"wear sounds (\{[^}]*\})", 3, 3, "sum"),
    ]),
    ("cooking", ["--cooking"], 4500, [
        ("eaten or healed", r"eaten " + NUM, 7, 7),
        ("stomach growl", r"growls " + NUM, 1, 1),
        ("sizzle", r"sizzle " + NUM, 1, 1),
    ]),
    ("harvest", ["--gather"], 4500, [
        ("plants picked with sound", r"harvest sounds (\{[^}]*\})", 2, 40, "sum"),
        ("twist kinds known", r"\"twist\": " + NUM, 1, 1000),
    ]),
    ("treewind", ["--treewind"], 5500, [
        ("a loop plays", r"tree wind: .* playing (\w+) ", 0, 0, "text"),
    ]),
]


TIER_CAPS = [24, 48, 96, 96]            # Low, Medium, High, Ultra (sound_presets.gd)


def tier_cap(flags):
    for flag in flags:
        if flag.startswith("--quality="):
            return TIER_CAPS[min(int(flag.split("=")[1]), 3)]

    return LOW_VOICE_CAP


def numbers_in(text):
    return sum(float(x) for x in re.findall(r"-?\d+(?:\.\d+)?", text))


def run_scenario(name, flags, frames, checks, index, godot, verbose):
    port = PORT_BASE + index
    work = tempfile.mkdtemp(prefix="soundcheck_")
    server_log = open(os.path.join(work, "server.log"), "w")
    server = subprocess.Popen([godot, "--headless", "--path", ROOT, "scenes/terrain_server/terrain_server.tscn", "--",
                               "--port=%d" % port, "--store=%s" % os.path.join(work, "store"), "--quit-after=240"],
                              stdout=server_log, stderr=subprocess.STDOUT)
    time.sleep(12)
    out = ""

    try:
        client = subprocess.run([godot, "--headless", "--path", ROOT, "scenes/terrain_client/terrain_client.tscn", "--",
                                 "--port=%d" % port, "--cache=%s" % os.path.join(work, "cache"), "--quality=0",
                                 "--frames=%d" % frames] + flags,
                                capture_output=True, text=True, timeout=200)
        out = client.stdout + client.stderr
    except subprocess.TimeoutExpired as err:
        out = (err.stdout or b"").decode(errors="replace") if isinstance(err.stdout, bytes) else (err.stdout or "")
    finally:
        server.terminate()

        try:
            server.wait(timeout=20)
        except subprocess.TimeoutExpired:
            server.kill()

        server_log.close()

    problems = []

    if "SCRIPT ERROR" in out or "Parse Error" in out:
        problems.append("script error in the client log")

    peak = re.search(r"playing \(peak " + NUM + r"\)", out)

    if peak is None:
        problems.append("no sound budget line (the run did not reach its final report)")
    elif float(peak.group(1)) > tier_cap(flags) + VOICE_SCAN_SLACK:
        problems.append("voice peak %s over the cap %d" % (peak.group(1), tier_cap(flags)))

    refused = re.search(NUM + r" loads refused", out)

    if refused is not None and float(refused.group(1)) > 0:
        problems.append("%s sound loads refused (memory cap)" % refused.group(1))

    for check in checks:
        label, pattern, low, high = check[:4]
        mode = check[4] if len(check) > 4 else "number"
        match = re.search(pattern, out)

        if match is None:
            problems.append("%s: line not found" % label)
            continue

        if mode == "text":
            continue

        value = numbers_in(match.group(1)) if mode == "sum" else float(match.group(1))

        if not low <= value <= high:
            problems.append("%s: %g not in [%g, %g]" % (label, value, low, high))

    summary = "peak %s" % (peak.group(1) if peak else "?")

    if verbose or problems:
        with open(os.path.join(work, "client.log"), "w") as f:
            f.write(out)

        summary += " (logs in %s)" % work

    return problems, summary


def main():
    args = sys.argv[1:]
    only = []
    godot = GODOT

    if "--list" in args:
        print("slots      (offline) tools/slot_audit.py")
        for name, flags, frames, _ in SCENARIOS:
            print("%-10s %s (%d frames)" % (name, " ".join(flags), frames))

        return

    if "--only" in args:
        only = args[args.index("--only") + 1].split(",")

    if "--godot" in args:
        godot = args[args.index("--godot") + 1]

    verbose = "--verbose" in args
    failed = 0

    if not only or "steps_coverage" in only:                  # every ground, rock, ore and floor has steps and a loudness row
        started = time.time()
        run = subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "step_coverage.py")], capture_output=True, text=True)
        failed += 1 if run.returncode else 0
        print("%s  %-9s %s, %.0f s" % ("FAIL" if run.returncode else "PASS", "stepcov", run.stdout.strip().splitlines()[0] if run.stdout.strip() else run.stderr[-200:], time.time() - started))

        for line in [l for l in run.stdout.splitlines() if l.startswith("GAP")]:
            print("      - " + line)

    if not only or "slots" in only:                       # every sound file, offline: clipping, silence, loop seams, loudness
        started = time.time()
        run = subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "slot_audit.py")], capture_output=True, text=True)
        lines = [l for l in run.stdout.splitlines() if l.startswith("FAIL")]
        failed += 1 if run.returncode else 0
        print("%s  %-9s %s, %.0f s" % ("FAIL" if run.returncode else "PASS", "slots", run.stdout.strip().splitlines()[-1] if run.stdout.strip() else run.stderr[-200:], time.time() - started))

        for line in lines:
            print("      - " + line)

    for index, (name, flags, frames, checks) in enumerate(SCENARIOS):
        if only and name not in only:
            continue

        started = time.time()
        problems, summary = run_scenario(name, flags, frames, checks, index, godot, verbose)

        if any("did not reach its final report" in p for p in problems):
            # The headless server now and then dies at start (a thread-group error in terrain_server.gd); one retry.
            problems, summary = run_scenario(name, flags, frames, checks, index, godot, verbose)
            summary += ", after a retry"
        status = "FAIL" if problems else "PASS"
        failed += 1 if problems else 0
        print("%s  %-9s %s, %.0f s" % (status, name, summary, time.time() - started))

        for problem in problems:
            print("      - " + problem)

        sys.stdout.flush()

    print("%d scenario(s) failed" % failed if failed else "all sound scenarios passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
