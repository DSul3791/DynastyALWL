extends RefCounted

# The server's items: every player's inventory and the things lying on the ground.
# The server owns all of it; clients only ask (terrain_net.gd inventory_action) and the
# server checks every request. Saved to inventories.json and world_items.json in the
# store folder: a "version" field, written to a temp file then renamed, and a file that
# cannot be read is kept as .bad and replaced by an empty one.
#
# Until accounts exist an inventory is filed under the key the client made for itself.

const FlameRules := preload("res://src/shared/flame_rules.gd")
const WaterFlowScript := preload("res://src/stream/water_flow.gd")
const ShoreRules := preload("res://src/shared/shore_rules.gd")
const SnowWalk := preload("res://src/shared/snow_walk.gd")   # walking on snow and snowshoes (Part C plan 7)
const FellPose := preload("res://src/flora/fell_pose.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const RecipeTableScript := preload("res://src/shared/recipe_table.gd")
const LuckScript := preload("res://src/shared/luck.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const FloraLayout := preload("res://src/worldgen/runtime/flora_layout.gd")
const CoverScript := preload("res://src/shared/cover.gd")
const CaveClimate := preload("res://src/shared/cave_climate.gd")
const DrinkRules := preload("res://src/shared/drink_rules.gd")
const BogIron := preload("res://src/shared/bog_iron.gd")   # bog iron under fens and marshes (digging.json bog_iron)
const SwimRules := preload("res://src/shared/swim.gd")
const StructureLookScript := preload("res://src/shared/structure_look.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const VERSION := 1
const INVENTORY_VERSION := 2            # 2 added wear per slot; version 1 files load with zero wear
const SHOWROOM_CAP := 300                # most items one showroom fill places
const SHOWROOM_PATH := "res://data/items/showroom.json"
const MAX_DROPPED_NEAR := 64             # loose dropped items allowed within DROP_CROWD_M of a new drop
const DROP_CROWD_M := 12.0
const MERGE_M := 1.0                     # a stackable drop landing this close to the same kind on the ground joins it (Dave 2026-10-23, rock piles)
const PILE_MIN := 6                      # a ground item holding this many is a pile (the client draws it from the count)
const PILE_HANDFUL := 5                  # one E on a pile takes this many when the item has no "pile" row in items.json
const PILE_CAP := 100000                 # most one ground item holds; more starts a second pile beside it
const PILE_LIFETIME_S := 7200.0          # a pile lives this long after the last add or take (loose items keep WORLD_ITEM_LIFETIME_S)
const WORLD_ITEM_LIFETIME_S := 1200.0    # real seconds until a dropped item despawns
const CHUNK_M := 256.0
const NEAR_M := 100.0                    # items this close are sent to a player
const PICKUP_M := 3.0
const DROP_REACH_M := 6.0                # a drop lands at most this far from where the server last saw the player
const SYNC_EVERY_S := 1.0
const SAVE_EVERY_S := 30.0
const DROPS_PATH := "res://data/items/drops.json"
const PICKUP_BATCH_PATH := "res://data/items/pickup_batch.json"   # sticks and leaves come up in batches (Dave 10 Nov 2026)
const REGROW_GAME_S := 3.0 * 86400.0     # a picked plant bears again after 3 game days
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
const PLANT_BUSH_REACH_M := 4.0         # a dug bush is planted this close (flat) to the player
const PLANT_BUSH_GAP_M := 1.0           # and no closer than this to another planted bush or sapling
const CHOP_RESET_MS := 60000             # a half-chopped tree heals after this long untouched
const SCATTER_PAD_M := 30.0             # how far past its own square the layout of a scatter cell reads the ground (water probe 24 m)
const SLOW_TICK_LOG_MS := 100.0          # an items tick this long logs its slow parts (Tyler's join-stall aid, 31 Oct 2026)
const SLOW_PART_LOG_MS := 10.0           # a part of such a tick this long is named in that line
const SCATTER_TICK_MAX_MS := 40.0       # the ground scatter stops laying out cells for the tick once this long has passed (the rest follows on the next sync)
const TRUNKS_PER_CHUNK := 32             # felled trunks (and as many stumps) lying in one flora chunk
const SPLIT_LIFETIME_S := 7.0 * 86400.0  # what a felled tree breaks into lies a real week, as its trunk would have (it rotted after a real week)
const FALL_SETTLE_MS := 2000             # a felled tree takes 1.5 s to topple on the client; it breaks into logs a moment after it lands
const ROT_GAME_S := 168.0 * 86400.0      # a trunk or stump rots away after a real week (168 game days)
const TREE_SAVE_VERSION := 1
const SAPLING_YOUNG_S := 3.0 * 86400.0   # game seconds until a sapling is a young tree
const SAPLING_GROWN_S := 12.0 * 86400.0  # ...and until it is a full grown tree (can be felled)
const SAPLINGS_PER_CHUNK := 64
const RESPAWN_RADIUS_M := 25.0           # a sapling comes only near a standing tree of the same species
const RESPAWN_PLACE_M := 6.0
const REGROW_EXCLUDE_M := 50.0           # no sapling is seeded within this of anything placed on the ground (BUG-013; Dave: tunable)
const RESPAWN_CHANCE := 0.5              # per rotted-away stump, rolled once from the seed and the spot
const FLORA_CHUNK_M := 256.0
const PROCESS_REACH_M := 4.0
const JAB_REACH_M := 3.0
const STRIKE_COOLDOWN_MS := 600
const CARCASS_REACH_M := 3.0
const CARCASS_LIFE_S := 7200.0          # 2 game days of real time
const PROCESS_COOLDOWN_MS := 450
const FIRE_USE_M := 3.5
const COOKING_PATH := "res://data/items/cooking.json"
const GatherRules := preload("res://src/shared/gather_rules.gd")
const SkillRules := preload("res://src/shared/skill_rules.gd")
const SkillWeb := preload("res://src/shared/skill_web.gd")
const PlacementRules := preload("res://src/shared/placement_rules.gd")
const CraftPlanner := preload("res://src/shared/craft_planner.gd")
const Interact := preload("res://src/shared/interact_rules.gd")
const CraftStock := preload("res://src/shared/craft_stock.gd")   # what a craft may draw on: the pack, ground within 12 m, own containers within 12 m
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
const BLUEPRINTS_PATH := "res://data/items/blueprints.json"
const SKILLS_PATH := "res://data/items/skills.json"
const FIRE_BURN_S := 480.0               # real seconds a fresh campfire burns (4 sticks, cooking.json start_burn_game_s)
const FIRE_LAID_S := 1800.0             # a laid fire (empty 8, or loaded and unlit 9) waits this long for the player
const POT_ATTACH_M := 2.0                # a campfire pot snaps onto a small fire this close to where it is put
const POT_ON_FIRE_M := 0.3               # a pot and a fire this close are one: the pot hangs over that fire (nothing is stored; position is the link)
const FIRE_STATE_SURVIVAL := 40         # lit fire states by tier (1 stays the campfire; cooking.json fire_tiers)
const FIRE_STATE_BONFIRE := 41
const FIRE_STATE_COALS := StructureLookScript.FIRE_COALS   # 76: after the flames, coals glowing (cooking.json coals; docs/design/fire_coals_design.md)...
const FIRE_STATE_ASH := StructureLookScript.FIRE_ASH       # 77: ...then warm ash, then cold ash (8)
const FIRE_OUT_S := 300.0                # a burnt-out or rained-out fire stays this long
const FIRE_MIN_GAP_M := 2.0               # fallbacks: structures.json "campfire" decides
const FIRES_PER_CHUNK := 8
const RAIN_PUTS_OUT := 0.2               # open fires go out when the rain is at least this strong
const RAIN_LIGHT_GRACE_S := 6.0             # an open fire lit in the rain burns this long before the rain puts it out (Dave 5 Nov 2026)
const COVER_RECHECK_S := 30.0

var table
var recipes
# Set by the server scene: how to talk to one peer.
var send_full: Callable        # (peer, bytes)
var send_slots: Callable       # (peer, bytes)
var send_purse: Callable       # (peer, copper total): the purse (protocol 61)
var send_carry: Callable       # (peer, item id or ""): the large log on the shoulder (protocol 64)
var send_reputation: Callable  # (peer, ids PackedStringArray, names PackedStringArray, points PackedInt32Array)
var _coins_cfg: Dictionary = {}
var _rep_cfg: Dictionary = {}
var send_received: Callable    # (peer, item id, count, source): one call per item gained (protocol 60)
const SRC_PICKUP := "pickup"
const SRC_GATHER := "harvest"
const SRC_CRAFT := "craft"
const SRC_REWARD := "quest"
var _gain_source: String = SRC_PICKUP   # who is adding right now; callers set it around give()
var _gain_quiet: bool = false        # wearing and taking off gear moves items without gaining any
var send_world_items: Callable # (peer, added Array, removed PackedInt32Array)
var ground_height: Callable    # (x, z) -> ground height in metres, or NAN; set by the server scene
var cave_scatter: Callable     # (cell Vector2i, cell_m) -> PackedFloat32Array, 5 floats per cave floor spot in that cell: x, y, z, kind (0 stone, 1 boulder), radius; set by the server scene
var world_seed: int = 0
var rain_now: Callable         # () -> rain strength 0 to 1 over the world now; set by the server scene
var send_notice: Callable      # (peer, text)
var send_marker_done: Callable # (peer, Vector3): a road marker is reached or dropped, the client takes its flag down
var standing_near: Callable    # (species name, position, radius) -> [position] of the nearest standing tree of that species, or []
var flora_changed: Callable    # (chunk Vector2i) -> a chunk's saplings or trees changed: refresh the server cache and the clients near it
var shrub_info: Callable       # (chunk Vector2i, id) -> {name, position, height} of a standing bush or shrub (placer or planted), or {}; set by the server scene
var tree_info: Callable        # (chunk Vector2i, id) -> {name, position, height, trunk} of a standing tree, or {}
var cut_tree: Callable         # (chunk Vector2i, id) -> true when the standing tree was removed (and clients told)
var fill_ground: Callable        # (centre, radius, material) -> bool: add ground (a fill) and tell everyone; false when it changed nothing
var dig_refusal: Callable        # () -> String: why the last dig changed nothing, shown to the player; set by the server scene
var dig_ground: Callable         # (centre, radius) -> void: cut a hole in the ground and tell everyone; set by the server scene
var trees_near: Callable        # (point, radius) -> Array of [chunk Vector2i, id int]: standing placer trees whose root is that close; set by the server scene
var trees_near_cached: Callable # (point, radius) -> Array of [position, species name]: the same trees from chunks already made only, cheap (the hint triggers); unset = trees_near
var trunks_near: Callable       # (point, radius) -> Array of [root position, trunk radius m, height m]: standing trunks an arrow can stick in (terrain_server _arrow_trunks)
var dig_support: Callable       # (base, radius, depth) -> share 0..1 of the ground under a tree not dug away; set by the server scene
var ground_material: Callable   # (x, z) -> the surface material's name there ("loam", "clay", "sand", ... or "rock"); set by the server scene, feeds dig yields
var rock_at: Callable          # (x, z) -> true when bare rock shows at the surface there (no soil cover); set by the server scene
var game_seconds: Callable      # () -> game clock seconds
var season_now: Callable        # () -> "spring" | "summer" | "autumn" | "winter"
var season_at: Callable         # (position) -> the season there (Weather.season_at: half a year off across the equator); unset: season_now
var skill_level: Callable         # (peer, skill id) -> level factor around 1.0; unset until the skill system exists, then every factor is 1.0
var _skills_cfg: Dictionary = {}
var send_reject: Callable        # (peer, reason 0 too far, 1 no tool, 2 pack full, 3 other)
var send_craft_queue: Callable   # (peer, [[recipe, crafts left], ...], ms left on the first)
var send_strain: Callable       # (peer, strain in thousandths, state 0 normal 1 over 2 fainted 3 waking, fade in thousandths, stance)
var send_breath: Callable       # (peer, seconds of air left in tenths, or -1 when the head is above water)
var send_vitals: Callable       # (peer, hunger percent, health, weight in tenths of a kg, thirst percent, luck, fitness)
var send_training: Callable     # (peer, today's training in percent of a fitness point) (protocol 92, Dave: fitness feedback on the Tab screen)
var water_depth_at: Callable       # (position) -> metres of water there (optional; unset: depth is not checked)
var water_kind_at: Callable        # (x, z) -> {"kind": brook | river | lake | pond | sea_shallow | sea_mid | sea_deep | "", "depth"} (server_fish_water.gd; optional)
var ice_cover_at: Callable       # (position) -> 0..1 ice cover on still water there (ice.gd); unset: no ice
var ice_moat_at: Callable        # (position) -> true in a thaw's shore moat (Kathleen frozen_water_look.md 4, #729): open water there, as off the ice; unset: none
var spring_ice_x: Callable       # (position) -> the ice's share by springs (Jamie #739): 0 on the open brook below a spring, 0.5 near a spring mouth or inflow, else 1; unset: 1
var _holes: Array = []            # ice fishing holes: {pos, owner key, until game seconds}
var _hole_blows: Dictionary = {}  # peer -> [blows, msec of the last]
var rock_near: Callable          # (position) -> the rocks.json name of the bedrock under a boulder there (TileTerrainData.bedrock_name_at), "" when unknown; set by the server scene (unset: no rock pieces)
var ore_near: Callable           # (position, reach in metres, ore names wanted, layer depth in metres) -> the ore (data/tables/resources.json) a boulder there is an outcrop of, "" when none; set by the server scene (unset: no ore)
var bog_deposit_at: Callable     # (x, z, digging.json bog_iron) -> BogIron.deposit_at on the baked tile there ({} when none); set by the server scene (unset: no bog iron)
var nests_near: Callable         # (position, reach in metres) -> Array of {id: String, kind: String, pos: Vector3}: bird nests near the point (data/items/nests.json); set by the fauna side (unset: no inland nests)
var water_near: Callable         # (position, reach in metres) -> true when water lies within reach of the position; set by the server scene (unset: no water anywhere)
var water_source: Callable       # (position, reach in metres) -> Array of DrinkRules rows within reach (springs, brooks, lakes, salt); vitals.json thirst.sources (docs/design/drinking_water_design.md)
var send_chest: Callable        # (peer, world id, bytes) a chest's contents to the player who opened it
var send_chest_info: Callable   # (peer, world id, keep_out, may_set): the open container's "keep out" tick and whether this player may change it (protocol 98)
var send_craft_stock: Callable  # (peer, numbers PackedInt32Array, counts PackedInt32Array): what a craft may use besides the pack (protocol 98)
var send_wheel_share: Callable  # (peer, at, yaw degrees, percent, why): the answer to ACT_WHEEL_ASK (protocol 105, _wheel_ask)
var send_step_to: Callable      # (peer, position, yaw radians): the server moved the player to a station to craft there (protocol 103, _step_to_station)
var send_favourites: Callable   # (peer, flags PackedByteArray): one byte per pack slot, 1 for a favourite (protocol 99)
var send_hotbar: Callable      # (peer, keys PackedInt32Array): the ten hotbar keys' item numbers (protocol 100)
var send_bulk_done: Callable    # (peer, kind, stacks moved, container count, container ids PackedInt32Array): a bulk button's result for the toast (protocol 99)
var roof_add: Callable          # (roof Array from Cover.box_roof) -> key; the server's cover index gets the lean-to's roof
var roof_remove: Callable       # (key)
var cover_at: Callable         # (position) -> 0.0 open, 1.0 under a tree's crown, 2.0 under a built roof or in a cave (Cover.at, or its stand-in); rain and sun cover from 0.5, wind shelter only from 1.5
var cave_mean_c: Callable      # (position) -> the cave air (C): the island's year mean at the position's height when it is inside a cave, NAN outside one (unset: never in a cave)
var year_mean_at: Callable     # (position) -> the year-mean air (C) at that spot and height (Climate.year_mean_c): a cold store's temperature
var cave_air: Callable         # (position) -> {"deep_c", "depth_m", "kind", "day_part_c"} inside a cave, {} outside: the mouth blend (docs/design/cave_climate_design.md)

var _dir: String = ""
var _inventories: Dictionary = {}   # key String -> Inventory
var _peer_key: Dictionary = {}      # peer -> key
var _head_under: Dictionary = {}    # peer -> true while the server reads their head as under water
var _breath: Dictionary = {}        # peer -> seconds of air left (only while the head is under water)
var _suffocate: Dictionary = {}     # peer -> seconds since the air ran out with the head still under (BUG-029); gone the moment the head is above water
var _breath_sent: Dictionary = {}   # peer -> tenths of a second last sent (-1 = hidden)
var _speed3: Dictionary = {}        # peer -> smoothed speed in m/s, vertical included (the breath drain)
var _cave_pool: Dictionary = {}     # peer -> true while swimming in a spring cave pool (icy; BUG-008)
var _swimming: Dictionary = {}      # peer -> true while the server reads them as swimming
var _soak: Dictionary = {}          # peer -> 0..1, how rain-soaked they are (warmth.json soak_*: rain wets, only shelter dries; Dave 5 Nov on the rain card)
var _peer_pos: Dictionary = {}      # peer -> Vector3 last reported
var _items: Dictionary = {}         # id int -> {number, count, pos Vector3, left float}
var _next_id: int = 1
var _known: Dictionary = {}         # peer -> {id: true} world items the peer was told about
var _sync_in: float = 0.0
var _save_in: float = SAVE_EVERY_S
var _dirty: bool = false
var _drops: Dictionary = {}
var _batch_cfg: Dictionary = {}       # data/items/pickup_batch.json
var _cooking: Dictionary = {}
var _structures: Dictionary = {}    # structures.json: kind -> definition
var _struct_gap_m: float = 2.5
var _blueprints: Dictionary = {}    # blueprints.json: number -> row (with its "id"), placed from the hammer instead of a kit item
var _blueprint_of_kit: Dictionary = {}   # kit item id -> blueprint number (a piece takes down into its materials, not a kit)
var _structures_cfg: Dictionary = {}   # the whole structures.json, for the shared placement rules
var _fire_gap_m: float = FIRE_MIN_GAP_M
var _fires_per_chunk: int = FIRES_PER_CHUNK
var support_changed: Callable            # (Vector3) -> void: a bracing support was placed, taken down or loaded; the tunnel watch restarts its grace windows near it
var _supports: Array = []                # bracing supports [pos, reach_m, strength, wear_s, floor, born_s], rebuilt on the main thread, read by the tunnel watch's worker under the mutex
var _supports_mutex: Mutex = Mutex.new()
var _chest_viewer: Dictionary = {}   # peer -> world id of the container they last opened (fresh contents are pushed while it changes)
var _chests: Dictionary = {}        # structure uid -> Inventory (server-owned contents, chests.json)
var _next_uid: int = 1
var _vitals_cfg: Dictionary = {}
var _carry_cfg: Dictionary = {}
var _exertion_cfg: Dictionary = {}
var _strain: Dictionary = {}        # peer -> {s: strain, state: 0..3, t: seconds in the state}
var _strain_sent: Dictionary = {}
var send_body: Callable             # (peer, bpm, seconds until awake, phase 0 awake 1 falling asleep 2 asleep or fainted 3 waking), protocol 59
var _body_sent: Dictionary = {}
var _waking: Dictionary = {}        # peer -> {t seconds into the wake fade}, after any sleep ended
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
var hit_animal_path: Callable        # (peer, from, to, damage) -> {"at": position} or {}: the first animal an arrow passes through is hurt (set by the server)
var animal_alarm: Callable           # (point, radius): a loud noise (a shot) startles animals near it (set by the server)
var hit_animal: Callable            # (peer, origin, direction, reach, damage) -> bool: set by the server, hits the animal in front
var _last_strike: Dictionary = {}
var _carcass_cfg: Dictionary = {}   # data/items/carcass.json
var _sick_cfg: Dictionary = {}      # data/items/sickness.json
var send_thought: Callable          # (peer, line id, text, kind): the inner voice
var send_remains: Callable          # (peer, rows [[position Vector3, seconds left], ...]): the owner's remains that still hold gear
var _remains_sent: Dictionary = {}
var send_worn: Callable             # (peer, PackedInt32Array of item numbers, one per body slot in clothing.json order)
var _worn_sent: Dictionary = {}
var _fishing: Dictionary = {}         # peer -> {phase "wait" or "bite", at msec, spot, cell, bites}
var _fish_stock: Dictionary = {}      # cell key -> [fish left, unix time of the last count]
var _last_fish: Dictionary = {}
var _fishing_cfg: Dictionary = {}
var _station_said: Dictionary = {}
var _torch_seen: Dictionary = {}    # peer -> msec of the last burning-torch report (ACT_TORCH_BURN): while recent, the torch bearer scares animals like a small fire
const TORCH_REPORT_MS := 3000
const TORCH_PROTECT_M := 8.0        # how far wolves keep from a bearer of a burning torch (a campfire's tiers are 5, 10, 20 m); Dave 6 Nov 2026: torches give the best protection of what you carry. Tune.
var _wear_carry: Dictionary = {}     # peer -> fraction of a wear point not yet charged (tool_care skill)
var _clothing: Dictionary = {}
var send_limp: Callable             # (peer, percent of normal speed, 100 = none)
var _limp_sent: Dictionary = {}
var send_sick: Callable             # (peer, game hours of sickness left, rounded up; 0 = well)
var _sick_sent: Dictionary = {}
var _last_dose: Dictionary = {}     # peer -> msec of the last medicine taken
var _symptom_in: Dictionary = {}    # peer -> real seconds to the next symptom
var send_skills: Callable           # (peer, attributes PackedInt32Array [strength, memory], rows Array [[skill index, working level 0..100, rusty 0/1], ...])
var _skills_sent: Dictionary = {}   # peer -> the rows last sent
var _skills_send_in: Dictionary = {}   # peer -> msec before which no skills message goes out
var _last_practice: Dictionary = {}   # peer -> {skill: msec of its last counted success}
var _warmth_cfg: Dictionary = {}    # data/items/warmth.json
var send_zone: Callable = Callable()        # (peer, biome id): tells the client which biome it stands in (protocol 76; ambience slots read it)
var zone_at: Callable = Callable()          # (position Vector3) -> biome id from the tile biome map, -1 when unknown; set by the server scene
var zone_clock: Callable = Callable()       # () -> msec; tests set it, the game uses Time.get_ticks_msec
var send_vent: Callable = Callable()        # (peer, Vector3): the nearest volcanic vent within VENT_RANGE_M, Vector3.INF when none (protocol 77; the volcano bed sits there)
var vent_near: Callable = Callable()        # (position Vector3) -> Vector3 of the nearest vent top within VENT_RANGE_M, INF when none; set by the server scene
var zone_samples: int = 0                   # biome lookups made, messages sent and microseconds spent (the report reads these)
var zone_messages: int = 0
var vent_messages: int = 0
var zone_usec: int = 0
var weather_now: Callable           # () -> the weather state (Weather.state: temp_c, wind, rain, snow, ...); set by the server scene
var insulation_of: Callable         # (peer) -> 0..1 share of body heat clothes keep; unset until clothing exists
var send_warmth: Callable           # (peer, warmth percent 0..100)
var _warmth_sent: Dictionary = {}
var _cold_level: Dictionary = {}    # peer -> 0 fine, 1 cold, 2 freezing (the message that was last shown)
var _spoil_in: float = 0.0          # real seconds since the last spoilage step
var _wood_in: float = 0.0           # real seconds since the last wet-wood step (_wood_tick)
var _wood_acc: float = 0.0          # unspent fraction of a drying unit (a tenth of a game hour)
var _spoil_acc: Dictionary = {}     # place class -> unspent fraction of an age unit
var respawn_point: Vector3 = Vector3.ZERO   # where a dead character comes back; set by the server scene
var send_died: Callable             # (peer, cause String, respawn point Vector3)
var send_hit_number: Callable        # (peer, at Vector3, amount int): floating damage text where a hit landed (protocol 85; the client shows it unless turned off in Gameplay)
var send_final_death: Callable       # (peer, cause String): a death with no respawn (death.json novice_grace); the new-character / heir flow is not built, so nothing sets this yet
var unix_now: Callable              # () -> real unix seconds (tests stand in a clock); unset: the system clock
var _death_cause: Dictionary = {}   # peer -> what is draining health to zero (drowning, ...)
var _remains_check_in: float = 0.0
var _energy_sent: Dictionary = {}
var _sleep_cfg: Dictionary = {}     # data/items/sleep.json
var _bed_cfg: Dictionary = {}       # data/items/bed.json (the rough bed's function)
var _bed_cache: Dictionary = {}     # peer -> {"id": world id of the bed under them or 0, "until": msec of the next look}
var _asleep: Dictionary = {}        # peer -> true while asleep (a lying player who held Z); {rested: seconds with no strain}
var _dig_cfg: Dictionary = {}       # data/items/digging.json
var _boulder_cfg: Dictionary = {}    # data/items/boulders.json
var _boulder_left: Dictionary = {}   # boulder key -> rough stones still in it (absent = untouched), saved in world_items.json
var _bog_left: Dictionary = {}       # bog iron deposit key "gi,gj" -> [ore left, game seconds it is counted to] (absent = untouched, full), saved in world_items.json "bog_iron"
const BOULDER_KEY := 1 << 50
const BOG_STATE := 229            # world-item row state of a bog iron deposit (next free structure state, 10 Nov 2026; no structure may take it)
const BOG_ID_BASE := 2000000000   # bog deposit world row ids count down from here (int32, far above _next_id), one per deposit key per run
const BOG_SAMPLE_M := 8.0         # the baked tile's sample spacing: deposits sit on samples (BogIron), so the scan steps by it
const BOG_WET_M := 0.05           # a deposit under more standing water than this is drawn wet
var _bog_ids: Dictionary = {}     # deposit key "gi,gj" -> its world row id
var _bog_scan: Dictionary = {}    # peer -> {"at": Vector2i sample the scan was made from, "found": [[key, pos, size], ...]}
const CAVE_KEY := 1 << 51       # cave floor stones and boulders: CAVE_KEY | cell x << 28 | cell y << 8 | entry (up to 256 a cell)
const CAVE_ITEMS_MAX := 256
const BOULDER_STATE := 10            # world-item row state of a boulder          # boulder keys live apart from the loose stones' keys
var _fate_rng: RandomNumberGenerator = RandomNumberGenerator.new()   # luck-exempt: the server's own fate stream, the fate() hook below
var fate_counts: Dictionary = {}    # fate kind -> times rolled (what luck has touched)
var _vitals: Dictionary = {}        # player key -> {hunger, health} floats
var _vitals_sent: Dictionary = {}   # peer -> [hunger, health] last whole points sent
var _training_sent: Dictionary = {}  # peer -> today's training percent last sent
var _exertion: Dictionary = {}      # peer -> smoothed 0..1 from movement
var _motion: Dictionary = {}        # peer -> [last position, msec]
var _path_cfg: Dictionary = {}      # data/path_speed.json: range_m and exertion_factor for moving on or near a path
var _on_path_cache: Dictionary = {} # peer -> [msec checked, bool]: whether a path patch lies within range_m (looked up at most once a second)
var _work_level: Dictionary = {}    # peer -> effort of the last tool work (data/items/exertion.json tool_effort)
var _work_until: Dictionary = {}    # peer -> msec until which tool work counts as effort
var _last_eat: Dictionary = {}      # peer -> msec
var _last_drink: Dictionary = {}    # peer -> msec of the last mouthful at the water
var _last_rain_s: float = -INF      # game seconds when it last rained (thirst.sources: intermittent brooks run for a day after rain)
var _unfit: Dictionary = {}         # item id -> true: yields of poisonous plants never feed anyone
var _last_use: Dictionary = {}      # peer -> msec of the last structure use
const CHEST_REACH_M := 4.0
const FishSchoolsScript := preload("res://src/server/server_fish.gd")
const BowScript := preload("res://src/stream/server_bow.gd")
const BowAim := preload("res://src/shared/bow_aim.gd")
const TrapsScript := preload("res://src/stream/server_traps.gd")
const VitalsRules := preload("res://src/shared/vitals_rules.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
const GAME_RATE := 24.0                 # game seconds per real second
var _slow_in: float = 0.0
const SLOW_TICK_S := 0.25
const HINT_EVERY_TICKS := 4   # the hint triggers are looked at every 4th slow tick (about once a second)
var gather_pace_ms: int = GATHER_PACE_MS
var _last_gather: Dictionary = {}   # peer -> msec
var _last_cook: Dictionary = {}     # peer -> msec
var _flora_by_name: Dictionary = {}   # flora table rows by species name (yields, seasons)
# While a trunk splits (split_trunk), its drops look only at these loose items near it: every drop scanned every world record twice (scatter
# included), a split of 10 logs and their extras ran 30 scans of the whole world in one frame (Dave 2 Nov: a pause as the trunk came apart).
var _drop_scope: Array = []
var _drop_scoped: bool = false
var _picked: Dictionary = {}          # "cx,cz,id" -> game seconds when last picked
var _fruit: Dictionary = {}           # fruit trees: chunk key -> {tree id -> [season stamp, pieces taken this season]} (drops.json "fruit_tree"); saved with the world items
var _stripped: Dictionary = {}        # "cx,cz" -> {plant id -> season stamp}: a berry bush picked this season stays, bare, until the season changes (saved in world_items.json "stripped")
var season_stamp: Callable            # set by the server: () -> int, game year * 4 + season index; changes once a season
var plant_stays: bool = false         # set by gather(): the last pick left the plant standing (berries only), so the caller must not cut it
var _arrows: Array = []             # arrows in the air: {peer, number, tip, damage, pos, vel, age, flown}
var _traps = null                   # server_traps.gd (snares), made in setup
var animals_near: Callable           # (point, radius) -> Array of {id, sp, pos}: the animals a snare can reach (set by the server)
var animal_lure: Callable            # (animal id, point) -> bool: the animal moves its home to a snare and grazes there (set by the server)
var animal_snare: Callable           # (animal id) -> bool: a snare closes on it, it leaves the world (set by the server)
var trail_strength: Callable         # (x, z) -> how worn the game trail is there, 0 to 1 (set by the server)
var _bow = null                     # server_bow.gd, made at the first shot
var _aim_rng: RandomNumberGenerator = RandomNumberGenerator.new()   # luck-exempt: the bow's aim spread stream (luck then nudges each draw, _shoot)
var _last_shot: Dictionary = {}     # peer -> msec
var _flights: Array = []            # thrown things in the air: {number, pos, vel, age}
var _last_throw: Dictionary = {}    # peer -> msec
var _wood_species: Dictionary = {}   # data/items/wood_species.json: class of each tree species and the firewood and block items of each class
var showroom_enabled: bool = true   # off in a real shared world: showroom items become real items in the economy
var _showroom_todo: Array = []     # [key, number, count, Vector3 spot] still waiting for their ground to load
var _showroom_wait: float = 0.0
var _last_dig: Dictionary = {}
var _grade_points: Dictionary = {}   # peer -> [A, B] ground points of the hoe grade line (Vector3, or null while unset)
var _last_mine: Dictionary = {}     # peer -> msec
var _last_hit: Dictionary = {}      # peer -> msec
var _last_process: Dictionary = {}  # peer -> msec
var _split_due: Dictionary = {}      # trunk id -> tick msec after which it breaks into logs by itself (a felled tree nobody has cut yet)
var _chops: Dictionary = {}         # "cx,cz,id" -> {hits, msec}
var _rot_in: float = 60.0
var rot_scanned: int = 0              # felled records looked at in the last rot pass (the work done; the catch-up test reads it)
var rot_removed: int = 0              # and how many rotted away in it
var _saplings: Array = []           # {slot, chunk [cx, cz], species (flora id), pos, planted_at}
var _flora_by_id: Dictionary = {}
var _mined: Dictionary = {}         # Vector2i patch -> {taken, since msec}
var _taken: Dictionary = {}         # scatter key int -> true: loose items already picked up (stay gone)
var _log_tasks: Array = []           # worker tasks printing log lines (_log_off_main)
var _slow_parts: Array = []           # this items tick's parts over SLOW_PART_LOG_MS, as "name ms"
var _slow_prev_usec: int = 0          # when the last part of this items tick ended
var _cell_parts: Array = []           # the last scatter cell's parts, as "name ms" (the slow-cell line)
var _save_parts: Array = []           # this tick's save files over 10 ms to stringify, as "name ms (KB)" (the slow-tick line)
var hint_every: int = HINT_EVERY_TICKS   # tests set 1: the hints every goals tick
var _hint_ticks: int = HINT_EVERY_TICKS - 1   # slow ticks since the hints were last looked at (the first tick looks)
var _goals_detail: String = ""        # the last _goals_tick's split (the slow-tick line)
var _slowest_hint: String = ""
var _slowest_hint_usec: int = 0
var _sync_detail: String = ""         # the last _sync_world_items' split (the slow-tick line)
var _bank_ground_usec: int = 0       # the last cell's bank stones: time reading the ground and asking for water (the slow-cell line)
var _bank_water_usec: int = 0
var _cell_cave_ms: float = 0.0     # the cave floor part of the last cell laid out (for the slow-cell line)
var _cells_done: Dictionary = {}    # Vector2i scatter cell -> true while its items are laid out


func setup(item_table, store_dir: String) -> void:
	admin_mode_on = func(peer: int) -> bool: return not _admin_mode_off.has(peer)
	table = item_table
	_traps = TrapsScript.new()
	_traps.host = self
	recipes = RecipeTableScript.load_default(item_table)
	_dir = store_dir
	var structures: Variant = JSON.parse_string(FileAccess.get_file_as_string(STRUCTURES_PATH))

	if typeof(structures) == TYPE_DICTIONARY:
		_structures_cfg = structures
		_structures = structures.get("structures", {})
		_struct_gap_m = float(structures.get("gap_m", 2.5))
		_fire_gap_m = float(structures.get("campfire", {}).get("gap_m", FIRE_MIN_GAP_M))
		_fires_per_chunk = int(structures.get("campfire", {}).get("cap_per_chunk", FIRES_PER_CHUNK))

	_load_blueprints()
	var skills_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SKILLS_PATH))
	_skills_cfg = skills_parsed if typeof(skills_parsed) == TYPE_DICTIONARY else {}
	_vitals_cfg = VitalsRules.load_config()
	_luck_cfg = LuckScript.load_config()
	_fitness_cfg = _load_fitness_config()
	var energy_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/energy.json"))
	_energy_cfg = energy_parsed if typeof(energy_parsed) == TYPE_DICTIONARY else {}
	var warmth_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/warmth.json"))
	_warmth_cfg = warmth_parsed if typeof(warmth_parsed) == TYPE_DICTIONARY else {}
	var sick_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/sickness.json"))
	_sick_cfg = sick_parsed if typeof(sick_parsed) == TYPE_DICTIONARY else {}
	var carcass_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/carcass.json"))
	_carcass_cfg = carcass_parsed if typeof(carcass_parsed) == TYPE_DICTIONARY else {}
	var death_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/death.json"))
	_death_cfg = death_parsed if typeof(death_parsed) == TYPE_DICTIONARY else {}
	var bed_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/bed.json"))
	_bed_cfg = bed_parsed if typeof(bed_parsed) == TYPE_DICTIONARY else {}
	var sleep_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/sleep.json"))
	_sleep_cfg = sleep_parsed if typeof(sleep_parsed) == TYPE_DICTIONARY else {}
	var dig_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/digging.json"))
	_dig_cfg = dig_parsed if typeof(dig_parsed) == TYPE_DICTIONARY else {}
	var boulders_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/boulders.json"))
	_boulder_cfg = boulders_parsed if typeof(boulders_parsed) == TYPE_DICTIONARY else {}
	_carry_cfg = CarryRules.load_config()
	var path_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/path_speed.json"))
	_path_cfg = path_parsed if typeof(path_parsed) == TYPE_DICTIONARY else {}
	var exertion_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/exertion.json"))
	_exertion_cfg = exertion_parsed if typeof(exertion_parsed) == TYPE_DICTIONARY else {}
	var coins_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/coins.json"))
	_coins_cfg = coins_parsed if typeof(coins_parsed) == TYPE_DICTIONARY else {}
	var rep_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/reputation.json"))
	_rep_cfg = rep_parsed if typeof(rep_parsed) == TYPE_DICTIONARY else {}
	_load_vitals()
	_load_characters()
	_load_craft_queues()
	_load_inventories()
	_load_chests()
	_load_world_items()
	var lights_parsed: Variant = _read_json_version("lights.json", 1)
	_apply_lit_rows(lights_parsed.get("lit", []) if lights_parsed != null and typeof(lights_parsed.get("lit", null)) == TYPE_ARRAY else [])
	var crops_parsed: Variant = _read_json_version("crops.json", 1)
	_crops = (crops_parsed.get("crops", {}) as Dictionary) if crops_parsed != null and typeof(crops_parsed.get("crops", null)) == TYPE_DICTIONARY else {}
	_plot_water = (crops_parsed.get("plots", {}) as Dictionary) if crops_parsed != null and typeof(crops_parsed.get("plots", null)) == TYPE_DICTIONARY else {}
	_water_rebuild((crops_parsed.get("tanks", {}) as Dictionary) if crops_parsed != null and typeof(crops_parsed.get("tanks", null)) == TYPE_DICTIONARY else {})
	_rebuild_supports()
	_load_trees()
	var cooking: Variant = JSON.parse_string(FileAccess.get_file_as_string(COOKING_PATH))
	_cooking = cooking if typeof(cooking) == TYPE_DICTIONARY else {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DROPS_PATH))
	_drops = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	var batch_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PICKUP_BATCH_PATH)) if FileAccess.file_exists(PICKUP_BATCH_PATH) else null
	_batch_cfg = batch_parsed if typeof(batch_parsed) == TYPE_DICTIONARY else {}
	var wood_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/wood_species.json"))
	_wood_species = wood_parsed if typeof(wood_parsed) == TYPE_DICTIONARY else {}
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
	_zone_sent.erase(peer)
	_zone_cand.erase(peer)
	_zone_checked.erase(peer)
	_vent_sent.erase(peer)

	if not _inventories.has(key):
		_inventories[key] = InventoryScript.new(table)
		_dirty = true

	_known[peer] = {}
	send_full.call(peer, _inventories[key].to_bytes())
	_send_favs(peer, _inventories[key])

	if not _vitals.has(key):
		_vitals[key] = _new_vitals()
		_dirty = true

	if not _characters.has(key):
		_characters[key] = {"luck": _create_luck(), "fitness": _fitness_default(), "train": 0.0, "skills_v": 2, "grace_s": _eat_cfg_value("first_hour_s", 3600.0)}
		_dirty = true

	_join_hotbar(peer, key)

	if str(_characters[key].get("shoulder", "")) != "":   # before 1 Nov 2026 the large log was kept apart from the pack: it moves into the pack (kept aside while the pack is full)
		var legacy: int = table.number_of(str(_characters[key]["shoulder"]))

		if legacy <= 0 or _inventories[key].add(legacy, 1) == 0:
			_characters[key].erase("shoulder")
			_dirty = true
			send_full.call(peer, _inventories[key].to_bytes())
			_send_favs(peer, _inventories[key])

	if bool(_characters[key].get("dead", false)) and send_final_death.is_valid():
		send_final_death.call(peer, "")   # already dead: the death screen again

	if bool(_characters[key].get("new_player", false)):
		_admin_mode_off[peer] = true   # a character that started over as a new player logs in with Admin mode off

	_vitals_sent.erase(peer)
	_sync_vitals(peer, true)
	_sync_energy(peer, true)
	_sync_warmth(peer, true)
	_sync_remains(peer, true)
	_sync_sick(peer, true)
	_sync_limp(peer, true)
	_sync_worn(peer, true)
	_sync_skills(peer, true)
	sync_purse(peer)
	sync_reputation(peer)
	sync_shoulder(peer)
	_sync_craft_queue(peer)


# Delete-character (protocol 82): the client forgets a character it deleted, so its record is not left behind. The key is the secret, so whoever holds it may forget it; the
# caller must already be in the game (hello) and may not forget a key that anyone is playing right now, their own included. Remains the character left stay in the world.
func forget_key(peer: int, key: String) -> bool:
	if not _peer_key.has(peer) or not _valid_key(key) or _peer_key.values().has(key) or not _characters.has(key):
		return false

	_inventories.erase(key)
	_characters.erase(key)
	_vitals.erase(key)
	_craft_queues.erase(key)
	_dirty = true
	return true


# --- Where a character resumes (protocol 69, DECISIONS collapse-offline) ---
const RESUME_GRACE_S := 120          # a reconnect within this long of a dropped connection resumes in place
const SAVE_SPOT_EVERY_MSEC := 30000  # the last known spot is written to the character at most this often while playing
var _logout_peers: Dictionary = {}   # peer -> true once the client said it is quitting on purpose
var _spot_saved_msec: Dictionary = {}


func note_logout(peer: int) -> void:
	if _peer_key.has(peer):
		_logout_peers[peer] = true


# Writes where the peer is and how they last left into the character row: "online" while playing, then "deliberate" (the client
# sent logout first) or "disconnect" (anything else: a dropped line, a crash, a kick, a server stop).
func _note_spot(peer: int, how: String) -> void:
	var key: String = str(_peer_key.get(peer, ""))

	if key == "" or not _characters.has(key) or not _peer_pos.has(peer):
		return

	var at: Vector3 = _peer_pos[peer]
	_characters[key]["last"] = {"pos": [at.x, at.y, at.z], "t": int(Time.get_unix_time_from_system()), "left": how}
	_dirty = true


# [x, y, z] where this peer starts, or [] to stay at the world spawn. Deliberate quit: the saved spot. Disconnect (or a spot last
# written while online, which a crash leaves): the saved spot when they come back within RESUME_GRACE_S, else where they last
# rested or sheltered (rest_point_for: the nearest of their rest points), else the world spawn.
func start_position_for(peer: int) -> Array:
	var row: Dictionary = _characters.get(_peer_key.get(peer, ""), {})
	var last: Dictionary = row.get("last", {})
	var pos: Array = last.get("pos", [])

	if pos.size() != 3:
		return []

	var spot := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))

	if not (is_finite(spot.x) and is_finite(spot.y) and is_finite(spot.z)):
		return []

	if str(last.get("left", "")) != "deliberate" and int(Time.get_unix_time_from_system()) - int(last.get("t", 0)) > RESUME_GRACE_S:
		spot = rest_point_for(peer, spot)   # the nearest rest or shelter point to where they dropped

	return [spot.x, spot.y, spot.z]


func peer_left(peer: int) -> void:
	_bed_cache.erase(peer)
	_zone_sent.erase(peer)
	_zone_cand.erase(peer)
	_zone_pos.erase(peer)
	_zone_checked.erase(peer)
	_vent_sent.erase(peer)
	_note_spot(peer, "deliberate" if _logout_peers.has(peer) else "disconnect")
	_logout_peers.erase(peer)
	_admin_mode_off.erase(peer)
	spyglass.erase(peer)
	spyglass_tier.erase(peer)
	_chest_viewer.erase(peer)
	_spot_saved_msec.erase(peer)
	_station_said.erase(peer)
	_hole_blows.erase(peer)
	_fishing.erase(peer)
	_last_fish.erase(peer)
	_wear_carry.erase(peer)
	_swimming.erase(peer)
	_torch_seen.erase(peer)
	_cave_pool.erase(peer)
	_soak.erase(peer)
	_last_dose.erase(peer)
	_remains_sent.erase(peer)
	_worn_sent.erase(peer)
	_skills_sent.erase(peer)
	_skills_send_in.erase(peer)
	_last_practice.erase(peer)
	_head_under.erase(peer)
	_breath.erase(peer)
	_suffocate.erase(peer)
	_breath_sent.erase(peer)
	_speed3.erase(peer)
	_peer_key.erase(peer)
	_peer_pos.erase(peer)
	_known.erase(peer)
	_bog_scan.erase(peer)
	_last_throw.erase(peer)
	_last_mine.erase(peer)
	_last_dig.erase(peer)
	_last_average.erase(peer)
	_roads.erase(peer)
	_grade_points.erase(peer)
	_on_path_cache.erase(peer)
	_last_hit.erase(peer)
	_last_cook.erase(peer)
	_last_gather.erase(peer)
	_last_use.erase(peer)
	_last_eat.erase(peer)
	_eat_warn.erase(peer)
	_last_drink.erase(peer)
	_exertion.erase(peer)
	_motion.erase(peer)
	_snow_memo.erase(peer)
	_work_until.erase(peer)
	_vitals_sent.erase(peer)
	_strain.erase(peer)
	_strain_sent.erase(peer)
	_stance.erase(peer)
	_energy_sent.erase(peer)
	_asleep.erase(peer)
	_waking.erase(peer)
	_body_sent.erase(peer)
	_moving.erase(peer)
	_last_process.erase(peer)


func report_position(peer: int, position: Vector3) -> void:
	if _peer_key.has(peer):
		_peer_pos[peer] = position
		_note_motion(peer, position)
		var now: int = Time.get_ticks_msec()
		_note_zone(peer, position)

		if now - int(_spot_saved_msec.get(peer, 0)) >= SAVE_SPOT_EVERY_MSEC:
			_spot_saved_msec[peer] = now
			_note_spot(peer, "online")


const ZONE_EVERY_MSEC := 2000       # the biome under a player is read this often
const VENT_RANGE_M := 1500.0           # the volcano bed is inaudible beyond this (batch2_slots.json max_distance_m)
const VENT_MOVE_M := 1.0               # a vent anchor is sent again only when it moved by more than this (a different vent, or none)
const ZONE_TELEPORT_M := 200.0       # a jump this far between two reads (teleport, respawn) is sent at once
var _zone_sent: Dictionary = {}      # peer -> biome id the client was last told
var _zone_cand: Dictionary = {}      # peer -> a new biome read once; sent when the next read agrees (about 4 s)
var _zone_pos: Dictionary = {}       # peer -> position at the last read
var _zone_checked: Dictionary = {}   # peer -> msec of the last read
var _vent_sent: Dictionary = {}      # peer -> the vent anchor the client was last told (INF = none)


# Tell a client its biome: at once for a new player, after every teleport or respawn, and after a change that reads the same twice running (no flicker on
# a border). Reliable and ordered, so the client's last value is the server's last.
func _note_zone(peer: int, position: Vector3) -> void:
	if not zone_at.is_valid() or not send_zone.is_valid():
		return

	var now: int = int(zone_clock.call()) if zone_clock.is_valid() else Time.get_ticks_msec()

	if _zone_checked.has(peer) and now - int(_zone_checked[peer]) < ZONE_EVERY_MSEC:
		return

	_zone_checked[peer] = now
	_note_vent(peer, position)
	var started: int = Time.get_ticks_usec()
	var biome: int = int(zone_at.call(position))
	zone_usec += Time.get_ticks_usec() - started
	zone_samples += 1
	var jumped: bool = _zone_pos.has(peer) and position.distance_to(_zone_pos[peer]) > ZONE_TELEPORT_M
	_zone_pos[peer] = position

	if biome < 0:
		return

	if not _zone_sent.has(peer) or jumped:
		_send_zone(peer, biome)
	elif biome == int(_zone_sent[peer]):
		_zone_cand.erase(peer)
	elif int(_zone_cand.get(peer, -2)) == biome:
		_send_zone(peer, biome)
	else:
		_zone_cand[peer] = biome


# The nearest volcanic vent within VENT_RANGE_M, on the zone's 2 s cadence: sent at login and whenever it changes (a different vent, or none in range).
func _note_vent(peer: int, position: Vector3) -> void:
	if not vent_near.is_valid() or not send_vent.is_valid():
		return

	var at: Vector3 = vent_near.call(position)
	var known: bool = _vent_sent.has(peer)
	var before: Vector3 = _vent_sent.get(peer, Vector3.INF)

	if known and (at == before or (at.is_finite() and before.is_finite() and at.distance_to(before) <= VENT_MOVE_M)):
		return

	# At login nothing needs saying when there is no vent: the client starts with none.
	_vent_sent[peer] = at

	if known or at.is_finite():
		vent_messages += 1
		send_vent.call(peer, at)


func _send_zone(peer: int, biome: int) -> void:
	_zone_sent[peer] = biome
	_zone_cand.erase(peer)
	zone_messages += 1
	send_zone.call(peer, biome)


func inventory_of(peer: int):
	return _inventories.get(_peer_key.get(peer, ""), null)


# Puts items in a player's inventory. Whatever does not fit lies on the ground at their feet.
# Returns how many went into the inventory. For harvesting and crafting.
func give(peer: int, number: int, count: int) -> int:
	var inv = inventory_of(peer)

	if inv == null or number <= 0 or count <= 0 or table.id_of(number) == "":
		return 0

	if is_shoulder_item(number):
		return _give_shoulder(peer, number, count)

	var before: Array = _snapshot(inv)
	var fits: int = _fit(peer, inv, number, count)
	var left: int = inv.add(number, fits) + (count - fits)
	var was_src: String = _gain_source
	_gain_source = SRC_GATHER if was_src == SRC_PICKUP else was_src
	_send_changes(peer, inv, before)
	_gain_source = was_src
	_dirty = true

	if left > 0:
		drop_in_world(number, left, _peer_pos.get(peer, Vector3.ZERO))

	return count - left


# --- The large log on the shoulder (Dave 2026-10-21; 1 Nov 2026: it is a normal pack item, the shoulder is only how it is shown) ---
# A large log (items.json "carry": "shoulder") sits in the pack like any item: one slot, its weight counted once in the load, the same fuel / chest / craft rules as
# any log. Only one may be picked up at a time (the next one lies where it was), and the client draws the carry pose while the pack holds one.

func is_shoulder_item(number: int) -> bool:
	return number > 0 and str(table.entry(table.id_of(number)).get("carry", "")) == "shoulder"


# The pack slot holding the large log, -1 when there is none.
func _shoulder_slot(peer: int) -> int:
	var inv = inventory_of(peer)

	if inv == null:
		return -1

	for slot in range(inv.SLOTS):
		if inv.numbers[slot] != 0 and is_shoulder_item(inv.numbers[slot]):
			return slot

	return -1


# The item id of the large log in this player's pack (the one shown on the shoulder), "" when there is none.
func shoulder_of(peer: int) -> String:
	var slot: int = _shoulder_slot(peer)
	return table.id_of(inventory_of(peer).numbers[slot]) if slot >= 0 else ""


# Its weight is already in the pack's total, so the shoulder adds nothing on top.
func _shoulder_kg(_peer: int) -> float:
	return 0.0


func sync_shoulder(peer: int) -> void:
	if send_carry.is_valid() and _characters.has(_peer_key.get(peer, "")):
		var id: String = shoulder_of(peer)
		_shoulder_sent[peer] = id
		send_carry.call(peer, id)


# The client is told again whenever the pack gains or loses the large log.
func _sync_shoulder_if_changed(peer: int) -> void:
	if _shoulder_sent.get(peer, null) != shoulder_of(peer):
		sync_shoulder(peer)


var _shoulder_sent: Dictionary = {}


# Puts one large log in the pack (it shows on the shoulder); with a log already carried the new one lies at the player's feet. Returns how many were taken.
func _give_shoulder(peer: int, number: int, count: int) -> int:
	var key: String = str(_peer_key.get(peer, ""))
	var inv = inventory_of(peer)

	if not _characters.has(key) or inv == null:
		return 0

	var here: Vector3 = _peer_pos.get(peer, Vector3.ZERO)

	if shoulder_of(peer) != "":
		_say(peer, "Put your log down first (Q).")
		drop_in_world(number, count, here)
		return 0

	var before: Array = _snapshot(inv)
	var took: int = 1 if _fit(peer, inv, number, 1) > 0 and inv.add(number, 1) == 0 else 0
	_send_changes(peer, inv, before)
	_dirty = true

	if took == 0:
		_say(peer, "Too heavy to carry any more")

	if count > took:
		drop_in_world(number, count - took, here)

	return took


# D or the lay-down key with a log carried: it lies on the ground in front of the player.
func lay_down_shoulder(peer: int, at: Vector3 = Vector3.ZERO) -> bool:
	var slot: int = _shoulder_slot(peer)

	if slot < 0 or not _peer_pos.has(peer):
		return false

	var inv = inventory_of(peer)
	var here: Vector3 = _peer_pos[peer]
	var spot: Vector3 = at if at != Vector3.ZERO and at.distance_to(here) <= DROP_REACH_M else here
	var number: int = inv.numbers[slot]

	if not drop_in_world(number, 1, spot):
		return false

	var before: Array = _snapshot(inv)
	inv.take_from_slot(slot, 1)
	_send_changes(peer, inv, before)
	_dirty = true
	return true


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


# Puts a stack on the ground. False when the chunk is full. `lifetime_s` above 0 keeps it at least that many real seconds (a felled tree's logs last as its trunk did).
# `rot_y` (radians, NAN for none) turns a new loose item about the vertical: a felled tree's logs lie along its trunk.
# `girth` (NAN for none) scales a split log's thickness to the trunk it came from (Dave 2 Nov 2026: a skinny tree gave big logs); LOG_MESH_RADIUS_M is 1.
const LOG_MESH_RADIUS_M := 0.25   # the drawn species log's mean radius (inventory_view _mesh_for: 0.28 and 0.22 at its ends)


func drop_in_world(number: int, count: int, position: Vector3, item_wear: int = 0, lifetime_s: float = 0.0, rot_y: float = NAN, girth: float = NAN, by: String = "") -> bool:
	if count <= 0 or number <= 0:
		return false

	# Only loose dropped things near the spot count: felled trunks, stumps, fires, structures, carcasses and natural scatter are not
	# "dropped" and last far longer (Dave 2026-10-22: a drop was refused with nothing in sight, the chunk was full of stumps and trunks).
	position = _settled(position)

	# Same kind within MERGE_M joins the item already lying there (stackables without wear only), so a heap grows as one ground item
	# and never meets the crowd limit. The merge runs before the limit check.
	if item_wear == 0 and table.stack_of(number) > 1:
		for id in (_drop_scope if _drop_scoped else _items.keys()):
			if not _items.has(id):
				continue

			var near: Dictionary = _items[id]

			if near.has("scatter") or near.has("showroom") or near.has("struct") or near.has("fire") or near.has("tree") or near.has("boulder") or near.has("tilt"):   # an arrow in a tree stays one arrow
				continue

			if int(near["number"]) != number or int(near.get("wear", 0)) != 0 or int(near["count"]) >= PILE_CAP:
				continue

			if Vector2(near["pos"].x - position.x, near["pos"].z - position.z).length() <= MERGE_M and absf(near["pos"].y - position.y) <= 2.0:
				var room: int = PILE_CAP - int(near["count"])
				var added: int = mini(count, room)
				near["count"] = int(near["count"]) + added
				near["left"] = maxf(PILE_LIFETIME_S if int(near["count"]) >= PILE_MIN else WORLD_ITEM_LIFETIME_S, lifetime_s)

				if by != "":
					near["by"] = by   # the last player to add to it (goblin gifts; kept while the server runs, not saved)

				_dirty = true
				count -= added

				if count <= 0:
					return true

				break   # the rest (over the cap) falls through and starts a second pile

	var here: int = 0

	for id in (_drop_scope if _drop_scoped else _items.keys()):
		if not _items.has(id):
			continue

		var other: Dictionary = _items[id]

		if other.has("scatter") or other.has("showroom") or other.has("struct") or other.has("fire") or other.has("tree"):
			continue

		if Vector2(other["pos"].x - position.x, other["pos"].z - position.z).length() <= DROP_CROWD_M:
			here += 1

	if here >= MAX_DROPPED_NEAR:
		return false

	var first: int = mini(count, PILE_CAP)
	_items[_next_id] = {"number": number, "count": first, "pos": position, "left": maxf(PILE_LIFETIME_S if first >= PILE_MIN else WORLD_ITEM_LIFETIME_S, lifetime_s), "wear": item_wear}

	if not is_nan(rot_y):
		_items[_next_id]["rot_y"] = rot_y

	if by != "":
		_items[_next_id]["by"] = by   # who dropped it (goblin gifts; kept while the server runs, not saved)

	if not is_nan(girth):
		_items[_next_id]["girth"] = clampf(girth, 0.25, 2.5)

	if _drop_scoped:
		_drop_scope.append(_next_id)

	_next_id += 1
	_dirty = true

	if count > first:
		return drop_in_world(number, count - first, position, item_wear, lifetime_s, rot_y, girth, by)   # over the cap: the rest starts a second pile beside it

	return true


# Bug 6 (Dave 2 Nov 2026: about a second's pause when an old trunk is cut up): every player action is timed, and one over SLOW_ACTION_MS prints a line,
# so the server log shows whether the pause is here (and which action) or in the client ("client slow: world items ...").
const SLOW_ACTION_MS := 20.0


func action(peer: int, kind: int, a: int, b: int, count: int, at: Vector3) -> void:
	var t0: int = Time.get_ticks_usec()
	_action(peer, kind, a, b, count, at)
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0

	if ms > SLOW_ACTION_MS:
		print("server slow: action %d (a %d, b %d) took %.0f ms, %d world items" % [kind, a, b, ms, _items.size()])


func _action(peer: int, kind: int, a: int, b: int, count: int, at: Vector3) -> void:
	var inv = inventory_of(peer)

	if inv == null:
		return

	var before: Array = _snapshot(inv)

	if kind == Net.ACT_MOVE:
		inv.move(a, b)             # move() ignores bad slots
	elif kind == Net.ACT_DROP:
		if a == -1:
			lay_down_shoulder(peer, at)
		else:
			_drop(peer, inv, a, count, at)
	elif kind == Net.ACT_PICKUP:
		_pickup(peer, inv, a, count)
	elif kind == Net.ACT_HIT:
		_hit(peer, inv, a, Vector2i(b, count))
	elif kind == Net.ACT_CHEST_OPEN or kind == Net.ACT_CHEST_PUT or kind == Net.ACT_CHEST_TAKE:
		_chest_action(peer, inv, kind, a, b, count)
	elif kind == Net.ACT_USE_STRUCT:
		_use_struct(peer, inv, a)
	elif kind == Net.ACT_EAT:
		var fed_before: float = float(vitals_of(peer).get("fed", 0.0))
		_eat(peer, inv, a)

		if float(vitals_of(peer).get("fed", 0.0)) > fed_before:
			_goal_event(peer, "ate_food")
	elif kind == Net.ACT_DRINK:
		var wet_before: float = float(vitals_of(peer).get("wet", 0.0))
		_drink_water(peer, a, inv)

		if float(vitals_of(peer).get("wet", 0.0)) > wet_before:
			_goal_event(peer, "drink")
	elif kind == Net.ACT_ICEHOLE:
		_cut_hole(peer, inv, a)
	elif kind == Net.ACT_FISH:
		_fish(peer, inv, a, at)
	elif kind == Net.ACT_NET:
		_net_cast(peer, inv, a, b == 1, at)
	elif kind == Net.ACT_SHOOT:
		_shoot(peer, inv, a, b, at, count)
	elif kind == Net.ACT_WEAR:
		_gain_quiet = true
		_wear(peer, inv, a)
		_gain_quiet = false
	elif kind == Net.ACT_UNWEAR:
		_gain_quiet = true
		_unwear(peer, inv, a)
		_gain_quiet = false
	elif kind == Net.ACT_REPAIR:
		_repair(peer, inv, a)
	elif kind == Net.ACT_FUEL:
		_fuel(peer, inv, a)
	elif kind == Net.ACT_STANCE:
		_set_stance(peer, a)
	elif kind == Net.ACT_SLEEP:
		_sleep(peer, a)
	elif kind == Net.ACT_LIGHT:
		var was_laid: bool = _items.has(a) and _items[a].has("fire") and int(_items[a]["fire"]["state"]) in [9, FIRE_STATE_ASH]
		_light(peer, inv, a)

		if was_laid and _items.has(a) and _items[a].has("fire") and fire_is_lit(int(_items[a]["fire"]["state"])):
			_goal_event(peer, "fire_lit")
	elif kind == Net.ACT_COOK:
		_cook(peer, inv, a)
	elif kind == Net.ACT_SPLIT:
		_split(inv, a, count)
	elif kind == Net.ACT_PROCESS:
		_process_trunk(peer, inv, a)
	elif kind == Net.ACT_MINE:
		_mine(peer, inv, at)
	elif kind == Net.ACT_CHEST_CLOSE:
		_sync_fire_from_box(peer, int(_chest_viewer.get(peer, 0)))
		_chest_viewer.erase(peer)
	elif kind == Net.ACT_CHEST_KEEP_OUT:
		_set_keep_out(peer, a, b == 1)
	elif kind == Net.ACT_CRAFT_STOCK:
		_send_stock(peer)
	elif kind == Net.ACT_FAVOURITE:
		if a >= 0 and a < inv.SLOTS and inv.numbers[a] != 0:
			inv.set_fav(a, b == 1)
	elif kind == Net.ACT_BULK:
		_bulk(peer, inv, a, b)
	elif kind == Net.ACT_HOTBAR_SET:
		_set_hotkey(peer, inv, a, b)
	elif kind == Net.ACT_LITTER:
		_pick_litter(peer, inv, at)
	elif kind == Net.ACT_DIG:
		_dig(peer, inv, at)
	elif kind == Net.ACT_FILL:
		_fill(peer, inv, at)
	elif kind == Net.ACT_GATHER_EDGE:
		gather_edge(peer, inv)
	elif kind == Net.ACT_SET_SPAWN:
		set_spawn_bed(peer, a)
	elif kind == Net.ACT_TILL:
		till(peer, inv, at)
	elif kind == Net.ACT_SOW:
		sow(peer, inv, a, b)
	elif kind == Net.ACT_HARVEST:
		harvest(peer, inv, a)
	elif kind == Net.ACT_WATER_BED:
		water_bed(peer, inv, a)
	elif kind == Net.ACT_HOE_PATH:
		_hoe_path(peer, inv, at)
	elif kind == Net.ACT_HOE_SMOOTH:
		_hoe_smooth(peer, inv, at)
	elif kind == Net.ACT_HOE_GRADE_POINT:
		_hoe_grade_point(peer, inv, b, at)
	elif kind == Net.ACT_HOE_GRADE:
		_hoe_grade(peer, inv, at)
	elif kind == Net.ACT_PLACE:
		_place(peer, inv, a, at, count, b)
	elif kind == Net.ACT_REPAIR_STRUCT:
		_repair_struct(peer, inv, a)
	elif kind == Net.ACT_PLACE_BLUEPRINT:
		_place(peer, inv, -1, at, count, b, _blueprints.get(a, {}))
	elif kind == Net.ACT_THROW:
		_throw(peer, inv, a, at)
	elif kind == Net.ACT_HIT_SHRUB:
		_hit_shrub(peer, inv, a, Vector2i(b, count), at.x > 0.5)
	elif kind == Net.ACT_PLANT_BUSH:
		_plant_bush(peer, inv, a, at)
	elif kind == Net.ACT_DOUSE:
		_douse(peer, inv, a, b == 1)
	elif kind == Net.ACT_TORCH_BURN:
		_torch_burn(peer, inv, a)
	elif kind == Net.ACT_RELIGHT:
		_relight(peer, inv, a, b)
	elif kind == Net.ACT_PLACE_TORCH:
		_place_torch(peer, inv, a, b == 1, count, at)
	elif kind == Net.ACT_STRIKE:
		_strike(peer, inv, a, at)
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
		if table.id_of(a) != "" and (not admin_ok.is_valid() or admin_ok.call(peer)):
			var bag_was: int = inv.bag_from
			inv.bag_from = 0   # an admin give fills from the first slot (tests and the admin tool); player pickups keep to the bag
			var left: int = inv.add(a, clampi(count, 1, 100))
			inv.bag_from = bag_was

			if left > 0:
				drop_in_world(a, left, _peer_pos.get(peer, Vector3.ZERO))

	elif kind == Net.ACT_CLEAR_DROPS:
		if not admin_ok.is_valid() or admin_ok.call(peer):
			_say(peer, "Cleared %d dropped items." % clear_dropped(_peer_pos.get(peer, Vector3.ZERO), float(clampi(a, 1, 500))))

	elif kind == Net.ACT_SHOWROOM:
		if not admin_ok.is_valid() or admin_ok.call(peer):
			_showroom_seed(peer, a == 1, at)

	elif kind == Net.ACT_WHEEL_ASK:
		_wheel_ask(peer, a, b, at)
	elif kind == Net.ACT_SPYGLASS:
		if a == 2:
			_look_spyglass_item(peer, inv, count, b)
		elif a != 1:
			spyglass.erase(peer)
			spyglass_tier.erase(peer)
		elif not admin_ok.is_valid() or admin_ok.call(peer):
			spyglass[peer] = maxi(b, 0)
			spyglass_tier.erase(peer)
		else:
			spyglass[peer] = -1   # refused: the server scene tells the client once (animal_info id -1) and forgets it
			_say(peer, "The spyglass is for admins.")

	elif kind == Net.ACT_ADMIN_ENERGY:
		if admin_ok.is_valid() and admin_ok.call(peer):
			vitals_of(peer)["energy"] = clampf(float(count), 0.0, 100.0)

	elif kind == Net.ACT_NEW_PLAYER:
		if admin_ok.is_valid() and admin_ok.call(peer):
			_become_new_player(peer)

	elif kind == Net.ACT_ADMIN_MODE:
		if admin_ok.is_valid() and admin_ok.call(peer):
			if a == 1:
				_admin_mode_off.erase(peer)
			else:
				_admin_mode_off[peer] = true

			_say(peer, "Admin mode %s." % ("on: crafting is free" if a == 1 else "off"))

	elif kind == Net.ACT_DUMP_WATER:
		if admin_ok.is_valid() and admin_ok.call(peer) and dump_water.is_valid():
			_say(peer, "Water dump: %s" % str(dump_water.call(at.x, at.z)))
	elif kind == Net.ACT_LAND_TYPES:
		if admin_ok.is_valid() and admin_ok.call(peer) and land_types.is_valid():
			_say(peer, "Land types: %s" % str(land_types.call(at.x, at.z)))
	elif kind == Net.ACT_RESET_EDITS:
		if admin_ok.is_valid() and admin_ok.call(peer) and reset_terrain_edits.is_valid():
			print("server: peer %d reset all terrain edits" % peer)
			reset_terrain_edits.call()
			_say(peer, "All terrain edits are deleted. The ground is rebuilding.")

	_send_changes(peer, inv, before)
	_dirty = true


var ground_ready: Callable              # (x, z) -> bool: the ground there is in memory; when not, it is being read in the background (unset in tests = always ready)
var water_flow_at: Callable             # set by the server: (Vector3) -> float, the running speed of the water there in m/s (-1 none, 0 still), for placement rules
var water_wheel: Callable               # set by the server: (a: Vector3, b: Vector3) -> {"w": watts, "why": "" or dry/river/still/shallow, "along": bool}, a water wheel spanning a to b (WaterFlow.wheel)
var floor_below: Callable               # set by the server: (Vector3) -> float, the height a loose item let go there comes to rest at (NAN if none)
var land_types: Callable                # set by the server: (x, z) -> String, classifies the land near a point from the live water and writes a text file
var dump_water: Callable                # set by the server: (x, z) -> String, writes the live water cells near a point to a text file
var reset_terrain_edits: Callable       # set by the server: () -> void, wipes every saved dig and fill
var admin_ok: Callable                  # set by the server: true when the peer may use admin gives
var spyglass: Dictionary = {}          # peer -> the animal id an admin watches through the spyglass (0 none, -1 refused: not an admin); absent when not looking (ACT_SPYGLASS)
var spyglass_tier: Dictionary = {}     # peer -> the tier of the spyglass item looked through (absent: the admin glass, or not looking)
var _spyglass_tiers: Dictionary = {}   # data/items/spyglass.json "tiers", read on the first look


# ACT_SPYGLASS a = 2 (10 Nov 2026, data/items/spyglass.json): up to the eye through the spyglass item in pack slot `slot`. Needs no admin: the
# item is checked (a spyglass, not broken), one use of it is worn per look, and the server sends animals out to the tier's radius
# (spyglass_reach). The watched animal `watched` counts only for a tier with a readout. Refused: animal_info(-1) brings the client's glass down.
func _look_spyglass_item(peer: int, inv, slot: int, watched: int) -> void:
	var entry: Dictionary = table.entry(table.id_of(inv.numbers[slot])) if slot >= 0 and slot < inv.SLOTS and inv.numbers[slot] != 0 else {}

	if str(entry.get("tool_class", "")) != "spyglass" or _is_broken(inv.numbers[slot], inv.wear[slot]):
		spyglass[peer] = -1
		spyglass_tier.erase(peer)
		return

	if _spyglass_tiers.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/spyglass.json")) if FileAccess.file_exists("res://data/items/spyglass.json") else null
		_spyglass_tiers = parsed.get("tiers", {}) if typeof(parsed) == TYPE_DICTIONARY else {}

	var tier: int = int(entry.get("tier", 1))

	if not spyglass_tier.has(peer):
		_wear_slot(peer, inv, slot, "look")   # one use per look, not per resend

	spyglass_tier[peer] = tier
	spyglass[peer] = maxi(watched, 0) if bool(_spyglass_tiers.get(str(tier), {}).get("readout", false)) else 0


# The animals sent to a player looking through a spyglass: [radius m, cap]. The admin glass uses animals.json "spyglass" (`admin_cfg`),
# an item its tier's send_radius_m and cap; [-1, -1] when not looking (the normal send).
func spyglass_reach(peer: int, admin_cfg: Dictionary) -> Array:
	if not spyglass.has(peer) or int(spyglass[peer]) < 0:
		return [-1.0, -1]

	var cfg: Dictionary = _spyglass_tiers.get(str(spyglass_tier[peer]), {}) if spyglass_tier.has(peer) else admin_cfg
	return [float(cfg.get("send_radius_m", 300.0)), int(cfg.get("cap", 60))]


func tick(delta: float) -> void:
	var t0: int = Time.get_ticks_usec()
	_slow_parts = []
	_slow_prev_usec = t0
	_fly(delta)
	_showroom_retry(delta)
	_road_tick(delta)
	_slow_mark("fly-showroom-roads", t0)
	_slow_in += delta

	# Fires and item lifetimes only need about 4 looks a second (TD note 2026-10-20: 1.5 ms a frame at 1300 records).
	if _slow_in >= SLOW_TICK_S:
		var spent: float = _slow_in
		_slow_in = 0.0
		_rot(spent)
		_slow_mark("rot", t0)
		_fires(spent)
		_slow_mark("fires", t0)
		_vitals_tick(spent)
		_slow_mark("vitals", t0)
		_craft_tick(spent)
		_slow_mark("craft", t0)
		_auto_split()
		_slow_mark("auto-split", t0)
		_crops_tick()
		_water_tick(spent)
		_slow_mark("crops-water", t0)
		_lights_tick(spent)
		_dev_pending_tick(spent)
		_slow_mark("lights-dev", t0)
		_comfort_tick(spent)
		_slow_mark("comfort", t0)
		_goals_tick()
		_slow_mark("goals " + _goals_detail, t0)
		_learn_clock += spent

		if _learn_clock >= LEARN_TICK_S:
			_learn_clock = 0.0
			_learn_tick()

		_slow_mark("learn", t0)
		_fish_tick()
		_slow_mark("fish", t0)
		_remains_tick(spent)
		_slow_mark("remains", t0)
		_spoil_tick(spent)
		_wood_tick(spent)
		_slow_mark("spoil", t0)
		_traps.tick(spent)
		_slow_mark("learn-fish-remains-spoil-traps", t0)

		_expire_items(spent)

	_sync_in -= delta

	if _sync_in <= 0.0:
		_sync_in = SYNC_EVERY_S
		_scatter_around_players()
		_slow_mark("scatter", t0)
		_sync_world_items()
		_slow_mark("sync-world-items " + _sync_detail, t0)

	_save_in -= delta

	_reap_writer()

	_save_parts = []

	if _save_in <= 0.0:
		_save_in = SAVE_EVERY_S
		_async_writes = true
		save()
		_async_writes = false
		_start_writer()

	_slow_mark("save" + (" (stringify %s)" % ", ".join(_save_parts) if not _save_parts.is_empty() else ""), t0)
	var tick_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0

	if tick_ms > SLOW_TICK_LOG_MS:
		# One line a slow tick, naming each part's own time (the old lines gave only the running total, so a 274 ms "scatter reached after"
		# did not say whether scatter or something before it took the time). Printed from a worker: a print can stall the main thread (#397).
		_log_off_main("items tick slow: %.0f ms; parts over %.0f ms: %s" % [tick_ms, SLOW_PART_LOG_MS, ", ".join(_slow_parts)])


# Testing aid (Tyler, 31 Oct 2026): the items tick times its parts, so a join stall names its part. Each mark closes the part since the last
# one; a part over SLOW_PART_LOG_MS goes on the tick's list, printed at the end of a tick over SLOW_TICK_LOG_MS.
func _slow_mark(part: String, _since_usec: int) -> void:
	var now: int = Time.get_ticks_usec()
	var ms: float = float(now - _slow_prev_usec) / 1000.0
	_slow_prev_usec = now

	if ms > SLOW_PART_LOG_MS:
		_slow_parts.append("%s %.0f" % [part, ms])


# A log line printed on a worker thread (a print flushes the log on the PC's debug build and stalled the main thread 400+ ms, #397).
func _log_off_main(line: String) -> void:
	var still: Array = []

	for task in _log_tasks:   # reap the lines already printed (a task must be waited for once)
		if WorkerThreadPool.is_task_completed(task):
			WorkerThreadPool.wait_for_task_completion(task)
		else:
			still.append(task)

	still.append(WorkerThreadPool.add_task(func() -> void: print(line), false, "items log line"))
	_log_tasks = still


func save() -> void:
	if _dir == "" or not _dirty:
		return

	_finish_writer()   # an earlier background write finishes first, so files land in order

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

		if it.has("scatter") or it.has("tree") or it.has("showroom"):
			continue   # the showroom is never saved: an admin fills it again after a restart

		if it.has("struct") and bool(it["struct"].get("transient", false)):
			continue

		if it.has("struct"):
			items.append([int(it["number"]), 1, it["pos"].x, it["pos"].y, it["pos"].z, 1.0e9, int(_structures.get(str(it["struct"]["kind"]), {}).get("state", 5)), float(it["struct"]["yaw"]), int(it.get("wear", 0)), str(it["struct"]["kind"]), int(it["struct"].get("uid", 0)), str(it["struct"].get("owner", "")), float(it["struct"].get("born", it["struct"].get("seq", 0.0))), bool(it["struct"].get("cave", false)), int(it["struct"].get("coins", 0)), JSON.stringify(it["struct"]["site"]) if it["struct"].has("site") else "", 1 if bool(it["struct"].get("keep_out", false)) else 0])
			continue

		var at: Vector3 = it["pos"]

		if it.has("tilt") and ground_height.is_valid() and not is_nan(float(ground_height.call(at.x, at.z))):
			at.y = float(ground_height.call(at.x, at.z))   # an arrow stuck in a tree is saved as fallen to the foot of it (the tilt is not saved)

		var row: Array = [int(it["number"]), int(it["count"]), at.x, at.y, at.z, it["left"], int(it["fire"]["state"]) if it.has("fire") else 0, float(it["fire"]["burn_left"]) if it.has("fire") else 0.0, int(it.get("wear", 0))]

		if not it.has("fire") and it.has("rot_y"):
			row.append(float(it["rot_y"]))   # a loose item's turn (a split log along its trunk); fires use this slot for their store

			if it.has("girth"):
				row.append(float(it["girth"]))   # a split log's thickness against the drawn log

		if it.has("fire"):
			var wood: Dictionary = _fire_wood(it["fire"])
			row.append(int(it["fire"].get("uid", 0)))   # a campfire's store (a number here; a structure's kind is a string); 0 = none
			row.append([float(wood["log"]), float(wood["firewood"]), float(wood["weak"])])   # burning seconds by wood class (fire tiers)
			var pc: Dictionary = it["fire"].get("pieces", {})
			row.append([int(pc.get("log", -1)), int(pc.get("firewood", -1)), int(pc.get("weak", -1))])   # pieces laid by class (-1 = not known: counted by time)
			row.append(1 if bool(it["fire"].get("synced", false)) else 0)   # the store holds the fire's wood (older saves: 0, converted at the first opening)
			var burnt: Dictionary = it["fire"].get("burnt", {})
			row.append([float(burnt.get("log", 0.0)), float(burnt.get("firewood", 0.0)), float(burnt.get("weak", 0.0))])   # burned seconds not yet taken out of the store
			var counted: Dictionary = it["fire"].get("counted", {})
			row.append([int(counted.get("log", -1)), int(counted.get("firewood", -1)), int(counted.get("weak", -1))] if it["fire"].has("counted") else [])   # store pieces the last count knew ([] = never counted)
			row.append(float(it["fire"].get("lit_s", 0.0)))   # seconds burned since it was last cold (a coal bed at coals.coal_bed_s)
			row.append(int(it["fire"].get("damp", 0)))   # the wettest wood in it, drying left in tenths of a game hour (cooking.json wet_wood)

		items.append(row)

	_save_trees()
	_save_chests()
	_save_vitals()
	_save_characters()
	_save_craft_queues()
	_write_atomic("crops.json", {"version": 1, "crops": _crops, "plots": _plot_water, "tanks": _water_tanks_save()})
	_write_atomic("lights.json", {"version": 1, "lit": _light_rows_save()})
	_write_atomic("world_items.json", {"version": VERSION, "next_id": _next_id, "items": items, "taken": _taken.keys(), "picked": _picked, "stripped": _stripped_now(), "fruit": _fruit_now(), "boulders": _boulder_left, "bog_iron": _bog_left, "layout": FloraLayout.VERSION, "no_kits": true})


# Picking from a plant or shrub by hand. The plant stays where it is and is picked bare for
# REGROW_GAME_S of game time. It gives what drops.json says (fibre, sticks) and one of its
# natural yields (berries, leaves, roots...) when that is in season (flora table).
# Returns false when it gives nothing, the player is not near it, or it is not ready.
# True while a plant picked bare under the old regrow rule is still on the list (server_items keeps it for 3 game days).
func was_picked(flora_key: String) -> bool:
	var now_s: float = float(game_seconds.call()) if game_seconds.is_valid() else 0.0
	return now_s - float(_picked.get(flora_key, -1.0e12)) < REGROW_GAME_S


func gather(peer: int, species_name: String, kind: String, flora_key: String, flora_id: int, plant_position: Vector3, plant_height: float = -1.0) -> bool:
	plant_stays = false
	if not _peer_pos.has(peer) or _peer_pos[peer].distance_to(plant_position) > Interact.server_reach_m():
		return false

	var now_ms: int = Time.get_ticks_msec()

	if now_ms - int(_last_gather.get(peer, -100000)) < gather_pace_ms:
		return false

	_last_gather[peer] = now_ms
	var now_s: float = float(game_seconds.call()) if game_seconds.is_valid() else 0.0

	if now_s - float(_picked.get(flora_key, -1.0e12)) < REGROW_GAME_S:
		return false

	if (_drops.get("fruit_tree", {}) as Dictionary).has(species_name):
		return _gather_fruit_tree(peer, species_name, flora_key, plant_height, flora_id)

	var berry: Dictionary = GatherRules.harvest_row(_drops, species_name)      # berries and every other harvest plant: one path

	if not berry.is_empty():
		return _gather_berries(peer, species_name, flora_key, berry, plant_height)

	var rows: Array = _drops.get("by_species", {}).get(species_name, _drops.get("by_kind", {}).get(kind, []))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(flora_id) ^ int(now_s / REGROW_GAME_S) ^ 0x5bd1e995
	var entry: Dictionary = _flora_by_name.get(species_name, {})

	if not entry.is_empty() and season_now.is_valid() and not GatherRules.in_season(entry, str(season_now.call())):
		return false   # out of season: nothing to pick (the client shows no prompt either); refused quietly, no item and no tool wear
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

	var seed_rows: Array = _seed_rows(species_name)

	if rows.is_empty() and natural == "" and seed_rows.is_empty():
		return false

	var more: float = skill_factor(peer, "gather_plant")
	practice(peer, "gather_plant")

	for row in rows:
		give(peer, table.number_of(str(row[0])), maxi(1, int(round(float(roll_amount(peer, rng, int(row[1]), int(row[2]))) * more))))

	if natural != "":
		give(peer, table.number_of(natural), maxi(1, int(round(float(roll_amount(peer, rng, 1, 3)) * more))))

	for row in seed_rows:
		give(peer, table.number_of(str(row[0])), roll_amount(peer, rng, int(row[1]), int(row[2])))

	_picked[flora_key] = now_s
	_dirty = true
	return true


# Wild seeds a plant gives in this season (drops.json seed_drops), [] when none.
func _seed_rows(species_name: String) -> Array:
	var def: Dictionary = (_drops.get("seed_drops", {}) as Dictionary).get(species_name, {})

	if def.is_empty():
		return []

	var season: String = str(season_now.call()) if season_now.is_valid() else "all"
	return def.get("rows", []) if (def.get("seasons", []) as Array).has(season) else []


# A berry bush (data/items/drops.json "berry_yield"): E gives that berry only, count scaled by the plant's size, in its season, once a season;
# the plant stays standing and bare until the season changes (Dave 2026-10-23). A full pack: give() drops the rest on the ground at the
# player, beside the plant, so everything is taken and the bush is stripped.
# How many pieces of fruit a tree holds when full: the species range, by the tree's height against the species reference (0.6 to 1.5 times) and a stable
# variance from its id, so no two trees match and the same tree always holds the same.
func fruit_max(species_name: String, flora_id: int, plant_height: float) -> int:
	var cfg: Dictionary = (_drops.get("fruit_tree", {}) as Dictionary).get(species_name, {})

	if cfg.is_empty():
		return 0

	return GatherRules.fruit_max(cfg, _flora_by_name.get(species_name, {}), flora_id, plant_height)


# Pieces taken from a tree this season (0 when none, or from an older season).
func fruit_taken(flora_key: String) -> int:
	var parts: PackedStringArray = flora_key.rsplit(",", true, 1)
	var stamp: int = int(season_stamp.call()) if season_stamp.is_valid() else 0
	var record: Array = (_fruit.get(parts[0], {}) as Dictionary).get(int(parts[1]), [])
	return int(record[1]) if record.size() == 2 and int(record[0]) == stamp else 0


# The trees of a chunk ("cx,cz" home key) with fruit taken this season: [ids, taken] for a joining client.
func fruit_state(chunk_key: String) -> Array:
	var ids: PackedInt32Array = PackedInt32Array()
	var taken: PackedInt32Array = PackedInt32Array()
	var stamp: int = int(season_stamp.call()) if season_stamp.is_valid() else 0

	for tree in (_fruit.get(chunk_key, {}) as Dictionary):
		var record: Array = _fruit[chunk_key][tree]

		if int(record[0]) == stamp:
			ids.append(int(tree))
			taken.append(int(record[1]))

	return [ids, taken]


# Pieces of fruit left on a tree this season (a new season starts it full again).
func fruit_left(species_name: String, flora_key: String, flora_id: int, plant_height: float) -> int:
	var parts: PackedStringArray = flora_key.rsplit(",", true, 1)
	var stamp: int = int(season_stamp.call()) if season_stamp.is_valid() else 0
	var record: Array = (_fruit.get(parts[0], {}) as Dictionary).get(int(parts[1]), [])
	var taken: int = int(record[1]) if record.size() == 2 and int(record[0]) == stamp else 0
	return maxi(fruit_max(species_name, flora_id, plant_height) - taken, 0)


# One press on a fruit tree: up to per_pick pieces, as many as the weight limit lets the player carry, from the tree's real store (shared by all players, saved).
# Partial picks leave the rest on the tree; the last piece strips the tree (the existing bare-plant mark: no prompt, drawn bare) until the next season.
func _gather_fruit_tree(peer: int, species_name: String, flora_key: String, plant_height: float, flora_id: int) -> bool:
	var entry: Dictionary = _flora_by_name.get(species_name, {})
	var season: String = str(season_now.call()) if season_now.is_valid() else "all"

	if not GatherRules.in_season(entry, season):
		return false

	var parts: PackedStringArray = flora_key.rsplit(",", true, 1)
	var plant: int = int(parts[1])
	var stamp: int = int(season_stamp.call()) if season_stamp.is_valid() else 0
	var left: int = fruit_left(species_name, flora_key, flora_id, plant_height)

	if left <= 0:
		return false

	var item_row: Dictionary = GatherRules.harvest_row(_drops, species_name)
	var number: int = table.number_of(str(item_row.get("item", "")))
	var inv = inventory_of(peer)

	if number == 0 or inv == null:
		return false

	var want: int = mini(int((_drops["fruit_tree"][species_name] as Dictionary).get("per_pick", 5)), left)
	var fits: int = _fit(peer, inv, number, want)

	if fits <= 0:
		_say(peer, "Too heavy to carry more")
		return false

	practice(peer, "gather_plant")
	var given: int = give(peer, number, fits)

	if given <= 0:
		return false

	if not _fruit.has(parts[0]):
		_fruit[parts[0]] = {}

	var record: Array = (_fruit[parts[0]] as Dictionary).get(plant, [])
	var taken: int = int(record[1]) if record.size() == 2 and int(record[0]) == stamp else 0
	_fruit[parts[0]][plant] = [stamp, taken + given]

	if left - given <= 0:
		if not _stripped.has(parts[0]):
			_stripped[parts[0]] = {}

		_stripped[parts[0]][plant] = stamp

	plant_stays = true   # the tree stays; its store is what shrinks
	_dirty = true
	return true


func _gather_berries(peer: int, species_name: String, flora_key: String, berry: Dictionary, plant_height: float) -> bool:
	var entry: Dictionary = _flora_by_name.get(species_name, {})
	var seasons: Array = entry.get("season", [])
	var season: String = str(season_now.call()) if season_now.is_valid() else "all"

	if not (seasons.is_empty() or seasons.has("all") or seasons.has(season)):
		_say(peer, "Not in season")
		return false

	var parts: PackedStringArray = flora_key.rsplit(",", true, 1)
	var plant: int = int(parts[1])
	var stamp: int = int(season_stamp.call()) if season_stamp.is_valid() else 0

	if int((_stripped.get(parts[0], {}) as Dictionary).get(plant, -1)) == stamp:
		_say(peer, "Nothing left to pick this season")
		return false

	var number: int = table.number_of(str(berry["item"]))

	if number == 0:
		return false

	var count: int = GatherRules.harvest_count(berry, GatherRules.harvest_scale(_drops, plant_height, entry))      # the one count rule (Dave: size scaled, 3x cap, rounded up, never 0)
	practice(peer, "gather_plant")
	give(peer, number, count)

	var seed_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	seed_rng.seed = hash(flora_key) ^ stamp ^ 0x2545f491

	for row in _seed_rows(species_name):   # wild seeds beside the harvest (drops.json seed_drops, e.g. wild carrot)
		give(peer, table.number_of(str(row[0])), roll_amount(peer, seed_rng, int(row[1]), int(row[2])))

	if not _stripped.has(parts[0]):
		_stripped[parts[0]] = {}

	_stripped[parts[0]][plant] = stamp
	plant_stays = true
	_dirty = true
	return true


# The ids of a chunk's plants that are bare this season ("cx,cz" is the chunk's home key); for a joining client's chunk.
func stripped_ids(chunk_key: String) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var stamp: int = int(season_stamp.call()) if season_stamp.is_valid() else 0

	for plant in _stripped.get(chunk_key, {}):
		if int(_stripped[chunk_key][plant]) == stamp:
			out.append(int(plant))

	return out


# Fruit stores of this season only (an older stamp means the tree is full again).
func _fruit_now() -> Dictionary:
	var stamp: int = int(season_stamp.call()) if season_stamp.is_valid() else 0

	for chunk_key in _fruit.keys():
		var trees: Dictionary = _fruit[chunk_key]

		for tree in trees.keys():
			if int((trees[tree] as Array)[0]) != stamp:
				trees.erase(tree)

		if trees.is_empty():
			_fruit.erase(chunk_key)

	return _fruit


# Only this season's bare plants are kept (and saved): an older stamp means the bush bears again.
func _stripped_now() -> Dictionary:
	var stamp: int = int(season_stamp.call()) if season_stamp.is_valid() else 0

	for chunk_key in _stripped.keys():
		var ids: Dictionary = _stripped[chunk_key]

		for plant in ids.keys():
			if int(ids[plant]) != stamp:
				ids.erase(plant)

		if ids.is_empty():
			_stripped.erase(chunk_key)

	return _stripped


func _tool_for(item_id: String) -> String:
	return GatherRules.tool_for(item_id, _drops)


# The factor for an action's PACE (cooldowns and craft time): the skill factor times the Rested buff's action_speed_mult (comfort.json rested.tiers; 1.0 without the buff).
func _pace_factor(peer: int, action_name: String) -> float:
	return skill_factor(peer, action_name) * float(rested_tier(peer).get("action_speed_mult", 1.0)) / cold_pace(peer)


# What a skill does to an action (data/items/skills.json): 1.0 until the skill system exists. Never below 0.25 or above 4.
func skill_factor(peer: int, action_name: String) -> float:
	var def: Dictionary = _skills_cfg.get("actions", {}).get(action_name, {})

	if def.is_empty():
		return 1.0

	if skill_level.is_valid():
		return clampf(float(skill_level.call(peer, str(def.get("skill", "")))), 0.25, 4.0)

	var skill: String = str(def.get("skill", ""))
	return clampf(SkillWeb.factor(_skills_cfg, skill, working_level(peer, skill), attributes_of(peer)), 0.25, 4.0)


# --- Skills (job 87, data/items/skills.json) ---
# Practice comes only from successes the server verified, through practice(). Records live in the character record
# (characters.json "skills"), attributes beside luck and fitness; an old character simply has none and is neutral.

func attributes_of(peer: int) -> Dictionary:
	var row: Dictionary = _characters.get(_peer_key.get(peer, ""), {})
	return {"strength": float(row.get("strength", 0)), "memory": float(row.get("memory", 0)), "fitness": float(fitness_of(peer)),
		"dexterity": float(row.get("dexterity", 0)), "perception": float(row.get("perception", 0)), "charisma": float(row.get("charisma", 0))}


func set_attribute(peer: int, name: String, value: int) -> void:
	if _characters.has(_peer_key.get(peer, "")) and (_skills_cfg.get("traits", []) as Array).has(name):
		_characters[_peer_key[peer]][name] = clampi(value, -10, 10)
		_dirty = true
		_sync_skills(peer, true)


func _skill_records(peer: int) -> Dictionary:
	var row: Dictionary = _characters.get(_peer_key.get(peer, ""), {})

	if row.is_empty():
		return {}

	if not row.has("skills"):
		row["skills"] = {}

	return row["skills"]


func working_level(peer: int, skill: String) -> float:
	var records: Dictionary = _skill_records(peer)
	var now_s: float = float(game_seconds.call()) if game_seconds.is_valid() else 0.0

	for id in records:
		SkillRules.decay(_skills_cfg, records[id], now_s)

	return SkillWeb.working(_skills_cfg, skill, records)


# One verified success at `action` (a skills.json action): practice for its skill (80 percent) and the parent group (20 percent).
# Nothing for trivial work, a cooldown per skill, a soft cap per game day; returns the points the skill gained.
func practice(peer: int, action_name: String, difficulty: float = 1.0) -> float:
	var def: Dictionary = _skills_cfg.get("actions", {}).get(action_name, {})
	var records: Dictionary = _skill_records(peer)

	if def.is_empty() or not _characters.has(_peer_key.get(peer, "")):
		return 0.0

	var skill: String = str(def.get("skill", ""))
	var system: Dictionary = _skills_cfg.get("system", {})
	var now: int = Time.get_ticks_msec()
	var last: Dictionary = _last_practice.get(peer, {})

	if float(now - int(last.get(skill, -100000))) < float(system.get("cooldown_s", 2.0)) * 1000.0:
		return 0.0

	last[skill] = now
	_last_practice[peer] = last
	var now_s: float = float(game_seconds.call()) if game_seconds.is_valid() else 0.0
	var d: float = difficulty * float(def.get("difficulty", 1.0)) * float(rested_tier(peer).get("skill_gain_mult", 1.0))   # Rested: skills come a little faster
	var gained: float = SkillWeb.practice(_skills_cfg, skill, attributes_of(peer), records, d, now_s)

	if gained > 0.0:
		_dirty = true
		_sync_skills(peer, false)

	return gained


# Training level up (a trainer, a teacher or an admin calls this; the trainer action itself comes with the NPC step):
# returns "" on success or why not. teacher_peer < 0 trains without a teacher (admin and tests).
func train_skill(peer: int, skill: String, teacher_peer: int = -1) -> String:
	var records: Dictionary = _skill_records(peer)

	if records.is_empty() and not _characters.has(_peer_key.get(peer, "")):
		return "no such character"

	var now_s: float = float(game_seconds.call()) if game_seconds.is_valid() else 0.0
	var teacher_value: float = -1.0
	var teacher_level: int = 99

	if teacher_peer >= 0:
		if teacher_peer == peer or _peer_key.get(teacher_peer, "") == _peer_key.get(peer, "x"):
			return "you cannot teach yourself"

		var theirs: Dictionary = _skill_records(teacher_peer)
		teacher_value = SkillWeb.effective(_skills_cfg, skill, theirs)
		teacher_level = int(theirs.get(skill, {}).get("t", 0))

	var problem: String = SkillWeb.train(_skills_cfg, skill, records, now_s, teacher_value, teacher_level)

	if problem == "":
		_dirty = true
		_sync_skills(peer, true)

	return problem


# A trainer NPC (authored dialogue only): trains `skill` one level for `cost` (an item id and count, or empty), as a teacher who
# can teach up to level `max_level`. Returns "" on success or why not; nothing is taken when it fails.
func npc_train(peer: int, skill: String, max_level: int, cost_id: String = "", cost_n: int = 0, dry: bool = false) -> String:
	var records: Dictionary = _skill_records(peer)

	if records.is_empty() and not _characters.has(_peer_key.get(peer, "")):
		return "no such character"

	var now_s: float = float(game_seconds.call()) if game_seconds.is_valid() else 0.0
	var problem: String = SkillWeb.train_problem(_skills_cfg, skill, records, now_s, 100.0, max_level)

	if problem == "" and cost_id != "" and count_for(peer, cost_id) < cost_n:
		problem = "not enough to pay"

	if problem != "" or dry:
		return problem

	if cost_id != "":
		take_from(peer, cost_id, cost_n)

	return train_skill(peer, skill, -1)


func _sync_skills(peer: int, force: bool) -> void:
	if not send_skills.is_valid() or not _characters.has(_peer_key.get(peer, "")):
		return

	var now: int = Time.get_ticks_msec()

	if not force and now < int(_skills_send_in.get(peer, 0)):
		return

	var records: Dictionary = _skill_records(peer)
	var attrs: Dictionary = attributes_of(peer)
	var now_s: float = float(game_seconds.call()) if game_seconds.is_valid() else 0.0
	var rows: Array = []
	var index: int = 0

	for id in _skills_cfg.get("skills", {}):
		var eff: float = SkillWeb.effective(_skills_cfg, str(id), records)

		if records.has(id) or eff > 1.0:
			if records.has(id):
				SkillRules.decay(_skills_cfg, records[id], now_s)

			var rec: Dictionary = records.get(id, {})
			var today: int = 1 if int(rec.get("day", -1)) == int(now_s / 86400.0) and float(rec.get("dgain", 0.0)) > 0.0 else 0
			var raw: float = SkillWeb.raw_value(_skills_cfg, str(id), rec)
			var day_left: float = 1.0 - (float(rec.get("dgain", 0.0)) / maxf(float(_skills_cfg.get("system", {}).get("day_cap_units", 300.0)), 1.0) if today == 1 else 0.0)
			# [index, working level, rusty, cap, own training level, practised today, effective value, percent of the way to the next level, percent of today's gain left]
			rows.append([index, int(round(SkillWeb.working(_skills_cfg, str(id), records))), 1 if rec.has("p") and SkillRules.rusty(_skills_cfg, rec) else 0, SkillWeb.cap_of(_skills_cfg, str(id), records), int(rec.get("t", 0)), today, int(floor(eff)), int((raw - floorf(raw)) * 100.0), clampi(int(round(day_left * 100.0)), 0, 100)])

		index += 1

	var sent_key: Array = [int(attrs["strength"]), int(attrs["memory"]), rows]

	if not force and _skills_sent.get(peer, []) == sent_key:
		return

	_skills_sent[peer] = sent_key
	_skills_send_in[peer] = now + int(float(_skills_cfg.get("system", {}).get("send_every_s", 5.0)) * 1000.0)
	send_skills.call(peer, PackedInt32Array([int(attrs["strength"]), int(attrs["memory"])]), rows)


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


# Removes the loose dropped things (not trunks, stumps, fires, structures, boulders or the natural scatter) within `radius` of `centre`;
# the next sync tells the players they are gone. Dave 2026-10-23: 64 loose items within 12 m refused every drop, so he could not empty his pack.
func clear_dropped(centre: Vector3, radius: float) -> int:
	var gone: int = 0

	for id in _items.keys():
		var other: Dictionary = _items[id]

		if other.has("scatter") or other.has("showroom") or other.has("struct") or other.has("fire") or other.has("tree") or other.has("boulder"):
			continue

		if Vector2(other["pos"].x - centre.x, other["pos"].z - centre.z).length() <= radius:
			_items.erase(id)
			gone += 1

	if gone > 0:
		_dirty = true

	return gone


# A spot let go in the air comes down to the ground below it (up to 24 m); where nothing is known it stays.
func _settled(position: Vector3) -> Vector3:
	if not floor_below.is_valid():
		return position

	var rest: float = float(floor_below.call(position))
	return Vector3(position.x, rest, position.z) if not is_nan(rest) and rest < position.y - 0.05 else position


# After a dig or fill: loose items near it come down (or stay) onto what the ground is now.
func settle_loose_near(centre: Vector3, radius: float) -> void:
	for id in _items:
		var it: Dictionary = _items[id]

		if it.has("scatter") or it.has("struct") or it.has("fire") or it.has("tree") or it.has("boulder"):
			continue

		if it["pos"].distance_to(centre) <= radius + 1.5:
			it["pos"] = _settled(it["pos"])
			_dirty = true


func world_item_count() -> int:
	return _items.size()


func _drop(peer: int, inv, slot: int, count: int, at: Vector3) -> void:
	if slot < 0 or slot >= inv.SLOTS or inv.numbers[slot] == 0 or count <= 0:
		return

	var here: Vector3 = _peer_pos.get(peer, at)
	var spot: Vector3 = at if at.distance_to(here) <= DROP_REACH_M else here
	var number: int = inv.numbers[slot]
	var amount: int = mini(count, inv.counts[slot])

	if not drop_in_world(number, amount, spot, inv.wear[slot], 0.0, NAN, NAN, key_of(peer)):
		_say(peer, "Too many dropped things already lie within a few steps. Pick some up or move a little way off.")
		return

	inv.take_from_slot(slot, amount)


# A thrown weapon leaves the inventory and flies; where it comes down it lies as a world item.
# Only items marked as weapons can be thrown. Nothing can be hit yet (no creatures).
# Floating damage numbers (Dave 2 Nov 2026: on by default, a toggle in Gameplay). An animal shows the damage it took. A tree or a boulder has no health,
# so it counts as HIT_POINTS split over the blows it takes: each blow shows its share (a 10-blow tree shows 10 a blow).
const HIT_POINTS := 100.0


func hit_number(peer: int, at: Vector3, amount: float) -> void:
	if send_hit_number.is_valid() and amount > 0.0:
		send_hit_number.call(peer, at, maxi(1, int(round(amount))))


# One jab with a weapon (items.json "damage"): hits the animal in front within JAB_REACH_M through the animal hook.
func _strike(peer: int, inv, slot: int, direction: Vector3) -> void:
	if slot < 0 or slot >= inv.SLOTS or inv.numbers[slot] == 0 or not _peer_pos.has(peer) or direction.length() < 0.1 or not hit_animal.is_valid():
		return

	var entry: Dictionary = table.entry(table.id_of(inv.numbers[slot]))

	if str(entry.get("kind", "")) != "weapon" or _is_broken(inv.numbers[slot], inv.wear[slot]) or float(entry.get("damage", 0.0)) <= 0.0:
		return

	var now: int = Time.get_ticks_msec()

	if now - int(_last_strike.get(peer, -100000)) < STRIKE_COOLDOWN_MS:
		return

	_last_strike[peer] = now
	var eye: Vector3 = _peer_pos[peer] + Vector3(0.0, 1.4, 0.0)
	var hit: bool = bool(hit_animal.call(peer, eye, direction, JAB_REACH_M, float(entry["damage"])))

	if hit:
		hit_number(peer, eye + direction.normalized() * minf(JAB_REACH_M, 1.5), float(entry["damage"]))
		_wear_slot(peer, inv, slot, "strike")


# A carcass where an animal died (and for the admin test carcass): a struct the player works with a knife. Not saved, rots in 2 game days.
func make_carcass(species: String, pos: Vector3, hunter: int = -1) -> int:
	if not _carcass_cfg.get("species", {}).has(species) or not _structures.has("carcass"):
		return 0

	if hunter >= 0:
		practice(hunter, "hunt", float(_carcass_cfg["species"][species].get("hunt_difficulty", 1.0)))
		practice(hunter, "track", 0.5)   # following the game to the kill; Tracking also trains from the trail-reading event when it exists

	var ground: float = float(ground_height.call(pos.x, pos.z)) if ground_height.is_valid() else pos.y
	var spot: Vector3 = Vector3(pos.x, ground if not is_nan(ground) else pos.y, pos.z)
	var id: int = _next_id
	_next_id += 1
	_items[id] = {"number": table.number_of("carcass"), "count": 1, "pos": spot, "left": CARCASS_LIFE_S, "struct": {"kind": "carcass", "yaw": float(hash(id) % 360), "species": species, "blows": 0, "transient": true}}
	return id


# One knife blow on a carcass (data/items/carcass.json): the parts are rolled once (luck applies) and handed out over the blows.
func _process_carcass(peer: int, inv, id: int) -> void:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not _peer_pos.has(peer) or str(it.get("struct", {}).get("kind", "")) != "carcass" or not _has_tool(inv, str(_carcass_cfg.get("tool_class", "knife"))):
		return

	if _peer_pos[peer].distance_to(it["pos"]) > CARCASS_REACH_M:
		return

	var now: int = Time.get_ticks_msec()

	if now - int(_last_process.get(peer, -100000)) < PROCESS_COOLDOWN_MS:
		return

	_last_process[peer] = now
	var st: Dictionary = it["struct"]
	var blows_total: int = int((_carcass_cfg.get("species", {}).get(str(st.get("species", "")), {}) as Dictionary).get("blows", _carcass_cfg.get("blows", 4)))   # per species (carcass.json species row), else the global number
	_wear_tool(peer, inv, str(_carcass_cfg.get("tool_class", "knife")), "carcass")

	if not st.has("parts"):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = hash(id) ^ 0x2f6b
		st["parts"] = []

		for row in _carcass_cfg.get("species", {}).get(str(st["species"]), {}).get("parts", []):
			var rolled: int = roll_amount(peer, rng, int(row[1]), int(row[2]))
			st["parts"].append([str(row[0]), maxi(int(round(float(rolled) * skill_factor(peer, "dress_carcass"))), 1) if rolled > 0 else 0])

	var left_blows: int = maxi(blows_total - int(st["blows"]), 1)

	for part in st["parts"]:
		var share: int = ceili(float(part[1]) / float(left_blows))

		if share > 0:
			give(peer, table.number_of(str(part[0])), share)
			part[1] = int(part[1]) - share

	st["blows"] = int(st["blows"]) + 1

	if int(st["blows"]) >= blows_total:
		_items.erase(id)
		practice(peer, "dress_carcass")
		_goal_event(peer, "carcass_worked")

	_dirty = true


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
	_flights.append({"number": number, "wear": spent, "peer": peer, "pos": _peer_pos[peer] + Vector3(0.0, EYE_HEIGHT, 0.0), "vel": direction.normalized() * THROW_SPEED, "age": 0.0})


# ACT_SHOOT: one arrow from the bow in slot `slot`, drawn for `draw_ms` (never trusted: clamped), along `direction`. Plan 4b, data/items/bow.json.
# `loaded` is the arrow item the bow is loaded with (Dave 10 Nov 2026: arrows dragged onto the bow); 0, or one not in the pack: the first ammo there.
# The bow skill (the hunting skill's working level) turns the shot by up to aim.spread_deg at random (luck narrows it) and sets aim.damage_mult (BowAim).
func _shoot(peer: int, inv, slot: int, draw_ms: int, direction: Vector3, loaded: int = 0) -> void:
	if slot < 0 or slot >= inv.SLOTS or inv.numbers[slot] == 0 or not _peer_pos.has(peer) or direction.length() < 0.1:
		return

	var entry: Dictionary = table.entry(table.id_of(inv.numbers[slot]))

	if not BowAim.shoots(entry) or _is_broken(inv.numbers[slot], inv.wear[slot]):
		return

	if _bow == null:
		_bow = BowScript.new()

	var bow_id: String = table.id_of(inv.numbers[slot])

	var now: int = Time.get_ticks_msec()

	if now - int(_last_shot.get(peer, -100000)) < int(_bow.cfg.get("pace_ms", 700)):
		return

	var ammo: int = _bow.ammo_slot(inv, table, loaded, bow_id)

	if ammo < 0:
		_say(peer, BowAim.say(_bow.cfg, bow_id, "say_no_ammo"))
		return

	_last_shot[peer] = now
	var arrow: Dictionary = table.entry(table.id_of(inv.numbers[ammo]))
	var number: int = inv.numbers[ammo]
	inv.take_from_slot(ammo, 1)
	var power: float = _bow.power(draw_ms)

	if power <= float(_bow.cfg.get("weak_power", 0.25)):
		_say(peer, str(_bow.cfg.get("say_weak", "")))

	_wear_slot(peer, inv, slot, "strike")
	var level: float = working_level(peer, "hunting")
	var aim: Vector3 = BowAim.spread(direction, BowAim.spread_deg(_bow.cfg, level), LuckScript.low(_aim_rng.randf(), luck_of(peer), _luck_strength()), _aim_rng.randf())   # luck-exempt: the draws that luck nudges (how far out) and which way
	var fire_cfg: Dictionary = _bow.cfg.get("fire_arrow", {})
	var aflame: bool = bool(arrow.get("fire", false)) and not fire_cfg.is_empty() and _flame_near(_peer_pos[peer], float(fire_cfg.get("light_m", 3.0)))
	var damage: float = _bow.damage(float(arrow.get("damage", 5.0)), power, level, bow_id) * (float(fire_cfg.get("damage_mult", 1.5)) if aflame else 1.0)
	_arrows.append({"peer": peer, "number": number, "tip": str(arrow.get("tip", "wood")), "damage": damage, "fire": aflame,
		"pos": _peer_pos[peer] + Vector3(0.0, EYE_HEIGHT, 0.0), "vel": aim * _bow.speed(power, bow_id), "flown": 0.0, "age": 0.0, "range": _bow.range_m(bow_id), "sticks": BowAim.sticks(_bow.cfg, bow_id)})

	if animal_alarm.is_valid():
		animal_alarm.call(_peer_pos[peer], float(_bow.cfg.get("noise_m", 40.0)) * (float(fire_cfg.get("alarm_mult", 2.0)) if aflame else 1.0))


# A flame to light a fire arrow from (bow.json fire_arrow.light_m, Part C plan 6): a burning fire, a lit placed light or torch, or a
# player bearing a burning torch, within `reach` of `at`.
func _flame_near(at: Vector3, reach: float) -> bool:
	for row in _lit_rows():
		if (row[0] as Vector3).distance_to(at) <= reach:
			return true

	var now: int = Time.get_ticks_msec()

	for peer in _torch_seen:
		if now - int(_torch_seen[peer]) <= TORCH_REPORT_MS and _peer_pos.has(peer) and (_peer_pos[peer] as Vector3).distance_to(at) <= reach:
			return true

	for id in _items:
		var it: Dictionary = _items[id]

		if it.has("struct") and bool(it["struct"].get("lit", false)) and (it["pos"] as Vector3).distance_to(at) <= reach:
			return true

	return false


# A burning fire arrow comes down (Part C plan 6): a laid fire with wood on it, or an unlit placed light (a torch post), within
# fire_arrow.ignite_m of where it fell catches. Open rain still beats it, as with a lit hand. No spread: nothing else burns.
func _arrow_ignite(at: Vector3) -> String:
	var reach: float = float(_bow.cfg.get("fire_arrow", {}).get("ignite_m", 0.6))
	var raining: bool = rain_now.is_valid() and float(rain_now.call()) >= RAIN_PUTS_OUT

	for id in _items:
		var it: Dictionary = _items[id]

		if Vector2(it["pos"].x - at.x, it["pos"].z - at.z).length() > reach or absf(it["pos"].y - at.y) > 2.0:
			continue

		if it.has("fire"):
			var fire: Dictionary = it["fire"]

			if int(fire["state"]) in [9, FIRE_STATE_ASH] and float(fire.get("burn_left", 0.0)) > 0.0 and not (raining and not bool(fire.get("covered", false))):
				fire["state"] = _fire_best_state(fire)
				fire.erase("wet_s")
				it["left"] = 1.0e9
				_lit_valid = false
				_dirty = true
				return "fire"
		elif it.has("struct") and not bool(it["struct"].get("lit", false)):
			var def: Dictionary = _structures.get(str(it["struct"]["kind"]), {})
			var sheltered: bool = cover_at.is_valid() and float(cover_at.call(it["pos"])) > 0.5

			if str(def.get("use", "")) == "light" and def.has("fuel") and not (raining and bool(def.get("rain_douses", false)) and not sheltered):
				it["struct"]["lit"] = true
				it["struct"]["fuel_left"] = maxf(float(it["struct"].get("fuel_left", 0.0)), light_burn_s(def))
				_lit_valid = false
				_dirty = true
				return "light"

	return ""


# Arrows in the air, in steps of step_s: the first animal on the segment is hurt, otherwise the ground (or water) or the range ends the flight.
func _arrow_fly(delta: float) -> void:
	if _arrows.is_empty():
		return

	var step: float = float(_bow.cfg.get("step_s", 0.05))
	var left: float = delta

	while left > 0.0 and not _arrows.is_empty():
		var dt: float = minf(left, step)
		left -= dt

		for ar in _arrows.duplicate():
			var from: Vector3 = ar["pos"]
			ar["vel"].y -= THROW_GRAVITY * dt
			var to: Vector3 = from + ar["vel"] * dt
			ar["flown"] += from.distance_to(to)
			ar["age"] += dt
			var landed: bool = false
			var hit_animal_now: bool = false
			var at: Vector3 = to
			var stuck: bool = false

			if hit_animal_path.is_valid():
				var hit: Dictionary = hit_animal_path.call(int(ar["peer"]), from, to, float(ar["damage"]))

				if not hit.is_empty():
					landed = true
					hit_animal_now = true
					at = hit["at"]
					practice(int(ar["peer"]), "bow")
					hit_number(int(ar["peer"]), at, float(ar["damage"]))

			var at_foot: bool = false

			if not landed and trunks_near.is_valid():   # a tree trunk on the way: the arrow sticks in it (Dave 10 Nov 2026); a sling stone drops at its foot
				var into: float = _arrow_trunk(from, to)

				if into >= 0.0:
					landed = true
					stuck = bool(ar.get("sticks", true))
					at_foot = not stuck
					at = from.lerp(to, into)

			var ground: float = float(ground_height.call(to.x, to.z)) if ground_height.is_valid() else -1000000.0

			if at_foot and not is_nan(ground):
				at.y = float(ground_height.call(at.x, at.z))

			if not landed and ((not is_nan(ground) and to.y <= ground) or float(ar["flown"]) >= float(ar.get("range", _bow.range_m())) or float(ar["age"]) >= THROW_MAX_S * 2.0):
				landed = true
				at = Vector3(to.x, ground if not is_nan(ground) else to.y, to.z)

			ar["pos"] = to

			if not landed:
				continue

			_arrows.erase(ar)
			var wet: bool = water_depth_at.is_valid() and float(water_depth_at.call(at)) > 0.05

			if bool(ar.get("fire", false)):   # a burning arrow is always burnt up; where it falls it may light a fire or a torch post
				var lit_what: String = "" if wet else _arrow_ignite(at)
				print("server items: fire arrow came down at x%d z%d after %.0f m (animal %s): burnt up%s" % [int(at.x), int(at.z), float(ar["flown"]), str(hit_animal_now), (", lit a " + lit_what) if lit_what != "" else ""])
			elif stuck and fate(int(ar["peer"]), "arrow", 1.0 - _bow.lost_chance(str(ar["tip"]), false, false)):
				_stick_arrow(int(ar["number"]), at, (ar["vel"] as Vector3).normalized())
				print("server items: arrow stuck in a tree at x%d z%d y%.1f after %.0f m" % [int(at.x), int(at.z), at.y, float(ar["flown"])])
			elif stuck:
				print("server items: arrow hit a tree at x%d z%d after %.0f m: broke" % [int(at.x), int(at.z), float(ar["flown"])])
			elif fate(int(ar["peer"]), "arrow", 1.0 - _bow.lost_chance(str(ar["tip"]), hit_animal_now, wet)):
				var kept: bool = drop_in_world(int(ar["number"]), 1, at)
				print("server items: arrow landed at x%d z%d y%.1f after %.0f m (animal %s, water %s): %s" % [int(at.x), int(at.z), at.y, float(ar["flown"]), str(hit_animal_now), str(wet), "lying there" if kept else "NOT dropped (crowded or refused)"])
			else:
				print("server items: arrow landed at x%d z%d after %.0f m (animal %s, water %s): broke or lost" % [int(at.x), int(at.z), float(ar["flown"]), str(hit_animal_now), str(wet)])

				if wet:
					_say(int(ar["peer"]), str(_bow.cfg.get("say_lost", "")))


# The share 0..1 along from -> to where the flight first meets a standing trunk, or -1 (BowAim.segment_trunk on each trunk near the segment).
const ARROW_TRUNK_SEARCH_M := 2.0   # the thickest trunk's radius and a little over


func _arrow_trunk(from: Vector3, to: Vector3) -> float:
	var best: float = -1.0

	for trunk in trunks_near.call(from.lerp(to, 0.5), from.distance_to(to) * 0.5 + ARROW_TRUNK_SEARCH_M):
		var t: float = BowAim.segment_trunk(from, to, trunk[0], float(trunk[1]), float(trunk[2]))

		if t >= 0.0 and (best < 0.0 or t < best):
			best = t

	return best


# An arrow stuck in a tree where it hit (Dave 10 Nov 2026: "there should be an arrow in that tree until I collect it or it fades out in 5 minutes"):
# a loose arrow at the hit point, not let down to the ground, turned along its flight (rot_y about the vertical, tilt up), bow.json stuck_s seconds
# (300) unless picked up. It never joins another arrow's pile.
func _stick_arrow(number: int, at: Vector3, along: Vector3) -> void:
	_items[_next_id] = {"number": number, "count": 1, "pos": at, "left": float(_bow.cfg.get("stuck_s", 300.0)), "wear": 0,
		"rot_y": atan2(-along.z, along.x), "tilt": asin(clampf(along.y, -1.0, 1.0))}
	_next_id += 1
	_dirty = true


func _fly(delta: float) -> void:
	_arrow_fly(delta)
	for flight in _flights.duplicate():
		var from: Vector3 = flight["pos"]
		flight["vel"].y -= THROW_GRAVITY * delta
		flight["pos"] += flight["vel"] * delta
		flight["age"] += delta

		# A thrown spear or javelin hits the first animal on its path for the weapon's throw_damage (MikeW, 3 Nov: it flew
		# through them, so a new player could not hunt with the first weapon they make) and drops where it struck.
		var throw_damage: float = float(table.entry(table.id_of(int(flight["number"]))).get("throw_damage", 0.0))

		if throw_damage > 0.0 and hit_animal_path.is_valid() and flight.has("peer"):
			var hit: Dictionary = hit_animal_path.call(int(flight["peer"]), from, flight["pos"], throw_damage)

			if not hit.is_empty():
				var at: Vector3 = hit["at"]
				hit_number(int(flight["peer"]), at, throw_damage)
				var below: float = float(ground_height.call(at.x, at.z)) if ground_height.is_valid() else at.y
				drop_in_world(int(flight["number"]), 1, Vector3(at.x, below if not is_nan(below) else at.y, at.z), int(flight.get("wear", 0)))
				_flights.erase(flight)
				continue

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
		_say_tool_missing(peer, inv, "spade")
		_reject(peer, 1)
		return

	var now: int = Time.get_ticks_msec()
	var reach: float = _spade_reach(inv)

	if float(now - int(_last_dig.get(peer, -100000))) < float(DIG_COOLDOWN_MS) * reach:
		return

	_last_dig[peer] = now

	for n in maxi(1, int(round(reach))):
		_wear_tool(peer, inv, "spade", "dig")

	var dug: Variant = dig_ground.call(at - Vector3(0.0, DIG_DEPTH_M, 0.0), DIG_RADIUS_M * reach)

	# The ground answers false when the dig changed nothing (a block is full, or the hole was already there): no yield, no fall.
	if typeof(dug) == TYPE_BOOL and not bool(dug):
		if dig_refusal.is_valid():
			_say(peer, str(dig_refusal.call()))

		return

	_give_dig_yield(peer, at, _spade_tier(inv), _spade_pieces(inv))

	# A dig more than 2.5 m under the surface is a tunnel or a cave: the "cave_in" hint (hints.json digging_under_ceiling) warns about roof supports.
	if ground_height.is_valid() and float(ground_height.call(at.x, at.z)) - at.y > 2.5:
		_goal_event(peer, "dug_under")

	_fell_undermined(peer, at)
	settle_loose_near(at, DIG_RADIUS_M * reach + DIG_DEPTH_M)
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

	if float(now - int(_last_dig.get(peer, -100000))) < float(DIG_COOLDOWN_MS) * _spade_reach(inv):
		return

	# Raise mode (Dave 2026-10-22): no load, every raise takes shovelfuls from the pack (one for a small spade, 4 medium, 8 large),
	# soil first, then sand, gravel, clay, stone (digging.json "fill"). A short pack raises a smaller heap.
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
	var pieces: int = 0

	for n in _spade_pieces(inv):
		if take_fill_item(peer, material_item) < 1:
			break

		pieces += 1

	if pieces < 1:
		return

	for n in maxi(1, int(round(pow(float(pieces), 1.0 / 3.0)))):
		_wear_tool(peer, inv, "spade", "dig")

	var done: Variant = fill_ground.call(at + Vector3(0.0, FILL_UP_M, 0.0), FILL_RADIUS_M * pow(float(pieces), 1.0 / 3.0), int(FILL_SOIL.get(material_item, 5)))

	if typeof(done) == TYPE_BOOL and not bool(done):
		give(peer, table.number_of(material_item), pieces)   # the ground refused it: the shovelfuls come back

	_dirty = true


# --- The garden hoe (Dave 2026-10-22, items/HOE_AND_SHOVEL_DESIGN.md) ---
# Path: one stroke treads the metre of ground under the crosshair: a path patch (state 32) clears the grass and draws flat tan; the height does
# not change. Smooth: ground is MOVED within SMOOTH_REACH_M of the point, cut from the spots above the average height and put on the spots
# below it (volume balanced), at most SMOOTH_MAX_M a stroke. No items go in or out; the only cost is the hoe's own wear.
const HOE_COOLDOWN_MS := 500
const SMOOTH_REACH_M := 1.5
const SMOOTH_MAX_M := 0.25
const SMOOTH_MIN_M := 0.04
const SMOOTH_SPHERE_M := 0.9
const GRADE_REACH_M := 12.0       # a grade stroke works within this of point A (Dave 2026-10-22)
const GRADE_WIDTH_M := 1.5        # and within this of the straight line A to B


func _hoe_ready(peer: int, inv, at: Vector3) -> bool:
	if not _peer_pos.has(peer):
		return false

	if _peer_pos[peer].distance_to(at) > DIG_REACH_M:
		_reject(peer, 0)
		return false

	if not _has_tool(inv, "hoe"):
		_say_tool_missing(peer, inv, "hoe")
		_reject(peer, 1)
		return false

	var now: int = Time.get_ticks_msec()

	if now - int(_last_dig.get(peer, -100000)) < HOE_COOLDOWN_MS:
		return false

	_last_dig[peer] = now
	return true


# Path (Dave 2 Nov 2026): the stroke first AVERAGES the ground within PATH_AVERAGE_M of the point (ground moved from the high spots to the low ones,
# volume balanced, at most SMOOTH_MAX_M a stroke, like smooth but wider), then lays a round trodden patch exactly where the player pointed (not snapped
# to a grid). The client draws it strong brown for the middle half metre and fading to see-through by 1.25 m. A drag lays one every PATH_SPACING_M.
const PATH_AVERAGE_M := 2.0
const PATH_AVERAGE_MIN_M := 0.08    # ground within a path's reach that is flatter than this is left alone (no edit, no remesh)
const PATH_AVERAGE_OPS := 4         # at most this many ground edits a stroke: every edit is a message to every client, a remesh and a grass rebuild
const PATH_AVERAGE_GAP_MS := 1500   # and the ground is averaged at most this often per player (patches are still laid every stroke)
var _last_average: Dictionary = {}  # peer -> msec of the last averaging
const PATH_SPACING_M := 0.7   # the strong middle is 1 m across, so patches this far apart still join; fewer patches means fewer decals along a road

const PATH_BOULDER_MARGIN_M := 1.0   # a path patch is laid no nearer a boulder's edge than this: its brown fades out to 1.25 m, so the path goes round a rock instead of painting on it (Dave 3 Nov)


func _path_blocked_by_boulder(other: Dictionary, spot: Vector3) -> bool:
	if not other.has("boulder"):
		return false

	return Vector2(other["pos"].x - spot.x, other["pos"].z - spot.z).length() < float((other["boulder"] as Dictionary).get("radius", 0.5)) + PATH_BOULDER_MARGIN_M


func _hoe_path(peer: int, inv, at: Vector3) -> void:
	if not ground_height.is_valid() or not _structures.has("path_patch") or not _hoe_ready(peer, inv, at):
		return

	var ground: float = float(ground_height.call(at.x, at.z))

	if is_nan(ground):
		return

	var spot: Vector3 = Vector3(at.x, ground + 0.02, at.z)

	if water_depth_at.is_valid() and float(water_depth_at.call(Vector3(spot.x, ground, spot.z))) > 0.05:
		_say(peer, "You cannot tread a path in water.")
		return

	var here_chunk: Vector2i = _chunk_of(spot)
	var of_kind: int = 0
	var near_paths: Array = []

	for id in _items:
		var other: Dictionary = _items[id]

		if _path_blocked_by_boulder(other, spot):
			_say(peer, "A rock is in the way: tread the path round it.")
			return

		if not other.has("struct"):
			continue

		if str(other["struct"]["kind"]) == "path_patch":
			var flat: float = Vector2(other["pos"].x - spot.x, other["pos"].z - spot.z).length()

			if flat < PATH_SPACING_M:
				return   # already trodden here

			if flat <= PATH_AVERAGE_M + 1.25:
				near_paths.append(id)

			if _chunk_of(other["pos"]) == here_chunk:
				of_kind += 1
		elif other["pos"].distance_to(spot) < 1.0 and not bool(_structures.get(str(other["struct"]["kind"]), {}).get("walkover", false)):
			_say(peer, "Something stands there.")
			return

	if of_kind >= int(_structures["path_patch"]["cap_per_chunk"]):
		_say(peer, "This ground is paths enough.")
		return

	var spots: Array = [Vector2.ZERO]

	for k in 8:
		spots.append(Vector2.from_angle(float(k) * TAU / 8.0) * PATH_AVERAGE_M * 0.75)

	var moved: bool = false
	var now: int = Time.get_ticks_msec()

	if now - int(_last_average.get(peer, -100000)) >= PATH_AVERAGE_GAP_MS:
		moved = _average_ground(at, spots, PATH_AVERAGE_MIN_M, PATH_AVERAGE_OPS)

		if moved:
			_last_average[peer] = now

	_wear_tool(peer, inv, "hoe", "dig")

	if moved:
		# The ground under the patches laid before has moved: they are laid again on the new surface (new ids, so the clients redraw them).
		for id in near_paths:
			var old: Dictionary = _items[id]
			var old_ground: float = float(ground_height.call(old["pos"].x, old["pos"].z))

			if not is_nan(old_ground) and absf(old_ground + 0.02 - old["pos"].y) > 0.03:
				_items.erase(id)
				_items[_next_id] = {"number": old["number"], "count": 1, "pos": Vector3(old["pos"].x, old_ground + 0.02, old["pos"].z), "left": 1.0e9, "struct": {"kind": "path_patch", "yaw": 0.0}}
				_next_id += 1

		var new_ground: float = float(ground_height.call(at.x, at.z))
		spot.y = (new_ground if not is_nan(new_ground) else ground) + 0.02

	_items[_next_id] = {"number": table.number_of("path_patch"), "count": 1, "pos": spot, "left": 1.0e9, "struct": {"kind": "path_patch", "yaw": 0.0}}
	_next_id += 1
	_dirty = true
	_goal_event(peer, "path_laid")


# Moves ground between the sample spots (offsets from `at`) toward their mean height: cut above, fill below, volume balanced, at most SMOOTH_MAX_M each.
# Returns true when any ground moved.
func _average_ground(at: Vector3, spots: Array, min_m: float = SMOOTH_MIN_M, max_ops: int = 99) -> bool:
	if not dig_ground.is_valid() or not fill_ground.is_valid():
		return false

	var heights: Array = []
	var total: float = 0.0

	for offset in spots:
		var h: float = float(ground_height.call(at.x + offset.x, at.z + offset.y))

		if is_nan(h):
			return false

		heights.append(h)
		total += h

	var mean: float = total / float(spots.size())
	var cut_sum: float = 0.0
	var fill_sum: float = 0.0
	var moves: Array = []   # [index, depth, +1 cut / -1 fill]

	for n in spots.size():
		var d: float = float(heights[n]) - mean

		if absf(d) < min_m:
			continue

		moves.append([n, minf(absf(d), SMOOTH_MAX_M), 1 if d > 0.0 else -1])

	if moves.size() > max_ops:   # only the biggest bumps and dips are worked
		moves.sort_custom(func(p, q): return float(p[1]) > float(q[1]))
		moves = moves.slice(0, max_ops)

	for move in moves:
		if int(move[2]) > 0:
			cut_sum += float(move[1])
		else:
			fill_sum += float(move[1])

	var shifted: float = minf(cut_sum, fill_sum)

	if moves.is_empty() or shifted <= 0.0:
		return false

	var worked: int = 0

	for move in moves:
		var offset: Vector2 = spots[int(move[0])]
		var spot: Vector3 = Vector3(at.x + offset.x, float(heights[int(move[0])]), at.z + offset.y)
		var depth: float = float(move[1]) * shifted / (cut_sum if int(move[2]) > 0 else fill_sum)
		var done: Variant = dig_ground.call(Vector3(spot.x, spot.y - depth + SMOOTH_SPHERE_M, spot.z), SMOOTH_SPHERE_M) if int(move[2]) > 0 else fill_ground.call(Vector3(spot.x, spot.y + depth - SMOOTH_SPHERE_M, spot.z), SMOOTH_SPHERE_M, int(FILL_SOIL["soil"]))

		if typeof(done) != TYPE_BOOL or bool(done):
			worked += 1

	return worked > 0


func _hoe_smooth(peer: int, inv, at: Vector3) -> void:
	if not ground_height.is_valid() or not dig_ground.is_valid() or not fill_ground.is_valid() or not _hoe_ready(peer, inv, at):
		return

	var spots: Array = [Vector2.ZERO, Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0)]

	for offset in spots:
		if is_nan(float(ground_height.call(at.x + offset.x, at.z + offset.y))):
			return

	if not _average_ground(at, spots):
		_say(peer, "The ground here is already smooth, or worked enough.")
		return

	_wear_tool(peer, inv, "hoe", "dig")
	_remove_paths_near(at, SMOOTH_REACH_M + 1.0)
	_dirty = true


# The grade line (roads): point A, point B, then strokes along the line bring the ground toward the straight ramp between their heights.
func _hoe_grade_point(peer: int, inv, _which: int, at: Vector3) -> void:
	if not ground_height.is_valid() or not _peer_pos.has(peer) or _peer_pos[peer].distance_to(at) > DIG_REACH_M or not _has_tool(inv, "hoe"):
		return

	var h: float = float(ground_height.call(at.x, at.z))

	if is_nan(h):
		return

	var here: Vector3 = Vector3(at.x, h, at.z)
	var before: Array = _grade_points.get(peer, [null, null])
	_grade_points[peer] = [before[1] if before[1] != null else here, here]   # the last two markers, for the manual grade stroke
	_road_marker(peer, here)


# The A and B road (Dave 2 Nov 2026): the moment point B is set, the ground along the line from A to B follows the ground, averaged in 3 m sections (no straight ramp)
# between the two heights and a path is laid along it, by itself. Worked a station at a time (one every ROAD_STEP_S, at most ROAD_EDITS ground edits each), so a road
# never freezes the game the way one big edit would; the hoe wears once every ROAD_WEAR_EVERY stations and the job stops if the hoe is gone.
const ROAD_MAX_M := 40.0
const ROAD_STATION_M := 0.7
const ROAD_STEP_S := 0.5
const ROAD_EDITS := 3
const ROAD_WEAR_EVERY := 4
const ROAD_HALF_WIDTH_M := 1.0
const ROAD_DEPTH_M := 0.5
const ROAD_SECTION_M := 3.0   # the ground is averaged over sections this long along the line
var _roads: Dictionary = {}   # peer -> {"head": where the road has got to, "markers": [Vector3] waiting, "seg": null or {"a", "b", "n": stations, "i": next station, "wait": seconds to the next one}}


# Surveyor mode (Dave 3 Nov 2026): the player drops markers while walking. Markers belong to the player who set them (the peer id keys the job, so a
# builder never chases another player's markers). The first marker of an idle job is where the road starts; after that the builder takes the nearest
# remaining marker to where it has got to, builds toward it, deletes it on arrival and goes for the next nearest. The job is done when none are left.
const ROAD_MAX_MARKERS := 24


func _marker_done(peer: int, at: Vector3) -> void:
	if send_marker_done.is_valid():
		send_marker_done.call(peer, at)


func _road_abandon(peer: int, job: Dictionary) -> void:
	_roads.erase(peer)
	_marker_done(peer, job["head"])

	if job["seg"] != null:
		_marker_done(peer, job["seg"]["b"])

	for marker in job["markers"]:
		_marker_done(peer, marker)


func _road_marker(peer: int, here: Vector3) -> void:
	if not _roads.has(peer):
		_roads[peer] = {"head": here, "markers": [], "seg": null}
		_say(peer, "Road started at this marker: set more markers as you walk and the road builds toward the nearest one.")
		return

	var job: Dictionary = _roads[peer]

	if job["markers"].size() >= ROAD_MAX_MARKERS:
		_say(peer, "Too many markers waiting: let the road catch up.")
		return

	job["markers"].append(here)
	_say(peer, "Marker set: the road builds toward the nearest one, then the next.")


# Takes the nearest marker to the head as the next stretch; returns false when no markers are left.
func _road_next_segment(peer: int, job: Dictionary) -> bool:
	var head: Vector3 = job["head"]

	while not job["markers"].is_empty():
		var best: int = 0

		for k in job["markers"].size():
			if Vector2(job["markers"][k].x - head.x, job["markers"][k].z - head.z).length() < Vector2(job["markers"][best].x - head.x, job["markers"][best].z - head.z).length():
				best = k

		var target: Vector3 = job["markers"][best]
		job["markers"].remove_at(best)
		var length: float = Vector2(target.x - head.x, target.z - head.z).length()

		if length > ROAD_MAX_M:
			_say(peer, "A marker is more than %d m from the road: skipped." % int(ROAD_MAX_M))
			_marker_done(peer, target)
			continue

		if length < 1.0:
			job["head"] = target
			head = target
			_marker_done(peer, target)
			continue

		job["seg"] = {"a": head, "b": target, "n": int(ceil(length / ROAD_STATION_M)) + 1, "i": 0, "wait": 0.0}
		return true

	return false


func _road_tick(delta: float) -> void:
	if _roads.is_empty():
		return

	for peer in _roads.keys():
		var job: Dictionary = _roads[peer]
		var inv = inventory_of(peer)

		if inv == null or not _has_tool(inv, "hoe") or not ground_height.is_valid():
			_road_abandon(peer, job)   # the hoe is gone: the road stops and the waiting flags come down
			continue

		if job["seg"] == null and not _road_next_segment(peer, job):
			_roads.erase(peer)   # no markers left: the road is done
			_marker_done(peer, job["head"])
			_say(peer, "The road is finished.")
			continue

		var seg: Dictionary = job["seg"]
		seg["wait"] = float(seg["wait"]) - delta

		if float(seg["wait"]) > 0.0:
			continue

		seg["wait"] = ROAD_STEP_S
		var i: int = int(seg["i"])

		if i >= int(seg["n"]):
			_marker_done(peer, seg["a"])
			_marker_done(peer, seg["b"])
			job["head"] = seg["b"]   # reached the marker: it is deleted (taken off the list when it was chosen) and the next nearest is next
			job["seg"] = null
			continue

		_road_station(peer, inv, seg["a"], seg["b"], i, int(seg["n"]))
		seg["i"] = i + 1


# The ground height a road station is brought to: the average of the ground along the line within ROAD_SECTION_M (3 m) around the station, so the road
# follows the lie of the land and eases over bumps and dips instead of cutting a straight ramp between the two markers (Dave 3 Nov 2026).
func _road_section_height(a: Vector3, b: Vector3, t: float) -> float:
	var length: float = Vector2(b.x - a.x, b.z - a.z).length()
	var total: float = 0.0
	var count: int = 0

	for k in range(-3, 4):
		var tt: float = clampf(t + float(k) * (ROAD_SECTION_M / 6.0) / maxf(length, 0.01), 0.0, 1.0)
		var h: float = float(ground_height.call(lerpf(a.x, b.x, tt), lerpf(a.z, b.z, tt)))

		if not is_nan(h):
			total += h
			count += 1

	return total / float(count) if count > 0 else lerpf(a.y, b.y, t)


func _road_station(peer: int, inv, a: Vector3, b: Vector3, i: int, n: int) -> void:
	var t: float = float(i) / float(maxi(n - 1, 1))
	var along: Vector2 = Vector2(b.x - a.x, b.z - a.z).normalized()
	var side: Vector2 = Vector2(-along.y, along.x)
	var centre: Vector2 = Vector2(a.x, a.z).lerp(Vector2(b.x, b.z), t)
	var target: float = _road_section_height(a, b, t)
	var edits: int = 0
	var wet: bool = water_depth_at.is_valid() and float(water_depth_at.call(Vector3(centre.x, target, centre.y))) > 0.05   # no digging or filling in water: the road goes on over a ford

	if not wet and dig_ground.is_valid() and fill_ground.is_valid():
		for offset in [0.0, ROAD_HALF_WIDTH_M, -ROAD_HALF_WIDTH_M]:
			if edits >= ROAD_EDITS:
				break

			var spot: Vector2 = centre + side * float(offset)
			var h: float = float(ground_height.call(spot.x, spot.y))

			if is_nan(h) or absf(h - target) < PATH_AVERAGE_MIN_M:
				continue

			var depth: float = minf(absf(h - target), ROAD_DEPTH_M)

			if h > target:
				dig_ground.call(Vector3(spot.x, h - depth + SMOOTH_SPHERE_M, spot.y), SMOOTH_SPHERE_M)
			else:
				fill_ground.call(Vector3(spot.x, h + depth - SMOOTH_SPHERE_M, spot.y), SMOOTH_SPHERE_M, int(FILL_SOIL["soil"]))

			edits += 1

	var ground: float = float(ground_height.call(centre.x, centre.y))

	if is_nan(ground):
		return

	var pos: Vector3 = Vector3(centre.x, ground + 0.02, centre.y)

	if _structures.has("path_patch") and not (water_depth_at.is_valid() and float(water_depth_at.call(Vector3(pos.x, ground, pos.z))) > 0.05):
		var blocked: bool = false
		var of_kind: int = 0

		for id in _items:
			var other: Dictionary = _items[id]

			if _path_blocked_by_boulder(other, pos):
				blocked = true
				break

			if not other.has("struct"):
				continue

			if str(other["struct"]["kind"]) == "path_patch":
				if Vector2(other["pos"].x - pos.x, other["pos"].z - pos.z).length() < PATH_SPACING_M:
					blocked = true
					break

				if _chunk_of(other["pos"]) == _chunk_of(pos):
					of_kind += 1
			elif other["pos"].distance_to(pos) < 1.0 and not bool(_structures.get(str(other["struct"]["kind"]), {}).get("walkover", false)):
				blocked = true
				break

		if not blocked and of_kind < int(_structures["path_patch"]["cap_per_chunk"]):
			_items[_next_id] = {"number": table.number_of("path_patch"), "count": 1, "pos": pos, "left": 1.0e9, "struct": {"kind": "path_patch", "yaw": 0.0}}
			_next_id += 1
			_dirty = true
			_goal_event(peer, "path_laid")

	if i % ROAD_WEAR_EVERY == 0:
		_wear_tool(peer, inv, "hoe", "dig")



func _hoe_grade(peer: int, inv, at: Vector3) -> void:
	var pair: Array = _grade_points.get(peer, [null, null])

	if pair[1] == null:
		_say(peer, "Set point A and point B first (Shift + right click).")
		return

	if not ground_height.is_valid() or not dig_ground.is_valid() or not fill_ground.is_valid() or not _hoe_ready(peer, inv, at):
		return

	var a: Vector3 = pair[0]
	var b: Vector3 = pair[1]
	var along: Vector2 = Vector2(b.x - a.x, b.z - a.z)
	var length: float = along.length()

	if length < 1.0:
		_say(peer, "Points A and B are too close together.")
		return

	var dir: Vector2 = along / length
	var worked: int = 0
	var dug: bool = false

	for offset in [Vector2.ZERO, dir, -dir, Vector2(-dir.y, dir.x), Vector2(dir.y, -dir.x)]:
		var x: float = at.x + offset.x
		var z: float = at.z + offset.y
		var from_a: Vector2 = Vector2(x - a.x, z - a.z)
		var t: float = clampf(from_a.dot(dir) / length, 0.0, 1.0)

		if Vector2(x, z).distance_to(Vector2(a.x, a.z) + dir * t * length) > GRADE_WIDTH_M or from_a.length() > GRADE_REACH_M:
			continue

		var h: float = float(ground_height.call(x, z))

		if is_nan(h):
			continue

		var d: float = h - lerpf(a.y, b.y, t)

		if absf(d) < SMOOTH_MIN_M:
			continue

		var depth: float = minf(absf(d), SMOOTH_MAX_M)
		var done: Variant = dig_ground.call(Vector3(x, h - depth + SMOOTH_SPHERE_M, z), SMOOTH_SPHERE_M) if d > 0.0 else fill_ground.call(Vector3(x, h + depth - SMOOTH_SPHERE_M, z), SMOOTH_SPHERE_M, int(FILL_SOIL["soil"]))
		dug = true

		if typeof(done) != TYPE_BOOL or bool(done):
			worked += 1

	if not dug:
		_say(peer, "The ground here is already on the line.")
		return

	if worked == 0:
		_say(peer, "This ground is worked enough.")
		return

	_wear_tool(peer, inv, "hoe", "dig")
	_remove_paths_near(at, SMOOTH_REACH_M + 1.0)
	_dirty = true


# Ground that was moved takes the path on it with it: patches near a smoothed spot are removed (the hoe treads them again).
func _remove_paths_near(at: Vector3, radius: float) -> void:
	for id in _items.keys():
		var it: Dictionary = _items[id]

		if it.has("struct") and str(it["struct"]["kind"]) == "path_patch" and it["pos"].distance_to(at) <= radius:
			_items.erase(id)


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
# Spade sizes (Dave 2026-10-22, digging.json "spade_sizes"): a small shovel moves 1 piece (shovelful) per stroke, a medium 4, a large 8.
# The sphere it digs or raises grows with the cube root of the pieces (so its volume goes with them), and so do its pace and its wear.
func _spade_size(inv) -> Dictionary:
	var slot: int = _tool_slot(inv, "spade")
	var name: String = str(table.entry(table.id_of(inv.numbers[slot])).get("spade_size", "small")) if slot >= 0 else "small"
	return _dig_cfg.get("spade_sizes", {}).get(name, {"pieces": 1})


func _spade_pieces(inv) -> int:
	return maxi(1, int(_spade_size(inv).get("pieces", 1)))


func _spade_reach(inv) -> float:
	return pow(float(_spade_pieces(inv)), 1.0 / 3.0)


func _spade_tier(inv) -> int:
	var slot: int = _tool_slot(inv, "spade")
	return int(table.entry(table.id_of(inv.numbers[slot])).get("tier", 1)) if slot >= 0 else 1


func _give_dig_yield(peer: int, at: Vector3, tier: int = 1, pieces: int = 1) -> void:
	if not ground_material.is_valid() or _dig_cfg.is_empty():
		return

	var material: String = str(ground_material.call(at.x, at.z))
	var rows: Array = _dig_cfg.get("yield", {}).get(material, _dig_cfg.get("default", []))

	for row in rows:
		var number: int = table.number_of(str(row[0]))
		var extra: int = int(_dig_cfg.get("tier_extra", {}).get(str(tier), 0)) if int(row[2]) > int(row[1]) or int(row[2]) > 0 else 0
		var amount: int = roll_amount(peer, _fate_rng, int(row[1]), int(row[2]) + extra)

		if number > 0 and amount > 0:
			give(peer, number, maxi(1, int(round(float(amount) * skill_factor(peer, "dig")))) * pieces)

	_dig_bog_iron(peer, at, tier, pieces)
	practice(peer, "dig")
	var under: Array = _dig_cfg.get("under", {}).get(material, [])

	if under.size() == 2 and roll_chance(peer, _fate_rng, float(under[1])):
		var layer: int = table.number_of(str(under[0]))

		if layer > 0:
			give(peer, layer, 1)

	# digging.json finds: a small chance of something living in the soil (a worm in moist living soil), one per stroke at most.
	for find in _dig_cfg.get("finds", []):
		var found: int = table.number_of(str(find.get("item", "")))

		if found > 0 and material in find.get("soils", []) and roll_chance(peer, _fate_rng, float(find.get("chance", 0.0))):
			give(peer, found, 1)


# Bog iron (digging.json bog_iron, Sonny s11): a dig on a deposit also brings up its ore, on top of the peat or mud. It is per_dig rolled like a
# soil row, plus the spade tier's tier_extra, times the spade size's pieces, never more than is left; the deposit grows back one ore every
# regrow_game_days (BogIron.regrown, worked out at the dig). The first dig that finds any says first_find once to that character.
func _dig_bog_iron(peer: int, at: Vector3, tier: int, pieces: int) -> void:
	var cfg: Dictionary = _dig_cfg.get("bog_iron", {})

	if cfg.is_empty() or not bog_deposit_at.is_valid():
		return

	var deposit: Dictionary = bog_deposit_at.call(at.x, at.z, cfg)
	var number: int = table.number_of(str(cfg.get("item", "iron_ore")))

	if deposit.is_empty() or number <= 0:
		return

	var key: String = str(deposit["key"])
	var size: int = int(deposit["size"])
	var now_s: float = float(game_seconds.call()) if game_seconds.is_valid() else 0.0
	var row: Array = BogIron.regrown(_bog_left.get(key, [size, now_s]), size, now_s, cfg)
	var left: int = int(row[0])

	if left <= 0:
		_bog_left[key] = row
		return

	var per: Array = cfg.get("per_dig", [1, 2])
	var extra: int = int(_dig_cfg.get("tier_extra", {}).get(str(tier), 0))
	var amount: int = mini(maxi(1, int(round(float(roll_amount(peer, _fate_rng, int(per[0]), int(per[1]) + extra)) * skill_factor(peer, "dig")))) * pieces, left)
	give(peer, number, amount)
	_bog_left[key] = [left - amount, float(row[1])]
	_dirty = true
	var st: Dictionary = _goal_state_of(peer)   # the character's record: the line is said once, kept in hints_seen like a hint

	if not st.is_empty():
		if typeof(st.get("hints_seen", null)) != TYPE_DICTIONARY:
			st["hints_seen"] = {}

		if not st["hints_seen"].has("found_bog_iron") and str(cfg.get("first_find", "")) != "":
			st["hints_seen"]["found_bog_iron"] = Time.get_unix_time_from_system()
			_say(peer, str(cfg["first_find"]))


# The bog iron deposits a player can see (digging.json bog_iron seen_m), as world rows for the client's look (Kathleen's _show_bog):
#   [id, 0, ore left, the sample on the ground, BOG_STATE, {"key": "gi,gj", "total": its size, "wet": under standing water}]
# "left" is the deposit as it has grown back by now (BogIron.regrown, the same sum a dig makes), so a dig or the regrowth sends the row again.
# The deposits are looked up again only when the player moves onto another sample (a few dozen samples within seen_m).
func _bog_rows_near(peer: int, here: Vector3) -> Array:
	var cfg: Dictionary = _dig_cfg.get("bog_iron", {})

	if cfg.is_empty() or not bog_deposit_at.is_valid():
		return []

	var seen: float = float(cfg.get("seen_m", 30.0))
	var at: Vector2i = Vector2i(int(round(here.x / BOG_SAMPLE_M)), int(round(here.z / BOG_SAMPLE_M)))
	var scan: Dictionary = _bog_scan.get(peer, {})

	if scan.is_empty() or scan["at"] != at:
		var found: Array = []
		var keys: Dictionary = {}
		var reach: int = ceili(seen / BOG_SAMPLE_M)

		for dj in range(-reach, reach + 1):
			for di in range(-reach, reach + 1):
				var x: float = float(at.x + di) * BOG_SAMPLE_M
				var z: float = float(at.y + dj) * BOG_SAMPLE_M
				var deposit: Dictionary = bog_deposit_at.call(x, z, cfg)

				if deposit.is_empty() or keys.has(str(deposit["key"])):
					continue

				keys[str(deposit["key"])] = true
				var y: float = float(ground_height.call(x, z)) if ground_height.is_valid() else here.y
				found.append([str(deposit["key"]), Vector3(x, here.y if is_nan(y) else y, z), int(deposit["size"])])

		scan = {"at": at, "found": found}
		_bog_scan[peer] = scan

	var rows: Array = []
	var now_s: float = float(game_seconds.call()) if game_seconds.is_valid() else 0.0

	for entry in scan["found"]:
		var spot: Vector3 = entry[1]

		if Vector2(spot.x - here.x, spot.z - here.z).length() > seen:
			continue

		var key: String = str(entry[0])
		var size: int = int(entry[2])

		if not _bog_ids.has(key):
			_bog_ids[key] = BOG_ID_BASE - _bog_ids.size()

		var left: int = int(BogIron.regrown(_bog_left.get(key, [size, now_s]), size, now_s, cfg)[0])
		var wet: bool = water_depth_at.is_valid() and float(water_depth_at.call(spot)) > BOG_WET_M
		rows.append([int(_bog_ids[key]), 0, left, spot, BOG_STATE, {"key": key, "total": size, "wet": wet}])

	return rows


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
		var took: int = mini(units - got, inv.count_of(number)) if number > 0 else 0

		if took > 0 and inv.remove(number, took):
			got += took

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


# A dead branch on the forest floor (Dave 2026-10-22: loose sticks you can see should be pickable): one stick. The branches are drawn
# by the client, so the server only checks reach and pace (the same pace as a plant pick).
func _pick_litter(peer: int, inv, at: Vector3) -> void:
	if not _peer_pos.has(peer) or _peer_pos[peer].distance_to(at) > Interact.server_reach_m():
		return

	var now_ms: int = Time.get_ticks_msec()

	if now_ms - int(_last_gather.get(peer, -100000)) < gather_pace_ms:
		return

	_last_gather[peer] = now_ms
	var before: Array = _snapshot(inv)
	var left: int = inv.add(table.number_of("stick"), 1)

	if left > 0:
		drop_in_world(table.number_of("stick"), left, _peer_pos[peer])

	_send_changes(peer, inv, before)
	_dirty = true


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

	if not has_axe or float(now - int(_last_mine.get(peer, -100000))) < float(MINE_COOLDOWN_MS) / _pace_factor(peer, "mine_rock") or not bool(rock_at.call(at.x, at.z)):
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
	practice(peer, "mine_rock")

	if left > 0:
		drop_in_world(table.number_of("stone"), left, _peer_pos[peer])

	_send_changes(peer, inv, before)
	_dirty = true


# Bracing supports (Dave 2026-10-22, BRACING_ITEMS.md): the strength they give the ground at a point, for the tunnel watch.
func _rebuild_supports() -> void:
	var list: Array = []

	for id in _items:
		var it: Dictionary = _items[id]

		if not it.has("struct"):
			continue

		var support: Dictionary = _structures.get(str(it["struct"]["kind"]), {}).get("support", {})

		if support.is_empty():
			continue

		list.append([it["pos"], float(support["reach_m"]), float(support["strength"]), float(support["wear_game_days"]) * 86400.0, float(support.get("floor", 0.25)), float(it["struct"].get("born", 0.0))])

	_supports_mutex.lock()
	_supports = list
	_supports_mutex.unlock()


# Support at `at`, 0 or 1 (Dave 2026-10-22, spheres of influence): each support covers a sphere of its reach_m radius at full health; the radius
# falls in step with its condition (1 when new, down to its floor over its wear time), so at half health it is half. Overlapping spheres cover
# the whole area; anywhere inside one is held (1), outside all of them is not (0). Safe to call from the tunnel watch's worker thread.
func support_strength_at(at: Vector3, now_game_s: float = -1.0) -> float:
	var now_s: float = _now_game_s() if now_game_s < 0.0 else now_game_s
	_supports_mutex.lock()
	var list: Array = _supports
	_supports_mutex.unlock()

	for entry in list:
		var worn: float = clampf((now_s - float(entry[5])) / maxf(float(entry[3]), 1.0), 0.0, 1.0)
		var condition: float = lerpf(1.0, float(entry[4]), worn)

		if (entry[0] as Vector3).distance_to(at) <= float(entry[1]) * condition:
			return 1.0

	return 0.0


# Placed foundations as {"pos", "state"} rows, for pieces to snap to.
# Foundations and building pieces, for PlacementRules.snap (anchors and joins).
func _foundation_rows() -> Array:
	var rows: Array = []

	for id in _items:
		var it: Dictionary = _items[id]

		if it.has("struct") and (bool(_structures.get(str(it["struct"]["kind"]), {}).get("foundation", false)) or bool(_structures.get(str(it["struct"]["kind"]), {}).get("piece", false))):
			rows.append({"pos": it["pos"], "state": int(_structures[str(it["struct"]["kind"])]["state"]), "yaw": float(it["struct"]["yaw"])})

	return rows


# A placeable item (the campfire kit) becomes a fire on the ground in front of the player.
func _place(peer: int, inv, slot: int, at: Vector3, yaw_deg: int = 0, lift_steps: int = 0, blueprint: Dictionary = {}) -> void:
	var number: int = 0
	var kit_id: String = ""

	# Every refusal says why (Dave 5 Nov 2026: all items tell you what is wrong when they will not place): never a silent click.
	if not blueprint.is_empty():   # from the hammer: no kit item, the materials are checked here and taken with the piece
		if not _peer_pos.has(peer):
			_say(peer, "The game does not know where you are yet. Try again in a moment.")
			return

		if not _can_blueprint(peer, inv, blueprint, true):
			return   # _can_blueprint says why

		kit_id = str(_structures.get(str(blueprint["structure"]), {}).get("kit", ""))
	else:
		if slot < 0:
			_say(peer, "That blueprint is not in this game's list. Open the hammer menu (right click) and pick it again.")   # an unknown blueprint number reaches here with no kit
			return

		if slot >= inv.SLOTS or inv.numbers[slot] == 0:
			_say(peer, "There is nothing in that slot to place.")
			return

		if not _peer_pos.has(peer):
			_say(peer, "The game does not know where you are yet. Try again in a moment.")
			return

		number = inv.numbers[slot]
		kit_id = table.id_of(number)

	if kit_id != "campfire_kit" and (_structure_of_kit(kit_id).is_empty() or bool(_structure_of_kit(kit_id).get("hand_placed", false))):
		if _structure_of_kit(kit_id).is_empty():
			_say(peer, "That cannot be placed.")

		return      # a torch is placed from the hand (_place_torch), not as a kit

	if blueprint.is_empty() and is_dead_kit(number):
		# A kit that survived in a pack (Dave 5 Nov 2026: a Woven chest in the pack showed a ghost and the click did nothing): it turns back into the
		# materials of its blueprint, and the player is told to build it with the hammer. Never a silent refusal.
		var bp_number: int = int(_blueprint_of_kit.get(kit_id, 0))

		if bp_number > 0 and _refund_blueprint(peer, inv, _blueprints[bp_number]):
			inv.take_from_slot(slot, 1)
			_say(peer, "That old kit is gone. Its materials are back in your pack: build it with the hammer (right click for blueprints).")
			_dirty = true

		return

	if _peer_pos[peer].distance_to(at) > PLACE_REACH_M:
		_say(peer, "Too far to place that.")   # every refusal below says why, so the ghost doing nothing is never a mystery (Dave 31 Oct 2026)
		return

	var on_grid: Array = PlacementRules.snap(_structures_cfg, kit_id, at, yaw_deg, _foundation_rows())
	at = on_grid[0]
	yaw_deg = int(on_grid[1])
	var on_base: bool = bool(on_grid[2])
	var lift: float = 0.0

	if kit_id == "campfire_kit":   # a fire is laid on top of a foundation it is aimed at (Dave 10 Nov 2026), not on the ground under it
		var base_top: float = PlacementRules.foundation_top(_structures_cfg, at, _foundation_rows())

		if not is_nan(base_top):
			at.y = base_top
			on_base = true

	if not on_base and bool(_structure_of_kit(kit_id).get("foundation", false)):
		lift = float(clampi(lift_steps, 0, PlacementRules.LIFT_MAX_STEPS)) * PlacementRules.LIFT_STEP_M   # the client sent the lifted height; the ground is checked below it
		at.y -= lift

	var ground: float = float(ground_height.call(at.x, at.z)) if ground_height.is_valid() else at.y

	if is_nan(ground):
		_say(peer, "The ground there is not ready yet. Try again in a moment.")   # the terrain under the ghost has not streamed in
		return

	if ground < 1.0:
		_say(peer, "The ground is too wet here.")
		return

	var on_wall: bool = on_base and str(_structure_of_kit(kit_id).get("piece_kind", "")) == PlacementRules.WALL_TOP_KIND   # a wall top sits on a standing wall's top, however high that wall is

	if not on_wall and absf(ground - at.y) > (1.0 if not on_base else 1.5 + (PlacementRules.stack_rise(_structures_cfg, kit_id) * float(PlacementRules.STACK_MAX_LAYERS) if on_grid.size() > 3 else 0.0)):
		_say(peer, "You cannot place that there.")
		return

	var spot: Vector3 = Vector3(at.x, at.y if on_base else ground + lift, at.z)

	if not on_base and not _structure_of_kit(kit_id).has("needs_running_water") and water_depth_at.is_valid() and PlacementRules.over_water(_structures_cfg, kit_id, spot, deg_to_rad(float(yaw_deg)), func(x, z): return float(water_depth_at.call(Vector3(x, spot.y, z)))):
		_say(peer, "You cannot build in water.")
		return

	if water_depth_at.is_valid() and PlacementRules.water_short(_structures_cfg, kit_id, spot, func(x, z): return float(water_depth_at.call(Vector3(x, spot.y, z)))):
		var trap_def: Dictionary = _structure_of_kit(kit_id)
		_say(peer, "A %s needs water at least %s m deep." % [table.sentence_name(table.number_of(str(trap_def.get("item", kit_id)))), str(float(trap_def["min_water_m"]))])
		return

	if not on_base and ground_height.is_valid() and PlacementRules.steep(_structures_cfg, kit_id, spot, deg_to_rad(float(yaw_deg)), func(x, z): return float(ground_height.call(x, z))) == "steep":
		_say(peer, "The ground is too steep there.")
		return

	if kit_id != "campfire_kit":
		var placed_def: Dictionary = _structure_of_kit(kit_id)

		if placed_def.has("needs_base_lift_m") or placed_def.has("needs_running_water"):
			spot = _station_site(peer, placed_def, spot, yaw_deg)

			if is_nan(spot.y):
				return

		_place_structure(peer, inv, slot, spot, yaw_deg, placed_def, blueprint if (not blueprint.is_empty() and not free_build and _blueprint_short(peer, inv, blueprint)) else {})
		return

	var chunk_fires: int = 0

	for id in _items:   # a pot with no fire under it takes a new fire laid beside it
		if _is_pot(_items[id]) and (_items[id]["pos"] as Vector3).distance_to(spot) <= POT_ATTACH_M and _fire_under_pot(_items[id]["pos"]) < 0:
			spot = _items[id]["pos"]
			break

	for id in _items:
		if _items[id].has("fire"):
			if _items[id]["pos"].distance_to(spot) < _fire_gap_m:
				_say(peer, "Too close to another fire.")
				return

			if _chunk_of(_items[id]["pos"]) == _chunk_of(spot):
				chunk_fires += 1
		elif _items[id].has("struct") and _items[id]["pos"].distance_to(spot) < _struct_gap_m and not bool(_structures.get(str(_items[id]["struct"]["kind"]), {}).get("walkover", false)) and not bool(_structures.get(str(_items[id]["struct"]["kind"]), {}).get("gap_exempt", false)) and not bool(_structures.get(str(_items[id]["struct"]["kind"]), {}).get("foundation", false)) and not (_is_pot(_items[id]) and _items[id]["pos"].distance_to(spot) <= POT_ON_FIRE_M):   # a foundation is a floor the fire may stand on
			_say(peer, "Something is in the way.")
			return

	if chunk_fires >= _fires_per_chunk:
		_say(peer, "Too many fires here.")
		return

	inv.take_from_slot(slot, 1)
	var covered: bool = cover_at.is_valid() and float(cover_at.call(spot)) > 0.5
	_items[_next_id] = {"number": number, "count": 1, "pos": spot, "left": FIRE_LAID_S, "fire": {"state": 9, "burn_left": 0.0, "wood": {"log": 0.0, "firewood": 0.0, "weak": 0.0}, "covered": covered, "recheck": COVER_RECHECK_S, "synced": true}}
	var laid_fire: Dictionary = _items[_next_id]["fire"]
	var stick_s: float = float((_cooking.get("fuel", {}) as Dictionary).get("stick", 2880.0))
	var start_sticks: int = maxi(1, int(round(float(_cooking.get("start_burn_game_s", 3600.0)) / maxf(stick_s, 1.0))))   # a fresh fire holds its first sticks in its store, where Dave sees them
	_fire_store(laid_fire).add(table.number_of("stick"), start_sticks)
	_fire_apply_store(laid_fire, _fire_store(laid_fire))
	_next_id += 1
	_goal_event(peer, "placed", "campfire")   # the fire hint and goals count a laid fire


# Placement rules of a station that stands on a tall foundation over running water (the sawmill, Dave 2026-10-22): it needs a foundation under it
# lifted at least needs_base_lift_m off the ground, and the water at its wheel (structures.json needs_running_water, offsets from the middle,
# turned with the piece) running along the wheel's span. Returns the spot on the foundation top, or a NAN y after telling the player why.
func _station_site(peer: int, def: Dictionary, spot: Vector3, yaw_deg: int) -> Vector3:
	var lift_need: float = float(def.get("needs_base_lift_m", 0.0))

	if lift_need > 0.0:
		var found: bool = false

		for row in _foundation_rows():
			var base: Dictionary = PlacementRules.structure_of_state(_structures_cfg, int(row["state"]))

			if base.is_empty() or not bool(base.get("foundation", false)):
				continue

			if absf(spot.x - row["pos"].x) > float(base.get("footprint_x", 4.0)) * 0.5 or absf(spot.z - row["pos"].z) > float(base.get("footprint_z", 4.0)) * 0.5:
				continue

			var under: float = float(ground_height.call(row["pos"].x, row["pos"].z)) if ground_height.is_valid() else row["pos"].y

			if row["pos"].y - under >= lift_need - 0.02:
				spot = Vector3(spot.x, row["pos"].y + float(base.get("top_m", 0.3)), spot.z)
				found = true
				break

		if not found:
			_say(peer, "It needs a tall foundation (lifted %.1f m or more)." % lift_need)
			return Vector3(spot.x, NAN, spot.z)

	if def.has("needs_running_water") and water_wheel.is_valid():
		var wheel: Dictionary = _wheel_at(def, spot, yaw_deg)
		var rules: Dictionary = _water_flow_rules()
		var least: float = float(rules.get("min_power_w", 150.0))
		var why: String = str(wheel.get("why", ""))

		if why != "" or float(wheel.get("w", 0.0)) < least:
			_say(peer, WHEEL_SAYS.get(why, "") if why != "" else ("Turn the wheel across the current." if bool(wheel.get("along", false)) else "The wheel would give only %d W here; the saw needs %d W. Find faster or deeper water." % [int(round(float(wheel["w"]))), int(least)]))
			return Vector3(spot.x, NAN, spot.z)

		_say(peer, "The wheel would give %d %% (%d W)." % [int(round(100.0 * WaterFlowScript.wheel_share(float(wheel["w"]), rules))), int(round(float(wheel["w"])))])

	return spot


# The sawmill ghost asks what its wheel would give where it stands (protocol 105): the same rule as placing (_station_site), answered with the
# share in percent and why it would be refused ("along" turned along the current, "weak" under min_power_w).
func _wheel_ask(peer: int, yaw_deg: int, kit_number: int, at: Vector3) -> void:
	var def: Dictionary = _structure_of_kit(table.id_of(kit_number))

	if not def.has("needs_running_water") or not water_wheel.is_valid() or not send_wheel_share.is_valid():
		return

	var wheel: Dictionary = _wheel_at(def, at, yaw_deg)
	var rules: Dictionary = _water_flow_rules()
	var why: String = str(wheel.get("why", ""))

	if why == "" and float(wheel.get("w", 0.0)) < float(rules.get("min_power_w", 150.0)):
		why = "along" if bool(wheel.get("along", false)) else "weak"

	send_wheel_share.call(peer, at, yaw_deg, 0 if why != "" else int(round(100.0 * WaterFlowScript.wheel_share(float(wheel["w"]), rules))), why)


const WHEEL_SAYS := {
	"dry": "The wheel needs running water under all of it.",
	"river": "The wheel must stand over a river.",
	"still": "The water does not run here. The wheel needs a current.",
	"shallow": "The water is too shallow for the wheel (0.4 m or more).",
}


# The water wheel of a station that needs running water (structures.json needs_running_water: its span's ends, offsets from the middle, turned
# with the piece) standing at `spot` turned `yaw_deg`: WaterFlow.wheel's {"w", "why", "along"}.
func _wheel_at(def: Dictionary, spot: Vector3, yaw_deg: float) -> Dictionary:
	var water: Dictionary = def.get("needs_running_water", {})
	var turn: float = deg_to_rad(yaw_deg)
	var from_local: Vector2 = Vector2(float(water["from"][0]), float(water["from"][1])).rotated(turn)
	var to_local: Vector2 = Vector2(float(water["to"][0]), float(water["to"][1])).rotated(turn)
	return water_wheel.call(Vector3(spot.x + from_local.x, spot.y, spot.z + from_local.y), Vector3(spot.x + to_local.x, spot.y, spot.z + to_local.y))


var _water_flow_cfg: Dictionary = {}
var _wheel_stations: Dictionary = {}   # station name -> true when a structure serving it needs running water (the sawmill), filled on first ask


func _wheel_station(station: String) -> bool:
	if not _wheel_stations.has(station):
		_wheel_stations[station] = false

		for kind in _structures:
			if str(_structures[kind].get("station", "")) == station and (_structures[kind] as Dictionary).has("needs_running_water"):
				_wheel_stations[station] = true

	return bool(_wheel_stations[station])


func _water_flow_rules() -> Dictionary:
	if _water_flow_cfg.is_empty():
		_water_flow_cfg = WaterFlowScript.load_rules()

	return _water_flow_cfg


# How much slower a station recipe runs at a sawmill whose wheel gives less than full_power_w (Sonny section 10: craft time x full_power_w / P).
# The wheel's watts are worked out once per placed sawmill and kept on it ("wheel_w"); 1.0 for every other station, or with no wheel callable.
func _wheel_slow(peer: int, recipe: Dictionary) -> float:
	var station: String = str(recipe.get("station", ""))

	if station == "" or not water_wheel.is_valid() or not _wheel_station(station):
		return 1.0

	var id: int = serving_station(peer, station, int(recipe.get("station_level", 1)))

	if id < 0:
		return 1.0

	var watts: float = _wheel_watts(_items[id])
	return 1.0 if watts < 0.0 else 1.0 / WaterFlowScript.wheel_share(watts, _water_flow_rules())


# A placed piece's water wheel share in percent of full power (Sonny section 10: P / full_power_w, floored at min_power_w), or -1 for a piece with no
# wheel (structures.json needs_running_water) or a blueprint site. The watts are worked out once per piece and kept on it ("wheel_w"). Sent on the
# piece's world row ("wheel") so looking at a sawmill shows what its wheel gives.
func wheel_percent(it: Dictionary) -> int:
	var watts: float = _wheel_watts(it)
	return -1 if watts < 0.0 else int(round(100.0 * WaterFlowScript.wheel_share(watts, _water_flow_rules())))


# A placed wheel piece's watts, or -1 for a piece with no wheel. Kept on the piece ("wheel_w") only when the water answered (why ""): a mill first asked
# before its tile's settled water is in memory (a saved mill sent at the join) reads "dry" and 0 W, and keeping that would saw at the floor share for
# good (Sonny's review of #1009); it is asked again next time instead.
func _wheel_watts(it: Dictionary) -> float:
	if not it.has("struct") or it["struct"].has("site") or not water_wheel.is_valid():
		return -1.0

	var def: Dictionary = _structures.get(str(it["struct"]["kind"]), {})

	if not def.has("needs_running_water"):
		return -1.0

	if it["struct"].has("wheel_w"):
		return float(it["struct"]["wheel_w"])

	var wheel: Dictionary = _wheel_at(def, it["pos"], float(it["struct"].get("yaw", 0.0)))
	var watts: float = float(wheel.get("w", 0.0))

	if str(wheel.get("why", "")) == "":
		it["struct"]["wheel_w"] = watts

	return watts


# The admin showroom (Dave 2026-10-23): the rows of data/items/showroom.json laid out east and south of the spawn point as REAL world items
# (pick up, use, inspect). An upsert by key (row label + index): what is missing is placed, what is there stays, so a fill never flickers.
# Never saved and never despawned; the admin fills it again after a restart. clear = true removes them all first (the respawn button).
func _showroom_seed(peer: int, clear: bool, origin: Vector3) -> void:
	if not showroom_enabled or not ground_height.is_valid():
		_say(peer, "The showroom is off here.")
		return

	if clear:
		for id in _items.keys():
			if _items[id].has("showroom"):
				_items.erase(id)

	_showroom_todo.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHOWROOM_PATH))
	var rows: Array = parsed["rows"] if parsed is Dictionary and parsed.get("rows") is Array else []
	var there: Dictionary = {}

	for id in _items:
		if _items[id].has("showroom"):
			there[str(_items[id]["showroom"])] = true

	var planned: int = 0

	for row in rows:
		var start: Array = row.get("start", [0, 0])
		var step: Array = row.get("step", [0, 1.5])
		var at: Vector3 = origin + Vector3(float(start[0]), 0.0, float(start[1]))
		var index: int = 0

		for entry in row.get("items", []):
			var key: String = "%s|%d" % [str(row.get("label", "")), index]
			var number: int = table.number_of(str(entry[0]))
			index += 1

			if number > 0 and not there.has(key) and planned < SHOWROOM_CAP:
				_showroom_todo.append([key, number, maxi(int(entry[1]) if entry.size() > 1 else 1, 1), at])
				planned += 1
			elif number <= 0:
				print("Showroom: unknown item '%s' in row '%s' skipped" % [str(entry[0]), str(row.get("label", ""))])

			at += Vector3(float(step[0]), 0.0, float(step[1]))

	print("Showroom: peer %d %s, %d to place" % [peer, "respawned it" if clear else "filled it", _showroom_todo.size()])
	var placed: int = _showroom_place()
	_say(peer, "Showroom: %d items placed, %d waiting for the ground to load." % [placed, _showroom_todo.size()])


# Places the planned items whose ground is in memory; the rest stay planned and are tried again.
func _showroom_place() -> int:
	var placed: int = 0
	var left: Array = []

	for plan in _showroom_todo:
		var spot: Vector3 = plan[3]

		if ground_ready.is_valid() and not bool(ground_ready.call(spot.x, spot.z)):
			left.append(plan)
			continue

		var ground: float = float(ground_height.call(spot.x, spot.z))

		if is_nan(ground):
			left.append(plan)
			continue

		_items[_next_id] = {"number": int(plan[1]), "count": int(plan[2]), "pos": Vector3(spot.x, ground, spot.z), "left": 1.0e9, "wear": 0, "showroom": str(plan[0])}
		_next_id += 1
		placed += 1

	_showroom_todo = left
	return placed


func _showroom_retry(delta: float) -> void:
	if _showroom_todo.is_empty():
		return

	_showroom_wait += delta

	if _showroom_wait >= 2.0:
		_showroom_wait = 0.0
		_showroom_place()


# Fires burn down; open fires are put out by rain (Dave, 2026-10-20), covered ones are not.
func _fires(delta: float) -> void:
	var rain_v: float = float(rain_now.call()) if rain_now.is_valid() else 0.0
	var raining: bool = rain_v >= RAIN_PUTS_OUT
	_refresh_pots()

	for id in _items.keys():
		var it: Dictionary = _items[id]

		if not it.has("fire"):
			continue

		var fire: Dictionary = it["fire"]

		if fire.has("uid"):
			_tend_fire(id, it, fire, delta)

		if not fire_is_lit(int(fire["state"])):
			_fire_embers(it, fire, delta, raining)
			continue

		# Wet wood in it (fire design 5): a tier lower in heat and light while it is wet, back up once it has dried.
		var damp: bool = _fire_damp(fire)

		if damp != bool(fire.get("damp_on", false)):
			fire["damp_on"] = damp
			fire["state"] = _fire_best_state(fire)
			_lit_valid = false

		# A large fire on a coal bed burns on through rain of any strength, uncovered (fire design 4): faster in heavy rain, and smoking.
		# Wet wood burns wet_burn_x as long.
		var rain_proof: bool = _fire_rain_proof(fire)
		var in_rain: bool = raining and not bool(fire["covered"])
		var heavy: bool = rain_proof and in_rain and rain_v >= float(_coals_cfg().get("rain_burn_from", 0.6))
		var pace: float = (float(_coals_cfg().get("rain_burn_x", 1.25)) if heavy else 1.0) / (maxf(float(table.wet_wood().get("wet_burn_x", 1.5)), 0.1) if damp else 1.0)
		_fire_burn(fire, delta * pace)
		fire["lit_s"] = float(fire.get("lit_s", 0.0)) + delta   # the coal bed builds while it burns
		var smoke: int = 1 if (rain_proof and in_rain) or damp else 0

		if smoke != int(fire.get("smoke", 0)):
			fire["smoke"] = smoke   # the row is sent again (fire design 5: thick smoke while it burns wet)

		if bool(fire.get("synced", false)) and fire.has("uid") and _chests.has(int(fire["uid"])) and _fire_trim_store(fire, _chests[int(fire["uid"])]):
			_push_box(id, _chests[int(fire["uid"])])   # burned wood leaves the store; whoever has it open sees it go

		fire["recheck"] -= delta

		if fire["recheck"] <= 0.0:
			fire["recheck"] = COVER_RECHECK_S
			fire["covered"] = cover_at.is_valid() and float(cover_at.call(it["pos"])) > 0.5

		if fire["burn_left"] <= 0.0:
			_fire_burnt_out(it, fire)
			_dirty = true

			fire.erase("burnt")
			fire.erase("counted")

			if bool(fire.get("synced", false)) and fire.has("uid") and _chests.has(int(fire["uid"])) and _fire_clear_wood(_chests[int(fire["uid"])]):
				_push_box(id, _chests[int(fire["uid"])])   # burnt out: the last piece is ash too, so it cannot be counted again when the store is closed
		elif raining and not fire["covered"] and not _fire_rain_proof(fire):
			var grace: float = float(fire.get("rain_grace", 0.0)) - delta   # lit a moment ago in the rain: it burns until the grace is up

			if grace > 0.0:
				fire["rain_grace"] = grace
			else:
				fire.erase("rain_grace")
				fire.erase("lit_s")   # rained out: the coals are drowned too
				fire.erase("smoke")
				_wet_fire_wood(fire)   # and the wood left in it is wet
				fire["state"] = 9
				it["left"] = FIRE_LAID_S
				_dirty = true


# Item lifetimes run down; an item whose time is up goes, except coals and warm ash, which run on to their next stage (_fire_expire).
func _expire_items(spent: float) -> void:
	for id in _items.keys():
		if _items[id].has("scatter") or float(_items[id]["left"]) > 1.0e8:
			continue

		_items[id]["left"] -= spent

		if _items[id]["left"] <= 0.0:
			if not _fire_expire(_items[id]):
				_items.erase(id)

			_dirty = true


# A fire's world row extra: its burn time, smoke 1 while a large fire burns on in the rain, and, for coals and warm ash, glow (1 fresh .. 0 at
# the end of that stage).
func _fire_extra(it: Dictionary) -> Dictionary:
	var extra: Dictionary = {"burn": snappedf(float(it["fire"]["burn_left"]), 0.1)}
	var state: int = int(it["fire"]["state"])

	if int(it["fire"].get("smoke", 0)) > 0 and fire_is_lit(state):
		extra["smoke"] = int(it["fire"]["smoke"])

	if state == FIRE_STATE_COALS or state == FIRE_STATE_ASH:
		extra["glow"] = snappedf(_fire_glow(it), 0.01)

	return extra


func _fire_glow(it: Dictionary) -> float:
	var state: int = int(it["fire"]["state"])

	if state != FIRE_STATE_COALS and state != FIRE_STATE_ASH:
		return 0.0

	var total: float = float(_coals_cfg().get("coals_s" if state == FIRE_STATE_COALS else "ash_s", 7200.0 if state == FIRE_STATE_COALS else 43200.0))
	return clampf(float(it["left"]) / maxf(total, 1.0), 0.0, 1.0)


# After the flames (docs/design/fire_coals_design.md 3, coordinator decision 8 Nov 2026, Dave may revert): a fire that burned coals.coal_bed_s since
# it was last cold leaves coals; a shorter one is cold ash at once, as before.
func _coals_cfg() -> Dictionary:
	return _cooking.get("coals", {})


func _fire_burnt_out(it: Dictionary, fire: Dictionary) -> void:
	var cfg: Dictionary = _coals_cfg()
	_lit_valid = false
	fire.erase("rain_grace")
	fire.erase("smoke")

	if not cfg.is_empty() and float(fire.get("lit_s", 0.0)) >= float(cfg.get("coal_bed_s", 600.0)):
		fire["state"] = FIRE_STATE_COALS
		it["left"] = float(cfg.get("coals_s", 7200.0))
		fire.erase("wet_s")
		return

	_fire_cold(it, fire)


# --- Wet wood (docs/design/fire_coals_design.md 5, step 3; coordinator decision 8 Nov 2026, Dave may revert; cooking.json wet_wood) ---
# A wood item's slot wear is its drying left in tenths of a game hour. A fire keeps "damp", the wettest wood in it: its store's wettest wood, or
# for a fire with no store the wettest piece laid on, drying with it.

func _fire_damp(fire: Dictionary) -> bool:
	return int(fire.get("damp", 0)) > 0


# The slot of this item with the most drying left (the wettest piece goes on the fire first), or -1.
func _wettest_slot(inv, number: int) -> int:
	var best: int = -1

	for slot in range(inv.SLOTS):
		if inv.numbers[slot] == number and inv.counts[slot] > 0 and (best < 0 or inv.wear[slot] > inv.wear[best]):
			best = slot

	return best


# The fire's kindling is all wet: its weak wood (or, with none, all its wood) is wet and no dry tinder is in it.
func _fire_wet_kindling(fire: Dictionary) -> bool:
	var box = _chests.get(int(fire.get("uid", 0))) if bool(fire.get("synced", false)) else null

	if box == null:
		return _fire_damp(fire)

	var tinder: Array = [str(_cooking.get("tinder", "plant_fibre"))] + (_cooking.get("tinder_also", []) as Array)
	var weak_seen: bool = false
	var weak_dry: bool = false
	var any_dry: bool = false

	for slot in range(box.usable):
		var number: int = box.numbers[slot]

		if number == 0:
			continue

		if tinder.has(table.id_of(number)) and int(box.wear[slot]) == 0:
			return false   # dry tinder catches whatever the rest is

		var cls: String = table.wood_class(number)

		if cls == "":
			continue

		any_dry = any_dry or int(box.wear[slot]) == 0

		if cls == "weak":
			weak_seen = true
			weak_dry = weak_dry or int(box.wear[slot]) == 0

	return not weak_dry if weak_seen else (_fire_damp(fire) and not any_dry)


# A store fire's damp: the most drying left of the wood in its store.
func _fire_store_damp(fire: Dictionary, box) -> void:
	var damp: int = 0

	for slot in range(box.usable):
		if box.numbers[slot] != 0 and table.wood_class(box.numbers[slot]) != "":
			damp = maxi(damp, int(box.wear[slot]))

	fire["damp"] = damp


# Every wood slot of an inventory wetted to its class's full wet time; true when anything changed.
func _wet_inventory(inv) -> bool:
	var changed: bool = false

	for slot in range(inv.SLOTS):
		var full: int = table.wet_units(inv.numbers[slot]) if inv.numbers[slot] != 0 else 0

		if full > int(inv.wear[slot]):
			inv.wear[slot] = full
			changed = true

	return changed


# Every wood slot of an inventory dried by `units`; true when anything changed.
func _dry_inventory(inv, units: int) -> bool:
	var changed: bool = false

	if units <= 0:
		return false

	for slot in range(inv.SLOTS):
		if inv.numbers[slot] != 0 and int(inv.wear[slot]) > 0 and table.wood_class(inv.numbers[slot]) != "":
			inv.wear[slot] = maxi(int(inv.wear[slot]) - units, 0)
			changed = true

	return changed


# The rain on an unlit fire (or one it just put out): its wood is wet.
func _wet_fire_wood(fire: Dictionary) -> void:
	var box = _chests.get(int(fire.get("uid", 0))) if bool(fire.get("synced", false)) else null

	if box != null:
		if _wet_inventory(box):
			_fire_store_damp(fire, box)
			_dirty = true

		return

	if float(fire.get("burn_left", 0.0)) <= 0.0:
		return

	var wood: Dictionary = _fire_wood(fire)
	var full: int = 0

	for cls in ["log", "firewood", "weak"]:
		if float(wood.get(cls, 0.0)) > 0.0:
			full = maxi(full, int(round(float((table.wet_wood().get("wet_h", {}) as Dictionary).get(cls, 0.0)) * 10.0)))

	if full > int(fire.get("damp", 0)):
		fire["damp"] = full
		_dirty = true


# Every tick_s: rain wets loose wood lying uncovered and the wood of unlit uncovered fires; everywhere else wood dries, in a lit fire's store or
# within its heat reach fire_dry_x as fast. Packs and chests keep wood dry.
func _wood_tick(spent: float) -> void:
	var cfg: Dictionary = table.wet_wood()

	if cfg.is_empty():
		return

	_wood_in += spent

	if _wood_in < float(cfg.get("tick_s", 15.0)):
		return

	_wood_acc += _wood_in * GAME_RATE / 360.0   # tenths of a game hour
	_wood_in = 0.0
	var units: int = int(_wood_acc)
	_wood_acc -= float(units)
	var fire_x: int = maxi(int(round(float(cfg.get("fire_dry_x", 6.0)))), 1)
	var raining: bool = rain_now.is_valid() and float(rain_now.call()) >= float(cfg.get("rain_from", 0.2))
	var peer_of_key: Dictionary = {}

	for peer in _peer_key:
		peer_of_key[_peer_key[peer]] = peer

	for key in _inventories:
		var peer: int = int(peer_of_key.get(key, 0))
		var before: Array = _snapshot(_inventories[key]) if peer != 0 else []

		if _dry_inventory(_inventories[key], units):
			_dirty = true

			if peer != 0:
				_send_changes(peer, _inventories[key], before)

	var fire_box: Dictionary = {}

	for id in _items:
		if _items[id].has("fire") and _items[id]["fire"].has("uid"):
			fire_box[int(_items[id]["fire"]["uid"])] = id

	for uid in _chests:
		if not fire_box.has(uid) and _dry_inventory(_chests[uid], units):
			_dirty = true

	var heat: Array = []
	var tiers: Dictionary = _cooking.get("fire_tiers", {})

	for row in _lit_rows():
		heat.append([row[0], float((tiers.get(_fire_class_of_state(int(row[1])), {}) as Dictionary).get("heat_radius_m", 4.0))])

	for id in _items:
		var it: Dictionary = _items[id]

		if it.has("fire"):
			_wood_tick_fire(id, it, units, fire_x, raining)
			continue

		if it.has("struct") or it.has("tree") or it.has("boulder") or it.has("scatter") or table.wood_class(int(it["number"])) == "":
			continue

		var full: int = table.wet_units(int(it["number"]))

		if raining and not (cover_at.is_valid() and float(cover_at.call(it["pos"])) > 0.5):
			if int(it.get("wear", 0)) < full:
				it["wear"] = full
				_dirty = true
		elif int(it.get("wear", 0)) > 0:
			var x: int = 1

			for h in heat:
				if (h[0] as Vector3).distance_to(it["pos"]) <= float(h[1]):
					x = fire_x
					break

			it["wear"] = maxi(int(it["wear"]) - units * x, 0)
			_dirty = true


func _wood_tick_fire(id: int, it: Dictionary, units: int, fire_x: int, raining: bool) -> void:
	var fire: Dictionary = it["fire"]
	var lit: bool = fire_is_lit(int(fire["state"]))
	var box = _chests.get(int(fire.get("uid", 0))) if bool(fire.get("synced", false)) else null
	var tracked: bool = lit or int(fire["state"]) == FIRE_STATE_COALS or int(fire["state"]) == FIRE_STATE_ASH   # these keep fire["covered"] fresh (_fires)
	var covered: bool = bool(fire.get("covered", false)) if tracked else (cover_at.is_valid() and float(cover_at.call(it["pos"])) > 0.5)

	if raining and not covered and not lit:
		_wet_fire_wood(fire)
		return

	var x: int = fire_x if lit else 1

	if box != null:
		if _dry_inventory(box, units * x):
			_fire_store_damp(fire, box)
			_push_box(id, box)
			_dirty = true
	elif int(fire.get("damp", 0)) > 0:
		fire["damp"] = maxi(int(fire["damp"]) - units * x, 0)
		_dirty = true


# A large fire (state 41) with a coal bed (coals.coal_bed_s burned since it was last cold) is not put out by rain (fire design 4, coordinator
# decision 8 Nov 2026). Small and medium fires, and a large one lit a moment ago, go out as before; once a large fire's logs are gone it is
# medium again and the rain takes it.
func _fire_rain_proof(fire: Dictionary) -> bool:
	var large: bool = int(fire["state"]) == FIRE_STATE_BONFIRE or (fire_is_lit(int(fire["state"])) and _fire_damp(fire) and _fire_best_state(fire, false) == FIRE_STATE_BONFIRE)   # a log fire held a tier down by wet wood is still a log fire
	return large and not _coals_cfg().is_empty() and float(fire.get("lit_s", 0.0)) >= float(_coals_cfg().get("coal_bed_s", 600.0))


# Coals run out (or are rained out) to warm ash.
func _fire_to_ash(it: Dictionary, fire: Dictionary) -> void:
	fire["state"] = FIRE_STATE_ASH
	it["left"] = float(_coals_cfg().get("ash_s", 43200.0))

	for key in ["lit_s", "wet_s", "catch"]:   # the coal bed is spent: warm ash lit again needs coal_bed_s more burning to leave coals
		fire.erase(key)
	_lit_valid = false
	_dirty = true


# The fire is cold: cold ash (8) for FIRE_OUT_S, or a laid fire (9) when wood is in it.
func _fire_cold(it: Dictionary, fire: Dictionary) -> void:
	for key in ["lit_s", "wet_s", "catch"]:
		fire.erase(key)

	if float(fire.get("burn_left", 0.0)) > 0.0:
		fire["state"] = 9
		it["left"] = FIRE_LAID_S
	else:
		fire["state"] = 8
		it["left"] = FIRE_OUT_S

	_lit_valid = false
	_dirty = true


# The item expiry loop found a fire's time run out: coals go on to warm ash, warm ash to cold. False for anything else (it is then removed).
func _fire_expire(it: Dictionary) -> bool:
	if not it.has("fire"):
		return false

	var state: int = int(it["fire"]["state"])

	if state == FIRE_STATE_COALS:
		_fire_to_ash(it, it["fire"])
		return true

	if state == FIRE_STATE_ASH:
		_fire_cold(it, it["fire"])
		return true

	return false


# Coals and warm ash between ticks: rain of RAIN_PUTS_OUT or more on them uncovered turns coals to ash after coals.rain_s and ash cold after a further
# ash_rain_s; out of that rain, wood laid on coals catches by itself after coals.catch_s (by its biggest wood) and the fire is back at its size.
func _fire_embers(it: Dictionary, fire: Dictionary, delta: float, raining: bool) -> void:
	var state: int = int(fire["state"])

	if state != FIRE_STATE_COALS and state != FIRE_STATE_ASH:
		return

	var cfg: Dictionary = _coals_cfg()
	fire["recheck"] = float(fire.get("recheck", 0.0)) - delta

	if float(fire["recheck"]) <= 0.0:
		fire["recheck"] = COVER_RECHECK_S
		fire["covered"] = cover_at.is_valid() and float(cover_at.call(it["pos"])) > 0.5

	if raining and not bool(fire.get("covered", false)):
		fire["wet_s"] = float(fire.get("wet_s", 0.0)) + delta
		fire.erase("catch")

		if state == FIRE_STATE_COALS and float(fire["wet_s"]) >= float(cfg.get("rain_s", 120.0)):
			_fire_to_ash(it, fire)
		elif state == FIRE_STATE_ASH and float(fire["wet_s"]) >= float(cfg.get("ash_rain_s", 600.0)):
			_fire_cold(it, fire)

		return

	if state != FIRE_STATE_COALS or float(fire.get("burn_left", 0.0)) <= 0.0:
		return

	fire["catch"] = float(fire.get("catch", 0.0)) + delta

	if float(fire["catch"]) >= _fire_catch_s(fire):
		fire.erase("catch")
		fire["state"] = _fire_best_state(fire)
		it["left"] = 1.0e9
		_lit_valid = false
		_dirty = true


# How long wood laid on coals takes to catch: the time for the biggest wood class in the fire (coals.catch_s).
func _fire_catch_s(fire: Dictionary) -> float:
	var wood: Dictionary = _fire_wood(fire)
	var times: Dictionary = _coals_cfg().get("catch_s", {})

	for cls in ["log", "firewood", "weak"]:
		if float(wood.get(cls, 0.0)) > 0.0:
			return float(times.get(cls, 45.0))

	return float(times.get("weak", 10.0))


# E on a burning fire puts it out (Dave 2 Nov 2026). It goes back to a laid fire with its wood kept, the same as when rain puts it out, so it can be lit again.
func _put_out_fire(peer: int, id: int) -> void:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not it.has("fire") or not _peer_pos.has(peer) or _peer_pos[peer].distance_to(it["pos"]) > FIRE_USE_M:
		return

	var fire: Dictionary = it["fire"]

	if not fire_is_lit(int(fire["state"])):
		return

	fire["state"] = 9
	fire.erase("lit_s")   # put out: the coals are put out too
	it["left"] = FIRE_LAID_S
	_dirty = true


# Hold E on a fire that is not burning picks it up again as a campfire kit (Dave 2 Nov 2026). Refused with a reason while it burns, while a pot hangs
# on it, or while its wood and food store (F) still holds anything.
func _pick_up_fire(peer: int, inv, id: int) -> void:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not it.has("fire") or not _peer_pos.has(peer):
		return

	if _peer_pos[peer].distance_to(it["pos"]) > Interact.server_reach_m():
		_reject(peer, 0)
		return

	var fire: Dictionary = it["fire"]

	if fire_is_lit(int(fire["state"])):
		_say(peer, "Let the fire burn out first.")
		return

	if bool(fire.get("pot", false)):
		_say(peer, "Take the pot down first.")
		return

	var box = _chests.get(int(fire.get("uid", 0)))

	if box != null and not box.is_empty():
		_say(peer, "Empty it first.")
		return

	var kit: int = table.number_of("campfire_kit")

	if _fit(peer, inv, kit, 1) == 0 or inv.add(kit, 1) > 0:
		_say(peer, "Too heavy to carry any more")
		return

	_chests.erase(int(fire.get("uid", 0)))
	_items.erase(id)
	_dirty = true


func _pickup(peer: int, inv, id: int, wanted: int = 0) -> void:
	var it: Dictionary = _items.get(id, {})

	if it.has("struct"):
		_take_down(peer, inv, id)
		return

	if it.has("fire"):
		_pick_up_fire(peer, inv, id)
		return

	if it.is_empty() or it.has("tree") or it.has("boulder") or not _peer_pos.has(peer):
		return

	if _peer_pos[peer].distance_to(it["pos"]) > Interact.server_reach_m():
		_reject(peer, 0)
		return

	if is_shoulder_item(int(it["number"])):
		if shoulder_of(peer) != "":
			_say(peer, "Put your log down first (Q).")
			return

		if _fit(peer, inv, int(it["number"]), 1) == 0:
			_say(peer, "Too heavy to carry any more")
			return

		var took: int = _give_shoulder(peer, int(it["number"]), 1)

		if took > 0:
			if int(it["count"]) > 1:
				it["count"] = int(it["count"]) - 1
			else:
				_items.erase(id)

		return

	var batch: int = int((_batch_cfg.get("batch", {}) as Dictionary).get(table.id_of(int(it["number"])), 0))

	if batch > 0 and int(it.get("wear", 0)) == 0:
		_pickup_batch(peer, inv, id, batch)
		return

	# A pile gives a handful (or the count the client asks for), anything smaller is taken whole.
	var want: int = int(it["count"])

	if want >= PILE_MIN:
		want = mini(want, wanted if wanted > 0 else int(table.entry(table.id_of(int(it["number"]))).get("pile", {}).get("handful", PILE_HANDFUL)))

	want = mini(want, table.COUNT_MAX)   # one action moves at most a full stack's worth; the rest stays on the ground
	var fits: int = _fit(peer, inv, int(it["number"]), want)

	if fits == 0:
		_say(peer, "Too heavy to carry any more")
		_reject(peer, 2)
		return

	var left: int = int(it["count"]) - want + inv.add(int(it["number"]), fits, int(it.get("wear", 0))) + (want - fits)
	_take_from(id, int(it["count"]) - left)


# `n` of the ground item `id` were picked up: it holds fewer, or is gone with its last (a natural scatter one stays gone).
func _take_from(id: int, n: int) -> void:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or n <= 0:
		return

	var left: int = int(it["count"]) - n

	if left <= 0:
		if it.has("scatter"):
			_taken[it["scatter"]] = true

		_items.erase(id)
	else:
		it["count"] = left

		if left >= PILE_MIN:
			it["left"] = PILE_LIFETIME_S

	_dirty = true


# Sticks and leaves come up in batches (Dave 10 Nov 2026: "when you pick up the sticks and leaves by holding down the E key it picks them up in batches
# of 10 or 20"): one E takes up to `batch` of the item, from the heap picked and then the nearest heaps of the same item within gather_m of it (and in
# reach), as much as the carry limit and the pack allow. Refused (reason 2) only when none at all could be taken.
func _pickup_batch(peer: int, inv, id: int, batch: int) -> void:
	var it: Dictionary = _items[id]
	var number: int = int(it["number"])
	var fits: int = _fit(peer, inv, number, mini(batch, table.COUNT_MAX))

	if fits == 0:
		_say(peer, "Too heavy to carry any more")
		_reject(peer, 2)
		return

	var gather_m: float = float(_batch_cfg.get("gather_m", 2.5))
	var reach: float = Interact.server_reach_m()
	var heaps: Array = [[0.0, id]]

	for other_id in _items:
		var other: Dictionary = _items[other_id]

		if other_id == id or int(other.get("number", 0)) != number or int(other.get("wear", 0)) != 0:
			continue

		if other.has("showroom") or other.has("struct") or other.has("fire") or other.has("tree") or other.has("boulder"):
			continue

		var flat: float = Vector2(other["pos"].x - it["pos"].x, other["pos"].z - it["pos"].z).length()

		if flat <= gather_m and _peer_pos[peer].distance_to(other["pos"]) <= reach:
			heaps.append([flat, other_id])

	heaps.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var wanted: int = fits
	var taken: int = 0

	for heap in heaps:
		if wanted <= 0:
			break

		var share: int = mini(int(_items[heap[1]]["count"]), wanted)
		var over: int = inv.add(number, share, 0)
		_take_from(int(heap[1]), share - over)
		taken += share - over
		wanted -= share - over

		if over > 0:
			break   # the pack is full

	if taken == 0:
		_reject(peer, 2)


func _sync_world_items() -> void:
	# The records are filed into a NEAR_M grid once, so each player looks only at the nine cells around them instead of every
	# record in the world (the soak test found 2 to 9 ms a second at 20 players and 500 records, growing with both).
	var t_grid: int = Time.get_ticks_usec()
	var send_usec: int = 0
	var sent: int = 0
	var grid: Dictionary = {}

	for id in _items:
		var cell: Vector2i = Vector2i(int(floor(_items[id]["pos"].x / NEAR_M)), int(floor(_items[id]["pos"].z / NEAR_M)))

		if not grid.has(cell):
			grid[cell] = []

		grid[cell].append(id)

	var t_scan: int = Time.get_ticks_usec()

	for peer in _known:
		if not _peer_pos.has(peer):
			continue

		var here: Vector3 = _peer_pos[peer]
		var known: Dictionary = _known[peer]
		var added: Array = []
		var removed: PackedInt32Array = PackedInt32Array()
		var near: Dictionary = {}
		var home: Vector2i = Vector2i(int(floor(here.x / NEAR_M)), int(floor(here.z / NEAR_M)))
		var candidates: Array = []

		for dx in range(-1, 2):
			for dz in range(-1, 2):
				candidates.append_array(grid.get(Vector2i(home.x + dx, home.y + dz), []))

		for id in candidates:
			var it: Dictionary = _items[id]

			if it["pos"].distance_to(here) <= NEAR_M:
				near[id] = true

				var state: int = int(it["fire"]["state"]) if it.has("fire") else (int(it["tree"]["state"]) if it.has("tree") else (_struct_state(it) if it.has("struct") else (BOULDER_STATE if it.has("boulder") else 0)))
				var signature: int = int(it["count"]) + 1000 * state + 100000 * int(it["number"]) + 1000000000 * int(round(it["pos"].y * 10.0))   # the height too: an item that comes down onto the ground after a dig is sent again

				if it.has("struct") and bool(it["struct"].get("lit", false)):
					signature += 7      # a fixture lit or put out is sent again (the client draws or drops its flame)

				var site_view: Array = []

				if it.has("struct") and it["struct"].has("site"):
					site_view = _site_view(peer, it)   # this player's own list: what is still needed and what they have to put in (Dave 5 Nov 2026)
					signature += 37

					for line in site_view:
						signature += 101 * int(line[1]) + 7 * mini(int(line[2]), int(line[1]) + 1)   # a deposit, or having enough on hand, sends it again

				if it.has("fire"):
					signature += 13 * int(it["fire"].get("fed", 0))      # wood laid on a fire is sent again (its burn time for the inspection label)
					signature += 17 * int(floor(_fire_glow(it) * 10.0))   # coals and warm ash are sent again each tenth of their time (the client dims them)
					signature += 19 * int(it["fire"].get("smoke", 0))   # a fire that starts or stops smoking is sent again

				if it.has("tree"):
					signature += int(round(float(it["tree"].get("length", 0.0)) * 20.0)) * 7      # a trunk that got shorter (a log was cut off) is sent again

				if not known.has(id) or known[id] != signature:
					added.append([id, int(it["number"]), int(it["count"]), it["pos"], state, it["tree"] if it.has("tree") else ({"yaw": float(it["struct"]["yaw"]), "age": _remains_age(it), "sp": str(it["struct"].get("species", "")), "lit": bool(it["struct"].get("lit", false))} if it.has("struct") else (it["boulder"] if it.has("boulder") else (_fire_extra(it) if it.has("fire") else (_loose_extra(it) if it.has("rot_y") or it.has("girth") or it.has("tilt") else {}))))])
					if not site_view.is_empty():
						(added[added.size() - 1][5] as Dictionary)["site"] = site_view

					if it.has("struct") and not it["struct"].has("site"):
						var wheel: int = wheel_percent(it)

						if wheel >= 0:
							(added[added.size() - 1][5] as Dictionary)["wheel"] = wheel   # a sawmill: its water wheel's share, for the look-at line
					known[id] = signature

		for bog in _bog_rows_near(peer, here):
			near[int(bog[0])] = true
			var bog_signature: int = int(bog[2]) + 1000 * BOG_STATE + (7 if bool(bog[5]["wet"]) else 0)

			if not known.has(int(bog[0])) or known[int(bog[0])] != bog_signature:
				added.append(bog)
				known[int(bog[0])] = bog_signature

		for id in known.keys():
			if not near.has(id):
				removed.append(id)
				known.erase(id)

		if not added.is_empty() or not removed.is_empty():
			var t_send: int = Time.get_ticks_usec()
			send_world_items.call(peer, added, removed)
			send_usec += Time.get_ticks_usec() - t_send
			sent += added.size()

	# For the slow-tick line: where the time went (lag run 5 Nov: sync-world-items 60-124 ms at a join).
	var total_ms: float = float(Time.get_ticks_usec() - t_grid) / 1000.0
	_sync_detail = "(%d records: grid %.0f, scan %.0f, send %.0f for %d items)" % [_items.size(), float(t_scan - t_grid) / 1000.0, total_ms - float(t_scan - t_grid) / 1000.0 - float(send_usec) / 1000.0, float(send_usec) / 1000.0, sent]


func _send_changes(peer: int, inv, before: Array) -> void:
	var out: PackedByteArray = PackedByteArray()

	if not _gain_quiet and send_received.is_valid():
		_report_gains(peer, inv, before)

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

	if before.size() > 3 and inv.fav_flags() != before[3]:
		_send_favs(peer, inv)   # after the slots, so the client marks the stacks where they now are

	_hotbar_autofill(peer, inv, before[0])

	_sync_shoulder_if_changed(peer)


func _send_favs(peer: int, inv) -> void:
	if send_favourites.is_valid() and inv != null:
		send_favourites.call(peer, inv.fav_flags())


# Every item that is more numerous in the pack than before (all gains pass _send_changes): a pickup, harvest, craft output, reward.
func _report_gains(peer: int, inv, before: Array) -> void:
	var gained: Dictionary = {}

	for i in inv.SLOTS:
		var now_n: int = int(inv.numbers[i])

		if now_n > 0:
			gained[now_n] = int(gained.get(now_n, 0)) + int(inv.counts[i])

	for i in inv.SLOTS:
		var was_n: int = int(before[0][i])

		if was_n > 0 and gained.has(was_n):
			gained[was_n] = int(gained[was_n]) - int(before[1][i])

	for number in gained:
		if int(gained[number]) > 0:
			send_received.call(peer, table.id_of(int(number)), int(gained[number]), _gain_source)


func _snapshot(inv) -> Array:
	return [inv.numbers.duplicate(), inv.counts.duplicate(), inv.wear.duplicate(), inv.fav_flags()]


func _chunk_of(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / CHUNK_M)), int(floor(p.z / CHUNK_M)))


func _valid_key(key: String) -> bool:
	if key.length() < 8 or key.length() > 64:
		return false

	for ch in key:
		if not (ch >= "0" and ch <= "9") and not (ch >= "a" and ch <= "z") and not (ch >= "A" and ch <= "Z") and ch != "-" and ch != "_" and ch != "'":
			return false

	return true


func _load_inventories() -> void:
	var parsed: Variant = _read_json_version("inventories.json", INVENTORY_VERSION, 1)

	if parsed == null:
		return

	for key in parsed["inventories"]:
		var inv = InventoryScript.new(table)
		inv.from_json_array(parsed["inventories"][key])
		_strip_dead_kits(inv)
		_inventories[key] = inv


func _load_world_items() -> void:
	var parsed: Variant = _read_json("world_items.json")

	if parsed == null:
		return

	_next_id = int(parsed.get("next_id", 1))

	_picked = parsed.get("picked", {})
	_stripped = {}
	var same_layout: bool = int(parsed.get("layout", 1)) == FloraLayout.VERSION

	# Picked and bare marks name plants by chunk and id: under another flora layout they would point at the wrong plants, so they start clean
	# (a file from before the stamp counts as layout 1; the removed-plant marks do the same in server_flora.gd).
	if not same_layout:
		_picked = {}
		print("server items: flora layout %d is not %d, picked and bare plant marks cleared" % [int(parsed.get("layout", 1)), FloraLayout.VERSION])

	for chunk_key in (parsed.get("stripped", {}) if same_layout else {}):      # JSON gives the stamps back as floats
		var ids: Dictionary = {}

		for plant in parsed["stripped"][chunk_key]:
			ids[int(plant)] = int(parsed["stripped"][chunk_key][plant])

		_stripped[str(chunk_key)] = ids

	_fruit = {}

	for chunk_key in (parsed.get("fruit", {}) if same_layout else {}):      # JSON gives the numbers back as floats
		var trees: Dictionary = {}

		for tree in parsed["fruit"][chunk_key]:
			var record: Array = parsed["fruit"][chunk_key][tree]
			trees[int(tree)] = [int(record[0]), int(record[1])]

		_fruit[str(chunk_key)] = trees

	for key in parsed.get("taken", []):
		_taken[int(key)] = true

	for key in parsed.get("boulders", {}):
		_boulder_left[int(key)] = int(parsed["boulders"][key])

	for key in parsed.get("bog_iron", {}):
		var bog_row: Variant = parsed["bog_iron"][key]

		if typeof(bog_row) == TYPE_ARRAY and (bog_row as Array).size() >= 2:
			_bog_left[str(key)] = [int(bog_row[0]), float(bog_row[1])]

	var had_kits: bool = not bool(parsed.get("no_kits", false))   # a world saved before kits were dropped (Dave 4 Nov 2026) loses its kit items and every placed building once

	for row in parsed["items"]:
		var entry: Dictionary = {"number": table.current_number(int(row[0])), "count": int(row[1]), "pos": Vector3(row[2], row[3], row[4]), "left": float(row[5])}

		if is_dead_kit(int(row[0])):
			continue

		if had_kits and row.size() > 9 and int(row[6]) >= 5 and typeof(row[9]) == TYPE_STRING and str(row[9]) != "remains" and (_traps == null or not _traps.is_kind(str(row[9]))):
			continue

		if row.size() > 9 and int(row[6]) >= 5 and typeof(row[9]) == TYPE_STRING:
			entry["struct"] = {"kind": _kind_now(str(row[9])), "yaw": float(row[7])}

			if row.size() > 10 and int(row[10]) > 0:
				entry["struct"]["uid"] = int(row[10])
				_next_uid = maxi(_next_uid, int(row[10]) + 1)

				if not _chests.has(int(row[10])):
					_chests[int(row[10])] = InventoryScript.new(table)

			if row.size() > 12 and (_structures.get(str(row[9]), {}).has("support") or (not BuildingWear.rule_for(_wear_cfg, str(entry["struct"]["kind"])).is_empty() and float(row[12]) > 0.0)):
				entry["struct"]["born"] = float(row[12])

			if row.size() > 12 and str(row[9]) == "remains":
				entry["struct"]["owner"] = str(row[11])
				entry["struct"]["born"] = float(row[12])
				entry["struct"]["cave"] = row.size() > 13 and bool(row[13])
				entry["struct"]["coins"] = maxi(int(row[14]), 0) if row.size() > 14 else 0

			if row.size() > 11 and entry["struct"].has("uid") and str(row[9]) != "remains" and str(row[11]) != "":
				entry["struct"]["owner"] = str(row[11])   # a container's owner (crafting stock); one saved before owners belongs to its first opener

			if row.size() > 16 and int(row[16]) == 1:
				entry["struct"]["keep_out"] = true   # the owner keeps it out of crafting and blueprint sites

			if row.size() > 15 and str(row[15]) != "":
				var saved_site: Variant = JSON.parse_string(str(row[15]))

				if typeof(saved_site) == TYPE_DICTIONARY:
					entry["struct"]["site"] = {"bp": int((saved_site as Dictionary).get("bp", 0)), "have": (saved_site as Dictionary).get("have", {})}

			if row.size() > 12 and _traps != null and _traps.is_kind(str(row[9])):
				entry["struct"]["owner"] = str(row[11])
				entry["struct"]["seq"] = float(row[12])
				_next_uid = maxi(_next_uid, int(row[12]) + 1)
				entry["wear"] = int(row[8])

			_items[_next_id] = entry
			_grid_add(_next_id, entry)
			_next_id += 1
			continue

		if row.size() > 8:
			entry["wear"] = int(row[8])

		if row.size() > 9 and int(row[6]) == 0 and typeof(row[9]) == TYPE_FLOAT:
			entry["rot_y"] = float(row[9])

			if row.size() > 10 and typeof(row[10]) == TYPE_FLOAT:
				entry["girth"] = float(row[10])

		if row.size() > 7 and int(row[6]) != 0:
			var saved_state: int = int(row[6])

			if saved_state == 2:   # before protocol 19: an out fire is empty ashes, or loaded when it still has wood
				saved_state = 9 if float(row[7]) > 0.0 else 8

			entry["fire"] = {"state": saved_state, "burn_left": float(row[7]), "covered": false, "recheck": 0.0}

			if row.size() > 10 and typeof(row[10]) == TYPE_ARRAY and (row[10] as Array).size() == 3:   # before fire tiers the one counter is split by the fire's size
				entry["fire"]["wood"] = {"log": float(row[10][0]), "firewood": float(row[10][1]), "weak": float(row[10][2])}

			if row.size() > 11 and typeof(row[11]) == TYPE_ARRAY and (row[11] as Array).size() == 3:
				var pieces: Dictionary = {}

				for k in range(3):
					if int(row[11][k]) >= 0:
						pieces[["log", "firewood", "weak"][k]] = int(row[11][k])

				entry["fire"]["pieces"] = pieces

			if row.size() > 12 and int(row[12]) == 1:
				entry["fire"]["synced"] = true

			# A restart keeps what has burned since the last count and which pieces that count knew, so closing the store after a load does not give
			# burned wood back as fresh burn time, and the half-burned piece still leaves the store when it is done.
			if row.size() > 13 and typeof(row[13]) == TYPE_ARRAY and (row[13] as Array).size() == 3:
				var burnt: Dictionary = {}

				for k in range(3):
					if float(row[13][k]) > 0.0:
						burnt[["log", "firewood", "weak"][k]] = float(row[13][k])

				entry["fire"]["burnt"] = burnt

			if row.size() > 14 and typeof(row[14]) == TYPE_ARRAY and (row[14] as Array).size() == 3:
				var counted: Dictionary = {}

				for k in range(3):
					counted[["log", "firewood", "weak"][k]] = maxi(int(row[14][k]), 0)

				entry["fire"]["counted"] = counted

			if row.size() > 15 and (typeof(row[15]) == TYPE_FLOAT or typeof(row[15]) == TYPE_INT) and float(row[15]) > 0.0:
				entry["fire"]["lit_s"] = float(row[15])

			if row.size() > 16 and (typeof(row[16]) == TYPE_FLOAT or typeof(row[16]) == TYPE_INT) and int(row[16]) > 0:
				entry["fire"]["damp"] = int(row[16])

			if row.size() > 9 and int(row[9]) > 0:
				entry["fire"]["uid"] = int(row[9])
				_next_uid = maxi(_next_uid, int(row[9]) + 1)

				if not _chests.has(int(row[9])):
					_chests[int(row[9])] = InventoryScript.new(table)

		_items[_next_id] = entry
		_next_id += 1

	_refresh_pots()   # a pot hangs over whatever fire shares its spot: nothing about it is saved


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
	var t0: int = Time.get_ticks_usec()
	var text: String = JSON.stringify(data)   # the snapshot is taken now, on the tick
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0

	if ms > 10.0:
		_save_parts.append("%s %.0f (%d KB)" % [name.get_basename(), ms, int(text.length() / 1024.0)])   # for the slow-tick line (lag run 5 Nov: a 675 ms save in one tick)

	if _async_writes:
		_pending_writes.append([path, text])   # the files are written by the background writer (see _start_writer)
		return

	_finish_writer()
	_write_file(path, text)


# The disk part of a save: the text goes to .tmp, the file it replaces is copied to .prev, then .tmp is renamed over it.
# One write at a time: the background writer and a save from anywhere else (shutdown, a test's last save) used the same path.tmp, and the second rename failed with an error
# line ("Error calling utility function", exit 1 or 139 in the gates, 31 Oct 2026). The lock makes the files land in order.
static var _file_lock: Mutex = Mutex.new()


static func _write_file(path: String, text: String) -> void:
	_file_lock.lock()
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)

	if file == null:
		_file_lock.unlock()
		push_error("server items: cannot write %s" % path)
		return

	file.store_string(text)
	file.close()

	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".prev")

	DirAccess.rename_absolute(path + ".tmp", path)
	_file_lock.unlock()


# The autosave only serialises on the tick (about 3 ms at 500 records); the file writes (renames, copies) run on one short-lived
# background thread, so the 20 Hz tick never waits for the disk. A save() from anywhere else (shutdown, tests) first waits for
# that thread, so files always land in order.
var _async_writes: bool = false
var _pending_writes: Array = []
var _writer: Thread = null


func _start_writer() -> void:
	if _pending_writes.is_empty():
		return

	var batch: Array = _pending_writes
	_pending_writes = []
	_writer = Thread.new()
	_writer.start(_write_batch.bind(batch))


static func _write_batch(batch: Array) -> void:
	for row in batch:
		_write_file(str(row[0]), str(row[1]))


func _reap_writer() -> void:
	if _writer != null and not _writer.is_alive():
		_writer.wait_to_finish()
		_writer = null


func _finish_writer() -> void:
	for task in _log_tasks:
		WorkerThreadPool.wait_for_task_completion(task)

	_log_tasks = []

	if _writer != null:
		_writer.wait_to_finish()
		_writer = null


# Loose stones and fallen sticks lie about the ground (Dave, 2026-10-20: more stones near rock
# and on slopes). Laid out cell by cell around players from the world seed, so the same cell
# always has the same things; picked-up ones are remembered in _taken.
func _scatter_around_players() -> void:
	if not ground_height.is_valid():
		return

	var cfg: Dictionary = _drops.get("ground_scatter", {})
	var cell_m: float = float(cfg.get("cell_m", 32.0))
	var budget: int = SCATTER_CELLS_PER_TICK
	var started: int = Time.get_ticks_usec()   # a tick lays out cells for at most SCATTER_TICK_MAX_MS: a join took 0.7 to 6.9 s here in one go (Tyler, 1 Nov 2026)

	for peer in _peer_pos:
		var here: Vector3 = _peer_pos[peer]
		var reach: int = int(ceil(SCATTER_RADIUS_M / cell_m))
		var home: Vector2i = Vector2i(int(floor(here.x / cell_m)), int(floor(here.z / cell_m)))

		for dz in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var cell: Vector2i = home + Vector2i(dx, dz)

				if budget > 0 and float(Time.get_ticks_usec() - started) / 1000.0 > SCATTER_TICK_MAX_MS:
					budget = 0

				if budget > 0 and not _cells_done.has(cell) and Vector2(dx, dz).length() * cell_m <= SCATTER_RADIUS_M:
					# A tile that is not in memory yet takes over a second to read: ask for it on a worker thread and lay this cell out next time.
					if not _cell_ground_ready(cell, cell_m):
						continue

					_cells_done[cell] = true
					var cell_usec: int = Time.get_ticks_usec()
					_lay_out_cell(cell, cell_m, cfg)
					var cell_ms: float = float(Time.get_ticks_usec() - cell_usec) / 1000.0

					if cell_ms > 50.0:   # names a slow cell (a tile read on the main thread), so a hitch in the log says where
						_log_off_main("items tick slow: scatter cell %s took %.0f ms (%s)" % [str(cell), cell_ms, ", ".join(_cell_parts)])

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



# True when every tile the layout of this cell can read is in memory: the centre, and the four corners pushed out by SCATTER_PAD_M
# (the bank-stone water probe reaches 24 m, boulder hollows 6 m). Only the centre was checked before, so a cell at a tile edge read the
# next tile from disk on the main thread: "items tick slow: scatter reached after 479 ms" in Dave's 2 Nov log. Each missing tile is
# asked for on a worker thread (ground_ready prefetches it) and the cell waits for the next sync.
func _cell_ground_ready(cell: Vector2i, cell_m: float) -> bool:
	if not ground_ready.is_valid():
		return true

	var lo: Vector2 = Vector2(cell) * cell_m - Vector2(SCATTER_PAD_M, SCATTER_PAD_M)
	var hi: Vector2 = (Vector2(cell) + Vector2.ONE) * cell_m + Vector2(SCATTER_PAD_M, SCATTER_PAD_M)
	var all_ready: bool = true

	for p in [(lo + hi) * 0.5, lo, hi, Vector2(lo.x, hi.y), Vector2(hi.x, lo.y)]:
		if not bool(ground_ready.call(p.x, p.y)):
			all_ready = false   # keep asking for the others too, so they all load together

	return all_ready


# The spawn boost adds up to the cap but never takes away: a sloped cell already rolling more than the cap keeps its own roll (Dino round 7).
static func boosted(base: int, add: int, cap: int) -> int:
	return maxi(base, mini(base + add, cap))


func _lay_out_cell(cell: Vector2i, cell_m: float, cfg: Dictionary) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(cell.x, cell.y, world_seed))
	var part_usec: int = Time.get_ticks_usec()
	_cell_parts = []
	_lay_out_cave_items(cell, cell_m, cfg)
	_cell_cave_ms = float(Time.get_ticks_usec() - part_usec) / 1000.0
	part_usec = _cell_part("cave floor", part_usec)
	var centre: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * cell_m
	var h0: float = float(ground_height.call(centre.x, centre.y))
	var h1: float = float(ground_height.call(centre.x + 4.0, centre.y))
	var h2: float = float(ground_height.call(centre.x, centre.y + 4.0))

	if is_nan(h0) or is_nan(h1) or is_nan(h2) or h0 < 1.0:
		return

	var slope: float = (absf(h1 - h0) + absf(h2 - h0)) / 4.0
	var stones: int = mini(int(rng.randf() * (float(cfg.get("stones_flat", 0.5)) + slope * float(cfg.get("stones_per_slope", 3.0))) * 2.0), int(cfg.get("stones_max", 4)))   # luck-exempt: seeded world layout
	var sticks: int = mini(int(rng.randf() * 3.0), int(cfg.get("sticks_max", 2)))   # luck-exempt: seeded world layout
	var boost: Dictionary = cfg.get("spawn_boost", {})

	# Near the spawn every cell holds extra stones and sticks (a new player's first campfire kit; drops.json spawn_boost).
	if not boost.is_empty() and Vector2(centre.x - respawn_point.x, centre.y - respawn_point.z).length() <= float(boost.get("radius_m", 0.0)):
		var more_stones: Array = boost.get("stones_add", [0, 0])
		var more_sticks: Array = boost.get("sticks_add", [0, 0])
		stones = boosted(stones, rng.randi_range(int(more_stones[0]), int(more_stones[1])), int(boost.get("stones_max_boost", 4)))   # luck-exempt: seeded world layout
		sticks = boosted(sticks, rng.randi_range(int(more_sticks[0]), int(more_sticks[1])), int(boost.get("sticks_max_boost", 4)))   # luck-exempt: seeded world layout

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

	part_usec = _cell_part("stones and sticks", part_usec)
	_bank_ground_usec = 0
	_bank_water_usec = 0
	_lay_out_bank_stones(cell, cell_m, cfg, kinds.size())
	part_usec = _cell_part("bank stones", part_usec)
	_cell_parts[-1] += " (ground %.0f, water %.0f)" % [float(_bank_ground_usec) / 1000.0, float(_bank_water_usec) / 1000.0]
	_lay_out_boulders(cell, cell_m)
	_cell_part("boulders", part_usec)


# A cell's own random stream for one part of its layout (Sonny, 10 Nov 2026). The loose stones and sticks drew first from one stream, and a stick's spot
# takes more or fewer draws as the flora cover reads 0 or 1 (cover_at reads 0 until a worker builds the flora chunk). So the bank stones and boulders after
# them moved with the timing, and a boulder's key (its worked count, its outcrop ore) could land on another boulder after a restart. Bank stones and
# boulders each draw from their own stream, seeded from the cell, the world seed and the part, so their places are fixed per world.
func _layout_rng(cell: Vector2i, part: String) -> RandomNumberGenerator:
	var stream: RandomNumberGenerator = RandomNumberGenerator.new()
	stream.seed = hash([cell.x, cell.y, world_seed, part])
	return stream


# Notes a part of a scatter cell's layout in _cell_parts (for the slow-cell line); returns now, the next part's start.
func _cell_part(part: String, since_usec: int) -> int:
	var now: int = Time.get_ticks_usec()
	_cell_parts.append("%s %.0f" % [part, float(now - since_usec) / 1000.0])
	return now


# Boulders (Dave 2026-10-21), see data/items/boulders.json: server-owned lumps of rock a pick breaks into stones. Laid out per
# cell like loose stones, from the cell's own "boulders" stream (_layout_rng), only where the ground rises or at a
# water bank; what is left of a worked boulder is kept in _boulder_left. The row carries its radius and the stones it started
# with; the item's count is the stones left.
func _boulder_stones(radius: float) -> int:
	var cfg: Dictionary = _boulder_cfg
	var volume: float = 4.0 / 3.0 * PI * radius * radius * radius * float(cfg.get("height_ratio", 0.85))
	var stone_kg: float = maxf(CarryRules.weight_of("stone", _carry_cfg) if not _carry_cfg.is_empty() else 1.0, 0.05)
	return maxi(int(volume * float(cfg.get("density_kg_m3", 2600)) * float(cfg.get("yield", 0.5)) / stone_kg), 1)


func _lay_out_boulders(cell: Vector2i, cell_m: float) -> void:
	var cfg: Dictionary = _boulder_cfg

	if cfg.is_empty():
		return

	var rng: RandomNumberGenerator = _layout_rng(cell, "boulders")
	var laid: int = 0

	# Every try takes the same five draws whatever happens to it, and the boulder's key is its try, not its count: a try that the live water turns
	# on or off (the bank chance) adds or drops that one boulder and moves no other boulder's key.
	for attempt in range(mini(int(cfg.get("tries", 8)), 16)):
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

		var key: int = BOULDER_KEY | ((cell.x & 0xfffff) << 24) | ((cell.y & 0xfffff) << 4) | attempt
		laid += 1
		var radius: float = lerpf(float(cfg.get("radius_min", 0.3)), float(cfg.get("radius_max", 1.2)), pow(size_draw, float(cfg.get("radius_power", 2.0))))
		var total: int = _boulder_stones(radius)
		var left: int = mini(int(_boulder_left.get(key, total)), total)

		if left <= 0:
			continue

		var row: Dictionary = {"radius": radius, "yaw": yaw, "total": total}
		var ore_name: String = _boulder_ore(spot, key)

		if ore_name != "":
			row["ore"] = ore_name   # an outcrop: a pick takes this ore out of it (boulders.json ore)

		_items[_next_id] = {"number": 0, "count": left, "pos": spot, "left": 1.0e9, "scatter": key, "boulder": row}
		_next_id += 1


# The ore a boulder is an outcrop of ("" for a plain boulder): the terrain's ore body within reach of it, for a share of the boulders chosen from the key.
func _boulder_ore(spot: Vector3, key: int) -> String:
	var cfg: Dictionary = _boulder_cfg.get("ore", {})

	if cfg.is_empty():
		return ""

	if ore_near.is_valid() and float(hash(key) % 1000) < 1000.0 * float(cfg.get("boulder_share", 0.0)):
		var name: String = str(ore_near.call(spot, float(cfg.get("reach_m", 40.0)), cfg.get("items", {}), float(cfg.get("layer_depth_m", 10.0))))

		if (cfg.get("items", {}) as Dictionary).has(name):
			return name

	# Else the boulder's own rock (Dave 10 Nov 2026, Concrete = Lime powder + Sand + Stone): over limestone, chalk or marble bedrock a share of the
	# boulders give limestone pieces (boulders.json ore "rocks": rock name -> item, rock_boulder_share, rock_piece_share).
	var rocks: Dictionary = cfg.get("rocks", {})

	if rocks.is_empty() or not rock_near.is_valid() or float(hash([key, "rock"]) % 1000) >= 1000.0 * float(cfg.get("rock_boulder_share", 0.0)):
		return ""

	var rock: String = str(rock_near.call(spot))
	return rock if rocks.has(rock) else ""


# The blows a stone takes from the best tool a hotbar key points at (items.json material, boulders.json tools), as [slot, blows], or [].
func _boulder_tool(inv) -> Array:
	var best: Array = []
	var tools: Dictionary = _boulder_cfg.get("tools", {})

	for slot in range(inv.SLOTS):
		if not inv.on_hotbar(slot) or _is_broken(inv.numbers[slot], inv.wear[slot]):
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
	hit_number(peer, it["pos"] + Vector3(0.0, size_now, 0.0), HIT_POINTS / float(maxi(int(tool[1]), 1)))

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

	# Ore (F-23): a pick on an outcrop takes ore out of it now and then, else stone.
	var ore_cfg: Dictionary = _boulder_cfg.get("ore", {})
	var ore_item: int = 0

	if info.has("ore") and not ore_cfg.is_empty():
		var held: Dictionary = table.entry(table.id_of(inv.numbers[int(tool[0])]))

		# needs_material (boulders.json ore): the pick materials that may take each ore; no entry = any pick (iron ore needs a bronze, iron or steel pick: the ladder).
		var allowed_materials: Array = (ore_cfg.get("needs_material", {}) as Dictionary).get(str(info["ore"]), [])
		var material_ok: bool = allowed_materials.is_empty() or allowed_materials.has(str(held.get("material", "")))

		if not material_ok and str(held.get("tool_class", "")) == str(ore_cfg.get("tool_class", "pick")) and int(info.get("blows", 0)) == 0:
			_say(peer, "This pick is too soft for that ore.")   # said once per stone, when the stone comes away

		var rock_piece: bool = (ore_cfg.get("rocks", {}) as Dictionary).has(str(info["ore"])) and not (ore_cfg.get("items", {}) as Dictionary).has(str(info["ore"]))
		var share: float = float(ore_cfg.get("rock_piece_share", 0.5)) if rock_piece else float(ore_cfg.get("piece_share", 0.5))

		if material_ok and str(held.get("tool_class", "")) == str(ore_cfg.get("tool_class", "pick")) and fate(peer, "boulder_ore", share):
			var piece_id: String = str((ore_cfg.get("rocks", {}) as Dictionary).get(str(info["ore"]), "")) if rock_piece else str((ore_cfg.get("items", {}) as Dictionary).get(str(info["ore"]), ""))
			ore_item = table.number_of(piece_id)

	if ore_item > 0:
		inv.add(ore_item, 1)
		out = 1

	# Flint (F-02): now and then the piece that comes away is a flint nodule (more near water). A nodule is one piece, never a double.
	var flint_cfg: Dictionary = _boulder_cfg.get("flint", {})
	var flint_n: int = table.number_of(str(flint_cfg.get("item", "flint"))) if not flint_cfg.is_empty() else 0
	var flint_p: float = float(flint_cfg.get("chance", 0.0))

	if flint_n > 0 and water_near.is_valid() and bool(water_near.call(it["pos"], float(flint_cfg.get("water_reach_m", 6.0)))):
		flint_p = float(flint_cfg.get("near_water_chance", flint_p))

	if ore_item > 0:
		pass   # the piece was ore
	elif flint_n > 0 and flint_p > 0.0 and fate(peer, "boulder_flint", flint_p):
		inv.add(flint_n, 1)
		out = 1
	else:
		inv.add(stone, out)

	practice(peer, "mine_rock")   # breaking a boulder is Mining too
	it["count"] = int(it["count"]) - out
	_boulder_left[it["scatter"]] = int(it["count"])
	_dirty = true

	if int(it["count"]) <= 0:
		_items.erase(id)


# Caves are riddled with rocks and stones (Dave 4 Nov 2026): the loose stones and boulders the baked caves under this cell hold
# (tile_terrain_data.cave_scatter_in), a share of the stones flint as on the banks. Keys of their own (CAVE_KEY), so a stone taken stays taken.
func _lay_out_cave_items(cell: Vector2i, cell_m: float, cfg: Dictionary) -> void:
	if not cave_scatter.is_valid():
		return

	var spots: PackedFloat32Array = cave_scatter.call(cell, cell_m)
	var flint: float = float(cfg.get("bank", {}).get("flint", 0.0))

	@warning_ignore("integer_division")
	for n in range(mini(spots.size() / 5, CAVE_ITEMS_MAX)):
		var key: int = CAVE_KEY | ((cell.x & 0xfffff) << 28) | ((cell.y & 0xfffff) << 8) | n

		if _taken.has(key):
			continue

		var spot: Vector3 = Vector3(spots[n * 5], spots[n * 5 + 1], spots[n * 5 + 2])

		if int(spots[n * 5 + 3]) == 1 and not _boulder_cfg.is_empty():
			var radius: float = spots[n * 5 + 4]
			var total: int = _boulder_stones(radius)
			var left: int = mini(int(_boulder_left.get(key, total)), total)

			if left > 0:
				var cave_row: Dictionary = {"radius": radius, "yaw": float(hash(key) % 360), "total": total}
				var cave_ore: String = _boulder_ore(spot, key)   # a cave boulder is an outcrop like one on the surface (Kathleen 10 Nov 2026: caves never rolled ore)

				if cave_ore != "":
					cave_row["ore"] = cave_ore

				_items[_next_id] = {"number": 0, "count": left, "pos": spot, "left": 1.0e9, "scatter": key, "boulder": cave_row}
				_next_id += 1

			continue

		var number: String = "flint" if flint > 0.0 and float(hash(key) % 1000) < 1000.0 * flint else "stone"
		_items[_next_id] = {"number": table.number_of(number), "count": 1, "pos": spot, "left": 1.0e9, "scatter": key}
		_next_id += 1


# Stones along the water's edge (Dave 2026-10-21: any rock put down is pickable, so Art's drawn pebbles and boulders became
# real stones). A cell with water in or near it tries bank_tries spots; a dry spot within bank_reach_m of water takes a
# stone with chance bank_chance, up to bank_max a cell. Item keys continue after the cell's own scatter (low four bits).
func _lay_out_bank_stones(cell: Vector2i, cell_m: float, cfg: Dictionary, used: int) -> void:
	var bank: Dictionary = cfg.get("bank", {})

	if bank.is_empty() or not water_near.is_valid():
		return

	var rng: RandomNumberGenerator = _layout_rng(cell, "bank stones")   # its own stream: the sticks before it no longer move it

	var centre: Vector3 = Vector3((float(cell.x) + 0.5) * cell_m, 0.0, (float(cell.y) + 0.5) * cell_m)

	if not bool(water_near.call(centre, float(bank.get("cell_probe_m", 24.0)))):
		return

	var reach: float = float(bank.get("reach_m", 3.0))
	var laid: int = 0

	for attempt in range(int(bank.get("tries", 40))):
		var x: float = (float(cell.x) + rng.randf()) * cell_m   # luck-exempt: seeded world layout
		var z: float = (float(cell.y) + rng.randf()) * cell_m   # luck-exempt: seeded world layout
		var chance: float = rng.randf()   # luck-exempt: seeded world layout

		if chance > float(bank.get("chance", 0.5)):   # before the ground is read (the draws are in the same order, so the stones lie where they did)
			continue

		var ground_usec: int = Time.get_ticks_usec()
		var y: float = float(ground_height.call(x, z))
		var water_usec: int = Time.get_ticks_usec()
		_bank_ground_usec += water_usec - ground_usec

		if is_nan(y) or y < 1.0:
			continue

		var spot: Vector3 = Vector3(x, y, z)
		var wet: bool = bool(water_near.call(spot, 0.0)) or not bool(water_near.call(spot, reach))
		_bank_water_usec += Time.get_ticks_usec() - water_usec

		if wet:
			continue

		var key: int = ((cell.x & 0xfffff) << 24) | ((cell.y & 0xfffff) << 4) | (used + laid)

		if used + laid >= 15 or laid >= int(bank.get("max", 6)):
			return

		laid += 1

		if _taken.has(key):
			continue

		var driftwood: bool = float(hash([key, "driftwood"]) % 1000) < 1000.0 * float(bank.get("driftwood", 0.12))   # from the key, so every try takes three draws
		var bank_number: String = "driftwood" if driftwood else "stone"

		if not driftwood and float(bank.get("flint", 0.0)) > 0.0 and float(hash(key) % 1000) < 1000.0 * float(bank.get("flint", 0.0)):
			bank_number = "flint"   # F-02: a share of the bank stones are flint (from the key, so the layout's random stream is not touched)

		_items[_next_id] = {"number": table.number_of(bank_number), "count": 1, "pos": spot, "left": 1.0e9, "scatter": key}
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
	var fell: Dictionary = _drops.get("felling", {})   # data/items/drops.json "felling": the blow counts follow the swing time (balance, Dave tunes)
	var hit_radius: float = float(info["trunk"])

	if bool(fell.get("size_scaled", false)):   # off until Dave says yes (QA card tree-hits-follow-size): the blows follow this tree's own drawn trunk, so a sapling falls in fewer than a giant
		hit_radius = FellPose.standing_radius(float(info["trunk"]), float(info.get("ref_height", 0.0)), float(info["height"]), bool(info.get("broadleaf", false)))

	var needed: int = maxi(1, int(ceil(float(clampi(int(round(float(fell.get("tree_base", 4.0)) + hit_radius * float(fell.get("tree_per_trunk_m", 30.0)))), int(fell.get("tree_min", 4)), int(fell.get("tree_max", 40)))) / skill_factor(peer, "fell_tree"))))

	hit_number(peer, spot + Vector3(0.0, 1.2, 0.0), HIT_POINTS / float(needed))

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
	_goal_event(peer, "tree_felled")
	practice(peer, "fell_tree", clampf(float(info["trunk"]) * 3.0, 0.4, 2.0))   # a thick trunk teaches more than a sapling


# Cuts a standing tree and lays its trunk and stump down (the last axe blow and a dug-out tree both end here). `away` is the
# direction it falls in.
func _fell(chunk: Vector2i, tree_id: int, info: Dictionary, away: Vector2) -> void:
	if not bool(cut_tree.call(chunk, tree_id)):
		return

	_fell_record(chunk, info, away)


# The butt radius of a felled tree: the radius its standing model is drawn with (fell_pose.gd drawn_radius: its species model and variant, so a slim
# young tree gives a slim trunk, stump and logs; Dave 2 Nov). Without the tree's id, the species trunk scaled with height as before.
func _felled_radius(info: Dictionary) -> float:
	var entry: Dictionary = _flora_by_name.get(str(info.get("name", "")), {})

	if info.has("id") and not entry.is_empty():
		return maxf(FellPose.drawn_radius(entry, int(info["id"]), float(info["height"])), 0.06)

	return maxf(FellPose.standing_radius(float(info["trunk"]), float(info.get("ref_height", 0.0)), float(info["height"]), bool(info.get("broadleaf", false))), 0.1)


# The circle a felled tree's crown lands on (Dave 10 Nov 2026), as [x, z, radius]: the canopy's own size (Cover.crown_radius of its species and height),
# centred on the middle of the crown's part of the trunk (drops.json trunk.crown_scatter.crown_from) as it lies.
func _crown_circle(spot: Vector3, info: Dictionary, yaw: float, pitch: float) -> Array:
	var cfg: Dictionary = (_drops.get("trunk", {}) as Dictionary).get("crown_scatter", {})
	var entry: Dictionary = _flora_by_name.get(str(info.get("name", "")), {})
	var height: float = float(info["height"])
	var span: Array = entry.get("height_m", [])
	var ref_height: float = float(info.get("ref_height", 0.0))

	if ref_height <= 0.0:
		ref_height = 0.5 * (float(span[0]) + float(span[1])) if span.size() >= 2 else height

	var radius: float = maxf(CoverScript.crown_radius(float(entry.get("crown_m", 3.0)), ref_height, height), float(cfg.get("min_radius_m", 1.5)))
	var from: float = clampf(float(cfg.get("crown_from", 0.5)), 0.0, 1.0)
	var along: float = height * (from + (1.0 - from) * 0.5) * cos(pitch)
	return [spot.x + sin(yaw) * along, spot.z + cos(yaw) * along, radius]


func _fell_record(chunk: Vector2i, info: Dictionary, away: Vector2) -> void:
	var spot: Vector3 = info["position"]
	var yaw: float = atan2(away.x, away.y) if away.length() > 0.01 else 0.0
	var pitch: float = 0.0

	if ground_height.is_valid():   # fall away from the player, resting ON the ground and never inside a slope (fell_pose.gd)
		var pose: Dictionary = FellPose.choose(spot, away, float(info["height"]), _felled_radius(info), ground_height)
		yaw = float(pose["yaw"])
		pitch = float(pose["pitch"])

	var now_s: float = float(game_seconds.call()) if game_seconds.is_valid() else 0.0
	# The same size as the standing tree: its drawn radius (scaled with its height), and its whole height as the length.
	var radius: float = _felled_radius(info)
	var base: Dictionary = {"species": str(info["name"]), "yaw": yaw, "length": float(info["height"]), "radius": radius, "felled_at": now_s}
	var trunk: Dictionary = base.duplicate()
	trunk["state"] = 3
	trunk["pitch"] = pitch
	trunk["keywood"] = true   # every full-size tree is cut into logs (Dave 1 Nov): the client marks the next cut line on them. Only key woods have their own log item; the rest drop the plain Log
	trunk["chunk"] = [chunk.x, chunk.y]
	trunk["auto_split"] = true   # it breaks into its logs by itself once it has hit the ground (_auto_split)
	trunk["crown"] = _crown_circle(spot, info, yaw, pitch)   # where its crown lands: the client flattens the grass there, the split litters it
	var stump: Dictionary = base.duplicate()
	stump["state"] = 4
	stump["chunk"] = [chunk.x, chunk.y]
	_items[_next_id] = {"number": 0, "count": 1, "pos": spot, "left": 1.0e9, "tree": trunk}
	_split_due[_next_id] = Time.get_ticks_msec() + FALL_SETTLE_MS
	_next_id += 1
	_items[_next_id] = {"number": 0, "count": 1, "pos": spot, "left": 1.0e9, "tree": stump}
	_next_id += 1
	_dirty = true
	_sync_in = 0.0   # bug 6: the trunk goes out on the next tick with the flora cut, not up to SYNC_EVERY_S later, so the tree never vanishes before it falls


func _has_tool(inv, tool_class: String) -> bool:
	return _tool_slot(inv, tool_class) >= 0


# The pack slot of a usable (not broken) tool of this class that a hotbar key points at (inventory step 4: keys hold items, not slots), or -1.
func _tool_slot(inv, tool_class: String) -> int:
	for slot in range(inv.SLOTS):
		if inv.on_hotbar(slot) and str(table.entry(table.id_of(inv.numbers[slot])).get("tool_class", "")) == tool_class and not _is_broken(inv.numbers[slot], inv.wear[slot]):
			return slot

	return -1


# Why a tool-class action did nothing: no tool, the tool is worn out, or it lies in the bag instead of on the hotbar.
func _say_tool_missing(peer: int, inv, tool_class: String) -> void:
	var found: int = -1

	for slot in range(inv.SLOTS):
		if inv.numbers[slot] != 0 and str(table.entry(table.id_of(inv.numbers[slot])).get("tool_class", "")) == tool_class:
			found = slot

			if not _is_broken(inv.numbers[slot], inv.wear[slot]):
				break

	if found < 0:
		_say(peer, "You need a %s for that." % tool_class)
	elif _is_broken(inv.numbers[found], inv.wear[found]):
		_say(peer, "Your %s is worn out. Repair it (R in the inventory) with %s." % [table.sentence_name(inv.numbers[found]), _repair_text(table.entry(table.id_of(inv.numbers[found])).get("repair", []))])
	else:
		_say(peer, "Put your %s on the hotbar: select it in the inventory and press E." % table.sentence_name(inv.numbers[found]))


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

	var work_cfg: Dictionary = _exertion_cfg.get("tool_effort", {})
	_work_until[peer] = Time.get_ticks_msec() + int(float(_exertion_cfg.get("work_s", 2.5)) * 1000.0)
	_work_level[peer] = float(work_cfg.get(tool_class, work_cfg.get("default", 0.6)))
	var before: Array = _snapshot(inv)
	# A skilled crafter looks after their tools: wear is spread by the tool_care factor (1.0 for everyone at first), a deterministic
	# carry of the fraction so no dice are involved.
	var wear_now: float = float(maxi(1, int(_drops.get("tool_wear", {}).get("per_use", {}).get(tool_class, {}).get(use, 1)))) / skill_factor(peer, "tool_care") + float(_wear_carry.get(peer, 0.0))
	var whole: int = int(floor(wear_now + 0.001))
	_wear_carry[peer] = wear_now - float(whole)
	inv.wear[slot] += whole
	_dirty = true

	if _is_broken(inv.numbers[slot], inv.wear[slot]):
		_say(peer, "Your %s broke. Repair it with new materials." % table.sentence_name(inv.numbers[slot]))

	_send_changes(peer, inv, before)


# Repair (ACT_REPAIR): the slot's tool, worn or broken, takes the repair materials from items.json
# ("repair": [[item, count], ...]) and wins back half its durability.
func _repair(peer: int, inv, slot: int) -> void:
	if slot < 0 or slot >= inv.SLOTS or inv.numbers[slot] == 0 or inv.wear[slot] <= 0:
		return

	var entry: Dictionary = table.entry(table.id_of(inv.numbers[slot]))
	var costs: Array = entry.get("repair", [])

	if bool(entry.get("edge", false)) and _hone(peer, inv, slot, entry):
		return

	if costs.is_empty():
		return

	var bench: String = str(entry.get("repair_station", ""))

	if bench != "" and not station_near(peer, bench):
		_say(peer, "Repairing this needs a %s nearby." % _station_name(bench).to_lower())
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
	practice(peer, "tool_care")


# Whetstone hand repair (Part C plan 4; drops.json tool_wear.hone): R on an edged tool (items.json "edge": true) with a sound whetstone in the
# pack hones it with no materials. It wins back hone.restores of its durability but never past hone.up_to of it; the whetstone wears and is
# kept. False (and the real repair goes ahead) with no whetstone, or when the tool is already that sharp: past it, the haft and binding need mending.
func _hone(peer: int, inv, slot: int, entry: Dictionary) -> bool:
	var cfg: Dictionary = _drops.get("tool_wear", {}).get("hone", {})
	var stone: int = table.number_of(str(cfg.get("item", "whetstone")))
	var most: int = int(entry.get("durability", 0))

	if cfg.is_empty() or stone == 0 or most <= 0:
		return false

	var sharpest: int = int(ceil(float(most) * (1.0 - float(cfg.get("up_to", 0.75)))))   # the least wear a hone leaves

	if inv.wear[slot] <= sharpest:
		return false

	var stone_slot: int = -1

	for s in inv.SLOTS:
		if s != slot and inv.numbers[s] == stone and not _is_broken(stone, inv.wear[s]):
			stone_slot = s
			break

	if stone_slot < 0:
		return false

	inv.wear[slot] = maxi(sharpest, inv.wear[slot] - int(float(most) * float(cfg.get("restores", 0.25))))
	_wear_slot(peer, inv, stone_slot, "hone")
	practice(peer, "tool_care")
	_say(peer, str(cfg.get("say_hone", "")) % table.sentence_name(inv.numbers[slot]))
	_dirty = true
	return true


func _repair_text(costs: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()

	for cost in costs:
		parts.append("%d %s" % [int(cost[1]), table.sentence_name(table.number_of(str(cost[0])))])

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

		if int(tree["state"]) == 3:
			tree["landed"] = true   # BUG-024: a saved trunk fell long ago; it is never drawn falling again

		_items[_next_id] = {"number": 0, "count": 1, "pos": Vector3(row["pos"][0], row["pos"][1], row["pos"][2]), "left": 1.0e9, "tree": tree}

		if int(tree["state"]) == 3 and (bool(tree.get("auto_split", false)) or (not tree.has("auto_split") and not tree.has("split_tries") and int(tree.get("blows", 0)) == 0)):   # felled but not yet broken up (also a trunk from before the auto-split that nobody has cut): do it now
			_split_due[_next_id] = 0

		_next_id += 1


# One axe blow on a felled trunk (drops.json "trunk"): branches and leaves first, then logs with some
# bark and now and then seeds. The server checks the axe, the pace and that the player stands at the
# trunk (distance to its line). The trunk is used up when its logs are gone; the stump stays.
func _process_trunk(peer: int, inv, id: int) -> void:
	var it: Dictionary = _items.get(id, {})

	if str(it.get("struct", {}).get("kind", "")) == "carcass":
		_process_carcass(peer, inv, id)
		return

	if not it.is_empty() and not it.has("tree") and not it.has("struct"):
		_chop_loose_log(peer, inv, id)
		return

	if not it.is_empty() and it.has("tree") and int(it["tree"]["state"]) == 4:
		_chop_stump(peer, inv, id)
		return

	if it.is_empty() or not it.has("tree") or int(it["tree"]["state"]) != 3 or not _peer_pos.has(peer) or not _has_tool(inv, "axe"):
		return

	var tree: Dictionary = it["tree"]
	var cfg: Dictionary = _drops.get("trunk", {})
	var along: Vector3 = Vector3(sin(float(tree["yaw"])), 0.0, cos(float(tree["yaw"])))
	var from_base: Vector3 = _peer_pos[peer] - it["pos"]
	var flat: float = cos(float(tree.get("pitch", 0.0)))
	var length_now: float = float(tree["length"])
	var logs_phase: bool = int(tree.get("blows", 0)) >= int(cfg.get("branch_blows", 3)) and int(tree.get("logs_left", 0)) > 0
	var t: float = clampf(from_base.dot(along), 0.0, length_now * flat)

	if logs_phase:   # logs come off the far end: the player stands by the next cut line (the middle of the piece that comes off)
		var piece: float = length_now if int(tree["logs_left"]) <= 1 else minf(float(cfg.get("log_length_m", 2.44)), length_now)
		t = (length_now - piece * 0.5) * flat

	var nearest: Vector3 = it["pos"] + along * t

	if Vector2(_peer_pos[peer].x - nearest.x, _peer_pos[peer].z - nearest.z).length() > PROCESS_REACH_M + float(tree["radius"]):
		if logs_phase and _peer_pos[peer].distance_to(it["pos"]) < length_now + 6.0:
			_say(peer, "Walk along the trunk to the cut line.")

		return

	var now: int = Time.get_ticks_msec()

	if float(now - int(_last_process.get(peer, -100000))) < float(PROCESS_COOLDOWN_MS) / _pace_factor(peer, "work_trunk"):
		return

	_last_process[peer] = now
	_wear_tool(peer, inv, "axe", "trunk")
	practice(peer, "work_trunk")
	tree["landed"] = true   # the client draws it lying from now on (a shorter trunk is not felled again)

	if not tree.has("logs_left"):
		tree["logs_left"] = clampi(int(float(tree["length"]) / float(cfg.get("log_length_m", 2.44))), 0, int(cfg.get("max_logs", 20)))   # whole 8 ft (2.44 m) lengths only
		tree["blows"] = 0   # every tree makes logs (Dave 1 Nov); a species without its own log item drops the plain Log (_cut_log_off)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(id) ^ (int(tree["blows"]) * 7919)
	var blows: int = int(tree["blows"])
	tree["blows"] = blows + 1

	if blows < int(cfg.get("branch_blows", 3)):
		for row in _branch_rows(tree, cfg, it["pos"]):
			give(peer, table.number_of(str(row[0])), roll_amount(peer, rng, int(row[1]), int(row[2])))
	elif int(tree["logs_left"]) <= 0:   # too short for one whole log: only firewood, kindling and sticks
		for row in cfg.get("small", []):
			var small_id: String = _wood_item("firewood", str(tree.get("species", ""))) if str(row[0]) == "firewood" else str(row[0])
			give(peer, table.number_of(small_id), roll_amount(peer, rng, int(row[1]), int(row[2])))

		if blows + 1 >= int(cfg.get("branch_blows", 3)) + int(cfg.get("small_blows", 3)):
			_items.erase(id)
	else:
		var per_log: float = float(cfg.get("blows_per_log", 3))   # a fraction is fine (1.6: a log every 1 or 2 blows, the remainder carries over)
		var progress: float = float(tree.get("cut_progress", 0.0)) + 1.0
		tree["cut_progress"] = progress

		if progress >= per_log - 0.001:   # the cut goes through: the log drops on the ground beside the trunk (never into the pack or onto the shoulder)
			if _cut_log_off(peer, id, tree, cfg):
				tree["cut_progress"] = progress - per_log
				tree["logs_left"] = int(tree["logs_left"]) - 1
			else:
				tree["cut_progress"] = maxf(per_log - 1.0, 0.0)   # no room for it: the next blow tries the cut again

		var thatch_bark: Dictionary = (cfg.get("thatch_bark", {}) as Dictionary).get(str(tree.get("species", "")), {})

		if not thatch_bark.is_empty():   # birch and softwood bark is thatch (Dave 24 Oct)
			if roll_chance(peer, rng, float(thatch_bark.get("chance", 0.3))):
				var count: Array = thatch_bark.get("count", [2, 4])
				give(peer, table.number_of("thatch"), roll_amount(peer, rng, int(count[0]), int(count[1])))
		elif roll_chance(peer, rng, float(cfg.get("bark_chance", 0.3))):
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


# The rows the last blow gives: the first final_by_radius entry whose max_radius_m reaches the stump's radius (the last has no limit), else the plain "final" rows (Sal and Dave, 1 Nov 2026).
func _stump_final_rows(cfg: Dictionary, radius: float) -> Array:
	for entry in cfg.get("final_by_radius", []):
		if radius <= float(entry.get("max_radius_m", 1.0e9)):
			return entry.get("rows", [])

	return cfg.get("final", [])


# One axe blow on a stump (drops.json "stump"): a few blows (more for a thick one) chop it up for kindling and firewood, then it is gone and its record
# is freed. The blow count is saved with the stump, so a half-chopped stump stays half-chopped across a restart; the pace and skill rules are the trunk's.
func _chop_stump(peer: int, inv, id: int) -> void:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not it.has("tree") or int(it["tree"]["state"]) != 4 or not _peer_pos.has(peer) or not _has_tool(inv, "axe"):
		return

	var tree: Dictionary = it["tree"]
	var cfg: Dictionary = _drops.get("stump", {})

	if Vector2(_peer_pos[peer].x - it["pos"].x, _peer_pos[peer].z - it["pos"].z).length() > PROCESS_REACH_M + float(tree["radius"]):
		return

	var now: int = Time.get_ticks_msec()

	if float(now - int(_last_process.get(peer, -100000))) < float(PROCESS_COOLDOWN_MS) / _pace_factor(peer, "work_trunk"):
		return

	_last_process[peer] = now
	_wear_tool(peer, inv, "axe", "trunk")
	practice(peer, "work_trunk")
	var needed: int = clampi(int(ceil(float(cfg.get("blows_base", 3)) + float(tree["radius"]) * float(cfg.get("blows_per_radius_m", 15)))), int(cfg.get("blows_min", 3)), int(cfg.get("blows_max", 14)))
	var blows: int = int(tree.get("blows", 0)) + 1
	tree["blows"] = blows
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(id) ^ (blows * 7919)
	var species: String = str(tree.get("species", ""))

	if blows < needed:
		if roll_chance(peer, rng, float(cfg.get("chip_chance", 0.5))):
			for row in cfg.get("chip", []):
				give(peer, table.number_of(str(row[0])), roll_amount(peer, rng, int(row[1]), int(row[2])))

		if send_notice.is_valid():
			send_notice.call(peer, "Chopping the stump: %d of %d" % [blows, needed])
	else:
		for row in _stump_final_rows(cfg, float(tree["radius"])):
			var drop_id: String = _wood_item("firewood", species) if str(row[0]) == "firewood" else str(row[0])
			give(peer, table.number_of(drop_id), roll_amount(peer, rng, int(row[1]), int(row[2])))

		_items.erase(id)

	_dirty = true


# Where the next cut goes (the middle of the piece that comes off the far end), as a world position: the spot a player stands at to cut the next log (tests and the cut-line hint use it).
func cut_line_point(id: int) -> Vector3:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not it.has("tree"):
		return Vector3.ZERO

	var tree: Dictionary = it["tree"]
	var log_len: float = float(_drops.get("trunk", {}).get("log_length_m", 2.44))
	var length_now: float = float(tree["length"])
	var piece: float = length_now if int(tree.get("logs_left", 1)) <= 1 else minf(log_len, length_now)
	var yaw: float = float(tree["yaw"])
	return it["pos"] + Vector3(sin(yaw), 0.0, cos(yaw)) * ((length_now - piece * 0.5) * cos(float(tree.get("pitch", 0.0))))


# The item number of a species' log; a species without its own log item (or a retired one: alder, willow...) gives the plain Log.
func _log_number(species: String) -> int:
	var log_n: int = table.number_of("log_" + species)

	if log_n <= 0 or bool(table.entry("log_" + species).get("retired", false)):
		log_n = table.number_of("log")

	return log_n


# A felled tree breaks into its logs by itself once it has hit the ground (Dave 2 Nov): the same whole 2.44 m lengths as cutting it would give
# (_process_trunk: logs_left), the same species log, lying along the line where the trunk fell. The trunk record goes, so the client drops one
# mesh and shows the logs as ordinary loose items (one cached mesh per species): no repeated trunk rebuild as in bug 6. A trunk already worked with
# the axe (it has blows), one with no whole log in it, or one with no room for all its logs is left as a trunk to cut by hand.
func _auto_split() -> void:
	if _split_due.is_empty():
		return

	var now: int = Time.get_ticks_msec()
	var ready: Array = []

	for id in _split_due:
		if int(_split_due[id]) <= now:
			ready.append(id)

	for id in ready:
		_split_due.erase(id)

		# BUG-024: it has hit the ground. A client that sees the trunk from now on (coming back into range) draws it lying, not falling again.
		if _items.has(id) and _items[id].has("tree") and int(_items[id]["tree"].get("state", 0)) == 3 and not bool(_items[id]["tree"].get("landed", false)):
			_items[id]["tree"]["landed"] = true
			_dirty = true

		if not split_trunk(int(id)) and _items.has(id) and _items[id].has("tree") and bool(_items[id]["tree"].get("auto_split", false)):
			var tries: int = int(_items[id]["tree"].get("split_tries", 0)) + 1   # no room yet (a crowded spot): look again in half a minute, three times, then it stays a trunk to cut by hand
			_items[id]["tree"]["split_tries"] = tries

			if tries < 3:
				_split_due[id] = now + 30000
			else:
				_items[id]["tree"].erase("auto_split")
				_dirty = true


# Breaks the felled trunk `id` into logs now; true when it did. See _auto_split.
func split_trunk(id: int) -> bool:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not it.has("tree") or int(it["tree"]["state"]) != 3 or int(it["tree"].get("blows", 0)) > 0:
		return false

	var tree: Dictionary = it["tree"]
	var cfg: Dictionary = _drops.get("trunk", {})
	var log_len: float = float(cfg.get("log_length_m", 2.44))
	var length: float = float(tree["length"])
	var count: int = clampi(int(length / log_len), 0, int(cfg.get("max_logs", 20)))

	if count <= 0:   # too short for one whole log (a sapling-sized tree): it breaks up into what hand-cutting gives, firewood, kindling and sticks (and the branches)
		tree.erase("auto_split")
		return _split_small(id, it, cfg)

	var yaw: float = float(tree["yaw"])
	var pitch: float = float(tree.get("pitch", 0.0))
	var along: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
	var radius: float = float(tree["radius"])
	var log_n: int = _log_number(str(tree.get("species", "")))
	var spots: Array = []

	for k in range(count):   # the last log takes the rest of the trunk, as cutting does; each lies at the middle of its piece
		var from_butt: float = float(k) * log_len
		var piece: float = log_len if k < count - 1 else length - from_butt
		var mid: float = from_butt + piece * 0.5
		spots.append(it["pos"] + along * (mid * cos(pitch)) + Vector3(0.0, sin(pitch) * mid + radius, 0.0))

	var near: int = 0

	var scope: Array = []   # the loose items any of the drops below can meet (each drop then looks at these, not every record in the world)

	for other_id in _items:   # room for every log, or none (the crowd rule of drop_in_world, counted once)
		var other: Dictionary = _items[other_id]

		if other.has("scatter") or other.has("showroom") or other.has("struct") or other.has("fire") or other.has("tree"):
			continue

		var flat: float = Vector2(other["pos"].x - it["pos"].x, other["pos"].z - it["pos"].z).length()

		if flat <= DROP_CROWD_M + length:
			near += 1

		if flat <= DROP_CROWD_M + length + radius + 1.0:
			scope.append(other_id)

	var litter: Array = _crown_litter(id, tree, cfg, it["pos"])   # the crown's sticks and leaves, all over the circle it landed on
	var extras: Array = _trunk_extras(id, tree, count, cfg, litter.is_empty())   # what hand-cutting gives besides the logs (bark, seeds, roots; the branches when there is no crown litter)

	if near + count + extras.size() + litter.size() > MAX_DROPPED_NEAR:
		_dirty = true
		return false

	tree.erase("auto_split")
	_items.erase(id)
	_drop_scope = scope
	_drop_scoped = true

	for spot in spots:   # the log mesh lies along its x axis: turned by yaw - 90 degrees it runs along the trunk (0 = +Z)
		drop_in_world(log_n, 1, spot, 0, SPLIT_LIFETIME_S, yaw - PI * 0.5, _log_girth(log_n, radius))

	var heap: Vector3 = it["pos"] + along * (length * 0.5 * cos(pitch)) + Vector3(-along.z, 0.0, along.x) * (radius + 0.7)   # beside the middle of the trunk, as the cut logs land

	for extra in extras:
		drop_in_world(int(extra[0]), int(extra[1]), heap, 0, SPLIT_LIFETIME_S)

	for row in litter:
		drop_in_world(int(row[0]), int(row[1]), row[2], 0, SPLIT_LIFETIME_S)

	_drop_scoped = false
	_drop_scope = []
	_dirty = true
	return true


# A trunk too short for a whole log breaks up into what hand-cutting gives it: the branch blows' sticks and leaves, then the small rows (firewood, kindling, sticks) of every small blow.
func _split_small(id: int, it: Dictionary, cfg: Dictionary) -> bool:
	var tree: Dictionary = it["tree"]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(id) ^ 7919
	var species: String = str(tree.get("species", ""))
	var totals: Dictionary = {}
	var litter: Array = _crown_litter(id, tree, cfg, it["pos"])
	var branch: Array = _branch_rows(tree, cfg, it["pos"]) if litter.is_empty() else []

	for blow in range(int(cfg.get("branch_blows", 3))):
		for row in branch:
			var n: int = table.number_of(str(row[0]))
			totals[n] = int(totals.get(n, 0)) + rng.randi_range(int(row[1]), int(row[2]))   # luck-exempt: world drop, no player

	for blow in range(int(cfg.get("small_blows", 3))):
		for row in cfg.get("small", []):
			var small_id: String = _wood_item("firewood", species) if str(row[0]) == "firewood" else str(row[0])
			var m: int = table.number_of(small_id)
			totals[m] = int(totals.get(m, 0)) + rng.randi_range(int(row[1]), int(row[2]))   # luck-exempt: world drop, no player

	var rows: Array = []

	for n in totals:
		if int(n) > 0 and int(totals[n]) > 0:
			rows.append([int(n), int(totals[n])])

	var yaw: float = float(tree["yaw"])
	var heap: Vector3 = it["pos"] + Vector3(sin(yaw), 0.0, cos(yaw)) * (float(tree["length"]) * 0.5) + Vector3(0.0, float(tree["radius"]), 0.0)
	_items.erase(id)

	for row in rows:
		drop_in_world(int(row[0]), int(row[1]), heap, 0, SPLIT_LIFETIME_S)

	for row in litter:
		drop_in_world(int(row[0]), int(row[1]), row[2], 0, SPLIT_LIFETIME_S)

	_dirty = true
	return true


# What one branch blow of a felled trunk gives (drops.json trunk.branch) when it is cut by hand, with the leaves sized to the crown (Dave 10 Nov 2026: "everyone
# should be giving me hundreds"): trunk.crown_leaves.per_m leaves per metre of tree, shared over the branch blows. A bare broadleaf in winter (Cover.DECIDUOUS,
# the season where it lies) and the species in crown_leaves.fixed (the conifers) give sticks only.
func _branch_rows(tree: Dictionary, cfg: Dictionary, at: Vector3) -> Array:
	var branch: Array = cfg.get("branch", [])
	var crown: Dictionary = cfg.get("crown_leaves", {})

	if crown.is_empty():
		return branch

	var leafy: bool = _crown_leafy(tree, cfg, at)
	var per_m: Array = crown.get("per_m", [8, 12])
	var share: float = float(tree.get("orig_length", tree.get("length", 0.0))) / float(maxi(int(cfg.get("branch_blows", 3)), 1))
	var rows: Array = []

	for row in branch:
		if str(row[0]) != "leaves":
			rows.append(row)
		elif leafy:
			rows.append(["leaves", maxi(roundi(float(per_m[0]) * share), 1), maxi(roundi(float(per_m[1]) * share), 1)])

	return rows


# Whether a felled crown has leaves to give: not a conifer (crown_leaves.fixed) and not a broadleaf bare in winter where it lies.
func _crown_leafy(tree: Dictionary, cfg: Dictionary, at: Vector3) -> bool:
	var species: String = str(tree.get("species", ""))

	if ((cfg.get("crown_leaves", {}) as Dictionary).get("fixed", []) as Array).has(species):
		return false

	return not (CoverScript.is_deciduous(species) and CoverScript.leafless_for(str(season_at.call(at)) if season_at.is_valid() else _season()))


# A felled crown's sticks and leaves (Dave 10 Nov 2026: "drop like 30 sticks and a hundred leaves all over the forest floor in that circle"), as
# [item number, count, Vector3] rows spread over the circle it landed on (tree.crown, see _crown_circle): trunk.crown_scatter sticks_per_m and
# leaves_per_m per metre of tree, each over `spots` little heaps. Sticks only from a conifer or a bare winter broadleaf. Empty for a trunk without a
# crown circle (saved before it): it keeps the branch rows. Rolled from the trunk's id; no player, so no luck (world drop).
func _crown_litter(id: int, tree: Dictionary, cfg: Dictionary, at: Vector3) -> Array:
	var scatter: Dictionary = cfg.get("crown_scatter", {})
	var circle: Array = tree.get("crown", [])

	if scatter.is_empty() or circle.size() < 3:
		return []

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(id) ^ 104729
	var length: float = float(tree.get("orig_length", tree.get("length", 0.0)))
	var sticks: Array = scatter.get("sticks_per_m", [1.6, 2.4])
	var leaves: Array = scatter.get("leaves_per_m", [5.5, 8.0])
	var spots: Dictionary = scatter.get("spots", {})
	var lots: Array = [["stick", roundi(rng.randf_range(float(sticks[0]), float(sticks[1])) * length)]]   # luck-exempt: world drop, no player

	if _crown_leafy(tree, cfg, at):
		lots.append(["leaves", roundi(rng.randf_range(float(leaves[0]), float(leaves[1])) * length)])   # luck-exempt: world drop, no player

	var rows: Array = []

	for lot in lots:
		var total: int = int(lot[1])
		var number: int = table.number_of(str(lot[0]))

		if total <= 0 or number <= 0:
			continue

		var heaps: int = clampi(int(spots.get(str(lot[0]), 6)), 1, total)

		for k in range(heaps):
			var angle: float = rng.randf() * TAU   # luck-exempt: where it lands, no player
			var far: float = sqrt(rng.randf()) * float(circle[2])   # luck-exempt: where it lands, no player
			var x: float = float(circle[0]) + cos(angle) * far
			var z: float = float(circle[1]) + sin(angle) * far
			var y: float = at.y

			if ground_height.is_valid():   # on the ground where it lands, not at the stump's height (a slope)
				var ground: float = float(ground_height.call(x, z))
				y = ground + 0.1 if not is_nan(ground) else y

			rows.append([number, floori(float(total) / float(heaps)) + (1 if k < total % heaps else 0), Vector3(x, y, z)])

	return rows


# What cutting a trunk by hand gives besides the logs, as [item number, count] rows, for a trunk of `logs` whole logs (_process_trunk): the branch blows' sticks and leaves,
# then per log the bark (or thatch) and seed rolls, and the root ball at the end. Rolled from the trunk's id like hand cutting; no player, so no luck (world drops).
func _trunk_extras(id: int, tree: Dictionary, logs: int, cfg: Dictionary, with_branches: bool = true) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(id) ^ 7919
	var species: String = str(tree.get("species", ""))
	var totals: Dictionary = {}
	var branch: Array = _branch_rows(tree, cfg, _items.get(id, {}).get("pos", Vector3.ZERO)) if with_branches else []

	for blow in range(int(cfg.get("branch_blows", 3))):
		for row in branch:
			var n: int = table.number_of(str(row[0]))
			totals[n] = int(totals.get(n, 0)) + rng.randi_range(int(row[1]), int(row[2]))   # luck-exempt: world drop, no player

	var thatch_bark: Dictionary = (cfg.get("thatch_bark", {}) as Dictionary).get(species, {})
	var own: Array = cfg.get("by_species", {}).get(species, [])

	for k in range(logs):
		if not thatch_bark.is_empty():
			if rng.randf() < float(thatch_bark.get("chance", 0.3)):   # luck-exempt: world drop, no player
				var span: Array = thatch_bark.get("count", [2, 4])
				var t: int = table.number_of("thatch")
				totals[t] = int(totals.get(t, 0)) + rng.randi_range(int(span[0]), int(span[1]))   # luck-exempt: world drop, no player
		elif rng.randf() < float(cfg.get("bark_chance", 0.3)):   # luck-exempt: world drop, no player
			var b: int = table.number_of("bark")
			totals[b] = int(totals.get(b, 0)) + 1

		if rng.randf() < float(cfg.get("seed_chance", 0.15)):   # luck-exempt: world drop, no player
			var sn: int = table.number_of("seed_bundle") if own.is_empty() else table.number_of(str(own[0][0]))
			totals[sn] = int(totals.get(sn, 0)) + (1 if own.is_empty() else rng.randi_range(int(own[0][1]), int(own[0][2])))   # luck-exempt: world drop, no player

	var roots: Array = cfg.get("roots", [])

	if not roots.is_empty():
		var r: int = table.number_of(str(roots[0]))
		totals[r] = int(totals.get(r, 0)) + rng.randi_range(int(roots[1]), int(roots[2]))   # luck-exempt: world drop, no player

	var rows: Array = []

	for n in totals:
		if int(n) > 0 and int(totals[n]) > 0:
			rows.append([int(n), int(totals[n])])

	return rows


# One log cut off the far end of a felled trunk (Dave: a log must land on the ground, never in the pack or on the shoulder; the trunk gets shorter with a fresh cut face). The log is an ordinary
# dropped log item beside the trunk, so it obeys the drop rules; false (nothing changes, the next blow tries again) when the spot is too crowded. The last log takes whatever is left of the trunk.
func _cut_log_off(peer: int, id: int, tree: Dictionary, cfg: Dictionary) -> bool:
	var it: Dictionary = _items[id]
	var log_len: float = float(cfg.get("log_length_m", 2.44))
	var length_now: float = float(tree["length"])
	var seg: float = length_now if int(tree.get("logs_left", 1)) <= 1 else minf(log_len, length_now)
	var yaw: float = float(tree["yaw"])
	var pitch: float = float(tree.get("pitch", 0.0))
	var along: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
	var side: Vector3 = Vector3(-along.z, 0.0, along.x)
	var mid: float = length_now - seg * 0.5
	var radius: float = float(tree["radius"])
	var at: Vector3 = it["pos"] + along * (mid * cos(pitch)) + side * (radius + 0.7) + Vector3(0.0, sin(pitch) * mid + radius, 0.0)
	var log_n: int = _log_number(str(tree.get("species", "")))

	if not drop_in_world(log_n, 1, at, 0, 0.0, yaw - PI * 0.5, _log_girth(log_n, radius)):
		_say(peer, "Too many things lie here. Clear some away first.")
		return false

	if not tree.has("orig_length"):
		tree["orig_length"] = length_now

	tree["length"] = maxf(length_now - seg, 0.0)
	return true


# A stump has rotted away: maybe a sapling grows near a standing tree of the same species. Nothing
# comes while any felled trunk still lies in the chunk. The dice come from the seed and the spot,
# so a restart gives the same answer.
# Is a placed structure, fire or other ground-placed thing within `radius` of the spot (flat distance)? Saplings keep away from these.
func _built_within(spot: Vector3, radius: float) -> bool:
	for id in _items:
		var it: Dictionary = _items[id]

		if not (it.has("struct") or it.has("fire")):
			continue

		if str(it.get("struct", {}).get("kind", "")) == "remains":
			continue

		if Vector2(it["pos"].x - spot.x, it["pos"].z - spot.z).length() <= radius:
			return true

	return false


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

	if _built_within(spot, REGROW_EXCLUDE_M):
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

			if str(entry.get("kind", "tree")) != "tree":
				return {}   # a planted bush is not a tree to fell (shrub_info finds it)

			var span: Array = entry.get("height_m", [])
			var ref_height: float = 0.5 * (float(span[0]) + float(span[1])) if span.size() >= 2 else 0.0
			return {"name": str(entry.get("name", "")), "position": sapling["pos"], "height": _sapling_height(sapling, now_s), "trunk": float(entry.get("trunk_m", 0.4)), "ref_height": ref_height, "broadleaf": str(entry.get("shape", "")) == "broadleaf", "dynamic": true, "id": id}

	return {}


# A split log's girth against the drawn species log (only species logs: the plain Log has its own small mesh).
func _log_girth(log_n: int, radius: float) -> float:
	return radius / LOG_MESH_RADIUS_M if table.id_of(log_n).begins_with("log_") else NAN


# The extra row fields of a loose item: its turn and a split log's girth.
func _loose_extra(it: Dictionary) -> Dictionary:
	var extra: Dictionary = {}

	if it.has("rot_y"):
		extra["rot_y"] = float(it["rot_y"])

	if it.has("girth"):
		extra["girth"] = float(it["girth"])

	if it.has("tilt"):
		extra["tilt"] = float(it["tilt"])   # an arrow stuck in a tree: drawn where it is, along its flight

	return extra


# A planted bush or shrub (dynamic flora) as shrub_info gives it, or {}.
func dynamic_shrub_info(home: Vector2i, id: int) -> Dictionary:
	var now_s: float = float(game_seconds.call()) if game_seconds.is_valid() else 0.0

	for sapling in _saplings:
		if sapling["chunk"] == [home.x, home.y] and ((int(sapling["species"]) << 16) | (0xFFFF - int(sapling["slot"]))) == id:
			var entry: Dictionary = _flora_by_id.get(int(sapling["species"]), {})

			if str(entry.get("kind", "")) != "shrub":
				return {}

			return {"name": str(entry.get("name", "")), "position": sapling["pos"], "height": _sapling_height(sapling, now_s), "dynamic": true}

	return {}


# Bushes and shrubs (Dave 2 Nov 2026, hazel too). An axe chops one up into leaves and sticks (drops.json shrub_work axe_blows, axe_gives); a pickaxe
# digs it up whole as <species>_bush, to plant again elsewhere (_plant_bush). Either way the bush is gone from the world.
func _hit_shrub(peer: int, inv, flora_id: int, chunk: Vector2i, pick: bool) -> void:
	if not _peer_pos.has(peer) or not shrub_info.is_valid() or not cut_tree.is_valid():
		return

	var now: int = Time.get_ticks_msec()

	if now - int(_last_hit.get(peer, -100000)) < HIT_COOLDOWN_MS:
		return

	var tool_class: String = "pick" if pick else "axe"
	var slot: int = _tool_slot(inv, tool_class)

	if slot < 0:
		_reject(peer, 1)
		return

	var info: Dictionary = shrub_info.call(chunk, flora_id)

	if info.is_empty():
		return

	var spot: Vector3 = info["position"]

	if Vector2(_peer_pos[peer].x - spot.x, _peer_pos[peer].z - spot.z).length() > HIT_REACH_M + 1.0:
		_reject(peer, 0)
		return

	var cfg: Dictionary = _drops.get("shrub_work", {})
	var dug_id: String = str(info["name"]) + str(cfg.get("dig_suffix", "_bush"))

	if pick and table.number_of(dug_id) == 0:
		_say(peer, "That one will not come up whole.")
		return

	if pick and _fit(peer, inv, table.number_of(dug_id), 1) == 0:
		_say(peer, "Too heavy to carry any more")
		_reject(peer, 2)
		return

	_last_hit[peer] = now
	_wear_slot(peer, inv, slot, "shrub")
	var key: String = "s%s,%d,%d,%d" % ["p" if pick else "a", chunk.x, chunk.y, flora_id]
	var chop: Dictionary = _chops.get(key, {"hits": 0, "msec": now})

	if now - int(chop["msec"]) > CHOP_RESET_MS:
		chop["hits"] = 0

	chop["hits"] = int(chop["hits"]) + 1
	chop["msec"] = now
	_chops[key] = chop

	if int(chop["hits"]) < int(cfg.get("pick_blows" if pick else "axe_blows", 2)):
		return

	_chops.erase(key)

	if not bool(cut_tree.call(chunk, flora_id)):
		return

	if pick:
		give(peer, table.number_of(dug_id), 1)
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(key) ^ now

	for row in cfg.get("axe_gives", []):
		give(peer, table.number_of(str(row[0])), roll_amount(peer, rng, int(row[1]), int(row[2])))


# Planting a dug-up bush (<species>_bush) at `at`, the ground under the crosshair: it grows there as a full bush (dynamic flora, saved with the saplings).
func _plant_bush(peer: int, inv, slot: int, at: Vector3) -> void:
	if slot < 0 or slot >= inv.SLOTS or inv.numbers[slot] == 0 or not _peer_pos.has(peer):
		return

	var suffix: String = str(_drops.get("shrub_work", {}).get("dig_suffix", "_bush"))
	var item_id: String = table.id_of(inv.numbers[slot])

	if not item_id.ends_with(suffix):
		return

	var entry: Dictionary = _flora_by_name.get(item_id.trim_suffix(suffix), {})

	if entry.is_empty() or str(entry.get("kind", "")) != "shrub":
		return

	if Vector2(_peer_pos[peer].x - at.x, _peer_pos[peer].z - at.z).length() > PLANT_BUSH_REACH_M:
		_reject(peer, 0)
		return

	var ground: float = float(ground_height.call(at.x, at.z)) if ground_height.is_valid() else at.y

	if is_nan(ground) or ground < 1.0:
		_say(peer, "The ground is too wet here.")
		return

	if water_depth_at.is_valid() and float(water_depth_at.call(Vector3(at.x, ground, at.z))) >= PlacementRules.FIRE_WATER_BLOCK_M:
		_say(peer, "You cannot plant it in water.")
		return

	var spot: Vector3 = Vector3(at.x, ground, at.z)
	var home: Vector2i = Vector2i(int(floor(spot.x / FLORA_CHUNK_M)), int(floor(spot.z / FLORA_CHUNK_M)))
	var used: Dictionary = {}

	for sapling in _saplings:
		if sapling["chunk"] == [home.x, home.y]:
			used[sapling["slot"]] = true

			if (sapling["pos"] as Vector3).distance_to(spot) < PLANT_BUSH_GAP_M:
				_say(peer, "Too close to another plant.")
				return

	if used.size() >= SAPLINGS_PER_CHUNK:
		_say(peer, "Too many young plants here.")
		return

	var new_slot: int = 0

	while used.has(new_slot):
		new_slot += 1

	inv.take_from_slot(slot, 1)
	var now_s: float = float(game_seconds.call()) if game_seconds.is_valid() else 0.0
	_saplings.append({"slot": new_slot, "chunk": [home.x, home.y], "species": int(entry["id"]), "pos": spot, "planted_at": now_s - SAPLING_GROWN_S})   # a dug bush goes in full size
	_dirty = true

	if flora_changed.is_valid():
		flora_changed.call(home)


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
			inv.set_fav(target, inv.is_fav(slot))   # both halves of a favourite stay favourites
			return


# --- Fire tiers (Dave 24 Oct, cooking.json fire_tiers): the wood in a fire is kept as burning seconds per class (log, firewood, weak),
# burn_left is their sum. The biggest wood burns first; 3 pieces of a class lift the fire to its tier and it keeps that size until
# that wood is gone. A lit fire's world-item state is its tier (40 survival, 1 campfire, 41 bonfire).
static func fire_is_lit(state: int) -> bool:
	return state == 1 or state == FIRE_STATE_SURVIVAL or state == FIRE_STATE_BONFIRE


func _fire_wood(fire: Dictionary) -> Dictionary:
	if not fire.has("wood"):
		var all: float = maxf(float(fire.get("burn_left", 0.0)), 0.0)
		fire["wood"] = {"log": 0.0, "firewood": all if int(fire.get("state", 0)) == 1 else 0.0, "weak": 0.0 if int(fire.get("state", 0)) == 1 else all}

	return fire["wood"]


# How many pieces of a wood class the fire holds: the pieces laid on it (fire["pieces"], one each however long it burns, so a soft firewood counts like a hard one),
# never more than the burning time left allows at the shortest piece of that class (piece_game_s).
func _fire_class_pieces(cls: String, seconds: float, laid: int = -1) -> int:
	var row: Dictionary = (_cooking.get("fire_tiers", {}) as Dictionary).get(cls, {})
	var piece_s: float = float((_cooking.get("piece_game_s", {"log": 259200.0, "firewood": 14400.0, "weak": 1440.0}) as Dictionary).get(cls, 1440.0)) / GAME_RATE
	var by_time: int = int(ceil(seconds / piece_s - 0.0001)) if seconds > 0.0 and not row.is_empty() else 0
	return by_time if laid < 0 else mini(by_time, laid)


# The lit state the wood now in the fire supports: the biggest class with at least min_pieces, else the survival fire.
func _fire_best_state(fire: Dictionary, wet_counts: bool = true) -> int:
	var wood: Dictionary = _fire_wood(fire)
	var need: int = int(_cooking.get("min_pieces", 3))
	var best: int = FIRE_STATE_SURVIVAL

	for cls in ["log", "firewood"]:
		var laid: int = int((fire.get("pieces", {}) as Dictionary).get(cls, -1))

		if _fire_class_pieces(cls, float(wood[cls]), laid) >= need:
			if cls == "log" and bool(fire.get("pot", false)):
				best = int(_cooking["fire_tiers"]["firewood"]["state"])   # a campfire pot hangs over this fire: it never grows past the firewood stage
			else:
				best = int(_cooking["fire_tiers"][cls]["state"])

			break

	if wet_counts and _fire_damp(fire):   # wet wood in it (fire design 5): the heat and light of one tier lower until it is dry
		return FIRE_STATE_SURVIVAL if best == 1 else (1 if best == FIRE_STATE_BONFIRE else best)

	return best


# The lit state after the wood in a burning fire changed (a piece put in, its store closed). Dave 2 Nov 2026: three pieces lift the fire a tier and
# it STAYS at that tier until that wood is gone, then drops to the next class with at least three pieces. So a recount never lowers the tier
# while wood of the tier's class is still burning (two of three logs left is still a bonfire); only a hung pot does (_refresh_pots).
func _fire_restate(fire: Dictionary) -> int:
	var state: int = int(fire["state"])
	var best: int = _fire_best_state(fire)

	if not fire_is_lit(state) or state == FIRE_STATE_SURVIVAL or _fire_tier_of_state(best) >= _fire_tier_of_state(state):
		return best

	if state == FIRE_STATE_BONFIRE and bool(fire.get("pot", false)):
		return best

	return state if float(_fire_wood(fire).get(_fire_class_of_state(state), 0.0)) > 0.0 else best


# A structure kind as it is called now (old saves keep their old name: the tripod pot is the campfire pot).
func _kind_now(kind: String) -> String:
	if _structures.has(kind):
		return kind

	for name in _structures:
		if (_structures[name].get("legacy_kinds", []) as Array).has(kind):
			return str(name)

	return kind


func _is_pot(it: Dictionary) -> bool:
	return it.has("struct") and str(_structures.get(str(it["struct"]["kind"]), {}).get("attach_to", "")) == "fire"


# The fire a pot at this spot hangs over, or -1.
func _fire_under_pot(pos: Vector3) -> int:
	for id in _items:
		if _items[id].has("fire") and (_items[id]["pos"] as Vector3).distance_to(pos) <= POT_ON_FIRE_M:
			return id

	return -1


# Sets fire["pot"] (not saved: the pot's position is the whole link) on every fire. A fire whose pot is gone gets its tier back;
# a fire that was a bonfire when a pot arrived steps down to the firewood stage.
func _refresh_pots() -> void:
	var pots: Array = []

	for id in _items:
		if _is_pot(_items[id]):
			pots.append(_items[id]["pos"])

	for id in _items:
		var it: Dictionary = _items[id]

		if not it.has("fire"):
			continue

		var fire: Dictionary = it["fire"]
		var hung: bool = false

		for at in pots:
			if (at as Vector3).distance_to(it["pos"]) <= POT_ON_FIRE_M:
				hung = true
				break

		fire["pot"] = hung

		if not fire_is_lit(int(fire["state"])):
			continue

		var best: int = _fire_best_state(fire)
		var state: int = int(fire["state"])

		if hung and state == FIRE_STATE_BONFIRE:
			fire["state"] = best
			_lit_valid = false
		elif not hung and state != FIRE_STATE_BONFIRE and _fire_tier_of_state(best) > _fire_tier_of_state(state):
			fire["state"] = best
			_lit_valid = false


func _fire_class_of_state(state: int) -> String:
	return "log" if state == FIRE_STATE_BONFIRE else ("firewood" if state == 1 else "weak")


func _fire_tier_of_state(state: int) -> int:
	return 3 if state == FIRE_STATE_BONFIRE else (2 if state == 1 else 1)


func _fire_sum(fire: Dictionary) -> void:
	var wood: Dictionary = _fire_wood(fire)
	fire["burn_left"] = float(wood["log"]) + float(wood["firewood"]) + float(wood["weak"])


func _fire_wood_class(wood_id: String) -> String:
	return str((_cooking.get("fuel_class", {}) as Dictionary).get(wood_id, "weak"))


# One piece of wood onto the fire: its seconds go to its class (never past the stored-fuel cap) and a lit fire may step up a tier.
func _fire_add(fire: Dictionary, wood_id: String, wet: int = 0) -> void:
	if wet > 0:
		fire["damp"] = maxi(int(fire.get("damp", 0)), wet)   # a wet piece: the fire holds wet wood until it has dried (_wood_tick)

	var wood: Dictionary = _fire_wood(fire)
	var cls: String = str((_cooking.get("fuel_class", {}) as Dictionary).get(wood_id, "weak"))
	var seconds: float = float((_cooking.get("fuel", {}) as Dictionary).get(wood_id, 900.0)) / GAME_RATE
	_fire_sum(fire)
	wood[cls] = float(wood[cls]) + maxf(seconds, 0.0)   # no cap (Dave 2 Nov 2026): the burn time is the sum of every piece in the fire
	var pieces: Dictionary = fire.get("pieces", {})
	pieces[cls] = int(pieces.get(cls, 0)) + 1
	fire["pieces"] = pieces
	_fire_sum(fire)
	fire["fed"] = int(fire.get("fed", 0)) + 1

	if fire_is_lit(int(fire["state"])):
		var best: int = _fire_best_state(fire)

		if _fire_tier_of_state(best) > _fire_tier_of_state(int(fire["state"])):
			fire["state"] = best


# Time passes on a lit fire: the biggest wood burns; when the wood that set its tier is gone it drops a tier.
func _fire_burn(fire: Dictionary, delta: float) -> void:
	var wood: Dictionary = _fire_wood(fire)
	var left: float = delta

	for cls in ["log", "firewood", "weak"]:
		if left <= 0.0:
			break

		var used: float = minf(float(wood[cls]), left)
		wood[cls] = float(wood[cls]) - used
		left -= used

		if bool(fire.get("synced", false)) and used > 0.0:   # what has burned since the store was last counted: whole pieces of it leave the store (_fire_trim_store)
			var burnt: Dictionary = fire.get("burnt", {})
			burnt[cls] = float(burnt.get(cls, 0.0)) + used
			fire["burnt"] = burnt

		if float(wood[cls]) <= 0.0 and fire.has("pieces"):
			(fire["pieces"] as Dictionary).erase(cls)

	_fire_sum(fire)
	var state: int = int(fire["state"])

	if fire_is_lit(state) and state != FIRE_STATE_SURVIVAL and float(wood[_fire_class_of_state(state)]) <= 0.0:
		fire["state"] = _fire_best_state(fire)


# Wood on the fire: a stick or a log adds burning time (no cap). A fire the rain put out
# lights again when fed where rain no longer reaches it (covered, or the rain has stopped).
func _fuel(peer: int, inv, id: int) -> void:
	var fire: Dictionary = _fire_in_reach(peer, id)

	if fire.is_empty():
		return

	_fire_sum(fire)

	var refused_log: bool = false

	for wood in _cooking.get("fuel_order", ["stick", "log"]):
		var number: int = table.number_of(wood)

		if inv.has(number, 1):
			if bool(fire.get("pot", false)) and _fire_wood_class(wood) == "log":
				refused_log = true   # a pot hangs over this fire: no logs, the fire would be too big for it
				continue

			var slot: int = _wettest_slot(inv, number)
			var wet: int = int(inv.wear[slot]) if slot >= 0 else 0

			if bool(fire.get("synced", false)) and _chests.has(int(fire.get("uid", 0))):
				if _chests[int(fire["uid"])].add(number, 1, wet) > 0:   # the store is what burns: the piece goes into it; a full store keeps it in the pack
					_say(peer, "The fire's store is full.")
					return

				inv.take_from_slot(slot, 1)
				_fire_apply_store(fire, _chests[int(fire["uid"])])
				fire["fed"] = int(fire.get("fed", 0)) + 1   # the row is sent again (the inspection label's burn time)

				if fire_is_lit(int(fire["state"])):
					fire["state"] = _fire_restate(fire)
			else:
				inv.take_from_slot(slot, 1)
				_fire_add(fire, wood, wet)

			# Wood laid in an unlit fire only loads it; Press E to light comes next (ACT_LIGHT).
			if int(fire["state"]) == 8:
				fire["state"] = 9
				_items[id]["left"] = FIRE_LAID_S

			return

	if refused_log:
		_say(peer, "Take the pot down before you put logs on. The fire would be too big for it.")
	else:
		_say(peer, "You have no wood, sticks or logs to put on the fire.")


# Lighting a loaded fire (Dave 5 Nov 2026, simplified): any wood in the fire is enough, E lights it, and no starter (plant fibre, tinder, kindling)
# is needed or used up. Every kind of wood goes in: sticks, kindling, tinder, firewood, blocks, logs. An open fire will not take while it rains.
func _light(peer: int, inv, id: int) -> void:
	var fire: Dictionary = _fire_in_reach(peer, id)

	if fire.is_empty() or (int(fire["state"]) != 9 and int(fire["state"]) != FIRE_STATE_ASH):
		return

	if float(fire["burn_left"]) <= 0.0:
		_say(peer, "Put sticks or wood on the fire first (F), then light it.")
		return

	# Warm ash (docs/design/fire_coals_design.md 3): wood and a tinder item light it at once, with no damp roll, and the tinder is used up.
	# Without tinder it lights like a cold laid fire.
	if int(fire["state"]) == FIRE_STATE_ASH and _use_tinder(fire, inv):
		fire["state"] = _fire_best_state(fire)
		fire.erase("wet_s")
		_items[id]["left"] = 1.0e9
		_lit_valid = false
		_dirty = true
		_say(peer, "The tinder catches on the warm ash.")
		return

	var raining: bool = rain_now.is_valid() and float(rain_now.call()) >= RAIN_PUTS_OUT

	var rain_cfg: Dictionary = _cooking.get("rain_light_chance", {})
	var rain_now_v: float = float(rain_now.call()) if rain_now.is_valid() else 0.0

	# Dave 5 Nov 2026: an open fire does light in the rain, but the rain puts it out again after a few seconds (RAIN_LIGHT_GRACE_S).
	if raining and not bool(fire["covered"]):
		fire["rain_grace"] = RAIN_LIGHT_GRACE_S
		_say(peer, "It catches, but the rain will put it out in a moment. Move it under cover.")
	else:
		# A drizzle makes lighting a gamble (cooking.json rain_light_chance); kindling that is all wet halves the chance (wet_wood.light_x) unless
		# there is dry tinder in the fire (fire design 5).
		var chance: float = 1.0
		var wet_kindling: bool = _fire_wet_kindling(fire)

		if rain_now_v > 0.02 and not bool(fire["covered"]):
			chance = maxf(1.0 - rain_now_v / maxf(float(rain_cfg.get("puts_out", 0.2)), 0.01) * float(rain_cfg.get("loss", 0.8)), float(rain_cfg.get("min_chance", 0.2)))

		if wet_kindling:
			chance *= float(table.wet_wood().get("light_x", 0.5))

		if chance < 1.0 and not roll_chance(peer, _rain_rng, chance):
			_say(peer, "The wet wood will not catch. Try again, or put dry tinder in." if wet_kindling else "The wood will not catch in the damp. Try again.")
			return

	fire["state"] = _fire_best_state(fire)
	fire.erase("wet_s")
	_items[id]["left"] = 1.0e9
	_lit_valid = false
	_dirty = true


# One tinder item (cooking.json tinder and tinder_also) taken for lighting warm ash: from the fire's store first, else from the pack. False when there is none.
func _use_tinder(fire: Dictionary, inv) -> bool:
	var kinds: Array = [str(_cooking.get("tinder", "plant_fibre"))] + (_cooking.get("tinder_also", []) as Array)
	var box = _chests.get(int(fire.get("uid", 0))) if bool(fire.get("synced", false)) else null

	for kind in kinds:
		var number: int = table.number_of(str(kind))

		if number <= 0:
			continue

		if box != null:
			for slot in range(box.usable):
				if box.numbers[slot] == number and box.counts[slot] > 0:
					box.take_from_slot(slot, 1)
					_fire_apply_store(fire, box)
					return true

		if inv != null and inv.has(number, 1):
			inv.remove(number, 1)
			return true

	return false


# Roasting at a lit fire: one raw forage item (cookable_suffixes in cooking.json) becomes Campfire Stew.
func _cook(peer: int, inv, id: int) -> void:
	var fire: Dictionary = _fire_in_reach(peer, id)

	if fire.is_empty() or not fire_is_lit(int(fire["state"])):
		return

	var now: int = Time.get_ticks_msec()

	if now - int(_last_cook.get(peer, -100000)) < int(_cooking.get("pace_ms", 1200)):
		return

	for slot in range(inv.SLOTS):
		if inv.numbers[slot] != 0 and _cookable(table.id_of(inv.numbers[slot])):
			_last_cook[peer] = now
			var raw: Dictionary = inv.take_from_slot(slot, 1)
			var cooked: int = table.number_of(str(_cooking.get("cooks_into", {}).get(table.id_of(int(raw["number"])), _cooking.get("gives", "roast_forage"))))
			# Cooking: the roast keeps for cooked_life_mult times what the raw item had left (Tyler: 1.5 to 2.5 times, about 3 at most), never more than the roast's own shelf life.
			var left_units: float = float(table.shelf_units(int(raw["number"])) - int(raw.get("wear", 0))) if table.shelf_units(int(raw["number"])) > 0 else 1.0e9
			var life: int = table.shelf_units(cooked)
			var age: int = maxi(life - int(minf(left_units * float(_cooking.get("cooked_life_mult", 2.0)), float(life))), 0)
			var left: int = inv.add(cooked, 1, age)

			if left > 0:
				drop_in_world(cooked, left, _peer_pos[peer])

			return

	# Nothing in the pack the fire can cook: say what it does cook, at most every 5 s while E is held (Sal: the refusal for plants was silent).
	if now - int(_last_cook.get(peer, -100000)) > 5000:
		_last_cook[peer] = now
		_say(peer, "The campfire cooks meat and fish. Plants go in a pot or on the clay hearth.")


# Food that should have been cooked (cooking.json raw_sick, hours of sickness by item id or id suffix; Tyler: raw meat 24 h,
# fiddleheads and beans 12, acorns and wild mushrooms mild at 6). It still feeds you; the stomach pays afterwards.
func _raw_hours(item_id: String) -> float:
	var cfg: Dictionary = _cooking.get("raw_sick", {})
	var hours: float = float(cfg.get("by_id", {}).get(item_id, 0.0))

	if hours <= 0.0:
		for suffix in cfg.get("by_suffix", {}):
			if item_id.ends_with(str(suffix)):
				hours = float(cfg["by_suffix"][suffix])
				break

	return hours


func _raw_sickness(peer: int, item_id: String) -> void:
	var hours: float = _raw_hours(item_id)
	var odds: Dictionary = _infection_cfg().get("odds", {})
	var known_harm: bool = str(tried_of(peer).get(item_id, "")) == "harm"     # a known harm costs the full sickness at once (ruling 8 Nov, row 26)

	if hours > 0.0 and odds.has(item_id) and not known_harm and not (not tried_of(peer).has(item_id) and grace_of(peer) > 0.0):
		_infect(peer, item_id, hours, float(odds[item_id]))
	elif hours > 0.0:
		_harm_bite(peer, item_id, hours, "That should have been cooked. Your stomach turns.")
	else:
		_learn_food(peer, item_id, "ok")


# Late, uncertain sickness from raw animal food (docs/design/body_in_weather_design.md 5; sickness.json infection when its flag is on, else empty).
func _infection_cfg() -> Dictionary:
	var inf: Variant = _sick_cfg.get("infection", {})
	return inf if typeof(inf) == TYPE_DICTIONARY and bool(inf.get("enabled", false)) else {}


# One roll at the bite (luck helps you escape it); on a hit the sickness waits onset_h game hours in the vitals' sick_due. A miss teaches nothing:
# the food stays unknown until it makes you sick.
func _infect(peer: int, item_id: String, hours: float, p: float) -> void:
	var v: Dictionary = vitals_of(peer)

	if v.is_empty() or roll_chance(peer, _fate_rng, 1.0 - clampf(p, 0.0, 1.0)):
		return

	var onset: Array = _infection_cfg().get("onset_h", [24, 72])
	var minutes: int = roll_amount(peer, _fate_rng, int(float(onset[0]) * 60.0), int(float(onset[onset.size() - 1]) * 60.0))   # lucky: later

	if typeof(v.get("sick_due", null)) != TYPE_ARRAY:
		v["sick_due"] = []

	v["sick_due"].append([float(minutes) * 60.0, hours, item_id, float(minutes) * 60.0])
	_dirty = true


# Pending sicknesses count down in game seconds while the player is online; one that starts names what was eaten and is learned as harm.
func _sick_due_tick(peer: int, v: Dictionary, game_s: float) -> void:
	if typeof(v.get("sick_due", null)) != TYPE_ARRAY or (v["sick_due"] as Array).is_empty():
		return

	var keep: Array = []

	for due in v["sick_due"]:
		var left: float = float(due[0]) - game_s

		if left > 0.0:
			keep.append([left, due[1], due[2], due[3]])
			continue

		var item_id: String = str(due[2])
		var days: int = maxi(int(round(float(due[3]) / 86400.0)), 1)
		var when: String = "yesterday" if days == 1 else "%d days ago" % days
		var food: String = table.sentence_name(table.number_of(item_id)) if table != null else item_id
		_say(peer, str(_sick_cfg.get("infection", {}).get("say_onset", "Your stomach turns. It was the %s %s.")) % [food, when])
		_learn_food(peer, item_id, "harm")
		make_sick(peer, float(due[1]), false)   # the onset line above says it

	v["sick_due"] = keep


# --- Eat-once learning (EARLY_GAME_PRINCIPLES 5, data/items/eat_memory.json) ---

var _eat_cfg: Dictionary = {}
var _eat_warn: Dictionary = {}      # peer -> {"item": id, "until": msec}: the harm warning the next press confirms


func _eat_cfg_value(key: String, fallback: Variant) -> Variant:
	if _eat_cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/eat_memory.json"))
		_eat_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {"none": true}

	return _eat_cfg.get(key, fallback)


func tried_of(peer: int) -> Dictionary:
	var key: String = str(_peer_key.get(peer, ""))

	if key == "" or not _characters.has(key):
		return {}

	if typeof(_characters[key].get("tried", null)) != TYPE_DICTIONARY:
		_characters[key]["tried"] = {}

	return _characters[key]["tried"]


func grace_of(peer: int) -> float:
	return float(_characters.get(str(_peer_key.get(peer, "")), {}).get("grace_s", 0.0))


# A harm is never forgotten; "ok" only fills an unknown food.
func _learn_food(peer: int, item_id: String, what: String) -> void:
	var tried: Dictionary = tried_of(peer)

	if str(tried.get(item_id, "")) == "harm" or str(tried.get(item_id, "")) == what:
		return

	if _characters.has(str(_peer_key.get(peer, ""))):
		tried[item_id] = what
		_dirty = true


# A food that harms: in the first hour an unknown one costs food and water only, otherwise the stomach pays. Either way it is remembered.
func _harm_bite(peer: int, item_id: String, hours: float, line: String) -> void:
	var unknown: bool = not tried_of(peer).has(item_id)
	_learn_food(peer, item_id, "harm")

	if unknown and grace_of(peer) > 0.0:
		var v: Dictionary = vitals_of(peer)
		var cost: Dictionary = _eat_cfg_value("first_hour_cost", {})
		v["fed"] = maxf(float(v["fed"]) - float(cost.get("fed_kcal", 150)), 0.0)
		v["wet"] = maxf(float(v["wet"]) - float(cost.get("wet_ml", 150)), 0.0)
		_say(peer, str(_eat_cfg_value("say_first_hour", "")))
		_sync_vitals(peer, true)
		return

	if line != "":
		_say(peer, line)

	make_sick(peer, hours)


# True when the bite must wait: a food that harmed this character before is stopped once, with a hint; a second press within
# confirm_window_s eats it anyway.
func _eat_stopped(peer: int, item_id: String, now: int) -> bool:
	if str(tried_of(peer).get(item_id, "")) != "harm":
		return false

	var warn: Dictionary = _eat_warn.get(peer, {})

	if str(warn.get("item", "")) == item_id and now <= int(warn.get("until", 0)):
		_eat_warn.erase(peer)
		return false

	_eat_warn[peer] = {"item": item_id, "until": now + int(float(_eat_cfg_value("confirm_window_s", 5.0)) * 1000.0)}
	_say(peer, str(_eat_cfg_value("say_warn", "")))
	think(peer, "hint_harm")
	return true


# A hot meal or a hot drink lifts body warmth a little (cooking.json "warms", warmth points); the warmth tick then pulls it back.
func _warm_bite(v: Dictionary, item_id: String) -> void:
	var gain: float = float(_cooking.get("warms", {}).get(item_id, 0.0))

	if gain > 0.0:
		v["warmth"] = minf(float(v.get("warmth", 100.0)) + gain, 100.0)


func _cookable(item_id: String) -> bool:
	if _cooking.get("cooks_into", {}).has(item_id):
		return true

	if item_id == "" or item_id == str(_cooking.get("gives", "")):
		return false

	for suffix in _cooking.get("cookable_suffixes", []):
		if item_id.ends_with(str(suffix)):
			return true

	return false


# The fire record of a world item id when the player stands within reach of it, else {}.
# A torch in hand goes out under water or in the open rain (Dave, 4 Nov 2026; flame_rules.gd): the client, which knows the held slot, asks; the
# item becomes its "doused_item" with the same wear. Rain is checked here too (the world's rain now and the cover over the player).
func _douse(peer: int, inv, slot: int, by_rain: bool) -> void:
	if slot < 0 or slot >= inv.SLOTS or inv.numbers[slot] == 0:
		return

	var into: String = str(table.entry(table.id_of(inv.numbers[slot])).get("doused_item", ""))

	if into == "" or table.number_of(into) <= 0:
		return

	if by_rain:
		var rain: float = float(rain_now.call()) if rain_now.is_valid() else 0.0

		if not FlameRules.in_rain(rain, _peer_covered(peer)):
			return
	elif not bool(_head_under.get(peer, false)) and not bool(_swimming.get(peer, false)):
		return   # water puts it out only when the server too sees the head under water or the player swimming

	var flame_row: Dictionary = table.entry(table.id_of(inv.numbers[slot]))

	if by_rain and not bool(flame_row.get("rain_douses", false)):
		return   # a lantern burns on in the rain behind its horn panes

	var word: String = FlameRules.flame_word(flame_row)
	inv.numbers[slot] = table.number_of(into)
	_say(peer, ("The rain puts your %s out. Press its key to light it again." if by_rain else "The water puts your %s out. Press its key to light it again.") % word)


# Whether a player is under cover from the rain (a crown, a roof, a cave): at the feet or at the eye, where the flame and the client's own test are
# (Dave 10 Nov 2026: a torch went out in a lean-to). The shelter status reads the same cover (comfort_at).
const EYE_M := 1.6


func _peer_covered(peer: int) -> bool:
	if not cover_at.is_valid() or not _peer_pos.has(peer):
		return false

	var feet: Vector3 = _peer_pos[peer]
	return float(cover_at.call(feet)) > 0.5 or float(cover_at.call(feet + Vector3(0.0, EYE_M, 0.0))) > 0.5


# A torch in hand stuck in the ground or on a wall (Dave, 4 Nov 2026): items.json places_as names the structure for each; a burning torch stays lit with
# one stick's worth of fuel (structures.json fuel_s), a doused one is placed out. No gap rule (gap_exempt); the chunk cap holds. Hold E takes it back.
func _place_torch(peer: int, inv, slot: int, on_wall: bool, yaw_deg: int, at: Vector3) -> void:
	if slot < 0 or slot >= inv.SLOTS or inv.numbers[slot] == 0 or not _peer_pos.has(peer):
		return

	var entry: Dictionary = table.entry(table.id_of(inv.numbers[slot]))
	var kind: String = str((entry.get("places_as", {}) as Dictionary).get("wall" if on_wall else "ground", ""))
	var def: Dictionary = _structures.get(kind, {})

	if def.is_empty():
		return

	if _peer_pos[peer].distance_to(at) > float(def.get("use_reach_m", 3.0)) + 1.0:
		_say(peer, "Too far to place that.")
		return

	if water_depth_at.is_valid() and float(water_depth_at.call(at)) > 0.05:
		_say(peer, "A torch will not burn in water.")
		return

	var spot: Vector3 = at

	if not on_wall:
		var ground: float = float(ground_height.call(at.x, at.z)) if ground_height.is_valid() else at.y

		if is_nan(ground) or absf(ground - at.y) > 0.6:
			_say(peer, "Push it into the ground.")
			return

		spot.y = minf(ground, at.y)      # on a floor or a foundation the aimed point stands; on open ground it goes in at the ground

	var of_kind: int = 0

	for id in _items:
		if _items[id].has("struct") and str(_items[id]["struct"]["kind"]) == kind and _chunk_of(_items[id]["pos"]) == _chunk_of(spot):
			of_kind += 1

	if of_kind >= int(def.get("cap_per_chunk", 24)):
		_say(peer, "Too many of these stand here already.")
		return

	var lit: bool = bool(entry.get("flame", false))
	var wear: int = inv.wear[slot]
	inv.take_from_slot(slot, 1)
	var placed: Dictionary = {"number": table.number_of(str(def["item"])), "count": 1, "pos": spot, "left": 1.0e9, "wear": wear, "struct": {"kind": kind, "yaw": float(posmod(yaw_deg, 360))}}

	if lit:
		placed["struct"]["lit"] = true
		placed["struct"]["fuel_left"] = light_burn_s(def)

	_items[_next_id] = placed
	_grid_add(_next_id, placed)
	_next_id += 1
	_dirty = true


# E at a burning fire with a doused torch in the pack lights the first one again (Dave, 4 Nov 2026).
# `want` is the hotbar slot plus one of the torch the player holds (0 for none): pressing a doused torch on the hotbar at a burning fire lights that one
# (Dave 6 Nov 2026); otherwise the first doused torch in the pack.
func _relight(peer: int, inv, id: int, want: int = 0) -> void:
	# id 0 is the hotkey: a torch that went out simply lights again, wherever you are (Dave 6 Nov 2026: nobody is stuck in a cave without light). With a fire id
	# (E at a burning fire) the fire has to be lit and in reach, as before.
	if id != 0:
		var fire: Dictionary = _fire_in_reach(peer, id)

		if fire.is_empty() or not fire_is_lit(int(fire["state"])):
			return

	var order_first: int = want - 1 if want >= 1 and want <= inv.SLOTS else -1

	if bool(_swimming.get(peer, false)):
		var asked: String = table.id_of(inv.numbers[order_first]) if order_first >= 0 else ""
		_say(peer, "It is too wet to light the %s in the water." % FlameRules.flame_word(table.entry(asked)))      # rain is the client's call: it sees caves and roofs (_flame_wet)
		return

	var order: Array = range(inv.SLOTS)

	if want >= 1 and want <= inv.SLOTS:
		order.push_front(want - 1)

	for slot in order:
		if inv.numbers[slot] == 0:
			continue

		var back: String = str(table.entry(table.id_of(inv.numbers[slot])).get("relit_item", ""))

		if back == "" or table.number_of(back) <= 0:
			continue

		var lit_row: Dictionary = table.entry(back)
		var said: String = "You light your %s again." % FlameRules.flame_word(lit_row)

		# A lantern whose candle or lamp oil burned out takes one more from the pack (buildables plan B4); with none it stays dark, and only the key of that
		# lantern says so (E at a fire looks on for a torch).
		if FlameRules.out_of_fuel(lit_row, inv.wear[slot]):
			var fuel: int = table.number_of(str(lit_row["fuel"]))
			var fuel_slot: int = _slot_holding(inv, fuel)

			if fuel_slot < 0:
				if slot == order_first:
					_say(peer, "Your lantern is out of fuel. It takes %s." % table.name_of(fuel))
					return

				continue

			inv.take_from_slot(fuel_slot, 1)
			inv.wear[slot] = 0
			said = "You put %s in your lantern and light it." % table.sentence_name(fuel)

		inv.numbers[slot] = table.number_of(back)
		_say(peer, said)
		return


# The first pack slot holding item `number`, or -1.
func _slot_holding(inv, number: int) -> int:
	if number <= 0:
		return -1

	for slot in range(inv.SLOTS):
		if inv.numbers[slot] == number and inv.counts[slot] > 0:
			return slot

	return -1


# A torch in hand burns down (Dave 6 Nov 2026: about half an hour of real time). The client says once a second that it holds a burning torch; the server
# adds the elapsed time (tenths of a second, capped, so a gap does not burn it) to the slot's wear and the torch is gone at items.json "burn_s".
func _torch_burn(peer: int, inv, slot: int) -> void:
	if slot < 0 or slot >= inv.SLOTS or inv.numbers[slot] == 0:
		return

	var entry: Dictionary = table.entry(table.id_of(inv.numbers[slot]))
	var burn_s: float = float(entry.get("burn_s", 0.0))

	if burn_s <= 0.0 or str(entry.get("doused_item", "")) == "":
		return

	var now: int = Time.get_ticks_msec()
	var last: int = int(_torch_seen.get(peer, now - 1000))
	_torch_seen[peer] = now
	inv.wear[slot] += int(round(float(clampi(now - last, 0, 2000)) / 100.0))
	_dirty = true

	if float(inv.wear[slot]) < burn_s * 10.0:
		return

	var before: Array = _snapshot(inv)
	_torch_seen.erase(peer)
	var dark: int = table.number_of(str(entry["doused_item"]))

	# A carried lantern (buildables plan B4) is not used up: its fuel is. It goes dark with its wear full, and its key loads the next candle or lamp oil.
	if entry.has("fuel") and dark > 0:
		inv.numbers[slot] = dark
		inv.wear[slot] = int(ceil(burn_s * 10.0))
		_say(peer, "Your lantern has burned its %s. Press its key with another in your pack to light it again." % table.sentence_name(table.number_of(str(entry["fuel"]))))
		_send_changes(peer, inv, before)
		return

	inv.numbers[slot] = 0
	inv.counts[slot] = 0
	inv.wear[slot] = 0
	_say(peer, "Your torch has burned down to nothing.")
	_send_changes(peer, inv, before)


func _fire_in_reach(peer: int, id: int) -> Dictionary:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not it.has("fire") or not _peer_pos.has(peer) or _peer_pos[peer].distance_to(it["pos"]) > FIRE_USE_M:
		return {}

	return it["fire"]


# --- Placed structures (data/items/structures.json): lean-to shelter now, storage chest next ---

func _load_blueprints() -> void:
	_blueprints.clear()
	_blueprint_of_kit.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BLUEPRINTS_PATH))

	if typeof(parsed) != TYPE_DICTIONARY:
		return

	for id in parsed.get("blueprints", {}):
		var row: Dictionary = parsed["blueprints"][id].duplicate()

		if bool(row.get("retired", false)):   # kept in the file for its number only
			continue

		row["id"] = id
		_blueprints[int(row["number"])] = row
		_blueprint_of_kit[str(_structures.get(str(row["structure"]), {}).get("kit", ""))] = int(row["number"])


# Whether this blueprint can go down now: a hammer of enough tier on the hotbar, the station near when it needs one, every material in the pack.
# Says why when it cannot, and takes nothing.
# Tests and admin tools: lay a piece by its old kit name with no hammer, station or materials needed (kits are gone from the game, Dave 4 Nov 2026).
# The piece still takes down into its blueprint materials like any hammer build.
var free_build: bool = false


func place_piece(peer: int, kit_id: String, at: Vector3, yaw_deg: int = 0, lift_steps: int = 0) -> void:
	if inventory_of(peer) == null:
		return

	var number: int = int(_blueprint_of_kit.get(kit_id, 0))

	if number <= 0:
		return

	free_build = true
	_place(peer, inventory_of(peer), -1, at, yaw_deg, lift_steps, _blueprints[number])
	free_build = false


# Tests: place whatever item number the test holds. A dropped kit lays its piece (and uses up the one in the pack); anything else places from its slot as a player would.
func place_item(peer: int, number: int, at: Vector3, lift_steps: int = 0, yaw_deg: int = 0) -> void:
	var inv = inventory_of(peer)

	if inv == null:
		return

	if is_dead_kit(number):
		inv.remove_fill(number, 1)
		place_piece(peer, table.id_of(number), at, yaw_deg, lift_steps)
		return

	action(peer, Net.ACT_PLACE, inv.numbers.find(number), lift_steps, yaw_deg, at)


func _can_blueprint(peer: int, inv, row: Dictionary, site_ok: bool = false) -> bool:
	if free_build:
		return not _structures.get(str(row["structure"]), {}).is_empty()

	if not bool(row.get("known", true)) or _structures.get(str(row["structure"]), {}).is_empty():
		return false

	var hammer: int = _heaviest_hammer_slot(inv)

	if hammer < 0:
		_say(peer, "You need a hammer in your hand bar to build from a blueprint.")
		return false

	if int(table.entry(table.id_of(inv.numbers[hammer])).get("tier", 1)) < int(row.get("hammer", 1)):
		_say(peer, "This hammer is too light for that. You need %s." % _hammers_for(int(row.get("hammer", 1))))
		return false

	if str(row.get("station", "")) != "" and not station_near(peer, str(row["station"]), int(row.get("station_level", 1))):
		_say(peer, "You need a %s close by." % str(row["station"]).replace("_", " "))
		return false

	if str(row.get("near", "")) != "" and not station_near(peer, str(row["near"]), int(row.get("near_level", 1))):
		_say(peer, "You need a %s close by." % str(row["near"]).replace("_", " "))
		return false

	var cost_rows: Array = []

	for need in row["cost"]:
		cost_rows.append([table.number_of(str(need[0])), int(need[1])])

	_pull_nearby_logs(peer, inv, _log_need(cost_rows, 1))   # shoulder and ground logs count (F-16)

	for need in row["cost"]:
		if inv.count_fill(table.number_of(str(need[0]))) + _ground_stock_count(peer, table.number_of(str(need[0]))) < int(need[1]):
			if site_ok:
				continue   # a blueprint site is set down anyway; the materials are deposited later (Dave 5 Nov 2026)

			_say(peer, "Not enough %s (%d needed)." % [table.in_sentence(str(table.entry(str(need[0])).get("name", need[0]))), int(need[1])])
			return false

	return true


# The heaviest working hammer on the hotbar (-1 none): a stone hammer in key 1 does not hide the iron one in key 4 that the player holds
# (the hammer panel lists rows by the hammer in hand).
func _heaviest_hammer_slot(inv) -> int:
	var best: int = -1

	for slot in range(inv.SLOTS):
		if not inv.on_hotbar(slot) or inv.numbers[slot] == 0 or _is_broken(inv.numbers[slot], inv.wear[slot]):
			continue

		var entry: Dictionary = table.entry(table.id_of(inv.numbers[slot]))

		if str(entry.get("tool_class", "")) == "hammer" and (best < 0 or int(entry.get("tier", 1)) > int(table.entry(table.id_of(inv.numbers[best])).get("tier", 1))):
			best = slot

	return best


# The hammers heavy enough for a blueprint row's "hammer" tier, as said in a sentence, lightest first ("a stone hammer or better"; tier 3 is any
# metal one: "a bronze, iron or steel hammer"). From items.json, so a new hammer is named without a code change.
func _hammers_for(tier_needed: int) -> String:
	var hammers: Array = []   # [tier, number, material] of every live hammer heavy enough

	for id in table.ids():
		var entry: Dictionary = table.entry(id)

		if str(entry.get("tool_class", "")) == "hammer" and not bool(entry.get("retired", false)) and int(entry.get("tier", 1)) >= tier_needed:
			hammers.append([int(entry.get("tier", 1)), int(entry.get("number", 0)), str(entry.get("material", id.trim_suffix("_hammer")))])

	if hammers.is_empty():
		return "a heavier hammer"

	hammers.sort()
	var lightest: int = int(hammers[0][0])
	var words: Array = []

	for row in hammers:
		if int(row[0]) == lightest:
			words.append(str(row[2]))

	var listed: String = str(words[0]) if words.size() == 1 else ", ".join(words.slice(0, words.size() - 1)) + " or " + str(words[-1])
	return "a %s hammer%s" % [listed, " or better" if int(hammers[-1][0]) > lightest else ""]


# True when the pack and the ground stock beside the builder cannot cover the blueprint's materials: the click then sets down a blueprint site.
func _blueprint_short(peer: int, inv, row: Dictionary) -> bool:
	for need in row["cost"]:
		if inv.count_fill(table.number_of(str(need[0]))) + _ground_stock_count(peer, table.number_of(str(need[0]))) < int(need[1]):
			return true

	return false


func _pay_blueprint(inv, row: Dictionary, peer: int = -1) -> void:
	for need in row["cost"]:
		var number: int = table.number_of(str(need[0]))
		var left: int = int(need[1]) - _take_ground_stock(peer, number, int(need[1]))   # heavy stock laid on the ground beside the build goes first (Dave 2 Nov)

		if left > 0:
			inv.remove_fill(number, left)


# Heavy building stock on the ground (Dave 2 Nov 2026: "we use the hammer to make blueprints on the spot"): a blueprint takes its materials from loose
# stacks lying within BUILD_STOCK_M of the builder before the pack, so stone blocks and bricks can be carried over in several trips and stacked beside
# the site. Logs keep their own rule (_pull_nearby_logs).
const BUILD_STOCK_M := 4.0


func _ground_stock(peer: int, number: int) -> Array:
	var out: Array = []

	if peer < 0 or number <= 0 or not _peer_pos.has(peer) or number == table.number_of("log"):
		return out

	var fills: PackedInt32Array = _fills(number)   # a group cost (nails: any nails) is filled by any member lying there

	for id in _items:
		var it: Dictionary = _items[id]

		if it.has("scatter") or it.has("tree") or it.has("fire") or it.has("struct") or it.has("boulder") or not fills.has(int(it.get("number", 0))):
			continue

		var d: float = _peer_pos[peer].distance_to(it["pos"])

		if d <= BUILD_STOCK_M:
			out.append([id, int(it["count"]), d])

	out.sort_custom(func(a, b): return float(a[2]) < float(b[2]))
	return out


func _ground_stock_count(peer: int, number: int) -> int:
	var total: int = 0

	for row in _ground_stock(peer, number):
		total += int(row[1])

	return total


# Takes up to `want` of `number` from the ground stock near the builder; returns how many it took.
func _take_ground_stock(peer: int, number: int, want: int) -> int:
	var took: int = 0

	for row in _ground_stock(peer, number):
		if took >= want:
			break

		var it: Dictionary = _items[int(row[0])]
		var take: int = mini(int(row[1]), want - took)

		if int(it["count"]) > take:
			it["count"] = int(it["count"]) - take
		else:
			_items.erase(int(row[0]))

		took += take

	if took > 0:
		_dirty = true

	return took


# All the materials back into the pack, or none (with a word) when they do not fit.
# A blueprint's materials back in the pack, all or nothing. `taken_down`: the piece stood, so what it burned is gone (blueprints.json "spent", [item,
# count], also counted in "cost": a lantern's candle or lamp oil; coordinator ruling 10 Nov 2026) and only the rest comes back.
func _refund_blueprint(peer: int, inv, row: Dictionary, taken_down: bool = false) -> bool:
	var given: Array = []

	for need in row["cost"]:
		var number: int = table.number_of(str(need[0]))
		var count: int = int(need[1])

		if taken_down:
			for burnt in row.get("spent", []):
				if str(burnt[0]) == str(need[0]):
					count = maxi(count - int(burnt[1]), 0)

		if count <= 0:
			continue

		number = _refund_number(number)   # a group cost gives back its lowest member (we do not record which member was used)
		var left: int = inv.add(number, count)
		given.append([number, count - left])

		if left > 0:
			for put in given:
				inv.remove(int(put[0]), int(put[1]))

			_say(peer, "Make room in your pack first.")
			return false

	return true


func _structure_of_kit(kit_id: String) -> Dictionary:
	for kind in _structures:
		if str(_structures[kind]["kit"]) == kit_id:
			var def: Dictionary = _structures[kind].duplicate()
			def["kind"] = kind
			return def

	return {}


# Does a spot lie inside the covered box of a placed shelter (its half_x by half_z from structures.json, turned by its yaw)?
func _inside_shelter(shelter: Dictionary, spot: Vector3) -> bool:
	var def: Dictionary = _structures.get(str(shelter["struct"]["kind"]), {})
	var local: Vector2 = Vector2(spot.x - shelter["pos"].x, spot.z - shelter["pos"].z).rotated(deg_to_rad(float(shelter["struct"].get("yaw", 0.0))))
	return absf(local.x) <= float(def.get("half_x", 0.0)) and absf(local.y) <= float(def.get("half_z", 0.0)) and absf(spot.y - shelter["pos"].y) < 1.5


func _place_structure(peer: int, inv, slot: int, spot: Vector3, yaw_deg: int, def: Dictionary, site_row: Dictionary = {}) -> void:
	var attaching: bool = str(def.get("attach_to", "")) == "fire"

	if attaching:
		spot = _snap_to_fire(peer, spot)

		if is_nan(spot.y):
			return

		for fid in _items:
			var fit: Dictionary = _items[fid]

			if fit.has("fire") and (fit["pos"] as Vector3).distance_to(spot) <= POT_ON_FIRE_M and float(_fire_wood(fit["fire"])["log"]) > 0.0:
				_say(peer, "The fire is too big for a pot. Let the logs burn down first.")
				return

	if _traps.is_kind(str(def["kind"])) and not _traps.allow_place(peer, spot, str(def["kind"])):
		return

	var here_chunk: Vector2i = _chunk_of(spot)
	var of_kind: int = 0

	for id in _items:
		var other: Dictionary = _items[id]

		var both_pieces: bool = bool(def.get("piece", false)) and other.has("struct") and bool(_structures.get(str(other["struct"]["kind"]), {}).get("piece", false))

		var walkover: bool = other.has("struct") and bool(_structures.get(str(other["struct"]["kind"]), {}).get("walkover", false))

		var stands_on: bool = def.has("needs_base_lift_m") and other.has("struct") and bool(_structures.get(str(other["struct"]["kind"]), {}).get("foundation", false))   # a sawmill stands on its foundation

		# A rough bed goes INSIDE a lean-to (Dave 31 Oct 2026): its middle may lie within the shelter's covered box, whatever the gap.
		var bed_in_shelter: bool = _is_bed_kind(str(def.get("kind", ""))) and other.has("struct") and bool(_structures.get(str(other["struct"]["kind"]), {}).get("shelter", false)) and _inside_shelter(other, spot)

		if bed_in_shelter:
			yaw_deg = int(round(float(other["struct"].get("yaw", 0.0))))   # the bed lies along the lean-to (1 x 2 m inside 2.6 x 2.4 m), whatever way the player faced

		if PlacementRules.one_to_a_point(str(def.get("piece_kind", ""))) and other.has("struct") and str(_structures.get(str(other["struct"]["kind"]), {}).get("piece_kind", "")) == str(def.get("piece_kind", "")) and other["pos"].distance_to(spot) < PlacementRules.ANCHOR_TAKEN_M:
			_say(peer, "Something is in the way.")   # one pillar to a point, one wall top to a wall (PlacementRules.blocked)
			return

		if other["pos"].distance_to(spot) < _struct_gap_m and (other.has("struct") or other.has("fire")) and not both_pieces and not walkover and not stands_on and not (attaching and other.has("fire")) and not bed_in_shelter and not bool(def.get("gap_exempt", false)) and not (other.has("struct") and bool(_structures.get(str(other["struct"]["kind"]), {}).get("gap_exempt", false))):   # furniture (gap_exempt) stands beside fires, shelters and each other
			_say(peer, "Something is in the way.")
			return

		if other.has("struct") and str(other["struct"]["kind"]) == str(def["kind"]) and _chunk_of(other["pos"]) == here_chunk:
			of_kind += 1

	if of_kind >= int(def["cap_per_chunk"]):
		_say(peer, "Too many of these stand here already.")
		return

	var water_why: String = _water_refusal(def, spot, yaw_deg)

	if water_why != "":
		_say(peer, water_why)
		return

	if slot < 0 and free_build:
		pass   # a test or admin piece: nothing is taken
	elif slot < 0 and not site_row.is_empty():
		pass   # a blueprint site: nothing is taken now, the materials are deposited with E (_deposit_site)
	elif slot < 0:
		_pay_blueprint(inv, _blueprints[int(_blueprint_of_kit[str(def["kit"])])], peer)
	else:
		inv.take_from_slot(slot, 1)

	var entry: Dictionary = {"number": table.number_of(str(def["item"])), "count": 1, "pos": spot, "left": 1.0e9, "struct": {"kind": str(def["kind"]), "yaw": float(posmod(yaw_deg, 360))}}

	if int(def.get("slots", 0)) > 0:
		entry["struct"]["uid"] = _next_uid
		entry["struct"]["owner"] = str(_peer_key.get(peer, ""))   # crafting draws only on the owner's containers (CraftStock.owner_ok)
		_chests[_next_uid] = InventoryScript.new(table)
		_next_uid += 1

	if not site_row.is_empty():
		entry["struct"]["site"] = {"bp": int(site_row["number"]), "have": {}}
		_say(peer, "Blueprint down. Press E on it to deposit the materials.")

	_items[_next_id] = entry
	_grid_add(_next_id, entry)
	_next_id += 1
	_add_roof(entry)

	if _traps.is_kind(str(def["kind"])):
		_traps.on_placed(peer, _next_id - 1)

	if attaching:
		_refresh_pots()   # the fire under it takes the firewood cap now

	if not BuildingWear.rule_for(_wear_cfg, str(def["kind"])).is_empty():
		entry["struct"]["born"] = _now_game_s()   # last cared for: placed now

	if not site_row.is_empty():
		_dirty = true
		return   # a site counts as built, holds nothing up and shelters nobody until _finish_site

	_after_built(peer, entry, def)
	_water_add(_next_id - 1)
	_dirty = true


# What a piece does once it stands: a support holds the ground, a lean-to is a place to rest, the goal list hears of it.
func _after_built(peer: int, entry: Dictionary, def: Dictionary) -> void:
	var spot: Vector3 = entry["pos"]

	if str(def.get("use", "")) == "light" and _blueprint_of_kit.has(str(def.get("kit", ""))):   # a lantern built with its candle or oil ("spent") stands lit on it
		for burnt in _blueprints[int(_blueprint_of_kit[str(def["kit"])])].get("spent", []):
			if str(burnt[0]) == str(def.get("fuel", "")) and int(burnt[1]) > 0:
				entry["struct"]["lit"] = true
				entry["struct"]["fuel_left"] = light_burn_s(def) * float(int(burnt[1]))

	if def.has("support"):
		entry["struct"]["born"] = _now_game_s()
		_rebuild_supports()

		if support_changed.is_valid():
			support_changed.call(spot)

	if bool(def.get("shelter", false)):
		_record_rest(str(_peer_key.get(peer, "")), spot, "shelter")   # a lean-to you built is a place to come back to

	_goal_event(peer, "placed", str(def.get("kind", "")))


# A campfire pot goes onto the nearest small fire (laid, lit or burnt out; never a bonfire) within POT_ATTACH_M of where it was put and
# takes that fire's spot. Returns the fire's spot, or a NAN y after telling the player why it cannot go there.
func _snap_to_fire(peer: int, spot: Vector3) -> Vector3:
	var best: int = -1
	var best_d: float = POT_ATTACH_M

	for id in _items:
		if _items[id].has("fire") and (_items[id]["pos"] as Vector3).distance_to(spot) <= best_d:
			best = id
			best_d = (_items[id]["pos"] as Vector3).distance_to(spot)

	if best < 0:
		_say(peer, "The campfire pot hangs over a small fire. Lay a fire first.")
		return Vector3(spot.x, NAN, spot.z)

	var at: Vector3 = _items[best]["pos"]

	if int(_items[best]["fire"]["state"]) == FIRE_STATE_BONFIRE:
		_say(peer, "That fire is too big for a pot. Let it burn down first.")
		return Vector3(spot.x, NAN, spot.z)

	for id in _items:
		if _is_pot(_items[id]) and (_items[id]["pos"] as Vector3).distance_to(at) <= POT_ON_FIRE_M:
			_say(peer, "That fire already has a pot.")
			return Vector3(spot.x, NAN, spot.z)

	return at


# The structure's roof joins the cover index (both ends do the same on seeing the structure).
# --- Building wear and repair (DESIGN_IDEAS.md Section 8.13; Dave 4 Nov 2026) ---
const BuildingWear := preload("res://src/shared/building_wear.gd")
var _wear_cfg: Dictionary = BuildingWear.load_config()


# The condition (0 to 1) of a placed piece now; 1.0 for a kind that does not wear. A piece placed before wear existed starts its clock now.
func piece_condition(id: int) -> float:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not it.has("struct"):
		return 1.0

	var rule: Dictionary = BuildingWear.rule_for(_wear_cfg, str(it["struct"]["kind"]))

	if rule.is_empty():
		return 1.0

	if not it["struct"].has("born"):
		it["struct"]["born"] = _now_game_s()

	return BuildingWear.condition(rule, float(it["struct"]["born"]), _now_game_s())


# Hammer, Repair mode, left click on a worn piece: spends repair_share of the piece's blueprint materials times what it lost, from loose items near the
# piece, then containers within reach, then the pack (all or nothing), and sets the piece back to full condition.
func _repair_struct(peer: int, inv, id: int) -> void:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not it.has("struct") or not _peer_pos.has(peer):
		return

	if _peer_pos[peer].distance_to(it["pos"]) > Interact.server_reach_m():
		_say(peer, "Too far to repair that.")
		return

	if _tool_slot(inv, "hammer") < 0:
		_say(peer, "You need a hammer in your hand bar to repair.")
		return

	if it["struct"].has("site"):
		_gather_site(peer, inv, id)   # a blue blueprint: the hammer fills it from all around
		return

	var kind: String = str(it["struct"]["kind"])
	var def: Dictionary = _structures.get(kind, {})
	var piece_name: String = kind.replace("_", " ")
	var blueprint: Dictionary = _blueprints.get(int(_blueprint_of_kit.get(str(def.get("kit", "")), 0)), {})

	if BuildingWear.rule_for(_wear_cfg, kind).is_empty() or blueprint.is_empty():
		_say(peer, "The %s does not wear, so it needs no repair." % piece_name)
		return

	var cond: float = piece_condition(id)

	if cond >= float(_wear_cfg.get("good_condition", 0.98)):
		_say(peer, "The %s is in good repair (%d percent)." % [piece_name, int(round(cond * 100.0))])
		return

	var needs: Array = BuildingWear.repair_needs(blueprint["cost"], cond, float(_wear_cfg.get("repair_share", 0.5)))
	var log_need: int = 0

	for need in needs:
		if str(need[0]) == "log":
			log_need = int(need[1])

	if log_need > 0:
		_pull_nearby_logs(peer, inv, maxi(0, log_need - inv.count_fill(table.number_of("log"))))   # shoulder and ground logs count, as for building

	var ground_m: float = float(_wear_cfg.get("ground_m", 6.0))
	var boxes: Array = _boxes_near(peer)
	var short: PackedStringArray = []

	for need in needs:
		var number: int = table.number_of(str(need[0]))
		var have: int = inv.count_fill(number) + _ground_count(number, it["pos"], ground_m)

		for box in boxes:
			have += box[1].count_fill(number)

		if have < int(need[1]):
			short.append("%d %s" % [int(need[1]), table.in_sentence(str(table.entry(str(need[0])).get("name", need[0])))])

	if not short.is_empty():
		_say(peer, "Repairing the %s (%d percent) needs %s." % [piece_name, int(round(cond * 100.0)), ", ".join(short)])
		return

	for need in needs:
		var number: int = table.number_of(str(need[0]))
		var left: int = int(need[1])
		left -= _ground_take(number, left, it["pos"], ground_m)

		for box in boxes:
			if left <= 0:
				break

			var from_box: int = mini(left, box[1].count_fill(number))

			if from_box > 0 and box[1].remove_fill(number, from_box):
				left -= from_box
				_push_box(int(box[0]), box[1])

		if left > 0:
			inv.remove_fill(number, left)

	it["struct"]["born"] = _now_game_s()
	_dirty = true
	_say(peer, "Repaired the %s (was %d percent)." % [piece_name, int(round(cond * 100.0))])


# Loose items (not structures, fires or trees) of one kind, or of any member of its group, within `radius` of a spot.
func _ground_count(number: int, at: Vector3, radius: float) -> int:
	var total: int = 0
	var fills: PackedInt32Array = _fills(number)

	for gid in _items:
		var g: Dictionary = _items[gid]

		if fills.has(int(g.get("number", 0))) and not g.has("struct") and not g.has("fire") and not g.has("tree") and (g["pos"] as Vector3).distance_to(at) <= radius:
			total += int(g["count"])

	return total


func _ground_take(number: int, want: int, at: Vector3, radius: float) -> int:
	var taken: int = 0
	var fills: PackedInt32Array = _fills(number)

	for gid in _items.keys():
		if taken >= want:
			break

		var g: Dictionary = _items[gid]

		if not fills.has(int(g.get("number", 0))) or g.has("struct") or g.has("fire") or g.has("tree") or (g["pos"] as Vector3).distance_to(at) > radius:
			continue

		var take: int = mini(int(g["count"]), want - taken)

		if take >= int(g["count"]):
			_items.erase(gid)
		else:
			g["count"] = int(g["count"]) - take

		taken += take

	return taken


# The item numbers that fill an ingredient or a blueprint cost: its group's members (item_table.gd load_groups: "log", "nails", "hinges"), or the number alone.
# Inventory.fills_of is the same rule for a pack or a chest.
func _fills(number: int) -> PackedInt32Array:
	var members: PackedInt32Array = table.group_members(number)
	return members if not members.is_empty() else PackedInt32Array([number])


# What a group cost gives back when a piece or a site is taken down (coordinator 10 Nov 2026): the group's lowest member, since which member was
# paid in is not recorded. A wall built with Bronze nails must not give back iron Nails, the scarce kind. Lowest means the lowest items.json "tier",
# then the lowest material on REFUND_MATERIALS, then the lowest "value"; a member with none of these ranks last on that field, and a full tie keeps
# the group's own order (its own id first: plain logs for any log).
const REFUND_MATERIALS := ["wood", "bone", "stone", "flint", "obsidian", "copper", "tin", "bronze", "iron", "steel"]


func _refund_number(number: int) -> int:
	var best: int = number
	var best_key: Array = []

	for member in table.group_members(number):
		var entry: Dictionary = table.entry(table.id_of(member))
		var material_rank: int = REFUND_MATERIALS.find(str(entry.get("material", "")))
		var key: Array = [int(entry.get("tier", 99)), material_rank if material_rank >= 0 else 99, float(entry.get("value", 1.0e9))]

		if best_key.is_empty() or _rank_below(key, best_key):
			best = member
			best_key = key

	return best


static func _rank_below(a: Array, b: Array) -> bool:
	for k in a.size():
		if a[k] != b[k]:
			return a[k] < b[k]

	return false


# [[item id, inventory], ...] of containers (chests) within reach of the player.
func _boxes_near(peer: int) -> Array:
	var out: Array = []

	for sid in _items:
		var s: Dictionary = _items[sid]

		if not s.has("struct") or not s["struct"].has("uid") or not _chests.has(int(s["struct"]["uid"])) or int(_structures.get(str(s["struct"]["kind"]), {}).get("slots", 0)) <= 0:
			continue

		if (s["pos"] as Vector3).distance_to(_peer_pos[peer]) <= Interact.server_reach_m() + 2.0:
			out.append([sid, _chests[int(s["struct"]["uid"])]])

	return out


# --- Blueprint sites (Dave 5 Nov 2026) ---
# A hammer click without the materials sets down a site instead: the real piece, drawn blue and see-through, that can be walked through. E on it deposits
# what the builder has (pack, loose stock beside them and their own containers within CraftStock.CRAFT_REACH_M, the crafting rule: _craft_boxes);
# when every material is in, it becomes the real piece. The site is the piece's own entry with struct["site"] = {"bp": blueprint number,
# "have": {item id: count}}; taking a site down gives back what was put in.


func _site_of(it: Dictionary) -> Dictionary:
	if it.has("struct") and it["struct"].has("site"):
		return it["struct"]["site"]

	return {}


# [[item id, still needed, total needed], ...] for a site's blueprint.
func _site_needs(site: Dictionary) -> Array:
	var out: Array = []
	var have: Dictionary = site.get("have", {})

	for need in _blueprints.get(int(site.get("bp", 0)), {}).get("cost", []):
		out.append([str(need[0]), maxi(int(need[1]) - int(have.get(str(need[0]), 0)), 0), int(need[1])])

	return out


# What a site's list shows one player: [[item id, still needed, on hand], ...], "on hand" being the pack, loose stock beside them and containers within reach.
func _site_view(peer: int, it: Dictionary) -> Array:
	var out: Array = []
	var inv = inventory_of(peer)

	if inv == null or not _peer_pos.has(peer):
		return out

	var boxes: Array = _craft_boxes(peer)

	for need in _site_needs(_site_of(it)):
		var number: int = table.number_of(str(need[0]))
		var on_hand: int = inv.count_fill(number) + _ground_count(number, _peer_pos[peer], BUILD_STOCK_M)

		for box in boxes:
			on_hand += box[1].count_fill(number)

		out.append([str(need[0]), int(need[1]), on_hand])

	return out


# E on a site: moves what the builder has of each missing material into it, then finishes it when nothing is missing.
func _deposit_site(peer: int, inv, id: int) -> void:
	var it: Dictionary = _items.get(id, {})
	var site: Dictionary = _site_of(it)

	if site.is_empty() or not _peer_pos.has(peer):
		return

	if _peer_pos[peer].distance_to(it["pos"]) > Interact.server_reach_m():
		_say(peer, "Too far to deposit materials there.")
		return

	var boxes: Array = _craft_boxes(peer)
	var have: Dictionary = site["have"]
	var moved: int = 0

	for need in _site_needs(site):
		var left: int = int(need[1])

		if left <= 0:
			continue

		var number: int = table.number_of(str(need[0]))
		var put: int = 0
		var from_pack: int = mini(left, inv.count_fill(number))

		if from_pack > 0 and inv.remove_fill(number, from_pack):
			put += from_pack

		if put < left:
			put += _ground_take(number, left - put, _peer_pos[peer], BUILD_STOCK_M)

		for box in boxes:
			if put >= left:
				break

			var from_box: int = mini(left - put, box[1].count_fill(number))

			if from_box > 0 and box[1].remove_fill(number, from_box):
				put += from_box
				_push_box(int(box[0]), box[1])

		if put > 0:
			have[str(need[0])] = int(have.get(str(need[0]), 0)) + put
			moved += put

	var missing: PackedStringArray = []

	for need in _site_needs(site):
		if int(need[1]) > 0:
			missing.append("%d %s" % [int(need[1]), table.in_sentence(str(table.entry(str(need[0])).get("name", need[0])))])

	if moved == 0:
		_say(peer, "You have none of what it needs: %s." % ", ".join(missing))
		return

	_dirty = true

	if missing.is_empty():
		_finish_site(peer, id)
		_say(peer, "Built.")
	else:
		_say(peer, "Deposited. Still needed: %s." % ", ".join(missing))


# The hammer in Repair mode on a blueprint site (Dave 10 Nov 2026: "search the area around me for 12 meters. on the ground, in my inventory, in any containers
# near me ... anything for materials that this blue print needs and pull those items and put them in the blueprint"; craft from containers, built in and
# always on). Takes only what the site still needs: the pack first (any member of a group, a `log` need takes any log), then loose items on the ground and
# the builder's own containers (CraftStock.owner_ok, not keep out) within building_wear.json site_gather_m of the builder, nearest first. One line says
# what came and what is still missing; with nothing missing the piece is built.
func _gather_site(peer: int, inv, id: int) -> void:
	var it: Dictionary = _items[id]
	var site: Dictionary = _site_of(it)
	var here: Vector3 = _peer_pos[peer]
	var reach: float = float(_wear_cfg.get("site_gather_m", CraftStock.CRAFT_REACH_M))
	var key: String = str(_peer_key.get(peer, ""))
	var sources: Array = []   # [distance, world id, is a container], nearest first

	for sid in _items:
		var s: Dictionary = _items[sid]
		var d: float = (s["pos"] as Vector3).distance_to(here)

		if d > reach:
			continue

		if _is_loose(s) or (s.has("scatter") and int(s.get("number", 0)) > 0):   # natural sticks and stones on the ground too
			sources.append([d, sid, false])
		elif _is_storage(s) and CraftStock.owner_ok(str(s["struct"].get("owner", "")), key) and not bool(s["struct"].get("keep_out", false)):
			sources.append([d, sid, true])

	sources.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var have: Dictionary = site["have"]
	var pulled: PackedStringArray = []

	for need in _site_needs(site):
		var left: int = int(need[1])

		if left <= 0:
			continue

		var number: int = table.number_of(str(need[0]))
		var fills: PackedInt32Array = inv.fills_of(number)
		var put: int = mini(left, inv.count_fill(number))

		if put > 0 and not inv.remove_fill(number, put):
			put = 0

		for src in sources:
			if put >= left:
				break

			if bool(src[2]):
				var box = _chests[int(_items[src[1]]["struct"]["uid"])]
				var from_box: int = mini(left - put, box.count_fill(number))

				if from_box > 0 and box.remove_fill(number, from_box):
					put += from_box
					_push_box(int(src[1]), box)
			elif _items.has(src[1]) and fills.has(int(_items[src[1]]["number"])):
				var g: Dictionary = _items[src[1]]
				var from_ground: int = mini(left - put, int(g["count"]))
				put += from_ground

				if from_ground >= int(g["count"]):
					if g.has("scatter"):
						_taken[g["scatter"]] = true

					_items.erase(src[1])
				else:
					g["count"] = int(g["count"]) - from_ground

		if put > 0:
			have[str(need[0])] = int(have.get(str(need[0]), 0)) + put
			pulled.append("%d %s" % [put, _item_name_lower(str(need[0]))])

	var missing: PackedStringArray = []

	for need in _site_needs(site):
		if int(need[1]) > 0:
			missing.append("%d %s" % [int(need[1]), _item_name_lower(str(need[0]))])

	if pulled.is_empty():
		_say(peer, "Nothing within %d m that it needs. Still needed: %s." % [int(round(reach)), ", ".join(missing)])
		return

	_dirty = true

	if missing.is_empty():
		_finish_site(peer, id)
		_say(peer, "Pulled %s. Built." % ", ".join(pulled))
	else:
		_say(peer, "Pulled %s. Still needed: %s." % [", ".join(pulled), ", ".join(missing)])


func _item_name_lower(item_id: String) -> String:
	return table.in_sentence(str(table.entry(item_id).get("name", item_id)))


# Every material is in: the site becomes the real piece.
func _finish_site(peer: int, id: int) -> void:
	var it: Dictionary = _items[id]
	it["struct"].erase("site")
	var def: Dictionary = _structures.get(str(it["struct"]["kind"]), {})
	_grid_add(id, it)
	_add_roof(it)
	_after_built(peer, it, def)
	_water_add(id)
	_dirty = true


# Taking a site down gives back everything deposited (100 percent, like any blueprint).
func _take_down_site(peer: int, _inv, id: int) -> void:
	var it: Dictionary = _items[id]

	for item_id in _site_of(it).get("have", {}):
		var count: int = int(_site_of(it)["have"][item_id])

		if count > 0:
			give(peer, _refund_number(table.number_of(str(item_id))), count)

	_items.erase(id)
	_dirty = true


# --- Solid footprints (Dave 3 Nov 2026): the server knows where walls and heavy stations stand, so animals can be stopped by them ---
const StructureGridScript := preload("res://src/stream/structure_grid.gd")
var _grid = StructureGridScript.new()


# Registers a freshly placed or loaded structure when its structures.json row says "blocks_walk".
func _grid_add(id: int, entry: Dictionary) -> void:
	if entry["struct"].has("site"):
		return   # a blueprint site is walked through and blocks nothing until it is finished (_finish_site)

	var kind: String = str(entry["struct"]["kind"])
	var def: Dictionary = _structures.get(kind, {})

	if bool(def.get("blocks_walk", false)):
		_grid.add(id, kind, entry["pos"].x, entry["pos"].z, float(entry["struct"]["yaw"]), float(def.get("footprint_x", 1.0)), float(def.get("footprint_z", 1.0)))


# True when a wall or a heavy station stands over (x, z); margin grows each piece by an animal's body radius.
func structure_blocks(x: float, z: float, margin: float = 0.0) -> bool:
	return _grid.blocks(x, z, margin, _items)


# True when the straight step from (x0, z0) to (x1, z1) goes through such a piece: a long stride cannot jump a thin wall.
func structure_blocks_step(x0: float, z0: float, x1: float, z1: float, margin: float = 0.0) -> bool:
	return _grid.segment_blocked(x0, z0, x1, z1, margin, _items)


func _add_roof(entry: Dictionary) -> void:
	if entry["struct"].has("site"):
		return

	var def: Dictionary = _structures.get(str(entry["struct"]["kind"]), {})
	var box: Array = CoverScript.structure_roof(def, entry["pos"], deg_to_rad(float(entry["struct"]["yaw"])))

	if box.is_empty() or not roof_add.is_valid() or entry["struct"].has("roof"):
		return

	entry["struct"]["roof"] = int(roof_add.call(box))


# After loading a save and wiring roof_add: put every saved structure's roof in the cover index.
func register_roofs() -> void:
	for id in _items:
		if _items[id].has("struct"):
			_add_roof(_items[id])


# True when another placed piece stands on this foundation (on its top, inside its footprint).
func _stands_on(base: Dictionary, def: Dictionary) -> bool:
	var half_x: float = float(def.get("footprint_x", 4.0)) * 0.5 + 0.1
	var half_z: float = float(def.get("footprint_z", 4.0)) * 0.5 + 0.1

	for other in _items.values():
		if other == base or not other.has("struct") or not bool(_structures.get(str(other["struct"]["kind"]), {}).get("piece", false)):
			continue

		var d: Vector3 = other["pos"] - base["pos"]

		if d.y > 0.1 and absf(d.x) <= half_x and absf(d.z) <= half_z:
			return true

	return false


# Taking a structure down (E near it) gives its kit back. A chest with things in it cannot be taken down.
func _take_down(peer: int, inv, id: int) -> void:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not _peer_pos.has(peer) or _peer_pos[peer].distance_to(it["pos"]) > Interact.server_reach_m():
		return

	if it["struct"].has("site"):
		_take_down_site(peer, inv, id)
		return

	var def: Dictionary = _structures.get(str(it["struct"]["kind"]), {})

	if def.is_empty() or str(def.get("kit", "")) == "":
		return

	if not _struct_empty(id):
		_say(peer, "Empty it first.")
		return

	if bool(def.get("foundation", false)) and _stands_on(it, def):
		_say(peer, "Take down what stands on it first.")
		return

	if _blueprint_of_kit.has(str(def["kit"])):   # a blueprint piece gives its materials back, all of them
		if not _refund_blueprint(peer, inv, _blueprints[int(_blueprint_of_kit[str(def["kit"])])], true):
			return
	elif inv.add(table.number_of(str(def["kit"]) if bool(it["struct"].get("lit", false)) or not def.has("kit_out") else str(def["kit_out"])), 1, int(it.get("wear", 0))) > 0:
		return      # a placed torch comes back burning, or doused when it burned out or the rain put it out

	if it["struct"].has("roof") and roof_remove.is_valid():
		roof_remove.call(int(it["struct"]["roof"]))

	_chests.erase(int(it["struct"].get("uid", 0)))
	_items.erase(id)
	_dirty = true

	if str(def.get("attach_to", "")) == "fire":
		_refresh_pots()   # the fire keeps burning and gets its tiers back

	if def.has("support"):
		_rebuild_supports()

		if support_changed.is_valid():
			support_changed.call(it["pos"])


# E at a chopping block: one log becomes firewood; the axe wears one use. The server checks the reach,
# a log in the pack, a usable axe on the hotbar and the pace.
func _use_struct(peer: int, inv, id: int) -> void:
	var it: Dictionary = _items.get(id, {})

	if it.has("fire"):
		_put_out_fire(peer, id)
		return

	if it.is_empty() or not it.has("struct") or not _peer_pos.has(peer):
		return

	if it["struct"].has("site"):
		_deposit_site(peer, inv, id)
		return

	var def: Dictionary = _structures.get(str(it["struct"]["kind"]), {})

	if _peer_pos[peer].distance_to(it["pos"]) > float(def.get("use_reach_m", 3.0)):
		return

	if _water_kind.has(id) and _is_pumpable(_water.pieces[id]):   # a well or pump: E starts working it, E again stops
		_toggle_pump(peer, id)
		return

	if str(def.get("use", "")) == "door":
		# A door opens and shuts: the structure turns into its other kind (structures.json "toggle"), the row's state follows.
		var now_ms: int = Time.get_ticks_msec()

		if now_ms - int(_last_use.get(peer, -100000)) >= int(def.get("use_pace_ms", 400)) and _structures.has(str(def.get("toggle", ""))):
			_last_use[peer] = now_ms
			it["struct"]["kind"] = str(def["toggle"])
			_grid_add(id, it)   # a shut door or gate ("blocks_walk") stops animals again; the open one is forgotten by the grid itself (its kind changed)
			_dirty = true

		return

	if str(def.get("use", "")) == "light":   # a torch, chandelier or fireplace: E with its fuel in the pack lights it (comfort counts only lit lights)
		_light_fixture(peer, inv, it, def)
		return

	if str(def.get("use", "")) == "set_spawn":   # E on a bed: it becomes this character's spawn point (set_spawn_bed)
		set_spawn_bed(peer, id)
		return

	if str(def.get("use", "")) == "unpile":
		# A rock pile gives back all the stones it was made of (what does not fit in the pack lies on the ground).
		give(peer, table.number_of("stone"), int(def.get("stones", 45)))
		_items.erase(id)
		_dirty = true
		return

	if str(def.get("use", "")) != "split_log":
		return

	var now: int = Time.get_ticks_msec()

	if float(now - int(_last_use.get(peer, -100000))) < float(def.get("use_pace_ms", 600)) / _pace_factor(peer, "split_log"):
		return

	# Dave 2026-10-23: the chopping block splits WOODEN BLOCKS (a log chopped on the ground gives them). Dave 4 Nov 2026 (BUG-014): a large block
	# (from a big trunk) splits into firewood_per_large_block (4), a small one into firewood_per_block. Large first, hardwood before softwood.
	var block_n: int = 0

	for kind in ["wooden_block_large", "wooden_block_soft_large", "wooden_block", "wooden_block_soft"]:
		if block_n == 0 and inv.has(table.number_of(kind), 1):
			block_n = table.number_of(kind)

	if block_n == 0:
		block_n = table.number_of("wooden_block")

	if not _has_tool(inv, "axe"):
		_say(peer, "You need an axe to split wood.")
		return

	if not inv.has(block_n, 1):
		_say(peer, "You need a wooden block to split. Chop a log on the ground with your axe first.")
		return

	_last_use[peer] = now
	inv.remove(block_n, 1)
	var large: bool = block_n == table.number_of("wooden_block_large") or block_n == table.number_of("wooden_block_soft_large")
	var soft: bool = block_n == table.number_of("wooden_block_soft") or block_n == table.number_of("wooden_block_soft_large")
	_drop_firewood_beside(it, int(def.get("firewood_per_large_block", 4)) if large else int(def.get("firewood_per_block", 1)), "firewood_soft" if soft else "firewood")
	_wear_tool(peer, inv, "axe", "split")
	practice(peer, "split_log")
	_dirty = true


# The item of a wood chain step ("firewood" or "block") for a tree species: its class (hardwood or softwood, unknown species use the default entry) decides.
func _wood_item(step: String, species: String) -> String:
	var info: Dictionary = _wood_species.get("species", {}).get(species, _wood_species.get("default", {}))
	var items: Dictionary = _wood_species.get("class_items", {}).get(str(info.get("class", "hardwood")), {})
	return str(items.get(step, "firewood" if step == "firewood" else "wooden_block"))


# Split firewood falls beside the chopping block and joins the heap lying there (drop_in_world merges it, PILE_CAP and the pile lifetime included);
# six or more make a pile the client draws from the count (bug 3: before, this had its own merge capped at the 40 stack with the 20-minute loose lifetime).
func _drop_firewood_beside(block: Dictionary, count: int, wood_id: String = "firewood") -> void:
	drop_in_world(table.number_of(wood_id), count, block["pos"] + Vector3(0.9, 0.0, 0.0))


# A log lying on the ground, struck with an axe, falls apart into wooden blocks: 3 per log (Dave 4 Nov 2026, BUG-014), small blocks from a short log,
# large blocks from a large shoulder log.
func _chop_loose_log(peer: int, inv, id: int) -> void:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or it.has("struct") or it.has("tree") or it.has("fire") or it.has("scatter") or not _peer_pos.has(peer) or not _has_tool(inv, "axe"):
		return

	var item_id: String = table.id_of(int(it["number"]))
	var big: bool = is_shoulder_item(int(it["number"]))

	if item_id != "log" and not big:
		return

	if _peer_pos[peer].distance_to(it["pos"]) > PROCESS_REACH_M + 1.0:
		return

	var now: int = Time.get_ticks_msec()

	if float(now - int(_last_process.get(peer, -100000))) < float(PROCESS_COOLDOWN_MS):
		return

	_last_process[peer] = now
	var cfg: Dictionary = _structures.get("chopping_block", {})
	var blocks: int = int(cfg.get("blocks_per_shoulder_log", 3)) if big else int(cfg.get("blocks_per_log", 3))

	if int(it["count"]) > 1:
		it["count"] = int(it["count"]) - 1
	else:
		_items.erase(id)

	_wear_tool(peer, inv, "axe", "split")
	drop_in_world(table.number_of(_wood_item("block_large" if big else "block", str(table.entry(item_id).get("species", "")))), blocks, it["pos"] + Vector3(0.0, 0.1, 0.0))
	practice(peer, "split_log")
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

# A campfire's own little store (Dave 2026-10-22, F beside a fire): a few slots for wood that feeds it and food that cooks on it.
# Made the first time anyone opens it. _tend_fire does the feeding and cooking.
func _fire_box(peer: int, it: Dictionary):
	if _peer_pos[peer].distance_to(it["pos"]) > CHEST_REACH_M:
		return null

	var fire: Dictionary = it["fire"]
	var box = _fire_store(fire)

	if not bool(fire.get("synced", false)):
		_fire_unload_to_store(fire, box)   # a fire from before the store held its wood: its wood becomes pieces in the store, the first time it is opened

	return box


# The fire's own store, made on first use (no reach check: the placing code seeds it too). It stacks every item to the u16 count (Dave 2 Nov 2026).
func _fire_store(fire: Dictionary):
	if not _chests.has(int(fire.get("uid", 0))):
		fire["uid"] = _next_uid
		_next_uid += 1
		_chests[int(fire["uid"])] = InventoryScript.new(table)
		_dirty = true

	var box = _chests[int(fire["uid"])]
	box.usable = clampi(int(_cooking.get("fire_slots", 4)), 1, box.SLOTS)
	box.stack_all = true
	return box


# The store is what the fire burns (Dave 2 Nov 2026): burn time and tier come from the wood in it, and wood burns out of it. A fire that still carries wood
# of its own (an older save, `synced` false) has that wood turned into plain pieces of its class in the store: stick, firewood or log.
func _fire_unload_to_store(fire: Dictionary, box) -> void:
	var wood: Dictionary = _fire_wood(fire)

	for cls in ["log", "firewood", "weak"]:
		var item_id: String = {"log": "log", "firewood": "firewood", "weak": "stick"}[cls]
		var each: float = float((_cooking.get("fuel", {}) as Dictionary).get(item_id, 900.0)) / GAME_RATE

		if float(wood[cls]) > 0.0 and each > 0.0:
			box.add(table.number_of(item_id), maxi(1, int(ceil(float(wood[cls]) / each - 0.0001))))

	fire["synced"] = true
	_fire_apply_store(fire, box)
	_dirty = true


# The seconds and pieces of wood by class that a store holds (a log is left out under a pot), the stored-fuel cap applied, written onto the fire.
func _fire_apply_store(fire: Dictionary, box) -> void:
	var fuel: Dictionary = _cooking.get("fuel", {})
	var seconds: Dictionary = {"log": 0.0, "firewood": 0.0, "weak": 0.0}
	var pieces: Dictionary = {"log": 0, "firewood": 0, "weak": 0}
	var damp: int = 0

	for slot in range(box.usable):
		var number: int = box.numbers[slot]

		if number == 0:
			continue

		var wood_id: String = table.id_of(number)

		if not fuel.has(wood_id):
			continue

		var cls: String = _fire_wood_class(wood_id)

		if cls == "log" and bool(fire.get("pot", false)):
			continue

		seconds[cls] = float(seconds[cls]) + float(box.counts[slot]) * float(fuel[wood_id]) / GAME_RATE
		pieces[cls] = int(pieces[cls]) + int(box.counts[slot])
		damp = maxi(damp, int(box.wear[slot]) if table.wood_class(number) != "" else 0)

	var wood: Dictionary = _fire_wood(fire)
	var laid: Dictionary = {}

	var burnt: Dictionary = fire.get("burnt", {})
	fire["counted"] = pieces.duplicate()   # the pieces this count knows; only these may burn out of the store (_fire_trim_store), never wood put in after it

	for cls in ["log", "firewood", "weak"]:
		# The piece that is half burned counts only what is left of it, so counting the store again never gives burned wood back.
		if float(seconds[cls]) <= 0.0:
			burnt.erase(cls)
		else:
			burnt[cls] = minf(float(burnt.get(cls, 0.0)), float(seconds[cls]))
			seconds[cls] = float(seconds[cls]) - float(burnt[cls])

		wood[cls] = maxf(float(seconds[cls]), 0.0)   # every piece in the store counts, however much (Dave 2 Nov 2026)

		if int(pieces[cls]) > 0:
			laid[cls] = int(pieces[cls])

	fire["pieces"] = laid
	fire["burnt"] = burnt
	fire["damp"] = damp   # the wettest wood in the store (fire design 5)
	_fire_sum(fire)


# Wood that has burned leaves the store: of each class, one whole piece goes for each piece's worth of burn time since the store was counted
# (fire["burnt"], added up by _fire_burn). Only burned wood goes: wood just put in while the store is open stays until the store is closed and counted
# (Dave 2 Nov 2026: a third log put in vanished, because the old trim compared the store with the fire's burn time before the close had counted it).
func _fire_trim_store(fire: Dictionary, box) -> bool:
	var fuel: Dictionary = _cooking.get("fuel", {})
	var burnt: Dictionary = fire.get("burnt", {})
	var removed: bool = false

	if not fire.has("counted"):   # a fire loaded from a save: what is in its store now is what was counted
		fire["counted"] = _fire_store_pieces(fire, box)

	var counted: Dictionary = fire["counted"]

	for cls in burnt.keys():
		for slot in range(box.usable):
			var number: int = box.numbers[slot]

			if number == 0 or not fuel.has(table.id_of(number)) or _fire_wood_class(table.id_of(number)) != cls or (cls == "log" and bool(fire.get("pot", false))):
				continue

			var each: float = float(fuel[table.id_of(number)]) / GAME_RATE

			while box.numbers[slot] == number and box.counts[slot] > 0 and int(counted.get(cls, 0)) > 0 and float(burnt[cls]) >= each - 0.01:
				box.take_from_slot(slot, 1)
				burnt[cls] = float(burnt[cls]) - each
				counted[cls] = int(counted[cls]) - 1
				removed = true
				print("fire store: one %s burned away (%s burned %.0f s, %d counted left)" % [table.id_of(number), cls, float(burnt[cls]) + each, int(counted[cls])])

		# Dave 2 Nov 2026 (the third log still vanished): burn time with no counted piece left to take (a fire whose burn time ran ahead of its store)
		# is not a debt on wood put in later. It goes, so a new piece stays until the next count.
		if int(counted.get(cls, 0)) <= 0:
			burnt[cls] = 0.0

	return removed


# Pieces of each wood class in a fire's store (logs left out while a pot hangs over it).
func _fire_store_pieces(fire: Dictionary, box) -> Dictionary:
	var fuel: Dictionary = _cooking.get("fuel", {})
	var pieces: Dictionary = {"log": 0, "firewood": 0, "weak": 0}

	for slot in range(box.usable):
		var number: int = box.numbers[slot]

		if number == 0 or not fuel.has(table.id_of(number)):
			continue

		var cls: String = _fire_wood_class(table.id_of(number))

		if cls == "log" and bool(fire.get("pot", false)):
			continue

		pieces[cls] = int(pieces[cls]) + int(box.counts[slot])

	return pieces


# A burnt-out fire's store keeps no wood: the trim leaves the last piece until the fire is out, and it must not come back as fresh burn time. Food stays.
func _fire_clear_wood(box) -> bool:
	var fuel: Dictionary = _cooking.get("fuel", {})
	var removed: bool = false

	for slot in range(box.usable):
		if box.numbers[slot] != 0 and fuel.has(table.id_of(box.numbers[slot])):
			box.take_from_slot(slot, box.counts[slot])
			removed = true

	return removed


# Closing a fire's store (Dave 2 Nov 2026): the burn time and the tier are worked out again from the wood in it. An empty store means no burn time: a burning
# fire goes out, a laid one is empty. The player is told the result.
func _sync_fire_from_box(peer: int, id: int) -> void:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not it.has("fire"):
		return

	var fire: Dictionary = it["fire"]
	var box = _chests.get(int(fire.get("uid", 0)))

	if box == null or not bool(fire.get("synced", false)):
		return

	_fire_apply_store(fire, box)
	fire["fed"] = int(fire.get("fed", 0)) + 1   # the row is sent again, so the client's burn timer shows the new time (Dave 2 Nov 2026: it stayed at the old time, counting down)
	var state: int = int(fire["state"])

	if float(fire["burn_left"]) <= 0.0:
		if fire_is_lit(state):
			_fire_burnt_out(it, fire)   # the last wood taken out of a burning fire: what is left is its coals (or cold ash)
		elif state == 9:
			fire["state"] = 8
			it["left"] = FIRE_OUT_S

		_say(peer, "There is no wood in the fire.")
	else:
		if state == 8:
			fire["state"] = 9
			it["left"] = FIRE_LAID_S
		elif fire_is_lit(state):
			fire["state"] = _fire_restate(fire)

		var secs: int = int(ceil(float(fire["burn_left"])))
		var size: String = ["small", "medium", "large"][_fire_tier_of_state(int(fire["state"]) if fire_is_lit(int(fire["state"])) else _fire_best_state(fire)) - 1]
		_say(peer, "Wood on the fire: %d:%02d:%02d of burn time, a %s fire." % [secs / 3600, (secs / 60) % 60, secs % 60, size])

	_dirty = true


# Wood or food a fire's store accepts.
func _fire_takes(item_id: String) -> bool:
	return _cooking.get("fuel", {}).has(item_id) or _cookable(item_id)


# Once every couple of seconds: wood in the store feeds a fire that is nearly out (or loads a cold one), and raw food on a lit fire cooks, one item per box_cook_s.
func _tend_fire(id: int, it: Dictionary, fire: Dictionary, delta: float) -> void:
	if not fire.has("uid") or not _chests.has(int(fire["uid"])):
		return

	fire["tend"] = float(fire.get("tend", 0.0)) - delta

	if float(fire["tend"]) > 0.0:
		return

	fire["tend"] = 2.0
	var box = _chests[int(fire["uid"])]
	var state: int = int(fire["state"])

	if not fire_is_lit(int(fire["state"])):
		return

	fire["cook_t"] = float(fire.get("cook_t", 0.0)) + 2.0

	if float(fire["cook_t"]) < float(_cooking.get("box_cook_s", 8.0)):
		return

	for slot in range(box.usable):
		if box.numbers[slot] != 0 and _cookable(table.id_of(box.numbers[slot])):
			fire["cook_t"] = 0.0
			var raw: Dictionary = box.take_from_slot(slot, 1)
			var cooked: int = table.number_of(str(_cooking.get("cooks_into", {}).get(table.id_of(int(raw["number"])), _cooking.get("gives", "roast_forage"))))

			if box.add(cooked, 1) > 0:
				box.add(int(raw["number"]), 1, int(raw.get("wear", 0)))

			_dirty = true
			_push_box(id, box)
			return


# Sends fresh contents to whoever has this container open and still stands beside it.
func _push_box(id: int, box) -> void:
	if not send_chest.is_valid():
		return

	for peer in _chest_viewer:
		if int(_chest_viewer[peer]) == id and _peer_pos.has(peer) and _peer_pos[peer].distance_to(_items[id]["pos"]) <= CHEST_REACH_M:
			send_chest.call(peer, id, box.to_bytes())


func _chest_of(peer: int, id: int):
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not _peer_pos.has(peer):
		return null

	if it.has("fire"):
		return _fire_box(peer, it)

	if not it.has("struct") or not it["struct"].has("uid"):
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

	if kind == Net.ACT_CHEST_OPEN:
		_chest_viewer[peer] = id
		var opened: Dictionary = _items.get(id, {})

		if _is_storage(opened) and str(opened["struct"].get("owner", "")) == "" and str(_peer_key.get(peer, "")) != "":
			opened["struct"]["owner"] = str(_peer_key[peer])   # a container from before owners belongs to the first player who opens it (8 Nov 2026)
			_dirty = true

	# A fire with no count yet (loaded, or older than the count) is counted now, before anything is put in: wood put in later is not counted, so
	# burned time can never take it (Tyler's run of #85: the trim's own fallback counted the newly put log, and the old burn time ate it).
	var chest_fire: Dictionary = _items.get(id, {}).get("fire", {})

	if bool(chest_fire.get("synced", false)) and not chest_fire.has("counted"):
		chest_fire["counted"] = _fire_store_pieces(chest_fire, chest)

	# Remains hold the dead character's purse: whoever may open them takes it with the first opening.
	var rec_struct: Dictionary = _items.get(id, {}).get("struct", {})

	if kind != Net.ACT_CHEST_PUT and str(rec_struct.get("kind", "")) == "remains" and int(rec_struct.get("coins", 0)) > 0:
		add_coins(peer, int(rec_struct["coins"]), "pickup")
		rec_struct["coins"] = 0
		_dirty = true

	if kind == Net.ACT_CHEST_PUT and a == -1:   # slot -1 was the log on the shoulder: it is now the pack slot that holds it
		a = _shoulder_slot(peer)

	var fire_refuses: bool = kind == Net.ACT_CHEST_PUT and _items.get(id, {}).has("fire") and a >= 0 and a < inv.SLOTS and inv.numbers[a] != 0 and not _fire_takes(table.id_of(inv.numbers[a]))

	if fire_refuses:
		_say(peer, "A fire takes wood and food.")
		_reject(peer, 3)
	elif kind == Net.ACT_CHEST_PUT and bool(_structures.get(str(_items.get(id, {}).get("struct", {}).get("kind", "")), {}).get("take_only", false)):
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

		if is_shoulder_item(number):   # a large log goes on the shoulder, never into the pack
			if shoulder_of(peer) != "":
				_say(peer, "Put your log down first (Q).")
			elif _give_shoulder(peer, number, 1) == 1:
				chest.take_from_slot(a, 1)
				_dirty = true
		else:
			amount = _fit(peer, inv, number, amount)
			var left: int = inv.add(number, amount, held_wear)
			chest.take_from_slot(a, amount - left)
			_dirty = true

	# Wood moved in or out of a fire's store counts at once (Dave 5 Nov 2026), not only when the window closes: the burn time, the tier and the laid state follow.
	# A burning fire waits for the window to close (its burn debt must not take wood put in meanwhile, test_fire_store); a fire that is not burning has no debt.
	if (kind == Net.ACT_CHEST_PUT or kind == Net.ACT_CHEST_TAKE) and _items.get(id, {}).has("fire") and not fire_is_lit(int(_items[id]["fire"]["state"])):
		_sync_fire_from_box(peer, id)

	if send_chest.is_valid():
		send_chest.call(peer, id, chest.to_bytes())

	if kind == Net.ACT_CHEST_OPEN:
		_send_chest_info(peer, id)   # after the contents, so the client knows which container it is about
		_say_cold_store(peer, id)

	if kind == Net.ACT_CHEST_TAKE and str(_items.get(id, {}).get("struct", {}).get("kind", "")) == "remains":
		_sync_remains(peer, false)


func _save_chests() -> void:
	var rows: Dictionary = {}

	for uid in _chests:
		rows[str(uid)] = _chests[uid].to_json_array()

	_write_atomic("chests.json", {"version": 1, "next_uid": _next_uid, "chests": rows})


# A kit item that was dropped from the game: kits are gone, only the rough bed and the campfire are still made in the pack (Dave 4 Nov 2026).
func is_dead_kit(number: int) -> bool:
	return number > 0 and bool(table.entry(table.id_of(number)).get("retired", false)) and table.id_of(number).ends_with("_kit")


# Empty every slot that holds a dropped kit.
func _strip_dead_kits(inv) -> void:
	for slot in inv.SLOTS:
		if is_dead_kit(inv.numbers[slot]):
			inv.numbers[slot] = 0
			inv.counts[slot] = 0
			inv.wear[slot] = 0


func _load_chests() -> void:
	var parsed: Variant = _read_json_version("chests.json", 1)

	if parsed == null:
		return

	_next_uid = int(parsed.get("next_uid", 1))

	for key in parsed.get("chests", {}):
		var chest = InventoryScript.new(table)
		chest.from_json_array(parsed["chests"][key])
		_strip_dead_kits(chest)
		_chests[int(key)] = chest


# --- Hunger, health and body weight (data/items/vitals.json; Dave 2026-10-20) ---
# An energy balance: a stomach (kcal) is burnt down by rest metabolism plus work; an empty stomach
# burns body weight, a surplus beyond a full one adds it. The player sees hunger as the stomach's
# share in percent, health in points and weight in tenths of a kilo.

# How many of `count` more of an item the player can carry before the hard cap (weights.json).
func _fit(peer: int, inv, number: int, count: int) -> int:
	if _carry_cfg.is_empty():
		return count

	var body: float = _carry_body(peer)
	return CarryRules.fit_count(table.id_of(number), count, CarryRules.carried_kg(inv, table, _carry_cfg) + _shoulder_kg(peer), body, _carry_cfg)


func carried_kg_of(peer: int) -> float:
	var inv = inventory_of(peer)
	return (CarryRules.carried_kg(inv, table, _carry_cfg) + _shoulder_kg(peer)) if inv != null and not _carry_cfg.is_empty() else 0.0


func vitals_of(peer: int) -> Dictionary:
	return _vitals.get(_peer_key.get(peer, ""), {})


# ACT_NEW_PLAYER: the admin's own character starts over as a brand new player, to test the early game as a newcomer sees it. No teleport.
func _become_new_player(peer: int) -> void:
	var key: String = str(_peer_key.get(peer, ""))

	if key == "":
		return

	_inventories[key] = InventoryScript.new(table)
	_store_hotbar(peer, _inventories[key])   # a new player starts with empty keys
	_characters[key]["worn"] = _clean_worn([])
	_characters[key]["new_player"] = true
	_characters[key]["tried"] = {}
	_characters[key]["grace_s"] = _eat_cfg_value("first_hour_s", 3600.0)
	_vitals[key] = _new_vitals()
	_craft_queues.erase(key)
	_asleep.erase(peer)
	_admin_mode_off[peer] = true
	_known[peer] = {}
	send_full.call(peer, _inventories[key].to_bytes())
	_send_favs(peer, _inventories[key])
	_vitals_sent.erase(peer)
	_sync_vitals(peer, true)
	_sync_energy(peer, true)
	_sync_warmth(peer, true)
	_sync_sick(peer, true)
	_sync_worn(peer, true)
	_sync_craft_queue(peer)
	_dirty = true
	_say(peer, "You start again as a new player. Admin mode is off.")


func _new_vitals() -> Dictionary:
	return {"fed": float(_vitals_cfg.get("stomach_cap_kcal", 2400)), "weight": float(_vitals_cfg.get("start_weight_kg", 75)), "health": float(_vitals_cfg.get("health_max", 100)), "wet": float(_vitals_cfg.get("thirst", {}).get("cap_ml", 2400)), "energy": 100.0, "warmth": 100.0, "sick": 0.0}


# How hard the player is working, 0 to 1: movement speed from position reports, lifted by recent tool work.
func exertion_of(peer: int) -> float:
	if int(_strain.get(peer, {}).get("state", 0)) >= 2:
		return 0.0

	return minf(effort_of(peer), 1.0)


# The same without the ceiling (a heavy pack can push it past 1): what strain builds on.
func effort_of(peer: int) -> float:
	var level: float = float(_exertion.get(peer, 0.0))

	if Time.get_ticks_msec() < int(_work_until.get(peer, 0)):
		level = maxf(level, float(_work_level.get(peer, 0.6)))

	# Vomiting and diarrhoea keep the body working at least exertion_floor (data/items/sickness.json) until the sickness fades.
	if float(vitals_of(peer).get("sick", 0.0)) > 0.0:
		level = maxf(level, float(_sick_cfg.get("exertion_floor", 0.5)))

	# Shivering is work (data/items/warmth.json shiver_effort), more the colder.
	if not _warmth_cfg.is_empty():
		var cold_at: float = float(_warmth_cfg.get("cold_at", 40.0))
		var warmth: float = float(vitals_of(peer).get("warmth", 100.0))

		if warmth >= float(_body_cfg().get("shiver_stop_at", -1.0)):   # the body stops shivering deep in the cold (docs/design/body_in_weather_design.md 4)
			level += float(_warmth_cfg.get("shiver_effort", 0.15)) * maxf(cold_at - warmth, 0.0) / maxf(cold_at, 1.0)

	# A pack past 80 percent of the limit is work for anyone on the move, even at a crawl: load_effort x fraction^power added.
	if not _carry_cfg.is_empty():
		level += float(_moving.get(peer, 0.0)) * float(_carry_cfg.get("load_effort", 0.45)) * pow(_load_ratio(peer), float(_carry_cfg.get("load_effort_power", 1.5)))

	return level


# How far into the hindering band the load is: 0 up to 80 percent of the limit, 1 at the limit.
var _load_cache: Dictionary = {}     # peer -> load ratio, valid only during one _vitals_tick (it asks four times per player)
var _in_vitals: bool = false


func _load_ratio(peer: int) -> float:
	if _carry_cfg.is_empty():
		return 0.0

	if _in_vitals and _load_cache.has(peer):
		return float(_load_cache[peer])

	var body: float = _carry_body(peer)
	var ratio: float = CarryRules.load_fraction(carried_kg_of(peer), body, _carry_cfg)

	if _in_vitals:
		_load_cache[peer] = ratio

	return ratio


# Stance changes (0 stand, 1 crouch, 2 sit, 3 lie). Fainted or waking players cannot choose; the answer
# (the confirmed stance) goes back in the next strain message.
func _set_stance(peer: int, wanted: int) -> void:
	if wanted < 0 or wanted > 3 or not _peer_key.has(peer) or _forced_sleep(peer):
		return

	if int(_strain.get(peer, {}).get("state", 0)) < 2:
		_stance[peer] = wanted

		if wanted != 3:
			_end_sleep(peer)

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
func _energy_tick(peer: int, v: Dictionary, _spent: float, game_s: float) -> void:
	if _energy_cfg.is_empty():
		return

	var e: float = float(v.get("energy", 100.0))
	var hours: float = game_s / 3600.0
	var drain: Dictionary = _energy_cfg.get("drain_per_game_day", {})
	var rec: Dictionary = _energy_cfg.get("recover_per_game_hour", {})
	e -= (float(drain.get("rest", 12.0)) + float(drain.get("work", 42.0)) * exertion_of(peer)) * game_s / 86400.0 * float(rested_tier(peer).get("exhaustion_mult", 1.0))   # Rested: slower exhaustion
	var stance: int = int(_stance.get(peer, 0))

	if _forced_sleep(peer):
		e += float(rec.get("sleep", 12.5)) * hours
	elif _asleep.has(peer):
		e += lerpf(float(rec.get("lie", 8.3)), float(rec.get("sleep", 12.5)), clampf(_sleep_quality(peer), 0.0, 1.0)) * hours
	elif stance == 3:
		e += float(rec.get("sleep", 12.5) if on_good_bed(peer) else rec.get("lie", 8.3)) * hours
	elif stance == 2 and e < float(_energy_cfg.get("sit_cap", 75.0)):
		e = minf(e + float(rec.get("sit", 9.4)) * hours, float(_energy_cfg.get("sit_cap", 75.0)))

	e = clampf(e, 0.0, 100.0)
	v["energy"] = e

	if e <= 0.0 and not _forced_sleep(peer) and int(_strain.get(peer, {}).get("state", 0)) < 2:
		_stance[peer] = 3
		_asleep[peer] = {"rested": 0.0, "forced": true, "t": 0.0}
		_note_shelter(peer)
		_strain_sent.erase(peer)
		_say(peer, "You collapse with exhaustion")
	elif _forced_sleep(peer) and e >= float(_energy_cfg.get("forced", {}).get("wake_at", 100.0)) and float(_strain.get(peer, {}).get("s", 0.0)) <= 0.02:
		_end_sleep(peer)
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
			_wake(peer, "You wake, not fully rested" if energy_of(peer) < 99.0 else "")
		elif energy_of(peer) >= float(_energy_cfg.get("forced", {}).get("manual_wake_at", 30.0)) and float(_strain.get(peer, {}).get("s", 0.0)) <= 0.3:
			# Dave 2026-10-22: after an exhaustion collapse the sleeper may wake early once the energy is back to manual_wake_at.
			_end_sleep(peer)
			_strain_sent.erase(peer)
			_say(peer, "You wake, not fully rested")

		return

	if _asleep.has(peer):
		return

	if int(_stance.get(peer, 0)) != 3 or int(_strain.get(peer, {}).get("state", 0)) >= 2:
		return

	if _sleep_quality(peer) < 0.0:
		_say(peer, "Rain falls on you: find cover to sleep")
		return

	# Dave 2026-10-21: with full energy you cannot sleep, unless exertion is high: then a short nap brings it down fast.
	var nap: Dictionary = _sleep_cfg.get("nap", {})
	var strain_now: float = float(_strain.get(peer, {}).get("s", 0.0))
	var exertion_share: float = strain_now / maxf(float(_exertion_cfg.get("over_on", 1.0)), 0.01)
	var napping: bool = false

	if not nap.is_empty() and energy_of(peer) >= float(nap.get("energy_full", 99.0)):
		if exertion_share <= float(nap.get("exertion_min", 0.75)):
			_say(peer, str(nap.get("say_rested", "You are well rested, you really can't sleep right now")))
			return

		napping = true

	_asleep[peer] = {"rested": 0.0, "t": 0.0}

	if napping:
		var end_strain: float = float(nap.get("exertion_end", 0.25)) * float(_exertion_cfg.get("over_on", 1.0))
		_asleep[peer]["nap"] = true
		_asleep[peer]["nap_end"] = end_strain
		_asleep[peer]["nap_rate"] = maxf(strain_now - end_strain, 0.0) / maxf(float(nap.get("target_s", 10.0)), 1.0)

	_waking.erase(peer)
	_strain_sent.erase(peer)
	_note_shelter(peer)
	_say(peer, "You lie down for a nap" if napping else "You fall asleep")


# Dave 2026-10-21: a dead character comes back at the last shelter they slept in. Sleeping within SHELTER_NOTE_M of a standing
# shelter structure (structures.json "shelter", the lean-to) keeps its spot in the character row (characters.json "shelter").
const SHELTER_NOTE_M := 3.0


func _shelter_near(pos: Vector3) -> int:
	var best: int = -1
	var best_d: float = SHELTER_NOTE_M

	for id in _items:
		var it: Dictionary = _items[id]

		if not it.has("struct") or not bool(_structures.get(str(it["struct"]["kind"]), {}).get("shelter", false)):
			continue

		var d: float = Vector2(it["pos"].x - pos.x, it["pos"].z - pos.z).length()

		if d < best_d:
			best_d = d
			best = id

	return best


# The places a character rested or built a shelter (characters.json "rests", newest last, at most REST_POINTS_MAX): [x, y, z, "shelter" or "fire"].
# DECISIONS.md 2026-10-22 collapse-offline: after a dropped connection the player comes back at the nearest of these (rest_point_for).
const REST_POINTS_MAX := 12


func _record_rest(key: String, pos: Vector3, kind: String) -> void:
	if not _characters.has(key):
		return

	var rests: Array = _characters[key].get("rests", [])

	for r in rests:
		if Vector3(float(r[0]), float(r[1]), float(r[2])).distance_to(pos) < 1.0:
			return

	rests.append([pos.x, pos.y, pos.z, kind])

	while rests.size() > REST_POINTS_MAX:
		rests.remove_at(0)

	_characters[key]["rests"] = rests
	_dirty = true


# Where a character who dropped off comes back: the nearest of their rest and shelter points (by distance from `from`) that still stands,
# in front of it; with none, their last shelter or the world spawn. Computed when they rejoin, never stored.
func rest_point_for(peer: int, from: Vector3) -> Vector3:
	var best: Vector3 = Vector3.ZERO
	var best_d: float = INF

	for r in _characters.get(_peer_key.get(peer, ""), {}).get("rests", []):
		var spot: Vector3 = Vector3(float(r[0]), float(r[1]), float(r[2]))
		var landing: Vector3 = Vector3.INF

		if str(r[3]) == "shelter":
			var id: int = _shelter_near(spot)

			if id >= 0 and _items[id]["pos"].distance_to(spot) <= 0.5:
				var def: Dictionary = _structures.get(str(_items[id]["struct"]["kind"]), {})
				var yaw: float = deg_to_rad(float(_items[id]["struct"]["yaw"]))
				landing = spot + Vector3(cos(yaw), 0.0, sin(yaw)) * (maxf(float(def.get("half_x", 1.0)), float(def.get("half_z", 1.0))) + 1.5)
		else:
			for id in _items:
				if _items[id].has("fire") and _items[id]["pos"].distance_to(spot) <= 0.5:
					landing = spot + Vector3(1.5, 0.0, 0.0)
					break

		if landing != Vector3.INF and landing.distance_to(from) < best_d:
			best_d = landing.distance_to(from)
			best = landing

	return best if best_d < INF else respawn_for(peer)


func _note_shelter(peer: int) -> void:
	if not _peer_pos.has(peer) or not _characters.has(_peer_key.get(peer, "")):
		return

	var id: int = _shelter_near(_peer_pos[peer])

	if id < 0:
		for fire_id in _items:
			if _items[fire_id].has("fire") and _items[fire_id]["pos"].distance_to(_peer_pos[peer]) <= SHELTER_NOTE_M:
				_record_rest(str(_peer_key[peer]), _items[fire_id]["pos"], "fire")
				break

		return

	_record_rest(str(_peer_key[peer]), _items[id]["pos"], "shelter")

	var p: Vector3 = _items[id]["pos"]
	var row: Dictionary = _characters[_peer_key[peer]]

	if row.get("shelter", []) != [p.x, p.y, p.z]:
		row["shelter"] = [p.x, p.y, p.z]
		_dirty = true


# The spawn point a player chooses (Dave 31 Oct 2026): E on a placed bed offers "Set this bed as your spawn point" (ACT_SET_SPAWN). One per character, saved in
# characters.json "spawn_bed" [x, y, z]; a new choice unsets the old; if that bed is taken down or destroyed the character comes back at the spawn pad.
func set_spawn_bed(peer: int, bed_id: int) -> bool:
	var it: Dictionary = _items.get(bed_id, {})
	var key: String = str(_peer_key.get(peer, ""))

	if it.is_empty() or not it.has("struct") or not _is_bed_kind(str(it["struct"].get("kind", ""))) or key == "" or not _characters.has(key) or not _peer_pos.has(peer):
		return false

	if _peer_pos[peer].distance_to(it["pos"]) > Interact.server_reach_m() + 1.0:
		_say(peer, "Too far from the bed.")
		return false

	var p: Vector3 = it["pos"]
	_characters[key]["spawn_bed"] = [p.x, p.y, p.z]
	_dirty = true
	_say(peer, "Spawn point set")
	return true


# The bed standing at the saved spawn spot, 0 when it is gone.
func _spawn_bed_id(peer: int) -> int:
	var saved: Array = _characters.get(_peer_key.get(peer, ""), {}).get("spawn_bed", [])

	if saved.size() != 3:
		return 0

	var spot := Vector3(float(saved[0]), float(saved[1]), float(saved[2]))

	for id in _items:
		var it: Dictionary = _items[id]

		if it.has("struct") and _is_bed_kind(str(it["struct"].get("kind", ""))) and it["pos"].distance_to(spot) <= 0.5:
			return id

	return 0


var _bed_deaths: Dictionary = {}    # player key -> msecs of the recent deaths that came back at their bed (bed.json respawn)


# A bed that keeps killing its sleeper (the danger is still there): after max_in_window deaths inside window_s the next one comes back elsewhere. Counts the death when it says yes.
func _bed_death_allowed(key: String) -> bool:
	var cfg: Dictionary = _bed_cfg.get("respawn", {})
	var now: int = Time.get_ticks_msec()
	var window_ms: int = int(float(cfg.get("window_s", 600.0)) * 1000.0)
	var recent: Array = (_bed_deaths.get(key, []) as Array).filter(func(t): return now - int(t) < window_ms)
	_bed_deaths[key] = recent

	if recent.size() >= int(cfg.get("max_in_window", 2)):
		return false

	recent.append(now)
	return true


# A free place beside the bed: a ring from landing_m out to search_m, nearest first, on ground within 2 m of the bed's height and not inside a structure; none free = the bed's own spot
# plus 0.3 m (the old behaviour), never the void.
func _bed_landing(bed: Vector3) -> Vector3:
	var cfg: Dictionary = _bed_cfg.get("respawn", {})
	var r: float = float(cfg.get("landing_m", 1.2))
	var max_r: float = float(cfg.get("search_m", 3.0))

	while r <= max_r + 0.001:
		for k in 8:
			var a: float = TAU * float(k) / 8.0
			var spot: Vector3 = bed + Vector3(cos(a) * r, 0.0, sin(a) * r)
			var ground: float = float(ground_height.call(spot.x, spot.z)) if ground_height.is_valid() else bed.y

			if not is_nan(ground) and absf(ground - bed.y) < 2.0 and not _blocked_spot(spot, bed):
				return Vector3(spot.x, ground + 0.1, spot.z)

		r += 0.5

	return bed + Vector3(0.0, 0.3, 0.0)


func _blocked_spot(spot: Vector3, bed: Vector3) -> bool:
	for id in _items:
		var it: Dictionary = _items[id]

		if not it.has("struct") or absf(it["pos"].y - spot.y) > 3.0:
			continue

		var def: Dictionary = _structures.get(str(it["struct"].get("kind", "")), {})

		if bool(def.get("walkover", false)):
			continue

		var reach: float = maxf(float(def.get("footprint_x", 1.0)), float(def.get("footprint_z", 1.0))) * 0.5

		if Vector2(it["pos"].x - bed.x, it["pos"].z - bed.z).length() < reach:
			continue   # the shelter the bed stands in (a lean-to): landing under its roof is the point

		if Vector2(it["pos"].x - spot.x, it["pos"].z - spot.z).length() < reach + 0.35:
			return true

	return false


# Where this character comes back: at their spawn bed if they set one and it still stands (a bed that is gone is forgotten and the spawn pad is used), else just in front of
# their last shelter if it still stands, else the world spawn.
func respawn_for(peer: int, dying: bool = false) -> Vector3:
	var row: Dictionary = _characters.get(_peer_key.get(peer, ""), {})

	if (row.get("spawn_bed", []) as Array).size() == 3:
		var bed: int = _spawn_bed_id(peer)

		if bed == 0:
			row.erase("spawn_bed")
			_dirty = true
			return respawn_point

		if not dying or _bed_death_allowed(str(_peer_key.get(peer, ""))):
			return _bed_landing(_items[bed]["pos"])
		# else: the third death in the window falls through to the shelter rule or the world spawn below (the bed stays set)

	var saved: Array = _characters.get(_peer_key.get(peer, ""), {}).get("shelter", [])

	if saved.size() != 3:
		return respawn_point

	var spot := Vector3(float(saved[0]), float(saved[1]), float(saved[2]))
	var id: int = _shelter_near(spot)

	if id < 0 or _items[id]["pos"].distance_to(spot) > 0.5:
		return respawn_point

	var def: Dictionary = _structures.get(str(_items[id]["struct"]["kind"]), {})
	var yaw: float = deg_to_rad(float(_items[id]["struct"]["yaw"]))
	var out: float = maxf(float(def.get("half_x", 1.0)), float(def.get("half_z", 1.0))) + 1.5
	return spot + Vector3(cos(yaw), 0.0, sin(yaw)) * out


func _wake(peer: int, why: String) -> void:
	if not _end_sleep(peer):
		return

	_strain_sent.erase(peer)
	_say(peer, why if why != "" else "You wake")


# Sleep ends (any reason): the wake fade starts. True when the player was asleep.
func _end_sleep(peer: int) -> bool:
	if not _asleep.erase(peer):
		return false

	_waking[peer] = {"t": 0.0}
	return true


# Real seconds until a sleeper wakes by themselves: the longer of the energy still to fill (at the rate sleeping here refills
# it, game hours at 24:1) and the exertion still to rest off (strain falls at the lying rate times the sleep multiplier).
func sleep_eta(peer: int) -> float:
	if not _asleep.has(peer):
		return 0.0

	if bool(_asleep[peer].get("nap", false)):
		var left: float = maxf(float(_strain.get(peer, {}).get("s", 0.0)) - float(_asleep[peer]["nap_end"]), 0.0)
		return left / maxf(float(_asleep[peer]["nap_rate"]), 0.001)

	var rec: Dictionary = _energy_cfg.get("recover_per_game_hour", {})
	var rate: float = float(rec.get("sleep", 12.5)) if _forced_sleep(peer) else lerpf(float(rec.get("lie", 8.3)), float(rec.get("sleep", 12.5)), clampf(_sleep_quality(peer), 0.0, 1.0))
	var energy_s: float = maxf(100.0 - energy_of(peer), 0.0) / maxf(rate, 0.1) * 3600.0 / GAME_RATE
	var cfg: Dictionary = _exertion_cfg
	var strain: float = float(_strain.get(peer, {}).get("s", 0.0))
	var fall: float = float(cfg.get("fall_per_s", 0.05)) * (float(_sleep_cfg.get("strain_mult", 6.0)) if not _forced_sleep(peer) else float(cfg.get("lie_fall_mult", 3.0))) * maxf(float(cfg.get("rest_effort", 0.52)), 0.1)
	return maxf(energy_s, strain / maxf(fall, 0.001)) + float(_sleep_cfg.get("rested_s", 1.5))


# 1 under a roof or crown, the open-dry value in the open, -1 when rain reaches the sleeper (cannot sleep there).
# A bed is a structure whose comfort kind (comfort.json) is of class "bed": the rough bed, the straw bed, the feather bed, the canopy bed. Sleep, the good-bed bonuses, the
# spawn point and the bed-in-a-shelter placement all find any of them.
func _is_bed_kind(kind: String) -> bool:
	if kind == "rough_bed":
		return true

	return str(_comfort_kind(str(_structures.get(kind, {}).get("comfort", kind))).get("class", "")) == "bed"


# The rough bed under a lying player (bed.json): the world id of the nearest placed rough_bed within reach, or 0. Looked up at most every
# recheck_s; a bed that is gone (taken up, destroyed) is dropped from the cache at once, so nothing keeps a sleeper "in bed".
func _bed_of(peer: int) -> int:
	if _bed_cfg.is_empty() or int(_stance.get(peer, 0)) != 3 or not _peer_pos.has(peer):
		_bed_cache.erase(peer)
		return 0

	var now: int = Time.get_ticks_msec()
	var entry: Dictionary = _bed_cache.get(peer, {})

	if not entry.is_empty() and int(entry["id"]) != 0 and not _items.has(int(entry["id"])):
		entry = {}

	if not entry.is_empty() and now < int(entry["until"]):
		return int(entry["id"])

	var here: Vector3 = _peer_pos[peer]
	var reach: float = float(_bed_cfg.get("reach_m", 1.2))
	var best: int = 0
	var best_d: float = INF

	for id in _items:
		var it: Dictionary = _items[id]

		if not it.has("struct") or not _is_bed_kind(str(it["struct"].get("kind", ""))):
			continue

		var d: float = Vector2(it["pos"].x - here.x, it["pos"].z - here.z).length()

		if d <= reach and d < best_d and absf(it["pos"].y - here.y) < 3.0:
			best = int(id)
			best_d = d

	_bed_cache[peer] = {"id": best, "until": now + int(float(_bed_cfg.get("recheck_s", 1.5)) * 1000.0)}
	return best


# A lying player on a rough bed that has cover over it (roof or crown): the only case the bed's advantages apply.
func on_good_bed(peer: int) -> bool:
	return _bed_of(peer) != 0 and cover_at.is_valid() and float(cover_at.call(_peer_pos[peer])) > 0.5


# True when that good bed stands in a closed room: a roof (cover 2.0, a built one) and walls_needed wall pieces near it. Animals do not sense the sleeper.
func _bed_room_closed(peer: int) -> bool:
	if not on_good_bed(peer) or float(cover_at.call(_peer_pos[peer])) < 1.5:
		return false

	var here: Vector3 = _peer_pos[peer]
	var radius: float = float(_bed_cfg.get("walls_radius_m", 3.0))
	var walls: int = 0

	for id in _items:
		var it: Dictionary = _items[id]

		if it.has("struct") and str(_structures.get(str(it["struct"].get("kind", "")), {}).get("piece_kind", "")) == "wall" and Vector2(it["pos"].x - here.x, it["pos"].z - here.z).length() <= radius:
			walls += 1

	return walls >= int(_bed_cfg.get("walls_needed", 3))


# How fast food and water drain right now: bed.json drain_mult asleep or lying on a good bed, asleep_ground_mult asleep anywhere else, 1 otherwise.
func _drain_mult(peer: int) -> float:
	if _bed_cfg.is_empty():
		return 1.0

	if on_good_bed(peer):
		return float(_bed_cfg.get("drain_mult", 0.5))

	return float(_bed_cfg.get("asleep_ground_mult", 1.0)) if _asleep.has(peer) else 1.0


func _sleep_quality(peer: int) -> float:
	var q: Dictionary = _sleep_cfg.get("quality", {})
	var covered: bool = cover_at.is_valid() and _peer_pos.has(peer) and float(cover_at.call(_peer_pos[peer])) > 0.5

	if covered:
		return float(_bed_cfg.get("quality", 1.0)) if on_good_bed(peer) else float(q.get("covered", 1.0))

	if rain_now.is_valid() and float(rain_now.call()) >= float(_sleep_cfg.get("rain_wakes", 0.2)):
		return -1.0   # a bedroll is not a roof

	if _has_bedroll(peer):
		return float(_sleep_cfg.get("bedroll", {}).get("open_dry", q.get("open_dry", 0.6)))

	return float(q.get("open_dry", 0.6))


# A Bedroll in the pack (sleep.json "bedroll", Part C plan 5): better sleep on open dry ground and a little warmth lying down. Not a bed: no
# spawn point, and nothing that asks "on a good bed" counts it.
func _has_bedroll(peer: int) -> bool:
	return count_for(peer, str(_sleep_cfg.get("bedroll", {}).get("item", "bedroll"))) > 0


# Who is where and under which key: for the NPC runner and the admin check.
func peer_positions() -> Array:
	return _peer_pos.values()


# Stances in the same order as peer_positions (0 stand, 1 crouch, 2 sit, 3 lie): wildlife notices a crouching player later.
func peer_stances() -> Array:
	var out: Array = []

	for peer in _peer_pos:
		var stance: int = int(_stance.get(peer, 0))

		if stance == 3 and on_good_bed(peer):
			stance = 5 if _bed_room_closed(peer) else 4   # 4 lying on a covered bed, 5 in a closed room: server_animals reads them as lying, harder to sense

		out.append(stance)

	return out


# The hunting skill's effect on stalking (skills.json actions.stalk) for each player, in the same order as peer_positions: a
# skilled hunter rustles less pushing through bushes (server_animals _sample_noise).
func peer_stalk_factors() -> Array:
	var out: Array = []

	for peer in _peer_pos:
		out.append(skill_factor(peer, "stalk"))

	return out


# What the wolf pack brain may know about each player: where, how they stand, health share, whether they carry raw meat, a
# spear or a torch on the hotbar (the server does not know the selected slot).
func wolf_info() -> Array:
	var out: Array = []

	for peer in _peer_pos:
		var inv = inventory_of(peer)

		if inv == null:
			continue

		var v: Dictionary = vitals_of(peer)
		out.append({"peer": peer, "pos": _peer_pos[peer], "stance": int(_stance.get(peer, 0)),
			"hp": float(v.get("health", 100.0)) / maxf(float(_vitals_cfg.get("health_max", 100)), 1.0),
			"meat": count_for(peer, "raw_meat") > 0, "meat_cooked": count_for(peer, "roast_meat") > 0, "spear": _tool_slot(inv, "spear") >= 0, "torch": _tool_slot(inv, "torch") >= 0})

	return out


# Loose food lying on the ground within r of a point, for a fox to smell: [[world id, position], ...]. Chests, remains, fires and
# placed things are not loose; whatever is in a chest or a pack is safe.
func loose_food_near(centre: Vector3, r: float) -> Array:
	var out: Array = []

	for id in _items:
		var it: Dictionary = _items[id]

		if it.has("struct") or it.has("fire") or it.has("tree") or it.has("boulder") or it.has("scatter"):
			continue

		if str(table.entry(table.id_of(int(it["number"]))).get("kind", "")) != "food":
			continue

		if Vector2(it["pos"].x - centre.x, it["pos"].z - centre.z).length() <= r:
			out.append([id, it["pos"]])

	return out


# A thief takes a loose item whole: [item number, count], or [] when it is no longer there.
func take_loose(id: int) -> Array:
	if not _items.has(id):
		return []

	var it: Dictionary = _items[id]
	var out: Array = [int(it["number"]), int(it["count"])]
	_items.erase(id)
	_dirty = true
	return out


# Goblins steal (docs/design/goblin_stealing_design.md, Dave 8 Nov 2026): loose small things lying on the ground within r of a point,
# [[world id, position, dropped by (character key or ""), item kind, item id], ...]. Not structures, fires, trees, boulders, natural scatter or the showroom; not a shoulder carry (logs); not a
# structure, placeable or container item. Whatever is in a chest or a pack is safe. Light and den piles are the goblin's own checks.
const STEAL_NEVER_KINDS := ["structure", "placeable", "container"]


func stealable_near(centre: Vector3, r: float) -> Array:
	var out: Array = []

	for id in _items:
		var it: Dictionary = _items[id]

		if it.has("struct") or it.has("fire") or it.has("tree") or it.has("boulder") or it.has("scatter") or it.has("showroom") or int(it["count"]) <= 0:
			continue

		if Vector2(it["pos"].x - centre.x, it["pos"].z - centre.z).length() > r:
			continue

		var row: Dictionary = table.entry(table.id_of(int(it["number"])))

		if row.is_empty() or row.has("carry") or STEAL_NEVER_KINDS.has(str(row.get("kind", ""))):
			continue

		out.append([id, it["pos"], str(it.get("by", "")), str(row.get("kind", "")), table.id_of(int(it["number"]))])

	return out


# A goblin takes one piece of a loose stack: [item number, 1], or [] when it is no longer there. The rest of the stack stays.
func take_one(id: int) -> Array:
	if not _items.has(id) or int(_items[id]["count"]) <= 0:
		return []

	var it: Dictionary = _items[id]
	it["count"] = int(it["count"]) - 1

	if int(it["count"]) <= 0:
		_items.erase(id)

	_dirty = true
	return [int(it["number"]), 1]


# Whether a burning placed fire (a campfire, a hearth, a forge: not a torch bearer) lies within r of a point (flat distance). A goblin
# band does not come back to a cave while one burns this near its mouth (Dave 8 Nov 2026, decision 13).
func lit_fire_near(point: Vector3, r: float) -> bool:
	for row in _lit_rows():
		if Vector2(row[0].x - point.x, row[0].z - point.z).length() <= r:
			return true

	return false


# Wolves steal: every raw and roast meat leaves the pack. Returns how many pieces went.
func take_all_meat(peer: int) -> int:
	var total: int = 0

	for id in ["raw_meat", "roast_meat"]:
		var n: int = count_for(peer, id)

		if n > 0 and take_from(peer, id, n):
			total += n

	return total


# Wolf bites (data/animals/animals.json "wolves"). Not lethal: health stops at maim_hp and the bite reports "maimed" (a crippling
# injury; the pack then backs off). Lethal (a player already maimed): health can reach zero and the character dies.
# Returns "hurt", "maimed" or "dead".
func hurt_player(peer: int, amount: float, lethal: bool, cause: String, floor_hp: float = 25.0) -> String:
	var v: Dictionary = vitals_of(peer)

	if v.is_empty():
		return "hurt"

	var before: float = float(v["health"])
	v["health"] = before - amount

	if lethal and float(v["health"]) <= 0.0:
		v["health"] = 0.0
		_sync_vitals(peer, true)
		return "dead" if kill(peer, cause) else "hurt"

	if not lethal and float(v["health"]) <= floor_hp:
		v["health"] = minf(before, floor_hp)
		_say(peer, "The wolves have crippled you. Get away while you can." if cause == "wolves" else "You are badly hurt. Get away while you can.")
		v["limp"] = float(_vitals_cfg.get("limp", {}).get("seconds", 600.0))
		_sync_limp(peer, false)
		_sync_vitals(peer, true)
		return "maimed"

	if not _forced_sleep(peer):
		_end_sleep(peer)

	_sync_vitals(peer, false)
	return "hurt"


# For the dialogue effects (authored lines only): how many of an item the pack holds, and give or take some.
func count_for(peer: int, id: String) -> int:
	var inv = inventory_of(peer)
	return inv.count_of(table.number_of(id)) if inv != null and table.number_of(id) > 0 else 0


func give_to(peer: int, id: String, count: int) -> void:
	if id.begins_with("coin_"):
		add_coins(peer, count * coin_copper(id), SRC_REWARD)
		return

	var inv = inventory_of(peer)

	if inv == null or table.number_of(id) <= 0:
		return

	var before: Array = _snapshot(inv)
	var left: int = inv.add(table.number_of(id), count)

	if left > 0:
		drop_in_world(table.number_of(id), left, _peer_pos.get(peer, Vector3.ZERO))

	_gain_source = SRC_REWARD
	_send_changes(peer, inv, before)
	_gain_source = SRC_PICKUP
	_dirty = true


# --- money and reputation (Dave 2026-10-21; data/items/coins.json, data/npcs/reputation.json, items/COINS.md) ---

func coin_copper(id: String) -> int:
	for row in _coins_cfg.get("ladder", []):
		if str(row["id"]) == id:
			return int(row["copper"])

	return 0


# The purse as a number of copper. Coins are not item stacks: the purse is part of the character row.
func coins_of(peer: int) -> int:
	return maxi(int(_characters.get(_peer_key.get(peer, ""), {}).get("coins", 0)), 0)


# The purse as [[coin item id, count], ...], richest first.
func purse_breakdown(copper: int) -> Array:
	var out: Array = []
	var left: int = copper

	for row in _coins_cfg.get("ladder", []):
		var each: int = maxi(int(row["copper"]), 1)

		if left >= each:
			@warning_ignore("integer_division")
			out.append([str(row["id"]), left / each])
			left = left % each

	return out


# Pays copper into the purse and tells the feed what came (as coins, richest first).
func add_coins(peer: int, copper: int, source: String = "pickup") -> void:
	var key: String = _peer_key.get(peer, "")

	if copper <= 0 or not _characters.has(key):
		return

	var cap: int = int(_coins_cfg.get("max_copper", 100000000))
	var before: int = coins_of(peer)
	var after: int = mini(before + copper, cap)
	_characters[key]["coins"] = after
	_dirty = true
	sync_purse(peer)

	if send_received.is_valid():
		for row in purse_breakdown(after - before):
			send_received.call(peer, row[0], row[1], source)


# Takes copper out of the purse, all or nothing.
func take_coins(peer: int, copper: int) -> bool:
	var key: String = _peer_key.get(peer, "")

	if copper < 0 or not _characters.has(key) or coins_of(peer) < copper:
		return false

	_characters[key]["coins"] = coins_of(peer) - copper
	_dirty = true
	sync_purse(peer)
	return true


# The copper amount in words, richest coin first: "2 silver, 3 bronze".
func _coin_words(copper: int) -> String:
	var parts: PackedStringArray = PackedStringArray()

	for row in purse_breakdown(copper):
		parts.append("%d %s" % [int(row[1]), str(_coin_name(str(row[0])))])

	return ", ".join(parts) if not parts.is_empty() else "nothing"


func _coin_name(id: String) -> String:
	for row in _coins_cfg.get("ladder", []):
		if str(row["id"]) == id:
			return str(row["name"])

	return id


func sync_purse(peer: int) -> void:
	if send_purse.is_valid() and _characters.has(_peer_key.get(peer, "")):
		send_purse.call(peer, coins_of(peer))


func rep_points(peer: int, npc_id: String) -> int:
	var rows: Dictionary = _characters.get(_peer_key.get(peer, ""), {}).get("rep", {})
	return maxi(int(rows.get(npc_id, 0)), 0)


# The rank word for a score: the highest rank whose `at` is not above it.
func rank_of(points: int) -> String:
	var word: String = "Stranger"

	for row in _rep_cfg.get("ranks", []):
		if points >= int(row["at"]):
			word = str(row["name"])

	return word


# Whether `points` reaches the named rank (or better).
func rank_reached(points: int, rank: String) -> bool:
	for row in _rep_cfg.get("ranks", []):
		if str(row["name"]) == rank:
			return points >= int(row["at"])

	return false


# What an NPC charges this player: the base price scaled by the rank discount, never below 1 when it was above 0.
func price_for(peer: int, npc_id: String, base: int) -> int:
	if base <= 0:
		return base

	var mult: float = float(_rep_cfg.get("price_mult", {}).get(rank_of(rep_points(peer, npc_id)), 1.0))
	return maxi(int(round(float(base) * mult)), 1)


func add_rep(peer: int, npc_id: String, points: int) -> void:
	var key: String = _peer_key.get(peer, "")

	if not _characters.has(key) or points == 0 or npc_id == "":
		return

	if typeof(_characters[key].get("rep", null)) != TYPE_DICTIONARY:
		_characters[key]["rep"] = {}

	var before: int = rep_points(peer, npc_id)
	var after: int = clampi(before + points, 0, int(_rep_cfg.get("max_points", 30)))
	_characters[key]["rep"][npc_id] = after
	_dirty = true
	sync_reputation(peer)

	if rank_of(after) != rank_of(before):
		_say(peer, "You are now a %s of that person: %s." % [rank_of(after).to_lower(), npc_name.call(npc_id) if npc_name.is_valid() else npc_id])


var npc_name: Callable   # (npc id) -> display name, wired by the server


func sync_reputation(peer: int) -> void:
	if not send_reputation.is_valid() or not _characters.has(_peer_key.get(peer, "")):
		return

	var ids: PackedStringArray = PackedStringArray()
	var names: PackedStringArray = PackedStringArray()
	var points: PackedInt32Array = PackedInt32Array()
	var rows: Dictionary = _characters[_peer_key[peer]].get("rep", {})

	for id in rows:
		ids.append(str(id))
		names.append(npc_name.call(str(id)) if npc_name.is_valid() else str(id))
		points.append(int(rows[id]))

	send_reputation.call(peer, ids, names, points)


func take_from(peer: int, id: String, count: int) -> bool:
	var inv = inventory_of(peer)

	if inv == null or table.number_of(id) <= 0:
		return false

	var before: Array = _snapshot(inv)
	var ok: bool = inv.remove(table.number_of(id), count)
	_send_changes(peer, inv, before)
	return ok


func peer_ids() -> Array:
	return _peer_pos.keys()


func position_of(peer: int) -> Variant:
	return _peer_pos.get(peer, null)


func key_of(peer: int) -> String:
	return str(_peer_key.get(peer, ""))


func stance_of(peer: int) -> int:
	return int(_stance.get(peer, 0))


# The server's own reading of whether a player is swimming (from their position and the water there,
# see terrain_server._swim_state): swimming is work whatever the client says.
func set_swimming(peer: int, swimming: bool) -> void:
	_swimming[peer] = swimming


func set_cave_pool(peer: int, in_pool: bool) -> void:
	_cave_pool[peer] = in_pool


# The server's own reading of whether a player's head is under water (terrain_server._head_under): the air runs down.
func set_head_under(peer: int, under: bool) -> void:
	_head_under[peer] = under


# Air left in seconds, or -1 when the head is above water (for tests and the status line).
func breath_of(peer: int) -> float:
	return float(_breath.get(peer, -1.0))


# One slow tick of breath (data/items/vitals.json "breath"): under water the air runs down, at the
# surface it is full at once; with none left the character suffocates, faints and drowns (BUG-029).
func _breath_tick(peer: int, v: Dictionary, spent: float) -> void:
	var cfg: Dictionary = _vitals_cfg.get("breath", {})

	if cfg.is_empty():
		return

	var full: float = float(cfg.get("seconds", 60))

	if not bool(_head_under.get(peer, false)):
		_suffocate.erase(peer)

		if _breath.has(peer):
			_breath.erase(peer)

		_sync_breath(peer, -1)
		return

	var air: float = float(_breath.get(peer, full))
	var drain: float = SwimRules.breath_drain(float(_speed3.get(peer, 0.0)), float(cfg.get("rest_speed", 0.5)), float(cfg.get("rest_mult", 0.5)), float(cfg.get("hard_speed", 2.6)), float(cfg.get("hard_mult", 1.6)))
	air -= spent * drain

	if air <= 0.0:
		# BUG-029 (Dave 2026-11-04): no auto-rise and no health drain. Suffocation: the heart races (_sync_body) and the vision fades (_strain_tick)
		# until the character faints; fainting with the head still under water is drowning. Surfacing before then undoes it.
		air = 0.0
		var was_out: bool = _suffocate.has(peer)
		var t: float = float(_suffocate.get(peer, 0.0)) + spent
		_suffocate[peer] = t
		_asleep.erase(peer)

		if not was_out:
			_say(peer, "You are out of air")

		if t >= float(cfg.get("faint_after_s", 15.0)) and int(_strain.get(peer, {}).get("state", 0)) == 2 and bool(cfg.get("can_die", false)):
			_death_cause[peer] = "drowning"
			v["health"] = 0.0
	else:
		_suffocate.erase(peer)

	_breath[peer] = air
	_sync_breath(peer, int(ceil(air * 10.0)))


func vitals_breath_faint_s() -> float:
	return float(_vitals_cfg.get("breath", {}).get("faint_after_s", 15.0))


func _sync_breath(peer: int, tenths: int) -> void:
	# While diving, a change of half a second or more; the hide message once.
	var last: int = int(_breath_sent.get(peer, -1))

	if tenths == last or (tenths >= 0 and last >= 0 and absi(tenths - last) < 5 and tenths != 0):
		return

	_breath_sent[peer] = tenths

	if send_breath.is_valid():
		send_breath.call(peer, tenths)


# Whether a path patch has its centre within data/path_speed.json range_m of the player, checked at most once a second per player (one pass over the items).
func _on_path(peer: int, position: Vector3) -> bool:
	var now: int = Time.get_ticks_msec()
	var cached: Array = _on_path_cache.get(peer, [])

	if not cached.is_empty() and now - int(cached[0]) < 1000:
		return bool(cached[1])

	var reach: float = float(_path_cfg.get("range_m", 3.0))
	var found: bool = false

	for id in _items:
		var other: Dictionary = _items[id]

		if other.has("struct") and str(other["struct"]["kind"]) == "path_patch" and Vector2(other["pos"].x - position.x, other["pos"].z - position.z).length() <= reach:
			found = true
			break

	_on_path_cache[peer] = [now, found]
	return found


# Effort (0 to 1) for a ground speed: straight lines through exertion.json effort_by_speed ([speed m/s, effort] pairs).
func _effort_at_speed(speed: float) -> float:
	var anchors: Array = _exertion_cfg.get("effort_by_speed", [[0.2, 0.0], [3.2, 0.5], [9.0, 1.0]])

	if speed <= float(anchors[0][0]):
		return float(anchors[0][1])

	for n in range(1, anchors.size()):
		if speed <= float(anchors[n][0]):
			var from: Array = anchors[n - 1]
			var to: Array = anchors[n]
			return lerpf(float(from[1]), float(to[1]), (speed - float(from[0])) / (float(to[0]) - float(from[0])))

	return float(anchors[anchors.size() - 1][1])


var _snow_memo: Dictionary = {}     # peer -> [the metre cell last asked about, whether its surface is snow]


# Is the ground under `position` snow or glacial ice (snow_walk.json soils)? Asked once per metre cell the player enters.
func _on_snow(peer: int, position: Vector3) -> bool:
	if not ground_material.is_valid():
		return false

	var cell: Vector2i = Vector2i(floori(position.x), floori(position.z))
	var memo: Array = _snow_memo.get(peer, [])

	if memo.is_empty() or memo[0] != cell:
		memo = [cell, SnowWalk.name_is_snow(str(ground_material.call(position.x, position.z)))]
		_snow_memo[peer] = memo

	return bool(memo[1])


func _note_motion(peer: int, position: Vector3) -> void:
	var now: int = Time.get_ticks_msec()
	var last: Array = _motion.get(peer, [])

	if not last.is_empty() and now > int(last[1]):
		var dt: float = float(now - int(last[1])) / 1000.0
		var speed: float = Vector2(position.x - last[0].x, position.z - last[0].z).length() / dt
		_speed3[peer] = lerpf(float(_speed3.get(peer, 0.0)), Vector3(position.x - last[0].x, position.y - last[0].y, position.z - last[0].z).length() / dt, clampf(dt * 2.0, 0.0, 1.0))
		var target: float = _effort_at_speed(speed)                      # standing 0, walking 0.5, running 1 (data)

		if _on_path(peer, position):
			target *= float(_path_cfg.get("exertion_factor", 1.0))   # a trodden path eases the going (data/path_speed.json)

		target *= SnowWalk.effort_mult(_on_snow(peer, position), SnowWalk.shod(worn_of(peer), table))   # snow is heavy going, snowshoes ease it (Part C plan 7)

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
	var health_max: float = float(_vitals_cfg.get("health_max", 100))
	var game_s: float = spent * GAME_RATE
	_load_cache.clear()
	_lit_valid = false
	_in_vitals = true

	if weather_now.is_valid() and float((weather_now.call() as Dictionary).get("rain", 0.0)) > 0.05:
		_last_rain_s = _now_game_s()

	for peer in _peer_key:
		var v: Dictionary = _vitals.get(_peer_key[peer], {})

		if v.is_empty():
			continue

		var crow: Dictionary = _characters.get(_peer_key[peer], {})

		if float(crow.get("grace_s", 0.0)) > 0.0:   # online time only: this loop runs for connected peers
			crow["grace_s"] = maxf(float(crow["grace_s"]) - spent, 0.0)
			_dirty = _dirty or float(crow["grace_s"]) <= 0.0

		var burn_per_day: float = float(_vitals_cfg.get("rest_kcal_per_kg_day", 22)) * float(v["weight"]) + float(_vitals_cfg.get("work_kcal_day", 1500)) * exertion_of(peer)
		var drain_mult: float = _drain_mult(peer) * float(rested_tier(peer).get("hunger_thirst_mult", 1.0))   # Rested: a little less hunger and thirst
		var burn: float = burn_per_day * game_s / 86400.0 * drain_mult
		v["fed"] = float(v["fed"]) - burn

		if float(v["fed"]) < 0.0:
			# Empty: the shortfall comes off the body.
			v["weight"] = clampf(float(v["weight"]) + float(v["fed"]) / float(_vitals_cfg.get("kcal_per_kg", 7700)), float(_vitals_cfg.get("min_weight_kg", 40)), float(_vitals_cfg.get("max_weight_kg", 150)))
			v["fed"] = 0.0

		var thirst: Dictionary = _vitals_cfg.get("thirst", {})
		var dry_per_day: float = float(thirst.get("rest_ml_day", 1000)) + float(thirst.get("work_ml_day", 1200)) * exertion_of(peer)
		v["wet"] = maxf(float(v["wet"]) - dry_per_day * game_s / 86400.0 * drain_mult, 0.0)

		_warmth_tick(peer, v, spent, game_s)
		_sick_due_tick(peer, v, game_s)
		_sick_tick(peer, v, spent, game_s)

		if float(v["fed"]) > 0.0 and float(v["wet"]) > 0.0 and float(v.get("warmth", 100.0)) >= float(_warmth_cfg.get("cold_at", 40.0)):
			var regen: float = float(_vitals_cfg.get("health_regen_per_s", 0.05))

			if _asleep.has(peer):
				regen *= 1.0 + (float(_sleep_cfg.get("regen_mult", 2.0)) - 1.0) * maxf(_sleep_quality(peer), 0.0)

			if on_good_bed(peer):
				regen *= float(_bed_cfg.get("regen_mult", 1.0))   # asleep or just lying on it

			var rested: Dictionary = rested_tier(peer)

			if not rested.is_empty():   # the Rested buff: the larger of the two, never the product (comfort spec)
				regen = maxf(regen, float(_vitals_cfg.get("health_regen_per_s", 0.05)) * float(rested.get("regen_mult", 1.0)))

			v["health"] = clampf(float(v["health"]) + regen * spent, 0.0, health_max)

		_energy_tick(peer, v, spent, game_s)
		_breath_tick(peer, v, spent)

		if float(v["health"]) <= 0.0 and kill(peer, str(_death_cause.get(peer, "drowning"))):
			continue

		_limp_tick(peer, v, spent)
		_sync_vitals(peer, false)
		_strain_tick(peer, spent)

	_in_vitals = false


# --- Sickness (Dave 2026-10-21; data/items/sickness.json) ---
# `sick` in the vitals is the game seconds of sickness left (0 = well).

func make_sick(peer: int, hours: float = -1.0, say_start: bool = true) -> void:
	var v: Dictionary = vitals_of(peer)

	if v.is_empty() or _sick_cfg.is_empty():
		return

	if say_start and float(v.get("sick", 0.0)) <= 0.0:
		_say(peer, str(_sick_cfg.get("say_start", "You feel sick.")))

	v["sick"] = maxf(float(v.get("sick", 0.0)), (hours if hours > 0.0 else float(_sick_cfg.get("duration_h", 24.0))) * 3600.0)
	_symptom_in[peer] = float(_sick_cfg.get("symptom_every_s", 90.0)) * 0.5
	_sync_sick(peer, true)
	_dirty = true


# A crippling injury (vitals.json "limp"): `limp` seconds left in the vitals, speed_share of normal speed while it lasts; it ends
# when the time runs out or health has climbed back to heal_at of the maximum.
func limp_share(peer: int) -> float:
	var cfg: Dictionary = _vitals_cfg.get("limp", {})
	return float(cfg.get("speed_share", 0.5)) if float(vitals_of(peer).get("limp", 0.0)) > 0.0 else 1.0


func _limp_tick(peer: int, v: Dictionary, spent: float) -> void:
	var left: float = float(v.get("limp", 0.0))

	if left <= 0.0:
		_sync_limp(peer, false)   # also clears a limp the client still holds after a death
		return

	var cfg: Dictionary = _vitals_cfg.get("limp", {})
	left -= spent

	if float(v["health"]) >= float(_vitals_cfg.get("health_max", 100)) * float(cfg.get("heal_at", 0.6)):
		left = 0.0

	v["limp"] = maxf(left, 0.0)

	if left <= 0.0:
		_say(peer, "Your leg has healed enough to walk on.")

	_sync_limp(peer, false)


func _sync_limp(peer: int, force: bool) -> void:
	if not send_limp.is_valid():
		return

	var percent: int = int(round(limp_share(peer) * 100.0))

	if force or int(_limp_sent.get(peer, -1)) != percent:
		_limp_sent[peer] = percent
		send_limp.call(peer, percent)


func is_sick(peer: int) -> bool:
	return float(vitals_of(peer).get("sick", 0.0)) > 0.0


func _sick_tick(peer: int, v: Dictionary, spent: float, game_s: float) -> void:
	var left: float = float(v.get("sick", 0.0))

	if left <= 0.0 or _sick_cfg.is_empty():
		return

	left -= game_s * (float(_sick_cfg.get("sleep_mult", 4.0)) if _asleep.has(peer) else 1.0)
	_symptom_in[peer] = float(_symptom_in.get(peer, float(_sick_cfg.get("symptom_every_s", 90.0)))) - spent

	if left <= 0.0:
		v["sick"] = 0.0
		_symptom_in.erase(peer)
		_say(peer, str(_sick_cfg.get("say_well", "You feel well again")))
	else:
		v["sick"] = left

		if float(_symptom_in[peer]) <= 0.0:
			_symptom_in[peer] = float(_sick_cfg.get("symptom_every_s", 90.0))
			var symptoms: Array = _sick_cfg.get("symptoms", [])

			if not symptoms.is_empty():
				var symptom: Dictionary = symptoms[int(_symptom_count(peer)) % symptoms.size()]
				v["fed"] = maxf(float(v["fed"]) - float(symptom.get("fed_kcal", 0)), 0.0)
				v["wet"] = maxf(float(v["wet"]) - float(symptom.get("wet_ml", 0)), 0.0)
				_say(peer, str(symptom.get("say", "")))
				think(peer, str(symptom.get("kind", "")))

	_sync_sick(peer, false)


var _symptoms_seen: Dictionary = {}
var _voice_cfg: Dictionary = {}
var _voice_last: Dictionary = {}    # peer -> the last inner-voice line, so it does not repeat


# The inner voice speaks: a line of `kind` goes to the player as audio id plus subtitle (design: DESIGN_IDEAS 6.14, sparing and
# never twice in a row). Returns the text.
func think(peer: int, kind: String) -> String:
	var text: String = inner_voice(peer, kind)

	if text != "" and send_thought.is_valid():
		send_thought.call(peer, voice_line_id(text), text, kind)

	return text


# A stable id for a line, so adding or reordering lines in inner_voice.json never moves a recording to the wrong text.
func voice_line_id(text: String) -> String:
	return text.md5_text().substr(0, 8)


# One inner-voice joke for a symptom kind (data/items/inner_voice.json), never the one just shown.
func inner_voice(peer: int, kind: String) -> String:
	if _voice_cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/inner_voice.json"))
		_voice_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {"none": true}

	var lines: Array = _voice_cfg.get(kind, [])

	if lines.is_empty():
		return ""

	var pick: String = str(lines[_fate_rng.randi() % lines.size()])   # luck-exempt: flavour text
	var guard: int = 0

	while pick == str(_voice_last.get(peer, "")) and lines.size() > 1 and guard < 20:
		pick = str(lines[_fate_rng.randi() % lines.size()])   # luck-exempt: flavour text
		guard += 1

	_voice_last[peer] = pick
	return pick


func _symptom_count(peer: int) -> int:
	_symptoms_seen[peer] = int(_symptoms_seen.get(peer, -1)) + 1
	return int(_symptoms_seen[peer])


# --- Clothing and equipment (data/items/clothing.json; items of kind clothing or gear with a slot) ---

func _clothing_slots() -> Array:
	if _clothing.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/clothing.json"))
		_clothing = parsed if typeof(parsed) == TYPE_DICTIONARY else {"slots": []}

	return _clothing.get("slots", [])


# The item numbers a character wears, one per body slot; old saves have none.
func worn_of(peer: int) -> Array:
	var row: Dictionary = _characters.get(_peer_key.get(peer, ""), {})
	var list: Array = row.get("worn", [])
	var out: Array = []

	for i in _clothing_slots().size():
		out.append(int(list[i]) if i < list.size() else 0)

	return out


func _clean_worn(raw: Variant) -> Array:
	var out: Array = []
	var slots: Array = _clothing_slots()

	for i in slots.size():
		var number: int = table.current_number(int(raw[i])) if typeof(raw) == TYPE_ARRAY and i < raw.size() else 0   # worn Hide leggings come back as Hide trousers
		out.append(number if number > 0 and table.id_of(number) != "" and str(table.entry(table.id_of(number)).get("slot", "")) == str(slots[i]) else 0)

	return out


# Share of body heat the worn pieces keep, 0..max_insulation (warmth.json). The `insulation_of` hook, when set, takes over.
func insulation_worn(peer: int) -> float:
	var total: float = 0.0

	for number in worn_of(peer):
		if number > 0:
			total += float(table.entry(table.id_of(number)).get("warmth", 0.0))

	return minf(total, float(_warmth_cfg.get("max_insulation", 0.85)))


# Extra kilograms a worn pack lets the body carry.
func carry_bonus_kg(peer: int) -> float:
	var total: float = 0.0

	for number in worn_of(peer):
		if number > 0:
			total += float(table.entry(table.id_of(number)).get("carry_bonus_kg", 0.0))

	return total


# The body weight the carry limit is worked out from: the real weight plus what the worn pack adds (cap = ratio x body).
func _carry_body(peer: int) -> float:
	var ratio: float = maxf(float(_carry_cfg.get("carry_kg_per_body_kg", 0.7)), 0.01)
	return float(vitals_of(peer).get("weight", 75.0)) + carry_bonus_kg(peer) / ratio


func _wear(peer: int, inv, slot: int) -> void:
	if slot < 0 or slot >= inv.SLOTS or inv.numbers[slot] == 0 or not _characters.has(_peer_key.get(peer, "")):
		return

	var number: int = inv.numbers[slot]
	var place: int = _clothing_slots().find(str(table.entry(table.id_of(number)).get("slot", "")))

	if place < 0:
		_say(peer, "You cannot wear that.")
		return

	var worn: Array = worn_of(peer)
	var old: int = int(worn[place])
	inv.take_from_slot(slot, 1)

	if old > 0 and inv.add(old, 1) > 0:
		inv.add(number, 1)
		_reject(peer, 0)
		return

	worn[place] = number
	_characters[_peer_key[peer]]["worn"] = worn
	_dirty = true
	_sync_worn(peer, true)


func _unwear(peer: int, inv, place: int) -> void:
	var worn: Array = worn_of(peer)

	if place < 0 or place >= worn.size() or int(worn[place]) == 0 or not _characters.has(_peer_key.get(peer, "")):
		return

	if inv.add(int(worn[place]), 1) > 0:
		_reject(peer, 0)
		return

	worn[place] = 0
	_characters[_peer_key[peer]]["worn"] = worn
	_dirty = true
	_sync_worn(peer, true)


func _sync_worn(peer: int, force: bool) -> void:
	if not send_worn.is_valid() or not _peer_key.has(peer):
		return

	var numbers: PackedInt32Array = PackedInt32Array(worn_of(peer))

	if force or _worn_sent.get(peer, PackedInt32Array()) != numbers:
		_worn_sent[peer] = numbers
		send_worn.call(peer, numbers)


func _sync_sick(peer: int, force: bool) -> void:
	if not send_sick.is_valid():
		return

	var hours: int = int(ceil(float(vitals_of(peer).get("sick", 0.0)) / 3600.0))

	if force or int(_sick_sent.get(peer, -1)) != hours:
		_sick_sent[peer] = hours
		send_sick.call(peer, hours)


# --- Warmth (job 92; data/items/warmth.json) ---

# The positions of the burning fires. Inside one _vitals_tick they are listed once for all players (the soak test found warmth
# scanning every world record per player); anywhere else the scan is live.
func _lit_fires() -> Array:
	var found: Array = []
	var now: int = Time.get_ticks_msec()

	for peer in _torch_seen:      # a bearer of a burning torch keeps wolves off like a small fire
		if now - int(_torch_seen[peer]) <= TORCH_REPORT_MS and _peer_pos.has(peer):
			found.append(_peer_pos[peer])

	for row in _lit_rows():
		found.append(row[0])

	for row in _guard_rows():   # a lit torch post or other placed light with protect_m keeps them off too (buildables plan, batch B4)
		found.append(row[0])

	return found


# How far wolves keep from the lit fire at this spot: its tier's protect_m (cooking.json fire_tiers; 10 m when unknown).
func fire_protect_m(at: Vector3) -> float:
	for peer in _torch_seen:
		if _peer_pos.has(peer) and (_peer_pos[peer] as Vector3).is_equal_approx(at):
			return TORCH_PROTECT_M

	for row in _lit_rows():
		if (row[0] as Vector3).is_equal_approx(at):
			return float(((_cooking.get("fire_tiers", {}) as Dictionary).get(_fire_class_of_state(int(row[1])), {}) as Dictionary).get("protect_m", 10.0))

	for row in _guard_rows():
		if (row[0] as Vector3).is_equal_approx(at):
			return float(row[1])

	return 10.0


var _lit_valid: bool = false
var _rain_rng: RandomNumberGenerator = RandomNumberGenerator.new()


# [position, lit state] of every burning fire (warmth reads the tier's heat and reach from cooking.json fire_tiers). Cached inside one vitals tick.
var _lit_cache_rows: Array = []


func _lit_rows() -> Array:
	if _in_vitals and _lit_valid:
		return _lit_cache_rows

	var found: Array = []
	_coal_cache_rows = []
	_guard_cache_rows = []

	for id in _items:
		var it: Dictionary = _items[id]

		if it.has("fire") and fire_is_lit(int(it["fire"]["state"])):
			found.append([it["pos"], int(it["fire"]["state"])])
		elif it.has("fire") and int(it["fire"]["state"]) == FIRE_STATE_COALS:
			_coal_cache_rows.append(it["pos"])
		elif it.has("struct") and bool(it["struct"].get("lit", false)) and float(_structures.get(str(it["struct"]["kind"]), {}).get("protect_m", 0.0)) > 0.0:
			_guard_cache_rows.append([it["pos"], float(_structures[str(it["struct"]["kind"])]["protect_m"])])

	if _in_vitals:
		_lit_cache_rows = found
		_lit_valid = true

	return found


# The positions of glowing coals (state 76): they warm coals.heat_c within coals.heat_m and keep nothing off. The same scan as _lit_rows.
var _coal_cache_rows: Array = []
var _guard_cache_rows: Array = []   # [position, protect_m] of every lit placed light whose structures.json row has protect_m (the same scan)


func _guard_rows() -> Array:
	if not (_in_vitals and _lit_valid):
		_lit_rows()

	return _guard_cache_rows


func _coal_rows() -> Array:
	if not (_in_vitals and _lit_valid):
		_lit_rows()

	return _coal_cache_rows


# The warmth the body is heading for here and now: 100 on a mild day, less as the cold stress grows.
func warmth_target(peer: int) -> float:
	var cfg: Dictionary = _warmth_cfg
	var weather: Dictionary = weather_now.call() if weather_now.is_valid() else {}
	var pos: Vector3 = _peer_pos.get(peer, Vector3.ZERO)
	var covered: bool = cover_at.is_valid() and float(cover_at.call(pos)) > 0.5
	var cave_c: float = float(cave_mean_c.call(pos)) if cave_mean_c.is_valid() else NAN
	# The weather's temp_c already carries the day and night swing (one temperature, docs/design/one_temperature.md); the server's weather is
	# at sea level, so the height is taken off here.
	var air: float = float(weather.get("temp_c", float(cfg.get("comfort_c", 15.0)))) - maxf(pos.y, 0.0) * float(cfg.get("lapse_c_per_m", 0.0065))
	var roofed: bool = cover_at.is_valid() and float(cover_at.call(pos)) > 1.5
	var wind: float = float(weather.get("wind", 0.0)) * (float(cfg.get("covered_wind_share", 0.3)) if roofed else 1.0)

	# In a cave (Jamie's caves page, #664): the air sits at the island's year mean for its height (cave_mean_c, Climate.year_mean_c), with no
	# day and night swing and no rain cooling, and no wind reaches in.
	if not is_nan(cave_c):
		var mouth_air: Dictionary = _cave_mouth_air(pos, air)   # in from the mouth the outside air still reaches, with a small draught (#709)
		wind = float(mouth_air.get("wind", 0.0))
		air = float(mouth_air.get("air_c", cave_c))
	var feels: float = air - wind * float(cfg.get("wind_chill_c", 6.0))
	var radius: float = float(cfg.get("fire_radius_m", 4.0))

	var heat: float = 0.0
	var tiers: Dictionary = _cooking.get("fire_tiers", {})

	for row in _lit_rows():
		var tier_row: Dictionary = tiers.get(_fire_class_of_state(int(row[1])), {})
		var reach: float = float(tier_row.get("heat_radius_m", radius))

		if (row[0] as Vector3).distance_to(pos) <= reach:
			heat = maxf(heat, float(tier_row.get("heat_c", cfg.get("fire_c", 20.0))))

	var coals: Dictionary = _coals_cfg()

	for at in _coal_rows():
		if (at as Vector3).distance_to(pos) <= float(coals.get("heat_m", 1.5)):
			heat = maxf(heat, float(coals.get("heat_c", 8.0)))

	feels += heat

	var stress: float = maxf(float(cfg.get("comfort_c", 15.0)) - feels, 0.0)

	if on_good_bed(peer):
		stress *= 1.0 - float(_bed_cfg.get("warmth_bonus", 0.0))
	elif (_asleep.has(peer) or int(_stance.get(peer, 0)) == 3) and _has_bedroll(peer):
		stress *= 1.0 - float(_sleep_cfg.get("bedroll", {}).get("warmth_bonus", 0.0))   # rolled up in it: half a bed's warmth
	stress *= float(rested_tier(peer).get("cold_stress_mult", 1.0))   # Rested: the cold bites a little less
	var precip: float = maxf(float(weather.get("rain", 0.0)), float(weather.get("snow", 0.0)))

	# Wet from rain or snow (Dave 5 Nov, rain card: "Rain x1.5"; only shelter dries you, slowly under a tree or roof, fast by a fire): the chill follows
	# how soaked the player is (_update_soak), not only the rain falling this moment. A peer the tick has not seen yet uses the rain falling now.
	var soak: float = float(_soak[peer]) if _soak.has(peer) else (minf(precip * 2.0, 1.0) if precip > 0.05 and not covered else 0.0)

	var body: Dictionary = _body_cfg()

	if soak > 0.0:
		# Wet plus wind is what kills (docs/design/body_in_weather_design.md 3): the wind pumps through wet cloth.
		stress *= 1.0 + (float(cfg.get("rain_mult", 1.5)) - 1.0) * soak + float(body.get("wet_wind_gain", 0.0)) * soak * wind

	var insulation: float = clampf(float(insulation_of.call(peer)) if insulation_of.is_valid() else insulation_worn(peer), 0.0, float(cfg.get("max_insulation", 0.85)))

	if not body.is_empty():
		# Soaked in a gale, clothes keep a tenth of their insulation (Pugh, Four Inns 1964: "nearly nothing").
		insulation *= 1.0 - float(body.get("wet_strip", 0.9)) * soak * minf(wind / maxf(float(body.get("wet_strip_wind", 0.6)), 0.01), 1.0)

	if bool(_swimming.get(peer, false)):
		# In the water the cold follows the WATER's temperature, not the air's (Tyler): a lagged, damped copy of the air at sea level.
		var sea_air: float = float(weather.get("temp_c", float(cfg.get("comfort_c", 15.0))))
		var water_c: float = maxf(float(cfg.get("water_base_c", 6.0)) + float(cfg.get("water_follow", 0.5)) * (sea_air - float(cfg.get("water_base_c", 6.0))), 1.0)

		if bool(_cave_pool.get(peer, false)):
			water_c = cave_c if not is_nan(cave_c) else float(cfg.get("cave_pool_c", 2.0))   # a cave pool is at the cave air's year mean (Jamie #664, CONTRADICTIONS.md), not the weather (BUG-008)
		stress = maxf(float(cfg.get("water_comfort_c", 26.0)) - water_c, 0.0) * float(cfg.get("water_gain", 5.0)) / maxf(float(cfg.get("gain", 3.0)), 0.01)

	return clampf(100.0 - stress * float(cfg.get("gain", 3.0)) * (1.0 - insulation), 0.0, 100.0)


func _warmth_tick(peer: int, v: Dictionary, spent: float, game_s: float) -> void:
	if _warmth_cfg.is_empty():
		return

	var cfg: Dictionary = _warmth_cfg
	_update_soak(peer, game_s)
	var w: float = float(v.get("warmth", 100.0))
	var target: float = warmth_target(peer)
	var tau_h: float = float(cfg.get("tau_warm_h", 0.5)) if target > w else (float(cfg.get("tau_water_h", 0.7)) if bool(_swimming.get(peer, false)) else float(cfg.get("tau_cool_h", 3.0)))
	w += (target - w) * (1.0 - exp(-(game_s / 3600.0) / maxf(tau_h, 0.01)))
	w = clampf(w, 0.0, 100.0)
	v["warmth"] = w
	var hurt_at: float = float(cfg.get("hurt_at", 20.0))

	if w < hurt_at:
		# Cold costs health, slowly, more the colder; like hunger it stops at 1.
		var severe_mult: float = float(_body_cfg().get("severe_hurt_mult", 2.0)) if cold_stage(peer) == 3 else 1.0   # severe cold (docs/design/body_in_weather_design.md 4)
		v["health"] = maxf(float(v["health"]) - float(cfg.get("hurt_per_s", 0.15)) * spent * (hurt_at - w) / maxf(hurt_at, 1.0) * 2.0 * severe_mult, 1.0)

	# Messages with two levels each way, so a player on the edge is not nagged; with body_703 on, a third for severe cold.
	var level: int = int(_cold_level.get(peer, 0))
	var body: Dictionary = _body_cfg()

	if not body.is_empty() and level < 3 and w < float(body.get("severe_at", 8.0)):
		_cold_level[peer] = 3
		_say(peer, str(body.get("say_severe", "You have stopped shivering. Get to a fire, now.")))
	elif level == 3 and w >= float(body.get("severe_clear", 14.0)):
		_cold_level[peer] = 2
	elif level < 2 and w < hurt_at:
		_cold_level[peer] = 2
		_say(peer, str(cfg.get("say_freezing", "You are freezing")))
	elif level == 0 and w < float(cfg.get("cold_at", 40.0)):
		_cold_level[peer] = 1
		_say(peer, str(cfg.get("say_cold", "You are getting cold")))
	elif level == 2 and w >= float(cfg.get("hurt_clear", 32.0)):
		_cold_level[peer] = 1
	elif level == 1 and w >= float(cfg.get("cold_clear", 52.0)):
		_cold_level[peer] = 0
		_say(peer, str(cfg.get("say_warm", "You feel warm again")))

	_sync_warmth(peer, false)


# The air in a cave at this point (docs/design/cave_climate_design.md; Jamie #709, coordinator 8 Nov 2026): {"air_c", "wind" (0..1, the mouth's
# draught), "dry_share"} blended in from the mouth by warmth.json cave_climate; without cave_climate (or the cave_air callable) the flat cave of #667: the year
# mean, no wind, no drying. outside_c is the day's air at the point as warmth_target works it out.
func _cave_mouth_air(pos: Vector3, outside_c: float) -> Dictionary:
	var deep: float = float(cave_mean_c.call(pos)) if cave_mean_c.is_valid() else NAN
	var at: Dictionary = cave_air.call(pos) if cave_air.is_valid() else {}
	var cfg: Dictionary = _warmth_cfg.get("cave_climate", {})

	if is_nan(deep) or at.is_empty() or cfg.is_empty():
		return {"air_c": deep, "wind": 0.0, "dry_share": 0.0}

	var depth: float = float(at.get("depth_m", INF))
	return {"air_c": CaveClimate.air_c(cfg, outside_c, float(at.get("day_part_c", 0.0)), deep, depth, int(at.get("kind", CaveClimate.LEVEL))),
		"wind": CaveClimate.wind_of_ms(CaveClimate.draught_ms(cfg, outside_c, deep, depth)), "dry_share": CaveClimate.dry_share(cfg, outside_c, deep, depth)}


# The body in weather (docs/design/body_in_weather_design.md; Jamie #703, coordinator 8 Nov 2026): warmth.json body_703 when its flag is on, else empty,
# and every reader falls back to today's numbers.
func _body_cfg() -> Dictionary:
	var body: Variant = _warmth_cfg.get("body_703", {})
	return body if typeof(body) == TYPE_DICTIONARY and bool(body.get("enabled", false)) else {}


# The cold stage on the warmth bar: 0 fine, 1 mild (under cold_at), 2 moderate (under hurt_at), 3 severe (under body_703 severe_at, flag on only).
func cold_stage(peer: int) -> int:
	if _warmth_cfg.is_empty():
		return 0

	var w: float = float(vitals_of(peer).get("warmth", 100.0))
	var body: Dictionary = _body_cfg()

	if not body.is_empty() and w < float(body.get("severe_at", 8.0)):
		return 3

	if w < float(_warmth_cfg.get("hurt_at", 20.0)):
		return 2

	return 1 if w < float(_warmth_cfg.get("cold_at", 40.0)) else 0


# How many times as long an action takes in the cold (body_703 moderate_pace and severe_pace; 1 with the flag off). Nothing is refused, so a
# freezing player can still light a fire, only slowly.
func cold_pace(peer: int) -> float:
	var body: Dictionary = _body_cfg()

	if body.is_empty():
		return 1.0

	match cold_stage(peer):
		3:
			return maxf(float(body.get("severe_pace", 2.5)), 1.0)
		2:
			return maxf(float(body.get("moderate_pace", 1.5)), 1.0)

	return 1.0


# Rain or snow on an uncovered player soaks them toward the rain's strength (soak_per_h), swimming soaks them through; out of it they dry only in shelter:
# slowly under a tree or roof (dry_cover_per_h), fast within reach of a lit fire (dry_fire_per_h); in the open they stay wet, and in a cave
# (cover from the rain, but air near saturated) only a fire dries them.
func _update_soak(peer: int, game_s: float) -> void:
	var cfg: Dictionary = _warmth_cfg
	var weather: Dictionary = weather_now.call() if weather_now.is_valid() else {}
	var pos: Vector3 = _peer_pos.get(peer, Vector3.ZERO)
	var covered: bool = cover_at.is_valid() and float(cover_at.call(pos)) > 0.5
	var precip: float = maxf(float(weather.get("rain", 0.0)), float(weather.get("snow", 0.0)))
	var soak: float = float(_soak.get(peer, 0.0))
	var in_cave: bool = cave_mean_c.is_valid() and not is_nan(float(cave_mean_c.call(pos)))
	var hours: float = game_s / 3600.0

	var by_fire: bool = false
	var tiers: Dictionary = _cooking.get("fire_tiers", {})

	for row in _lit_rows():   # within a lit fire's heat reach, as warmth_target counts it
		var tier_row: Dictionary = tiers.get(_fire_class_of_state(int(row[1])), {})

		if (row[0] as Vector3).distance_to(pos) <= float(tier_row.get("heat_radius_m", cfg.get("fire_radius_m", 4.0))):
			by_fire = true
			break

	if bool(_swimming.get(peer, false)):
		soak = 1.0   # in the water: soaked through
	elif precip > 0.05 and not covered:
		soak = minf(soak + float(cfg.get("soak_per_h", 4.0)) * hours, maxf(soak, minf(precip * 2.0, 1.0)))
	elif by_fire:   # body_703 on: wool by a fire dries in hours, not minutes (docs/design/body_in_weather_design.md 2)
		soak = maxf(soak - float(_body_cfg().get("dry_fire_per_h", cfg.get("dry_fire_per_h", 6.0))) * hours, 0.0)
	elif covered and not in_cave:
		soak = maxf(soak - float(_body_cfg().get("dry_cover_per_h", cfg.get("dry_cover_per_h", 1.0))) * hours, 0.0)
	elif in_cave:
		# Cave air past the mouth is 98 to 100% wet: only a fire dries you there (#664); a winter mouth's dry incoming air dries at half (#709).
		var outside: float = float(weather.get("temp_c", float(cfg.get("comfort_c", 15.0)))) - maxf(pos.y, 0.0) * float(cfg.get("lapse_c_per_m", 0.0065))
		var share: float = float(_cave_mouth_air(pos, outside).get("dry_share", 0.0))
		soak = maxf(soak - float(_body_cfg().get("dry_cover_per_h", cfg.get("dry_cover_per_h", 1.0))) * share * hours, 0.0)

	_soak[peer] = soak


func _sync_warmth(peer: int, force: bool) -> void:
	if not send_warmth.is_valid():
		return

	var pct: int = int(ceil(clampf(float(vitals_of(peer).get("warmth", 100.0)), 0.0, 100.0)))

	if force or int(_warmth_sent.get(peer, -1)) != pct:
		_warmth_sent[peer] = pct
		send_warmth.call(peer, pct)


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


# The air inside a cold store (root cellar; item_system.md D1, Sonny): the ground from about 2 m down holds the site's year-mean air all year, so
# the cellar sits at Climate.year_mean_c for its height; in a cave cell it is the cave air's year mean (cave_mean_c, 5.5 C at cave 8002, #717).
# NAN when neither is known (a test without the callables): the store then spoils like a plain chest.
func cold_store_c(pos: Vector3) -> float:
	var cave_c: float = float(cave_mean_c.call(pos)) if cave_mean_c.is_valid() else NAN

	if not is_nan(cave_c):
		return cave_c

	return float(year_mean_at.call(pos)) if year_mean_at.is_valid() else NAN


# On opening a cold store: how cool it is inside and how much longer food keeps there than in the pack.
func _say_cold_store(peer: int, id: int) -> void:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not it.has("struct") or not bool(_structures.get(str(it["struct"]["kind"]), {}).get("cold_store", false)):
		return

	var cold_c: float = cold_store_c(it["pos"])

	if is_nan(cold_c):
		return

	var cold_mult: float = cold_store_mult(table.spoilage().get("cold_store", {}), cold_c)
	_say(peer, "It is %d C in here all year. Food keeps about %d times as long as in a pack." % [roundi(cold_c), roundi(1.0 / cold_mult)])


# How fast food spoils at `temp_c` against the pack's rate (spoilage.json cold_store): q10 for every 10 C below ref_c, never under min_mult and
# never above 1 (a warm cellar is no worse than a pack).
static func cold_store_mult(cold_cfg: Dictionary, temp_c: float) -> float:
	var q10: float = float(cold_cfg.get("q10", 3.0))
	var ref_c: float = float(cold_cfg.get("ref_c", 20.0))
	return clampf(pow(q10, (temp_c - ref_c) / 10.0), float(cold_cfg.get("min_mult", 0.1)), 1.0)


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
	var pos_of_uid: Dictionary = {}

	for id in _items:
		if _items[id].has("struct") and _items[id]["struct"].has("uid"):
			kind_of_uid[int(_items[id]["struct"]["uid"])] = str(_items[id]["struct"]["kind"])
			pos_of_uid[int(_items[id]["struct"]["uid"])] = _items[id]["pos"]

	var place_units: Dictionary = {}

	for uid in _chests:
		var kind: String = str(kind_of_uid.get(uid, "chest"))

		# A cold store (root cellar, item_system.md D1) keeps the ground's year-round temperature, so the season does not reach it: its rate
		# follows that temperature alone. Cellars at the same temperature share one running fraction.
		if bool(_structures.get(kind, {}).get("cold_store", false)) and pos_of_uid.has(uid):
			var cold_c: float = cold_store_c(pos_of_uid[uid])

			if not is_nan(cold_c):
				var cold_mult: float = cold_store_mult(cfg.get("cold_store", {}), cold_c)
				kind = "cold@%.2f" % cold_mult

				if not place_units.has(kind):
					place_units[kind] = _spoil_units(kind, base * cold_mult, 1.0)

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


# The character level the novice grace reads (death.json novice_grace.metric): 'best_skill' is the highest effective skill value (what the skills page shows; 1 at the start, 100 at
# the top), 'skill_total' the sum over all skills of (value - 1).
func character_level(peer: int) -> int:
	var records: Dictionary = _skill_records(peer)
	var metric: String = str(_death_cfg.get("novice_grace", {}).get("metric", "best_skill"))
	var best: float = 1.0
	var total: float = 0.0

	for id in _skills_cfg.get("skills", {}):
		var value: float = SkillWeb.effective(_skills_cfg, str(id), records)
		best = maxf(best, value)
		total += value - 1.0

	return int(floor(total)) if metric == "skill_total" else int(floor(best))


# True while this character still respawns at the bed after dying (the novice grace); false = real death. Mode 'always' (the default) is the old behaviour for everyone.
func novice_grace(peer: int) -> bool:
	var rule: Dictionary = _death_cfg.get("novice_grace", {})
	var mode: String = str(rule.get("mode", "always"))

	if mode == "never":
		return false

	if mode == "level":
		return character_level(peer) < int(rule.get("level", 5))

	return true   # 'always', and 'heir' until children exist


# The character dies. Returns false when there is nobody to kill (no such player, no position yet, death switched off).
func kill(peer: int, cause: String) -> bool:
	var key: String = str(_peer_key.get(peer, ""))
	var inv = inventory_of(peer)

	if key == "" or inv == null or not _peer_pos.has(peer) or _death_cfg.is_empty() or not _structures.has("remains"):
		return false

	_characters[key].erase("rested")   # death ends the Rested buff
	_rest_credit.erase(peer)
	var pos: Vector3 = _peer_pos[peer]
	var ground: float = float(ground_height.call(pos.x, pos.z)) if ground_height.is_valid() else NAN
	var cave: bool = not is_nan(ground) and pos.y < ground - 1.5   # underground: keep the spot, the surface above is not theirs
	var spot: Vector3 = pos if (is_nan(ground) or cave) else Vector3(pos.x, ground, pos.z)
	_trim_owner_remains(key, peer)
	var uid: int = _next_uid
	_next_uid += 1
	var chest = InventoryScript.new(table)
	chest.from_json_array(inv.to_json_array())
	_chests[uid] = chest
	_items[_next_id] = {"number": table.number_of("remains"), "count": 1, "pos": spot, "left": 1.0e9, "struct": {"kind": "remains", "yaw": float(randi() % 360), "uid": uid, "owner": key, "born": _unix(), "cave": cave, "coins": coins_of(peer)}}   # luck-exempt: a body's facing
	_next_id += 1
	inv.from_json_array(InventoryScript.new(table).to_json_array())
	send_full.call(peer, inv.to_bytes())
	_send_favs(peer, inv)

	sync_shoulder(peer)   # the log in the pack went with the remains

	# Dave 2026-10-21: the purse stays on the body, so the whole purse lies with the remains and is found like the other things.
	if _characters.has(key):
		_characters[key]["coins"] = 0
		sync_purse(peer)

	_sync_remains(peer, true)

	# Start over: vitals, strain, sleep, breath. Luck, fitness and skills live in characters.json and stay.
	_vitals[key] = _new_vitals()
	_strain.erase(peer)
	_strain_sent.erase(peer)
	_asleep.erase(peer)
	_waking.erase(peer)
	_body_sent.erase(peer)
	_breath.erase(peer)
	_suffocate.erase(peer)
	_head_under.erase(peer)
	_exertion[peer] = 0.0
	_stance[peer] = 0
	_work_until.erase(peer)
	_death_cause.erase(peer)
	_energy_sent.erase(peer)
	_warmth_sent.erase(peer)
	_sick_sent.erase(peer)
	_limp_sent.erase(peer)
	_symptom_in.erase(peer)
	_cold_level.erase(peer)
	_fishing.erase(peer)
	_hole_blows.erase(peer)
	if not novice_grace(peer):
		_characters[key]["final_death_pending"] = true   # real death: the remains stay; the new-character / heir flow is not built, so the character still comes back below

		if send_final_death.is_valid():
			send_final_death.call(peer, cause)

			if bool(_death_cfg.get("real_death", false)):   # the character does not come back (Dave's cards pending: off by default)
				_characters[key]["dead"] = true
				_dirty = true
				return true

	var back: Vector3 = respawn_for(peer, true)
	_peer_pos[peer] = back
	_motion.erase(peer)
	_sync_breath(peer, -1)
	_sync_vitals(peer, true)
	_dirty = true

	if send_died.is_valid():
		send_died.call(peer, cause, back)

	if back != respawn_point:
		_say(peer, "You come back at your shelter")

	return true


# One character cannot litter the world: with per_owner_cap sets already out, the emptiest-then-oldest goes first to make room for the new one.
func _trim_owner_remains(key: String, peer: int = -1) -> void:
	var cap: int = int(_death_cfg.get("per_owner_cap", 5))
	var mine: Array = []

	for id in remains_ids():
		if str(_items[id]["struct"].get("owner", "")) == key:
			mine.append(id)

	while mine.size() >= cap and cap > 0:
		var drop: int = -1

		for id in mine:
			var chest = _chests.get(int(_items[id]["struct"].get("uid", 0)))
			var empty: bool = chest == null or chest.is_empty()
			var older: bool = drop < 0 or float(_items[id]["struct"].get("born", 0.0)) < float(_items[drop]["struct"].get("born", 0.0))
			var drop_empty: bool = drop >= 0 and (_chests.get(int(_items[drop]["struct"].get("uid", 0))) == null or _chests[int(_items[drop]["struct"].get("uid", 0))].is_empty())

			if drop < 0 or (empty and not drop_empty) or (empty == drop_empty and older):
				drop = id

		var lost_chest = _chests.get(int(_items[drop]["struct"].get("uid", 0)))

		if peer >= 0 and lost_chest != null and not lost_chest.is_empty():
			_say(peer, "Your oldest remains crumble to make room. What was on them is lost.")

		_chests.erase(int(_items[drop]["struct"].get("uid", 0)))
		_items.erase(drop)
		mine.erase(drop)
		_dirty = true


# The owner's death markers (protocol 39): every set of their remains that still holds something, with the seconds until it is cleaned up.
func _remains_rows(key: String) -> Array:
	var rows: Array = []
	var gone_s: float = float(_death_cfg.get("gone_s", 604800))

	for id in remains_ids():
		var it: Dictionary = _items[id]

		if str(it["struct"].get("owner", "")) != key:
			continue

		var chest = _chests.get(int(it["struct"].get("uid", 0)))

		if chest == null or chest.is_empty():
			continue

		rows.append([it["pos"], maxi(int(gone_s - (_unix() - float(it["struct"].get("born", 0.0)))), 0)])

	return rows


func _sync_remains(peer: int, force: bool) -> void:
	if not send_remains.is_valid() or not _peer_key.has(peer):
		return

	var rows: Array = _remains_rows(str(_peer_key[peer]))
	var shape: Array = []

	for row in rows:
		shape.append(row[0])

	if not force and _remains_sent.get(peer, []) == shape:
		return

	_remains_sent[peer] = shape
	send_remains.call(peer, rows)


# Once in a while: clean up remains that have run their seven days and put the others back on the surface when the ground
# under them has changed (digging, a fill). The record never moves anywhere else; the sinking is only a drawing offset.
func _remains_tick(spent: float) -> void:
	_remains_check_in -= spent

	if _remains_check_in > 0.0 or _death_cfg.is_empty():
		return

	_remains_check_in = float(_death_cfg.get("recheck_s", 30))
	var gone_s: float = float(_death_cfg.get("gone_s", 604800))

	for peer in _peer_key:
		_sync_remains(peer, false)

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
	practice(peer, "fall", clampf(drop / maxf(safe_m, 1.0), 0.2, 2.0))
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


# Crafting stations (structures.json "station", "station_level", "reach_m"): a placed structure of that station within reach of the
# player. The server measures the distance with 1 m of grace so lag never fails a craft; the client only displays (Tyler).
func station_near(peer: int, station: String, level: int = 1) -> bool:
	return serving_station(peer, station, level) >= 0


# The world id of the nearest placed station that serves `station` at `level` and is working (a lit fire; a pot over a lit fire), within its
# own reach (station_near) or, with `far_m` above it, within far_m (the crafting reach: _step_to_station); -1 when none.
func serving_station(peer: int, station: String, level: int = 1, far_m: float = 0.0) -> int:
	if not _peer_pos.has(peer):
		return -1

	var here: Vector3 = _peer_pos[peer]
	var best: int = -1
	var best_d: float = INF

	if station == "campfire":   # dishes are cooked at a lit campfire (data/items/dishes.json); a clay hearth or an oven beside you cooks them too ("also" in structures.json)
		for id in _items:
			var fire_item: Dictionary = _items[id]
			var d: float = here.distance_to(fire_item["pos"])

			if fire_item.has("fire") and fire_is_lit(int(fire_item["fire"]["state"])) and d <= maxf(FIRE_USE_M + 1.0, far_m) and d < best_d:
				best = int(id)
				best_d = d

	for id in _items:
		var it: Dictionary = _items[id]

		if not it.has("struct"):
			continue

		var def: Dictionary = _structures.get(str(it["struct"]["kind"]), {})
		var d: float = here.distance_to(it["pos"])

		if d > maxf(float(def.get("reach_m", 3.0)) + 1.0, far_m) or d >= best_d:
			continue

		if station_level_of(it, def, station) >= level:
			if str(def.get("attach_to", "")) == "fire" and not _lit_fire_within(it["pos"], POT_ON_FIRE_M):
				continue   # the pot hangs over its fire: with that fire out nothing cooks, the craft waits where it is and nothing is lost

			best = int(id)
			best_d = d

	return best


var _step_cfg: Dictionary = {}   # data/items/station_step.json, read on the first step


# Dave 10 Nov 2026: a station recipe crafted from the pack with its station in the crafting reach but not beside you moves you to the station.
# Directly in front of it (its +Z turned by its yaw; a fire: the side you came from), facing it; another player there: to one side, then
# behind. Returns the spot. The client is told (send_step_to) and the server's position is the spot at once, so the station check passes.
func _step_to_station(peer: int, station_id: int) -> Vector3:
	if _step_cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/station_step.json")) if FileAccess.file_exists("res://data/items/station_step.json") else null
		_step_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {"_read": true}

	var it: Dictionary = _items[station_id]
	var centre: Vector3 = it["pos"]
	var front: Vector3

	if it.has("struct") and not it.has("fire"):
		var yaw: float = deg_to_rad(float(it["struct"].get("yaw", 0.0)))
		front = Vector3(sin(yaw), 0.0, cos(yaw)) * float(_step_cfg.get("front_m", 1.3))   # the model's front: Godot's +Z (Vector3.MODEL_FRONT) turned by the yaw
	else:
		var from: Vector3 = Vector3(_peer_pos[peer].x - centre.x, 0.0, _peer_pos[peer].z - centre.z)
		front = (from.normalized() if from.length() > 0.01 else Vector3.BACK) * float(_step_cfg.get("fire_m", 1.5))

	var side: Vector3 = front.normalized().cross(Vector3.UP) * float(_step_cfg.get("side_m", 1.4))
	var spot: Vector3 = centre + front

	for candidate in [centre + front, centre + front.normalized() * front.length() + side, centre + front.normalized() * front.length() - side, centre - front]:
		if not _player_within(candidate, float(_step_cfg.get("clear_m", 0.9)), peer):
			spot = candidate
			break

	if ground_height.is_valid():
		spot.y = float(ground_height.call(spot.x, spot.z))

	_peer_pos[peer] = spot
	var look: Vector3 = centre - spot
	var yaw_to: float = atan2(-look.x, -look.z)   # the client's body.rotation.y facing the station (Godot looks down -Z)

	if send_step_to.is_valid():
		send_step_to.call(peer, spot, yaw_to)

	return spot


# Another player stands within `radius` (on the ground plane) of a point.
func _player_within(point: Vector3, radius: float, but: int) -> bool:
	for other in _peer_pos:
		if int(other) != but and Vector2(_peer_pos[other].x - point.x, _peer_pos[other].z - point.z).length() <= radius:
			return true

	return false


# Is a lit fire (any tier) within r metres of a point?
# A seat piece (comfort class seat) within 1.2 m horizontally and 1 m vertically.
func _seat_near(pos: Vector3) -> bool:
	for id in _items:
		var it: Dictionary = _items[id]

		if it.has("struct") and Vector2(it["pos"].x - pos.x, it["pos"].z - pos.z).length() <= 1.2 and absf(it["pos"].y - pos.y) <= 1.0:
			var skind: String = str(it["struct"].get("kind", ""))

			if str(_comfort_kind(str(_structures.get(skind, {}).get("comfort", skind))).get("class", "")) == "seat":
				return true

	return false


func _lit_fire_within(pos: Vector3, r: float) -> bool:
	for row in _lit_rows():
		if (row[0] as Vector3).distance_to(pos) <= r:
			return true

	return false


# What level this placed structure gives for a station (0 = none): its own station at station_level plus one per add-on kind
# beside it, or an "also" station it carries whole (the large and epic stations are a forge and a bench in one; Dave 2026-10-21).
func station_level_of(it: Dictionary, def: Dictionary, station: String) -> int:
	if str(def.get("station", "")) == station:
		return int(def.get("station_level", 1)) + _addon_kinds(it, def, station)

	return int(def.get("also", {}).get(station, 0))


# How many different add-on kinds (structures.json addon_of) stand within addon_reach_m of a station: each raises its level by one.
func _addon_kinds(station_row: Dictionary, def: Dictionary, station: String) -> int:
	var kinds: Dictionary = {}
	var reach: float = float(def.get("addon_reach_m", 5.0))

	for id in _items:
		var other: Dictionary = _items[id]

		if not other.has("struct"):
			continue

		var kind: String = str(other["struct"]["kind"])

		if str(_structures.get(kind, {}).get("addon_of", "")) == station and station_row["pos"].distance_to(other["pos"]) <= reach:
			kinds[kind] = true

	return kinds.size()


# --- Fishing (data/items/fishing.json, Tyler's model: no fish entities, a roll per cast) ---

func _fishing_data() -> Dictionary:
	if _fishing_cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/fishing.json"))
		_fishing_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {"none": true}

	return _fishing_cfg


func _fish_cell(pos: Vector3) -> Vector2i:
	var size: float = float(_fishing_data().get("cell_m", 128.0))
	return Vector2i(int(floor(pos.x / size)), int(floor(pos.z / size)))


func _cell_hash(cell: Vector2i) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663))


# Fish left in a cell of water: the hidden stock, which comes back one fish per regrow_s up to the cell's own best.
func fish_stock(cell: Vector2i) -> int:
	var cfg: Dictionary = _fishing_data()
	var best: int = mini(int(cfg.get("stock_base", 4)) + _cell_hash(cell) % maxi(int(cfg.get("stock_extra", 8)), 1), int(cfg.get("stock_max", 12)))
	var key: String = "%d,%d" % [cell.x, cell.y]
	var row: Array = _fish_stock.get(key, [best, _unix()])
	var regrow_s: float = float(cfg.get("regrow_s", 3600.0))

	if water_kind_at.is_valid() and cfg.has("regrow_s_sea"):
		var size: float = float(cfg.get("cell_m", 128.0))

		if str(water_kind_at.call((float(cell.x) + 0.5) * size, (float(cell.y) + 0.5) * size).get("kind", "")).begins_with("sea"):
			regrow_s = float(cfg["regrow_s_sea"])   # sea water refills faster (balance plan 5b)

	var back: int = int(floor((_unix() - float(row[1])) / maxf(regrow_s, 1.0)))
	var now_n: int = mini(int(row[0]) + back, best)
	_fish_stock[key] = [now_n, _unix() if back > 0 else float(row[1])]
	return now_n


var _schools = null     # server_fish.gd, made when the first cast needs it and the water kind hook is set


# The best school factor for a line or net thrown from `pos` with `reach` m of reach: the stand point and eight directions at half and full reach
# (the water is somewhere out there, the shore is under the feet). {"factor", "species", "active"}; factor 1.0 and not active when plan C has nothing to say.
func school_hit(pos: Vector3, reach: float) -> Dictionary:
	var none: Dictionary = {"factor": 1.0, "species": "", "active": false}

	if not water_kind_at.is_valid():
		return none

	if _schools == null:
		var has_item: Callable = func(species: String) -> bool: return table.number_of(species) != 0
		_schools = FishSchoolsScript.new(water_kind_at, has_item, {}, float(_fishing_data().get("cell_m", 128.0)))

	var day: int = int(floor(_now_game_s() / 86400.0))
	var season: String = str(season_now.call()) if season_now.is_valid() else "summer"
	var stock: Callable = func(cell: Vector2i) -> int: return fish_stock(cell)
	var best: Dictionary = none
	var memo: Dictionary = {}

	for k in 17:
		var at: Vector3 = pos

		if k > 0:
			var a: float = float((k - 1) % 8) * TAU / 8.0
			at = pos + Vector3(cos(a), 0.0, sin(a)) * (reach if k > 8 else reach * 0.5)

		var got: Dictionary = _schools.factor_at(at.x, at.z, day, season, _now_game_s(), stock, memo)

		if bool(got["active"]) and (not bool(best["active"]) or float(got["factor"]) > float(best["factor"])):
			best = got

	return best


func _fish_chance(peer: int, _cell: Vector2i, bait: bool, hit: Dictionary = {}) -> float:
	var cfg: Dictionary = _fishing_data()
	var chance: float = float(cfg.get("base_chance", 0.55)) * skill_factor(peer, "fish")
	var hour: float = fposmod(float(game_seconds.call()), 86400.0) / 3600.0 if game_seconds.is_valid() else 12.0
	var tod: float = float(cfg.get("night_mult", 0.9)) if (hour < 5.0 or hour >= 21.0) else 1.0

	for band in cfg.get("hour_mult", []):
		if hour >= float(band[0]) and hour < float(band[1]):
			tod = float(band[2])

	chance *= tod
	var weather: Dictionary = weather_now.call() if weather_now.is_valid() else {}

	if float(weather.get("storm", 0.0)) > 0.3:
		chance *= float(cfg.get("storm_mult", 0.4))
	elif float(weather.get("rain", 0.0)) > 0.0:
		chance *= float(cfg.get("rain_mult", 1.2))

	if float(weather.get("cloud", 0.0)) > 0.6:
		chance *= float(cfg.get("cloud_mult", 1.1))

	if float(weather.get("temp_c", 15.0)) < float(cfg.get("cold_c", 5.0)):
		chance *= float(cfg.get("cold_mult", 0.6))

	if bait:
		chance *= float(cfg.get("bait_mult", 1.5))

	chance *= float(hit.get("factor", 1.0))   # plan C: inside a school 1.0, near it 0.5, away from every school 0.15
	return clampf(chance, float(cfg.get("min_chance", 0.02)), float(cfg.get("max_chance", 0.93)))


func _fish_species(cell: Vector2i, hit: Dictionary = {}) -> String:
	var cfg: Dictionary = _fishing_data()

	if str(hit.get("species", "")) != "":
		return str(hit["species"])   # the school the line or net is in or near
	var types: Array = cfg.get("types", ["pond"])
	@warning_ignore("integer_division")
	var water: String = str(types[(_cell_hash(cell) / 7) % types.size()])
	var roll: float = _fate_rng.randf()   # luck-exempt: the fate stream picks the fish species (luck applies to the catch roll)
	var table_rows: Array = cfg.get("species", {}).get(water, [])
	var acc: float = 0.0

	for row in table_rows:
		acc += float(row[1])

		if roll <= acc:
			return str(row[0])

	return str(table_rows[table_rows.size() - 1][0]) if not table_rows.is_empty() else "perch"


func _fish(peer: int, inv, slot: int, at: Vector3 = Vector3.ZERO) -> void:
	var cfg: Dictionary = _fishing_data()

	if cfg.has("none") or slot < 0 or slot >= inv.SLOTS or inv.numbers[slot] == 0 or not _peer_pos.has(peer) or _is_broken(inv.numbers[slot], inv.wear[slot]):
		return

	var entry: Dictionary = table.entry(table.id_of(inv.numbers[slot]))

	if str(entry.get("weapon_class", "")) in ["spear", "fish_spear"]:
		_spear_fish(peer, inv, slot, at, cfg, str(entry["weapon_class"]) == "fish_spear")
		return

	if str(entry.get("tool_class", "")) != "rod":
		return

	var now: int = Time.get_ticks_msec()
	var state: Dictionary = _fishing.get(peer, {})

	if not state.is_empty():
		if str(state["phase"]) == "bite" and now <= int(state["at"]):
			_fish_land(peer, inv, slot, state)
		else:
			_fishing.erase(peer)
			_say(peer, str(cfg.get("say_early", "")) if str(state["phase"]) == "wait" else str(cfg.get("say_away", "")))

		return

	if now - int(_last_fish.get(peer, -100000)) < int(float(cfg.get("cooldown_s", 2.0)) * 1000.0):
		return

	_last_fish[peer] = now

	if not water_near.is_valid() or not bool(water_near.call(_peer_pos[peer], float(cfg.get("reach_m", 8.0)))):
		_say(peer, str(cfg.get("say_no_water", "")))
		return

	var icy: bool = _on_ice(_peer_pos[peer])

	if icy and not _hole_near(_peer_pos[peer]):
		_say(peer, str(cfg.get("ice", {}).get("say_need_hole", "")))
		return

	var cell: Vector2i = _fish_cell(_peer_pos[peer])
	var bait_slot: int = _fish_bait_slot(inv, cfg)
	var hit: Dictionary = school_hit(_peer_pos[peer], float(cfg.get("reach_m", 8.0)))
	var chance: float = _fish_chance(peer, cell, bait_slot >= 0, hit) * (float(cfg.get("ice", {}).get("ice_mult", 0.8)) if icy else 1.0)

	if bait_slot >= 0:
		inv.take_from_slot(bait_slot, 1)

	_wear_slot(peer, inv, slot, "fish")
	var bites: bool = fish_stock(cell) > 0 and fate(peer, "fish", chance)
	var wait_s: Array = cfg.get("wait_s", [6.0, 22.0])
	var wait_ms: int = int(lerpf(float(wait_s[0]), float(wait_s[1]), _fate_rng.randf()) * 1000.0)   # luck-exempt: the length of a wait
	_fishing[peer] = {"phase": "wait", "at": now + wait_ms, "spot": _peer_pos[peer], "cell": cell, "bites": bites, "species": str(hit.get("species", ""))}
	_say(peer, str(cfg.get("say_cast", "")))


# The shore net (ACT_NET, fishing.json "net"; Dave 2 Nov 2026): the player throws it onto the water (up to reach_m away), it sinks for hold_s,
# then is pulled back in by its twine and the server rolls the haul from the school it landed on.
func _net_cast(peer: int, inv, slot: int, cancel: bool, at: Vector3) -> void:
	var cfg: Dictionary = _fishing_data().get("net", {})
	var state: Dictionary = _fishing.get(peer, {})

	if cancel:
		if str(state.get("phase", "")) == "net":
			_fishing.erase(peer)
			_say(peer, str(cfg.get("say_cancel", "")))

		return

	if cfg.is_empty() or slot < 0 or slot >= inv.SLOTS or inv.numbers[slot] == 0 or not _peer_pos.has(peer) or _is_broken(inv.numbers[slot], inv.wear[slot]):
		return

	if str(table.entry(table.id_of(inv.numbers[slot])).get("tool_class", "")) != "net" or not state.is_empty():
		return

	var pos: Vector3 = _peer_pos[peer]
	var now: int = Time.get_ticks_msec()

	if now - int(_last_fish.get(peer, -100000)) < int(float(_fishing_data().get("cooldown_s", 2.0)) * 1000.0):
		return

	_last_fish[peer] = now

	if not water_near.is_valid() or not bool(water_near.call(at, 1.0)) or Vector2(at.x - pos.x, at.z - pos.z).length() > float(cfg.get("reach_m", 5.0)):
		_say(peer, str(cfg.get("say_no_water", "")))
		return

	if _on_ice(pos):
		_say(peer, str(cfg.get("say_frozen", "")))
		return

	if water_depth_at.is_valid():
		var depth: float = float(water_depth_at.call(at))
		var band: Array = cfg.get("depth_m", [0.3, 1.2])

		if depth < float(band[0]):
			_say(peer, str(cfg.get("say_shallow", "")))
			return

		if depth > float(band[1]):
			_say(peer, str(cfg.get("say_deep", "")))
			return

	_fishing[peer] = {"phase": "net", "at": now + int(float(cfg.get("hold_s", 6.0)) * 1000.0), "spot": pos, "landed": at, "cell": _fish_cell(at), "slot": slot}
	_say(peer, str(cfg.get("say_start", "")))


# The haul: a random number of fish wanted, set by the school the net landed on (catch_by_school: a bigger school, more fish; none: 0 or 1),
# each limited by the cell's stock and the fishing chance (dawn and dusk best).
func _net_haul(peer: int, state: Dictionary) -> void:
	var cfg: Dictionary = _fishing_data().get("net", {})
	_fishing.erase(peer)
	var key: String = _peer_key.get(peer, "")
	var inv = _inventories.get(key)
	var slot: int = int(state.get("slot", -1))

	if inv == null or slot < 0 or inv.numbers[slot] == 0 or str(table.entry(table.id_of(inv.numbers[slot])).get("tool_class", "")) != "net":
		return

	var cell: Vector2i = state["cell"]
	var cell_key: String = "%d,%d" % [cell.x, cell.y]
	var hit: Dictionary = school_hit(state.get("landed", state["spot"]), float(cfg.get("net_radius_m", 1.5)))
	var want: int = _fate_rng.randi_range(0, 1)   # luck-exempt: how many the net holds (no school under it: one stray fish at most)
	var by: Dictionary = cfg.get("catch_by_school", {})

	if float(hit.get("factor", 0.0)) >= float(by.get("school_factor_min", 0.5)):   # in a school (factor 1) or near one (0.5, fish_schools.json factor)
		var most: float = float(hit.get("radius", by.get("default_radius_m", 5.0))) * float(by.get("fish_per_radius_m", 0.75))

		if float(hit.get("factor", 1.0)) < 1.0:   # the net landed near the school, not in it
			most *= float(by.get("near_mult", 0.5))

		want = _fate_rng.randi_range(1, maxi(1, int(round(most))))   # luck-exempt: how many the net holds

	var chance: float = clampf(_fish_chance(peer, cell, false, hit) * float(cfg.get("chance_mult", 1.0)), float(_fishing_data().get("min_chance", 0.02)), float(cfg.get("max_chance", 0.95)))
	var caught: Array = []

	for n in want:
		if fish_stock(cell) <= 0:
			break

		if fate(peer, "fish", chance):
			_fish_stock[cell_key][0] = int(_fish_stock[cell_key][0]) - 1
			var species: String = _fish_species(cell, hit)
			var left: int = inv.add(table.number_of(species), 1)

			if left > 0:
				drop_in_world(table.number_of(species), left, _peer_pos[peer])

			caught.append(table.sentence_name(table.number_of(species)))

	_wear_slot(peer, inv, slot, "net")
	_dirty = true

	if caught.is_empty():
		_say(peer, str(cfg.get("say_nothing", "")))
		return

	practice(peer, "fish")
	_goal_event(peer, "fish_caught")
	var line: String = "You haul in %s." % ", ".join(caught)

	if fish_stock(cell) < int(_fishing_data().get("hint_below", 3)):
		line += " " + str(_fishing_data().get("say_still", "The water is still."))

	_say(peer, line)


# A spear jab at water (the client sends ACT_FISH with the spear in hand and the point it stabs at): see fishing.json "spear". The Fishing
# spear (weapon_class "fish_spear", Part C) jabs the same way with fishing.json "fish_spear" laid over those numbers.
func _spear_fish(peer: int, inv, slot: int, at: Vector3, fishing: Dictionary, fish_spear: bool = false) -> void:
	var cfg: Dictionary = (fishing.get("spear", {}) as Dictionary).duplicate()

	if fish_spear:
		cfg.merge(fishing.get("fish_spear", {}), true)

	var pos: Vector3 = _peer_pos[peer]

	if cfg.is_empty() or not water_near.is_valid() or Vector2(at.x - pos.x, at.z - pos.z).length() > float(cfg.get("reach_m", 3.0)) or not bool(water_near.call(at, 0.0)) or bool(_swimming.get(peer, false)):
		return

	var now: int = Time.get_ticks_msec()

	if now - int(_last_fish.get(peer, -100000)) < int(float(cfg.get("cooldown_s", 1.2)) * 1000.0):
		return

	_last_fish[peer] = now

	if _on_ice(at):
		_say(peer, str(cfg.get("say_ice", "")))
		return

	if water_depth_at.is_valid():
		var depth: float = float(water_depth_at.call(at))

		if depth < float(cfg.get("min_depth_m", 0.05)) or depth > float(cfg.get("max_depth_m", 1.5)):
			if cfg.has("say_depth"):
				_say(peer, str(cfg["say_depth"]))

			return

	if float(_moving.get(peer, 0.0)) > float(cfg.get("still_below", 0.25)):
		_say(peer, str(cfg.get("say_move", "")))
		return

	_wear_slot(peer, inv, slot, "fish")
	var cell: Vector2i = _fish_cell(pos)
	var chance: float = float(cfg.get("base_chance", 0.2)) * skill_factor(peer, "fish")
	var weather: Dictionary = weather_now.call() if weather_now.is_valid() else {}

	if float(weather.get("storm", 0.0)) > 0.3 or float(weather.get("rain", 0.0)) > float(cfg.get("rain_over", 0.4)):
		chance *= float(cfg.get("murky_mult", 0.5))

	var hour: float = fposmod(_now_game_s(), 86400.0) / 3600.0
	var glare: Array = cfg.get("glare_hours", [11.0, 14.0])

	if hour >= float(glare[0]) and hour < float(glare[1]):
		chance *= float(cfg.get("glare_mult", 0.85))

	chance = clampf(chance, 0.02, float(cfg.get("max_chance", 0.6)))

	if fish_stock(cell) > 0 and fate(peer, "fish", chance):
		var key: String = "%d,%d" % [cell.x, cell.y]
		_fish_stock[key][0] = int(_fish_stock[key][0]) - 1
		var species: String = _fish_species(cell)
		var left: int = inv.add(table.number_of(species), 1)

		if left > 0:
			drop_in_world(table.number_of(species), left, pos)

		practice(peer, "fish")
		_goal_event(peer, "fish_caught")
		_say(peer, str(cfg.get("say_hit", "")) % table.sentence_name(table.number_of(species)))
		_dirty = true
	else:
		_say(peer, str(cfg.get("say_miss", "")))


func _on_ice(pos: Vector3) -> bool:
	if ice_moat_at.is_valid() and bool(ice_moat_at.call(pos)):
		return false   # the thaw's shore moat is open water: no ice to stand on, a drink without a hole (#729 decision, 8 Nov 2026)

	var by_spring: float = clampf(float(spring_ice_x.call(pos)), 0.0, 1.0) if spring_ice_x.is_valid() else 1.0   # half ice near a spring (#739)
	return ice_cover_at.is_valid() and float(ice_cover_at.call(pos)) * by_spring >= 0.5 and water_near.is_valid() and bool(water_near.call(pos, 0.0))


# The live ice holes within reach of a point, nearest first, at most `count` (protocol 97, Kathleen's frozen_water_look.md 5): [positions,
# game seconds each stays open until]. The client turns `until` into an age with fishing.json ice.hole_game_h.
func ice_holes_near(at: Vector3, reach: float = 120.0, count: int = 8) -> Array:
	var now: float = _now_game_s()
	var live: Array = _holes.filter(func(h): return float(h["until"]) > now and Vector2(h["pos"].x - at.x, h["pos"].z - at.z).length() <= reach)
	live.sort_custom(func(p, q): return at.distance_squared_to(p["pos"]) < at.distance_squared_to(q["pos"]))
	var points: PackedVector3Array = PackedVector3Array()
	var untils: PackedFloat32Array = PackedFloat32Array()

	for h in live.slice(0, count):
		points.append(h["pos"])
		untils.append(float(h["until"]))

	return [points, untils]


func _now_game_s() -> float:
	return float(game_seconds.call()) if game_seconds.is_valid() else 0.0


func _hole_near(pos: Vector3) -> bool:
	_holes = _holes.filter(func(h): return float(h["until"]) > _now_game_s())

	for hole in _holes:
		if pos.distance_to(hole["pos"]) <= float(_fishing_data().get("ice", {}).get("hole_reach_m", 2.0)):
			return true

	return false


# Right click with an axe or pick on a bearing sheet: blows_needed blows (blow_gap_s apart) open a hole that stays open hole_game_h
# game hours. The oldest of a player's holes closes when they cut a new one over their limit.
func _cut_hole(peer: int, inv, slot: int) -> void:
	var cfg: Dictionary = _fishing_data().get("ice", {})

	if cfg.is_empty() or slot < 0 or slot >= inv.SLOTS or inv.numbers[slot] == 0 or not _peer_pos.has(peer) or not _peer_key.has(peer):
		return

	if not str(table.entry(table.id_of(inv.numbers[slot])).get("tool_class", "")) in ["axe", "pick"] or _is_broken(inv.numbers[slot], inv.wear[slot]):
		_reject(peer, 1)
		return

	if not _on_ice(_peer_pos[peer]):
		_say(peer, str(cfg.get("say_no_ice", "")))
		return

	var now: int = Time.get_ticks_msec()
	var row: Array = _hole_blows.get(peer, [0, -100000])

	if now - int(row[1]) < int(float(cfg.get("blow_gap_s", 0.8)) * 1000.0):
		return

	_wear_slot(peer, inv, slot, "ice")
	var blows: int = int(row[0]) + 1

	if blows < int(cfg.get("blows_needed", 6)):
		_hole_blows[peer] = [blows, now]
		return

	_hole_blows.erase(peer)
	var key: String = str(_peer_key[peer])
	var mine: Array = _holes.filter(func(h): return str(h["owner"]) == key)

	while mine.size() >= int(cfg.get("holes_per_player", 2)):
		_holes.erase(mine[0])
		mine.remove_at(0)

	_holes.append({"pos": _peer_pos[peer], "owner": key, "until": _now_game_s() + float(cfg.get("hole_game_h", 12.0)) * 3600.0})
	_say(peer, str(cfg.get("say_hole", "")))


func _fish_bait_slot(inv, cfg: Dictionary) -> int:
	for slot in range(inv.SLOTS):
		if inv.numbers[slot] == 0:
			continue

		var id: String = table.id_of(inv.numbers[slot])

		for word in cfg.get("bait", []):
			if id == str(word) or id.ends_with(str(word)):
				return slot

	return -1


var _trap_rolled: Dictionary = {}   # fish trap uid -> game second up to which its hours are rolled (not saved: after a restart its hour starts again)
var _traps_at_s: float = -1.0e18    # game second of the last _fish_traps_tick pass
const FISH_TRAP_LOOK_S := 600.0     # the traps are looked over every ten game minutes; each rolls once per whole game hour it has stood


# Fish traps (structures.json "fish_trap": true, fishing.json "trap"; Part C plan 2): each game hour a trap rolls the fishing cell's stock at
# hour_chance, or bait_chance with a bait from trap.bait in its slots, which a catch uses up. The fish goes into its slots, so E takes it out
# like a chest; a full trap or a frozen one catches nothing. Every fish counts against the cell's stock, so traps cannot empty a pond faster
# than it refills. Hours missed while the clock jumped (sleep) are rolled, at most catch_up_h of them.
func _fish_traps_tick() -> void:
	var cfg: Dictionary = _fishing_data().get("trap", {})
	var now_s: float = _now_game_s()

	if cfg.is_empty() or now_s - _traps_at_s < FISH_TRAP_LOOK_S:
		return

	_traps_at_s = now_s
	var seen: Dictionary = {}

	for id in _items:
		var it: Dictionary = _items[id]

		if not it.has("struct") or not it["struct"].has("uid") or not bool(_structures.get(str(it["struct"]["kind"]), {}).get("fish_trap", false)):
			continue

		var uid: int = int(it["struct"]["uid"])
		var box = _chests.get(uid)

		if box == null:
			continue

		seen[uid] = true
		var since: float = float(_trap_rolled.get(uid, now_s))
		var whole_h: int = floori((now_s - since) / 3600.0)
		_trap_rolled[uid] = since + float(maxi(whole_h, 0)) * 3600.0

		if whole_h <= 0 or _on_ice(it["pos"]):
			continue

		box.usable = clampi(int(_structures[str(it["struct"]["kind"])].get("slots", box.SLOTS)), 1, box.SLOTS)
		var caught: int = 0

		for h in mini(whole_h, int(cfg.get("catch_up_h", 24))):
			if _fish_trap_roll(it["pos"], box, cfg):
				caught += 1

		if caught > 0:
			_dirty = true
			_push_box(id, box)

	for uid in _trap_rolled.keys():
		if not seen.has(uid):
			_trap_rolled.erase(uid)


# One game hour of one trap: true when a fish went into it.
func _fish_trap_roll(pos: Vector3, box, cfg: Dictionary) -> bool:
	var cell: Vector2i = _fish_cell(pos)

	if fish_stock(cell) <= 0:
		return false

	var bait_slot: int = _fish_bait_slot(box, cfg)
	var chance: float = float(cfg.get("bait_chance", 0.2)) if bait_slot >= 0 else float(cfg.get("hour_chance", 0.12))

	if _fate_rng.randf() >= chance:   # luck-exempt: nobody stands at a trap while it fishes
		return false

	var number: int = table.number_of(_fish_species(cell))

	if number == 0:
		return false

	var eaten: Dictionary = box.take_from_slot(bait_slot, 1) if bait_slot >= 0 else {}   # the bait is eaten; its slot may be where the fish goes

	if box.add(number, 1) > 0:
		if int(eaten.get("number", 0)) != 0:
			box.add(int(eaten["number"]), 1, int(eaten.get("wear", 0)))   # full: nothing caught, the bait stays

		return false

	var key: String = "%d,%d" % [cell.x, cell.y]
	_fish_stock[key][0] = int(_fish_stock[key][0]) - 1
	return true


func _fish_land(peer: int, inv, _slot: int, state: Dictionary) -> void:
	_fishing.erase(peer)
	var cell: Vector2i = state["cell"]
	var key: String = "%d,%d" % [cell.x, cell.y]

	if fish_stock(cell) <= 0:
		_say(peer, str(_fishing_data().get("say_empty", "")))
		return

	_fish_stock[key][0] = int(_fish_stock[key][0]) - 1
	var species: String = _fish_species(cell, {"species": str(state.get("species", ""))})
	var left: int = inv.add(table.number_of(species), 1)

	if left > 0:
		drop_in_world(table.number_of(species), left, _peer_pos[peer])

	practice(peer, "fish")
	_goal_event(peer, "fish_caught")   # the fish goal counts a catch even after the fish is eaten
	var landed: String = "You land a %s." % table.sentence_name(table.number_of(species))

	if int(_fish_stock[key][0]) < int(_fishing_data().get("hint_below", 3)):
		landed += " " + str(_fishing_data().get("say_still", "The water is still."))

	_say(peer, landed)
	_dirty = true


func _fish_tick() -> void:
	if _fishing.is_empty():
		return

	var now: int = Time.get_ticks_msec()
	var cfg: Dictionary = _fishing_data()

	for peer in _fishing.keys():
		var state: Dictionary = _fishing[peer]

		var net_phase: bool = str(state["phase"]) == "net"
		var cancel_m: float = float(cfg.get("net", {}).get("move_cancel_m", 2.0)) if net_phase else float(cfg.get("move_cancel_m", 6.0))

		if not _peer_pos.has(peer) or _peer_pos[peer].distance_to(state["spot"]) > cancel_m:
			_fishing.erase(peer)

			if net_phase:
				_say(peer, str(cfg.get("net", {}).get("say_cancel", "")))

			continue

		if now < int(state["at"]):
			continue

		if net_phase:
			_net_haul(peer, state)
			continue

		if str(state["phase"]) == "wait":
			if bool(state["bites"]):
				state["phase"] = "bite"
				state["at"] = now + int(float(cfg.get("window_s", 3.0)) * 1000.0)
				_say(peer, str(cfg.get("say_bite", "")))
			else:
				_fishing.erase(peer)
				_say(peer, str(cfg.get("say_nothing", "")))
		else:
			_fishing.erase(peer)
			_say(peer, str(cfg.get("say_away", "")))


func _station_name(station: String) -> String:
	for kind in _structures:
		if str(_structures[kind].get("station", "")) == station:
			return table.sentence_name(table.number_of(str(_structures[kind].get("item", ""))))

	for kind in _structures:
		if _structures[kind].get("also", {}).has(station):
			return table.sentence_name(table.number_of(str(_structures[kind].get("item", ""))))

	return station.replace("_", " ")


# Admin mode (Dave 2026-10-23, on by default): an admin with the mode on crafts anything in the list free and unlimited, locked or
# not, with no station and no ingredients (the queue entry carries an empty needs list, which the tick reads as a free craft).
var _admin_mode_off: Dictionary = {}    # peer -> true when that admin switched Admin mode off (ON by default for admins; resets at login)
var admin_mode_on: Callable             # (peer) -> bool, set by the server from the Esc > Admin settings switch; unset means on


func free_craft_for(peer: int) -> bool:
	return admin_ok.is_valid() and bool(admin_ok.call(peer)) and (not admin_mode_on.is_valid() or bool(admin_mode_on.call(peer)))


# --- Gather from the sea edge (WATER_GATHER_SPEC.md; Tyler 31 Oct 2026) ---
# ACT_GATHER_EDGE: with a bucket, clay jug or waterskin in the pack and the sea within reach, one `sea_water`; otherwise the tide-line node of the cell the player stands in
# (data/items/shore_nodes.json), the same node every time that game day, used up until the next. `water_kind` is set by the server scene (position -> "sea_shallow", "river", ...;
# unset: no sea anywhere). Fresh water into a container is the existing drink action (_drink_water).
var _shore_taken: Dictionary = {} # "cx,cz" -> game day the node was used
var _shore_cfg: Dictionary = {}
var _shore_loaded: bool = false


func _shore_data() -> Dictionary:
	if not _shore_loaded:
		_shore_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/shore_nodes.json"))
		_shore_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

	return _shore_cfg


func _sea_near(pos: Vector3, reach: float) -> bool:
	if not water_kind_at.is_valid():
		return false

	for offset in [Vector2.ZERO, Vector2(reach, 0.0), Vector2(-reach, 0.0), Vector2(0.0, reach), Vector2(0.0, -reach)]:
		if str((water_kind_at.call(pos.x + offset.x, pos.z + offset.y) as Dictionary).get("kind", "")).begins_with("sea"):
			return true

	return false


# The node of a cell on a game day: {} when none, else the row of shore_nodes.json "nodes" (deterministic from the cell and the day).
func shore_node_at(pos: Vector3, day: int, hour: float, season: String) -> Dictionary:
	return ShoreRules.node_at(_shore_data(), pos, day, hour, season)


func gather_edge(peer: int, inv) -> bool:
	if not _peer_pos.has(peer) or inv == null:
		return false

	if not _nearest_nest(_peer_pos[peer]).is_empty():   # an inland bird nest within reach comes first (data/items/nests.json)
		return take_nest(peer, inv)

	var cfg: Dictionary = _shore_data()
	var here: Vector3 = _peer_pos[peer]
	var reach: float = float(cfg.get("reach_m", 4.0))

	if not _sea_near(here, reach):
		_say(peer, "There is no sea water here.")
		return false

	for id in cfg.get("containers", []):
		if table.number_of(str(id)) > 0 and inv.count_of(table.number_of(str(id))) > 0:
			var water: int = table.number_of(str(cfg.get("sea_water_item", "sea_water")))

			if water > 0 and _fit(peer, inv, water, 1) > 0:
				give(peer, water, 1)
				_dirty = true
				return true

			_say(peer, "Too heavy to carry any more")
			return false

	if float(ground_height.call(here.x, here.z)) > float(cfg.get("beach_max_height_m", 4.0)):
		return false

	var day: int = _game_day()
	var hour: float = fmod(float(game_seconds.call()) if game_seconds.is_valid() else 0.0, 86400.0) / 3600.0
	var node: Dictionary = shore_node_at(here, day, hour, _season())
	var key: String = "%d,%d" % [int(floor(here.x / float(cfg.get("cell_m", 8.0)))), int(floor(here.z / float(cfg.get("cell_m", 8.0))))]

	if node.is_empty():
		_say(peer, "Nothing on the tide line here.")
		return false

	if int(_shore_taken.get(key, -1)) == day:
		_say(peer, "Nothing left here today.")
		return false

	var count: Array = node.get("count", [1, 1])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(key) ^ day ^ 0x3c6ef372
	give(peer, table.number_of(str(node["item"])), roll_amount(peer, rng, int(count[0]), int(count[1])))
	_shore_taken[key] = day
	_dirty = true
	return true


# --- Inland bird nests (Sal 3 Nov 2026; data/items/nests.json) ---
# The fauna side places nests near grouse and songbird homes (nests_near). E at one takes its eggs in its seasons; a robbed nest is empty for refill_days.
# The robbed days are kept in memory only: a restart lets every nest lay again, which is harmless.
var _nest_taken: Dictionary = {}   # nest id -> game day it was robbed
var _nest_cfg: Dictionary = {}
var _nest_loaded: bool = false


func _nest_data() -> Dictionary:
	if not _nest_loaded:
		_nest_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/nests.json"))
		_nest_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

	return _nest_cfg


# The nearest nest of a known kind within reach_m of the point, or {}.
func _nearest_nest(pos: Vector3) -> Dictionary:
	if not nests_near.is_valid():
		return {}

	var cfg: Dictionary = _nest_data()
	var best: Dictionary = {}
	var best_d: float = INF

	for nest in nests_near.call(pos, float(cfg.get("reach_m", 2.5))):
		var d: float = (nest["pos"] as Vector3).distance_to(pos)

		if cfg.get("kinds", {}).has(str(nest["kind"])) and d < best_d:
			best = nest
			best_d = d

	return best


func take_nest(peer: int, inv) -> bool:
	if not _peer_pos.has(peer) or inv == null:
		return false

	var nest: Dictionary = _nearest_nest(_peer_pos[peer])

	if nest.is_empty():
		return false

	var cfg: Dictionary = _nest_data()
	var row: Dictionary = cfg["kinds"][str(nest["kind"])]
	var id: String = str(nest["id"])
	var day: int = _game_day()

	if not (_season() in row.get("seasons", [])):
		_say(peer, str(cfg.get("say_season", "")))
		return false

	if _nest_taken.has(id) and day - int(_nest_taken[id]) < int(row.get("refill_days", 3)):
		_say(peer, str(cfg.get("say_empty", "")))
		return false

	var count: Array = row.get("count", [1, 1])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(id) ^ day ^ 0x1b873593
	give(peer, table.number_of(str(row.get("item", "egg"))), roll_amount(peer, rng, int(count[0]), int(count[1])))

	if row.has("extra") and roll_chance(peer, rng, float(row.get("extra_chance", 1.0))):   # luck nudges the extra find too (job 77)
		give(peer, table.number_of(str(row["extra"][0])), int(row["extra"][1]))

	_nest_taken[id] = day
	_dirty = true
	return true


# --- Farming (FARMING_SPEC.md steps 2 to 5; Tyler 31 Oct 2026) ---
# A hoe tills a metre of ground into a tilled bed (structure kind tilled_bed, state 47; a garden plot, "plot": true, works the same); a seed sown on it starts a
# crop (data/items/crops.json); a game day that ends with the bed's moisture at wet_min_pct or more (plot_water.gd: rain and pours fill it, the weather dries it) counts as watered; a crop is ripe when it is old enough (grow_days) AND has had enough wet days (water_per_day x grow_days); winter
# pauses growth (turnip excepted) and frost kills a seedling; compost speeds one crop cycle by 20 percent; E on a ripe crop gives its yields (half without the sickle
# where the crop needs one) and seeds back, and the bed is empty soil again. The crop records live beside the beds in crops.json (key "x,z" of the bed). The client side
# (a hoe mode that sends ACT_TILL, a seed use that sends ACT_SOW, E on a crop that sends ACT_HARVEST, the stage looks) is not built: see PROTOCOL.md.
const TILLED_STATE := 47
var _crops: Dictionary = {}              # "x,z" -> {"crop": id, "sown": game day, "age": days grown, "wet": watered days, "day": last game day looked at, "compost": bool, "poured": game day water was poured (one pour a day)}; the bed's moisture is in _plot_water
var _crops_cfg: Dictionary = {}
var _crops_loaded: bool = false
var _moisture_cfg: Dictionary = {}       # crops.json "moisture" (plot_water.gd)
var _plot_water: Dictionary = {}         # bed key "x,z" -> [moisture percent, game second it was worked out at]; saved in crops.json "plots"
var _plots_at_s: float = -1.0e18         # game second of the last _plots_tick pass
const PLOT_STEP_S := 3600.0              # plots are looked at once a game hour (150 real seconds)
const PlotWater := preload("res://src/shared/plot_water.gd")


func _crop_table() -> Dictionary:
	if not _crops_loaded:
		_crops_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/crops.json"))
		_crops_cfg = (parsed.get("crops", {}) as Dictionary) if typeof(parsed) == TYPE_DICTIONARY else {}
		_moisture_cfg = (parsed.get("moisture", {}) as Dictionary) if typeof(parsed) == TYPE_DICTIONARY else {}

	return _crops_cfg


func _bed_key(pos: Vector3) -> String:
	return "%d,%d" % [int(floor(pos.x)), int(floor(pos.z))]


func _game_day() -> int:
	return int(floor((float(game_seconds.call()) if game_seconds.is_valid() else 0.0) / 86400.0))


func _season() -> String:
	return str(season_now.call()) if season_now.is_valid() else "spring"


func _bed_at(id: int) -> Dictionary:
	var it: Dictionary = _items.get(id, {})
	return it if (not it.is_empty() and it.has("struct") and _is_plot_kind(str(it["struct"].get("kind", "")))) else {}


# A tilled bed, or a garden plot (structures.json "plot": true, buildables plan B5): it takes a seed, holds moisture and is tended the same way.
func _is_plot_kind(kind: String) -> bool:
	return kind == "tilled_bed" or bool(_structures.get(kind, {}).get("plot", false))


# The bed's moisture now, 0 to 100 (plot_water.gd): start_pct for one not seen yet.
func plot_moisture(pos: Vector3) -> float:
	var row: Array = _plot_water.get(_bed_key(pos), [])
	_crop_table()
	return float(row[0]) if row.size() >= 2 else float(_moisture_cfg.get("start_pct", 50.0))


# Every game hour (or at once when the clock jumped): each bed's moisture follows the weather since it was last worked out (rain fills it, the dry
# weather's evaporation takes it, times the structure's moisture_factor); beds that are gone are forgotten.
func _plots_tick() -> void:
	var now_s: float = float(game_seconds.call()) if game_seconds.is_valid() else 0.0

	if now_s - _plots_at_s < PLOT_STEP_S:
		return

	_plots_at_s = now_s
	_crop_table()
	var weather: Dictionary = weather_now.call() if weather_now.is_valid() else {}
	var rain: float = float(rain_now.call()) if rain_now.is_valid() else float(weather.get("rain", 0.0))
	var seen: Dictionary = {}

	for id in _items:
		var it: Dictionary = _items[id]

		if not it.has("struct") or not _is_plot_kind(str(it["struct"].get("kind", ""))):
			continue

		var key: String = _bed_key(it["pos"])
		var row: Array = _plot_water.get(key, [float(_moisture_cfg.get("start_pct", 50.0)), now_s])
		var factor: float = float(_structures.get(str(it["struct"]["kind"]), {}).get("moisture_factor", 1.0))
		var dt_days: float = maxf(now_s - float(row[1]), 0.0) / PlotWater.DAY_S
		_plot_water[key] = [PlotWater.step(_moisture_cfg, float(row[0]), dt_days, float(weather.get("temp_c", 15.0)), float(weather.get("wind", 0.0)), rain, factor), now_s]
		seen[key] = true

	for key in _plot_water.keys():
		if not seen.has(key):
			_plot_water.erase(key)

	_water_dirty = _water_dirty or not _water_kind.is_empty()   # the weather moved the plots' moisture: their room changed


# --- Water pieces (buildables plan section 6, part 6b; Sonny's water rules; Steve's design note, 10 Nov 2026) ---
# A structure with a structures.json "water" block is a piece of the water network (water_network.gd): its block names the role and numbers, and its
# inlet and outlet as [x, y, z] metres from the piece's middle, turned with its yaw. The network is accounting only: the live water sim never sees it.
# Pieces join when built (a blueprint site joins when finished) and leave when the structure is gone; the network is solved again then and at its next
# event (a tank full or empty, a plot full, water going still). A garden plot's water block makes it a consumer: what flows in becomes moisture (1
# percent a litre on a 2 x 2 plot: its store_mm over its area), and a full plot takes no more. Tank litres are saved in crops.json "tanks".
# Times are real seconds (the game clock over GameClock.RATIO), as pumping and flow are.
const WaterNetwork := preload("res://src/shared/water_network.gd")
const GameClockScript := preload("res://src/shared/game_clock.gd")
const WATER_SOURCES_PER_CHUNK := 4
var _water = WaterNetwork.new()
var _water_kind: Dictionary = {}        # item id -> structure kind of a piece in the network
var _water_dirty: bool = false
var _water_at_s: float = -1.0           # real second of the last solve
var _water_next_s: float = INF          # the network's next event, real seconds
var _water_tanks_saved: Dictionary = {} # crops.json "tanks": position key -> litres, read at load


func _water_now_s() -> float:
	return _now_game_s() / GameClockScript.RATIO


# The network piece a structure of `def` makes standing at `pos` turned `yaw_deg`, or {} when it carries no water.
func water_piece(def: Dictionary, pos: Vector3, yaw_deg: float) -> Dictionary:
	var block: Variant = def.get("water", {})

	if typeof(block) != TYPE_DICTIONARY or (block as Dictionary).is_empty():
		return {}

	var piece: Dictionary = {}

	for key in block:
		var value: Variant = block[key]

		if (key == "inlet" or key == "outlet") and typeof(value) == TYPE_ARRAY and (value as Array).size() == 3:
			piece[key] = pos + Vector3(float(value[0]), float(value[1]), float(value[2])).rotated(Vector3.UP, deg_to_rad(yaw_deg))
		elif key != "note":
			piece[key] = value

	return piece


# Why a water piece may not go here ("" when it may): more than WATER_SOURCES_PER_CHUNK sources in the chunk, a loop, or a network past 256 pieces.
func _water_refusal(def: Dictionary, spot: Vector3, yaw_deg: int) -> String:
	var piece: Dictionary = water_piece(def, spot, float(posmod(yaw_deg, 360)))

	if piece.is_empty():
		return ""

	var dry: String = _ground_water_refusal(piece, spot)

	if dry != "":
		return dry

	if str(piece.get("role", "")) == "source":
		var sources: int = 0

		for id in _water_kind:
			if str(_water.pieces.get(id, {}).get("role", "")) == "source" and _chunk_of(_items[id]["pos"]) == _chunk_of(spot):
				sources += 1

		if sources >= WATER_SOURCES_PER_CHUNK:
			return "Too many water sources stand here already."

	match _water.check(piece):
		"loop":
			return "This would make a loop."
		"full":
			return "This water network cannot grow any bigger."

	return ""


# A built structure joins the network when it carries water.
func _water_add(id: int) -> void:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not it.has("struct") or it["struct"].has("site"):
		return

	var kind: String = str(it["struct"]["kind"])
	var piece: Dictionary = water_piece(_structures.get(kind, {}), it["pos"], float(it["struct"].get("yaw", 0.0)))

	if piece.is_empty():
		return

	_water.add(id, piece)
	_water_kind[id] = kind

	if str(piece.get("role", "")) == "tank":
		_water.set_litres(id, float(_water_tanks_saved.get(_water_key(it["pos"]), 0.0)))
		_water_tanks_saved.erase(_water_key(it["pos"]))

	_water_dirty = true


func _water_key(pos: Vector3) -> String:
	return "%.2f,%.2f,%.2f" % [pos.x, pos.y, pos.z]


# At load: every standing water structure joins, and tanks take their saved litres.
func _water_rebuild(tanks: Dictionary) -> void:
	_water = WaterNetwork.new()
	_water.still_after_s = 3.0 * GameClockScript.SECONDS_PER_DAY / GameClockScript.RATIO   # 3 game days (Sonny's rules)
	_water_kind.clear()
	_water_depth.clear()
	_pumping.clear()
	_water_tanks_saved = tanks.duplicate()
	_water_at_s = -1.0

	for id in _items:
		if _items[id].has("struct") and _structures.get(str(_items[id]["struct"]["kind"]), {}).has("water"):
			_water_add(id)

	_water_tanks_saved.clear()


func _water_tanks_save() -> Dictionary:
	var out: Dictionary = {}
	var now_s: float = _water_now_s()

	for id in _water_kind:
		if str(_water.pieces.get(id, {}).get("role", "")) == "tank":
			out[_water_key(_items[id]["pos"])] = snappedf(_water.litres(id, now_s), 0.01)

	return out


# Litres a garden plot takes for 1 percent of moisture: its store over its area (25 mm on 2 x 2 m: 1 L).
func _plot_litres_per_pct(kind: String) -> float:
	var def: Dictionary = _structures.get(kind, {})
	_crop_table()
	return maxf(float(_moisture_cfg.get("store_mm", 25.0)) * float(def.get("footprint_x", 1.0)) * float(def.get("footprint_z", 1.0)) / 100.0, 0.01)


# Pieces whose structure is gone leave; then, when anything changed or the next event is due, the water that flowed into plots since the last solve
# becomes moisture, each plot's room is set from its moisture, and the network is solved again.
func _water_tick(spent: float = 0.0) -> void:
	if _water_kind.is_empty():
		_pumping.clear()
		return

	for id in _water_kind.keys():
		var it: Dictionary = _items.get(id, {})

		if it.is_empty() or not it.has("struct") or str(it["struct"]["kind"]) != str(_water_kind[id]) or it["struct"].has("site"):
			_water.remove(id)
			_water_kind.erase(id)
			_water_depth.erase(id)
			_water_dirty = true

	_pump_tick(spent)
	var now_s: float = _water_now_s()

	if not _water_dirty and now_s < _water_next_s:
		return

	_water_resolve(now_s)


# The water that flowed into plots since the last solve becomes moisture, each plot's room is set from its moisture, and the network is solved.
func _water_resolve(now_s: float) -> void:
	_water_dirty = false

	for id in _water_kind:
		var piece: Dictionary = _water.pieces[id]

		if str(piece.get("role", "")) != "consumer" or not _is_plot_kind(str(_water_kind[id])):
			continue

		var key: String = _bed_key(_items[id]["pos"])
		var per_pct: float = _plot_litres_per_pct(str(_water_kind[id]))
		var pct: float = plot_moisture(_items[id]["pos"])

		if _water_at_s >= 0.0 and _water.inflow_lpm(id) > 0.0:
			pct = minf(100.0, pct + _water.inflow_lpm(id) * maxf(now_s - _water_at_s, 0.0) / 60.0 / per_pct)
			var row: Array = _plot_water.get(key, [])
			_plot_water[key] = [pct, float(row[1]) if row.size() >= 2 else _now_game_s()]   # its weather clock goes on as it was

		piece["room_l"] = (100.0 - pct) * per_pct if pct < 99.99 else 0.0

	_water.solve(now_s)
	_water_at_s = now_s
	_water_next_s = _water.next_event_s()


# --- Wells and pumps (6b part 2; Sonny's water rules sections 1 to 3) ---
# A source whose water block has "ground_water" (a well, a hand pump, a deep pump) lifts from the nearest fresh water within WELL_REACH_M: its depth
# is its ground minus that water's surface, and it may not go where there is none or deeper than its max_depth_m. E on one starts working it and E
# again stops: a pump ("pump": {cap_lps, watts}) gives WaterNetwork.pump_lpm, a windlass ("windlass": true) windlass_lpm with its bucket's draw_l,
# while the worker stays within its use reach and is not worn out; the work is exertion (the block's effort, 0.7). A source with nothing linked below
# it pours into the worker's containers instead (the first with room, hotbar first), and stops when they are full.
const WELL_REACH_M := 200.0
var fresh_water_y: Callable             # (position, reach m) -> surface height of the nearest lake or river within reach, NAN when none; set by the server scene (unset: the block's depth_m)
var _pumping: Dictionary = {}           # peer -> item id of the well or pump they work
var _water_depth: Dictionary = {}       # item id -> metres down to the water it lifts
var _pour_carry: Dictionary = {}        # peer -> millilitres poured but not yet a whole one


func _ground_water_depth(spot: Vector3, piece: Dictionary) -> float:
	if not fresh_water_y.is_valid():
		return float(piece.get("depth_m", 2.0))

	var surface: float = float(fresh_water_y.call(spot, WELL_REACH_M))
	return NAN if is_nan(surface) else maxf(spot.y - surface, 0.0)


# Why a well or pump may not go here ("" when it may): no fresh water within 200 m, or the water deeper than it reaches.
func _ground_water_refusal(piece: Dictionary, spot: Vector3) -> String:
	if not bool(piece.get("ground_water", false)):
		return ""

	var depth: float = _ground_water_depth(spot, piece)

	if is_nan(depth):
		return "There is no fresh water within %d m to reach down to." % int(WELL_REACH_M)

	if depth > _lift_limit_m(piece, spot):
		return "The water lies %d m down here, too deep for this." % int(round(depth))

	return ""


# How deep a well or pump reaches (Sonny's water rules, section 1): its max_depth_m (25 m when it has none: the windlass and the deep pump), and a
# suction pump ("suction": true, the hand pumps' 7 m) loses 1 m of it for every 1,000 m of height, as the air pressure falls.
static func _lift_limit_m(piece: Dictionary, spot: Vector3) -> float:
	var limit: float = float(piece.get("max_depth_m", 25.0))
	return limit - maxf(spot.y, 0.0) / 1000.0 if bool(piece.get("suction", false)) else limit


func _is_pumpable(piece: Dictionary) -> bool:
	return str(piece.get("role", "")) == "source" and (piece.has("pump") or bool(piece.get("windlass", false)))


# Litres a minute the worker gets out of a well or pump at its depth.
func _pump_rate(id: int) -> float:
	var piece: Dictionary = _water.pieces.get(id, {})

	if not _water_depth.has(id):
		_water_depth[id] = _ground_water_depth(_items[id]["pos"], piece)

	var depth: float = float(_water_depth[id])

	if is_nan(depth):
		return 0.0

	if piece.has("pump"):
		var pump: Dictionary = piece["pump"]
		return WaterNetwork.pump_lpm(float(pump.get("cap_lps", 0.8)), float(pump.get("watts", 40.0)), depth)

	return WaterNetwork.windlass_lpm(depth, float(piece.get("draw_l", 8.0)))


# E on a well or pump: start working it, or stop.
func _toggle_pump(peer: int, id: int) -> void:
	if int(_pumping.get(peer, 0)) == id:
		_stop_pump(peer, "You stop.")
		return

	if int(_strain.get(peer, {}).get("state", 0)) >= 2:
		_say(peer, "You are too worn out to work it.")
		return

	_stop_pump(peer, "")

	for other in _pumping:
		if int(_pumping[other]) == id:
			_say(peer, "Someone is working it already.")
			return

	var rate: float = _pump_rate(id)

	if rate <= 0.0:
		_say(peer, "It draws nothing.")
		return

	_pumping[peer] = id
	_water.pieces[id]["rate_lpm"] = rate
	_water_dirty = true
	_say(peer, "You start working it (%d L a minute). Press E again to stop." % int(round(rate)))


func _stop_pump(peer: int, say: String) -> void:
	if not _pumping.has(peer):
		return

	var id: int = int(_pumping[peer])
	_pumping.erase(peer)
	_pour_carry.erase(peer)

	if _water.pieces.has(id):
		_water.pieces[id]["rate_lpm"] = 0.0
		_water_dirty = true

	if say != "":
		_say(peer, say)


# Each slow tick: a worker who walked off, wore out or lost the piece stops; the others work on (exertion), and a source with nothing below it fills
# the worker's containers.
func _pump_tick(spent: float) -> void:
	for peer in _pumping.keys():
		var id: int = int(_pumping[peer])

		if not _peer_pos.has(peer) or not _water_kind.has(id):
			_stop_pump(peer, "")
			continue

		var def: Dictionary = _structures.get(str(_water_kind[id]), {})

		if _peer_pos[peer].distance_to(_items[id]["pos"]) > float(def.get("use_reach_m", 3.0)) + 0.5:
			_stop_pump(peer, "You stop working it.")
			continue

		if int(_strain.get(peer, {}).get("state", 0)) >= 2:
			_stop_pump(peer, "You are too worn out to go on.")
			continue

		var piece: Dictionary = _water.pieces[id]
		_work_until[peer] = Time.get_ticks_msec() + int(maxf(spent, SLOW_TICK_S) * 1000.0) + 500
		_work_level[peer] = float(piece.get("effort", 0.7))

		if _water.downstream(id).is_empty() and spent > 0.0:
			_pour_into_containers(peer, float(piece.get("rate_lpm", 0.0)) * spent / 60.0 * 1000.0)


func _pour_into_containers(peer: int, ml: float) -> void:
	var inv = inventory_of(peer)

	if inv == null:
		_stop_pump(peer, "")
		return

	var carry: float = float(_pour_carry.get(peer, 0.0)) + ml
	var whole: int = int(floor(carry))
	_pour_carry[peer] = carry - float(whole)
	var before: Array = _snapshot(inv)
	var order: Array = []

	for slot in range(inv.SLOTS):
		if inv.numbers[slot] != 0 and _container_cap(inv.numbers[slot]) > inv.wear[slot]:
			if inv.on_hotbar(slot):
				order.push_front(slot)
			else:
				order.append(slot)

	if order.is_empty():
		_stop_pump(peer, "You have nothing with room for water.")
		return

	for slot in order:
		var poured: int = mini(whole, _container_cap(inv.numbers[slot]) - inv.wear[slot])
		inv.wear[slot] += poured
		whole -= poured

		if whole <= 0:
			break

	_send_changes(peer, inv, before)
	_dirty = true


# The nearest tank (trough, barrel, cistern) holding water within `reach` of `pos`, or -1.
func _tank_near(pos: Vector3, reach: float) -> int:
	var best: int = -1
	var best_m: float = reach
	var now_s: float = _water_now_s()

	for id in _water_kind:
		if str(_water.pieces[id].get("role", "")) != "tank" or _water.litres(id, now_s) < 0.01:
			continue

		var gap: float = (_items[id]["pos"] as Vector3).distance_to(pos)

		if gap <= best_m:
			best_m = gap
			best = id

	return best


# E to drink at a tank, or to fill the container in hand from it (ACT_DRINK): the water comes out of the tank.
func _drink_from_tank(peer: int, slot: int, inv, tank: int, v: Dictionary, thirst: Dictionary, now: int) -> void:
	var now_s: float = _water_now_s()
	_water_resolve(now_s)   # the tank's litres are brought to now before any is taken
	var held_ml: int = int(floor(_water.litres(tank, now_s) * 1000.0))

	if _water.quality(tank) == "still":
		_say(peer, "The water has stood a long time. It smells stale.")

	if inv != null and slot >= 0 and slot < inv.SLOTS and inv.numbers[slot] != 0 and _container_cap(inv.numbers[slot]) > inv.wear[slot]:
		var ml: int = mini(mini(int(thirst.get("fill_ml", 500)), _container_cap(inv.numbers[slot]) - inv.wear[slot]), held_ml)
		var before: Array = _snapshot(inv)
		inv.wear[slot] += ml
		_send_changes(peer, inv, before)
		_water.set_litres(tank, float(held_ml - ml) / 1000.0)
	else:
		var cap: float = float(thirst.get("cap_ml", 2400))

		if float(v["wet"]) >= cap - 1.0:
			_say(peer, "You have had enough water.")
			return

		var sip: int = mini(int(thirst.get("drink_ml", 300)), held_ml)
		v["wet"] = minf(float(v["wet"]) + float(sip), cap)
		_sync_vitals(peer, true)
		_water.set_litres(tank, float(held_ml - sip) / 1000.0)

	_last_drink[peer] = now
	_water_dirty = true
	_dirty = true


# One hoe stroke tills a metre: a tilled bed where the player points (reach and hoe like the hoe path).
func till(peer: int, inv, at: Vector3) -> int:
	if not ground_height.is_valid() or not _structures.has("tilled_bed") or not _hoe_ready(peer, inv, at):
		return 0

	var cell: Vector3 = Vector3(floor(at.x) + 0.5, 0.0, floor(at.z) + 0.5)
	var ground: float = float(ground_height.call(cell.x, cell.z))

	if is_nan(ground):
		return 0

	cell.y = ground + 0.02

	if water_depth_at.is_valid() and float(water_depth_at.call(Vector3(cell.x, ground, cell.z))) > 0.05:
		_say(peer, "You cannot till ground under water.")
		return 0

	var here_chunk: Vector2i = _chunk_of(cell)
	var of_kind: int = 0

	for id in _items:
		var other: Dictionary = _items[id]

		if not other.has("struct"):
			continue

		var kind: String = str(other["struct"]["kind"])

		if kind == "tilled_bed":
			if absf(other["pos"].x - cell.x) < 0.25 and absf(other["pos"].z - cell.z) < 0.25:
				return 0   # already tilled

			if _chunk_of(other["pos"]) == here_chunk:
				of_kind += 1
		elif other["pos"].distance_to(cell) < 1.0 and not bool(_structures.get(kind, {}).get("walkover", false)):
			_say(peer, "Something stands there.")
			return 0

	if of_kind >= int(_structures["tilled_bed"].get("cap_per_chunk", 200)):
		_say(peer, "This ground is tilled enough.")
		return 0

	_wear_tool(peer, inv, "hoe", "dig")
	_items[_next_id] = {"number": table.number_of("tilled_bed"), "count": 1, "pos": cell, "left": 1.0e9, "struct": {"kind": "tilled_bed", "yaw": 0.0}}
	_next_id += 1
	_dirty = true
	return _next_id - 1


# A seed from the pack slot goes into the bed: right season, empty bed, the seed is used up.
func sow(peer: int, inv, bed_id: int, slot: int) -> bool:
	var bed: Dictionary = _bed_at(bed_id)

	if bed.is_empty() or not _peer_pos.has(peer) or _peer_pos[peer].distance_to(bed["pos"]) > DIG_REACH_M or slot < 0 or slot >= inv.SLOTS or inv.numbers[slot] == 0:
		return false

	var key: String = _bed_key(bed["pos"])

	if _crops.has(key):
		_say(peer, "Something is growing there already.")
		return false

	var seed_id: String = table.id_of(inv.numbers[slot])
	var crop_id: String = ""

	for id in _crop_table():
		if str(_crop_table()[id].get("seed", "")) == seed_id:
			crop_id = str(id)

	if crop_id == "":
		_say(peer, "That cannot be sown.")
		return false

	var def: Dictionary = _crop_table()[crop_id]

	var sow_seasons: Array = def.get("sow_seasons", [def.get("sow_season", "spring")])   # Sal's data: a list of sowing seasons (older rows: one string)

	if not sow_seasons.has(_season()):
		_say(peer, "Wrong season to sow %s" % table.in_sentence(str(def.get("name", crop_id))))
		return false

	inv.remove(inv.numbers[slot], 1)
	_crops[key] = {"crop": crop_id, "sown": _game_day(), "age": 0.0, "wet": 0, "day": _game_day(), "compost": false, "poured": -1}
	_dirty = true
	return true


# One `water` item from the pack on the bed: that game day counts as watered.
func water_bed(peer: int, inv, bed_id: int) -> bool:
	var bed: Dictionary = _bed_at(bed_id)

	if bed.is_empty() or not _peer_pos.has(peer) or _peer_pos[peer].distance_to(bed["pos"]) > DIG_REACH_M:
		return false

	var crop: Dictionary = _crops.get(_bed_key(bed["pos"]), {})
	var water: int = table.number_of("water")

	if crop.is_empty() or int(crop["poured"]) == _game_day() or not inv.has(water, 1):
		return false

	inv.remove(water, 1)
	crop["poured"] = _game_day()
	var key: String = _bed_key(bed["pos"])
	_plot_water[key] = [PlotWater.pour(_moisture_cfg, plot_moisture(bed["pos"])), float(game_seconds.call()) if game_seconds.is_valid() else 0.0]   # a bucket's worth (pour_pct)
	_dirty = true
	return true


# Compost on the bed: +20 percent growth for this crop. When the "fertiliser" ingredient group exists (Jamie, Part C: compost or bonemeal),
# any of its members does; the pack's has/remove follow the group.
func compost_bed(peer: int, inv, bed_id: int) -> bool:
	var bed: Dictionary = _bed_at(bed_id)
	var crop: Dictionary = _crops.get(_bed_key(bed["pos"]), {}) if not bed.is_empty() else {}
	var compost: int = table.number_of("fertiliser") if table.number_of("fertiliser") > 0 else table.number_of("compost")

	if crop.is_empty() or bool(crop["compost"]) or compost <= 0 or not inv.has(compost, 1):
		return false

	inv.remove(compost, 1)
	crop["compost"] = true
	_dirty = true
	return true


# The stage of a crop 0 seedling .. 3 ripe; a crop short of water stays at 2.
func crop_stage(crop: Dictionary) -> int:
	var def: Dictionary = _crop_table().get(str(crop["crop"]), {})
	var days: float = maxf(float(def.get("grow_days", 100)), 1.0)
	var stage: int = mini(int(floor(float(crop["age"]) / days * 4.0)), 3)

	if stage >= 3 and int(crop["wet"]) < int(ceil(float(def.get("water_per_day", 0.0)) * days)):
		return 2

	return stage


# Looks at the clock once per game day: a bed holding wet_min_pct of moisture (plot_water.gd: rain fills it, a pour adds to it, the weather dries it)
# makes it a wet day; winter pauses growth (turnip excepted) and kills a seedling.
func _crops_tick() -> void:
	_plots_tick()
	_fish_traps_tick()

	if _crops.is_empty():
		return

	var today: int = _game_day()

	for key in _crops.keys():
		var crop: Dictionary = _crops[key]
		var def: Dictionary = _crop_table().get(str(crop["crop"]), {})

		while int(crop["day"]) < today:
			crop["day"] = int(crop["day"]) + 1
			var winter: bool = _season() == "winter" and not bool(def.get("grows_in_winter", str(crop["crop"]) == "turnip"))   # data flag grows_in_winter; turnip by default

			if winter:
				if crop_stage(crop) == 0:
					_crops.erase(key)   # frost kills a seedling
					_dirty = true
					break

				continue

			crop["age"] = float(crop["age"]) + (1.2 if bool(crop["compost"]) else 1.0)

			if PlotWater.is_wet(_moisture_cfg, float((_plot_water.get(key, [float(_moisture_cfg.get("start_pct", 50.0))]) as Array)[0])):
				crop["wet"] = int(crop["wet"]) + 1

			_dirty = true


# E on a ripe crop: its yields (half without the right tool), seeds back, and the bed is empty again. Returns true when something was harvested.
func harvest(peer: int, inv, bed_id: int) -> bool:
	var bed: Dictionary = _bed_at(bed_id)

	if bed.is_empty() or not _peer_pos.has(peer) or _peer_pos[peer].distance_to(bed["pos"]) > DIG_REACH_M:
		return false

	var key: String = _bed_key(bed["pos"])
	var crop: Dictionary = _crops.get(key, {})

	if crop.is_empty():
		return false

	if crop_stage(crop) < 3:
		_say(peer, "It is not ripe yet.")
		return false

	var def: Dictionary = _crop_table().get(str(crop["crop"]), {})
	var tool_class: String = str(def.get("tool_to_harvest", "hand"))
	var full: bool = tool_class == "hand" or _has_tool(inv, tool_class)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(key) ^ int(crop["sown"])

	for row in def.get("yields", []):
		var n: int = int(row[1]) if full else maxi(int(ceil(float(row[1]) / 2.0)), 1)
		give(peer, table.number_of(str(row[0])), n)

	var back: Array = def.get("seeds_back", [])

	if back.size() == 2:
		give(peer, table.number_of(str(back[0])), roll_amount(peer, rng, int((back[1] as Array)[0]), int((back[1] as Array)[1])))

	if full and tool_class != "hand":
		_wear_tool(peer, inv, tool_class, "gather")

	_crops.erase(key)
	_dirty = true
	return true


# Lights (wall torch: a stick, chandelier: a candle, fireplace: firewood; structures.json fuel and fuel_s = burning seconds per fuel item, topped up to twice that). Lit lights count
# for comfort; the flag and the fuel left live on the placed row and burn down on the slow tick (not saved: a restart puts them out).
func _light_fixture(peer: int, inv, it: Dictionary, def: Dictionary) -> void:
	var fuel: int = table.number_of(str(def.get("fuel", "")))
	var burn: float = light_burn_s(def)
	var left: float = float(it["struct"].get("fuel_left", 0.0)) if bool(it["struct"].get("lit", false)) else 0.0

	if fuel <= 0 or not inv.has(fuel, 1):
		_say(peer, "You need %s to light that." % table.sentence_name(fuel) if fuel > 0 else "It cannot be lit.")
		return

	if left + burn > burn * 2.0:
		_say(peer, "It is burning well already.")
		return

	inv.remove(fuel, 1)
	it["struct"]["lit"] = true
	it["struct"]["fuel_left"] = left + burn
	_dirty = true
	_say(peer, "It burns.")


# How long one of a light's fuel items burns (buildables plan, batch B4: burn times in game days): structures.json fuel_days game days
# (BuildingWear.GAME_DAY_S, 1 game day = 1 real hour), else fuel_s seconds. A candle, lamp oil or tallow is just the row's "fuel" item.
func light_burn_s(def: Dictionary, fallback_s: float = 1800.0) -> float:
	if def.has("fuel_days"):
		return float(def["fuel_days"]) * BuildingWear.GAME_DAY_S

	return float(def.get("fuel_s", fallback_s))


# The lit lights (and the fuel each has left) are saved beside the world items in lights.json as [x, y, z, fuel_left] and put back on the structures at those spots after a load.
func _light_rows_save() -> Array:
	var rows: Array = []

	for id in _items:
		var it: Dictionary = _items[id]

		if it.has("struct") and bool(it["struct"].get("lit", false)):
			rows.append([it["pos"].x, it["pos"].y, it["pos"].z, float(it["struct"].get("fuel_left", 0.0))])

	return rows


func _apply_lit_rows(rows: Array) -> void:
	for row in rows:
		if typeof(row) != TYPE_ARRAY or (row as Array).size() < 4:
			continue

		var spot := Vector3(float(row[0]), float(row[1]), float(row[2]))

		for id in _items:
			var it: Dictionary = _items[id]

			if it.has("struct") and it["pos"].distance_to(spot) <= 0.3 and str(_structures.get(str(it["struct"].get("kind", "")), {}).get("use", "")) == "light":
				it["struct"]["lit"] = true
				it["struct"]["fuel_left"] = float(row[3])
				break


func _lights_tick(spent: float) -> void:
	var rain: float = float(rain_now.call()) if rain_now.is_valid() else 0.0

	for id in _items:
		var it: Dictionary = _items[id]

		if it.has("struct") and bool(it["struct"].get("lit", false)):
			# A torch out in the open rain goes out like an open fire (Dave, 4 Nov 2026); one under a crown, a roof or an overhang burns on.
			if rain >= FlameRules.RAIN_DOUSE and bool(_structures.get(str(it["struct"]["kind"]), {}).get("rain_douses", false)) and not (cover_at.is_valid() and float(cover_at.call(it["pos"] + Vector3(0.0, 0.5, 0.0))) > 0.5):
				it["struct"]["lit"] = false
				it["struct"].erase("fuel_left")
				_dirty = true
				continue

			it["struct"]["fuel_left"] = float(it["struct"].get("fuel_left", 0.0)) - spent

			if float(it["struct"]["fuel_left"]) <= 0.0:
				it["struct"]["lit"] = false
				it["struct"].erase("fuel_left")


# --- Comfort and the Rested buff (docs/COMFORT_DESIGN.md, data/items/comfort.json; Sal's design, Tyler 31 Oct 2026) ---
# comfort_at(peer): 0 when not sheltered; else 1 for the shelter plus the points of every DIFFERENT comfort kind within radius_m (9 m) and height_m (3 m) of the player, each kind
# once, only the best bed, fires/torches/chandeliers only while lit, clamped to max_level (20). A placed structure counts by its structures.json `comfort` id (or its own kind
# when comfort.json has a kind of that name: rough_bed, workbench, chest ...); lit fires count as `campfire`, a clay hearth as lit when a lit fire burns within 3 m.
# Rested: earned by sleeping or lying on a good bed at comfort 2 or more (sitting on a seat for 30 s is not built yet); lasts comfort_buff_real_minutes (45) REAL minutes; the tier
# (health regeneration, exhaustion, hunger and thirst, action speed, skill gain, cold) is the highest whose min_level is reached when earned; a rest at an equal or higher level
# refreshes it, a lower one leaves it alone; saved in characters.json "rested" {level, until (unix seconds)}; cleared by death. Hooks built: health regeneration (the larger of the
# bed's and the buff's, never the product), hunger and thirst drain, skill gain, energy drain. Action speed (cooldowns and craft time, _pace_factor) and cold stress (warmth_target) are built too; the HUD line and its tooltip come with protocol 80 and 81. Not built: HUD icons.
var _comfort_cfg: Dictionary = {}
var _comfort_loaded: bool = false
var _comfort_cache: Dictionary = {}     # peer -> {"at": msec, "data": comfort_at result}


func _comfort_data() -> Dictionary:
	if not _comfort_loaded:
		_comfort_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/comfort.json"))
		_comfort_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

	return _comfort_cfg


func _comfort_kind(id: String) -> Dictionary:
	for row in _comfort_data().get("kinds", []):
		if str(row["id"]) == id:
			return row

	return {}


func comfort_at(peer: int, force: bool = false) -> Dictionary:
	var cfg: Dictionary = _comfort_data()
	var out: Dictionary = {"level": 0, "sheltered": false, "items": [], "missing": []}

	if cfg.is_empty() or not _peer_pos.has(peer):
		return out

	var now: int = Time.get_ticks_msec()
	var cached: Dictionary = _comfort_cache.get(peer, {})

	if not force and not cached.is_empty() and now - int(cached["at"]) < int(float(cfg.get("recheck_s", 1.5)) * 1000.0):
		return cached["data"]

	var here: Vector3 = _peer_pos[peer]
	var sheltered: bool = cover_at.is_valid() and float(cover_at.call(here)) > 0.0
	out["sheltered"] = sheltered

	if not sheltered:
		_comfort_cache[peer] = {"at": now, "data": out}
		return out

	var radius: float = float(cfg.get("radius_m", 9.0))
	var height: float = float(cfg.get("height_m", 3.0))
	var found: Dictionary = {}     # comfort kind id -> true (each kind once)

	for id in _items:
		var it: Dictionary = _items[id]
		var pos: Vector3 = it["pos"]

		if Vector2(pos.x - here.x, pos.z - here.z).length() > radius or absf(pos.y - here.y) > height:
			continue

		var kind_id: String = ""

		if it.has("fire"):
			if fire_is_lit(int(it["fire"]["state"])):
				kind_id = "campfire"
		elif it.has("struct"):
			var skind: String = str(it["struct"].get("kind", ""))
			var row: Dictionary = _structures.get(skind, {})
			kind_id = str(row.get("comfort", skind))

			if not _comfort_kind(kind_id).is_empty() and bool(_comfort_kind(kind_id).get("needs_lit", false)):
				if kind_id == "clay_hearth":
					kind_id = "clay_hearth" if _comfort_lit_fire_near(pos, 3.0) else ""
				elif not bool(it["struct"].get("lit", false)):
					kind_id = ""   # torches, chandeliers and fireplaces count only while lit

		if kind_id != "" and not _comfort_kind(kind_id).is_empty():
			found[kind_id] = true

	var level: int = int(cfg.get("shelter", {}).get("points", 1))
	var best_bed: int = 0
	var items: Array = []

	for kind_id in found:
		var kind: Dictionary = _comfort_kind(kind_id)
		var points: int = int(kind["points"])

		if str(kind.get("class", "")) == "bed":
			best_bed = maxi(best_bed, points)
			continue

		level += points
		items.append([kind_id, points, bool(kind.get("needs_lit", false))])

	level += best_bed

	if best_bed > 0:
		items.append(["bed", best_bed, false])

	out["level"] = clampi(level, 0, int(cfg.get("max_level", 20)))
	out["items"] = items
	_comfort_cache[peer] = {"at": now, "data": out}
	return out


# The tooltip of the comfort line (protocol 81): what counts now with its points, what a few more pieces would add, and the Rested buff with its bonuses and minutes left.
func comfort_tip(peer: int) -> String:
	var cfg: Dictionary = _comfort_data()
	var data: Dictionary = comfort_at(peer)
	var lines: PackedStringArray = PackedStringArray()

	if not bool(data["sheltered"]):
		lines.append("Comfort 0: you are not under a roof or a tree crown.")
		lines.append("Shelter gives +1, and then furniture and fire nearby count.")
	else:
		lines.append("Comfort %d of %d" % [int(data["level"]), int(cfg.get("max_level", 20))])
		lines.append("+%d  Shelter" % int(cfg.get("shelter", {}).get("points", 1)))
		var have: Dictionary = {}

		for row in data["items"]:
			var id: String = str(row[0])
			have[id] = true
			lines.append("+%d  %s" % [int(row[1]), _comfort_name(id)])

		var missing: Array = []

		for kind in cfg.get("kinds", []):
			var id: String = str(kind["id"])

			if have.has(id) or (str(kind.get("class", "")) == "bed" and have.has("bed")) or not (str(kind.get("status", "")) in ["live", "placeable"]):
				continue

			missing.append([int(kind["points"]), id, bool(kind.get("needs_lit", false))])

		missing.sort_custom(func(a, b): return a[0] > b[0])

		if not missing.is_empty():
			lines.append("Could add:")

			for n in mini(missing.size(), 5):
				lines.append("  +%d  %s%s" % [missing[n][0], _comfort_name(missing[n][1]), " (lit)" if missing[n][2] else ""])

	var tier: Dictionary = rested_tier(peer)

	if not tier.is_empty():
		lines.append("%s, %d min left:" % [str(tier.get("name", "Rested")), int(ceil(rested_seconds_left(peer) / 60.0))])
		lines.append_array(_rested_bonus_lines(tier))
	else:
		lines.append("Rest on a bed or sit 30 s at comfort 2 or more to become Rested.")

	return "\n".join(lines)


func _comfort_name(id: String) -> String:
	var words: String = id.replace("_", " ")
	return words.substr(0, 1).to_upper() + words.substr(1)


func _rested_bonus_lines(tier: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var rows: Array = [["regen_mult", "health regeneration +%d%%"], ["exhaustion_mult", "exhaustion %d%% slower"], ["hunger_thirst_mult", "hunger and thirst %d%% slower"], ["action_speed_mult", "work %d%% faster"], ["skill_gain_mult", "skill gain +%d%%"], ["cold_stress_mult", "cold %d%% weaker"]]

	for r in rows:
		var change: int = int(round(absf(float(tier.get(r[0], 1.0)) - 1.0) * 100.0))

		if change > 0:
			out.append("  " + str(r[1]) % change)

	return out


func _comfort_lit_fire_near(pos: Vector3, radius: float) -> bool:
	for id in _items:
		if _items[id].has("fire") and fire_is_lit(int(_items[id]["fire"]["state"])) and _items[id]["pos"].distance_to(pos) <= radius:
			return true

	return false


# The tier of the Rested buff a player has now ({} when none or run out): the comfort.json rested.tiers row picked when it was earned.
func rested_tier(peer: int) -> Dictionary:
	var row: Dictionary = _characters.get(_peer_key.get(peer, ""), {}).get("rested", {})

	if row.is_empty() or Time.get_unix_time_from_system() >= float(row.get("until", 0.0)):
		return {}

	var best: Dictionary = {}

	for tier in _comfort_data().get("rested", {}).get("tiers", []):
		if int(tier["min_level"]) <= int(row.get("level", 0)):
			best = tier

	return best


func rested_seconds_left(peer: int) -> float:
	var row: Dictionary = _characters.get(_peer_key.get(peer, ""), {}).get("rested", {})
	return maxf(float(row.get("until", 0.0)) - Time.get_unix_time_from_system(), 0.0)


# A rest was completed (slept, or lay on a good bed). At comfort 2 or more the buff is set or refreshed; a lower level than the buff in force changes nothing.
func rest_completed(peer: int, half: bool = false) -> bool:
	var key: String = str(_peer_key.get(peer, ""))
	var cfg: Dictionary = _comfort_data().get("rested", {})

	if key == "" or not _characters.has(key) or cfg.is_empty():
		return false

	var level: int = int(comfort_at(peer, true)["level"])

	if level < int(cfg.get("min_level_to_earn", 2)):
		var data: Dictionary = comfort_at(peer)

		if not bool(data["sheltered"]):
			_say(peer, "You are not sheltered: nothing here comforts you.")
		else:
			_say(peer, "It is too bare to rest well here (comfort 2 needed).")

		return false

	var current: Dictionary = _characters[key].get("rested", {})
	var minutes: float = float(cfg.get("comfort_buff_real_minutes", 45)) * (0.5 if half else 1.0)
	var active: bool = not current.is_empty() and Time.get_unix_time_from_system() < float(current.get("until", 0.0))

	if active and level < int(current.get("level", 0)):
		return false

	_characters[key]["rested"] = {"level": level, "until": Time.get_unix_time_from_system() + minutes * 60.0}
	_dirty = true
	_say(peer, "You feel rested.")
	return true


# Called every slow tick: lying on a good bed (awake or asleep) at comfort 2+ earns the buff once per rest; the buff ending is told once.
var send_comfort: Callable            # (peer, comfort level, rested tier level 0 = none, whole minutes of Rested left, tooltip text): the HUD line and its tooltip (protocol 80, 81)
var _comfort_sent: Dictionary = {}      # peer -> the last [level, rested level, minutes] told
const SIT_REST_S := 30.0
var _sit_s: Dictionary = {}             # peer -> seconds sat on a seat so far
var _rest_credit: Dictionary = {}       # peer -> true while this rest has already earned the buff
var _rested_told: Dictionary = {}       # peer -> true while "You feel rested" is in force (to say the end once)


func _comfort_tick(spent: float = 0.0) -> void:
	for peer in _peer_key.keys():
		if not _peer_pos.has(peer):
			continue

		# Sitting (stance 2) within 1.2 m of a seat piece for 30 s completes a rest too.
		if int(_stance.get(peer, 0)) == 2 and _seat_near(_peer_pos[peer]):
			_sit_s[peer] = float(_sit_s.get(peer, 0.0)) + spent

			if float(_sit_s[peer]) >= SIT_REST_S and not _rest_credit.has(peer):
				_rest_credit[peer] = true
				rest_completed(peer)
		else:
			_sit_s.erase(peer)

		var sitting_credit: bool = _sit_s.has(peer) and _rest_credit.has(peer)
		var resting: bool = _asleep.has(peer) or (int(_stance.get(peer, 0)) == 3 and on_good_bed(peer)) or sitting_credit

		if resting and not _rest_credit.has(peer):
			_rest_credit[peer] = true
			rest_completed(peer)
		elif not resting:
			_rest_credit.erase(peer)

		var rested: bool = not rested_tier(peer).is_empty()

		if send_comfort.is_valid():
			var told: Array = [int(comfort_at(peer)["level"]), int(_characters.get(_peer_key.get(peer, ""), {}).get("rested", {}).get("level", 0)) if rested else 0, int(ceil(rested_seconds_left(peer) / 60.0)) if rested else 0, comfort_tip(peer)]

			if _comfort_sent.get(peer, []) != told:
				_comfort_sent[peer] = told
				send_comfort.call(peer, told[0], told[1], told[2], told[3])

		if rested:
			_rested_told[peer] = true
		elif _rested_told.has(peer):
			_rested_told.erase(peer)
			_say(peer, "You no longer feel rested.")


# --- Camp goals' own checks (data/items/camp_goals.json, HINTS_AND_CAMP_EVENTS_SPEC.md section 2; Tyler 31 Oct 2026) ---
# worn_warmth {min}: the warmth of the worn pieces (items.json `warmth`, summed, capped at 0.85) is at least min. talked {npc, hour_between}: note_talked(peer, npc) is called when a
# dialogue with that NPC opens, and counts when the game hour is inside the band. moved_lit_night {metres}: walking while holding a torch (in the pack) or within 4 m of a lit fire, between
# dusk (hour 19) and dawn (hour 6); the metres are added up once a slow tick and kept in the goal counts.
var _night_last_pos: Dictionary = {}


func _worn_warmth(peer: int) -> float:
	var total: float = 0.0

	for number in worn_of(peer):
		if int(number) > 0:
			total += float(table.entry(table.id_of(int(number))).get("warmth", 0.0))

	return minf(total, 0.85)


func _game_hour() -> float:
	return fmod(float(game_seconds.call()) if game_seconds.is_valid() else 0.0, 86400.0) / 3600.0


func note_talked(peer: int, npc_id: String) -> void:
	var st: Dictionary = _goal_state_of(peer)

	if st.is_empty():
		return

	var hour: float = _game_hour()

	for goal in _goals_data():
		var check: Dictionary = goal.get("check", {})

		if str(check.get("event", "")) != "talked" or str(check.get("npc", npc_id)) != npc_id:
			continue

		var band: Array = check.get("hour_between", [])

		if band.size() == 2 and not (hour >= float(band[0]) and hour < float(band[1])):
			continue

		var key: String = "hit:" + str(goal["id"])
		st["goal_counts"][key] = int(st["goal_counts"].get(key, 0)) + 1
		_dirty = true

	_goals_check(peer)


func _night_walk_tick() -> void:
	var hour: float = _game_hour()
	var night: bool = hour >= 19.0 or hour < 6.0

	for peer in _peer_key.keys():
		if not _peer_pos.has(peer):
			continue

		var last: Vector3 = _night_last_pos.get(peer, _peer_pos[peer])
		_night_last_pos[peer] = _peer_pos[peer]
		var st: Dictionary = _goal_state_of(peer)

		if st.is_empty() or not night:
			continue

		var step: float = Vector2(_peer_pos[peer].x - last.x, _peer_pos[peer].z - last.z).length()

		if step <= 0.0 or step > 30.0:
			continue   # standing still, or a jump (respawn, teleport)

		var inv = inventory_of(peer)
		var lit: bool = _lit_fire_within(_peer_pos[peer], 4.0) or (inv != null and inv.count_of(table.number_of("torch")) > 0)

		if lit:
			st["goal_counts"]["moved_lit_night"] = float(st["goal_counts"].get("moved_lit_night", 0.0)) + step
			_dirty = true


var _dev_pending: Array = []          # [spec, seconds waited]: --dev-place specs still waiting for their ground


func dev_place_later(spec: String) -> void:
	_dev_pending.append([spec, 0.0])


# Once a second-ish (slow tick): tries each waiting spec; a spec that placed is dropped, one still without ground after 180 s is given up with a line in the log.
func _dev_pending_tick(spent: float) -> void:
	for entry in _dev_pending.duplicate():
		var made: int = dev_place(str(entry[0]))

		if made != 0:
			print("server: dev-place %s -> world id %d" % [str(entry[0]), made])
			_dev_pending.erase(entry)
		else:
			entry[1] = float(entry[1]) + spent

			if float(entry[1]) > 180.0:
				print("server: dev-place %s NOT placed (unknown name, or no ground there)" % str(entry[0]))
				_dev_pending.erase(entry)


# --- Testing only: place structures without a kit (for screenshots and rigs) -------------------------------------------------------------------------------------------
# The server scene calls this for each `--dev-place=name@x,z,yaw[,lit]` argument (repeatable); nothing else calls it, so normal play never runs it. `name` is a structure
# kind of structures.json (lean_to, rough_bed, fireplace, wall_torch, chandelier, chest, workbench ...), x and z world metres (the ground height is taken from the ground),
# yaw degrees; the word `lit` lights a light or a fire, `coals` or `ash` lays a campfire burnt down to glowing coals or warm ash, and `firewood` or `log` makes a lit campfire
# medium or large (its wood; weak wood, a small fire, without). A fire name (`campfire`) lays a campfire. Returns the world id, 0 when the name or the ground is unknown.
func dev_place(spec: String) -> int:
	var parts: PackedStringArray = spec.split("@")

	if parts.size() != 2 or not ground_height.is_valid():
		return 0

	var name: String = parts[0].strip_edges()
	var nums: PackedStringArray = parts[1].split(",")

	if nums.size() < 2:
		return 0

	var x: float = float(nums[0])
	var z: float = float(nums[1])
	var yaw: float = float(nums[2]) if nums.size() > 2 and nums[2].is_valid_float() else 0.0
	var lit: bool = nums.has("lit")
	var y: float = float(ground_height.call(x, z))

	if is_nan(y):
		return 0

	var at: Vector3 = Vector3(x, y, z)

	if name == "campfire" and (nums.has("coals") or nums.has("ash")):   # a burnt-out bed: glowing coals (76) or warm ash (77), at the start of its time
		var coals: bool = nums.has("coals")
		_items[_next_id] = {"number": table.number_of("campfire_kit"), "count": 1, "pos": at, "left": float(_coals_cfg().get("coals_s" if coals else "ash_s", 7200.0 if coals else 43200.0)),
			"fire": {"state": FIRE_STATE_COALS if coals else FIRE_STATE_ASH, "burn_left": 0.0, "wood": {"log": 0.0, "firewood": 0.0, "weak": 0.0}, "covered": false, "recheck": COVER_RECHECK_S}}
		_lit_valid = false
		_next_id += 1
		_dirty = true
		return _next_id - 1

	if name == "campfire":
		var wood_class: String = "log" if nums.has("log") else ("firewood" if nums.has("firewood") else "weak")   # the fire's size follows its wood (cooking.json fire_tiers)
		var wood: Dictionary = {"log": 0.0, "firewood": 0.0, "weak": 0.0}
		wood[wood_class] = 36000.0
		var lit_state: int = int(((_cooking.get("fire_tiers", {}) as Dictionary).get(wood_class, {}) as Dictionary).get("state", 1))
		_items[_next_id] = {"number": table.number_of("campfire_kit"), "count": 1, "pos": at, "left": 1.0e9, "fire": {"state": lit_state if lit else 9, "burn_left": 36000.0, "wood": wood, "covered": false, "recheck": COVER_RECHECK_S}}
		_lit_valid = false
		_next_id += 1
		_dirty = true
		return _next_id - 1

	var def: Dictionary = _structures.get(name, {})

	if def.is_empty():
		return 0

	var row: Dictionary = {"kind": name, "yaw": float(posmod(int(yaw), 360))}

	if lit:
		row["lit"] = true
		row["fuel_left"] = light_burn_s(def, 3600.0) * 2.0

	var entry: Dictionary = {"number": table.number_of(str(def.get("item", name))), "count": 1, "pos": at, "left": 1.0e9, "struct": row}

	if int(def.get("slots", 0)) > 0:
		row["uid"] = _next_uid
		_chests[_next_uid] = InventoryScript.new(table)
		_next_uid += 1

	_items[_next_id] = entry
	_grid_add(_next_id, entry)
	_next_id += 1
	_add_roof(entry)
	_dirty = true
	return _next_id - 1


# --- Hints (data/items/hints.json by Sal, HINTS_AND_CAMP_EVENTS_SPEC.md; Tyler 31 Oct 2026) ---
# A hint is a one-line notice (the same line as the goal notices) said once per character and hint id when its trigger becomes true; the ids said are saved in
# characters.json "hints_seen". Triggers by name (below); a trigger the server cannot judge (beach_with_container) never fires.
# A hint whose goal is still open HINT_REPEAT_S (5 minutes) after it was said is said once more.
const HINT_REPEAT_S := 300.0
var _hints: Array = []
var _hints_loaded: bool = false
var _hint_origin: Dictionary = {}     # peer -> first position seen (the "moved" trigger)


func _hints_data() -> Array:
	if not _hints_loaded:
		_hints_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/hints.json"))
		_hints = parsed.get("hints", []) if typeof(parsed) == TYPE_DICTIONARY else []

	return _hints


# Fresh fruit that spoils fast (the "fruit_in_pack" hint): picked from trees, not cooked or dried.
const HINT_FRUIT := ["wild_apples", "apple_early", "apple_summer", "apple_autumn", "apple_keeping", "apple_cooking", "pear_summer", "pear_autumn", "pear_winter", "sour_cherries", "plums", "damsons", "quince", "medlar", "figs", "pomegranates", "mangoes", "oranges", "lemons"]


func _hint_count(st: Dictionary, key: String) -> int:
	return int(st["goal_counts"].get(key, 0))


# _hint_trigger_true, noting the slowest trigger of this goals tick (the slow-tick line).
func _timed_trigger(peer: int, st: Dictionary, trigger: String) -> bool:
	var t0: int = Time.get_ticks_usec()
	var out: bool = _hint_trigger_true(peer, st, trigger)
	var spent: int = Time.get_ticks_usec() - t0

	if spent > _slowest_hint_usec:
		_slowest_hint_usec = spent
		_slowest_hint = trigger

	return out


func _hint_trigger_true(peer: int, st: Dictionary, trigger: String) -> bool:
	var inv = inventory_of(peer)

	if inv == null or not _peer_pos.has(peer):
		return false

	var v: Dictionary = vitals_of(peer)
	var hour: float = fmod(float(game_seconds.call()) if game_seconds.is_valid() else 0.0, 86400.0) / 3600.0

	match trigger:
		"first_frame":
			return true
		"moved":
			return _hint_origin.has(peer) and (_hint_origin[peer] as Vector3).distance_to(_peer_pos[peer]) >= 5.0
		"water_in_view":
			return water_near.is_valid() and bool(water_near.call(_peer_pos[peer], 20.0)) and not v.is_empty() and float(v.get("wet", 0.0)) < float(_vitals_cfg.get("thirst", {}).get("cap_ml", 2400)) - 1.0
		"after_drink":
			return _hint_count(st, "event:drink") >= 1
		"8_sticks":
			return inv.count_of(table.number_of("stick")) >= 8
		"12_fibre":
			return inv.count_of(table.number_of("plant_fibre")) >= 12
		"2_twine_1_stone_1_stick":
			return inv.count_of(table.number_of("twine")) >= 2 and inv.count_of(table.number_of("stone")) >= 1 and inv.count_of(table.number_of("stick")) >= 1
		"axe_made":
			return _hint_count(st, "made:stone_axe") >= 1
		"tree_down":
			return _hint_count(st, "event:tree_felled") >= 1
		"6_sticks_3_stones":
			return inv.count_of(table.number_of("stick")) >= 6 and inv.count_of(table.number_of("stone")) >= 3
		"kit_made":
			return _hint_count(st, "made:campfire_kit") >= 1
		"fire_placed":
			return _hint_count(st, "event:placed:campfire") >= 1
		"fire_lit":
			return _hint_count(st, "event:fire_lit") >= 1
		"hungry":
			return not v.is_empty() and int(_vitals_points(v)[0]) < 80
		"fire_burning_cold":
			return _hint_count(st, "event:fire_lit") >= 1 and not v.is_empty() and float(v.get("warmth", 100.0)) < 70.0
		"leanto_made":
			return inv.count_of(table.number_of("wooden_hammer")) >= 1   # the shelter is a hammer blueprint now: with the hammer in the pack, the next step is to click it down
		"leanto_placed":
			return _hint_count(st, "event:placed:lean_to") >= 1
		"bed_placed":
			return _hint_count(st, "event:placed:rough_bed") >= 1
		"workbench_placed":   # the camp bench or the log workbench (Dino round 6)
			return _hint_count(st, "event:placed:workbench") + _hint_count(st, "event:placed:log_workbench") >= 1
		"axe_held_near_tree":   # an axe on the hotbar and a standing tree within 6 m (any axe on the hotbar where the tree index is not wired)
			if _tool_slot(inv, "axe") < 0:
				return false

			if trees_near_cached.is_valid():
				return not (trees_near_cached.call(_peer_pos[peer], 6.0) as Array).is_empty()

			return not trees_near.is_valid() or not (trees_near.call(_peer_pos[peer], 6.0) as Array).is_empty()
		"has_campfire_kit":
			return inv.count_of(table.number_of("campfire_kit")) >= 1
		"near_fire_with_food":   # raw meat or fish in the pack, a lit fire within 4 m
			return _lit_fire_within(_peer_pos[peer], 4.0) and _has_raw_meat(inv)
		"has_sea_water":
			return inv.count_of(table.number_of("sea_water")) >= 1
		"beach_with_container", "beach_with_bucket":   # a water container in the pack at the sea edge (ACT_GATHER_EDGE reach)
			var carries: bool = false

			for container in (["bucket"] if trigger == "beach_with_bucket" else ["bucket", "clay_jug", "waterskin"]):
				carries = carries or inv.count_of(table.number_of(container)) >= 1

			return carries and _sea_near(_peer_pos[peer], float(_shore_data().get("reach_m", 4.0)))
		"near_nettle":   # no flora query for small plants on the server: the first nettles in the pack stand in for "near a nettle"
			return inv.count_of(table.number_of("nettles")) >= 1
		"spear_made":
			return _hint_count(st, "made:spear") >= 1
		"warmth_under_70":
			return not v.is_empty() and float(v.get("warmth", 100.0)) < 70.0
		"dusk":
			return hour >= 18.0 and hour < 20.0
		"has_plant_food_at_fire":
			return _plant_food_at_fire(peer, inv)
		"campfire_pot_placed":
			return _hint_count(st, "event:placed:campfire_pot") >= 1
		"digging_under_ceiling":   # the first dig more than 2.5 m under the surface (_dig)
			return _hint_count(st, "event:dug_under") >= 1
		"fruit_in_pack":
			for fruit in HINT_FRUIT:
				if table.number_of(str(fruit)) > 0 and inv.count_of(table.number_of(str(fruit))) >= 1:
					return true

			return false
		"near_fruit_tree_in_season":   # a fruit tree in fruit within 8 m
			return _fruit_trees_near(_peer_pos[peer], 8.0, true) >= 1
		"near_orchard":   # four or more fruit trees within 25 m
			return _fruit_trees_near(_peer_pos[peer], 25.0, false) >= 4
		"season_changes":   # the season stamp is not the one this player last saw (the first look only records it)
			var stamp: int = int(season_stamp.call()) if season_stamp.is_valid() else 0
			var seen: int = int(st.get("season_seen", -1))
			st["season_seen"] = stamp
			return seen >= 0 and seen != stamp
		"autumn_end":   # the last quarter of autumn
			if not season_now.is_valid() or str(season_now.call()) != "autumn" or not game_seconds.is_valid():
				return false

			var day: int = int(floorf(float(game_seconds.call()) / 86400.0)) % 365
			return fmod(float(day) * 4.0 / 365.0, 1.0) >= 0.75

	return false


# Fruit trees (drops.json "fruit_tree") standing within r metres of the point; in_fruit_only counts only those whose flora row is in season.
func _fruit_trees_near(pos: Vector3, r: float, in_fruit_only: bool) -> int:
	var fruit: Dictionary = _drops.get("fruit_tree", {})
	var season: String = str(season_now.call()) if season_now.is_valid() else "all"
	var count: int = 0

	for tree in _standing_trees(pos, r):
		var species: String = str(tree[1])

		if not fruit.has(species):
			continue

		if in_fruit_only and not GatherRules.in_season(_flora_by_name.get(species, {}), season):
			continue

		count += 1

	return count


# [position, species name] of the standing trees within r metres, for the hint triggers: the server's cached look when it has one (trees_near_cached), else
# trees_near and tree_info (tests).
func _standing_trees(pos: Vector3, r: float) -> Array:
	if trees_near_cached.is_valid():
		return trees_near_cached.call(pos, r)

	if not trees_near.is_valid() or not tree_info.is_valid():
		return []

	var out: Array = []

	for found in trees_near.call(pos, r):
		var info: Dictionary = tree_info.call(found[0], int(found[1]))

		if not info.is_empty():
			out.append([info.get("position", pos), str(info.get("name", ""))])

	return out


# Hint trigger has_plant_food_at_fire (Sal's tutorial steps 23 and 24): the player stands within 4 m of a lit fire with an ingredient of a campfire_pot or clay hearth recipe in the pack
# (berries, nectar, pears ...; the plain campfire does not cook plants) and no campfire pot stands at that fire yet. The ingredient set is read from recipes.json by station.
func _plant_food_at_fire(peer: int, inv) -> bool:
	var pos: Vector3 = _peer_pos[peer]

	if not _lit_fire_within(pos, 4.0) or _struct_kind_within(pos, "campfire_pot", 4.0):
		return false

	for number in recipes.numbers():
		var r: Dictionary = recipes.recipe(int(number))

		if not (str(r.get("station", "")) in ["campfire_pot", "clay_hearth"]) or not (str(r.get("category", "")) in ["Food and drink"]):
			continue

		for need in r["needs"]:
			if int(need[0]) > 0 and inv.count_of(int(need[0])) >= int(need[1]) and not _cooking.get("cooks_into", {}).has(table.id_of(int(need[0]))):   # meat and fish are what the plain campfire cooks
				return true

	return false


# True when the pack holds something the plain campfire cooks (cooking.json cooks_into: raw meat and fish).
func _has_raw_meat(inv) -> bool:
	for id in _cooking.get("cooks_into", {}):
		var number: int = table.number_of(str(id))

		if number > 0 and inv.count_of(number) >= 1:
			return true

	return false


# True when a placed structure of this kind stands within r metres of the point.
func _struct_kind_within(pos: Vector3, kind: String, r: float) -> bool:
	for id in _items:
		var it: Dictionary = _items[id]

		if it.has("struct") and str(it["struct"].get("kind", "")) == kind and (it["pos"] as Vector3).distance_to(pos) <= r:
			return true

	return false


# Looks at every hint for one player: says the ones whose trigger holds and that were not said yet (or whose goal is still open 5 minutes after).
func _hints_check(peer: int) -> void:
	var st: Dictionary = _goal_state_of(peer)

	if st.is_empty() or _hints_data().is_empty() or not _peer_pos.has(peer):
		return

	if not _hint_origin.has(peer):
		_hint_origin[peer] = _peer_pos[peer]

	if typeof(st.get("hints_seen", null)) != TYPE_DICTIONARY:
		st["hints_seen"] = {}

	var now_s: float = Time.get_unix_time_from_system()

	for hint in _hints_data():
		var id: String = str(hint["id"])
		var said_at: float = float(st["hints_seen"].get(id, 0.0))
		var goal: String = str(hint.get("goal", ""))

		if said_at > 0.0:
			var again: bool = goal != "" and not st["goals_done"].has(goal) and not st["hints_seen"].has(id + "#again") and now_s - said_at >= HINT_REPEAT_S

			if not again:
				continue

			st["hints_seen"][id + "#again"] = now_s
		elif not _timed_trigger(peer, st, str(hint.get("trigger", ""))):
			continue
		else:
			st["hints_seen"][id] = now_s

		if goal != "" and st["goals_done"].has(goal):
			continue   # the goal is already done: the hint would only nag

		_say(peer, str(hint.get("text", "")))
		_dirty = true
		return   # one hint at a time


# Starter goals (data/items/starter_goals.json by Sal; Tyler 31 Oct 2026): an ordered list of small first-hour goals. A goal is open when every goal in its `after` is done.
# Checks: {event, count, what?} (the server calls _goal_event: drink, tree_felled, fire_lit, ate_food, placed what, carcass_worked), {made_item, count} (crafts that
# finished), {have_item, count} and {have_item_any: [ids], count} (true while the pack holds that many, looked at every slow tick). Events and crafts are counted from the
# start of the character, so an early fire counts when its goal opens. A goal is done once and saved per character (characters.json goals_done and goal_counts); the reward
# ({coin_copper: n} into the purse, or {item: [id, n]} into the pack) is given when it completes, and the player is told the goal and the next hint through the notice line.
# The goal list on the screen needs a protocol message and a client list; until then the notices carry it, and goals_state(peer) is what that message would send.
var _goals: Array = []
var _goals_loaded: bool = false


func _goals_data() -> Array:
	if not _goals_loaded:
		_goals_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/starter_goals.json"))
		_goals = parsed.get("goals", []) if typeof(parsed) == TYPE_DICTIONARY else []
		var camp: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/camp_goals.json")) if FileAccess.file_exists("res://data/items/camp_goals.json") else {}

		if typeof(camp) == TYPE_DICTIONARY:
			_goals = _goals + (camp.get("goals", []) as Array)   # the camp and winter goals follow the starter ones (their `after` may name a starter goal)

	return _goals


func _goal_state_of(peer: int) -> Dictionary:
	var key: String = str(_peer_key.get(peer, ""))

	if key == "" or not _characters.has(key):
		return {}

	for name in ["goals_done", "goal_counts"]:
		if typeof(_characters[key].get(name, null)) != TYPE_DICTIONARY:
			_characters[key][name] = {}

	return _characters[key]


func _goal_count_key(name: String, what: String) -> String:
	return "event:" + name + (":" + what if what != "" else "")


func _goal_event(peer: int, name: String, what: String = "") -> void:
	var st: Dictionary = _goal_state_of(peer)

	if st.is_empty() or _goals_data().is_empty():
		return

	var plain: String = _goal_count_key(name, "")
	st["goal_counts"][plain] = int(st["goal_counts"].get(plain, 0)) + 1

	if what != "":
		var specific: String = _goal_count_key(name, what)
		st["goal_counts"][specific] = int(st["goal_counts"].get(specific, 0)) + 1

	_dirty = true
	_goals_check(peer)


func _goal_made(peer: int, item: int) -> void:
	var st: Dictionary = _goal_state_of(peer)

	if st.is_empty() or _goals_data().is_empty():
		return

	var k: String = "made:" + table.id_of(item)
	st["goal_counts"][k] = int(st["goal_counts"].get(k, 0)) + 1
	_dirty = true
	_goals_check(peer)


func _goal_met(peer: int, st: Dictionary, check: Dictionary, goal_id: String = "") -> bool:
	var need: int = int(check.get("count", 1))
	var inv = inventory_of(peer)

	if str(check.get("event", "")) == "worn_warmth":
		return _worn_warmth(peer) >= float(check.get("min", 0.7))

	if str(check.get("event", "")) == "talked":
		return int(st["goal_counts"].get("hit:" + goal_id, 0)) >= need

	if str(check.get("event", "")) == "moved_lit_night":
		return float(st["goal_counts"].get("moved_lit_night", 0.0)) >= float(check.get("metres", 100.0))

	if check.has("event") and check.has("what_any"):   # any of these kinds counts: the camp bench or the log workbench (Dino round 6)
		var total: int = 0

		for what in check["what_any"]:
			total += int(st["goal_counts"].get(_goal_count_key(str(check["event"]), str(what)), 0))

		return total >= need

	if check.has("event"):
		return int(st["goal_counts"].get(_goal_count_key(str(check["event"]), str(check.get("what", ""))), 0)) >= need

	if check.has("made_item"):
		var made: int = int(st["goal_counts"].get("made:" + str(check["made_item"]), 0))

		if bool(check.get("or_have", false)) and inv != null:   # a bought one counts too (Hob sells the stone axe; Dino round 6)
			made = maxi(made, inv.count_of(table.number_of(str(check["made_item"]))))

		return made >= need

	if inv == null:
		return false

	if check.has("have_item"):
		return inv.count_of(table.number_of(str(check["have_item"]))) >= need

	if check.has("have_item_any"):
		var total: int = int(st["goal_counts"].get(_goal_count_key(str(check["or_event"]), ""), 0)) if check.has("or_event") else 0   # a catch counts though the fish was eaten

		for id in check["have_item_any"]:
			total += inv.count_of(table.number_of(str(id)))

		return total >= need

	return false


func _goal_open(st: Dictionary, goal: Dictionary) -> bool:
	for before in goal.get("after", []):
		if not st["goals_done"].has(str(before)):
			return false

	return true


# Completes every open goal that is met (one pass can open the next, so it loops until nothing changes).
func _goals_check(peer: int) -> void:
	var st: Dictionary = _goal_state_of(peer)

	if st.is_empty():
		return

	var changed: bool = true

	while changed:
		changed = false

		for goal in _goals_data():
			var id: String = str(goal["id"])

			if st["goals_done"].has(id) or not _goal_open(st, goal) or not _goal_met(peer, st, goal.get("check", {}), id):
				continue

			st["goals_done"][id] = true
			changed = true
			_dirty = true
			var reward: Dictionary = goal.get("reward", {})

			if reward.has("coin_copper"):
				add_coins(peer, int(reward["coin_copper"]), "goal")

			if reward.has("item"):
				give(peer, table.number_of(str(reward["item"][0])), int(reward["item"][1]))

			_say(peer, "Goal done: %s" % str(goal.get("title", id)))

			for next in _goals_data():
				if not st["goals_done"].has(str(next["id"])) and (next.get("after", []) as Array).has(id) and _goal_open(st, next):
					_say(peer, "Next: %s. %s" % [str(next.get("title", "")), str(next.get("hint", ""))])
					break


func _goals_tick() -> void:
	if _goals_data().is_empty():
		return

	var t0: int = Time.get_ticks_usec()
	_night_walk_tick()
	var t1: int = Time.get_ticks_usec()
	var goals_usec: int = 0
	_slowest_hint_usec = 0
	_slowest_hint = ""

	# Hints are looked at every HINT_EVERY_TICKS slow ticks (about once a second), not 4 times a second: the tree triggers
	# (near_orchard, near_fruit_tree_in_season) scan the trees of nine flora chunks each look (lag run 5 Nov: hints 18 to 76 ms a tick).
	_hint_ticks += 1
	var hints_now: bool = _hint_ticks >= hint_every

	if hints_now:
		_hint_ticks = 0

	for peer in _peer_key.keys():
		var tg: int = Time.get_ticks_usec()
		_goals_check(peer)
		goals_usec += Time.get_ticks_usec() - tg

		if hints_now:
			_hints_check(peer)

	# For the slow-tick line (lag run 5 Nov: goals 43 and 102 ms, no split).
	_goals_detail = "(night walk %.0f, goals %.0f, hints %.0f, slowest hint trigger %s %.0f)" % [float(t1 - t0) / 1000.0, float(goals_usec) / 1000.0,
		float(Time.get_ticks_usec() - t1 - goals_usec) / 1000.0, _slowest_hint, float(_slowest_hint_usec) / 1000.0]


# What the goal list would show: [[id, title, hint, state]] with state 0 locked, 1 open, 2 done.
func goals_state(peer: int) -> Array:
	var st: Dictionary = _goal_state_of(peer)
	var rows: Array = []

	if st.is_empty():
		return rows

	for goal in _goals_data():
		var state: int = 2 if st["goals_done"].has(str(goal["id"])) else (1 if _goal_open(st, goal) else 0)
		rows.append([str(goal["id"]), str(goal.get("title", "")), str(goal.get("hint", "")), state])

	return rows


# --- Logs from the shoulder and the ground (guide finding F-16, moderator decision for Dave, 31 Oct 2026) ---
# A log is carried on the shoulder (one at a time) and a cut log lies on the ground; neither is in the pack. A craft or blueprint that needs the log group (plain `log`)
# takes its logs in this order: the log on the shoulder, then log items lying on the ground within LOG_NEAR_M of the player, then the pack. The ones taken from the
# shoulder or the ground move into the pack at that moment and are used up by the craft like any ingredient (a craft that is refused takes nothing). The player is told
# "Using nearby logs". Ground logs go with the same authority as a pickup (removed on the server, the clients see them vanish).
const LOG_NEAR_M := 3.0


func _log_need(rows: Array, times: int) -> int:
	var log_n: int = table.number_of("log")
	var total: int = 0

	for need in rows:
		if int(need[0]) == log_n and log_n > 0:
			total += int(need[1]) * times

	return total


# Log items lying on the ground within reach of the player: [[world id, count], ...], nearest first.
func _ground_logs_near(peer: int) -> Array:
	var out: Array = []

	if not _peer_pos.has(peer):
		return out

	var members: PackedInt32Array = table.group_members(table.number_of("log"))

	for id in _items:
		var it: Dictionary = _items[id]

		if it.has("scatter") or it.has("tree") or it.has("fire") or it.has("struct") or it.has("boulder") or not members.has(int(it.get("number", 0))):
			continue

		var d: float = _peer_pos[peer].distance_to(it["pos"])

		if d <= LOG_NEAR_M:
			out.append([id, int(it["count"]), d])

	out.sort_custom(func(a, b): return float(a[2]) < float(b[2]))
	return out


# How many logs the shoulder and the ground near the player offer.
func logs_near_count(peer: int) -> int:
	var total: int = 0   # the carried log is a pack item and counted with the pack

	for row in _ground_logs_near(peer):
		total += int(row[1])

	return total


# Moves up to `want` logs (shoulder first, then the ground) into the pack when the pack plus those logs can cover `want`; returns how many moved. Takes nothing when they cannot.
func _pull_nearby_logs(peer: int, inv, want: int) -> int:
	if want <= 0 or inv == null or not _peer_pos.has(peer):
		return 0

	var log_n: int = table.number_of("log")

	if inv.count_fill(log_n) + logs_near_count(peer) < want:
		return 0

	var moved: int = 0
	var key: String = str(_peer_key.get(peer, ""))

	for row in _ground_logs_near(peer):
		if moved >= want:
			break

		var it: Dictionary = _items.get(int(row[0]), {})
		var take: int = mini(int(row[1]), want - moved)

		if it.is_empty() or inv.add(int(it["number"]), take) > 0:
			continue

		if int(it["count"]) > take:
			it["count"] = int(it["count"]) - take
		else:
			_items.erase(int(row[0]))

		moved += take

	if moved > 0:
		_dirty = true
		_say(peer, "Using nearby logs")

	return moved


# Recipe learning (guide finding F-01, LEARN_SYSTEM_SPEC.md; Tyler 31 Oct 2026). A recipe is known when its table row says known (the data decides what a first-day
# player gets), or the character has learned it. Learned recipes are saved with the character (characters.json "learned": recipe numbers).
# A character learns an unknown recipe (1) by discovery: it holds every ingredient and stands at the station the recipe needs; (2) by seeing: the item the recipe
# makes is in the pack. Checked when the recipe is asked for and every LEARN_TICK_S for every player. One line is said: "You work out how to make X".
const LEARN_TICK_S := 10.0
var _learn_clock: float = 0.0


func _learned_of(peer: int) -> Dictionary:
	var key: String = str(_peer_key.get(peer, ""))

	if key == "" or not _characters.has(key):
		return {}

	if typeof(_characters[key].get("learned", null)) != TYPE_DICTIONARY:
		_characters[key]["learned"] = {}

	return _characters[key]["learned"]


func recipe_known_for(peer: int, recipe: Dictionary) -> bool:
	return bool(recipe.get("known", false)) or _learned_of(peer).has(str(int(recipe.get("number", -1))))


# Learns the recipe if the character qualifies; true when it is known afterwards.
func _try_learn(peer: int, inv, recipe: Dictionary) -> bool:
	if recipe_known_for(peer, recipe):
		return true

	if bool(recipe.get("locked", false)):
		return false   # a chain it depends on does not exist yet (recipes.json "locked"): discovery and seeing do not teach it

	var learned: Dictionary = _learned_of(peer)

	if inv == null or recipe.is_empty() or not _characters.has(str(_peer_key.get(peer, ""))):
		return false

	var seen: bool = inv.count_of(int(recipe["gives"][0])) > 0
	var station_ok: bool = str(recipe.get("station", "")) == "" or station_near(peer, str(recipe["station"]), int(recipe.get("station_level", 1)))
	var discovered: bool = station_ok and _pack_covers(inv, recipe, 1)

	if not seen and not discovered:
		return false

	learned[str(int(recipe["number"]))] = true
	_dirty = true
	_say(peer, "You work out how to make %s" % table.in_sentence(str(recipe.get("name", "that"))))
	return true


func _learn_tick() -> void:
	for peer in _peer_key.keys():
		var inv = inventory_of(peer)

		if inv == null or not _peer_pos.has(peer):
			continue

		for number in recipes.numbers():
			var r: Dictionary = recipes.recipe(int(number))

			if not bool(r.get("known", false)):
				_try_learn(peer, inv, r)


# --- Crafting stock (docs/design/INVENTORY_CRAFTING_REPORT.md step 2; src/shared/craft_stock.gd) ---
# A craft draws on the pack, then loose stacks lying within CraftStock.LOOSE_STOCK_M, then the player's own storage containers within
# CraftStock.CRAFT_REACH_M, nearest first, skipping any ticked "keep out". Never a stranger's chest, and never a fire's store (fires are fuel).
# A container gets its owner when it is placed; one saved before that belongs to the first player who opens it.

# A storage container: a placed chest with slots, not a fire's store and not a take-only container (remains).
func _is_storage(it: Dictionary) -> bool:
	if it.has("fire") or not it.has("struct") or not it["struct"].has("uid") or not _chests.has(int(it["struct"]["uid"])) or it["struct"].has("site"):
		return false

	var def: Dictionary = _structures.get(str(it["struct"]["kind"]), {})
	return int(def.get("slots", 0)) > 0 and not bool(def.get("take_only", false))


# The containers a craft or a blueprint site may use: [[world id, inventory, distance], ...], nearest first.
func _craft_boxes(peer: int) -> Array:
	return _stock_of(peer)["boxes"]


# A loose item that counts as ground stock: not scatter, trees, fires, structures or boulders (the same as building's ground stock).
func _is_loose(it: Dictionary) -> bool:
	return not (it.has("scatter") or it.has("tree") or it.has("fire") or it.has("struct") or it.has("boulder")) and int(it.get("number", 0)) > 0


# One pass over the world items for one craft request: {"boxes": [[world id, inventory, distance], ...] nearest first (_craft_boxes),
# "near": [[world id, distance], ...] the loose items within CraftStock.LOOSE_STOCK_M, nearest first}. The stock functions below take it.
func _stock_of(peer: int) -> Dictionary:
	var boxes: Array = []
	var near: Array = []

	if not _peer_pos.has(peer):
		return {"boxes": boxes, "near": near}

	var key: String = str(_peer_key.get(peer, ""))

	for sid in _items:
		var s: Dictionary = _items[sid]

		if _is_loose(s):
			var near_d: float = (s["pos"] as Vector3).distance_to(_peer_pos[peer])

			if near_d <= CraftStock.LOOSE_STOCK_M:
				near.append([sid, near_d])
		elif _is_storage(s):
			var box_d: float = (s["pos"] as Vector3).distance_to(_peer_pos[peer])

			if CraftStock.box_counts(str(s["struct"].get("owner", "")), bool(s["struct"].get("keep_out", false)), key, box_d):
				boxes.append([sid, _chests[int(s["struct"]["uid"])], box_d])

	boxes.sort_custom(func(a, b): return float(a[2]) < float(b[2]))
	near.sort_custom(func(a, b): return float(a[1]) < float(b[1]))
	return {"boxes": boxes, "near": near}


# Loose stacks of an ingredient (or any member of its group: a `log` need takes any log) near the player: [[world id, count], ...], nearest first.
func _craft_ground(stock: Dictionary, number: int, inv) -> Array:
	var out: Array = []

	if number <= 0 or inv == null:
		return out

	var fills: PackedInt32Array = inv.fills_of(number)

	for row in stock.get("near", []):
		var it: Dictionary = _items.get(int(row[0]), {})

		if not it.is_empty() and fills.has(int(it.get("number", 0))):
			out.append([int(row[0]), int(it["count"])])

	return out


# How much of an ingredient the craft stock holds: the pack, the ground near the player and their containers (`stock` from _stock_of).
func _stock_have(inv, number: int, stock: Dictionary) -> int:
	if inv == null:
		return 0

	var total: int = inv.count_fill(number)

	for row in _craft_ground(stock, number, inv):
		total += int(row[1])

	for box in stock.get("boxes", []):
		total += box[1].count_fill(number)

	return total


# Takes up to `want` of an ingredient: the pack first, then the ground near the player, then the containers nearest first. Returns how many it took.
func _stock_take(inv, number: int, want: int, stock: Dictionary) -> int:
	if inv == null or want <= 0:
		return 0

	var boxes: Array = stock.get("boxes", [])
	var ground: Array = _craft_ground(stock, number, inv)
	var have: Array = [inv.count_fill(number)]

	for row in ground:
		have.append(int(row[1]))

	for box in boxes:
		have.append(box[1].count_fill(number))

	var plan: Array = CraftStock.take_plan(want, have)
	var took: int = 0

	if int(plan[0]) > 0 and inv.remove_fill(number, int(plan[0])):
		took += int(plan[0])

	for i in ground.size():
		var share: int = int(plan[1 + i])
		var it: Dictionary = _items.get(int(ground[i][0]), {})

		if share <= 0 or it.is_empty():
			continue

		if int(it["count"]) > share:
			it["count"] = int(it["count"]) - share
		else:
			_items.erase(int(ground[i][0]))

		took += share
		_dirty = true

	for i in boxes.size():
		var share: int = int(plan[1 + ground.size() + i])

		if share > 0 and boxes[i][1].remove_fill(number, share):
			took += share
			_push_box(int(boxes[i][0]), boxes[i][1])   # whoever has that chest open sees it go
			_dirty = true

	return took


# Does the craft stock hold everything `times` crafts of a recipe need (kept tools once)?
func _stock_covers(inv, recipe: Dictionary, times: int, stock: Dictionary) -> bool:
	for need in recipe["needs"]:
		if _stock_have(inv, int(need[0]), stock) < int(need[1]) * clampi(times, 1, CRAFT_QUEUE_MAX_COUNT):
			return false

	for keep in recipe["keeps"]:
		if _stock_have(inv, int(keep[0]), stock) < int(keep[1]):
			return false

	return true


# What a craft may use besides the pack, sent to the player (protocol 98) when their crafting window opens (ACT_CRAFT_STOCK), after each craft
# request and after a "keep out" change: item number -> count, the ground near them and their containers in reach. The client adds the pack.
func _send_stock(peer: int) -> void:
	if not send_craft_stock.is_valid() or not _peer_pos.has(peer):
		return

	var counts: Dictionary = {}
	var stock: Dictionary = _stock_of(peer)

	for row in stock["near"]:
		var it: Dictionary = _items[int(row[0])]
		counts[int(it["number"])] = int(counts.get(int(it["number"]), 0)) + int(it["count"])

	for box in stock["boxes"]:
		for slot in box[1].SLOTS:
			if int(box[1].numbers[slot]) != 0:
				counts[int(box[1].numbers[slot])] = int(counts.get(int(box[1].numbers[slot]), 0)) + int(box[1].counts[slot])

	var numbers: PackedInt32Array = PackedInt32Array()
	var amounts: PackedInt32Array = PackedInt32Array()

	for number in counts:
		numbers.append(int(number))
		amounts.append(int(counts[number]))

	send_craft_stock.call(peer, numbers, amounts)


# The open container's "keep out" tick to the player, and whether they may change it (their own storage container).
func _send_chest_info(peer: int, id: int) -> void:
	if not send_chest_info.is_valid():
		return

	var it: Dictionary = _items.get(id, {})
	var storage: bool = not it.is_empty() and _is_storage(it)
	var mine: bool = storage and CraftStock.owner_ok(str(it["struct"].get("owner", "")), str(_peer_key.get(peer, "")))
	send_chest_info.call(peer, id, storage and bool(it["struct"].get("keep_out", false)), mine)


# ACT_CHEST_KEEP_OUT: the owner ticks (b = 1) or clears (b = 0) "keep out" on one of their containers within reach; crafting and blueprint
# sites then leave it alone. Saved with the container (world_items.json row index 16).
func _set_keep_out(peer: int, id: int, on: bool) -> void:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not _is_storage(it) or not _peer_pos.has(peer) or _peer_pos[peer].distance_to(it["pos"]) > CHEST_REACH_M:
		return

	if not CraftStock.owner_ok(str(it["struct"].get("owner", "")), str(_peer_key.get(peer, ""))):
		_say(peer, "Only the owner can change that.")
		return

	if on:
		it["struct"]["keep_out"] = true
	else:
		it["struct"].erase("keep_out")

	_dirty = true
	_send_chest_info(peer, id)
	_send_stock(peer)


# --- Pointer hotbar (docs/design/INVENTORY_CRAFTING_REPORT.md step 4; decisions in docs/design/OVERNIGHT_DECISIONS_8NOV.md row 24) ---
# Keys 1 to 9 and 0 hold item numbers (Inventory.hotbar), saved as the character's "hotbar"; sorting and moving never change them. A tool or weapon
# that newly enters the pack goes on the first empty key unless a key already holds that item. ACT_HOTBAR_SET puts any item on a key by hand.

# Whether an item goes on a free key by itself when it comes into the pack: tools and weapons (torch included), not food, clothing or materials.
func _autofills(number: int) -> bool:
	return number > 0 and str(table.entry(table.id_of(number)).get("kind", "")) in ["tool", "weapon"]


# The keys at the join. A character saved before the pointer hotbar has no "hotbar": its keys are the items in its old slots 1 to 10, once.
func _join_hotbar(peer: int, key: String) -> void:
	var inv = _inventories[key]
	var saved: Variant = _characters[key].get("hotbar", null)
	inv.hotbar = PackedInt32Array()
	inv.hotbar.resize(inv.HOTBAR_KEYS)

	if saved is Array:
		for k in mini((saved as Array).size(), inv.HOTBAR_KEYS):
			var number: int = table.current_number(int(saved[k]))
			inv.hotbar[k] = number if number > 0 and table.id_of(number) != "" and not inv.hotbar.has(number) else 0
	else:
		for k in inv.HOTBAR_KEYS:
			var number: int = inv.numbers[k]

			if number != 0 and not inv.hotbar.has(number):
				inv.hotbar[k] = number

	_store_hotbar(peer, inv)


# Saves the keys with the character and tells the player (hotbar, protocol 100).
func _store_hotbar(peer: int, inv) -> void:
	var key: String = str(_peer_key.get(peer, ""))

	if key != "" and _characters.has(key):
		_characters[key]["hotbar"] = Array(inv.hotbar)
		_dirty = true

	if send_hotbar.is_valid():
		send_hotbar.call(peer, inv.hotbar)


# ACT_HOTBAR_SET: key a (0 to 9) holds item number b, 0 clears it. One key per item: putting it on a key takes it off any other.
func _set_hotkey(peer: int, inv, key: int, number: int) -> void:
	if key < 0 or key >= inv.HOTBAR_KEYS or number < 0 or (number > 0 and table.id_of(number) == ""):
		return

	if number > 0:
		var was: int = inv.hotbar.find(number)

		if was >= 0:
			inv.hotbar[was] = 0

	inv.hotbar[key] = number
	_store_hotbar(peer, inv)


# A tool or weapon newly in the pack (picked up, crafted, taken from a chest) goes on the first empty key, unless a key already holds that item
# (its dimmed key lights again). `before` is the pack's item numbers before the change.
func _hotbar_autofill(peer: int, inv, before: PackedInt32Array) -> void:
	if inv.hotbar.size() != inv.HOTBAR_KEYS:
		return

	var changed: bool = false

	for slot in inv.SLOTS:
		var number: int = inv.numbers[slot]

		if number == 0 or before.has(number) or inv.hotbar.has(number) or not _autofills(number):
			continue

		var empty_key: int = inv.hotbar.find(0)

		if empty_key < 0:
			break

		inv.hotbar[empty_key] = number
		changed = true

	if changed:
		_store_hotbar(peer, inv)


# --- Bulk buttons (docs/design/INVENTORY_CRAFTING_REPORT.md step 3; decisions in docs/design/OVERNIGHT_DECISIONS_8NOV.md row 23) ---
# ACT_BULK a = kind: Take all and Store all work on the open container; Stack to nearby needs none (the player's own storage chests within
# CraftStock.CRAFT_REACH_M that already hold the item; keep out does not block stacking in); Sort reorders the pack (and an open storage chest)
# by the client's sort key b. Favourites are never moved (pack slots 1 to 10 were fixed too until the pointer hotbar, step 4). The player is told what happened (bulk_done).
const BULK_TAKE_ALL := 0
const BULK_STORE_ALL := 1
const BULK_STACK_NEARBY := 2
const BULK_SORT := 3
const BULK_FIXED_SLOTS := 0    # since the pointer hotbar (step 4, row 24) every pack slot is ordinary: only favourites stay where they are


func _bulk(peer: int, inv, kind: int, sort_key: int) -> void:
	var stacks: int = 0
	var touched: Array = []
	var open_id: int = int(_chest_viewer.get(peer, 0))
	var open_box = _chest_of(peer, open_id) if open_id != 0 else null

	if kind == BULK_TAKE_ALL or kind == BULK_STORE_ALL:
		if open_box == null:
			return

		stacks = _bulk_take_all(peer, inv, open_id, open_box) if kind == BULK_TAKE_ALL else _bulk_store_all(peer, inv, open_id, open_box)

		if stacks > 0:
			touched.append(open_id)
	elif kind == BULK_STACK_NEARBY:
		var result: Array = _bulk_stack_nearby(peer, inv)
		stacks = int(result[0])
		touched = result[1]
	elif kind == BULK_SORT:
		stacks = _sort_slots(inv, BULK_FIXED_SLOTS, inv.SLOTS, sort_key, true)

		if open_box != null and _is_storage(_items.get(open_id, {})):
			stacks += _sort_slots(open_box, 0, open_box.usable, sort_key, false)   # favourites are the pack's only
			_push_box(open_id, open_box)
			touched.append(open_id)
	else:
		return

	_dirty = true

	if send_bulk_done.is_valid():
		send_bulk_done.call(peer, kind, stacks, touched.size(), PackedInt32Array(touched))


# Take all: every stack of the open container that fits in the pack and under the carry limit (the rules of one take). A large log goes on the
# shoulder, not in the pack, so Take all leaves logs where they are. Returns the stacks moved.
func _bulk_take_all(peer: int, inv, id: int, box) -> int:
	var moved: int = 0

	for slot in box.usable:
		if box.numbers[slot] == 0 or is_shoulder_item(box.numbers[slot]):
			continue

		var had: int = box.counts[slot]
		_chest_action(peer, inv, Net.ACT_CHEST_TAKE, slot, id, had)

		if box.numbers[slot] == 0 or box.counts[slot] < had:
			moved += 1

	return moved


# Store all: every pack stack that is not a favourite and not the log on the shoulder, into the open container (the rules of one put:
# a fire takes only wood and food, a take-only container nothing, a heavy one up to its max_kg). Returns the stacks moved.
func _bulk_store_all(peer: int, inv, id: int, _box) -> int:
	var it: Dictionary = _items.get(id, {})
	var def: Dictionary = _structures.get(str(it.get("struct", {}).get("kind", "")), {})

	if bool(def.get("take_only", false)):
		return 0

	var moved: int = 0

	for slot in range(BULK_FIXED_SLOTS, inv.SLOTS):
		var number: int = inv.numbers[slot]

		if number == 0 or inv.is_fav(slot) or is_shoulder_item(number) or (it.has("fire") and not _fire_takes(table.id_of(number))):
			continue

		if _box_room(id, number, inv.counts[slot]) == 0:
			continue   # full by weight for this item: a lighter one may still go in, and the refusal is not said once per stack

		var had: int = inv.counts[slot]
		_chest_action(peer, inv, Net.ACT_CHEST_PUT, slot, id, had)

		if inv.numbers[slot] != number or inv.counts[slot] < had:
			moved += 1

	return moved


# How many of `amount` a storage container still takes by weight (structures.json max_kg); all of it when it has no weight limit.
func _box_room(sid: int, number: int, amount: int) -> int:
	var box = _chests.get(int(_items.get(sid, {}).get("struct", {}).get("uid", -1)))
	var max_kg: float = float(_structures.get(str(_items.get(sid, {}).get("struct", {}).get("kind", "")), {}).get("max_kg", 0.0))

	if max_kg <= 0.0 or _carry_cfg.is_empty() or box == null:
		return amount

	var each: float = maxf(CarryRules.weight_of(table.id_of(number), _carry_cfg), 0.001)
	return clampi(int(floor((max_kg - CarryRules.carried_kg(box, table, _carry_cfg)) / each + 0.0001)), 0, amount)


# Stack to nearby: each pack stack (not a favourite, not the shoulder log) goes into the player's own storage chests within
# CraftStock.CRAFT_REACH_M that already hold that item, nearest first; keep out does not block stacking in. Returns [stacks moved, chest ids].
func _bulk_stack_nearby(peer: int, inv) -> Array:
	var boxes: Array = []
	var touched: Dictionary = {}
	var key: String = str(_peer_key.get(peer, ""))

	if not _peer_pos.has(peer):
		return [0, []]

	for sid in _items:
		var s: Dictionary = _items[sid]

		if not _is_storage(s) or not CraftStock.owner_ok(str(s["struct"].get("owner", "")), key):
			continue

		var d: float = (s["pos"] as Vector3).distance_to(_peer_pos[peer])

		var chest = _chests.get(int(s["struct"]["uid"]))

		if chest != null and d <= CraftStock.CRAFT_REACH_M:
			chest.usable = clampi(int(_structures.get(str(s["struct"]["kind"]), {}).get("slots", chest.SLOTS)), 1, chest.SLOTS)
			boxes.append([sid, chest, d])

	boxes.sort_custom(func(a, b): return float(a[2]) < float(b[2]))
	var moved: int = 0

	for slot in range(BULK_FIXED_SLOTS, inv.SLOTS):
		var number: int = inv.numbers[slot]

		if number == 0 or inv.is_fav(slot) or is_shoulder_item(number):
			continue

		var moved_here: bool = false

		for box in boxes:
			if inv.numbers[slot] != number:
				break   # the whole stack has gone

			if box[1].count_of(number) <= 0:
				continue

			var amount: int = _box_room(int(box[0]), number, inv.counts[slot])
			var put: int = amount - (box[1].add(number, amount, inv.wear[slot]) if amount > 0 else 0)

			if put > 0:
				inv.take_from_slot(slot, put)
				moved_here = true
				touched[int(box[0])] = box[1]

		if moved_here:
			moved += 1

	for sid in touched:
		_push_box(int(sid), touched[sid])   # whoever has that chest open sees it fill

	return [moved, touched.keys()]


# Sort: the stacks in slots [from, to) of an inventory are put in order by the client's sort key (1 name, 2 and 3 weight up and down, 4 and 5 value
# up and down; 0, the picked-up order the server does not know, sorts by name), empty slots last. In the pack (keep_favs) favourites keep their slots
# and the rest flow round them. Stacks are only reordered, never joined. Returns how many stacks changed slot.
func _sort_slots(inv, from: int, to: int, sort_key: int, keep_favs: bool) -> int:
	var open_slots: Array = []
	var stacks: Array = []

	for i in range(from, mini(to, inv.SLOTS)):
		if keep_favs and inv.is_fav(i):
			continue

		open_slots.append(i)

		if inv.numbers[i] != 0:
			stacks.append([inv.numbers[i], inv.counts[i], inv.wear[i], i])

	var cfg: Dictionary = _carry_cfg
	var order_key: Callable = func(row: Array) -> Variant:
		var number: int = int(row[0])

		match sort_key:
			2:
				return CarryRules.weight_of(table.id_of(number), cfg) * float(row[1])
			3:
				return -CarryRules.weight_of(table.id_of(number), cfg) * float(row[1])
			4:
				return table.value_of(number) * int(row[1])
			5:
				return -table.value_of(number) * int(row[1])

		return table.name_of(number).to_lower()

	stacks.sort_custom(func(a, b):
		var ka: Variant = order_key.call(a)
		var kb: Variant = order_key.call(b)

		if ka != kb:
			return ka < kb

		return int(a[3]) < int(b[3]))
	var moved: int = 0

	for k in open_slots.size():
		var slot: int = int(open_slots[k])

		if k < stacks.size():
			var row: Array = stacks[k]
			inv.numbers[slot] = int(row[0])
			inv.counts[slot] = int(row[1])
			inv.wear[slot] = int(row[2])

			if int(row[3]) != slot:
				moved += 1
		else:
			inv.numbers[slot] = 0
			inv.counts[slot] = 0
			inv.wear[slot] = 0

		inv.fav[slot] = 0

	return moved


func _queue_craft(peer: int, inv, recipe_number: int, count: int) -> void:
	var queue: Dictionary = _queue_of(peer)
	var recipe: Dictionary = recipes.recipe(recipe_number)
	var free: bool = free_craft_for(peer)

	if queue.is_empty() or recipe.is_empty() or (not recipe_known_for(peer, recipe) and not free and not _try_learn(peer, inv, recipe)):
		return

	# The station within the crafting reach but not beside you: go to it and craft there (Dave 10 Nov 2026), when the stock here covers one.
	var station_name: String = str(recipe.get("station", ""))
	var station_level: int = int(recipe.get("station_level", 1))

	if station_name != "" and not station_near(peer, station_name, station_level):
		var far_id: int = serving_station(peer, station_name, station_level, CraftStock.CRAFT_REACH_M)

		if far_id >= 0 and (free or _stock_covers(inv, recipe, 1, _stock_of(peer))):
			_step_to_station(peer, far_id)

	if free:
		var line: Array = queue["entries"]

		if line.size() >= CRAFT_QUEUE_ENTRIES:
			_say(peer, "The crafting queue is full")
			return

		line.append([recipe_number, clampi(count, 1, CRAFT_QUEUE_MAX_COUNT), []])
		_dirty = true
		_sync_craft_queue(peer)
		return

	if str(recipe.get("station", "")) != "" and not station_near(peer, str(recipe["station"]), int(recipe.get("station_level", 1))):
		_say(peer, "That needs a %s nearby" % _station_name(str(recipe["station"])))
		return

	_pull_nearby_logs(peer, inv, _log_need(recipe["needs"], clampi(count, 1, CRAFT_QUEUE_MAX_COUNT)))   # shoulder and ground logs count (F-16)
	var stock: Dictionary = _stock_of(peer)   # the ground near the player and their own containers in reach count too (step 2): pack first, then the ground, then the nearest

	# Short of a part the stock could make (no twine, but the fibre for it): queue the missing parts first, then this (Dave 25 Oct).
	if not _stock_covers(inv, recipe, count, stock):
		var outcome: int = _queue_with_parts(peer, inv, queue, recipe_number, count, stock)

		if outcome == 1:
			_send_stock(peer)
			return

	var entries: Array = queue["entries"]
	var merge: bool = not entries.is_empty() and int(entries[entries.size() - 1][0]) == recipe_number and not (entries[entries.size() - 1][2] as Array).is_empty() and (entries[entries.size() - 1].size() < 5 or int(entries[entries.size() - 1][4]) == 0)

	if entries.size() >= CRAFT_QUEUE_ENTRIES and not merge:
		_say(peer, "The crafting queue is full")
		return

	var taken: int = 0

	for n in range(clampi(count, 1, CRAFT_QUEUE_MAX_COUNT)):
		if not _stock_covers(inv, recipe, 1, stock):
			break

		for need in recipe["needs"]:
			_stock_take(inv, int(need[0]), int(need[1]), stock)

		taken += 1

	if taken == 0:
		_say(peer, "You do not have what that needs")
		return

	if taken < clampi(count, 1, CRAFT_QUEUE_MAX_COUNT):
		_say(peer, "You only have enough for %d" % taken)

	if merge:
		entries[entries.size() - 1][1] = mini(int(entries[entries.size() - 1][1]) + taken, CRAFT_QUEUE_MAX_COUNT)
	else:
		entries.append([recipe_number, taken, recipe["needs"].duplicate(true)])

	_dirty = true
	_sync_craft_queue(peer)
	_send_stock(peer)


# Does the pack hold everything `times` crafts of a recipe need (kept tools once)?
func _pack_covers(inv, recipe: Dictionary, times: int) -> bool:
	for need in recipe["needs"]:
		if not inv.has_fill(need[0], int(need[1]) * clampi(times, 1, CRAFT_QUEUE_MAX_COUNT)):
			return false

	for keep in recipe["keeps"]:
		if not inv.has_fill(keep[0], keep[1]):
			return false

	return true


# Plans the missing parts of a craft and queues them, all or nothing, in one step. Returns 1 when queued, 0 when it could not be and the player
# was told why, -1 when there is nothing to add (the plain craft goes on, or fails the old way).
func _queue_with_parts(peer: int, inv, queue: Dictionary, recipe_number: int, count: int, stock: Dictionary = {}) -> int:
	if stock.is_empty():
		stock = _stock_of(peer)

	var ctx: Dictionary = {
		"have": func(item: int) -> int: return _stock_have(inv, item, stock),
		"station_ok": func(r: Dictionary) -> bool: return str(r.get("station", "")) == "" or station_near(peer, str(r["station"]), int(r.get("station_level", 1))),
		"known": func(r: Dictionary) -> bool: return recipe_known_for(peer, r),
		"free": false,
	}
	var plan: Dictionary = CraftPlanner.plan(recipes, table, recipe_number, clampi(count, 1, CRAFT_QUEUE_MAX_COUNT), ctx)

	if not bool(plan["ok"]):
		if str(plan["msg"]) != "" and str(plan["msg"]) != "You do not have what that needs":
			_say(peer, str(plan["msg"]))
			return 0

		return -1

	var steps: Array = plan["steps"]

	if steps.size() == 1:
		return -1   # nothing to make first: the plain path

	var entries: Array = queue["entries"]

	if entries.size() + steps.size() > CRAFT_QUEUE_ENTRIES:
		_say(peer, "The crafting queue is full")
		return 0

	for made in plan["made"]:   # the made parts must fit in the pack and under the carry limit
		if _fit(peer, inv, int(made[0]), int(made[1])) < int(made[1]):
			_say(peer, "You cannot carry that many %s" % table.sentence_name(int(made[0])))
			return 0

	var chain: int = 1

	for entry in entries:
		if entry.size() > 4:
			chain = maxi(chain, int(entry[4]) + 1)

	for step in steps:
		for need in step["take"]:
			_stock_take(inv, int(need[0]), int(need[1]) * int(step["count"]), stock)

		entries.append([int(step["recipe"]), int(step["count"]), (step["take"] as Array).duplicate(true), (step["deferred"] as Array).duplicate(true), chain])

	_dirty = true
	_sync_craft_queue(peer)
	return 1


# The head entry starts: the parts an earlier step made leave the pack now. False (the entry and what depends on it are cancelled and refunded)
# when they are not there any more.
func _start_deferred(peer: int, head: Array) -> bool:
	var inv = inventory_of(peer)
	var times: int = int(head[1])

	for need in head[3]:
		if inv == null or not inv.has_fill(need[0], int(need[1]) * times):
			_cancel_craft(peer, 0)
			_say(peer, "%s was cancelled: the parts it needed are gone" % str(recipes.recipe(int(head[0])).get("name", "That")))
			return false

	for need in head[3]:
		inv.remove_fill(need[0], int(need[1]) * times)
		var merged: bool = false

		for have in head[2]:
			if int(have[0]) == int(need[0]):
				have[1] = int(have[1]) + int(need[1])
				merged = true

		if not merged:
			head[2].append([int(need[0]), int(need[1])])

	head[3] = []
	_dirty = true
	return true


func _refund_entry(peer: int, entry: Array) -> void:
	# The entry keeps its own ingredient list, so a refund works even if the recipe is later removed or renumbered.
	for need in entry[2]:
		give(peer, _refund_number(int(need[0])), int(need[1]) * int(entry[1]))   # a group ingredient gives back its lowest member, as a taken-down piece does


func _cancel_craft(peer: int, index: int) -> void:
	var queue: Dictionary = _queue_of(peer)

	if queue.is_empty() or index < 0 or index >= queue["entries"].size():
		return

	var entry: Array = queue["entries"][index]
	queue["entries"].remove_at(index)

	if index == 0:
		queue["elapsed"] = 0.0

	_refund_entry(peer, entry)

	# Cancelling a part cancels what was waiting for it (the same chain, queued after it); each is refunded what it took.
	if entry.size() > 4 and int(entry[4]) > 0:
		var at: int = index

		while at < queue["entries"].size():
			var later: Array = queue["entries"][at]

			if later.size() > 4 and int(later[4]) == int(entry[4]):
				queue["entries"].remove_at(at)
				_refund_entry(peer, later)
			else:
				at += 1

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

		# A station recipe only runs while you are near its station; step away and it waits (nothing is lost, cancel refunds).
		var free_entry: bool = (head[2] as Array).is_empty() and (head.size() < 4 or (head[3] as Array).is_empty())   # an admin-mode craft: no station, no kept tool

		if not free_entry and str(recipe.get("station", "")) != "" and not station_near(peer, str(recipe["station"]), int(recipe.get("station_level", 1))):
			if Time.get_ticks_msec() - int(_station_said.get(peer, -100000)) > 8000:
				_station_said[peer] = Time.get_ticks_msec()
				_say(peer, "Your craft waits: go back to the %s" % _station_name(str(recipe["station"])))

			continue

		if head.size() > 3 and not (head[3] as Array).is_empty() and not _start_deferred(peer, head):
			continue

		queue["elapsed"] = float(queue["elapsed"]) + spent

		if float(queue["elapsed"]) < float(recipe.get("craft_s", 3.0)) * _wheel_slow(peer, recipe) / _pace_factor(peer, "craft"):
			continue

		queue["elapsed"] = 0.0
		var inv = inventory_of(peer)

		# A kept tool that is no longer there stops the craft: the entry is refunded.
		var tools_ok: bool = inv != null

		for keep in recipe.get("keeps", []):
			tools_ok = tools_ok and (free_entry or inv.has_fill(keep[0], keep[1]))

		# A recipe that wears its tool (the hand saw) needs an unbroken one of that class on the hotbar.
		var wears_tool: String = str(recipe.get("wears_tool", ""))

		if wears_tool != "" and not free_entry:
			tools_ok = tools_ok and inv != null and _tool_slot(inv, wears_tool) >= 0

		if not tools_ok:
			queue["entries"].remove_at(0)
			_refund_entry(peer, head)
			_say(peer, "%s was cancelled: a tool is missing" % str(recipe.get("name", "That")))
		else:
			_gain_source = SRC_CRAFT
			give(peer, int(recipe["gives"][0]), int(recipe["gives"][1]))
			_gain_source = SRC_PICKUP
			_goal_made(peer, int(recipe["gives"][0]))

			if wears_tool != "" and not free_entry:
				_wear_tool(peer, inv, wears_tool, "craft")

			practice(peer, "craft", clampf(float(recipe.get("craft_s", 3.0)) / 3.0, 0.3, 2.0))   # a long craft teaches more than a quick one
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
		var head_recipe: Dictionary = recipes.recipe(int(entries[0][0]))
		var craft_s: float = float(head_recipe.get("craft_s", 3.0)) * _wheel_slow(peer, head_recipe)
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

			var parts: Array = []

			for need in entry[3] if entry.size() > 3 else []:
				parts.append([int(need[0]), int(need[1])])

			entries.append([int(entry[0]), clampi(int(entry[1]), 1, CRAFT_QUEUE_MAX_COUNT), needs, parts, int(entry[4]) if entry.size() > 4 else 0])

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
		_asleep[peer]["t"] = float(_asleep[peer].get("t", 0.0)) + spent

		if _forced_sleep(peer):
			sleep_quality = clampf(sleep_quality, 0.0, 1.0)
		elif state >= 2 or int(_stance.get(peer, 0)) != 3:
			_end_sleep(peer)
			_strain_sent.erase(peer)
		elif sleep_quality < 0.0:
			_wake(peer, "Rain woke you")
		else:
			var rest: Dictionary = _asleep[peer]
			rest["rested"] = float(rest["rested"]) + spent if strain <= 0.0 else 0.0

			if bool(rest.get("nap", false)):
				if strain <= float(rest["nap_end"]) + 0.001:
					_wake(peer, "You wake refreshed")
			elif float(rest["rested"]) >= float(_sleep_cfg.get("rested_s", 1.5)) and energy_of(peer) >= 99.9 and not on_good_bed(peer):
				_wake(peer, "You wake rested")   # on a good bed the sleeper stays (bed.json): only moving, a stance key, a hit or the bed going wakes them

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

		# A nap drops exertion fast, on a straight line to its end value in nap.target_s seconds.
		if _asleep.has(peer) and bool(_asleep[peer].get("nap", false)):
			strain = maxf(before - float(_asleep[peer]["nap_rate"]) * spent, float(_asleep[peer]["nap_end"]))

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

		if _suffocate.has(peer):   # BUG-029: the vision closes in as the air stays out, and at 1 the character lies down unconscious
			black = maxf(black, clampf(float(_suffocate[peer]) / maxf(float(vitals_breath_faint_s()), 0.1), 0.0, 1.0))

		st["black"] = black

		if black >= 1.0 and state <= 1:
			state = 2
			st["t"] = 0.0
			_stance[peer] = 3

	st["s"] = strain
	st["state"] = state
	_train_fitness(peer, effort_of(peer) if state < 2 else 0.0, spent)
	var fade: float = 0.0

	if state <= 1:
		fade = float(st.get("black", 0.0))                      # the blackout coming on, 0 to 1
	elif state == 2:
		var vision: float = float(cfg.get("vision_frac", 0.625))
		fade = vision + (1.0 - vision) * clampf(float(st["t"]) / float(cfg.get("faint_s", 8.0)), 0.0, 1.0)
	elif state == 3:
		fade = 1.0 - clampf(float(st["t"]) / float(cfg.get("wake_s", 12.0)), 0.0, 1.0)

	# Sleep: the blackout comes on smoothly (fade_in_s) and goes off smoothly (fade_out_s) after waking.
	if _asleep.has(peer):
		fade = maxf(fade, clampf(float(_asleep[peer].get("t", 0.0)) / maxf(float(_sleep_cfg.get("fade_in_s", 4.0)), 0.1), 0.0, 1.0))
	elif _waking.has(peer):
		_waking[peer]["t"] = float(_waking[peer]["t"]) + spent
		fade = maxf(fade, 1.0 - clampf(float(_waking[peer]["t"]) / maxf(float(_sleep_cfg.get("fade_out_s", 4.0)), 0.1), 0.0, 1.0))

		if float(_waking[peer]["t"]) >= float(_sleep_cfg.get("fade_out_s", 4.0)):
			_waking.erase(peer)

	_sync_body(peer, state, st)
	var points: Array = [int(strain * 50.0) * 20, state, int(fade * 200.0) * 5, int(_stance.get(peer, 0)) | (4 if _asleep.has(peer) else 0) | (8 if _forced_sleep(peer) else 0)]

	if send_strain.is_valid() and _strain_sent.get(peer, []) != points:
		_strain_sent[peer] = points
		send_strain.call(peer, points[0], points[1], points[2], points[3])


# The heart in the ears, the expected wake time and the phase (protocol 59): 0 awake, 1 falling asleep, 2 out (asleep or fainted),
# 3 waking. Fainted: a fast, high heart (exertion.json faint_bpm.out), dropping to a brisk 140 for the waking stage. Asleep: slows
# from bpm.start to bpm.end over bpm.slow_s. Sent on change, whole bpm, ETA in steps of 5 s.
func _sync_body(peer: int, state: int, st: Dictionary) -> void:
	if not send_body.is_valid():
		return

	var fb: Dictionary = _exertion_cfg.get("faint_bpm", {"out": 172, "wake": 140})
	var bpm: float = 0.0
	var eta: float = 0.0
	var phase: int = 0

	if _suffocate.has(peer) and state <= 1:
		# BUG-029: suffocating, the heart climbs fast from bpm.start to bpm.peak over the seconds to the faint.
		var hb: Dictionary = _vitals_cfg.get("breath", {}).get("bpm", {})
		phase = 1
		bpm = lerpf(float(hb.get("start", 110.0)), float(hb.get("peak", 190.0)), clampf(float(_suffocate[peer]) / maxf(vitals_breath_faint_s(), 0.1), 0.0, 1.0))
	elif state == 2:
		phase = 2
		bpm = float(fb.get("out", 172))
		eta = maxf(float(_exertion_cfg.get("faint_s", 8.0)) - float(st["t"]), 0.0) + float(_exertion_cfg.get("wake_s", 12.0))
	elif state == 3:
		phase = 3
		bpm = float(fb.get("wake", 140))
		eta = maxf(float(_exertion_cfg.get("wake_s", 12.0)) - float(st["t"]), 0.0)
	elif _asleep.has(peer):
		var cfg: Dictionary = _sleep_cfg.get("bpm", {})
		var t: float = float(_asleep[peer].get("t", 0.0))
		phase = 1 if t < float(_sleep_cfg.get("fade_in_s", 4.0)) else 2
		bpm = lerpf(float(cfg.get("start", 66.0)), float(cfg.get("end", 44.0)), clampf(t / maxf(float(cfg.get("slow_s", 45.0)), 1.0), 0.0, 1.0))
		eta = sleep_eta(peer)
	elif _waking.has(peer):
		phase = 3
		bpm = float(_sleep_cfg.get("bpm", {}).get("wake", 72.0))
		eta = maxf(float(_sleep_cfg.get("fade_out_s", 4.0)) - float(_waking[peer]["t"]), 0.0)

	var row: Array = [int(round(bpm)), int(ceil(eta / 5.0)) * 5, phase]

	if _body_sent.get(peer, [0, 0, 0]) != row:
		_body_sent[peer] = row
		send_body.call(peer, row[0], row[1], row[2])


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

	_sync_training(peer, force)


# Today's training (the XP bucket that turns into fitness at game midnight) in whole percent of a fitness point, for the Tab screen.
func training_pm_of(peer: int) -> int:
	var row: Dictionary = _characters.get(_peer_key.get(peer, ""), {})
	var per_point: float = maxf(float(_fitness_cfg.get("train", {}).get("xp_per_point", 1000.0)), 1.0)
	return int(floor(float(row.get("xp_today", 0.0)) / per_point * 100.0))


func _sync_training(peer: int, force: bool) -> void:
	if not send_training.is_valid():
		return

	var pm: int = training_pm_of(peer)

	if force or int(_training_sent.get(peer, -1)) != pm:
		_training_sent[peer] = pm
		send_training.call(peer, pm)


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

	if _eat_stopped(peer, item_id, now):
		_last_eat[peer] = now
		return

	if not spoil.is_empty() and item_id == str(spoil.get("rotten_item", "")):
		_last_eat[peer] = now
		inv.take_from_slot(slot, 1)

		if not tried_of(peer).has(item_id) and grace_of(peer) > 0.0:
			_harm_bite(peer, item_id, -1.0, "")
			return

		var sick: Dictionary = spoil.get("sick", {})
		v["health"] = maxf(float(v["health"]) - float(sick.get("health", 0)), 1.0)
		v["wet"] = maxf(float(v["wet"]) - float(sick.get("wet_ml", 0)), 0.0)
		_learn_food(peer, item_id, "harm")
		make_sick(peer)
		_sync_vitals(peer, true)
		return

	if _unfit.has(item_id):
		_last_eat[peer] = now
		_say(peer, "It tastes bitter and wrong. You spit it out.")
		return

	var cure: Dictionary = VitalsRules.medicine(item_id, _vitals_cfg)

	if not cure.is_empty():
		if float(v.get("sick", 0.0)) <= 0.0:
			_say(peer, "Your health is fine")
			return

		_last_eat[peer] = now
		# Fresh herbs are stronger (spoilage), and a second dose soon after the first works only redose_share as well:
		# re-dosing shortens the effect instead of stacking it.
		var strength: float = 0.5 + 0.5 * table.freshness(inv.numbers[slot], inv.wear[slot])
		var recent: bool = float(now - int(_last_dose.get(peer, -10000000))) < float(_sick_cfg.get("dose_cooldown_s", 180.0)) * 1000.0

		if recent:
			strength *= float(_sick_cfg.get("redose_share", 0.25))
			_say(peer, str(_sick_cfg.get("say_too_soon", "")))

		_warm_bite(v, item_id)
		_last_dose[peer] = now
		inv.take_from_slot(slot, 1)
		v["sick"] = maxf(float(v["sick"]) - float(cure.get("cure_h", 12.0)) * 3600.0 * strength, 0.0)
		_say(peer, str(_sick_cfg.get("say_medicine", "")))
		_sync_sick(peer, true)
		_dirty = true
		return

	var aid: Dictionary = VitalsRules.energy_aid(item_id, _vitals_cfg)

	if not aid.is_empty():
		_use_energy_aid(peer, inv, slot, v, aid)
		return

	# A splint (vitals.json limp "cure_items") sets the leg and ends a limp at once.
	var limp_cfg: Dictionary = _vitals_cfg.get("limp", {})

	if (limp_cfg.get("cure_items", []) as Array).has(item_id):
		if float(v.get("limp", 0.0)) <= 0.0:
			_say(peer, "Your legs are fine.")
			return

		_last_eat[peer] = now
		inv.take_from_slot(slot, 1)
		v["limp"] = 0.0
		_say(peer, str(limp_cfg.get("say_cured", "Your leg is set.")))
		_sync_limp(peer, true)
		_dirty = true
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
	_warm_bite(v, item_id)
	kcal = int(round(float(kcal) * (0.5 + 0.5 * table.freshness(inv.numbers[slot], inv.wear[slot]))))   # stale food feeds less
	inv.take_from_slot(slot, 1)
	var total: float = float(v["fed"]) + float(kcal)

	if total > cap:
		# Beyond a full stomach the surplus goes to the body.
		v["weight"] = clampf(float(v["weight"]) + (total - cap) * float(_vitals_cfg.get("gain_efficiency", 0.8)) / float(_vitals_cfg.get("kcal_per_kg", 7700)), float(_vitals_cfg.get("min_weight_kg", 40)), float(_vitals_cfg.get("max_weight_kg", 150)))
		total = cap

	v["fed"] = total
	_raw_sickness(peer, item_id)
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


# Fitness trains slowly like a skill (Dave 2 Nov 2026, fitness.json "train"): any physical effort adds to the character's training,
# walking, running and tool work alike (effort_of: speed, tool work, load). Effort under min_effort (standing, strolling)
# earns nothing; from there the share rises in a straight line to 1 at full effort (running; hard tool work a little above), and one
# point takes seconds_per_point of full-effort time. Time under min_effort takes training back, a point per decay_s_per_point,
# never below the creation value. The whole-number change is sent to the client.
var _train_rest: Dictionary = {}     # peer -> seconds continuously at rest (below rest_effort)


# Fitness XP (Dave 4 Nov, BUG-023). Every 10-second tick above min_effort (0.1) gives xp_base + xp_per_effort x effort XP (1 at the line,
# 2 at a steady walk, 3 at a run), counted continuously here per second into the character's day bucket (xp_today); at game midnight the
# bucket is turned into points (xp_per_point = 1000 XP, the same at every level) and the player is told. A midnight that passes while
# the player is offline is paid at the next tick after login (one bucket only, saved with the character).
# Only effort below rest_effort held for rest_grace_s loses fitness, one point per decay_s_per_point. Effort between the two lines is neutral, and so is sleep.
func _train_fitness(peer: int, effort: float, spent: float) -> void:
	var cfg: Dictionary = _fitness_cfg.get("train", {})
	var row: Dictionary = _characters.get(_peer_key.get(peer, ""), {})

	if cfg.is_empty() or row.is_empty():
		return

	var before: int = fitness_of(peer)
	var train: float = float(row.get("train", 0.0))

	var today: int = _game_day()

	if int(row.get("xp_day", today)) != today:
		var banked: float = float(row.get("xp_today", 0.0)) / maxf(float(cfg.get("xp_per_point", 1000.0)), 1.0)
		row["xp_today"] = 0.0
		row["xp_day"] = today
		_dirty = true

		if banked > 0.0:
			train = minf(train + banked, float(cfg.get("max_gain", 10)))
			row["train"] = train
			_say(peer, "Your day's work has made you fitter." if int(floor(train)) > int(floor(train - banked)) else "You feel your day's work in your legs.")
	elif not row.has("xp_day"):
		row["xp_day"] = today

	if effort > float(cfg.get("min_effort", 0.1)):
		var xp_per_tick: float = float(cfg.get("xp_base", 1.0)) + float(cfg.get("xp_per_effort", 2.0)) * minf(effort, float(cfg.get("max_effort", 1.1)))
		var pending: float = float(row.get("xp_today", 0.0)) + xp_per_tick * spent / maxf(float(cfg.get("tick_s", 10.0)), 1.0)
		row["xp_today"] = minf(pending, float(cfg.get("max_gain", 10)) * float(cfg.get("xp_per_point", 1000.0)))
		_dirty = true
		_train_rest[peer] = 0.0
	elif _asleep.has(peer):
		_train_rest[peer] = 0.0   # sleep is recovery, not idleness: a night in bed (about 20 real minutes) neither earns nor costs, and the grace starts again on waking
	elif effort <= float(cfg.get("rest_effort", 0.02)):
		var rested: float = float(_train_rest.get(peer, 0.0)) + spent
		_train_rest[peer] = rested

		if rested > float(cfg.get("rest_grace_s", 600.0)):
			var step: float = spent / maxf(float(cfg.get("decay_s_per_point", 43200.0)), 1.0)
			train = maxf(train - step, 0.0) if train > 0.0 else minf(train + step, 0.0)   # back toward the creation value from either side
	else:
		_train_rest[peer] = 0.0   # a dawdle between the lines neither earns nor costs

	if train != float(row.get("train", 0.0)):   # an idle character at the base changes nothing: do not mark the save dirty every tick (it rewrote all files every 30 s for every online player)
		row["train"] = train
		_dirty = true

	if fitness_of(peer) != before:
		_vitals_sent.erase(peer)
		_sync_vitals(peer, true)
	else:
		_sync_training(peer, false)   # a new whole percent of today's training (at most every few ticks), or the midnight reset to 0


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


# Protocol 37 skill records become web records (data/items/skills.json "migration"): once, with a copy of the old file kept as
# characters.json.v1.bak the first time. `dry_run` only reports what would change.
func migrate_old_skills(key: String, row: Dictionary, dry_run: bool = false) -> Array:
	var report: Array = []
	var old_block: Dictionary = row.get("skills", {}) if typeof(row.get("skills", {})) == TYPE_DICTIONARY else {}

	if old_block.is_empty():
		return report

	if not dry_run and _dir != "" and not FileAccess.file_exists(_dir + "/characters.json.v1.bak") and FileAccess.file_exists(_dir + "/characters.json"):
		DirAccess.copy_absolute(_dir + "/characters.json", _dir + "/characters.json.v1.bak")

	var converted: Dictionary = SkillWeb.migrate_block(_skills_cfg, old_block, report)

	if not dry_run and _characters.has(key):
		_characters[key]["skills"] = converted

	return report


func _load_characters() -> void:
	var parsed: Variant = _read_json_version("characters.json", 1)

	if typeof(parsed) != TYPE_DICTIONARY or typeof((parsed as Dictionary).get("players", {})) != TYPE_DICTIONARY:
		return

	for key in parsed.get("players", {}):
		if typeof(parsed["players"][key]) != TYPE_DICTIONARY:
			push_warning("characters.json: the record of %s is not a record, skipped (the others are kept)" % str(key))
			continue

		_characters[str(key)] = {
			"luck": clampi(int(parsed["players"][key].get("luck", 0)), -LuckScript.MAX, LuckScript.MAX),
			"fitness": clampi(int(parsed["players"][key].get("fitness", _fitness_default())), _fitness_min(), _fitness_max()),
			"train": clampf(float(parsed["players"][key].get("train", 0.0)), -10.0, 10.0),
			"strength": clampi(int(parsed["players"][key].get("strength", 0)), -10, 10),
			"memory": clampi(int(parsed["players"][key].get("memory", 0)), -10, 10),
			"worn": _clean_worn(parsed["players"][key].get("worn", [])),
			"shelter": parsed["players"][key].get("shelter", []) if typeof(parsed["players"][key].get("shelter", [])) == TYPE_ARRAY else [],
			"skills": parsed["players"][key].get("skills", {}) if typeof(parsed["players"][key].get("skills", {})) == TYPE_DICTIONARY else {},
			"dexterity": clampi(int(parsed["players"][key].get("dexterity", 0)), -10, 10),
			"perception": clampi(int(parsed["players"][key].get("perception", 0)), -10, 10),
			"charisma": clampi(int(parsed["players"][key].get("charisma", 0)), -10, 10),
			"coins": maxi(int(parsed["players"][key].get("coins", 0)), 0),
			"rep": parsed["players"][key].get("rep", {}) if typeof(parsed["players"][key].get("rep", {})) == TYPE_DICTIONARY else {},
			"new_player": bool(parsed["players"][key].get("new_player", false)),
			"tried": parsed["players"][key].get("tried", {}) if typeof(parsed["players"][key].get("tried", {})) == TYPE_DICTIONARY else {},
			"learned": parsed["players"][key].get("learned", {}) if typeof(parsed["players"][key].get("learned", {})) == TYPE_DICTIONARY else {},   # recipe numbers learned (F-01)
			"rested": parsed["players"][key].get("rested", {}) if typeof(parsed["players"][key].get("rested", {})) == TYPE_DICTIONARY else {},
			"spawn_bed": parsed["players"][key].get("spawn_bed", []) if typeof(parsed["players"][key].get("spawn_bed", [])) == TYPE_ARRAY and (parsed["players"][key].get("spawn_bed", []) as Array).size() == 3 else [],
			"goals_done": parsed["players"][key].get("goals_done", {}) if typeof(parsed["players"][key].get("goals_done", {})) == TYPE_DICTIONARY else {},   # starter goals finished
			"goal_counts": parsed["players"][key].get("goal_counts", {}) if typeof(parsed["players"][key].get("goal_counts", {})) == TYPE_DICTIONARY else {},
			"hints_seen": parsed["players"][key].get("hints_seen", {}) if typeof(parsed["players"][key].get("hints_seen", {})) == TYPE_DICTIONARY else {},   # events and crafts counted for the goals
			"grace_s": maxf(float(parsed["players"][key].get("grace_s", 0.0)), 0.0),   # eat-once: an older save has none, so no first-hour protection
		}

		if typeof(parsed["players"][key].get("hotbar", null)) == TYPE_ARRAY:   # the pointer hotbar's keys (step 4); a record without them is migrated once at the join
			_characters[str(key)]["hotbar"] = parsed["players"][key]["hotbar"]

		if bool(parsed["players"][key].get("dead", false)):   # real death (death.json real_death): a dead character stays dead across a restart
			_characters[str(key)]["dead"] = true

		if int(parsed["players"][key].get("skills_v", 1)) < 2:
			migrate_old_skills(str(key), parsed["players"][key])
			_characters[str(key)]["skills_v"] = 2
			_dirty = true
		else:
			_characters[str(key)]["skills_v"] = 2


# Drink from the water at the player's feet (ACT_DRINK): one mouthful of thirst.drink_ml, paced like eating. The scene's water_near says whether water lies within reach.
func _drink_water(peer: int, slot: int = -1, inv = null) -> void:
	var v: Dictionary = vitals_of(peer)

	if v.is_empty() or not _peer_pos.has(peer):
		return

	var thirst: Dictionary = _vitals_cfg.get("thirst", {})
	var now: int = Time.get_ticks_msec()

	if now - int(_last_drink.get(peer, -100000)) < int(thirst.get("drink_pace_ms", 900)):
		return

	var tank: int = _tank_near(_peer_pos[peer], float(thirst.get("reach_m", 3.0)))

	if tank >= 0:   # a trough, barrel or cistern of the water network within reach (6b part 2)
		_drink_from_tank(peer, slot, inv, tank, v, thirst, now)
		return

	var shown: bool = water_near.is_valid() and bool(water_near.call(_peer_pos[peer], float(thirst.get("reach_m", 3.0))))

	# The record's water counts too where the settled water does not show it (docs/design/drink_prompt_design.md (a)): a ground spring head, a narrow
	# brook. The rule below then says whether it runs (_drink_source_ok: "The bed is dry", frozen, salt).
	if not shown and not _record_water_near(peer, thirst):
		if _salt_only(peer, thirst):
			_say(peer, str(thirst["sources"].get("say_salt", "Salt water. It would only make you thirstier.")))   # the sea (design section 2)
		else:
			_reject(peer, 0)

		return

	if not _drink_source_ok(peer, thirst):
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


# With thirst.sources on and the scene's water_source set (docs/design/drinking_water_design.md): salt water is refused, a dry bed is refused,
# and frozen water needs an ice hole within reach (the fishing hole). Off, or with no source rows, the drink goes on as before.
func _drink_source_ok(peer: int, thirst: Dictionary) -> bool:
	var cfg: Dictionary = thirst.get("sources", {})

	if not bool(cfg.get("enabled", false)) or not water_source.is_valid():
		return true

	var pos: Vector3 = _peer_pos[peer]
	var rows: Array = (water_source.call(pos, float(thirst.get("reach_m", 3.0))) as Array).duplicate()

	if rows.is_empty():
		return true   # the record knows nothing here (an older world): today's water test stands

	var icy: int = -1   # a row without its own ice field takes the server's ice rule at the player (_on_ice, the fishing ice), read once

	for i in range(rows.size()):
		if not (rows[i] as Dictionary).has("iced"):
			if icy < 0:
				icy = 1 if _on_ice(pos) else 0

			rows[i] = (rows[i] as Dictionary).merged({"iced": icy == 1})

	var weather: Dictionary = weather_now.call() if weather_now.is_valid() else {}
	var ctx: Dictionary = {"season": str(season_at.call(pos)) if season_at.is_valid() else _season(), "rain_h_ago": (_now_game_s() - _last_rain_s) / 3600.0, "raining": float(weather.get("rain", 0.0)) > 0.05,
		"air_c": float(weather.get("temp_c", 10.0)) - maxf(pos.y, 0.0) * float(_warmth_cfg.get("lapse_c_per_m", 0.0065)), "wind": float(weather.get("wind", 0.0))}
	var found: Dictionary = DrinkRules.pick(cfg, rows, ctx)

	if str(found.get("refused", "")) == "salt":
		_say(peer, str(cfg.get("say_salt", "Salt water. It would only make you thirstier.")))
		return false

	if str(found.get("refused", "")) == "dry":
		_say(peer, str(cfg.get("say_dry", "The bed is dry.")))
		return false

	if bool(found.get("frozen", false)) and not _hole_near(pos):
		_say(peer, str(cfg.get("say_frozen", "The water is frozen. Break a hole in the ice first.")))
		return false

	return true


# With thirst.sources on, a spring or brook row of the record's within reach (water_source): water to drink at, or to be told is dry, even where the
# settled water does not show it (a spring head under its bushes, a brook narrower than an 8 m cell).
func _record_water_near(peer: int, thirst: Dictionary) -> bool:
	var cfg: Dictionary = thirst.get("sources", {})

	if not bool(cfg.get("enabled", false)) or not water_source.is_valid():
		return false

	var rows: Array = water_source.call(_peer_pos[peer], float(thirst.get("reach_m", 3.0)))
	return rows.any(func(row): return str((row as Dictionary).get("kind", "")) in ["spring", "brook"])


# With thirst.sources on, no drinking water within reach (water_near) but salt water is: the sea, which the live sim does not hold.
func _salt_only(peer: int, thirst: Dictionary) -> bool:
	var cfg: Dictionary = thirst.get("sources", {})

	if not bool(cfg.get("enabled", false)) or not water_source.is_valid():
		return false

	var rows: Array = water_source.call(_peer_pos[peer], float(thirst.get("reach_m", 3.0)))
	return rows.any(func(row): return str((row as Dictionary).get("kind", "")) == "salt")


func _save_vitals() -> void:
	_write_atomic("vitals.json", {"version": 1, "players": _vitals})


func _load_vitals() -> void:
	var parsed: Variant = _read_json_version("vitals.json", 1)

	if parsed == null:
		return

	for key in parsed.get("players", {}):
		var row: Dictionary = parsed["players"][key]
		var fresh: Dictionary = _new_vitals()
		_vitals[str(key)] = {"fed": float(row.get("fed", fresh["fed"])), "weight": float(row.get("weight", fresh["weight"])), "health": float(row.get("health", fresh["health"])), "wet": float(row.get("wet", fresh["wet"])), "energy": clampf(float(row.get("energy", 100.0)), 0.0, 100.0), "warmth": clampf(float(row.get("warmth", 100.0)), 0.0, 100.0), "sick": maxf(float(row.get("sick", 0.0)), 0.0), "limp": maxf(float(row.get("limp", 0.0)), 0.0)}

		if typeof(row.get("sick_due", null)) == TYPE_ARRAY and not (row["sick_due"] as Array).is_empty():
			_vitals[str(key)]["sick_due"] = row["sick_due"]   # pending sickness from raw food (docs/design/body_in_weather_design.md 5)
