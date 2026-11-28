extends RefCounted

# --- plan goals (Dave 25 Nov 2026: "test play ... see what bugs you can find ... improve the goals playthrough") -------------------------------
# One robot plays a brand-new character through the goal list as a new player would, with no admin gifts: it takes the first goal whose
# `after` goals are done, gets what that goal needs the way a player does and moves on. A player's means only:
# - it gathers by looking at a thing and pressing E (loose stones and sticks, plants, dead branches);
# - it chops and works wood by left clicks with the axe in hand (held_item.gd mouse_button, the real swing);
# - it crafts through the craft queue as the crafting window does, and builds blueprints with the hammer;
# - it drinks with E at the water's edge, eats from the pack, sells to Hob through his trade window's call.
# Each goal prints `GOAL <id> done|stuck ...` with the seconds it took and why it stuck; a GOALS line ends the run. A goal the robot
# cannot play yet says "robot cannot" (a note, not a bug). Anything the game refused prints the notice the player would read.
# Results are bugs only where the game is at fault: a step that should work but did nothing, a goal not credited, a misleading notice.

const NetScript := preload("res://src/stream/terrain_net.gd")
const FreezeWatchScript := preload("res://src/debug/freeze_watch.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
const MapCodec := preload("res://src/shared/map_codec.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const StructureLook := preload("res://src/shared/structure_look.gd")
const GameClockScript := preload("res://src/shared/game_clock.gd")
const StanceScript := preload("res://src/client/stance.gd")

const LOOK_UP := Vector3(0.0, 0.6, 0.0)   # harvest.gd AIM_UP: a plant is aimed at this far above its root
const SEARCH_M := 70.0                     # how far the robot looks round for a thing it needs before it walks on
const GOAL_S := 240.0                      # no goal starts with less than this left, so the end lines print before the client's timeout
const CHARCOAL_EACH_S := 400.0             # real seconds of wood burning a fire takes to leave one Charcoal (9600 game s at 24 game s a second)
const STALK_S := 45.0                      # how long a hunter stands, looks and walks up before the chase
const FISH_S := 240.0                      # the most time the fish goal spends at the water
const WAIT_VISITS := 5                     # a goal that waits on time (charcoal) is visited at most this often
const CLAY_S := 480.0                      # the most time the clay goal spends walking and digging
const HUNT_LEG_M := 300.0                  # a walk out from camp to look for game (the 25 Nov run: game ranges 175 to 270 m out)
const HUNT_WALK_S := 420.0                 # the window in which another walk-out leg may start (its chases count too)
const STORY_FROM_H := 17.5                 # the game hour a player heads back to camp for Edda's evening story (it counts from 19 to 23)
const FIRST_GOALS := ["copper_ore"]       # played as soon as they open, before the list order: 20 goals wait on copper (the runs kept ending first)
const GATHER_S := 300.0                    # one gather's time at most
const EXPLORE_S := 2400.0                  # the longest walk out looking for copper or tin (1.4 to 2 km by route each way at a walk)

var r                       # the robot (robot_play.gd)
var c                       # its client (terrain_client.gd)
var _drops: Dictionary = {}
var _gives: Dictionary = {}   # flora species name -> [item ids a pick gives] (drops.json by_species and harvest rows)
var _blueprints: Dictionary = {}   # structure -> blueprint row
var _tries: Dictionary = {}   # goal id -> tries
var _why: Dictionary = {}     # goal id -> last reason
var _visits: Dictionary = {}       # goal id -> visits that ended waiting on time
var _not_before: Dictionary = {}   # goal id -> ticks ms: a goal that waits on time (charcoal burning out of the fire) comes back no sooner
var _t0: int = 0
var _taken: Dictionary = {}   # "x,z" of a plant or branch already tried: not aimed at again
var _depth: int = 0
var _sites: Dictionary = {}       # structure -> its blueprint site's world id
var _home: Vector3 = Vector3.ZERO   # where the character first stood: the starter camp
var _fire_at: Vector3 = Vector3.INF   # where the robot lit its own fire (the fire goal): charcoal is taken from it
var _end_ms: int = 0x7FFFFFFFFFFFFFFF   # when the play must stop (play limit_s): no gather runs past it
var _groups: Dictionary = {}      # ingredient group id -> member item ids (wood_species.json ingredient_groups: "berries" is any sweet berry)


func _init(robot) -> void:
	r = robot
	c = robot.client
	var drops: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/drops.json"))
	_drops = drops if drops is Dictionary else {}

	for species in (_drops.get("by_species", {}) as Dictionary):
		_gives[species] = ((_drops["by_species"][species]) as Array).map(func(row): return str(row[0]))

	for key in ["berry_yield", "harvest_yield", "fruit_tree"]:
		for species in (_drops.get(key, {}) as Dictionary):
			var row: Variant = _drops[key][species]

			if row is Dictionary and (row as Dictionary).has("item"):
				_gives[species] = (_gives.get(species, []) as Array) + [str(row["item"])]

	var woods: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/wood_species.json"))

	for group in ((woods as Dictionary).get("ingredient_groups", {}) if woods is Dictionary else {}):
		if group != "note" and woods["ingredient_groups"][group] is Array:
			var members: Array = [str(group)] if c.items.table.has_id(str(group)) else []   # a key that is an item counts too, first (item_table.gd: a plain Log fills a log need)

			for m in woods["ingredient_groups"][group]:
				if not members.has(str(m)):
					members.append(str(m))

			_groups[str(group)] = members

	var bp: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/blueprints.json"))

	var rows: Variant = (bp as Dictionary).get("blueprints", {}) if bp is Dictionary else {}

	for row in ((rows as Dictionary).values() if rows is Dictionary else rows):
		if row is Dictionary and not bool(row.get("retired", false)) and str(row.get("station", "")) == "":
			_blueprints[str(row.get("structure", ""))] = row


func _line(text: String) -> void:
	FreezeWatchScript.printer.line("ROBOT %s %s" % [r.robot_name, text])


func _s() -> float:
	return float(Time.get_ticks_msec() - _t0) / 1000.0


# The whole play-through: goals in the book's order as they open, until none is left that the robot can try or `limit_s` runs out.
func play(limit_s: float) -> void:
	_t0 = Time.get_ticks_msec()
	_home = c.body.global_position
	_end_ms = Time.get_ticks_msec() + int(limit_s * 1000.0)
	r._step = "goals"
	var book = c.items.goal_book

	while (book == null or book.rows.is_empty()) and _s() < 30.0:
		await r._wait(0.5)
		book = c.items.goal_book

	if book == null or book.rows.is_empty():
		r._fail("goals", "book", "no goal list came from the server within 30 s of joining")
		return

	book.achieved.connect(func(row: Dictionary, copper: int) -> void: _line("GOAL %s achieved at %.0f s (%s), %d copper" % [str(row.get("id", "")), _s(), str(row.get("title", "")), copper]))
	_line("GOALS start: %d goals, %d done, pack %s" % [book.rows.size(), book.done_count(), _pack()])

	while _s() < limit_s - GOAL_S:
		var g: Dictionary = _next(book)

		if g.is_empty():
			var back: int = _waiting_until()   # only goals that wait on time are left: a player stays by the fire for them

			if back < 0 or float(back - Time.get_ticks_msec()) / 1000.0 > limit_s - GOAL_S - _s():
				break

			await r._wait(float(back - Time.get_ticks_msec()) / 1000.0 + 0.5)
			continue

		var id: String = str(g["id"])
		_tries[id] = int(_tries.get(id, 0)) + 1
		var t: float = _s()
		r._step = "goal " + id
		_line("GOAL %s try %d at %.0f s: %s" % [id, int(_tries[id]), t, str(g.get("title", ""))])
		_close_windows()
		await _lighten()
		var heard: int = r._notices.size()
		_not_before.erase(id)   # a wait that is over: this visit sets a new one if it has to wait again
		var why: String = await _play_goal(g)

		# A goal that waits on time (charcoal burning) set a time to come back: that visit is not one of its two tries, up to WAIT_VISITS visits.
		if Time.get_ticks_msec() < int(_not_before.get(id, 0)):
			_visits[id] = int(_visits.get(id, 0)) + 1

			if int(_visits[id]) < WAIT_VISITS:
				_tries[id] = int(_tries[id]) - 1
		await r._wait(2.0)   # the server's goal_progress after the last step
		_weigh_if_heavy(heard)

		if bool(book.row(id).get("done", false)):
			_line("GOAL %s done in %.0f s" % [id, _s() - t])
			continue

		if why == "":
			why = "every step went through and the goal was not credited (have %s of %s)" % [str(book.row(id).get("have", "?")), str(book.row(id).get("need", "?"))]

		_why[id] = why
		_line("GOAL %s stuck after %.0f s: %s" % [id, _s() - t, why])

	var left: Array = book.rows.filter(func(row): return not bool(row.get("done", false)))
	_line("GOALS end at %.0f s: %d of %d done, pack %s" % [_s(), book.done_count(), book.rows.size(), _pack()])

	for row in left:
		var id: String = str(row.get("id", ""))
		var why: String = str(_why.get(id, "not reached (its earlier goals were not done, or time ran out)"))
		_line("GOAL %s left: %s" % [id, why])

		if _why.has(id) and not why.begins_with("robot cannot") and Time.get_ticks_msec() >= int(_not_before.get(id, 0)):   # a goal still waiting on the clock when the run ended is not stuck
			r._fail("goals", id, "goal %s (%s) stuck: %s" % [id, str(row.get("title", "")), why])


# The first goal not done whose `after` goals are all done, tried at most twice. A goal that only wants the time of day comes first when
# the clock is right (the story in the evening, whatever its place in the list: the 26 Nov run reached it at 9 in the morning and ended
# before evening), and so do a goal whose wait is over and FIRST_GOALS.
func _next(book) -> Dictionary:
	var hour: float = _game_hour()

	for row in book.rows:
		var id: String = str(row["id"])
		var timed: bool = (id == "story" and hour >= STORY_FROM_H and hour < 22.5) or (_not_before.has(id) and Time.get_ticks_msec() >= int(_not_before[id])) or id in FIRST_GOALS

		if timed and _open(book, row):
			return row

	for row in book.rows:
		if _open(book, row):
			return row

	return {}


# Not done, under two tries, not given up on, not waiting, and its `after` goals done.
func _open(book, row: Dictionary) -> bool:
	var id: String = str(row["id"])

	if bool(row.get("done", false)) or int(_tries.get(id, 0)) >= 2 or str(_why.get(id, "")).begins_with("robot cannot") or Time.get_ticks_msec() < int(_not_before.get(id, 0)):
		return false

	for before in row.get("after", []):
		if not bool(book.row(str(before)).get("done", true)):
			return false

	return true


# The soonest a waiting goal comes back (ticks ms), -1 when none waits.
func _waiting_until() -> int:
	var soonest: int = -1

	for id in _not_before:
		var at: int = int(_not_before[id])

		if at > Time.get_ticks_msec() and int(_tries.get(id, 0)) < 2 and not bool(c.items.goal_book.row(str(id)).get("done", false)) and (soonest < 0 or at < soonest):
			soonest = at

	return soonest


# A player drops what weighs them down and no goal ahead needs: loose logs and seed stacks (the pack said "Too heavy").
func _lighten() -> void:
	var inv = c.items.inventory
	var dropped: PackedStringArray = PackedStringArray()

	for n in range(inv.numbers.size() - 1, -1, -1):
		var item: String = c.items.table.id_of(int(inv.numbers[n])) if int(inv.numbers[n]) > 0 else ""

		var keep: int = 20 if item in ["thatch", "reed_stems", "bedding", "samphire", "straw", "kindling"] else (40 if item == "stick" else 0)
		keep = 10 if item.begins_with("apple_") or item.ends_with("berries") or item in ["cherries", "fiddleheads", "foxglove_leaves"] else keep
		var junk: bool = item.begins_with("log_") or item.ends_with("_seed") or item.ends_with("_seeds") or item == "linseed" or keep > 0

		if junk and int(inv.counts[n]) > keep:
			dropped.append("%s x%d" % [item, int(inv.counts[n]) - keep])
			c.net.inventory_action.rpc_id(1, NetScript.ACT_DROP, n, 0, int(inv.counts[n]) - keep, c.body.global_position + Vector3(0.6, 0.0, 0.0))
			await r._wait(0.3)

	if not dropped.is_empty():
		_line("DROPPED %s" % ", ".join(dropped))


# When the game said "Too heavy" during a goal: the real load per item (CarryRules.weight_of, as the server weighs it), heaviest first.
func _weigh_if_heavy(from: int) -> void:
	var heavy: bool = false

	for said in r._notices.slice(from):
		heavy = heavy or str(said).contains("Too heavy")

	if not heavy:
		return

	var inv = c.items.inventory
	var rows: Array = []

	for n in range(inv.numbers.size()):
		if int(inv.numbers[n]) > 0:
			var item: String = c.items.table.id_of(int(inv.numbers[n]))
			rows.append([CarryRules.weight_of(item, c.items._carry_cfg) * float(inv.counts[n]), item, int(inv.counts[n])])

	rows.sort_custom(func(a, b): return a[0] > b[0])
	var parts: PackedStringArray = PackedStringArray()

	for row in rows:
		parts.append("%s x%d %.2f kg" % [row[1], row[2], row[0]])

	_line("WEIGHT carried %.2f of %.2f kg: %s" % [c.items.carried_kg(), c.items.carry_limit_kg(), ", ".join(parts)])


# The robot asked to walk and did not move: what holds it, so the report can say whether a window, sleep or the ground did it.
func _stuck_note(doing: String) -> void:
	var items = c.items
	_line("STUCK %s at %s: screen_open %s (pack %s, chest %s, character %s, journal %s, talk %s), asleep %s, stance %d, strain %d, held %s" % [doing,
		str(c.body.global_position.round()), str(items.screen_open()), str(items.open), str(items.chest_mode), str(items.character_open()),
		str(items.journal != null and items.journal.open), str(items.dialogue_open), str(items.asleep), int(c.stance.stance),
		int(items.strain_state), str(c.held.holding)])
	_close_windows()

	if int(items.strain_state) >= 1:   # worn out: a player stands and gets their breath back
		await r._wait(20.0)


# A player closes a trader's window before walking off (an open window holds the movement keys).
func _close_windows() -> void:
	if c.items.dialogue_open and c.items.dialogue_close.is_valid():
		c.items.dialogue_close.call()


# The hunt goal as its hint says: strike an animal with the spear (a rabbit is easiest), then hold the knife and work the body where it lies.
# The hunt is _chase_game: a rabbit and then a deer, seen, crept up on crouched and the spear thrown (_throw_hunt), stopping at the first kill.
func _hunt_goal() -> String:
	var why: String = await _have("spear", 1, false)

	if why != "":
		return "spear: " + why

	why = await _tool("knife")

	if why != "":
		return "knife: " + why

	var said: int = r._notices.size()
	var known: Dictionary = c.items._world.duplicate()
	var spear: int = r._slot_of("spear")

	if spear > 0:   # robot_play.gd _hunt strikes with slot 0: the spear goes there, as a player puts it on key 1
		c.net.inventory_action.rpc_id(1, NetScript.ACT_MOVE, spear, 0, 0, Vector3.ZERO)
		await r._wait(1.0)

	var body: int = await _chase_game(known)
	var leg: int = 0
	var until: int = mini(Time.get_ticks_msec() + int(HUNT_WALK_S * 1000.0), _end_ms - 120000)

	# None in reach of the camp (25 Nov run: the rabbit and deer ranges lie 175 to 270 m out, the animals drawn to 120 m): a player walks out
	# to look for game, a leg of HUNT_LEG_M a different way each time, and chases again there.
	while body < 0 and leg < 4 and Time.get_ticks_msec() < until:
		leg += 1
		var out: Vector3 = _home + Vector3.FORWARD.rotated(Vector3.UP, float(leg) * PI * 0.5 + 0.4) * HUNT_LEG_M
		await r._go_to(out, minf(120.0, float(until - Time.get_ticks_msec()) / 1000.0), 10.0)
		_line("HUNTWALK %d: %.0f m from camp" % [leg, _flat(_home)])   # not "HUNT": robot_check.py adds HUNT lines up as fights
		body = await _chase_game(known)

	# Rabbits feed most at dusk (animals.json rabbit active: day 0.5, dusk 1.0): a hunter who found nothing by day goes out again then, once.
	var hour: float = _game_hour()

	if body < 0 and int(_visits.get("hunt", 0)) == 0 and (hour < 17.0 or hour >= 21.0):
		var game_h: float = fposmod(17.0 - hour, 24.0)
		_not_before["hunt"] = Time.get_ticks_msec() + int(game_h * 3600.0 / GameClockScript.RATIO * 1000.0)
		return "no game brought down by day at game hour %.1f on %d walks out: it goes out again at dusk, when rabbits feed (back in %.0f real s)%s" % [hour, leg, game_h * 3600.0 / GameClockScript.RATIO, _said(said)]

	if body < 0:
		return "robot cannot hunt here yet: no rabbit or deer brought down by the camp or on %d walks out (aimed %.0f m from camp, %.0f m at the last), no carcass within 120 m%s" % [leg, HUNT_LEG_M, _flat(_home), _said(said)]

	var at: Vector3 = c.items._world[body]["pos"]
	await r._go_to(at, 30.0, 1.2)

	if _hold("knife") < 0:
		return "no knife to hold"

	var cuts: int = 0

	while cuts < 20 and c.items._world.has(body) and not bool(c.items.goal_book.row("hunt").get("done", false)):
		_look_at(at + Vector3(0.0, 0.2, 0.0))
		c.held.mouse_button(MOUSE_BUTTON_LEFT, true)
		await r._wait(0.1)
		c.held.mouse_button(MOUSE_BUTTON_LEFT, false)
		cuts += 1
		await r._wait(1.2)

	_line("CARCASS %d at %s: %d knife cuts, %s, pack %s%s" % [body, str(at.round()), cuts, "worked" if not c.items._world.has(body) else "still there", _pack(), _said(said)])
	return ""


# The nearest carcass not in `known`, within 120 m (a kill leaves its body where it fell, server make_carcass); -1 when none.
func _new_carcass(known: Dictionary) -> int:
	var body: int = -1
	var best_d: float = 120.0

	for w in c.items._world:
		var d: float = _flat(c.items._world[w]["pos"])

		if not known.has(w) and int(c.items._world[w]["state"]) == int(c.items.CARCASS_STATE) and d < best_d:
			best_d = d
			body = int(w)

	return body


# A hunt with the first spear the way a player can bring game down (26 Nov: three runs, six deer chases, no strike; a deer flees at 13 m/s,
# a player runs 9): crouched (animals.json senses crouch_factor 0.6: a deer bolts at 35 m from a standing player, 21 m from a crouched one;
# a rabbit at 14 m, 8.4 m), it creeps to throwing range and throws (right click aims, left click throws: 24 m/s, throw_damage 6 against a
# rabbit's 5 health and a deer's 20, and a wound bleeds out, blood.note_wounded), picks the spear up again and follows a hurt animal at a walk
# until it falls. The new carcass, or -1. Prints HUNTTHROW lines (not "HUNT": robot_check.py reads HUNT lines as jab fights).
func _throw_hunt(sp: int, known: Dictionary) -> int:
	# A thrown spear carries far (24 m/s): a deer is thrown at from 30 m, as a player would rather than creep the last 10 m at 0.64 m/s while
	# the herd grazes on away from them (change 14 run: 150 s crouched, the deer stayed 34 to 60 m off); a rabbit, small, from 14 m.
	var throw_m: float = 14.0 if sp == 1 else 30.0
	var seen_m: float = 120.0 if sp == 1 else 200.0
	var until: int = mini(Time.get_ticks_msec() + 150000, _end_ms - 60000)
	var target: int = -1
	var throws: int = 0
	var hit: bool = false
	var crept: bool = false
	var hp_was: float = 1.0
	var said: String = ""

	while Time.get_ticks_msec() < until and throws < 5:
		var me: Vector3 = c.body.global_position
		var drawn: Dictionary = {}

		for row in c._animal_view_node.drawn_positions():
			drawn[int(row[0])] = row[1]

		if target >= 0 and not drawn.has(target):
			said = "gone from sight"
			break

		if target < 0:
			var best_d: float = seen_m

			for id in drawn:
				var d0: float = Vector2((drawn[id] as Vector3).x - me.x, (drawn[id] as Vector3).z - me.z).length()

				if int(r._species.get(int(id), 0)) == sp and d0 < best_d:
					best_d = d0
					target = int(id)

			if target < 0:
				said = "none in sight"
				break

			hp_was = float(r._hp.get(target, 1.0))

		var at: Vector3 = drawn[target]
		var to: Vector3 = Vector3(at.x - me.x, 0.0, at.z - me.z)

		if hit:   # hurt: it bleeds out; a player follows at a walk (wounded_speed_x 0.7) and lets it go down
			if r._fell.has(target) or _new_carcass(known) >= 0:
				break

			await r._stance_to(StanceScript.STAND)
			r._face(to.normalized())
			r._key("move_forward", to.length() > 6.0)
			await r._wait(0.5)
			continue

		if to.length() > throw_m:   # walked up to 45 m (a standing player sends a deer off at 35 m), crept from there (crouched, 21 m)
			crept = to.length() < 45.0 or (crept and to.length() < 55.0)   # crouch under 45 m, stand again past 55 m (no flipping at 45 m)
			await r._stance_to(StanceScript.CROUCH if crept else StanceScript.STAND)
			r._face(to.normalized())
			r._key("move_forward", true)
			await r._wait(0.5)
			continue

		r._key("move_forward", false)

		if _hold("spear") < 0:
			said = "no spear in the pack to throw"
			break

		_aim_throw(at)
		c.held.mouse_button(MOUSE_BUTTON_RIGHT, true)   # the throw is aimed
		await r._wait(0.35)
		var now_at: Vector3 = _drawn_at(target, at)
		var lead_s: float = Vector2(now_at.x - me.x, now_at.z - me.z).length() / 24.0   # a player throws ahead of a walking animal
		_aim_throw(now_at + (now_at - at) / 0.35 * Vector3(1.0, 0.0, 1.0) * lead_s)
		await r._wait(0.1)   # the pitch reaches the camera on the next frame (terrain_client _update_view)
		var hits: int = int(r._hits.get(target, 0))
		c.held.mouse_button(MOUSE_BUTTON_LEFT, true)
		await r._wait(0.1)
		c.held.mouse_button(MOUSE_BUTTON_LEFT, false)
		c.held.mouse_button(MOUSE_BUTTON_RIGHT, false)
		throws += 1
		var flew: float = 0.0

		# The spear flies 1.3 s to 30 m and the hit comes back after it (change 16 run: the client heard "spear_hit_flesh" twice and the
		# robot, which looked after 1.0 s, called both throws misses and let the hurt deer go): up to 3 s for the answer.
		while flew < 3.0 and not hit:
			await r._wait(0.25)
			flew += 0.25
			hit = int(r._hits.get(target, 0)) > hits or float(r._hp.get(target, 1.0)) < hp_was or r._fell.has(target)

		_line("HUNTTHROW %s %d: throw %d from %.0f m, %s" % [str(r.SPECIES_NAME.get(sp, sp)), target, throws, to.length(), "hit" if hit else "missed"])
		await _pick_up_spear()

	r._release_all()
	await r._wait(1.5)
	var body: int = _new_carcass(known)
	_line("HUNTTHROW %s %d: %d throws, %s, %s%s" % [str(r.SPECIES_NAME.get(sp, sp)), target, throws, "hit" if hit else "no hit", "down, carcass %d" % body if body >= 0 else "not down",
		", " + said if said != "" else ""])

	if r._slot_of("spear") < 0:
		await _pick_up_spear()

	return body


# The camera pitched for a thrown spear to come down on `at` (server_items.gd THROW_SPEED 24 m/s, THROW_GRAVITY 9.8; the hit sphere is
# 0.6 m round the chest, 0.5 m up: target_on_segment), the lower of the two arcs.
func _aim_throw(at: Vector3) -> void:
	var eye: Vector3 = c.body.global_position + Vector3(0.0, 1.5, 0.0)   # the server flies the spear from the reported body position + EYE_HEIGHT 1.5, whatever the stance
	var aim: Vector3 = at + Vector3(0.0, 0.5, 0.0)
	var flat: float = maxf(Vector2(aim.x - eye.x, aim.z - eye.z).length(), 0.5)
	var h: float = aim.y - eye.y
	var v2: float = 24.0 * 24.0
	var root: float = v2 * v2 - 9.8 * (9.8 * flat * flat + 2.0 * h * v2)
	r._face(Vector3(aim.x - eye.x, 0.0, aim.z - eye.z).normalized())
	c.pitch = clampf(atan((v2 - sqrt(maxf(root, 0.0))) / (9.8 * flat)), -1.2, 1.2)


func _drawn_at(id: int, was: Vector3) -> Vector3:
	for row in c._animal_view_node.drawn_positions():
		if int(row[0]) == id:
			return row[1]

	return was


# The thrown spear lies where it came down (server_items _land_thrown): a player walks over and picks it up with E.
func _pick_up_spear() -> void:
	var number: int = c.items.table.number_of("spear")
	var waited: float = 0.0

	for n in range(3):
		var best: Vector3 = Vector3.INF

		# The spear flies a second or more and its row comes after it lands (change 15 run: looked at once, found nothing, and the hunt
		# went on with no spear): up to 6 s for it.
		while waited < 6.0 and r._slot_of("spear") < 0 and not _spear_on_ground(number):
			await r._wait(0.5)
			waited += 0.5

		for w in c.items._world:
			var row: Dictionary = c.items._world[w]

			if int(row.get("number", 0)) == number and _flat(row["pos"]) < 90.0 and (best == Vector3.INF or _flat(row["pos"]) < _flat(best)):
				best = row["pos"]

		if best == Vector3.INF or r._slot_of("spear") >= 0:
			if best == Vector3.INF and r._slot_of("spear") < 0:
				_line("HUNTTHROW the thrown spear is not drawn within 90 m of %s" % str(c.body.global_position.round()))

			return

		await r._stance_to(StanceScript.STAND)
		await r._go_to(best, 30.0, 1.2)
		await _press_e_at(best)
		await r._wait(0.8)


# A burning fire's state (inventory_view.gd _lit_state: the campfire, survival fire and bonfire tiers).
func _fire_lit(state: int) -> bool:
	return state in [1, 40, 41]


func _spear_on_ground(number: int) -> bool:
	for w in c.items._world:
		if int(c.items._world[w].get("number", 0)) == number and _flat(c.items._world[w]["pos"]) < 90.0:
			return true

	return false


# Hunt a rabbit, then a deer (a new character leaves the wolves alone): seen, crept up on and the spear thrown, stopping at the first kill:
# the new carcass, or -1.
func _chase_game(known: Dictionary) -> int:
	for sp in [1, 2]:
		if Time.get_ticks_msec() > _end_ms - 60000:
			break

		await _stalk(sp)
		var body: int = await _throw_hunt(sp, known)
		r._release_all()
		await r._stance_to(StanceScript.STAND)

		if body >= 0:
			return body

	return -1


# A hunter stands still and looks (a running player sends rabbits into their burrows and deer off: the 26 Nov run saw game within 150 m on
# the server and none drawn near the robot), then walks up quietly until the chase can start (robot_play.gd _hunt takes an animal drawn
# within 120 m). Big game is drawn out to 200 m (#1949), so a deer is seen further off. Up to STALK_S.
func _stalk(sp: int) -> void:
	var until: int = mini(Time.get_ticks_msec() + int(STALK_S * 1000.0), _end_ms - 60000)
	var seen_m: float = 200.0 if sp == 2 else 120.0
	var seen: float = -1.0   # the nearest it saw, -1 none
	var close: bool = false
	r._release_all()

	while Time.get_ticks_msec() < until:
		var me: Vector3 = c.body.global_position
		var near: Vector3 = Vector3.INF

		for row in c._animal_view_node.drawn_positions():
			if int(r._species.get(int(row[0]), 0)) == sp and (row[1] as Vector3).distance_to(me) < minf(seen_m, near.distance_to(me)):
				near = row[1]

		if near == Vector3.INF:
			c.body.rotation.y += 0.8   # stand and turn the head round, as a player looks about
			await r._wait(2.0)
			continue

		var d: float = Vector2(near.x - me.x, near.z - me.z).length()
		seen = d if seen < 0.0 else minf(seen, d)

		if d < 40.0:
			close = true
			break

		r._face(Vector3(near.x - me.x, 0.0, near.z - me.z).normalized())   # walk up, no running
		r._key("move_forward", true)
		r._key("run", false)
		await r._wait(1.0)

	r._release_all()
	_line("STALK %s: %s" % [str(r.SPECIES_NAME.get(sp, sp)), "within 40 m" if close else ("none seen in %.0f s" % STALK_S if seen < 0.0 else "nearest seen %.0f m, not reached" % seen)])


# A player out looking for a rock, as the copper goal's hint says: copper and tin lie inland along the rivers, more and bigger toward the
# mountains, so follow a river upstream and watch for the stained stones (boulders.json ore_rocks). The robot reads only its own map (what
# it has surveyed, map_knowledge.gd: cells within survey_radius_m 40 m of where it walked) and the rocks drawn round it. Once its map shows
# a river it walks up it in short legs, always on from where it is; where the river drops off the map for a while (a stream narrower than a
# map cell) it walks on the way the river ran; where it ends, or before any river is seen, legs of a widening loop round that spot (camp at
# first). Stops when a rock of `item` is drawn within 400 m or `limit_s` is used; returns the farthest it got from camp.
func _explore_for(item: String, limit_s: float) -> float:
	var until: int = mini(Time.get_ticks_msec() + int(limit_s * 1000.0), _end_ms)
	var leg: int = 0
	var farthest: float = 0.0
	var been: Array = []                 # river spots walked to: never chosen again
	var heading: Vector3 = Vector3.ZERO  # the way the river ran up, flat and unit; zero before a river is followed
	var lost: int = 0                    # legs walked on the heading with no river cell ahead
	var centre: Vector3 = _home          # what the loop legs circle: camp, then where a followed river gave out
	var legs: int = 0

	while Time.get_ticks_msec() < until and _nearest_boulder(item) == 0:
		var here: Vector3 = c.body.global_position
		var up: Vector3 = _river_upstream(been, heading)
		var how: String = "up the river"

		if not is_nan(up.x):
			lost = 0
			heading = Vector3(up.x - here.x, 0.0, up.z - here.z).normalized()
			been.append(up)
		elif heading != Vector3.ZERO and lost < 4:
			lost += 1
			up = here + heading * 40.0
			how = "on the river's line (%d)" % lost
		else:
			if heading != Vector3.ZERO:
				centre = here   # the river gave out (its source, or it is lost): look round there, not back at camp
				leg = 0
			heading = Vector3.ZERO
			lost = 0
			leg += 1
			up = centre + Vector3.FORWARD.rotated(Vector3.UP, float(leg) * 2.4) * (150.0 + 100.0 * float(leg))
			how = "loop leg %d" % leg

		await r._go_to(up, minf(60.0 if how.begins_with("loop") else 30.0, float(until - Time.get_ticks_msec()) / 1000.0), 6.0)
		farthest = maxf(farthest, _flat(_home))
		legs += 1

		if how.begins_with("loop") or legs % 5 == 0 or _nearest_boulder(item) != 0:   # one line in five while it follows a river
			_line("EXPLORE for %s: %s, moved %.0f m, %.0f m from camp, height %.0f m, rock found %s" % [item, how, _flat(here), _flat(_home),
				c.body.global_position.y, str(_nearest_boulder(item) != 0)])

		if _flat(here) < 1.0:
			await _stuck_note("exploring for %s" % item)

	return farthest


# On this character's own map: the river cell to walk to next going upstream, within 80 m, at least 16 m off, not within 15 m of a spot
# already walked to, not behind `heading`, and not clearly downstream (no lower than 12 m under the feet: map heights are rounded to the
# Mapping skill's step, up to 10 m, so ties are many). The highest wins; among equal heights the one farthest along `heading` (or farthest from camp before a river is
# followed). NAN when the map shows none.
func _river_upstream(been: Array, heading: Vector3) -> Vector3:
	var map = c.map_knowledge
	var cell_m: float = float(map.cell_m)
	var here: Vector3 = c.body.global_position
	var at: Vector2i = Vector2i(int(floor(here.x / cell_m)), int(floor(here.z / cell_m)))
	var reach: int = int(ceil(80.0 / cell_m))
	var away: Vector3 = heading if heading != Vector3.ZERO else Vector3(here.x - _home.x, 0.0, here.z - _home.z).normalized()
	var best: Vector3 = Vector3(NAN, NAN, NAN)
	var best_score: float = -INF

	for j in range(-reach, reach + 1):
		for i in range(-reach, reach + 1):
			var cell: Array = map.cell_at(at + Vector2i(i, j))

			if cell.size() < 3 or int(cell[2]) != MapCodec.WATER_RIVER or float(cell[1]) < here.y - 12.0:
				continue

			var spot: Vector3 = Vector3((float(at.x + i) + 0.5) * cell_m, float(cell[1]), (float(at.y + j) + 0.5) * cell_m)
			var off: Vector3 = Vector3(spot.x - here.x, 0.0, spot.z - here.z)

			if off.length() < 16.0 or off.length() > 80.0 or (heading != Vector3.ZERO and off.dot(heading) < 0.0):
				continue

			var walked: bool = false

			for b in been:
				walked = walked or Vector2(spot.x - b.x, spot.z - b.z).length() < 15.0

			var score: float = float(cell[1]) + 0.01 * off.dot(away)

			if not walked and score > best_score:
				best_score = score
				best = spot

	return best


# Back to the starter camp in 60 s legs; the seconds walked.
func _walk_home(limit_s: float) -> float:
	var leg_s: float = 0.0

	limit_s = maxf(limit_s, _flat(_home) / 1.5)   # back from a far trip (copper is over a kilometre out) at a walk, not cut off half way

	while leg_s < limit_s and c.body.global_position.distance_to(_home) > 8.0:
		await r._go_to(_home, 60.0, 6.0)
		leg_s += 60.0

	return leg_s


func _pack() -> String:
	var parts: PackedStringArray = PackedStringArray()
	var inv = c.items.inventory

	for n in range(inv.numbers.size()):
		if int(inv.numbers[n]) > 0:
			parts.append("%s x%d" % [c.items.table.id_of(int(inv.numbers[n])), int(inv.counts[n])])

	return "[" + ", ".join(parts) + "]"


# --- one goal: by its check (server data/items/starter_goals.json and camp_goals.json) --------------------------------------------------
func _play_goal(g: Dictionary) -> String:
	var id: String = str(g["id"])
	var check: Dictionary = _check_of(id)

	match id:
		"drink":
			return await _drink()
		"fell":
			return await _fell()
		"fire":
			return await _fire()
		"berries":
			return await _eat_wild()
		"copper_ore", "tin_ore":   # far inland by design (copper about 1.4 km by route, tin 2 km): a journey up a river, as the hint says
			if _nearest_boulder(id) == 0:
				var far: float = await _explore_for(id, EXPLORE_S)

				if _nearest_boulder(id) == 0:
					return "robot cannot find %s yet: none drawn after exploring up to %.0f m from camp (it walks up any river its map shows; the server's resources line gives the nearest by route)" % [id, far]

			return await _gather(id, _count(id) + int(check.get("count", 1)) if id == "tin_ore" else int(check.get("count", 1)))
		"path":
			return await _path(int(check.get("count", 15)))
		"sell":
			return await _sell()
		"hunt":
			return await _hunt_goal()
		"dig_clay":
			return await _dig_clay(int(check.get("count", 12)))
		"charcoal":
			return await _charcoal(int(check.get("count", 4)))
		"fish":
			return await _fish_goal()
		"story":
			return await _story()
		"snare", "order", "night_walk", "fur_for_winter":
			return "robot cannot play goal %s yet" % id

	if check.has("made_item"):
		return await _have(str(check["made_item"]), int(check.get("count", 1)), true)

	if check.has("made_item_all"):   # a tier's tool set (PR #1905): every one made (or held, with or_have)
		var missing: PackedStringArray = PackedStringArray()

		for item in check["made_item_all"]:
			if bool(check.get("or_have", false)) and _count(str(item)) > 0:
				continue

			var why_one: String = await _have(str(item), 1, true)

			if why_one != "":
				missing.append("%s (%s)" % [str(item), why_one])

		return "" if missing.is_empty() else "of the set, could not make: " + "; ".join(missing)

	if check.has("made_item_any"):
		return await _have(str((check["made_item_any"] as Array)[0]), int(check.get("count", 1)), true)

	if check.has("got_item"):
		return await _gather(str(check["got_item"]), _count(str(check["got_item"])) + int(check.get("count", 1)))

	if check.has("have_item"):
		return await _have(str(check["have_item"]), int(check.get("count", 1)), false)

	if str(check.get("event", "")) == "placed":
		var what: String = str(check.get("what", ((check.get("what_any", [""]) as Array)[0])))

		for any in check.get("what_any", []):   # the first one that has a hand blueprint (the Thatch - Bed's is retired: the Straw - Bed is built)
			if _blueprints.has(str(any)):
				what = str(any)
				break

		return await _build(what)

	return "robot cannot play goal %s yet (check %s)" % [id, JSON.stringify(check)]


var _checks: Dictionary = {}

func _check_of(id: String) -> Dictionary:
	if _checks.is_empty():
		for file in ["res://data/items/starter_goals.json", "res://data/items/camp_goals.json"]:
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))

			for row in ((d as Dictionary).get("goals", []) if d is Dictionary else []):
				_checks[str(row.get("id", ""))] = row.get("check", {})

	return _checks.get(id, {})


