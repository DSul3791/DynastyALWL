extends RefCounted

# The server's items: every player's inventory and the things lying on the ground.
# The server owns all of it; clients only ask (terrain_net.gd inventory_action) and the
# server checks every request. Saved to inventories.json and world_items.json in the
# store folder: a "version" field, written to a temp file then renamed, and a file that
# cannot be read is kept as .bad and replaced by an empty one.
#
# Until accounts exist an inventory is filed under the key the client made for itself.

const ItemTableScript := preload("res://src/shared/item_table.gd")
const RecipeTableScript := preload("res://src/shared/recipe_table.gd")
const LuckScript := preload("res://src/shared/luck.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const CoverScript := preload("res://src/shared/cover.gd")
const SwimRules := preload("res://src/shared/swim.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const VERSION := 1
const INVENTORY_VERSION := 2            # 2 added wear per slot; version 1 files load with zero wear
const MAX_WORLD_ITEMS_PER_CHUNK := 64    # chunks are 256 m
const WORLD_ITEM_LIFETIME_S := 1200.0    # real seconds until a dropped item despawns
const CHUNK_M := 256.0
const NEAR_M := 100.0                    # items this close are sent to a player
const PICKUP_M := 3.0
const DROP_REACH_M := 6.0                # a drop lands at most this far from where the server last saw the player
const SYNC_EVERY_S := 1.0
const SAVE_EVERY_S := 30.0
const DROPS_PATH := "res://data/items/drops.json"
const REGROW_GAME_S := 3.0 * 86400.0     # a picked plant bears again after 3 game days
const GATHER_M := 5.0                    # how far from the plant a gather request may come
const SCATTER_RADIUS_M := 96.0           # loose stones and sticks are laid out this far around players
const SCATTER_DROP_M := 250.0            # and taken away again beyond this (picked-up ones stay gone)
const SCATTER_CELLS_PER_TICK := 8
const THROW_SPEED := 24.0                # m/s
const THROW_GRAVITY := 9.8
const THROW_MAX_S := 6.0
const THROW_COOLDOWN_MS := 500
const EYE_HEIGHT := 1.5
const HIT_REACH_M := 3.5                 # from the trunk's edge
const HIT_COOLDOWN_MS := 400
const CHOP_RESET_MS := 60000             # a half-chopped tree heals after this long untouched
const TRUNKS_PER_CHUNK := 32             # felled trunks (and as many stumps) lying in one flora chunk
const ROT_GAME_S := 168.0 * 86400.0      # a trunk or stump rots away after a real week (168 game days)
const TREE_SAVE_VERSION := 1
const SAPLING_YOUNG_S := 3.0 * 86400.0   # game seconds until a sapling is a young tree
const SAPLING_GROWN_S := 12.0 * 86400.0  # ...and until it is a full grown tree (can be felled)
const SAPLINGS_PER_CHUNK := 64
const RESPAWN_RADIUS_M := 25.0           # a sapling comes only near a standing tree of the same species
const RESPAWN_PLACE_M := 6.0
const RESPAWN_CHANCE := 0.5              # per rotted-away stump, rolled once from the seed and the spot
const FLORA_CHUNK_M := 256.0
const PROCESS_REACH_M := 4.0
const PROCESS_COOLDOWN_MS := 450
const FIRE_USE_M := 3.5
const COOKING_PATH := "res://data/items/cooking.json"
const GatherRules := preload("res://src/shared/gather_rules.gd")
const GATHER_PACE_MS := 80              # at most about 12 picks a second per player (hold-E sweep)
const MINE_REACH_M := 4.5
const MINE_COOLDOWN_MS := 700
const DIG_REACH_M := 4.5
const DIG_COOLDOWN_MS := 700
const DIG_RADIUS_M := 0.9
const DIG_DEPTH_M := 0.25      # the hole is centred this far below the point struck
const MINE_CELL_M := 8.0                 # one outcrop patch
const MINE_STONES_PER_CELL := 6          # stones a patch gives before it is spent...
const MINE_REGROW_S := 300.0             # ...and one comes back this often (real seconds)
const PLACE_REACH_M := 6.0
const STRUCTURES_PATH := "res://data/items/structures.json"
const SKILLS_PATH := "res://data/items/skills.json"
const FIRE_BURN_S := 100.0               # real seconds a fresh campfire burns (20 sticks, cooking.json start_burn_game_s)
const FIRE_LAID_S := 1800.0             # a laid fire (empty 8, or loaded and unlit 9) waits this long for the player
const FIRE_OUT_S := 300.0                # a burnt-out or rained-out fire stays this long
const FIRE_MIN_GAP_M := 2.0               # fallbacks: structures.json "campfire" decides
const FIRES_PER_CHUNK := 8
const RAIN_PUTS_OUT := 0.2               # open fires go out when the rain is at least this strong
const COVER_RECHECK_S := 30.0

var table
var recipes
# Set by the server scene: how to talk to one peer.
var send_full: Callable        # (peer, bytes)
var send_slots: Callable       # (peer, bytes)
var send_world_items: Callable # (peer, added Array, removed PackedInt32Array)
var ground_height: Callable    # (x, z) -> ground height in metres, or NAN; set by the server scene
var world_seed: int = 0
var rain_now: Callable         # () -> rain strength 0 to 1 over the world now; set by the server scene
var send_notice: Callable      # (peer, text)
var standing_near: Callable    # (species name, position, radius) -> [position] of the nearest standing tree of that species, or []
var flora_changed: Callable    # (chunk Vector2i) -> a chunk's saplings or trees changed: refresh the server cache and the clients near it
var tree_info: Callable        # (chunk Vector2i, id) -> {name, position, height, trunk} of a standing tree, or {}
var cut_tree: Callable         # (chunk Vector2i, id) -> true when the standing tree was removed (and clients told)
var fill_ground: Callable        # (centre, radius, material) -> bool: add ground (a fill) and tell everyone; false when it changed nothing
var dig_ground: Callable         # (centre, radius) -> void: cut a hole in the ground and tell everyone; set by the server scene
var trees_near: Callable        # (point, radius) -> Array of [chunk Vector2i, id int]: standing placer trees whose root is that close; set by the server scene
var dig_support: Callable       # (base, radius, depth) -> share 0..1 of the ground under a tree not dug away; set by the server scene
var ground_material: Callable   # (x, z) -> the surface material's name there ("loam", "clay", "sand", ... or "rock"); set by the server scene, feeds dig yields
var rock_at: Callable          # (x, z) -> true when bare rock shows at the surface there (no soil cover); set by the server scene
var game_seconds: Callable      # () -> game clock seconds
var season_now: Callable        # () -> "spring" | "summer" | "autumn" | "winter"
var skill_level: Callable         # (peer, skill id) -> level factor around 1.0; unset until the skill system exists, then every factor is 1.0
var _skills_cfg: Dictionary = {}
var send_reject: Callable        # (peer, reason 0 too far, 1 no tool, 2 pack full, 3 other)
var send_craft_queue: Callable   # (peer, [[recipe, crafts left], ...], ms left on the first)
var send_strain: Callable       # (peer, strain in thousandths, state 0 normal 1 over 2 fainted 3 waking, fade in thousandths, stance)
var send_breath: Callable       # (peer, seconds of air left in tenths, or -1 when the head is above water)
var send_vitals: Callable       # (peer, hunger percent, health, weight in tenths of a kg, thirst percent, luck, fitness)
var water_near: Callable         # (position, reach in metres) -> true when water lies within reach of the position; set by the server scene (unset: no water anywhere)
var send_chest: Callable        # (peer, world id, bytes) a chest's contents to the player who opened it
var roof_add: Callable          # (roof Array from Cover.box_roof) -> key; the server's cover index gets the lean-to's roof
var roof_remove: Callable       # (key)
var cover_at: Callable         # (position) -> 0.0 open or 1.0 under a tree's crown (Cover.at, or its stand-in)

var _dir: String = ""
var _inventories: Dictionary = {}   # key String -> Inventory
var _peer_key: Dictionary = {}      # peer -> key
var _head_under: Dictionary = {}    # peer -> true while the server reads their head as under water
var _breath: Dictionary = {}        # peer -> seconds of air left (only while the head is under water)
var _breath_sent: Dictionary = {}   # peer -> tenths of a second last sent (-1 = hidden)
var _speed3: Dictionary = {}        # peer -> smoothed speed in m/s, vertical included (the breath drain)
var _swimming: Dictionary = {}      # peer -> true while the server reads them as swimming
var _peer_pos: Dictionary = {}      # peer -> Vector3 last reported
var _items: Dictionary = {}         # id int -> {number, count, pos Vector3, left float}
var _next_id: int = 1
var _known: Dictionary = {}         # peer -> {id: true} world items the peer was told about
var _sync_in: float = 0.0
var _save_in: float = SAVE_EVERY_S
var _dirty: bool = false
var _drops: Dictionary = {}
var _cooking: Dictionary = {}
var _structures: Dictionary = {}    # structures.json: kind -> definition
var _struct_gap_m: float = 2.5
var _fire_gap_m: float = FIRE_MIN_GAP_M
var _fires_per_chunk: int = FIRES_PER_CHUNK
var _chests: Dictionary = {}        # structure uid -> Inventory (server-owned contents, chests.json)
var _next_uid: int = 1
var _vitals_cfg: Dictionary = {}
var _carry_cfg: Dictionary = {}
var _exertion_cfg: Dictionary = {}
var _strain: Dictionary = {}        # peer -> {s: strain, state: 0..3, t: seconds in the state}
var _strain_sent: Dictionary = {}
var _last_fall: Dictionary = {}       # peer -> msec of its last accepted fall report
var _craft_queues: Dictionary = {}    # player key -> {entries: [[recipe, crafts left], ...], elapsed: seconds on the first}
const QUEUE_ACT_GAP_MS := 100          # queue and cancel requests closer together than this from one player are ignored
var _last_queue_act: Dictionary = {}   # peer -> msec of its last accepted queue or cancel request
const CRAFT_QUEUE_ENTRIES := 10
const CRAFT_QUEUE_MAX_COUNT := 20
var _stance: Dictionary = {}        # peer -> 0 stand, 1 crouch, 2 sit, 3 lie
var _moving: Dictionary = {}        # peer -> smoothed 0..1, 1 while walking about
var _characters: Dictionary = {}   # player key -> {luck: int}, rolled once at first sight and never changed (job 77)
var _luck_cfg: Dictionary = {}
var _fitness_cfg: Dictionary = {}
var send_energy: Callable       # (peer, energy percent 0..100)
var _energy_cfg: Dictionary = {}    # data/items/energy.json
var _death_cfg: Dictionary = {}     # data/items/death.json
var _spoil_in: float = 0.0          # real seconds since the last spoilage step
var _spoil_acc: Dictionary = {}     # place class -> unspent fraction of an age unit
var respawn_point: Vector3 = Vector3.ZERO   # where a dead character comes back; set by the server scene
var send_died: Callable             # (peer, cause String, respawn point Vector3)
var unix_now: Callable              # () -> real unix seconds (tests stand in a clock); unset: the system clock
var _death_cause: Dictionary = {}   # peer -> what is draining health to zero (drowning, ...)
var _remains_check_in: float = 0.0
var _energy_sent: Dictionary = {}
var _sleep_cfg: Dictionary = {}     # data/items/sleep.json
var _asleep: Dictionary = {}        # peer -> true while asleep (a lying player who held Z); {rested: seconds with no strain}
var _dig_cfg: Dictionary = {}       # data/items/digging.json
var _boulder_cfg: Dictionary = {}    # data/items/boulders.json
var _boulder_left: Dictionary = {}   # boulder key -> rough stones still in it (absent = untouched), saved in world_items.json
const BOULDER_KEY := 1 << 50
const BOULDER_STATE := 10            # world-item row state of a boulder          # boulder keys live apart from the loose stones' keys
var _fate_rng: RandomNumberGenerator = RandomNumberGenerator.new()   # luck-exempt: the server's own fate stream, the fate() hook below
var fate_counts: Dictionary = {}    # fate kind -> times rolled (what luck has touched)
var _vitals: Dictionary = {}        # player key -> {hunger, health} floats
var _vitals_sent: Dictionary = {}   # peer -> [hunger, health] last whole points sent
var _exertion: Dictionary = {}      # peer -> smoothed 0..1 from movement
var _motion: Dictionary = {}        # peer -> [last position, msec]
var _work_until: Dictionary = {}    # peer -> msec until which tool work counts as effort
var _last_eat: Dictionary = {}      # peer -> msec
var _last_drink: Dictionary = {}    # peer -> msec of the last mouthful at the water
var _unfit: Dictionary = {}         # item id -> true: yields of poisonous plants never feed anyone
var _last_use: Dictionary = {}      # peer -> msec of the last structure use
const CHEST_REACH_M := 4.0
const VitalsRules := preload("res://src/shared/vitals_rules.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
const GAME_RATE := 24.0                 # game seconds per real second
var _slow_in: float = 0.0
const SLOW_TICK_S := 0.25
var gather_pace_ms: int = GATHER_PACE_MS
var _last_gather: Dictionary = {}   # peer -> msec
var _last_cook: Dictionary = {}     # peer -> msec
var _flora_by_name: Dictionary = {}   # flora table rows by species name (yields, seasons)
var _picked: Dictionary = {}          # "cx,cz,id" -> game seconds when last picked
var _flights: Array = []            # thrown things in the air: {number, pos, vel, age}
var _last_throw: Dictionary = {}    # peer -> msec
var _last_dig: Dictionary = {}
var _last_mine: Dictionary = {}     # peer -> msec
var _last_hit: Dictionary = {}      # peer -> msec
var _last_process: Dictionary = {}  # peer -> msec
var _chops: Dictionary = {}         # "cx,cz,id" -> {hits, msec}
var _rot_in: float = 60.0
var rot_scanned: int = 0              # felled records looked at in the last rot pass (the work done; the catch-up test reads it)
var rot_removed: int = 0              # and how many rotted away in it
var _saplings: Array = []           # {slot, chunk [cx, cz], species (flora id), pos, planted_at}
var _flora_by_id: Dictionary = {}
var _mined: Dictionary = {}         # Vector2i patch -> {taken, since msec}
var _taken: Dictionary = {}         # scatter key int -> true: loose items already picked up (stay gone)
var _cells_done: Dictionary = {}    # Vector2i scatter cell -> true while its items are laid out


func setup(item_table, store_dir: String) -> void:
	table = item_table
	recipes = RecipeTableScript.load_default(item_table)
	_dir = store_dir
	var structures: Variant = JSON.parse_string(FileAccess.get_file_as_string(STRUCTURES_PATH))

	if typeof(structures) == TYPE_DICTIONARY:
		_structures = structures.get("structures", {})
		_struct_gap_m = float(structures.get("gap_m", 2.5))
		_fire_gap_m = float(structures.get("campfire", {}).get("gap_m", FIRE_MIN_GAP_M))
		_fires_per_chunk = int(structures.get("campfire", {}).get("cap_per_chunk", FIRES_PER_CHUNK))

	var skills_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SKILLS_PATH))
	_skills_cfg = skills_parsed if typeof(skills_parsed) == TYPE_DICTIONARY else {}
	_vitals_cfg = VitalsRules.load_config()
	_luck_cfg = LuckScript.load_config()
	_fitness_cfg = _load_fitness_config()
	var energy_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/energy.json"))
	_energy_cfg = energy_parsed if typeof(energy_parsed) == TYPE_DICTIONARY else {}
	var death_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/death.json"))
	_death_cfg = death_parsed if typeof(death_parsed) == TYPE_DICTIONARY else {}
	var sleep_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/sleep.json"))
	_sleep_cfg = sleep_parsed if typeof(sleep_parsed) == TYPE_DICTIONARY else {}
	var dig_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/digging.json"))
	_dig_cfg = dig_parsed if typeof(dig_parsed) == TYPE_DICTIONARY else {}
	var boulders_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/boulders.json"))
	_boulder_cfg = boulders_parsed if typeof(boulders_parsed) == TYPE_DICTIONARY else {}
	_carry_cfg = CarryRules.load_config()
	var exertion_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/exertion.json"))
	_exertion_cfg = exertion_parsed if typeof(exertion_parsed) == TYPE_DICTIONARY else {}
	_load_vitals()
	_load_characters()
	_load_craft_queues()
	_load_inventories()
	_load_chests()
	_load_world_items()
	_load_trees()
	var cooking: Variant = JSON.parse_string(FileAccess.get_file_as_string(COOKING_PATH))
	_cooking = cooking if typeof(cooking) == TYPE_DICTIONARY else {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DROPS_PATH))
	_drops = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	var flora_table: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/tables/flora.json"))

	if typeof(flora_table) == TYPE_DICTIONARY:
		for entry in flora_table["entries"]:
			_flora_by_name[str(entry["name"])] = entry
			_flora_by_id[int(entry["id"])] = entry

			if (entry.get("uses", []) as Array).has("poison"):
				for yield_id in entry.get("yields", []):
					_unfit[str(yield_id)] = true


func peer_connected_hello(peer: int, key: String) -> void:
	if not _valid_key(key):
		return

	_peer_key[peer] = key

	if not _inventories.has(key):
		_inventories[key] = InventoryScript.new(table)
		_dirty = true

	_known[peer] = {}
	send_full.call(peer, _inventories[key].to_bytes())

	if not _vitals.has(key):
		_vitals[key] = _new_vitals()
		_dirty = true

	if not _characters.has(key):
		_characters[key] = {"luck": _create_luck(), "fitness": _fitness_default(), "train": 0.0}
		_dirty = true

	_vitals_sent.erase(peer)
	_sync_vitals(peer, true)
	_sync_energy(peer, true)
	_sync_craft_queue(peer)


func peer_left(peer: int) -> void:
	_swimming.erase(peer)
	_head_under.erase(peer)
	_breath.erase(peer)
	_breath_sent.erase(peer)
	_speed3.erase(peer)
	_peer_key.erase(peer)
	_peer_pos.erase(peer)
	_known.erase(peer)
	_last_throw.erase(peer)
	_last_mine.erase(peer)
	_last_dig.erase(peer)
	_last_hit.erase(peer)
	_last_cook.erase(peer)
	_last_gather.erase(peer)
	_last_use.erase(peer)
	_last_eat.erase(peer)
	_last_drink.erase(peer)
	_exertion.erase(peer)
	_motion.erase(peer)
	_work_until.erase(peer)
	_vitals_sent.erase(peer)
	_strain.erase(peer)
	_strain_sent.erase(peer)
	_stance.erase(peer)
	_energy_sent.erase(peer)
	_asleep.erase(peer)
	_moving.erase(peer)
	_last_process.erase(peer)


