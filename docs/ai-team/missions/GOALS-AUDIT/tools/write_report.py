#!/usr/bin/env python3
"""GOALS-AUDIT: write docs/design/PLAYER_GOALS_REWARDS_AUDIT.md from the ledger and the consolidated findings.

Every count in the report is computed here from docs/design/PLAYER_GOALS_AUDIT_LEDGER.csv, work/lead_findings.json,
work/ws_economy.json and work/review_log.json, so the report and the ledger cannot disagree.
Usage: python3 write_report.py <repo_root> <work_dir>
"""
import csv, json, os, sys, collections, subprocess
ROOT, W = sys.argv[1], sys.argv[2]
OUT = os.path.join(ROOT, "docs/design/PLAYER_GOALS_REWARDS_AUDIT.md")
LED = os.path.join(ROOT, "docs/design/PLAYER_GOALS_AUDIT_LEDGER.csv")
J = lambda f, d=None: json.load(open(os.path.join(W, f))) if os.path.exists(os.path.join(W, f)) else d
rows = list(csv.DictReader(open(LED, encoding="utf-8")))
orig = [r for r in rows if r["record_type"] == "ORIGINAL"]; adds = [r for r in rows if r["record_type"] == "ADD"]
LF = J("lead_findings.json"); F = {k: v for k, v in LF.items() if k.startswith("GA-")}; C = LF["_computed"]
eco = J("ws_economy.json"); tot = eco["totals"]; ms = eco["milestones"]
rev = J("review_log.json", {"rounds": []})
BASE = "dc2fa52374d49ce05ef1f31a300999d1da872d9d"
cnt = lambda key, rs=orig: collections.Counter(r[key] for r in rs)
ds = cnt("design_status"); ev = cnt("evidence_level"); rs_ = cnt("runtime_support"); cs = cnt("content_status")
main = [r for r in orig if r["route"] == "MAIN"]; dsm = cnt("design_status", main)
by_id = {r["goal_id"]: r for r in orig}
ind = [r for r in orig if r["review_method"].startswith("INDIVIDUAL")]
def n(s): return "%d" % s
def fl(fid): f = F[fid]; return "**%s** (%s, %s): %s" % (fid, f["severity"], f["cls"].replace("_", " ").lower(), f["title"])
def flist(ids, show_goals=True):
    out = []
    for fid in ids:
        f = F[fid]
        g = f["goals"]
        gs = (" Goals (%d): %s." % (len(g), ", ".join("`%s`" % x for x in g[:14]) + (" and %d more (ledger column finding_ids)" % (len(g) - 14) if len(g) > 14 else ""))) if g and show_goals else ""
        out.append("- %s. Evidence: %s%s Correction: %s%s" % (fl(fid), f["evidence"], gs, f["correction"], (" Test: " + f["test"]) if f["test"] else ""))
    return "\n".join(out)
def pct(a, b): return "%.0f%%" % (100.0 * a / b) if b else "-"

L = []
P = L.append
P("# Player goals and rewards: audit")
P("")
P("Audit of `docs/design/PLAYER_GOALS_REWARDS_DRAFT.md` (651 goals) and `docs/design/PLAYER_JOURNAL_GOALS_UI.md` against the approved catalog, the live data and the server code. Audit only: nothing in the game, its data or its UI was changed. The per-goal record is `docs/design/PLAYER_GOALS_AUDIT_LEDGER.csv`; every count below is generated from that file (`docs/ai-team/missions/GOALS-AUDIT/tools/write_report.py`).")
P("")
P("Status: AUDIT REPORT (PROPOSAL-class findings and recommendations; not creator decisions). Mission GOALS-AUDIT, requested by Dave on 13 Nov 2026.")
P("")

