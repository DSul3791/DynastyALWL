#!/usr/bin/env python3
"""Cases for tools/hooks/agent_warn.py: the commit checks find a client print and a key and stay quiet on clean changes.
    python3 -I tools/test_agent_warn.py
"""
import importlib.util, pathlib, subprocess, sys, tempfile

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("agent_warn", HERE / "hooks" / "agent_warn.py")
aw = importlib.util.module_from_spec(spec)
spec.loader.exec_module(aw)


def run(files):
    with tempfile.TemporaryDirectory() as d:
        root = pathlib.Path(d)
        g = lambda *a: subprocess.run(["git", *a], cwd=root, check=True, capture_output=True)
        g("init", "-q"); g("config", "user.email", "t@t"); g("config", "user.name", "t")
        (root / "README.md").write_text("x\n"); g("add", "."); g("commit", "-q", "-m", "base")
        for rel, text in files.items():
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            (root / rel).write_text(text)
        g("add", ".")
        aw.ROOT = root
        return aw.commit_findings()


CASES = [
    ("clean client change", {"src/client/a.gd": "func f():\n\tFreezeWatch.printer.line(\"x\")\n"}, 0),
    ("bare print in client", {"src/client/a.gd": "func f():\n\tprint(\"x\")\n"}, 1),
    ("print in a tool is fine", {"src/worldgen/tools/t.gd": "func f():\n\tprint(\"x\")\n"}, 0),
    ("password value", {"deploy/x.json": "{\"password\": \"hunter22secret\"}\n"}, 1),
    ("password word alone is fine", {"docs/a.md": "set the server password by hand\n"}, 0),
    ("private file", {"data/admin.json": "{}\n"}, 1),
    ("github token", {"docs/b.md": "ghp_" + "a" * 36 + "\n"}, 1),
]

bad = 0
for name, files, want in CASES:
    got = len(run(files))
    if got != want:
        bad += 1
        print(f"FAIL {name}: {got} findings, wanted {want}")
print("test_agent_warn: " + ("PASS" if not bad else f"{bad} FAIL"))
sys.exit(1 if bad else 0)