func report_position(peer: int, position: Vector3) -> void:
	if _peer_key.has(peer):
		_peer_pos[peer] = position
		_note_motion(peer, position)


func inventory_of(peer: int):
	return _inventories.get(_peer_key.get(peer, ""), null)


# Puts items in a player's inventory. Whatever does not fit lies on the ground at their feet.
# Returns how many went into the inventory. For harvesting and crafting.
func give(peer: int, number: int, count: int) -> int:
	var inv = inventory_of(peer)

	if inv == null or number <= 0 or count <= 0 or table.id_of(number) == "":
		return 0

	var before: Array = _snapshot(inv)
	var fits: int = _fit(peer, inv, number, count)
	var left: int = inv.add(number, fits) + (count - fits)
	_send_changes(peer, inv, before)
	_dirty = true

	if left > 0:
		drop_in_world(number, left, _peer_pos.get(peer, Vector3.ZERO))

	return count - left


# Takes items out of a player's inventory (crafting). False and no change if they lack them.
func take(peer: int, number: int, count: int) -> bool:
	var inv = inventory_of(peer)

	if inv == null:
		return false

	var before: Array = _snapshot(inv)

	if not inv.remove(number, count):
		return false

	_send_changes(peer, inv, before)
	_dirty = true
	return true


# Puts a stack on the ground. False when the chunk is full.
func drop_in_world(number: int, count: int, position: Vector3, item_wear: int = 0) -> bool:
	if count <= 0 or number <= 0:
		return false

	var chunk: Vector2i = _chunk_of(position)
	var here: int = 0

	for id in _items:
		if not _items[id].has("scatter") and _chunk_of(_items[id]["pos"]) == chunk:
			here += 1

	if here >= MAX_WORLD_ITEMS_PER_CHUNK:
		return false

	_items[_next_id] = {"number": number, "count": count, "pos": position, "left": WORLD_ITEM_LIFETIME_S, "wear": item_wear}
	_next_id += 1
	_dirty = true
	return true


func action(peer: int, kind: int, a: int, b: int, count: int, at: Vector3) -> void:
	var inv = inventory_of(peer)

	if inv == null:
		return

	var before: Array = _snapshot(inv)

	if kind == Net.ACT_MOVE:
		inv.move(a, b)                 # move() ignores bad slots
	elif kind == Net.ACT_DROP:
		_drop(peer, inv, a, count, at)
	elif kind == Net.ACT_PICKUP:
		_pickup(peer, inv, a)
	elif kind == Net.ACT_HIT:
		_hit(peer, inv, a, Vector2i(b, count))
	elif kind == Net.ACT_CHEST_OPEN or kind == Net.ACT_CHEST_PUT or kind == Net.ACT_CHEST_TAKE:
		_chest_action(peer, inv, kind, a, b, count)
	elif kind == Net.ACT_USE_STRUCT:
		_use_struct(peer, inv, a)
	elif kind == Net.ACT_EAT:
		_eat(peer, inv, a)
	elif kind == Net.ACT_DRINK:
		_drink_water(peer, a, inv)
	elif kind == Net.ACT_REPAIR:
		_repair(peer, inv, a)
	elif kind == Net.ACT_FUEL:
		_fuel(peer, inv, a)
	elif kind == Net.ACT_STANCE:
		_set_stance(peer, a)
	elif kind == Net.ACT_SLEEP:
		_sleep(peer, a)
	elif kind == Net.ACT_LIGHT:
		_light(peer, inv, a)
	elif kind == Net.ACT_COOK:
		_cook(peer, inv, a)
	elif kind == Net.ACT_SPLIT:
		_split(inv, a, count)
	elif kind == Net.ACT_PROCESS:
		_process_trunk(peer, inv, a)
	elif kind == Net.ACT_MINE:
		_mine(peer, inv, at)
	elif kind == Net.ACT_DIG:
		_dig(peer, inv, at)
	elif kind == Net.ACT_FILL:
		_fill(peer, inv, at)
	elif kind == Net.ACT_PLACE:
		_place(peer, inv, a, at, count)
	elif kind == Net.ACT_THROW:
		_throw(peer, inv, a, at)
	elif kind == Net.ACT_CRAFT:
		recipes.craft(a, inv)
	elif kind == Net.ACT_FALL:
		_fall(peer, a)
	elif kind == Net.ACT_CRAFT_QUEUE or kind == Net.ACT_CRAFT_CANCEL:
		var now: int = Time.get_ticks_msec()

		if now - int(_last_queue_act.get(peer, -100000)) >= QUEUE_ACT_GAP_MS:
			_last_queue_act[peer] = now

			if kind == Net.ACT_CRAFT_QUEUE:
				_queue_craft(peer, inv, a, count)
			else:
				_cancel_craft(peer, a)
	elif kind == Net.ACT_ADMIN_GIVE:
		if table.id_of(a) != "":
			var left: int = inv.add(a, clampi(count, 1, 100))

			if left > 0:
				drop_in_world(a, left, _peer_pos.get(peer, Vector3.ZERO))

	_send_changes(peer, inv, before)
	_dirty = true


func tick(delta: float) -> void:
	_fly(delta)
	_slow_in += delta

	# Fires and item lifetimes only need about 4 looks a second (TD note 2026-10-20: 1.5 ms a frame at 1300 records).
	if _slow_in >= SLOW_TICK_S:
		var spent: float = _slow_in
		_slow_in = 0.0
		_rot(spent)
		_fires(spent)
		_vitals_tick(spent)
		_craft_tick(spent)
		_remains_tick(spent)
		_spoil_tick(spent)

		for id in _items.keys():
			if _items[id].has("scatter") or float(_items[id]["left"]) > 1.0e8:
				continue

			_items[id]["left"] -= spent

			if _items[id]["left"] <= 0.0:
				_items.erase(id)
				_dirty = true

	_sync_in -= delta

	if _sync_in <= 0.0:
		_sync_in = SYNC_EVERY_S
		_scatter_around_players()
		_sync_world_items()

	_save_in -= delta

	if _save_in <= 0.0:
		_save_in = SAVE_EVERY_S
		save()


func save() -> void:
	if _dir == "" or not _dirty:
		return

	_dirty = false
	var now_s: float = float(game_seconds.call()) if game_seconds.is_valid() else 0.0

	for key in _picked.keys():
		if now_s - float(_picked[key]) >= REGROW_GAME_S:
			_picked.erase(key)

	var invs: Dictionary = {}

	for key in _inventories:
		invs[key] = _inventories[key].to_json_array()

	_write_atomic("inventories.json", {"version": INVENTORY_VERSION, "inventories": invs})
	var items: Array = []

	for id in _items:
		var it: Dictionary = _items[id]

		if it.has("scatter") or it.has("tree"):
			continue

		if it.has("struct"):
			items.append([int(it["number"]), 1, it["pos"].x, it["pos"].y, it["pos"].z, 1.0e9, int(_structures.get(str(it["struct"]["kind"]), {}).get("state", 5)), float(it["struct"]["yaw"]), 0, str(it["struct"]["kind"]), int(it["struct"].get("uid", 0)), str(it["struct"].get("owner", "")), float(it["struct"].get("born", 0.0)), bool(it["struct"].get("cave", false))])
			continue

		items.append([int(it["number"]), int(it["count"]), it["pos"].x, it["pos"].y, it["pos"].z, it["left"], int(it["fire"]["state"]) if it.has("fire") else 0, float(it["fire"]["burn_left"]) if it.has("fire") else 0.0, int(it.get("wear", 0))])

	_save_trees()
	_save_chests()
	_save_vitals()
	_save_characters()
	_save_craft_queues()
	_write_atomic("world_items.json", {"version": VERSION, "next_id": _next_id, "items": items, "taken": _taken.keys(), "picked": _picked, "boulders": _boulder_left})


# Picking from a plant or shrub by hand. The plant stays where it is and is picked bare for
# REGROW_GAME_S of game time. It gives what drops.json says (fibre, sticks) and one of its
# natural yields (berries, leaves, roots...) when that is in season (flora table).
# Returns false when it gives nothing, the player is not near it, or it is not ready.
# True while a plant picked bare under the old regrow rule is still on the list (server_items keeps it for 3 game days).
func was_picked(flora_key: String) -> bool:
	var now_s: float = float(game_seconds.call()) if game_seconds.is_valid() else 0.0
	return now_s - float(_picked.get(flora_key, -1.0e12)) < REGROW_GAME_S


func gather(peer: int, species_name: String, kind: String, flora_key: String, flora_id: int, plant_position: Vector3) -> bool:
	if not _peer_pos.has(peer) or _peer_pos[peer].distance_to(plant_position) > GATHER_M:
		return false

	var tick: int = Time.get_ticks_msec()

	if tick - int(_last_gather.get(peer, -100000)) < gather_pace_ms:
		return false

	_last_gather[peer] = tick
	var now_s: float = float(game_seconds.call()) if game_seconds.is_valid() else 0.0

	if now_s - float(_picked.get(flora_key, -1.0e12)) < REGROW_GAME_S:
		return false

	var rows: Array = _drops.get("by_species", {}).get(species_name, _drops.get("by_kind", {}).get(kind, []))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(flora_id) ^ int(now_s / REGROW_GAME_S) ^ 0x5bd1e995
	var entry: Dictionary = _flora_by_name.get(species_name, {})
	var natural: String = ""

	if not entry.is_empty() and not entry["yields"].is_empty():
		var seasons: Array = entry["season"]
		var season: String = str(season_now.call()) if season_now.is_valid() else "all"

		if seasons.has("all") or seasons.has(season):
			var usable: Array = []
			var missing: String = ""
			var inv = inventory_of(peer)

			for candidate in entry["yields"]:
				var needed: String = _tool_for(str(candidate))

				if table.number_of(str(candidate)) == 0:
					continue

				if needed == "" or (inv != null and _has_tool(inv, needed)):
					usable.append(str(candidate))
				else:
					missing = needed

			if not usable.is_empty():
				natural = usable[rng.randi_range(0, usable.size() - 1)]   # luck-exempt: which yield a plant bears, none better or worse
				var used_class: String = _tool_for(natural)

				if used_class != "":
					_wear_tool(peer, inv, used_class, "gather")
			elif rows.is_empty() and missing != "":
				_say(peer, "You need a %s for that." % str(_drops.get("tool_rules", {}).get("tool_names", {}).get(missing, missing)))
				_reject(peer, 1)

	if rows.is_empty() and natural == "":
		return false

	var more: float = skill_factor(peer, "gather_plant")

	for row in rows:
		give(peer, table.number_of(str(row[0])), maxi(1, int(round(float(roll_amount(peer, rng, int(row[1]), int(row[2]))) * more))))

	if natural != "":
		give(peer, table.number_of(natural), maxi(1, int(round(float(roll_amount(peer, rng, 1, 3)) * more))))

	_picked[flora_key] = now_s
	_dirty = true
	return true


func _tool_for(item_id: String) -> String:
	return GatherRules.tool_for(item_id, _drops)


# What a skill does to an action (data/items/skills.json): 1.0 until the skill system exists. Never below 0.25 or above 4.
func skill_factor(peer: int, action: String) -> float:
	var def: Dictionary = _skills_cfg.get("actions", {}).get(action, {})

	if def.is_empty() or not skill_level.is_valid():
		return 1.0

	return clampf(float(skill_level.call(peer, str(def.get("skill", "")))), 0.25, 4.0)


func _reject(peer: int, reason: int) -> void:
	if send_reject.is_valid():
		send_reject.call(peer, reason)


func _say(peer: int, text: String) -> void:
	if send_notice.is_valid():
		send_notice.call(peer, text)


# How many felled trunks and stumps are on record (the persistence drills count them).
func tree_row_count() -> int:
	var n: int = 0

	for id in _items:
		if _items[id].has("tree"):
			n += 1

	return n


func world_item_count() -> int:
	return _items.size()


func _drop(peer: int, inv, slot: int, count: int, at: Vector3) -> void:
	if slot < 0 or slot >= inv.SLOTS or inv.numbers[slot] == 0 or count <= 0:
		return

	var here: Vector3 = _peer_pos.get(peer, at)
	var spot: Vector3 = at if at.distance_to(here) <= DROP_REACH_M else here
	var number: int = inv.numbers[slot]
	var amount: int = mini(count, inv.counts[slot])

	if not drop_in_world(number, amount, spot, inv.wear[slot]):
		return

	inv.take_from_slot(slot, amount)


# A thrown weapon leaves the inventory and flies; where it comes down it lies as a world item.
# Only items marked as weapons can be thrown. Nothing can be hit yet (no creatures).
func _throw(peer: int, inv, slot: int, direction: Vector3) -> void:
	if slot < 0 or slot >= inv.SLOTS or inv.numbers[slot] == 0 or not _peer_pos.has(peer) or direction.length() < 0.1:
		return

	var now: int = Time.get_ticks_msec()

	if now - int(_last_throw.get(peer, -100000)) < THROW_COOLDOWN_MS:
		return

	if str(table.entry(table.id_of(inv.numbers[slot])).get("kind", "")) != "weapon":
		return

	if _is_broken(inv.numbers[slot], inv.wear[slot]):
		return

	_last_throw[peer] = now
	var number: int = inv.numbers[slot]
	var spent: int = inv.wear[slot] + 1
	inv.take_from_slot(slot, 1)
	_flights.append({"number": number, "wear": spent, "pos": _peer_pos[peer] + Vector3(0.0, EYE_HEIGHT, 0.0), "vel": direction.normalized() * THROW_SPEED, "age": 0.0})


func _fly(delta: float) -> void:
	for flight in _flights.duplicate():
		flight["vel"].y -= THROW_GRAVITY * delta
		flight["pos"] += flight["vel"] * delta
		flight["age"] += delta
		var ground: float = float(ground_height.call(flight["pos"].x, flight["pos"].z)) if ground_height.is_valid() else -1000000.0

		if (not is_nan(ground) and flight["pos"].y <= ground) or flight["age"] >= THROW_MAX_S:
			var spot: Vector3 = flight["pos"]

			if not is_nan(ground):
				spot.y = maxf(ground, spot.y) if flight["age"] >= THROW_MAX_S else ground

			drop_in_world(int(flight["number"]), 1, spot, int(flight.get("wear", 0)))
			_flights.erase(flight)


# The stone axe used as a pick (Dave: no stone pickaxe): a blow on bare rock gives a stone. The
# server checks the axe, the reach, the pace and that rock really shows there, and each 8 m patch
# of outcrop gives only a few stones before it needs time to recover. No ground is dug.
# One spade dig (ACT_DIG): needs a whole spade in the pack and the point within reach; paced like mining.
func _dig(peer: int, inv, at: Vector3) -> void:
	if not _peer_pos.has(peer) or not dig_ground.is_valid():
		return

	if _peer_pos[peer].distance_to(at) > DIG_REACH_M:
		_reject(peer, 0)
		return

	if not _has_tool(inv, "spade"):
		_reject(peer, 1)
		return

	var now: int = Time.get_ticks_msec()

	if now - int(_last_dig.get(peer, -100000)) < DIG_COOLDOWN_MS:
		return

	_last_dig[peer] = now
	_wear_tool(peer, inv, "spade", "dig")
	var dug: Variant = dig_ground.call(at - Vector3(0.0, DIG_DEPTH_M, 0.0), DIG_RADIUS_M)

	# The ground answers false when the dig changed nothing (a block is full, or the hole was already there): no yield, no fall.
	if typeof(dug) == TYPE_BOOL and not bool(dug):
		return

	_give_dig_yield(peer, at, _spade_tier(inv))
	_fell_undermined(peer, at)
	_dirty = true


# One spade fill (ACT_FILL, saved edits step 3): a sphere of ground added at the point struck, using up one shovelful
# from the pack (digging.json "fill", soil first). Same reach, spade and pace as a dig; a fill that changes nothing
# hands the shovelful back.
const FILL_RADIUS_M := 0.9
const FILL_UP_M := 0.1         # the fill is centred this far above the point struck (it heaps a little)
const FILL_SOIL := {"soil": 5, "sand": 1, "gravel": 2, "clay": 4, "stone": 9}   # the ground material each fill item makes (data/tables/soils.json ids)


func _fill(peer: int, inv, at: Vector3) -> void:
	if not _peer_pos.has(peer) or not fill_ground.is_valid():
		return

	if _peer_pos[peer].distance_to(at) > DIG_REACH_M:
		_reject(peer, 0)
		return

	if not _has_tool(inv, "spade"):
		_reject(peer, 1)
		return

	var now: int = Time.get_ticks_msec()

	if now - int(_last_dig.get(peer, -100000)) < DIG_COOLDOWN_MS:
		return

	var material_item: String = ""

	for name in _dig_cfg.get("fill", []):
		var number: int = table.number_of(str(name))

		if number > 0 and inv.count_of(number) > 0:
			material_item = str(name)
			break

	if material_item == "":
		_say(peer, "Nothing to fill with: dig some soil, sand or gravel first")
		return

	_last_dig[peer] = now

	if take_fill_item(peer, material_item) < 1:
		return

	_wear_tool(peer, inv, "spade", "dig")
	var done: Variant = fill_ground.call(at + Vector3(0.0, FILL_UP_M, 0.0), FILL_RADIUS_M, int(FILL_SOIL.get(material_item, 5)))

	if typeof(done) == TYPE_BOOL and not bool(done):
		give(peer, table.number_of(material_item), 1)

	_dirty = true


# Takes one shovelful of the named fill item; returns 1 or 0.
func take_fill_item(peer: int, name: String) -> int:
	var inv = inventory_of(peer)
	var number: int = table.number_of(name)

	if inv == null or number <= 0 or inv.count_of(number) < 1:
		return 0

	var before: Array = _snapshot(inv)
	inv.remove(number, 1)
	_send_changes(peer, inv, before)
	return 1


