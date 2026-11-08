extends Node3D

const LifeUtil := preload("res://src/client/life_layer_util.gd")   # shared helpers of the life layer hooks (REVIEW_NOTES.md)
const FrameProbe := preload("res://src/debug/frame_probe.gd")

# Animals on the client (protocol 48): a simple rabbit until Art makes a real one (brown body, head, two ears, white
# tail). The server sends rows about four times a second; the view glides to each, faces the way it goes and hops while moving
# (higher and quicker when it bolts). At most MAX_DRAWN are drawn, the nearest ones (the server already sends only 30 within 120 m).

const MAX_DRAWN := 30
const MODELS_PATH := "res://data/animals/models.json"
const BoneOffsetsScript := preload("res://src/client/bone_offsets.gd")
const GRAZE := 0
const HOP := 1
const FLEE := 2

signal voiced(kind: String, voice: Dictionary, at: Vector3)    # voice_fx: a call by state from data/animals/voices.json (ANIMAL_VOICES.md); {mood} or {slot, db, unit, reach}
signal state_changed(kind: String, state: int, at: Vector3)     # an animal alerts, flees, warns or charges (sounds listen)
signal stepped(kind: String, at: Vector3)                       # a hoof or paw lands (each whole count of the gait; a rabbit hop lands): the step sounds listen
signal footfall(kind: String, at: Vector3, ground: String, speed: float)   # the same landing with the ground it lands on (dust, mud, snow, water) and the speed: puffs, tracks, ground-aware hoof sounds (docs/design/FOOTFALL.md)
signal fell(kind: String, at: Vector3, small: bool)            # an animal went down from a hit: it vanished right after a hit landed on it (sounds listen)

# Species numbers 8 to 13 were missing, so their voices and footsteps never fired (Kathreen, 2 Nov 2026). The sound side (creature_sounds.gd KINDS, the `<kind>_step` slots in
# data/sound/batch1_slots.json) skips a kind it has no clip for, so these stay silent until Jason adds the clips; the names here are the ones to use.
const KIND_OF_SPECIES := {1: "rabbit", 2: "deer", 3: "wolf", 4: "moose", 5: "fox", 6: "duck", 7: "horse", 8: "boar", 9: "songbird", 10: "frog", 11: "grouse", 12: "seal", 13: "seabird", 14: "bear", 15: "donkey", 16: "goblin", 17: "lynx", 18: "black_bear", 19: "elk", 20: "bighorn", 21: "mountain_goat", 22: "beaver", 23: "chamois", 24: "mink", 25: "raccoon", 26: "rat", 27: "crow", 28: "pheasant", 29: "goose", 30: "cow", 31: "goat", 32: "chicken", 33: "cat", 34: "dog", 35: "buffalo", 36: "puma", 37: "pronghorn", 38: "warthog", 39: "hyena", 40: "wildebeest", 41: "lion", 42: "leopard", 43: "rhino", 44: "elephant", 45: "camel", 46: "guineafowl", 47: "honey_badger", 48: "kangaroo", 49: "mammoth", 50: "tiger", 51: "alligator"}
const FELL_WINDOW_MS := 1500             # a body gone this soon after a hit near it fell from that hit
const FELL_M := 3.0                      # how near the hit (the hit is placed at the chest; rows move up to a few metres between updates)
const SMALL_FALL_KINDS := ["rabbit", "songbird", "frog", "grouse", "seabird", "duck", "fox"]   # fall softly
const BURROW_KINDS := ["rabbit"]          # a wounded rabbit can go to ground on its trail: it leaves the rows alive
const VOICED_STATES := [2, 3, 10, 11]         # flee, alert, warn, charge
const WARN_POP := 16                          # the threat ladder's jaw-pop rung (server_big_game.gd); drawn as the warning (10) unless the model maps a clip "16"
const AIR_STATES := [15, 17]                  # in the air (15 flapping, 17 gliding: Steve's #653): its own clip, never walk or run

var _bodies: Dictionary = {}     # id -> {node, target Vector3, heading, state, phase}
var _models: Variant = null      # data/animals/models.json "species" (loaded on first use)
var _model_notes: Dictionary = {}  # log lines already printed by _model_note
var _alpha_of: Dictionary = {}     # texture path -> has see-through pixels (_has_alpha)
var _mats: Dictionary = {}
var _t: float = 0.0
var conditions_now: Callable     # () -> {"hour": float, "season": String} from the client's ambient clock: the asleep test, tail swish
var _species_cfg: Variant = null  # data/animals/animals.json (the server's species file: active hours and the rest rule)
var footfall_fx: bool = false     # docs/design/FOOTFALL.md: dust, mud and snow puffs at running footfalls (off until the PC check)
var prints_fx: bool = false       # footprints in snow and mud that fade (FOOTFALL.md step 5; off until the PC check)
var _print_fade_t: float = 0.0
var _prints: Array = []           # [Decal, born msec, life s]
var _print_tex: Dictionary = {}   # sign group -> ImageTexture
var _sign_group: Variant = null   # kind -> hoofed / pawed / clawed / bird (data/animals/animal_sign.json)
var slope_tilt: bool = false
var look_at_foe: bool = false     # a warning animal looks at the foe the server names, not the camera (LIFE_LAYER_WIRING.md; off until the PC check)
var flight_bank: bool = false     # birds bank into turns and ravens roll on the server's roll event (BIRD_FLIGHT.md part 2; off until the PC check)
var idle_first_s: float = -1.0     # tools only: the first idle comes after this many seconds (-1: 8 to 25 s)
var idle_variety: bool = false    # grooming and idle variety from a weighted table per species (IDLE_VARIETY.md; off until the PC check)
var water_life: bool = false      # drinking at the bank, swimming low with paddling legs, shaking off (ANIMALS_AND_WATER.md; off until the PC check)
var young_age_days: float = -1.0  # tools only: every young one this many days old (-1: each its own age from its id)
var life_layer_all_off: bool = false   # kill switch for Dave's PC gate (--life-layer-off): every life-layer flag off and the always-on looks skipped, the model path as on main (PERF_BUDGET.md)
var _f_frame: int = -1            # the frame the caches below were read in
var _f_cond: Dictionary = {}
var _f_wx: Dictionary = {}
var _f_night: Dictionary = {}
var _f_torch: Array = []
var _f_wind: float = 0.0
var _f_herd_space: float = 2.0
var hunt_feedback: bool = false
var posed_flight_all: bool = false   # tools only: pose every bird's flight from its bones, clips or not (a stand-in until a Meshy bird arrives)
var fog_looks: bool = false       # animals in fog, mist and dusk: eye shine sooner, steam into the mist, herds closer in thick fog (ANIMAL_FOG.md; off until the PC check)
var fog_now: Callable             # () -> {visibility_m, mist 0..1, mist_top_m}: the client's fog, from Kathleen's weather look (ANIMAL_FOG.md names the fields)
var _f_fog: Dictionary = {}
var wind_looks: bool = false      # animals and the wind's direction: rumps to wind and rain, deer grazing into it, fur on the windward side, breath blown downwind, birds into wind (ANIMAL_WIND.md; off until the PC check)
var swim_rig: bool = false        # whales and dolphins posed from their spines: tail beat, flipper strokes, porpoise pitch (SWIM_RIG.md; off until a Meshy whale or dolphin arrives)
var bird_rig: bool = false        # birds and bats posed from their skeletons: wingbeat, glide hold, perch fold, landing flare (BIRD_FLIGHT.md part 3; off until a Meshy bird arrives)
var cover_still: bool = false     # state 20 in cover (Steve #701): hunched and still, the idle slowed, breathing slow, the wet look held (COVER_STILL in ANIMAL_WEATHER_LOOKS.md; off until the PC check)
var air_override: float = NAN     # --life-air=C (pictures and tools only): this air temperature everywhere, for the steam and cold looks
const HIT_EVENT_PROTOCOL := 96    # Steve's hit event (#705): zone and animal id to players within 60 m (HUNT_FEEDBACK.md)
const HIT_ZONES := ["body", "head", "chest", "hip", "leg"]   # the hit event's zone byte, in this order (agreed spec; change with Steve's PR if it differs)
var _hit_events_seen: bool = false   # once the server's hit events arrive, the hunter's own guess from the hit number is not used   # hit reactions by body zone, wounded gait, a death fall on the slope (HUNT_FEEDBACK.md; off until the PC check)
var _health: Variant = null       # species -> health from data/animals/animals.json (the client's own count of the damage it saw)
var weather_looks: bool = false   # shake-off after rain, tail to the wind, cold huddle, steam breath, snow on backs (ANIMAL_WEATHER_LOOKS.md; off until the PC check)
var air_at: Callable             # (position) -> air temperature C there: Weather.air_c by height and hour (#620, the one temperature); else weather temp_c
var weather_now: Callable         # () -> the client's weather state (temp_c, rain, snow, wind, wind_dir ...), the same on every client
var _wx_last_rain: float = 0.0
var _wx_shake_due: bool = false
var animal_sign: bool = false     # tracks on soft ground by stride, droppings, browse and beds that last by Jamie's soak numbers (ANIMAL_SIGN.md; off until the PC check)
var soil_at: Callable             # (position) -> footstep surface ("mud", "sand", "dirt", "grass", "stone" ...) from the sound stage's soil map
var _signs: Array = []            # [Decal, born msec, life s, ground] (animal_sign), oldest first
var _sign_check_t: float = 0.0
var _sign_rain_s: float = 0.0     # seconds of real rain (0.4 or more) in a row: a game hour washes mud prints
var _sign_drift_s: float = 0.0    # seconds of wind over 0.35 in a row: two game hours drift snow into snow prints
var eye_shine: bool = false       # night eye shine v2: torch or moon near the viewer's eye line, a dot per eye that reads far off (EYE_SHINE.md; off until the PC check)
var night_light: Callable         # () -> {night 0..1, moon 0..1, moon_to Vector3}: from the client's day cycle (eye_shine)
var voice_fx: bool = false        # animals call by state from data/animals/voices.json; terrain_client then skips the old state_changed calls (ANIMAL_VOICES.md; off until the PC check)
var _voices: Variant = null       # voices.json, loaded on first use
var _voice_times: Array = []      # msec of the calls this last second (voices.json per_second)
var swarm_fx: bool = false        # bat colonies boil in flight and hang head down at the roost (BAT_RIG.md, NEW_MODEL_IMPORT.md; off until the model and PC check)
var sea_life: bool = false        # whales and dolphins blow at the surface (SEA_MAMMALS.md; off until the models and PC check)
var young_follow: bool = false    # young look to their mother and nurse at her flank now and then (YOUNG_ANIMALS.md part 2; off until the PC check)
var young_gait: bool = false      # young drawn at their species' size, quick short steps, wobbly when newborn (YOUNG_ANIMALS.md; off until the PC check)
var coat_dust: bool = false       # coats dusty after a roll, washed by water and rain (COAT_SHADER.md section 4; off until the PC check)
var coat_ruffle: bool = false     # coats ruffle in the wind, a vertex shader on the coat (COAT_SHADER.md section 1; off until the PC check)
var season_coats: bool = false    # the coat's colour follows the season (COAT_SHADER.md; off until the PC check)
var stalk_fx: bool = false        # predators crouch and creep when stalking and pounce on the attack (STALK_POUNCE.md; off until the PC check)
var wind_now: Callable            # () -> wind 0..1 (Jamie's #637: 20 x wind^1.3 m/s); ears lie back and tails swing above about 0.5
var foot_ik: bool = false         # feet reach uneven ground (FOOTFALL.md step 4; off until the PC check)
var ground_height: Callable       # (x, z) -> terrain height or NAN, from the client (foot_ik probes)      # the body pitches with the slope it walks on (off until the PC check)
var season_now: String = ""      # "spring", "summer", "autumn", "winter" or "" when unknown; the client sets it (tail swish against flies)
var torch_light: Callable        # () -> [position, range] of the player's held light, or []: eyes facing it shine (_eye_shine)
var water_level: Callable        # (x, z) -> water surface height or NAN; set by the client: a swimmer below it plays its "swim" clip
var _blood_points: PackedVector3Array = PackedVector3Array()   # the trail last sent (on_blood), for near_blood
var _hits: Array = []            # [at Vector3, msec] of the hits reported in the last FELL_WINDOW_MS (note_hit)
var _blood: Array = []           # MeshInstance3D pool, one per drop shown
var _blood_mat: ShaderMaterial
const BLOOD_SHADER := """
shader_type spatial;
render_mode cull_disabled;

varying vec2 lp;

float h2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	lp = VERTEX.xz / 0.1;      // -1..1 across the 10 cm disc
}

void fragment() {
	float r = length(lp);
	float a = atan(lp.y, lp.x);
	float edge = 0.55 + 0.25 * vn(vec2(a * 2.2, 3.0)) + 0.18 * vn(vec2(a * 7.0, 9.0));      // a lobed rim with drips
	float drops = step(0.9, vn(lp * 6.0 + 11.0)) * step(r, 0.98);                          // a few flung drops beyond the rim
	if (r > edge && drops < 0.5) {
		discard;
	}
	float dry = smoothstep(edge - 0.25, edge, r);
	ALBEDO = mix(vec3(0.30, 0.02, 0.02), vec3(0.2, 0.06, 0.03), dry) * (0.85 + 0.2 * vn(lp * 9.0));
	ROUGHNESS = mix(0.15, 0.7, dry);      // wet and shiny in the middle
	SPECULAR = 0.6;
}
"""


# New species numbers (Sal's data/animals/spawn_plan.json proposal: boar 8, songbirds 9, frog 10, grouse 11, seal 12, seabird 13). The small ones hop
# on the generic Rig path like the rabbit; the boar is a four-legged body and animates like the deer. A species number with no model is not drawn.
const SMALL_SPECIES := [9, 10, 11, 13]
const HUNCH := 20           # server state 20 (Steve's #646): standing still against the weather, head low, ears back
const YOUNG_NUM := 100       # a young animal's species number + 100 (server_animals.gd)
const YOUNG_SCALE := 0.5     # how big the young are drawn


const FEATHERED := [6, 9, 11, 13]     # flock birds, songbirds, grouse, gulls: they take the feather coat while they build


# young: a young animal. When its species' model row has a young_model, that model is drawn at its own size (the calf beside
# the cow, Dave 7 Nov 2026); the node then carries the "young_model" meta and must not be shrunk. Otherwise the adult is drawn
# and the caller shrinks it to YOUNG_SCALE as before.
func _make_for_species(number: int, id: int, young: bool = false) -> Node3D:
	_coat = "feather" if FEATHERED.has(number) else "fur"
	var node: Node3D = _make_species_body(number, id, young)
	_coat = "fur"
	return node


func _make_species_body(number: int, id: int, young: bool = false) -> Node3D:
	var flock_row: Dictionary = _model_rows().get(str(KIND_OF_SPECIES.get(number, "")), {})

	if flock_row.has("flock_of"):
		var flock: Node3D = _make_model_flock(number, id, flock_row)

		if flock != null:
			return flock

	var model: Node3D = _make_model(number, id, young)

	if model != null:
		return model

	match number:
		2:
			return _make_deer(id)
		3:
			return _make_wolf()
		4:
			return _make_moose(id)
		5:
			return _make_fox()
		6:
			return _make_flock(id)
		7:
			return _make_horse(id)
		8:
			return _make_boar()
		9:
			return _make_songbird()
		10:
			return _make_frog()
		11:
			return _make_grouse()
		12:
			return _make_seal()
		13:
			return _make_gull_flock(id)      # one record per flock since MikeW's seabird flock block (PR 73): 5 to 12 gulls standing on the beach, all taking off in state 15
		14:
			return _make_bear()
		15:
			var donkey: Node3D = _make_horse(id)      # no code-built donkey: a smaller horse until its model files are there (Dave 7 Nov 2026)
			donkey.scale = Vector3.ONE * 0.8
			return donkey
		17:
			var lynx: Node3D = _make_fox()      # no code-built lynx: a bigger fox until its model files are there (Dave 7 Nov 2026)
			lynx.scale = Vector3.ONE * 1.4
			return lynx
		18:
			var black_bear: Node3D = _make_bear()      # a smaller brown bear
			black_bear.scale = Vector3.ONE * 0.8
			return black_bear
		19:
			var elk: Node3D = _make_moose(id)
			elk.scale = Vector3.ONE * 0.85
			return elk
		20:
			var bighorn: Node3D = _make_deer(id)
			bighorn.scale = Vector3.ONE * 0.75
			return bighorn
		21:
			var mountain_goat: Node3D = _make_deer(id)
			mountain_goat.scale = Vector3.ONE * 0.65
			return mountain_goat
		22:
			var beaver: Node3D = _make_fox()
			beaver.scale = Vector3.ONE * 0.6
			return beaver
		23:
			var chamois: Node3D = _make_deer(id)      # stand-in until the model files are there
			chamois.scale = Vector3.ONE * 0.6
			return chamois
		24:
			var mink: Node3D = _make_fox()      # stand-in until the model files are there
			mink.scale = Vector3.ONE * 0.45
			return mink
		25:
			var raccoon: Node3D = _make_fox()      # stand-in until the model files are there
			raccoon.scale = Vector3.ONE * 0.7
			return raccoon
		26:
			var rat: Node3D = _make_rabbit()      # stand-in until the model files are there
			rat.scale = Vector3.ONE * 0.5
			return rat
		27:
			var crow: Node3D = _make_grouse()      # stand-in until the model files are there
			crow.scale = Vector3.ONE * 1.0
			return crow
		28:
			var pheasant: Node3D = _make_grouse()      # stand-in until the model files are there
			pheasant.scale = Vector3.ONE * 1.3
			return pheasant
		29:
			var goose: Node3D = _make_grouse()      # stand-in until the model files are there
			goose.scale = Vector3.ONE * 1.8
			return goose
		30:
			var cow: Node3D = _make_horse(id)      # stand-in until the model files are there
			cow.scale = Vector3.ONE * 0.85
			return cow
		31:
			var goat: Node3D = _make_deer(id)      # stand-in until the model files are there
			goat.scale = Vector3.ONE * 0.6
			return goat
		32:
			var chicken: Node3D = _make_grouse()      # stand-in until the model files are there
			chicken.scale = Vector3.ONE * 1.0
			return chicken
		33:
			var cat: Node3D = _make_fox()      # stand-in until the model files are there
			cat.scale = Vector3.ONE * 0.55
			return cat
		34:
			var dog: Node3D = _make_wolf()      # stand-in until the model files are there
			dog.scale = Vector3.ONE * 0.7
			return dog
		35:
			var buffalo: Node3D = _make_moose(id)      # stand-in until the model files are there
			buffalo.scale = Vector3.ONE * 1.0
			return buffalo
		36:
			var puma: Node3D = _make_fox()      # stand-in until the model files are there
			puma.scale = Vector3.ONE * 1.8
			return puma
		37:
			var pronghorn: Node3D = _make_deer(id)      # stand-in until the model files are there
			pronghorn.scale = Vector3.ONE * 0.7
			return pronghorn
		38:
			var warthog: Node3D = _make_boar()      # stand-in until the model files are there
			warthog.scale = Vector3.ONE * 0.85
			return warthog
		39:
			var hyena: Node3D = _make_wolf()      # stand-in until the model files are there
			hyena.scale = Vector3.ONE * 0.85
			return hyena
		40:
			var wildebeest: Node3D = _make_moose(id)      # stand-in until the model files are there
			wildebeest.scale = Vector3.ONE * 0.7
			return wildebeest
		41:
			var lion: Node3D = _make_fox()      # stand-in until the model files are there
			lion.scale = Vector3.ONE * 2.4
			return lion
		42:
			var leopard: Node3D = _make_fox()      # stand-in until the model files are there
			leopard.scale = Vector3.ONE * 1.6
			return leopard
		43:
			var rhino: Node3D = _make_moose(id)      # stand-in until the model files are there
			rhino.scale = Vector3.ONE * 1.2
			return rhino
		44:
			var elephant: Node3D = _make_moose(id)      # stand-in until the model files are there
			elephant.scale = Vector3.ONE * 1.9
			return elephant
		45:
			var camel: Node3D = _make_horse(id)      # stand-in until the model files are there
			camel.scale = Vector3.ONE * 1.1
			return camel
		46:
			var guineafowl: Node3D = _make_grouse()      # stand-in until the model files are there
			guineafowl.scale = Vector3.ONE * 1.3
			return guineafowl
		47:
			var honey_badger: Node3D = _make_fox()      # stand-in until the model files are there
			honey_badger.scale = Vector3.ONE * 0.8
			return honey_badger
		48:
			var kangaroo: Node3D = _make_deer(id)      # stand-in until the model files are there
			kangaroo.scale = Vector3.ONE * 0.75
			return kangaroo
		49:
			var mammoth: Node3D = _make_moose(id)      # stand-in until the model files are there
			mammoth.scale = Vector3.ONE * 2.0
			return mammoth
		50:
			var tiger: Node3D = _make_fox()      # stand-in until the model files are there
			tiger.scale = Vector3.ONE * 2.6
			return tiger
		51:
			var alligator: Node3D = _make_seal()      # stand-in until the model files are there
			alligator.scale = Vector3.ONE * 1.4
			return alligator


	return null   # a species number with no model is not drawn (it used to be drawn as a rabbit)


# Whether a body that left the rows at `at` was standing on its blood trail: a wounded animal that bleeds out dies where it is,
# at the end of its trail, with no hit near. Bodies leave the rows only past send_radius_m (120 m), far beyond the 30 m a
# one-shot is played at, so a wounded animal running out of range is never heard falling.
static func near_blood(at: Vector3, points: PackedVector3Array) -> bool:
	for p in points:
		if p.distance_to(at) <= FELL_M:
			return true

	return false


# A hit the server reported (hit_number, protocol 85) at `at`: kept a moment so a body that then leaves the rows reads as killed.
func note_hit(at: Vector3, amount: int = 0) -> void:
	var now: int = Time.get_ticks_msec()
	_hits = _hits.filter(func(h): return now - int(h[1]) <= FELL_WINDOW_MS)
	_hits.append([at, now])

	if hunt_feedback and not _hit_events_seen:
		_hit_reaction(at, amount)


# Whether a body last seen at `at` that left the rows at `now_ms` was killed: a hit landed within FELL_M of it in the last
# FELL_WINDOW_MS. Bodies that walk out of range, or a snared one, leave with no hit near them.
static func killed_by_hit(at: Vector3, hits: Array, now_ms: int) -> bool:
	for h in hits:
		if now_ms - int(h[1]) <= FELL_WINDOW_MS and (h[0] as Vector3).distance_to(at) <= FELL_M:
			return true

	return false


func on_rows(rows: Array) -> void:
	var seen: Dictionary = {}

	for row in rows:
		var id: int = int(row[0])
		seen[id] = true

		# A young animal (calf, cub, fawn, piglet, foal: Dave 6 Nov 2026) comes as its species number + 100 (ServerAnimals.YOUNG_NUM);
		# it is drawn as its species, smaller.
		var young: bool = int(row[1]) >= YOUNG_NUM

		if young:
			row = row.duplicate()
			row[1] = int(row[1]) - YOUNG_NUM

		if not _bodies.has(id):
			if _bodies.size() >= MAX_DRAWN:
				continue

			var node: Node3D = _make_for_species(int(row[1]), id, young)

			if node == null:
				continue

			node.position = row[2]

			if young and not node.has_meta("young_model"):
				node.scale = Vector3.ONE * (_young_scale(int(row[1]), {"age_hash": (id * 2654435761) % 1000}) if young_gait else YOUNG_SCALE)

			add_child(node)
			_bodies[id] = {"node": node, "target": row[2], "heading": float(row[3]), "state": int(row[4]), "phase": float(id % 7), "deer": int(row[1]) >= 2 and not SMALL_SPECIES.has(int(row[1])), "wolf": int(row[1]) == 3 and not node.has_meta("model"), "quad": node.has_meta("quad"), "model": node.has_meta("model"), "kind": KIND_OF_SPECIES.get(int(row[1]), ""), "step_count": -1, "gulls": int(row[1]) == 13, "young": young, "age_hash": (id * 2654435761) % 1000}

		if int(row[4]) != int(_bodies[id]["state"]) and int(row[4]) in VOICED_STATES and KIND_OF_SPECIES.has(int(row[1])):
			state_changed.emit(KIND_OF_SPECIES[int(row[1])], int(row[4]), row[2])

		if voice_fx and int(row[4]) != int(_bodies[id]["state"]) and KIND_OF_SPECIES.has(int(row[1])):
			_voice(_bodies[id], str(KIND_OF_SPECIES[int(row[1])]), int(row[4]), row[2])

		_bodies[id]["target"] = row[2]
		_bodies[id]["heading"] = float(row[3])
		_bodies[id]["state"] = int(row[4])

		# The foe a warning or charging animal faces (Steve #659: rows in states 10 to 12 with a dog as foe carry the dog's position as a sixth
		# field): the head turns to it instead of the camera (look_at_foe, LIFE_LAYER_WIRING.md).
		_bodies[id].erase("foe")
		var health: float = -1.0

		# Fields after the five are read by type, so their order does not matter: a Vector3 is the foe (Steve #659), a number is the
		# animal's health 0 to 1 by tenths, sent only while it is hurt (Steve's hunt fields, HUNT_FEEDBACK.md); none means unhurt.
		for extra in row.slice(5):
			if extra is Vector3:
				_bodies[id]["foe"] = extra
			elif extra is float or extra is int:
				health = clampf(float(extra), 0.0, 1.0)

		if health >= 0.0:
			_bodies[id]["health"] = health
			_bodies[id]["wounded"] = health < 0.5      # the server's own count wins over the hunter's
		elif _bodies[id].has("health"):
			_bodies[id].erase("health")
			_bodies[id]["wounded"] = false

	var now: int = Time.get_ticks_msec()

	for id in _bodies.keys():
		if not seen.has(id):
			var killed: bool = killed_by_hit(_bodies[id]["target"], _hits, now) or (str(_bodies[id]["kind"]) not in BURROW_KINDS and near_blood(_bodies[id]["target"], _blood_points))

			if killed:
				fell.emit(str(_bodies[id]["kind"]), _bodies[id]["target"], str(_bodies[id]["kind"]) in SMALL_FALL_KINDS)

			if killed and hunt_feedback and bool(_bodies[id].get("model", false)):
				_death_fall(_bodies[id]["node"])      # it goes down on the slope, then is freed (the carcass item takes its place)
			else:
				_bodies[id]["node"].queue_free()

			_bodies.erase(id)


# The blood trail (protocol 55): dark red flat spots on the ground where a wounded animal ran, a pooled MeshInstance3D each,
# size varied by position so the trail does not look stamped.
func on_blood(points: PackedVector3Array) -> void:
	_blood_points = points

	if _blood_mat == null:
		# A blood trail spot as a ragged splash, not a perfect red disc (Kathreen, 3 Nov 2026): the edge is cut by noise into drips and a few flung drops,
		# wet and dark red in the middle, drying brown at the rim. Each spot is turned at random, so no two look the same.
		var shader: Shader = Shader.new()
		shader.code = BLOOD_SHADER
		_blood_mat = ShaderMaterial.new()
		_blood_mat.shader = shader

	while _blood.size() < points.size():
		var spot: MeshInstance3D = MeshInstance3D.new()
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = 0.1
		mesh.bottom_radius = 0.1
		mesh.height = 0.01
		mesh.radial_segments = 8
		mesh.rings = 1
		mesh.material = _blood_mat
		spot.mesh = mesh
		spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spot)
		_blood.append(spot)

	for i in _blood.size():
		var spot: MeshInstance3D = _blood[i]
		spot.visible = i < points.size()

		if i < points.size():
			spot.position = points[i] + Vector3(0.0, 0.03, 0.0)
			spot.rotation.y = fmod(points[i].x * 7.31 + points[i].z * 3.17, TAU)     # each spot turned its own way, steady from frame to frame
			var scale_xz: float = 0.6 + 0.8 * fposmod(points[i].x * 7.31 + points[i].z * 3.17, 1.0)
			spot.scale = Vector3(scale_xz, 1.0, scale_xz * 0.8)


# Where this view's bodies walked since the last call (grass trails, Dave 2026-10-21): a point a little behind each one that moved, within
# max_m of `from`, so no blade drops flat in front of anyone. Costs one distance test per body.
func trail_points(from: Vector3, max_m: float) -> Array:
	var out: Array = []

	for id in _bodies:
		var b: Dictionary = _bodies[id]
		var at: Vector3 = b["node"].position
		var last: Vector3 = b.get("trail_at", at)
		var step: Vector3 = Vector3(at.x - last.x, 0.0, at.z - last.z)

		if step.length() < 0.5 or from.distance_to(at) > max_m:
			continue

		b["trail_at"] = at
		out.append(at - step.normalized() * 0.6)

	return out


func drawn_count() -> int:
	return _bodies.size()


func _process(delta: float) -> void:
	var t: int = FrameProbe.start()
	_process_body(delta)
	FrameProbe.stop("animals", t)


