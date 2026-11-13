#!/usr/bin/env python3
"""GOALS-AUDIT: consolidate the workstream results into the stable GA-xx findings (work/lead_findings.json).

Every finding names: severity, class (CONFIRMED_DEFECT | UNVERIFIED_ASSUMPTION | DESIGN_RECOMMENDATION | OWNER_DECISION),
title, evidence, affected goals (explicit or computed from data), status_effect on the ledger's design status
(BLOCKED | NEEDS_CORRECTION | NEEDS_TEST | NONE), the recommended correction and any gameplay test.
Computed goal sets are reproducible from data/ and work/*.json.
Usage: python3 consolidate.py <repo_root> <work_dir>
"""
import json, os, re, sys, collections
ROOT, W = sys.argv[1], sys.argv[2]
J = lambda f: json.load(open(os.path.join(W, f)))
D = lambda p: json.load(open(os.path.join(ROOT, "data", p)))
goals = J("goals_parsed.json"); G = {g["goal_id"]: g for g in goals}
deps = J("pass2_deps.json"); acq = J("ws_acquisition.json"); rt = J("ws_runtime.json"); cat = J("ws_catalog.json"); eco = J("ws_economy.json")
R = D("items/recipes.json")["recipes"]; B = D("items/blueprints.json")["blueprints"]; S = D("items/structures.json")["structures"]
I = D("items/items.json")["items"]; I.update({k: v for k, v in D("items/gathered.json")["items"].items() if k not in I})
WD = D("items/wood_species.json"); GROUPS = {k: [k] + v for k, v in WD["ingredient_groups"].items() if isinstance(v, list)}
HAMMER = {v["tier"]: k for k, v in I.items() if v.get("tool_class") == "hammer"}
MAIN = [g["goal_id"] for g in goals if g["route"] == "MAIN"]

# ---------------------------------------------------------------- obtainability with real acquisition evidence
def fixpoint(excluded, force_ok=()):
    raw_ok = {k for k, v in acq.items() if (v["status"] in ("SOURCED", "SOURCED_CONDITIONAL") or k in force_ok) and k not in excluded}
    have = set(raw_ok); built = set(); st = collections.defaultdict(int)
    def ok(i): return any(m in have for m in GROUPS.get(i, [i]))
    changed = True
    while changed:
        changed = False
        for rk, r in R.items():
            if r.get("retired") or r.get("locked") or r["gives"][0] in have: continue
            if all(ok(n) for n, _ in r["needs"] + r.get("keeps", [])) and (not r.get("station") or st[r["station"]] >= r.get("station_level", 1)):
                have.add(r["gives"][0]); changed = True
        for sk, s in S.items():
            if s.get("retired") or sk in built: continue
            routes = [b for b in B.values() if b["structure"] == sk and not b.get("retired") and b.get("known", True) and not b.get("locked")]
            okb = any(all(ok(n) for n, _ in b["cost"]) and any(HAMMER[t] in have for t in HAMMER if t >= b.get("hammer", 1))
                      and (not b.get("near") or st[b["near"]] >= b.get("near_level", 1)) for b in routes)
            okk = any(it in have for it in {s.get("kit"), s.get("item")} - {None, ""} if I.get(it, {}).get("kind") == "placeable")
            if okb or okk:
                built.add(sk); changed = True
                provs = ([(s["station"], s.get("station_level", 1))] if s.get("station") else []) + list((s.get("also") or {}).items())
                for x, lv in provs: st[x] = max(st[x], lv)
        if "campfire_kit" in have and st["campfire"] < 1: st["campfire"] = 1; changed = True
        for ak, a in S.items():   # add-ons that raise a level
            if a.get("addon_of") and ak in built and a.get("adds_level", True) is not False:
                for sk, s in S.items():
                    if s.get("station") == a["addon_of"] and sk in built:
                        lv = s.get("station_level", 1) + len([x for x, y in S.items() if y.get("addon_of") == a["addon_of"] and x in built and y.get("adds_level", True) is not False])
                        if st[a["addon_of"]] < lv: st[a["addon_of"]] = lv; changed = True
    return have, built, st

def goal_doable(g, have, built):
    if g["kind"] == "craft": return g["key"] in have
    if g["kind"] == "build": return g["ref"].get("structure", g["key"]) in built
    if g["kind"] == "gather": return g["key"] in have
    return True
NOSRC = sorted(k for k, v in acq.items() if v["status"] == "NO_SOURCE")
base_have, base_built, base_st = fixpoint(set())
blocked_any = {g["goal_id"] for g in goals if not goal_doable(g, base_have, base_built)}
blocked_by = {}
# per item: goals that need it, assuming every other missing source were fixed
ALLMISS = set(NOSRC) | {"water"}
h_fix, b_fix, _ = fixpoint(set(), force_ok=ALLMISS)
for item in NOSRC + ["water"]:
    h, b, _ = fixpoint({item}, force_ok=ALLMISS - {item})
    blocked_by[item] = sorted(g["goal_id"] for g in goals if goal_doable(g, h_fix, b_fix) and not goal_doable(g, h, b))
h_all, b_all, _ = fixpoint(set(NOSRC))
blocked_nosrc = sorted(g["goal_id"] for g in goals if not goal_doable(g, h_all, b_all))
h_w, b_w, _ = fixpoint(set(NOSRC) | {"water"})
blocked_water_extra = sorted(g["goal_id"] for g in goals if not goal_doable(g, h_w, b_w) and g["goal_id"] not in blocked_nosrc)
locked_bp = sorted(g["goal_id"] for g in goals if g["kind"] == "build" and g["key"] in B and (B[g["key"]].get("locked") or not B[g["key"]].get("known", True)))
blocked_nosrc = [x for x in blocked_nosrc if x not in locked_bp]
blocked_water_extra = [x for x in blocked_water_extra if x not in locked_bp]
for k in blocked_by: blocked_by[k] = [x for x in blocked_by[k] if x not in locked_bp]
CROPS = {"wheat", "barley", "oats", "rye", "flax"}
h, b, _ = fixpoint(CROPS, force_ok=ALLMISS - CROPS)
blocked_by["crops"] = sorted(g["goal_id"] for g in goals if goal_doable(g, h_fix, b_fix) and not goal_doable(g, h, b) and g["goal_id"] not in locked_bp)
h, b, _ = fixpoint({"wool"}, force_ok=ALLMISS)
WOOL_GOALS = sorted(g["goal_id"] for g in goals if goal_doable(g, h_fix, b_fix) and not goal_doable(g, h, b) and g["goal_id"] not in locked_bp)
still_blocked_when_fixed = sorted(g["goal_id"] for g in goals if not goal_doable(g, h_fix, b_fix) and g["goal_id"] not in locked_bp)

# untaught inputs (pass 2) excluding the items handled by source findings
def untaught_items(gid):
    return sorted({u.split(":", 1)[1].split(" x")[0] for u in deps.get(gid, {}).get("untaught", []) if u.startswith("input:")})
SRC_HANDLED = set(NOSRC) | {"water"}
untaught = {gid: [i for i in untaught_items(gid) if i not in SRC_HANDLED] for gid in G}
untaught = {k: v for k, v in untaught.items() if v}

# side-branch order verdicts from the walkthrough workstreams
early_problem = set(re.findall(r"^- L\d+ `([^`]+)` \(draft line \d+\): problem", open(os.path.join(W, "ws_walk_early.md")).read(), re.M))
late_txt = open(os.path.join(W, "ws_walk_late.md")).read().split("## (d)")[1]
late_problem = set()
for line in late_txt.splitlines():
    if re.search(r"YES-WITH-UNTAUGHT-PREREQ|: NO\b|\(acq\)", line):
        for gid in re.findall(r"((?:craft|build|gather|activity):[a-z0-9_]+)", line): late_problem.add(gid)
        # bare ids following a family prefix ("craft:fur_boots L372, fur_cloak L373")
        m = re.match(r"- ((craft|build|gather):)", line.strip())
        if m:
            for bare in re.findall(r"(?:,|^- (?:craft|build|gather):)\s*([a-z0-9_]+) L\d+", line.strip()):
                late_problem.add(m.group(1) + bare)