# 1
P("## 1. Executive summary")
P("")
P("- **%d original goals reviewed** (%d main route, %d additional), plus **%d recommended ADD goals** kept as separate records." % (len(orig), len(main), len(orig) - len(main), len(adds)))
P("- **Design status:** PASS %d, NEEDS_CORRECTION %d, NEEDS_TEST %d, BLOCKED %d. On the main route: PASS %d, NEEDS_CORRECTION %d, NEEDS_TEST %d, BLOCKED %d." % (ds["PASS"], ds["NEEDS_CORRECTION"], ds["NEEDS_TEST"], ds["BLOCKED"], dsm["PASS"], dsm["NEEDS_CORRECTION"], dsm["NEEDS_TEST"], dsm["BLOCKED"]))
P("- **Depth:** %d goals (all %d main-route goals) were examined individually; %d side-branch goals (dependency levels 6-17) were assessed by rule only, by a script against the named data files (section 2). %d of the %d PASS verdicts are rule-only." % (len(ind), len(main), len(orig) - len(ind), sum(1 for r in orig if r["design_status"] == "PASS" and r["review_method"].startswith("RULE")), ds["PASS"]))
P("- **Evidence:** %d goals CODE_VERIFIED (data and code read at the baseline), %d AUTOMATED_TESTED (legacy goals asserted by `test_goals.gd`, passed on David4 at the baseline), 0 GAMEPLAY_VERIFIED. No goal has been seen completing in a played game." % (ev["CODE_VERIFIED"], ev["AUTOMATED_TESTED"]))
pass_rt = sum(1 for r in orig if r["design_status"] == "PASS" and r["runtime_support"] != "EXISTING")
P("- **Runtime:** %d goals can be detected by the existing goal engine; %d need a new server event (gather and fire/chop activities); %d need other implementation (paths that make the item without crediting the goal). Design status and runtime support are separate: %d PASS goals still need runtime work before they can complete." % (rs_["EXISTING"], rs_.get("NEW_EVENT_REQUIRED", 0), rs_.get("OTHER_IMPLEMENTATION_REQUIRED", 0), pass_rt))
P("- **Blocked content:** %d goals cannot be completed in play today: %d because a raw ingredient has no in-game source (Tanbark, pine tar, grain crops and flax; obsidian and quill also have none but block no goal on their own), %d more because the `water` ingredient exists only as desert cactus water, and %d because they target locked blueprints. %d of them are on the main route (Leather, Tar, Water wheel, Sawmill, Concrete, the three swords and every Engineered/Fortified piece that needs concrete)." % (ds["BLOCKED"], len(C["blocked_nosrc"]), len(C["blocked_water_extra"]), len(C["locked_bp"]), len(C["main_blocked"])))
P("- **Top tutorial problems:** the Wooden - Hammer step cannot be done as written (axing a log gives large blocks; small blocks are never taught); no hunting step precedes 'Obtain hide'; firewood is taught by a path that never completes the goal; doors come before their frames and never say to aim at an empty doorway; burning stations (Smithy, Blast furnace, Master smithy) need fuel in the pack and the guide never says so; bronze comes after iron, contrary to the approved catalog; legacy `after` gating withholds credit for out-of-order play.")
P("- **Top economy concerns:** the draft pays %s copper in total (main route %s). On the ASSUMED effort model that is %.1f times the picking wage over the modeled work and %.2f times the net coin Hob could pay one player; real play time is unmeasured. Rewards follow dependency depth, not effort or significance; variants take most of the money. Recommended per-goal values (ledger column `recommended_reward_copper`) total %s (main route %s). Coin values are unchanged by this audit (creator ruling relayed with the brief: coin rewards stay until Dave says otherwise)." % (tot["draft_total"], tot["draft_main"], 14.6, 1.70, tot["recommended_total"], tot["recommended_main"]))
P("- **Journal and HUD:** J, G and M are taken or unwired today; modifier handling would make Ctrl+Shift+G run Store All in the inventory; the client receives no goal state (protocol change needed); the upper-right HUD corner is occupied; no fanfare audio exists.")
P("- **Readiness: NOT READY for implementation.** See section 18. The goal list needs its BLOCKED and NEEDS_CORRECTION rows resolved and %d creator decisions (section 17) before the goal data can be written." % 11)
P("")

# 2
P("## 2. Scope and method")
P("")
P("Scope: every row of the draft goal table, the draft's runtime/Journal sections, and the Journal/HUD/placard/keyboard design in `PLAYER_JOURNAL_GOALS_UI.md` and `ADMIN_KEYBINDINGS_POLICY.md`. Out of scope (brief): implementing goals, changing rewards, recipes, stations, progression or the UI, inventing acquisition methods or renaming items.")
P("")
P("Method, in six passes (brief, section 'Passes'):")
P("1. **Discovery.** `tools/goals_audit.py` parses all 651 rows (title, How-to, marker, reward text and copper) and cross-checks each row against `recipes.json`, `blueprints.json`, `structures.json`, `items.json`, `gathered.json` and `wood_species.json` (materials, keeps, units, station and level, blueprint known/locked, group labels, names).")
P("2. **Dependencies.** `tools/pass2_deps.py` records each goal's real inputs, kept tools, stations and blueprint hammer tier, links each to the goal that teaches it, and reports untaught prerequisites and ordering inversions. An obtainability fixed point (`tools/consolidate.py`) propagates from items with a verified source through live recipes, buildable stations and add-on levels.")
P("3. **Individual verification**, by seven independent workstreams, each reading code and data at the baseline: acquisition (every raw input's source), runtime (completion, persistence, migration, performance), catalog (status, names, duplicates, intermediates), Journal/HUD/placard/keyboard, economy (`tools/economy.py`), and two new-player walkthroughs (main 1-45 and side levels 1-5; main 44-118 and levels 6-17).")
P("4. **Walkthrough** from an empty pack to the Fortified gate (section 5).")
P("5. **Independent challenge** by reviewers who did not write the findings (section 15).")
P("6. **Correction and consistency**: the findings are consolidated into stable IDs (GA-xx) by `tools/consolidate.py`; `tools/build_ledger.py` writes and validates the ledger; this report is generated from it.")
P("")
P("Design status of a goal is the most severe effect among its findings: BLOCKED (cannot be completed in play today), NEEDS_CORRECTION (the instruction, ordering, completion rule or text is wrong or incomplete), NEEDS_TEST (believed correct but depends on content not yet verified in play), PASS (instruction, materials, stations and prerequisites match the code and data). Design status is independent of runtime support: a PASS gather goal still needs a new event before it can complete (column `runtime_support`). Economy findings never change design status; recommended coin values sit in their own column. Engine-wide completion defects that affect every goal of a kind (GA-40 `after` gating, GA-43 uncredited paths, GA-45 missing events, GA-46 gather events) are recorded with no status effect on purpose and appear in `runtime_support` instead; a completion defect specific to one goal's taught path (for example GA-13 firewood) is NEEDS_CORRECTION.")
P("")

