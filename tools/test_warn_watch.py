#!/usr/bin/env python3
"""Cases for tools/warn_watch.py in a throwaway git repo: a problem line is flagged each time a change touches its file; the 3rd
flag blocks until it is fixed or removed, and then its count is gone; keys and passwords block on first sight; merge commits count once.
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
    C = "src/client/a.gd"
    PRINT = "func f():\n\tprint(1)\n"

    def change(rel, text, msg):
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
        g("add", "."); g("commit", "-q", "-m", msg)

    def run():
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            n = ww.watch("dev", "HEAD")
        return n, out.getvalue()

    def pr(rel, text):
        """A change on a branch off dev; returns (blocking, output) and leaves dev checked out."""
        g("checkout", "-q", "-b", "pr", "dev")
        change(rel, text, "pr")
        n, out = run()
        g("checkout", "-q", "dev"); g("branch", "-q", "-D", "pr")
        return n, out

    n, out = pr("docs/a.md", "plain words\n")
    expect("clean change", n == 0 and "0 problems" in out, out)
    n, out = pr(C, PRINT)
    expect("a new problem is flag 1 and only warns", n == 0 and "(flag 1;" in out, out)
    change(C, PRINT, "merged with the print")
    n, out = pr("src/client/b.gd", "func g():\n\tpass\n")
    expect("a change to another file does not flag it", n == 0 and "0 problems" in out, out)
    change("src/client/b.gd", "func g():\n\tpass\n", "merged other file")
    n, out = pr(C, PRINT + "func h():\n\tpass\n")
    expect("touching its file again is flag 2, still a warning", n == 0 and "(flag 2;" in out, out)
    change(C, PRINT + "func h():\n\tpass\n", "merged a second touch")
    n, out = pr(C, PRINT + "func h():\n\tpass\nfunc k():\n\tpass\n")
    expect("the 3rd touch is blocked until it is fixed", n == 1 and "flag 3: blocked" in out, out)
    n, out = pr(C, "func f():\n\tFreezeWatch.printer.line(\"x\")\nfunc h():\n\tpass\n")
    expect("fixing it in that change passes: handled", n == 0 and "0 problems" in out, out)
    change(C, "func f():\n\tFreezeWatch.printer.line(\"x\")\n", "fixed")
    n, out = pr(C, "func f():\n\tFreezeWatch.printer.line(\"x\")\n\tprint(2)\n")
    expect("a new print in the same file starts its own count", n == 0 and "(flag 1;" in out, out)

    n, out = pr("deploy/a.json", "{\"password\": \"hunter22secret\"}\n")
    expect("a password blocks on first sight", n == 1 and "first sight" in out, out)
    expect("a secret's text stays out of the log", "hunter22secret" not in out, out)
    n, out = pr("src/worldgen/tools/test_x.gd", "const ADMIN_KEY := \"admincheck001\"\n")
    expect("a test's made-up key is not flagged", n == 0, out)

    # Merge commits: a PR merged with --no-ff is one touch however many commits it has; a PR that merged dev in counts its own touch once.
    g("checkout", "-q", "-b", "feature", "dev")
    change("src/client/m.gd", "func f():\n\tprint(1)\n", "one")
    change("src/client/m.gd", "func f():\n\tprint(1)\nfunc g():\n\tpass\n", "two")
    g("checkout", "-q", "dev"); g("merge", "-q", "--no-ff", "-m", "merge feature", "feature")
    g("checkout", "-q", "-b", "pr2", "dev~1")
    change("src/client/m2.gd", "x\n", "pr2 base")
    g("merge", "-q", "--no-edit", "dev")
    change("src/client/m.gd", "func f():\n\tprint(1)\nfunc g():\n\tpass\nfunc k():\n\tpass\n", "pr2 touches m")
    n, out = run()
    expect("a --no-ff merge is one touch and a PR that merged dev counts once", n == 0 and "(flag 2;" in out, out)
    g("checkout", "-q", "dev")

print("test_warn_watch: " + ("PASS" if not bad else f"{bad} FAIL"))
sys.exit(1 if bad else 0)