late_problem &= set(G)

def by_station(*stations):
    out = []
    for g in goals:
        if g["kind"] == "craft" and g.get("recipe_used") in R and R[g["recipe_used"]].get("station") in stations: out.append(g["goal_id"])
    return out
def ids(*xs): return [x for x in xs if x in G]
doors = sorted(g["goal_id"] for g in goals if g["kind"] == "build" and re.search(r"_door$", g["key"]) and "doorway" not in g["key"])
doorways = sorted(g["goal_id"] for g in goals if g["kind"] == "build" and "doorway" in g["key"])
group_key = sorted(g["goal_id"] for g in goals if "GROUP_SHOWN_AS_KEY_ITEM" in g["static_flags"])
cat_c02 = sorted(k for k, v in cat["goals"].items() if any("C-02" in n for n in (v.get("notes") or [])) or k in doors or k in doorways or k == "build:thatch_roof_65")
legacy = [g["goal_id"] for g in goals if g["kind"] == "existing"]
LEGACY_WITH_AFTER = [x["id"] for f in ("starter_goals", "camp_goals") for x in D("items/%s.json" % f)["goals"] if x.get("after")]
gathers = [g["goal_id"] for g in goals if g["kind"] == "gather"]
non_legacy = [g["goal_id"] for g in goals if g["kind"] != "existing"]

F = {}
def add(fid, sev, cls, title, evidence, goals_, effect, correction="", test="", sources=""):
    F[fid] = dict(severity=sev, cls=cls, title=title, evidence=evidence, goals=sorted(set(goals_)), status_effect=effect,
                  correction=correction, test=test, sources=sources)

# ---------------- A. acquisition and sources
add("GA-01", "HIGH", "CONFIRMED_DEFECT", "Tanbark (tannin_bark) cannot be obtained, so the leather chain cannot be completed",
    "drops.json#harvest_yield.oak gives tannin_bark x3 but E-harvest is refused on any tree not in drops.json#fruit_tree (scenes/terrain_server/terrain_server.gd:1862-1865; src/client/harvest.gd:277-279); no trunk, felling, carcass, shop (data/npcs/shops.json hob.stock) or recipe row produces it; route tests hand it out (test_mission001_walkthrough.gd:606 'no route test proves stripping bark'; docs/ai-team/missions/M001/T19_RESULTS.md:35).",
    blocked_by["tannin_bark"], "BLOCKED",
    "Creator decision on the bark mechanism (see Q1); until then mark these goals blocked and do not publish their How-to.", "After a fix: strip/harvest tanbark in play, tan a hide.", "A-01")
add("GA-02", "HIGH", "CONFIRMED_DEFECT", "Pine tar cannot be obtained (Scots pine trunk only ever drops resin), so Tar, Water wheel and Sawmill are blocked",
    "data/tables/flora.json scots_pine yields [resin, pine_tar]; the trunk seed roll gives only the first drops.json#trunk.by_species row (src/stream/server_items.gd:6527-6533, 6886-6900): resin. E on a tree is refused (terrain_server.gd:1862-1865). Not sold by Hob.",
    blocked_by["pine_tar"], "BLOCKED", "Engineering fix (roll every by_species row) or creator decision; until then mark blocked.", "Fell Scots pines and confirm pine tar drops.", "A-02")
add("GA-03", "HIGH", "CONFIRMED_DEFECT", "Grain crops (wheat, barley, oats, rye) and flax cannot be harvested in play: the client never sends sow/harvest/water actions",
    "crops.json is the only source; the server implements sow/harvest (src/stream/server_items.gd:14635, 14757) but the client sends only ACT_TILL (src/client/held_item.gd:2064); no client code sends ACT_SOW, ACT_HARVEST or ACT_WATER_BED. Wild flax (E) gives plant fibre, linseed and flax seeds, never `flax`. test_farming.gd calls the server directly.",
    blocked_by["crops"], "BLOCKED",
    "Engineering: wire the farming client actions (implementation work, needs assignment); until then mark blocked.", "Sow, water and harvest a crop in play.", "A-04")
add("GA-04", "HIGH", "CONFIRMED_DEFECT", "The `water` ingredient is obtainable only from desert cactus; filling a container never creates it",
    "Only E on a cactus (flora.json cactus: hot_desert, dry_scrub) gives `water` items; filling a bucket/waterskin stores millilitres as slot wear (src/stream/server_items.gd:18396-18405); no craft code reads container water; water_bed consumes the item (14673-14690). Route tests give water directly (test_textile_route.gd:209; test_mission001_walkthrough.gd:612, 831).",
    blocked_by["water"], "BLOCKED",
    "Creator/engineering decision: let a filled container supply the `water` ingredient (recommended) or remove water from these recipes; until then mark blocked for non-desert starts.", "Draw water at a river and craft Leather / Concrete.", "A-03")
add("GA-05", "MED", "CONFIRMED_DEFECT", "Gather instructions that are wrong, placeholder or incomplete",
    "iron ore: rock outcrops need a bronze/iron/steel pick (boulders.json#ore.needs_material.iron; server_items.gd:5616-5622); the early route is bog iron with any spade (digging.json#bog_iron; server_items.gd:3405-3445); flint and limestone How-tos still say 'under verification' although both are sourced (drops.json#ground_scatter.bank.flint; boulders.json#flint, #ore.rocks); copper/tin need a pick held in hand; wool comes only from bighorn (carcass.json; wild sheep never spawns); logs are shoulder items, Q puts one down, crafts use logs within 3 m (server_items.gd:898-927, 15839-15925); Tanbark is the data name (gathered.json tannin_bark); clay's How-to still carries the placeholder 'verify the specific terrain/material shown by the game' (loam, silt and alluvium give clay under the topsoil: digging.json).",
    ids("gather:iron_ore", "gather:flint", "gather:limestone", "gather:copper_ore", "gather:tin_ore", "gather:wool", "gather:log", "gather:log_oak", "gather:log_spruce", "gather:tannin_bark", "gather:stone", "gather:clay"),
    "NEEDS_CORRECTION", "Rewrite each How-to from the acquisition evidence (ledger column acquisition_source_evidence).", "", "A-06..A-10, A-14..A-16, W-L01, W-L14, C-05")
add("GA-06", "HIGH", "CONFIRMED_DEFECT", "Ingredients whose source no goal teaches (the guide silently assumes them)",
    "pass2_deps.json 'untaught' (no goal teaches acquiring the input); sources per ws_acquisition.json, e.g. feather/raw_meat/sinew/fur (carcass.json, needs a weapon and knife), soil/worm/gravel (digging.json), honeyspindle_nectar (summer only, knife on hotbar by the accidental 'tar' suffix rule, drops.json#tool_rules), egg/shellfish/crab/seaweed (shore nodes, blocked while a water container is carried: server_items.gd:13969-13977), wild herbs, fruit, nuts, mushrooms (season and biome locked).",
    list(untaught), "NEEDS_CORRECTION",
    "Add acquisition steps or group discovery goals (ADD records) and name the source in each How-to; the Journal prerequisite chain must link a verified source for every raw input.", "", "A-11..A-13, A-23, pass 2")