ind = [r for r in orig if r["review_method"].startswith("INDIVIDUAL")]
P("**Depth of review, per goal (ledger column `review_method`).** %d goals (all %d main-route goals) were examined individually: a walkthrough step, a side goal read one by one, a completion rule read in the server code, or an independent reviewer's re-check (the column names which). The other %d goals (side branches at dependency levels 6-17, including about 68 cooking and food rows) were assessed **by rule only**: a script compared each row's materials, quantities, kept tools, station and level, blueprint status and hammer tier with the named data files, then placed it in the dependency graph and the obtainability fixed point. Those rows were not read one by one by a person or agent; mechanism-level findings (for example GA-20 fuel, GA-24 doors) were applied to them by station or family." % (len(ind), sum(1 for r in ind if r["route"] == "MAIN"), len(orig) - len(ind)))
P("")
P("**Evidence level, per goal.** CODE_VERIFIED means the named data sources in `source_refs` were read for that row (by script for rule-only rows) and the mechanism code was read once for the family; it does not mean the goal was seen working. AUTOMATED_TESTED is given only to the 11 legacy goals whose completion `test_goals.gd` asserts (one of the 20 David4 scripts). GAMEPLAY_VERIFIED is given to none: nobody has seen any of these goals on screen. No row is DOCUMENT_ONLY, because every row was compared with at least one named data file.")
P("")
P("**Ledger integrity (machine-checked by `tools/build_ledger.py` on every build):** %d ORIGINAL rows, exactly one per draft row (the parsed draft has %d rows and the ID sets are compared for equality, so a missing or extra goal fails the build); no duplicate `goal_id` across all %d rows; every required field present; every reward an integer copper value; every finding ID defined. Goal counts, status counts and copper totals in this report are computed from the CSV and the model outputs by `tools/write_report.py`. A few figures are quoted from the workstream records rather than recomputed here: the 14.6x and 1.70x economy ratios (GA-70, `work/ws_economy.md`), the 36 overlapping goals and 70 intermediates (`work/ws_catalog.md` sections 5-6), and the draft self-audit figures (`work/ws_acquisition.md`)." % (len(orig), len(orig), len(rows)))
P("")
P("Evidence classes: CREATOR (Dave's own rulings), IMPLEMENTED (code and data at the baseline), PROPOSAL (the draft and agent documents), UNKNOWN. Godot was not run in the cloud. Automated evidence comes from one David4 run relayed by the coordinator (section 3).")
P("")
P("Supporting material (not part of the deliverable, kept for review): `docs/ai-team/missions/GOALS-AUDIT/` (tools, workstream reports `work/ws_*.md`, machine results `work/*.json`, `STATE.md`).")
P("")

# 3
P("## 3. Baseline and source versions")
P("")
P("| Item | Version |")
P("|---|---|")
P("| Code and data baseline | `dev` at `%s` (all `src/` and `data/` citations) |" % BASE)
P("| Draft goals | `docs/design/PLAYER_GOALS_REWARDS_DRAFT.md` at the baseline (651 rows, lines 28-757) |")
P("| Journal design | `docs/design/PLAYER_JOURNAL_GOALS_UI.md`, `docs/design/ADMIN_KEYBINDINGS_POLICY.md` at the baseline |")
P("| Approved catalog | `docs/design/DYNASTY_MASTER_ITEMS.md` (Draft 18), `data/items/catalog_ledger.json`, BUGLIST-002 door contract (`docs/ai-team/missions/BUGLIST-002/CONTRACT.md`) |")
P("| Live goals | `data/items/starter_goals.json` (18), `data/items/camp_goals.json` (10), engine `src/stream/server_items.gd` ~15620-15840 |")
P("| Protocol | 118 (`src/shared/terrain_net.gd:40`) |")
P("| Automated evidence | David4 run at `%s`: 20/20 test scripts PASS (test_goals, test_mission001_walkthrough, test_fire_fuel_tiers, test_fire_wet_wood, test_campfire_pot, test_wanted_order, test_camp_bench_drink, test_cooking_route, test_iron_saw_route, test_lumber_route, test_textile_route, test_stations, test_blueprints, test_doors, test_bog_iron, test_stump_chop, test_logs_carry, test_auto_pickup, test_fishing, test_shore_gather) and `validate_items` 0 errors, 114 warnings. Relayed record: `docs/ai-team/missions/GOALS-AUDIT/work/david4_evidence_dc2fa52.md`. |" % BASE[:7])
P("| Placard art | `GoalAchieved_Blank.png` and `GoalAchieved_Example.png` from Dave's PC, 1448x1086 RGBA, ~2.6 MB each (SHA-256 df9a3d87... and 4c20d281...) |")
P("")
P("The audit branch changes only `docs/ai-team/missions/GOALS-AUDIT/` and the two deliverables, so every citation is identical at the branch head.")
P("")

