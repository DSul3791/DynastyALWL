extends Node3D

const FrameProbe := preload("res://src/debug/frame_probe.gd")

# Animals on the client (protocol 48): a simple rabbit until Art makes a real one (brown body, head, two ears, white
# tail). The server sends rows about four times a second; the view draws each between the sent points (motion_buffer.gd), faces the way it goes and hops while moving
# (higher and quicker when it bolts). At most MAX_DRAWN are drawn, the nearest ones (the server already sends only 30: within 120 m, big game within 200 m).

const MAX_DRAWN := 30
const FAR_KEEP_M := 110.0       # big game past the 120 m send radius comes in every other batch (R-ANIMAL-SEEN-FAR, terrain_server): a body this
const FAR_KEEP_MS := 1200       # far off that a batch left out is kept this long since its last row, not freed and drawn again
const SPYGLASS_DRAWN := 60      # while an admin looks through the spyglass the server sends up to 60 within 300 m (animals.json "spyglass")
const MODELS_PATH := "res://data/animals/models.json"
const BoneOffsetsScript := preload("res://src/client/bone_offsets.gd")
const HeadLookScript := preload("res://src/client/head_look.gd")       # the head turns to watch a player (docs/design/ANIMAL_GAIT.md "Head tracking")
const BreathLook := preload("res://src/client/breath_look.gd")   # head_bone_of: where an animal breathes from in the cold
const MotionBuffer := preload("res://src/client/motion_buffer.gd")   # drawn between sent points, a little behind (Dave 19 Nov 2026)
const AnimalContact := preload("res://src/shared/animal_contact.gd")   # how near a body comes to the player (data/animals/contact.json)
const AnimalGait := preload("res://src/client/animal_gait.gd")   # which leg clip and how fast, smoothed (Dave 21 Nov 2026: no running without moving the feet)
const BanditLook := preload("res://src/client/bandit_look.gd")   # camp bandits (species 52) are drawn as the human ragdoll (docs/design/BANDIT_CAMPS.md)
const FreezeWatchScript := preload("res://src/debug/freeze_watch.gd")
const LIE := 19        # lying down to rest: a companion at heel, or a wild grazer bedded down (protocol 148)
const TETHERED := 22   # a horse tethered at a bandit camp: its saddle is shown (server_bandits.gd)
const GRAZE := 0
const HOP := 1
const FLEE := 2
const CHARGE := 11                    # server_big_game.CHARGE: a locked charge (AHEAD_STATES)
const LUNGE_STATES := [11, 12]         # charge and recover: a lunge that came already done is eased on at MotionBuffer.LUNGE_MPS
const DRINK := 21                     # server_animals.DRINK: standing at the bank drinking (docs/design/animals_at_water_server.md)
const DRINK_SLOT_S := 17.0            # drinking, the head comes up once a slot: after 6 to 14 s, for 1.5 to 3 s (so 6 to 24 s between looks)

signal state_changed(kind: String, state: int, at: Vector3, body: Node3D)     # an animal alerts, flees, warns or charges (sounds listen; the call follows its body)
signal took_off(kind: String, at: Vector3)                       # a bird bursts up into flight (server_flight.FLY): its wings, where it rose (creature_sounds.took_off)
signal stepped(kind: String, at: Vector3)                       # a hoof or paw lands (each whole count of the gait; a rabbit hop lands): the step sounds listen
signal fell(kind: String, at: Vector3, small: bool)            # an animal went down from a hit: it vanished right after a hit landed on it (sounds listen)

# Species numbers 8 to 13 were missing, so their voices and footsteps never fired (Kathreen, 2 Nov 2026). The sound side (creature_sounds.gd KINDS, the `<kind>_step` slots in
# data/sound/batch1_slots.json) skips a kind it has no clip for, so these stay silent until Jason adds the clips; the names here are the ones to use.
const KIND_OF_SPECIES := {1: "rabbit", 2: "deer", 3: "wolf", 4: "moose", 5: "fox", 6: "duck", 7: "horse", 8: "boar", 9: "songbird", 10: "frog", 11: "grouse", 12: "seal", 13: "seabird", 14: "bear", 15: "donkey", 16: "goblin", 17: "lynx", 18: "black_bear", 19: "elk", 20: "bighorn", 21: "mountain_goat", 22: "beaver", 23: "chamois", 24: "mink", 25: "raccoon", 26: "rat", 27: "crow", 28: "pheasant", 29: "goose", 30: "cow", 31: "goat", 32: "chicken", 33: "cat", 34: "dog", 35: "buffalo", 36: "puma", 37: "pronghorn", 38: "warthog", 39: "hyena", 40: "wildebeest", 41: "lion", 42: "leopard", 43: "rhino", 44: "elephant", 45: "camel", 46: "guineafowl", 47: "honey_badger", 48: "kangaroo", 49: "mammoth", 50: "tiger", 51: "alligator", 52: "bandit"}
const FELL_WINDOW_MS := 1500             # a body gone this soon after a hit near it fell from that hit
const FELL_M := 3.0                      # how near the hit (the hit is placed at the chest; rows move up to a few metres between updates)
const SMALL_FALL_KINDS := ["rabbit", "songbird", "frog", "grouse", "seabird", "duck", "fox"]   # fall softly
const BURROW_KINDS := ["rabbit"]          # a wounded rabbit can go to ground on its trail: it leaves the rows alive
const FLY := 15                       # server_flight.FLY: a bird in flight (climbing)
const GLIDE := 17                     # server_flight.GLIDE: gliding; a glide that climbs again goes back to FLY, which is no new take-off
const VOICED_STATES := [2, 3, 7, 10, 11, 16, 25, 26]   # flee, alert, a wolf's attack (server_wolves.ATTACK), warn, charge, the jaw-pop warning, a close blow, a kick
const ATTACK_STATES := [7, 11, 25, 26]        # a wolf attacking, big game charging or striking up close: the one biting you (attacker_near)
const BITE_END_STATES := [7, 11]               # an attack that ends in the model's bite clip as it ends (a strike or kick plays its own clip as it starts)
const CLOSE_STATES := [25, 26]                # server_big_game STRIKE and KICK: a blow wound up where it stands, its clip timed to land when the server's does
const WARN_POP := 16                          # the threat ladder's jaw-pop rung (server_big_game.gd); drawn as the warning (10) unless the model maps a clip "16"
# Drawn at the present, not a delay behind (Dave 23 Nov 2026: "battle was almost impossible"): warn, charge, recover and the jaw-pop. A charge's
# line is locked when it starts and it turns only a little, so carrying it on from the newest point is where the server has it, and what the
# player dodges is what the server checks (docs/design/ANIMAL_NETCODE.md). Drawn a delay behind, a charge at 11 m/s was 4 to 9 m back.
const AHEAD_STATES := [10, 11, 12, 16, 25, 26]
const PINNED_MS := 2500                       # held at bodies this long on end while walking, the walker goes through (walker_stop): never shut in
const HELD_GAP_MS := 400                      # a hold broken for longer than this starts again
const STALL_S := 0.25                         # a frame this long is this computer's own stall, not the line's (MotionBuffer.stall_until)
const AIR_STATES := [15, 17]                  # in the air (a flock or a bird flying, a bird gliding): its own clip where the model row has one, never walk or run
# Drawn a delay behind, on the row clock: a bird in the air (FLY, GLIDE). Every other animal is drawn at the present (protocol 168, Dave 24 Nov
# 2026: "give as much control to the client as it takes to make them feel natural"; docs/design/ANIMAL_NETCODE.md "Plans"): a moving one carried
# on along its way past its newest point, never past where its row's plan says it stops (MotionBuffer.at_plan). server_animals AIR_DRAWN.
const AIR_DRAWN := [15, 17]
const PLAN_CARRY_S := 0.6                     # the longest a body at the present carries on past its newest point (a late or lost batch)

var _bodies: Dictionary = {}     # id -> {node, target Vector3 (newest sent), samples (MotionBuffer), heading, state, phase}
var _clock: Dictionary = MotionBuffer.clock_new()   # the rows' clock: offset, interval, holes and lateness, for the draw delay (MotionBuffer.clock_note)
var look_points: Callable        # () -> Array of Vector3: the players' heads (this one and the others drawn), for head tracking; unset in tests
var _look_points: Array = []     # this frame's look_points, fetched the first time an animal looks in a frame
var _look_frame: int = -1        # the _t-frame _look_points was fetched in
var _frame: int = 0              # counts _process_body calls
var _frame_s: float = -1.0       # when _process_body last ran (s, the ticks clock)
var _held_since_ms: int = -1     # walker_stop: when the walker was first held at bodies this time, -1 when free
var _held_last_ms: int = -100000 # and the last frame it was held
var _settle_until: float = -1.0  # after this computer's own stall: until then bodies are drawn where their points are (MotionBuffer.settle)
var player_at: Callable          # () -> Vector3: the local player's body (its xz), so a charge is never drawn inside them (AnimalContact.stop_toward); unset in tests
var max_drawn: int = MAX_DRAWN   # SPYGLASS_DRAWN while the admin spyglass is up (terrain_client.gd)
var _models: Variant = null      # data/animals/models.json "species" (loaded on first use)
var _scenes_of: Dictionary = {}   # species number -> its model files that exist (_species_scenes)
var _scene_held: Dictionary = {}  # model file path -> its scene or texture, loaded on a worker (_scenes_ready) and kept so load() finds it cached
var _model_notes: Dictionary = {}  # log lines already printed by _model_note
var _alpha_of: Dictionary = {}     # texture path -> has see-through pixels (_has_alpha)
const REPORT_MS := 30000         # how often the log gets the animals line (_report; QA #12)
var _report_ms: int = 0           # clock_ms of the last animals line
var _report_rows: int = 0         # rows in the newest batch
var _report_batches: int = 0      # batches since the last line
var _report_held: int = 0         # rows held undrawn for model files since the last line
const SCENE_WAIT_MS := 8000      # the longest a kind is held undrawn while its model files load on a worker (_waited_out; QA #12)
var _wait_since: Dictionary = {}  # species number -> clock_ms when it was first held undrawn for its files (_waited_out)
var _code_body_only: bool = false # set while an animal past SCENE_WAIT_MS is made: _make_model gives null, so the code-built body is drawn
var clock_ms: Callable = func() -> int: return Time.get_ticks_msec()   # the clock for the wait (tests set it)
var files_ready: Callable          # (species number) -> bool: stands in for _scenes_ready (tests: headless always loads at once); unset in the game
var _alpha_tasks: Dictionary = {}  # texture path -> the worker task finding its alpha (_scenes_ready)
var _alpha_done: Dictionary = {}   # texture path -> its alpha, written by _alpha_job under _alpha_mutex
var _alpha_mutex: Mutex = Mutex.new()
var _mats: Dictionary = {}
var _t: float = 0.0
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
const GOBLIN_SPECIES := 16   # KIND_OF_SPECIES: the goblin
const YOUNG_NUM := 100       # a young animal's species number + 100 (server_animals.gd)
const YOUNG_SCALE := 0.5     # how big the young are drawn