func _process_body(delta: float) -> void:
	_t += delta

	if life_layer_all_off and (fog_looks or wind_looks or swim_rig or bird_rig or cover_still or footfall_fx or prints_fx or slope_tilt or foot_ik or stalk_fx or season_coats or coat_dust or coat_ruffle or young_gait or young_follow or water_life or idle_variety or flight_bank or look_at_foe or swarm_fx or sea_life or voice_fx or eye_shine or animal_sign or weather_looks or hunt_feedback):
		_all_flags_off()

	_print_fade_t -= delta

	if not _prints.is_empty() and _print_fade_t <= 0.0:
		_print_fade_t = 0.25      # four times a second: a 10-minute fade does not need every frame
		_fade_prints()

	if weather_looks and weather_now.is_valid():
		var rain_now: float = float((_wx_state() as Dictionary).get("rain", 0.0))
		_wx_shake_due = _wx_last_rain >= 0.4 and rain_now < 0.1      # the rain has just stopped: shakers shake (this frame only)
		_wx_last_rain = rain_now if rain_now >= 0.4 or rain_now < 0.1 else _wx_last_rain

	if animal_sign and not _signs.is_empty():
		_sign_check_t -= delta

		if _sign_check_t <= 0.0:
			_sign_check_t = 2.0
			_fade_signs()

	for id in _bodies:
		var b: Dictionary = _bodies[id]
		var node: Node3D = b["node"]
		var state: int = b["state"]

		if state == WARN_POP and not (node.has_meta("player") and (node.get_meta("player").get_meta("roles", {}) as Dictionary).has(str(WARN_POP))):
			state = 10

		var before: Vector3 = node.position
		node.position = node.position.lerp(b["target"], clampf(delta * (10.0 if state == FLEE or state == 11 or state == 14 or state == 15 else 5.0), 0.0, 1.0))
		node.rotation.y = lerp_angle(node.rotation.y, -float(b["heading"]) - PI * 0.5, clampf(delta * 10.0, 0.0, 1.0))
		if bool(b.get("model", false)):
			var model_speed: float = Vector2(node.position.x - before.x, node.position.z - before.z).length() / maxf(delta, 0.001)
			# Stepping backward while facing something (a goblin backing off from a barking dog, Steve's #659): the walk plays in reverse.
			var moved: Vector2 = Vector2(node.position.x - before.x, node.position.z - before.z)
			var facing: Vector3 = -node.global_transform.basis.z if node.is_inside_tree() else Vector3.FORWARD
			# Only while facing something (alert 3, warn 10, recover 12): a fleeing animal turning round also moves against its facing
			# for a moment, and must not run backward.
			b["backing"] = state in [3, 10, 12] and model_speed > 0.3 and moved.normalized().dot(Vector2(facing.x, facing.z).normalized()) < -0.3

			if life_layer_all_off:
				pass      # the kill switch: no life-layer looks at all (below, the clip still plays)
			elif node.has_meta("eye_mats"):
				if eye_shine:
					_eye_shine_night(node)
				else:
					_eye_shine(node)

			if node.has_meta("tail") and not life_layer_all_off:
				_tail_motion(node, state, model_speed)

			if node.has_meta("ears") and not life_layer_all_off:
				_ear_motion(node, state)

			if node.has_meta("breath") and not life_layer_all_off:
				_breath_motion(node, b, state, model_speed, delta)

			if node.has_meta("look") and not life_layer_all_off:
				_look_motion(node, b, state, delta)

			if not life_layer_all_off:
				_hop_arc(node, b, model_speed, delta)

			if float(b.get("pounce_t", -1.0)) >= 0.0:
				_pounce(node, b, delta)

			_flap_bob(node, b, state)

			if flight_bank and not (state in AIR_STATES) and b.has("bank"):
				_bank_level(node, b, delta)

			if young_gait and bool(b.get("young", false)):
				_young_wobble(node, b, state, model_speed)

			if young_follow and bool(b.get("young", false)):
				_young_follow(node, b, state, model_speed, delta)

			if sea_life and _row_of(node).has("sea"):
				_sea_blow(node, b, delta)

			if animal_sign:
				_sign_rest(node, b, state, model_speed, delta)

			if swim_rig and b.get("hop") != null and _row_of(node).has("sea"):
				_porpoise_pitch(node, b)

			if weather_looks:
				_weather_look(node, b, state, model_speed, delta)

			if wind_looks:
				_wind_look(node, b, state, model_speed, delta)

			if hunt_feedback and (b.has("react") or float(b.get("damage", 0.0)) > 0.0):
				_hunt_motion(node, b, model_speed, delta)

			if season_coats or coat_dust or coat_ruffle:
				_coat_tick(node, b, state, delta)

			if slope_tilt:
				_slope_pitch(node, b, before, delta)

			if foot_ik and node.has_meta("feet"):
				_feet(node, b, delta)

			if bool(_row_of(node).get("herd", false)) and not life_layer_all_off:
				_herd_look(node, b, state, model_speed, delta)

			if node.has_meta("poses"):
				var posed = node.get_meta("poses")      # bone_offsets.gd: a pose for a state the file has no clip for

				var pose_key: int = -1 if bool(b.get("asleep", false)) and posed.poses.has(-1) else state      # -1: the sleep pose (horses doze standing)

				if not stalk_fx and _stalking(node, state):
					pose_key = -2      # the stalk crouch is off until the PC check

				if idle_variety and b.has("idle_pose"):
					pose_key = int(b["idle_pose"])

				if bird_rig and float(b.get("flare_t", 0.0)) > 0.0 and posed.poses.has(-20):
					b["flare_t"] = float(b["flare_t"]) - delta
					pose_key = -20      # wings up and forward, tail fanned: the landing flare
				elif bird_rig and state == 0 and posed.poses.has(18) and not posed.poses.has(0):
					pose_key = 18      # a posed bird at rest holds its perch fold

				if wind_looks and bool(b.get("wind_hunch", false)) and posed.poses.has(HUNCH):
					pose_key = HUNCH      # rump to the wind and rain, head down (ANIMAL_WIND.md)
				elif weather_looks and bool(b.get("cold_huddle", false)) and posed.poses.has(HUNCH) and (state == 0 or state == 12):
					pose_key = HUNCH      # head lowered in the cold (ANIMAL_WEATHER_LOOKS.md)

				if posed.poses.has(pose_key):
					posed.pose_state = pose_key

				posed.pose_weight = move_toward(float(posed.pose_weight), 1.0 if posed.poses.has(pose_key) else 0.0, delta / (0.25 if pose_key != -1 else 1.5))
			if node.has_meta("flock_birds"):
				if swarm_fx and bool(_row_of(node).get("swarm", false)):
					_swarm(node, state)

				for bird in node.get_meta("flock_birds"):
					_animate_model(bird, b, state, model_speed, delta)
			else:
				_animate_model(node, b, state, model_speed, delta)

				# Clip-rate changes the looks asked for this frame (the ice's careful steps, the wounded limp), applied after
				# _animate_model has set the clip's rate, so they are not overwritten (REVIEW_NOTES.md bug pass).
				if b.has("speed_x"):
					var sped: AnimationPlayer = node.get_meta("player", null) as AnimationPlayer if node.has_meta("player") else null

					if sped != null and sped.speed_scale > 0.0:
						sped.speed_scale *= float(b["speed_x"])

					b.erase("speed_x")

				if cover_still and state == HUNCH:
					_cover_still(node, b)
				elif b.has("wet_hold"):
					b.erase("wet_hold")
			_emit_steps(b, node, state, model_speed)
			continue

		var rig: Node3D = node.get_node("Rig")
		var rate: float = 9.0 if state == FLEE else 5.0
		var big: bool = bool(b.get("deer", false))
		var lift: float = ((0.06 if big else 0.22) if state == FLEE else (0.02 if big else 0.1)) * absf(sin(_t * (rate * (0.8 if big else 1.0)) + float(b["phase"]))) if state != GRAZE and state != 3 else 0.0
		# Wolf idle (protocol states 8 roll in the grass, 9 play): placeholder motion until Mandy animates it.
		var roll: float = PI * 0.5 if state == 8 else 0.0
		# Big game (protocol states 10 warn: head down and stamping, 11 charge: gallop, 12 recover): placeholder motion until Mandy animates it.
		rig.rotation.x = lerp_angle(rig.rotation.x, 0.28 if state == 10 or state == 13 else (0.12 if state == 11 or state == 15 else 0.0), clampf(delta * 8.0, 0.0, 1.0))
		rig.rotation.z = lerp_angle(rig.rotation.z, roll, clampf(delta * 6.0, 0.0, 1.0))
		if bool(b.get("wolf", false)):
			_animate_wolf(node, b, state, Vector2(node.position.x - before.x, node.position.z - before.z).length() / maxf(delta, 0.001), delta)
		elif bool(b.get("quad", false)):
			_animate_quad(node, b, state, Vector2(node.position.x - before.x, node.position.z - before.z).length() / maxf(delta, 0.001), delta)
		else:
			rig.position.y = lerp(rig.position.y, lift + (0.25 * absf(sin(_t * 7.0 + float(b["phase"]))) if state == 9 else 0.0), clampf(delta * 20.0, 0.0, 1.0))

		if bool(b.get("gulls", false)):
			_animate_gulls(rig, state == 15)

		_emit_steps(b, node, state, Vector2(node.position.x - before.x, node.position.z - before.z).length() / maxf(delta, 0.001))


# Realistic animal models (Dave 6 Nov 2026: aim for photorealism; design/realistic_animals_plan.md): a species listed in
# data/animals/models.json with a scene that exists is drawn from that scene (a rigged, animated mesh) instead of the code-built
# body; a missing file falls back to the code body, so a model can be added one species at a time. The row gives the scene, its
# scale and yaw (to face -Z), the clip for each protocol state, and the ground speed its walk and run clips were made at.
func _model_rows() -> Dictionary:
	if _models == null:
		_models = {}

		if FileAccess.file_exists(MODELS_PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MODELS_PATH))
			_models = (parsed as Dictionary).get("species", {}) if parsed is Dictionary else {}

	return _models


func _make_model(number: int, id: int = 0, young: bool = false) -> Node3D:
	var kind: String = str(KIND_OF_SPECIES.get(number, ""))
	var row: Dictionary = _model_rows().get(kind, {})

	# Several looks for one species (goblins, Dave 7 Nov 2026: Skritch and Rukz): the row's "variants" are laid over it, one picked by the
	# animal's id, so every goblin keeps its look. A row with height_m is sized by its mesh height, not its longest side, and each animal
	# gets its own height: height_m plus a bell-shaped roll of up to height_variation_m either way (the mean of three even rolls), seeded
	# from its id so it is the same on every client and every time it comes into view.
	if row.has("variants") and not (row["variants"] as Array).is_empty():
		var looks: Array = row["variants"]
		row = row.duplicate()
		row.merge(looks[id % looks.size()], true)

	# A young animal with a model of its own (young_model: scene, pack, clips, materials, length_m ...) is drawn from it, at its own size.
	var own_young: bool = young and row.get("young_model", null) is Dictionary

	if own_young:
		var young_row: Dictionary = row["young_model"]
		row = row.duplicate()
		row.erase("variants")
		row.merge(young_row, true)

	if row.has("height_m"):
		var dice: RandomNumberGenerator = RandomNumberGenerator.new()
		dice.seed = id * 7919 + 13
		var roll: float = (dice.randf_range(-1.0, 1.0) + dice.randf_range(-1.0, 1.0) + dice.randf_range(-1.0, 1.0)) / 3.0
		row = row.duplicate()
		row["length_m"] = float(row["height_m"]) + roll * float(row.get("height_variation_m", 0.0))

	if row.is_empty():
		return null

	if not ResourceLoader.exists(str(row.get("scene", ""))):
		_model_note(kind, "no file at %s: the code-built body is drawn" % str(row.get("scene", "")))
		return null

	var packed: PackedScene = load(str(row["scene"])) as PackedScene

	if packed == null:
		_model_note(kind, "%s did not load as a scene: the code-built body is drawn" % str(row["scene"]))
		return null

	var inst: Node = packed.instantiate()
	var meshes: Array = inst.find_children("*", "MeshInstance3D", true, false)

	if not (inst is Node3D) or meshes.is_empty():
		_model_note(kind, "%s has no mesh: the code-built body is drawn" % str(row["scene"]))
		inst.free()
		return null

	for m in meshes:
		_fit_skin(m as MeshInstance3D, inst, kind)

	var root: Node3D = Node3D.new()
	root.set_meta("model", true)
	root.set_meta("model_row", row)
	root.set_meta("meshes", meshes)

	if own_young:
		root.set_meta("young_model", true)
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	rig.add_child(inst)
	var body: Node3D = inst as Node3D
	body.rotation.y += deg_to_rad(float(row.get("yaw_deg", 0.0)))

	# Size from the mesh itself, not the file's units (an FBX may be in centimetres, metres, or carry its own root scale): the
	# longest side of the rest-pose bounds is made row.length_m, and the feet are put on the ground.
	# "bounds": "mesh" sizes by the skinned mesh instead of the bones: a bird's feathers reach far past its bones (the crow's bone
	# box is half its body), so a bone-sized crow was drawn twice too long.
	var box: AABB = _model_bounds(rig, meshes, row.has("height_m") or str(row.get("bounds", "")) == "mesh")

	# "size_clip": a model whose imported pose is not how it stands (the crow's is wings spread, three times its folded length) is
	# sized and grounded by its bones in the first frame of that clip instead, grown by the same 6% as the rest-pose bones.
	if row.has("size_clip"):
		var size_players: Array = inst.find_children("*", "AnimationPlayer", true, false)

		if not size_players.is_empty():
			var sp: AnimationPlayer = size_players[0]
			var size_name: String = _clip_full(sp, row, str(row["size_clip"]))

			if size_name != "":
				var posed: AABB = _clip_box(sp, sp.get_animation(size_name), rig)
				var side: float = maxf(posed.size.x, maxf(posed.size.y, posed.size.z))

				if side > 0.0001:
					box = posed.grow(side * 0.06)
			else:
				_model_note(kind, "no clip %s to size by" % str(row["size_clip"]))
	var longest: float = box.size.y if row.has("height_m") else maxf(box.size.x, maxf(box.size.y, box.size.z))

	if longest <= 0.0001:
		_model_note(kind, "%s has empty bounds: the code-built body is drawn" % str(row["scene"]))
		root.free()
		return null

	var k: float = float(row.get("length_m", longest)) / longest * float(row.get("scale", 1.0))
	body.scale *= k
	body.position.y -= box.position.y * k
	_model_materials(meshes, row)
	var eye_mats: Array = []

	for m in meshes:
		eye_mats.append_array((m as MeshInstance3D).get_meta("eye_mats", []))

	# A model whose eyes are only painted on its body texture gets two small glossy eyes on its eye bones (eye_bones [left, right])
	# or at eye_offset [x, y, z] (metres at the drawn size, x mirrored for the right eye) from its head bone (head_bone): they carry the
	# highlight every living eye has and the torchlight eye shine (docs/design/POSE_FIXES_PICTURES.md section 2).
	if eye_mats.is_empty() and (row.has("eye_bones") or row.has("eye_offset")):
		eye_mats = _add_eyes(inst, row, k, kind)

	if not eye_mats.is_empty():
		root.set_meta("eye_mats", eye_mats)

	if inst.has_meta("eye_dots"):
		root.set_meta("eye_dots", inst.get_meta("eye_dots"))      # the far-off glints (eye_shine)

	# Bone corrections and tail motion laid over every clip (bone_offsets.gd: the crow stands up and folds its wings; a dog wags).
	if row.has("bone_offsets") or row.has("tail_motion") or row.has("ear_motion") or row.has("breath") or row.has("look") or row.has("state_poses") or row.has("feet") or row.has("stalk") or (row.has("idles") and idle_variety) or (bird_rig and _posed_flight(row)) or (swim_rig and _posed_swim(row)):
		var sks: Array = inst.find_children("*", "Skeleton3D", true, false)

		if not sks.is_empty():
			var fix: SkeletonModifier3D = BoneOffsetsScript.new()
			var missing: PackedStringArray = fix.setup(sks[0], row.get("bone_offsets", {}))

			if row.has("tail_motion"):
				missing.append_array(fix.setup_waves(sks[0], row["tail_motion"]))
				root.set_meta("tail", fix)

			if row.has("ear_motion"):
				missing.append_array(fix.setup_ears(sks[0], row["ear_motion"]))
				root.set_meta("ears", fix)

			if row.has("breath"):
				missing.append_array(fix.setup_breath(sks[0], row["breath"]))
				root.set_meta("breath", fix)

			if row.has("look"):
				missing.append_array(fix.setup_look(sks[0], row["look"]))
				root.set_meta("look", fix)

			if row.has("state_poses"):
				missing.append_array(fix.setup_poses(sks[0], row["state_poses"]))
				root.set_meta("poses", fix)

			# A whale or dolphin posed from its own spine (SWIM_RIG.md): the tail beat in states 0, 1, 2.
			if swim_rig and _posed_swim(row):
				var swim_poses: Dictionary = _swim_poses(sks[0], row, kind)

				if not swim_poses.is_empty():
					missing.append_array(fix.setup_poses(sks[0], swim_poses))
					root.set_meta("poses", fix)

			# A bird or bat posed from its own wing bones (BIRD_FLIGHT.md part 3): flap 15, glide 17, perch 18 and 0, landing flare -20.
			if bird_rig and _posed_flight(row):
				var wing_poses: Dictionary = _wing_poses(sks[0], row, kind)

				if not wing_poses.is_empty():
					missing.append_array(fix.setup_poses(sks[0], wing_poses))
					root.set_meta("poses", fix)

			# Posed idles (IDLE_VARIETY.md): entry i of the row's idles with a "pose" is pose key -10 - i.
			if row.has("idles") and idle_variety:
				var idle_poses: Dictionary = {}

				for i in (row["idles"] as Array).size():
					if (row["idles"][i] as Dictionary).has("pose"):
						idle_poses[str(-10 - i)] = row["idles"][i]["pose"]

				if not idle_poses.is_empty():
					missing.append_array(fix.setup_poses(sks[0], idle_poses))
					root.set_meta("poses", fix)

			if row.has("stalk") and (row["stalk"] as Dictionary).has("pose"):
				var stalk_poses: Dictionary = {}

				for st in row["stalk"].get("states", []):
					stalk_poses[str(st)] = row["stalk"]["pose"]

				missing.append_array(fix.setup_poses(sks[0], stalk_poses))
				root.set_meta("poses", fix)

			if row.has("feet"):
				missing.append_array(fix.setup_legs(sks[0], row["feet"]))
				fix.leg_scale = 1.0 / maxf(_to_ancestor(sks[0], rig).basis.get_scale().x, 0.000001)
				root.set_meta("feet", fix)

			(sks[0] as Skeleton3D).add_child(fix)

			if not missing.is_empty():
				_model_note(kind, "bone_offsets / tail_motion: no bone %s" % ", ".join(missing))
	var players: Array = inst.find_children("*", "AnimationPlayer", true, false)

	if not players.is_empty():
		var player: AnimationPlayer = players[0]
		root.set_meta("player", player)

		# Each role the row names (state numbers, walk, run) is resolved once to a clip in this file (_role_clip: the row's
		# names first, then a clip whose name says the role), and those clips loop. A clip whose bone positions are in other
		# units than the skeleton (the bear lay flat as a legless tube, 7 Nov 2026) is rescaled to it (_fit_clip_units).
		var roles: Dictionary = {}

		# Hand-made gait clips (gait {role: spec}): a model with no usable clip for a role gets one built from its own bones
		# (_gait_clip). They are added under the name "gait_<role>" and the row's clips point at it.
		for gait_role in (row.get("gait", {}) as Dictionary):
			var gait_name: String = "gait_%s" % str(gait_role)

			if player.has_animation_library("") and not player.has_animation(gait_name):
				var made: Animation = _gait_clip(player, rig, row["gait"][gait_role], kind)

				if made != null:
					player.get_animation_library("").add_animation(gait_name, made)

			row = row.duplicate(true)

			if not row.has("clips"):
				row["clips"] = {}

			(row["clips"] as Dictionary)[str(gait_role)] = gait_name

		# A refused clip (it lays the model flat) does not leave the role empty: the next clip that names the role is tried (the elk's
		# file has two clips called Walk, one of them shrinking the rig to a hundredth; MikeW, 7 Nov 2026).
		var rest_h: float = _clip_height(player, null, rig)

		for key in _ROLE_WORDS.keys() + (row.get("clips", {}) as Dictionary).keys():
			var refused: Dictionary = {}

			for attempt in 6:
				var anim_name: String = _role_clip(player, row, str(key), refused)

				if anim_name == "":
					if (row.get("clips", {}) as Dictionary).has(key) and refused.is_empty():
						_model_note(kind, "no clip for role %s (%s)" % [str(key), str(row["clips"][key])])
					break

				var anim: Animation = player.get_animation(anim_name)

				# clip_loop {role: [t0, t1, blend_s]}: a file with no looping clip for a role (the mink has only start clips) loops a
				# window of another one; tools/find_loop.gd finds the window whose ends are most alike, and the last blend_s seconds
				# are eased back to the first pose so the loop has no jump.
				var loop_spec: Variant = (row.get("clip_loop", {}) as Dictionary).get(str(key), null)

				if loop_spec is Array and (loop_spec as Array).size() >= 2 and not anim_name.begins_with("gait_"):      # a hand-made gait already loops
					var loop_name: String = anim_name + "_loop_%s" % str(key)      # imported clips sit in the default library, "armature|clip"

					if player.has_animation_library("") and not player.has_animation(loop_name):
						player.get_animation_library("").add_animation(loop_name, _loop_copy(anim, float(loop_spec[0]), float(loop_spec[1]), float(loop_spec[2]) if (loop_spec as Array).size() > 2 else 0.1))

					anim_name = loop_name
					anim = player.get_animation(anim_name)
					_model_note(kind, "role %s loops %s from %.3f to %.3f s" % [str(key), anim_name, float(loop_spec[0]), float(loop_spec[1])])

				_fit_clip_units(player, anim, kind, anim_name)

				# A clip that lays the animal flat (the bear drew as a legless tube on the ground, 7 Nov 2026) is not used: its pose is
				# measured against the rest pose, and the next clip for the role is tried; with none, the model keeps its rest pose.
				var clip_h: float = _clip_height(player, anim, rig)

				if rest_h > 0.0001 and clip_h < rest_h * float(row.get("flat_share", 0.5)) and str(key) != "sleep":      # a sleeping animal lies low on purpose      # flat_share: an upright animal (the kangaroo) bends lower than half its height to eat
					_model_note(kind, "clip %s lays the model flat (height %.2f against %.2f standing): not used" % [anim_name, clip_h, rest_h])
					refused[anim_name] = true
					continue

				anim.loop_mode = Animation.LOOP_LINEAR
				_strip_root_drift(player, anim, rig, kind, anim_name)

				# An in-place walk or run (no travel in the clip) gets its speed from its feet: docs/design/FOOT_SLIDING.md.
				if (str(key) == "walk" or str(key) == "run") and not anim.has_meta("travel_mps") and not anim.has_meta("stride_measured"):
					anim.set_meta("stride_measured", true)
					var stride_mps: float = _measure_stride(player, anim, rig)

					if stride_mps >= 0.2 and stride_mps <= 25.0:
						anim.set_meta("travel_mps", stride_mps)
						_model_note(kind, "clip %s: feet move %.2f m/s on the ground, played at speed / %.2f" % [anim_name, stride_mps, stride_mps])
				roles[str(key)] = anim_name
				break

		player.set_meta("roles", roles)
		_model_note(kind, "clips by role %s" % str(roles))

	_model_note(kind, "drawn from %s: %d meshes, %.2f m long (file size %.2f, scale x%.4f)" % [str(row["scene"]), meshes.size(), longest * k, longest, k])
	return root


# The bounds of a model in the rig's space (so the file's own root scale and rotation count). With a skeleton, the bones' posed
# positions are used: a skinned FBX can keep its centimetre scale on a bone, which the mesh's own bounds never see (Dave 6 Nov saw
# a bear five times taller than a tree). The bones stop short of the skin, so their box is widened by 12%.
func _model_bounds(rig: Node3D, meshes: Array, by_mesh: bool = false) -> AABB:
	var skeletons: Array = rig.find_children("*", "Skeleton3D", true, false)

	if not by_mesh and not skeletons.is_empty():
		var sk: Skeleton3D = skeletons[0]
		var to_rig: Transform3D = _to_ancestor(sk, rig)
		var bones: AABB = AABB()

		for i in sk.get_bone_count():
			var at: Vector3 = to_rig * sk.get_bone_global_pose(i).origin
			bones = AABB(at, Vector3.ZERO) if i == 0 else bones.expand(at)

		if maxf(bones.size.x, maxf(bones.size.y, bones.size.z)) > 0.0001:
			return bones.grow(maxf(bones.size.x, maxf(bones.size.y, bones.size.z)) * 0.06)

	var box: AABB = AABB()
	var first: bool = true

	for m in meshes:
		var mi: MeshInstance3D = m
		var part: AABB = (_to_ancestor(mi, rig) * mi.get_aabb()) if mi.mesh != null else AABB()
		var sk_of: Skeleton3D = mi.get_node_or_null(mi.skeleton) as Skeleton3D

		# A skinned mesh is drawn through its skeleton (bone pose * bind), not through its own node: the goblins' files keep the
		# armature at a hundredth with the mesh node at 1, so the node box was 1 cm tall and the goblin was drawn 85 times too
		# big (MikeW's creature check, 7 Nov 2026). The box is taken through the first bind instead.
		if mi.mesh != null and mi.skin != null and sk_of != null and mi.skin.get_bind_count() > 0:
			var bone_name: String = str(mi.skin.get_bind_name(0))
			var bone: int = sk_of.find_bone(bone_name) if bone_name != "" else mi.skin.get_bind_bone(0)

			if bone >= 0:
				part = (_to_ancestor(sk_of, rig) * sk_of.get_bone_global_pose(bone) * mi.skin.get_bind_pose(0)) * mi.get_aabb()

		box = part if first else box.merge(part)
		first = false

	return box


# The transform from a node's space to one of its ancestors' space.
func _to_ancestor(node: Node, ancestor: Node) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var n: Node = node

	while n != null and n != ancestor:
		if n is Node3D:
			t = (n as Node3D).transform * t

		n = n.get_parent()

	return t


# The pack's FBX files name normal maps that are not in the pack, so the materials are set here: each surface whose material or
# mesh name contains a row.materials "match" gets that colour texture (the first entry with match "" covers the rest).
func _model_materials(meshes: Array, row: Dictionary) -> void:
	var sets: Array = row.get("materials", [])

	if sets.is_empty():
		return

	for m in meshes:
		var mi: MeshInstance3D = m

		if mi.mesh == null:
			continue

		for surface in mi.mesh.get_surface_count():
			var old: Material = mi.mesh.surface_get_material(surface)
			var file_tex: Texture2D = (old as BaseMaterial3D).albedo_texture if old is BaseMaterial3D else null
			# The imported material's own colour texture names the part best (T_Bear_Head.png), then the material, then the mesh.
			var name_text: String = (file_tex.resource_path.get_file() if file_tex != null else "") + " " + (str(old.resource_name) if old != null else "") + " " + str(mi.name)

			for entry in sets:
				var match_text: String = str(entry.get("match", ""))

				if match_text == "" or name_text.findn(match_text) >= 0:
					# A hide entry (a horse's saddle on a wild horse) cuts that part away entirely.
					if bool(entry.get("hide", false)):
						var gone: StandardMaterial3D = StandardMaterial3D.new()
						gone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
						gone.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
						mi.set_surface_override_material(surface, gone)
						_model_note(str(row.get("scene", "")).get_file(), "surface %d of %s [%s] hidden" % [surface, str(mi.name), name_text.strip_edges()])
						break

					var tex: Texture2D = load(str(entry.get("albedo", ""))) as Texture2D if ResourceLoader.exists(str(entry.get("albedo", ""))) else null

					if tex != null:
						var mat: StandardMaterial3D = StandardMaterial3D.new()
						mat.albedo_texture = tex
						mat.roughness = float(entry.get("roughness", 0.9))

						# Fur cards (the ruff round a bear's neck, lashes, lips) are cut out by the texture's alpha: drawn solid,
						# their cut-away parts show as black bands. Cut them, and draw both sides of the cards.
						# "opaque": a texture whose alpha holds something else (the goat's is nearly all zero) is drawn solid.
						if (_has_alpha(tex) or bool(entry.get("alpha", false))) and not bool(entry.get("opaque", false)):
							mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
							mat.alpha_scissor_threshold = float(entry.get("alpha_cut", 0.5))
							mat.cull_mode = BaseMaterial3D.CULL_DISABLED

						var is_eye: bool = name_text.findn("eye") >= 0 and name_text.findn("lid") < 0
						var coat: Material = mat

						if coat_ruffle and float(row.get("ruffle_cm", 0.0)) > 0.0 and not is_eye:
							coat = _ruffle_material(mat)
						mi.set_surface_override_material(surface, coat)

						if not is_eye:
							coat.set_meta("rough", mat.roughness)
							coat.set_meta("card", mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED)
							var coat_mats: Array = mi.get_meta("coat_mats", [])
							coat_mats.append(coat)
							mi.set_meta("coat_mats", coat_mats)

						# The eye surfaces (a material or texture named for the eye, not a lid or lash) carry the eye shine (_eye_shine).
						if name_text.findn("eye") >= 0 and name_text.findn("lid") < 0 and name_text.findn("lash") < 0 and float(row.get("shine", 0.0)) > 0.0:
							mat.emission_enabled = true
							mat.emission = Color.html(str(row.get("shine_color", "#ffffff")))
							mat.emission_energy_multiplier = 0.0
							var eyes: Array = mi.get_meta("eye_mats", [])
							eyes.append(mat)
							mi.set_meta("eye_mats", eyes)

					# One line per surface, so a part that takes the wrong texture (a dark band, dark eyes) shows which name it matched.
					_model_note(str(row.get("scene", "")).get_file(), "surface %d of %s [%s] takes %s" % [surface, str(mi.name), name_text.strip_edges(), str(entry.get("albedo", "")).get_file()])
					break


# Whether a texture has see-through pixels (checked once per texture).
func _has_alpha(tex: Texture2D) -> bool:
	var key: String = tex.resource_path

	if not _alpha_of.has(key):
		var img: Image = tex.get_image()

		if img != null and img.is_compressed():
			img = img.duplicate() as Image
			img.decompress()

		_alpha_of[key] = img != null and img.detect_alpha() != Image.ALPHA_NONE

	return bool(_alpha_of[key])


# A clip's full name in the player: row.clip_prefix + name when that exists, else the one clip whose name after its armature
# ("Armature|Idle") is the name, so a row need not know each file's armature name. "" when there is none. Cached per player.
func _clip_full(player: AnimationPlayer, row: Dictionary, clip_name: String) -> String:
	var prefixed: String = str(row.get("clip_prefix", "")) + clip_name

	if player.has_animation(prefixed):
		return prefixed

	if not player.has_meta("clip_map"):
		var by_bare: Dictionary = {}

		for full in player.get_animation_list():
			by_bare[str(full).get_slice("|", str(full).count("|"))] = str(full)

		player.set_meta("clip_map", by_bare)

	return str((player.get_meta("clip_map") as Dictionary).get(clip_name, ""))


# The words that name a role's clip in a file, tried in order when the row's own names are not in it (WildMesh files differ:
# G0_Walk, WalkMedium_F, walk_fwd_01). Transitions and turns ("Idle_to_Walk", "WalkL") are skipped.
const _ROLE_WORDS := {"0": ["idle_breathing", "graz", "idle"], "walk": ["walkmedium", "walk"], "run": ["gallop", "runfast", "run", "canter", "trot", "sprint"]}


func _role_clip(player: AnimationPlayer, row: Dictionary, role: String, refused: Dictionary = {}) -> String:
	var wanted: Variant = (row.get("clips", {}) as Dictionary).get(role, [])

	for name_text in (wanted if wanted is Array else [wanted]):
		var full: String = _clip_full(player, row, str(name_text))

		if full != "" and not refused.has(full):
			return full

		for other in player.get_animation_list():      # another clip with the same bare name (a file can hold two)
			if str(other).get_slice("|", str(other).count("|")) == str(name_text) and not refused.has(str(other)):
				return str(other)

	for word in _ROLE_WORDS.get(role, []):
		for full in player.get_animation_list():
			var bare: String = str(full).get_slice("|", str(full).count("|")).to_lower().replace(" ", "_")      # "idle to walk fwd" reads as idle_to_walk_fwd

			if bare.contains("dead") or bare.contains("death") or bare.contains("hit_") or bare.contains("interact") or bare.contains("attack") or bare.begins_with("start") or bare.ends_with("end") or bare.contains("stop"):
				continue      # the raccoon's "dead run" is not its run, nor the second wolf's "Attack_Run"

			if refused.has(str(full)):
				continue

			if bare.contains(str(word)) and not bare.contains("_to_") and not bare.contains("2") and not bare.ends_with("l") and not bare.ends_with("r") and not bare.contains("wound") and not bare.contains("injur") and not bare.contains("lying"):
				return str(full)

	return ""


# A skinned mesh draws right when every bind agrees with its bone's rest: rest * bind maps the mesh into the skeleton the
# same way for every bone (one shared transform C, whatever units or armature scale the file uses). The bear lay as a
# legless tube in the game while its skeleton stood (7 Nov 2026): binds that disagree pull parts of the skin apart. The
# spread of rest * bind across bones is measured at the mesh's own box corners against that box's size under C (unitless,
# so a file's scale never triggers it). Over 5%, every bind is rebuilt as inverse(rest) * C on a copy of the skin, C being
# the transform most binds agree with, and a log line says so.
func _fit_skin(mi: MeshInstance3D, top: Node, kind: String) -> void:
	if mi.skin == null or mi.mesh == null or mi.skin.get_bind_count() < 2:
		return

	var sk: Skeleton3D = mi.get_node_or_null(mi.skeleton) as Skeleton3D

	if sk == null:
		var found: Array = top.find_children("*", "Skeleton3D", true, false)
		sk = found[0] if not found.is_empty() else null

	if sk == null or sk.get_bone_count() == 0:
		return

	var box: AABB = mi.mesh.get_aabb()
	var probes: Array = [box.position, box.end, Vector3(box.end.x, box.position.y, box.position.z), Vector3(box.position.x, box.end.y, box.end.z)]
	var maps: Array = []      # [bind index, rest * bind]
	var bones: PackedInt32Array = PackedInt32Array()

	for b in mi.skin.get_bind_count():
		var bone_name: String = str(mi.skin.get_bind_name(b))
		var bone: int = sk.find_bone(bone_name) if bone_name != "" else mi.skin.get_bind_bone(b)
		bones.append(bone)

		if bone >= 0 and bone < sk.get_bone_count():
			maps.append([b, sk.get_bone_global_rest(bone) * mi.skin.get_bind_pose(b)])

	if maps.size() < 2:
		return

	# C: the map most binds agree with (the one nearest the rest, over an even sample of at most 24, so big rigs stay cheap).
	var step: int = maxi(1, int(maps.size() / 24.0))
	var shared: Transform3D = maps[0][1]
	var best: float = INF

	for i in range(0, maps.size(), step):
		var total: float = 0.0

		for j in range(0, maps.size(), step):
			total += _map_gap(maps[i][1], maps[j][1], probes)

		if total < best:
			best = total
			shared = maps[i][1]

	var scale_ref: float = (shared * box.end).distance_to(shared * box.position)
	var worst: float = 0.0

	for m in maps:
		worst = maxf(worst, _map_gap(m[1], shared, probes))

	if scale_ref <= 0.0 or worst <= scale_ref * 0.05:
		return

	var skin: Skin = mi.skin.duplicate() as Skin

	for b in skin.get_bind_count():
		if bones[b] >= 0 and bones[b] < sk.get_bone_count():
			skin.set_bind_pose(b, sk.get_bone_global_rest(bones[b]).affine_inverse() * shared)

	mi.skin = skin
	_model_note(kind, "skin of %s rebuilt: its binds disagreed by %.0f%% of the body's size" % [str(mi.name), 100.0 * worst / scale_ref])


# How far apart two mesh-to-skeleton maps put the probe points (the largest gap).
func _map_gap(x: Transform3D, y: Transform3D, probes: Array) -> float:
	var gap: float = 0.0

	for probe in probes:
		gap = maxf(gap, (x * (probe as Vector3)).distance_to(y * (probe as Vector3)))

	return gap


# How tall the skeleton stands in the rig's space (the height of its bones' box) in a clip's first frame, or in its imported pose with no clip.
# Worked out from the clip's own tracks and the bone rests, so it needs no running player.
func _clip_height(player: AnimationPlayer, anim: Animation, rig: Node3D) -> float:
	return _clip_box(player, anim, rig).size.y


# The box of the skeleton's bones in the rig's space in a clip's first frame (or the imported pose with no clip).
func _clip_box(player: AnimationPlayer, anim: Animation, rig: Node3D) -> AABB:
	var bones: PackedVector3Array = _clip_bones(player, anim, rig, 0.0)
	var box: AABB = AABB()

	for i in bones.size():
		box = AABB(bones[i], Vector3.ZERO) if i == 0 else box.expand(bones[i])

	return box