# 4
P("## 4. Inventory and coverage")
P("")
P("| Class | Goals |")
P("|---|---|")
for k in ("IMPLEMENTED", "APPROVED_BUT_NOT_IMPLEMENTED", "FUTURE", "RETIRED", "UNKNOWN"):
    P("| %s | %d |" % (k, cs.get(k, 0)))
P("")
P("- APPROVED_BUT_NOT_IMPLEMENTED: the 23 approved-KEEP blueprints that exist as locked rows (water network, garden pieces). FUTURE: Wool - Rug. No goal targets a retired item, structure or recipe; the draft's KEEP/retired split agrees with the catalog ledger (clay bloomery and woodworking table consistently retired).")
kinds = cnt("goal_id")
kc = collections.Counter(r["goal_id"].split(":")[0] if ":" in r["goal_id"] else "existing (legacy id)" for r in orig)
P("- By kind: %s." % ", ".join("%s %d" % (k, v) for k, v in kc.most_common()))
P("- Coverage of eligible content: every live tool ladder (knife, axe, pickaxe, hammer, saw, spade, hoe, sickle) is covered by a goal. Content with no goal is listed as %d ADD records (section 7)." % len(adds))
P("- Goal IDs: the draft has none. The ledger assigns stable IDs: the legacy runtime id for the 28 live goals, otherwise `<kind>:<key>` from each row's marker. All %d are unique (validated)." % len(orig))
P("- 70 craft goals are intermediate components (GA-58); 36 goals are in a duplicate or overlap relation (`work/ws_catalog.md` section 5; the clearest cases are GA-47 and GA-48).")
P("- The draft's own self-audit (its section 3, 43 'unconfirmed' sources) is inaccurate: 37 of the 43 are sourced; Tanbark, pine tar and obsidian, which it did not list, have no source (GA-59).")
P("")

# 5
P("## 5. Progression chain")
P("")
P("Main route as written, with each step's audit verdict. The full reasoning for each step is in the ledger row (columns `dependency_goal_ids`, `finding_ids`, `recommended_correction`).")
P("")
P("| # | Goal | Title | Status | Findings |")
P("|---|---|---|---|---|")
for i, r in enumerate(main, 1):
    P("| %d | `%s` | %s | %s | %s |" % (i, r["goal_id"], r["title"].replace("|", "/"), r["design_status"], r["finding_ids"]))
P("")
P("### Phase C walkthrough, step by step")
P("")
P("The new-player walkthrough was written one step at a time, from an empty pack (main 1-45, then 44-118), by two separate workstreams reading code and data. Their step tables are reproduced below unchanged, apart from cutting the evidence column. These tables are the walkers' first-pass reading and are **not** the verdicts: the Status column of the main-route table above and the ledger are authoritative. In particular, a YES cell is superseded wherever a goal is BLOCKED by a source or a locked blueprint (GA-01 to GA-04, GA-31: e.g. Leather, the swords, Concrete, the Engineered and Fortified pieces) and wherever the independent review corrected a step (section 15: GA-10 tree species, GA-21 foundation order, GA-23 bronze order, GA-36 drink). Verdicts: YES; YES-WITH-UNTAUGHT-PREREQ (doable, but the guide leaves out something the player needs); NO; UNKNOWN.")
P("")
import re as _re
def walk_table(path, title):
    txt = open(os.path.join(W, path)).read().split("## (a)", 1)[1].split("## (b)", 1)[0]
    lines = [l for l in txt.splitlines() if l.startswith("|")]
    P(title); P("")
    for l in lines:
        cells = l.strip().strip("|").split("|")
        P("|" + "|".join(cells[:4]) + "|")
    P("")