func _count(item: String) -> int:
	if _groups.has(item):   # a group need is filled by any member
		var total: int = 0

		for member in _groups[item]:
			total += int(r._count(member))

		return total

	return int(r._count(item))


# --- getting things -----------------------------------------------------------------------------------------------------------------
# Have `n` of `item`: made from its hand recipe (its inputs got first), or gathered. `make` crafts even when the pack already holds it.
func _have(item: String, n: int, make: bool) -> String:
	var recipe: Dictionary = _recipe_for(item)

	if not make and _count(item) >= n:
		return ""

	var station: String = ""

	if recipe.is_empty():
		recipe = _station_recipe_for(item)
		station = str(recipe.get("station", ""))

	if recipe.is_empty() and _groups.has(item) and item != "log":   # logs are felled (_gather sends "log" to _wood)
		return await _gather_group(item, n)

	if recipe.is_empty():
		return await _gather(item, n)

	_depth += 1

	if _depth > 6:
		_depth -= 1
		return "robot: the recipe chain for %s is too deep" % item

	var runs: int = maxi(1, ceili(float(n - (0 if make else _count(item))) / float(maxi(1, int(recipe["gives"][1])))))
	var why: String = ""

	for need in recipe.get("needs", []):
		why = await _have(str(need[0]), int(need[1]) * runs, false)

		if why != "":
			break

	if why == "":
		for keep in recipe.get("keeps", []):
			why = await _tool(str(keep[0]))

			if why != "":
				break

	_depth -= 1

	if why != "":
		return "for %s: %s" % [item, why]

	if station == "campfire":   # a clay pot is fired at a lit campfire: its own (the camp's fire is Edda and Hob's), lit again if it burned out
		if await _light_own_fire() < 0:
			return "for %s: no fire of its own to make it at (lit at %s)" % [item, str(_fire_at.round())]
	elif station != "":   # a player walks to the station they built and makes it there
		var site: int = int(_sites.get(station, -1))
		await _walk_home(240.0)

		if c.items._world.has(site):
			await r._go_to(c.items._world[site]["pos"], 30.0, 1.8)

	return await _craft(recipe, runs)


