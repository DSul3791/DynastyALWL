#!/usr/bin/env python3
"""GOALS-AUDIT economy workstream: reward economics of the 651 draft goals (PLAYER_GOALS_REWARDS_DRAFT.md).

Read-only. Reads work/goals_parsed.json, work/pass2_deps.json and data/ (items, gathered, recipes, blueprints, structures,
coins, shops, starter/camp goals, pace data). Writes work/ws_economy.json only. All money is integer copper unless a field
says "_f" (float, for unit values such as charcoal 0.15).

Usage: python3 tools/economy.py <repo_root> <work_dir>
   eg  python3 docs/ai-team/missions/GOALS-AUDIT/tools/economy.py . docs/ai-team/missions/GOALS-AUDIT/work

MODEL (every constant below is either cited to a file/key or marked ASSUMED):
  unit value  = items.json/gathered.json `value`; else cheapest member of an ingredient group (wood_species.json
                ingredient_groups); else derived from the cheapest live producing recipe (inputs / units given);
                else 2 copper, the convention of src/worldgen/tools/test_economy_guard.gd:4 ("2 when a row has none").
  raw cost    = the same recursion, but always expanded through the cheapest live recipe down to items that have none.
  effort      = minutes of hands-on work for the MARGINAL materials a goal consumes (recursive gather minutes + craft_s),
                excluding prerequisites that are separate goals (stations, kept tools), walking to a site, learning, waiting
                for fires/timers and rest. It is a LOWER BOUND on play time.
  wage        = W_PICK 0.2 copper per real minute: Dave's rule (2 Nov 2026) as recorded in docs/ECONOMY_FIRST_DAY.md lines
                3-6 ("4 hours of full-time picking pays about 40 to 60 copper") and its table (0.20 copper/min per item).
"""
import json, math, os, sys, collections

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
W = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "docs/ai-team/missions/GOALS-AUDIT/work")
D = lambda p: json.load(open(os.path.join(ROOT, "data", p)))

goals = json.load(open(os.path.join(W, "goals_parsed.json")))
deps = json.load(open(os.path.join(W, "pass2_deps.json")))
I = dict(D("items/items.json")["items"])
G = D("items/gathered.json")["items"]
ALL = dict(G); ALL.update(I)                                   # items.json wins where both have a row
R = D("items/recipes.json")["recipes"]
B = D("items/blueprints.json")["blueprints"]
S = D("items/structures.json")["structures"]
GROUPS = {k: v for k, v in D("items/wood_species.json")["ingredient_groups"].items() if isinstance(v, list)}
COINS = D("items/coins.json")
TRADE = COINS["trade"]
HOB = D("npcs/shops.json")["hob"]
FISH = D("items/fishing.json")
FELL = D("items/drops.json")["felling"]
TRUNK = D("items/drops.json")["trunk"]
LIVE = {g["id"]: g for f in ("starter_goals.json", "camp_goals.json") for g in D("items/" + f)["goals"]}

# ---------------------------------------------------------------- wage model ------------------------------------------
W_PICK = 0.2                     # copper per real minute, ECONOMY_FIRST_DAY.md (CREATOR rule, Sal's record of Dave 2 Nov 2026)
BUY = TRADE["buy_discount"]      # 0.55, coins.json trade.buy_discount (Hob pays value x 0.55, floor, min 1: server_trade.gd:230-234)
SELL = TRADE["sell_markup"]      # 1.3,  coins.json trade.sell_markup (Hob charges value x 1.3, ceil: server_trade.gd:226-227)
PURSE_CAP = HOB["purse_cap"]     # 300,  shops.json hob.purse_cap
PURSE_REGEN = HOB["purse_regen_per_day"]   # 100 per game day; a game day is one real hour (coins.json trade.stock.note)
W_HOB_CEIL = PURSE_REGEN / 60.0  # copper per real minute: the most all sales to Hob can pay, sustained
ORDERS = HOB["wanted_orders"]["orders"]

# ---------------------------------------------------------------- gather pace (minutes per unit) -----------------------
SAL_RATES = {"stone": 6, "stick": 12, "leaves": 12, "plant_fibre": 10, "bark": 6, "nettles": 8, "feather": 1, "soil": 4,
             "clay": 4, "sand": 4, "gravel": 4}           # picks/min, ASSUMED by Sal: tools/economy_first_day.py RATES
fish_cast_s = (sum(FISH["wait_s"]) / 2.0) + FISH["window_s"] / 2.0 + FISH["cooldown_s"]
FISH_MIN = fish_cast_s / FISH["base_chance"] / 60.0        # fishing.json wait_s, window_s, cooldown_s, base_chance
TREE_BLOWS = round(FELL["tree_base"] + 0.25 * FELL["tree_per_trunk_m"])     # ASSUMED trunk radius 0.25 m
LOGS_PER_TREE = 5                                                            # ASSUMED (trunk.max_logs is 20)
LOG_WORK_MIN = (TREE_BLOWS / LOGS_PER_TREE + TRUNK["blows_per_log"]) * FELL["swing_s_now"] / 60.0
LOG_MIN = 0.5                    # ASSUMED: LOG_WORK_MIN (about 0.05) plus walking between trees and hauling (log stack 5)
ORE_MIN = 0.5                    # ASSUMED: one piece per stone-pick blow (boulders.json tools.pick.stone 1) at about 1 s,
                                 # ore only with piece_share and only at outcrops, plus prospecting