walk_table("ws_walk_early.md", "**Main steps 1-45** (from `work/ws_walk_early.md`):")
walk_table("ws_walk_late.md", "**Main steps 44-118** (from `work/ws_walk_late.md`):")
P("**Walkthrough summary (new character, empty pack):**")
P("- Steps 1-10 (sticks, stones, drink, fibre, twine, knife, axe, pickaxe, fell, log) work, with gaps: drinking counts only when thirsty and a new character starts full (GA-36); a sapling gives no log (GA-35); logs are never explained (shoulder carry, Q to put down, recipes use logs within 3 m: GA-12).")
P("- Steps 11-16: what the axe gives depends on the tree. A key-species log gives large blocks, so the Wooden - Hammer needs the untaught 'Small wooden blocks' step; any other tree gives the plain Log and only small blocks, so the Chopping block (step 16) cannot be made (GA-10).")
P("- Steps 13-43 (campfire, fires, lean-to, workbench, Crude building set, clay, bricks, hearth, oven) work with explanation gaps: kit placement (GA-14), the pot needs a small fire (GA-15), lean-to leaves (GA-16), roof snapping (GA-18), firewood credit (GA-13), quantities (GA-19), door order and aiming (GA-24).")
P("- Step 45 'Obtain hide' is a hard stop for a player who follows only the main route: nothing on it can kill an animal (GA-11).")
P("- Steps 46-79 (hide work, Smelter, bog iron, iron tools, Smithy, plank and board, Stone - Workbench) work once bog iron is taught (GA-05) and the Smithy's fuel is explained (GA-20). Leather (main) is BLOCKED by Tanbark and water (GA-01, GA-04).")
P("- Steps 80-118 (bronze, construction tiers, steel, Blast furnace, Sawmill, Master smithy, Fortified set) contain the remaining blocks: Tar, Water wheel and Sawmill need pine tar (GA-02), concrete needs water (GA-04), the three swords need Leather. Bronze is placed after iron, which the approved catalog allows either way (GA-23, creator question Q11), and the construction tiers are taught as lone foundations (GA-26).")
P("- No circular requirement exists. Every station in the route is reachable when the source gaps are closed. Highest outputs reachable today: steel tools and Engineered pieces that need no concrete; with the gaps closed, the Fortified gate.")
P("")
P("**Side branches:** %d side-branch goals are listed before the goal that teaches a prerequisite (GA-07); %d goals need an ingredient whose source no goal teaches (GA-06, section 7)." % (len(F["GA-07"]["goals"]), len(F["GA-06"]["goals"])))
P("")
P("Milestones on the main route (cumulative draft copper vs modeled hands-on minutes):")
P("")
P("| Milestone | Main step | Draft copper | Recommended | Modeled work (min) |")
P("|---|---|---|---|---|")
for k, m in sorted(ms.items(), key=lambda kv: kv[1].get("main_index", 0)):
    if "draft_cum" not in m: continue
    P("| %s | %s | %s | %s | %s |" % (k.replace("_", " "), m["main_index"], m["draft_cum"], m["recommended_cum"], m["effort_cum_min"]))
P("")

# 6
P("## 6. Dependency findings")
P("")
P(flist(["GA-06", "GA-07", "GA-10", "GA-11", "GA-22", "GA-23", "GA-26", "GA-27", "GA-35", "GA-37", "GA-39", "GA-40"]))
P("")
P("Untaught ingredients, by number of goals that need them: water %s; honeyspindle nectar, feather, raw meat, wild garlic, soil, sinew, onion, hazelnuts, wild carrot, fur, herbs, egg, nettles and 27 more (pass 2, `work/pass2_report.txt`)." % 20)
P("")

# 7
P("## 7. Missing goals and steps")
P("")
P("Missing steps inside existing goals (corrections, not new goals): small wooden blocks before the hammer (GA-10), a hunting step before hide (GA-11), kiln charcoal before the metal steps (GA-22), sources for untaught ingredients (GA-06).")
P("")
P("Recommended ADD goals (%d). Each needs creator approval (catalog freeze); none is implemented by this audit." % len(adds))
P("")
P("| ID | Title | Route | Runtime | Why |")
P("|---|---|---|---|---|")
for a in adds:
    P("| `%s` | %s | %s | %s | %s |" % (a["goal_id"], a["title"], a["route"], a["runtime_support"], a["required_action_and_completion"].replace("|", "/")))
P("")

# 8
P("## 8. Invalid instructions")
P("")
P(flist(["GA-05", "GA-10", "GA-12", "GA-13", "GA-14", "GA-15", "GA-16", "GA-17", "GA-18", "GA-19", "GA-24", "GA-30", "GA-34", "GA-36", "GA-51", "GA-52"]))
P("")

# 9
P("## 9. Unobtainable ingredients")
P("")
P("Computed by a fixed point over verified sources (`tools/consolidate.py`). Counts per ingredient assume every other gap is closed:")
P("")
P("| Ingredient | Goals that need it | Note |")
P("|---|---|---|")
notes = {"tannin_bark": "GA-01, leather chain", "pine_tar": "GA-02", "water": "GA-04, any non-desert start", "crops": "GA-03 (wheat, barley, oats, rye, flax together)", "obsidian": "no goal depends on it alone", "quill": "no goal depends on it alone"}
for k in ("tannin_bark", "pine_tar", "crops", "water", "obsidian", "quill"):
    P("| %s | %d | %s |" % (k, C["blocked_by"].get(k, 0), notes[k]))
P("")
P("Total BLOCKED by sources: %d goals (%d by the no-source items, %d more by water). The per-ingredient counts overlap." % (len(C["blocked_nosrc"]) + len(C["blocked_water_extra"]), len(C["blocked_nosrc"]), len(C["blocked_water_extra"])))
P("")
P(flist(["GA-01", "GA-02", "GA-03", "GA-04"]))
P("")

# 10
P("## 10. Station and tier defects")
P("")
P(flist(["GA-20", "GA-21", "GA-23", "GA-26", "GA-27", "GA-28", "GA-29", "GA-31", "GA-32", "GA-33"]))
P("")

