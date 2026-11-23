#!/usr/bin/env python3
"""Check the text a player reads against the game's real data (coordinator 23 Nov 2026: "what the game tells the player must be true").

The text checked is what the game shows: item, blueprint and structure descriptions (tooltips, the hammer list), the hints
(hints.json) and the guide's goals (starter_goals.json, camp_goals.json: title and hint). encyclopedia.json, item_uses.json
and other files nothing in the game reads are left out.

1. Names. A "Tier - Name" name in the text (Stone - Axe, Crude - Roof 45) must be a live item, blueprint or structure name,
   and no text names a retired item (one that is gone from the game) unless a live thing has the same name.
2. Amounts in hints and goals. Each "<N> <ingredient>" in a sentence (2 twine, 16 stones) must be an amount that one of the
   recipes or blueprints the sentence names (or the goal's own target) really asks for. A recipe or blueprint is named by its
   name or by the name of what it makes, with or without its "Tier - " part. An amount that matches none of them is reported.
3. Keeping. "<N> game days" in a food's description is how long it really keeps in a pack (spoilage.json shelf life times
   gentle_mult; summer ages it faster, so anything from the summer to the spring figure counts).

Exit status 1 when anything is wrong. Usage: python3 tools/check_player_text.py
"""
import json
import pathlib
import re
import sys

D = pathlib.Path(__file__).resolve().parent.parent / "data" / "items"


def load(name):
    with open(D / name, encoding="utf8") as f:
        return json.load(f)


ITEMS = load("items.json")
ITEMS = ITEMS.get("items", ITEMS)
BLUEPRINTS = load("blueprints.json")
BLUEPRINTS = BLUEPRINTS.get("blueprints", BLUEPRINTS)
STRUCTURES = load("structures.json")["structures"]
RECIPES = load("recipes.json")["recipes"]


def entries(table):
    return {k: v for k, v in table.items() if isinstance(v, dict) and not k.startswith("_")}


ITEMS, BLUEPRINTS, STRUCTURES, RECIPES = entries(ITEMS), entries(BLUEPRINTS), entries(STRUCTURES), entries(RECIPES)

live = set()
retired = set()
for table in (BLUEPRINTS, STRUCTURES, RECIPES, ITEMS):
    live |= {v["name"] for v in table.values() if "name" in v and not v.get("retired")}
    retired |= {v["name"] for v in table.values() if "name" in v and v.get("retired")}
retired -= live


def item_name(item_id):
    return str(ITEMS.get(item_id, {}).get("name", item_id))


# --- the text the player reads -------------------------------------------------------------------------------------------

def texts():
    for k, v in ITEMS.items():
        if not v.get("retired") and isinstance(v.get("description"), str):
            yield "items.json %s description" % k, v["description"], None
    for k, v in BLUEPRINTS.items():
        if isinstance(v.get("description"), str):
            yield "blueprints.json %s description" % k, v["description"], None
    for k, v in STRUCTURES.items():
        if isinstance(v.get("description"), str):
            yield "structures.json %s description" % k, v["description"], None
    for h in load("hints.json")["hints"]:
        yield "hints.json %s" % h["id"], h["text"], None
    for f in ("starter_goals.json", "camp_goals.json"):
        for g in load(f)["goals"]:
            yield "%s %s title" % (f, g["id"]), g["title"], g.get("check", {})
            yield "%s %s hint" % (f, g["id"]), g["hint"], g.get("check", {})


# --- 1. names ---------------------------------------------------------------------------------------------------------------

TIER_NAME = re.compile(r"\b([A-Z][a-z']+(?: [A-Z][a-z']+)? - [A-Z][\w']*(?: [a-z0-9][\w']*)*)")


PICK = re.compile(r"\bpick (?:a |an |the )?([A-Z][\w'-]*(?:(?: - | )[\w']+)*?)(?=[:,.(;]| and | from | at | to | on | or | in |$)")


def name_problems(text):
    problems = []
    for m in TIER_NAME.finditer(text):
        words = m.group(1).split(" ")
        # The longest run of words from the start that is a live name ("Crude - Roof 45 or 65" is Crude - Roof 45).
        if not any(" ".join(words[:n]) in live | retired for n in range(len(words), 2, -1)):   # a retired one is reported below
            problems.append("names %r, which is no item, blueprint or structure" % m.group(1))
    for n in retired:
        if re.search(r"(?<![\w-])" + re.escape(n) + r"(?![\w])", text):
            problems.append("names %r, which is retired (gone from the game)" % n)
    # "pick Lean-to", "pick Twine": the name the list shows, as it shows it.
    for m in PICK.finditer(text):
        if m.group(1) not in live:
            problems.append("says pick %r; no recipe, blueprint or item is called that" % m.group(1))
    return problems


# --- 2. amounts -------------------------------------------------------------------------------------------------------------

def forms(name):
    low = name.lower()
    out = {low, low + "s", low + "es"}
    if low.endswith("y"):
        out.add(low[:-1] + "ies")
    if " - " in low:   # "Stone - Axe": also "stone axe", "axe"
        tier, base = low.split(" - ", 1)
        out |= {base, base + "s", tier + " " + base}
    return out


# Every recipe and blueprint as (the names it goes by, {ingredient id: amounts}).
makers = []
for r in RECIPES.values():
    if r.get("retired"):
        continue
    needs = {}
    for ing, n in r.get("needs", []):
        needs.setdefault(ing, set()).add(int(n))
    gives = r.get("gives", [""])[0]
    makers.append((forms(r.get("name", "")) | forms(item_name(gives)), needs, {gives}))