# Dig under trees (job 85, drops.json "dig_fell"): every standing tree near the new hole whose support is now thin enough falls
# as a trunk, away from the hole. The axe is still needed to work the trunk.
func _fell_undermined(peer: int, at: Vector3) -> void:
	var cfg: Dictionary = _drops.get("dig_fell", {})

	if cfg.is_empty() or not trees_near.is_valid() or not dig_support.is_valid() or not tree_info.is_valid() or not cut_tree.is_valid():
		return

	for found in trees_near.call(at, float(cfg.get("search_m", 4.0))):
		var chunk: Vector2i = found[0]
		var info: Dictionary = tree_info.call(chunk, int(found[1]))

		if info.is_empty():
			continue

		var trunk: float = float(info["trunk"])
		var radius: float = float(cfg.get("support_r_per_trunk", 2.0)) * trunk + float(cfg.get("support_r_base", 1.0))
		var share: float = float(dig_support.call(info["position"], radius, float(cfg.get("depth_m", 1.0))))
		var limits: Dictionary = cfg.get("fall_below", {})
		var limit: float = float(limits.get("default", 0.35))

		for word in cfg.get("conifer_words", []):
			if str(info["name"]).contains(str(word)):
				limit = float(limits.get("conifer", 0.45))

		if trunk >= float(cfg.get("big_trunk_m", 0.55)):
			limit = minf(limit, float(limits.get("big", 0.25)))

		if share >= limit:
			continue

		if _trees_in_chunk(chunk) >= TRUNKS_PER_CHUNK:
			if send_notice.is_valid():
				send_notice.call(peer, "Too many felled trunks lie here. Clear some away first.")

			continue

		_fell(chunk, int(found[1]), info, Vector2(info["position"].x - at.x, info["position"].z - at.z))


# What a dig brings up (data/items/digging.json): shovelfuls by the surface material at the hole, through luck, counted by weight.
func _spade_tier(inv) -> int:
	var slot: int = _tool_slot(inv, "spade")
	return int(table.entry(table.id_of(inv.numbers[slot])).get("tier", 1)) if slot >= 0 else 1


func _give_dig_yield(peer: int, at: Vector3, tier: int = 1) -> void:
	if not ground_material.is_valid() or _dig_cfg.is_empty():
		return

	var material: String = str(ground_material.call(at.x, at.z))
	var rows: Array = _dig_cfg.get("yield", {}).get(material, _dig_cfg.get("default", []))

	for row in rows:
		var number: int = table.number_of(str(row[0]))
		var extra: int = int(_dig_cfg.get("tier_extra", {}).get(str(tier), 0)) if int(row[2]) > int(row[1]) or int(row[2]) > 0 else 0
		var amount: int = roll_amount(peer, _fate_rng, int(row[1]), int(row[2]) + extra)

		if number > 0 and amount > 0:
			give(peer, number, amount)

	var under: Array = _dig_cfg.get("under", {}).get(material, [])

	if under.size() == 2 and roll_chance(peer, _fate_rng, float(under[1])):
		var layer: int = table.number_of(str(under[0]))

		if layer > 0:
			give(peer, layer, 1)


# What filling a hole uses up (digging.json "fill", in that order): takes up to `units` shovelfuls from the pack, returns how many
# it got. The fill operation calls this and fills only as many units as it got. fill_units_of is the same count without taking.
func take_fill(peer: int, units: int) -> int:
	var inv = inventory_of(peer)

	if inv == null or units <= 0:
		return 0

	var before: Array = _snapshot(inv)
	var got: int = 0

	for name in _dig_cfg.get("fill", []):
		var number: int = table.number_of(str(name))
		var take: int = mini(units - got, inv.count_of(number)) if number > 0 else 0

		if take > 0 and inv.remove(number, take):
			got += take

		if got >= units:
			break

	if got > 0:
		_send_changes(peer, inv, before)
		_dirty = true

	return got


func fill_units_of(peer: int) -> int:
	var inv = inventory_of(peer)
	var total: int = 0

	if inv != null:
		for name in _dig_cfg.get("fill", []):
			var number: int = table.number_of(str(name))
			total += inv.count_of(number) if number > 0 else 0

	return total


func _mine(peer: int, inv, at: Vector3) -> void:
	if not _peer_pos.has(peer) or not rock_at.is_valid():
		return

	if _peer_pos[peer].distance_to(at) > MINE_REACH_M:
		_reject(peer, 0)
		return

	var has_axe: bool = _has_tool(inv, "axe")

	if not has_axe:
		_reject(peer, 1)

	var now: int = Time.get_ticks_msec()

	if not has_axe or float(now - int(_last_mine.get(peer, -100000))) < float(MINE_COOLDOWN_MS) / skill_factor(peer, "mine_rock") or not bool(rock_at.call(at.x, at.z)):
		return

	_last_mine[peer] = now
	_wear_tool(peer, inv, "axe", "rock")
	var patch: Vector2i = Vector2i(int(floor(at.x / MINE_CELL_M)), int(floor(at.z / MINE_CELL_M)))
	var state: Dictionary = _mined.get(patch, {"taken": 0, "since": now})
	var regrown: int = int((now - int(state["since"])) / (MINE_REGROW_S * 1000.0))
	state["taken"] = maxi(int(state["taken"]) - regrown, 0)

	if regrown > 0:
		state["since"] = now

	if int(state["taken"]) >= MINE_STONES_PER_CELL:
		_mined[patch] = state
		return

	state["taken"] = int(state["taken"]) + 1
	_mined[patch] = state
	var before: Array = _snapshot(inv)
	var left: int = inv.add(table.number_of("stone"), 1)

	if left > 0:
		drop_in_world(table.number_of("stone"), left, _peer_pos[peer])

	_send_changes(peer, inv, before)
	_dirty = true


# A placeable item (the campfire kit) becomes a fire on the ground in front of the player.
func _place(peer: int, inv, slot: int, at: Vector3, yaw_deg: int = 0) -> void:
	if slot < 0 or slot >= inv.SLOTS or inv.numbers[slot] == 0 or not _peer_pos.has(peer):
		return

	var number: int = inv.numbers[slot]

	var kit_id: String = table.id_of(number)

	if _peer_pos[peer].distance_to(at) > PLACE_REACH_M or (kit_id != "campfire_kit" and _structure_of_kit(kit_id).is_empty()):
		return

	var ground: float = float(ground_height.call(at.x, at.z)) if ground_height.is_valid() else at.y

	if is_nan(ground) or absf(ground - at.y) > 1.0 or ground < 1.0:
		return

	var spot: Vector3 = Vector3(at.x, ground, at.z)

	if kit_id != "campfire_kit":
		_place_structure(peer, inv, slot, spot, yaw_deg, _structure_of_kit(kit_id))
		return

	var chunk_fires: int = 0

	for id in _items:
		if _items[id].has("fire"):
			if _items[id]["pos"].distance_to(spot) < _fire_gap_m:
				return

			if _chunk_of(_items[id]["pos"]) == _chunk_of(spot):
				chunk_fires += 1
		elif _items[id].has("struct") and _items[id]["pos"].distance_to(spot) < _struct_gap_m:
			return

	if chunk_fires >= _fires_per_chunk:
		return

	inv.take_from_slot(slot, 1)
	var covered: bool = cover_at.is_valid() and float(cover_at.call(spot)) > 0.5
	_items[_next_id] = {"number": number, "count": 1, "pos": spot, "left": 1.0e9, "fire": {"state": 1, "burn_left": float(_cooking.get("start_burn_game_s", 2400.0)) / GAME_RATE, "covered": covered, "recheck": COVER_RECHECK_S}}
	_next_id += 1


# Fires burn down; open fires are put out by rain (Dave, 2026-10-20), covered ones are not.
func _fires(delta: float) -> void:
	var raining: bool = rain_now.is_valid() and float(rain_now.call()) >= RAIN_PUTS_OUT

	for id in _items.keys():
		var it: Dictionary = _items[id]

		if not it.has("fire"):
			continue

		var fire: Dictionary = it["fire"]

		if int(fire["state"]) != 1:
			continue

		fire["burn_left"] -= delta
		fire["recheck"] -= delta

		if fire["recheck"] <= 0.0:
			fire["recheck"] = COVER_RECHECK_S
			fire["covered"] = cover_at.is_valid() and float(cover_at.call(it["pos"])) > 0.5

		if fire["burn_left"] <= 0.0:
			fire["state"] = 8
			it["left"] = FIRE_OUT_S
			_dirty = true
		elif raining and not fire["covered"]:
			fire["state"] = 9
			it["left"] = FIRE_LAID_S
			_dirty = true


func _pickup(peer: int, inv, id: int) -> void:
	var it: Dictionary = _items.get(id, {})

	if it.has("struct"):
		_take_down(peer, inv, id)
		return

	if it.is_empty() or it.has("fire") or it.has("tree") or it.has("boulder") or not _peer_pos.has(peer):
		return

	if _peer_pos[peer].distance_to(it["pos"]) > PICKUP_M + 2.0:
		_reject(peer, 0)
		return

	var fits: int = _fit(peer, inv, int(it["number"]), int(it["count"]))

	if fits == 0:
		_say(peer, "Too heavy to carry any more")
		_reject(peer, 2)
		return

	var left: int = inv.add(int(it["number"]), fits, int(it.get("wear", 0))) + (int(it["count"]) - fits)

	if left == 0:
		if it.has("scatter"):
			_taken[it["scatter"]] = true

		_items.erase(id)
	else:
		it["count"] = left


func _sync_world_items() -> void:
	for peer in _known:
		if not _peer_pos.has(peer):
			continue

		var here: Vector3 = _peer_pos[peer]
		var known: Dictionary = _known[peer]
		var added: Array = []
		var removed: PackedInt32Array = PackedInt32Array()
		var near: Dictionary = {}

		for id in _items:
			var it: Dictionary = _items[id]

			if it["pos"].distance_to(here) <= NEAR_M:
				near[id] = true

				var state: int = int(it["fire"]["state"]) if it.has("fire") else (int(it["tree"]["state"]) if it.has("tree") else (_struct_state(it) if it.has("struct") else (BOULDER_STATE if it.has("boulder") else 0)))
				var signature: int = int(it["count"]) + 1000 * state + 100000 * int(it["number"])

				if not known.has(id) or known[id] != signature:
					added.append([id, int(it["number"]), int(it["count"]), it["pos"], state, it["tree"] if it.has("tree") else ({"yaw": float(it["struct"]["yaw"]), "age": _remains_age(it)} if it.has("struct") else (it["boulder"] if it.has("boulder") else {}))])
					known[id] = signature

		for id in known.keys():
			if not near.has(id):
				removed.append(id)
				known.erase(id)

		if not added.is_empty() or not removed.is_empty():
			send_world_items.call(peer, added, removed)


func _send_changes(peer: int, inv, before: Array) -> void:
	var out: PackedByteArray = PackedByteArray()

	for i in inv.SLOTS:
		if inv.numbers[i] != before[0][i] or inv.counts[i] != before[1][i] or inv.wear[i] != before[2][i]:
			var at: int = out.size()
			out.resize(at + 9)
			out[at] = i
			out.encode_u32(at + 1, inv.numbers[i])
			out.encode_u16(at + 5, inv.counts[i])
			out.encode_u16(at + 7, mini(inv.wear[i], 65535))

	if not out.is_empty():
		send_slots.call(peer, out)


func _snapshot(inv) -> Array:
	return [inv.numbers.duplicate(), inv.counts.duplicate(), inv.wear.duplicate()]


func _chunk_of(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / CHUNK_M)), int(floor(p.z / CHUNK_M)))


func _valid_key(key: String) -> bool:
	if key.length() < 8 or key.length() > 64:
		return false

	for ch in key:
		if not (ch >= "0" and ch <= "9") and not (ch >= "a" and ch <= "z") and not (ch >= "A" and ch <= "Z") and ch != "-" and ch != "_":
			return false

	return true


func _load_inventories() -> void:
	var parsed: Variant = _read_json_version("inventories.json", INVENTORY_VERSION, 1)

	if parsed == null:
		return

	for key in parsed["inventories"]:
		var inv = InventoryScript.new(table)
		inv.from_json_array(parsed["inventories"][key])
		_inventories[key] = inv


func _load_world_items() -> void:
	var parsed: Variant = _read_json("world_items.json")

	if parsed == null:
		return

	_next_id = int(parsed.get("next_id", 1))

	_picked = parsed.get("picked", {})

	for key in parsed.get("taken", []):
		_taken[int(key)] = true

	for key in parsed.get("boulders", {}):
		_boulder_left[int(key)] = int(parsed["boulders"][key])

	for row in parsed["items"]:
		var entry: Dictionary = {"number": int(row[0]), "count": int(row[1]), "pos": Vector3(row[2], row[3], row[4]), "left": float(row[5])}

		if row.size() > 9 and int(row[6]) >= 5:
			entry["struct"] = {"kind": str(row[9]), "yaw": float(row[7])}

			if row.size() > 10 and int(row[10]) > 0:
				entry["struct"]["uid"] = int(row[10])
				_next_uid = maxi(_next_uid, int(row[10]) + 1)

				if not _chests.has(int(row[10])):
					_chests[int(row[10])] = InventoryScript.new(table)

			if row.size() > 12 and str(row[9]) == "remains":
				entry["struct"]["owner"] = str(row[11])
				entry["struct"]["born"] = float(row[12])
				entry["struct"]["cave"] = row.size() > 13 and bool(row[13])

			_items[_next_id] = entry
			_next_id += 1
			continue

		if row.size() > 8:
			entry["wear"] = int(row[8])

		if row.size() > 7 and int(row[6]) != 0:
			var saved_state: int = int(row[6])

			if saved_state == 2:   # before protocol 19: an out fire is empty ashes, or loaded when it still has wood
				saved_state = 9 if float(row[7]) > 0.0 else 8

			entry["fire"] = {"state": saved_state, "burn_left": float(row[7]), "covered": false, "recheck": 0.0}

		_items[_next_id] = entry
		_next_id += 1


# The parsed dictionary, or null when there is no file or it cannot be used (then it is kept as .bad).
func _read_json(name: String) -> Variant:
	return _read_json_version(name, VERSION)


# Reads a save file. A file that does not parse (a torn write, a damaged disk) is set aside as .bad and the copy kept
# from the save before it (.prev, at most one save interval old) is used instead, so a corrupt file costs seconds,
# not the world. A file from another version is set aside as .bad and NOT replaced by the older copy.
func _read_json_version(name: String, version: int, oldest: int = -1) -> Variant:
	var path: String = _dir + "/" + name

	if not FileAccess.file_exists(path):
		return null

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

	if typeof(parsed) == TYPE_DICTIONARY and int(parsed.get("version", 0)) <= version and int(parsed.get("version", 0)) >= (version if oldest < 0 else oldest):
		return parsed

	push_error("server items: %s is not usable; kept as %s.bad" % [path, path])
	DirAccess.rename_absolute(path, path + ".bad")

	if typeof(parsed) == TYPE_DICTIONARY:
		return null

	if FileAccess.file_exists(path + ".prev"):
		var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + ".prev"))

		if typeof(previous) == TYPE_DICTIONARY and int(previous.get("version", 0)) <= version and int(previous.get("version", 0)) >= (version if oldest < 0 else oldest):
			push_error("server items: %s restored from the save before it" % path)
			DirAccess.copy_absolute(path + ".prev", path)
			return previous

	return null


# Writes a save file without ever leaving a half-written one: the new text goes to .tmp and is renamed over the old file,
# and the file it replaces is first copied to .prev (the fallback when a file later turns out torn or damaged).
func _write_atomic(name: String, data: Dictionary) -> void:
	var path: String = _dir + "/" + name
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)

	if file == null:
		push_error("server items: cannot write %s" % path)
		return

	file.store_string(JSON.stringify(data))
	file.close()

	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".prev")

	DirAccess.rename_absolute(path + ".tmp", path)


# Loose stones and fallen sticks lie about the ground (Dave, 2026-10-20: more stones near rock
# and on slopes). Laid out cell by cell around players from the world seed, so the same cell
# always has the same things; picked-up ones are remembered in _taken.
func _scatter_around_players() -> void:
	if not ground_height.is_valid():
		return

	var cfg: Dictionary = _drops.get("ground_scatter", {})
	var cell_m: float = float(cfg.get("cell_m", 32.0))
	var budget: int = SCATTER_CELLS_PER_TICK

	for peer in _peer_pos:
		var here: Vector3 = _peer_pos[peer]
		var reach: int = int(ceil(SCATTER_RADIUS_M / cell_m))
		var home: Vector2i = Vector2i(int(floor(here.x / cell_m)), int(floor(here.z / cell_m)))

		for dz in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var cell: Vector2i = home + Vector2i(dx, dz)

				if budget > 0 and not _cells_done.has(cell) and Vector2(dx, dz).length() * cell_m <= SCATTER_RADIUS_M:
					_cells_done[cell] = true
					_lay_out_cell(cell, cell_m, cfg)
					budget -= 1

	# Take away loose things far from every player (they come back when someone returns).
	for id in _items.keys():
		var it: Dictionary = _items[id]

		if not it.has("scatter"):
			continue

		var far: bool = true

		for peer in _peer_pos:
			if _peer_pos[peer].distance_to(it["pos"]) < SCATTER_DROP_M:
				far = false
				break

		if far:
			_cells_done.erase(Vector2i(int(floor(it["pos"].x / cell_m)), int(floor(it["pos"].z / cell_m))))
			_items.erase(id)


func _lay_out_cell(cell: Vector2i, cell_m: float, cfg: Dictionary) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(cell.x, cell.y, world_seed))
	var centre: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * cell_m
	var h0: float = float(ground_height.call(centre.x, centre.y))
	var h1: float = float(ground_height.call(centre.x + 4.0, centre.y))
	var h2: float = float(ground_height.call(centre.x, centre.y + 4.0))

	if is_nan(h0) or is_nan(h1) or is_nan(h2) or h0 < 1.0:
		return

	var slope: float = (absf(h1 - h0) + absf(h2 - h0)) / 4.0
	var stones: int = mini(int(rng.randf() * (float(cfg.get("stones_flat", 0.5)) + slope * float(cfg.get("stones_per_slope", 3.0))) * 2.0), int(cfg.get("stones_max", 4)))   # luck-exempt: seeded world layout
	var sticks: int = mini(int(rng.randf() * 3.0), int(cfg.get("sticks_max", 2)))   # luck-exempt: seeded world layout
	var kinds: Array = []

	for n in stones:
		kinds.append("stone")

	for n in sticks:
		kinds.append("stick")

	for n in kinds.size():
		var key: int = ((cell.x & 0xfffff) << 24) | ((cell.y & 0xfffff) << 4) | n

		if _taken.has(key):
			continue

		var spot: Vector3 = _scatter_spot(rng, cell, cell_m, kinds[n] == "stone")
		var x: float = spot.x
		var z: float = spot.z
		var y: float = spot.y

		if is_nan(y) or y < 1.0:
			continue

		_items[_next_id] = {"number": table.number_of(kinds[n]), "count": 1, "pos": Vector3(x, y, z), "left": 1.0e9, "scatter": key}
		_next_id += 1

	_lay_out_bank_stones(cell, cell_m, cfg, rng, kinds.size())
	_lay_out_boulders(cell, cell_m, rng)