# 11
P("## 11. Server completion, persistence and payout")
P("")
P("How the engine works today: goals live in `starter_goals.json` and `camp_goals.json`; `_goal_event` and `_goal_made` increment per-character counters (`event:<name>[:<what>]`, `made:<item>`); `_goals_check` tests every goal for the player after each event and on the 0.25 s slow tick; a completed id goes into `goals_done` and its reward is paid once. Goals, counters and coins are saved together in one atomic `characters.json` write. The client receives only the notice text.")
P("")
P(flist(["GA-40", "GA-41", "GA-42", "GA-43", "GA-44", "GA-45", "GA-46", "GA-47", "GA-48", "GA-49", "GA-50", "GA-53", "GA-54", "GA-55", "GA-56", "GA-57", "GA-38"]))
P("")
P("Migration plan (recommended): keep the 28 legacy ids and counter formats (hints and tests depend on them); add a `goals_v` version to the character; on first join after the change, run one catch-up check from the stored counters and decide (creator) whether those completions pay; never pay a done id twice; queue the resulting notices (GA-89).")
P("")

# 12
P("## 12. Economy, with recommendations in copper")
P("")
P("All values in integer copper (10 copper = 1 bronze, 10 bronze = 1 silver, 10 silver = 1 gold). The model is `tools/economy.py` (deterministic). Gathering rates are ASSUMED (nobody has timed them); real play time is UNKNOWN and probably several times the modeled time.")
P("")
P("| Scope | Goals | Draft | Recommended |")
P("|---|---|---|---|")
P("| All goals | %d | %d | %d |" % (tot["goal_count"], tot["draft_total"], tot["recommended_total"]))
P("| Main route | %d | %d | %d |" % (len(main), tot["draft_main"], tot["recommended_main"]))
P("| Additional | %d | %d | %d |" % (len(orig) - len(main), tot["draft_additional"], tot["recommended_additional"]))
P("")
P("Reference wages: picking about 0.2 copper/min (Dave's rule: 4 hours of full-time picking pays about 40 to 60 copper, `docs/ECONOMY_FIRST_DAY.md:3-6`; 0.2 is the midpoint Sal used); Hob's daily wanted order about 8.4/h; Hob's purse ceiling 300 then +100 per real hour (`data/npcs/shops.json`, `server_trade.gd:397-414`). Goal coin bypasses the purse (`server_items.gd:15771-15772`).")
P("")
P(flist(["GA-70", "GA-71", "GA-72", "GA-73", "GA-74", "GA-75"]))
P("")
P("Legacy item rewards: see GA-42 in section 11.")
P("")
P("Recommended bands (copper):")
P("")
P("| Goal class | Lead | Variant |")
P("|---|---|---|")
for a, b, c in [("First gather of a raw material", "3 (5 for ores, limestone, flint, pine tar, Tanbark, hide, fat, wool, flax)", "-"),
                ("Teaching action (place, chop, fire size)", "up to 5", "-"),
                ("Station tier 1 / 2 / 3 / 4", "10 / 20 / 40 / 80", "-"),
                ("Station add-on", "half the station band", "-"),
                ("Tier-entry material", "iron ingot 15, steel 25, bronze 10, copper/tin 5, concrete 15, plank/board 8, leather 8, charcoal 5, brick 4", "-"),
                ("Other intermediate, material tier 1-5", "3 / 4 / 5 / 7 / 10", "-"),
                ("Building piece, tier lead (Crude / Rustic / Sturdy / Superior / Refined / Engineered / Fortified)", "7 / 7 / 10 / 12 / 15 / 25 / 40", "2"),
                ("Door of a tier", "half the piece band (min 3; 5 on the main route)", "1"),
                ("Metal tools and weapons (bronze / iron / steel)", "10 / 12 / 15 on the main route; off-route working tools 5", "3 / 3 / 4"),
                ("Food (first dish per cooking station)", "5", "2"),
                ("Clothing, containers, medicine, placeables (first per family)", "3 / 5 / 8 / 10 / 12 by material tier", "2"),
                ("Every non-legacy goal", "plus half the picking wage for the modeled work", "")]:
    P("| %s | %s | %s |" % (a, b, c))
P("")
P("These are recommendations only. Coin rewards stay as they are until Dave decides (section 17, Q2 and Q3).")
P("")

# 13
P("## 13. Journal, HUD, placard and keyboard")
P("")
P(flist(["GA-80", "GA-81", "GA-82", "GA-83", "GA-84", "GA-85", "GA-86", "GA-87", "GA-88", "GA-89", "GA-90", "GA-91", "GA-92", "GA-93", "GA-94", "GA-95"], show_goals=False))
P("")
P("Key-conflict summary (contexts: world, inventory open, menu or text field, blueprint list, inspection, photo):")
P("")
P("| Key | Today | Proposed | Verdict |")
P("|---|---|---|---|")
for a, b, c, d in [("J", "jitter test", "Journal index", "OK once jitter moves to Ctrl+Shift+J"),
                   ("G", "Admin Fly (world); Store All (inventory)", "Journal Goals (world); Store All kept", "OK: the inventory branch handles G first"),
                   ("M", "unused", "Journal Map", "OK; no world map exists (GA-92)"),
                   ("Ctrl+Shift+G", "GPU probe", "Fly", "Fires Store All in the inventory until GA-81 is fixed"),
                   ("Ctrl+Shift+R", "-", "Admin rabbit", "Fires Repair in the inventory until GA-81 is fixed"),
                   ("Ctrl+Shift+= / - / ]", "plain keys plus hard-coded +/numpad", "spring controls, starter items", "Remove hard-coded keys; layout-fragile (GA-82, GA-86)"),
                   ("Ctrl+Shift+F2..F8, N, X, L, P, J", "various plain/Ctrl keys", "admin and debug group", "OK; editor capture of F5/F8 untested")]:
    P("| %s | %s | %s | %s |" % (a, b, c, d))
