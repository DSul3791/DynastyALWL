# R9 follow-up (#1108): the static reach check behind the second catalog recheck.
# tools/encyclopedia_reach.py does not know the self-running smelters (structures.json "smelting"), so this wraps its reach
# model and adds one step: a built smelting structure whose jobs' inputs are held, with any smelting fuel held, gives the job's output.
# Usage: python3 docs/ai-team/missions/GOALS-REPAIR/r9_reach_with_smelters.py <repo root> [out.json]
# Output: {"have": {item id: reachable from an empty character}, "built": {structure kind: how it was reached}}. Static read of the data, not play.
# shortcut: a mission tool, not a repo tool; retire it when encyclopedia_reach.py models the smelters itself.
import importlib.util
import json
import sys

ROOT = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else None
spec = importlib.util.spec_from_file_location("er", ROOT + "/tools/encyclopedia_reach.py")
er = importlib.util.module_from_spec(spec)
sys.argv = [sys.argv[0]]
spec.loader.exec_module(er)
Reach = [v for v in vars(er).values() if isinstance(v, type) and hasattr(v, "step") and hasattr(v, "run")][0]
cfg = json.load(open(ROOT + "/data/items/structures.json"))["smelting"]
orig = Reach.step


def step(self):
    changed = orig(self)
    fuel = any(self.has(f) for f in cfg["fuel"])

    for kind in list(self.built):
        d = self.structures[kind]

        if d.get("use") != "smelt" or not fuel:
            continue

        for j in d["smelt"]["jobs"]:
            job = cfg["jobs"][j]

            if all(self.has(i[0]) for i in job["in"]):
                changed |= self.give(job["out"][0], "smelting job %s at %s" % (j, kind))

    return changed


Reach.step = step
r = Reach()
r.run()
result = {"have": {iid: r.has(iid) for iid in r.all}, "built": dict(r.built)}

if OUT:
    with open(OUT, "w") as f:
        json.dump(result, f)
else:
    json.dump(result, sys.stdout)
