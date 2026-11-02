#!/usr/bin/env python3
"""List dead relative links in tracked .md files (outside docs/archive, docs/mirror, addons, .claude)."""
import re, subprocess, os, sys
files = subprocess.check_output(['git','ls-files','*.md'],text=True).split()
skip = ('docs/archive/','docs/mirror/','addons/','.claude/')
bad = 0
for f in files:
    if f.startswith(skip): continue
    txt = open(f, encoding='utf-8', errors='replace').read()
    for m in re.finditer(r'\]\(([^)#\s]+)(?:#[^)]*)?\)', txt):
        t = m.group(1)
        if re.match(r'[a-z]+:', t): continue
        p = os.path.normpath(os.path.join(os.path.dirname(f), t))
        if not os.path.exists(p):
            print(f'{f}: dead link {t}'); bad += 1
print(f'{bad} dead links'); sys.exit(1 if bad else 0)