const FEATHERED := [6, 9, 11, 13]     # flock birds, songbirds, grouse, gulls: they take the feather coat while they build


# A bird takes off when its row goes from the ground into flight (FLY); a glide climbing again (GLIDE to FLY) or a row sent again in
# flight is the same flight. A body first drawn already flying starts in that state, so it is no take-off either.
static func takes_off(was: int, now: int) -> bool:
	return now == FLY and not was in [FLY, GLIDE]


# A goblin tribe member's body (npc_view.gd, data/creatures/goblin_tribes.json, Dave 19 Nov 2026): the goblin model's look `variant` (0 Skritch,
# 1 Rukz, 2 Vrixa, 3 Grikka), with its own steady height roll from `look_seed`, drawn and clipped exactly as a wild goblin; null when the model file is not
# there. Every look is open here, also those marked "wild": false that wild goblins never get.
func make_goblin(variant: int, look_seed: int) -> Node3D:
	var looks: int = maxi((_model_rows().get("goblin", {}).get("variants", []) as Array).size(), 1)
	return _make_model(GOBLIN_SPECIES, posmod(variant, looks) + looks * posmod(look_seed, 4096), false, true)


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

	if number == 52:
		return BanditLook.make(id)

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


# Whether a body missing from a batch is kept: far off (past FAR_KEEP_M from the player, whose rows carry far big game every other time)
# and its last row within FAR_KEEP_MS. One that really left (past 200 m, gone, dead) goes within FAR_KEEP_MS.
static func far_kept(at: Vector3, me: Vector3, row_at_ms: int, now_ms: int) -> bool:
	return me != Vector3.INF and Vector2(at.x - me.x, at.z - me.z).length() > FAR_KEEP_M and now_ms - row_at_ms <= FAR_KEEP_MS


# Whether a body that left the rows at `at` was standing on its blood trail: a wounded animal that bleeds out dies where it is,
# at the end of its trail, with no hit near. Bodies leave the rows only past send_radius_m (120 m; big game 200 m, animals.json big_game), far beyond the 30 m a
# one-shot is played at, so a wounded animal running out of range is never heard falling.
static func near_blood(at: Vector3, points: PackedVector3Array) -> bool:
	for p in points:
		if p.distance_to(at) <= FELL_M:
			return true

	return false


# A blow landed on animal `id` (animal_hit, protocol 96; Dave 19 Nov 2026: he could not tell a spear was hurting a bear): the body squashes and
# springs back in a fifth of a second, so a hit is seen. FLINCH is the squash (PROVISIONAL HIT-2).
const FLINCH := Vector3(1.08, 0.88, 1.08)
const FLINCH_S := 0.2


# The player's own blow seen to land (held_item blow_landing; docs/design/ANIMAL_NETCODE.md "Plans" step 3): the flinch now, not a round trip
# later. True when it flinched, so the caller plays the thud too. The server's animal_hit for it, within PREDICT_KEEP_S, then plays neither
# again (confirm_hit). A blow the server judges a miss after all has only flinched (and played its hit clip); it does no damage and leaves no blood.
const PREDICT_KEEP_S := 0.8
var _predicted: Dictionary = {}   # id -> _t of the blow this screen saw land and has not yet heard the server's hit for


func predict_hit(id: int) -> bool:
	if not _bodies.has(id):
		return false

	for was in _predicted.keys():   # blows the server never confirmed (judged a miss, or the animal went) are let go
		if _t - float(_predicted[was]) > PREDICT_KEEP_S:
			_predicted.erase(was)

	_predicted[id] = _t
	flinch(id)
	return true


# The server's hit on animal `id` (animal_hit): true when it is the blow already shown (predict_hit, inside PREDICT_KEEP_S), which plays no
# second flinch or thud; false for any other hit, which plays them as before.
func confirm_hit(id: int) -> bool:
	var at: float = float(_predicted.get(id, -INF))
	_predicted.erase(id)
	return _t - at <= PREDICT_KEEP_S


func flinch(id: int) -> void:
	if not _bodies.has(id) or not is_instance_valid(_bodies[id]["node"]):
		return

	var node: Node3D = _bodies[id]["node"]

	if not node.has_meta("rest_scale"):
		node.set_meta("rest_scale", node.scale)   # the species' own size (a lynx is drawn 1.4 times): a second hit mid-flinch springs back to it

	var rest: Vector3 = node.get_meta("rest_scale")

	if not node.is_inside_tree():
		return

	var tween: Tween = node.create_tween()
	tween.tween_property(node, "scale", rest * FLINCH, FLINCH_S * 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", rest, FLINCH_S * 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# A model with a hit clip plays it once: standing still, or any time when the clip is a hit taken on the run (HitInRunHead_F).
	# A standing hit clip on a running body would slide it along with its legs still.
	var roles: Dictionary = (node.get_meta("player") as AnimationPlayer).get_meta("roles", {}) if node.has_meta("player") else {}

	if int(_bodies[id].get("state", 0)) != LIE and (float(_bodies[id].get("spd", 0.0)) <= HIT_STILL_MPS or str(roles.get("hit", "")).to_lower().contains("run")):      # a lying body has no standing hit to show
		_play_once(_bodies[id], "hit", HIT_MAX_S)


# The plan in an animal row (protocol 168, server_animals rows_near): where a moving animal is walking to on the ground, a Vector2 (x, z)
# after the fixed six fields (for STOP_PLAN_MS after its step stopped it, where it stands: server_animals row_plan); null when it has none.
static func plan_of(row: Array) -> Variant:
	for i in range(6, row.size()):
		if row[i] is Vector2:
			return row[i]

	return null


# One-shot clips (Dave 23 Nov 2026: animals "like really bad animatronics"): a bite as an attack ends, a hit, a death. The model's
# "bite", "hit" and "die" roles (models.json) are copies that do not loop. While one plays (up to cap_s), _animate_model leaves the clip
# alone, then blends back to the state's own clip. False when the model has no clip for the role.
const ONCE_ROLES := ["bite", "hit", "die", "strike", "strike2", "kick"]
const HIT_STILL_MPS := 1.0     # a standing hit clip plays only on a body slower than this
const HIT_MAX_S := 0.9         # a hit clip is cut here: the animal is back in its state's clip within a second
const BITE_MAX_S := 1.2
const BLOW_MAX_S := 2.0         # a strike or kick clip is cut here
const HIT_AT := 0.45           # where in a strike or kick clip the blow lands, as a share of its length, when the model row gives no "hit_at"
const ANIMALS_PATH := "res://data/animals/animals.json"
static var _windups: Dictionary = {}   # kind -> {"strike": s, "kick": s}: each close blow's wind-up (animals.json defend rows), read once
const DIE_MAX_S := 2.0         # short: the carcass is already on the ground there (carcass_look.gd), so the falling body goes soon
const DIE_HOLD_S := 0.3        # the last pose of a death clip is held this long before the body goes


# A strike or kick begins (server_big_game _close_attack): the model's own attack clip plays once, sped so its blow (hit_at of the clip) lands
# when the server's does, windup_s after the state began. The row came the clock's lateness after that, so the clip starts that far in.
# A kind with two strikes ("strike2") takes turns between them.
func _close_blow(b: Dictionary, state: int) -> void:
	var how: String = "kick" if state == CLOSE_STATES[1] else "strike"
	var role: String = how

	if how == "strike":
		b["strikes"] = int(b.get("strikes", -1)) + 1
		role = "strike2" if int(b["strikes"]) % 2 == 1 else "strike"

	if not _play_once(b, role, BLOW_MAX_S, windup_s(str(b.get("kind", "")), how), float(_clock["late"])) and role == "strike2":
		_play_once(b, "strike", BLOW_MAX_S, windup_s(str(b.get("kind", "")), how), float(_clock["late"]))


# The wind-up of kind's close blow `how` ("strike" or "kick") from animals.json, 0.7 s when it has none.
static func windup_s(kind: String, how: String) -> float:
	if _windups.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ANIMALS_PATH)) if FileAccess.file_exists(ANIMALS_PATH) else null
		var species: Dictionary = (parsed as Dictionary).get("species", {}) if parsed is Dictionary else {}
		_windups["_read"] = true

		for sp in species:
			var defend: Dictionary = (species[sp] as Dictionary).get("defend", {}) if species[sp] is Dictionary else {}

			for k in ["strike", "kick"]:
				if defend.get(k, null) is Dictionary:
					if not _windups.has(sp):
						_windups[sp] = {}

					_windups[sp][k] = float(defend[k].get("windup_s", 0.7))

	return float((_windups.get(kind, {}) as Dictionary).get(how, 0.7))


