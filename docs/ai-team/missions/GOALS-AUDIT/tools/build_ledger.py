#!/usr/bin/env python3
"""GOALS-AUDIT: merge the static passes, the workstream results and the lead's findings into
docs/design/PLAYER_GOALS_AUDIT_LEDGER.csv, then validate it.

Inputs (work/): goals_parsed.json, pass2_deps.json, ws_acquisition.json, ws_runtime.json, ws_catalog.json,
ws_economy.json, lead_findings.json (finding id -> {severity, type, goals[], status_effect, correction, test}).
Usage: python3 build_ledger.py <repo_root> <work_dir>
"""
import csv, json, os, sys, collections, io

ROOT, W = sys.argv[1], sys.argv[2]
OUT = os.path.join(ROOT, "docs/design/PLAYER_GOALS_AUDIT_LEDGER.csv")
J = lambda f, d=None: json.load(open(os.path.join(W, f))) if os.path.exists(os.path.join(W, f)) else d
goals = J("goals_parsed.json")
deps = J("pass2_deps.json", {})
acq = J("ws_acquisition.json", {})
rt = J("ws_runtime.json", {}).get("goals", {})
rt_kind = J("ws_runtime.json", {}).get("by_kind", {})
cat = J("ws_catalog.json", {}).get("goals", {})
eco = J("ws_economy.json", {}).get("goals", {})
LF = J("lead_findings.json", {})
D = lambda p: json.load(open(os.path.join(ROOT, "data", p)))
R = D("items/recipes.json")["recipes"]; B = D("items/blueprints.json")["blueprints"]

by_goal = collections.defaultdict(list)
for fid, f in LF.items():
    if fid.startswith("_"): continue
    for gid in f.get("goals", []):
        by_goal[gid].append(fid)

COLS = ["goal_id", "record_type", "draft_line", "title", "route", "draft_section", "content_status", "proposed_reward_copper",
        "required_action_and_completion", "materials_exact", "tools_required", "stations_required", "dependency_goal_ids",
        "acquisition_source_evidence", "completion_event_support", "design_status", "evidence_level", "runtime_support",
        "source_refs", "finding_ids", "recommended_correction", "recommended_reward_copper", "gameplay_test_required"]
SEV = {"HIGH": 3, "MED": 2, "LOW": 1}
STATUS_RANK = {"PASS": 0, "NEEDS_TEST": 1, "NEEDS_CORRECTION": 2, "BLOCKED": 3}

def default_completion(g):
    if g["kind"] == "craft":
        return "Craft %s once (any recipe: %s); server counts made:%s when the craft finishes" % (g["key"], ",".join(g.get("listed_recipes", [])), g["key"])
    if g["kind"] == "build":
        return "Place structure %s once with the hammer; server counts event placed:%s" % (g["ref"].get("structure", g["key"]), g["ref"].get("structure", g["key"]))
    if g["kind"] == "gather":
        return "Obtain %s by gathering (no gather event exists; see runtime findings)" % g["key"]
    return g["how"][:200]