add("GA-07", "MED", "CONFIRMED_DEFECT", "Side-branch goals listed before the goals that teach their prerequisites",
    "Walkthrough verdicts (ws_walk_early.md section c 'problem'; ws_walk_late.md section d YES-WITH-UNTAUGHT-PREREQ/(acq)); pass2_report.txt document-order check (craft:herb_fish, craft:juniper_trout before fish; craft:stone_hoe before hoe). Dependency levels in the draft headings were computed from recipe depth, not from where the prerequisite is taught.",
    sorted((early_problem | late_problem) - set(blocked_nosrc) - set(blocked_water_extra) - set(locked_bp)), "NEEDS_CORRECTION",
    "Recompute section order from the position of each prerequisite's teaching goal; move hunting into the main route (GA-11).", "", "W-18, W-L side branches")

# ---------------- B. main-route walkthrough
add("GA-10", "HIGH", "CONFIRMED_DEFECT", "Wooden - Hammer and Chopping block steps depend on which tree was felled: the 8 key species give LARGE blocks (hammer needs small), other trees give the plain Log and only small blocks (chopping block needs large)",
    "server_items.gd:9223-9276 (_chop_loose_log: a shoulder log of the 8 key species oak, beech, birch, maple, walnut, Scots pine, spruce, tropical hardwood -> 3 Large wooden blocks; the plain Log (stack 5, not shoulder) -> 3 small softwood blocks); server_items.gd:6627-6633 (_log_number: a retired or missing species log falls back to the plain Log: alder, willow, rowan, balsam fir, acacia, mangrove, sweet chestnut, fruit trees); recipes.json chopping_block needs a Large wooden block and no recipe turns small blocks into large; recipes.json wooden_hammer needs the wooden_block group (Hardwood/Softwood block) (wood_species.json ingredient_groups.wooden_block); 'Small wooden blocks' (small_blocks_from_large) is the missing step, used by test_mission001_walkthrough.gd:482-484 (passed on David4 at dc2fa52). CONTROLS.md:72 says 4/12 blocks (stale; data 3/3).",
    ids("activity:chop_log_blocks", "hammer", "craft:chopping_block", "craft:wooden_block", "craft:wooden_block_soft"), "NEEDS_CORRECTION",
    "Name a key-species tree in rows 9-11 and 16; correct row 11's yield; move craft:wooden_block (and _soft) into the main route between rows 11 and 12.", "", "W-01")
add("GA-11", "HIGH", "CONFIRMED_DEFECT", "'Obtain hide' (main 45) has no hunting step before it: no main-route item can strike an animal",
    "server_items.gd:2243-2259 (_strike accepts kind weapon with damage only); stone axe/pickaxe/knife are kind tool (items.json); dressing needs a knife in hand (server_items.gd:2288-2296). Spear, snare and the legacy 'knife' kill goal are all in the additional sections.",
    ids("gather:hide", "gather:bone", "gather:animal_fat", "spear", "knife", "craft:wooden_spear"), "NEEDS_CORRECTION",
    "Move craft:wooden_spear (or craft:snare) and the legacy knife kill-and-dress goal into the main route before row 45.", "Hunt and dress a deer/rabbit with the listed tools.", "W-02")
add("GA-12", "MED", "CONFIRMED_DEFECT", "Logs are never explained: species logs are shoulder-carried one at a time (the plain Log stacks to 5), Q puts one down, recipes and blueprints use logs within 3 m",
    "items.json log_<species> carry shoulder, stack 1; items.json log stack 5; server_items.gd:898-927, 15839-15925, 8164, 17005-17006; key_bindings.gd:30 (Q).",
    ids("gather:log", "activity:chop_log_blocks", "gather:log_oak", "gather:log_spruce"), "NEEDS_CORRECTION",
    "Add one sentence on shoulder logs and the 3 m rule to the first log row and to the Journal's building basics (GA-33); later log-cost rows then need no change.", "", "W-04, A-14")
add("GA-13", "HIGH", "CONFIRMED_DEFECT", "Firewood and small blocks: the taught action never completes the goal",
    "Two real firewood paths: E-split at the chopping block (server_items.gd:9170-9207, 2/4 firewood per block, no _goal_made) and the block's F Craft recipe chopping_hard_firewood (1 hardwood log -> 12, recipes.json). Main row 19 teaches the E split but cites the recipe; only the queued craft calls _goal_made (server_items.gd:17414). Axe on a loose log (9223-9278) is also uncredited. Title 'Split your first firewood' differs from the item name 'Hard firewood'.",
    ids("craft:firewood", "craft:firewood_soft"), "NEEDS_CORRECTION",
    "Teach the recipe path (F at the block) or credit the hand split with a made/unit event; name the item 'Hard firewood'.", "Split firewood both ways and confirm the goal completes.", "W-05, R-05, C-05")
add("GA-14", "MED", "CONFIRMED_DEFECT", "Placing kits (campfire, chopping block, Thatch - Bed) is never explained",
    "kind placeable goes to the pack, not the hotbar; I, select, Use (E) to hold, left-click (CONTROLS.md:59, 67; hints.json place_fire). 2.5 m gap between structures, 2 m between fires (server_items.gd:8418; structures.json gap_m).",
    ids("activity:place_campfire", "activity:place_chopping_block", "bed"), "NEEDS_CORRECTION", "State the exact placement controls and spacing.", "", "W-06, W-16")
add("GA-15", "MED", "CONFIRMED_DEFECT", "Campfire pot: only snaps to a small fire with no logs, but follows the bonfire step",
    "placement_rules.gd:10, 66-67, 731-743 (POT_FIRE_STATES excludes the bonfire); server_items.gd:8371-8379 ('The fire is too big for a pot'); test_campfire_pot.gd:166-172 (passed on David4 at dc2fa52).",
    ids("build:campfire_pot"), "NEEDS_CORRECTION", "Tell the player to use a small fire (no logs) or lay a second fire.", "", "W-07")
add("GA-16", "MED", "CONFIRMED_DEFECT", "Lean-to cost and its 60 leaves are never taught",
    "blueprints.json lean_to cost 20 stick, 60 leaves, 6 twine; leaves come from felled broadleaf crowns (none from conifers, none in winter) or axing bushes (drops.json trunk crown_leaves, leaves_note, shrub_work).",
    ids("shelter", "fell"), "NEEDS_CORRECTION", "Give the cost and the leaf source.", "", "W-08")
add("GA-17", "MED", "UNVERIFIED_ASSUMPTION", "Thatch - Bed 'under cover' may be refused beside Crude pieces while the client ghost shows green",
    "server_items.gd:8406-8418 exempts beds from the 2.5 m gap only inside a lean-to box; placement_rules.gd:12, 745-765 checks only states 5/6/7 on the client; structures.json shelter_needed is read by no script.",
    ids("bed"), "NEEDS_TEST", "Say 'inside your lean-to'; confirm in play.", "Place a Thatch - Bed beside Crude walls and inside a lean-to.", "W-09")
add("GA-18", "MED", "CONFIRMED_DEFECT", "Roof panels: must rest on a wall top or panel edge; mouse wheel flips rise/fall; never explained",
    "server_items.gd:3730; placement_rules.gd:306-338; held_item.gd:990-992; CONTROLS.md lacks the roof wheel.",
    ids("build:thatch_roof", "build:thatch_roof_65"), "NEEDS_CORRECTION", "Add the snapping rule and the wheel control.", "", "W-10")
add("GA-19", "MED", "CONFIRMED_DEFECT", "Quantities the player needs are not stated (fibre, thatch, bricks, iron, pine tar, fasteners, concrete)",
    "Main rows 5-43 need 55 twine (165 fibre) and 145 thatch and 34 bricks (blueprints.json costs); row 4 asks for 12 fibre. Pine tar: Water wheel needs 4 Tar = 20 pine tar, How-to says 5 (recipes.json tar, water_wheel). Main route needs ~108 iron ingots, ~22 steel, ~690 fuel (ws_walk_late.md W-L12).",
    ids("fibre", "gather:thatch", "craft:brick", "build:clay_hearth", "build:oven", "craft:iron_ingot", "gather:pine_tar", "craft:tar", "craft:nails", "craft:iron_band", "craft:concrete", "craft:clay_roof_tile"),
    "NEEDS_CORRECTION", "State the needed count on each producing row.", "", "W-11, W-L12")