# At its own fire, with sticks put on and lit again in case it has burned down (a campfire station must be burning: server_items.gd
# nearest station, "a lit fire"); the fire's world id, or -1.
func _light_own_fire() -> int:
	if not _fire_at.is_finite() or await _have("stick", 4, false) != "":
		return -1

	await r._go_to(_fire_at, 60.0 + _flat(_fire_at) / 2.5, 2.0)
	var fire: int = _camp_fire()

	if fire < 0:
		return -1

	await r._go_to(c.items._world[fire]["pos"], 20.0, 1.6)

	for n in range(2):
		c.net.inventory_action.rpc_id(1, NetScript.ACT_FUEL, fire, 0, 0, Vector3.ZERO)
		await r._wait(0.5)

	c.net.inventory_action.rpc_id(1, NetScript.ACT_LIGHT, fire, 0, 0, Vector3.ZERO)

	# Wood laid on glowing coals catches by itself after a while (cooking.json coals.catch_s: sticks 10 s, a log 180 s; ACT_LIGHT does
	# nothing on coals): a player waits by it (change 15 run: the pot was queued 2 s after the sticks went on, "The fire is out").
	var waited: float = 0.0

	while waited < 200.0 and Time.get_ticks_msec() < _end_ms - 60000 and c.items._world.has(fire) and not _fire_lit(int(c.items._world[fire]["state"])):
		await r._wait(2.0)
		waited += 2.0

		if int(waited) % 20 == 0:
			if int(c.items._world.get(fire, {}).get("state", -1)) == 8:   # gone to cold ash (rain): sticks on again, which lays it
				c.net.inventory_action.rpc_id(1, NetScript.ACT_FUEL, fire, 0, 0, Vector3.ZERO)
				await r._wait(0.5)

			c.net.inventory_action.rpc_id(1, NetScript.ACT_LIGHT, fire, 0, 0, Vector3.ZERO)   # a laid fire or warm ash lights at once

	return fire if c.items._world.has(fire) and _fire_lit(int(c.items._world[fire]["state"])) else -1


