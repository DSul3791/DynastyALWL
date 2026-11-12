#!/usr/bin/env python3
"""Turns data/items/dishes.json into items, recipes, food points, shelf life, weights and warmth. Safe to run again.

Run from the repo root:  python3 tools/gen_dishes.py
A dish may name a "station" (default campfire; clay_hearth or oven): the tiers are in structures.json "also", so an oven cooks what a hearth cooks and a hearth what a campfire cooks.
Numbers are append-only: an existing dish keeps its item and recipe numbers; its other rows are rewritten from dishes.json.
An existing dish also keeps its items.json "value" (economy passes tune it there; the formula prices a new dish) and its recipe "category".

Prepare -> cook (master s3.12 [D12], Mission 001 phase 6), optional dish fields:
  "prepared": an item id. The dish's "needs" become recipe prep_<dish> at the Food preparation table (prep_s seconds, default 4), giving "gives"
     of the prepared item; cook_<dish> then takes those and nothing else (the ingredients are spent once, at the table).
  "keeps": kept equipment for cook_<dish> (the Clay - Griddle on a campfire), like a recipe's own "keeps".
  "also_cook": more ways to cook the same dish, each {"station", "keeps" (required: the equipment that makes it a different method),
     "label" or "name", optional "times" (one craft makes that many batches: the cauldron) and "craft_s"}: recipe cook_<dish>_<first kept item>.
  "ready_age": game hours a sealed batch matures before it may be eaten or used (master s3.14 [D14]); put on cook_<dish>.
"""
import json


def load(path):
    return json.load(open(path, encoding="utf-8"))


def save(path, data):
    open(path, "w", encoding="utf-8").write(json.dumps(data, indent="\t", ensure_ascii=False) + "\n")


dishes = load("data/items/dishes.json")["dishes"]
items_doc = load("data/items/items.json")
recipes_doc = load("data/items/recipes.json")
vitals = load("data/items/vitals.json")
spoilage = load("data/items/spoilage.json")
weights = load("data/items/weights.json")
cooking = load("data/items/cooking.json")
gathered = load("data/items/gathered.json")["items"]
items = items_doc["items"]
recipes = recipes_doc["recipes"]
PREP_STATION = "food_preparation_table"


def known_item(item_id):
    return item_id in items or item_id in gathered


def put_recipe(recipe_id, row):
    old = recipes.get(recipe_id)

    if old:
        row["number"] = old["number"]
        row["category"] = old.get("category", row["category"])
    else:
        row["number"] = recipes_doc["next_number"]
        recipes_doc["next_number"] += 1

    recipes[recipe_id] = {key: row[key] for key in ["number", "name", "category", "needs", "keeps", "gives", "craft_s", "station", "ready_age", "known"] if key in row}


for dish_id, d in dishes.items():
    for ingredient, _ in d["needs"] + d.get("keeps", []) + [kept for way in d.get("also_cook", []) for kept in way["keeps"]]:
        if not known_item(ingredient):
            raise SystemExit("%s: unknown ingredient %s" % (dish_id, ingredient))

    if d.get("prepared") and d["prepared"] not in items:
        raise SystemExit("%s: unknown prepared item %s" % (dish_id, d["prepared"]))

    kinds = len(d["needs"])
    old = items.get(dish_id)
    number = old["number"] if old else items_doc["next_number"]

    if not old:
        items_doc["next_number"] += 1

    value = old["value"] if old and "value" in old else max(4, d["kcal"] // 40 * kinds // 2)
    items[dish_id] = {"number": number, "name": d["name"], "description": d["description"], "kind": "food", "stack": 10, "value": value, "look_alikes": []}
    prepared = d.get("prepared", "")
    cook_needs = [[prepared, d["gives"]]] if prepared else d["needs"]

    if prepared:
        put_recipe("prep_" + dish_id, {"name": items[prepared]["name"], "category": "Food and drink", "needs": d["needs"], "gives": [prepared, d["gives"]], "craft_s": float(d.get("prep_s", 4)), "station": PREP_STATION, "known": True})

    cook = {"name": d["name"], "category": "Food and drink", "needs": cook_needs, "gives": [dish_id, d["gives"]], "craft_s": float(d["craft_s"]), "station": d.get("station", "campfire"), "known": True}

    if d.get("keeps"):
        cook["keeps"] = d["keeps"]

    if d.get("ready_age"):
        cook["ready_age"] = float(d["ready_age"])

    put_recipe("cook_" + dish_id, cook)

    for way in d.get("also_cook", []):
        times = int(way.get("times", 1))
        put_recipe("cook_%s_%s" % (dish_id, way["keeps"][0][0]), {
            "name": way.get("name", "%s (%s)" % (d["name"], way.get("label", ""))), "category": "Food and drink",
            "needs": [[need[0], need[1] * times] for need in cook_needs], "keeps": way["keeps"], "gives": [dish_id, d["gives"] * times],
            "craft_s": float(way.get("craft_s", d["craft_s"])), "station": way.get("station", d.get("station", "campfire")), "known": True})

    vitals["food"]["by_id"][dish_id] = d["kcal"]
    spoilage["by_id"][dish_id] = d["shelf_h"]
    weights["by_id"][dish_id] = 0.3
    cooking["warms"][dish_id] = d["warms"]

save("data/items/items.json", items_doc)
save("data/items/recipes.json", recipes_doc)
save("data/items/vitals.json", vitals)
save("data/items/spoilage.json", spoilage)
save("data/items/weights.json", weights)
save("data/items/cooking.json", cooking)
print("%d dishes" % len(dishes))