add("GA-20", "HIGH", "CONFIRMED_DEFECT", "Burning stations: Smithy, Blast furnace and Master smithy craft only while lit; a cold one needs Charcoal or Coal in the pack to light it, which the guide never mentions",
    "structures.json blacksmithy/large_forge/master_forge craft_needs_lit, fuel 'fuel', fuel_s 1800; server_items.gd:13066-13092, 13209-13220; test_stations.gd:131, 162-163 (passed on David4 at dc2fa52).",
    ids("build:blacksmithy", "build:large_forge", "build:master_forge") + by_station("brick_forge", "blast_furnace", "master_smithy"), "NEEDS_CORRECTION",
    "Add 'the station must be lit, or keep Charcoal or Coal in your pack and crafting here lights it (1 fuel per 30 min)' to the station rows and the Journal station detail.", "", "W-L02")
add("GA-21", "HIGH", "CONFIRMED_DEFECT", "Sawmill placement rules (a foundation raised at least 0.5 m beside fast deep water) are not taught",
    "structures.json saw_mill needs_base_lift_m 0.5, needs_running_water; server_items.gd:3786-3792, 3835-3875 (refusals; _station_site accepts any foundation:true piece lifted 0.5 m, so the Crude - Foundation of main row 28 qualifies: structures.json thatch_floor max_rise_m 0.6); data/water_flow.json.",
    ids("build:saw_mill"), "NEEDS_CORRECTION", "Tell the player to raise a Crude - Foundation 0.5 m at a fast river bank first; say the Sawmill is optional (hand saw yields are equal).",
    "Place a Sawmill in a typical world; record whether a qualifying river is usually reachable.", "W-L03")
add("GA-22", "MED", "DESIGN_RECOMMENDATION", "Kiln charcoal (the catalog's main fuel route) has no goal and the Kiln comes after the fuel-hungry metal steps",
    "structures.json kiln use kiln, per_log 100, batch_logs 6 (server_items.gd:9163-9164, 9400, 9421-9449, which also does not credit goals); master s2.6; the main route needs ~690 fuel (W-L04).",
    ids("craft:charcoal", "build:kiln", "craft:mortar"), "NEEDS_CORRECTION", "Move mortar and the Kiln before the Smelter; ADD 'Burn charcoal in the Kiln'.", "", "W-L04, R-05, C add #18")
add("GA-23", "MED", "OWNER_DECISION", "Bronze comes after iron in the main route; the approved catalog supports both orders, and the Stone - Forge adds nothing at that point",
    "DYNASTY_MASTER_ITEMS.md s2.7 item 1 [D1] (Dave: a wilderness route to the Iron Hand Saw with no bronze step) and item 4 [C] (bronze is a real rung before iron, keeping that wilderness route); the draft follows item 1; structures.json blacksmithy also forge 1 (the Smithy already serves bronze recipes); test_stations.gd:103-122.",
    ids("gather:copper_ore", "gather:tin_ore", "craft:copper_ingot", "craft:tin_ingot", "craft:bronze_ingot", "build:stone_forge", "craft:bronze_hammer", "craft:bronze_pickaxe", "craft:bronze_sword"), "NONE",
    "Creator decision (Q11): keep iron first (item 1) and present bronze as an optional side rung, or move main rows 83-91 directly after the Smelter (item 4).", "", "W-L05, reviewer round 1")
add("GA-24", "HIGH", "CONFIRMED_DEFECT", "Doors: listed before their frames, How-to never says 'aim at an empty doorway', and each main-route single door needs its own empty single doorway",
    "placement_rules.gd:32, 587-627 (doorway_fit: a door needs an empty doorway of the same opening shape, any tier, one per frame); server_items.gd:3733-3740; test_doors.gd (passed on David4 at dc2fa52). Crude arched/double/double-arched doors sit at draft level 2, their doorways at level 4.",
    doors + ids("build:thatch_doorway"), "NEEDS_CORRECTION",
    "Every door How-to: 'aim at the empty opening of a matching doorway (any tier); the door snaps in'; order each door after a frame of its shape; say a doorway is an empty frame.", "", "W-03, W-L06, C-02")
add("GA-25", "MED", "UNVERIFIED_ASSUMPTION", "Door, doorway and Crude - Roof 65 content is implemented but not yet player-verified",
    "catalog_ledger.json IMPLEMENTED - UNVERIFIED for entries 1255-1303; docs/ai-team/missions/BUGLIST-002/LEDGER.md all NEEDS PLAYER VERIFICATION; BUGLIST-001 BUG-011 open (Crude - Roof corner question).",
    cat_c02, "NEEDS_TEST", "Keep the goals; confirm on Dave's F6 checklist before publishing.", "Dave's BUGLIST-002 F6 checklist (doors, doorways, Roof 65).", "C-02")
add("GA-26", "MED", "CONFIRMED_DEFECT", "Construction tiers in the main route are incoherent: four lone foundations, no walls/roofs for those tiers, doors placed after the Master smithy without a real dependency",
    "Main rows 79-82 and 106-118; costs per blueprints.json show Rustic/Refined/Sturdy doors need only planks/boards and iron, Engineered needs no steel (ws_walk_late.md construction matrix).",
    ids("build:wood_foundation", "build:log_foundation", "build:foundation_section", "build:brick_foundation", "build:refined_door", "build:rustic_door", "build:sturdy_door", "build:engineered_door"), "NEEDS_CORRECTION",
    "Teach each tier as a block (foundation, wall, doorway, door, window, roof) at the point its materials first exist.", "", "W-L07")
add("GA-27", "MED", "CONFIRMED_DEFECT", "Stonecutter's bench is a dead end in the main route: every recipe keeps a Bronze - Chisel the route never makes",
    "recipes.json bench_stone_block, carved_stone_block, carved_stone_shingle keep bronze_chisel; master s2.1 chisel is sculpture/art only.",
    ids("build:stonecutters_bench"), "NEEDS_CORRECTION", "Move it to the side branch, or add craft:bronze_chisel before it.", "", "W-L08")
add("GA-28", "LOW", "CONFIRMED_DEFECT", "Workbench levels are not explained; the draft implies the Carpenter's bench is needed for the Stone - Workbench",
    "structures.json workbench/log_workbench/stone_workbench station_level 1/2/3, add-ons tool_rack/vice +1 each (server_items.gd:13184-13190); water_wheel and spyglass need L3; test_stations.gd:80, 117.",
    ids("build:log_workbench", "build:stone_workbench", "craft:water_wheel", "build:tool_rack", "build:vice", "craft:spyglass"), "NEEDS_CORRECTION",
    "State the level each station or add-on gives and what it unlocks; offer Workbench + Tool rack + Vice as the cheap level 3.", "", "W-L10")
add("GA-29", "LOW", "CONFIRMED_DEFECT", "Add-on rows do not say which station they attach to or what they do",
    "structures.json bellows/quenching_trough addon_of brick_forge (adds_level false; within 5 m of a Smithy), fireplace_cooking_crane addon_of fireplace; smithing.json temper; server_items.gd:13064-13065.",
    ids("build:bellows", "build:quenching_trough", "build:fireplace_cooking_crane", "build:master_forge"), "NEEDS_CORRECTION", "One placement-and-effect sentence each (Master smithy: +1/+2 craftsmanship).", "", "W-L11, W-L16, C-07")
