#!/usr/bin/env python3
"""Static check (runs in CI via merge_check.py): a GDScript file may not declare the same top-level name twice
(var / const / func / signal / enum / class). This is the clash that broke the client in builds 750-753
(func water_debug vs var water_debug). Prints problems and exits 1; no Godot needed."""
import re, subprocess, sys

DECL = re.compile(r"^(?:static\s+)?(var|const|func|signal|enum|class)\s+([A-Za-z_]\w*)")

def check(path):
    seen = {}
    problems = []
    in_text = False  # inside a triple-quoted string (shader source and the like)
    with open(path, encoding="utf-8", errors="replace") as f:
        for n, line in enumerate(f, 1):
            was_in_text = in_text
            if line.count('"""') % 2 == 1:
                in_text = not in_text
            if was_in_text:
                continue
            m = DECL.match(line)  # top level only: column 0
            if not m:
                m2 = re.match(r"^@export(?:_\w+)?(?:\([^)]*\))?\s+var\s+([A-Za-z_]\w*)", line) or re.match(r"^@onready\s+var\s+([A-Za-z_]\w*)", line)
                if m2:
                    m = re.match(r"(var)\s+(.*)", "var " + m2.group(1))
                else:
                    continue
            kind, name = m.group(1), m.group(2)
            if name in seen:
                problems.append("%s:%d: '%s' (%s) already declared at line %d (%s)" % (path, n, name, kind, seen[name][1], seen[name][0]))
            else:
                seen[name] = (kind, n)
    return problems

def main():
    files = subprocess.run(["git", "ls-files", "*.gd"], capture_output=True, text=True).stdout.split()
    problems = []
    for p in files:
        problems += check(p)
    for p in problems:
        print(p)
    print("dupe names: %s" % ("FAILED (%d)" % len(problems) if problems else "ok"))
    return 1 if problems else 0

sys.exit(main())