# Boulders (Dave 2026-10-21), see data/items/boulders.json: server-owned lumps of rock a pick breaks into stones. Laid out per
# cell like loose stones (same seeded rng, drawn last so the stones above do not move), only where the ground rises or at a
# water bank; what is left of a worked boulder is kept in _boulder_left. The row carries its radius and the stones it started
# with; the item's count is the stones left.
func _boulder_stones(radius: float) -> int:
	var cfg: Dictionary = _boulder_cfg
	var volume: float = 4.0 / 3.0 * PI * radius * radius * radius * float(cfg.get("height_ratio", 0.85))
	var stone_kg: float = maxf(CarryRules.weight_of("stone", _carry_cfg) if not _carry_cfg.is_empty() else 1.0, 0.05)
	return maxi(int(volume * float(cfg.get("density_kg_m3", 2600)) * float(cfg.get("yield", 0.5)) / stone_kg), 1)


func _lay_out_boulders(cell: Vector2i, cell_m: float, rng: RandomNumberGenerator) -> void:
	var cfg: Dictionary = _boulder_cfg

	if cfg.is_empty():
		return

	var laid: int = 0

	for attempt in range(int(cfg.get("tries", 8))):
		var x: float = (float(cell.x) + rng.randf()) * cell_m   # luck-exempt: seeded world layout
		var z: float = (float(cell.y) + rng.randf()) * cell_m   # luck-exempt: seeded world layout
		var draw: float = rng.randf()   # luck-exempt: seeded world layout
		var size_draw: float = rng.randf()   # luck-exempt: seeded world layout
		var yaw: float = rng.randf() * 360.0   # luck-exempt: seeded world layout
		var y: float = float(ground_height.call(x, z))

		if is_nan(y) or y < 1.0 or laid >= mini(int(cfg.get("max_per_cell", 4)), 15):
			continue

		var rise: float = (absf(float(ground_height.call(x + 3.0, z)) - y) + absf(float(ground_height.call(x, z + 3.0)) - y)) / 3.0
		var chance: float = clampf((rise - float(cfg.get("min_slope", 0.1))) * float(cfg.get("slope_chance", 2.0)), 0.0, float(cfg.get("max_chance", 0.5)))
		var spot: Vector3 = Vector3(x, y, z)

		if water_near.is_valid() and not bool(water_near.call(spot, 0.0)) and bool(water_near.call(spot, float(cfg.get("bank_reach_m", 3.0)))):
			chance = maxf(chance, float(cfg.get("bank_chance", 0.4)))

		if draw > chance:
			continue

		var key: int = BOULDER_KEY | ((cell.x & 0xfffff) << 24) | ((cell.y & 0xfffff) << 4) | laid
		laid += 1
		var radius: float = lerpf(float(cfg.get("radius_min", 0.3)), float(cfg.get("radius_max", 1.2)), pow(size_draw, float(cfg.get("radius_power", 2.0))))
		var total: int = _boulder_stones(radius)
		var left: int = mini(int(_boulder_left.get(key, total)), total)

		if left <= 0:
			continue

		_items[_next_id] = {"number": 0, "count": left, "pos": spot, "left": 1.0e9, "scatter": key, "boulder": {"radius": radius, "yaw": yaw, "total": total}}
		_next_id += 1


# The blows a stone takes from the best tool on the hotbar (items.json material, boulders.json tools), as [slot, blows], or [].
func _boulder_tool(inv) -> Array:
	var best: Array = []
	var tools: Dictionary = _boulder_cfg.get("tools", {})

	for slot in range(10):
		if inv.numbers[slot] == 0 or _is_broken(inv.numbers[slot], inv.wear[slot]):
			continue

		var entry: Dictionary = table.entry(table.id_of(inv.numbers[slot]))
		var blows: int = int(tools.get(str(entry.get("tool_class", "")), {}).get(str(entry.get("material", "")), 0))

		if blows > 0 and (best.is_empty() or blows < int(best[1])):
			best = [slot, blows]

	return best


# One blow on a boulder (ACT_HIT with the boulder marker). The best tool wears every blow; after its blows-per-stone a rough
# stone comes out into the pack (refused when too heavy to carry), the boulder shrinks, and it is gone with its last stone.
func _hit_boulder(peer: int, inv, id: int) -> void:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not it.has("boulder") or not _peer_pos.has(peer):
		return

	var now: int = Time.get_ticks_msec()

	if now - int(_last_hit.get(peer, -100000)) < HIT_COOLDOWN_MS:
		return

	var tool: Array = _boulder_tool(inv)

	if tool.is_empty():
		_reject(peer, 1)
		return

	var info: Dictionary = it["boulder"]
	var size_now: float = float(info["radius"]) * pow(float(it["count"]) / float(maxi(int(info["total"]), 1)), 1.0 / 3.0)
	var flat: Vector2 = Vector2(_peer_pos[peer].x - it["pos"].x, _peer_pos[peer].z - it["pos"].z)

	if flat.length() > HIT_REACH_M + size_now:
		_reject(peer, 0)
		return

	_last_hit[peer] = now
	_wear_slot(peer, inv, int(tool[0]), "boulder")
	info["blows"] = int(info.get("blows", 0)) + 1

	if int(info["blows"]) < int(tool[1]):
		return

	var stone: int = table.number_of("stone")

	if _fit(peer, inv, stone, 1) == 0:
		_say(peer, "Too heavy to carry any more")
		_reject(peer, 2)
		return

	info["blows"] = 0
	var out: int = 1

	# Luck (TD condition): a rough stone now and then comes away as two (boulders.json luck_extra, nudged by the peer's luck).
	if int(it["count"]) > 1 and fate(peer, "boulder_extra", float(_boulder_cfg.get("luck_extra", 0.05))):
		out = 2

	inv.add(stone, out)
	it["count"] = int(it["count"]) - out
	_boulder_left[it["scatter"]] = int(it["count"])
	_dirty = true

	if int(it["count"]) <= 0:
		_items.erase(id)


# Stones along the water's edge (Dave 2026-10-21: any rock put down is pickable, so Art's drawn pebbles and boulders became
# real stones). A cell with water in or near it tries bank_tries spots; a dry spot within bank_reach_m of water takes a
# stone with chance bank_chance, up to bank_max a cell. Item keys continue after the cell's own scatter (low four bits).
func _lay_out_bank_stones(cell: Vector2i, cell_m: float, cfg: Dictionary, rng: RandomNumberGenerator, used: int) -> void:
	var bank: Dictionary = cfg.get("bank", {})

	if bank.is_empty() or not water_near.is_valid():
		return

	var centre: Vector3 = Vector3((float(cell.x) + 0.5) * cell_m, 0.0, (float(cell.y) + 0.5) * cell_m)

	if not bool(water_near.call(centre, float(bank.get("cell_probe_m", 24.0)))):
		return

	var reach: float = float(bank.get("reach_m", 3.0))
	var laid: int = 0

	for attempt in range(int(bank.get("tries", 40))):
		var x: float = (float(cell.x) + rng.randf()) * cell_m   # luck-exempt: seeded world layout
		var z: float = (float(cell.y) + rng.randf()) * cell_m   # luck-exempt: seeded world layout
		var y: float = float(ground_height.call(x, z))
		var chance: float = rng.randf()   # luck-exempt: seeded world layout

		if is_nan(y) or y < 1.0 or chance > float(bank.get("chance", 0.5)):
			continue

		var spot: Vector3 = Vector3(x, y, z)

		if bool(water_near.call(spot, 0.0)) or not bool(water_near.call(spot, reach)):
			continue

		var key: int = ((cell.x & 0xfffff) << 24) | ((cell.y & 0xfffff) << 4) | (used + laid)

		if used + laid >= 15 or laid >= int(bank.get("max", 6)):
			return

		laid += 1

		if _taken.has(key):
			continue

		var driftwood: bool = rng.randf() < float(bank.get("driftwood", 0.12))   # luck-exempt: seeded world layout
		_items[_next_id] = {"number": table.number_of("driftwood" if driftwood else "stone"), "count": 1, "pos": spot, "left": 1.0e9, "scatter": key}
		_next_id += 1


# Where in a cell a loose stone or stick lies (Dave 2026-10-20: place them appropriately). A few random spots are
# tried and the first one the terrain "likes" is taken, so the counts stay as they were but the places are natural:
# sticks mostly under and around tree crowns and rarely on bare rock; stones on slopes, on bare rock and gravel, and
# in hollows at the foot of a rise, with a few left in open ground. The odds are in data/items/drops.json.
func _scatter_spot(rng: RandomNumberGenerator, cell: Vector2i, cell_m: float, stone: bool) -> Vector3:
	var cfg: Dictionary = _drops.get("ground_scatter", {})
	var tries: int = int(cfg.get("spot_tries", 4))
	var best: Vector3 = Vector3(0.0, NAN, 0.0)

	for attempt in range(tries):
		var x: float = (float(cell.x) + rng.randf()) * cell_m   # luck-exempt: seeded world layout
		var z: float = (float(cell.y) + rng.randf()) * cell_m   # luck-exempt: seeded world layout
		var y: float = float(ground_height.call(x, z))

		if is_nan(y) or y < 1.0:
			continue

		var spot: Vector3 = Vector3(x, y, z)
		var like: float

		if stone:
			var east: float = float(ground_height.call(x + 3.0, z))
			var south: float = float(ground_height.call(x, z + 3.0))
			var rise: float = (absf(east - y) + absf(south - y)) / 3.0
			var west: float = float(ground_height.call(x - 6.0, z))
			var north: float = float(ground_height.call(x, z - 6.0))
			var hollow: float = clampf(((west + north + float(ground_height.call(x + 6.0, z)) + float(ground_height.call(x, z + 6.0))) / 4.0 - y) / 3.0, 0.0, 1.0)
			like = float(cfg.get("stone_open", 0.12)) + minf(rise * float(cfg.get("stone_slope", 1.2)), 0.6) + hollow * float(cfg.get("stone_foot", 0.25))

			if rock_at.is_valid() and bool(rock_at.call(x, z)):
				like += float(cfg.get("stone_rock", 0.4))
		else:
			like = float(cfg.get("stick_open", 0.12))

			if cover_at.is_valid() and float(cover_at.call(spot)) > 0.5:
				like += float(cfg.get("stick_tree", 0.88))

			if rock_at.is_valid() and bool(rock_at.call(x, z)):
				like *= float(cfg.get("stick_on_rock", 0.3))

		best = spot

		if like >= rng.randf():   # luck-exempt: seeded world layout
			return spot

	return best


# One axe blow on a standing tree. Enough blows fell it: the standing tree is removed, and a trunk
# and a stump lie there (records in _items with a "tree" entry, saved in tree_states.json).
func _hit(peer: int, inv, tree_id: int, chunk: Vector2i) -> void:
	if chunk.x == Net.HIT_BOULDER:
		_hit_boulder(peer, inv, tree_id)
		return

	if not _peer_pos.has(peer) or not tree_info.is_valid() or not cut_tree.is_valid():
		return

	var now: int = Time.get_ticks_msec()

	if now - int(_last_hit.get(peer, -100000)) < HIT_COOLDOWN_MS:
		return

	if not _has_tool(inv, "axe"):
		_reject(peer, 1)
		return

	var info: Dictionary = tree_info.call(chunk, tree_id)

	if info.is_empty():
		return

	var spot: Vector3 = info["position"]
	var flat: float = Vector2(_peer_pos[peer].x - spot.x, _peer_pos[peer].z - spot.z).length()

	if flat > HIT_REACH_M + float(info["trunk"]):
		_reject(peer, 0)
		return

	_last_hit[peer] = now
	_wear_tool(peer, inv, "axe", "tree")
	var key: String = "%d,%d,%d" % [chunk.x, chunk.y, tree_id]
	var chop: Dictionary = _chops.get(key, {"hits": 0, "msec": now})

	if now - int(chop["msec"]) > CHOP_RESET_MS:
		chop["hits"] = 0

	chop["hits"] = int(chop["hits"]) + 1
	chop["msec"] = now
	_chops[key] = chop
	var needed: int = maxi(1, int(ceil(float(clampi(int(4.0 + float(info["trunk"]) * 30.0), 4, 40)) / skill_factor(peer, "fell_tree"))))

	if int(chop["hits"]) < needed:
		return

	if _trees_in_chunk(chunk) >= TRUNKS_PER_CHUNK:
		if send_notice.is_valid():
			send_notice.call(peer, "Too many felled trunks lie here. Clear some away first.")

		return

	if not bool(cut_tree.call(chunk, tree_id)):
		return

	_chops.erase(key)
	_fell_record(chunk, info, Vector2(spot.x - _peer_pos[peer].x, spot.z - _peer_pos[peer].z))


# Cuts a standing tree and lays its trunk and stump down (the last axe blow and a dug-out tree both end here). `away` is the
# direction it falls in.
func _fell(chunk: Vector2i, tree_id: int, info: Dictionary, away: Vector2) -> void:
	if not bool(cut_tree.call(chunk, tree_id)):
		return

	_fell_record(chunk, info, away)


func _fell_record(chunk: Vector2i, info: Dictionary, away: Vector2) -> void:
	var spot: Vector3 = info["position"]
	var yaw: float = atan2(away.x, away.y) if away.length() > 0.01 else 0.0
	var now_s: float = float(game_seconds.call()) if game_seconds.is_valid() else 0.0
	var base: Dictionary = {"species": str(info["name"]), "yaw": yaw, "length": float(info["height"]), "radius": maxf(float(info["trunk"]), 0.1), "felled_at": now_s}
	var trunk: Dictionary = base.duplicate()
	trunk["state"] = 3
	trunk["chunk"] = [chunk.x, chunk.y]
	var stump: Dictionary = base.duplicate()
	stump["state"] = 4
	stump["chunk"] = [chunk.x, chunk.y]
	_items[_next_id] = {"number": 0, "count": 1, "pos": spot, "left": 1.0e9, "tree": trunk}
	_next_id += 1
	_items[_next_id] = {"number": 0, "count": 1, "pos": spot, "left": 1.0e9, "tree": stump}
	_next_id += 1
	_dirty = true


func _has_tool(inv, tool_class: String) -> bool:
	return _tool_slot(inv, tool_class) >= 0


# The hotbar slot (the first ten pack slots, keys 1 to 9 and 0) of a usable (not broken) tool of this class, or -1.
func _tool_slot(inv, tool_class: String) -> int:
	for slot in range(10):
		if inv.numbers[slot] != 0 and str(table.entry(table.id_of(inv.numbers[slot])).get("tool_class", "")) == tool_class and not _is_broken(inv.numbers[slot], inv.wear[slot]):
			return slot

	return -1


# Worn out: durability is the number of uses a tool lasts (items.json); items without it never wear.
func _is_broken(number: int, item_wear: int) -> bool:
	var durability: int = int(table.entry(table.id_of(number)).get("durability", 0))
	return durability > 0 and item_wear >= durability


# One use spent on the first usable tool of this class on the hotbar; tells the player when it breaks.
# Wear per use comes from drops.json "tool_wear" (per tool class and kind of work, default 1), so a tuning change is data.
func _wear_tool(peer: int, inv, tool_class: String, use: String = "") -> void:
	_wear_slot(peer, inv, _tool_slot(inv, tool_class), use)


func _wear_slot(peer: int, inv, slot: int, use: String = "") -> void:
	if slot < 0 or int(table.entry(table.id_of(inv.numbers[slot])).get("durability", 0)) <= 0:
		return

	var tool_class: String = str(table.entry(table.id_of(inv.numbers[slot])).get("tool_class", ""))

	_work_until[peer] = Time.get_ticks_msec() + 5000
	var before: Array = _snapshot(inv)
	inv.wear[slot] += maxi(1, int(_drops.get("tool_wear", {}).get("per_use", {}).get(tool_class, {}).get(use, 1)))
	_dirty = true

	if _is_broken(inv.numbers[slot], inv.wear[slot]):
		_say(peer, "Your %s broke. Repair it with new materials." % table.name_of(inv.numbers[slot]).to_lower())

	_send_changes(peer, inv, before)


# Repair (ACT_REPAIR): the slot's tool, worn or broken, takes the repair materials from items.json
# ("repair": [[item, count], ...]) and wins back half its durability.
func _repair(peer: int, inv, slot: int) -> void:
	if slot < 0 or slot >= inv.SLOTS or inv.numbers[slot] == 0 or inv.wear[slot] <= 0:
		return

	var entry: Dictionary = table.entry(table.id_of(inv.numbers[slot]))
	var costs: Array = entry.get("repair", [])

	if costs.is_empty():
		return

	# The tool's own slot must not be spent as material.
	var held_number: int = inv.numbers[slot]

	for cost in costs:
		var number: int = table.number_of(str(cost[0]))
		var have: int = inv.count_of(number) - (inv.counts[slot] if number == held_number else 0)

		if number == 0 or have < int(cost[1]):
			_say(peer, "Repair needs %s." % _repair_text(costs))
			return

	for cost in costs:
		inv.remove(table.number_of(str(cost[0])), int(cost[1]))

	inv.wear[slot] = maxi(0, inv.wear[slot] - int(float(entry.get("durability", 0)) * float(_drops.get("tool_wear", {}).get("repair_restores", 0.5))))


