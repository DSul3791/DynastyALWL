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
for table in (BLUEPRINTS, STRUCTURES, RECIPES):
    live |= {v["name"] for v in table.values() if "name" in v}
live |= {v["name"] for v in ITEMS.values() if "name" in v and not v.get("retired")}
retired = {v["name"] for v in ITEMS.values() if "name" in v and v.get("retired")} - live


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


PICK = re.compile(r"\bpick (?:a |an |the )?([A-Z][\w']*(?:(?: - | )[\w']+)*?)(?=[:,.(;]| and | from | at | to | on | or | in |$)")


def name_problems(text):
    problems = []
    for m in TIER_NAME.finditer(text):
        words = m.group(1).split(" ")
        # The longest run of words from the start that is a live name ("Crude - Roof 45 or 65" is Crude - Roof 45).
        if not any(" ".join(words[:n]) in live | retired for n in range(len(words), 2, -1)):   # a retired one is reported below
            problems.append("names %r, which is no item, blueprint or structure" % m.group(1))
    for n in retired:
        if re.search(r"(?<![\w-])" + re.escape(n) + r"(?![\w])", text):
            problems.append("names %r, a retired item" % n)
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
    needs = {}
    for ing, n in r.get("needs", []):
        needs.setdefault(ing, set()).add(int(n))
    gives = r.get("gives", [""])[0]
    makers.append((forms(r.get("name", "")) | forms(item_name(gives)), needs, {gives}))
for k, b in BLUEPRINTS.items():
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
    for sentence in re.split(r"(?<=[.!?])\s+", text):
        low = sentence.lower()
        named = [m for m in makers if any(re.search(r"(?<![\w-])" + re.escape(f) + r"(?![\w])", low) for f in m[0] if len(f) > 2) or (m[2] & goal)]
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


def main():
    bad = 0
    for where, text, check in texts():
        problems = name_problems(text) + (amount_problems(text, check) if where.split(" ")[0] in ("hints.json", "starter_goals.json", "camp_goals.json") else [])
        for p in problems:
            print("%s: %s" % (where, p))
            bad += 1
    print("player text: %d problem(s)" % bad)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