# land_in_s > 0: the clip is sped so its blow (the model row's "hit_at" share of the clip, else HIT_AT) comes land_in_s after it began, and
# it starts from_s into that (the row's lateness).
func _play_once(b: Dictionary, role: String, cap_s: float, land_in_s: float = 0.0, from_s: float = 0.0) -> bool:
	var node: Node3D = b.get("node", null)

	if node == null or not is_instance_valid(node) or not node.has_meta("player"):
		return false

	var player: AnimationPlayer = node.get_meta("player")
	var clip: String = str((player.get_meta("roles", {}) as Dictionary).get(role, ""))

	if clip == "" or not player.has_animation(clip):
		return false

	var length: float = player.get_animation(clip).length
	var rate: float = 1.0

	if land_in_s > 0.0:
		rate = clampf(float((node.get_meta("model_row", {}) as Dictionary).get("hit_at", HIT_AT)) * length / land_in_s, 0.5, 3.0)

	var into: float = clampf(from_s * rate, 0.0, length * 0.9)
	player.play(clip, 0.1)
	player.speed_scale = rate

	if into > 0.0:
		player.seek(into, true)

	b["once_until"] = _t + minf((length - into) / rate, cap_s)
	return true


# A killed animal with a death clip falls where it is drawn and goes after the clip: true when it does (the caller then drops it
# from the rows without freeing it), false when it has none (it goes at once, as before).
func _die(b: Dictionary) -> bool:
	if not is_inside_tree() or not _play_once(b, "die", DIE_MAX_S):
		return false

	var node: Node3D = b["node"]

	if node.has_meta("head_look"):
		(node.get_meta("head_look") as SkeletonModifier3D).active = false      # the death clip's own head (head tracking stops)

	get_tree().create_timer(float(b["once_until"]) - _t + DIE_HOLD_S).timeout.connect(node.queue_free)
	return true


# The kind and place of the nearest animal attacking or charging within `max_m` of `at` ({} when none): who bit you, for its snarl.
func attacker_near(at: Vector3, max_m: float) -> Dictionary:
	var best: Dictionary = {}
	var best_m: float = max_m

	for id in _bodies:
		var b: Dictionary = _bodies[id]

		if not int(b["state"]) in ATTACK_STATES or str(b["kind"]) == "" or not is_instance_valid(b["node"]):
			continue

		var where: Vector3 = (b["node"] as Node3D).global_position
		var d: float = where.distance_to(at)

		if d <= best_m:
			best_m = d
			best = {"kind": str(b["kind"]), "at": where, "node": b["node"]}   # node: the snarl follows the body

	return best


# A hit the server reported (hit_number, protocol 85) at `at`: kept a moment so a body that then leaves the rows reads as killed.
func note_hit(at: Vector3) -> void:
	var now: int = Time.get_ticks_msec()
	_hits = _hits.filter(func(h): return now - int(h[1]) <= FELL_WINDOW_MS)
	_hits.append([at, now])


# Whether a body last seen at `at` that left the rows at `now_ms` was killed: a hit landed within FELL_M of it in the last
# FELL_WINDOW_MS. Bodies that walk out of range, or a snared one, leave with no hit near them.
static func killed_by_hit(at: Vector3, hits: Array, now_ms: int) -> bool:
	for h in hits:
		if now_ms - int(h[1]) <= FELL_WINDOW_MS and (h[0] as Vector3).distance_to(at) <= FELL_M:
			return true

	return false


# The walker's frame move from `before` to `after` (feet) stopped at the animals drawn near: the correction to add (AnimalContact.walker_stop).
# Bodies of AnimalContact.BLOCK_M or more (a deer, a boar, a wolf and up) stand in the way; a rabbit, a fox or a dog at heel is stepped past.
func walker_stop(before: Vector3, after: Vector3) -> Vector3:
	var bodies: Array = []

	for id in _bodies:
		var b: Dictionary = _bodies[id]
		if AnimalContact.body_m(str(b["kind"])) < AnimalContact.BLOCK_M:
			continue

		var m: float = float(b["contact_m"]) - AnimalContact.WALK_INTO_M
		var at: Vector3 = (b["node"] as Node3D).global_position

		if Vector2(at.x - after.x, at.z - after.z).length() < m + 1.0:
			bodies.append([at, m])

	var stop: Vector3 = AnimalContact.walker_stop(before, after, bodies) if not bodies.is_empty() else Vector3.ZERO
	var wanted: float = Vector2(after.x - before.x, after.z - before.z).length()
	var made: float = Vector2(after.x + stop.x - before.x, after.z + stop.z - before.z).length()
	var pinned: bool = stop.length() >= 0.001 and made < wanted * 0.3   # held, not sliding round it
	var held: Array = AnimalContact.walker_held([_held_since_ms, _held_last_ms], Time.get_ticks_msec(), pinned, PINNED_MS, HELD_GAP_MS)
	_held_since_ms = int(held[0])
	_held_last_ms = int(held[1])
	return Vector3.ZERO if bool(held[2]) else stop   # held so long they go through: a walker is never shut in


# [[id, drawn position], ...] of every animal drawn: the admin spyglass picks the one nearest its centre.
func drawn_positions() -> Array:
	var out: Array = []

	for id in _bodies:
		out.append([int(id), (_bodies[id]["node"] as Node3D).global_position])

	return out


# [[drawn position, heading, body_m], ...] of the animals drawn within `range_m` of `from`: the bow's aim assist finds their vital zones from these
# (BowAim.zone_points); a blow's reach is to the body, body_m short of its middle (held_item._animal_aimed).
func aim_rows(from: Vector3, range_m: float) -> Array:
	var out: Array = []

	for id in _bodies:
		var at: Vector3 = (_bodies[id]["node"] as Node3D).global_position

		if at.distance_to(from) <= range_m:
			out.append([at, float(_bodies[id]["heading"]), AnimalContact.body_m(str(_bodies[id]["kind"])), id])   # its reach from middle to nose: a blow reaches its body, not its middle

	return out


# The server moments this screen shows the animals at now (protocol 155, a blow sends them; docs/design/ANIMAL_NETCODE.md "Fair hits"):
# [the row clock's draw time, the present a committed charge is drawn at], in server ms; [0, 0] before any rows came.
func seen_server_ms() -> Array:
	var off: float = float(_clock["off"])

	if off == INF:
		return [0, 0]

	var now_s: float = float(Time.get_ticks_usec()) / 1.0e6
	return [int(round((now_s - MotionBuffer.clock_delay(_clock) - off) * 1000.0)), int(round((now_s - float(_clock["late"]) - off) * 1000.0))]


func on_rows(rows: Array, server_ms: int) -> void:
	var seen: Dictionary = {}
	_report_rows = rows.size()
	_report_batches += 1
	var now_s: float = float(Time.get_ticks_usec()) / 1.0e6
	_settle_until = MotionBuffer.stall_until(now_s, _frame_s, _settle_until, get_process_delta_time(), STALL_S)
	MotionBuffer.clock_note(_clock, now_s, server_ms, now_s <= _settle_until)

	var now_ms: int = Time.get_ticks_msec()

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
			if _bodies.size() >= max_drawn:
				continue

			# The first of a kind waits, undrawn, while its model files load on a worker; its next rows draw it. Never longer than
			# SCENE_WAIT_MS (QA #12, 25 Nov 2026: a tester on a slow 2-core PC saw no animals at all): past it, the animal is drawn with
			# its code-built body, and later ones of its kind get the model once it is in.
			var files_in: bool = bool(files_ready.call(int(row[1]))) if files_ready.is_valid() else _scenes_ready(int(row[1]))

			if not files_in and not _waited_out(int(row[1])):
				_report_held += 1
				continue

			_code_body_only = not files_in
			var node: Node3D = _make_for_species(int(row[1]), id, young)
			_code_body_only = false

			if node == null:
				continue

			node.position = row[2]

			if young and not node.has_meta("young_model"):
				node.scale = Vector3.ONE * YOUNG_SCALE

			add_child(node)
			_bodies[id] = {"node": node, "target": row[2], "heading": float(row[3]), "state": int(row[4]), "phase": float(id % 7), "deer": int(row[1]) >= 2 and not SMALL_SPECIES.has(int(row[1])), "wolf": int(row[1]) == 3 and not node.has_meta("model"), "quad": node.has_meta("quad"), "model": node.has_meta("model"), "kind": KIND_OF_SPECIES.get(int(row[1]), ""), "step_count": -1, "gulls": int(row[1]) == 13, "id": int(id), "samples": [], "contact_m": AnimalContact.contact_m(str(KIND_OF_SPECIES.get(int(row[1]), ""))), "turn_rad_s": AnimalContact.draw_turn_rad_s(str(KIND_OF_SPECIES.get(int(row[1]), "")))}

		if int(row[4]) == 3 and int(row[4]) != int(_bodies[id]["state"]) and bool(_bodies[id].get("alarmed", false)):
			pass   # one alarm call: an animal gives it the first time it looks up, not each look (ANIMAL_SCENARIOS gap 4)
		elif int(row[4]) != int(_bodies[id]["state"]) and int(row[4]) in VOICED_STATES and KIND_OF_SPECIES.has(int(row[1])):
			_bodies[id]["alarmed"] = _bodies[id].get("alarmed", false) or int(row[4]) == 3
			state_changed.emit(KIND_OF_SPECIES[int(row[1])], int(row[4]), row[2], _bodies[id]["node"])
		elif takes_off(int(_bodies[id]["state"]), int(row[4])) and KIND_OF_SPECIES.has(int(row[1])):
			took_off.emit(KIND_OF_SPECIES[int(row[1])], row[2])

		# An attack ending (a wolf's lunge, big game's charge) ends in a bite or a blow: the model's bite clip plays once.
		if int(_bodies[id]["state"]) in BITE_END_STATES and not int(row[4]) in ATTACK_STATES:
			_play_once(_bodies[id], "bite", BITE_MAX_S)
		elif int(row[4]) in CLOSE_STATES and int(row[4]) != int(_bodies[id]["state"]):
			_close_blow(_bodies[id], int(row[4]))

		_bodies[id]["target"] = row[2]
		_bodies[id]["heading"] = float(row[3])
		_bodies[id]["row_at_ms"] = now_ms

		# When the server moved it, on this clock; a repeat is skipped. No pause guess (gap INF): since protocol 154 a standing animal's
		# row carries the send time, so every leg between two points is one the animal really made.
		MotionBuffer.push_row(_bodies[id], row[2], float(row[3]), int(row[5]), float(_clock["off"]), INF)

		if int(_bodies[id].get("row_ms", -1)) == int(row[5]):
			_bodies[id]["plan"] = plan_of(row)   # an older row out of order (dropped by push_row) leaves the newer plan
		_bodies[id]["state"] = int(row[4])

	var now: int = now_ms
	var me: Vector3 = player_at.call() if player_at.is_valid() else Vector3.INF

	for id in _bodies.keys():
		if not seen.has(id) and far_kept(_bodies[id]["target"], me, int(_bodies[id].get("row_at_ms", now)), now):
			continue   # far big game left out of this batch: it comes in the next one

		if not seen.has(id):
			var killed: bool = killed_by_hit(_bodies[id]["target"], _hits, now) or (str(_bodies[id]["kind"]) not in BURROW_KINDS and near_blood(_bodies[id]["target"], _blood_points))

			if killed:
				fell.emit(str(_bodies[id]["kind"]), _bodies[id]["target"], str(_bodies[id]["kind"]) in SMALL_FALL_KINDS)

			if not (killed and _die(_bodies[id])):
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


