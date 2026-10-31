#!/usr/bin/env python3
"""Read-only report of the Godot processes on this PC (Tyler, 31 Oct 2026): age, memory, what it is, and a guess at who owns it. Kills nothing.
   python3 tools/stale_processes.py [--min-age 30]      lists processes older than N minutes (default 30), oldest first, then a summary
Owner guess: the worktree folder named in the command line (.claude/worktrees/<name>), else the --path folder. Kind: server (terrain_server), client (terrain_client),
script (--script / -s, with the test name), import, editor. 'stale' = a server or client older than 60 min, or any script older than 30 min (a test takes seconds to minutes).
Needs Windows PowerShell (Get-CimInstance); on other systems it uses ps."""
import json, os, re, subprocess, sys, time

PS = "Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'godot*' } | Select-Object ProcessId, ParentProcessId, CreationDate, WorkingSetSize, CommandLine | ConvertTo-Json -Compress"


def rows():
    if os.name == "nt":
        out = subprocess.run(["powershell", "-NoProfile", "-Command", PS], capture_output=True, text=True).stdout.strip()
        data = json.loads(out) if out else []
        data = data if isinstance(data, list) else [data]
        now = time.time()
        for d in data:
            m = re.search(r"/Date\((\d+)\)/", str(d.get("CreationDate", "")))
            started = int(m.group(1)) / 1000.0 if m else now
            yield int(d["ProcessId"]), int(d.get("ParentProcessId") or 0), (now - started) / 60.0, int(d.get("WorkingSetSize") or 0) / 1048576.0, d.get("CommandLine") or ""
    else:
        out = subprocess.run(["ps", "-eo", "pid,ppid,etimes,rss,args"], capture_output=True, text=True).stdout.splitlines()[1:]
        for line in out:
            parts = line.split(None, 4)
            if len(parts) == 5 and "godot" in parts[4].lower():
                yield int(parts[0]), int(parts[1]), int(parts[2]) / 60.0, int(parts[3]) / 1024.0, parts[4]


def describe(cmd):
    owner = ""
    m = re.search(r"worktrees[\/]([^\/\s\"]+)", cmd)
    if m:
        owner = m.group(1)
    else:
        m = re.search(r"--path\s+\"?([^\s\"]+)", cmd)
        owner = os.path.basename(m.group(1).rstrip("\/")) if m else "?"
    if "terrain_server" in cmd:
        kind = "server"
    elif "terrain_client" in cmd:
        kind = "client"
    elif "--import" in cmd:
        kind = "import"
    elif "--script" in cmd or re.search(r"\s-s\s", cmd):
        m = re.search(r"([A-Za-z0-9_]+)\.gd", cmd)
        kind = "script " + (m.group(1) if m else "")
    else:
        kind = "godot"
    return owner, kind


def main():
    min_age = 30.0
    if "--min-age" in sys.argv:
        min_age = float(sys.argv[sys.argv.index("--min-age") + 1])
    found = sorted(rows(), key=lambda r: -r[2])
    stale = 0
    print("%7s %7s %8s  %-28s %-22s %s" % ("pid", "parent", "age min", "owner (guess)", "kind", "MB  command"))
    for pid, parent, age, mb, cmd in found:
        owner, kind = describe(cmd)
        is_stale = (kind in ("server", "client") and age > 60) or (kind.startswith("script") and age > 30) or (kind == "import" and age > 15)
        stale += 1 if is_stale else 0

        if age >= min_age or is_stale:
            print("%7d %7d %8.0f  %-28s %-22s %4.0f  %s%s" % (pid, parent, age, owner[:28], kind[:22], mb, "STALE " if is_stale else "", cmd[:110].replace("\n", " ")))
    print("%d Godot processes, %d look stale (nothing was killed). Ask the owner, or stop one by hand: taskkill /T /F /PID <pid>" % (len(found), stale))
    return 0


if __name__ == "__main__":
    sys.exit(main())
