#!/usr/bin/env python3
"""Summary of one server load test (tools/load_test.sh writes the folder): python3 tools/load_report.py OUT_DIR BOTS [--json]

Reads OUT_DIR/server.log (TELEMETRY and PROFILE lines of a server started with --profile), server_proc.txt (CPU ticks and memory every
2 s), the swarm logs (BOT lines) and the stop timing. The steady part is the seconds when every bot was connected.
"""
import glob
import json
import os
import re
import sys

STATE = re.compile(r"max gap (\d+) ms.*?\| peers (\d+) fps (\d+) ram (\d+) MB.*?in the last second: sent (\d+) pkts (\d+) KB, received (\d+) pkts (\d+) KB")
PROFILE = re.compile(r"PROFILE window_us=(\d+) frames=(\d+) \| (.*)")


def pct(values, p):
    if not values:
        return -1
    values = sorted(values)
    return values[min(int(len(values) * p), len(values) - 1)]


def read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def main():
    out, bots = sys.argv[1], int(sys.argv[2])
    log = read(os.path.join(out, "server.log")).splitlines()
    seconds, profiles, stalls, slow_rpcs = [], [], [], []
    for line in log:
        if "TELEMETRY" not in line:
            continue
        m = STATE.search(line)
        if m:
            seconds.append([int(x) for x in m.groups()])
            continue
        m = PROFILE.search(line)
        if m:
            phases = {}
            for part in m.group(3).split(" ; "):
                if "=" in part:
                    name, val = part.rsplit("=", 1)
                    s, mx = val.split("/")
                    phases[name.strip()] = (int(s), int(mx))
            profiles.append((int(m.group(1)), int(m.group(2)), phases, None))
            continue
        if "STALL" in line:
            stalls.append(int(re.search(r"for (\d+) ms", line).group(1)) if re.search(r"for (\d+) ms", line) else 0)
        if "SLOW RPC" in line:
            slow_rpcs.append(line.split("SLOW RPC", 1)[1].strip())
    # profiles get the peer count of the second before them (they are written in the same stream)
    peers_now, tagged = 0, []
    pi = 0
    for line in log:
        if "TELEMETRY" not in line:
            continue
        m = STATE.search(line)
        if m:
            peers_now = int(m.group(2))
        elif PROFILE.search(line) and pi < len(profiles):
            w, f, ph, _ = profiles[pi]
            tagged.append((w, f, ph, peers_now))
            pi += 1
    steady = [s for s in seconds if s[1] >= bots]
    steady_prof = [p for p in tagged if p[3] >= bots]
    r = {"bots": bots, "seconds_logged": len(seconds), "steady_seconds": len(steady)}
    use = steady if steady else seconds
    gaps = [s[0] for s in use]
    r["frame_gap_ms"] = {"p50": pct(gaps, 0.5), "p95": pct(gaps, 0.95), "p99": pct(gaps, 0.99), "max": max(gaps) if gaps else -1,
                         "seconds_over_100": sum(g >= 100 for g in gaps), "seconds_over_250": sum(g >= 250 for g in gaps)}
    r["fps_median"] = pct([s[2] for s in use], 0.5)
    rams = [s[3] for s in seconds]
    r["static_ram_mb"] = {"first": rams[0] if rams else -1, "steady_first": use[0][3] if use else -1, "last": rams[-1] if rams else -1, "max": max(rams) if rams else -1}
    sent = [s[5] for s in use]
    recv = [s[7] for s in use]
    r["traffic_kb_s"] = {"sent_mean": round(sum(sent) / len(sent), 1) if sent else -1, "sent_p95": pct(sent, 0.95), "sent_max": max(sent) if sent else -1,
                         "received_mean": round(sum(recv) / len(recv), 1) if recv else -1,
                         "sent_per_player_mean": round(sum(sent) / len(sent) / bots, 2) if sent and bots else -1}
    # frame steps: ms per second of wall time, and the longest single run
    totals, longest, window = {}, {}, 0
    for w, f, ph, _ in (steady_prof if steady_prof else tagged):
        window += w
        for name, (s, mx) in ph.items():
            totals[name] = totals.get(name, 0) + s
            longest[name] = max(longest.get(name, 0), mx)
    busy = sum(v for k, v in totals.items() if not k.startswith("between frames"))
    r["main_thread_busy_pct"] = round(100.0 * busy / window, 1) if window else -1
    r["steps_ms_per_s"] = {k: [round(1000.0 * v / window, 2), round(longest[k] / 1000.0, 1)] for k, v in sorted(totals.items(), key=lambda kv: -kv[1])} if window else {}
    r["stalls_over_500ms"] = len(stalls)
    r["worst_stall_ms"] = max(stalls) if stalls else 0
    r["slow_rpcs"] = slow_rpcs[:12]
    r["slow_rpc_count"] = len(slow_rpcs)
    # CPU and memory of the process
    proc = [l.split() for l in read(os.path.join(out, "server_proc.txt")).splitlines() if len(l.split()) >= 4]
    try:
        t0 = float(read(os.path.join(out, "bots_start.txt")).strip()) + 30.0
        t1 = float(read(os.path.join(out, "bots_end.txt")).strip())
    except ValueError:
        t0, t1 = 0.0, 1e18
    win = [p for p in proc if t0 <= float(p[0]) <= t1]
    if len(win) >= 2:
        hz = float(win[0][2])
        r["server_cpu_cores"] = round((int(win[-1][1]) - int(win[0][1])) / hz / (float(win[-1][0]) - float(win[0][0])), 2)
        r["rss_mb"] = {"steady_first": int(win[0][3]) // 1024, "steady_last": int(win[-1][3]) // 1024, "max": max(int(p[3]) for p in proc) // 1024,
                       "growth_mb_per_min": round((int(win[-1][3]) - int(win[0][3])) / 1024.0 / ((float(win[-1][0]) - float(win[0][0])) / 60.0), 1)}
        r["threads"] = int(win[-1][4]) if len(win[-1]) > 4 else -1
    try:
        r["closing_save_s"] = round(float(read(os.path.join(out, "server_gone.txt"))) - float(read(os.path.join(out, "stop_asked.txt"))), 1)
    except ValueError:
        r["closing_save_s"] = -1
    r["store_kb"] = int(read(os.path.join(out, "store_kb.txt")).strip() or -1)
    # what the bots saw
    bot_lines = []
    for path in glob.glob(os.path.join(out, "swarm_*.log")):
        bot_lines += [l for l in read(path).splitlines() if l.startswith("BOT ")]
    stats = [l for l in bot_lines if "pulses" in l]
    hb = [int(m.group(1)) for l in stats for m in [re.search(r"worst heartbeat gap (\d+) ms", l)] if m]
    med = [int(m.group(1)) for l in stats for m in [re.search(r"block wait median (-?\d+) ms", l)] if m]
    p95 = [int(m.group(1)) for l in stats for m in [re.search(r"p95 (-?\d+) ms", l)] if m]
    unanswered = sum(int(m.group(1)) for l in stats for m in [re.search(r"still unanswered (\d+)", l)] if m)
    work = [l for l in bot_lines if "work sent" in l]
    def total(key):
        return sum(int(m.group(1)) for l in work for m in [re.search(key + r" (\d+)", l)] if m)
    r["bots_seen"] = {"finished": len(stats), "joined": sum(1 for l in stats if "pulses 0" not in l), "worst_heartbeat_gap_ms": max(hb) if hb else -1,
                      "block_wait_median_of_medians_ms": pct(med, 0.5), "block_wait_worst_p95_ms": max(p95) if p95 else -1, "blocks_unanswered": unanswered,
                      "problems": [l for l in bot_lines if "pulses" not in l and "work sent" not in l][:8]}
    r["bot_actions"] = {"digs": total("digs"), "axe_blows": total("axe blows"), "crafts": total("twine crafts"), "strikes": total("spear strikes"),
                        "blueprints": total("blueprints"), "animal_updates": total("animal updates")}
    if "--json" in sys.argv:
        print(json.dumps(r, indent=1))
        return
    g = r["frame_gap_ms"]
    print(f"LOAD {bots} bots: steady {r['steady_seconds']} s of {r['seconds_logged']}; frame gap p50 {g['p50']} p95 {g['p95']} p99 {g['p99']} max {g['max']} ms; "
          f"seconds with a gap >= 100 ms {g['seconds_over_100']}, >= 250 ms {g['seconds_over_250']}; fps {r['fps_median']}; main thread busy {r['main_thread_busy_pct']}%")
    print(f"  cpu {r.get('server_cpu_cores', '?')} cores, rss {r.get('rss_mb', {})}, threads {r.get('threads', '?')}, static ram MB {r['static_ram_mb']}")
    t = r["traffic_kb_s"]
    print(f"  sent {t['sent_mean']} KB/s (p95 {t['sent_p95']}, max {t['sent_max']}), {t['sent_per_player_mean']} KB/s per player; received {t['received_mean']} KB/s")
    print(f"  stalls over 500 ms {r['stalls_over_500ms']} (worst {r['worst_stall_ms']} ms), slow rpcs {r['slow_rpc_count']}; closing save {r['closing_save_s']} s; store {r['store_kb']} KB")
    print("  steps ms per s [mean, longest single ms]: " + ", ".join(f"{k} {v}" for k, v in list(r["steps_ms_per_s"].items())[:10]))
    print(f"  bots {r['bots_seen']}")
    print(f"  actions {r['bot_actions']}")
    for s in r["slow_rpcs"]:
        print("  slow rpc: " + s)


if __name__ == "__main__":
    main()