# A hand recipe (no station) that gives `item`, the first in recipes.json order that is known.
func _recipe_for(item: String) -> Dictionary:
	for key in r._recipes:
		var row: Dictionary = r._recipes[key]

		if str(row.get("gives", [""])[0]) == item and bool(row.get("known", true)) and str(row.get("station", "")) == "" and not row.has("needs_station") and not bool(row.get("retired", false)):   # the server drops retired rows (recipe_table.gd)
			return row

	return {}


# A station recipe that gives `item`, at a station this robot has built (its site still stands); {} when none.
func _station_recipe_for(item: String) -> Dictionary:
	for key in r._recipes:
		var row: Dictionary = r._recipes[key]
		var station: String = str(row.get("station", ""))

		var built: bool = c.items._world.has(int(_sites.get(station, -1))) or (station == "campfire" and _fire_at.is_finite())   # its own fire is a campfire station

		if str(row.get("gives", [""])[0]) == item and bool(row.get("known", true)) and station != "" and built and not bool(row.get("retired", false)):
			return row

	return {}


# `n` of a group (any member): the member already carried most of, else each member in turn until the group's count is reached.
func _gather_group(group: String, n: int) -> String:
	var members: Array = (_groups[group] as Array).duplicate()
	members.sort_custom(func(a, b): return int(r._count(a)) > int(r._count(b)))
	var why: String = ""

	for member in members.slice(0, 4):
		if _count(group) >= n:
			return ""

		why = await _gather(str(member), int(r._count(member)) + n - _count(group))

	return "" if _count(group) >= n else "for %s (any of %s): %s" % [group, ", ".join(members.slice(0, 4)), why]


# A kept tool (an item id, or a tool class such as "knife"): one in the pack, made if need be.
func _tool(id: String) -> String:
	if _tool_slot(id) >= 0:
		return ""

	for maker in ["stone_" + id, "wooden_" + id, id]:
		if c.items.table.has_id(maker) and not _recipe_for(maker).is_empty():
			return await _have(maker, 1, false)

	if c.items.table.has_id(id):   # a kept material (a stone the hoe and wooden spear keep)
		return await _gather(id, 1)

	return "robot: no item found for the tool class %s" % id


func _craft(recipe: Dictionary, runs: int) -> String:
	var gives: String = str(recipe["gives"][0])
	var before: int = _count(gives)
	var hand: int = -1

	for keep in recipe.get("keeps", []):
		hand = _hold(str(keep[0]))

	var said: int = r._notices.size()
	c.net.inventory_action.rpc_id(1, NetScript.ACT_CRAFT_QUEUE, int(recipe["number"]), 0, runs, Vector3(float(hand + 1), 0.0, 0.0))
	var until: int = Time.get_ticks_msec() + int((float(recipe.get("craft_s", 5.0)) * float(runs) * 1.5 + 15.0) * 1000.0)

	while _count(gives) < before + int(recipe["gives"][1]) * runs and Time.get_ticks_msec() < until:
		await r._wait(0.3)

	var got: int = _count(gives) - before
	_line("MADE %d x %s (queued %d): %s%s" % [got, gives, runs, _pack(), _said(said)])

	if got <= 0:
		return "queued %d x %s with its needs in the pack; nothing came%s" % [runs, str(recipe.get("name", gives)), _said(said)]

	return ""


# The item (or one of the tool class) put in hand from the hotbar: its slot, or -1.
func _tool_slot(id: String) -> int:
	var inv = c.items.inventory

	for n in range(inv.numbers.size()):
		var item: String = c.items.table.id_of(int(inv.numbers[n])) if int(inv.numbers[n]) > 0 else ""

		if item != "" and (item == id or str(c.items.table.entry(item).get("tool_class", "")) == id):
			return n

	return -1


func _hold(id: String) -> int:
	var slot: int = _tool_slot(id)
	var inv = c.items.inventory

	if slot < 0:
		return -1

	if not inv.on_hotbar(slot):   # a tool further in the pack goes to a free hotbar slot first, as a player drags it (the first slot if none is free)
		var free: int = 0

		for n in range(inv.slot_count):
			if inv.on_hotbar(n) and int(inv.numbers[n]) <= 0:
				free = n
				break

		c.net.inventory_action.rpc_id(1, NetScript.ACT_MOVE, slot, free, 0, Vector3.ZERO)
		slot = free

	if not (c.held.holding and c.held.held_slot == slot):
		c.held.press_slot(slot)

	return slot


func _said(from: int) -> String:
	var said: Array = r._notices.slice(from)
	return "" if said.is_empty() else "; it said %s" % str(said)


