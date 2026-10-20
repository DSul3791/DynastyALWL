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
    ("rain_stone", ["--weather=rain", "--rain-ground=stone"], 5000, [
        ("stone weight", r"rain ground stone \(weights \{ \"stone\": " + NUM, 0.95, 1.0),
    ]),
    ("rain_snow", ["--weather=rain", "--rain-ground=snow"], 5000, [
        ("snow weight", r"rain ground snow \(weights \{ \"stone\": [\d.]+, \"mud\": [\d.]+, \"litter\": [\d.]+, \"snow\": " + NUM, 0.95, 1.0),
    ]),
    ("storm", ["--weather=storm", "--distant"], 5000, [
        ("storm weather", r"weather storm rain " + NUM, 0.9, 1.0),
        ("heard list names sounds", r"sounds heard \(" + NUM + r"\)", 2, 40),
        ("far thunder takes the far bus", r"thunder (thunder_far 2500 m, WeatherFar)", 0, 1, "text"),
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
        ("heaves played", r"gain down to [\d.]+, " + NUM + r" heaves", 3, 200),
        ("run completes", r"done (true)", 0, 1, "text"),
        ("no breathing while fainted", r"breaths while fainted " + NUM, 0, 0),
        ("world returns with the vision", r"wake mute " + NUM, 0.1, 0.9),
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
    ("stance", ["--stance"], 6000, [
        ("posture changes heard", r"stance check: " + NUM + r" changes", 6, 6),
        ("last is the rise", r"last (stance_rise)", 0, 1, "text"),
    ]),
    ("lake", ["--lake"], 9000, [
        ("soft laps, not a steady bed", r"lake laps: " + NUM + r" laps", 2, 8),
        ("brook is Dave's recording", r"brook loop (recorded)", 0, 1, "text"),
        ("laps are the slowed fish splash", r"last (lake_lap_\d)", 0, 1, "text"),
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
    elif float(peak.group(1)) > LOW_VOICE_CAP:
        problems.append("voice peak %s over the Low cap %d" % (peak.group(1), LOW_VOICE_CAP))

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
        for name, flags, frames, _ in SCENARIOS:
            print("%-10s %s (%d frames)" % (name, " ".join(flags), frames))

        return

    if "--only" in args:
        only = args[args.index("--only") + 1].split(",")

    if "--godot" in args:
        godot = args[args.index("--godot") + 1]

    verbose = "--verbose" in args
    failed = 0

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
