#!/usr/bin/env python3
"""Shader source lint, no Godot needed (Tyler, 5 Nov 2026, after #416 broke GREENS_SHADER with a '#' comment).
Headless runs never compile shaders, so a shader that fails to compile passes every gate and only shows as
"SHADER ERROR ... Unknown character #35" in a windowed client. This catches the common cause before merge:
a '#' in shader code (a whole-line or end-of-line comment) that is not a line-start preprocessor directive (#define, #if ...).
Shader code = every .gdshader / .gdshaderinc file, and every triple-quoted string in a .gd file that holds "shader_type".
  python3 tools/check_shader_comments.py      exit 0 = clean, exit 1 = problems listed (one per line: file:line: text)"""
import re, subprocess, sys

DIRECTIVES = ("define", "undef", "include", "if", "ifdef", "ifndef", "elif", "else", "endif", "pragma", "error")
HASH_LINE = re.compile(r"^\s*#\s*(\w*)")
TRIPLE = re.compile(r'("""|\'\'\')(.*?)\1', re.S)


def bad_lines(code, first_line):
    # blank out /* */ blocks (keeping newlines so line numbers hold), then drop // comments per line
    code = re.sub(r"/\*.*?\*/", lambda m: re.sub(r"[^\n]", " ", m.group(0)), code, flags=re.S)
    out = []
    for i, line in enumerate(code.split("\n")):
        line = line.split("//", 1)[0]
        if "#" not in line:
            continue
        m = HASH_LINE.match(line)
        if m and m.group(1) in DIRECTIVES and "#" not in line[m.end():]:
            continue
        out.append((first_line + i, line.strip()[:80]))
    return out


def main():
    files = subprocess.run(["git", "ls-files", "*.gd", "*.gdshader", "*.gdshaderinc"], capture_output=True, text=True).stdout.split()
    found = []
    for f in files:
        try:
            txt = open(f, encoding="utf-8", errors="ignore").read()
        except OSError:
            continue
        if f.endswith(".gd"):
            if "shader_type" not in txt:
                continue
            for m in TRIPLE.finditer(txt):
                body = m.group(2)
                if "shader_type" in body:
                    start = txt.count("\n", 0, m.start(2)) + 1
                    found += [(f, n, s) for n, s in bad_lines(body, start)]
        else:
            found += [(f, n, s) for n, s in bad_lines(txt, 1)]
    for f, n, s in found:
        print("%s:%d: '#' comment in shader code (use //): %s" % (f, n, s))
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