# Gather until the pack holds `n` of `item` (first-hand, as a player: E on loose items, plants and dead branches; wood by the axe).
func _gather(item: String, n: int) -> String:
	if item in ["log", "leaves", "bark", "firewood"]:
		return await _wood(item, n)

	var start: int = _count(item)
	var until: int = mini(Time.get_ticks_msec() + int(GATHER_S * 1000.0), _end_ms)   # never past the play's own end, so its end lines print
	var said: int = r._notices.size()
	var walks: int = 0
	var presses: int = 0
	var unreached: int = 0
	var in_row: int = 0
	var heavy_from: int = said

	while _count(item) < n and Time.get_ticks_msec() < until:
		var spot: Dictionary = _nearest_source(item)

		# Many stones wanted (a smoker's 32): a player strikes a boulder, which gives them faster than walking to loose ones (change 16
		# run: 22 loose stones in 300 s), as the fire goal's hint says.
		var many: bool = item == "stone" and n - _count(item) >= 10 and (_tool_slot("pick") >= 0 or _tool_slot("axe") >= 0)   # no tool: keep the boulders for later

		if (spot.is_empty() or many) and item in ["stone", "flint", "copper_ore", "tin_ore", "iron_ore"]:
			var rock: int = _nearest_boulder(item)

			if rock != 0:   # none near: the loose ones
				_taken["rock%d" % rock] = true   # tried once, reached or not, so the loop moves on to the next rock
				var why_rock: String = await _break_rock(rock, item)

				if why_rock != "":
					_line("ROCK %d: %s" % [rock, why_rock])

				continue

		if spot.is_empty() or in_row >= 3:
			in_row = 0
			walks += 1
			_line("GATHER %s: nothing giving it within %.0f m of %s; walking on (%d)" % [item, SEARCH_M, str(c.body.global_position.round()), walks])
			var from: Vector3 = c.body.global_position
			await r._go_to(c.body.global_position + Vector3.FORWARD.rotated(Vector3.UP, float(walks) * 0.8) * (30.0 + 10.0 * float(walks)), 30.0, 3.0)   # a widening spiral

			if _flat(from) < 1.0:
				await _stuck_note("walking on for %s" % item)
			continue

		var at: Vector3 = spot["pos"]
		_taken[_key(at)] = true

		if not await r._go_to(at, 25.0, 1.4):
			unreached += 1
			in_row += 1
			continue

		in_row = 0

		var had: int = _count(item)
		await _press_e_at(at + (LOOK_UP if str(spot["kind"]) == "plant" else Vector3(0.0, 0.1, 0.0)))
		presses += 1
		var wait_until: int = Time.get_ticks_msec() + 2500

		while _count(item) == had and Time.get_ticks_msec() < wait_until:
			await r._wait(0.2)

		if str(r._notices.slice(maxi(heavy_from, r._notices.size() - 3))).contains("Too heavy"):   # a player stops and drops the straw and thatch a pick brought with it
			await _lighten()
			heavy_from = r._notices.size()   # one notice, one lightening

	var got: int = _count(item) - start
	_line("GATHER %s: +%d (now %d of %d) in %d presses, %d walks, %d out of reach%s" % [item, got, _count(item), n, presses, walks, unreached, _said(said)])

	if _count(item) < n:
		return "gathered %d %s in %.0f s (wanted %d more), %d E presses, %d sources out of reach%s" % [got, item, GATHER_S, n - start, presses, unreached, _said(said)]

	return ""


# The nearest boulder within SEARCH_M not yet worked (inventory_view.gd _boulders: stone, and the ore rocks).
func _nearest_boulder(item: String = "stone") -> int:
	var best: int = 0
	var metal: String = item.trim_suffix("_ore")
	var best_d: float = 400.0 if item.ends_with("_ore") else SEARCH_M   # a player looks further for the green rocks along a river (all drawn rocks are known)

	for id in c.items._boulders:
		var d: float = (c.items._boulders[id]["pos"] as Vector3).distance_to(c.body.global_position)
		var ore: String = str(c.items._boulders[id].get("ore", "")).trim_suffix("_ore")
		var fits: bool = ore == metal if item.ends_with("_ore") else ore == ""

		if fits and d < best_d and not _taken.has("rock%d" % int(id)):
			best_d = d
			best = int(id)

	return best


# Blows with the axe (or a pickaxe) on a boulder, as a player clicks at it, until it gives no more or 40 blows; then what fell is swept up.
func _break_rock(rock: int, item: String) -> String:
	# Ore takes a pick or a stone hammer (boulders.json tool_classes; an axe only knocks off stone); plain stone takes a pick or the axe.
	var tool: String = "pick" if _tool_slot("pick") >= 0 else ("stone_hammer" if item.ends_with("_ore") else "axe")

	if _tool_slot(tool) < 0 or _hold(tool) < 0:
		return "no %s in the pack to break it with" % tool

	var entry: Dictionary = c.items._boulders[rock]
	var at: Vector3 = entry["pos"]
	var reach: float = float(entry["radius"]) + 1.2
	var legs: int = 0

	while legs < 8 and Time.get_ticks_msec() < _end_ms and _flat(at) > reach + 0.6:   # a far rock (ore is looked for up to 400 m away) is walked to in legs
		await r._go_to(at, 60.0, reach)
		legs += 1

	if _flat(at) > reach + 0.6:
		return "walked %d legs and is still %.0f m from it" % [legs, _flat(at)]

	var had: int = _count(item)
	var said: int = r._notices.size()
	var blows: int = 0

	while blows < 40 and c.items._boulders.has(rock):
		_look_at(at + Vector3(0.0, float(entry["radius"]) * 0.5, 0.0))
		c.held.mouse_button(MOUSE_BUTTON_LEFT, true)
		await r._wait(0.1)
		c.held.mouse_button(MOUSE_BUTTON_LEFT, false)
		blows += 1
		await r._wait(1.0)

	await _sweep_up(6.0)
	_line("ROCK %d at %s: %d blows with the %s, +%d %s%s" % [rock, str(at.round()), blows, tool, _count(item) - had, item, _said(said)])
	return ""


# Ground distance from the robot (a rock on a bank above the feet is still in reach).
func _flat(p: Vector3) -> float:
	return Vector2(p.x - c.body.global_position.x, p.z - c.body.global_position.z).length()


func _key(p: Vector3) -> String:
	return "%d,%d" % [roundi(p.x * 2.0), roundi(p.z * 2.0)]


# The nearest thing within SEARCH_M that gives `item`: a loose world item of it, a plant whose pick gives it, or (sticks) a dead branch.
func _nearest_source(item: String) -> Dictionary:
	var here: Vector3 = c.body.global_position
	var best: Dictionary = {}
	var best_d: float = SEARCH_M
	var number: int = c.items.table.number_of(item) if c.items.table.has_id(item) else -1

	for w in c.items._world:
		var row: Dictionary = c.items._world[w]

		if int(row.get("number", 0)) == number and not _taken.has(_key(row["pos"])):
			var d: float = Vector2(row["pos"].x - here.x, row["pos"].z - here.z).length()

			if d < best_d:
				best_d = d
				best = {"pos": row["pos"], "kind": "pickup"}

	for chunk in c.flora._chunks:
		var held: Dictionary = c.flora._chunks[chunk].get("items", {})

		for k in range(held.get("ids", []).size()):
			var p: Vector3 = held["positions"][k]
			var d: float = Vector2(p.x - here.x, p.z - here.z).length()

			if d >= best_d or _taken.has(_key(p)):
				continue

			var sp: Dictionary = c.flora._species.get(int(held["ids"][k]) >> 16, {})
			var name: String = str(sp.get("name", ""))

			if int(sp.get("kind", 0)) == 0 and not (_drops.get("fruit_tree", {}) as Dictionary).has(name):
				continue

			if item in (_gives.get(name, []) as Array):
				best_d = d
				best = {"pos": p, "kind": "plant"}

	if item == "stick" and c.grass != null:
		var branch: Dictionary = c.grass.branch_near(here, minf(best_d, 30.0))

		if not branch.is_empty() and not _taken.has(_key(branch["pos"])):
			best = {"pos": branch["pos"], "kind": "pickup"}

	return best


# Look at a point (the body turned, the camera pitched) and tap E as a player does.
# E goes to what is closest to the reticle (Dave's rule), and at camp that can be Edda or Hob: a player who wanted a stick does not press
# E on a "Press E to talk" prompt, and shuts a talk that opened anyway (a talk screen holds the movement keys: 25 Nov run, 5 minutes stood).
func _press_e_at(point: Vector3) -> void:
	_look_at(point)
	await r._wait(0.45)   # the harvest prompt is judged every 0.2 s

	if str(c.items.current_interaction().get("kind", "")) == "npc":
		return

	await r._tap("interact")
	await r._wait(0.4)

	if c.items.dialogue_open:
		_close_windows()


func _look_at(point: Vector3) -> void:
	var eye: Vector3 = c.camera.global_position
	var to: Vector3 = point - eye
	var flat: float = Vector2(to.x, to.z).length()

	if flat > 0.05:
		r._face(Vector3(to.x, 0.0, to.z).normalized())

	c.pitch = clampf(atan2(to.y, maxf(flat, 0.05)), -1.4, 1.4)


# --- wood: fell a tree with the axe and work the trunk into logs, sticks, leaves and bark -------------------------------------------
func _fell() -> String:
	var why: String = await _tool("axe")

	if why != "":
		return why

	return await _chop_one()


func _wood(item: String, n: int) -> String:
	var why: String = await _tool("axe")

	if why != "":
		return "for %s: %s" % [item, why]

	var trees: int = 0

	while _count(item) < n and trees < 3:
		if item == "leaves":   # an axe chops a bush into leaves (and sticks) (held_item.gd _strike, ACT_HIT_SHRUB)
			await _chop_shrubs(8)

			if _count(item) >= n:
				break

		why = await _chop_one()
		trees += 1

		if why != "":
			return "for %s: %s" % [item, why]

	return "" if _count(item) >= n else "felled and worked %d trees and had %d of %d %s" % [trees, _count(item), n, item]


func _chop_one() -> String:
	var slot: int = _hold("axe")

	if slot < 0:
		return "no axe in the pack to hold"

	var trees: Array = r._trees_near(SEARCH_M)

	if trees.is_empty():
		await r._go_to(r._forest_spot() if not is_nan(r._forest_spot().x) else c.body.global_position + Vector3(0.0, 0.0, 60.0), 40.0, 4.0)
		trees = r._trees_near(SEARCH_M)

	if trees.is_empty():
		return "no tree within %.0f m" % SEARCH_M

	var here: Vector3 = c.body.global_position
	trees.sort_custom(func(a, b): return (a[0] as Vector3).distance_to(here) < (b[0] as Vector3).distance_to(here))
	var trunk: Vector3 = Vector3.INF

	for tree in trees.slice(0, 5):   # the nearest of five the robot can walk up to (a trunk on a slope or behind a rock is passed by)
		if _taken.has("tree" + _key(tree[0])):
			continue

		_taken["tree" + _key(tree[0])] = true

		if await r._go_to(tree[0], 30.0, 1.6):
			trunk = tree[0]
			break

	if trunk == Vector3.INF:
		return "walked to %d trees and reached none within 1.6 m" % mini(5, trees.size())

	var known: Dictionary = c.items._world.duplicate()
	var said: int = r._notices.size()
	var swings: int = 0
	var felled: bool = false
	var until: int = Time.get_ticks_msec() + 120000

	while Time.get_ticks_msec() < until and not felled:
		_look_at(trunk + Vector3(0.0, 1.2, 0.0))
		c.held.mouse_button(MOUSE_BUTTON_LEFT, true)
		await r._wait(0.1)
		c.held.mouse_button(MOUSE_BUTTON_LEFT, false)
		swings += 1
		await r._wait(1.0)
		felled = r._trees_near(3.0).filter(func(t): return (t[0] as Vector3).distance_to(trunk) < 0.5).is_empty()

	_line("FELL tree at %s: %s after %d swings%s" % [str(trunk.round()), "down" if felled else "standing", swings, _said(said)])

	if not felled:
		return "swung the axe at a tree %d times over 120 s and it stood%s" % [swings, _said(said)]

	await r._wait(4.0)   # it lands and becomes a trunk
	var work: int = 0
	var until_work: int = Time.get_ticks_msec() + 120000

	while Time.get_ticks_msec() < until_work:
		var piece: int = -1
		var best: float = 25.0

		for w in c.items._world:
			if known.has(w):
				continue

			var d: float = (c.items._world[w]["pos"] as Vector3).distance_to(c.body.global_position)
			var what: String = c.items.table.id_of(int(c.items._world[w].get("number", 0)))

			if d < best and (what.begins_with("log") or what.contains("trunk") or what.contains("stump")):
				best = d
				piece = int(w)

		if piece < 0:
			break

		var at: Vector3 = c.items._world[piece]["pos"]
		await r._go_to(at, 15.0, 1.6)
		_look_at(at + Vector3(0.0, 0.3, 0.0))
		c.held.mouse_button(MOUSE_BUTTON_LEFT, true)
		await r._wait(0.1)
		c.held.mouse_button(MOUSE_BUTTON_LEFT, false)
		work += 1
		await r._wait(1.0)

		if work > 80:
			break

	_line("WOOD worked the tree in %d blows: %s" % [work, _pack()])
	await _sweep_up(12.0)
	return ""