# Where the nearest animals breathe from, for breath in the cold (breath_look.gd, art_weather_light.md 8.4): up to `most`
# shown bodies within radius_m of `centre`, nearest first, each as [key, mouth, forward]. The mouth is the head bone (a
# rigged model) or the "Head" node (a code-built body) a little ahead along the body; a body with neither does not breathe.
# The head is looked up once per body and kept in its row.
func breath_points(centre: Vector3, radius_m: float, most: int) -> Array:
	var near: Array = []

	for id in _bodies:
		var node: Node3D = _bodies[id]["node"]

		if node == null or not is_instance_valid(node) or not node.is_visible_in_tree():
			continue

		var d: float = node.global_position.distance_to(centre)

		if d <= radius_m:
			near.append([d, id])

	near.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var out: Array = []

	for pair in near.slice(0, most):
		var b: Dictionary = _bodies[pair[1]]
		var node: Node3D = b["node"]

		if not b.has("breath_head"):
			var bone: Array = BreathLook.head_bone_of(node)

			if bone.is_empty():
				b["breath_head"] = node.find_child("Head", true, false)
			else:
				b["breath_head"] = bone

		var head: Variant = b["breath_head"]
		var forward: Vector3 = -node.global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
		var at: Vector3

		if head is Array:
			var sk: Skeleton3D = head[0]

			if not is_instance_valid(sk):
				continue

			at = sk.global_transform * sk.get_bone_global_pose(int(head[1])).origin
		elif head != null and is_instance_valid(head):
			at = (head as Node3D).global_position
		else:
			continue

		out.append(["animal_%d" % int(pair[1]), at + forward * 0.1, forward])

	return out


func _process(delta: float) -> void:
	var t: int = FrameProbe.start()
	_process_body(delta)
	FrameProbe.stop("animals", t)


func _process_body(delta: float) -> void:
	_t += delta
	var now_s: float = float(Time.get_ticks_usec()) / 1.0e6
	_settle_until = MotionBuffer.stall_until(now_s, _frame_s, _settle_until, delta, STALL_S)   # this computer's own stall: rows read now came late because nobody read them
	var settle: bool = now_s <= _settle_until
	_frame_s = now_s
	var drawn_at: float = now_s - MotionBuffer.clock_delay(_clock)
	var present: float = now_s - float(_clock["late"])   # where the newest rows say it is now: every animal on the ground is drawn there (protocol 168), a committed charge too (AHEAD_STATES)
	var me: Vector3 = player_at.call() if player_at.is_valid() else Vector3.INF
	_frame += 1

	if int(clock_ms.call()) - _report_ms >= REPORT_MS:
		_report_ms = int(clock_ms.call())
		_report(me)

	for id in _bodies:
		var b: Dictionary = _bodies[id]
		var node: Node3D = b["node"]
		var state: int = b["state"]

		if state == WARN_POP and not (node.has_meta("player") and (node.get_meta("player").get_meta("roles", {}) as Dictionary).has(str(WARN_POP))):
			state = 10

		var before: Vector3 = node.position

		if settle:
			MotionBuffer.settle(b)

		var ahead: bool = int(b["state"]) in AHEAD_STATES
		if int(b["state"]) in AIR_DRAWN:
			b["air_until"] = _t + MotionBuffer.MAX_DELAY_S   # a bird just landed is drawn a delay behind until it has stood that long: no jump forward on landing
		var at_present: bool = ahead or (not int(b["state"]) in AIR_DRAWN and _t >= float(b.get("air_until", -1.0)))
		var t_drawn: float = present if at_present else drawn_at
		var drawn: Array

		if ahead:
			drawn = MotionBuffer.at(b["samples"], t_drawn, MotionBuffer.AHEAD_CARRY_S if int(b["state"]) == CHARGE else 0.0)   # only a charge carries on; the others stand
		elif at_present:
			drawn = MotionBuffer.at_plan(b["samples"], t_drawn, PLAN_CARRY_S, b.get("plan", null))   # on along its way, never past where it stops
		else:
			drawn = MotionBuffer.at(b["samples"], t_drawn)
		var spot: Vector3 = drawn[0]

		if not ahead:
			spot = MotionBuffer.follow(b, spot, delta)   # its own feet: eased starts and stops, a curve at a corner (Dave: "more freedom client side")

		if me != Vector3.INF:
			# Never drawn into the local player: a charge (carried on past its newest point) waits on its own side; an animal that went past them is drawn going round
			# them at no more than its drawing's own room a frame (MotionBuffer.smooth), never held at their edge and then snapped on.
			var reach: float = clampf(MotionBuffer.speed_at(b["samples"], t_drawn), 2.0, MotionBuffer.CARRY_MPS) * delta * 1.05
			spot = AnimalContact.stop_toward(me, b.get("sm_p", before), spot, float(b["contact_m"]) - AnimalContact.WALK_INTO_M - 0.02, reach, int(b["state"]) != CHARGE)   # inside where the walker stops (walker_stop): their pressing never shoves it on

		if ahead:
			MotionBuffer.follow_hold(b, spot, delta)   # a committed charge runs its locked line; the feet pick up from here after it

		if int(b["state"]) in LUNGE_STATES:
			node.position = MotionBuffer.smooth(b, spot, MotionBuffer.LUNGE_MPS, delta, 1.05, 1.0)
		else:
			node.position = MotionBuffer.smooth(b, spot, MotionBuffer.speed_at(b["samples"], t_drawn), delta)
		node.rotation.y = MotionBuffer.face(b, node.rotation.y, float(drawn[1]), float(b["turn_rad_s"]), delta)   # turned, never snapped
		# The legs follow the drawn ground speed eased over a moment (AnimalGait.smooth), not each frame's own: that jumped at every sent point.
		var spd: float = AnimalGait.smooth(float(b.get("spd", 0.0)), Vector2(node.position.x - before.x, node.position.z - before.z).length() / maxf(delta, 0.001), delta)
		b["spd"] = spd
		if node.has_meta("bandit"):
			BanditLook.animate(node, state, spd)
			continue

		if state == TETHERED and not node.has_meta("saddled"):
			_show_hidden(node)   # a camp horse wears its saddle
		if bool(b.get("model", false)):
			var model_speed: float = spd
			if node.has_meta("flock_birds"):
				var birds: Array = node.get_meta("flock_birds")

				for bird in birds:
					_animate_model(bird, b, state, model_speed, delta, bird == birds[0])      # the flock's gait (footsteps) counts once, not once a bird
			else:
				_animate_model(node, b, state, model_speed, delta)
			_emit_steps(b, node, state, model_speed)
			continue

		var rig: Node3D = node.get_node("Rig")
		var rate: float = 9.0 if state == FLEE else 5.0
		var big: bool = bool(b.get("deer", false))
		var lift: float = ((0.06 if big else 0.22) if state == FLEE else (0.02 if big else 0.1)) * absf(sin(_t * (rate * (0.8 if big else 1.0)) + float(b["phase"]))) if state != GRAZE and state != 3 and state != LIE else 0.0
		# Wolf idle (protocol states 8 roll in the grass, 9 play): placeholder motion until Mandy animates it.
		var roll: float = PI * 0.5 if state == 8 else 0.0
		# Big game (protocol states 10 warn: head down and stamping, 11 charge: gallop, 12 recover): placeholder motion until Mandy animates it.
		rig.rotation.x = lerp_angle(rig.rotation.x, 0.28 if state == 10 or state == 13 else (0.12 if state == 11 or state == 15 else 0.0), clampf(delta * 8.0, 0.0, 1.0))
		rig.rotation.z = lerp_angle(rig.rotation.z, roll, clampf(delta * 6.0, 0.0, 1.0))
		if bool(b.get("wolf", false)):
			_animate_wolf(node, b, state, spd, delta)
		elif bool(b.get("quad", false)):
			_animate_quad(node, b, state, spd, delta)
		else:
			rig.position.y = lerp(rig.position.y, lift + (0.25 * absf(sin(_t * 7.0 + float(b["phase"]))) if state == 9 else 0.0), clampf(delta * 20.0, 0.0, 1.0))

		if bool(b.get("gulls", false)):
			_animate_gulls(rig, state == 15)

		_emit_steps(b, node, state, spd)


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