func _repair_text(costs: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()

	for cost in costs:
		parts.append("%d %s" % [int(cost[1]), table.name_of(table.number_of(str(cost[0]))).to_lower()])

	return ", ".join(parts)


func _trees_in_chunk(chunk: Vector2i) -> int:
	var count: int = 0

	for id in _items:
		var it: Dictionary = _items[id]

		if it.has("tree") and int(it["tree"]["state"]) == 3 and it["tree"]["chunk"] == [chunk.x, chunk.y]:
			count += 1

	return count


# Trunks and stumps rot away after 168 game days (the game clock only runs while the server does).
func _rot(delta: float) -> void:
	_rot_in -= delta

	if _rot_in > 0.0 or not game_seconds.is_valid():
		return

	_rot_in = 60.0
	var now_s: float = float(game_seconds.call())
	rot_scanned = 0
	rot_removed = 0

	for id in _items.keys():
		if _items.has(id) and _items[id].has("tree"):
			rot_scanned += 1

		if _items.has(id) and _items[id].has("tree") and now_s - float(_items[id]["tree"]["felled_at"]) >= ROT_GAME_S:
			var rotted: Dictionary = _items[id]
			_items.erase(id)
			_dirty = true
			rot_removed += 1

			# Lazy catch-up: a stump that rotted while nobody was here seeds its sapling at the moment it rotted, so it has
			# grown by the time we look (growth is computed from planted_at, nothing ticks).
			if int(rotted["tree"]["state"]) == 4:
				_maybe_sapling(rotted, float(rotted["tree"]["felled_at"]) + ROT_GAME_S)

	var stale: Array = []
	var now_ms: int = Time.get_ticks_msec()

	for key in _chops:
		if now_ms - int(_chops[key]["msec"]) > CHOP_RESET_MS:
			stale.append(key)

	for key in stale:
		_chops.erase(key)


func _save_trees() -> void:
	var rows: Array = []

	for id in _items:
		if _items[id].has("tree"):
			var it: Dictionary = _items[id]
			rows.append({"pos": [it["pos"].x, it["pos"].y, it["pos"].z], "tree": it["tree"]})

	var plants: Array = []

	for sapling in _saplings:
		plants.append({"slot": sapling["slot"], "chunk": sapling["chunk"], "species": sapling["species"], "pos": {"x": sapling["pos"].x, "y": sapling["pos"].y, "z": sapling["pos"].z}, "planted_at": sapling["planted_at"]})

	_write_atomic("tree_states.json", {"version": TREE_SAVE_VERSION, "trees": rows, "saplings": plants})


func _load_trees() -> void:
	var parsed: Variant = _read_json_version("tree_states.json", TREE_SAVE_VERSION)

	if parsed == null:
		return

	for sapling in parsed.get("saplings", []):
		_saplings.append({"slot": int(sapling["slot"]), "chunk": [int(sapling["chunk"][0]), int(sapling["chunk"][1])], "species": int(sapling["species"]), "pos": Vector3(sapling["pos"]["x"], sapling["pos"]["y"], sapling["pos"]["z"]), "planted_at": float(sapling["planted_at"])})

	for row in parsed["trees"]:
		var tree: Dictionary = row["tree"]
		tree["state"] = int(tree["state"])
		tree["chunk"] = [int(tree["chunk"][0]), int(tree["chunk"][1])]
		_items[_next_id] = {"number": 0, "count": 1, "pos": Vector3(row["pos"][0], row["pos"][1], row["pos"][2]), "left": 1.0e9, "tree": tree}
		_next_id += 1


# One axe blow on a felled trunk (drops.json "trunk"): branches and leaves first, then logs with some
# bark and now and then seeds. The server checks the axe, the pace and that the player stands at the
# trunk (distance to its line). The trunk is used up when its logs are gone; the stump stays.
func _process_trunk(peer: int, inv, id: int) -> void:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not it.has("tree") or int(it["tree"]["state"]) != 3 or not _peer_pos.has(peer) or not _has_tool(inv, "axe"):
		return

	var tree: Dictionary = it["tree"]
	var cfg: Dictionary = _drops.get("trunk", {})
	var along: Vector3 = Vector3(sin(float(tree["yaw"])), 0.0, cos(float(tree["yaw"])))
	var from_base: Vector3 = _peer_pos[peer] - it["pos"]
	var t: float = clampf(from_base.dot(along), 0.0, float(tree["length"]))
	var nearest: Vector3 = it["pos"] + along * t

	if Vector2(_peer_pos[peer].x - nearest.x, _peer_pos[peer].z - nearest.z).length() > PROCESS_REACH_M + float(tree["radius"]):
		return

	var now: int = Time.get_ticks_msec()

	if float(now - int(_last_process.get(peer, -100000))) < float(PROCESS_COOLDOWN_MS) / skill_factor(peer, "work_trunk"):
		return

	_last_process[peer] = now
	_wear_tool(peer, inv, "axe", "trunk")

	if not tree.has("logs_left"):
		tree["logs_left"] = clampi(int(float(tree["length"]) / float(cfg.get("log_length_m", 2.5)) * clampf(float(tree["radius"]) * 2.5, 0.5, 2.0)), 1, int(cfg.get("max_logs", 12)))
		tree["blows"] = 0

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(id) ^ (int(tree["blows"]) * 7919)
	var blows: int = int(tree["blows"])
	tree["blows"] = blows + 1

	if blows < int(cfg.get("branch_blows", 3)):
		for row in cfg.get("branch", []):
			give(peer, table.number_of(str(row[0])), roll_amount(peer, rng, int(row[1]), int(row[2])))
	else:
		if (blows - int(cfg.get("branch_blows", 3))) % int(cfg.get("blows_per_log", 3)) == 2:
			give(peer, table.number_of("log"), 1)
			tree["logs_left"] = int(tree["logs_left"]) - 1

		if roll_chance(peer, rng, float(cfg.get("bark_chance", 0.3))):
			give(peer, table.number_of("bark"), 1)

		if roll_chance(peer, rng, float(cfg.get("seed_chance", 0.15))):
			var own: Array = cfg.get("by_species", {}).get(str(tree.get("species", "")), [])

			if own.is_empty():
				give(peer, table.number_of("seed_bundle"), 1)
			else:
				give(peer, table.number_of(str(own[0][0])), roll_amount(peer, rng, int(own[0][1]), int(own[0][2])))

		if int(tree["logs_left"]) <= 0:
			var roots: Array = cfg.get("roots", [])

			if not roots.is_empty():
				give(peer, table.number_of(str(roots[0])), roll_amount(peer, rng, int(roots[1]), int(roots[2])))

			_items.erase(id)

	_dirty = true


# A stump has rotted away: maybe a sapling grows near a standing tree of the same species. Nothing
# comes while any felled trunk still lies in the chunk. The dice come from the seed and the spot,
# so a restart gives the same answer.
func _maybe_sapling(stump: Dictionary, planted_at: float = -1.0) -> void:
	if not standing_near.is_valid() or not ground_height.is_valid():
		return

	var tree: Dictionary = stump["tree"]
	var chunk: Vector2i = Vector2i(int(tree["chunk"][0]), int(tree["chunk"][1]))

	if _trees_in_chunk(chunk) > 0:
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(int(stump["pos"].x), int(stump["pos"].z), world_seed))

	if rng.randf() > RESPAWN_CHANCE:   # luck-exempt: world regrowth, no player
		return

	var near: Array = standing_near.call(str(tree["species"]), stump["pos"], RESPAWN_RADIUS_M)

	if near.is_empty():
		return

	var angle: float = rng.randf() * TAU   # luck-exempt: world regrowth, no player
	var spot: Vector3 = near[0] + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(2.0, RESPAWN_PLACE_M)   # luck-exempt: world regrowth, no player
	var ground: float = float(ground_height.call(spot.x, spot.z))
	var species_entry: Dictionary = _flora_by_name.get(str(tree["species"]), {})

	if is_nan(ground) or ground < 1.0 or species_entry.is_empty():
		return

	var home: Vector2i = Vector2i(int(floor(spot.x / FLORA_CHUNK_M)), int(floor(spot.z / FLORA_CHUNK_M)))
	var used: Dictionary = {}

	for sapling in _saplings:
		if sapling["chunk"] == [home.x, home.y]:
			used[sapling["slot"]] = true

	if used.size() >= SAPLINGS_PER_CHUNK:
		return

	var slot: int = 0

	while used.has(slot):
		slot += 1

	spot.y = ground
	_saplings.append({"slot": slot, "chunk": [home.x, home.y], "species": int(species_entry["id"]), "pos": spot, "planted_at": planted_at if planted_at >= 0.0 else (float(game_seconds.call()) if game_seconds.is_valid() else 0.0)})
	_dirty = true

	if flora_changed.is_valid():
		flora_changed.call(home)


# Saplings and grown trees of a flora chunk as flora items (ids, positions, heights, yaws), the
# way the placer lists trees, so the flora view and the cover index treat them as trees. The
# size comes from the age now (computed here, nothing runs per frame). {} when there are none.
func dynamic_items(home: Vector2i) -> Dictionary:
	var result: Dictionary = {}
	var now_s: float = float(game_seconds.call()) if game_seconds.is_valid() else 0.0

	for sapling in _saplings:
		if sapling["chunk"] != [home.x, home.y]:
			continue

		if result.is_empty():
			result = {"ids": PackedInt32Array(), "positions": PackedVector3Array(), "heights": PackedFloat32Array(), "yaws": PackedFloat32Array()}

		result["ids"].append((int(sapling["species"]) << 16) | (0xFFFF - int(sapling["slot"])))
		result["positions"].append(sapling["pos"])
		result["heights"].append(_sapling_height(sapling, now_s))
		result["yaws"].append(float(hash(sapling["pos"]) % 628) / 100.0)

	return result


func _sapling_height(sapling: Dictionary, now_s: float) -> float:
	var entry: Dictionary = _flora_by_id.get(int(sapling["species"]), {})
	var full: float = float(entry["height_m"][0]) if not entry.is_empty() else 8.0
	var age: float = now_s - float(sapling["planted_at"])

	if age >= SAPLING_GROWN_S:
		return full

	if age >= SAPLING_YOUNG_S:
		return full * lerpf(0.4, 0.9, (age - SAPLING_YOUNG_S) / (SAPLING_GROWN_S - SAPLING_YOUNG_S))

	return maxf(full * 0.4 * age / SAPLING_YOUNG_S, 0.5)


# A grown tree of the dynamic kind as tree_info answers for placer trees, or {} (saplings and
# young trees cannot be felled, and there is no such id).
func dynamic_tree_info(home: Vector2i, id: int) -> Dictionary:
	var now_s: float = float(game_seconds.call()) if game_seconds.is_valid() else 0.0

	for sapling in _saplings:
		if sapling["chunk"] == [home.x, home.y] and ((int(sapling["species"]) << 16) | (0xFFFF - int(sapling["slot"]))) == id:
			if now_s - float(sapling["planted_at"]) < SAPLING_GROWN_S:
				return {}

			var entry: Dictionary = _flora_by_id.get(int(sapling["species"]), {})
			return {"name": str(entry.get("name", "")), "position": sapling["pos"], "height": _sapling_height(sapling, now_s), "trunk": float(entry.get("trunk_m", 0.4)), "dynamic": true}

	return {}


# A grown dynamic tree was felled: the record goes. True if there was one.
func remove_dynamic(home: Vector2i, id: int) -> bool:
	for sapling in _saplings:
		if sapling["chunk"] == [home.x, home.y] and ((int(sapling["species"]) << 16) | (0xFFFF - int(sapling["slot"]))) == id:
			_saplings.erase(sapling)
			_dirty = true

			if flora_changed.is_valid():
				flora_changed.call(home)

			return true

	return false


func peers_near(position: Vector3, radius: float) -> Array:
	var out: Array = []

	for peer in _peer_pos:
		if _peer_pos[peer].distance_to(position) <= radius:
			out.append(peer)

	return out


# Splits `count` off a stack into the first empty slot (the stack keeps at least one).
func _split(inv, slot: int, count: int) -> void:
	if slot < 0 or slot >= inv.SLOTS or inv.numbers[slot] == 0 or count < 1 or count >= inv.counts[slot]:
		return

	for target in range(inv.SLOTS):
		if inv.numbers[target] == 0:
			inv.numbers[target] = inv.numbers[slot]
			inv.counts[target] = count
			inv.counts[slot] -= count
			return


# Wood on the fire: a stick or a log adds burning time (up to max_burn_game_s). A fire the rain put out
# lights again when fed where rain no longer reaches it (covered, or the rain has stopped).
func _fuel(peer: int, inv, id: int) -> void:
	var fire: Dictionary = _fire_in_reach(peer, id)

	if fire.is_empty():
		return

	var fuel: Dictionary = _cooking.get("fuel", {})

	for wood in _cooking.get("fuel_order", ["stick", "log"]):
		var number: int = table.number_of(wood)

		if inv.has(number, 1):
			inv.remove(number, 1)
			fire["burn_left"] = minf(float(fire["burn_left"]) + float(fuel.get(wood, 120.0)) / GAME_RATE, float(_cooking.get("max_burn_game_s", 43200.0)) / GAME_RATE)

			# Wood laid in an unlit fire only loads it; Press E to light comes next (ACT_LIGHT).
			if int(fire["state"]) == 8:
				fire["state"] = 9
				_items[id]["left"] = FIRE_LAID_S

			return


# Lighting a loaded fire (Dave 2026-10-20): bare hands, one tinder item from the pack (cooking.json
# "tinder"). Open fires will not take while it rains.
func _light(peer: int, inv, id: int) -> void:
	var fire: Dictionary = _fire_in_reach(peer, id)

	if fire.is_empty() or int(fire["state"]) != 9 or float(fire["burn_left"]) <= 0.0:
		return

	var raining: bool = rain_now.is_valid() and float(rain_now.call()) >= RAIN_PUTS_OUT

	if raining and not bool(fire["covered"]):
		_say(peer, "The rain will not let it light. Move it under cover.")
		return

	var tinder: String = str(_cooking.get("tinder", "plant_fibre"))

	if not inv.has(table.number_of(tinder), 1):
		_say(peer, "Needs %s to light" % table.name_of(table.number_of(tinder)).to_lower())
		return

	inv.remove(table.number_of(tinder), 1)
	fire["state"] = 1
	_items[id]["left"] = 1.0e9
	_dirty = true


# Roasting at a lit fire: one raw forage item (cookable_suffixes in cooking.json) becomes Roasted forage.
func _cook(peer: int, inv, id: int) -> void:
	var fire: Dictionary = _fire_in_reach(peer, id)

	if fire.is_empty() or int(fire["state"]) != 1:
		return

	var now: int = Time.get_ticks_msec()

	if now - int(_last_cook.get(peer, -100000)) < int(_cooking.get("pace_ms", 1200)):
		return

	for slot in range(inv.SLOTS):
		if inv.numbers[slot] != 0 and _cookable(table.id_of(inv.numbers[slot])):
			_last_cook[peer] = now
			inv.take_from_slot(slot, 1)
			var left: int = inv.add(table.number_of(str(_cooking.get("gives", "roast_forage"))), 1)

			if left > 0:
				drop_in_world(table.number_of(str(_cooking.get("gives", "roast_forage"))), left, _peer_pos[peer])

			return


func _cookable(item_id: String) -> bool:
	if item_id == "" or item_id == str(_cooking.get("gives", "")):
		return false

	for suffix in _cooking.get("cookable_suffixes", []):
		if item_id.ends_with(str(suffix)):
			return true

	return false


# The fire record of a world item id when the player stands within reach of it, else {}.
func _fire_in_reach(peer: int, id: int) -> Dictionary:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not it.has("fire") or not _peer_pos.has(peer) or _peer_pos[peer].distance_to(it["pos"]) > FIRE_USE_M:
		return {}

	return it["fire"]


# --- Placed structures (data/items/structures.json): lean-to shelter now, storage chest next ---

func _structure_of_kit(kit_id: String) -> Dictionary:
	for kind in _structures:
		if str(_structures[kind]["kit"]) == kit_id:
			var def: Dictionary = _structures[kind].duplicate()
			def["kind"] = kind
			return def

	return {}


func _place_structure(peer: int, inv, slot: int, spot: Vector3, yaw_deg: int, def: Dictionary) -> void:
	var here_chunk: Vector2i = _chunk_of(spot)
	var of_kind: int = 0

	for id in _items:
		var other: Dictionary = _items[id]

		if other["pos"].distance_to(spot) < _struct_gap_m and (other.has("struct") or other.has("fire")):
			return

		if other.has("struct") and str(other["struct"]["kind"]) == str(def["kind"]) and _chunk_of(other["pos"]) == here_chunk:
			of_kind += 1

	if of_kind >= int(def["cap_per_chunk"]):
		_say(peer, "Too many of these stand here already.")
		return

	inv.take_from_slot(slot, 1)
	var entry: Dictionary = {"number": table.number_of(str(def["item"])), "count": 1, "pos": spot, "left": 1.0e9, "struct": {"kind": str(def["kind"]), "yaw": float(posmod(yaw_deg, 360))}}

	if int(def.get("slots", 0)) > 0:
		entry["struct"]["uid"] = _next_uid
		_chests[_next_uid] = InventoryScript.new(table)
		_next_uid += 1

	_items[_next_id] = entry
	_next_id += 1
	_add_roof(entry)
	_dirty = true


# The structure's roof joins the cover index (both ends do the same on seeing the structure).
func _add_roof(entry: Dictionary) -> void:
	var def: Dictionary = _structures.get(str(entry["struct"]["kind"]), {})

	if def.is_empty() or not def.has("height") or not roof_add.is_valid() or entry["struct"].has("roof"):
		return

	var box: Array = CoverScript.box_roof(Vector2(entry["pos"].x, entry["pos"].z), float(def["half_x"]), float(def["half_z"]), deg_to_rad(float(entry["struct"]["yaw"])), entry["pos"].y - 0.5, entry["pos"].y + float(def["height"]))
	entry["struct"]["roof"] = int(roof_add.call(box))


# After loading a save and wiring roof_add: put every saved structure's roof in the cover index.
func register_roofs() -> void:
	for id in _items:
		if _items[id].has("struct"):
			_add_roof(_items[id])


# Taking a structure down (E near it) gives its kit back. A chest with things in it cannot be taken down.
func _take_down(peer: int, inv, id: int) -> void:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not _peer_pos.has(peer) or _peer_pos[peer].distance_to(it["pos"]) > PICKUP_M + 2.0:
		return

	var def: Dictionary = _structures.get(str(it["struct"]["kind"]), {})

	if def.is_empty() or str(def.get("kit", "")) == "":
		return

	if not _struct_empty(id):
		_say(peer, "Empty it first.")
		return

	var kit: int = table.number_of(str(def["kit"]))

	if inv.add(kit, 1) > 0:
		return

	if it["struct"].has("roof") and roof_remove.is_valid():
		roof_remove.call(int(it["struct"]["roof"]))

	_chests.erase(int(it["struct"].get("uid", 0)))
	_items.erase(id)
	_dirty = true


