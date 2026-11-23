#!/usr/bin/env python3
"""Hard stops on a throwaway server store (coordinator 23 Nov 2026, before the live save goes over on Wednesday).

Starts a headless server on a spare local port with its own store, puts protocol-only bots on it (scenes/bot/bot_swarm.tscn: walk, dig,
chop, craft, build, fight), and kills the server with SIGKILL, round after round, on the same store:
  - "save" rounds wait until a save is being written (a .tmp file in the store, or the ground's SQLite journal) and kill it then;
  - "random" rounds kill at a random moment.
After every kill src/worldgen/tools/store_check.gd reads a copy of the store: it must load with no failures and read as one whole save
(no file past the header's gen). The next round's server must start on it. The last round asks for a clean stop (stop.now) with the bots
on, times it against docker's stop_grace_period (deploy/server/compose.yaml) and checks the store again.

  python3 tools/crash_drill.py [--rounds 12] [--bots 6] [--from-store DIR_OR_TAR] [--out DIR] [--godot godot]

Never point it at a live server or its volume: it makes its own store under --out. Exit 0 = every round held; 1 = a round broke a rule.
"""
import argparse, json, os, random, re, subprocess, sys, tarfile, tempfile, time

GRACE_S = 90.0   # deploy/server/compose.yaml stop_grace_period


def start_server(godot, store, port, log):
    out = open(log, "a")
    out.write("\n===== server start %s =====\n" % time.strftime("%H:%M:%S"))
    out.flush()
    proc = subprocess.Popen([godot, "--headless", "--rendering-driver", "dummy", "--path", ".", "res://scenes/terrain_server/terrain_server.tscn", "--",
                             "--port=%d" % port, "--store=%s" % store, "--open-admin", "--timeout=3600"], stdout=out, stderr=subprocess.STDOUT)
    t0 = time.time()
    while time.time() - t0 < 300:
        if proc.poll() is not None:
            return proc, None
        with open(log, errors="replace") as f:
            text = f.read()
        if text.rfind("server listening on port %d" % port) > text.rfind("===== server start"):
            return proc, time.time() - t0
        time.sleep(0.5)
    return proc, None


def start_bots(godot, port, bots, seconds, log, first):
    return subprocess.Popen([godot, "--headless", "--rendering-driver", "dummy", "--path", ".", "res://scenes/bot/bot_swarm.tscn", "--",
                             "--server=127.0.0.1", "--port=%d" % port, "--bots=%d" % bots, "--first=%d" % first, "--stagger-ms=400",
                             "--seconds=%d" % seconds, "--spread=0", "--timeout=%d" % (seconds + 120), "--work", "--fight", "--build", "--dig-every=5"],
                            stdout=open(log, "a"), stderr=subprocess.STDOUT)


def writing(store):
    """What of the store is being written right now, or ''."""
    for sub in ("", "world_items", "flora_removed"):
        d = os.path.join(store, sub)
        try:
            for e in os.scandir(d):
                if e.name.endswith(".tmp"):
                    return os.path.join(sub, e.name)
                if e.name.endswith("-journal") or e.name.endswith("-wal"):
                    return os.path.join(sub, e.name)
        except FileNotFoundError:
            pass
    return ""


