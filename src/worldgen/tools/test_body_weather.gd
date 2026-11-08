extends SceneTree

# The body in weather (docs/design/body_in_weather_design.md; Jamie #703): with the flags off nothing changes; with warmth.json body_703 on,
# soaked wool dries 0.4 an hour by a fire and 0.1 under a roof, wet plus wind bites harder than wet alone and strips the clothes, moderate and
# severe cold slow actions and severe doubles the drain (never below 1, no shivering); with sickness.json infection on, raw meat rolls once,
# a hit waits 1 to 3 game days, then sickens with a line naming it and is learned, a miss teaches nothing, the wait survives a save, cooked
# food never rolls and fiddleheads still sicken at once.
#   godot --headless --path . --script res://src/worldgen/tools/test_body_weather.gd

const Net := preload("res://src/stream/terrain_net.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

const KEY := "body-key-00001"

var failures: int = 0
var weather: Dictionary = {"temp_c": 5.0, "wind": 0.0, "rain": 0.0, "snow": 0.0}
var said: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(text)
	items.send_warmth = func(_p, _pct): pass
	items.send_sick = func(_p, _h): pass
	items.send_thought = func(_p, _id, _text, _kind): pass
	items.weather_now = func(): return weather
	items.setup(ItemTableScript.load_default(), dir)
	items._hints_loaded = true
	items._hints = []
	items.peer_connected_hello(1, KEY)
	items._characters[items._peer_key[1]]["grace_s"] = 0.0   # the first-hour protection has its own test
	items.report_position(1, Vector3(10.0, 0.0, 10.0))
	return items


func soak_after(items, hours: float) -> float:
	items._soak[1] = 1.0
	items._update_soak(1, hours * 3600.0)
	return float(items._soak[1])


func eat(items, id: String) -> void:
	var number: int = items.table.number_of(id)
	items.action(1, Net.ACT_ADMIN_GIVE, number, 0, 1, Vector3.ZERO)
	items.vitals_of(1)["fed"] = 0.0
	items._last_eat.erase(1)
	items.action(1, Net.ACT_EAT, items.inventory_of(1).numbers.find(number), 0, 0, Vector3.ZERO)


func _init() -> void:
	var dir: String = "user://test_body_weather"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = make(dir)
	var fire: Dictionary = {"number": 1, "count": 1, "pos": Vector3(11.0, 0.0, 10.0), "left": 1.0e9, "fire": {"state": 1, "burn_left": 1.0e6, "covered": false, "recheck": 0.0}}

	# 1. Flags off: today's drying and today's raw meat.
	check(not bool(items._warmth_cfg["body_703"]["enabled"]) and not bool(items._sick_cfg["infection"]["enabled"]), "both flags ship off")
	items._items[778] = fire
	check(soak_after(items, 0.1) < 0.5, "flag off: a fire still dries fast (%.2f after 6 game minutes)" % float(items._soak[1]))
	items._items.erase(778)
	eat(items, "raw_meat")
	check(items.is_sick(1), "flag off: raw meat sickens at once")
	items.vitals_of(1)["sick"] = 0.0
	check(is_equal_approx(items.cold_pace(1), 1.0), "flag off: no cold slowdown")

	# 2. Drying with body_703 on.
	items._warmth_cfg["body_703"]["enabled"] = true
	items._items[778] = fire
	var by_fire_2h: float = soak_after(items, 2.0)
	var by_fire_26: float = soak_after(items, 2.6)
	items._items.erase(778)
	check(by_fire_2h > 0.1 and by_fire_26 == 0.0, "by a fire, soaked wool is still damp after 2 game hours and dry by 2.6 (%.2f, %.2f)" % [by_fire_2h, by_fire_26])
	items.cover_at = func(_p): return 2.0
	var roof_5h: float = soak_after(items, 5.0)
	items.cover_at = Callable()
	check(is_equal_approx(roof_5h, 0.5), "under a roof, 0.1 an hour (%.2f after 5 game hours)" % roof_5h)
	check(soak_after(items, 3.0) == 1.0, "in the open without rain, no drying")

	# 3. Wet in wind.
	items._soak[1] = 0.0
	weather = {"temp_c": 5.0, "wind": 0.6, "rain": 0.0, "snow": 0.0}
	var dry_wind: float = items.warmth_target(1)
	items._soak[1] = 1.0
	var wet_wind: float = items.warmth_target(1)
	weather = {"temp_c": 5.0, "wind": 0.0, "rain": 0.0, "snow": 0.0}
	var wet_still: float = items.warmth_target(1)
	items._soak[1] = 0.0
	var dry_still: float = items.warmth_target(1)
	check(wet_wind < dry_wind and wet_still < dry_still, "wet is colder than dry (%.0f / %.0f windy, %.0f / %.0f still)" % [wet_wind, dry_wind, wet_still, dry_still])
	check(dry_wind - wet_wind > dry_still - wet_still, "and the wind makes the wet bite harder (%.0f against %.0f)" % [dry_wind - wet_wind, dry_still - wet_still])
	items.insulation_of = func(_p): return 0.5
	weather = {"temp_c": 10.0, "wind": 0.6, "rain": 0.0, "snow": 0.0}
	items._soak[1] = 1.0
	items._warmth_cfg["body_703"]["wet_wind_gain"] = 0.0   # isolate the stripped insulation
	var stripped: float = items.warmth_target(1)
	items._warmth_cfg["body_703"]["enabled"] = false
	var kept: float = items.warmth_target(1)
	items._warmth_cfg["body_703"]["enabled"] = true
	items._warmth_cfg["body_703"]["wet_wind_gain"] = 1.5
	items.insulation_of = func(_p): return 0.05
	items._warmth_cfg["body_703"]["enabled"] = false
	var tenth: float = items.warmth_target(1)
	items._warmth_cfg["body_703"]["enabled"] = true
	items.insulation_of = Callable()
	items._soak[1] = 0.0
	check(stripped < kept and absf(stripped - tenth) < 0.5, "soaked in a gale the clothes keep a tenth of their insulation (%.1f, as 0.05 gives %.1f; dry rules %.1f)" % [stripped, tenth, kept])

	# 4. Cold stages.
	var v: Dictionary = items.vitals_of(1)
	v["warmth"] = 30.0
	check(items.cold_stage(1) == 1 and is_equal_approx(items.cold_pace(1), 1.0), "mild cold: no slowdown")
	v["warmth"] = 15.0
	var mild_pace: float = items._pace_factor(1, "split_log")
	check(items.cold_stage(1) == 2 and is_equal_approx(items.cold_pace(1), 1.5), "moderate cold: actions take 1.5 times as long")
	v["warmth"] = 5.0
	check(items.cold_stage(1) == 3 and is_equal_approx(items.cold_pace(1), 2.5) and items._pace_factor(1, "split_log") < mild_pace, "severe cold: 2.5 times as long")
	v["warmth"] = 12.0
	var shiver_12: float = items.effort_of(1)
	v["warmth"] = 9.0
	var shiver_9: float = items.effort_of(1)
	check(shiver_12 > shiver_9, "shivering stops under 10 (effort %.2f at 12, %.2f at 9)" % [shiver_12, shiver_9])

	weather = {"temp_c": -20.0, "wind": 0.6, "rain": 0.0, "snow": 0.0}
	v["warmth"] = 5.0
	v["health"] = 80.0
	items._warmth_tick(1, v, 1.0, 1.0)
	var severe_loss: float = 80.0 - float(v["health"])
	items._warmth_cfg["body_703"]["enabled"] = false
	v["warmth"] = 5.0
	v["health"] = 80.0
	items._warmth_tick(1, v, 1.0, 1.0)
	var plain_loss: float = 80.0 - float(v["health"])
	items._warmth_cfg["body_703"]["enabled"] = true
	check(absf(severe_loss - 2.0 * plain_loss) < 0.01 and plain_loss > 0.0, "severe cold drains health twice as fast (%.3f against %.3f)" % [severe_loss, plain_loss])
	check(said.has("You have stopped shivering. Get to a fire, now."), "and says so")
	v["health"] = 1.0
	v["warmth"] = 5.0
	items._warmth_tick(1, v, 60.0, 60.0)
	check(float(v["health"]) == 1.0, "severe cold never takes health below 1")
	v["health"] = 100.0
	v["warmth"] = 100.0
	weather = {"temp_c": 15.0, "wind": 0.0, "rain": 0.0, "snow": 0.0}

	# 5. Late, uncertain sickness.
	items._sick_cfg["infection"]["enabled"] = true
	items._sick_cfg["infection"]["odds"]["raw_meat"] = 1.0   # pin a hit
	items.tried_of(1).erase("raw_meat")   # the flag-off bite taught it; start unknown so the eat is not stopped
	eat(items, "raw_meat")
	check(not items.is_sick(1) and (v.get("sick_due", []) as Array).size() == 1, "a hit waits: no sickness at the bite, one pending")
	items._sick_due_tick(1, v, 23.0 * 3600.0)
	check(not items.is_sick(1), "still well after 23 game hours")
	items._dirty = true
	items.save()
	var again = make(dir)
	var v2: Dictionary = again.vitals_of(1)
	check((v2.get("sick_due", []) as Array).size() == 1, "the pending sickness survives a save and a load")
	again._sick_cfg["infection"]["enabled"] = true
	said.clear()
	again._sick_due_tick(1, v2, 49.0 * 3600.0)
	check(again.is_sick(1) and (v2.get("sick_due", []) as Array).is_empty(), "by 72 game hours it has started")
	check(said.any(func(line): return str(line).begins_with("Your stomach turns. It was the raw meat")) and not said.has("It was rotten. You feel sick."), "with a line naming the food, not the rotten one (%s)" % str(said))
	check(str(again.tried_of(1).get("raw_meat", "")) == "harm", "and the food is learned as harmful")
	v2["sick"] = 0.0

	# A pinned miss teaches nothing, on a fresh character.
	var fresh = make(dir)
	fresh.peer_connected_hello(2, "body-key-00002")
	fresh._characters[fresh._peer_key[2]]["grace_s"] = 0.0
	fresh._sick_cfg["infection"]["enabled"] = true
	fresh._sick_cfg["infection"]["odds"]["raw_meat"] = 0.0
	fresh.report_position(2, Vector3(12.0, 0.0, 10.0))
	var meat: int = fresh.table.number_of("raw_meat")
	fresh.action(2, Net.ACT_ADMIN_GIVE, meat, 0, 1, Vector3.ZERO)
	fresh.vitals_of(2)["fed"] = 0.0
	fresh.action(2, Net.ACT_EAT, fresh.inventory_of(2).numbers.find(meat), 0, 0, Vector3.ZERO)
	check(not fresh.is_sick(2) and (fresh.vitals_of(2).get("sick_due", []) as Array).is_empty() and str(fresh.tried_of(2).get("raw_meat", "")) != "harm", "a miss leaves nothing pending and teaches nothing")

	# Cooked food never rolls; plant toxins still sicken at once.
	items._sick_cfg["infection"]["odds"]["roast_meat"] = 1.0   # even listed, cooked food has no raw_sick hours
	v["sick_due"] = []
	eat(items, "roast_meat")
	check((v.get("sick_due", []) as Array).is_empty() and not items.is_sick(1), "cooked meat never rolls")
	eat(items, "fiddleheads")
	check(items.is_sick(1) and (v.get("sick_due", []) as Array).is_empty(), "raw fiddleheads still sicken at once")

	print("test_body_weather: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