func _chop_shrubs(most: int) -> void:
	var here: Vector3 = c.body.global_position
	var bushes: Array = []

	for chunk in c.flora._chunks:
		var held: Dictionary = c.flora._chunks[chunk].get("items", {})

		for k in range(held.get("ids", []).size()):
			var p: Vector3 = held["positions"][k]

			if int(c.flora._species.get(int(held["ids"][k]) >> 16, {}).get("kind", 0)) == 1 and p.distance_to(here) < 40.0 and not _taken.has("bush" + _key(p)):
				bushes.append(p)

	bushes.sort_custom(func(a, b): return (a as Vector3).distance_to(here) < (b as Vector3).distance_to(here))
	var had: int = _count("leaves")
	var said: int = r._notices.size()
	var done: int = 0

	for p in bushes.slice(0, most):
		_taken["bush" + _key(p)] = true

		if _hold("axe") < 0 or not await r._go_to(p, 15.0, 1.3):
			continue

		for n in range(4):
			_look_at(p + Vector3(0.0, 0.5, 0.0))
			c.held.mouse_button(MOUSE_BUTTON_LEFT, true)
			await r._wait(0.1)
			c.held.mouse_button(MOUSE_BUTTON_LEFT, false)
			await r._wait(1.0)

		done += 1
		await _sweep_up(3.0)

	_line("BUSHES chopped %d of %d near: +%d leaves, pack %s%s" % [done, bushes.size(), _count("leaves") - had, _pack(), _said(said)])


# Held E for `s` seconds: the sweep picks up what lies within 2 m, as a player clears up after a felling.
# Not while E would talk (Edda or Hob nearest the reticle, as _press_e_at); a talk that opened anyway is shut.
func _sweep_up(s: float) -> void:
	if str(c.items.current_interaction().get("kind", "")) == "npc":
		return

	var start: Vector3 = c.body.global_position
	r._key("interact", true)

	for n in range(int(s)):
		await r._go_to(start + Vector3(2.0, 0.0, 0.0).rotated(Vector3.UP, float(n) * 0.9), 1.0, 0.5)

	r._key("interact", false)

	if c.items.dialogue_open:
		_close_windows()


# --- fire: a campfire kit laid on open ground and lit (plant fibre is the tinder, cooking.json) -------------------------------------
func _fire() -> String:
	var why: String = await _have("campfire_kit", 1, false)

	if why != "":
		return why

	why = await _have("plant_fibre", 3, false)

	if why != "":
		return "tinder: " + why

	# A player lights their fire by the camp (the 26 Nov runs lit it 280 m out, where the stones were): clay pots and charcoal are made at it.
	# Not within keep_m (8 m) of the camp tree (data/npcs/camp.json; the camp's own fire burns 2 m from it): 14 m out from that fire, on the spawn's side.
	await _walk_home(240.0)
	var camp_fire: Vector3 = _home   # Edda and Hob's fire, the "camp" row nearest the spawn within 60 m (goblin and bandit camps carry the flag too)
	var camp_d: float = 60.0

	for w in c.items._world:
		var row: Dictionary = c.items._world[w]

		if row.get("camp", false) and not row.get("bandits", false) and (row["pos"] as Vector3).distance_to(_home) < camp_d:
			camp_d = (row["pos"] as Vector3).distance_to(_home)
			camp_fire = row["pos"]

	var away: Vector3 = (_home - camp_fire) * Vector3(1.0, 0.0, 1.0)
	away = away.normalized() if away.length() > 0.5 else Vector3.FORWARD
	await r._go_to(camp_fire + away * 14.0, 30.0, 1.0)
	r._face(away)
	await r._wait(0.3)
	var slot: int = r._slot_of("campfire_kit")
	var at: Vector3 = c.body.global_position - c.body.global_transform.basis.z * 2.5
	var ground: float = float(c.items._ground_below.call(at))
	at.y = ground if not is_nan(ground) else c.body.global_position.y - 0.9
	var known: Dictionary = c.items._world.duplicate()
	var said: int = r._notices.size()
	c.net.inventory_action.rpc_id(1, NetScript.ACT_PLACE, slot, 0, 0, at)
	await r._wait(2.5)
	var fire: int = -1

	for w in c.items._world:
		if not known.has(w) and (c.items._world[w]["pos"] as Vector3).distance_to(at) < 3.0:
			fire = int(w)

	if fire < 0:
		return "laid the campfire kit 2.5 m ahead; no fire came%s" % _said(said)

	await _press_e_at(c.items._world[fire]["pos"])
	await r._wait(3.0)

	for n in range(4):   # sticks on, and lit (E on a laid fire; the call it makes if E gave another choice)
		c.net.inventory_action.rpc_id(1, NetScript.ACT_FUEL, fire, 0, 0, Vector3.ZERO)
		await r._wait(0.5)

	c.net.inventory_action.rpc_id(1, NetScript.ACT_LIGHT, fire, 0, 0, Vector3.ZERO)
	await r._wait(3.0)
	_fire_at = at
	_line("FIRE %d at %s%s" % [fire, str(at.round()), _said(said)])
	return ""


# --- Edda's story: talk with her at the camp in the evening (camp_goals.json "story": talked, npc edda, hour_between 19 and 23) ------------
# A player comes back to camp late in the afternoon, waits for 7 o'clock, walks up to Edda and presses E on "Press E to talk to Edda".
# Before that hour the goal waits (a wait is not a try); the talk screen is shut again once it opens.
func _story() -> String:
	var hour: float = _game_hour()

	if hour < STORY_FROM_H or hour >= 22.5:
		var game_h: float = fposmod(STORY_FROM_H - hour, 24.0)
		_not_before["story"] = Time.get_ticks_msec() + int(game_h * 3600.0 / GameClockScript.RATIO * 1000.0)
		return "waits for the evening: the game hour is %.1f and the story counts from 19 to 23 (back in %.0f real s)" % [hour, game_h * 3600.0 / GameClockScript.RATIO]

	_not_before.erase("story")
	var leg_s: float = await _walk_home(480.0)

	while _game_hour() < 19.0 and _game_hour() >= STORY_FROM_H - 0.5:
		await r._wait(5.0)   # by the fire until 7 o'clock

	if _game_hour() >= 23.0 or _game_hour() < 19.0:
		return "back at camp after %.0f s of walking, the game hour is %.1f: the evening was over" % [leg_s, _game_hour()]

	var said: int = r._notices.size()

	for attempt in range(4):
		var edda: Dictionary = _edda()

		if edda.is_empty():
			return "Edda is not drawn anywhere near the camp at game hour %.1f (people drawn: %s)" % [_game_hour(), str((c._npc_view.within(c.body.global_position, 3000.0) if c._npc_view != null else []).map(func(n): return str(n["name"])))]

		await r._go_to(edda["pos"], 60.0, 1.8)
		_look_at(_edda().get("pos", edda["pos"]) + Vector3(0.0, 1.2, 0.0))   # dialogue_view.gd CHEST: a person is aimed at by the chest
		await r._wait(0.45)
		var prompt: String = str(c.items.current_interaction().get("prompt", ""))

		if str(c.items.current_interaction().get("kind", "")) != "npc" or not prompt.contains("Edda"):
			_line("STORY try %d: %.1f m from Edda, the prompt is \"%s\"" % [attempt + 1, c.body.global_position.distance_to(edda["pos"]), prompt])
			continue

		await r._tap("interact")
		await r._wait(2.0)
		var opened: bool = c.items.dialogue_open
		_close_windows()
		await r._wait(2.0)   # the server's goal_progress
		_line("STORY talked to Edda at game hour %.1f (talk screen opened %s, closed)%s" % [_game_hour(), str(opened), _said(said)])

		if bool(c.items.goal_book.row("story").get("done", false)):
			return ""

	return "4 tries to talk to Edda at game hour %.1f did not count%s" % [_game_hour(), _said(said)]


func _edda() -> Dictionary:
	for npc in (c._npc_view.within(c.body.global_position, 3000.0) if c._npc_view != null else []):
		if str(npc["id"]) == "edda" or str(npc["name"]).to_lower() == "edda":
			return npc

	return {}


func _game_hour() -> float:
	return fposmod(float(c.game_clock.seconds), 86400.0) / 3600.0


# --- a fish with the Fishing spear, as the goal's hint says: stand still at the water's edge, the spear in hand, and jab (left click) at
# water ankle to waist deep (fishing.json fish_spear: reach 2.5 m, standing still, a 0.2 chance a jab, only where fish are). The jab lands
# 2.5 m ahead of the eye and 1.2 m down (held_item.gd). Where the game says no fish or the wrong depth, a player moves along the shore.
func _fish_goal() -> String:
	var why: String = await _have("fishing_spear", 1, false)

	if why != "":
		return "fishing spear: " + why

	if _hold("fishing_spear") < 0:
		return "no fishing spear to hold"

	var said: int = r._notices.size()
	var until: int = mini(Time.get_ticks_msec() + int(FISH_S * 1000.0), _end_ms)
	var jabs: int = 0
	var spots: int = 0
	var told: PackedStringArray = PackedStringArray()
	var swam: int = 0

	while Time.get_ticks_msec() < until and not bool(c.items.goal_book.row("fish").get("done", false)) and spots < 6:
		spots += 1
		var water: Vector3 = await r._find_water()

		if is_nan(water.x):
			return "no water in any loaded chunk"

		# The edge: 0.5 to 2.5 m short of the wet corner, on the land side (the jab lands 2.4 m ahead, inside the 2.5 m reach).
		var back: Vector3 = Vector3(c.body.global_position.x - water.x, 0.0, c.body.global_position.z - water.z).normalized()
		await r._go_to(water + back * 1.5, minf(90.0, float(until - Time.get_ticks_msec()) / 1000.0), 1.0)
		r._release_all()
		var heard: int = r._notices.size()
		var here: int = 0

		if c.swimming:   # the server takes no jab from a swimmer: back out onto the land and try the next stretch
			swam += 1
			await r._go_to(c.body.global_position + back * 4.0, minf(8.0, float(until - Time.get_ticks_msec()) / 1000.0), 1.0)
			continue

		await r._wait(1.5)   # still long enough for the server (fish_spear still_below)

		while here < 15 and Time.get_ticks_msec() < until and not bool(c.items.goal_book.row("fish").get("done", false)):
			_look_at(water)
			c.pitch = -0.25
			await r._wait(0.8)   # standing still (fish_spear still_below)
			c.held.mouse_button(MOUSE_BUTTON_LEFT, true)
			await r._wait(0.1)
			c.held.mouse_button(MOUSE_BUTTON_LEFT, false)
			await r._wait(1.2)   # the jab's cooldown is 1.2 s
			here += 1
			jabs += 1

		for n in range(heard, r._notices.size()):
			if not told.has(str(r._notices[n])):
				told.append(str(r._notices[n]))

		_line("FISH spot %d at %s: %d jabs, goal %s" % [spots, str(c.body.global_position.round()), here, str(c.items.goal_book.row("fish").get("have", "?"))])

		# Another stretch of shore: 12 m along it, round the water's edge.
		if spots < 6 and Time.get_ticks_msec() < until and not bool(c.items.goal_book.row("fish").get("done", false)):
			await r._go_to(c.body.global_position + back.rotated(Vector3.UP, PI * 0.5) * 12.0, minf(8.0, float(until - Time.get_ticks_msec()) / 1000.0), 1.0)

	if bool(c.items.goal_book.row("fish").get("done", false)):
		return ""

	return "%d jabs at %d spots along the shore (%d stood swimming, no jab) and no fish; at the shore the game said %s%s" % [jabs, spots, swam,
		str(told) if not told.is_empty() else "nothing", _said(said)]


# --- drink and eat --------------------------------------------------------------------------------------------------------------------
func _drink() -> String:
	var water: Vector3 = await r._find_water()

	if is_nan(water.x):
		return "no water in any loaded chunk"

	await r._go_to(water, 90.0, 2.0)
	var said: int = r._notices.size()
	var found: Dictionary = {}

	for pitch in [-0.5, -0.8, -0.3]:
		_look_at(water)
		c.pitch = pitch
		await r._wait(0.4)
		found = c.items.current_interaction()

		if str(found.get("prompt", "")).contains("drink"):
			break

	_line("DRINK at %s, %.1f m from the water; E offers %s" % [str(c.body.global_position.round()), Vector2(water.x - c.body.global_position.x, water.z - c.body.global_position.z).length(), str(found.get("prompt", "nothing"))])

	for n in range(3):
		await r._tap("interact")
		await r._wait(1.0)

	return "" if str(found.get("prompt", "")).contains("drink") else "at the water's edge E offered no drink (%s)%s" % [str(found.get("prompt", "nothing")), _said(said)]