add("GA-30", "LOW", "CONFIRMED_DEFECT", "Group ingredients are named by their key item (Spruce log, Oak log, Hardwood block, Knife, Axe, Fuel) instead of the in-game labels",
    "wood_species.json group_labels (Softwood log, Hardwood log, Wooden block, Any knife, Any axe, Any saw; item_table.gd cost_name); static flag GROUP_SHOWN_AS_KEY_ITEM in goals_parsed.json.",
    group_key + ids("craft:charcoal", "craft:iron_ingot", "craft:steel_ingot", "craft:copper_ingot", "craft:tin_ingot"), "NEEDS_CORRECTION",
    "Use the group label and list the accepted members once.", "", "W-L13, W-14, pass 1")
add("GA-31", "HIGH", "CONFIRMED_DEFECT", "24 goals target blueprints that no player can build (locked water network, garden pieces, Wool - Rug)",
    "blueprints.json rows known:false, locked:true; server_items.gd:8138 (_can_blueprint refuses unknown rows); test_blueprints.gd:199. 23 are approved catalog KEEP (buildables_plan.md B6), Wool - Rug is FUTURE.",
    locked_bp, "BLOCKED", "Keep them out of the active guide (future list) until the blueprints are made learnable.", "", "C-01, W-17, W-L15")
add("GA-32", "LOW", "DESIGN_RECOMMENDATION", "Main-route rows without a purpose at that point (sand at 35, thread at 44, Leatherworking table, Tailor's table, Loom, Preserving jar)",
    "First consumers come much later (mortar at main 69; thread consumers in side branches).", ids("gather:sand", "craft:thread", "build:leatherworking_table", "build:tailors_table", "build:loom", "build:preserving_jar"), "NONE",
    "Move each next to its first use or state its purpose.", "", "W-13, W-L18")
add("GA-33", "LOW", "DESIGN_RECOMMENDATION", "Generic station rules (2.5 m spacing, hotbar tools, oven near the hearth) should appear once in the guide",
    "structures.json gap_m 2.5; server_items.gd:8418, 5979-5983, 8155-8156.", ids("build:oven", "workbench", "axe"), "NONE", "Add a short 'building basics' Journal entry.", "", "W-15, W-16")
add("GA-34", "LOW", "DESIGN_RECOMMENDATION", "Fire row text: the placed kit already holds sticks; 'add sticks with F' is unnecessary; the kit description still says 'light it with fibre'; rain is never mentioned",
    "server_items.gd:3822-3828; CONTROLS.md:73; items.json campfire_kit description; server_items.gd:7589-7611 (an uncovered fire in rain goes out; drizzle makes lighting a chance roll).", ids("fire", "craft:campfire_kit"), "NONE", "Simplify to 'Press E on the laid fire'.", "", "W-12, R-13")

# ---------------- C. runtime, persistence, migration
add("GA-40", "HIGH", "CONFIRMED_DEFECT", "`after` prerequisites gate completion, contrary to 'goals are guidance, not locks'",
    "server_items.gd:15740-15747 (_goal_open) used at 15763; legacy chain fibre -> twine -> axe -> fell -> ...; counters keep counting so event/made goals pay late, possession goals can be lost; test_goals.gd 'a goal done early waits for its after' (passed on David4).",
    LEGACY_WITH_AFTER, "NONE", "Drop `after` from the completion test; keep it only for display order and Journal prerequisite links.", "Out-of-order: build a lean-to before gathering 12 fibre; confirm immediate credit.", "R-01, U-13")
add("GA-41", "HIGH", "CONFIRMED_DEFECT", "Possession checks lose credit and accept bought/admin/chest items",
    "server_items.gd:15715-15734 (have_item, have_item_any, or_have); starter_goals.json fibre have 12, hammer/hoe have_item_any, winter_store hold 5, fish fallback, axe or_have; Hob sells plant fibre, stone axe, twine, torch (data/npcs/shops.json).",
    ids("fibre", "hammer", "hoe", "winter_store", "fish", "axe"), "NEEDS_CORRECTION",
    "Use history counters (made:, got:) instead of current possession; winter_store's 'hold 5' is a creator call.", "Make twine as fibre arrives; confirm the fibre goal still completes.", "R-02, C-11")
add("GA-42", "HIGH", "OWNER_DECISION", "Legacy item rewards conflict with money-only rewards (twine pays 4 sticks, fell pays 3 kindling, story's +1 reputation is ignored)",
    "starter_goals.json twine/fell reward.item; camp_goals.json story reward.rep (ignored at server_items.gd:15766-15775); test_goals.gd asserts the sticks and kindling (passed on David4). Creator ruling relayed with this mission's brief (recorded in project memory for the PLAYTEST-001 goals, 13 Nov 2026): coin rewards stay as they are until Dave says otherwise. Item rewards save to inventories.json before characters.json (server_items.gd:1490, 1545): a crash between them can pay an item reward twice.",
    ids("twine", "fell", "story"), "NEEDS_CORRECTION", "Recommend the draft's own coin values (twine 4, fell 6, story 3 copper) replace the item and reputation rewards (Q3).", "", "R-03, E-09")
add("GA-43", "MED", "CONFIRMED_DEFECT", "Some item-making paths never credit craft goals (kiln charcoal, fire cooking, pick yields, legacy instant craft)",
    "_goal_made is called only from _craft_tick (server_items.gd:17414); uncredited: 9170-9203, 9223-9278, 9421-9449, 9834-9864, 7650-7668, 1218 (ACT_CRAFT).",
    ids("craft:charcoal", "craft:roast_forage"), "NONE", "Add one made-credit helper to the player-driven paths; decide whether purchases count (they should not).", "Make charcoal in the Kiln; roast food on a fire.", "R-05")
add("GA-44", "MED", "CONFIRMED_DEFECT", "Made counts are per craft action, not per item: count>1 goals mean 'crafts', not 'items'",
    "server_items.gd:17414 (one _goal_made per finished craft), 17396-17401 (a sealed batch counts once); jerky needs 2 crafts = 4 jerky; twine 2; dry_berries 3.",
    ids("twine", "jerky", "dry_berries"), "NEEDS_CORRECTION", "Count units produced (recommended) or say 'crafts' in the text.", "", "R-06")
add("GA-45", "MED", "CONFIRMED_DEFECT", "Activity goals for log chopping and fire size have no server event",
    "Only drink, ate_food, fire_lit, carcass_worked, dug_under, path_laid, tree_felled, fish_caught, placed, wanted_order, sold are emitted (_goal_event calls). Fire tiers verified: 3 firewood-class pieces -> medium, 3 logs -> bonfire, a hung pot caps at medium, damp wood one tier lower (cooking.json min_pieces 3, fire_tiers; server_items.gd:7345-7365, 7354-7355, 7361, 7614); tier changes in ~10 places (2460, 4127, 4544, 7440/7443, 7484, 7512, 7548, 7581, 7614, 9819).",
    ids("activity:chop_log_blocks", "activity:medium_fire", "activity:bonfire"), "NONE",
    "New events: log_chopped in _chop_loose_log; one fire-tier helper emitting fire_tier with the acting peer (store last_peer on the fire). Medium = tier >= medium.", "Grow a fire to medium and bonfire; chop a log.", "R-07")
add("GA-46", "MED", "OWNER_DECISION", "Gather goals have no acquisition event; which acquisitions count is undecided",
    "No pickup/harvest path calls a goal hook; _report_gains (server_items.gd:4929-4947) only feeds the client; chest withdrawals are reported as pickup (10042-10066).",
    gathers, "NONE", "Add got:<item> counters for first-hand sources only (pickup, harvest, dig, mine, carcass, fishing, crop); creator to confirm bought/looted/chest items do not count (Q6).", "", "R-08")