def check_store(godot, store, log):
    r = subprocess.run([godot, "--headless", "--path", ".", "--script", "res://src/worldgen/tools/store_check.gd", "--", "--store=%s" % store],
                       capture_output=True, text=True, timeout=600)
    with open(log, "a") as f:
        f.write(r.stdout + r.stderr)
    for line in r.stdout.splitlines():
        if line.startswith("STORE "):
            return json.loads(line[6:]), r.returncode
    return {"error": "no STORE line"}, 2


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rounds", type=int, default=12)
    ap.add_argument("--bots", type=int, default=6)
    ap.add_argument("--from-store", default="")
    ap.add_argument("--out", default="")
    ap.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    ap.add_argument("--seed", type=int, default=1)
    a = ap.parse_args()
    random.seed(a.seed)
    out = a.out or tempfile.mkdtemp(prefix="crash_drill_")
    store = os.path.join(out, "store")
    os.makedirs(store, exist_ok=True)
    if a.from_store:
        if a.from_store.endswith((".tar.gz", ".tgz")):
            with tarfile.open(a.from_store) as t:
                top = t.getnames()[0].split("/")[0]
                t.extractall(out)
            os.rmdir(store)
            os.rename(os.path.join(out, top), store)
        else:
            subprocess.run(["cp", "-a", a.from_store + "/.", store], check=True)
    port = 7400 + random.randrange(400)
    slog = os.path.join(out, "server.log")
    blog = os.path.join(out, "bots.log")
    clog = os.path.join(out, "check.log")
    print("crash_drill: %d rounds, %d bots, store %s" % (a.rounds, a.bots, store), flush=True)
    broke = []
    rows = []
    expect_digs = None
    for r in range(a.rounds):
        last = r == a.rounds - 1
        mode = "clean stop" if last else ("save" if r % 3 != 2 else "random")
        proc, took = start_server(a.godot, store, port, slog)
        if took is None:
            broke.append("round %d: the server did not start on the store (see server.log)" % r)
            proc.kill()
            break
        if r > 0 and expect_digs is not None and expect_digs >= 0:
            with open(slog, errors="replace") as f:
                text = f.read()
            m = re.findall(r"server: (\d+) ground edits loaded from digs.dat", text[text.rfind("===== server start"):])
            if not m or int(m[-1]) != expect_digs:
                broke.append("round %d: the server kept %s ground edits, the last whole save covers %d" % (r, m[-1] if m else "?", expect_digs))
        bots = start_bots(a.godot, port, a.bots, 400, blog, 1 + r * 100)
        warm = random.uniform(25, 60)
        time.sleep(warm)
        hit = ""
        t_stop = 0.0
        if mode == "save":
            t0 = time.time()
            while time.time() - t0 < 90 and hit == "":
                hit = writing(store)
                if hit == "":
                    time.sleep(0.001)
            proc.kill()   # SIGKILL on Linux, TerminateProcess on Windows: a hard stop either way
        elif mode == "random":
            time.sleep(random.uniform(0, 30))
            hit = writing(store)
            proc.kill()   # SIGKILL on Linux, TerminateProcess on Windows: a hard stop either way
        else:
            t0 = time.time()
            open(os.path.join(store, "stop.now"), "w").close()
            try:
                proc.wait(timeout=GRACE_S + 30)
            except subprocess.TimeoutExpired:
                proc.kill()
            t_stop = time.time() - t0
        proc.wait()
        bots.kill()
        bots.wait()
        state, rc = check_store(a.godot, store, clog)
        expect_digs = state.get("header_digs")
        row = {"round": r, "mode": mode, "start_s": round(took, 1), "killed_while": hit, "stop_s": round(t_stop, 1),
               "header_gen": state.get("header_gen"), "header_digs": state.get("header_digs"), "digs_in_log": state.get("digs_in_log"), "past_header": state.get("past_header"), "load_failures": state.get("load_failures"),
               "players": state.get("players"), "chests": state.get("chests"), "world_items": state.get("world_items"),
               "items": sum(int(v) for v in state.get("totals", {}).values()), "store_kb": int(subprocess.run(["du", "-sk", store], capture_output=True, text=True).stdout.split()[0])}
        rows.append(row)
        print("round %d %-10s start %5.1fs  killed while %-34s header %s  digs %s/%s  players %s chests %s items %s  %s" % (
            r, mode, took, hit or "-", row["header_gen"], row["header_digs"], row["digs_in_log"], row["players"], row["chests"], row["items"],
            ("stop %.1fs" % t_stop) if last else ""), flush=True)
        if rc != 0:
            broke.append("round %d: the store does not read as one whole save: %s" % (r, json.dumps(state)[:600]))
        if last and state.get("header_digs", -1) >= 0 and state.get("header_digs") != state.get("digs_in_log"):
            broke.append("round %d: after the clean stop the header covers %s ground edits, the log holds %s" % (r, state.get("header_digs"), state.get("digs_in_log")))
        if last and t_stop > GRACE_S:
            broke.append("round %d: the clean stop took %.1f s, past docker's %d s" % (r, t_stop, GRACE_S))
    with open(slog, errors="replace") as f:
        text = f.read()
    for bad in ("SERVER SAVE FAILED", "is damaged", "SCRIPT ERROR", "has no usable earlier copy"):
        if bad in text:
            broke.append("server.log has %d lines with %r" % (text.count(bad), bad))
    with open(os.path.join(out, "rounds.json"), "w") as f:
        json.dump(rows, f, indent=1)
    print("crash_drill: %s (%s)" % ("PASS" if not broke else "FAIL", out))
    for b in broke:
        print("  " + b)
    return 0 if not broke else 1


if __name__ == "__main__":
    sys.exit(main())