func _eat_wild() -> String:
	var food: String = ""

	for item in ["wild_apples", "raspberries", "blackberries", "blueberries", "hazelnuts", "acorns"]:
		if _count(item) > 0:
			food = item

	if food == "":
		for item in ["raspberries", "blackberries", "blueberries", "wild_apples", "hazelnuts"]:
			if not _nearest_source(item).is_empty():
				var why: String = await _gather(item, 1)

				if why == "":
					food = item
					break

	if food == "":
		return "found nothing wild to eat within %.0f m (berries, apples, nuts)" % SEARCH_M

	var said: int = r._notices.size()
	c.net.inventory_action.rpc_id(1, NetScript.ACT_EAT, r._slot_of(food), 0, 0, Vector3.ZERO)
	await r._wait(2.0)
	_line("ATE %s%s" % [food, _said(said)])
	return ""


# --- the hoe treads a path toward the water ----------------------------------------------------------------------------------------
func _path(strokes: int) -> String:
	var why: String = await _tool("wooden_hoe")

	if why != "":
		return why

	var slot: int = _hold("wooden_hoe")
	await _walk_home(240.0)   # "from camp to the water": the path starts at the camp
	var water: Vector3 = await r._find_water()
	var dir: Vector3 = Vector3(water.x - c.body.global_position.x, 0.0, water.z - c.body.global_position.z).normalized() if not is_nan(water.x) else Vector3.FORWARD
	var said: int = r._notices.size()

	# Each stroke lands 1 m past the last along one line: the game lays nothing within 0.7 m (PATH_SPACING_M) of a patch.
	# At the shore ("You cannot tread a path in water.") a player starts another line from the camp and keeps going until the goal counts.
	var start: Vector3 = _home
	var base: Vector3 = dir
	var missed: int = 0
	var sent: int = 0
	var along: int = 0
	var dry: int = 0
	var turns: int = 0

	for n in range(strokes * 2 + 6):
		if bool(c.items.goal_book.row("path").get("done", false)):
			break

		# The goal's own count is the truth: two strokes in a row that laid nothing (water, a patch already there, a tree) and the robot turns.
		# A new line out from the camp (round it by 70 degrees a time), so a turn never walks the robot along the shore into the water.
		if dry >= 2:
			turns += 1
			dir = base.rotated(Vector3.UP, deg_to_rad(70.0) * float(turns))
			start = _home
			along = 0
			dry = 0

		var ground: Vector3 = start + dir * (1.5 + float(along))
		along += 1
		await r._go_to(ground - dir * 1.2, 6.0, 0.5)

		if Vector2(ground.x - c.body.global_position.x, ground.z - c.body.global_position.z).length() > 2.5:
			missed += 1
			continue

		var y: float = float(c.items._ground_below.call(ground))
		ground.y = y if not is_nan(y) else c.body.global_position.y - 0.9
		var had: int = int(c.items.goal_book.row("path").get("have", 0))
		c.net.inventory_action.rpc_id(1, NetScript.ACT_HOE_PATH, slot, 0, 0, ground)
		sent += 1
		await r._wait(0.8)
		dry = dry + 1 if int(c.items.goal_book.row("path").get("have", 0)) == had else 0

	_line("PATH %d hoe strokes toward the water, %d out of reach, %d turns, goal has %s%s" % [sent, missed, turns, str(c.items.goal_book.row("path").get("have", "?")), _said(said)])
	return ""


# --- charcoal, the game's way (cooking.json charcoal_left): wood burning in a fire leaves one Charcoal for every 9600 game seconds of
# burning, about 400 real seconds at 24 game seconds a second, in the fire's own store. A player keeps a log or firewood burning in the
# camp fire, takes the charcoal out of its store (the fire's window: ACT_CHEST_OPEN on the fire, as F beside it) and comes back for more.
func _charcoal(want: int) -> String:
	var said: int = r._notices.size()

	if _count("charcoal") >= want:
		return ""

	# Its own fire, where it lit it (the 26 Nov run lit its first fire 280 m out, where its stones were; things are drawn to 100 m).
	if _fire_at.is_finite():
		await r._go_to(_fire_at, 60.0 + _flat(_fire_at) / 2.5, 6.0)
	else:
		await _walk_home(240.0)

	var fire: int = _camp_fire()

	if fire < 0:
		return "no campfire of its own drawn within 40 m (its fire was lit at %s, %.0f m from camp)%s" % [str(_fire_at.round()) if _fire_at.is_finite() else "no known spot", _fire_at.distance_to(_home) if _fire_at.is_finite() else 0.0, _said(said)]

	await r._go_to(c.items._world[fire]["pos"], 30.0, 1.6)
	var store: Array = await _open_store(fire)

	if store[0] == null:
		return "opened the fire's store (world item %d): no contents came%s" % [fire, _said(said)]

	var took: int = await _take_all(fire, store, "charcoal")
	var wood: int = _store_count(store[0], ["log", "firewood"])

	# Nothing burning that leaves charcoal (sticks and kindling leave none): a piece of firewood or a log goes in, and the fire is lit.
	var fed: String = "none"

	if wood == 0:
		for item in ["log", "firewood"]:   # a log leaves 27 Charcoal, a Firewood 3 (cooking.json fuel: 259200 and 28800 game s)
			var slot: int = r._slot_of(item) if item != "log" else _log_slot()

			if slot >= 0:
				var pieces: int = 1 if item == "log" else mini(ceili(float(want - _count("charcoal")) / 3.0), int(c.items.inventory.counts[slot]))
				c.net.inventory_action.rpc_id(1, NetScript.ACT_CHEST_PUT, slot, fire, pieces, Vector3.ZERO)
				await r._wait(1.0)
				fed = c.items.table.id_of(int(c.items.inventory.numbers[slot])) if int(c.items.inventory.numbers[slot]) > 0 else item
				break

		if fed == "none":
			c.net.inventory_action.rpc_id(1, NetScript.ACT_CHEST_CLOSE, fire, 0, 0, Vector3.ZERO)
			c.net.chest_received.disconnect(store[1])
			var why: String = "" if _log_slot() >= 0 else await _have("log", 1, false)

			if why != "" and _log_slot() < 0:
				why = await _have("firewood", 1, false)

			if _log_slot() >= 0 or r._slot_of("firewood") >= 0:
				why = ""

			if why != "":
				return "no firewood or log to burn for charcoal: %s" % why

			await r._go_to(c.items._world[fire]["pos"], 60.0, 1.6)
			store = await _open_store(fire)

			if store[0] == null:
				return "opened the fire's store again: no contents came%s" % _said(said)

			var slot2: int = _log_slot()
			slot2 = slot2 if slot2 >= 0 else r._slot_of("firewood")
			c.net.inventory_action.rpc_id(1, NetScript.ACT_CHEST_PUT, slot2, fire, 1, Vector3.ZERO)
			await r._wait(1.0)
			fed = "firewood or log"

	c.net.inventory_action.rpc_id(1, NetScript.ACT_CHEST_CLOSE, fire, 0, 0, Vector3.ZERO)
	c.net.chest_received.disconnect(store[1])
	c.net.inventory_action.rpc_id(1, NetScript.ACT_LIGHT, fire, 0, 0, Vector3.ZERO)   # a cold fire is lit again (a lit one ignores it)
	await r._wait(1.0)
	var have: int = _count("charcoal")
	_line("CHARCOAL fire %d (state %d): took %d, %d log or firewood burning, fed %s, pack has %d of %d%s" % [fire, int(c.items._world.get(fire, {}).get("state", -1)),
		took, wood, fed, have, want, _said(said)])

	if have >= want or bool(c.items.goal_book.row("charcoal").get("done", false)):
		_not_before.erase("charcoal")
		return ""

	# The fire makes one about every CHARCOAL_EACH_S: the robot plays other goals and comes back when the rest should be there.
	# Damp wood burns slower (cooking.json wet_burn_x): a visit that finds too few just waits again; a wait is not a try (see the main loop).
	_not_before["charcoal"] = Time.get_ticks_msec() + int(float(want - have) * CHARCOAL_EACH_S * 1000.0) + 60000
	return "waiting for the fire: %d of %d charcoal so far, back in about %.0f s" % [have, want, float(want - have) * CHARCOAL_EACH_S + 60.0]


# This character's own fire nearest the camp (not Edda and Hob's: their fire is marked camp), -1 when none is within 40 m.
func _camp_fire() -> int:
	var best: int = -1
	var best_d: float = 40.0   # the robot's own fire, the nearest to where it stands (it walked to its fire, or to camp)

	for id in c.items._world:
		var w: Dictionary = c.items._world[id]

		if int(w["state"]) in StructureLook.CAMPFIRE_STATES and not w.get("camp", false) and _flat(w["pos"]) < best_d:
			best_d = _flat(w["pos"])
			best = int(id)

	return best