# Every model file a species may be drawn from (the scenes of its row, its variants and its young model, and their materials' colour
# textures) that exists.
func _species_scenes(number: int) -> PackedStringArray:
	if not _scenes_of.has(number):
		var row: Dictionary = _model_rows().get(str(KIND_OF_SPECIES.get(number, "")), {})
		var rows: Array = [row] + (row.get("variants", []) as Array)

		if row.get("young_model", null) is Dictionary:
			rows.append(row["young_model"])

		var out: PackedStringArray = PackedStringArray()

		for r in rows:
			if not r is Dictionary:
				continue

			var paths: Array = [str((r as Dictionary).get("scene", ""))]

			for entry in ((r as Dictionary).get("materials", []) as Array):      # the colour textures _model_materials lays over the file's own
				if entry is Dictionary:
					paths.append(str((entry as Dictionary).get("albedo", "")))

			for path in paths:
				if path != "" and not out.has(path) and ResourceLoader.exists(path):
					out.append(path)

		_scenes_of[number] = out

	return _scenes_of[number]


# True when every model scene of the species is loaded, so drawing one does not read the file on the main thread. Lane A route plays,
# 23 Nov 2026: the first moose, black bear, horse, wildebeest or warthog drawn was a 0.6 to 1.4 s freeze, about half the freezes of a
# walk, because load() read the model (2 to 3 MB) on the main thread. A scene not loaded yet is asked of a worker and false returned;
# one that fails to load counts as ready, and _make_model then falls back to the code-built body as before.
func _scenes_ready(number: int) -> bool:
	if DisplayServer.get_name() == "headless":
		return true      # the dummy renderer's stores are not thread safe (test_worker_resources): headless clients load as before

	var all_in: bool = true

	for path in _species_scenes(number):
		if not _scene_held.has(path):
			var status: int = ResourceLoader.load_threaded_get_status(path)

			if status == ResourceLoader.THREAD_LOAD_LOADED:
				_scene_held[path] = ResourceLoader.load_threaded_get(path)
			elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				all_in = false
			elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE and ResourceLoader.has_cached(path):
				_scene_held[path] = load(path)      # already in memory (another view loaded it): no file read
			elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE and ResourceLoader.load_threaded_request(path, "", true) == OK:
				all_in = false
			else:
				_scene_held[path] = null      # it failed: _make_model's own load() says so and draws the code-built body

		if _scene_held.get(path) is Texture2D and not _alpha_ready(path, _scene_held[path]):
			all_in = false

	if all_in:
		_wait_since.erase(number)

	return all_in


# The log line every REPORT_MS (QA #12, 25 Nov 2026: Dave saw no animals on the live server though bodies were built): how many rows the
# last batch had and how many batches came, how many bodies are drawn and how many rows were held for model files, and the nearest drawn
# body: its kind, distance, drawn height, the height the server sent, the first thing under it (one ray down from 60 m above: the ground, or a
# tree or roof over it) and whether it is shown. One line, so the log says
# whether the server sends none near, or the client holds, hides or misplaces them.
func _report(me: Vector3) -> void:
	var near_id: int = -1
	var near_d: float = INF

	for id in _bodies:
		var at: Vector3 = (_bodies[id]["node"] as Node3D).global_position if (_bodies[id]["node"] as Node3D).is_inside_tree() else (_bodies[id]["node"] as Node3D).position
		var d: float = Vector2(at.x - me.x, at.z - me.z).length() if me != Vector3.INF else 0.0

		if d < near_d:
			near_d = d
			near_id = int(id)

	var nearest: String = "none"

	if near_id >= 0:
		var node: Node3D = _bodies[near_id]["node"]
		var at: Vector3 = node.global_position if node.is_inside_tree() else node.position
		var ground: float = _ground_under(at)
		var sent_y: float = float((_bodies[near_id]["target"] as Vector3).y)
		nearest = "%s %.0f m off, drawn at y %.1f, sent at y %.1f, first hit below it %s, %s" % [str(_bodies[near_id]["kind"]), near_d, at.y, sent_y, "%.1f" % ground if not is_nan(ground) else "none", "shown" if node.is_visible_in_tree() else "hidden"]

	FreezeWatchScript.printer.line("Animals: %d rows in the last batch, %d batches in %.0f s, %d drawn, %d held for model files; nearest drawn %s; player at %s" % [_report_rows, _report_batches, REPORT_MS / 1000.0, _bodies.size(), _report_held, nearest, "%.0f %.0f" % [me.x, me.z] if me != Vector3.INF else "unknown"])
	_report_batches = 0
	_report_held = 0


# The drawn ground's height under a point (one ray from 60 m above to 200 m below), NAN when nothing is hit or there is no world.
func _ground_under(at: Vector3) -> float:
	if not is_inside_tree() or get_world_3d() == null:
		return NAN

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	if space == null:
		return NAN

	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 60.0, at + Vector3.DOWN * 200.0))
	return float((hit["position"] as Vector3).y) if not hit.is_empty() else NAN


# Whether a kind has waited SCENE_WAIT_MS (clock_ms, tests) for its model files since it was first sent: then it is drawn anyway, with the
# code-built body, and the log says so once per kind ("animal model <kind>: still loading after N s ..."). Its files all in (_scenes_ready),
# the wait is forgotten. Bodies already drawn with the code-built body keep it until they leave; the next ones get the model.
func _waited_out(number: int) -> bool:
	var now: int = int(clock_ms.call())

	if not _wait_since.has(number):
		_wait_since[number] = now
		return false

	if now - int(_wait_since[number]) < SCENE_WAIT_MS:
		return false

	_model_note(str(KIND_OF_SPECIES.get(number, number)), "still loading after %.0f s: drawn with the code-built body until its files are in" % (SCENE_WAIT_MS / 1000.0))
	return true


# A colour texture's see-through test (_has_alpha) reads its pixels back and unpacks them. The unpacking of a 4096 texture is the slow
# part: it is done on a worker, before the animal is drawn (_scenes_ready). The read back stays here, on the main thread, so the worker
# only touches its own Image (no renderer call to wait on, so _exit_tree can wait for it). `source` is the Texture2D, or its Image
# (tests). False until the answer is in _alpha_of; the first call starts the worker.
func _alpha_ready(path: String, source: Variant) -> bool:
	if _alpha_of.has(path):
		return true

	if not _alpha_tasks.has(path):
		var img: Image = source as Image if source is Image else (source as Texture2D).get_image()
		_alpha_tasks[path] = WorkerThreadPool.add_task(_alpha_job.bind(img, path), false, "animal texture alpha")
		return false

	if not WorkerThreadPool.is_task_completed(int(_alpha_tasks[path])):
		return false

	WorkerThreadPool.wait_for_task_completion(int(_alpha_tasks[path]))
	_alpha_tasks.erase(path)
	_alpha_mutex.lock()
	_alpha_of[path] = bool(_alpha_done.get(path, false))
	_alpha_done.erase(path)
	_alpha_mutex.unlock()
	return true


# On a worker (_scenes_ready): whether a texture's pixels `img` have see-through ones, as _has_alpha works it out. Only this Image is touched.
func _alpha_job(img: Image, path: String) -> void:
	if img != null and img.is_compressed():
		img.decompress()      # its own copy: the main thread let go of it

	var has: bool = img != null and img.detect_alpha() != Image.ALPHA_NONE
	_alpha_mutex.lock()
	_alpha_done[path] = has
	_alpha_mutex.unlock()


# Alpha tests still running on a worker are waited for: their bound calls hold this view.
func _exit_tree() -> void:
	for path in _alpha_tasks:
		WorkerThreadPool.wait_for_task_completion(int(_alpha_tasks[path]))

	_alpha_tasks.clear()