# E at a chopping block: one log becomes firewood; the axe wears one use. The server checks the reach,
# a log in the pack, a usable axe on the hotbar and the pace.
func _use_struct(peer: int, inv, id: int) -> void:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not it.has("struct") or not _peer_pos.has(peer):
		return

	var def: Dictionary = _structures.get(str(it["struct"]["kind"]), {})

	if str(def.get("use", "")) != "split_log" or _peer_pos[peer].distance_to(it["pos"]) > float(def.get("use_reach_m", 3.0)):
		return

	var now: int = Time.get_ticks_msec()

	if float(now - int(_last_use.get(peer, -100000))) < float(def.get("use_pace_ms", 600)) / skill_factor(peer, "split_log"):
		return

	var log_n: int = table.number_of("log")

	if not _has_tool(inv, "axe"):
		_say(peer, "You need an axe to split wood.")
		return

	if not inv.has(log_n, 1):
		_say(peer, "You need a log to split.")
		return

	_last_use[peer] = now
	inv.remove(log_n, 1)
	var wood: int = table.number_of("firewood")
	var left: int = inv.add(wood, int(def.get("logs_to_firewood", 4)))

	if left > 0:
		drop_in_world(wood, left, _peer_pos[peer])

	_wear_tool(peer, inv, "axe", "split")
	_dirty = true


func _struct_empty(id: int) -> bool:
	var chest = _chests.get(int(_items.get(id, {}).get("struct", {}).get("uid", 0)))

	if chest == null:
		return true

	for slot in range(chest.SLOTS):
		if chest.numbers[slot] != 0:
			return false

	return true


# --- Chest contents: server-owned; the actor gets the full 30 slots after every open, put and take ---

func _chest_of(peer: int, id: int):
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not it.has("struct") or not it["struct"].has("uid") or not _peer_pos.has(peer):
		return null

	if _peer_pos[peer].distance_to(it["pos"]) > CHEST_REACH_M:
		return null

	if str(it["struct"]["kind"]) == "remains" and not _may_open_remains(peer, it):
		_say(peer, "These remains are not yours to open yet.")
		return null

	var chest = _chests.get(int(it["struct"]["uid"]))

	if chest != null:
		chest.usable = clampi(int(_structures.get(str(it["struct"]["kind"]), {}).get("slots", chest.SLOTS)), 1, chest.SLOTS)

	return chest


func _chest_action(peer: int, inv, kind: int, a: int, id: int, count: int) -> void:
	if kind == Net.ACT_CHEST_OPEN:
		id = a

	var chest = _chest_of(peer, id)

	if chest == null:
		return

	if kind == Net.ACT_CHEST_PUT and bool(_structures.get(str(_items.get(id, {}).get("struct", {}).get("kind", "")), {}).get("take_only", false)):
		_reject(peer, 3)
	elif kind == Net.ACT_CHEST_PUT and a >= 0 and a < inv.SLOTS and inv.numbers[a] != 0 and count > 0:
		var number: int = inv.numbers[a]
		var held_wear: int = inv.wear[a]
		var amount: int = mini(count, inv.counts[a])
		var max_kg: float = float(_structures.get(str(_items.get(id, {}).get("struct", {}).get("kind", "")), {}).get("max_kg", 0.0))

		# A container takes only so many kilograms (structures.json max_kg): put what fits, keep the rest.
		if max_kg > 0.0 and not _carry_cfg.is_empty():
			var each: float = maxf(CarryRules.weight_of(table.id_of(number), _carry_cfg), 0.001)
			var room: float = max_kg - CarryRules.carried_kg(chest, table, _carry_cfg)
			amount = clampi(int(floor(room / each + 0.0001)), 0, amount)

			if amount == 0:
				_say(peer, "It is too heavy for the chest")
				_reject(peer, 2)

		var left: int = chest.add(number, amount, held_wear) if amount > 0 else 0
		inv.take_from_slot(a, amount - left)
		_dirty = true
	elif kind == Net.ACT_CHEST_TAKE and a >= 0 and a < chest.SLOTS and chest.numbers[a] != 0 and count > 0:
		var number: int = chest.numbers[a]
		var held_wear: int = chest.wear[a]
		var amount: int = mini(count, chest.counts[a])
		amount = _fit(peer, inv, number, amount)
		var left: int = inv.add(number, amount, held_wear)
		chest.take_from_slot(a, amount - left)
		_dirty = true

	if send_chest.is_valid():
		send_chest.call(peer, id, chest.to_bytes())


func _save_chests() -> void:
	var rows: Dictionary = {}

	for uid in _chests:
		rows[str(uid)] = _chests[uid].to_json_array()

	_write_atomic("chests.json", {"version": 1, "next_uid": _next_uid, "chests": rows})


func _load_chests() -> void:
	var parsed: Variant = _read_json_version("chests.json", 1)

	if parsed == null:
		return

	_next_uid = int(parsed.get("next_uid", 1))

	for key in parsed.get("chests", {}):
		var chest = InventoryScript.new(table)
		chest.from_json_array(parsed["chests"][key])
		_chests[int(key)] = chest


# --- Hunger, health and body weight (data/items/vitals.json; Dave 2026-10-20) ---
# An energy balance: a stomach (kcal) is burnt down by rest metabolism plus work; an empty stomach
# burns body weight, a surplus beyond a full one adds it. The player sees hunger as the stomach's
# share in percent, health in points and weight in tenths of a kilo.

# How many of `count` more of an item the player can carry before the hard cap (weights.json).
func _fit(peer: int, inv, number: int, count: int) -> int:
	if _carry_cfg.is_empty():
		return count

	var body: float = float(vitals_of(peer).get("weight", 75.0))
	return CarryRules.fit_count(table.id_of(number), count, CarryRules.carried_kg(inv, table, _carry_cfg), body, _carry_cfg)


func carried_kg_of(peer: int) -> float:
	var inv = inventory_of(peer)
	return CarryRules.carried_kg(inv, table, _carry_cfg) if inv != null and not _carry_cfg.is_empty() else 0.0


func vitals_of(peer: int) -> Dictionary:
	return _vitals.get(_peer_key.get(peer, ""), {})


func _new_vitals() -> Dictionary:
	return {"fed": float(_vitals_cfg.get("stomach_cap_kcal", 2400)), "weight": float(_vitals_cfg.get("start_weight_kg", 75)), "health": float(_vitals_cfg.get("health_max", 100)), "wet": float(_vitals_cfg.get("thirst", {}).get("cap_ml", 2400)), "energy": 100.0}


# How hard the player is working, 0 to 1: movement speed from position reports, lifted by recent tool work.
func exertion_of(peer: int) -> float:
	if int(_strain.get(peer, {}).get("state", 0)) >= 2:
		return 0.0

	return minf(effort_of(peer), 1.0)


# The same without the ceiling (a heavy pack can push it past 1): what strain builds on.
func effort_of(peer: int) -> float:
	var level: float = float(_exertion.get(peer, 0.0))

	if Time.get_ticks_msec() < int(_work_until.get(peer, 0)):
		level = maxf(level, 0.6)

	# A pack past 80 percent of the limit is work for anyone on the move, even at a crawl: load_effort x fraction^power added.
	if not _carry_cfg.is_empty():
		level += float(_moving.get(peer, 0.0)) * float(_carry_cfg.get("load_effort", 0.45)) * pow(_load_ratio(peer), float(_carry_cfg.get("load_effort_power", 1.5)))

	return level


# How far into the hindering band the load is: 0 up to 80 percent of the limit, 1 at the limit.
func _load_ratio(peer: int) -> float:
	if _carry_cfg.is_empty():
		return 0.0

	var body: float = float(vitals_of(peer).get("weight", 75.0))
	return CarryRules.load_fraction(carried_kg_of(peer), body, _carry_cfg)


# Stance changes (0 stand, 1 crouch, 2 sit, 3 lie). Fainted or waking players cannot choose; the answer
# (the confirmed stance) goes back in the next strain message.
func _set_stance(peer: int, wanted: int) -> void:
	if wanted < 0 or wanted > 3 or not _peer_key.has(peer) or _forced_sleep(peer):
		return

	if int(_strain.get(peer, {}).get("state", 0)) < 2:
		_stance[peer] = wanted

		if wanted != 3:
			_asleep.erase(peer)

	_strain_sent.erase(peer)


# --- Sleep (job 86, data/items/sleep.json) ---
func sleeping_of(peer: int) -> bool:
	return _asleep.has(peer)


# --- Energy (job 95, data/items/energy.json) ---
func energy_of(peer: int) -> float:
	return float(vitals_of(peer).get("energy", 100.0))


func _forced_sleep(peer: int) -> bool:
	return _asleep.has(peer) and bool(_asleep[peer].get("forced", false))


# Drains with game time by exertion, refills by resting; at 0 the character collapses asleep until the pool is full again.
func _energy_tick(peer: int, v: Dictionary, spent: float, game_s: float) -> void:
	if _energy_cfg.is_empty():
		return

	var e: float = float(v.get("energy", 100.0))
	var hours: float = game_s / 3600.0
	var drain: Dictionary = _energy_cfg.get("drain_per_game_day", {})
	var rec: Dictionary = _energy_cfg.get("recover_per_game_hour", {})
	e -= (float(drain.get("rest", 12.0)) + float(drain.get("work", 42.0)) * exertion_of(peer)) * game_s / 86400.0
	var stance: int = int(_stance.get(peer, 0))

	if _forced_sleep(peer):
		e += float(rec.get("sleep", 12.5)) * hours
	elif _asleep.has(peer):
		e += lerpf(float(rec.get("lie", 8.3)), float(rec.get("sleep", 12.5)), clampf(_sleep_quality(peer), 0.0, 1.0)) * hours
	elif stance == 3:
		e += float(rec.get("lie", 8.3)) * hours
	elif stance == 2 and e < float(_energy_cfg.get("sit_cap", 75.0)):
		e = minf(e + float(rec.get("sit", 9.4)) * hours, float(_energy_cfg.get("sit_cap", 75.0)))

	e = clampf(e, 0.0, 100.0)
	v["energy"] = e

	if e <= 0.0 and not _forced_sleep(peer) and int(_strain.get(peer, {}).get("state", 0)) < 2:
		_stance[peer] = 3
		_asleep[peer] = {"rested": 0.0, "forced": true}
		_strain_sent.erase(peer)
		_say(peer, "You collapse with exhaustion")
	elif _forced_sleep(peer) and e >= float(_energy_cfg.get("forced", {}).get("wake_at", 100.0)):
		_asleep.erase(peer)
		_strain_sent.erase(peer)
		_say(peer, "You wake rested")

	_sync_energy(peer, false)


func _sync_energy(peer: int, force: bool) -> void:
	if not send_energy.is_valid():
		return

	var pct: int = int(ceil(clampf(energy_of(peer), 0.0, 100.0)))

	if force or int(_energy_sent.get(peer, -1)) != pct:
		_energy_sent[peer] = pct
		send_energy.call(peer, pct)


# An energy supplement (vitals.json energy_aids): energy at once, a cost to fitness training.
func _use_energy_aid(peer: int, inv, slot: int, v: Dictionary, aid: Dictionary) -> void:
	if float(v.get("energy", 100.0)) >= 99.0:
		_say(peer, "You are not tired")
		return

	_last_eat[peer] = Time.get_ticks_msec()
	inv.take_from_slot(slot, 1)
	v["energy"] = minf(float(v.get("energy", 100.0)) + float(aid.get("energy", 0)), 100.0)
	_fitness_cost(peer, float(aid.get("fitness", 0.0)))
	_sync_energy(peer, true)
	_dirty = true


# a = 1: fall asleep (lying, not fainted, not in rain on open ground); a = 0: wake.
func _sleep(peer: int, want: int) -> void:
	if not _peer_key.has(peer) or _sleep_cfg.is_empty():
		return

	if want == 0:
		if not _forced_sleep(peer):
			_wake(peer, "")

		return

	if _asleep.has(peer):
		return

	if int(_stance.get(peer, 0)) != 3 or int(_strain.get(peer, {}).get("state", 0)) >= 2:
		return

	if _sleep_quality(peer) < 0.0:
		_say(peer, "Rain falls on you: find cover to sleep")
		return

	_asleep[peer] = {"rested": 0.0}
	_strain_sent.erase(peer)
	_say(peer, "You fall asleep")


func _wake(peer: int, why: String) -> void:
	if not _asleep.erase(peer):
		return

	_strain_sent.erase(peer)
	_say(peer, why if why != "" else "You wake")


# 1 under a roof or crown, the open-dry value in the open, -1 when rain reaches the sleeper (cannot sleep there).
func _sleep_quality(peer: int) -> float:
	var q: Dictionary = _sleep_cfg.get("quality", {})
	var covered: bool = cover_at.is_valid() and _peer_pos.has(peer) and float(cover_at.call(_peer_pos[peer])) > 0.5

	if covered:
		return float(q.get("covered", 1.0))

	if rain_now.is_valid() and float(rain_now.call()) >= float(_sleep_cfg.get("rain_wakes", 0.2)):
		return -1.0

	return float(q.get("open_dry", 0.6))


func stance_of(peer: int) -> int:
	return int(_stance.get(peer, 0))


# The server's own reading of whether a player is swimming (from their position and the water there,
# see terrain_server._swim_state): swimming is work whatever the client says.
func set_swimming(peer: int, swimming: bool) -> void:
	_swimming[peer] = swimming


# The server's own reading of whether a player's head is under water (terrain_server._head_under): the air runs down.
func set_head_under(peer: int, under: bool) -> void:
	_head_under[peer] = under


# Air left in seconds, or -1 when the head is above water (for tests and the status line).
func breath_of(peer: int) -> float:
	return float(_breath.get(peer, -1.0))


# One slow tick of breath (data/items/vitals.json "breath"): under water the air runs down, at the
# surface it is full at once; with none left the health drains.
func _breath_tick(peer: int, v: Dictionary, spent: float) -> void:
	var cfg: Dictionary = _vitals_cfg.get("breath", {})

	if cfg.is_empty():
		return

	var full: float = float(cfg.get("seconds", 60))

	if not bool(_head_under.get(peer, false)):
		if _breath.has(peer):
			_breath.erase(peer)

		_sync_breath(peer, -1)
		return

	var air: float = float(_breath.get(peer, full))
	var drain: float = SwimRules.breath_drain(float(_speed3.get(peer, 0.0)), float(cfg.get("rest_speed", 0.5)), float(cfg.get("rest_mult", 0.5)), float(cfg.get("hard_speed", 2.6)), float(cfg.get("hard_mult", 1.6)))
	air -= spent * drain

	if air <= 0.0:
		var was_out: bool = float(_breath.get(peer, full)) <= 0.0
		air = 0.0
		var floor_hp: float = 0.0 if bool(cfg.get("can_die", false)) else 1.0
		v["health"] = maxf(float(v["health"]) - float(cfg.get("drown_per_s", 6.0)) * spent, floor_hp)
		_asleep.erase(peer)

		if not was_out:
			_say(peer, "You are out of air")

	_breath[peer] = air
	_sync_breath(peer, int(ceil(air * 10.0)))


func _sync_breath(peer: int, tenths: int) -> void:
	# While diving, a change of half a second or more; the hide message once.
	var last: int = int(_breath_sent.get(peer, -1))

	if tenths == last or (tenths >= 0 and last >= 0 and absi(tenths - last) < 5 and tenths != 0):
		return

	_breath_sent[peer] = tenths

	if send_breath.is_valid():
		send_breath.call(peer, tenths)


func _note_motion(peer: int, position: Vector3) -> void:
	var now: int = Time.get_ticks_msec()
	var last: Array = _motion.get(peer, [])

	if not last.is_empty() and now > int(last[1]):
		var dt: float = float(now - int(last[1])) / 1000.0
		var speed: float = Vector2(position.x - last[0].x, position.z - last[0].z).length() / dt
		_speed3[peer] = lerpf(float(_speed3.get(peer, 0.0)), Vector3(position.x - last[0].x, position.y - last[0].y, position.z - last[0].z).length() / dt, clampf(dt * 2.0, 0.0, 1.0))
		var target: float = clampf((speed - 1.0) / 10.0, 0.0, 1.0)      # standing 0, walking 0.5, running 1

		if bool(_swimming.get(peer, false)):
			target = SwimRules.effort(speed)                              # strokes and treading water are work
		_exertion[peer] = lerpf(float(_exertion.get(peer, 0.0)), target, clampf(dt * 0.25, 0.0, 1.0))
		_moving[peer] = lerpf(float(_moving.get(peer, 0.0)), 1.0 if speed > 0.4 else 0.0, clampf(dt * 1.0, 0.0, 1.0))

		# Walking off stands a sitting or lying player up.
		if int(_stance.get(peer, 0)) >= 2 and speed > float(_exertion_cfg.get("stand_up_speed_mps", 1.5)) and int(_strain.get(peer, {}).get("state", 0)) < 2 and not _forced_sleep(peer):
			_stance[peer] = 0
			_asleep.erase(peer)
			_strain_sent.erase(peer)

	_motion[peer] = [position, now]


func _vitals_tick(spent: float) -> void:
	var cap: float = float(_vitals_cfg.get("stomach_cap_kcal", 2400))
	var health_max: float = float(_vitals_cfg.get("health_max", 100))
	var game_s: float = spent * GAME_RATE

	for peer in _peer_key:
		var v: Dictionary = _vitals.get(_peer_key[peer], {})

		if v.is_empty():
			continue

		var burn_per_day: float = float(_vitals_cfg.get("rest_kcal_per_kg_day", 22)) * float(v["weight"]) + float(_vitals_cfg.get("work_kcal_day", 1500)) * exertion_of(peer)
		var burn: float = burn_per_day * game_s / 86400.0
		v["fed"] = float(v["fed"]) - burn

		if float(v["fed"]) < 0.0:
			# Empty: the shortfall comes off the body.
			v["weight"] = clampf(float(v["weight"]) + float(v["fed"]) / float(_vitals_cfg.get("kcal_per_kg", 7700)), float(_vitals_cfg.get("min_weight_kg", 40)), float(_vitals_cfg.get("max_weight_kg", 150)))
			v["fed"] = 0.0

		var thirst: Dictionary = _vitals_cfg.get("thirst", {})
		var dry_per_day: float = float(thirst.get("rest_ml_day", 1000)) + float(thirst.get("work_ml_day", 1200)) * exertion_of(peer)
		v["wet"] = maxf(float(v["wet"]) - dry_per_day * game_s / 86400.0, 0.0)

		if float(v["fed"]) > 0.0 and float(v["wet"]) > 0.0:
			var regen: float = float(_vitals_cfg.get("health_regen_per_s", 0.05))

			if _asleep.has(peer):
				regen *= 1.0 + (float(_sleep_cfg.get("regen_mult", 2.0)) - 1.0) * maxf(_sleep_quality(peer), 0.0)

			v["health"] = clampf(float(v["health"]) + regen * spent, 0.0, health_max)

		_energy_tick(peer, v, spent, game_s)
		_breath_tick(peer, v, spent)

		if float(v["health"]) <= 0.0 and kill(peer, str(_death_cause.get(peer, "drowning"))):
			continue

		_sync_vitals(peer, false)
		_strain_tick(peer, spent)