ANIMAL_MIN = 3.0                 # ASSUMED: hunting plus carcass.json blows, per unit of hide/meat/sinew/fur/fat/bone etc.
CROP_MIN = 0.5                   # ASSUMED: farmed or hand-processed crops (grain, flax, vegetables)
DEFAULT_MIN = 0.25               # ASSUMED: any other gathered item, Sal's 4 picks/min for soil/clay/sand
WATER_MIN = 0.1                  # ASSUMED: fill at the water's edge
THATCH_MIN = 0.1                 # ASSUMED: drops.json harvest_yield.thatch_grass.count 10 per plant
ANIMAL = {"hide", "raw_meat", "bone", "sinew", "fur", "animal_fat", "gut", "antler", "tusk", "horn", "down", "quill",
          "claw", "seal_meat", "egg", "wool", "crab_meat", "feather"}
ORES = {"iron_ore", "copper_ore", "tin_ore", "coal", "limestone", "flint", "obsidian", "crystal_lens", "salt"}
CROPS = {"wheat", "barley", "oats", "rye", "flax", "linseed", "potato", "turnip", "cabbage", "beet", "onion", "peas",
         "carrot", "parsnip", "radish", "straw"}
LOGS = {"log", "wooden_block_large", "wooden_block_soft_large"} | {k for k in ALL if k.startswith("log_") and k in GROUPS.get("log", []) + ["log_spruce", "log_oak"]}


def gather_min(i):
    if i in SAL_RATES: return 1.0 / SAL_RATES[i], "Sal RATES (assumed)"
    if i in GROUPS.get("fish", []) or i == "fish": return FISH_MIN, "fishing.json"
    if i in LOGS: return LOG_MIN, "assumed log"
    if i in ORES: return ORE_MIN, "assumed ore"
    if i in ANIMAL: return ANIMAL_MIN, "assumed animal"
    if i in CROPS: return CROP_MIN, "assumed crop"
    if i in ("water", "sea_water"): return WATER_MIN, "assumed water"
    if i in ("thatch", "bedding"): return THATCH_MIN, "assumed thatch"
    return DEFAULT_MIN, "assumed default"


# ---------------------------------------------------------------- recipes and values -----------------------------------
LIVE_R = {k: r for k, r in R.items() if not r.get("retired")}
PRODUCERS = collections.defaultdict(list)
for k, r in LIVE_R.items():
    PRODUCERS[r["gives"][0]].append(k)
RAW = set(json.load(open(os.path.join(W, "raw_inputs.json"))))    # pass-1: inputs no live recipe makes


def _members(i):
    return [m for m in GROUPS[i] if m != i] + ([i] if i in ALL else []) if i in GROUPS else [i]


_val, _raw, _eff = {}, {}, {}


def unit_value(i, stack=()):
    """market value of one unit, copper (float) and its source"""
    if i in _val: return _val[i]
    if i in ALL and "value" in ALL[i]:
        res = (float(ALL[i]["value"]), "items.json value")
    elif i in GROUPS:
        opts = [unit_value(m, stack + (i,))[0] for m in _members(i) if m not in stack and m != i]
        res = (min(opts), "group min") if opts else (2.0, "guard default 2")
    elif PRODUCERS.get(i) and i not in stack:
        opts = []
        for rk in PRODUCERS[i]:
            r = LIVE_R[rk]
            if any(n in stack + (i,) for n, _ in r["needs"]): continue
            opts.append(sum(c * unit_value(n, stack + (i,))[0] for n, c in r["needs"]) / r["gives"][1])
        res = (min(opts), "derived from recipe") if opts else (2.0, "guard default 2")
    else:
        res = (2.0, "guard default 2")
    if not stack: _val[i] = res
    return res


def best_recipe(i, stack=()):
    """the live recipe making i with the least effort (None for raw items)"""
    if i in RAW or i in SAL_RATES or not PRODUCERS.get(i): return None
    best = None
    for rk in PRODUCERS[i]:
        r = LIVE_R[rk]
        if any(n in stack + (i,) for n, _ in r["needs"]): continue
        e = (r.get("craft_s", 0) / 60.0 + sum(c * unit_effort(n, stack + (i,)) for n, c in r["needs"])) / r["gives"][1]
        if best is None or e < best[1]: best = (rk, e)
    return best


def unit_effort(i, stack=()):
    if not stack and i in _eff: return _eff[i]
    if i in GROUPS:
        ms = [m for m in _members(i) if m not in stack and m != i]
        opts = [unit_effort(m, stack + (i,)) for m in ms] + ([gather_min(i)[0]] if i in ALL and not PRODUCERS.get(i) else [])
        e = min(opts) if opts else DEFAULT_MIN
    else:
        br = best_recipe(i, stack)
        e = br[1] if br else gather_min(i)[0]
    if not stack: _eff[i] = e
    return e


def unit_raw(i, stack=()):
    """raw cost: value of the raw materials behind one unit, through the least-effort live recipe"""
    if not stack and i in _raw: return _raw[i]
    if i in GROUPS:
        ms = [m for m in _members(i) if m not in stack and m != i]
        opts = [unit_raw(m, stack + (i,)) for m in ms] + ([float(ALL[i]["value"])] if i in ALL and "value" in ALL[i] else [])
        v = min(opts) if opts else unit_value(i)[0]   # a group id that is itself an item (log, firewood) counts as a member
    else:
        br = best_recipe(i, stack)
        v = sum(c * unit_raw(n, stack + (i,)) for n, c in LIVE_R[br[0]]["needs"]) / LIVE_R[br[0]]["gives"][1] if br else unit_value(i)[0]
    if not stack: _raw[i] = v
    return v


def uses_closure(i, seen=None):
    """every item behind i through least-effort recipes (for the material tier)"""
    seen = set() if seen is None else seen
    if i in seen: return seen
    seen.add(i)
    if i in GROUPS:
        ms = [m for m in _members(i) if m != i]
        if ms and not (i in ALL and not PRODUCERS.get(i)): uses_closure(min(ms, key=lambda m: unit_effort(m)), seen)
        return seen
    br = best_recipe(i)
    if br:
        for n, _ in LIVE_R[br[0]]["needs"]: uses_closure(n, seen)
    return seen