func _make_model(number: int, id: int = 0, young: bool = false, every_look: bool = false) -> Node3D:
	_clip_maps.clear()      # the last model's rig is drawn now, or freed: its maps are not wanted

	if _code_body_only:
		return null      # its files are still loading past SCENE_WAIT_MS: no load() on the main thread, the code-built body instead

	var kind: String = str(KIND_OF_SPECIES.get(number, ""))
	var row: Dictionary = _model_rows().get(kind, {})

	# Several looks for one species (goblins, Dave 7 Nov 2026: Skritch and Rukz): the row's "variants" are laid over it, one picked by the
	# animal's id, so every goblin keeps its look. A row with height_m is sized by its mesh height, not its longest side, and each animal
	# gets its own height: height_m plus a bell-shaped roll of up to height_variation_m either way (the mean of three even rolls), seeded
	# from its id so it is the same on every client and every time it comes into view. A look marked "wild": false (Vrixa and Grikka, Dave 20 Nov 2026:
	# named Ragtooth goblins) is only drawn for a tribe member (every_look, make_goblin), never picked for a wild animal.
	if row.has("variants") and not (row["variants"] as Array).is_empty():
		var looks: Array = row["variants"]

		if not every_look:
			var wild: Array = looks.filter(func(look: Variant) -> bool: return bool((look as Dictionary).get("wild", true)))
			looks = wild if not wild.is_empty() else looks

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

	# Bone corrections laid over every clip (bone_offsets.gd: the crow stands up and folds its wings).
	if row.has("bone_offsets"):
		var sks: Array = inst.find_children("*", "Skeleton3D", true, false)

		if not sks.is_empty():
			var fix: SkeletonModifier3D = BoneOffsetsScript.new()
			var missing: PackedStringArray = fix.setup(sks[0], row["bone_offsets"])
			(sks[0] as Skeleton3D).add_child(fix)

			if not missing.is_empty():
				_model_note(kind, "bone_offsets: no bone %s" % ", ".join(missing))

	# The head turns to watch a player (head_look.gd); a row with "head_look": false keeps its clip's head.
	var head_bone: Array = BreathLook.head_bone_of(inst) if bool(row.get("head_look", true)) else []

	if not head_bone.is_empty():
		var look: SkeletonModifier3D = HeadLookScript.new()
		look.setup(head_bone[0], int(head_bone[1]), root)
		(head_bone[0] as Skeleton3D).add_child(look)
		root.set_meta("head_look", look)
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
				var refuse_as: String = anim_name

				# clip_loop {role: [t0, t1, blend_s]}: a file with no looping clip for a role (the mink has only start clips) loops a
				# window of another one; tools/find_loop.gd finds the window whose ends are most alike, and the last blend_s seconds
				# are eased back to the first pose so the loop has no jump.
				var loop_spec: Variant = (row.get("clip_loop", {}) as Dictionary).get(str(key), null)

				if loop_spec is Array and (loop_spec as Array).size() >= 2 and not anim_name.begins_with("gait_"):      # a hand-made gait already loops
					var loop_name: String = anim_name + "_loop_%s" % str(key)      # imported clips sit in the default library, "armature|clip"

					if player.has_animation_library("") and not player.has_animation(loop_name):
						player.get_animation_library("").add_animation(loop_name, _loop_copy(anim, float(loop_spec[0]), float(loop_spec[1]), float(loop_spec[2]) if (loop_spec as Array).size() > 2 else 0.1))

					refuse_as = anim_name      # a refused loop copy refuses its source clip, so the next clip for the role is tried
					anim_name = loop_name
					anim = player.get_animation(anim_name)
					_model_note(kind, "role %s loops %s from %.3f to %.3f s" % [str(key), anim_name, float(loop_spec[0]), float(loop_spec[1])])

				if not _fit_clip_units(player, anim, kind, anim_name):
					refused[refuse_as] = true
					continue

				# A clip that lays the animal flat (the bear drew as a legless tube on the ground, 7 Nov 2026) is not used: its pose is
				# measured against the rest pose, and the next clip for the role is tried; with none, the model keeps its rest pose.
				var clip_h: float = _clip_height(player, anim, rig)

				# A lying clip is low by nature: only one flatter than LIE_FLAT_SHARE of the standing height is refused.
				if rest_h > 0.0001 and clip_h < rest_h * (LIE_FLAT_SHARE if str(key) == "19" or str(key) == "die" else float(row.get("flat_share", 0.5))):      # flat_share: an upright animal (the kangaroo) bends lower than half its height to eat
					_model_note(kind, "clip %s lays the model flat (height %.2f against %.2f standing): not used" % [anim_name, clip_h, rest_h])
					refused[refuse_as] = true
					continue

				# A clip that throws the model far taller than it stands (the elephant's Hit_Head_Right-IP stood 4 times its height and
				# drew nothing on screen: Lane A one-shot check, 23 Nov 2026) is broken the other way: the next clip for the role is tried.
				if rest_h > 0.0001 and clip_h > rest_h * TALL_SHARE:
					_model_note(kind, "clip %s throws the model up (height %.2f against %.2f standing): not used" % [anim_name, clip_h, rest_h])
					refused[refuse_as] = true
					continue

				# A bite, a hit or a death plays once (_play_once) from its own copy, so a looping role naming the same clip keeps looping.
				if str(key) in ONCE_ROLES:
					var once_name: String = anim_name.get_slice("|", anim_name.count("|")) + "_once"

					if player.has_animation_library("") and not player.has_animation(once_name):
						var once: Animation = anim.duplicate() as Animation
						once.loop_mode = Animation.LOOP_NONE
						_strip_root_drift(player, once, rig, kind, once_name)
						player.get_animation_library("").add_animation(once_name, once)

					if player.has_animation(once_name):
						roles[str(key)] = once_name

					break

				anim.loop_mode = Animation.LOOP_LINEAR
				_strip_root_drift(player, anim, rig, kind, anim_name)

				# An in-place walk, trot or run (no travel in the clip) gets its speed from its feet: docs/design/FOOT_SLIDING.md.
				if (str(key) == "walk" or str(key) == "trot" or str(key) == "run") and not anim.has_meta("travel_mps") and not anim.has_meta("stride_measured"):
					anim.set_meta("stride_measured", true)
					var stride_mps: float = _measure_stride(player, anim, rig)

					var typed_mps: float = float(row.get(str(key) + "_mps", 0.0))   # walk_mps, trot_mps or run_mps: the speed the row says this clip was made at

					if stride_mps >= 0.2 and stride_mps <= 25.0 and AnimalGait.stride_ok(stride_mps, typed_mps):
						anim.set_meta("travel_mps", stride_mps)
						_model_note(kind, "clip %s: feet move %.2f m/s on the ground, played at speed / %.2f" % [anim_name, stride_mps, stride_mps])
					elif stride_mps > 0.0:
						# The lynx walk measured 0.26 m/s and the guineafowl run 0.20 (Dave's log, 21 Nov 2026): played at a fifth of the ground
						# speed their legs hardly moved. A measurement that far off the row's speed is a failed one.
						_model_note(kind, "clip %s: feet measured %.2f m/s, too far from the row's %.2f: played at speed / %.2f" % [anim_name, stride_mps, typed_mps, typed_mps])
				roles[str(key)] = anim_name
				break

		player.set_meta("roles", roles)
		_model_note(kind, "clips by role %s" % str(roles))

		# Idle life: the row's idle_variants {role: [clip...]} are the other idle or graze clips of the file, each played once now and then
		# between spells of the role's own clip (_idle_life). Checked like a role clip: one that lays the model flat is left out.
		var idle: Dictionary = {}

		for idle_key in (row.get("idle_variants", {}) as Dictionary):
			if not roles.has(str(idle_key)):
				continue

			var idle_list: Array = []

			for idle_name in row["idle_variants"][idle_key]:
				var idle_full: String = _clip_full(player, row, str(idle_name))

				if idle_full == "" or idle_full == str(roles[str(idle_key)]):
					continue

				var idle_anim: Animation = player.get_animation(idle_full)
				if not _fit_clip_units(player, idle_anim, kind, idle_full):
					continue

				var idle_h: float = _clip_height(player, idle_anim, rig)

				if rest_h > 0.0001 and (idle_h < rest_h * float(row.get("flat_share", 0.5)) or idle_h > rest_h * TALL_SHARE):
					_model_note(kind, "idle clip %s lays the model flat or throws it up: not used" % idle_full)
					continue

				idle_anim.loop_mode = Animation.LOOP_LINEAR
				_strip_root_drift(player, idle_anim, rig, kind, idle_full)
				idle_list.append(idle_full)

			if not idle_list.is_empty():
				idle[str(idle_key)] = idle_list

		player.set_meta("idle", idle)
		_model_note(kind, "role 21 plays %s" % (str(roles["21"]) if roles.has("21") else "none (the drink falls back to role 0); the file's clips: %s" % _clip_names(player)))

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
						mi.set_meta("hidden_surfaces", (mi.get_meta("hidden_surfaces", []) as Array) + [surface])
						_model_note(str(row.get("scene", "")).get_file(), "surface %d of %s [%s] hidden" % [surface, str(mi.name), name_text.strip_edges()])
						break

					var tex: Texture2D = load(str(entry.get("albedo", ""))) as Texture2D if ResourceLoader.exists(str(entry.get("albedo", ""))) else null

					if tex != null:
						var mat: StandardMaterial3D = StandardMaterial3D.new()
						mat.albedo_texture = tex
						mat.roughness = float(entry.get("roughness", 0.9))
						var tint: Array = entry.get("tint", [])

						if tint.size() == 3:
							mat.albedo_color = Color(float(tint[0]), float(tint[1]), float(tint[2]))   # one model as a darker kind (the black bear, from the brown bear model)

						# Fur cards (the ruff round a bear's neck, lashes, lips) are cut out by the texture's alpha: drawn solid,
						# their cut-away parts show as black bands. Cut them, and draw both sides of the cards.
						# "opaque": a texture whose alpha holds something else (the goat's is nearly all zero) is drawn solid.
						if (_has_alpha(tex) or bool(entry.get("alpha", false))) and not bool(entry.get("opaque", false)):
							mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
							mat.alpha_scissor_threshold = float(entry.get("alpha_cut", 0.5))
							mat.cull_mode = BaseMaterial3D.CULL_DISABLED

						mi.set_surface_override_material(surface, mat)

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
const _ROLE_WORDS := {"0": ["idle_breathing", "graz", "idle"], "19": ["lying_breathing", "lying_idle", "lying", "sleep", "lay"], "21": ["drink", "eat", "graz"], "walk": ["walkmedium", "walk"], "run": ["gallop", "runfast", "run", "canter", "trot", "sprint"]}


# Lying down or getting up ("Lying_Down", "Lay_Down", "Lying_Get_Up", "Stand_Up") is a change of pose, not lying.
static func _lie_change(bare: String) -> bool:
	for w in ["down", "get_up", "getup", "stand", "rise", "_up"]:
		if bare.contains(w):
			return true

	return false


const TALL_SHARE := 3.0       # a clip taller than this many times the standing height is a broken one (a standing animal's clips stay well under 2)
const LIE_FLAT_SHARE := 0.2   # a lying clip lower than this share of the standing height is a broken one (the bear's legless tube)


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
			var cased: String = str(full).get_slice("|", str(full).count("|")).replace(" ", "_")      # "idle to walk fwd" reads as idle_to_walk_fwd
			var bare: String = cased.to_lower()

			if bare.contains("dead") or bare.contains("death") or bare.contains("hit_") or bare.contains("interact") or bare.contains("attack") or bare.begins_with("start") or bare.ends_with("end") or bare.contains("stop"):
				continue      # the raccoon's "dead run" is not its run, nor the second wolf's "Attack_Run"

			if refused.has(str(full)):
				continue

			# The lying role (19, protocol 148) takes a lying clip, numbered variants too (Lying_Idle_02), never a change of pose (Idle_to_Lying).
			if role == "19" and names_word(cased, str(word)) and not bare.contains("_to_") and not bare.contains("trans") and not bare.contains("wound") and not bare.contains("injur") and not _lie_change(bare):
				return str(full)

			if role != "19" and names_word(cased, str(word)) and not bare.contains("_to_") and not bare.contains("2") and not bare.ends_with("l") and not bare.ends_with("r") and not bare.contains("wound") and not bare.contains("injur") and not bare.contains("lying") and not names_word(cased, "lay") and not names_word(cased, "sleep"):
				return str(full)

	return ""