# --- Food spoilage (Dave: gentle; data/items/spoilage.json) ---
# Age lives in the slot's wear field (tenths of a game hour), so nothing about saves or the wire changes: old stacks read as
# fresh. One slow step every tick_s ages every pack, chest, remains and loose item; a stack at its shelf life becomes rotten food.

func _spoil_units(place: String, base_units: float, season_mult: float) -> int:
	var cfg: Dictionary = table.spoilage()
	var mult: float = float(cfg.get("place_mult", {}).get(place, 1.0)) * season_mult
	_spoil_acc[place] = float(_spoil_acc.get(place, 0.0)) + base_units * mult
	var whole: int = int(_spoil_acc[place])
	_spoil_acc[place] -= float(whole)
	return whole


# Ages one inventory by `units`; true when anything changed.
func _spoil_inventory(inv, units: int) -> bool:
	var rotten: int = table.number_of(str(table.spoilage().get("rotten_item", "rotten_food")))
	var changed: bool = false

	for i in inv.SLOTS:
		var life: int = table.shelf_units(inv.numbers[i])

		if life <= 0:
			continue

		changed = true
		inv.wear[i] = mini(inv.wear[i] + units, 65535)

		if inv.wear[i] >= life:
			inv.numbers[i] = rotten
			inv.wear[i] = 0
			inv.counts[i] = mini(inv.counts[i], table.stack_of(rotten))

	return changed


func _spoil_tick(spent: float) -> void:
	var cfg: Dictionary = table.spoilage()

	if cfg.is_empty():
		return

	_spoil_in += spent
	var every: float = float(cfg.get("tick_s", 15))

	if _spoil_in < every:
		return

	var steps: int = int(_spoil_in / every)
	_spoil_in -= float(steps) * every
	var base: float = float(steps) * every * GAME_RATE / 3600.0 / float(cfg.get("unit_h", 0.1))
	var season_mult: float = float(cfg.get("season_mult", {}).get(str(season_now.call()), 1.0)) if season_now.is_valid() else 1.0
	var pack_units: int = _spoil_units("pack", base, season_mult)
	var peer_of_key: Dictionary = {}

	for peer in _peer_key:
		peer_of_key[_peer_key[peer]] = peer

	if pack_units > 0:
		for key in _inventories:
			var peer: int = int(peer_of_key.get(key, 0))
			var before: Array = _snapshot(_inventories[key]) if peer != 0 else []

			if _spoil_inventory(_inventories[key], pack_units):
				_dirty = true

				if peer != 0:
					_send_changes(peer, _inventories[key], before)

	var kind_of_uid: Dictionary = {}

	for id in _items:
		if _items[id].has("struct") and _items[id]["struct"].has("uid"):
			kind_of_uid[int(_items[id]["struct"]["uid"])] = str(_items[id]["struct"]["kind"])

	var place_units: Dictionary = {}

	for uid in _chests:
		var kind: String = str(kind_of_uid.get(uid, "chest"))

		if not place_units.has(kind):
			place_units[kind] = _spoil_units(kind, base, season_mult)

		if int(place_units[kind]) > 0 and _spoil_inventory(_chests[uid], int(place_units[kind])):
			_dirty = true

	var ground_units: int = _spoil_units("ground", base, season_mult)
	var rotten_n: int = table.number_of(str(cfg.get("rotten_item", "rotten_food")))

	if ground_units > 0:
		for id in _items:
			var it: Dictionary = _items[id]

			if it.has("struct") or it.has("fire") or it.has("tree") or it.has("boulder"):
				continue

			var life: int = table.shelf_units(int(it["number"]))

			if life <= 0:
				continue

			it["wear"] = int(it.get("wear", 0)) + ground_units
			_dirty = true

			if int(it["wear"]) >= life:
				it["number"] = rotten_n
				it["wear"] = 0


# --- Death and remains (Dave: DESIGN_IDEAS.md 6.1; data/items/death.json) ---
# A character whose health reaches zero dies: the whole pack goes onto a remains record where they fell (server-owned,
# a chest with no lid that only the owner may open for the first day), their vitals start over, and they are put back at
# the spawn point. Luck, fitness and skills are kept; placed things stay where they are.

func _unix() -> float:
	return float(unix_now.call()) if unix_now.is_valid() else Time.get_unix_time_from_system()


func _remains_age(it: Dictionary) -> float:
	if str(it["struct"]["kind"]) != "remains":
		return 0.0

	return clampf((_unix() - float(it["struct"].get("born", 0.0))) / maxf(float(_death_cfg.get("gone_s", 604800)), 1.0), 0.0, 1.0)


# Row state clients draw by: 11 fresh remains (day 1, owner only), 12 once anyone may take the gear.
func _struct_state(it: Dictionary) -> int:
	var state: int = int(_structures.get(str(it["struct"]["kind"]), {}).get("state", 5))

	if state == 11 and _unix() - float(it["struct"].get("born", 0.0)) >= float(_death_cfg.get("owner_only_s", 86400)):
		return 12

	return state


func _may_open_remains(peer: int, it: Dictionary) -> bool:
	return str(it["struct"].get("owner", "")) == str(_peer_key.get(peer, "?")) or _unix() - float(it["struct"].get("born", 0.0)) >= float(_death_cfg.get("owner_only_s", 86400))


func remains_ids() -> Array:
	var out: Array = []

	for id in _items:
		if _items[id].has("struct") and str(_items[id]["struct"]["kind"]) == "remains":
			out.append(id)

	return out


# The character dies. Returns false when there is nobody to kill (no such player, no position yet, death switched off).
func kill(peer: int, cause: String) -> bool:
	var key: String = str(_peer_key.get(peer, ""))
	var inv = inventory_of(peer)

	if key == "" or inv == null or not _peer_pos.has(peer) or _death_cfg.is_empty() or not _structures.has("remains"):
		return false

	var pos: Vector3 = _peer_pos[peer]
	var ground: float = float(ground_height.call(pos.x, pos.z)) if ground_height.is_valid() else NAN
	var cave: bool = not is_nan(ground) and pos.y < ground - 1.5   # underground: keep the spot, the surface above is not theirs
	var spot: Vector3 = pos if (is_nan(ground) or cave) else Vector3(pos.x, ground, pos.z)
	var uid: int = _next_uid
	_next_uid += 1
	var chest = InventoryScript.new(table)
	chest.from_json_array(inv.to_json_array())
	_chests[uid] = chest
	_items[_next_id] = {"number": table.number_of("remains"), "count": 1, "pos": spot, "left": 1.0e9, "struct": {"kind": "remains", "yaw": float(randi() % 360), "uid": uid, "owner": key, "born": _unix(), "cave": cave}}   # luck-exempt: a body's facing
	_next_id += 1
	inv.from_json_array(InventoryScript.new(table).to_json_array())
	send_full.call(peer, inv.to_bytes())

	# Start over: vitals, strain, sleep, breath. Luck, fitness and skills live in characters.json and stay.
	_vitals[key] = _new_vitals()
	_strain.erase(peer)
	_strain_sent.erase(peer)
	_asleep.erase(peer)
	_breath.erase(peer)
	_head_under.erase(peer)
	_exertion[peer] = 0.0
	_stance[peer] = 0
	_work_until.erase(peer)
	_death_cause.erase(peer)
	_energy_sent.erase(peer)
	_peer_pos[peer] = respawn_point
	_motion.erase(peer)
	_sync_breath(peer, -1)
	_sync_vitals(peer, true)
	_dirty = true

	if send_died.is_valid():
		send_died.call(peer, cause, respawn_point)

	return true


# Once in a while: clean up remains that have run their seven days and put the others back on the surface when the ground
# under them has changed (digging, a fill). The record never moves anywhere else; the sinking is only a drawing offset.
func _remains_tick(spent: float) -> void:
	_remains_check_in -= spent

	if _remains_check_in > 0.0 or _death_cfg.is_empty():
		return

	_remains_check_in = float(_death_cfg.get("recheck_s", 30))
	var gone_s: float = float(_death_cfg.get("gone_s", 604800))

	for id in remains_ids():
		var it: Dictionary = _items[id]

		if _unix() - float(it["struct"].get("born", 0.0)) >= gone_s:
			_chests.erase(int(it["struct"].get("uid", 0)))
			_items.erase(id)
			_dirty = true
			continue

		if bool(it["struct"].get("cave", false)) or not ground_height.is_valid():
			continue

		var ground: float = float(ground_height.call(it["pos"].x, it["pos"].z))

		if not is_nan(ground) and absf(ground - it["pos"].y) > 0.25:
			it["pos"].y = ground
			_dirty = true


# --- Fall damage (job 62) ---
# The client reports a landing from at least the sound threshold; the server turns the drop into damage (data/items/vitals.json
# "fall"): nothing under safe_m, per_m health per metre beyond it, a faint from faint_m. Health never goes below 1 (nothing kills yet).
# A client that stays silent only spares itself; reports are limited to one per 2 s and a drop is capped at 60 m.
func _fall(peer: int, centimetres: int) -> void:
	var cfg: Dictionary = _vitals_cfg.get("fall", {})
	var v: Dictionary = vitals_of(peer)
	var now: int = Time.get_ticks_msec()

	if cfg.is_empty() or v.is_empty() or now - int(_last_fall.get(peer, -100000)) < 2000:
		return

	var drop: float = clampf(float(centimetres) / 100.0, 0.0, 60.0)
	# The jumping skill (Dave 2026-10-21): a better jumper can drop further unhurt and takes less damage per metre beyond.
	# skill_factor is 1.0 until the skill system exists; it never makes a fall worse than the base numbers.
	var jump: float = maxf(skill_factor(peer, "fall"), 1.0)
	var safe_m: float = float(cfg.get("safe_m", 6.0)) * jump
	var damage: float = maxf(drop - safe_m, 0.0) * float(cfg.get("per_m", 8.0)) / jump

	if damage <= 0.0:
		return

	_last_fall[peer] = now
	v["health"] = maxf(float(v["health"]) - damage, 1.0)
	_say(peer, "The fall hurt")

	if not _forced_sleep(peer):
		_asleep.erase(peer)

	if drop >= float(cfg.get("faint_m", 12.0)) * jump and not _exertion_cfg.is_empty():
		_strain[peer] = {"s": float(_exertion_cfg.get("faint_at", 1.4)) + 0.05, "state": 1, "t": 0.0, "black": 1.0}

	_sync_vitals(peer, true)


# --- Crafting queue (Dave 2026-10-20, like Ark) ---
# Crafts line up per player and run one after another while the player is connected, screen open or not.
# Ingredients are taken when queued and refunded in full when an entry is cancelled (the running one too).
func _queue_of(peer: int) -> Dictionary:
	var key: String = str(_peer_key.get(peer, ""))

	if key == "":
		return {}

	if not _craft_queues.has(key):
		_craft_queues[key] = {"entries": [], "elapsed": 0.0}

	return _craft_queues[key]


func _queue_craft(peer: int, inv, recipe_number: int, count: int) -> void:
	var queue: Dictionary = _queue_of(peer)
	var recipe: Dictionary = recipes.recipe(recipe_number)

	if queue.is_empty() or recipe.is_empty() or not bool(recipe["known"]):
		return

	var entries: Array = queue["entries"]
	var merge: bool = not entries.is_empty() and int(entries[entries.size() - 1][0]) == recipe_number

	if entries.size() >= CRAFT_QUEUE_ENTRIES and not merge:
		_say(peer, "The crafting queue is full")
		return

	var taken: int = 0

	for n in range(clampi(count, 1, CRAFT_QUEUE_MAX_COUNT)):
		if not recipes.can_make(recipe_number, inv):
			break

		for need in recipe["needs"]:
			inv.remove(need[0], need[1])

		taken += 1

	if taken == 0:
		_say(peer, "You do not have what that needs")
		return

	if merge:
		entries[entries.size() - 1][1] = mini(int(entries[entries.size() - 1][1]) + taken, CRAFT_QUEUE_MAX_COUNT)
	else:
		entries.append([recipe_number, taken, recipe["needs"].duplicate(true)])

	_dirty = true
	_sync_craft_queue(peer)


func _refund_entry(peer: int, entry: Array) -> void:
	# The entry keeps its own ingredient list, so a refund works even if the recipe is later removed or renumbered.
	for need in entry[2]:
		give(peer, int(need[0]), int(need[1]) * int(entry[1]))


func _cancel_craft(peer: int, index: int) -> void:
	var queue: Dictionary = _queue_of(peer)

	if queue.is_empty() or index < 0 or index >= queue["entries"].size():
		return

	var entry: Array = queue["entries"][index]
	queue["entries"].remove_at(index)

	if index == 0:
		queue["elapsed"] = 0.0

	_refund_entry(peer, entry)
	_dirty = true
	_sync_craft_queue(peer)


func _craft_tick(spent: float) -> void:
	for peer in _peer_key:
		var queue: Dictionary = _craft_queues.get(_peer_key[peer], {})

		if queue.is_empty() or queue["entries"].is_empty():
			continue

		var head: Array = queue["entries"][0]
		var recipe: Dictionary = recipes.recipe(int(head[0]))

		if recipe.is_empty():
			queue["entries"].remove_at(0)
			queue["elapsed"] = 0.0
			_refund_entry(peer, head)
			_say(peer, "A craft was cancelled: that recipe is gone")
			_dirty = true
			_sync_craft_queue(peer)
			continue

		queue["elapsed"] = float(queue["elapsed"]) + spent

		if float(queue["elapsed"]) < float(recipe.get("craft_s", 3.0)) / skill_factor(peer, "craft"):
			continue

		queue["elapsed"] = 0.0
		var inv = inventory_of(peer)

		# A kept tool that is no longer there stops the craft: the entry is refunded.
		var tools_ok: bool = inv != null

		for keep in recipe.get("keeps", []):
			tools_ok = tools_ok and inv.has(keep[0], keep[1])

		if not tools_ok:
			queue["entries"].remove_at(0)
			_refund_entry(peer, head)
			_say(peer, "%s was cancelled: a tool is missing" % str(recipe.get("name", "That")))
		else:
			give(peer, int(recipe["gives"][0]), int(recipe["gives"][1]))
			head[1] = int(head[1]) - 1

			if int(head[1]) <= 0:
				queue["entries"].remove_at(0)

		_dirty = true
		_sync_craft_queue(peer)


func _sync_craft_queue(peer: int) -> void:
	if not send_craft_queue.is_valid():
		return

	var queue: Dictionary = _craft_queues.get(_peer_key.get(peer, ""), {})
	var entries: Array = queue.get("entries", [])
	var left_ms: int = 0

	if not entries.is_empty():
		var craft_s: float = float(recipes.recipe(int(entries[0][0])).get("craft_s", 3.0))
		left_ms = int(maxf(craft_s - float(queue["elapsed"]), 0.0) * 1000.0)

	send_craft_queue.call(peer, _pairs(entries), left_ms)


func _pairs(entries: Array) -> Array:
	var out: Array = []

	for entry in entries:
		out.append([int(entry[0]), int(entry[1])])

	return out


func craft_queue_of(peer: int) -> Array:
	return _pairs(_craft_queues.get(_peer_key.get(peer, ""), {}).get("entries", []))


func _save_craft_queues() -> void:
	var rows: Dictionary = {}

	for key in _craft_queues:
		if not _craft_queues[key]["entries"].is_empty():
			rows[key] = _craft_queues[key]

	_write_atomic("craft_queues.json", {"version": 1, "players": rows})


func _load_craft_queues() -> void:
	var parsed: Variant = _read_json_version("craft_queues.json", 1)

	if parsed == null:
		return

	for key in parsed.get("players", {}):
		var row: Dictionary = parsed["players"][key]
		var entries: Array = []

		for entry in row.get("entries", []):
			var needs: Array = []

			for need in entry[2] if entry.size() > 2 else []:
				needs.append([int(need[0]), int(need[1])])

			entries.append([int(entry[0]), clampi(int(entry[1]), 1, CRAFT_QUEUE_MAX_COUNT), needs])

		_craft_queues[str(key)] = {"entries": entries, "elapsed": float(row.get("elapsed", 0.0))}