# The bones of the skeleton in the rig's space at `time` into a clip (or the imported pose with no clip), from the clip's own tracks
# and the bone rests: no running player needed.
func _clip_bones(player: AnimationPlayer, anim: Animation, rig: Node3D, time: float = 0.0) -> PackedVector3Array:
	var skeletons: Array = rig.find_children("*", "Skeleton3D", true, false)

	if skeletons.is_empty():
		return PackedVector3Array()

	var sk: Skeleton3D = skeletons[0]
	var local: Array = []

	for i in sk.get_bone_count():
		local.append(sk.get_bone_pose(i))      # the pose as imported (the bear stands in it on the animal sheet)

	if anim != null:
		var base: Node = player.get_node_or_null(player.root_node)

		for t in anim.get_track_count():
			var kind: int = anim.track_get_type(t)

			if kind != Animation.TYPE_POSITION_3D and kind != Animation.TYPE_ROTATION_3D and kind != Animation.TYPE_SCALE_3D:
				continue

			var path: NodePath = anim.track_get_path(t)

			if base == null or base.get_node_or_null(NodePath(str(path.get_concatenated_names()))) != sk:
				continue

			var bone: int = sk.find_bone(str(path.get_concatenated_subnames()))

			if bone < 0 or anim.track_get_key_count(t) == 0:
				continue

			var bone_xf: Transform3D = local[bone]

			if kind == Animation.TYPE_POSITION_3D:
				bone_xf.origin = anim.position_track_interpolate(t, time)
			elif kind == Animation.TYPE_ROTATION_3D:
				bone_xf.basis = Basis(anim.rotation_track_interpolate(t, time)).scaled(bone_xf.basis.get_scale())
			else:
				bone_xf.basis = Basis(bone_xf.basis.get_rotation_quaternion()).scaled(anim.scale_track_interpolate(t, time))

			local[bone] = bone_xf

	# Tracks on the nodes above the skeleton (RigRoot) count too: a clip can scale or turn the whole rig (the elk's second Walk
	# shrinks it to a hundredth).
	var to_rig: Transform3D = Transform3D.IDENTITY
	var up: Node = sk

	while up != null and up != rig:
		if up is Node3D:
			var xf: Transform3D = (up as Node3D).transform

			if anim != null and up != sk:
				var base_node: Node = player.get_node_or_null(player.root_node)
				var origin: Vector3 = xf.origin
				var turn: Quaternion = xf.basis.get_rotation_quaternion()
				var size: Vector3 = xf.basis.get_scale()

				for t in anim.get_track_count():
					var tp: NodePath = anim.track_get_path(t)

					if tp.get_subname_count() > 0 or anim.track_get_key_count(t) == 0 or base_node == null or base_node.get_node_or_null(NodePath(str(tp.get_concatenated_names()))) != up:
						continue

					match anim.track_get_type(t):
						Animation.TYPE_POSITION_3D:
							origin = anim.position_track_interpolate(t, time)
						Animation.TYPE_ROTATION_3D:
							turn = anim.rotation_track_interpolate(t, time)
						Animation.TYPE_SCALE_3D:
							size = anim.scale_track_interpolate(t, time)

				xf = Transform3D(Basis(turn) * Basis.from_scale(size), origin)

			to_rig = xf * to_rig

		up = up.get_parent()

	var world: Array = []
	world.resize(sk.get_bone_count())
	var out: PackedVector3Array = PackedVector3Array()
	out.resize(sk.get_bone_count())

	for i in sk.get_bone_count():
		var chain: Array = []
		var b: int = i

		while b >= 0 and world[b] == null:
			chain.push_front(b)
			b = sk.get_bone_parent(b)

		for c in chain:
			var parent: int = sk.get_bone_parent(c)
			world[c] = (world[parent] as Transform3D) * (local[c] as Transform3D) if parent >= 0 else local[c]

		out[i] = to_rig * (world[i] as Transform3D).origin

	return out


# Some files keep their bone positions in other units than the skeleton's rest pose (a centimetre clip on a metre skeleton):
# played as they are, every bone falls into the body. The middle ratio of rest length to the clip's first key over the
# position tracks gives the factor; far from 1 (below 0.2 or above 5), every position key is scaled by it. Once per clip.
func _fit_clip_units(player: AnimationPlayer, anim: Animation, kind: String, anim_name: String) -> void:
	if anim.has_meta("units_fitted"):
		return

	anim.set_meta("units_fitted", true)
	var base: Node = player.get_node_or_null(player.root_node)

	if base == null:
		return

	var ratios: Array = []
	var tracks: Array = []

	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_POSITION_3D or anim.track_get_key_count(t) == 0:
			continue

		var path: NodePath = anim.track_get_path(t)
		var sk: Skeleton3D = base.get_node_or_null(NodePath(str(path.get_concatenated_names()))) as Skeleton3D

		if sk == null:
			continue

		var bone: int = sk.find_bone(str(path.get_concatenated_subnames()))

		if bone < 0:
			continue

		tracks.append(t)
		var rest_len: float = sk.get_bone_rest(bone).origin.length()
		var key_len: float = (anim.track_get_key_value(t, 0) as Vector3).length()

		if rest_len > 0.0001 and key_len > 0.000001:
			ratios.append(rest_len / key_len)

	if ratios.size() < 3:
		return

	ratios.sort()
	var k: float = float(ratios[int(ratios.size() * 0.5)])

	if k > 0.2 and k < 5.0:
		return

	for t in tracks:
		for i in anim.track_get_key_count(t):
			anim.track_set_key_value(t, i, (anim.track_get_key_value(t, i) as Vector3) * k)

	_model_note(kind, "clip %s bone positions rescaled x%.4f to the skeleton" % [anim_name, k])


# Some clips carry the animal forward themselves (root motion). In the WildMesh files the travel sits on the RigRoot node above
# the skeleton: the bear's Sprint moves it 6 m in half a second, its Walk 1.4 m in 1.7 s. The server already moves the animal, so
# such a clip drew the body running ahead of where the animal is and snapping back at every loop (MikeW's creature check,
# 7 Nov 2026). The steady horizontal travel from the first key to the last is taken out of every key of a node above the
# skeleton, the root bone and its first children; the sway and bob inside the stride stay, and so does up and down travel (a
# rearing or lying-down clip needs it). Only travel over a tenth of the standing height counts. The travel speed is kept on the
# clip ("travel_mps", metres a second at the drawn size): it is the speed the feet were made for, so the walk and run clips are
# played at speed / travel_mps and the feet do not slide. Once per clip.
func _strip_root_drift(player: AnimationPlayer, anim: Animation, rig: Node3D, kind: String, anim_name: String) -> void:
	if anim.has_meta("drift_stripped"):
		return

	anim.set_meta("drift_stripped", true)
	var base: Node = player.get_node_or_null(player.root_node)
	var skeletons: Array = rig.find_children("*", "Skeleton3D", true, false)

	if base == null or skeletons.is_empty() or anim.length <= 0.0:
		return

	var sk: Skeleton3D = skeletons[0]
	var sk_to_rig: Basis = _to_ancestor(sk, rig).basis
	var lo: float = INF
	var hi: float = -INF

	for i in sk.get_bone_count():
		var y: float = (sk_to_rig * sk.get_bone_global_rest(i).origin).y
		lo = minf(lo, y)
		hi = maxf(hi, y)

	var tall: float = hi - lo

	if tall <= 0.0001:
		return

	var mps: float = 0.0

	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_POSITION_3D or anim.track_get_key_count(t) < 2:
			continue

		var path: NodePath = anim.track_get_path(t)
		var target: Node = base.get_node_or_null(NodePath(str(path.get_concatenated_names())))
		var to_parent: Basis

		if target == sk and path.get_subname_count() > 0:
			var bone: int = sk.find_bone(str(path.get_concatenated_subnames()))
			var parent: int = sk.get_bone_parent(bone) if bone >= 0 else -1

			if bone < 0 or (parent >= 0 and sk.get_bone_parent(parent) >= 0):
				continue      # only the root bone and its first children carry the travel

			to_parent = sk_to_rig * (sk.get_bone_global_rest(parent).basis if parent >= 0 else Basis.IDENTITY)
		elif target is Node3D and path.get_subname_count() == 0 and (target == sk or (target as Node).is_ancestor_of(sk)) and target.get_parent() != null:
			to_parent = _to_ancestor(target.get_parent(), rig).basis
		else:
			continue

		var last: int = anim.track_get_key_count(t) - 1
		var drift: Vector3 = to_parent * ((anim.track_get_key_value(t, last) as Vector3) - (anim.track_get_key_value(t, 0) as Vector3))
		drift.y = 0.0

		if drift.length() < tall * 0.1:
			continue

		var span: float = maxf(anim.track_get_key_time(t, last) - anim.track_get_key_time(t, 0), 0.0001)
		var local_drift: Vector3 = to_parent.inverse() * drift

		for k in anim.track_get_key_count(t):
			var f: float = (anim.track_get_key_time(t, k) - anim.track_get_key_time(t, 0)) / span
			anim.track_set_key_value(t, k, (anim.track_get_key_value(t, k) as Vector3) - local_drift * f)

		mps = maxf(mps, drift.length() / span)

	if mps >= 0.3:      # a start clip drifts a few centimetres: too little to set the playing speed by (the mink's sprint start)
		anim.set_meta("travel_mps", mps)
		_model_note(kind, "clip %s travels %.1f m/s by itself: travel taken out (the server moves the animal), played at speed / %.1f" % [anim_name, mps, mps])


# A flock drawn from a model (ducks, Dave 7 Nov 2026: all the animals we have models for): one wire record is a whole flock, so
# the row's "flock_of" [min, max] birds are built from the model, spread over "spread_m" round the record, each turned its own
# way and set "sink_m" into the surface (a swimming bird sits low in the water). Every bird plays the record's state (_animate_model).
func _make_model_flock(number: int, id: int, row: Dictionary) -> Node3D:
	var span: Array = row["flock_of"]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = id * 7919
	var count: int = int(span[0]) + id % maxi(1, int(span[1]) - int(span[0]) + 1)
	var spread: float = float(row.get("spread_m", 3.0))
	var root: Node3D = Node3D.new()
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var birds: Array = []

	for k in count:
		var bird: Node3D = _make_model(number, id * 31 + k)

		if bird == null:
			root.free()
			return null      # no model file: the code flock is drawn

		bird.position = Vector3(rng.randf_range(-spread, spread), -_flock_sink(bird, row), rng.randf_range(-spread, spread))
		bird.rotation.y = rng.randf_range(-0.6, 0.6)
		rig.add_child(bird)
		birds.append(bird)

	root.set_meta("model", true)
	root.set_meta("flock_birds", birds)
	return root


# A looping copy of a clip's window [t0, t1], resampled 30 times a second, with the last `blend` seconds eased back to the
# window's first pose so the end meets the start (clip_loop above). Position, rotation and scale tracks only.
func _loop_copy(src: Animation, t0: float, t1: float, blend: float) -> Animation:
	var out: Animation = Animation.new()
	out.length = t1 - t0
	out.loop_mode = Animation.LOOP_LINEAR
	var step: float = 1.0 / 30.0

	for t in src.get_track_count():
		var kind: int = src.track_get_type(t)

		if kind != Animation.TYPE_POSITION_3D and kind != Animation.TYPE_ROTATION_3D and kind != Animation.TYPE_SCALE_3D:
			continue

		var nt: int = out.add_track(kind)
		out.track_set_path(nt, src.track_get_path(t))
		var first: Variant = _track_at(src, t, kind, t0)
		var time: float = t0

		while true:
			var v: Variant = _track_at(src, t, kind, time)
			var w: float = clampf((time - (t1 - blend)) / maxf(blend, 0.001), 0.0, 1.0)
			w = w * w * (3.0 - 2.0 * w)

			if kind == Animation.TYPE_ROTATION_3D:
				v = (v as Quaternion).slerp(first as Quaternion, w)
			else:
				v = (v as Vector3).lerp(first as Vector3, w)

			out.track_insert_key(nt, time - t0, v)

			if time >= t1:
				break

			time = minf(time + step, t1)

	return out


func _track_at(anim: Animation, t: int, kind: int, time: float) -> Variant:
	if kind == Animation.TYPE_ROTATION_3D:
		return anim.rotation_track_interpolate(t, time)
	if kind == Animation.TYPE_POSITION_3D:
		return anim.position_track_interpolate(t, time)
	return anim.scale_track_interpolate(t, time)


# Eye shine (docs/design/EYE_SHINE_AND_WET.md, Kathleen's art_animals.md section 6): only the player's own held light makes eyes
# shine, and only eyes that face it. Strength = the row's shine x the torch light reaching the eye (fading to nothing at twice the
# torch's range) x a cone on the angle between where the animal looks and the line to the camera (gone past 30 degrees). It is an
# emission on the eye surface only: no light is cast, and terrain or fur in front hides it like any surface. Animals drop out of the
# rows when they die, and a carcass is built without these materials, so a dead animal never shines.
func _eye_shine(node: Node3D) -> void:
	var mats: Array = node.get_meta("eye_mats")
	var energy: float = 0.0
	var light: Array = _torch() if torch_light.is_valid() else []
	var cam: Camera3D = _cam()

	if light.size() >= 2 and cam != null:
		var row: Dictionary = node.get_meta("model_row", {})
		var eye: Vector3 = node.global_position + Vector3.UP * float(row.get("length_m", 1.0)) * 0.35
		var reach: float = float(light[1]) * 2.0
		var near: float = clampf(1.0 - (light[0] as Vector3).distance_to(eye) / maxf(reach, 0.01), 0.0, 1.0)
		var facing: Vector3 = -node.global_transform.basis.z.normalized()      # the model faces -Z
		var to_cam: Vector3 = (cam.global_position - eye).normalized()
		var cone: float = smoothstep(cos(deg_to_rad(30.0)), 1.0, facing.dot(to_cam))
		energy = float(row.get("shine", 0.0)) * near * near * cone * 2.0

	for mat in mats:
		(mat as StandardMaterial3D).emission_energy_multiplier = energy


# How fast a clip's feet move over the ground while they touch it (docs/design/FOOT_SLIDING.md, MikeW 8 Nov 2026). In an in-place
# walk the body stays put and a planted foot slides backward at exactly the speed the animal should travel, so: sample the bones 40
# times over the clip in the rig's space (metres, the model's size scale is in it), take the lowest point the clip reaches as the
# ground, call a bone planted while it is within 3% of the standing height of that ground, and return the middle horizontal speed
# of planted bones between neighbouring samples. 0 when nothing is planted long enough to tell.
func _measure_stride(player: AnimationPlayer, anim: Animation, rig: Node3D) -> float:
	if anim.length <= 0.0:
		return 0.0

	var samples: int = 40
	var frames: Array = []
	var low: float = INF
	var high: float = -INF

	for i in samples + 1:
		var bones: PackedVector3Array = _clip_bones(player, anim, rig, anim.length * float(i) / float(samples))
		frames.append(bones)

		for p in bones:
			low = minf(low, p.y)
			high = maxf(high, p.y)

	if frames.is_empty() or high <= low:
		return 0.0

	var near_ground: float = low + (high - low) * 0.03
	var dt: float = anim.length / float(samples)
	var speeds: Array = []

	for i in samples:
		var a: PackedVector3Array = frames[i]
		var b: PackedVector3Array = frames[i + 1]

		for bone in a.size():
			if a[bone].y <= near_ground and b[bone].y <= near_ground:
				speeds.append(Vector2(b[bone].x - a[bone].x, b[bone].z - a[bone].z).length() / dt)

	if speeds.size() < 4:
		return 0.0

	speeds.sort()
	return float(speeds[int(speeds.size() / 2.0)])


# How far a bird of a model flock sits into the surface: "sink_share" of its height in its graze clip (its swim pose: the legs
# paddle below the body, and about a third of the body rides under the water line), else the fixed "sink_m".
func _flock_sink(bird: Node3D, row: Dictionary) -> float:
	if not row.has("sink_share") or not bird.has_meta("player"):
		return float(row.get("sink_m", 0.0))

	var player: AnimationPlayer = bird.get_meta("player")
	var clip: String = str((player.get_meta("roles", {}) as Dictionary).get("0", ""))
	var rig: Node3D = bird.get_node_or_null("Rig")

	if clip == "" or rig == null:
		return float(row.get("sink_m", 0.0))

	var tall: float = _clip_box(player, player.get_animation(clip), rig).size.y      # in the rig's space: the model's size scale is in it
	return tall * float(row["sink_share"])


# A hand-made walk or run cycle from a model's own bones (MikeW, 8 Nov 2026: the mink's file has no looping walk; this is the
# fallback if its loop window looks jerky in the game). spec: period_s, and "bones" {bone: [phase 0..1, swing degrees, axis "x"/"y"/"z"]}:
# each bone turns about its own axis by swing * sin(2 pi (t / period + phase)) over its rest. A four-beat walk puts the legs at
# phases 0, 0.25, 0.5, 0.75 (left hind, left fore, right hind, right fore); spine, tail and head bones sway at small swings.
func _gait_clip(player: AnimationPlayer, rig: Node3D, spec: Dictionary, kind: String) -> Animation:
	var skeletons: Array = rig.find_children("*", "Skeleton3D", true, false)
	var base: Node = player.get_node_or_null(player.root_node)

	if skeletons.is_empty() or base == null:
		return null

	var sk: Skeleton3D = skeletons[0]
	var period: float = float(spec.get("period_s", 0.5))
	var out: Animation = Animation.new()
	out.length = period
	out.loop_mode = Animation.LOOP_LINEAR
	var sk_path: String = str(base.get_path_to(sk))
	var steps: int = 16
	var missing: PackedStringArray = PackedStringArray()

	for bone_name in (spec.get("bones", {}) as Dictionary):
		var bone: int = sk.find_bone(str(bone_name))

		if bone < 0:
			missing.append(str(bone_name))
			continue

		var b: Array = spec["bones"][bone_name]
		var axis: Vector3 = {"x": Vector3.RIGHT, "y": Vector3.UP, "z": Vector3.BACK}.get(str(b[2]) if b.size() > 2 else "x", Vector3.RIGHT)
		var rest: Quaternion = sk.get_bone_rest(bone).basis.get_rotation_quaternion()
		var t: int = out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(t, NodePath("%s:%s" % [sk_path, str(bone_name)]))

		for i in steps + 1:
			var time: float = period * float(i) / float(steps)
			var angle: float = deg_to_rad(float(b[1])) * sin(TAU * (time / period + float(b[0])))
			out.track_insert_key(t, time, rest * Quaternion(axis, angle))

	if not missing.is_empty():
		_model_note(kind, "gait: no bone %s" % ", ".join(missing))

	return out


# Two glossy eye spheres fixed to the skeleton (see _make_model). `size_k` is the model's size scale (file units to metres), so
# eye_offset and eye_radius_m are in metres at the drawn size. Returns their materials for the eye shine.
func _add_eyes(inst: Node, row: Dictionary, size_k: float, kind: String) -> Array:
	var sks: Array = inst.find_children("*", "Skeleton3D", true, false)

	if sks.is_empty():
		return []

	var sk: Skeleton3D = sks[0]
	var parent: Node = inst.get_parent()
	size_k = _to_ancestor(sk, parent).basis.get_scale().x if parent != null else size_k      # skeleton units to metres (file scale, armature scale, the model's size)
	var mats: Array = []
	var radius: float = float(row.get("eye_radius_m", float(row.get("length_m", 1.0)) * 0.012))
	var places: Array = []      # [bone name, offset Vector3 in metres]

	if row.has("eye_bones"):
		for bone_name in row["eye_bones"]:
			places.append([str(bone_name), Vector3.ZERO])
	else:
		var off: Array = row["eye_offset"]
		var head: String = str(row.get("head_bone", "Head"))
		places.append([head, Vector3(float(off[0]), float(off[1]), float(off[2]))])
		places.append([head, Vector3(-float(off[0]), float(off[1]), float(off[2]))])

	for place in places:
		if sk.find_bone(str(place[0])) < 0:
			_model_note(kind, "eyes: no bone %s" % str(place[0]))
			continue

		var at: BoneAttachment3D = BoneAttachment3D.new()
		at.bone_name = str(place[0])
		sk.add_child(at)
		var eye: MeshInstance3D = MeshInstance3D.new()
		var ball: SphereMesh = SphereMesh.new()
		ball.radius = radius / maxf(size_k, 0.0001)      # in the skeleton's units
		ball.height = ball.radius * 2.0
		ball.radial_segments = 12
		ball.rings = 6
		eye.mesh = ball
		eye.position = (place[1] as Vector3) / maxf(size_k, 0.0001)
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color.html(str(row.get("eye_color", "#1c140e")))
		mat.roughness = 0.08
		mat.metallic_specular = 0.8

		if float(row.get("shine", 0.0)) > 0.0:
			mat.emission_enabled = true
			mat.emission = Color.html(str(row.get("shine_color", "#ffffff")))
			mat.emission_energy_multiplier = 0.0

		eye.material_override = mat
		at.add_child(eye)
		mats.append(mat)

		# The far-off glint (EYE_SHINE.md): a small additive point the same size on screen at any distance, so two eyes read in the
		# dark well beyond where the body can be seen. Only with eye_shine, and only for species that shine.
		if eye_shine and float(row.get("shine", 0.0)) > 0.0:
			var dot: MeshInstance3D = MeshInstance3D.new()
			var quad: QuadMesh = QuadMesh.new()
			quad.size = Vector2(0.006, 0.006)
			dot.mesh = quad
			var glow: StandardMaterial3D = StandardMaterial3D.new()
			glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			glow.fixed_size = true
			glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glow.albedo_color = Color.html(str(row.get("shine_color", "#ffffff")))
			glow.albedo_color.a = 0.0
			dot.material_override = glow
			dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			dot.visible = false
			eye.add_child(dot)
			dot.set_meta("glow", glow)
			var dots: Array = inst.get_meta("eye_dots", [])
			dots.append(dot)
			inst.set_meta("eye_dots", dots)

	_model_note(kind, "eyes: %d placed" % mats.size())
	return mats


# How much a tail moves (docs/design/TAIL_MOTION.md): the row's tail_motion "when" says in which states and seasons; resting
# states swing fully, moving ones a little, a flick only when alert. Eased so it starts and stops softly.
func _tail_motion(node: Node3D, state: int, speed: float) -> void:
	var row: Dictionary = node.get_meta("model_row", {})
	var spec: Dictionary = row.get("tail_motion", {})
	var when: String = str(spec.get("when", "rest"))
	var want: float = 0.0

	match when:
		"rest":      # a dog's wag: standing, sitting or lying by its owner
			want = 1.0 if (state == 0 or state == 12 or state == 18 or state == 19) and speed < 0.3 else 0.2
		"alert":     # a cat's flick: when it watches something
			want = 1.0 if state == 3 or state == 6 else 0.15
		"flies":     # a horse's or cow's swish against flies: grazing in the warm months
			var season: String = str((_cond() as Dictionary).get("season", "")) if conditions_now.is_valid() else season_now
			want = (1.0 if speed < 0.3 else 0.3) * (1.0 if season == "" or season == "summer" or season == "spring" else 0.0)

			if conditions_now.is_valid() and float((_cond() as Dictionary).get("storm_ahead", 0.0)) > 0.5:
				want = 0.0      # the flies go to ground before a storm (Steve's #646 storm_ahead), so no swish

	if state == HUNCH:
		want = 0.0      # hunched against the weather: the tail clamped down

	if stalk_fx and _stalking(node, state):
		want = 0.0      # a stalker's tail is low and still

	want = maxf(want, _wind() - 0.4)      # gusts above about 0.5 swing every tail a little (Jamie's #637)
	var fix = node.get_meta("tail")      # bone_offsets.gd (untyped: its own property)
	fix.wave_scale = lerpf(float(fix.wave_scale), want, 0.05)


# Ears (docs/design/EAR_AND_BREATH.md): they turn toward the player when the player is within 20 m (the nearest sound the client
# knows of: the camera), harder when the animal is alert, and lie back flat when it warns or charges. Eased so they move like ears.
func _ear_motion(node: Node3D, state: int) -> void:
	var fix = node.get_meta("ears")      # bone_offsets.gd (untyped: its own properties)
	var cam: Camera3D = _cam()
	var turn: float = 0.0

	if cam != null:
		var to: Vector3 = cam.global_position - node.global_position
		to.y = 0.0

		if to.length() < 20.0 and to.length() > 0.01:
			var frame: Basis = node.global_transform.basis      # not "basis": that is Node3D's own
			var side: float = (-frame.x.normalized()).dot(to.normalized())      # the model faces -Z, so its left is -X
			turn = clampf(side * (1.5 if state == 3 else 1.0), -1.0, 1.0)

	var flat: float = 1.0 if state == 10 or state == 11 or state == 16 or (stalk_fx and state == 7) else 0.7 if state == HUNCH else clampf((_wind() - 0.5) * 0.8, 0.0, 0.4)      # threat flat; a strong wind lays them back a little
	fix.ear_turn = lerpf(float(fix.ear_turn), turn, 0.08)
	fix.ear_flat = lerpf(float(fix.ear_flat), flat, 0.15)


# Breathing (docs/design/EAR_AND_BREATH.md section 2): at rest the chest swells at the row's rate; for 20 s after a flee or charge it
# breathes twice as fast and deep, settling back; while moving fast the gait hides it.
func _breath_motion(node: Node3D, b: Dictionary, state: int, speed: float, delta: float) -> void:
	var fix = node.get_meta("breath")      # bone_offsets.gd (untyped: its own properties)

	if state == FLEE or state == 11 or speed > 3.0:
		b["puffed"] = 20.0

	b["puffed"] = maxf(0.0, float(b.get("puffed", 0.0)) - delta)
	fix.breath_rate = (1.0 + float(b["puffed"]) / 20.0) * (0.5 if bool(b.get("asleep", false)) else 1.0)      # asleep: half the rate
	fix.breath_on = lerpf(float(fix.breath_on), 1.0 if speed < 1.0 else 0.0, 0.1)


# Head tracking (docs/design/HEAD_TRACKING.md). "glance" (grazers): grazing, a player within range_m makes the animal look for 2 to
# 4 s, again for every 5 m closer. "track" (predators): alert, stalking or warning, it keeps looking. The clip plays underneath.
func _look_motion(node: Node3D, b: Dictionary, state: int, delta: float) -> void:
	var fix = node.get_meta("look")      # bone_offsets.gd (untyped: its own properties)
	var spec: Dictionary = _row_of(node).get("look", {})
	var cam: Camera3D = _cam()
	var want: float = 0.0

	if cam != null:
		var dist: float = cam.global_position.distance_to(node.global_position)
		var range_m: float = float(spec.get("range_m", 30.0))
		fix.look_target = cam.global_position

		if str(spec.get("mode", "glance")) == "track":
			want = 1.0 if (state == 3 or state == 6 or state == 10) and dist < range_m * 1.5 else 0.0
		elif state == 0 and dist < range_m:
			if dist < float(b.get("next_glance_m", range_m)):
				var hold: Array = spec.get("hold_s", [2.0, 4.0])
				b["look_left"] = randf_range(float(hold[0]), float(hold[1]))      # luck-exempt: how long a deer stares (client look)
				b["next_glance_m"] = dist - 5.0
				_herd_glance(node, b)

			want = 1.0 if float(b.get("look_left", 0.0)) > 0.0 else 0.0
		else:
			b["next_glance_m"] = range_m      # out of range or busy: the next approach starts a fresh glance

	if look_at_foe and b.has("foe") and (state == 10 or state == 11 or state == 12 or state == WARN_POP):
		fix.look_target = (b["foe"] as Vector3) + Vector3(0.0, 0.4, 0.0)      # the dog (or player) it is warning, not the camera
		want = 1.0

	# A herd mate looked up: this one follows a moment later (_herd_glance).
	if float(b.get("glance_at", -1.0)) >= 0.0 and _t >= float(b["glance_at"]):
		b["glance_at"] = -1.0

		if state == 0 and float(b.get("look_left", 0.0)) <= 0.0:
			b["look_left"] = randf_range(1.5, 3.0)      # luck-exempt: how long a herd mate stares (client look)
			want = 1.0

	# A young one with its mother near looks to her now and then, and up at her flank while nursing (_young_follow).
	if young_follow and b.has("mother_at") and want < 0.5 and state == 0:
		fix.look_target = b["mother_at"]
		want = 1.0 if b.has("nurse_left") else (0.7 if float(b.get("mother_look", 0.0)) > 0.0 else 0.0)

	if bool(b.get("asleep", false)):
		want = 0.0      # asleep: no glances (the ears still turn)

	b["look_left"] = maxf(0.0, float(b.get("look_left", 0.0)) - delta)
	fix.look_weight = move_toward(float(fix.look_weight), want, delta / 0.3)


# The body's rise and fall over each bound of a hopping animal (see the hop block in _animate_model): a half sine of arc_m per bound,
# so the feet leave and meet the ground once a bound; settles to the ground when it stops.
func _hop_arc(node: Node3D, b: Dictionary, speed: float, delta: float) -> void:
	var rig: Node3D = LifeUtil.rig(node)

	if rig == null:
		return

	var hop: Variant = b.get("hop", null)

	if hop is Array:
		b["hop_phase"] = float(b.get("hop_phase", 0.0)) + speed * delta / maxf(float(hop[0]), 0.05)
		rig.position.y = float(hop[1]) * sin(PI * fposmod(float(b["hop_phase"]), 1.0))
	elif absf(rig.position.y) > 0.0005:
		rig.position.y = move_toward(rig.position.y, 0.0, delta * 0.5)


# The server's rest rule on the client (server_animals.gd resting): the species' activity for this period of the day at or under
# rest.below. Needs the client clock (conditions_now); without it nobody sleeps.
func _asleep_now(kind: String) -> bool:
	if kind == "" or not conditions_now.is_valid():
		return false

	if _species_cfg == null:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/animals.json"))
		_species_cfg = parsed if parsed is Dictionary else {}

	var cfg: Dictionary = _species_cfg
	var key: String = "songbirds" if kind == "songbird" else kind
	var def: Dictionary = (cfg.get("species", {}) as Dictionary).get(key, {})

	if not def.has("active"):
		return false

	var hour: float = float((_cond() as Dictionary).get("hour", 12.0))
	var period: String = "day" if hour >= 8.0 and hour < 18.0 else ("dusk" if (hour >= 5.0 and hour < 8.0) or (hour >= 18.0 and hour < 21.0) else "night")
	return float((def["active"] as Dictionary).get(period, 1.0)) <= float((cfg.get("rest", {}) as Dictionary).get("below", 0.1))


# Herds on the client (docs/design/HERD_CLIENT.md), from what the server already sends: grazing herd mates (rows with "herd": true)
# within 12 m turn a little toward the herd's mean facing and are drawn at least 2 m apart (a visual nudge of the body inside its
# node, never the position the server sent); one lifting its head makes the others look within 2 s (_herd_glance).
const HERD_M := 12.0
const HERD_SPACE_M := 2.0

func _herd_look(node: Node3D, b: Dictionary, state: int, speed: float, delta: float) -> void:
	var rig: Node3D = LifeUtil.rig(node)

	if rig == null:
		return

	var kind: String = str(b.get("kind", ""))
	var sum: Vector2 = Vector2.ZERO
	var push: Vector3 = Vector3.ZERO
	var mates: int = 0
	b["herd_t"] = float(b.get("herd_t", float(b.get("phase", 0.0)) * 0.03)) - delta
	var fresh: bool = float(b["herd_t"]) <= 0.0      # the mates are looked at 5 times a second (PERF_BUDGET.md worst 2), eased between

	if fresh:
		b["herd_t"] = 0.2

	if fresh and state == 0 and speed < 0.3:
		var space: float = _herd_space()

		for other_id in _bodies:
			var o: Dictionary = _bodies[other_id]

			if o == b or str(o.get("kind", "")) != kind:
				continue

			var on: Node3D = o["node"]
			var gap: Vector3 = node.position - on.position
			gap.y = 0.0
			var d: float = gap.length()

			if d > HERD_M:
				continue

			mates += 1
			sum += Vector2(cos(on.rotation.y), sin(on.rotation.y))

			if d < space and d > 0.01:
				push += gap.normalized() * (space - d) * 0.5

	if fresh:
		b["herd_aim"] = clampf(angle_difference(node.rotation.y, sum.angle()), -0.35, 0.35) if mates > 0 and sum.length() > 0.01 else 0.0      # at most 20 degrees toward the herd's facing
		b["herd_push"] = push

	var bias: float = float(b.get("herd_aim", 0.0))
	push = b.get("herd_push", Vector3.ZERO)

	b["herd_bias"] = lerpf(float(b.get("herd_bias", 0.0)), bias, clampf(delta * 0.5, 0.0, 1.0))
	rig.rotation.y = float(b["herd_bias"]) + float(b.get("wind_turn", 0.0))      # on the rig, not the node: the node's facing follows the server every frame (plus the gale turn, weather_looks)
	if b.has("nurse_left"):
		return      # a young one nursing is under its mother's flank (_young_follow), not pushed apart

	var want: Vector3 = node.global_transform.basis.inverse() * push.limit_length(1.0)
	rig.position.x = lerpf(rig.position.x, want.x, clampf(delta, 0.0, 1.0))
	rig.position.z = lerpf(rig.position.z, want.z, clampf(delta, 0.0, 1.0))


