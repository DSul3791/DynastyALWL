#!/usr/bin/env python3
"""Turns data/items/dishes.json into items, recipes, food points, shelf life, weights and warmth. Safe to run again.

Run from the repo root:  python3 tools/gen_dishes.py
Numbers are append-only: an existing dish keeps its item and recipe numbers; its other rows are rewritten from dishes.json.
"""
import json


def load(path):
    return json.load(open(path))


def save(path, data):
    open(path, "w").write(json.dumps(data, indent="\t", ensure_ascii=False) + "\n")


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

for dish_id, d in dishes.items():
    for ingredient, _ in d["needs"]:
        if ingredient not in items and ingredient not in gathered:
            raise SystemExit("%s: unknown ingredient %s" % (dish_id, ingredient))

    kinds = len(d["needs"])
    old = items.get(dish_id)
    number = old["number"] if old else items_doc["next_number"]

    if not old:
        items_doc["next_number"] += 1

    items[dish_id] = {"number": number, "name": d["name"], "description": d["description"], "kind": "food", "stack": 10, "value": max(4, d["kcal"] // 40 * kinds // 2), "look_alikes": []}
    old_recipe = recipes.get("cook_" + dish_id)
    recipe_number = old_recipe["number"] if old_recipe else recipes_doc["next_number"]

    if not old_recipe:
        recipes_doc["next_number"] += 1

    recipes["cook_" + dish_id] = {"number": recipe_number, "name": d["name"], "needs": d["needs"], "gives": [dish_id, d["gives"]], "craft_s": float(d["craft_s"]), "station": "campfire", "known": True}
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
