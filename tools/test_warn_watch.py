#!/usr/bin/env python3
"""Cases for tools/warn_watch.py in a throwaway git repo: flags 1 and 2 warn, the 3rd blocks; with 3 flags in history every
change is blocked until the flagged lines are fixed; merge commits count once.
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
    expect("after 2 flags a clean change passes, warned of the lines to fix", n == 0 and "one more blocks" in out, out)
    n, out = pr("src/client/p3.gd", "func f():\n\tprint(3)\n")
    expect("the 3rd flag blocks, with the 2 earlier lines to fix", n == 3 and "blocks from 3" in out, out)
    change("src/client/p3.gd", "func f():\n\tprint(3)\n", "a 3rd flag landed anyway (an admin merge)")
    n, out = pr("docs/c.md", "plain words\n")
    expect("with 3 flags in history a clean change is blocked while the lines remain", n == 3, out)
    for i in range(1, 4):
        change(f"src/client/p{i}.gd", "func f():\n\tFreezeWatch.printer.line(\"x\")\n", f"fix {i}")
    n, out = pr("docs/d.md", "plain words\n")
    expect("once the flagged lines are fixed a clean change passes", n == 0, out)
    n, out = pr("src/client/p5.gd", "func f():\n\tprint(5)\n")
    expect("a blocking check stays blocking", n == 1, out)

    # Merge commits: a PR merged with --no-ff is one flag however many commits it has; a PR that merged dev in counts only its own lines.
    g("checkout", "-q", "-b", "feature", "dev")
    change("deploy/a.json", "{\"password\": \"hunter22secret\"}\n", "one")
    change("deploy/b.json", "{\"password\": \"hunter33secret\"}\n", "two")
    g("checkout", "-q", "dev"); g("merge", "-q", "--no-ff", "-m", "merge feature", "feature")
    g("checkout", "-q", "-b", "pr2", "dev~1")
    change("deploy/c.json", "{\"password\": \"hunter44secret\"}\n", "pr2 own")
    g("merge", "-q", "--no-edit", "dev")
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        n = ww.watch("dev", "HEAD")
    out = out.getvalue()
    expect("a --no-ff merge is one flag and a PR that merged dev counts once", n == 0 and "'secret': flag 2;" in out and "1 found" in out, out)
    expect("a secret's text stays out of the log", "hunter22secret" not in out, out)
    g("checkout", "-q", "dev")

print("test_warn_watch: " + ("PASS" if not bad else f"{bad} FAIL"))
sys.exit(1 if bad else 0)