# One herd member looked up: grazing mates of its kind within HERD_M follow 0.3 to 2 s later.
func _herd_glance(node: Node3D, b: Dictionary) -> void:
	if not bool(_row_of(node).get("herd", false)):
		return

	for other_id in _bodies:
		var o: Dictionary = _bodies[other_id]

		if o == b or str(o.get("kind", "")) != str(b.get("kind", "")) or float(o.get("look_left", 0.0)) > 0.0:
			continue

		if (o["node"] as Node3D).position.distance_to(node.position) <= HERD_M and float(o.get("glance_at", -1.0)) < 0.0:
			o["glance_at"] = _t + randf_range(0.3, 2.0)      # luck-exempt: when a herd mate looks up (client look)


# What a foot lands on (docs/design/FOOTFALL.md): water where the client's water level is above the animal's feet, snow in winter,
# mud while the animal is wet or just out of water, dust otherwise. The flora's ground kinds can refine this later.
func _ground_kind(node: Node3D, b: Dictionary) -> String:
	if water_level.is_valid():
		var level: float = float(water_level.call(node.global_position.x, node.global_position.z))

		if not is_nan(level) and node.global_position.y < level:
			return "water"

	# Rain-soaked ground (the sound stage's puddle rule: ground_wet from 0.6) splashes like the player's steps do.
	if conditions_now.is_valid() and float((_cond() as Dictionary).get("ground_wet", 0.0)) >= 0.6:
		return "puddle"

	var season: String = str((_cond() as Dictionary).get("season", "")) if conditions_now.is_valid() else season_now

	if season == "winter":
		return "snow"

	if float(b.get("wet", 0.0)) > 0.3:
		return "mud"

	return "dust"


# A small one-shot puff where a running foot lands: brown dust, dark mud flecks, or white snow. Short-lived, a few particles.
func _puff(at: Vector3, ground: String, speed: float) -> void:
	if not is_inside_tree():
		return

	var puff: CPUParticles3D = CPUParticles3D.new()
	puff.one_shot = true
	puff.emitting = false
	puff.amount = 6 if speed < 6.0 else 10
	puff.lifetime = 0.6 if ground != "snow" else 0.9
	puff.explosiveness = 1.0
	puff.direction = Vector3.UP
	puff.spread = 70.0
	puff.initial_velocity_min = 0.4
	puff.initial_velocity_max = 1.2
	puff.gravity = Vector3(0.0, -2.0, 0.0)
	puff.scale_amount_min = 0.05
	puff.scale_amount_max = 0.12
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(0.12, 0.12)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = {"dust": Color(0.55, 0.47, 0.36, 0.5), "mud": Color(0.25, 0.19, 0.12, 0.7), "snow": Color(0.95, 0.96, 1.0, 0.7)}.get(ground, Color(0.55, 0.47, 0.36, 0.5))
	mesh.material = mat
	puff.mesh = mesh
	LifeUtil.fire_once(self, puff, at + Vector3(0.0, 0.05, 0.0), 0.3)


# Slope planting, simple form (docs/design/FOOTFALL.md): the body pitches with the ground it walks on, learnt from its own movement
# (the server puts it on the ground, so its rise over its run is the slope), held while it stands, at most 20 degrees. Feet stay
# on the ground at both ends of a long body; full foot IK is the later step.
func _slope_pitch(node: Node3D, b: Dictionary, before: Vector3, delta: float) -> void:
	var rig: Node3D = LifeUtil.rig(node)

	if rig == null:
		return

	var run: float = Vector2(node.position.x - before.x, node.position.z - before.z).length()

	if run > 0.02:
		b["slope"] = lerpf(float(b.get("slope", 0.0)), clampf((node.position.y - before.y) / run, -0.36, 0.36), clampf(delta * 3.0, 0.0, 1.0))

	rig.rotation.x = lerp_angle(rig.rotation.x, atan(float(b.get("slope", 0.0))), clampf(delta * 4.0, 0.0, 1.0))      # nose up going uphill (the model faces -Z)


# Footprints in snow and mud (docs/design/FOOTFALL.md step 5): a small decal where a foot lands, its shape from the species' sign
# group in animal_sign.json (two cloven ovals for hoofed, a pad and four toes for pawed, the same with claw points for clawed, three
# thin toes for birds), turned to the heading, fading over 10 minutes in mud and 20 in snow. At most 200 near the player; the
# oldest go first. These are the prints the tracking skill reads in its hints.
const PRINT_CAP := 200

func _print_at(kind: String, node: Node3D, ground: String) -> void:
	if not is_inside_tree():
		return

	var group: String = _print_group(kind)
	var tex: ImageTexture = _print_texture(group)
	var decal: Decal = Decal.new()
	decal.texture_albedo = tex
	var big: float = clampf(float(_row_of(node).get("length_m", 1.0)) * 0.08, 0.04, 0.35)
	decal.size = Vector3(big, 0.3, big)
	decal.modulate = Color(0.35, 0.28, 0.2, 0.85) if ground == "mud" else Color(0.75, 0.8, 0.9, 0.8)
	add_child(decal)
	decal.global_position = node.global_position + Vector3(0.0, 0.1, 0.0)
	decal.rotation.y = node.rotation.y
	_prints.append([decal, Time.get_ticks_msec(), 600.0 if ground == "mud" else 1200.0])

	while _prints.size() > PRINT_CAP:
		(_prints.pop_front()[0] as Decal).queue_free()


func _fade_prints() -> void:
	var now: int = Time.get_ticks_msec()

	for i in range(_prints.size() - 1, -1, -1):
		var p: Array = _prints[i]
		var age: float = float(now - int(p[1])) / 1000.0

		if age >= float(p[2]):
			(p[0] as Decal).queue_free()
			_prints.remove_at(i)
		else:
			var decal: Decal = p[0]
			decal.modulate.a = 0.85 * (1.0 - age / float(p[2]))


func _print_group(kind: String) -> String:
	if _sign_group == null:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/animal_sign.json"))
		var out: Dictionary = {}

		if parsed is Dictionary:
			for k in ((parsed as Dictionary).get("species", {}) as Dictionary):
				out[k] = str(parsed["species"][k].get("group", "hoofed"))

		_sign_group = out

	return str((_sign_group as Dictionary).get("songbirds" if kind == "songbird" else kind, "hoofed"))


# A 64 px print drawn once per group: white shapes on clear, the decal's modulate gives the ground's colour.
func _print_texture(group: String) -> ImageTexture:
	if _print_tex.has(group):
		return _print_tex[group]

	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var blobs: Array = []      # [centre Vector2, radius x, radius y]

	match group:
		"hoofed":
			blobs = [[Vector2(24, 32), 7.0, 15.0], [Vector2(40, 32), 7.0, 15.0]]
		"pawed", "clawed":
			blobs = [[Vector2(32, 40), 11.0, 9.0], [Vector2(20, 24), 4.0, 5.0], [Vector2(28, 19), 4.0, 5.0], [Vector2(36, 19), 4.0, 5.0], [Vector2(44, 24), 4.0, 5.0]]

			if group == "clawed":
				blobs += [[Vector2(20, 16), 1.5, 2.5], [Vector2(28, 11), 1.5, 2.5], [Vector2(36, 11), 1.5, 2.5], [Vector2(44, 16), 1.5, 2.5]]
		_:
			blobs = [[Vector2(32, 34), 1.8, 14.0], [Vector2(24, 26), 1.8, 10.0], [Vector2(40, 26), 1.8, 10.0], [Vector2(32, 46), 1.8, 6.0]]

	for y in 64:
		for x in 64:
			for blob in blobs:
				var c: Vector2 = blob[0]
				var dx: float = (float(x) - c.x) / float(blob[1])
				var dy: float = (float(y) - c.y) / float(blob[2])

				if dx * dx + dy * dy <= 1.0:
					img.set_pixel(x, y, Color(1, 1, 1, 1))
					break

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_print_tex[group] = tex
	return tex


# Feet on uneven ground (FOOTFALL.md step 4): four times a second, within 25 m of the camera, the ground under each foot is probed
# and compared with the ground under the body (which the server already stands on); each foot reaches up or down by the difference
# (at most 25 cm), eased. Grazers only for now (rows with "feet").
func _feet(node: Node3D, b: Dictionary, delta: float) -> void:
	var fix = node.get_meta("feet")      # bone_offsets.gd (untyped: its own properties)
	var cam: Camera3D = _cam()

	if not ground_height.is_valid() or cam == null or cam.global_position.distance_to(node.global_position) > 25.0:
		for i in fix.leg_drop.size():
			fix.leg_drop[i] = move_toward(fix.leg_drop[i], 0.0, delta * 0.5)
		return

	b["feet_t"] = float(b.get("feet_t", 0.0)) - delta

	if float(b["feet_t"]) <= 0.0:
		b["feet_t"] = 0.25
		var centre: float = float(ground_height.call(node.global_position.x, node.global_position.z))
		if not node.has_meta("feet_sk"):
			var found: Array = node.find_children("*", "Skeleton3D", true, false)
			node.set_meta("feet_sk", found[0] if not found.is_empty() else null)

		var sk: Skeleton3D = node.get_meta("feet_sk") as Skeleton3D

		if sk == null or is_nan(centre):
			return
		var wants: Array = []

		for chain in fix.legs:
			var foot: Vector3 = sk.global_transform * sk.get_bone_global_pose(int(chain[2])).origin
			var under: float = float(ground_height.call(foot.x, foot.z))
			wants.append(clampf(under - centre, -0.25, 0.25) if not is_nan(under) else 0.0)

		b["feet_want"] = wants

	var w: Array = b.get("feet_want", [])

	for i in mini(w.size(), fix.leg_drop.size()):
		fix.leg_drop[i] = lerpf(fix.leg_drop[i], float(w[i]), clampf(delta * 6.0, 0.0, 1.0))


# A splash where a foot lands in water or a puddle (FOOTFALL.md step 6): a few droplets thrown up and out, more and higher at a run
# and in open water. The sound is the sound stage's own step_water slot, played by the client on the footfall signal.
func _splash(at: Vector3, deep: bool, speed: float) -> void:
	if not is_inside_tree():
		return

	var drops: CPUParticles3D = CPUParticles3D.new()
	drops.one_shot = true
	drops.emitting = false
	drops.amount = (8 if deep else 4) + int(minf(speed, 8.0))
	drops.lifetime = 0.5
	drops.explosiveness = 1.0
	drops.direction = Vector3.UP
	drops.spread = 55.0
	drops.initial_velocity_min = 0.6
	drops.initial_velocity_max = 1.4 + speed * 0.15
	drops.gravity = Vector3(0.0, -9.8, 0.0)
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.015
	mesh.height = 0.03
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.82, 0.9, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	mesh.material = mat
	drops.mesh = mesh
	LifeUtil.fire_once(self, drops, at + Vector3(0.0, 0.05, 0.0), 0.3)


# Whether this animal is in one of its row's stalk states (wolves 6, the thief's sneak 13).
func _stalking(node: Node3D, state: int) -> bool:
	var row: Dictionary = node.get_meta("model_row", {})
	return row.has("stalk") and (row["stalk"].get("states", []) as Array).has(state)


# A grazer within 25 m with its head up toward the player: the stalker freezes (STALK_POUNCE.md step 3).
func _prey_looking(node: Node3D) -> bool:
	for id in _bodies:
		var o: Dictionary = _bodies[id]

		if float(o.get("look_left", 0.0)) > 0.0 and (o["node"] as Node3D).position.distance_to(node.position) < 25.0:
			return true

	return false


# The pounce arc: a 0.2 s crouch back, then a leap of the row's arc_m height over 0.5 s, then down.
func _pounce(node: Node3D, b: Dictionary, delta: float) -> void:
	var rig: Node3D = LifeUtil.rig(node)
	var spec: Dictionary = _row_of(node).get("pounce", {})
	b["pounce_t"] = float(b["pounce_t"]) + delta
	var t: float = float(b["pounce_t"])

	if rig == null or t > 0.7:
		b["pounce_t"] = -1.0
		return

	if t < 0.2:
		rig.position.y = -0.08 * sin(PI * t / 0.2)
	else:
		rig.position.y = float(spec.get("arc_m", 0.6)) * sin(PI * (t - 0.2) / 0.5)


func _wind() -> float:
	_refresh_frame()
	return _f_wind


# The small up-and-down of a small bird's body with each wingbeat (row flight.bob_m, at beat_hz), only while flapping in the air.
func _flap_bob(node: Node3D, b: Dictionary, state: int) -> void:
	var flight: Dictionary = (node.get_meta("model_row", {}) as Dictionary).get("flight", {})      # the node's own row: a model flock's node has none, so the flock itself does not bob

	if flight.is_empty() or float(flight.get("bob_m", 0.0)) <= 0.0:
		return

	var rig: Node3D = LifeUtil.rig(node)

	if rig == null:
		return

	if state in AIR_STATES:
		rig.position.y = float(flight["bob_m"]) * sin(TAU * float(flight.get("beat_hz", 4.0)) * float(b.get("air_t", _t)))
	elif absf(rig.position.y) > 0.0005 and b.get("hop") == null and float(b.get("pounce_t", -1.0)) < 0.0:      # not while hopping or pouncing
		rig.position.y = 0.0


# The coat (COAT_SHADER.md): season tint x dust, and the wind ruffle's strength, set once a second on the coat materials.
# Season (section 3): the row's season_tint {spring, summer, autumn, winter: colour} multiplies the coat textures, eased 30 percent a
# check (a real moult takes weeks; the client's season is the moult's middle).
# Dust (section 4): builds while the animal rolls (state 8, or the row's roll_states) over about 2 s, takes the ground's colour, fades
# over 3 minutes, and is washed off at once in water or in rain (ground_wet 0.6). The coat leans toward the dust colour by
# dust x 0.35 and is 0.1 rougher.
# Ruffle (section 1): the shader's amp = ruffle_cm x wind^1.3, alpha cards (ruffs, manes) full, the body at a third.
# Eyes are not in coat_mats and keep their own colour.
const DUST_COLOURS := {"dust": Color(0.62, 0.54, 0.42), "mud": Color(0.32, 0.25, 0.17), "snow": Color(1.0, 1.0, 1.0), "grass": Color(0.6, 0.55, 0.42)}

func _coat_tick(node: Node3D, b: Dictionary, state: int, delta: float) -> void:
	var row: Dictionary = node.get_meta("model_row", {})

	if coat_dust and (row.get("roll_states", [8]) as Array).has(state):
		b["dust"] = minf(1.0, float(b.get("dust", 0.0)) + delta * 0.5)

		if not b.has("dust_col"):
			var ground: String = _ground_kind(node, b)
			b["dust_col"] = DUST_COLOURS.get(ground, DUST_COLOURS["dust"])

	b["coat_t"] = float(b.get("coat_t", 0.0)) - delta

	if float(b["coat_t"]) > 0.0 and b.has("coat_now"):
		return

	b["coat_t"] = 1.0
	var tint: Color = Color.WHITE

	if season_coats and row.has("season_tint"):
		var season: String = str((_cond() as Dictionary).get("season", "summer")) if conditions_now.is_valid() else "summer"
		tint = Color.html(str((row["season_tint"] as Dictionary).get(season, "#ffffff")))

	var now: Color = (b.get("coat_now", tint) as Color).lerp(tint, 0.3)
	b["coat_now"] = now
	var dust: float = float(b.get("dust", 0.0))

	if coat_dust and dust > 0.0 and not (row.get("roll_states", [8]) as Array).has(state):
		var ground: String = _ground_kind(node, b)
		dust = 0.0 if ground == "water" or ground == "puddle" else maxf(0.0, dust - 1.0 / 180.0)
		b["dust"] = dust

		if dust <= 0.0:
			b.erase("dust_col")

	var colour: Color = now.lerp(b.get("dust_col", Color.WHITE), dust * 0.35) if coat_dust else now
	var amp: float = float(row.get("ruffle_cm", 0.0)) * 0.01 * pow(clampf(_wind(), 0.0, 1.0), 1.3) if coat_ruffle else 0.0

	for mi in node.get_meta("meshes", []):
		for mat in (mi as MeshInstance3D).get_meta("coat_mats", []):
			var rough: float = float(mat.get_meta("rough", 0.9)) + (0.1 * dust if coat_dust else 0.0)

			if mat is ShaderMaterial:
				(mat as ShaderMaterial).set_shader_parameter("albedo_color", colour)
				(mat as ShaderMaterial).set_shader_parameter("roughness_v", minf(rough, 1.0))
				(mat as ShaderMaterial).set_shader_parameter("amp", amp * (1.0 if bool(mat.get_meta("card", false)) else 0.33))

				if wind_looks:
					var to: float = _wind_to()

					if not is_nan(to):
						(mat as ShaderMaterial).set_shader_parameter("wind_dir", Vector3(cos(to), 0.0, sin(to)))
					(mat as ShaderMaterial).set_shader_parameter("windward_share", 0.6)
			else:
				(mat as StandardMaterial3D).albedo_color = colour
				(mat as StandardMaterial3D).roughness = minf(rough, 1.0)


# The ruffle shader (COAT_SHADER.md section 1): the coat's texture, colour, roughness and alpha cut, with each vertex pushed a little
# along its normal and the wind by a travelling ripple. Two shaders, one per cull mode (fur cards draw both sides).
static var _ruffle_shaders: Dictionary = {}

const RUFFLE_CODE := """shader_type spatial;
render_mode %s;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness_v = 0.9;
uniform float alpha_cut = 0.0;
uniform float amp = 0.0;
uniform vec3 wind_dir = vec3(0.96, 0.0, 0.28);
uniform float windward_share = 0.0;
void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float ripple = sin(dot(wp.xz, vec2(9.1, 6.7)) - TIME * 7.0) * 0.5 + sin(dot(wp.xz, vec2(-4.3, 11.3)) - TIME * 4.3) * 0.5;
	float windward = clamp(dot(-wn, wind_dir), 0.0, 1.0);      // the side the wind meets ruffles most (wind_looks)
	vec3 push = (wn * 0.5 + wind_dir * 0.5) * amp * (0.5 + 0.5 * ripple) * (1.0 - windward_share + windward_share * windward);
	VERTEX += (inverse(MODEL_MATRIX) * vec4(push, 0.0)).xyz;
}
void fragment() {
	vec4 c = texture(albedo_tex, UV) * albedo_color;
	if (c.a < alpha_cut) {
		discard;
	}
	ALBEDO = c.rgb;
	ROUGHNESS = roughness_v;
}
"""

func _ruffle_material(mat: StandardMaterial3D) -> ShaderMaterial:
	var both: bool = mat.cull_mode == BaseMaterial3D.CULL_DISABLED
	var key: String = "both" if both else "back"

	if not _ruffle_shaders.has(key):
		var shader: Shader = Shader.new()
		shader.code = RUFFLE_CODE % ("cull_disabled" if both else "cull_back")
		_ruffle_shaders[key] = shader

	var out: ShaderMaterial = ShaderMaterial.new()
	out.shader = _ruffle_shaders[key]
	out.set_shader_parameter("albedo_tex", mat.albedo_texture)
	out.set_shader_parameter("roughness_v", mat.roughness)
	out.set_shader_parameter("alpha_cut", mat.alpha_scissor_threshold if mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.0)
	return out

# Young animals (docs/design/YOUNG_ANIMALS.md). The row's young_look {scale, wobble_days} sets how big the young are drawn (default
# YOUNG_SCALE) and how many days they stay unsteady (default 10).
# Size by age (YOUNG_ANIMALS.md part 2): born at young_look.scale, growing on a straight line to grown_scale at grown_days (180), so
# a spring fawn is smaller than the same fawn in late summer. Without grown_scale the young keep their birth size.
func _young_scale(number: int, b: Dictionary = {}) -> float:
	var row: Variant = _models.get(KIND_OF_SPECIES.get(number, ""), null) if _models is Dictionary else null

	if not (row is Dictionary):
		return YOUNG_SCALE

	var look: Dictionary = (row as Dictionary).get("young_look", {})
	var born: float = float(look.get("scale", YOUNG_SCALE))

	if not look.has("grown_scale"):
		return born

	return lerpf(born, float(look["grown_scale"]), clampf(_young_age(b) / float(look.get("grown_days", 180.0)), 0.0, 1.0))


# How old a young one looks, in days. The server keeps no birthdays (animals are not saved), so the client gives each young one a
# steady age from its id: born through spring (0 to 40 days old in spring, 60 and more later in the year), so about a quarter of
# spring's young are under 10 days. When the server sends a real birth day this reads it instead.
func _young_age(b: Dictionary) -> float:
	if young_age_days >= 0.0:
		return young_age_days

	if b.has("age_cache") and _t - float(b.get("age_cache_t", -9.0)) < 1.0:
		return float(b["age_cache"])

	b["age_cache_t"] = _t
	b["age_cache"] = _young_age_now(b)
	return float(b["age_cache"])


func _young_age_now(b: Dictionary) -> float:
	var season: String = str((_cond() as Dictionary).get("season", "summer")) if conditions_now.is_valid() else "summer"
	var base: float = float(int(b.get("age_hash", 0)) % 41)
	return base if season == "spring" else base + 60.0


# A newborn's wobble: under wobble_days old it sways side to side (up to 6 degrees, quicker while walking), fading out day by day. Uses the Rig's roll, which no other model look turns.
func _young_wobble(node: Node3D, b: Dictionary, _state: int, speed: float) -> void:
	var rig: Node3D = LifeUtil.rig(node)

	if rig == null:
		return

	var row: Dictionary = node.get_meta("model_row", {})
	var days: float = float(row.get("young_look", {}).get("wobble_days", 10.0))
	var w: float = clampf(1.0 - _young_age(b) / maxf(days, 0.1), 0.0, 1.0)

	if w <= 0.0:
		if absf(rig.rotation.z) > 0.0005:
			rig.rotation.z = 0.0
		return

	var phase: float = float(b.get("phase", 0.0))
	var rate: float = 6.0 if speed > 0.3 else 1.4
	rig.rotation.z = w * deg_to_rad(6.0) * (0.7 * sin(_t * rate + phase) + 0.3 * sin(_t * rate * 2.7 + phase * 1.9))


# Land animals and water (docs/design/ANIMALS_AND_WATER.md). Probed four times a second: the water depth over the ground the server
# stands the animal on. Wading (below swim depth) changes nothing but the footfall splashes already there. Deeper than
# swim_depth_x (0.7) of its shoulder height, an animal whose row has water_swim floats with its back at the surface (the Rig raised
# so 15 percent of its height shows), plays its walk clip quickly as a paddle and leaves rings behind it. Out on the bank again it
# shakes off: a fast roll that dies away over 0.9 s with a spray of drops (the wet look sheds its wet_shed share then). Grazing with
# water just ahead of its muzzle, it drinks: the graze clip (head down) and a ring on the water every 1.6 s.
# Returns true while swimming (the clip is chosen here).
func _water_body(node: Node3D, b: Dictionary, row: Dictionary, player: AnimationPlayer, state: int, delta: float) -> bool:
	var rig: Node3D = LifeUtil.rig(node)

	if rig == null or not node.is_inside_tree():
		return false

	var size: float = maxf(node.scale.y, 0.05)
	var h: float = float(row.get("height_m", float(row.get("length_m", 1.0)) * 0.55)) * size
	b["water_t"] = float(b.get("water_t", 0.0)) - delta

	if float(b["water_t"]) <= 0.0:
		b["water_t"] = 0.25
		var level: float = float(water_level.call(node.global_position.x, node.global_position.z))
		b["depth"] = level - node.global_position.y if not is_nan(level) else 0.0
		b["drink_at"] = null

		if state == 0 and float(b["depth"]) < 0.1 * h:
			var muzzle: Vector3 = node.global_position - node.global_transform.basis.z.normalized() * float(row.get("length_m", 1.0)) * 0.55 * size
			var ahead: float = float(water_level.call(muzzle.x, muzzle.z))

			if not is_nan(ahead):
				b["drink_at"] = Vector3(muzzle.x, ahead, muzzle.z)

	var depth: float = float(b.get("depth", 0.0))
	var swims: bool = bool(row.get("water_swim", false)) and depth > float(row.get("swim_depth_x", 0.7)) * h

	if swims:
		b["swum"] = true
		rig.position.y = lerpf(rig.position.y, (depth - 0.85 * h) / size, clampf(delta * 4.0, 0.0, 1.0))
		var paddle: String = _clip_full(player, row, str((row.get("clips", {}) as Dictionary).get("walk", "")))

		if paddle != "" and player.current_animation != paddle:
			player.play(paddle, 0.3)

		player.speed_scale = 1.8
		b["ring_t"] = float(b.get("ring_t", 0.0)) - delta

		if float(b["ring_t"]) <= 0.0:
			b["ring_t"] = 0.6
			_ring(Vector3(node.global_position.x, node.global_position.y + depth, node.global_position.z), h * 0.6)

		return true

	if b.has("swum") and depth < 0.15 * h:
		b.erase("swum")
		b["shake_t"] = 0.9
		b["shed"] = true      # the wet look (claude/mikew-wet-look) drops its wet_shed share on this
		_splash(node.global_position + Vector3(0.0, h * 0.6, 0.0), true, 6.0)

	if absf(rig.position.y) > 0.002 and b.get("hop") == null and float(b.get("pounce_t", -1.0)) < 0.0:
		rig.position.y = lerpf(rig.position.y, 0.0, clampf(delta * 3.0, 0.0, 1.0))      # back down as it wades out

	if float(b.get("shake_t", 0.0)) > 0.0:
		b["shake_t"] = float(b["shake_t"]) - delta
		rig.rotation.z = 0.3 * sin(float(b["shake_t"]) * 45.0) * maxf(float(b["shake_t"]), 0.0) / 0.9

		if float(b["shake_t"]) <= 0.0:
			rig.rotation.z = 0.0

	if b.get("drink_at") != null:
		b["ring_t"] = float(b.get("ring_t", 0.0)) - delta

		if float(b["ring_t"]) <= 0.0:
			b["ring_t"] = 1.6
			_ring(b["drink_at"], 0.35 * size + 0.1)

	return false


# A ring on the water that spreads to `wide` metres across and fades over 1.5 s (drinking, a swimmer's wake).
func _ring(at: Vector3, wide: float) -> void:
	if not is_inside_tree():
		return

	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.46
	torus.outer_radius = 0.5
	torus.rings = 24
	torus.ring_segments = 4
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.9, 0.95, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material = mat
	ring.mesh = torus
	add_child(ring)
	ring.global_position = at + Vector3(0.0, 0.01, 0.0)
	ring.scale = Vector3(0.1, 0.02, 0.1)
	var grow: Tween = create_tween()
	grow.set_parallel(true)
	grow.tween_property(ring, "scale", Vector3(wide, 0.02, wide), 1.5)
	grow.tween_property(mat, "albedo_color:a", 0.0, 1.5)
	grow.chain().tween_callback(ring.queue_free)


# Grooming and idle variety (docs/design/IDLE_VARIETY.md). The row's idles is a weighted table: [{clip | pose | act, w, s, after,
# needs}]. A standing animal (graze 0, alert 3, recover 12, still, awake) waits 8 to 25 s, then picks one entry by weight and plays
# it once: a clip from the file to its end; a pose (bone offsets and waves, pose key -10 - i) for s seconds; or an act on the Rig for
# s seconds (shake, look_around, stretch, roll). An entry with after "lie" is played as the animal gets up from sleep; one with
# needs "dry" is skipped in water and on wet ground. Moving or a new state ends it at once. Returns true while a clip plays.
const IDLE_STATES := [0, 3, 12]

func _idle_variety(node: Node3D, b: Dictionary, row: Dictionary, player: AnimationPlayer, state: int, speed: float, delta: float) -> bool:
	var table: Array = row["idles"]
	var asleep: bool = bool(b.get("asleep", false))
	var woke: bool = bool(b.get("idle_woke", false))      # set where the sleep block sees the animal wake
	b.erase("idle_woke")

	if b.has("idle_left") and (speed > 0.3 or not (state in IDLE_STATES) or asleep):
		_idle_end(node, b)

	if not b.has("idle_left"):
		if asleep or speed > 0.3 or not (state in IDLE_STATES):
			b["idle_wait"] = randf_range(8.0, 25.0)      # luck-exempt: when the next idle comes (client look)
			return false

		var pick: int = -1

		if woke:
			for i in table.size():
				if str((table[i] as Dictionary).get("after", "")) == "lie":
					pick = i
					break
		else:
			b["idle_wait"] = float(b.get("idle_wait", idle_first_s if idle_first_s >= 0.0 else randf_range(8.0, 25.0))) - delta      # luck-exempt: the first wait

			if float(b["idle_wait"]) <= 0.0:
				b["idle_wait"] = randf_range(8.0, 25.0)      # luck-exempt: the next wait
				pick = _idle_pick(node, b, table)

		if pick < 0:
			return false

		_idle_start(node, b, row, player, pick)

	if not b.has("idle_left"):
		return false

	b["idle_left"] = float(b["idle_left"]) - delta
	b["idle_t"] = float(b.get("idle_t", 0.0)) + delta

	if b.has("idle_act"):
		_idle_act(node, b, row, delta)

	if float(b["idle_left"]) <= 0.0:
		var was_clip: bool = b.has("idle_clip")
		_idle_end(node, b)
		return was_clip

	return b.has("idle_clip")


func _idle_pick(node: Node3D, b: Dictionary, table: Array) -> int:
	var total: float = 0.0
	var ok: Array = []

	for i in table.size():
		var e: Dictionary = table[i]

		if str(e.get("after", "")) == "lie" and not bool(e.get("also_awake", false)):
			continue

		if str(e.get("needs", "")) == "dry" and (_ground_kind(node, b) in ["water", "puddle"]):
			continue

		ok.append(i)
		total += float(e.get("w", 1.0))

	var roll: float = randf() * total      # luck-exempt: which idle (client look)

	for i in ok:
		roll -= float((table[i] as Dictionary).get("w", 1.0))

		if roll <= 0.0:
			return int(i)

	return -1


func _idle_start(node: Node3D, b: Dictionary, row: Dictionary, player: AnimationPlayer, i: int) -> void:
	var e: Dictionary = row["idles"][i]
	b["idle_t"] = 0.0

	if e.has("clip"):
		var full: String = _clip_full(player, row, str(e["clip"]))

		if full == "":
			_model_note(str(row.get("scene", "")).get_file(), "idle clip %s not in the file" % str(e["clip"]))
			return

		player.play(full, 0.25)
		player.speed_scale = 1.0
		b["idle_clip"] = full
		b["idle_left"] = player.get_animation(full).length
	elif e.has("pose"):
		b["idle_pose"] = -10 - i
		b["idle_left"] = float(e.get("s", 2.0))
	elif e.has("act"):
		b["idle_act"] = str(e["act"])
		b["idle_left"] = float(e.get("s", 1.0))
		b["idle_yaw0"] = (node.get_node("Rig") as Node3D).rotation.y if node.has_node("Rig") else 0.0


func _idle_end(node: Node3D, b: Dictionary) -> void:
	var rig: Node3D = LifeUtil.rig(node)

	if rig != null and b.has("idle_act"):
		rig.rotation.z = 0.0
		rig.rotation.x = 0.0

		if str(b["idle_act"]) == "look_around":
			rig.rotation.y = float(b.get("idle_yaw0", 0.0))

		if str(b["idle_act"]) == "roll":
			rig.position.y = 0.0

	for k in ["idle_left", "idle_clip", "idle_pose", "idle_act", "idle_t", "idle_yaw0"]:
		b.erase(k)


# The Rig acts, for files with no clip for them. t runs 0 to s.
func _idle_act(node: Node3D, b: Dictionary, row: Dictionary, delta: float) -> void:
	var rig: Node3D = LifeUtil.rig(node)

	if rig == null:
		return

	var t: float = float(b["idle_t"])
	var span: float = maxf(t + float(b["idle_left"]), 0.1)
	var arc: float = sin(PI * clampf(t / span, 0.0, 1.0))

	match str(b["idle_act"]):
		"shake":      # a shake from head to tail, dying away
			rig.rotation.z = 0.22 * sin(t * 40.0) * (1.0 - t / span)
		"look_around":      # the whole body turns a little one way, then the other
			rig.rotation.y = float(b.get("idle_yaw0", 0.0)) + 0.35 * sin(TAU * t / span)
		"stretch":      # front low, hindquarters up, held, then back
			rig.rotation.x = 0.12 * arc
		"roll":      # down on its side and back up (horses, dogs); dusts the coat when coat_dust is on
			var h: float = float(row.get("height_m", float(row.get("length_m", 1.0)) * 0.55))
			rig.rotation.z = PI * 0.5 * arc
			rig.position.y = 0.25 * h * arc

			if coat_dust:
				b["dust"] = minf(1.0, float(b.get("dust", 0.0)) + delta * 0.5)

				if not b.has("dust_col"):
					b["dust_col"] = DUST_COLOURS.get(_ground_kind(node, b), DUST_COLOURS["dust"])


