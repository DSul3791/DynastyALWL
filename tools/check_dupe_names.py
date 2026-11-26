#!/usr/bin/env python3
"""Static check (runs in CI via merge_check.py): a GDScript file may not declare the same top-level name twice
(var / const / func / signal / enum / class). This is the clash that broke the client in builds 750-753
(func water_debug vs var water_debug). Also a local `var` (or `for` name) declared again while the first is still in scope inside one
function: Godot refuses the whole script ("There is already a variable named pk declared in this scope", test_server_items on PR #1987,
26 Nov 2026), and gdparse does not see it. Prints problems and exits 1; no Godot needed."""
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

LOCAL = re.compile(r"^\t+(?:for\s+([A-Za-z_]\w*)\s+in\b|var\s+([A-Za-z_]\w*))")


def local_check(path):
    problems = []
    scopes = []   # [indent, {name: line}] from the function's body inward; a block's names go when the code goes back out of it
    in_text = False
    with open(path, encoding="utf-8", errors="replace") as f:
        for n, line in enumerate(f, 1):
            was_in_text = in_text
            if line.count('"""') % 2 == 1:
                in_text = not in_text
            if was_in_text or not line.strip() or line.lstrip().startswith("#"):
                continue
            indent = len(line) - len(line.lstrip("\t"))
            if indent == 0 or re.match(r"^\s*(?:static\s+)?func\s", line) or re.match(r"^\s*class\s", line):
                scopes = []   # a new function (or class): nothing of the last one is in scope
                continue
            while scopes and scopes[-1][0] > indent:
                scopes.pop()
            m = LOCAL.match(line)
            if not m:
                continue
            name = m.group(1) or m.group(2)
            for _, names in scopes:
                if name in names:
                    problems.append("%s:%d: local '%s' already declared at line %d in this scope" % (path, n, name, names[name]))
                    break
            if m.group(1):
                scopes.append([indent + 1, {name: n}])   # a for name lives in the loop's body
            else:
                if not scopes or scopes[-1][0] < indent:
                    scopes.append([indent, {}])
                scopes[-1][1][name] = n
    return problems

def main():
    files = subprocess.run(["git", "ls-files", "*.gd"], capture_output=True, text=True).stdout.split()
    problems = []
    for p in files:
        problems += check(p)
        problems += local_check(p)
    for p in problems:
        print(p)
    print("dupe names: %s" % ("FAILED (%d)" % len(problems) if problems else "ok"))
    return 1 if problems else 0

sys.exit(main())
