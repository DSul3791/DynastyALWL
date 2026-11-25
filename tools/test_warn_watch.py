#!/usr/bin/env python3
"""Cases for tools/warn_watch.py in a throwaway git repo: flags 1 and 2 warn, the 3rd blocks, and after that every earlier flagged
line must be fixed.
    python3 -I tools/test_warn_watch.py
"""
import contextlib, importlib.util, io, pathlib, subprocess, sys, tempfile

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("warn_watch", HERE / "warn_watch.py")
ww = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ww)

bad = 0


def expect(name, ok, detail=""):
    global bad
    if not ok:
        bad += 1
        print(f"FAIL {name} {detail}")


with tempfile.TemporaryDirectory() as d:
    root = pathlib.Path(d)
    g = lambda *a: subprocess.run(["git", *a], cwd=root, check=True, capture_output=True, text=True).stdout
    g("init", "-q", "-b", "dev"); g("config", "user.email", "t@t"); g("config", "user.name", "t")
    (root / "README.md").write_text("x\n"); g("add", "."); g("commit", "-q", "-m", "base")
    ww.ROOT = root
    ww.START = "2000-01-01T00:00:00Z"   # the throwaway commits are made now

    def change(rel, text, msg):
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
        g("add", "."); g("commit", "-q", "-m", msg)

    def pr(rel, text):
        """A change on a branch off dev; returns (blocking, output) and leaves dev checked out."""
        g("checkout", "-q", "-b", "pr", "dev")
        change(rel, text, "pr")
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            n = ww.watch("dev", "HEAD")
        g("checkout", "-q", "dev"); g("branch", "-q", "-D", "pr")
        return n, out.getvalue()

    n, out = pr("docs/a.md", "plain words\n")
    expect("clean change", n == 0 and "0 found" in out, out)
    for i in range(1, 3):
        n, out = pr(f"src/client/p{i}.gd", f"func f():\n\tprint({i})\n")
        expect(f"flag {i} only warns", n == 0 and f"flag {i}; it blocks at 3" in out, out)
        change(f"src/client/p{i}.gd", f"func f():\n\tprint({i})\n", f"merged flag {i}")
    n, out = pr("docs/b.md", "plain words\n")
    expect("clean change after 2 flags passes", n == 0, out)
    n, out = pr("src/client/p3.gd", "func f():\n\tprint(3)\n")
    expect("the 3rd flag blocks, with the 2 earlier lines to fix", n == 3 and "now blocks" in out, out)
    n, out = pr("src/client/s.gd", "const ADMIN_KEY := \"abcdefgh\"\n")
    expect("another check keeps its own count", n == 0 and "'secret': flag 1; it blocks at 3" in out, out)
    for i in range(1, 3):
        change(f"src/client/p{i}.gd", "func f():\n\tFreezeWatch.printer.line(\"x\")\n", f"fix {i}")
    n, out = pr("docs/c.md", "plain words\n")
    expect("once the flagged lines are fixed a clean change passes", n == 0, out)
    n, out = pr("src/client/p5.gd", "func f():\n\tprint(5)\n")
    expect("a blocking check stays blocking", n == 1, out)

print("test_warn_watch: " + ("PASS" if not bad else f"{bad} FAIL"))
sys.exit(1 if bad else 0)