# The bare clip names of a model file, for a log line (a role with no clip is then set by name in models.json).
static func _clip_names(player: AnimationPlayer) -> String:
	var names: PackedStringArray = PackedStringArray()

	for full in player.get_animation_list():
		names.append(str(full).get_slice("|", str(full).count("|")))

	return ", ".join(names)


# Whether `word` (lower case) starts a word of a clip name: at the start, after a non-letter, or at a lower-to-upper case step (GrazingOnSpot,
# Idle_Eating, G0_Walk); never inside a word. Dino 9 Nov 2026: "eat" inside Idle_Breathing and Cue_Bleat gave the deer, moose, elk, pronghorn,
# bighorn and wildebeest a head-up clip for the drink, and the buffalo Sitting_Breathing.
static func names_word(name_text: String, word: String) -> bool:
	var lower: String = name_text.to_lower()
	var at: int = lower.find(word)

	while at >= 0:
		if at == 0:
			return true

		var before: String = name_text[at - 1]
		var first: String = name_text[at]

		if before.to_lower() == before.to_upper() or (before == before.to_lower() and first != first.to_lower()):   # no case: not a letter
			return true

		at = lower.find(word, at + 1)

	return false


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


# Which of a clip's tracks move which bone of the rig's skeleton, and which move the nodes between the skeleton and the rig, worked out
# once per clip and rig: _clip_bones samples a walk 41 times and every role's first frame, and resolving each track's node and bone by
# name on every sample was most of the first moose's 0.8 s (Lane A route plays, 23 Nov 2026). Empty with no skeleton.
# The rig's nodes must not be renamed or moved between calls (they are not: the model is set up before it is drawn).
var _clip_maps: Dictionary = {}

func _clip_map(player: AnimationPlayer, anim: Animation, rig: Node3D) -> Dictionary:
	var key: String = "%d:%d" % [anim.get_instance_id() if anim != null else 0, rig.get_instance_id()]

	if _clip_maps.has(key):
		return _clip_maps[key]

	if _clip_maps.size() >= 64:
		_clip_maps.clear()      # one model's clips at a time are all that is wanted; an old rig's nodes may be freed

	var skeletons: Array = rig.find_children("*", "Skeleton3D", true, false)
	var map: Dictionary = {}

	if not skeletons.is_empty():
		var sk: Skeleton3D = skeletons[0]
		var base: Node = player.get_node_or_null(player.root_node) if anim != null else null
		var bones: Array = []
		var chain: Array = []

		if anim != null:
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

				bones.append([t, bone, kind])

		var up: Node = sk

		while up != null and up != rig:
			if up is Node3D:
				var tracks: Array = []

				if anim != null and up != sk:
					for t in anim.get_track_count():
						var tp: NodePath = anim.track_get_path(t)

						if tp.get_subname_count() > 0 or anim.track_get_key_count(t) == 0 or base == null or base.get_node_or_null(NodePath(str(tp.get_concatenated_names()))) != up:
							continue

						var kind: int = anim.track_get_type(t)

						if kind == Animation.TYPE_POSITION_3D or kind == Animation.TYPE_ROTATION_3D or kind == Animation.TYPE_SCALE_3D:
							tracks.append([t, kind])

				chain.append([up, tracks])

			up = up.get_parent()

		map = {"sk": sk, "bones": bones, "chain": chain}

	_clip_maps[key] = map
	return map


# The bones of the skeleton in the rig's space at `time` into a clip (or the imported pose with no clip), from the clip's own tracks
# and the bone rests: no running player needed.
func _clip_bones(player: AnimationPlayer, anim: Animation, rig: Node3D, time: float = 0.0) -> PackedVector3Array:
	var map: Dictionary = _clip_map(player, anim, rig)

	if map.is_empty():
		return PackedVector3Array()

	var sk: Skeleton3D = map["sk"]
	var local: Array = []

	for i in sk.get_bone_count():
		local.append(sk.get_bone_pose(i))      # the pose as imported (the bear stands in it on the animal sheet)

	if anim != null:
		for entry in (map["bones"] as Array):      # [track, bone, track type]
			var t: int = entry[0]
			var bone: int = entry[1]
			var kind: int = entry[2]
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

	for link in (map["chain"] as Array):      # [node, [[track, track type]]], from the skeleton up to the rig
		var up: Node3D = link[0]
		var xf: Transform3D = up.transform

		if anim != null and up != sk:
			var origin: Vector3 = xf.origin
			var turn: Quaternion = xf.basis.get_rotation_quaternion()
			var size: Vector3 = xf.basis.get_scale()

			for track in (link[1] as Array):
				match int(track[1]):
					Animation.TYPE_POSITION_3D:
						origin = anim.position_track_interpolate(int(track[0]), time)
					Animation.TYPE_ROTATION_3D:
						turn = anim.rotation_track_interpolate(int(track[0]), time)
					Animation.TYPE_SCALE_3D:
						size = anim.scale_track_interpolate(int(track[0]), time)

			xf = Transform3D(Basis(turn) * Basis.from_scale(size), origin)

		to_rig = xf * to_rig

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


const UNIT_FIT_MAX := 1500.0   # a clip further off its skeleton than this is not in other units but broken


# Some files keep their bone positions in other units than the skeleton's rest pose (a centimetre clip on a metre skeleton):
# played as they are, every bone falls into the body. The middle ratio of rest length to the clip's first key over the
# position tracks gives the factor; far from 1 (below 0.2 or above 5), every position key is scaled by it; beyond UNIT_FIT_MAX the clip is
# broken, not in other units: false, and the caller does not use it. Once per clip.


func _fit_clip_units(player: AnimationPlayer, anim: Animation, kind: String, anim_name: String) -> bool:
	if anim.has_meta("units_fitted"):
		return not anim.has_meta("units_broken")

	anim.set_meta("units_fitted", true)
	var base: Node = player.get_node_or_null(player.root_node)

	if base == null:
		return true

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
		return true

	ratios.sort()
	var k: float = float(ratios[int(ratios.size() * 0.5)])

	if k > 0.2 and k < 5.0:
		return true

	# No real unit is a thousand times off (centimetres, inches, millimetres are 100, 39, 1000): a clip whose positions are nearly all
	# zero (the elephant's hit clips, about a millionth of the skeleton) is broken. Scaled up it stood four times the elephant's height
	# (Lane A tall check, 23 Nov 2026); played with its turns only it crumpled the elephant into a ball floating a body-height up (Lane A
	# one-shot check of #1712). It is not used.
	if k > UNIT_FIT_MAX or k < 1.0 / UNIT_FIT_MAX:
		anim.set_meta("units_broken", true)
		_model_note(kind, "clip %s bone positions about x%.0f off the skeleton: broken, not used" % [anim_name, k])
		return false

	for t in tracks:
		for i in anim.track_get_key_count(t):
			anim.track_set_key_value(t, i, (anim.track_get_key_value(t, i) as Vector3) * k)

	_model_note(kind, "clip %s bone positions rescaled x%.4f to the skeleton" % [anim_name, k])
	return true


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
	# A bone that stays put over the whole clip (the root at the rig's feet, an IK target) lies on the ground too, at no speed: counted, it
	# pulled the middle speed down to a fifth (the lynx walk 0.26 m/s; Dave's log, 21 Nov 2026). Only bones that move count: a foot does.
	var first: PackedVector3Array = frames[0]
	var swings: PackedByteArray = PackedByteArray()
	swings.resize(first.size())

	for bone in swings.size():
		var box: Rect2 = Rect2(Vector2(first[bone].x, first[bone].z), Vector2.ZERO)

		for f in frames:
			var at: PackedVector3Array = f
			box = box.expand(Vector2(at[bone].x, at[bone].z))

		swings[bone] = 1 if box.size.length() >= (high - low) * 0.05 else 0

	for i in samples:
		var a: PackedVector3Array = frames[i]
		var b: PackedVector3Array = frames[i + 1]

		for bone in a.size():
			if swings[bone] == 1 and a[bone].y <= near_ground and b[bone].y <= near_ground:
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


# One line per kind and message in the game log, so a model that is not drawn says why.
func _model_note(kind: String, text: String) -> void:
	var key: String = kind + text

	if not _model_notes.has(key):
		_model_notes[key] = true
		FreezeWatchScript.printer.line("animal model %s: %s" % [kind, text])


# Whether a drinking animal has its head up to look round at time t (seconds): once per DRINK_SLOT_S slot, starting 6 to 14 s into it and lasting
# 1.5 to 3 s, both from a hash of the animal id and the slot, so the animals of a herd look up at different moments.
static func drink_looking(id: int, t: float) -> bool:
	var slot: int = floori(t / DRINK_SLOT_S)
	var h: int = hash([id, slot])
	var start: float = 6.0 + 8.0 * float(h & 0xffff) / 65535.0
	var length: float = 1.5 + 1.5 * float((h >> 16) & 0xffff) / 65535.0
	var into: float = t - float(slot) * DRINK_SLOT_S
	return into >= start and into < start + length