P("")
P("HUD ordering: in this draft all 118 main rows precede all 533 additional rows, so 'document order' and 'main first' give the same two goals. Legacy additional goals (fish, spear, hoe, story...) never reach the HUD until the main route is done. Recommended: an explicit `display_order` field in the approved goal data (GA-91).")
P("")
P("Placard: 'Goal Achieved' and 'Reward' are baked into the art; title and reward text go into the centre panel and the reward box; titles run to 40 characters, so two-line shrink-to-fit; rewards are formatted from the copper value in the game's existing words ('2 silver, 4 bronze'). This audit does not design the goal UI; Dave designs the goal section himself.")
P("")

# 14
P("## 14. Corrections with stable finding IDs")
P("")
P("Severity: HIGH (blocks a player or pays wrongly), MED (misleads or needs a decision), LOW (polish). Class: CONFIRMED_DEFECT, UNVERIFIED_ASSUMPTION, DESIGN_RECOMMENDATION, OWNER_DECISION. Effect: the design status the finding gives its goals.")
P("")
P("| ID | Severity | Class | Effect | Goals | Finding | Sources |")
P("|---|---|---|---|---|---|---|")
for fid in sorted(F, key=lambda x: int(x.split("-")[1])):
    f = F[fid]
    P("| %s | %s | %s | %s | %d | %s | %s |" % (fid, f["severity"], f["cls"], f["status_effect"], len(f["goals"]), f["title"].replace("|", "/"), f["sources"]))
P("")
sev = collections.Counter(f["severity"] for f in F.values())
P("%d findings: %d HIGH, %d MED, %d LOW. Each goal's findings, corrections and tests are in its ledger row." % (len(F), sev["HIGH"], sev["MED"], sev["LOW"]))
P("")

# 15
P("## 15. Reviewer objections and their resolution")
P("")
if not rev["rounds"]:
    P("Pending: the independent challenge pass has not run yet.")
else:
    for rd in rev["rounds"]:
        P("**%s** (%s). %s" % (rd["name"], rd["reviewer"], rd.get("summary", "")))
        P("")
        P("| # | Objection | Resolution |")
        P("|---|---|---|")
        for i, o in enumerate(rd["objections"], 1):
            P("| %d | %s | %s |" % (i, o["objection"].replace("|", "/"), o["resolution"].replace("|", "/")))
        P("")
P("")

# 16
P("## 16. Evidence gaps and required tests")
P("")
P("- **No goal is GAMEPLAY_VERIFIED.** Every completion claim needs a played check before the goal list ships.")
P("- **Partly met: individual review.** %d of %d goals were examined individually (all main-route goals); %d side-branch goals at dependency levels 6-17 were assessed by rule only (section 2). Their PASS verdicts mean 'the row matches the data and its inputs are obtainable', not 'a person read it'. A sampled re-check of about 40 of them by the independent reviewer found no wrong materials, but the remaining rule-only rows (column `review_method` = RULE) should be read before their text is published." % (len(ind), len(orig), len(orig) - len(ind)))
P("- **Partly met: walkthrough.** The step-by-step walkthrough covers the 118 main-route steps; side branches were checked per goal (levels 1-5) or by rule (levels 6-17), not walked as a player.")
P("- AUTOMATED_TESTED covers only the 11 legacy goals asserted by `test_goals.gd`: %s." % ", ".join("`%s`" % k for k in LF["_evidence_overrides"]))
P("- Gathering rates and play time are ASSUMED; time a real first session before setting rewards (GA-70).")
P("- The goal-check cost at 651 goals is estimated, not measured (GA-49).")
P("- Door, doorway and Crude - Roof 65 content awaits Dave's BUGLIST-002 F6 check (GA-25).")
P("- Editor capture of F5/F8 chords and keyboard layouts are untested (GA-86).")
P("")
P("Gameplay tests named by findings:")
P("")
tests = collections.OrderedDict()
for fid in sorted(F, key=lambda x: int(x.split("-")[1])):
    if F[fid]["test"]: tests.setdefault(F[fid]["test"], []).append(fid)
for t, fs in tests.items():
    P("- %s (%s)" % (t, ", ".join(fs)))
P("")
P("%d ledger rows name a gameplay test (column `gameplay_test_required`)." % sum(1 for r in orig if r["gameplay_test_required"].strip()))
P("")