# Banking (BIRD_FLIGHT.md part 2): a bird in the air leans into its turn, the bank worked out from how fast its heading turns (the
# server sends no bank), up to 45 degrees, eased; a roll event (the raven's play, Steve's #653) adds a half or full roll over 1 s.
# Uses the Rig's roll, which no other look turns while a bird flies.
func _bank(node: Node3D, b: Dictionary, delta: float) -> void:
	var rig: Node3D = LifeUtil.rig(node)

	if rig == null or delta <= 0.0:
		return

	var heading: float = float(b.get("heading", 0.0))
	var turn: float = angle_difference(float(b.get("bank_heading", heading)), heading) / delta      # radians a second
	b["bank_heading"] = heading
	b["bank"] = lerpf(float(b.get("bank", 0.0)), clampf(turn * 0.6, -PI * 0.25, PI * 0.25), clampf(delta * 3.0, 0.0, 1.0))
	var roll: float = 0.0

	if b.has("roll_t"):
		b["roll_t"] = float(b["roll_t"]) + delta
		var t: float = clampf(float(b["roll_t"]), 0.0, 1.0)
		roll = float(b.get("roll_turns", 1.0)) * TAU * (t * t * (3.0 - 2.0 * t))      # eased in and out

		if float(b["roll_t"]) >= 1.0:
			b.erase("roll_t")
			roll = 0.0

			if b.has("roll_next"):      # the pair's second roll
				b["roll_t"] = 0.0
				b["roll_turns"] = float(b["roll_next"])
				b.erase("roll_next")

	rig.rotation.z = float(b["bank"]) + roll


# Back level once the bird is down.
func _bank_level(node: Node3D, b: Dictionary, delta: float) -> void:
	var rig: Node3D = LifeUtil.rig(node)
	b["bank"] = lerpf(float(b["bank"]), 0.0, clampf(delta * 4.0, 0.0, 1.0))

	if rig != null:
		rig.rotation.z = float(b["bank"])

	if absf(float(b["bank"])) < 0.002:
		b.erase("bank")
		b.erase("bank_heading")


# The server's one-shot roll event for a bird (Steve's #653, ravens at play: about once a minute in ridge lift, often in pairs).
# turns: 0.5 a half roll, 1.0 a full roll. Called by the client's protocol handler when the event arrives (wire format: Steve's
# server_flight step 2); a second event within the first's second queues behind it.
func play_roll(id: int, turns: float = 1.0) -> void:
	if not flight_bank or not _bodies.has(id):
		return

	var b: Dictionary = _bodies[id]

	if b.has("roll_t"):
		b["roll_next"] = turns
		return

	b["roll_t"] = 0.0
	b["roll_turns"] = turns


# Young and their mother on the client (docs/design/YOUNG_ANIMALS.md part 2). The server keeps a young one at its place beside its
# mother (_step_young, follow_m) but sends no link between them, so every 2 s the client takes the nearest grown animal of its kind
# within 8 m as the mother. Grazing beside her (state 0, still, within 3 m): it looks to her for 1.5 to 3 s every 6 to 15 s (look
# bones, where the row has them); every 40 to 120 s it nurses for 6 to 12 s: it moves in under her flank (the Rig, at most 1 m, as the
# herd spacing does) with its head turned up to her belly. Moving or a new state ends it.
const MOTHER_SEARCH_M := 8.0   # the nearest grown animal of its kind within this is taken as the mother
const NURSE_NEAR_M := 3.0      # grazing this close to her: glances and nursing

func _young_follow(node: Node3D, b: Dictionary, state: int, speed: float, delta: float) -> void:
	b["mother_t"] = float(b.get("mother_t", 0.0)) - delta

	if float(b["mother_t"]) <= 0.0:
		b["mother_t"] = 2.0
		b.erase("mother_node")
		var best: float = MOTHER_SEARCH_M

		for other_id in _bodies:
			var o: Dictionary = _bodies[other_id]

			if o == b or bool(o.get("young", false)) or str(o.get("kind", "")) != str(b.get("kind", "")):
				continue

			var d: float = (o["node"] as Node3D).position.distance_to(node.position)

			if d < best:
				best = d
				b["mother_node"] = o["node"]

	var rig: Node3D = LifeUtil.rig(node)
	var mother: Node3D = b.get("mother_node") as Node3D if is_instance_valid(b.get("mother_node")) else null

	if mother == null or rig == null or not node.is_inside_tree():
		b.erase("mother_at")
		b.erase("nurse_left")
		return

	var row: Dictionary = mother.get_meta("model_row", {})
	var h: float = float(row.get("height_m", float(row.get("length_m", 1.0)) * 0.55))
	var calm: bool = state == 0 and speed < 0.3 and mother.global_position.distance_to(node.global_position) < NURSE_NEAR_M
	b["mother_at"] = mother.global_position + Vector3(0.0, h * 0.85, 0.0)      # her head
	b["mother_look"] = maxf(0.0, float(b.get("mother_look", 0.0)) - delta)
	b["mother_glance"] = float(b.get("mother_glance", randf_range(6.0, 15.0))) - delta      # luck-exempt: the first glance (client look)

	if calm and float(b["mother_glance"]) <= 0.0:
		b["mother_glance"] = randf_range(6.0, 15.0)      # luck-exempt: the next glance
		b["mother_look"] = randf_range(1.5, 3.0)      # luck-exempt: how long

	b["nurse_wait"] = float(b.get("nurse_wait", idle_first_s if idle_first_s >= 0.0 else randf_range(40.0, 120.0))) - delta      # luck-exempt: the first nursing (client look)

	if not calm:
		b.erase("nurse_left")
	elif not b.has("nurse_left") and float(b["nurse_wait"]) <= 0.0:
		b["nurse_wait"] = randf_range(40.0, 120.0)      # luck-exempt: the next nursing
		b["nurse_left"] = randf_range(6.0, 12.0)      # luck-exempt: how long

	if b.has("nurse_left"):
		b["nurse_left"] = float(b["nurse_left"]) - delta
		var flank: Vector3 = mother.global_position + mother.global_transform.basis.x.normalized() * h * 0.25
		b["mother_at"] = mother.global_position + Vector3(0.0, h * 0.5, 0.0)      # her belly
		var want: Vector3 = node.global_transform.basis.inverse() * (flank - node.global_position)
		want.y = 0.0
		want = want.limit_length(1.0 / maxf(node.scale.x, 0.1))
		rig.position.x = lerpf(rig.position.x, want.x, clampf(delta, 0.0, 1.0))
		rig.position.z = lerpf(rig.position.z, want.z, clampf(delta, 0.0, 1.0))

		if float(b["nurse_left"]) <= 0.0:
			b.erase("nurse_left")
	elif absf(rig.position.x) + absf(rig.position.z) > 0.01 and not bool(_row_of(node).get("herd", false)):
		rig.position.x = lerpf(rig.position.x, 0.0, clampf(delta, 0.0, 1.0))      # back to its own place (herd rows ease it themselves)
		rig.position.z = lerpf(rig.position.z, 0.0, clampf(delta, 0.0, 1.0))


# The model row of an animal, or of a model flock's first bird (the flock's own node carries none).
func _row_of(node: Node3D) -> Dictionary:
	if node.has_meta("model_row"):
		return node.get_meta("model_row")

	var birds: Array = node.get_meta("flock_birds", [])
	return (birds[0] as Node3D).get_meta("model_row", {}) if not birds.is_empty() else {}

# A bat colony (BAT_RIG.md 3, row "swarm"): in the air every bat wanders round its place in the colony on its own slow loops, so the
# swarm boils instead of moving as a plate; at rest (state 0) with "roost_flip" each hangs head down from the roof point (the bird's
# origin is at its feet, so a half turn about its side puts the body below the feet). Positions are local to the colony's Rig.
func _swarm(node: Node3D, state: int) -> void:
	var row: Dictionary = _row_of(node)
	var spread: float = float(row.get("spread_m", 1.5))
	var flying: bool = state in AIR_STATES
	var k: int = 0

	for bird in node.get_meta("flock_birds"):
		var b3: Node3D = bird
		k += 1

		if not b3.has_meta("swarm_home"):
			b3.set_meta("swarm_home", b3.position)

		var home: Vector3 = b3.get_meta("swarm_home")
		var ph: float = float(k) * 1.618

		if flying:
			b3.position = home + Vector3(sin(_t * 1.7 + ph), 0.5 * sin(_t * 2.3 + ph * 2.0), cos(_t * 1.3 + ph * 3.0)) * spread * 0.8
			b3.rotation.z = 0.0
		else:
			b3.position = home
			b3.rotation.z = PI if bool(row.get("roost_flip", false)) else 0.0


# A whale or dolphin at the surface (SEA_MAMMALS.md, row "sea"): every blow_every_s it blows, a white spout spout_m high, while it is
# within 1.5 m below the water's surface. Breach, dive and leap clips wait for the server's sea events.
func _sea_blow(node: Node3D, b: Dictionary, delta: float) -> void:
	if not water_level.is_valid() or not node.is_inside_tree():
		return

	var sea: Dictionary = _row_of(node)["sea"]
	var span: Array = sea.get("blow_every_s", [20.0, 60.0])
	b["blow_t"] = float(b.get("blow_t", randf_range(2.0, float(span[1])))) - delta      # luck-exempt: when it next blows (client look)

	if float(b["blow_t"]) > 0.0:
		return

	b["blow_t"] = randf_range(float(span[0]), float(span[1]))      # luck-exempt: as above
	var level: float = float(water_level.call(node.global_position.x, node.global_position.z))

	if is_nan(level) or level - node.global_position.y > 1.5:
		return

	var high: float = float(sea.get("spout_m", 3.0))
	var spout: CPUParticles3D = CPUParticles3D.new()
	spout.one_shot = true
	spout.emitting = false
	spout.amount = 40
	spout.lifetime = 1.6
	spout.explosiveness = 0.6
	spout.direction = Vector3.UP
	spout.spread = 8.0
	spout.initial_velocity_min = sqrt(2.0 * 9.8 * high) * 0.8
	spout.initial_velocity_max = sqrt(2.0 * 9.8 * high)
	spout.gravity = Vector3(0.0, -9.8, 0.0)
	spout.scale_amount_min = 0.5
	spout.scale_amount_max = 1.5
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.08 + high * 0.02
	mesh.height = mesh.radius * 2.0
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.95, 1.0, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	spout.mesh = mesh
	LifeUtil.fire_once(self, spout, Vector3(node.global_position.x, level + 0.1, node.global_position.z), 0.5)


# A call by state (docs/design/ANIMAL_VOICES.md): the species' states map in voices.json names a call for the new state; a young one
# fleeing uses its "young" call. One call per animal every cooldown_s, at most per_second calls in all; "silent" plays nothing.
func _voice(b: Dictionary, kind: String, state: int, at: Vector3) -> void:
	if _voices == null:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/voices.json"))
		_voices = parsed if parsed is Dictionary else {}

	var row: Dictionary = ((_voices as Dictionary).get("species", {}) as Dictionary).get(kind, {})

	if row.is_empty():
		return

	var calls: Dictionary = row.get("calls", {})
	var call_name: String = str((row.get("states", {}) as Dictionary).get(str(state), ""))

	if bool(b.get("young", false)) and state == FLEE and calls.has("young"):
		call_name = "young"

	if call_name == "" or call_name == "silent" or not calls.has(call_name):
		return

	var now: int = Time.get_ticks_msec()

	if now < int(b.get("voice_at", 0)):
		return

	_voice_times = _voice_times.filter(func(t): return now - int(t) < 1000)

	if _voice_times.size() >= int((_voices as Dictionary).get("per_second", 6)):
		return

	_voice_times.append(now)
	b["voice_at"] = now + int(float((_voices as Dictionary).get("cooldown_s", 4.0)) * 1000.0)
	voiced.emit(kind, calls[call_name], at)


# Night eye shine (docs/design/EYE_SHINE.md). The tapetum sends light back toward where it came from, so the viewer sees it only when
# the light is close to their own line of sight: a torch in their hand, or the moon behind them. For each light the glow is
#   strength x (1 - angle / 12 degrees) between eye-to-light and eye-to-viewer   (a torch at the viewer is about 1 degree off at 30 m)
#   x facing: the animal's head within 60 degrees of the viewer (full inside 30)
#   x the light: torch by its reach (inverse square), moon by night x moon phase
# and nothing in daylight (night below 0.15). The eye material glows by it, and the far-off dots (_add_eyes) show above 8 m.
const SHINE_FACE_FULL_DEG := 30.0   # the head within this of the viewer: full glow
const SHINE_FACE_OFF_DEG := 60.0    # past this: none
const SHINE_READS_DARK_M := 20.0    # how far the shine reads on a moonless night (Jamie #679)
const SHINE_READS_MOON_M := 5.0     # and under a full moon
const SHINE_MOON_SHARE := 0.1       # the moon's glint against the held torch's (0.25 lux against 3.5 at 1 m)
const SHINE_DOTS_FROM_M := 6.0      # the far-off eye dots fade in from here
const SHINE_DOTS_FULL_M := 10.0     # full from here
const RETRO_DEG := 12.0             # a retroreflector returns nothing past this angle between light and viewer

func _eye_shine_night(node: Node3D) -> void:
	var cam: Camera3D = _cam()
	var row: Dictionary = node.get_meta("model_row", {})
	var energy: float = 0.0
	var sky: Dictionary = _night() if night_light.is_valid() else {}
	var night: float = float(sky.get("night", 1.0 if not night_light.is_valid() else 0.0))

	var night_from: float = 0.15

	if fog_looks and _fog_visibility() < FOG_SHINE_M:
		night_from = 0.05      # in fog the light goes sooner: the shine shows from dusk (ANIMAL_FOG.md)

	if cam != null and night > night_from:
		var eye: Vector3 = node.global_position + Vector3.UP * float(row.get("length_m", 1.0)) * 0.35
		var to_cam: Vector3 = cam.global_position - eye
		var dist: float = to_cam.length()
		to_cam = to_cam.normalized()
		var facing: Vector3 = -node.global_transform.basis.z.normalized()
		var face: float = smoothstep(cos(deg_to_rad(SHINE_FACE_OFF_DEG)), cos(deg_to_rad(SHINE_FACE_FULL_DEG)), facing.dot(to_cam))
		var light: Array = _torch() if torch_light.is_valid() else []
		var lit: float = 0.0

		# How far the shine reads (Jamie's moonlight-and-starlight page, #679): 10 to 20 m on a moonless night, about 5 m under a full
		# moon, where the brighter ground takes the contrast away. A torch gives 3.5 lux at 1 m and 0.035 at 10 m, the full moon 0.25 lux
		# overhead: inside that range the torch's glint is full, the moon's a tenth of it.
		var moon: float = float(sky.get("moon", 0.0))
		var reads_m: float = lerpf(SHINE_READS_DARK_M, SHINE_READS_MOON_M, clampf(moon, 0.0, 1.0))

		if fog_looks:
			reads_m = minf(reads_m, _fog_visibility() / 3.0)      # in fog the shine shows to about a third of the visibility (Jamie's fog page, #716)
		var fade: float = 1.0 - smoothstep(reads_m * 0.75, reads_m * 1.25, dist)

		if light.size() >= 2:
			lit += _retro(((light[0] as Vector3) - eye).normalized(), to_cam)

		if sky.has("moon_to"):
			lit += SHINE_MOON_SHARE * moon * _retro((sky["moon_to"] as Vector3).normalized(), to_cam)

		energy = float(row.get("shine", 0.0)) * minf(lit, 1.0) * face * fade * smoothstep(night_from, night_from + 0.25, night) * 2.0
		var dot_a: float = clampf(energy / 3.0, 0.0, 1.0) * smoothstep(SHINE_DOTS_FROM_M, SHINE_DOTS_FULL_M, dist)

		for dot in node.get_meta("eye_dots", []):
			(dot as MeshInstance3D).visible = dot_a > 0.01
			((dot as MeshInstance3D).get_meta("glow") as StandardMaterial3D).albedo_color.a = dot_a

	for mat in node.get_meta("eye_mats"):
		(mat as StandardMaterial3D).emission_energy_multiplier = energy


# How much a retroreflector returns toward the viewer: full when the light comes from the viewer's direction, nothing past 12 degrees.
func _retro(to_light: Vector3, to_cam: Vector3) -> float:
	var angle: float = rad_to_deg(acos(clampf(to_light.dot(to_cam), -1.0, 1.0)))
	return clampf(1.0 - angle / RETRO_DEG, 0.0, 1.0)


# Animal sign (docs/design/ANIMAL_SIGN.md). One pool of ground decals for tracks, droppings, browse and beds: at most SIGN_CAP, the
# oldest dropped first, and none placed beyond SIGN_NEAR_M of the camera. A track is laid only on soft ground: mud, sand, snow, or
# turf and dirt wet from rain; none on stone, gravel, leaf litter or dry turf. How long each lasts is Jamie's soak numbers in game days
# (a game day is one real hour): wet clay and turf 3 days in summer, 10 in winter (5 between); snow until it melts or new snow falls;
# sand until rain or a strong wind. Walking, prints alternate left and right a stride apart; running, they fall in groups of two
# (front and hind) a longer stride apart, so a tracker can tell the gait.
const SIGN_CAP := 400
const SIGN_NEAR_M := 60.0
const GAME_DAY_S := 3600.0
const SOFT_DRY := ["mud", "sand", "snow"]
const SOFT_WET := ["dirt", "grass", "grass_tall", "path", "bushes"]

func _sign_ground(node: Node3D) -> String:
	var cond: Dictionary = _cond() if conditions_now.is_valid() else {}
	var soil: String = str(soil_at.call(node.global_position)) if soil_at.is_valid() else "dirt"

	if water_level.is_valid():
		var level: float = float(water_level.call(node.global_position.x, node.global_position.z))

		if not is_nan(level) and node.global_position.y < level:
			return ""      # under water: nothing stays

	if float(cond.get("ground_snow", 0.0)) > 0.3 and soil != "stone":
		return "snow"

	if soil in SOFT_DRY:
		return soil

	if soil in SOFT_WET and float(cond.get("ground_wet", 0.0)) >= 0.3:
		return "clay" if soil == "dirt" or soil == "path" else "turf"

	return ""


# How long a print lasts at most (Jamie's tracks page, docs/knowledge/animal-tracks-sign.md, #696): mud and wet clay until the next
# real rain (_fade_signs), ten days at most; bent turf half a day, a heavy animal's hoof holes in soaked turf two and a half days;
# snow until melt, new snow or drifting wind, ten days at most; sand until rain or wind, three days at most.
const HEAVY_KINDS := ["moose", "horse", "donkey", "cow", "buffalo", "elk", "bear", "black_bear", "camel", "elephant", "rhino", "mammoth"]
const GAME_HOUR_S := GAME_DAY_S / 24.0

func _sign_life(ground: String, kind: String = "") -> float:
	match ground:
		"snow":
			return 10.0 * GAME_DAY_S
		"sand":
			return 3.0 * GAME_DAY_S
		"turf":
			return GAME_DAY_S * (2.5 if kind in HEAVY_KINDS else 0.5)
		_:
			return 10.0 * GAME_DAY_S      # mud and clay: the next real rain ends them (_fade_signs)


func _sign_track(kind: String, node: Node3D, b: Dictionary, speed: float) -> void:
	var cam: Camera3D = _cam()

	if cam == null or cam.global_position.distance_to(node.global_position) > SIGN_NEAR_M:
		return

	# Spacing by gait (Jamie's tracks page, #696): a walk lays one print per step (the row's track.walk_m, about half the full stride),
	# a trot 1.45 steps apart in a straighter line, a run a group (four prints, or a rabbit's Y) every track.run_m.
	var row: Dictionary = node.get_meta("model_row", {})
	var track: Dictionary = row.get("track", {})
	var walk_m: float = float(track.get("walk_m", float(row.get("stride_m", 1.0)) * 0.5)) * maxf(node.scale.x, 0.3)
	var run_m: float = float(track.get("run_m", walk_m * 5.0)) * maxf(node.scale.x, 0.3)
	var walk_mps: float = float(row.get("walk_mps", 1.5))
	var running: bool = speed > maxf(walk_mps * 2.4, 3.5)
	var trotting: bool = not running and speed > walk_mps * 1.4
	var gap: float = run_m if running else (walk_m * 1.45 if trotting else walk_m)
	var last: Vector3 = b.get("track_at", Vector3.INF)

	if last != Vector3.INF and last.distance_to(node.global_position) < gap:
		return

	var ground: String = _sign_ground(node)

	if ground == "":
		return

	# The footfall event comes once per stride_m, which is longer than a walking step: lay every print since the last one, at its own
	# spacing along the way the animal went (up to four at once), so a walk shows one print per step.
	var here: Vector3 = node.global_position
	var count: int = 1
	var from: Vector3 = here

	if last != Vector3.INF and last.distance_to(here) < SIGN_NEAR_M:
		count = clampi(int(last.distance_to(here) / maxf(gap, 0.05)), 1, 4)
		from = last

	var step_dir: Vector3 = (here - from).normalized() if count > 1 else Vector3.ZERO

	for n in count:
		var at: Vector3 = from + step_dir * gap * float(n + 1) if count > 1 else here
		_sign_lay(kind, node, b, row, at, running, trotting, ground)

	b["track_at"] = from + step_dir * gap * float(count) if count > 1 else here


# One print, or one gait group of prints, at `at` (_sign_track).
func _sign_lay(kind: String, node: Node3D, b: Dictionary, row: Dictionary, at: Vector3, running: bool, trotting: bool, ground: String) -> void:
	b["track_side"] = -float(b.get("track_side", 1.0))
	var size: float = clampf(float(row.get("length_m", 1.0)) * 0.08, 0.04, 0.35) * maxf(node.scale.x, 0.3)
	var across: Vector3 = node.global_transform.basis.x.normalized()
	var ahead: Vector3 = -node.global_transform.basis.z.normalized()
	var width: float = float(row.get("length_m", 1.0)) * 0.1 * maxf(node.scale.x, 0.3)
	var tex: ImageTexture = _print_texture(_print_group(kind))

	if running and kind == "rabbit":      # the Y: two small front prints one behind the other, the two big hind prints side by side ahead
		_sign_decal(tex, at - ahead * size * 1.6, size * 0.7, node.rotation.y, ground, -1.0, kind)
		_sign_decal(tex, at - ahead * size * 0.6, size * 0.7, node.rotation.y, ground, -1.0, kind)
		_sign_decal(tex, at + across * width * 0.6 + ahead * size * 0.8, size, node.rotation.y, ground, -1.0, kind)
		_sign_decal(tex, at - across * width * 0.6 + ahead * size * 0.8, size, node.rotation.y, ground, -1.0, kind)
	elif running:      # a gallop group of four in a slanting row, then the long gap
		for k in 4:
			var f: float = float(k) - 1.5
			_sign_decal(tex, at + ahead * size * 1.6 * f + across * width * (0.5 if k % 2 == 0 else -0.5), size, node.rotation.y, ground, -1.0, kind)
	else:      # walk or trot: alternating single prints, a trotting fox or wolf almost on one line
		var line: float = 0.25 if trotting and kind in ["fox", "wolf", "dog"] else 1.0
		_sign_decal(tex, at + across * width * line * float(b["track_side"]), size, node.rotation.y, ground, -1.0, kind)


# Droppings, browse and beds (ANIMAL_SIGN.md): a grazer that has fed in one spot for 40 s leaves browse there (nibbled stems), once
# in a while droppings (one in four feeding spots); an animal lying (state 19, or asleep) for 30 s leaves a flattened bed the size of
# its body. Placed only on ground that is not water, near the camera.
func _sign_rest(node: Node3D, b: Dictionary, state: int, speed: float, delta: float) -> void:
	var lying: bool = state == 19 or bool(b.get("asleep", false))
	var feeding: bool = state == 0 and speed < 0.3 and not lying

	if not (lying or feeding):
		b.erase("rest_t")
		return

	b["rest_t"] = float(b.get("rest_t", 0.0)) + delta
	var at: Vector3 = node.global_position
	var spot: Vector3 = b.get("sign_spot", Vector3.INF)

	if spot != Vector3.INF and spot.distance_to(at) < 3.0:
		return      # this spot is already marked

	var cam: Camera3D = _cam()

	if cam == null or cam.global_position.distance_to(at) > SIGN_NEAR_M:
		return

	var row: Dictionary = node.get_meta("model_row", {})
	var length: float = float(row.get("length_m", 1.0)) * maxf(node.scale.x, 0.3)

	if lying and float(b["rest_t"]) > 30.0:
		b["sign_spot"] = at
		_sign_decal(_sign_texture("bed"), at, length * 0.8, node.rotation.y, "bed", GAME_DAY_S)
	elif feeding and float(b["rest_t"]) > 40.0:
		b["sign_spot"] = at
		var ahead: Vector3 = -node.global_transform.basis.z.normalized()
		_sign_decal(_sign_texture("browse"), at + ahead * length * 0.45, maxf(length * 0.35, 0.3), randf() * TAU, "browse", 7.0 * GAME_DAY_S)      # luck-exempt: the browse patch's turn (client look)

		if randf() < 0.25:      # luck-exempt: whether it left droppings here (client look)
			_sign_decal(_sign_texture("droppings"), at - ahead * length * 0.4, clampf(length * 0.12, 0.08, 0.4), randf() * TAU, "droppings", 5.0 * GAME_DAY_S)      # luck-exempt: as above


func _sign_decal(tex: Texture2D, at: Vector3, size: float, turn: float, ground: String, life: float = -1.0, kind: String = "") -> void:
	if not is_inside_tree():
		return

	var decal: Decal = Decal.new()
	decal.texture_albedo = tex
	decal.size = Vector3(size, 0.4, size)
	decal.modulate = {"snow": Color(0.72, 0.78, 0.9, 0.85), "sand": Color(0.55, 0.47, 0.35, 0.7), "mud": Color(0.3, 0.23, 0.16, 0.85),
		"clay": Color(0.36, 0.27, 0.18, 0.8), "turf": Color(0.28, 0.3, 0.18, 0.6), "bed": Color(0.45, 0.48, 0.3, 0.45),
		"browse": Color(0.5, 0.55, 0.3, 0.6), "droppings": Color(0.2, 0.15, 0.1, 0.95)}.get(ground, Color(0.3, 0.25, 0.2, 0.8))
	add_child(decal)
	decal.global_position = at + Vector3(0.0, 0.15, 0.0)
	decal.rotation.y = turn
	decal.set_meta("alpha", decal.modulate.a)
	_signs.append([decal, Time.get_ticks_msec(), life if life > 0.0 else _sign_life(ground, kind), ground])

	while _signs.size() > SIGN_CAP:
		(_signs.pop_front()[0] as Decal).queue_free()


# Every 2 s: each sign fades with its age; rain over 0.5 washes sand prints, falling snow covers snow prints, and thawed ground
# (lying snow under 0.2) melts them; a strong wind (0.6) blurs sand.
func _fade_signs() -> void:
	var cond: Dictionary = _cond() if conditions_now.is_valid() else {}
	var rain: float = float(cond.get("rain", 0.0))
	var snowing: bool = bool(cond.get("snowing", false))
	var thawed: bool = float(cond.get("ground_snow", 1.0)) < 0.2
	var now: int = Time.get_ticks_msec()
	# Real rain (0.4 or more for a game hour) softens mud and clay prints away; a wind over 0.35 for two game hours drifts snow into
	# snow prints (Jamie's tracks page). Counted in this check's 2 s steps.
	_sign_rain_s = _sign_rain_s + 2.0 if rain >= 0.4 else 0.0
	_sign_drift_s = _sign_drift_s + 2.0 if _wind() > 0.35 else 0.0
	var washed: bool = _sign_rain_s >= GAME_HOUR_S
	var drifted: bool = _sign_drift_s >= 2.0 * GAME_HOUR_S

	for i in range(_signs.size() - 1, -1, -1):
		var sg: Array = _signs[i]
		var decal: Decal = sg[0]
		var age: float = float(now - int(sg[1])) / 1000.0
		var ground: String = sg[3]
		var gone: bool = age >= float(sg[2])

		if ground == "sand" and (rain > 0.5 or _wind() > 0.6):
			gone = true
		elif ground == "snow" and (snowing or thawed or drifted):
			gone = true
		elif (ground == "mud" or ground == "clay") and washed:
			gone = true

		if gone or not is_instance_valid(decal):
			if is_instance_valid(decal):
				decal.queue_free()

			_signs.remove_at(i)
		else:
			decal.modulate.a = float(decal.get_meta("alpha", 0.8)) * (1.0 - 0.8 * age / float(sg[2]))      # a fresh print is sharp, an old one faint


# Plain generated shapes for the rest sign (no art files): a flattened oval for a bed, flecks for browse, a cluster of pellets.
func _sign_texture(what: String) -> ImageTexture:
	if _print_tex.has(what):
		return _print_tex[what]

	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dice: RandomNumberGenerator = RandomNumberGenerator.new()
	dice.seed = hash(what)

	for y in 64:
		for x in 64:
			var dx: float = (float(x) - 32.0) / 30.0
			var dy: float = (float(y) - 32.0) / 18.0

			match what:
				"bed":
					var r: float = dx * dx + dy * dy
					if r <= 1.0:
						img.set_pixel(x, y, Color(1, 1, 1, 1.0 - r * 0.6))

	var blobs: int = 18 if what == "browse" else (7 if what == "droppings" else 0)

	for n in blobs:
		var c: Vector2 = Vector2(dice.randf_range(14.0, 50.0), dice.randf_range(14.0, 50.0))
		var rad: float = dice.randf_range(1.5, 3.0) if what == "browse" else dice.randf_range(3.0, 4.5)

		for y in range(int(c.y - rad), int(c.y + rad) + 1):
			for x in range(int(c.x - rad), int(c.x + rad) + 1):
				if x >= 0 and x < 64 and y >= 0 and y < 64 and Vector2(x, y).distance_to(c) <= rad:
					img.set_pixel(x, y, Color(1, 1, 1, 1))

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_print_tex[what] = tex
	return tex


# Animals in weather, the client looks (docs/design/ANIMAL_WEATHER_LOOKS.md). From the client's own weather state (the same on every
# client) and the animal's state; the server's moves (cover, the gale drift, hunch 20 in rain) arrive as positions and states.
const SHAKERS := ["dog", "wolf", "fox", "bear", "black_bear"]
const TAIL_TO_WIND := ["deer", "elk", "horse", "donkey", "cow", "buffalo", "goat", "bighorn", "mountain_goat", "chamois", "wildebeest"]
const COLD_C := 5.0          # steam breath below this
const STEAM_NEAR_M := 30.0   # steam is drawn only this near the camera
const HUDDLE_C := -5.0       # herds stand closer, heads low, below this (Steve's cold_c)
const GALE := 0.6            # wind at which stock turn tail to it (Steve's gale_from)

func _herd_space() -> float:
	_refresh_frame()
	return _f_herd_space


func _weather_look(node: Node3D, b: Dictionary, state: int, speed: float, delta: float) -> void:
	var wx: Dictionary = _wx_state() if weather_now.is_valid() else {}
	var kind: String = str(b.get("kind", ""))
	var rig: Node3D = LifeUtil.rig(node)
	var air: float = _air(node.global_position, wx)
	var standing: bool = speed < 0.3 and (state == 0 or state == 3 or state == 12 or state == HUNCH)

	if rig == null:
		return

	# 1. Shake-off when the rain stops: a 1 s shiver from head to tail, dying away (each animal a moment apart, by its id phase).
	if _wx_shake_due and kind in SHAKERS:
		b["wx_shake"] = -0.15 * float(b.get("phase", 0.0))      # a short wait first

	if b.has("wx_shake"):
		b["wx_shake"] = float(b["wx_shake"]) + delta
		var t: float = float(b["wx_shake"])

		if t >= 1.0:
			b.erase("wx_shake")
			rig.rotation.z = 0.0
			b["shed"] = true      # the wet look sheds its wet_shed share on this (claude/mikew-wet-look)
		elif t >= 0.0:
			rig.rotation.z = 0.25 * sin(t * 42.0) * (1.0 - t)

			if t < delta * 1.5:
				_splash(node.global_position + Vector3(0.0, float(_row_of(node).get("length_m", 1.0)) * 0.35, 0.0), false, 4.0)

	# 2. Tail to the wind in a gale: standing grazers turn their rump to it (on the Rig, as the herd facing does), up to 60 degrees.
	var wind: float = float(wx.get("wind", 0.0))

	if wind_looks:
		pass      # the turn to the wind is _wind_look's (ANIMAL_WIND.md), with rain and the deer's graze into the wind
	elif kind in TAIL_TO_WIND and standing and wind >= GALE and wx.has("wind_dir"):
		var downwind: float = -float(wx["wind_dir"]) - PI * 0.5      # the node turn that faces the way the wind blows
		var want: float = clampf(angle_difference(node.rotation.y, downwind), -PI / 3.0, PI / 3.0)
		b["wind_turn"] = lerp_angle(float(b.get("wind_turn", 0.0)), want, clampf(delta * 0.5, 0.0, 1.0))
		rig.rotation.y = float(b.get("herd_bias", 0.0)) + float(b["wind_turn"])
	elif absf(float(b.get("wind_turn", 0.0))) > 0.01:
		b["wind_turn"] = lerp_angle(float(b["wind_turn"]), 0.0, clampf(delta * 0.5, 0.0, 1.0))
		rig.rotation.y = float(b.get("herd_bias", 0.0)) + float(b["wind_turn"])

	# 3. Cold: herds stand closer (_herd_space) with heads low (the hunch pose while standing, in the posed block).
	b["cold_huddle"] = air < HUDDLE_C and standing

	# 4. Steam breath below 5 C: a small puff at the muzzle on each breath (the row's breath rate, else 15 a minute), only near the camera.
	if air < COLD_C:
		_steam_breath(node, b, air, speed, delta)

	# 5. Snow on the back: lying (19 or asleep) in falling snow it builds over 2 minutes, getting up shakes it off (the coat whitens).
	var lying: bool = state == 19 or bool(b.get("asleep", false))
	var snowing: float = float(wx.get("snow", 0.0))

	if lying and snowing > 0.2:
		b["snow_back"] = minf(1.0, float(b.get("snow_back", 0.0)) + delta / 120.0 * snowing)
	elif not lying and float(b.get("snow_back", 0.0)) > 0.0:
		if float(b["snow_back"]) > 0.2 and not b.has("wx_shake"):
			b["wx_shake"] = 0.0      # it shakes the snow off as it gets up
			_puff(node.global_position + Vector3(0.0, float(_row_of(node).get("length_m", 1.0)) * 0.3, 0.0), "snow", 6.0)

		b["snow_back"] = 0.0

	if float(b.get("snow_back", 0.0)) > 0.0 or b.has("snow_tint"):
		var white: float = float(b.get("snow_back", 0.0)) * 0.5
		b["snow_tint"] = white

		for mi in node.get_meta("meshes", []):
			for mat in (mi as MeshInstance3D).get_meta("coat_mats", []):
				var base: Color = b.get("coat_now", Color.WHITE)
				var c: Color = base.lerp(Color(1.3, 1.3, 1.35), white)

				if mat is ShaderMaterial:
					(mat as ShaderMaterial).set_shader_parameter("albedo_color", c)
				else:
					(mat as StandardMaterial3D).albedo_color = c

		if white <= 0.0:
			b.erase("snow_tint")