rows = []
for g in goals:
    gid = g["goal_id"]
    c = cat.get(gid, {}); r = rt.get(gid) or {}
    kind_rt = rt_kind.get(g["kind"], {})
    fids = sorted(set(by_goal.get(gid, [])))
    # design status: worst status_effect of attached findings; default from evidence
    status = "PASS"
    for fid in fids:
        eff = LF[fid].get("status_effect", "NEEDS_CORRECTION")
        if STATUS_RANK.get(eff, 0) > STATUS_RANK[status]: status = eff
    # runtime support is reported separately from design status (brief: three independent columns).
    # craft/build are PARTIAL only for the specific paths listed per goal in ws_runtime.json goals.
    runtime = LF.get("_runtime_overrides", {}).get(gid) or r.get("runtime_support") or ("EXISTING" if g["kind"] in ("craft", "build") else kind_rt.get("support")) or "UNKNOWN"
    evidence = LF.get("_evidence_overrides", {}).get(gid) if isinstance(LF.get("_evidence_overrides"), dict) else None
    evidence = evidence or ("CODE_VERIFIED" if (c or r or g["kind"] in ("craft", "build")) else "DOCUMENT_ONLY")
    # acquisition evidence for gather goals and raw inputs of this goal
    acq_txt = []
    keys = [g["key"]] if g["kind"] == "gather" else []
    for d in deps.get(gid, {}).get("deps", []):
        if d[0] == "input":
            keys.append(d[1].split(" x")[0])
    for k in keys:
        a = acq.get(k)
        if a: acq_txt.append("%s: %s (%s) [%s]" % (k, a.get("status"), a.get("mechanism", "")[:90], "; ".join(a.get("evidence", [])[:2])))
    corr = " | ".join(LF[f].get("correction", "") for f in fids if LF[f].get("correction"))
    tests = " | ".join(sorted({LF[f].get("test", "") for f in fids if LF[f].get("test")}))
    e = eco.get(gid, {})
    rows.append({
        "goal_id": gid, "record_type": "ORIGINAL", "draft_line": g["line"], "title": g["title"], "route": g["route"],
        "draft_section": g["section"], "content_status": c.get("content_status", "UNKNOWN"),
        "proposed_reward_copper": g["coin_copper"],
        "required_action_and_completion": (r.get("completion_condition") or default_completion(g)).replace("\n", " "),
        "materials_exact": g.get("materials", ""), "tools_required": g.get("tools", ""), "stations_required": g.get("station", ""),
        "dependency_goal_ids": " ".join(deps.get(gid, {}).get("dep_goal_ids", [])),
        "acquisition_source_evidence": " || ".join(acq_txt),
        "completion_event_support": (r.get("event_support") or kind_rt.get("summary") or "").replace("\n", " "),
        "design_status": status, "evidence_level": evidence, "runtime_support": runtime,
        "source_refs": " ".join(g.get("evidence", []) + ["PLAYER_GOALS_REWARDS_DRAFT.md:%d" % g["line"]]),
        "finding_ids": " ".join(fids), "recommended_correction": corr,
        "recommended_reward_copper": e.get("recommended_copper", ""),
        "gameplay_test_required": tests or g.get("test", ""),
    })
for a in LF.get("_adds", []) if isinstance(LF.get("_adds"), list) else []:
    row = {c: "" for c in COLS}
    row.update(a); row["record_type"] = "ADD"
    rows.append(row)

buf = io.StringIO()
w = csv.DictWriter(buf, fieldnames=COLS, lineterminator="\n", quoting=csv.QUOTE_MINIMAL)
w.writeheader()
for row in rows: w.writerow(row)
open(OUT, "w", encoding="utf-8", newline="").write(buf.getvalue())

# ---------------- validation
back = list(csv.DictReader(open(OUT, encoding="utf-8", newline="")))
orig = [x for x in back if x["record_type"] == "ORIGINAL"]
errs = []
ids = [x["goal_id"] for x in back]
if len(ids) != len(set(ids)): errs.append("duplicate ids: %s" % [i for i, n in collections.Counter(ids).items() if n > 1])
if len(orig) != len(goals): errs.append("original count %d != draft %d" % (len(orig), len(goals)))
if {x["goal_id"] for x in orig} != {g["goal_id"] for g in goals}: errs.append("original id set differs from draft")
REQ = ["goal_id", "title", "route", "content_status", "proposed_reward_copper", "required_action_and_completion", "design_status", "evidence_level", "runtime_support", "source_refs"]
for x in back:
    for c in REQ:
        if x["record_type"] == "ORIGINAL" and not x[c].strip(): errs.append("%s missing %s" % (x["goal_id"], c))
    if x["record_type"] == "ORIGINAL" and not x["proposed_reward_copper"].isdigit(): errs.append("%s bad reward" % x["goal_id"])
    if x["recommended_reward_copper"] and not x["recommended_reward_copper"].isdigit(): errs.append("%s bad recommended reward" % x["goal_id"])
    if x["design_status"] not in STATUS_RANK and x["record_type"] == "ORIGINAL": errs.append("%s bad status" % x["goal_id"])
    for f in x["finding_ids"].split():
        if f not in LF or f.startswith("_"): errs.append("%s unknown finding %s" % (x["goal_id"], f))
stats = dict(rows=len(back), original=len(orig), adds=len(back) - len(orig),
             design_status=collections.Counter(x["design_status"] for x in orig),
             evidence_level=collections.Counter(x["evidence_level"] for x in orig),
             runtime_support=collections.Counter(x["runtime_support"] for x in orig),
             content_status=collections.Counter(x["content_status"] for x in orig),
             route=collections.Counter(x["route"] for x in orig),
             reward_total=sum(int(x["proposed_reward_copper"]) for x in orig),
             recommended_total=sum(int(x["recommended_reward_copper"] or x["proposed_reward_copper"]) for x in orig))
json.dump(stats, open(os.path.join(W, "ledger_stats.json"), "w"), indent=1)
print(json.dumps(stats, indent=1))
print("VALIDATION:", "OK" if not errs else "%d errors" % len(errs))
for e in errs[:60]: print("  ", e)
sys.exit(1 if errs else 0)