def hob_pay(i, n):
    """what Hob pays for n units sold at once, full demand, stranger, no luck (server_trade.gd:366-403)"""
    v = ALL.get(i, {}).get("value", 0)
    rule = HOB.get("buy_rules", {}).get(i)
    if rule:
        return (min(n, rule["per_day"]) // rule["lot"]) * rule["lot_value"]
    if not v or int(v) <= 0: return 0
    lot = max(int(ALL[i].get("sell_lot", 1)), 1)
    per = max(int(math.floor(int(v) * BUY + 0.0001)), 1)
    total, k = 0, 0
    for k in range(n - n % lot):
        d = max(1.0 - TRADE["demand"]["drop_per_sale"] * k, TRADE["demand"]["floor"])
        if (k + 1) % lot == 0: total += max(int(math.floor(int(v) * BUY * d + 0.0001)), 1)
    return total


def batch(needs, mult=1.0):
    return [(n, c * mult) for n, c in needs]


# ---------------------------------------------------------------- per-goal inputs ---------------------------------------
def recipe_for(item):
    ks = PRODUCERS.get(item, [])
    return ks[0] if ks else None


LEGACY_INPUTS = {   # what each legacy goal's check consumes or demands (starter_goals.json / camp_goals.json `check`)
    "drink": ([], 0.5), "fibre": ([("plant_fibre", 12)], 0.0), "fell": ([], 1.0), "fire": ([("stick", 3)], 0.5),
    "berries": ([], 0.5), "path": ([], 1.5), "sell": ([], 1.0), "story": ([], 3.0), "night_walk": ([], 1.5),
    "knife": ([("stone", 2), ("stick", 1)], 3.0 + 0.1), "fish": ([("trout", 1)], 0.0),
}
LEGACY_RECIPE = {"twine": ("twine", 2), "axe": ("stone_axe", 1), "hammer": ("wooden_hammer", 1), "hoe": ("wooden_hoe", 1),
                 "spear": ("spear", 1), "torch_night": ("torch", 1), "candle": ("tallow_candle", 1), "smoke_fish": ("cook_smoked_fish", 1),
                 "dry_berries": ("cook_dried_berries", 3), "jerky": ("cook_jerky", 2), "salted_fish": ("cook_salted_fish", 1),
                 "bed": ("rough_bed_kit", 1)}
LEGACY_BUILD = {"shelter": "lean_to", "workbench": "workbench"}
HIDE_SET = ["hide_cloak", "hide_boots", "hide_gloves", "hide_hood", "hide_trousers", "hide_tunic"]
ACTIVITY = {"activity:chop_log_blocks": ([("log", 1)], 0.5), "activity:place_campfire": ([], 0.2),
            "activity:place_chopping_block": ([], 0.2), "activity:medium_fire": ([("firewood", 3)], 0.5),
            "activity:bonfire": ([("log", 3)], 0.5)}
order_units = [sum(c for _, c in o["needs"]) for o in ORDERS]
order_eff = [sum(c * unit_effort(n) for n, c in o["needs"]) for o in ORDERS]


def goal_inputs(g):
    """(consumed [(item, n)], extra minutes, outputs [(item, n)], recipe or blueprint id)"""
    gid, k, key = g["goal_id"], g["kind"], g["key"]
    if k == "craft" and g.get("recipe_used") in R:
        r = R[g["recipe_used"]]
        return batch(r["needs"]), r.get("craft_s", 0) / 60.0, [tuple(r["gives"])], g["recipe_used"]
    if k == "build" and key in B:
        return batch(B[key]["cost"]), 0.5, [], key           # 0.5 min placement, ASSUMED
    if k == "gather":
        extra = 5.0 if key in ORES or key in ("pine_tar", "tannin_bark") else 1.0   # ASSUMED search time
        return [], gather_min(key)[0] + extra, [(key, 1)], None
    if k == "activity":
        ins, m = ACTIVITY.get(gid, ([], 0.5))
        return ins, m, [], None
    if k == "existing":
        if gid in LEGACY_RECIPE:
            rk, cnt = LEGACY_RECIPE[gid]
            r = R[rk]
            b = math.ceil(cnt / r["gives"][1])
            return batch(r["needs"], b), b * r.get("craft_s", 0) / 60.0, [(r["gives"][0], b * r["gives"][1])], rk
        if gid in LEGACY_BUILD:
            return batch(B[LEGACY_BUILD[gid]]["cost"]), 0.5, [], LEGACY_BUILD[gid]
        if gid == "order":
            # average wanted order (shops.json hob.wanted_orders.orders): pay and units, as an ordinary-play wage
            avg = [(n, c / len(ORDERS)) for o in ORDERS for n, c in o["needs"]]
            return avg, 1.0, [], None
        if gid == "winter_store":
            r = R["cook_dried_berries"]
            return batch(r["needs"], 5), 5 * r["craft_s"] / 60.0, [("dried_berries", 5)], "cook_dried_berries"
        if gid == "fur_for_winter":
            ins, m, outs = [], 0.0, []
            for it in HIDE_SET:
                rk = recipe_for(it)
                if rk:
                    ins += batch(LIVE_R[rk]["needs"]); m += LIVE_R[rk].get("craft_s", 0) / 60.0; outs.append((it, 1))
            return ins, m, outs, "hide set"
        if gid in LEGACY_INPUTS:
            ins, m = LEGACY_INPUTS[gid]
            return list(ins), m, [], None
    return [], 0.5, [], None


# ---------------------------------------------------------------- classification ----------------------------------------
BUILD_TIERS = ["Crude", "Rustic", "Sturdy", "Superior", "Refined", "Engineered", "Fortified"]
PIECE_CATS = {"Walls and doors", "Roofs and ceilings", "Foundations", "Stairs, ladders and supports", "Fences and gates"}
METALS = ("bronze", "iron", "steel")


def mat_tier(items):
    """1 primitive, 2 fired clay/stonework/sawn wood, 3 copper-tin-bronze, 4 iron, 5 steel"""
    u = set()
    for i, _ in items: u |= uses_closure(i)
    if "steel_ingot" in u: return 5
    if "iron_ingot" in u or "iron_ore" in u: return 4
    if u & {"bronze_ingot", "copper_ingot", "tin_ingot"}: return 3
    if u & {"brick", "mortar", "cobblestone", "lumber", "hardwood_board", "concrete", "lime_powder", "leather", "wooden_pin"}: return 2
    return 1


def door_shape(key):
    for s in ("double_arched_door", "double_door", "arched_door"):
        if key.endswith(s): return s
    return "door"


def classify(g, ins):
    k, key = g["kind"], g["key"]
    if k == "existing": return "legacy", "legacy", None
    if k == "gather": return "gather", "gather", None
    if k == "activity": return "activity", "activity", None
    if k == "build":
        b = B.get(key, {}); cat = b.get("category", ""); nm = b.get("name", key)
        pre = nm.split(" - ")[0] if " - " in nm else ""
        st = S.get(b.get("structure", key), {})
        if st.get("addon_of"): return "station_addon", "addon:" + st["addon_of"], None
        if st.get("station") or st.get("also"): return "station", "station", None
        if "door" in key and "doorway" not in key: return "door", "door:" + pre, door_shape(key)
        if cat in PIECE_CATS and pre in BUILD_TIERS: return "piece", "piece:" + pre, nm.split(" - ", 1)[1]
        return "placeable", "placeable:" + cat, None
    r = R.get(g.get("recipe_used") or "", {})
    cat = r.get("category", "")
    out = (r.get("gives") or [key])[0]
    if cat == "Food and drink": return "food", "food:" + (r.get("station") or "hand"), None
    if cat in ("Tools", "Weapons", "Armour"):
        metal = next((m for m in METALS if out.startswith(m + "_")), None)
        if metal is None and r.get("station") in ("brick_forge", "forge"): metal = "iron" if any(n.startswith("iron") for n, _ in r["needs"]) else ("steel" if any(n.startswith("steel") for n, _ in r["needs"]) else "bronze")
        return "equipment", "equipment:" + (metal or "primitive"), None
    if cat == "Clothing": return "clothing", "clothing:" + out.split("_")[0], None
    if cat == "Workshops and stations": return "station_part", "station_part", None
    if cat == "Medicine": return "medicine", "medicine", None
    if cat.startswith("Containers"): return "container", "container", None
    if cat == "Materials": return "material", "material", None
    return "other", "other:" + cat, None


# ---------------------------------------------------------------- recommended reward policy ------------------------------
STATION_BAND = {1: 10, 2: 20, 3: 40, 4: 80}                    # by station tier (see station_tier)
# ERA OPENERS (recommendation): a station that opens a new production era is paid at least that era's tier, whatever it is built of.
FLAGSHIP = {"smelter": 2,          # first metal (ingots); built of clay and stone only
            "stone_forge": 2,      # bronze smithing
            "stone_workbench": 3,  # workbench level 3 (water wheel and other L3 recipes)
            "mixer": 3,            # concrete: Engineered and Fortified building tiers
            "saw_mill": 4, "large_forge": 4, "master_forge": 4}   # mass planks, steel, master smithing
PIECE_LEAD = {"Crude": 7, "Rustic": 7, "Sturdy": 10, "Superior": 12, "Refined": 15, "Engineered": 25, "Fortified": 40}
VARIANT = 2                                                    # any further variant of a family already paid
MAIN_FLOOR = 5                                                 # a guided main-route building goal never pays less
EFFORT_SHARE = 0.5                                             # top-up: half the picking wage for the modeled marginal minutes
FIRST_FUNCTION = 4                                             # first time a building function (roof, window, stairs...) appears
DOOR_SHAPE_FIRST = 3
EQUIP_LEAD = {"primitive": 3, "bronze": 10, "iron": 12, "steel": 15}
EQUIP_VAR = {"primitive": 2, "bronze": 3, "iron": 3, "steel": 4}
EQUIP_TOOL_VAR = 5                                             # off-route metal working tool (axe, spade, sickle...)
MATERIAL_BAND = {1: 3, 2: 4, 3: 5, 4: 7, 5: 10}
MILESTONE_MATERIAL = {"iron_ingot": 15, "steel_ingot": 25, "bronze_ingot": 10, "copper_ingot": 5, "tin_ingot": 5,
                      "lumber": 8, "hardwood_board": 8, "concrete": 15, "leather": 8, "charcoal": 5, "brick": 4}
LEAD_BAND = {1: 3, 2: 5, 3: 8, 4: 10, 5: 12}                   # first of a non-structural family (food station, clothing, furniture)


def station_tier(g, ins):
    st = B.get(g["key"], {}).get("structure", g["key"])
    t = {1: 1, 2: 2, 3: 3, 4: 3, 5: 4}[mat_tier(ins)]
    return max(t, FLAGSHIP.get(st, 0))


def recommend(g, cls, fam, sub, ins, ctx):
    gid, key, draft = g["goal_id"], g["key"], g["coin_copper"]
    t = mat_tier(ins)
    main = g["route"] == "MAIN"
    lead = fam not in ctx["seen"]
    ctx["seen"].add(fam)
    if cls == "legacy":
        live = LIVE[gid]["reward"]
        if "coin_copper" in live: return live["coin_copper"], "Creator ruling relayed with the mission brief (coin rewards stay until Dave says otherwise): legacy coin reward stays (live %d)." % live["coin_copper"]
        if "item" not in live:
            return draft, "Live reward is reputation only (ignored by the engine); recommend the draft's own %d copper (Q3). His decision." % draft
        it, n = live["item"]
        return draft, "Live reward is %d %s (items, not coins, value %.0f); recommend the draft's own coin value %d (Q3). His decision." % (n, it, unit_value(it)[0] * n, draft)
    if cls == "gather":
        v = 5 if key in ORES or key in ("pine_tar", "tannin_bark", "hide", "animal_fat", "wool", "flax") else 3
        return v, "First find of a raw material: %d copper = %d min of picking wage (0.2/min)." % (v, v * 5)
    if cls == "activity":
        v = min(draft, 5)
        return v, "Teaching action; capped at 5 (bonfire 10 is twice the medium fire for 3 logs of extra work)." if draft > 5 else "Teaching action; draft value is in band."
    if cls == "station":
        s = station_tier(g, ins)
        return STATION_BAND[s], "Station tier %d (%s): band %d, monotone with tier." % (s, "era opener" if B.get(key, {}).get("structure", key) in FLAGSHIP else "material tier %d" % t, STATION_BAND[s])
    if cls == "station_addon":
        v = STATION_BAND[station_tier(g, ins)] // 2
        return v, "Add-on of an existing station: half its tier band."
    if cls == "station_part":
        v = {"water_wheel": 15, "chopping_block": 5}.get(key, MATERIAL_BAND[t])
        return v, "Station component; paid below the station it enables."
    if cls == "piece":
        tier = fam.split(":")[1]
        func = sub
        first_func = ("func:" + func) not in ctx["seen"]
        ctx["seen"].add("func:" + func)
        if lead: return PIECE_LEAD[tier], "First %s building piece: tier band %d." % (tier, PIECE_LEAD[tier])
        if main: return MAIN_FLOOR, "Guided-route %s piece after the tier's first: main-route floor %d." % (tier, MAIN_FLOOR)
        if first_func: return FIRST_FUNCTION, "First building piece of function '%s' in any tier: %d." % (func, FIRST_FUNCTION)
        return VARIANT, "Another %s piece of an already-taught function: variant %d." % (tier, VARIANT)
    if cls == "door":
        tier = fam.split(":")[1]
        first_shape = ("shape:" + sub) not in ctx["seen"]
        ctx["seen"].add("shape:" + sub)
        if sub == "door": return max(MAIN_FLOOR if main else 3, PIECE_LEAD[tier] // 2), "Plain %s door: half the tier band (main-route floor %d)." % (tier, MAIN_FLOOR)
        if first_shape: return DOOR_SHAPE_FIRST, "First %s anywhere: %d." % (sub.replace("_", " "), DOOR_SHAPE_FIRST)
        return 1, "Shape variant of a door already taught: 1 (one of 28 door configurations)."
    if cls == "material":
        out = (R[g["recipe_used"]]["gives"][0]) if g.get("recipe_used") in R else key
        if out in MILESTONE_MATERIAL: return MILESTONE_MATERIAL[out], "Tier-entry material (%s): milestone value." % out
        return MATERIAL_BAND[t], "Intermediate material, material tier %d band." % t
    if cls == "equipment":
        metal = fam.split(":")[1]
        if main or lead: return EQUIP_LEAD[metal], "%s equipment on the guided route or first of its tier: %d." % (metal.title(), EQUIP_LEAD[metal])
        r = R.get(g.get("recipe_used") or "", {})
        outi = ALL.get((r.get("gives") or [key])[0], {})
        if metal != "primitive" and r.get("category") == "Tools" and outi.get("tool_class") and not key.endswith(("_arrow", "_bolt")):
            return EQUIP_TOOL_VAR, "Off-route %s working tool (%s: changes work pace): %d." % (metal, outi.get("tool_class"), EQUIP_TOOL_VAR)
        return EQUIP_VAR[metal], "Another %s weapon/armour/ammunition variant: %d." % (metal, EQUIP_VAR[metal])
    if cls in ("food", "clothing", "container", "medicine", "placeable", "other"):
        if lead or main: return LEAD_BAND[t] if cls != "food" else 5, "First of family %s: lead band." % fam
        return VARIANT, "Further member of family %s: variant %d." % (fam, VARIANT)
    return min(draft, 5), "Unclassified: capped at 5."


# ---------------------------------------------------------------- run -----------------------------------------------------
out_goals, rows = {}, []
ctx = {"seen": set()}
# main route first so its goals are the family leads, then document order
order = [g for g in goals if g["route"] == "MAIN"] + [g for g in goals if g["route"] != "MAIN"]
for g in order:
    ins, extra, outs, src = goal_inputs(g)
    cls, fam, sub = classify(g, ins)
    rec, why = recommend(g, cls, fam, sub, ins, ctx)
    in_val = sum(c * unit_value(i)[0] for i, c in ins)
    in_raw = sum(c * unit_raw(i) for i, c in ins)
    eff = extra + sum(c * unit_effort(i) for i, c in ins)
    top = int(eff * W_PICK * EFFORT_SHARE) if cls != "legacy" else 0
    if top:
        rec += top
        why += " +%d effort top-up (%.0f min x 0.2 x %.1f)." % (top, eff, EFFORT_SHARE)
    if g["kind"] == "build":
        st = S.get(B.get(g["key"], {}).get("structure", g["key"]), {})
        kv = ALL.get(st.get("kit") or "", {}).get("value") or ALL.get(st.get("item") or "", {}).get("value")
        out_val = float(kv) if kv is not None else None
        out_hob = None
    else:
        out_val = sum(n * ALL[i]["value"] for i, n in outs if i in ALL and "value" in ALL[i]) if outs else None
        out_hob = sum(hob_pay(i, int(n)) for i, n in outs) if outs else None
    draft = g["coin_copper"]
    rec_row = {
        "reward": draft, "route": g["route"], "line": g["line"], "section": g["section"], "dep_level": g["dep_level"],
        "class": cls, "family": fam,
        "inputs": [[i, round(c, 2)] for i, c in ins], "input_value": round(in_val, 1), "input_raw_cost": round(in_raw, 1),
        "output_value": None if out_val is None else round(out_val, 1), "output_hob_pay": out_hob,
        "reward_over_input": None if in_val <= 0 else round(draft / in_val, 2),
        "effort_min": round(eff, 2), "picking_wage_for_effort": round(eff * W_PICK, 1),
        "reward_in_picking_minutes": round(draft / W_PICK, 0),
        "effort_note": "%.1f min marginal hands-on work (materials %s, recipe %s); excludes prerequisite goals, walking, waiting, rest" % (eff, "+".join("%s x%g" % (i, round(c, 2)) for i, c in ins) or "none", src or "-"),
        "recommended_copper": int(rec), "rationale": why,
    }
    out_goals[g["goal_id"]] = rec_row
# keep the draft's document order in the output
out_goals = {g["goal_id"]: out_goals[g["goal_id"]] for g in goals}


def tot(pred, field):
    return int(sum(v[field] for k, v in out_goals.items() if pred(k, v)))


SECTIONS = list(dict.fromkeys(g["section"] for g in goals))
totals = {
    "goal_count": len(out_goals),
    "draft_total": tot(lambda k, v: True, "reward"), "recommended_total": tot(lambda k, v: True, "recommended_copper"),
    "draft_main": tot(lambda k, v: v["route"] == "MAIN", "reward"), "recommended_main": tot(lambda k, v: v["route"] == "MAIN", "recommended_copper"),
    "draft_additional": tot(lambda k, v: v["route"] != "MAIN", "reward"), "recommended_additional": tot(lambda k, v: v["route"] != "MAIN", "recommended_copper"),
    "by_section": {s: {"goals": sum(1 for v in out_goals.values() if v["section"] == s), "draft": tot(lambda k, v, s=s: v["section"] == s, "reward"),
                       "recommended": tot(lambda k, v, s=s: v["section"] == s, "recommended_copper")} for s in SECTIONS},
    "by_dep_level": {}, "by_class": {}, "by_family_variants": {},
    "draft_reward_values_by_dep_level": {},
}
for lv in sorted({v["dep_level"] for v in out_goals.values()}, key=lambda x: -1 if x is None else x):
    sel = [v for v in out_goals.values() if v["dep_level"] == lv]
    totals["by_dep_level"][str(lv if lv is not None else "main")] = {"goals": len(sel), "draft": sum(v["reward"] for v in sel), "recommended": sum(v["recommended_copper"] for v in sel)}
    totals["draft_reward_values_by_dep_level"][str(lv if lv is not None else "main")] = dict(sorted(collections.Counter(v["reward"] for v in sel).items()))
for cl in sorted({v["class"] for v in out_goals.values()}):
    sel = [v for v in out_goals.values() if v["class"] == cl]
    totals["by_class"][cl] = {"goals": len(sel), "draft": sum(v["reward"] for v in sel), "recommended": sum(v["recommended_copper"] for v in sel),
                              "effort_min": round(sum(v["effort_min"] for v in sel), 1)}

# trivial / near-duplicate groups named in the brief
GROUPS_TRIVIAL = {
    "doors_28_configurations": lambda k, v: v["class"] == "door",
    "door_shape_variants_(arched/double/double_arched)": lambda k, v: v["class"] == "door" and door_shape(k.split(":", 1)[1]) != "door",
    "building_pieces_all": lambda k, v: v["class"] == "piece",
    "building_piece_variants_(non-lead_per_tier)": lambda k, v: v["class"] == "piece" and v["recommended_copper"] <= FIRST_FUNCTION,
    "food_dishes": lambda k, v: v["class"] == "food",
    "metal_equipment_bronze_iron_steel": lambda k, v: v["family"] in ("equipment:bronze", "equipment:iron", "equipment:steel"),
    "metal_equipment_off_route_variants": lambda k, v: v["family"] in ("equipment:bronze", "equipment:iron", "equipment:steel") and v["route"] != "MAIN",
    "clothing": lambda k, v: v["class"] == "clothing",
    "furniture_storage_decor_water_garden": lambda k, v: v["class"] == "placeable",
    "engineered_and_fortified_pieces_at_120": lambda k, v: v["family"] in ("piece:Engineered", "piece:Fortified") and v["reward"] == 120,
}
for name, p in GROUPS_TRIVIAL.items():
    sel = [(k, v) for k, v in out_goals.items() if p(k, v)]
    totals["by_family_variants"][name] = {"goals": len(sel), "draft": sum(v["reward"] for _, v in sel), "recommended": sum(v["recommended_copper"] for _, v in sel),
                                          "draft_share_of_catalog": round(sum(v["reward"] for _, v in sel) / totals["draft_total"], 3)}

# ordinary-play comparison
eff_all = sum(v["effort_min"] for v in out_goals.values())
eff_main = sum(v["effort_min"] for v in out_goals.values() if v["route"] == "MAIN")
totals["wage_model"] = {
    "W_PICK_copper_per_min": W_PICK, "W_PICK_copper_per_hour": W_PICK * 60,
    "W_HOB_CEILING_copper_per_min": round(W_HOB_CEIL, 3), "hob_purse_cap": PURSE_CAP, "hob_purse_regen_per_real_hour": PURSE_REGEN,
    "wanted_order_pay_mean": round(sum(o["pay"] for o in ORDERS) / len(ORDERS), 2), "wanted_order_units_mean": round(sum(order_units) / len(ORDERS), 1),
    "wanted_order_effort_min_mean": round(sum(order_eff) / len(ORDERS), 1),
    "wanted_order_copper_per_min": round(sum(o["pay"] for o in ORDERS) / sum(order_eff), 3),
    "fish_min_per_catch": round(FISH_MIN, 2), "trout_hob_pay": hob_pay("trout", 1),
    "fish_copper_per_min_burst": round(hob_pay("trout", 1) / FISH_MIN, 2),
    "fish_sustained_per_cell_per_min": round(60.0 / FISH["regrow_s"], 2),
    "planks_hob_max_per_game_day": hob_pay("lumber", 10 ** 6),
    "hardwood_boards_hob_max_per_game_day": hob_pay("hardwood_board", 10 ** 6),
    "log_hob_pay_first": hob_pay("log", 1), "log_work_min_model": round(LOG_WORK_MIN, 3), "LOG_MIN_assumed": LOG_MIN,
    "coins_md_day_unskilled": 30, "coins_md_day_skilled": 60,
    "oak_log_hob_pay_1": hob_pay("log_oak", 1), "oak_logs_10_hob_pay_before_purse": hob_pay("log_oak", 10),
    "spruce_logs_10_hob_pay_before_purse": hob_pay("log_spruce", 10),
    "sticks_60_hob_pay": hob_pay("stick", 60), "stones_30_hob_pay": hob_pay("stone", 30),
}
for label, total in (("draft_total", totals["draft_total"]), ("draft_main", totals["draft_main"]), ("recommended_total", totals["recommended_total"]), ("recommended_main", totals["recommended_main"])):
    totals["wage_model"][label + "_hours_of_picking"] = round(total / W_PICK / 60, 1)
    totals["wage_model"][label + "_hours_at_hob_ceiling"] = round(total / W_HOB_CEIL / 60, 1)
totals["effort"] = {
    "catalog_effort_min": round(eff_all, 1), "main_effort_min": round(eff_main, 1),
    "picking_wage_over_catalog_effort": round(eff_all * W_PICK, 1), "hob_ceiling_over_catalog_effort": round(eff_all * W_HOB_CEIL, 1),
    "draft_multiple_of_picking_wage_catalog": round(totals["draft_total"] / (eff_all * W_PICK), 1),
    "draft_multiple_of_picking_wage_main": round(totals["draft_main"] / (eff_main * W_PICK), 1),
    "recommended_multiple_of_picking_wage_catalog": round(totals["recommended_total"] / (eff_all * W_PICK), 1),
    "recommended_multiple_of_picking_wage_main": round(totals["recommended_main"] / (eff_main * W_PICK), 1),
}

# what coins buy: Hob's stock at stranger prices (the only coin sink besides repairs and lessons)
hob_prices = {i: int(math.ceil(ALL[i]["value"] * SELL - 0.0001)) for i in HOB["stock"] if i in ALL and "value" in ALL[i]}
totals["hob_stock_prices"] = hob_prices
totals["hob_stock_one_of_each"] = sum(hob_prices.values())

# milestones along the main route
main = [g for g in goals if g["route"] == "MAIN"]
ms_ids = {"first_shelter": "shelter", "first_workbench": "workbench", "first_metal_ingot": None, "first_steel": "craft:steel_ingot",
          "first_fortified_piece": None, "end_of_main_route": main[-1]["goal_id"]}
ms_ids["first_metal_ingot"] = next(g["goal_id"] for g in main if g["key"] in ("iron_ingot", "copper_ingot", "tin_ingot"))
ms_ids["first_fortified_piece"] = next(g["goal_id"] for g in main if g["key"].startswith("fortified_"))
cum_d = cum_r = cum_e = cum_l = 0.0
milestones, first_hour = {}, None
for idx, g in enumerate(main, 1):
    v = out_goals[g["goal_id"]]
    cum_d += v["reward"]; cum_r += v["recommended_copper"]; cum_e += v["effort_min"]
    cum_l += LIVE[g["goal_id"]]["reward"].get("coin_copper", 0) if g["kind"] == "existing" else 0
    snap = {"goal": g["goal_id"], "main_index": idx, "draft_cum": int(cum_d), "recommended_cum": int(cum_r), "live_legacy_coin_cum": int(cum_l),
            "effort_cum_min": round(cum_e, 1), "picking_wage_cum": round(cum_e * W_PICK, 1),
            "draft_multiple_of_wage": round(cum_d / max(cum_e * W_PICK, 0.01), 1)}
    if first_hour is None and cum_e >= 60: first_hour = snap
    for name, mid in ms_ids.items():
        if mid == g["goal_id"]: milestones[name] = snap
milestones["first_hour_of_modeled_work"] = first_hour
for lab, fld in (("draft", "reward"), ("recommended", "recommended_copper")):
    c = 0
    for idx, g in enumerate(main, 1):
        c += out_goals[g["goal_id"]][fld]
        if c >= totals["hob_stock_one_of_each"]:
            milestones[lab + "_cum_buys_one_of_all_hob_stock_at"] = {"goal": g["goal_id"], "main_index": idx, "cum": c}
            break
milestones["first_10_main_goals"] = {"draft": sum(out_goals[g["goal_id"]]["reward"] for g in main[:10]), "recommended": sum(out_goals[g["goal_id"]]["recommended_copper"] for g in main[:10]),
                                     "effort_min": round(sum(out_goals[g["goal_id"]]["effort_min"] for g in main[:10]), 1)}

# anomalies (computed lists the .md cites)
an = {}
st_rows = [(k, v) for k, v in out_goals.items() if v["class"] in ("station", "station_addon")]
an["stations_draft_vs_recommended"] = {k: {"draft": v["reward"], "recommended": v["recommended_copper"], "effort_min": v["effort_min"], "input_value": v["input_value"]} for k, v in st_rows}
an["reward_below_input_value"] = sorted([(k, v["reward"], v["input_value"]) for k, v in out_goals.items() if v["input_value"] and v["reward"] < v["input_value"]], key=lambda x: x[1] - x[2])
an["reward_over_10x_input_value"] = sorted([(k, v["reward"], v["input_value"]) for k, v in out_goals.items() if v["input_value"] and v["reward"] > 10 * v["input_value"]], key=lambda x: -x[1] / max(x[2], 0.01))
an["reward_over_output_hob_pay"] = sorted([(k, v["reward"], v["output_hob_pay"]) for k, v in out_goals.items() if v["output_hob_pay"] is not None and v["reward"] > v["output_hob_pay"]], key=lambda x: -(x[1] - x[2]))
# monotonicity: pairs where a goal needs more effort and a higher material tier but pays less
pairs = []
for k1, v1 in out_goals.items():
    for k2, v2 in out_goals.items():
        if v1["class"] == v2["class"] and v1["class"] in ("station", "door", "piece", "equipment", "material") and v1["effort_min"] > 3 * v2["effort_min"] and v1["reward"] < v2["reward"]:
            pairs.append((k1, v1["reward"], v1["effort_min"], k2, v2["reward"], v2["effort_min"]))
an["not_monotone_in_effort_same_class_(3x_effort_pays_less)"] = {"count": len(pairs), "examples": sorted(pairs, key=lambda p: -(p[2] / max(p[5], 0.01)))[:40]}
an["recommended_not_monotone_count"] = sum(1 for v1 in out_goals.values() for v2 in out_goals.values() if v1["class"] == v2["class"] and v1["class"] in ("station", "door", "piece", "equipment", "material") and v1["effort_min"] > 3 * v2["effort_min"] and v1["recommended_copper"] < v2["recommended_copper"])
# rank correlation reward vs effort (Spearman)
def ranks(xs):
    s = sorted(range(len(xs)), key=lambda i: xs[i]); r = [0] * len(xs); i = 0
    while i < len(s):
        j = i
        while j + 1 < len(s) and xs[s[j + 1]] == xs[s[i]]: j += 1
        for t in range(i, j + 1): r[s[t]] = (i + j) / 2.0
        i = j + 1
    return r
def spearman(a, b):
    ra, rb = ranks(a), ranks(b); n = len(a); ma, mb = sum(ra) / n, sum(rb) / n
    cov = sum((x - ma) * (y - mb) for x, y in zip(ra, rb)); va = sum((x - ma) ** 2 for x in ra); vb = sum((y - mb) ** 2 for y in rb)
    return round(cov / math.sqrt(va * vb), 3)
vals = list(out_goals.values())
an["spearman_draft_reward_vs_effort"] = spearman([v["reward"] for v in vals], [v["effort_min"] for v in vals])
an["spearman_draft_reward_vs_dep_level"] = spearman([v["reward"] for v in vals if v["dep_level"] is not None], [v["dep_level"] for v in vals if v["dep_level"] is not None])
an["spearman_draft_reward_vs_effort_additional"] = spearman([v["reward"] for v in vals if v["dep_level"] is not None], [v["effort_min"] for v in vals if v["dep_level"] is not None])
an["spearman_recommended_vs_effort"] = spearman([v["recommended_copper"] for v in vals], [v["effort_min"] for v in vals])
# legacy: draft vs live data
leg = {}
for g in goals:
    if g["kind"] != "existing": continue
    live = LIVE[g["goal_id"]]["reward"]
    leg[g["goal_id"]] = {"draft_coin": g["coin_copper"], "live_reward": live, "same": live == {"coin_copper": g["coin_copper"]},
                         "live_check": LIVE[g["goal_id"]]["check"]}
an["legacy_draft_vs_live"] = {k: v for k, v in leg.items() if not v["same"]}
an["legacy_identical_count"] = sum(1 for v in leg.values() if v["same"])
an["legacy_live_total_coin"] = sum(v["live_reward"].get("coin_copper", 0) for v in leg.values())
an["legacy_draft_total_coin"] = sum(v["draft_coin"] for v in leg.values())
# unit values the model had to invent (no items.json value)
an["unit_value_sources"] = dict(collections.Counter(unit_value(i)[1] for v in out_goals.values() for i, _ in v["inputs"]))
an["valueless_inputs"] = sorted({i for v in out_goals.values() for i, _ in v["inputs"] if unit_value(i)[1] == "guard default 2"})
an["selected_unit_values"] = {i: {"value_f": unit_value(i)[0], "source": unit_value(i)[1], "raw_cost_f": round(unit_raw(i), 3), "effort_min_f": round(unit_effort(i), 3), "hob_pay_1": hob_pay(i, 1)}
                              for i in ("stick", "stone", "plant_fibre", "twine", "log", "log_spruce", "log_oak", "lumber", "hardwood_board", "wooden_pin", "nails", "iron_ore", "charcoal", "fuel", "iron_ingot", "steel_ingot", "brick", "mortar", "cobblestone", "concrete", "iron_band", "hinges", "water_wheel", "kindling", "thatch", "leather", "trout", "lime_powder", "clay_roof_tile")}
an["crude_door_cost"] = B["crude_door"]["cost"]

out = {"_about": "GOALS-AUDIT economy workstream (tools/economy.py). Read-only analysis of the draft's coin rewards; recommendations only. Money in copper.",
       "goals": out_goals, "totals": totals, "milestones": milestones, "anomalies": an}
json.dump(out, open(os.path.join(W, "ws_economy.json"), "w"), indent=1)
print(json.dumps({"totals": {k: v for k, v in totals.items() if k not in ("by_section", "by_dep_level", "draft_reward_values_by_dep_level", "hob_stock_prices")}, "milestones": milestones}, indent=1))