func _steam_breath(node: Node3D, b: Dictionary, air: float, speed: float, delta: float) -> void:
	var cam: Camera3D = _cam()

	if cam == null or cam.global_position.distance_to(node.global_position) > STEAM_NEAR_M:
		return

	var row: Dictionary = _row_of(node)
	var per_min: float = float((row.get("breath", {}) as Dictionary).get("per_min", 15.0)) * (2.5 if speed > 3.0 else 1.0)
	b["steam_t"] = float(b.get("steam_t", randf() * 2.0)) - delta      # luck-exempt: the first breath (client look)

	if float(b["steam_t"]) > 0.0:
		return

	b["steam_t"] = 60.0 / maxf(per_min, 4.0)
	var length: float = float(row.get("length_m", 1.0)) * maxf(node.scale.x, 0.3)
	var muzzle: Vector3 = node.global_position - node.global_transform.basis.z.normalized() * length * 0.5 + Vector3.UP * length * 0.45
	var cloud: CPUParticles3D = CPUParticles3D.new()
	cloud.one_shot = true
	cloud.emitting = false
	cloud.amount = 8
	cloud.lifetime = 1.4
	cloud.explosiveness = 0.7
	cloud.direction = -node.global_transform.basis.z.normalized() + Vector3.UP * 0.3
	cloud.spread = 20.0
	cloud.initial_velocity_min = 0.2
	cloud.initial_velocity_max = 0.5
	cloud.gravity = Vector3(0.0, 0.15, 0.0)

	if wind_looks:      # the breath drifts downwind (ANIMAL_WIND.md)
		var to: float = _wind_to()

		if not is_nan(to):
			cloud.gravity += Vector3(cos(to), 0.0, sin(to)) * 1.5 * float(_wx_state().get("wind", 0.0))
	cloud.scale_amount_min = length * 0.04
	cloud.scale_amount_max = length * 0.09
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.96, 1.0, clampf((COLD_C - air) / 15.0, 0.12, 0.35))      # thicker the colder it is
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	if fog_looks and float(_f_fog.get("mist", 0.0)) > 0.3:      # in the mist the breath is fainter and lingers, merging into it (ANIMAL_FOG.md)
		mat.albedo_color.a *= 0.5
		cloud.lifetime *= 1.6

	mesh.material = mat
	cloud.mesh = mesh
	LifeUtil.fire_once(self, cloud, muzzle, 0.4)


# Hunting feedback (docs/design/HUNT_FEEDBACK.md). The client hears of a hit only as the floating hit number (protocol 85, sent to
# the hunter alone: the point and the damage), so the nearest drawn animal within FELL_M of the point takes it, and the zone is read
# from where the point sits on its body: head (front quarter, upper half), chest (front half), hip (back quarter), leg (lower third).
func _hit_reaction(at: Vector3, amount: int) -> void:
	var best: float = FELL_M
	var hit_b: Dictionary = {}

	for id in _bodies:
		var o: Dictionary = _bodies[id]
		var d: float = (o["node"] as Node3D).global_position.distance_to(at) if is_inside_tree() else INF

		if bool(o.get("model", false)) and d < best:
			best = d
			hit_b = o

	if hit_b.is_empty():
		return

	var node: Node3D = hit_b["node"]
	var row: Dictionary = _row_of(node)
	var length: float = float(row.get("length_m", 1.0)) * maxf(node.scale.x, 0.3)
	var local: Vector3 = node.global_transform.affine_inverse() * at      # -Z is forward
	var along: float = clampf(-local.z / maxf(length * 0.5, 0.05), -1.0, 1.0)      # +1 the nose, -1 the tail
	var up: float = local.y / maxf(length * 0.6, 0.05)
	var zone: String = "leg" if up < 0.3 else ("head" if along > 0.55 and up > 0.5 else ("hip" if along < -0.45 else "chest"))
	hit_b["react"] = zone
	hit_b["react_t"] = 0.0

	if zone == "hip":
		hit_b["hip_hit"] = true      # the hind leg drags from now on

	if _health == null:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/animals.json"))
		_health = {}

		if parsed is Dictionary:
			for k in ((parsed as Dictionary).get("species", {}) as Dictionary):
				_health[k] = float(parsed["species"][k].get("health", 10.0))

	hit_b["damage"] = float(hit_b.get("damage", 0.0)) + float(amount)
	hit_b["wounded"] = float(hit_b["damage"]) >= 0.5 * float((_health as Dictionary).get(str(hit_b.get("kind", "")), 10.0))


# The reaction plays on the Rig over a few tenths of a second (flinch: a jolt sideways; head: a toss up and back; chest: a stumble,
# front dipping; leg: a buckle), then the lasting gait: a hip hit drags the hind end low and the steps uneven, and below half health
# (of the damage this client saw) the animal limps, with a slower, uneven stride.
func _hunt_motion(node: Node3D, b: Dictionary, speed: float, delta: float) -> void:
	var rig: Node3D = LifeUtil.rig(node)

	if rig == null:
		return

	var pitch: float = 0.0
	var roll: float = 0.0
	var drop: float = 0.0

	if b.has("react"):
		b["react_t"] = float(b["react_t"]) + delta
		var t: float = float(b["react_t"])
		var span: float = 0.45
		var k: float = sin(PI * clampf(t / span, 0.0, 1.0))

		match str(b["react"]):
			"head":
				pitch = -0.3 * k      # the head and front thrown up
			"chest":
				pitch = 0.22 * k      # a stumble: the front dips
				drop = 0.06 * k
			"hip":
				pitch = -0.18 * k
				drop = 0.05 * k
			"leg":
				roll = 0.2 * k
				drop = 0.08 * k
			_:
				roll = 0.12 * k

		if t >= span:
			b.erase("react")

	var limp: float = 0.0

	if speed > 0.3 and (bool(b.get("hip_hit", false)) or bool(b.get("wounded", false))):
		var beat: float = float(b.get("gait", 0.0)) * TAU
		limp = absf(sin(beat))

		if bool(b.get("hip_hit", false)):
			pitch -= 0.08      # hind end low: the dragged leg
			roll += 0.06 * sin(beat)

		if bool(b.get("wounded", false)):
			roll += 0.05 * sin(beat)
			drop += 0.03 * limp

			b["speed_x"] = float(b.get("speed_x", 1.0)) * (0.85 + 0.15 * limp)      # an uneven, slower stride (applied after the clip, below)

	rig.rotation.x = pitch
	rig.rotation.z = roll
	rig.position.y = -drop


# The death fall (HUNT_FEEDBACK.md): the body goes down onto its side over 0.8 s and comes to rest lying along the ground's slope (the
# ground sampled a body's width either side), then is freed; the server's carcass item takes its place. No canned drop.
func _death_fall(node: Node3D) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		if is_instance_valid(node):
			node.queue_free()
		return

	var row: Dictionary = _row_of(node)
	var width: float = float(row.get("length_m", 1.0)) * 0.25 * maxf(node.scale.x, 0.3)
	var side: Vector3 = node.global_transform.basis.x.normalized()
	var tilt: float = 0.0

	if ground_height.is_valid():
		var left: float = float(ground_height.call(node.global_position.x - side.x * width, node.global_position.z - side.z * width))
		var right: float = float(ground_height.call(node.global_position.x + side.x * width, node.global_position.z + side.z * width))

		if not is_nan(left) and not is_nan(right):
			tilt = atan2(right - left, 2.0 * width)      # the slope across the body

	var falls_right: bool = tilt <= 0.0      # it falls downhill
	var rig: Node3D = LifeUtil.rig(node)
	var target: Node3D = rig if rig != null else node
	var player: AnimationPlayer = node.get_meta("player", null) as AnimationPlayer if node.has_meta("player") else null

	if player != null:
		player.speed_scale = 0.3      # the legs slow as it goes down

	var down: Tween = create_tween()
	down.tween_property(target, "rotation:z", (-PI * 0.5 if falls_right else PI * 0.5) + tilt, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	down.parallel().tween_property(target, "position:y", -width * 0.2, 0.8)
	down.tween_callback(func() -> void: if player != null: player.speed_scale = 0.0)
	down.tween_interval(1.5)
	down.tween_callback(node.queue_free)


# One read a frame of each client callable (PERF_BUDGET.md worst 1): conditions, weather, night light, torch and wind were called
# once per animal per look, and the client's conditions builds a new Dictionary each call. Every look reads these instead.
func _refresh_frame() -> void:
	var f: int = Engine.get_process_frames()

	if f == _f_frame:
		return

	_f_frame = f
	_f_cond = conditions_now.call() if conditions_now.is_valid() else {}
	_f_wx = weather_now.call() if weather_now.is_valid() else {}
	_f_night = night_light.call() if night_light.is_valid() and eye_shine else {}      # only eye shine v2 reads it: no Dictionary a frame with it off
	_f_torch = torch_light.call() if torch_light.is_valid() else []
	_f_wind = float(wind_now.call()) if wind_now.is_valid() else 0.0
	_f_fog = fog_now.call() if fog_now.is_valid() and fog_looks else {}      # only the fog looks read it: no Dictionary a frame with them off
	var cam: Camera3D = _cam()
	_f_herd_space = HERD_SPACE_M * (0.6 if weather_looks and _air(cam.global_position if cam != null else Vector3.ZERO, _f_wx) < HUDDLE_C else 1.0)

	if fog_looks and _fog_visibility() < THICK_FOG_M:
		_f_herd_space *= 0.5      # herds keep closer when they cannot see each other: spread halved (ANIMAL_FOG.md, Jamie #716)


func _cond() -> Dictionary:
	_refresh_frame()
	return _f_cond


func _wx_state() -> Dictionary:
	_refresh_frame()
	return _f_wx


func _night() -> Dictionary:
	_refresh_frame()
	return _f_night


func _torch() -> Array:
	_refresh_frame()
	return _f_torch


# The kill switch (PERF_BUDGET.md): every life-layer flag off at once; set by --life-layer-off on the command line or by the gate.
const LIFE_FLAGS := ["footfall_fx", "prints_fx", "slope_tilt", "foot_ik", "stalk_fx", "season_coats", "coat_dust", "coat_ruffle",
	"young_gait", "young_follow", "water_life", "idle_variety", "flight_bank", "look_at_foe", "swarm_fx", "sea_life", "voice_fx",
	"eye_shine", "animal_sign", "weather_looks", "hunt_feedback", "cover_still", "bird_rig", "swim_rig", "wind_looks", "fog_looks"]

func _all_flags_off() -> void:
	cover_still = false
	bird_rig = false
	swim_rig = false
	wind_looks = false
	fog_looks = false
	footfall_fx = false
	prints_fx = false
	slope_tilt = false
	foot_ik = false
	stalk_fx = false
	season_coats = false
	coat_dust = false
	coat_ruffle = false
	young_gait = false
	young_follow = false
	water_life = false
	idle_variety = false
	flight_bank = false
	look_at_foe = false
	swarm_fx = false
	sea_life = false
	voice_fx = false
	eye_shine = false
	animal_sign = false
	weather_looks = false
	hunt_feedback = false


func _enter_tree() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--life="):      # --life=eye_shine,animal_sign: turn those flags on (pictures, DINO_SHOTS.md)
			for flag in arg.trim_prefix("--life=").split(",", false):
				if flag in LIFE_FLAGS:
					set(flag, true)
		elif arg.begins_with("--life-air="):
			air_override = float(arg.trim_prefix("--life-air="))

	if OS.get_cmdline_user_args().has("--life-layer-off"):
		life_layer_all_off = true
		_all_flags_off()


# The camera the life layer measures distances and angles from, or null outside the tree.
func _cam() -> Camera3D:
	return get_viewport().get_camera_3d() if is_inside_tree() else null

# The air temperature at a place (ANIMAL_WEATHER_LOOKS.md, agreed with Steve): the shared Weather.air_c by height and hour through
# the client's air_at, the same function the server calls; without it (tools) the weather state's temp_c. No lapse of our own.
func _air(at: Vector3, wx: Dictionary) -> float:
	if not is_nan(air_override):
		return air_override

	return float(air_at.call(at)) if air_at.is_valid() else float(wx.get("temp_c", 10.0))

# Steve's hit event (HUNT_FEEDBACK.md, protocol HIT_EVENT_PROTOCOL): the animal id and the zone (an index into HIT_ZONES, or its
# name), sent to every player within 60 m. terrain_client connects it when the network has the signal; from the first one on, the
# hunter's own guess from the hit number is not used, so nobody sees a reaction twice.
func on_hit_event(id: int, zone: Variant) -> void:
	_hit_events_seen = true

	if not hunt_feedback or not _bodies.has(id):
		return

	var zone_name: String = HIT_ZONES[clampi(int(zone), 0, HIT_ZONES.size() - 1)] if (zone is int or zone is float) else str(zone)
	var b: Dictionary = _bodies[id]
	b["react"] = zone_name
	b["react_t"] = 0.0

	if zone_name == "hip":
		b["hip_hit"] = true


# State 20 in cover (Steve #646 section 11, #701): a deer or stock animal standing in its cover for the whole rain, gale or cold. It
# is the hunch (head low, ears back, tail still) and more: the idle clip at half speed so it stands still, breathing slow, no glances,
# and the wet look held (it does not dry while it stands out the weather). It is silent (voices.json names no call for 20) and its
# eyes shine only in a light, as always.
func _cover_still(node: Node3D, b: Dictionary) -> void:
	var player: AnimationPlayer = node.get_meta("player", null) as AnimationPlayer if node.has_meta("player") else null

	if player != null and player.speed_scale > 0.0:
		player.speed_scale = minf(player.speed_scale, 0.5)

	if node.has_meta("breath"):
		var fix = node.get_meta("breath")      # bone_offsets.gd (untyped: its own properties)
		fix.breath_rate = float(fix.breath_rate) * 0.8

	b["look_left"] = 0.0
	b["wet_hold"] = true      # the wet look (claude/mikew-wet-look) keeps its wet amount while this is set


# Birds posed from their skeletons (docs/design/BIRD_FLIGHT.md part 3). A row is posed when it asks for it ("posed_flight": true) or
# when its flight row names no flap clip, so a Meshy bird with a good skeleton and no clips still flies.
func _posed_flight(row: Dictionary) -> bool:
	if not row.has("flight"):
		return false

	var flap: String = str((row["flight"] as Dictionary).get("flap", ""))
	return posed_flight_all or bool(row.get("posed_flight", false)) or flap == "" or flap.begins_with("<")


# The wing bones by name (MODEL_QUIRKS.md pattern: any naming, the row's "wing_bones" wins): for each side the upper, fore and hand
# bones, found by the first bone whose lower-case name holds a side word and a part word. Then the poses:
#   15 flap: the three bones beating at flight.beat_hz (the fore and hand a little behind), up and down about the row's wing_axis
#   17 glide: the wings held out level (glide_deg), the hands a little swept back
#   18 perch: folded against the body (fold_deg)
#   -20 landing flare: the wings up and forward, held
# Mirrored left and right. A tail bone, if found, fans a little in the flare. Missing bones are logged, and a bird with no wing
# bones found keeps its clips (or its flap bob) only.
const WING_SIDES := {"l": ["left", "_l", ".l", "l_", "lft"], "r": ["right", "_r", ".r", "r_", "rgt"]}
const WING_PARTS := {"up": ["upperarm", "humerus", "wing1", "wing_01", "shoulder", "arm"], "fore": ["forearm", "lowerarm", "ulna", "wing2", "wing_02", "elbow"], "hand": ["hand", "wrist", "wing3", "wing_03", "finger", "tip"]}

func _wing_poses(sk: Skeleton3D, row: Dictionary, kind: String) -> Dictionary:
	var named: Dictionary = row.get("wing_bones", {})
	var found: Dictionary = {}

	for side in WING_SIDES:
		for part in WING_PARTS:
			var key: String = side + "_" + part

			if named.has(key) and sk.find_bone(str(named[key])) >= 0:
				found[key] = str(named[key])
				continue

			for i in sk.get_bone_count():
				var bone_name: String = sk.get_bone_name(i).to_lower()
				var side_hit: bool = false

				for w in WING_SIDES[side]:
					if bone_name.contains(w):
						side_hit = true

				var part_hit: bool = false

				for w in WING_PARTS[part]:
					if bone_name.contains(w):
						part_hit = true

				if side_hit and part_hit and not found.values().has(sk.get_bone_name(i)) and not (part == "up" and (bone_name.contains("fore") or bone_name.contains("lower"))):
					found[key] = sk.get_bone_name(i)
					break

	if not found.has("l_up") or not found.has("r_up"):
		_model_note(kind, "posed flight: no wing bones found (the row's wing_bones can name them); flight clips or the flap bob only")
		return {}

	_model_note(kind, "posed flight: wing bones %s" % str(found))
	var flight: Dictionary = row["flight"]
	var axis: String = str(row.get("wing_axis", "z"))
	var beat: float = maxf(float(flight.get("beat_hz", 4.0)), 0.5)
	var swing: float = float(row.get("wing_swing_deg", 45.0))
	var glide: float = float(row.get("glide_deg", 10.0))
	var fold: float = float(row.get("fold_deg", 60.0))
	var idx: int = {"x": 0, "y": 1, "z": 2}.get(axis, 2)

	var hold := func(deg: float) -> Array:
		var v: Array = [0.0, 0.0, 0.0]
		v[idx] = deg
		return v

	var flap_waves: Dictionary = {}
	var glide_bones: Dictionary = {}
	var fold_bones: Dictionary = {}
	var flare_bones: Dictionary = {}

	for side in ["l", "r"]:
		var sgn: float = 1.0 if side == "l" else -1.0

		for part in ["up", "fore", "hand"]:
			var key: String = side + "_" + part

			if not found.has(key):
				continue

			var share: float = {"up": 1.0, "fore": 0.6, "hand": 0.4}[part]
			var lag: float = {"up": 0.0, "fore": 0.12, "hand": 0.22}[part]
			flap_waves[found[key]] = [lag, sgn * swing * share, axis]
			glide_bones[found[key]] = hold.call(sgn * (glide if part == "up" else -glide * 0.5))
			fold_bones[found[key]] = hold.call(-sgn * fold * share)
			flare_bones[found[key]] = hold.call(sgn * swing * 0.9 * share)

	var poses: Dictionary = {
		"15": {"waves": flap_waves, "period_s": 1.0 / beat},
		"17": {"bones": glide_bones},
		"18": {"bones": fold_bones},
		"-20": {"bones": flare_bones}}
	return poses


# Whales and dolphins posed from their spines (docs/design/SWIM_RIG.md). A row is posed when it asks ("posed_swim": true) or names no
# swim clip, so a Meshy model with a good skeleton swims with no clips.
func _posed_swim(row: Dictionary) -> bool:
	if posed_flight_all and (row.get("clips", {}) as Dictionary).has("swim"):
		return true      # tools only (--posed): any swimmer with a swim clip, as a stand-in until a Meshy whale or dolphin arrives

	if not row.has("sea"):
		return false

	var swim: String = str((row.get("clips", {}) as Dictionary).get("swim", ""))
	return bool(row.get("posed_swim", false)) or swim == "" or swim.begins_with("<")


# The spine chain by name (the row's "spine_bones" list wins): every bone whose lower-case name holds spine, back, chest, tail, caudal
# or fluke, in skeleton order (parents before children), and the flippers (flipper, pectoral, fin, or arm and hand on a humanoid rig).
# The poses (bone_offsets.gd state poses, all up and down about the row's swim_axis, default x: whales and dolphins beat their flukes
# vertically, not side to side like a fish):
#   0 idle at the surface: a slow, small wave (a third of the swing at half the beat)
#   1 travelling: the wave runs from the chest to the flukes, each bone later and wider than the one before, at sea.tail_hz
#   2 fast: the same at 1.6 times the beat and 1.3 times the swing
# The flippers stroke a little against the beat. No spine bones found: a log note, and the clips (or the swim block) only.
const SPINE_WORDS := ["spine", "back", "chest", "tail", "caudal", "fluke"]
const FLIPPER_WORDS := ["flipper", "pectoral", "fin"]

func _swim_poses(sk: Skeleton3D, row: Dictionary, kind: String) -> Dictionary:
	var chain: Array = []

	for bone_name in row.get("spine_bones", []):
		if sk.find_bone(str(bone_name)) >= 0:
			chain.append(str(bone_name))

	if chain.is_empty():
		for i in sk.get_bone_count():
			var low: String = sk.get_bone_name(i).to_lower()

			for w in SPINE_WORDS:
				if low.contains(w):
					chain.append(sk.get_bone_name(i))
					break

	var flippers: Array = []

	for i in sk.get_bone_count():
		var low: String = sk.get_bone_name(i).to_lower()

		for w in FLIPPER_WORDS:
			if low.contains(w) and not chain.has(sk.get_bone_name(i)):
				flippers.append(sk.get_bone_name(i))
				break

	if chain.size() < 2:
		_model_note(kind, "posed swim: no spine chain found (the row's spine_bones can name it); swim clip or the swim block only")
		return {}

	_model_note(kind, "posed swim: spine %s, flippers %s" % [str(chain), str(flippers)])
	var sea: Dictionary = row.get("sea", {})
	var axis: String = str(row.get("swim_axis", "x"))
	var hz: float = maxf(float(sea.get("tail_hz", 0.5)), 0.05)
	var swing: float = float(row.get("swim_swing_deg", 12.0))
	var n: int = chain.size()
	var poses: Dictionary = {}

	for spec in [["0", 0.33, 0.5], ["1", 1.0, 1.0], ["2", 1.3, 1.6]]:
		var waves: Dictionary = {}

		for i in n:
			var along: float = float(i) / float(maxi(n - 1, 1))      # 0 at the chest, 1 at the flukes
			waves[chain[i]] = [along * 0.35, swing * float(spec[1]) * (0.25 + 0.75 * along), axis]

		for f in flippers:
			waves[f] = [0.5, swing * 0.4 * float(spec[1]), "z"]

		poses[spec[0]] = {"waves": waves, "period_s": 1.0 / (hz * float(spec[2]))}

	return poses


# A dolphin porpoising (the hop arc, sea rows): the body pitches nose-up as it rises and nose-down as it falls, along the arc.
func _porpoise_pitch(node: Node3D, b: Dictionary) -> void:
	var rig: Node3D = LifeUtil.rig(node)

	if rig == null:
		return

	var phase: float = fposmod(float(b.get("hop_phase", 0.0)), 1.0)
	rig.rotation.x = -0.6 * cos(PI * phase) if rig.position.y > 0.02 else lerpf(rig.rotation.x, 0.0, 0.2)


# Animals and the wind's direction (docs/design/ANIMAL_WIND.md). The way the wind blows toward: the shared weather's wind_dir, which
# becomes Kathleen's per-group prevailing wind (prevailing_wind.md) once it lands. The island is a grid of rows with the equator in
# the middle, so no direction is assumed: with no wind_dir in the weather (the tool without one) there is no wind turn (NAN).
const RUMP_WIND := 0.45      # with rain over RUMP_RAIN, stock and deer stand rump to the wind from here (Jamie #639); a gale alone does it too
const RUMP_RAIN := 0.3
const GRAZE_WIND := [0.15, 0.6]   # deer graze moving into a light or moderate wind (Jamie #639; Steve's _upwind_angle on the server)

func _wind_to() -> float:
	var wx: Dictionary = _wx_state()
	return float(wx["wind_dir"]) if wx.has("wind_dir") else NAN


func _wind_look(node: Node3D, b: Dictionary, state: int, speed: float, delta: float) -> void:
	var rig: Node3D = LifeUtil.rig(node)

	if rig == null:
		return

	var wx: Dictionary = _wx_state()
	var wind: float = float(wx.get("wind", 0.0))
	var rain: float = maxf(float(wx.get("rain", 0.0)), float(wx.get("snow", 0.0)))
	var kind: String = str(b.get("kind", ""))
	var standing: bool = speed < 0.3 and (state == 0 or state == 3 or state == 12 or state == HUNCH)
	if is_nan(_wind_to()):
		return      # no direction known: no turn to the wind

	var downwind: float = -_wind_to() - PI * 0.5      # the node turn that faces the way the wind blows
	var want: float = 0.0
	b["wind_hunch"] = false

	if kind in TAIL_TO_WIND and standing and (wind >= GALE or (wind >= RUMP_WIND and rain >= RUMP_RAIN)):
		want = clampf(angle_difference(node.rotation.y, downwind), -PI / 3.0, PI / 3.0)      # rump to the wind
		b["wind_hunch"] = rain >= RUMP_RAIN      # and the head down in the rain
	elif kind in ["deer", "elk", "moose"] and state == 0 and wind >= float(GRAZE_WIND[0]) and wind < float(GRAZE_WIND[1]):
		want = clampf(angle_difference(node.rotation.y, downwind + PI), -PI / 4.0, PI / 4.0)      # grazing into the wind, nose to the scent

	b["wind_turn"] = lerp_angle(float(b.get("wind_turn", 0.0)), want, clampf(delta * 0.5, 0.0, 1.0))

	if absf(float(b["wind_turn"])) > 0.005 or absf(want) > 0.0:
		rig.rotation.y = float(b.get("herd_bias", 0.0)) + float(b["wind_turn"])


# A bird taking off or landing turns into the wind (the Rig, up to 90 degrees, eased), as real birds do for lift.
func _into_wind(node: Node3D, delta: float) -> void:
	var rig: Node3D = LifeUtil.rig(node)

	if rig == null or float(_wx_state().get("wind", 0.0)) < 0.1:
		return

	if is_nan(_wind_to()):
		return

	var upwind: float = -_wind_to() - PI * 0.5 + PI
	var want: float = clampf(angle_difference(node.rotation.y, upwind), -PI * 0.5, PI * 0.5)
	rig.rotation.y = lerp_angle(rig.rotation.y, want, clampf(delta * 4.0, 0.0, 1.0))


# Fog (docs/design/ANIMAL_FOG.md): how far one can see, from the client's fog (Kathleen's weather look). `visibility_m` when it is
# given; else from the scene's exponential fog density (contrast falls to 5 percent at 3 / density metres); INF in clear air.
const FOG_M := 1000.0         # fog proper below this visibility (Jamie #716: mist 1 to 2 km, fog 180 to 1,000 m, thick 50 to 180, dense under 50)
const THICK_FOG_M := FOG_M    # herds bunch in fog: spread halved (Jamie #716, judged)
const FOG_SHINE_M := 180.0    # eye shine from dusk in thick fog

func _fog_visibility() -> float:
	_refresh_frame()

	if _f_fog.has("visibility_m"):
		return float(_f_fog["visibility_m"])

	var density: float = float(_f_fog.get("density", 0.0))
	return 3.0 / density if density > 0.0001 else INF


# One line per kind and message in the game log, so a model that is not drawn says why.
func _model_note(kind: String, text: String) -> void:
	var key: String = kind + text

	if not _model_notes.has(key):
		_model_notes[key] = true
		print("animal model %s: %s" % [kind, text])


# Plays the clip for the animal's state (a moving animal walks or runs by its real ground speed) and keeps the gait count for footsteps.
func _animate_model(node: Node3D, b: Dictionary, state: int, speed: float, delta: float) -> void:
	var row: Dictionary = node.get_meta("model_row", {})
	var clips: Dictionary = row.get("clips", {})
	var clip: String = str(clips.get(str(state), clips.get("0", "")))
	var walk_mps: float = float(row.get("walk_mps", 1.5))
	var run_mps: float = float(row.get("run_mps", 7.0))
	var ref: float = 0.0

	if speed > 0.3 and state != 10 and state != 12 and state != WARN_POP:
		var running: bool = speed > (walk_mps + run_mps) * 0.5
		clip = str(clips.get("run" if running else "walk", clip))
		ref = run_mps if running else walk_mps

	b["gait"] = float(b.get("gait", 0.0)) + speed * delta / maxf(float(row.get("stride_m", 1.2)), 0.1)

	if not node.has_meta("player"):
		return

	var player: AnimationPlayer = node.get_meta("player")
	var roles: Dictionary = player.get_meta("roles", {})
	var role: String = str(state) if roles.has(str(state)) else "0"

	# State 20 hunch (Steve's #646, weather): standing still head low; with no clip of its own the standing idle (12, then 3) plays
	# under the row's state_poses "20" (head and neck down), never the grazing clip.
	if state == HUNCH and not roles.has("20"):
		role = "12" if roles.has("12") else ("3" if roles.has("3") else "0")

	# Asleep (docs/design/ANIMAL_SLEEP.md): the server beds an animal down outside its active hours but sends it as grazing; the client
	# applies the same rule from the species file and its clock and plays the row's sleep clip (or holds its sleep pose). The server's
	# alert or flee wakes it; a get-up clip plays first when the row names one.
	var was_asleep: bool = bool(b.get("asleep", false))
	b["asleep"] = state == 0 and speed < 0.3 and _asleep_now(str(b.get("kind", "")))

	if bool(b["asleep"]) and roles.has("sleep"):
		var sleep_clip: String = str(roles["sleep"])

		if player.current_animation != sleep_clip:
			player.play(sleep_clip, 0.6)

		player.speed_scale = 1.0
		return

	if was_asleep and not bool(b["asleep"]):
		b["idle_woke"] = true      # idle variety: a stretch on getting up (IDLE_VARIETY.md)

	if was_asleep and not bool(b["asleep"]) and row.has("wake_clip"):
		var wake: String = _clip_full(player, row, str(row["wake_clip"]))

		if wake != "":
			player.play(wake, 0.2)
			player.speed_scale = 1.5
			b["waking"] = player.get_animation(wake).length / 1.5

	if float(b.get("waking", 0.0)) > 0.0:
		b["waking"] = float(b["waking"]) - delta
		return
	# Idle variety (IDLE_VARIETY.md): now and then a standing animal scratches, shakes, stretches, looks round or rolls.
	if idle_variety and row.has("idles") and _idle_variety(node, b, row, player, state, speed, delta):
		return

	# Land animals and water (ANIMALS_AND_WATER.md): deep enough, a row with water_swim swims low and paddles; at the bank it drinks.
	if water_life and not roles.has("swim") and water_level.is_valid() and _water_body(node, b, row, player, state, delta):
		return

	# A swimmer (a row with a "swim" clip, the alligator) in the water plays its swim clip whatever its state, at its swim speed.
	if roles.has("swim") and water_level.is_valid():
		var level: float = float(water_level.call(node.global_position.x, node.global_position.z)) if node.is_inside_tree() else NAN

		if not is_nan(level) and node.global_position.y < level - 0.05:
			role = "swim"
			ref = float(row.get("swim_mps", 1.5)) if speed > 0.3 else 0.0
			clip = str(roles.get("swim", ""))

			if clip != "" and player.current_animation != clip:
				player.play(clip, 0.25)

			player.speed_scale = clampf(speed / ref, 0.5, 2.0) if ref > 0.0 else 0.6
			return

	if ref > 0.0 and not (state in AIR_STATES and roles.has(str(state))):      # in the air a flock plays its flight clip at any speed
		role = "run" if ref == run_mps else "walk"
	elif state in AIR_STATES and roles.has(str(state)):
		ref = 0.0

	clip = str(roles.get(role, roles.get("0", "")))

	# Birds in flight (docs/design/BIRD_FLIGHT.md, row "flight"): a take-off clip once as the bird leaves the ground, then flapping
	# and gliding in turns (flap_s, glide_s) at the species' wingbeat, a small bob with each beat for small birds, and a landing
	# flare once as it comes down; the bird's own state 15 still drives when it is in the air.
	var flight: Dictionary = row.get("flight", {})

	if not flight.is_empty():
		# Each bird of a model flock keeps its own take-off, air time and bank (the flock shares one record b, and this runs once per
		# bird a frame); a single bird uses b itself, so play_roll and _flap_bob see the same values.
		var fb: Dictionary = b

		if node != b.get("node"):
			if not node.has_meta("flight_b"):
				node.set_meta("flight_b", {})

			fb = node.get_meta("flight_b")

		var air: bool = state in AIR_STATES
		var was_air: bool = bool(fb.get("was_air", false))
		fb["was_air"] = air

		if air and not was_air:
			fb["air_t"] = 0.0
			var lift: String = _clip_full(player, row, str(flight.get("takeoff", "")))

			if lift != "":
				player.play(lift, 0.1)
				fb["air_once"] = player.get_animation(lift).length

		elif was_air and not air:
			if bird_rig and _posed_flight(row):
				b["flare_t"] = 0.6      # the posed landing flare (pose -20) for 0.6 s

			var flare: String = _clip_full(player, row, str(flight.get("land", "")))

			if flare != "":
				player.play(flare, 0.1)
				fb["air_once"] = player.get_animation(flare).length

		fb["air_once"] = maxf(0.0, float(fb.get("air_once", 0.0)) - delta)

		if float(fb["air_once"]) > 0.0:
			if wind_looks:
				_into_wind(node, delta)      # birds take off and land facing into the wind

			return      # a take-off or landing plays to its end

		if air:
			fb["air_t"] = float(fb.get("air_t", 0.0)) + delta
			var flap_s: float = float(flight.get("flap_s", 99.0))
			var glide_s: float = float(flight.get("glide_s", 0.0))
			# State 17 is the server's glide (Steve's #653: the pheasant's locked-wing glide into cover, the eagle's glide between
			# thermals). Once a bird has been sent 17, its 15 means flapping; a flock that never sends 17 keeps the timed turns.
			if state == 17:
				fb["seen_glide"] = true

			var gliding: bool = state == 17 or (not fb.has("seen_glide") and glide_s > 0.0 and fposmod(float(fb["air_t"]), flap_s + glide_s) > flap_s)

			if flight_bank:
				fb["heading"] = b.get("heading", 0.0)
				_bank(node, fb, delta)
			var air_clip: String = _clip_full(player, row, str(flight.get("glide" if gliding else "flap", "")))

			if air_clip != "":
				if player.current_animation != air_clip:
					player.play(air_clip, 0.3)

				var beat: float = float(flight.get("beat_hz", 0.0))
				player.speed_scale = 1.0 if beat <= 0.0 or gliding else clampf(beat * player.get_animation(air_clip).length, 0.5, 3.0)
				return

	if clip != "" and player.current_animation != clip:
		player.play(clip, 0.25)

	if ref > 0.0 and clip != "" and player.has_animation(clip):
		ref = float(player.get_animation(clip).get_meta("travel_mps", ref))      # the speed the clip's feet were made for (_strip_root_drift)

	player.speed_scale = clampf(speed / ref, 0.5, 2.0) if ref > 0.0 else 1.0

	if bool(b.get("backing", false)) and ref > 0.0:
		player.speed_scale = -player.speed_scale      # backing away: the steps run backward, no moonwalk

	# A young one drawn smaller than the clip's measured size (YOUNG_ANIMALS.md): its feet cover less ground a step, so the same speed
	# needs quicker steps (shorter stride, higher rate); up to three times the clip's rate so a foal keeps up with a trotting mare.
	if young_gait and bool(b.get("young", false)) and not node.has_meta("young_model") and ref > 0.0:
		player.speed_scale = clampf(speed / (ref * maxf(node.scale.x, 0.1)), 0.5, 3.0)

	# Stalking (STALK_POUNCE.md): the walk at the row's slower rate, a stalk clip if the file has one, and a freeze for 1 to 3 s
	# when a grazer near it looks up. On the attack a pounce clip plays once and _pounce lifts the body on an arc.
	if stalk_fx and _stalking(node, state):
		var stalk: Dictionary = row["stalk"]

		if stalk.has("clip"):
			var creep: String = _clip_full(player, row, str(stalk["clip"]))

			if creep != "" and player.current_animation != creep:
				player.play(creep, 0.3)

		player.speed_scale *= float(stalk.get("rate", 0.5))

		if float(b.get("freeze", 0.0)) <= 0.0 and float(b.get("freeze_cool", 0.0)) <= 0.0 and _prey_looking(node):
			var span: Array = stalk.get("freeze_s", [1.0, 3.0])
			b["freeze"] = randf_range(float(span[0]), float(span[1]))      # luck-exempt: how long a stalker holds still (client look)
			b["freeze_cool"] = float(b["freeze"]) + 3.0

		b["freeze"] = maxf(0.0, float(b.get("freeze", 0.0)) - delta)
		b["freeze_cool"] = maxf(0.0, float(b.get("freeze_cool", 0.0)) - delta)

		if float(b["freeze"]) > 0.0:
			player.speed_scale = 0.0

	if stalk_fx and row.has("pounce") and state == 7 and int(b.get("last_state", -1)) != 7:
		b["pounce_t"] = 0.0
		var leap: String = _clip_full(player, row, str(row["pounce"].get("clip", "")))

		if leap != "":
			player.play(leap, 0.1)

	b["last_state"] = state

	# A hopping animal (docs/design/HOP_ARC.md, row "hop" {walk|run: {bound_m, arc_m}}) bounds on an arc instead of skating on a
	# sped-up hop: one hop clip cycle per bound, the bound lengthening above the clip's own rate (_hop_arc lifts the body).
	var hop: Dictionary = row.get("hop", {})

	if hop.has(role) and speed > 0.3 and clip != "" and player.has_animation(clip):
		var bound: float = float(hop[role].get("bound_m", 0.5))
		player.speed_scale = clampf(speed / bound * player.get_animation(clip).length, 0.5, 1.5)
		b["hop"] = [bound * maxf(1.0, (speed / bound * player.get_animation(clip).length) / 1.5), float(hop[role].get("arc_m", 0.1))]
	else:
		b["hop"] = null


# A step lands when the gait (four-legged and wolf) passes a whole number, or a rabbit's hop comes down; none while standing, grazing or a duck flock (no gait yet).
func _emit_steps(b: Dictionary, node: Node3D, state: int, speed: float) -> void:
	var kind: String = str(b.get("kind", ""))

	if kind == "" or kind == "duck" or speed < 0.4:
		return

	var count: int
	if kind == "rabbit":
		if state == GRAZE:
			return

		count = int(floor((_t * (9.0 if state == FLEE else 5.0) + float(b["phase"])) / PI))
	else:
		count = int(floor(float(b.get("gait", 0.0))))

	if int(b["step_count"]) >= 0 and count != int(b["step_count"]):
		stepped.emit(kind, node.global_position)
		var ground: String = _ground_kind(node, b)
		footfall.emit(kind, node.global_position, ground, speed)

		if footfall_fx and speed > 2.0 and ground != "water" and ground != "puddle":
			_puff(node.global_position, ground, speed)

		if footfall_fx and (ground == "water" or ground == "puddle") and speed > 0.4:
			_splash(node.global_position, ground == "water", speed)

		if prints_fx and not animal_sign and (ground == "snow" or ground == "mud"):
			_print_at(kind, node, ground)

		if animal_sign:
			_sign_track(kind, node, b, speed)

	b["step_count"] = count


# The coat (Kathreen, 3 Nov 2026; art/Art_Direction.md: nothing plastic): every animal piece was a flat StandardMaterial3D, so rabbits and deer read as smooth
# painted toys. One small shader gives a coat instead: fine strands lying back along the body (-Z is forward, so the streaks run along Z), soft clumps, a darker
# underside on each piece, and a pale fuzzy rim where the coat meets the sky, which is what makes fur read as fur at a distance. Frogs, fish and seals take the
# "wet" coat (smoother, a little sheen, faint streaks). Small dark balls (eyes, noses) take the "eye" look: glossy, so they catch the sun.
# Cost: one shader for every animal, a few hashes per pixel, no textures; at most MAX_DRAWN animals and each is small on screen.
const COAT_SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform vec3 coat : source_color = vec3(0.5, 0.4, 0.28);
uniform float strands = 1.0;      // 1 fur, 0.3 wet skin, 0 eyes
uniform float fuzz = 0.35;        // the pale rim
uniform float rough = 0.95;
uniform float spec = 0.15;

varying vec3 lp;
varying vec3 ln;

float h3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 0.0)), h3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(h3(i + vec3(0.0, 0.0, 1.0)), h3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 1.0)), h3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

