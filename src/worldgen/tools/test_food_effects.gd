extends SceneTree

# Temporary food effects (master DYNASTY_MASTER_ITEMS.md s3.16 [D16, D17]; Mission 001 phase 7, M001-T16): every edible crafted food has one
# group and its tier from the whole chain; XP bonuses apply at the Fitness tick only while active, never to XP already earned; the same group
# refreshes and never stacks, a weaker tier asks first, a fourth group asks which slot to replace, a declined question eats for calories
# only; slots expire; the dessert penalty is finite and shown; energy aids cost no fitness and give energy only into a new slot; medicinal
# teas are not refused when well; death clears all; effects survive a save and load and their rows survive the wire encoding.
#   godot --headless --path . --script res://src/worldgen/tools/test_food_effects.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const FoodEffects := preload("res://src/shared/food_effects.gd")
const VitalsRules := preload("res://src/shared/vitals_rules.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const KEY := "foodfx-key-0001"
const NOON := (100.0 * 24.0 + 12.0) * 3600.0   # day 100 at noon: hours of play before the Fitness midnight payout

var failures: int = 0
var items
var clock: Array = [NOON]
var food_rows: Array = []
var asks: Array = []
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(dir: String):
	var it = ItemsScript.new()
	it.send_full = func(_p, _b): pass
	it.send_slots = func(_p, _b): pass
	it.send_world_items = func(_p, _a, _r): pass
	it.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	it.send_notice = func(_p, t): said.append(str(t))
	it.send_food = func(_p, rows): food_rows.append(rows)
	it.send_food_ask = func(_p, slot, number, groups): asks.append([slot, number, groups])
	it.game_seconds = func(): return clock[0]
	it.ground_height = func(_x, _z): return 10.0
	it.setup(ItemTableScript.load_default(), dir)
	it.peer_connected_hello(1, KEY)
	it.report_position(1, Vector3(0.0, 10.0, 0.0))
	return it


func gi(group: String) -> int:
	return FoodEffects.group_index(group, items._food_cfg)


# Eats one `id` from the pack (given first when there is none) with the answer `choice`; true when one was eaten.
func eat(id: String, choice: int = 0) -> bool:
	var n: int = items.table.number_of(id)
	var inv = items.inventory_of(1)

	if inv.count_of(n) == 0:
		items.action(1, Net.ACT_ADMIN_GIVE, n, 0, 1, Vector3.ZERO)

	var before: int = inv.count_of(n)
	items._last_eat.clear()
	items.vitals_of(1)["fed"] = 0.0
	items.action(1, Net.ACT_EAT, inv.numbers.find(n), choice, 0, Vector3.ZERO)
	return inv.count_of(n) < before


func live() -> Dictionary:
	return FoodEffects.live(items._food_of(1), clock[0])


# Today's Fitness XP gained by `ticks` 10-second ticks at full effort.
func fitness_xp(ticks: int) -> float:
	var row: Dictionary = items._characters[KEY]
	var before: float = float(row.get("xp_today", 0.0))

	for n in ticks:
		items._train_fitness(1, 1.0, 10.0)

	return float(row.get("xp_today", 0.0)) - before


func _init() -> void:
	var dir: String = "user://test_food_effects"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = make(dir)
	var cfg: Dictionary = items._food_cfg
	_data_checks(cfg)

	# XP at the tick, only while active.
	var plain: float = fitness_xp(6)
	check(absf(plain - 18.0) < 0.01, "full effort earns 3 XP a 10 s tick without food (%.2f in 6 ticks)" % plain)
	var day_before_meal: float = float(items._characters[KEY]["xp_today"])
	check(eat("roast_meat"), "roast meat is eaten")
	check(float(items._characters[KEY]["xp_today"]) == day_before_meal, "eating changes no XP already earned today (never retroactive)")
	check(live().has("main") and int(live()["main"]["t"]) == 1 and absf(float(live()["main"]["until"]) - (clock[0] + 2.0 * 3600.0)) < 0.5, "Roast meat fills the Main meal slot, tier 1, for 2 game hours")
	check(absf(fitness_xp(6) - plain * 1.10) < 0.01, "Fitness XP is +10 %% at each tick while it runs (%.2f)" % (plain * 1.10))
	check(items.skill_xp_mult(1) == 1.0, "a Main meal's Fitness bonus does not touch skill XP")
	check(absf(items.food_mult(1, "regen_mult") - 1.05) < 0.0001, "red meat: health regeneration x1.05")

	for n in 5:
		eat("roast_meat")

	check(live().size() == 1 and absf(items.fitness_xp_mult(1) - 1.10) < 0.0001, "five more roast meats: still one slot, still +10 % (no stacking)")
	check(absf(float(live()["main"]["until"]) - (clock[0] + 2.0 * 3600.0)) < 0.5, "and the timer is refreshed, not extended")

	# Stronger, then weaker in the same group.
	check(eat("hunters_stew") and int(live()["main"]["t"]) == 2 and absf(items.fitness_xp_mult(1) - 1.15) < 0.0001, "a tier 2 stew replaces it without a question: +15 %, 6 h")
	asks.clear()
	check(not eat("roast_meat") and asks.size() == 1 and Array(asks[0][2]) == [gi("main")], "a weaker roast meat would replace it: the player is asked and nothing is eaten")
	check(eat("roast_meat", FoodEffects.DECLINE) and int(live()["main"]["t"]) == 2, "declined: the meat is eaten for calories only and the stew effect stays")
	check(eat("roast_meat", gi("main")) and int(live()["main"]["t"]) == 1, "confirmed: the roast meat replaces the stew")

	# Expiry.
	clock[0] += 2.0 * 3600.0 + 1.0
	check(live().is_empty() and items.fitness_xp_mult(1) == 1.0 and absf(fitness_xp(6) - plain) < 0.01, "after 2 game hours it has run out: plain XP again")
	food_rows.clear()
	items._comfort_tick()
	check(food_rows.size() == 1 and (food_rows[0] as Array).is_empty(), "the HUD is told it has gone")

	# Three groups, then a fourth.
	eat("hunters_stew")
	eat("flatbread")
	eat("roast_roots")
	check(live().size() == 3, "Main meal, Bread and grains, Fruit and vegetables run together")
	check(absf(items.food_mult(1, "exhaustion_mult") - 0.90) < 0.0001 and absf(items.food_mult(1, "regen_mult") - 1.10) < 0.0001, "bread: energy drain x0.90; the hearty stew's x1.10 regeneration beats the roots' x1.05 (the larger, not the product)")
	asks.clear()
	items.vitals_of(1)["energy"] = 50.0
	check(not eat("berry_compote") and asks.size() == 1 and Array(asks[0][2]) == [gi("main"), gi("bread"), gi("fruit_veg")], "a fourth group (Dessert) asks which of the three to replace")
	check(eat("plums") and live().size() == 3, "a raw plum has no profile: eaten, no slot touched, no question")
	check(eat("berry_compote", FoodEffects.DECLINE) and live().size() == 3 and not live().has("dessert") and items.energy_of(1) == 50.0, "declined: calories only, no energy, the three stay")
	check(eat("berry_compote", gi("bread")) and live().has("dessert") and not live().has("bread"), "answered: the Dessert replaces Bread and grains")
	check(items.energy_of(1) == 58.0, "a tier 1 dessert newly in its slot gives +8 energy at once (%.0f)" % items.energy_of(1))
	check(eat("berry_compote") and items.energy_of(1) == 58.0, "a second dessert while the first runs refreshes it with no energy")

	# The dessert penalty: finite and on its own visible timer.
	check(absf(items.fitness_xp_mult(1) - 1.10) < 0.0001, "Fitness XP = +15 % stew - 5 % dessert = +10 %")
	check(absf(items.skill_xp_mult(1) - 0.95) < 0.0001, "skill XP -5 % while the dessert runs")
	food_rows.clear()
	items._sync_food(1, true)
	var dessert_row: Array = []

	for row in food_rows[0]:
		if int(row[0]) == gi("dessert"):
			dessert_row = row

	check(not dessert_row.is_empty() and int(dessert_row[3]) == 3 and int(dessert_row[1]) == items.table.number_of("berry_compote"), "the HUD row shows the dessert with its real minutes left (1 game hour = 3 min rounded up)")
	check(FoodEffects.describe("dessert", 1, "berry_compote", cfg) == "XP -5 %", "and its effect reads 'XP -5 %'")
	clock[0] += 3601.0
	check(not live().has("dessert") and absf(items.fitness_xp_mult(1) - 1.15) < 0.0001, "after 1 game hour the penalty is gone while the 6 h stew still runs")

	# Rested and food together: added once, capped.
	items._characters[KEY]["rested"] = {"level": 20, "until": Time.get_unix_time_from_system() + 600.0}
	var rested_mult: float = float(items.rested_tier(1).get("skill_gain_mult", 1.0))
	check(rested_mult > 1.0 and absf(items.skill_xp_mult(1) - rested_mult) < 0.0001, "skill XP with Rested and a Fitness meal: Rested only (x%.2f)" % rested_mult)
	eat("berry_compote", gi("fruit_veg"))
	check(absf(items.skill_xp_mult(1) - (rested_mult - 0.05)) < 0.0001, "Rested plus a dessert: x%.2f, one sum" % (rested_mult - 0.05))
	check(absf(FoodEffects.skill_mult({"main": {"id": "feast_board_test", "t": 3, "until": 1.0e12}}, 0.0, {"caps": {"skill": 0.25}, "groups": cfg["groups"], "foods": {"feast_board_test": {"group": "main", "tier": 3, "xp": "all"}}}, 1.2) - 1.25) < 0.0001, "an all-skill +10 % with Rested +20 % is capped at +25 %")
	items._characters[KEY].erase("rested")

	# Energy aids and teas (s3.16 [D17], s7 item 22).
	items._characters[KEY]["food"] = {}
	items._characters[KEY]["train"] = 0.0
	items.vitals_of(1)["energy"] = 100.0
	check(eat("herbal_tea") and live().has("beverage"), "herbal tea is drunk when rested (no refusal) and fills the Beverage slot")
	items.vitals_of(1)["energy"] = 40.0
	check(eat("energy_bar") and items.energy_of(1) == 52.0 and float(items._characters[KEY]["train"]) == 0.0, "a Nut cake into a new Dessert slot: +12 energy, no fitness cost")
	check(eat("energy_bar") and items.energy_of(1) == 52.0, "a second Nut cake while its slot runs gives no energy (it cannot replace sleep)")
	clock[0] += 3601.0
	check(eat("energy_bar") and items.energy_of(1) == 64.0, "once the slot has run out, energy again")
	items._last_practice.clear()
	check(items.practice(1, "craft", 0.2) > 0.0, "with the dessert penalty, work at the trivial line (difficulty 0.2) still earns skill XP")
	items._characters[KEY]["food"] = {}
	eat("hunters_stew")
	eat("flatbread")
	eat("roast_roots")
	items.vitals_of(1)["energy"] = 40.0
	check(eat("energy_bar", FoodEffects.DECLINE) and items.energy_of(1) == 40.0 and not live().has("dessert"), "a declined Nut cake (a fourth group) is eaten for calories only: no energy, no slot")
	items._characters[KEY]["food"] = {}
	check(eat("chamomile_tea") and live().has("beverage") and absf(items.food_mult(1, "hunger_thirst_mult") - 0.95) < 0.0001, "chamomile tea while healthy: not refused, Beverage hunger and thirst x0.95")
	items.vitals_of(1)["sick"] = 20.0 * 3600.0
	items._last_dose.clear()
	check(eat("stomach_tea") and float(items.vitals_of(1)["sick"]) < 20.0 * 3600.0 and int(live()["beverage"]["t"]) == 2 and absf(items.food_mult(1, "hunger_thirst_mult") - 0.90) < 0.0001, "stomach tea while sick: cures and gives its tier 2 Beverage effect (x0.90)")
	items.vitals_of(1)["sick"] = 0.0
	said.clear()
	check(not eat("medicine") and said.has("Your health is fine"), "medicine without a food profile is still refused when well")
	items.vitals_of(1)["fed"] = 3000.0
	items._last_eat.clear()
	var stew_n: int = items.table.number_of("hunters_stew")
	items.action(1, Net.ACT_ADMIN_GIVE, stew_n, 0, 1, Vector3.ZERO)
	var full_before: int = items.inventory_of(1).count_of(stew_n)
	items.action(1, Net.ACT_EAT, items.inventory_of(1).numbers.find(stew_n), 0, 0, Vector3.ZERO)
	check(items.inventory_of(1).count_of(stew_n) == full_before and not live().has("main"), "a full stomach still refuses food, and no slot is filled")

	# Save, load and the wire.
	eat("hunters_stew")
	var saved_until: float = float(live()["main"]["until"])
	items._save_characters()
	items._finish_writer()
	var again = make(dir)
	check(absf(float(FoodEffects.live(again._food_of(1), clock[0]).get("main", {}).get("until", 0.0)) - saved_until) < 0.01, "the effects and their timers are saved with the character and loaded")
	food_rows.clear()
	again._sync_food(1, true)
	var rows: Array = food_rows[0]
	check(rows.size() == 2 and rows == bytes_to_var(var_to_bytes(rows)) and int(rows[0][0]) == gi("main") and int(rows[0][1]) == stew_n and int(rows[0][2]) == 2, "the HUD rows (group, item, tier, minutes) survive the wire encoding (%s)" % str(rows))
	var methods: Array = (Net as Script).get_script_method_list().map(func(m): return str(m["name"]))
	check(methods.has("food_effects") and methods.has("food_ask") and Net.PROTOCOL_VERSION >= 110, "protocol 110 carries food_effects and food_ask")
	check(asks.size() > 0 and typeof(asks[0][2]) == TYPE_PACKED_INT32_ARRAY, "the question's groups go as a PackedInt32Array")

	# Death clears every effect.
	check(again.kill(1, "test"), "the character dies")
	check(FoodEffects.live(again._food_of(1), clock[0]).is_empty() and (food_rows[-1] as Array).is_empty(), "death clears every food effect and tells the HUD")

	print("food effects: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# Every edible crafted food has a profile; the tiers follow the ingredient kinds of the whole chain; the [D17] values.
func _data_checks(cfg: Dictionary) -> void:
	var table = items.table
	var recipes: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/items/recipes.json")) as Dictionary)["recipes"]
	var vit: Dictionary = VitalsRules.load_config()
	var made: Dictionary = {}

	for rid in recipes:
		var r: Dictionary = recipes[rid]

		if not bool(r.get("future", false)) and not bool(r.get("retired", false)) and not bool(r.get("hidden", false)):
			var out: String = str(r["gives"][0])

			if not made.has(out):
				made[out] = []

			made[out].append(r)

	var missing: Array = []
	var wrong: Array = []
	var unknown: Array = (cfg["foods"] as Dictionary).keys().filter(func(id): return table.number_of(str(id)) <= 0 or not cfg["groups"].has(str(cfg["foods"][id]["group"])))
	check(unknown.is_empty(), "every profile names a real item and a known group (%s)" % str(unknown))

	for out in made:
		var entry: Dictionary = table.entry(out)

		if str(entry.get("kind", "")) != "food" or bool(entry.get("future", false)) or not VitalsRules.edible(out, vit):
			continue

		var prof: Dictionary = FoodEffects.profile(out, cfg)

		if prof.is_empty():
			missing.append(out)
			continue

		var kinds: int = _kinds(out, made, vit).size()
		var tier: int = 1 if kinds <= 2 else (2 if kinds == 3 else 3)

		if str(prof["group"]) == "beverage":
			tier = mini(tier, 2)

		if out != "energy_bar" and int(prof["tier"]) != tier:
			wrong.append("%s %d (chain %d)" % [out, int(prof["tier"]), tier])

	check(missing.is_empty(), "every edible crafted food has a food group (missing: %s)" % str(missing))
	check(wrong.is_empty(), "every tier follows its chain's ingredient kinds (wrong: %s)" % str(wrong))

	for id in ["roast_meat", "roast_fish", "roast_shellfish", "roast_seal"]:
		check(str(FoodEffects.profile(id, cfg).get("group", "")) == "main", "%s (cooked at a fire) is a Main meal" % id)

	for id in ["herbal_tea", "nettle_tea", "stomach_tea", "chamomile_tea", "willow_bark_tea", "fruit_juice"]:
		check(str(FoodEffects.profile(id, cfg).get("group", "")) == "beverage", "%s is a Beverage" % id)

	check(str(FoodEffects.profile("energy_bar", cfg).get("group", "")) == "dessert" and int(FoodEffects.profile("energy_bar", cfg)["tier"]) == 2, "Nut cake is a tier 2 Dessert (master s3.16)")
	check(FoodEffects.profile("raw_meat", cfg).is_empty() and FoodEffects.profile("sea_salt", cfg).is_empty() and FoodEffects.profile("unbaked_flatbread", cfg).is_empty(), "raw meat, salt and dough have no profile")

	for group in cfg["order"]:
		check(table != null and not FoodEffects.tier_row(str(group), 1, cfg).is_empty(), "group %s has its tier table" % group)

	var main: Array = cfg["groups"]["main"]["tiers"]
	check([main[0]["fitness_xp"], main[1]["fitness_xp"], main[2]["fitness_xp"], main[0]["h"], main[1]["h"], main[2]["h"]] == [0.10, 0.15, 0.20, 2.0, 6.0, 12.0], "Main meal +10/15/20 % for 2/6/12 h [D17]")
	check(FoodEffects.tier_row("beverage", 3, cfg) == FoodEffects.tier_row("beverage", 2, cfg), "a Beverage has no tier 3 (reads tier 2)")
	var aids: Dictionary = vit.get("energy_aids", {})
	var cost_left: bool = false

	for id in aids:
		cost_left = cost_left or aids[id].has("fitness")

	check(not cost_left and int(aids["energy_bar"]["energy"]) == 12, "energy aids carry no fitness cost; Nut cake energy 12")
	check(not str(table.entry("energy_bar").get("description", "")).contains("fitness"), "the Nut cake tooltip no longer says it wears on your fitness")


# The ingredient kinds of the cheapest recipe for `item`, through prepared (inedible) intermediates.
func _kinds(item: String, made: Dictionary, vit: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var first: bool = true

	for r in made.get(item, []):
		var kinds: Dictionary = {}

		for need in r["needs"]:
			var id: String = str(need[0])

			if made.has(id) and str(items.table.entry(id).get("kind", "")) == "food" and not VitalsRules.edible(id, vit):
				kinds.merge(_kinds(id, made, vit))
			else:
				kinds[id] = true

		if first or kinds.size() < best.size():
			best = kinds
			first = false

	return best
