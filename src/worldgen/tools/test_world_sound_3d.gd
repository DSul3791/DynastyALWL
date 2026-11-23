extends SceneTree

# World sounds can be pinpointed by ear (Dave 23 Nov 2026: "the sound is not overly directional. it seems very broad and hard to pinpoint").
# - Full left/right: the project's 3D panning strength times each voice's own is 1.0, and a tone straight to the right of the ears is
#   heard in the right ear only (measured through the mixer: an AudioEffectCapture on Master, the headless Dummy driver mixes).
# - The ears sit at the eye (Sound3D.ears), not on the drawn third-person camera behind it.
# - The world events that tell where an animal or another player is (a call, an animal's step, a blow landing, another player's step)
#   each play an AudioStreamPlayer3D at that place, with distance falloff, a reach, and in "world_sounds" (cover muffling, voice budget).
# - Every flat AudioStreamPlayer under src/client is one of the listed own-body, UI or ambient-bed modules, so a new world sound cannot
#   start flat without this list being changed in review.
# - Another player walking makes footsteps (player_view.gd stepped, at the feet, the own stride lengths; none lying down or swimming).
#   godot --headless --path . --script res://src/worldgen/tools/test_world_sound_3d.gd

const Sound3D := preload("res://src/client/sound_3d.gd")
const CreatureSounds := preload("res://src/client/creature_sounds.gd")
const SlotSounds := preload("res://src/client/slot_sounds.gd")
const SpearSounds := preload("res://src/client/spear_sounds.gd")
const GearSounds := preload("res://src/client/gear_sounds.gd")
const PlayerView := preload("res://src/client/player_view.gd")
const Stance := preload("res://src/client/stance.gd")
const SoundStage := preload("res://src/client/sound_stage.gd")
const AnimalView := preload("res://src/client/animal_view.gd")

# Modules allowed flat players: the listener's own body, the UI, and beds that are around the listener on purpose.
const FLAT_OK := {
	"src/client/sound_stage.gd": "own footsteps, the wind beds",
	"src/client/step_fx.gd": "own footstep layers",
	"src/client/landing_sounds.gd": "own landing",
	"src/client/stance_sounds.gd": "own crouch, sit and lie",
	"src/client/gear_sounds.gd": "own worn gear (others' gear is step_at, positional)",
	"src/client/breath_sounds.gd": "own breath and heart",
	"src/client/item_sounds.gd": "own hands and mouth",
	"src/client/flame_sounds.gd": "the torch in the own hand",
	"src/client/swim_sounds.gd": "own swimming",
	"src/client/inner_voice_sounds.gd": "the inner voice",
	"src/client/ui_sounds.gd": "menu clicks",
	"src/client/ui/goals/goal_placard.gd": "goal card",
	"src/client/ambient_life.gd": "ambient beds (the calls are positional)",
	"src/client/ambience_slots.gd": "biome beds",
	"src/client/insect_bed.gd": "insect bed",
	"src/client/weather_sounds.gd": "rain and wind beds (thunder is positional)",
	"src/client/wind_structures.gd": "wind in the gaps round the listener",
	"src/client/interior_sounds.gd": "the room and roof round the listener",
}

var failures: int = 0
var _capture: AudioEffectCapture