add("GA-47", "MED", "CONFIRMED_DEFECT", "One item pays two milestones (legacy any-of checks overlap the new tier goals); data lists a non-item",
    "starter_goals.json hammer have_item_any [wooden_hammer, wooden_hammer_soft, stone_hammer] (wooden_hammer_soft is a recipe id, not an item); hoe [wooden_hoe, stone_hoe, steel_hoe] (iron_hoe missing); workbench what_any [workbench, log_workbench] (test_goals.gd 'a log workbench also completes the workbench goal').",
    ids("hammer", "hoe", "workbench"), "NEEDS_CORRECTION", "Each legacy goal checks only its own basic item; each upgrade pays only its own goal.", "", "R-09, C-03")
add("GA-48", "LOW", "DESIGN_RECOMMENDATION", "Overlapping goal chains (craft/place/light campfire; craft/place chopping block; bed and Thatch - Bed; knife and Stone - Knife; fell and Collect a log; pine tar and Tar; winter store)",
    "ws_catalog.md section 5; legacy knife check is carcass_worked while its title crafts the knife.",
    ids("craft:campfire_kit", "activity:place_campfire", "craft:chopping_block", "craft:rough_bed_kit", "craft:stone_knife", "knife", "gather:log", "craft:tar", "winter_store", "craft:stone_hammer", "craft:stone_hoe", "craft:steel_hoe", "build:log_workbench"),
    "NONE", "Keep each only where it teaches a distinct action; otherwise group (owner decision with the reward model, Q2).", "", "C-03, W-19")
add("GA-49", "MED", "CONFIRMED_DEFECT", "Performance: every goal is re-checked for every player 4 times a second and on every event",
    "server_items.gd:15792-15822 (_goals_tick), 15749-15789 (_goals_check loop), slow tick 0.25 s (376, 1395); estimate 2-5 ms per player per tick at 651 goals, 65-170 ms for 32 players (not measured; the _goals_detail slow-tick split can measure it).",
    [], "NONE", "Index goals by counter key; test only goals listed under the changed key; full catch-up once at join.", "Measure _goals_detail with the 651-goal data on David4.", "R-10")
add("GA-50", "MED", "OWNER_DECISION", "Goals are per character: every new character can earn the whole catalog again, and coins can move between characters",
    "identity_provider.gd:1-24 (character = account key); server_items.gd:593-604 (forget_key), 9948 (looting remains), 12811-12815 (death moves the purse).",
    [], "NONE", "Creator decision (Q5): accept, or cap rewards per account.", "", "R-11")
add("GA-51", "LOW", "CONFIRMED_DEFECT", "Legacy goal text does not match its live check or recipe",
    "smoke_fish: live recipe cook_smoked_fish = 1 fish + 1 Salt at the Smoker; dry_berries: 3 berries at the Drying rack; salted_fish needs Trout; fish: rod needs a hook (recipes.json fishing_rod); story counts only Edda (server_items.gd:15200-15223); night_walk counts a torch in the pack (15185-15186); fur_for_winter is worn warmth >= 0.7.",
    ids("smoke_fish", "dry_berries", "salted_fish", "fish", "story", "night_walk", "fur_for_winter"), "NEEDS_CORRECTION", "Rewrite from the live recipes and checks.", "", "R-12, C-06, A-24")
add("GA-52", "LOW", "DESIGN_RECOMMENDATION", "Loose legacy checks (bed not under cover, path not camp-to-water, any food for berries, torch crafted not carried, any knife)",
    "ws_runtime.json goals entries; server_items.gd checks.", ids("bed", "path", "berries", "torch_night", "knife"), "NONE", "Accept, or tighten when the catalog is implemented.", "", "R-12")
add("GA-53", "LOW", "CONFIRMED_DEFECT", "Stale metadata: needs_code true on four working goals; '_about: read by nothing yet' in both goal files",
    "camp_goals.json needs_code on jerky, salted_fish, story, night_walk; server_items.gd:15635-15640 reads both files; test_goals.gd covers story and night_walk.",
    ids("jerky", "salted_fish", "story", "night_walk"), "NONE", "Fix when the canonical goal file replaces them.", "", "R-13")
add("GA-54", "LOW", "DESIGN_RECOMMENDATION", "Admin actions earn goals (admin give, free crafts, free-build placements)",
    "server_items.gd:1232-1241, 8435.", [], "NONE", "Exclude admin actions or flag admin characters.", "", "R-14")
add("GA-55", "MED", "CONFIRMED_DEFECT", "Save window: goals, coins and counters are saved together atomically, but up to ~30 s can be lost on a crash",
    "server_items.gd:18178, 5221-5260 (one atomic characters.json write), 50 and 1425-1435 (30 s autosave when dirty); clean shutdown saves synchronously (terrain_server.gd:2943).",
    [], "NONE", "Bring the next save forward after a completion.", "Kill the server after a completion; confirm state on restart.", "R-04")
add("GA-56", "HIGH", "OWNER_DECISION", "Migration: existing characters' counters would complete many new goals at once",
    "made:* and event:placed:* counters exist since 31 Oct 2026; keep the 28 legacy ids and counter formats (hints.json 14 goal references; test_goals.gd); add a goals_v version and run catch-up once at join.",
    [], "NONE", "Creator decision (Q4): pay, grandfather without pay, or pay main route only; never re-pay a done id.", "", "R-11 migration plan, U-11")
add("GA-57", "MED", "CONFIRMED_DEFECT", "The draft has no stable goal IDs",
    "PLAYER_GOALS_REWARDS_DRAFT.md rows carry only an HTML marker (craft:<item>, build:<structure>, ...); goal ids from structure keys no longer match names (build:thatch_* = Crude).",
    non_legacy, "NONE", "Adopt the ledger's IDs (legacy ids unchanged; others '<kind>:<key>'); never derive display names from ids.", "", "pass 1, C-05")
add("GA-58", "LOW", "DESIGN_RECOMMENDATION", "70 craft goals are intermediate components that could be grouped",
    "ws_catalog.md section 6 (fasteners, bronze route, leather chain, cloth, masonry, roof coverings, wood processing, machine parts, prep-stage foods).",
    [k for k, v in cat["goals"].items() if v.get("intermediate_only")], "NONE", "Group by family (Q2); keep gate milestones (iron ingot, Plank, Hardwood board, Leather, Steel ingot) single.", "", "C-04")
add("GA-59", "LOW", "CONFIRMED_DEFECT", "Draft self-audit statements are inaccurate",
    "Section 3 lists 43 'unconfirmed' raw sources: 37 are sourced (24 sourced, 13 conditional), 6 confirmed unobtainable, and tannin bark, pine tar and obsidian (not listed) have none (ws_acquisition.md); headings L2 '36 goals' and L4 '37 goals' have 35 and 36 rows.",
    [], "NONE", "Replace section 3 with this audit's results.", "", "A, E-13")

# ---------------- D. economy (owner decisions; per-goal recommendations live in the ledger)
add("GA-70", "HIGH", "OWNER_DECISION", "Total payout 15,670 copper is far above ordinary earning (ASSUMED model: 14.6x the picking wage over the modeled work; 1.70x the net coin Hob could pay one player)",
    "tools/economy.py -> work/ws_economy.json totals. Picking wage: Dave's rule '4 hours of full-time picking pays about 40 to 60 copper' (0.17-0.25/min; docs/ECONOMY_FIRST_DAY.md:3-6), 0.2/min is the midpoint used by Sal (line 38). Hob: purse 300 then +100 per real hour (data/npcs/shops.json; server_trade.gd:397-414), so over the modeled 89 h at most 300 + 8,915 = 9,215 net (buying from Hob refills the purse: server_trade.gd:335, 517; the purse is shared by all players, so this is a single-player ceiling). Goal coin bypasses the purse (server_items.gd:15771-15772). Both ratios rest on the ASSUMED effort model (a lower bound): if real play takes 1.7x the modeled time or more, Hob's ceiling exceeds the draft total, though the picking-wage ratio stays above 8x until play takes 1.8x longer.",
    [], "NONE", "Recommended ~%d copper (main route %d) with class bands and a family-lead model (Q2)." % (eco["totals"]["recommended_total"], eco["totals"]["recommended_main"]), "Time real play to calibrate.", "E-01")
