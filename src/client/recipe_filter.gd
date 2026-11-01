extends RefCounted

# The craft menu's search box and category tabs (Dave 25 Oct; 1 Nov 2026 search by ingredient). A recipe is shown when it is in the chosen category
# ("" = All) and every word typed (any case) is found in its name, what it makes, or one of the things it needs or keeps (tools): typing "hide" lists
# everything made from a hide. The same box serves the inventory's Make list and every crafting table or station, which open that list.

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


# Everything a typed word can match: the recipe's name, the item it makes, and the names of its ingredients and tools (a group such as plain log by its own name).
static func text_of(recipe: Dictionary, table = null) -> String:
	var parts: Array = [str(recipe.get("name", ""))]

	if table != null:
		parts.append(table.name_of(int(recipe.get("number", 0))))

		for key in ["needs", "keeps"]:
			for need in recipe.get(key, []):
				parts.append(table.name_of(int(need[0])))
				parts.append(table.id_of(int(need[0])).replace("_", " "))

	return " ".join(parts).to_lower()