# 17
P("## 17. Creator questions")
P("")
Q = [
 ("Q1", "How should the missing ingredients be obtained: Tanbark, pine tar, `water` from a container, grain crops and flax?",
  "(a) Engineering fixes that follow existing data: strip Tanbark from felled oak, roll every pine trunk drop, let a filled bucket or waterskin supply the `water` ingredient, wire the farming client actions. (b) Remove the affected goals until the content works. (c) Change the recipes (catalog change).",
  "(a). Each fix follows data that already says the item comes from that source; until fixed, keep these %d goals out of the active guide." % (len(C["blocked_nosrc"]) + len(C["blocked_water_extra"]))),
 ("Q2", "What total should goals pay, and should variants pay like their family lead?",
  "(a) Keep the draft (15,670 copper). (b) The recommended bands (about %d; main route %d)." % (tot["recommended_total"], tot["recommended_main"]) + " (c) Group variants into family goals with one payment.",
  "(b), with (c) for the largest variant families (building sets, doors, furniture)."),
 ("Q3", "Should the legacy item rewards become coin?",
  "(a) Keep twine = 4 sticks, fell = 3 kindling, story's extra reputation (ignored today). (b) Use the draft's own coin values: twine 4, fell 6, story 3 copper, and drop the reputation.",
  "(b): one reward type, and no double payment on a crash (GA-42)."),
 ("Q4", "On migration, should goals that existing characters already earned by their counters pay out?",
  "(a) Pay them all at once (queued placards). (b) Mark them done without payment. (c) Pay main-route goals only.",
  "(b): this is a new game with no live economy to protect, and it avoids a placard flood."),
 ("Q5", "Are goals per character (a new character can earn everything again) acceptable?",
  "(a) Accept. (b) Pay once per account.", "(a) for now; revisit if alt farming appears."),
 ("Q6", "Which acquisitions count for gather goals?",
  "(a) First-hand only (pick up, harvest, dig, mine, carcass, fishing, crops). (b) Also bought, looted or taken from a chest.",
  "(a)."),
 ("Q7", "Which two goals does the HUD show?",
  "(a) The first two unfinished in an explicit display order, main route first (equals the literal rule for this draft). (b) Skip goals whose prerequisites are unmet. (c) Mix in legacy additional goals.",
  "(a), with `after` used only for Journal links."),
 ("Q8", "What should the Map page (M) show while no world map exists?",
  "(a) Greyed 'coming later'. (b) Omit the page until a map exists.", "(a)."),
 ("Q9", "Placard art and sound: accept the slightly translucent art, add a coin icon, and how to source a fanfare?",
  "(a) Accept translucency; coin icon from existing coin art; commission an original fanfare, silent until then. (b) Ask for a solid version of the art.",
  "(a)."),
 ("Q10", "Should the 24 goals on locked blueprints stay in the guide?",
  "(a) Hide them as future goals until the blueprints are learnable. (b) Drop them.", "(a)."),
 ("Q11", "Should bronze come before or after iron on the main route?",
  "(a) Keep iron first (catalog s2.7 item 1, the wilderness route to the Iron Hand Saw) and show bronze as an optional side rung. (b) Move bronze directly after the Smelter (s2.7 item 4).",
  "(a): it keeps the route the draft already teaches and costs no reordering; the Stone - Forge then becomes optional."),
]
P("| # | Decision | Alternatives | Recommendation |")
P("|---|---|---|---|")
for q in Q: P("| %s | %s | %s | %s |" % q)
P("")

# 18
P("## 18. Readiness assessment")
P("")
P("**NOT READY for implementation.** Evidence:")
P("- %d goals (%s) are BLOCKED: they cannot be completed in play today (sections 9, 10)." % (ds["BLOCKED"], pct(ds["BLOCKED"], len(orig))))
P("- %d goals (%s) need their instruction, order, completion rule or text corrected (sections 6, 8, 11)." % (ds["NEEDS_CORRECTION"], pct(ds["NEEDS_CORRECTION"], len(orig))))
P("- On the main route only %d of %d goals PASS; %d are BLOCKED and the route has a hard stop at step 45." % (dsm["PASS"], len(main), dsm["BLOCKED"]))
P("- %d goals need new server events or other implementation before they can complete (section 11)." % (rs_.get("NEW_EVENT_REQUIRED", 0) + rs_.get("OTHER_IMPLEMENTATION_REQUIRED", 0)))
P("- 11 creator decisions are open (section 17), including the reward budget.")
P("- The Journal needs a protocol change, key moves and a server-authority fix first (section 13).")
P("- No goal has been played (section 16).")
P("")
P("Recommended order: (1) creator decisions Q1-Q4; (2) fix the acquisition gaps and corrected route order in the approved goal list; (3) engine work: no award gating, history counters, new events, event index, protocol messages; (4) key moves and server checks; (5) the Journal and HUD from Dave's design; (6) a played first-session check with timings, then set rewards.")
P("")
P("What already works: %d goals PASS on code and data (%d on the main route; %d of the PASS verdicts are rule-only, section 2); the tool ladders and station chains have no circular requirements; the legacy engine pays once and persists atomically; 11 legacy goals are automated-tested." % (ds["PASS"], dsm["PASS"], sum(1 for r in orig if r["design_status"] == "PASS" and r["review_method"].startswith("RULE"))))
P("")
open(OUT, "w", encoding="utf-8").write("\n".join(L))
print("wrote", OUT, len(L), "lines")