add("GA-71", "HIGH", "DESIGN_RECOMMENDATION", "Rewards follow dependency depth, not effort or significance; variants take most of the money; stations are not monotone",
    "Spearman reward vs level 0.886, vs effort 0.319 (additional route); L15 79/84 pay 60, L17 all 120; Crude chair/table/bench/stool 80 each vs Smithy 40; Stone - Workbench 120 vs Blast furnace 40; furniture/placeables 4,827 and building pieces 4,275 of 15,670 (ws_economy.md E-02..E-04).",
    [], "NONE", "Price by class (ws_economy.md bands), family leads pay the band, variants 1-2 plus a small effort top-up.", "", "E-02, E-03, E-04")
add("GA-72", "MED", "DESIGN_RECOMMENDATION", "Tier-entry materials are priced inversely (Wooden pin 30 vs first Iron ingot 7; Concrete 40; Steel 15)",
    "goals_parsed.json coin_copper; ws_economy.json recommended.", ids("craft:wooden_pin", "craft:iron_ingot", "craft:concrete", "craft:steel_ingot", "craft:lumber", "craft:hardwood_board", "craft:nails", "craft:hinges", "craft:iron_band"),
    "NONE", "Iron 15, steel 25, concrete 15, plank/board 8, fasteners 7.", "", "E-05")
add("GA-73", "MED", "OWNER_DECISION", "Early cash shock: by main goal 38 the draft has paid 200 copper, enough to buy one of everything Hob sells (198)",
    "ws_economy.md milestones; Hob stock prices (data/npcs/shops.json).", [], "NONE", "Creator: should the first hour pay about one picking day? (Q2)", "", "E-06, E-07")
add("GA-74", "LOW", "DESIGN_RECOMMENDATION", "Bonfire pays twice the medium fire for about two minutes more work", "goals_parsed.json activity:bonfire 10, activity:medium_fire 5.",
    ids("activity:bonfire"), "NONE", "5 copper.", "", "E-11")
add("GA-75", "LOW", "DESIGN_RECOMMENDATION", "Catalog/economy notes outside this audit's authority (report only)",
    "Crude door 50 stick + 100 twine (350 copper of inputs) vs Rustic 5 planks; Fortified double door 1,800 of inputs; charcoal value 0.15 rounds to 0 (server_trade.gd:371); species logs sell for 24-48 with no lot rule (E-10); steel_striker live recipe for a FUTURE item (recipes.json #183; recipe_table.gd:49 no future filter); four Log furniture items live while their structures are retired.",
    [], "NONE", "For the catalog owner; no change proposed here (catalog freeze).", "", "E-08, E-10, E-12, C-08, C-09")

add("GA-35", "LOW", "CONFIRMED_DEFECT", "A tree too short for one log gives no log at all", "server_items.gd:6683, 6748 (split_trunk count <= 0 -> _split_small: firewood, kindling and sticks only).",
    ids("fell", "gather:log"), "NEEDS_CORRECTION", "Say 'fell a full-grown tree'.", "", "reviewer round 1")
add("GA-36", "MED", "CONFIRMED_DEFECT", "Drink and eat goals only count when the player is thirsty or hungry, and a new character starts full",
    "_new_vitals sets fed and wet to their caps (server_items.gd:10218-10219); _drink_water refuses at the cap ('You have had enough water.', 18408-18412) and refuses salt water (18386-18387); a held container with room fills instead (18396-18406); ACT_DRINK / ACT_EAT emit the goal only if the vital rose (1098-1109); test_goals.gd:85 lowers wet first.",
    ids("drink", "berries"), "NEEDS_CORRECTION", "Say 'when you are thirsty, drink fresh water (not the sea) with no empty container in hand' and 'once you are hungry'.", "First minutes of a new character at a river.", "reviewer round 1")
add("GA-37", "LOW", "DESIGN_RECOMMENDATION", "Log-cost builds rely on the 3 m log rule taught once (GA-12)",
    "server_items.gd:8164, 15895-15928 (_pull_nearby_logs serves every blueprint and recipe that costs logs).",
    [g["goal_id"] for g in goals if g["kind"] == "build" and g["key"] in B and any(n.startswith("log") for n, _ in B[g["key"]]["cost"])],
    "NONE", "No per-row change once GA-12 is fixed; the Journal can link the rule.", "", "reviewer round 1")
add("GA-38", "MED", "DESIGN_RECOMMENDATION", "One carcass dressing would pay several goals at once (legacy knife plus hide, bone, animal fat once got: counters exist); site-finish credit goes to the finisher, not the placer",
    "carcass_worked (server_items.gd:2335) completes the legacy knife goal; the same dressing yields hide, bone, fat and sinew (carcass.json); site finish 8452-8474, 8954.",
    ids("knife", "gather:hide", "gather:bone", "gather:animal_fat"), "NONE", "Accept as a teaching burst with small gather rewards, or merge into one 'dress your first carcass' goal (part of Q2).", "", "reviewer round 1")
add("GA-39", "LOW", "UNVERIFIED_ASSUMPTION", "Wool goods depend on bighorn only (alpine and bare rock); whether a typical start can reach them is untested",
    "carcass.json wool from bighorn; data/animals/spawn_plan.json wild_sheep 'needs: spawn + model'.",
    WOOL_GOALS, "NEEDS_TEST", "Keep; confirm a wool route in play or mark the wool family as regional.", "Find and hunt a bighorn from a typical start.", "A-16, reviewer round 1")

