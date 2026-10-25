extends RefCounted

# The craft menu's search box and category tabs (Dave 25 Oct): a recipe is shown when it is in the chosen category ("" = All)
# and its name contains the typed text (any case).

const CATEGORIES := ["Tools", "Weapons", "Shelter and building", "Workshops and stations", "Fire and cooking", "Food and drink", "Medicine", "Clothing", "Containers and furniture", "Materials"]


static func shown(recipe: Dictionary, category: String, typed: String) -> bool:
	var text: String = typed.strip_edges().to_lower()
	return (category == "" or str(recipe.get("category", "")) == category) and (text == "" or str(recipe["name"]).to_lower().contains(text))
