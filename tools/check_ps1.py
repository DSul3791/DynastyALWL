"""Checks every tracked PowerShell script for mistakes that stop Windows PowerShell 5.1 (Dave's PC) before a line runs.

No PowerShell runs in the cloud or on the Linux lanes, so these are text checks (22 Nov 2026: release_first_run.ps1 reached Dave's
PC with "exit $code:" in a string, which 5.1 refuses to parse: InvalidVariableReferenceWithDrive):
- "$name:" where name is not a scope or drive PowerShell knows (env, script, global, ...): write "${name}:" or "$($name):".
- A file with non-ASCII text and no UTF-8 byte order mark: 5.1 reads it as the ANSI code page, so a dash or quote mark breaks strings.
    python3 tools/check_ps1.py          exit 1 and one line per problem
"""
import re, subprocess, sys

SCOPES = {"env", "script", "global", "local", "private", "using", "variable", "function", "alias"}
VAR_COLON = re.compile(r'(?<!`)\$([A-Za-z_][A-Za-z0-9_]*):(?!:)')

files = [f for f in subprocess.run(["git", "ls-files", "-z", "*.ps1"], capture_output=True, text=True, check=True).stdout.split("\0") if f]
problems = []
for path in files:
    raw = open(path, "rb").read()
    if not raw.startswith(b"\xef\xbb\xbf") and any(b > 127 for b in raw):
        problems.append("%s: non-ASCII text without a UTF-8 byte order mark (Windows PowerShell 5.1 misreads it)" % path)
    for number, line in enumerate(raw.decode("utf-8", "replace").splitlines(), 1):
        code = line.split("#", 1)[0] if line.lstrip().startswith("#") else line
        for match in VAR_COLON.finditer(code):
            if match.group(1).lower() not in SCOPES:
                problems.append("%s:%d: \"$%s:\" does not parse in PowerShell; write ${%s}: or $(%s):" % (path, number, match.group(1), match.group(1), "$" + match.group(1)))

for p in problems:
    print(p)
sys.exit(1 if problems else 0)