# Over-exertion (data/items/exertion.json): strain climbs with effort above rest and falls below it. Over
# over_on the player is over-exerted (the client caps speed); past faint_at they faint, then wake slowly.
func _strain_tick(peer: int, spent: float) -> void:
	if _exertion_cfg.is_empty():
		return

	var st: Dictionary = _strain.get(peer, {})

	if st.is_empty():
		st = {"s": 0.0, "state": 0, "t": 0.0}
		_strain[peer] = st

	var cfg: Dictionary = _exertion_cfg
	var body: float = float(vitals_of(peer).get("weight", 75.0))
	var scale: float = pow(float(cfg.get("reference_body_kg", 75.0)) / maxf(body, 20.0), 0.5) * float(cfg.get("fitness", 1.0))
	var state: int = int(st["state"])
	var strain: float = float(st["s"])
	st["t"] = float(st["t"]) + spent

	# Sleep ends on its own: fainting, standing up, rain on an open sleeper, or rested for rested_s seconds.
	var sleep_quality: float = 0.0

	if _asleep.has(peer):
		sleep_quality = _sleep_quality(peer)

		if _forced_sleep(peer):
			sleep_quality = clampf(sleep_quality, 0.0, 1.0)
		elif state >= 2 or int(_stance.get(peer, 0)) != 3:
			_asleep.erase(peer)
			_strain_sent.erase(peer)
		elif sleep_quality < 0.0:
			_wake(peer, "Rain woke you")
		else:
			var rest: Dictionary = _asleep[peer]
			rest["rested"] = float(rest["rested"]) + spent if strain <= 0.0 else 0.0

			if float(rest["rested"]) >= float(_sleep_cfg.get("rested_s", 10.0)) and energy_of(peer) >= 99.0:
				_wake(peer, "You wake rested")

	if state == 2:
		if float(st["t"]) >= float(cfg.get("faint_s", 8.0)):
			state = 3
			st["t"] = 0.0
			st["after_faint"] = true
			st["black"] = 0.0
			strain = float(cfg.get("wake_strain", 1.1))
	elif state == 3:
		strain = maxf(strain - float(cfg.get("rest_effort", 0.52)) * float(cfg.get("fall_per_s", 0.05)) * float(cfg.get("wake_fall_mult", 0.4)) * spent, 0.0)

		if float(st["t"]) >= float(cfg.get("wake_s", 12.0)):
			state = 1 if strain >= float(cfg.get("over_off", 0.75)) * scale else 0

			if state == 0:
				st["after_faint"] = false
			st["t"] = 0.0
	else:
		var diff: float = effort_of(peer) - float(cfg.get("rest_effort", 0.52))
		var rate: float = float(cfg.get("rise_per_s", 0.02)) * fitness_rise_mult(peer) if diff > 0.0 else float(cfg.get("fall_per_s", 0.05))

		# Slower to come down while still racing after a faint.
		if diff < 0.0 and bool(st.get("after_faint", false)):
			rate *= float(cfg.get("wake_fall_mult", 0.4))

		var stance: int = int(_stance.get(peer, 0))

		if diff < 0.0 and stance == 2:
			rate *= float(cfg.get("sit_fall_mult", 2.0))
		elif diff < 0.0 and stance == 3:
			rate *= float(cfg.get("lie_fall_mult", 3.0)) + (maxf(float(_sleep_cfg.get("strain_mult", 6.0)) - float(cfg.get("lie_fall_mult", 3.0)), 0.0) * sleep_quality if _asleep.has(peer) else 0.0)

		var before: float = strain
		strain = maxf(strain + diff * rate * spent, 0.0)

		# Standing under a heavy load only rests down to a floor (about half at the limit); sitting or lying has none.
		if diff < 0.0 and stance < 2:
			strain = maxf(strain, minf(before, float(cfg.get("stand_load_floor", 0.5)) * minf(_load_ratio(peer), 1.0)))

		if state == 0 and strain >= float(cfg.get("over_on", 1.0)) * scale:
			state = 1
		elif state == 1 and strain < float(cfg.get("over_off", 0.75)) * scale:
			state = 0
			st["after_faint"] = false

		# Blacking out is a smooth build-up, not a step (Dave 2026-10-21): past the faint threshold "black" climbs, slowly right
		# at the threshold and faster the further strain overshoots it (a straight line in the overshoot, no steps); under the
		# threshold it drains away. When it reaches 1 the character lies down unconscious.
		var threshold: float = float(cfg.get("faint_at", 1.4)) * scale
		var black: float = float(st.get("black", 0.0))
		var blackout: Dictionary = cfg.get("blackout", {})

		if strain >= threshold and state <= 1:
			black = minf(black + _blackout_rate(strain / threshold - 1.0, blackout) * spent, 1.0)
		else:
			black = maxf(black - spent / maxf(float(blackout.get("recover_s", 6.0)), 0.1), 0.0)

		st["black"] = black

		if black >= 1.0 and state <= 1:
			state = 2
			st["t"] = 0.0
			_stance[peer] = 3

	st["s"] = strain
	st["state"] = state
	_train_fitness(peer, state == 1, spent)
	var fade: float = 0.0

	if state <= 1:
		fade = float(st.get("black", 0.0))                      # the blackout coming on, 0 to 1
	elif state == 2:
		var vision: float = float(cfg.get("vision_frac", 0.625))
		fade = vision + (1.0 - vision) * clampf(float(st["t"]) / float(cfg.get("faint_s", 8.0)), 0.0, 1.0)
	elif state == 3:
		fade = 1.0 - clampf(float(st["t"]) / float(cfg.get("wake_s", 12.0)), 0.0, 1.0)

	var points: Array = [int(strain * 50.0) * 20, state, int(fade * 50.0) * 20, int(_stance.get(peer, 0)) | (4 if _asleep.has(peer) else 0) | (8 if _forced_sleep(peer) else 0)]

	if send_strain.is_valid() and _strain_sent.get(peer, []) != points:
		_strain_sent[peer] = points
		send_strain.call(peer, points[0], points[1], points[2], points[3])


# How fast the blackout builds, per second, for an overshoot of the faint threshold (0 = right at it, as a fraction of it):
# 1 / slow_s at the threshold, rising in a straight line to 1 / fast_s at `margin` over it and beyond.
func _blackout_rate(overshoot: float, blackout: Dictionary) -> float:
	var slow: float = 1.0 / maxf(float(blackout.get("slow_s", 14.0)), 0.1)
	var fast: float = 1.0 / maxf(float(blackout.get("fast_s", 1.5)), 0.1)
	return lerpf(slow, fast, clampf(overshoot / maxf(float(blackout.get("margin", 0.25)), 0.001), 0.0, 1.0))


func strain_of(peer: int) -> Dictionary:
	return _strain.get(peer, {})


func _vitals_points(v: Dictionary) -> Array:
	var cap: float = float(_vitals_cfg.get("stomach_cap_kcal", 2400))
	var wet_cap: float = float(_vitals_cfg.get("thirst", {}).get("cap_ml", 2400))
	return [int(ceil(clampf(float(v["fed"]) / cap, 0.0, 1.0) * 100.0)), int(floor(float(v["health"]))), int(round(float(v["weight"]) * 10.0)), int(ceil(clampf(float(v["wet"]) / wet_cap, 0.0, 1.0) * 100.0))]


func _sync_vitals(peer: int, force: bool) -> void:
	var v: Dictionary = vitals_of(peer)

	if v.is_empty() or not send_vitals.is_valid():
		return

	var now_points: Array = _vitals_points(v)

	if force or _vitals_sent.get(peer, []) != now_points:
		_vitals_sent[peer] = now_points
		send_vitals.call(peer, now_points[0], now_points[1], now_points[2], now_points[3], luck_of(peer), fitness_of(peer))
		_dirty = true


func _container_cap(number: int) -> int:
	return int(table.entry(table.id_of(number)).get("capacity_ml", 0)) if number > 0 else 0


# Use on a water container: one mouthful (thirst.drink_ml) out of what it holds.
func _drink_from_container(peer: int, inv, slot: int, v: Dictionary) -> void:
	var thirst: Dictionary = _vitals_cfg.get("thirst", {})
	var now: int = Time.get_ticks_msec()

	if now - int(_last_drink.get(peer, -100000)) < int(thirst.get("drink_pace_ms", 900)):
		return

	if inv.wear[slot] <= 0:
		_say(peer, "It is empty.")
		return

	var cap: float = float(thirst.get("cap_ml", 2400))

	if float(v["wet"]) >= cap - 1.0:
		_say(peer, "You have had enough water.")
		return

	_last_drink[peer] = now
	var sip: int = mini(int(thirst.get("drink_ml", 300)), inv.wear[slot])
	var before: Array = _snapshot(inv)
	inv.wear[slot] -= sip
	v["wet"] = minf(float(v["wet"]) + float(sip), cap)
	_send_changes(peer, inv, before)
	_sync_vitals(peer, true)
	_dirty = true


func _eat(peer: int, inv, slot: int) -> void:
	var v: Dictionary = vitals_of(peer)

	if v.is_empty() or slot < 0 or slot >= inv.SLOTS or inv.numbers[slot] == 0:
		return

	if _container_cap(inv.numbers[slot]) > 0:
		_drink_from_container(peer, inv, slot, v)
		return

	var now: int = Time.get_ticks_msec()

	if now - int(_last_eat.get(peer, -100000)) < int(_vitals_cfg.get("eat_pace_ms", 800)):
		return

	var item_id: String = table.id_of(inv.numbers[slot])
	var spoil: Dictionary = table.spoilage()

	if not spoil.is_empty() and item_id == str(spoil.get("rotten_item", "")):
		_last_eat[peer] = now
		inv.take_from_slot(slot, 1)
		var sick: Dictionary = spoil.get("sick", {})
		v["health"] = maxf(float(v["health"]) - float(sick.get("health", 10)), 1.0)
		v["wet"] = maxf(float(v["wet"]) - float(sick.get("wet_ml", 300)), 0.0)
		_say(peer, str(sick.get("say", "It was rotten.")))
		_sync_vitals(peer, true)
		return

	if _unfit.has(item_id):
		_last_eat[peer] = now
		_say(peer, "It tastes bitter and wrong. You spit it out.")
		return

	var aid: Dictionary = VitalsRules.energy_aid(item_id, _vitals_cfg)

	if not aid.is_empty():
		_use_energy_aid(peer, inv, slot, v, aid)
		return

	var kcal: int = VitalsRules.food_value(item_id, _vitals_cfg)
	var heal: int = VitalsRules.heal_value(item_id, _vitals_cfg)
	var ml: int = VitalsRules.drink_value(item_id, _vitals_cfg)

	if kcal <= 0 and heal <= 0 and ml <= 0:
		_say(peer, "You cannot eat that.")
		return

	var wet_cap: float = float(_vitals_cfg.get("thirst", {}).get("cap_ml", 2400))

	if ml > 0 and kcal <= 0 and heal <= 0 and float(v["wet"]) >= wet_cap - 1.0:
		_say(peer, "You have had enough water.")
		return

	var cap: float = float(_vitals_cfg.get("stomach_cap_kcal", 2400))
	var limit: float = cap * (1.0 + float(_vitals_cfg.get("overeat_allowance", 0.25)))

	if kcal > 0 and heal <= 0 and float(v["fed"]) >= limit - 1.0:
		_say(peer, "You cannot eat another bite.")
		return

	if heal > 0 and kcal <= 0 and float(v["health"]) >= float(_vitals_cfg.get("health_max", 100)) - 0.5:
		_say(peer, "You are not hurt.")
		return

	_last_eat[peer] = now
	kcal = int(round(float(kcal) * (0.5 + 0.5 * table.freshness(inv.numbers[slot], inv.wear[slot]))))   # stale food feeds less
	inv.take_from_slot(slot, 1)
	var total: float = float(v["fed"]) + float(kcal)

	if total > cap:
		# Beyond a full stomach the surplus goes to the body.
		v["weight"] = clampf(float(v["weight"]) + (total - cap) * float(_vitals_cfg.get("gain_efficiency", 0.8)) / float(_vitals_cfg.get("kcal_per_kg", 7700)), float(_vitals_cfg.get("min_weight_kg", 40)), float(_vitals_cfg.get("max_weight_kg", 150)))
		total = cap

	v["fed"] = total
	v["wet"] = minf(float(v["wet"]) + float(ml), wet_cap)
	v["health"] = clampf(float(v["health"]) + float(heal), 0.0, float(_vitals_cfg.get("health_max", 100)))
	_sync_vitals(peer, true)


# --- Luck (job 77) ---
# Each character has a luck number, -10 to +10, rolled once when the server first sees the key (the creation screen will
# send a chosen value instead) and stored in characters.json. Every server roll that a player takes part in goes through
# roll_chance / roll_amount / fate so luck can nudge it (data/items/luck.json strength; 0 switches luck off).
func luck_of(peer: int) -> int:
	return int(_characters.get(_peer_key.get(peer, ""), {}).get("luck", 0))


func _luck_strength() -> float:
	return float(_luck_cfg.get("strength", 0.04))


# The creation roll: the sum of dice rolls of -faces to +faces, centred on 0.
func _create_luck() -> int:
	var make: Dictionary = _luck_cfg.get("creation", {})
	var total: int = 0

	for n in int(make.get("dice", 2)):
		total += _fate_rng.randi_range(-int(make.get("faces", 5)), int(make.get("faces", 5)))   # luck-exempt: the creation roll itself

	return clampi(total, -LuckScript.MAX, LuckScript.MAX)


# True with probability p, nudged by the peer's luck. `rng` is the caller's own stream (often seeded so a plant or a
# trunk gives the same on every server run); the draw is taken from it so replay stays the same.
func roll_chance(peer: int, rng: RandomNumberGenerator, p: float) -> bool:
	return LuckScript.chance(rng.randf(), p, luck_of(peer), _luck_strength())   # luck-exempt: the draw that luck then nudges


# A whole number from lo to hi, the top end likelier when lucky.
func roll_amount(peer: int, rng: RandomNumberGenerator, lo: int, hi: int) -> int:
	return LuckScript.amount(rng.randf(), lo, hi, luck_of(peer), _luck_strength())   # luck-exempt: the draw that luck then nudges


# The hook for later fate events (a fall going well or badly, a fight, a rare thing in the world): true when fate favours
# the peer with base probability p. Counted by kind so we can see what luck touches.
func fate(peer: int, kind: String, p: float) -> bool:
	fate_counts[kind] = int(fate_counts.get(kind, 0)) + 1
	return LuckScript.chance(_fate_rng.randf(), p, luck_of(peer), _luck_strength())   # luck-exempt: the fate stream


func _save_characters() -> void:
	_write_atomic("characters.json", {"version": 1, "players": _characters})


# Fitness (Dave 2026-10-21), see data/items/fitness.json: scales how fast exertion rises, a whole number min..max.
func _load_fitness_config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/fitness.json"))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _fitness_min() -> int:
	return int(_fitness_cfg.get("min", -10))


func _fitness_max() -> int:
	return int(_fitness_cfg.get("max", 10))


func _fitness_default() -> int:
	return clampi(int(_fitness_cfg.get("default", 0)), _fitness_min(), _fitness_max())


func fitness_of(peer: int) -> int:
	var row: Dictionary = _characters.get(_peer_key.get(peer, ""), {})
	return clampi(int(row.get("fitness", _fitness_default())) + int(float(row.get("train", 0.0))), _fitness_min(), _fitness_max())


# Fitness trains slowly (Dave 2026-10-21, fitness.json "train"): time spent over-exerted adds to the character's training, a point
# per winded_s_per_point seconds up to max_gain over the creation value; time not winded takes it back, a point per
# decay_s_per_point seconds, never below the creation value. The whole-number change is sent to the client.
func _train_fitness(peer: int, winded: bool, spent: float) -> void:
	var cfg: Dictionary = _fitness_cfg.get("train", {})
	var row: Dictionary = _characters.get(_peer_key.get(peer, ""), {})

	if cfg.is_empty() or row.is_empty():
		return

	var before: int = fitness_of(peer)
	var train: float = float(row.get("train", 0.0))

	if winded:
		train = minf(train + spent / maxf(float(cfg.get("winded_s_per_point", 1800.0)), 1.0), float(cfg.get("max_gain", 5)))
	else:
		var step: float = spent / maxf(float(cfg.get("decay_s_per_point", 14400.0)), 1.0)
		train = maxf(train - step, 0.0) if train > 0.0 else minf(train + step, 0.0)   # back toward the creation value from either side

	row["train"] = train
	_dirty = true

	if fitness_of(peer) != before:
		_vitals_sent.erase(peer)
		_sync_vitals(peer, true)


# The shared multiplier on the exertion rise: below 1 for the fit, above 1 for the unfit.
func fitness_rise_mult(peer: int) -> float:
	return exp(-float(fitness_of(peer)) * float(_fitness_cfg.get("strength", 0.05)))


# Hook for training (not designed yet): set a character's fitness, clamped, saved with the character, sent to the client.
func set_fitness(peer: int, value: int) -> void:
	var key: String = _peer_key.get(peer, "")

	if not _characters.has(key):
		return

	_characters[key]["fitness"] = clampi(value, _fitness_min(), _fitness_max())
	_characters[key]["train"] = 0.0
	_dirty = true
	_vitals_sent.erase(peer)
	_sync_vitals(peer, true)


# Energy supplements wear the body down (Dave 2026-10-21): training points lost, down to energy.json fitness_max_loss under the base.
func _fitness_cost(peer: int, points: float) -> void:
	var row: Dictionary = _characters.get(_peer_key.get(peer, ""), {})

	if row.is_empty() or points <= 0.0:
		return

	var before: int = fitness_of(peer)
	row["train"] = maxf(float(row.get("train", 0.0)) - points, -float(_energy_cfg.get("fitness_max_loss", 3.0)))
	_dirty = true

	if fitness_of(peer) != before:
		_vitals_sent.erase(peer)
		_sync_vitals(peer, true)


func _load_characters() -> void:
	var parsed: Variant = _read_json_version("characters.json", 1)

	if parsed == null:
		return

	for key in parsed.get("players", {}):
		_characters[str(key)] = {
			"luck": clampi(int(parsed["players"][key].get("luck", 0)), -LuckScript.MAX, LuckScript.MAX),
			"fitness": clampi(int(parsed["players"][key].get("fitness", _fitness_default())), _fitness_min(), _fitness_max()),
			"train": clampf(float(parsed["players"][key].get("train", 0.0)), -10.0, 10.0),
		}


# Drink from the water at the player's feet (ACT_DRINK): one mouthful of thirst.drink_ml, paced like eating. The scene's water_near says whether water lies within reach.
func _drink_water(peer: int, slot: int = -1, inv = null) -> void:
	var v: Dictionary = vitals_of(peer)

	if v.is_empty() or not _peer_pos.has(peer):
		return

	var thirst: Dictionary = _vitals_cfg.get("thirst", {})
	var now: int = Time.get_ticks_msec()

	if now - int(_last_drink.get(peer, -100000)) < int(thirst.get("drink_pace_ms", 900)):
		return

	if not water_near.is_valid() or not bool(water_near.call(_peer_pos[peer], float(thirst.get("reach_m", 3.0)))):
		_reject(peer, 0)
		return

	# A water container in hand with room is filled instead (job 89); a full one lets you drink from the water as before.
	if inv != null and slot >= 0 and slot < inv.SLOTS and inv.numbers[slot] != 0:
		var room: int = _container_cap(inv.numbers[slot]) - inv.wear[slot]

		if _container_cap(inv.numbers[slot]) > 0 and room > 0:
			_last_drink[peer] = now
			var before_fill: Array = _snapshot(inv)
			inv.wear[slot] += mini(int(thirst.get("fill_ml", 500)), room)
			_send_changes(peer, inv, before_fill)
			_dirty = true
			return

	var cap: float = float(thirst.get("cap_ml", 2400))

	if float(v["wet"]) >= cap - 1.0:
		_say(peer, "You have had enough water.")
		return

	_last_drink[peer] = now
	v["wet"] = minf(float(v["wet"]) + float(thirst.get("drink_ml", 300)), cap)
	_sync_vitals(peer, true)


func _save_vitals() -> void:
	_write_atomic("vitals.json", {"version": 1, "players": _vitals})


func _load_vitals() -> void:
	var parsed: Variant = _read_json_version("vitals.json", 1)

	if parsed == null:
		return

	for key in parsed.get("players", {}):
		var row: Dictionary = parsed["players"][key]
		var fresh: Dictionary = _new_vitals()
		_vitals[str(key)] = {"fed": float(row.get("fed", fresh["fed"])), "weight": float(row.get("weight", fresh["weight"])), "health": float(row.get("health", fresh["health"])), "wet": float(row.get("wet", fresh["wet"])), "energy": clampf(float(row.get("energy", 100.0)), 0.0, 100.0)}