class StubStage extends Node:
	var voice_cap: int = 64
	var preset: Dictionary = {"creature_voices": 8}

	func has_room() -> bool:
		return true

	func voices_playing() -> int:
		return 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var strength: float = float(ProjectSettings.get_setting("audio/general/3d_panning_strength", 0.5))
	var probe: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	check(is_equal_approx(strength * probe.panning_strength, Sound3D.PAN_FULL), "full panning: project 3d_panning_strength %.2f x voice %.2f = %.2f (wanted %.2f)" % [strength, probe.panning_strength, strength * probe.panning_strength, Sound3D.PAN_FULL])
	probe.free()
	_static_checks()

	_capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(0, _capture)
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var eye: Camera3D = Camera3D.new()
	world.add_child(eye)
	var drawn: Camera3D = Camera3D.new()          # the third-person camera: 3 m back and a little up, the one drawn
	eye.add_child(drawn)
	drawn.position = Vector3(0.0, 0.36, 3.0)
	drawn.current = true

	# Through the drawn camera alone (no ears), a source 2 m right of the head is only about 34 degrees off and stays in both ears.
	var before: float = await _left_minus_right(world, Vector3(2.0, 0.0, 0.0))
	var ears: AudioListener3D = Sound3D.ears(eye)
	check(ears.is_current() and ears.global_position.is_equal_approx(eye.global_position), "the ears are current, at the eye")
	var right: float = await _left_minus_right(world, Vector3(2.0, 0.0, 0.0))
	var ahead: float = await _left_minus_right(world, Vector3(0.0, 0.0, -5.0))
	var thirty: float = await _left_minus_right(world, Vector3(sin(deg_to_rad(30.0)), 0.0, -cos(deg_to_rad(30.0))) * 5.0)
	print("left minus right: drawn camera only %.1f dB, ears right %.1f dB, ahead %.1f dB, 30 degrees right %.1f dB" % [before, right, ahead, thirty])
	check(not is_nan(right), "the mixer ran (frames captured)")
	check(right <= -20.0, "a sound straight to the right is in the right ear only (%.1f dB)" % right)
	check(absf(ahead) <= 1.0, "a sound straight ahead is even (%.1f dB)" % ahead)
	check(thirty <= -3.5, "a sound 30 degrees right leans right clearly (%.1f dB)" % thirty)
	check(right < before - 10.0, "the ears at the eye pan harder than the drawn camera behind (%.1f against %.1f dB)" % [right, before])

	await _rear_checks(world, ears)
	_event_checks(world)
	_animal_checks(world)
	_other_steps(world)
	await _other_step_voice(world)
	print("world sound 3d: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# Plays a steady mono tone at `at` and returns the level of the left ear minus the right, in dB (NAN when nothing was mixed).
func _left_minus_right(world: Node3D, at: Vector3) -> float:
	var heard: Vector3 = await _mix(world, at, "Master", false)

	if heard.x + heard.y <= 0.0:
		return NAN

	return 10.0 * log(maxf(heard.x, 1e-12) / maxf(heard.y, 1e-12)) / log(10.0)


# Plays a steady mono tone at `at` on `bus` (with `bright` a high one mixed in) through the mixer; returns the energy of the left ear,
# the right ear and of the change between samples (the top of the sound) as x, y, z. Waits for enough mixed frames, however fast or
# slow the loop runs against the mixer.
func _mix(world: Node3D, at: Vector3, bus: String, bright: bool) -> Vector3:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	var tone: AudioStreamGenerator = AudioStreamGenerator.new()
	tone.mix_rate = 44100.0
	player.stream = tone
	player.unit_size = 10.0
	player.bus = bus
	world.add_child(player)
	player.global_position = at
	player.play()
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var heard: Vector3 = Vector3.ZERO
	var phase: float = 0.0
	var last: float = 0.0
	var settle_until: int = Time.get_ticks_msec() + 400   # the pan settles and the old voice's tail drains first
	var give_up: int = Time.get_ticks_msec() + 4000
	var counted: int = 0

	while counted < 8000 and Time.get_ticks_msec() < give_up:
		for n in playback.get_frames_available():
			phase += 1.0
			var sample: float = 0.5 * sin(phase * 0.06) if not bright else 0.25 * sin(phase * 0.06) + 0.25 * sin(phase * 1.4)   # 420 Hz, and 9.8 kHz
			playback.push_frame(Vector2.ONE * sample)

		await process_frame
		var got: int = _capture.get_frames_available()

		if got <= 0:
			continue

		var buffer: PackedVector2Array = _capture.get_buffer(got)

		if Time.get_ticks_msec() < settle_until:
			continue

		counted += buffer.size()

		for v in buffer:
			heard.x += v.x * v.x
			heard.y += v.y * v.y
			heard.z += (v.x - last) * (v.x - last)
			last = v.x

	player.queue_free()
	await process_frame
	return heard


# Behind the ears (Sound3D.place_rear): the same sound 5 m straight behind comes out a little softer and darker than 5 m ahead, and the
# choice holds across the hysteresis.
func _rear_checks(world: Node3D, ears: AudioListener3D) -> void:
	var at_ears: Transform3D = ears.global_transform
	check(is_zero_approx(Sound3D.rear_share(at_ears, at_ears.origin + Vector3(0.0, 0.0, -5.0))), "ahead: rear share 0")
	check(is_zero_approx(Sound3D.rear_share(at_ears, at_ears.origin + Vector3(5.0, 0.0, 0.0))), "beside: rear share 0")
	check(is_equal_approx(Sound3D.rear_share(at_ears, at_ears.origin + Vector3(0.0, 2.0, 5.0)), 1.0), "behind (and above): rear share 1")

	if AudioServer.get_bus_index("Foley") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Foley")

	var probe: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	probe.bus = "Foley"
	check(not Sound3D.place_rear(probe, 0.45) and String(probe.bus) == "Foley", "0.45 behind from the front: stays on Foley")
	check(Sound3D.place_rear(probe, 0.6) and String(probe.bus) == "Rear_Foley", "0.6 behind: on Rear_Foley")
	check(Sound3D.place_rear(probe, 0.45) and String(probe.bus) == "Rear_Foley", "back to 0.45: still behind (hysteresis)")
	check(not Sound3D.place_rear(probe, 0.2) and String(probe.bus) == "Foley", "0.2: back on Foley")
	probe.bus = "Master"
	check(not Sound3D.place_rear(probe, 1.0) and String(probe.bus) == "Master", "a voice on another bus (a bed, a band) is left alone")
	probe.free()

	var front: Vector3 = await _mix(world, at_ears.origin + Vector3(0.0, 0.0, -5.0), "Foley", true)
	var back: Vector3 = await _mix(world, at_ears.origin + Vector3(0.0, 0.0, 5.0), Sound3D.rear_bus("Foley"), true)
	var level_db: float = 10.0 * log(maxf(back.x + back.y, 1e-12) / maxf(front.x + front.y, 1e-12)) / log(10.0)
	var top_db: float = 10.0 * log(maxf(back.z / maxf(back.x, 1e-12), 1e-12) / maxf(front.z / maxf(front.x, 1e-12), 1e-12)) / log(10.0)
	print("behind against ahead: level %.1f dB, top of the sound %.1f dB more down" % [level_db, top_db])
	check(level_db <= -1.0 and level_db >= -5.0, "behind is a little softer, not hidden (%.1f dB)" % level_db)
	check(top_db <= -1.5 and top_db >= -8.0, "behind is darker, not muffled (top %.1f dB)" % top_db)


# A world voice: positional at `at`, falls off with distance, ends somewhere, cover can muffle it.
func _positional(found: Array, at: Vector3, what: String) -> void:
	check(found.size() >= 1, "%s: a voice was made" % what)

	for player in found:
		var ok: bool = player is AudioStreamPlayer3D and (player as AudioStreamPlayer3D).global_position.is_equal_approx(at)
		check(ok, "%s: an AudioStreamPlayer3D at its place" % what)

		if ok:
			var voice: AudioStreamPlayer3D = player
			check(voice.attenuation_model != AudioStreamPlayer3D.ATTENUATION_DISABLED and voice.max_distance > 0.0, "%s: falloff with a reach (unit %.1f m, reach %.0f m)" % [what, voice.unit_size, voice.max_distance])
			check(voice.is_in_group("world_sounds"), "%s: in world_sounds" % what)


func _made(host: Node, before: int) -> Array:
	var out: Array = []

	for n in range(before, host.get_child_count()):
		var child: Node = host.get_child(n)

		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			out.append(child)

	return out


func _event_checks(world: Node3D) -> void:
	var stage: StubStage = StubStage.new()
	world.add_child(stage)
	var at: Vector3 = Vector3(6.0, 0.0, -9.0)

	var creatures = CreatureSounds.new()
	stage.add_child(creatures)
	creatures.setup(stage)
	var count: int = creatures.get_child_count()
	creatures.call_at("deer", at, "alert")
	_positional(_made(creatures, count), at, "an animal's call")

	var slots: SlotSounds = SlotSounds.new()
	stage.add_child(slots)
	slots.setup(stage)
	count = slots.get_child_count()
	slots.play("deer_step", at, Vector3.ZERO)
	_positional(_made(slots, count), at, "an animal's step")

	var spear = SpearSounds.new()
	stage.add_child(spear)
	spear.setup(stage)
	count = spear.get_child_count()
	spear.hit("flesh", at, 1.0)
	_positional(_made(spear, count), at, "a blow landing on an animal")

	var gear = GearSounds.new()
	stage.add_child(gear)
	gear.setup(stage)
	count = gear.get_child_count()
	gear.step_at(["leather", "hobnail"], at, 1, "dirt")
	_positional(_made(gear, count), at, "another character's step")


func _static_checks() -> void:
	var files: Array = []
	_scripts("res://src/client", files)
	var flat_in: Array = []
	var odd_pan: Array = []

	for path in files:
		var text: String = FileAccess.get_file_as_string(path)
		var key: String = path.trim_prefix("res://")

		if text.contains("AudioStreamPlayer.new()") and not FLAT_OK.has(key):
			flat_in.append(key)

		if text.contains("panning_strength =") and key != "src/client/sound_3d.gd":
			odd_pan.append(key)

	check(flat_in.is_empty(), "flat players only in the own-body, UI and bed modules (also in: %s)" % ", ".join(flat_in))
	check(odd_pan.is_empty(), "no voice changes its own panning strength (%s)" % ", ".join(odd_pan))

	for key in FLAT_OK:
		check(FileAccess.file_exists("res://" + key), "listed flat module exists: %s" % key)


func _scripts(dir_path: String, out: Array) -> void:
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			out.append(dir_path + "/" + file)

	for sub in DirAccess.get_directories_at(dir_path):
		_scripts(dir_path + "/" + sub, out)


# Steps counted from another player's drawn travel: walking 3.2 m/s for 3 s is 8 steps of 1.2 m, running 9 m/s is 9 steps of 3 m.
func _other_steps(world: Node3D) -> void:
	var view = PlayerView.new()
	world.add_child(view)
	var node: Node3D = Node3D.new()
	world.add_child(node)
	node.position = Vector3(4.0, 10.9, 0.0)
	var heard: Array = []
	view.stepped.connect(func(at: Vector3, gait: int, crouched: bool) -> void: heard.append([at, gait, crouched]))
	var cases: Array = [[3.2, Stance.STAND, 0, 8, 0], [9.0, Stance.STAND, 0, 9, 2], [3.2, Stance.CROUCH, 0, 8, 0], [3.2, Stance.LIE, 0, 0, 0],
		[3.2, Stance.STAND, PlayerView.SWIM, 0, 0], [0.5, Stance.STAND, 0, 0, 0]]

	for c in cases:
		heard.clear()
		var b: Dictionary = {"node": node, "state": int(c[1]) | int(c[2])}

		for n in 60:
			view._count_steps(b, Vector3(float(c[0]), 0.0, 0.0), 0.05, 10.0)

		var ok: bool = heard.size() == int(c[3])

		for h in heard:
			ok = ok and (h[0] as Vector3).is_equal_approx(Vector3(4.0, 10.0, 0.0)) and int(h[1]) == int(c[4]) and bool(h[2]) == (int(c[1]) == Stance.CROUCH)

		check(ok, "another player at %.1f m/s, stance %d%s: %d steps at the feet, gait %d (heard %d)" % [c[0], c[1], " swimming" if int(c[2]) != 0 else "", c[3], c[4], heard.size()])

	heard.clear()
	var far: Dictionary = {"node": node, "state": Stance.STAND}

	for n in 60:
		view._count_steps(far, Vector3(3.2, 0.0, 0.0), 0.05, PlayerView.STEP_HEAR_M + 5.0)

	check(heard.is_empty(), "no steps counted past hearing (%d)" % heard.size())


# Another player's step voice (sound_stage.gd play_other_step, other_step_room): positional at the feet, and at most OTHER_STEP_VOICES at once.
func _other_step_voice(world: Node3D) -> void:
	var stage: SoundStage = SoundStage.new()
	world.add_child(stage)

	for wind in ["_wind_low", "_wind_gust"]:                # set up by setup() in the game; its _exit_tree stops them
		var bed: AudioStreamPlayer = AudioStreamPlayer.new()
		stage.add_child(bed)
		stage.set(wind, bed)

	var feet: Vector3 = Vector3(-3.0, 0.0, 5.0)
	var count: int = stage.get_child_count()
	check(stage.other_step_room() and stage.play_other_step(feet, "dirt", [0.0, 1.0], 0, false), "another player's step plays")
	_positional(_made(stage, count), feet, "another player's step")
	check(stage.others_steps == 1, "counted (%d)" % stage.others_steps)

	for n in range(SoundStage.OTHER_STEP_VOICES - 1):
		stage.play_other_step(feet, "gravel", [0.0, 1.0], 2, false)

	check(not stage.other_step_room(), "no room past %d other players' steps sounding" % SoundStage.OTHER_STEP_VOICES)

	for child in stage.get_children():
		if child is AudioStreamPlayer3D:
			child.queue_free()

	await process_frame
	check(stage.other_step_room(), "room again once they end")


# A fight is heard from the animal: a wolf's attack and a black bear's or an elk's warning call (stand-in clips), close calls keep getting
# louder (max_db), and attacker_near finds who is biting.
func _animal_checks(world: Node3D) -> void:
	check(7 in AnimalView.VOICED_STATES and 16 in AnimalView.VOICED_STATES, "a wolf's attack (7) and the jaw-pop warning (16) are voiced")
	var stage: StubStage = StubStage.new()
	world.add_child(stage)
	var creatures = CreatureSounds.new()
	stage.add_child(creatures)
	creatures.setup(stage)

	for kind in ["black_bear", "elk", "wolf"]:
		var count: int = creatures.get_child_count()
		var at: Vector3 = Vector3(3.0, 0.0, -4.0)
		check(creatures.call_at(kind, at, "threat"), "%s's threat call plays" % kind)
		_positional(_made(creatures, count), at, "%s's threat call" % kind)
		var made: Array = _made(creatures, count)
		check(not made.is_empty() and is_equal_approx((made[0] as AudioStreamPlayer3D).max_db, CreatureSounds.NEAR_MAX_DB), "%s's call keeps rising close by (max_db %.0f)" % [kind, CreatureSounds.NEAR_MAX_DB])

	var view = AnimalView.new()
	world.add_child(view)
	var wolf: Node3D = Node3D.new()
	world.add_child(wolf)
	wolf.global_position = Vector3(2.0, 0.0, 0.0)
	var deer: Node3D = Node3D.new()
	world.add_child(deer)
	deer.global_position = Vector3(1.0, 0.0, 0.0)
	view._bodies = {1: {"node": wolf, "state": 7, "kind": "wolf"}, 2: {"node": deer, "state": 2, "kind": "deer"}}
	var who: Dictionary = view.attacker_near(Vector3.ZERO, 5.0)
	check(str(who.get("kind", "")) == "wolf" and (who["at"] as Vector3).is_equal_approx(wolf.global_position), "the biting wolf is found, not the nearer fleeing deer (%s)" % str(who))
	check(view.attacker_near(Vector3(20.0, 0.0, 0.0), 5.0).is_empty(), "no attacker past 5 m")
	view._bodies = {}