# ---------------- E. Journal, HUD, placard, keyboard (system-level)
U = [("GA-80", "HIGH", "CONFIRMED_DEFECT", "J, G and M are taken or unwired: J = jitter test, bare G = Admin Fly (and Store All in the inventory), Ctrl+Shift+G = GPU probe; M unused",
      "key_bindings.gd:50, 53, 65, 66; terrain_client.gd:4289-4293 (the inventory branch returns first, so plain-G Store All is safe).", "Move admin/debug actions per ADMIN_KEYBINDINGS_POLICY.md before adding J/G/M.", "U-01, U-02, U-04"),
     ("GA-81", "HIGH", "CONFIRMED_DEFECT", "Modifiers are ignored for held and inventory actions: Ctrl+Shift+G with a container open runs Store All; Ctrl+Shift+R runs Repair",
      "key_bindings.gd:200-201 (matches() skips modifiers for held/inventory rows).", "Reject events holding both Ctrl and Shift for those rows.", "U-03"),
     ("GA-82", "HIGH", "CONFIRMED_DEFECT", "Admin defaults break the Ctrl+Shift rule today, and hard-coded keys bypass the binding table",
      "key_bindings.gd:53-70; terrain_client.gd:4347-4349 (plain +, numpad +/- spring controls); terrain_preview.gd:228 (bare G fly in a dev scene).", "Apply the policy map; remove hard-coded keys.", "U-20"),
     ("GA-83", "HIGH", "CONFIRMED_DEFECT", "Several admin actions have no server-side authority check (fly, NPC teleport, jitter teleport, spring water rate)",
      "terrain_server.gd:1138 (spring rate, no admin check); check_admin false today so everyone is admin; dig, rabbit, spyglass and starter items are checked.", "Add server checks; a chord is not authorisation (security-sensitive: Dave's approval).", "U-21"),
     ("GA-84", "HIGH", "CONFIRMED_DEFECT", "Saved key bindings can keep non-compliant admin chords; loader and editor accept any modifiers",
      "key_bindings.gd loader/set_binding/swap; user://key_bindings.json.", "Sanitise on load; force Ctrl+Shift on the admin group; block swapping a plain key onto it.", "U-23"),
     ("GA-85", "MED", "CONFIRMED_DEFECT", "Help strings and docs name old keys (HELP_TEXT 'G or F'; Shift+F3 missing from CONTROLS.md; PROTOCOL.md header says 56, code is 118)",
      "key_bindings.gd HELP_TEXT; CONTROLS.md; PROTOCOL.md; terrain_net.gd:40.", "Update in the same change.", "U-24, U-09"),
     ("GA-86", "LOW", "UNVERIFIED_ASSUMPTION", "Ctrl+Shift+= and Ctrl+Shift+] cannot be typed on some layouts; editor/driver capture of F5/F8 chords untested",
      "ADMIN_KEYBINDINGS_POLICY.md map; German QWERTZ.", "Choose layout-safe primary keys; test on Dave's PC.", "U-22"),
     ("GA-87", "HIGH", "CONFIRMED_DEFECT", "The design documents the Journal is told to copy are not what the live Inventory/Crafting uses",
      "Live inventory is drawn by art_kit.gd (redesign v4, leather/brass palette) which differs from src/client/ui/dynasty_theme.gd and INVENTORY_CRAFTING_LOOK.md; most painted art is still code placeholders.", "Build the Journal with ArtKit, not the cited docs.", "U-06, U-07, U-08"),
     ("GA-88", "HIGH", "CONFIRMED_DEFECT", "The client receives only notice text; goals_state() is never sent; a protocol change is needed",
      "server_items.gd:15825 (goals_state, unused); terrain_net.gd:40 protocol 118.", "Three messages: join snapshot, progress deltas, a separate goal-achieved event that alone triggers placards (protocol bump: Dave's approval).", "U-09, U-10"),
     ("GA-89", "HIGH", "CONFIRMED_DEFECT", "Reconnect must not replay placards and a migration would flood them",
      "Placards must be driven by a one-shot achieved event, not by state diff; migration may complete dozens at once (GA-56).", "Queue with a cap and a summary line.", "U-11, U-16, R-15"),
     ("GA-90", "MED", "CONFIRMED_DEFECT", "The upper-right corner already holds the Comfort/Rested label", "HUD code (ws_ui.md U-12).", "Move or stack it; keep the Goals box as specified.", "U-12"),
     ("GA-91", "MED", "OWNER_DECISION", "Which two goals the HUD shows: the draft has no display-order field; with this draft, document order and main-first are identical; legacy additional goals (fish, spear, hoe, ...) never show until all 118 main goals are done",
      "goals_parsed.json (118 MAIN rows precede all 533 additional); legacy after gating conflicts (GA-40).", "Keep the literal rule with an explicit display_order field (main route first); anything else is Dave's call (Q7).", "U-13"),
     ("GA-92", "MED", "OWNER_DECISION", "No in-game World Map exists for the M / Map page", "No world-map UI in src/client (ws_ui.md U-05).", "Show Map greyed as 'coming later', or omit it until a map exists (Q8).", "U-05"),
     ("GA-93", "MED", "CONFIRMED_DEFECT", "Placard: text areas, long names (up to 40 characters), denomination format and the missing coin icon",
      "Blank art 1448x1086 RGBA: centre panel approx. x 280-1160, y 410-560; reward box approx. x 360-1100, y 715-860 (measured on the staged image, +-20 px); the Example shows a coin stack the Blank lacks; draft text '2 silver + 4 bronze' vs game format '2 silver, 4 bronze' (_coin_words); some legacy rewards are items/rep.", "Two-line shrink-to-fit title; format from the copper value; coin icon from existing coin_*.png (Q9).", "U-14, U-15"),
     ("GA-94", "LOW", "OWNER_DECISION", "Placard art is slightly translucent (body alpha 240-254), conflicting with the 23 Oct 'solid panels' rule; 2.6 MB at full size",
      "Alpha histogram of GoalAchieved_Blank.png (lead measurement); ws_ui.md U-17, U-18.", "Import only the Blank, cropped and downscaled; Dave to accept the translucency or ask for a solid version (Q9).", "U-17, U-18"),
     ("GA-95", "MED", "CONFIRMED_DEFECT", "No fanfare or trumpet audio exists in the repo",
      "docs/SOUND_MAP.md:44 ('Goal done: none?'); no matching asset found.", "Commission/obtain an original or properly licensed clip with a credits entry; ship silent until then.", "U-19"),
     ]
for fid, sev, cls, title, ev, corr, src in U:
    add(fid, sev, cls, title, ev, [], "NONE", corr, "", src)

# ---------------- ADD recommendations (separate ledger records)
adds = []
for i, a in enumerate(cat["add_candidates"], 1):
    adds.append(dict(goal_id="ADD-%02d %s" % (i, a["proposed_id"]), title=a["title"], route="ADDITIONAL" if a["proposed_id"] not in ("craft:kindling",) else "MAIN",
                     draft_section="(not in draft) " + a["suggested_group"], content_status="IMPLEMENTED" if a["kind"] == "craft" else "IMPLEMENTED (mechanic)",
                     required_action_and_completion=a["why"], source_refs=a["target"], design_status="", runtime_support="EXISTING" if a["kind"] == "craft" else "NEW_EVENT_REQUIRED",
                     evidence_level="CODE_VERIFIED", finding_ids="GA-63", recommended_correction="ADD (creator approval required; catalog freeze)"))
add("GA-63", "MED", "DESIGN_RECOMMENDATION", "Eligible content and interactions with no goal (26 ADD recommendations)",
    "ws_catalog.md section 4: kindling and tinder (live hand crafts), cooking on a campfire, farming (till/sow/harvest), replanting bushes, snares, sharpening and repair, sleeping, storage and locks, handcart hauling, tempering and masterwork, kiln charcoal, buying, preserving-jar maturing, serving, food effects, torches, discovery goals for foraging, fishing variety, mining.",
    [], "NONE", "Add only after creator approval; activities need new server events.", "", "C add candidates")

out = dict(F)
out["_adds"] = adds
# legacy goals whose completion test_goals.gd asserts (David4 run at dc2fa52, 20/20 pass: work/david4_evidence_dc2fa52.md)
# reviewer round 1: the small-block recipe runs through _craft_tick, so it is credited today
out["_runtime_overrides"] = {"craft:wooden_block": "EXISTING", "craft:wooden_block_soft": "EXISTING"}
out["_evidence_overrides"] = {k: "AUTOMATED_TESTED" for k in ("drink", "fibre", "twine", "axe", "fell", "fire", "shelter", "workbench", "story", "night_walk", "fish")}
out["_computed"] = dict(nosrc_items=NOSRC, blocked_nosrc=blocked_nosrc, blocked_water_extra=blocked_water_extra, locked_bp=locked_bp,
                        blocked_by={k: len(v) for k, v in blocked_by.items()}, still_blocked_when_fixed=still_blocked_when_fixed, untaught_goals=len(untaught),
                        main_blocked=[x for x in blocked_nosrc + blocked_water_extra + locked_bp if x in MAIN])
json.dump(out, open(os.path.join(W, "lead_findings.json"), "w"), indent=1)
print("findings", len([k for k in out if k.startswith("GA-")]), "adds", len(adds))
print(json.dumps(out["_computed"]["blocked_by"]), "nosrc", len(blocked_nosrc), "water extra", len(blocked_water_extra), "locked", len(locked_bp))
cov = set(F["GA-01"]["goals"]) | set(F["GA-02"]["goals"]) | set(F["GA-03"]["goals"]) | set(F["GA-04"]["goals"])
print("uncovered blocked", sorted(set(blocked_nosrc + blocked_water_extra) - cov), "extra covered", len(cov - set(blocked_nosrc + blocked_water_extra)))
print("main blocked", out["_computed"]["main_blocked"])
print("untaught goals", len(untaught), "early_problem", len(early_problem), "late_problem", len(late_problem))
