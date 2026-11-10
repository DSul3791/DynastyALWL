extends RefCounted

# The craft menu's search box and category tabs (Dave 25 Oct; 5 Nov 2026 by name only; 10 Nov the Admin kits too). A recipe is shown when it is in the chosen category ("" = All) and
# every word typed (any case) is found in its own name or the name of what it makes. Ingredients and tools are not searched (Dave 5 Nov: a word that is not in
# the name must not list the recipe; 1 Nov's search by ingredient is dropped). The same box serves the inventory's Make list and every crafting table or station.

const CATEGORIES := ["Tools", "Weapons", "Armour", "Shelter and building", "Workshops and stations", "Fire and cooking", "Food and drink", "Medicine", "Clothing", "Containers and furniture", "Materials"]


static func shown(recipe: Dictionary, category: String, typed: String, table = null) -> bool:
	if category != "" and str(recipe.get("category", "")) != category:
		return false

	return matches(text_of(recipe, table), typed)


# Whether every word typed (any case) is in `text`; an empty box matches everything. The Admin kits under the list use it too (Dave 10 Nov).
static func matches(text: String, typed: String) -> bool:
	var words: PackedStringArray = typed.replace("\t", " ").replace("\n", " ").replace("\r", " ").strip_edges().to_lower().split(" ", false)   # pasted text may carry tabs and new lines
	var haystack: String = text.to_lower()

	for word in words:
		if not haystack.contains(word):
			return false

	return true


# Everything a typed word can match: the recipe's name and the name of the item it makes. "gives" holds the made item's number; the recipe's own
# "number" is the recipe's, not an item's (Dave 10 Nov: "campfire" listed Beet roast, Cabbage stew and Plantain poultice, recipes 255, 254 and 8,
# because items 255, 254 and 8 are the two Campfire pots and the Campfire).
static func text_of(recipe: Dictionary, table = null) -> String:
	var parts: Array = [str(recipe.get("name", ""))]
	var gives = recipe.get("gives", [])

	if table != null and gives is Array and not gives.is_empty() and (gives[0] is int or gives[0] is float):
		parts.append(table.name_of(int(gives[0])))

	return " ".join(parts).to_lower()