# Opens a store (a fire's, a chest's) as its window does; [the contents (null when none came), the handler to disconnect].
func _open_store(id: int) -> Array:
	var out: Array = [null, null]
	var got := func(box: int, bytes: PackedByteArray) -> void:
		if box == id:
			var inv = InventoryScript.new(c.items.table)
			inv.from_bytes(bytes)
			out[0] = inv
	out[1] = got
	c.net.chest_received.connect(got)
	c.net.inventory_action.rpc_id(1, NetScript.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
	await r._wait(1.5)

	if out[0] == null:
		c.net.chest_received.disconnect(got)

	return out


# Takes every stack of `item` out of an open store; how many came into the pack.
func _take_all(id: int, store: Array, item: String) -> int:
	var before: int = _count(item)
	var number: int = c.items.table.number_of(item)

	for n in range(4):
		var slot: int = store[0].numbers.find(number)

		if slot < 0:
			break

		c.net.inventory_action.rpc_id(1, NetScript.ACT_CHEST_TAKE, slot, id, int(store[0].counts[slot]), Vector3.ZERO)
		await r._wait(1.0)

	return _count(item) - before


func _store_count(inv, items: Array) -> int:
	var n: int = 0

	for slot in range(inv.numbers.size()):
		var id: String = c.items.table.id_of(int(inv.numbers[slot])) if int(inv.numbers[slot]) > 0 else ""

		if id in items or id.begins_with("log_"):
			n += int(inv.counts[slot])

	return n


# The pack slot of any log (log or log_<species>), -1 when none.
func _log_slot() -> int:
	var inv = c.items.inventory

	for slot in range(inv.numbers.size()):
		var id: String = c.items.table.id_of(int(inv.numbers[slot])) if int(inv.numbers[slot]) > 0 else ""

		if id == "log" or id.begins_with("log_"):
			return slot

	return -1


# --- clay, as the goal's hint says: the Wooden - Shovel in Dig mode, left clicks at the ground. Loam, forest humus, silt and alluvium
# lie on clay (digging.json under: a 70 to 90% chance a dig of 2 to 3), clay ground gives it every dig, sand and rock never. A dig is a bowl
# about 1.7 m across and 1.15 m deep (server_items.gd DIG_RADIUS_M, DIG_DEPTH_M) and the shovel reaches 3 m from the eye (held_item.gd
# REACH_M), so a player digs once where they stand, 1.8 m ahead, then steps 1.8 m sideways: the holes lie side by side and the robot
# never stands in one. Lines go out from the camp a different way each time, further out, when the ground gives no clay.
func _dig_clay(want: int) -> String:
	var why: String = await _tool("wooden_shovel")

	if why != "":
		return why

	if _hold("wooden_shovel") < 0:
		return "no shovel to hold"

	await r._wait(0.6)

	if c.held.raise_mode:   # right click switches Raise and Dig (held_item.gd); the robot wants Dig
		c.held.mouse_button(MOUSE_BUTTON_RIGHT, true)
		await r._wait(0.1)
		c.held.mouse_button(MOUSE_BUTTON_RIGHT, false)
		await r._wait(0.4)

	var said: int = r._notices.size()
	var start_clay: int = _count("clay")
	var start_ground: int = _dug_count()
	var clicks: int = 0
	var dug: int = 0
	var line: int = 0
	var until: int = mini(Time.get_ticks_msec() + int(CLAY_S * 1000.0), _end_ms)
	var stood: Array = []   # where the robot stood for each dig: never twice on one spot (26 Nov run: the side steps failed, 28 digs went into one
	                        # hole beside the camp and the robot slid 5 m down into it, and every goal after it was "out of reach")

	while _count("clay") - start_clay < want and Time.get_ticks_msec() < until and line < 8:
		line += 1
		var dir: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, float(line) * 2.3)
		var side: Vector3 = dir.rotated(Vector3.UP, PI * 0.5)
		var from: Vector3 = _home + dir * (12.0 + 25.0 * float(line - 1))

		if not await r._go_to(from, minf(90.0, float(until - Time.get_ticks_msec()) / 1000.0), 3.0):
			await _climb_out()
			_line("CLAY line %d: could not walk to its start %s (stood at %s), the next line" % [line, str(from.round()), str(c.body.global_position.round())])
			continue

		var got_here: int = _count("clay")
		var tries: int = 0
		var dug_here: int = 0

		while tries < 10 and _count("clay") - start_clay < want and Time.get_ticks_msec() < until:
			if tries > 0:   # a short walk sideways (r._go_to walks in 1 s steps of 3.2 m and rocked about a 1.8 m step: the 26 Nov runs)
				await r._walk_for(side, 0.7)

			if _stood_near(stood, c.body.global_position) or _in_hole():
				break   # the side step did not take it off the last spot, or it stands in a hollow: this line is done

			stood.append(c.body.global_position)
			var had: int = _dug_count()

			# A click that brought nothing in (the ray met a bush or grass, or the ground fell away out of the 3 m reach) is aimed again
			# closer and steeper, once; the pack is watched up to 2 s for the server's answer.
			for ahead in [1.8, 1.4]:   # 1.4 keeps the rim of the bowl 0.5 m off the robot
				var ground: Vector3 = c.body.global_position + dir * ahead
				var y: float = float(c.items._ground_below.call(ground))
				ground.y = y if not is_nan(y) else c.body.global_position.y - 0.9
				_look_at(ground)
				await r._wait(0.3)
				c.held.mouse_button(MOUSE_BUTTON_LEFT, true)
				await r._wait(0.1)
				c.held.mouse_button(MOUSE_BUTTON_LEFT, false)
				clicks += 1
				var waited: float = 0.0

				while waited < 2.0 and _dug_count() <= had:
					await r._wait(0.25)
					waited += 0.25

				if _dug_count() > had:
					break

				await r._wait(maxf(0.0, 0.8 - waited))   # the server's dig pace is 0.7 s

			tries += 1
			dug_here += 1 if _dug_count() > had else 0

			# Sand, gravel or rock under the spade eight digs running and no clay: this ground has none, try another way out (on loam, with
			# a 35% chance a dig, four dry digs in a row happen one time in five; eight, one time in thirty).
			if dug_here >= 8 and _count("clay") == got_here:
				break

		dug += dug_here
		_line("CLAY line %d at %s, %.0f m from camp: %d digs tried, %d gave ground, +%d clay here" % [line, str(c.body.global_position.round()), _flat(_home),
			tries, dug_here, _count("clay") - got_here])

	await _climb_out()
	var got: int = _count("clay") - start_clay
	_line("CLAY %d clicks on %d lines, %d gave ground: +%d clay (wanted %d), +%d ground items in all, goal has %s%s" % [clicks, line, dug, got, want,
		_dug_count() - start_ground, str(c.items.goal_book.row("dig_clay").get("have", "?")), _said(said)])
	return "" if got >= want or bool(c.items.goal_book.row("dig_clay").get("done", false)) else "%d shovel clicks on %d lines, %d gave ground: %d of %d clay%s" % [clicks, line, dug, got, want, _said(said)]


func _stood_near(stood: Array, at: Vector3) -> bool:
	for p in stood:
		if Vector2(p.x - at.x, p.z - at.z).length() < 1.2:
			return true

	return false


# The ground under the feet lies more than 0.8 m below the ground 3 m round on most sides: the robot is down in a dug hollow.
func _in_hole() -> bool:
	var me: Vector3 = c.body.global_position
	var feet: float = float(c.items._ground_below.call(me))

	if is_nan(feet):
		return false

	var higher: int = 0

	for k in range(8):
		var y: float = float(c.items._ground_below.call(me + Vector3.FORWARD.rotated(Vector3.UP, TAU * float(k) / 8.0) * 3.0))
		higher += 1 if not is_nan(y) and y > feet + 0.8 else 0

	return higher >= 5


# Out of a hollow as a player gets out: walk at its lowest side toward the camp and jump (a jump lifts about 2.5 m), up to 20 s.
func _climb_out() -> void:
	var until: int = Time.get_ticks_msec() + 20000

	while _in_hole() and Time.get_ticks_msec() < until:
		var me: Vector3 = c.body.global_position
		var best: Vector3 = (_home - me) * Vector3(1.0, 0.0, 1.0)
		var low: float = INF

		for k in range(8):
			var way: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, TAU * float(k) / 8.0)
			var y: float = float(c.items._ground_below.call(me + way * 3.0))

			if not is_nan(y) and y < low:
				low = y
				best = way

		r._face(best.normalized())
		r._key("move_forward", true)
		r._key("jump", true)
		await r._wait(0.6)
		r._key("jump", false)
		await r._wait(0.6)

	r._release_all()

	if _in_hole():
		_line("CLAY still down in a hollow at %s after 20 s of climbing" % str(c.body.global_position.round()))


# What a dig gives (digging.json yield and under), summed: a click that raised it dug.
func _dug_count() -> int:
	var n: int = 0

	for item in ["soil", "sand", "gravel", "clay", "stone", "sea_salt", "crystal_lens"]:
		n += _count(item)

	return n


# --- a blueprint with the hammer: placed on open ground ahead, then hammered until it stands --------------------------------------
func _build(structure: String) -> String:
	var bp: Dictionary = _blueprints.get(structure, {})

	if bp.is_empty():
		return "robot cannot build %s: no hand blueprint for it" % structure

	for cost in bp.get("cost", []):
		var why: String = await _have(str(cost[0]), int(cost[1]), false)

		if why != "":
			return "materials for %s: %s" % [structure, why]

	var why2: String = await _tool("stone_hammer")

	if why2 != "":
		return why2

	var hammer: int = _hold("stone_hammer")

	if not c.items._world.has(int(_sites.get(structure, -1))):
		await _walk_home(240.0)   # a player builds at the camp, not at the shore where the last gather ended ("The ground is too wet here.")

	var known: Dictionary = c.items._world.duplicate()
	var said: int = r._notices.size()
	var at: Vector3 = Vector3.ZERO
	var site: int = int(_sites.get(structure, -1)) if c.items._world.has(int(_sites.get(structure, -1))) else -1   # a site placed on an earlier try

	var fire: int = -1

	if site < 0 and structure == "campfire_pot" and _fire_at.is_finite():   # the pot hangs over a small fire: placed on its own (server _snap_to_fire)
		await r._go_to(_fire_at, 60.0 + _flat(_fire_at) / 2.5, 2.0)
		fire = _camp_fire()

	if site < 0 and structure == "campfire_pot" and _fire_at.is_finite() and fire < 0:
		return "no fire of its own within 40 m of where it lit it (%s) to hang the pot over%s" % [str(_fire_at.round()), _said(said)]

	if site >= 0:
		at = c.items._world[site]["pos"]
	elif fire >= 0:
		at = c.items._world[fire]["pos"]
		c.net.inventory_action.rpc_id(1, NetScript.ACT_PLACE_BLUEPRINT, int(bp["number"]), 0, 0, at)
		await r._wait(3.0)

		for w in c.items._world:
			if not known.has(w) and Vector2(c.items._world[w]["pos"].x - at.x, c.items._world[w]["pos"].z - at.z).length() < 2.5:
				site = int(w)

		_sites[structure] = site
	else:
		for side in range(12):   # a player turns to open ground when the game says a tree is in the way
			var heard: int = r._notices.size()
			var out: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, float(side) * PI * 0.5 + 0.4)
			var far: float = 8.0 * float(side >= 4) + 10.0 * float(side >= 8)

			if far > 0.0:   # farther out: walk there first, since a blueprint is placed only within reach
				await r._go_to(_home + out * far, 30.0, 2.0)

			at = c.body.global_position + out * 4.0
			var y: float = float(c.items._ground_below.call(at))
			at.y = y if not is_nan(y) else c.body.global_position.y - 0.9
			c.net.inventory_action.rpc_id(1, NetScript.ACT_PLACE_BLUEPRINT, int(bp["number"]), 0, 0, at)
			await r._wait(3.0)

			for w in c.items._world:
				if not known.has(w) and Vector2(c.items._world[w]["pos"].x - at.x, c.items._world[w]["pos"].z - at.z).length() < 2.5:
					site = int(w)

			var told: String = str(r._notices.slice(heard))

			if site >= 0 or not (told.contains("in the way") or told.contains("build away") or told.contains("too wet") or told.contains("in water") or told.contains("stands there") or told.contains("above or below")):
				break

		_sites[structure] = site

	if site < 0:
		return ("placed the campfire pot blueprint on its own fire; no site came%s" if fire >= 0 else "placed the %s blueprint on open ground round the robot; no site came%s") % ([_said(said)] if fire >= 0 else [structure, _said(said)])

	await r._go_to(at, 10.0, 1.5)

	for n in range(12):
		c.net.inventory_action.rpc_id(1, NetScript.ACT_REPAIR_STRUCT, site, hammer + 1, 0, Vector3.ZERO)
		await r._wait(0.8)

	_line("BUILT %s site %d at %s, drawn %s%s" % [structure, site, str(at.round()), str(c.items._world.get(site, {}).get("state", "gone")), _said(said)])
	return ""


# --- Hob: sell him something from the pack -------------------------------------------------------------------------------------------
func _sell() -> String:
	var hob: Vector3 = Vector3.INF
	var short: String = await _gather("plant_fibre", 50)   # Hob buys fibre in lots of 50 (server_trade.gd: "He buys plant fibres 50 at a time.")

	if short != "" and _count("stone") < 60 and _count("twine") <= 0:
		return "nothing to sell in a lot Hob buys: %s" % short
	var leg_s: float = await _walk_home(480.0)   # the starter camp, where Hob trades (NPCs are sent within 120 m)

	await r._wait(3.0)
	_line("HOME %.0f m from the start spot after %.0f s of walking, pack %s" % [c.body.global_position.distance_to(_home), leg_s, _pack()])

	var seen: Array = c._npc_view.within(c.body.global_position, 3000.0) if c._npc_view != null else []

	for npc in seen:
		if str(npc["id"]).to_lower().contains("hob") or str(npc["name"]).to_lower().contains("hob"):
			hob = npc["pos"]

	if hob == Vector3.INF:
		return "Hob is not drawn anywhere on the client at the starter camp (people drawn: %s)" % str(seen.map(func(n): return "%s %s" % [str(n["id"]), str(n["name"])]))

	await r._go_to(hob, 180.0, 2.5)
	var said: int = r._notices.size()

	for item in ["plant_fibre", "stone", "twine", "stick"]:
		if _count(item) > 0 and not bool(c.items.goal_book.row("sell").get("done", false)):
			c.net.trade.rpc_id(1, "hob", 1, r._slot_of(item), _count(item))
			await r._wait(2.0)

	var was_open: bool = c.items.dialogue_open   # a sale sends the shop back and the client opens its window, which holds the walk
	_close_windows()
	_line("SOLD to Hob (shop window opened %s, closed)%s" % [str(was_open), _said(said)])
	return ""