void vertex() {
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	lp = VERTEX * s;          // metres along the piece, so a big deer and a small rabbit get the same strand size
	ln = NORMAL;
}

void fragment() {
	float strand = vnoise(lp * vec3(420.0, 420.0, 70.0));                  // fine hairs lying back along the body
	float clump = vnoise(lp * 45.0 + 7.0);                                 // soft tufts
	float grain = mix(1.0, 0.78 + 0.3 * strand + 0.12 * clump, strands);
	float under = mix(0.78, 1.04, clamp(ln.y * 0.5 + 0.5, 0.0, 1.0));     // each piece darker underneath, as a coat is in its own shadow
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	vec3 col = coat * grain * mix(1.0, under, step(0.01, strands));
	col = mix(col, min(coat * 1.6 + 0.08, vec3(1.0)), rim * fuzz);        // the light caught in the tips of the coat
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
"""

static var _coat_shader: Shader
const SHADOW_MIN_M := 0.09      # a piece this big (its radius times its largest scale) casts a shadow
var _coat: String = "fur"        # the coat the next pieces take: _make_frog, _make_fish and _make_seal switch it to "wet", the birds (FEATHERED) to "feather", while they build


func _material(color: Color) -> Material:
	var look: String = "eye" if color.v < 0.12 else _coat
	var key: String = color.to_html() + look

	if not _mats.has(key):
		if _coat_shader == null:
			_coat_shader = Shader.new()
			_coat_shader.code = COAT_SHADER

		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = _coat_shader
		m.set_shader_parameter("coat", color)

		if look == "eye":
			m.set_shader_parameter("strands", 0.0)
			m.set_shader_parameter("fuzz", 0.0)
			m.set_shader_parameter("rough", 0.12)
			m.set_shader_parameter("spec", 0.8)
		elif look == "feather":
			# Feathers lie in broad smooth vanes, not fine hairs: a softer grain, a little sheen on the vanes, a light rim (Kathreen, 3 Nov 2026).
			m.set_shader_parameter("strands", 0.45)
			m.set_shader_parameter("fuzz", 0.22)
			m.set_shader_parameter("rough", 0.72)
			m.set_shader_parameter("spec", 0.3)
		elif look == "wet":
			m.set_shader_parameter("strands", 0.3)
			m.set_shader_parameter("fuzz", 0.12)
			m.set_shader_parameter("rough", 0.4)
			m.set_shader_parameter("spec", 0.45)

		_mats[key] = m

	return _mats[key]


func _ball(parent: Node3D, radius: float, scale_v: Vector3, at: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8 if radius >= 0.05 else 5      # tiny balls (eyes, nostrils, tail tips) need few facets
	mesh.rings = 4 if radius >= 0.05 else 2
	mesh.material = _material(color)
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = mesh
	inst.scale = scale_v
	inst.position = at
	inst.rotation = rot
	# Only the big pieces (body, haunch, chest, head of the large animals) cast a shadow, so an animal stands on the ground instead of floating over it; ears, legs, eyes
	# and other small parts stay off (Kathreen, 3 Nov 2026). About 2 to 5 shadow pieces per animal, at most MAX_DRAWN animals.
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if radius * maxf(scale_v.x, maxf(scale_v.y, scale_v.z)) >= SHADOW_MIN_M else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)


# Facing -Z (the heading turns the root). About 0.45 m long, 0.3 m to the ear tips.
func _make_rabbit() -> Node3D:
	# A wild rabbit (refs: field-guide photos of the European rabbit: a brown-grey agouti coat, a rounded hunched body with big haunches, long hind feet, short forelegs, a small blunt head,
	# long ears with dark tips, a rusty nape patch, pale belly and chin, a small white-underside scut). About 0.45 m long, 0.25 m high. Facing -Z; the node is named Rig for the hop animation.
	var root: Node3D = Node3D.new()
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var fur: Color = Color(0.5, 0.4, 0.28)
	var dark: Color = Color(0.3, 0.23, 0.16)
	var pale: Color = Color(0.9, 0.86, 0.78)
	_ball(rig, 0.09, Vector3(1.0, 1.0, 1.2), Vector3(0.0, 0.1, 0.1), fur)                       # the haunch: the big rounded rear is the rabbit's silhouette
	_ball(rig, 0.075, Vector3(0.95, 0.9, 1.5), Vector3(0.0, 0.1, -0.02), fur)                   # the body
	_ball(rig, 0.05, Vector3(0.9, 1.0, 1.0), Vector3(0.0, 0.14, -0.1), fur)                     # the shoulders
	_ball(rig, 0.06, Vector3(0.8, 0.5, 1.6), Vector3(0.0, 0.05, -0.02), pale)                   # the pale belly
	_ball(rig, 0.024, Vector3(1.3, 0.55, 0.8), Vector3(0.0, 0.18, -0.118), Color(0.6, 0.4, 0.22))   # the rusty nape patch
	_ball(rig, 0.052, Vector3(0.85, 0.9, 1.15), Vector3(0.0, 0.17, -0.17), fur)                 # the head
	_ball(rig, 0.03, Vector3(0.8, 0.75, 1.2), Vector3(0.0, 0.155, -0.215), pale)                # muzzle and chin
	_ball(rig, 0.01, Vector3.ONE, Vector3(0.0, 0.16, -0.243), Color(0.2, 0.1, 0.1))             # the nose
	_ball(rig, 0.01, Vector3.ONE, Vector3(0.036, 0.18, -0.19), Color(0.05, 0.04, 0.04))         # eyes
	_ball(rig, 0.01, Vector3.ONE, Vector3(-0.036, 0.18, -0.19), Color(0.05, 0.04, 0.04))

	for side in [-1.0, 1.0]:
		var ear: Node3D = Node3D.new()
		ear.name = "Ear_L" if side < 0.0 else "Ear_R"
		ear.position = Vector3(side * 0.03, 0.2, -0.15)
		rig.add_child(ear)
		_ball(ear, 0.03, Vector3(0.62, 2.5, 0.25), Vector3(0.0, 0.07, 0.02), fur, Vector3(-0.2, 0.0, side * -0.2))     # a long ear leaning back and out
		_ball(ear, 0.018, Vector3(0.4, 2.0, 0.15), Vector3(0.0, 0.1, 0.0), dark, Vector3(-0.2, 0.0, side * -0.2))      # the dark tip
		_box(rig, Vector3(0.022, 0.03, 0.07), Vector3(side * 0.045, 0.02, -0.12), fur)          # a short foreleg and paw
		_box(rig, Vector3(0.032, 0.026, 0.15), Vector3(side * 0.06, 0.013, 0.07), fur)            # the long hind foot flat on the ground

	_ball(rig, 0.03, Vector3(1.0, 1.0, 0.9), Vector3(0.0, 0.14, 0.2), pale)                     # the white scut
	return root


# A wild boar (refs: Eurasian wild boar photographs): a stocky wedge, deepest at the shoulder and tapering to a small rump, a heavy head with a long snout and small ears, short legs, a dark bristly mane along the
# neck and back, a thin tail, two curved ivory tusks beside the mouth; coat dark grizzled brown. About 1.3 m long, 0.8 m at the shoulder. Built on the shared four-legged body so it animates like the others.
func _make_boar() -> Node3D:
	var node: Node3D = _make_quad({"leg_h": 0.36, "rb": 0.24, "len": 1.15, "neck": 0.16, "head": 0.34, "snout": 1.6, "hump": true, "ear": 0.5, "pale_belly": false, "dark_head": true, "coat": Color(0.3, 0.24, 0.18), "dark": Color(0.14, 0.11, 0.09), "pale": Color(0.5, 0.42, 0.34), "mane": true, "socks": false})
	var head: Node3D = node.get_node("Rig/Head")
	var hd: float = 0.34
	var top: Vector3 = Vector3(0.0, 0.16 * 0.78, -0.16 * 0.85)

	for side in [-1.0, 1.0]:
		_box(head, Vector3(hd * 0.07, hd * 0.07, hd * 0.45), top + Vector3(side * hd * 0.17, -hd * 0.2, -hd * 0.66), Color(0.93, 0.9, 0.8), Vector3(0.6, side * 0.2, side * -0.55))   # a tusk beside the snout, curving up

	var rig: Node3D = node.get_node("Rig")

	for k in 9:   # the bristle ridge: a row of stiff dark spikes along the neck and back, tallest over the shoulders
		_box(rig, Vector3(0.02, 0.05 + 0.035 * sin(float(k) * 0.35 + 0.4), 0.045), Vector3(0.0, 0.575 + 0.03 * sin(float(k) * 0.35), -0.46 + 0.1 * float(k)), Color(0.1, 0.08, 0.07), Vector3(0.0, 0.0, 0.0))

	return node


# A songbird (refs: European robin and blackbird photographs): a plump round body tipped forward, a round head, a short pointed beak, a tail slanting down behind, folded wings along the sides, two thin legs;
# the robin's colours: brown back, orange-red breast and face, pale belly. About 0.15 m long. Facing -Z.
func _make_songbird() -> Node3D:
	var root: Node3D = Node3D.new()
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var back: Color = Color(0.45, 0.34, 0.22)
	var breast: Color = Color(0.85, 0.38, 0.14)
	_ball(rig, 0.045, Vector3(0.9, 1.0, 1.25), Vector3(0.0, 0.09, 0.0), back)                       # body
	_ball(rig, 0.038, Vector3(0.9, 0.9, 1.0), Vector3(0.0, 0.085, -0.025), breast)                   # breast
	_ball(rig, 0.03, Vector3(1.0, 1.0, 1.0), Vector3(0.0, 0.125, -0.04), back)                        # head
	_ball(rig, 0.022, Vector3(1.0, 0.9, 0.8), Vector3(0.0, 0.118, -0.058), breast)                    # the orange face
	_box(rig, Vector3(0.008, 0.008, 0.02), Vector3(0.0, 0.12, -0.08), Color(0.2, 0.15, 0.1), Vector3(0.1, 0.0, 0.0))   # beak
	_ball(rig, 0.006, Vector3.ONE, Vector3(0.016, 0.13, -0.062), Color(0.04, 0.04, 0.04))            # eyes
	_ball(rig, 0.006, Vector3.ONE, Vector3(-0.016, 0.13, -0.062), Color(0.04, 0.04, 0.04))
	_box(rig, Vector3(0.026, 0.008, 0.07), Vector3(0.0, 0.082, 0.07), back.darkened(0.1), Vector3(-0.35, 0.0, 0.0))   # tail

	for side in [-1.0, 1.0]:
		_ball(rig, 0.03, Vector3(0.35, 0.8, 1.7), Vector3(side * 0.036, 0.09, 0.02), back.darkened(0.15), Vector3(0.1, 0.0, side * -0.15))   # a folded wing
		_box(rig, Vector3(0.004, 0.05, 0.004), Vector3(side * 0.014, 0.035, 0.0), Color(0.35, 0.28, 0.2))   # a leg

	return root


# A frog (refs: common frog photographs): a squat olive-brown body with a pale throat, a broad blunt head with two big bulging eyes on top, folded hind legs bent in a Z, small front legs, a dark patch behind each eye.
# About 0.08 m long, sitting. Facing -Z.
func _make_frog() -> Node3D:      # the wet coat while this one builds
	_coat = "wet"
	var node: Node3D = _frog_body()
	_coat = "fur"
	return node


func _frog_body() -> Node3D:
	var root: Node3D = Node3D.new()
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var skin: Color = Color(0.42, 0.45, 0.2)
	_ball(rig, 0.03, Vector3(1.0, 0.8, 1.3), Vector3(0.0, 0.026, 0.01), skin)                         # body
	_ball(rig, 0.024, Vector3(1.1, 0.7, 1.0), Vector3(0.0, 0.03, -0.03), skin.lightened(0.05))        # head
	_ball(rig, 0.016, Vector3(1.0, 0.5, 1.0), Vector3(0.0, 0.016, -0.034), Color(0.85, 0.82, 0.6))    # pale throat

	for side in [-1.0, 1.0]:
		_ball(rig, 0.01, Vector3.ONE, Vector3(side * 0.014, 0.046, -0.034), Color(0.82, 0.7, 0.2))    # a bulging eye
		_ball(rig, 0.004, Vector3.ONE, Vector3(side * 0.014, 0.049, -0.043), Color(0.04, 0.04, 0.03))
		_ball(rig, 0.012, Vector3(0.6, 0.8, 1.1), Vector3(side * 0.025, 0.036, -0.012), Color(0.22, 0.2, 0.1))   # the dark patch behind the eye
		_ball(rig, 0.018, Vector3(0.7, 1.0, 1.4), Vector3(side * 0.03, 0.022, 0.025), skin.darkened(0.05))      # the folded thigh
		_box(rig, Vector3(0.01, 0.01, 0.045), Vector3(side * 0.03, 0.008, 0.05), skin.darkened(0.1))            # the long hind foot
		_box(rig, Vector3(0.008, 0.02, 0.008), Vector3(side * 0.018, 0.01, -0.025), skin)                       # a front leg

	return root


# A trout (refs: brown trout photographs): a long torpedo body, deepest ahead of the middle, a small head with a pale mouth, olive-brown back with dark and red spots, a golden-cream flank and belly, a fan tail,
# a dorsal fin and small side fins. About 0.35 m long. Facing -Z, swimming level.
func _make_fish() -> Node3D:      # the wet coat while this one builds
	_coat = "wet"
	var node: Node3D = _fish_body()
	_coat = "fur"
	return node


func _fish_body() -> Node3D:
	var root: Node3D = Node3D.new()
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var back: Color = Color(0.36, 0.34, 0.16)
	var flank: Color = Color(0.74, 0.62, 0.34)
	_ball(rig, 0.05, Vector3(0.9, 0.9, 3.2), Vector3(0.0, 0.0, 0.0), back)                            # body
	_ball(rig, 0.043, Vector3(0.9, 0.7, 3.0), Vector3(0.0, -0.014, 0.0), flank)                       # the paler flank and belly
	_ball(rig, 0.03, Vector3(0.9, 0.9, 1.5), Vector3(0.0, 0.0, -0.15), back.lightened(0.05))          # head
	_box(rig, Vector3(0.02, 0.006, 0.03), Vector3(0.0, -0.012, -0.19), Color(0.85, 0.8, 0.6))         # the mouth
	_ball(rig, 0.008, Vector3.ONE, Vector3(0.022, 0.012, -0.155), Color(0.03, 0.03, 0.03))            # eyes
	_ball(rig, 0.008, Vector3.ONE, Vector3(-0.022, 0.012, -0.155), Color(0.03, 0.03, 0.03))
	var tail: Node3D = Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0.0, 0.0, 0.14)
	rig.add_child(tail)
	_box(tail, Vector3(0.005, 0.02, 0.03), Vector3(0.0, 0.0, 0.012), back.darkened(0.1))                                  # the narrow tail root
	_box(tail, Vector3(0.004, 0.022, 0.05), Vector3(0.0, 0.016, 0.042), back.darkened(0.12), Vector3(0.55, 0.0, 0.0))   # the upper lobe of the forked tail, swept back
	_box(tail, Vector3(0.004, 0.022, 0.05), Vector3(0.0, -0.016, 0.042), back.darkened(0.12), Vector3(-0.55, 0.0, 0.0)) # the lower lobe
	_box(rig, Vector3(0.006, 0.03, 0.06), Vector3(0.0, 0.05, 0.01), back.darkened(0.1), Vector3(0.3, 0.0, 0.0))   # the dorsal fin

	for side in [-1.0, 1.0]:
		_box(rig, Vector3(0.025, 0.004, 0.035), Vector3(side * 0.045, -0.025, -0.07), flank.darkened(0.1), Vector3(0.0, side * 0.4, side * 0.3))   # a side fin

	# Spots painted on the skin (trout sheet 2 Nov: they stood up like studs and floated at the ends): small flat discs pressed onto the body
	# surface, dark over the back and upper flanks, a few red ones with a pale ring along the middle of each flank.
	for k in 14:
		var sp: float = -0.11 + 0.017 * float(k)
		var reach: float = sqrt(maxf(0.0, 1.0 - pow(sp / 0.16, 2.0)))       # the body's half-size here, as a share of the middle (radius 0.05 scaled 0.9, 0.9, 3.2)
		var a: float = 0.35 + 0.5 * float(k % 3)                              # round from the top of the back down the flank
		var side: float = 1.0 if k % 2 == 0 else -1.0
		var at: Vector3 = Vector3(side * sin(a) * 0.045 * reach, cos(a) * 0.045 * reach, sp)
		_ball(rig, 0.005, Vector3(1.2, 0.35, 1.2), at * 0.97, Color(0.12, 0.1, 0.06), Vector3(0.0, 0.0, -side * a))

		if k % 4 == 1:
			var red: Vector3 = Vector3(side * 0.045 * reach, -0.004, sp + 0.008)
			_ball(rig, 0.006, Vector3(0.35, 1.2, 1.2), red * 0.97, Color(0.85, 0.82, 0.7))      # the pale ring
			_ball(rig, 0.004, Vector3(0.4, 1.2, 1.2), red * 0.985, Color(0.75, 0.15, 0.1))      # the red spot

	return root


# A red grouse (refs: red and black grouse photographs): a plump ground bird, round chunky body held horizontally, a short thick neck and small head with a short curved beak and a red comb over the eye, a short
# rounded tail, feathered legs; rich reddish-brown barred plumage, darker on the back. About 0.38 m long. Facing -Z.
func _make_grouse() -> Node3D:
	var root: Node3D = Node3D.new()
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var plume: Color = Color(0.5, 0.2, 0.12)
	var dark: Color = Color(0.3, 0.14, 0.1)
	_ball(rig, 0.085, Vector3(0.85, 0.85, 1.3), Vector3(0.0, 0.14, 0.02), plume)                      # body
	_ball(rig, 0.075, Vector3(0.9, 0.5, 1.2), Vector3(0.0, 0.17, 0.03), dark)                         # the darker back
	_ball(rig, 0.05, Vector3(0.9, 1.0, 0.9), Vector3(0.0, 0.19, -0.09), plume)                        # the thick neck
	_ball(rig, 0.034, Vector3(0.9, 0.9, 1.0), Vector3(0.0, 0.23, -0.115), plume.lightened(0.05))      # the head
	_box(rig, Vector3(0.01, 0.014, 0.025), Vector3(0.0, 0.222, -0.15), Color(0.15, 0.1, 0.06), Vector3(0.2, 0.0, 0.0))   # the short beak
	_box(rig, Vector3(0.012, 0.01, 0.03), Vector3(0.022, 0.247, -0.12), Color(0.85, 0.1, 0.08))        # a red comb above each eye
	_box(rig, Vector3(0.012, 0.01, 0.03), Vector3(-0.022, 0.247, -0.12), Color(0.85, 0.1, 0.08))
	_ball(rig, 0.006, Vector3.ONE, Vector3(0.026, 0.236, -0.13), Color(0.03, 0.03, 0.03))
	_ball(rig, 0.006, Vector3.ONE, Vector3(-0.026, 0.236, -0.13), Color(0.03, 0.03, 0.03))
	_box(rig, Vector3(0.05, 0.012, 0.07), Vector3(0.0, 0.14, 0.14), dark, Vector3(-0.1, 0.0, 0.0))     # the short tail

	for k in 6:   # barring: pale flecks along the flank
		_ball(rig, 0.008, Vector3(1.6, 0.5, 1.0), Vector3(0.07 * float(k % 2 * 2 - 1), 0.14 + 0.012 * float(k % 3), -0.03 + 0.03 * float(k)), plume.lightened(0.35))

	for side in [-1.0, 1.0]:
		_ball(rig, 0.03, Vector3(0.45, 0.9, 1.7), Vector3(side * 0.07, 0.15, 0.03), dark.lightened(0.05), Vector3(0.0, 0.0, side * -0.1))   # a folded wing
		_box(rig, Vector3(0.012, 0.07, 0.012), Vector3(side * 0.03, 0.04, 0.0), Color(0.65, 0.45, 0.3))   # a feathered leg

	return root


# A grey seal (refs: grey and harbour seal photographs): a thick spindle body tapering to the hind flippers, a round head with a long blunt snout (grey seal) and big dark eyes, small whiskers, short front flippers
# set low, the hind flippers joined behind; silver-grey coat with dark blotches. About 1.8 m long, lying on the shore. Facing -Z.
func _make_seal() -> Node3D:      # the wet coat while this one builds
	_coat = "wet"
	var node: Node3D = _seal_body()
	_coat = "fur"
	return node


func _seal_body() -> Node3D:
	var root: Node3D = Node3D.new()
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var coat: Color = Color(0.55, 0.55, 0.52)
	_ball(rig, 0.28, Vector3(0.8, 0.7, 2.6), Vector3(0.0, 0.2, 0.0), coat)                            # the thick body
	_ball(rig, 0.2, Vector3(0.7, 0.55, 1.5), Vector3(0.0, 0.15, 0.45), coat.darkened(0.05))           # the tapering rear
	_ball(rig, 0.2, Vector3(0.95, 0.9, 1.0), Vector3(0.0, 0.3, -0.5), coat.lightened(0.04))           # the head
	_ball(rig, 0.1, Vector3(0.8, 0.7, 1.4), Vector3(0.0, 0.26, -0.68), coat.lightened(0.08))          # the long blunt snout
	_ball(rig, 0.025, Vector3(1.0, 0.9, 0.9), Vector3(0.0, 0.275, -0.78), Color(0.05, 0.04, 0.04))   # the nose
	_box(rig, Vector3(0.1, 0.01, 0.01), Vector3(0.0, 0.24, -0.76), Color(0.9, 0.88, 0.8))             # whiskers

	for side in [-1.0, 1.0]:
		_ball(rig, 0.03, Vector3.ONE, Vector3(side * 0.1, 0.36, -0.6), Color(0.04, 0.04, 0.04))      # a big dark eye
		_ball(rig, 0.1, Vector3(0.25, 0.5, 1.2), Vector3(side * 0.24, 0.1, -0.2), coat.darkened(0.15), Vector3(0.0, 0.0, side * -0.4))   # a front flipper set low
		_ball(rig, 0.1, Vector3(1.4, 0.35, 1.3), Vector3(side * 0.08, 0.09, 0.74), coat.darkened(0.2), Vector3(0.25, 0.0, 0.0))   # a hind flipper, joined to the rear and tipped up a little

	for k in 7:   # dark blotches pressed into the skin of the back and flanks: each sits on the body (or the rear) surface, so none hovers above it (pr64 sheet, 2 Nov 2026)
		var bx: float = 0.1 * float(k % 3 - 1)
		var bz: float = -0.3 + 0.13 * float(k)
		var body_top: float = 0.2 + 0.196 * sqrt(maxf(0.0, 1.0 - pow(bz / 0.728, 2.0) - pow(bx / 0.224, 2.0)))                    # the thick body: radius 0.28 scaled (0.8, 0.7, 2.6) at y 0.2
		var rear_top: float = 0.15 + 0.11 * sqrt(maxf(0.0, 1.0 - pow((bz - 0.45) / 0.3, 2.0) - pow(bx / 0.14, 2.0)))               # the rear: radius 0.2 scaled (0.7, 0.55, 1.5) at y 0.15, z 0.45
		_ball(rig, 0.045, Vector3(1.4, 0.3, 1.1), Vector3(bx, maxf(body_top, rear_top) - 0.01, bz), Color(0.28, 0.28, 0.27))

	return root


# A gull (refs: herring gull photographs): a sturdy white body with a grey back and wings folded to black-tipped points, a white head, a heavy yellow bill with a red spot, pale eyes, pink legs and webbed feet; standing.
# About 0.6 m long. Facing -Z.
func _make_seabird() -> Node3D:
	var root: Node3D = Node3D.new()
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var white: Color = Color(0.94, 0.94, 0.92)
	var grey: Color = Color(0.62, 0.66, 0.7)
	_ball(rig, 0.07, Vector3(0.85, 0.9, 1.6), Vector3(0.0, 0.2, 0.02), white)                         # body
	_ball(rig, 0.055, Vector3(0.9, 1.0, 1.0), Vector3(0.0, 0.25, -0.09), white)                       # the chest and neck
	_ball(rig, 0.04, Vector3(0.9, 0.9, 1.05), Vector3(0.0, 0.29, -0.115), white)                      # the head
	_box(rig, Vector3(0.016, 0.018, 0.06), Vector3(0.0, 0.282, -0.16), Color(0.95, 0.78, 0.15))       # the heavy yellow bill
	_box(rig, Vector3(0.008, 0.006, 0.008), Vector3(0.0, 0.272, -0.178), Color(0.8, 0.1, 0.08))       # the red spot
	_ball(rig, 0.006, Vector3.ONE, Vector3(0.022, 0.298, -0.135), Color(0.9, 0.85, 0.5))              # pale eyes
	_ball(rig, 0.006, Vector3.ONE, Vector3(-0.022, 0.298, -0.135), Color(0.9, 0.85, 0.5))
	_box(rig, Vector3(0.05, 0.012, 0.09), Vector3(0.0, 0.2, 0.16), white, Vector3(-0.25, 0.0, 0.0))   # the tail

	var folded: Node3D = Node3D.new()
	folded.name = "Folded"
	rig.add_child(folded)
	var legs: Node3D = Node3D.new()
	legs.name = "Legs"
	rig.add_child(legs)

	for side in [-1.0, 1.0]:
		_ball(folded, 0.045, Vector3(0.3, 0.8, 2.3), Vector3(side * 0.06, 0.215, 0.06), grey, Vector3(0.0, 0.0, side * -0.12))   # a folded grey wing
		_box(folded, Vector3(0.025, 0.01, 0.05), Vector3(side * 0.06, 0.22, 0.17), Color(0.08, 0.08, 0.1))                    # the black wing tip
		_box(legs, Vector3(0.008, 0.11, 0.008), Vector3(side * 0.025, 0.055, 0.0), Color(0.9, 0.55, 0.55))                  # a pink leg
		_box(legs, Vector3(0.03, 0.004, 0.04), Vector3(side * 0.025, 0.003, -0.015), Color(0.9, 0.55, 0.55))                # a webbed foot
		# The open wing for flight, hidden on the ground: a long grey arm wing hinged at the shoulder, a narrower hand wing with a black tip, about 0.9 m across both.
		var wing: Node3D = Node3D.new()
		wing.name = "Wing_L" if side < 0.0 else "Wing_R"
		wing.position = Vector3(side * 0.05, 0.225, -0.01)
		wing.visible = false
		rig.add_child(wing)
		_box(wing, Vector3(0.24, 0.012, 0.13), Vector3(side * 0.12, 0.0, 0.0), grey)                                     # the arm wing, broad
		_box(wing, Vector3(0.16, 0.01, 0.09), Vector3(side * 0.31, 0.0, 0.02), grey, Vector3(0.0, side * 0.15, 0.0))    # the hand wing, swept back
		_box(wing, Vector3(0.07, 0.008, 0.07), Vector3(side * 0.41, 0.0, 0.04), Color(0.08, 0.08, 0.1), Vector3(0.0, side * 0.25, 0.0))   # the black tip
		_box(wing, Vector3(0.22, 0.004, 0.02), Vector3(side * 0.13, -0.004, 0.065), white)                               # the white trailing edge

	return root


# A gull flock (MikeW's seabird flock block, 2 Nov 2026): 5 to 12 gulls standing loosely on the beach over a few metres, each turned its own way; the
# whole flock is one wire record. In state 15 every gull opens its wings and flaps (_animate_gulls); the record itself rises and flies.
func _make_gull_flock(id: int) -> Node3D:
	var root: Node3D = Node3D.new()
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = id * 6151

	for k in 5 + id % 8:
		var single: Node3D = _make_seabird()
		var gull: Node3D = single.get_node("Rig")
		single.remove_child(gull)
		single.free()
		gull.name = "Gull%d" % k
		gull.position = Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-3.0, 3.0))
		gull.rotation.y = rng.randf_range(-0.6, 0.6)      # mostly facing the same way (into the wind), not stamped
		gull.set_meta("phase", rng.randf() * TAU)
		gull.set_meta("ground", gull.position)
		rig.add_child(gull)

	return root


# Flying gulls: wings open and flap (each its own beat, about 3 beats a second, a short glide now and then), legs tucked, folded wings hidden;
# in flight the birds draw in a little and spread in height so the flock reads as a loose group, not a flat plate. On the ground they stand.
func _animate_gulls(rig: Node3D, flying: bool) -> void:
	for gull in rig.get_children():
		var phase: float = float(gull.get_meta("phase", 0.0))
		var ground: Vector3 = gull.get_meta("ground", gull.position)
		gull.get_node("Folded").visible = not flying
		gull.get_node("Legs").visible = not flying
		var target: Vector3 = Vector3(ground.x * 0.7, 0.6 + 0.8 * (0.5 + 0.5 * sin(phase * 3.0)), ground.z * 0.7) if flying else ground
		gull.position = gull.position.lerp(target, 0.05)

		for side in [-1.0, 1.0]:
			var wing: Node3D = gull.get_node("Wing_L" if side < 0.0 else "Wing_R")
			wing.visible = flying

			if flying:
				var beat: float = sin(_t * 19.0 + phase)
				var glide: bool = sin(_t * 0.7 + phase) > 0.7
				wing.rotation.z = side * (0.12 if glide else 0.55 * beat)      # up and down, mirrored; held almost level while gliding


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at
	inst.rotation = rot
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)


# The wolf (Dave 2026-10-21): about 1.3 m of body and 0.8 m at the shoulder, grey with a pale belly and muzzle, a deep chest, a thick neck, a
# long snout, upright ears, a bushy tail and four legs on pivots so they can walk, trot, run and kick. Facing -Z. The pieces are named for
# `_animate_wolf`: Rig (everything that rolls and crouches), Head, Tail, Leg_FL, Leg_FR, Leg_HL, Leg_HR.
func _make_wolf() -> Node3D:
	var root: Node3D = Node3D.new()
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var coat: Color = Color(0.36, 0.35, 0.33)
	var dark: Color = Color(0.24, 0.23, 0.22)
	var pale: Color = Color(0.72, 0.69, 0.63)
	_ball(rig, 0.25, Vector3(0.95, 1.15, 1.45), Vector3(0.0, 0.55, -0.18), coat)     # chest and shoulders, deep (round 3: deeper, Kathleen's critique)
	_ball(rig, 0.145, Vector3(0.9, 0.95, 1.5), Vector3(0.0, 0.56, 0.28), coat)       # hips (smaller: a tucked waist and a straight back, not two equal blobs)
	_ball(rig, 0.13, Vector3(0.85, 0.6, 1.7), Vector3(0.0, 0.46, 0.0), pale)         # belly, tucked up toward the hips
	_ball(rig, 0.17, Vector3(0.9, 0.8, 1.0), Vector3(0.0, 0.68, -0.36), dark)       # mane over the shoulders
	var neck: Node3D = Node3D.new()
	neck.name = "Head"
	neck.position = Vector3(0.0, 0.6, -0.42)
	rig.add_child(neck)
	_ball(neck, 0.15, Vector3(0.9, 0.9, 1.5), Vector3(0.0, 0.04, -0.12), coat)     # neck (thicker, Kathreen 2 Nov: it read as a thin stalk)
	_ball(neck, 0.135, Vector3(0.95, 0.9, 1.0), Vector3(0.0, 0.06, -0.3), coat)      # head (bigger: it was a small ball on a long body)
	_ball(neck, 0.06, Vector3(0.9, 0.75, 2.2), Vector3(0.0, 0.04, -0.46), coat)      # muzzle: tapers forward, grey on top (round 3: it was a pale box)
	_ball(neck, 0.045, Vector3(0.85, 0.5, 2.0), Vector3(0.0, 0.0, -0.45), pale)      # pale only underneath: chin and lips
	_ball(neck, 0.022, Vector3(1.2, 0.9, 1.0), Vector3(0.0, 0.06, -0.58), Color(0.08, 0.07, 0.07))   # nose

	for side in [-1.0, 1.0]:
		_ball(neck, 0.05, Vector3(1.0, 1.6, 0.3), Vector3(side * 0.065, 0.2, -0.28), dark, Vector3(-0.15, 0.0, side * -0.2))   # ears: wide upright triangles (round 3: a thin stick from the side)
		_ball(neck, 0.018, Vector3.ONE, Vector3(side * 0.055, 0.09, -0.4), Color(0.9, 0.7, 0.2))                        # eyes

	var tail: Node3D = Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0.0, 0.6, 0.42)
	rig.add_child(tail)
	_ball(tail, 0.1, Vector3(0.85, 0.85, 2.6), Vector3(0.0, -0.08, 0.2), coat, Vector3(0.7, 0.0, 0.0))
	_ball(tail, 0.05, Vector3(0.8, 0.8, 1.6), Vector3(0.0, -0.2, 0.36), dark, Vector3(0.7, 0.0, 0.0))

	for leg in [["Leg_FL", -1.0, -0.26], ["Leg_FR", 1.0, -0.26], ["Leg_HL", -1.0, 0.3], ["Leg_HR", 1.0, 0.3]]:
		var pivot: Node3D = Node3D.new()
		pivot.name = leg[0]
		pivot.position = Vector3(float(leg[1]) * 0.1, 0.44, float(leg[2]))   # round 2 (Kathreen 2 Nov): legs 6 cm shorter and the body 6 cm lower, they read as stilts
		rig.add_child(pivot)
		# Round 3 (Kathleen's critique: square posts with block feet): tapered ellipsoids, the hind leg bent back at the hock, the front pastern sloping forward, an oval paw.
		var hind: bool = String(leg[0]).begins_with("Leg_H")
		if hind:
			_ball(pivot, 0.075, Vector3(0.9, 1.9, 1.25), Vector3(0.0, -0.1, 0.02), coat, Vector3(-0.35, 0.0, 0.0))     # thigh, sloping back to the hock
			_ball(pivot, 0.035, Vector3(1.0, 2.7, 1.0), Vector3(0.0, -0.3, 0.05), dark, Vector3(0.2, 0.0, 0.0))        # shank from the hock down and a little forward
		else:
			_ball(pivot, 0.06, Vector3(0.95, 2.1, 1.05), Vector3(0.0, -0.12, 0.0), coat)                               # forearm
			_ball(pivot, 0.033, Vector3(1.0, 2.6, 1.0), Vector3(0.0, -0.31, -0.01), dark, Vector3(-0.15, 0.0, 0.0))   # pastern sloping forward
		_ball(pivot, 0.04, Vector3(1.0, 0.5, 1.5), Vector3(0.0, -0.42, -0.025), dark)                                  # paw

	return root


# The wolf's legs, head and tail follow what it does: legs swing with the real ground speed (walk, trot, gallop), the head sinks to sniff or
# stalk, the tail wags at play and hangs low when stalking, a roll kicks the legs up. `speed` is metres a second.
func _animate_wolf(node: Node3D, b: Dictionary, state: int, speed: float, delta: float) -> void:
	var rig: Node3D = node.get_node("Rig")
	var head: Node3D = rig.get_node("Head")
	var tail: Node3D = rig.get_node("Tail")
	var gallop: float = clampf((speed - 2.5) / 3.5, 0.0, 1.0)
	b["gait"] = float(b.get("gait", 0.0)) + speed * delta * lerpf(2.6, 1.8, gallop)
	var amp: float = clampf(speed / 1.8, 0.0, 1.0) * lerpf(0.5, 0.95, gallop)
	var swing: float = sin(float(b["gait"]) * TAU * 0.5)
	var rolling: bool = state == 8
	var kick: float = sin(_t * 9.0) * 0.6 if rolling else 0.0
	var legs: Dictionary = {"Leg_FL": swing, "Leg_HR": swing, "Leg_FR": -swing, "Leg_HL": -swing}

	if gallop > 0.5:
		legs = {"Leg_FL": swing, "Leg_FR": swing * 0.9, "Leg_HL": -swing, "Leg_HR": -swing * 0.9}      # bounding: the pairs move together

	for leg in legs:
		var pivot: Node3D = rig.get_node(leg)
		var target: float = float(legs[leg]) * amp + (kick * (1.0 if leg.ends_with("L") else -1.0) + 1.2 if rolling else 0.0)
		pivot.rotation.x = lerpf(pivot.rotation.x, target, clampf(delta * 18.0, 0.0, 1.0))

	var head_down: float = 0.0

	if state == 6:
		head_down = 0.55          # stalking: head low, eyes on the prey
	elif state == 0 and speed < 0.3:
		head_down = 0.35 + 0.15 * sin(_t * 1.3 + float(b["phase"]))      # grazing wolf: nose to the ground, sniffing
	elif state == 3:
		head_down = -0.25         # alert: head high
	elif state == 7 or gallop > 0.5:
		head_down = 0.1

	head.rotation.x = lerpf(head.rotation.x, -(head_down + 0.04 * swing * amp), clampf(delta * 8.0, 0.0, 1.0))
	var tail_target: float = 0.2
	var tail_wag: float = 0.0

	if state == 6:
		tail_target = -0.2        # low and straight
	elif state == 9:
		tail_target = 0.5
		tail_wag = sin(_t * 12.0) * 0.5
	elif gallop > 0.5:
		tail_target = -0.35       # streaming behind

	tail.rotation.x = lerpf(tail.rotation.x, tail_target, clampf(delta * 6.0, 0.0, 1.0))
	tail.rotation.y = lerpf(tail.rotation.y, tail_wag, clampf(delta * 10.0, 0.0, 1.0))
	# Crouch low when stalking, bob with the stride, play bow (front down, hips up) when playing.
	var crouch: float = -0.12 if state == 6 else 0.0
	var bob: float = absf(sin(float(b["gait"]) * TAU * 0.5)) * 0.04 * amp
	rig.position.y = lerpf(rig.position.y, crouch + bob + (0.06 if state == 9 else 0.0), clampf(delta * 10.0, 0.0, 1.0))


# A flock of ducks for now (placeholder until Art): 6 to 13 small birds spread over a few metres (one wire record per flock).
# State 3 heads up, 15 in the air (the whole flock rises and leans forward).
func _make_flock(id: int) -> Node3D:
	var root: Node3D = Node3D.new()
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = id * 7919

	for k in 6 + id % 8:
		var at: Vector3 = Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-3.0, 3.0))
		var drake: bool = k % 2 == 0      # drakes: green head, white neck ring, grey flanks; hens: plain mottled brown
		_ball(rig, 0.16, Vector3(0.8, 0.7, 1.4), at + Vector3(0.0, 0.1, 0.0), Color(0.5, 0.5, 0.52) if drake else Color(0.45, 0.36, 0.26))
		_ball(rig, 0.055, Vector3(0.9, 1.4, 0.9), at + Vector3(0.0, 0.24, -0.16), Color(0.92, 0.9, 0.86) if drake else Color(0.45, 0.36, 0.26))   # neck
		_ball(rig, 0.07, Vector3.ONE, at + Vector3(0.0, 0.32, -0.2), Color(0.12, 0.34, 0.2) if drake else Color(0.4, 0.31, 0.22))
		_box(rig, Vector3(0.05, 0.02, 0.09), at + Vector3(0.0, 0.31, -0.29), Color(0.9, 0.68, 0.15))                            # bill

	return root


# Fox, horse and moose share one four-legged build (Mandy 2026-10-22). `spec` sizes it: leg_h (hip height), rb (body radius), len (shoulder to
# hip), neck, head (head length), coat, dark, pale, plus flags hump, mane, antlers, bushy, snout. Facing -Z. Pieces named for `_animate_quad`: Rig,
# Head (neck and head), Ear_L, Ear_R, Tail, Leg_FL, Leg_FR, Leg_HL, Leg_HR.
func _make_quad(spec: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	root.set_meta("quad", true)
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var leg_h: float = float(spec["leg_h"])
	var rb: float = float(spec["rb"])
	var half: float = float(spec["len"]) * 0.5
	var nk: float = float(spec["neck"])
	var hd: float = float(spec["head"])
	var coat: Color = spec["coat"]
	var dark: Color = spec["dark"]
	var pale: Color = spec["pale"]
	var back: float = leg_h + rb * 0.8
	rig.set_meta("leg_h", leg_h)
	_ball(rig, rb, Vector3(0.85, 1.0, 1.5), Vector3(0.0, leg_h + rb * 0.35, -half * 0.45), coat)       # chest
	_ball(rig, rb * 0.95, Vector3(0.85, 0.95, 1.5), Vector3(0.0, leg_h + rb * 0.3, half * 0.5), coat)  # hips
	_ball(rig, rb * 0.8, Vector3(0.8, 0.8, 2.2), Vector3(0.0, leg_h + rb * 0.15, 0.0), pale if bool(spec.get("pale_belly", true)) else coat)   # belly
	# The barrel (cloud render 4 Nov: chest and hips read as two separate lumps with a pinched waist): one long ball fills the back between them.
	_ball(rig, rb * 0.92, Vector3(0.86, 0.97, 1.9), Vector3(0.0, leg_h + rb * 0.33, 0.0), coat)

	if bool(spec.get("hump", false)):
		_ball(rig, rb * 0.7, Vector3(0.8, 0.9, 1.3), Vector3(0.0, back + rb * 0.2, -half * 0.55), coat.lerp(dark, 0.45))   # shoulder hump (coat shading into dark: all-dark it read as a second animal lying on the back)

	var head: Node3D = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, back - rb * 0.1, -half * 0.8)
	rig.add_child(head)
	for seg in 9:   # the neck: nine close, long, thinning segments from the shoulder to the skull (five read as a stack of rings on the deer, cloud render 4 Nov)
		var t: float = float(seg) / 8.0
		_ball(head, nk * lerpf(0.27, 0.19, t) * float(spec.get("neck_thick", 1.0)), Vector3(0.85, 0.85, 1.6), Vector3(0.0, lerpf(nk * 0.1, nk * 0.7, t), lerpf(-nk * 0.08, -nk * 0.75, t)), coat, Vector3(0.7, 0.0, 0.0))
	var top: Vector3 = Vector3(0.0, nk * 0.78, -nk * 0.85)
	_ball(head, hd * 0.28, Vector3(0.85, 0.9, 1.4), top, coat if not bool(spec.get("dark_head", false)) else dark)       # skull
	var snout: float = float(spec.get("snout", 1.0))
	_ball(head, hd * 0.2, Vector3(0.75, 0.7, 1.3), top + Vector3(0.0, -hd * 0.12, -hd * 0.12), coat if not bool(spec.get("dark_head", false)) else dark)       # jaw and cheek: the head tapers to the muzzle
	var muzzle: Color = pale if bool(spec.get("pale_snout", false)) else dark
	_ball(head, hd * 0.2, Vector3(0.75, 0.62, 1.7 * snout), top + Vector3(0.0, -hd * 0.1, -hd * 0.4 * snout), muzzle)      # the muzzle tapers to the nose, not a box
	_ball(head, hd * 0.08, Vector3(1.0, 0.8, 0.8), top + Vector3(0.0, -hd * 0.06, -hd * 0.4 * snout - hd * 0.34 * snout), Color(0.05, 0.04, 0.04))      # the nose
	_ball(head, hd * 0.05, Vector3.ONE, top + Vector3(0.1 * hd, hd * 0.12, -hd * 0.18), Color(0.05, 0.04, 0.04))        # eyes
	_ball(head, hd * 0.05, Vector3.ONE, top + Vector3(-0.1 * hd, hd * 0.12, -hd * 0.18), Color(0.05, 0.04, 0.04))

	for side in [-1.0, 1.0]:
		var ear: Node3D = Node3D.new()
		ear.name = "Ear_L" if side < 0.0 else "Ear_R"
		ear.position = top + Vector3(side * hd * 0.2, hd * 0.2, hd * 0.1)
		head.add_child(ear)
		if bool(spec.get("round_ears", false)):
			_ball(ear, hd * 0.11, Vector3(1.0, 1.0, 0.45), Vector3(0.0, hd * 0.08, 0.0), coat.lerp(dark, 0.4))      # a bear's small round ear
		else:
			_ball(ear, hd * 0.13, Vector3(0.4, 1.7 * float(spec.get("ear", 1.0)), 0.22), Vector3(0.0, hd * 0.17 * float(spec.get("ear", 1.0)), 0.0), dark, Vector3(0.0, 0.0, side * -0.35))      # a leaf-shaped ear

		if bool(spec.get("antlers", false)):
			# Bull moose: broad flat palms swept out and up from above the ears, with tines along the rim.
			_box(head, Vector3(hd * 1.1, hd * 0.09, hd * 0.55), top + Vector3(side * hd * 0.75, hd * 0.4, 0.0), Color(0.72, 0.66, 0.54), Vector3(0.0, side * 0.3, side * -0.25))
			# Kathreen 2 Nov: the palms floated beside the head as flat slabs; a beam from the skull now carries each one.
			_box(head, Vector3(hd * 0.1, hd * 0.1, hd * 0.55), top + Vector3(side * hd * 0.3, hd * 0.25, 0.0), Color(0.62, 0.56, 0.45), Vector3(0.0, 0.0, side * -0.75))

			for tine in 4:
				_box(head, Vector3(hd * 0.05, hd * 0.05, hd * 0.3), top + Vector3(side * hd * (0.7 + 0.2 * float(tine)), hd * 0.48, -hd * 0.3 + hd * 0.2 * float(tine)), Color(0.72, 0.66, 0.54), Vector3(0.0, side * 0.2, 0.0))

	if bool(spec.get("mane", false)):
		_box(head, Vector3(hd * 0.06, nk * 0.6, hd * 0.25), Vector3(0.0, nk * 0.55, -nk * 0.4), dark, Vector3(0.7, 0.0, 0.0))

	# Goal 2 batch A details, all children of existing nodes (names and animation unchanged): nostrils, then per species marks.
	_ball(head, hd * 0.045, Vector3(1.0, 0.7, 0.7), top + Vector3(hd * 0.08, -hd * 0.1, -hd * 0.45 * snout - hd * 0.28 * snout), Color(0.04, 0.03, 0.03))
	_ball(head, hd * 0.045, Vector3(1.0, 0.7, 0.7), top + Vector3(-hd * 0.08, -hd * 0.1, -hd * 0.45 * snout - hd * 0.28 * snout), Color(0.04, 0.03, 0.03))

	if bool(spec.get("blaze", false)):
		_box(head, Vector3(hd * 0.1, hd * 0.05, hd * 0.8), top + Vector3(0.0, hd * 0.14, -hd * 0.3), pale, Vector3(-0.15, 0.0, 0.0))      # a white stripe down the face

	if bool(spec.get("bell", false)):
		_ball(head, hd * 0.12, Vector3(0.6, 1.8, 0.6), top + Vector3(0.0, -hd * 0.55, hd * 0.12), dark)      # the moose's dangling bell under the throat

	if bool(spec.get("tines", false)):
		# A deer's antlers: a main beam sweeping up and back from each side with three tines.
		for side in [-1.0, 1.0]:
			var beam: Vector3 = top + Vector3(side * hd * 0.22, hd * 0.3, hd * 0.12)
			_box(head, Vector3(hd * 0.05, hd * 0.9, hd * 0.05), beam + Vector3(side * hd * 0.1, hd * 0.4, hd * 0.2), Color(0.76, 0.7, 0.58), Vector3(0.45, 0.0, side * -0.25))

			for tine in 3:
				_box(head, Vector3(hd * 0.035, hd * 0.3, hd * 0.035), beam + Vector3(side * hd * (0.12 + 0.05 * float(tine)), hd * (0.25 + 0.22 * float(tine)), hd * (0.12 + 0.08 * float(tine))), Color(0.76, 0.7, 0.58), Vector3(-0.3, 0.0, side * 0.5))

	if bool(spec.get("rump", false)):
		_ball(rig, rb * 0.6, Vector3(0.8, 0.9, 0.5), Vector3(0.0, leg_h + rb * 0.4, half * 0.5 + rb * 0.8), pale)      # the pale rump patch

	var tail: Node3D = Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0.0, leg_h + rb * 0.7, half * 0.9)
	rig.add_child(tail)

	if bool(spec.get("bushy", false)):
		_ball(tail, rb * 0.95, Vector3(0.7, 0.7, 2.3), Vector3(0.0, -rb * 0.3, rb * 1.3), coat, Vector3(0.45, 0.0, 0.0))      # a fox brush: long, thickest in the middle
		_ball(tail, rb * 0.55, Vector3(0.7, 0.7, 1.3), Vector3(0.0, -rb * 0.75, rb * 2.55), Color(0.92, 0.9, 0.86), Vector3(0.45, 0.0, 0.0))
	elif bool(spec.get("long_tail", false)):
		_box(tail, Vector3(rb * 0.3, leg_h * 0.95, rb * 0.2), Vector3(0.0, -leg_h * 0.45, rb * 0.2), dark, Vector3(0.12, 0.0, 0.0))      # a horse's tail hangs nearly to the hocks
		_box(tail, Vector3(rb * 0.2, leg_h * 0.5, rb * 0.15), Vector3(rb * 0.12, -leg_h * 0.62, rb * 0.28), dark, Vector3(0.18, 0.0, 0.1))
	else:
		_box(tail, Vector3(rb * 0.12, leg_h * 0.5, rb * 0.12), Vector3(0.0, -leg_h * 0.22, rb * 0.1), dark, Vector3(0.1, 0.0, 0.0))

	for leg in [["Leg_FL", -1.0, -half * 0.8], ["Leg_FR", 1.0, -half * 0.8], ["Leg_HL", -1.0, half * 0.8], ["Leg_HR", 1.0, half * 0.8]]:
		var pivot: Node3D = Node3D.new()
		pivot.name = leg[0]
		pivot.position = Vector3(float(leg[1]) * rb * 0.55, leg_h, float(leg[2]))
		rig.add_child(pivot)
		var w: float = rb * 0.3 * float(spec.get("leg_w", 1.0))   # leg_w: a bear's legs are thick pillars, not a deer's sticks
		# Shoulder and haunch: a long muscle tapering down the upper leg into the body, so the leg grows out of it instead of a stick under a ball (cloud render 4 Nov).
		_ball(pivot, w * 1.0, Vector3(1.0, 2.4, 1.3 if String(leg[0]).begins_with("Leg_F") else 1.7), Vector3(0.0, -leg_h * 0.12, 0.0), coat)
		_box(pivot, Vector3(w, leg_h * 0.5, w), Vector3(0.0, -leg_h * 0.24, 0.0), coat)
		_ball(pivot, w * 0.55, Vector3.ONE, Vector3(0.0, -leg_h * 0.5, 0.0), coat.lerp(dark, 0.5))   # the knee or hock joint
		_box(pivot, Vector3(w * 0.7, leg_h * 0.5, w * 0.7), Vector3(0.0, -leg_h * 0.74, 0.0), dark if not bool(spec.get("socks", false)) else pale)
		_box(pivot, Vector3(w * 0.9, leg_h * 0.06, w * 1.2), Vector3(0.0, -leg_h * 0.98, -w * 0.1), Color(0.12, 0.1, 0.09))      # hoof

	return root


# Legs swing with the real ground speed; the head sinks to graze, lifts to watch, lowers to warn; ears go forward when alert and flat when
# warning; the front hoof stamps at a warn (10, the moose telegraph: head low, ears flat, one fore hoof pawing, unmistakable); a charge (11)
# gallops with the head low; a recover (12) stands blowing, the chest heaving. `speed` is metres a second.
func _animate_quad(node: Node3D, b: Dictionary, state: int, speed: float, delta: float) -> void:
	var rig: Node3D = node.get_node("Rig")
	var head: Node3D = rig.get_node("Head")
	var tail: Node3D = rig.get_node("Tail")
	var leg_h: float = float(rig.get_meta("leg_h"))
	var gallop: float = clampf((speed - 3.0) / 4.0, 0.0, 1.0)
	b["gait"] = float(b.get("gait", 0.0)) + speed * delta / (leg_h * lerpf(1.8, 1.3, gallop))
	var amp: float = clampf(speed / 1.2, 0.0, 1.0) * lerpf(0.45, 0.85, gallop)
	var swing: float = sin(float(b["gait"]) * TAU * 0.5)
	var legs: Dictionary = {"Leg_FL": swing, "Leg_HR": swing, "Leg_FR": -swing, "Leg_HL": -swing}

	if gallop > 0.5:
		legs = {"Leg_FL": swing, "Leg_FR": swing * 0.9, "Leg_HL": -swing, "Leg_HR": -swing * 0.9}

	for leg in legs:
		var pivot: Node3D = rig.get_node(leg)
		var target: float = float(legs[leg]) * amp

		if state == 10 and leg == "Leg_FR":
			target = -0.9 + 0.9 * maxf(0.0, sin(_t * 9.0))      # paws and stamps the ground
		elif state == 10 and leg == "Leg_FL":
			target = -0.2 * maxf(0.0, sin(_t * 9.0 + 3.1))

		pivot.rotation.x = lerpf(pivot.rotation.x, target, clampf(delta * 18.0, 0.0, 1.0))

	var head_down: float = 0.0

	if state == 0 and speed < 0.3:
		head_down = 0.9 + 0.08 * sin(_t * 0.9 + float(b["phase"]))      # grazing
	elif state == 3:
		head_down = -0.35
	elif state == 10:
		head_down = 0.75 + 0.1 * sin(_t * 9.0)
	elif state == 11 or gallop > 0.5:
		head_down = 0.45
	elif state == 12:
		head_down = 0.2 + 0.1 * sin(_t * 3.5)

	head.rotation.x = lerpf(head.rotation.x, -(head_down + 0.05 * swing * amp), clampf(delta * 8.0, 0.0, 1.0))
	var ear_back: float = 1.2 if state == 10 or state == 11 else (-0.3 if state == 3 else 0.2 * sin(_t * 0.7 + float(b["phase"]) * 9.0) * (1.0 if state == 0 else 0.0))

	for ear_name in ["Ear_L", "Ear_R"]:
		var ear: Node3D = head.get_node(ear_name)
		ear.rotation.x = lerpf(ear.rotation.x, ear_back, clampf(delta * 12.0, 0.0, 1.0))

	var tail_target: float = -0.4 if gallop > 0.5 else (0.15 + 0.1 * sin(_t * 2.0 + float(b["phase"])))
	tail.rotation.x = lerpf(tail.rotation.x, tail_target, clampf(delta * 6.0, 0.0, 1.0))
	var bob: float = absf(swing) * leg_h * 0.04 * amp
	var heave: float = 0.012 * sin(_t * 7.0) * leg_h if state == 12 else 0.0
	rig.position.y = lerpf(rig.position.y, bob + heave, clampf(delta * 10.0, 0.0, 1.0))


# A fox (Mandy 2026-10-22): small, rusty red, pale belly and muzzle, dark socks, big bushy white-tipped brush. State 13 creeps low, 14 runs with food.
func _make_fox() -> Node3D:
	return _make_quad({"leg_h": 0.22, "rb": 0.1, "len": 0.5, "neck": 0.16, "head": 0.2, "snout": 1.3, "pale_belly": false, "coat": Color(0.72, 0.34, 0.12), "dark": Color(0.2, 0.12, 0.08), "pale": Color(0.93, 0.88, 0.8), "pale_snout": true, "bushy": true})


# A horse (Mandy 2026-10-22): coat chosen from the animal id (bay, chestnut, grey, black, dun), dark mane and tail. Foals and harness come later.
func _make_horse(id: int) -> Node3D:
	var coats: Array = [[Color(0.36, 0.2, 0.11), Color(0.08, 0.06, 0.05)], [Color(0.5, 0.26, 0.12), Color(0.34, 0.17, 0.08)], [Color(0.66, 0.66, 0.64), Color(0.45, 0.45, 0.44)], [Color(0.1, 0.09, 0.09), Color(0.05, 0.04, 0.04)], [Color(0.62, 0.5, 0.32), Color(0.2, 0.14, 0.09)]]
	var pick: Array = coats[id % coats.size()]
	return _make_quad({"leg_h": 0.85, "rb": 0.32, "len": 1.05, "neck": 0.66, "neck_thick": 1.45, "head": 0.6, "snout": 1.2, "coat": pick[0], "dark": pick[1], "pale": pick[0].lerp(Color(0.9, 0.85, 0.78), 0.25), "mane": true, "socks": false, "long_tail": true, "blaze": id % 3 == 0})


# A brown bear (Dave 6 Nov 2026; FAUNA_BY_BIOME): the shared four-legged build, heavy and low. About 2 m long, 1 m at the shoulder hump, a broad
# head on a short neck with a short snout, small round ears, thick dark brown coat a shade paler on the head and hump, no tail to speak of.
func _make_bear() -> Node3D:
	# Brown bear (PC look 6 Nov: the first build read as a blob on wheels with horns): shoulder about 1.1 m, legs showing about half of
	# that under the belly, thick legs, a big head with a short snout and small round ears, the shoulder hump.
	return _make_quad({"leg_h": 0.75, "rb": 0.45, "len": 1.2, "neck": 0.3, "head": 0.62, "snout": 0.8, "leg_w": 1.6, "round_ears": true, "coat": Color(0.27, 0.18, 0.11), "dark": Color(0.16, 0.11, 0.07), "pale": Color(0.4, 0.3, 0.2), "hump": true, "socks": false, "pale_belly": false})


# A moose (Mandy 2026-10-22): about 2.7 m long, 2.1 m at the shoulder hump, dark brown, long pale legs, big drooping muzzle; every second one is a bull with broad antlers.
func _make_moose(id: int) -> Node3D:
	return _make_quad({"leg_h": 1.15, "rb": 0.5, "len": 1.4, "neck": 0.8, "head": 0.65, "snout": 1.2, "coat": Color(0.2, 0.14, 0.1), "dark": Color(0.12, 0.09, 0.07), "pale": Color(0.4, 0.33, 0.27), "hump": true, "socks": true, "antlers": id % 2 == 0, "pale_belly": false, "bell": true})


# A deer (goal 2 batch A, Kathleen): the shared four-legged build, so it walks, grazes and watches like the others. About 1.5 m long, 1.2 m to the back, tan coat, pale belly and rump,
# a stag's branched antlers on every second one (by id).
func _make_deer(id: int = 0) -> Node3D:
	return _make_quad({"leg_h": 0.62, "rb": 0.22, "len": 1.05, "neck": 0.42, "head": 0.32, "snout": 1.1, "pale_belly": false, "coat": Color(0.52, 0.38, 0.24), "dark": Color(0.32, 0.23, 0.15), "pale": Color(0.9, 0.85, 0.77), "rump": true, "tines": id % 2 == 0, "socks": false})
