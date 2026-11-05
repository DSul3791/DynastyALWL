extends RefCounted

# The craft menu's search box and category tabs (Dave 25 Oct; 5 Nov 2026 by name only). A recipe is shown when it is in the chosen category ("" = All) and
# every word typed (any case) is found in its own name or the name of what it makes. Ingredients and tools are not searched (Dave 5 Nov: a word that is not in
# the name must not list the recipe; 1 Nov's search by ingredient is dropped). The same box serves the inventory's Make list and every crafting table or station.

const CATEGORIES := ["Tools", "Weapons", "Shelter and building", "Workshops and stations", "Fire and cooking", "Food and drink", "Medicine", "Clothing", "Containers and furniture", "Materials"]


static func shown(recipe: Dictionary, category: String, typed: String, table = null) -> bool:
	if category != "" and str(recipe.get("category", "")) != category:
		return false

	var words: PackedStringArray = typed.replace("\t", " ").replace("\n", " ").replace("\r", " ").strip_edges().to_lower().split(" ", false)   # pasted text may carry tabs and new lines

	if words.is_empty():
		return true

	var haystack: String = text_of(recipe, table)

	for word in words:
		if not haystack.contains(word):
			return false

	return true


# Everything a typed word can match: the recipe's name and the name of the item it makes.
static func text_of(recipe: Dictionary, table = null) -> String:
	var parts: Array = [str(recipe.get("name", ""))]

	if table != null:
		parts.append(table.name_of(int(recipe.get("number", 0))))

	return " ".join(parts).to_lower()