for k, b in BLUEPRINTS.items():
    if b.get("retired"):
        continue
    needs = {}
    for ing, n in b.get("cost", []):
        needs.setdefault(ing, set()).add(int(n))
    makers.append((forms(b.get("name", "")), needs, {k, str(b.get("places", "")), str(b.get("structure", ""))}))

# Ingredient words: an item's name and its plurals, longest first so "4 bronze nails" is Bronze nails, not "bronze".
ingredient_words = []
for k, v in ITEMS.items():
    if "name" in v:
        for f in forms(v["name"]):
            ingredient_words.append((f, k))
ingredient_words.append(("fibre", "plant_fibre"))   # "3 fibre": plant fibre, the only fibre a starter has
ingredient_words.sort(key=lambda t: -len(t[0]))

NUMBER = re.compile(r"(?<![\w.,])(\d+) ([a-z][\w' -]*)", re.I)


def targets(check):
    out = set()
    if not check:
        return out
    for key in ("made_item", "got_item", "have_item", "what"):
        if isinstance(check.get(key), str):
            out.add(check[key])
    for key in ("made_item_any", "what_any"):
        out |= set(check.get(key, []))
    return out


def amount_problems(text, check):
    problems = []
    goal = targets(check)
    before = []   # what the sentence before named: "A Wooden - Workbench: ... pick it. 16 sticks, 6 twine, 8 stones."
    for sentence in re.split(r"(?<=[.!?])\s+", text):
        low = sentence.lower()
        here = [m for m in makers if any(re.search(r"(?<![\w-])" + re.escape(f) + r"(?![\w])", low) for f in m[0] if len(f) > 2) or (m[2] & goal)]
        named, before = here + before, here
        if not named:
            continue
        for m in NUMBER.finditer(sentence):
            n = int(m.group(1))
            rest = m.group(2).lower()
            ing = next((k for f, k in ingredient_words if rest == f or rest.startswith(f + " ") or rest.startswith(f + ",")), None)
            if ing is None:
                continue
            if not any(n in needs.get(ing, set()) for _, needs, _ in named):
                asks = sorted({"%d" % a for _, needs, _ in named for a in needs.get(ing, set())})
                if asks:
                    problems.append("says %d %s; what it names asks for %s" % (n, item_name(ing), " or ".join(asks)))
    return problems


# --- 3. how long food keeps -------------------------------------------------------------------------------------------------

SPOIL = load("spoilage.json")


def keep_days(item_id):
    """(fewest, most) game days the item keeps in a pack, summer to spring or autumn (winter is slower still); None if it never spoils."""
    hours = SPOIL["by_id"].get(item_id)
    if hours is None:
        hours = next((h for suffix, h in SPOIL.get("by_suffix", {}).items() if item_id.endswith(suffix)), None)
    if not isinstance(hours, (int, float)) or hours <= 0:
        return None
    life = hours * float(SPOIL.get("gentle_mult", 1)) / 24.0
    season = [float(v) for k, v in SPOIL.get("season_mult", {}).items() if k != "winter"] or [1.0]
    return life / max(season), life / min(season)


# A keeping time in words is not checkable: a food's description gives it in game days (the fruit said "a couple of weeks" for 60).
KEEP_WORDS = re.compile(r"\b(?:keeps?|lasts?|spoils?|goes soft)\b[^.]*\b(?:a|one|two|few|couple of|several) (?:day|days|week|weeks|month|months)\b", re.I)


def keep_problems(item_id, text):
    span = keep_days(item_id)
    problems = []
    if span is not None and KEEP_WORDS.search(text):
        problems.append("gives how long it keeps in words; say it in game days (it keeps %.0f to %.0f)" % span)
    for m in re.finditer(r"(\d+)(?: to (\d+))? game days", text):
        if span is None:
            problems.append("says it keeps %s game days, but it never spoils" % m.group(1))
            continue
        for n in [int(g) for g in m.groups() if g]:
            if not span[0] - 1.0 <= n <= span[1] + 1.0:
                problems.append("says %d game days; in a pack it keeps %.0f to %.0f (spoilage.json, times gentle_mult)" % (n, span[0], span[1]))
    return problems


# Known-wrong lines the check must catch, so a regex that goes blind fails here instead of passing everything.
SELF_TEST = [
    (lambda: amount_problems("Craft a Stone - Axe: 1 stone, 1 stick, 3 twine.", None), "a wrong amount"),
    (lambda: amount_problems("A Wooden - Workbench: hold your hammer. 17 sticks, 6 twine, 8 stones.", None), "a wrong amount in the next sentence"),
    (lambda: name_problems("Make a Stone - Spoon."), "a made-up name"),
    (lambda: name_problems("Build a Wooden - Chest."), "a retired name"),
    (lambda: name_problems("Hold your hammer, press R and pick Lean-too: 20 sticks."), "a wrong pick name"),
    (lambda: keep_problems("apple_early", "It keeps 3 game days."), "a wrong keeping time"),
    (lambda: keep_problems("apple_early", "It keeps a couple of days."), "a keeping time in words"),
]


def main():
    bad = 0
    for run, what in SELF_TEST:
        if not run():
            print("check_player_text self-test: missed %s" % what)
            bad += 1
    shown = list(texts())
    if len(shown) < 500 or len(live) < 500:   # a data file whose shape changed would leave nothing to check and pass
        print("check_player_text: read only %d texts and %d names; the data files' shape changed" % (len(shown), len(live)))
        bad += 1
    for where, text, check in shown:
        problems = name_problems(text) + (amount_problems(text, check) if where.split(" ")[0] in ("hints.json", "starter_goals.json", "camp_goals.json") else [])
        if where.startswith("items.json "):
            problems += keep_problems(where.split(" ")[1], text)
        for p in problems:
            print("%s: %s" % (where, p))
            bad += 1
    print("player text: %d problem(s)" % bad)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