# Plays the clip for the animal's state (a moving animal walks or runs by its real ground speed) and keeps the gait count for footsteps.
func _animate_model(node: Node3D, b: Dictionary, state: int, speed: float, delta: float, count_gait: bool = true) -> void:
	var row: Dictionary = node.get_meta("model_row", {})
	var clips: Dictionary = row.get("clips", {})
	var clip: String = str(clips.get(str(state), clips.get("0", "")))
	var walk_mps: float = float(row.get("walk_mps", 1.5))
	var run_mps: float = float(row.get("run_mps", 7.0))
	var trot_mps: float = float(row.get("trot_mps", 0.0)) if clips.has("trot") else 0.0      # a row with a trot clip trots between the walk and the run
	var typed: Dictionary = {"walk": walk_mps, "trot": trot_mps, "run": run_mps}
	var ref: float = 0.0
	# Standing, walking, trotting or running, with a margin either side so the clip does not flick at the edge (AnimalGait.role).
	var moving: String = AnimalGait.role(speed, str(b.get("gait_role", "")), walk_mps, run_mps, trot_mps) if state != 10 and state != 12 and state != WARN_POP and not state in CLOSE_STATES else ""
	b["gait_role"] = moving

	if moving != "":
		clip = str(clips.get(moving, clip))
		ref = float(typed[moving])

	if count_gait:
		b["gait"] = float(b.get("gait", 0.0)) + speed * delta / maxf(float(row.get("stride_m", 1.2)), 0.1)

	if not node.has_meta("player"):
		return

	var player: AnimationPlayer = node.get_meta("player")
	var once: bool = _t < float(b.get("once_until", -1.0))

	if node.has_meta("head_look"):
		_steer_head(node, b, state, speed, once, delta)

	if once:
		return      # a bite, hit or death clip is playing once (_play_once)

	var roles: Dictionary = player.get_meta("roles", {})
	var role: String = str(state) if roles.has(str(state)) else "0"

	# Drinking at the bank (state 21): the head comes up now and then to look round (role 3), then goes down again (docs/design/animals_drink_client_design.md).
	if state == DRINK and speed <= 0.3 and roles.has("3") and drink_looking(int(b.get("id", 0)), _t):
		role = "3"

	# A swimmer (a row with a "swim" clip, the alligator) in the water plays its swim clip whatever its state, at its swim speed.
	if roles.has("swim") and water_level.is_valid():
		var level: float = float(water_level.call(node.global_position.x, node.global_position.z)) if node.is_inside_tree() else NAN

		if not is_nan(level) and node.global_position.y < level - 0.05:
			role = "swim"
			ref = float(row.get("swim_mps", 1.5)) if speed > 0.3 else 0.0
			clip = str(roles.get("swim", ""))

			if clip != "" and player.current_animation != clip:
				player.play(clip, 0.25)

			player.speed_scale = AnimalGait.rate(speed, ref) if ref > 0.0 else 0.6
			return

	if ref > 0.0 and not (state in AIR_STATES and roles.has(str(state))):      # in the air a flock plays its flight clip at any speed
		role = moving
	elif state in AIR_STATES and roles.has(str(state)):
		ref = 0.0

	# A moving animal plays a moving clip: a model with a walk but no run (or the other way) uses the one it has, not its idle pose.
	var gait: bool = role == "walk" or role == "trot" or role == "run"
	clip = AnimalGait.moving_clip(roles, role) if gait else str(roles.get(role, roles.get("0", "")))

	if not gait and state == GRAZE:
		clip = _idle_life(b, player, role, clip)
	else:
		b.erase("idle_role")      # moving or any other state (warn, alert, lie): the next stop starts on its own clip

	if gait and not roles.has(role):
		ref = 0.0      # no moving clip at all: the idle clip plays at its own rate

		for other in typed:
			if roles.has(other) and str(roles[other]) == clip:
				ref = float(typed[other])      # another moving clip stands in: played by its own speed

	if clip != "" and player.current_animation != clip:
		player.play(clip, 0.25)

	if ref > 0.0 and clip != "" and player.has_animation(clip):
		ref = float(player.get_animation(clip).get_meta("travel_mps", ref))      # the speed the clip's feet were made for (_strip_root_drift)

	player.speed_scale = AnimalGait.rate(speed, ref)


# Idle life (Dave 23 Nov 2026: animals "like really bad animatronics"): a grazing or standing animal played one clip for minutes. Now it
# plays its role's own clip (`base`) for IDLE_BASE_S, then one of the model's idle variants for that clip's own length (once through: a
# shake, a look up from grazing, a fidget), then its own clip again. A change of role starts again on the own clip, after a staggered
# first spell so a herd does not change in step. Drawing only: the server's state is untouched. Returns the clip to play.
const IDLE_FIRST_S := [2.0, 12.0]
const IDLE_BASE_S := [6.0, 16.0]
const IDLE_MIN_S := 1.0        # a variant shorter than this plays through more than once


func _idle_life(b: Dictionary, player: AnimationPlayer, role: String, base: String) -> String:
	var pool: Array = (player.get_meta("idle", {}) as Dictionary).get(role, [])

	if pool.is_empty() or base == "":
		b.erase("idle_role")      # a role with no variants: coming back to one with variants starts on its own clip
		return base

	if str(b.get("idle_role", "")) != role or not b.has("idle_until"):
		b["idle_role"] = role
		b["idle_clip"] = base
		b["idle_until"] = _t + randf_range(float(IDLE_FIRST_S[0]), float(IDLE_FIRST_S[1]))
	elif _t >= float(b["idle_until"]):
		if str(b["idle_clip"]) == base:
			var pick: String = str(pool[randi() % pool.size()])
			b["idle_clip"] = pick
			b["idle_until"] = _t + maxf(player.get_animation(pick).length if player.has_animation(pick) else 0.0, IDLE_MIN_S)
		else:
			b["idle_clip"] = base
			b["idle_until"] = _t + randf_range(float(IDLE_BASE_S[0]), float(IDLE_BASE_S[1]))

	return str(b["idle_clip"])


# Head tracking (head_look.gd): an animal on watch (alert, stalking, warning, recovering, sneaking, or a drinker looking up) follows
# the nearest player's head within LOOK_WATCH_M; a calm one (grazing, standing, lying) only one within LOOK_CALM_M, and less strongly (LOOK_CALM_STRENGTH);
# moving faster than LOOK_STILL_MPS, an attack, a charge or a one-shot clip: it looks where it goes (the clip's own head).
const LOOK_WATCH_STATES := [3, 6, 10, 12, 13, 16]
const LOOK_CALM_STATES := [GRAZE, LIE]
const LOOK_WATCH_M := 30.0
const LOOK_CALM_M := 8.0
const LOOK_CALM_STRENGTH := 0.6
const LOOK_STILL_MPS := 1.5


static func look_strength(state: int, speed: float, once: bool, drink_up: bool) -> Vector2:
	if once or speed > LOOK_STILL_MPS:
		return Vector2.ZERO

	if state in LOOK_WATCH_STATES or (state == DRINK and drink_up):
		return Vector2(1.0, LOOK_WATCH_M)

	if state in LOOK_CALM_STATES:
		return Vector2(LOOK_CALM_STRENGTH, LOOK_CALM_M)

	return Vector2.ZERO


func _steer_head(node: Node3D, b: Dictionary, state: int, speed: float, once: bool, delta: float) -> void:
	var look = node.get_meta("head_look")      # head_look.gd (untyped: its own fields are read)

	if not is_instance_valid(look):
		return

	var how: Vector2 = look_strength(state, speed, once, state == DRINK and drink_looking(int(b.get("id", 0)), _t))
	var want: Vector3 = Vector3.ZERO

	if how.x > 0.0 and _look_frame != _frame:
		_look_frame = _frame
		_look_points = look_points.call() if look_points.is_valid() else []

	if how.x > 0.0 and not _look_points.is_empty():
		var sk: Skeleton3D = look.get_skeleton()
		var at: Vector3 = sk.global_transform * sk.get_bone_global_pose(int(look.head)).origin if sk != null else node.global_position
		want = HeadLookScript.goal(at, node.global_transform.basis, _look_points, how.y, how.x)

	look.steer(want, delta)


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

		if state == LIE:
			target = 1.4 if leg.begins_with("Leg_F") else -1.4      # lying: the legs folded under
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
	var crouch: float = -0.12 if state == 6 else (-0.3 if state == LIE else 0.0)
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

		if state == LIE:
			target = 1.4 if leg.begins_with("Leg_F") else -1.4      # lying: the legs folded under
		elif state == 10 and leg == "Leg_FR":
			target = -0.9 + 0.9 * maxf(0.0, sin(_t * 9.0))      # paws and stamps the ground
		elif state == 10 and leg == "Leg_FL":
			target = -0.2 * maxf(0.0, sin(_t * 9.0 + 3.1))

		pivot.rotation.x = lerpf(pivot.rotation.x, target, clampf(delta * 18.0, 0.0, 1.0))

	var head_down: float = 0.0

	if state == LIE:
		head_down = 0.15 + 0.03 * sin(_t * 0.6 + float(b["phase"]))      # lying, the head up, chewing or dozing
	elif state == 0 and speed < 0.3:
		head_down = 0.9 + 0.08 * sin(_t * 0.9 + float(b["phase"]))      # grazing
	elif state == DRINK and speed < 0.3:
		head_down = -0.35 if drink_looking(int(b.get("id", 0)), _t) else 0.95 + 0.04 * sin(_t * 2.2 + float(b["phase"]))      # drinking, the head up now and then to look round
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
	var down: float = -leg_h * 0.7 if state == LIE else 0.0      # lying: the body on the ground
	rig.position.y = lerpf(rig.position.y, bob + heave + down, clampf(delta * (3.0 if state == LIE else 10.0), 0.0, 1.0))


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


# Puts back the surfaces a hide entry cut away (a tethered camp horse's saddle, docs/design/BANDIT_CAMPS.md), once per body.
func _show_hidden(node: Node3D) -> void:
	node.set_meta("saddled", true)

	for mi in node.find_children("*", "MeshInstance3D", true, false):
		for surface in (mi.get_meta("hidden_surfaces", []) as Array):
			(mi as MeshInstance3D).set_surface_override_material(int(surface), null)
