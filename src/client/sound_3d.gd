extends RefCounted

# One place for the settings of a world sound that comes from somewhere (client only; Dave 2026-10-23: every sound out in the world is
# directional, only the player's own body and the UI stay flat). A positional player on the sound's own bus, so the Esc volume sliders
# and the cave and air band filters keep working, in the group "world_sounds" (sound_occlusion.gd dulls it behind hills and in forest, the
# voice budget may shed it). Distances: voices 30 to 60 m, fire 15 m, tree wind 40 m, doors and chests 25 m, thunder 400 m and more.
# Direction (Dave 23 Nov 2026: "the sound is not overly directional. it seems very broad and hard to pinpoint"): project.godot sets
# audio/general/3d_panning_strength to 1.0 (Godot's default 0.5 left a sound straight to one side only 6 dB down in the other ear; at 1.0
# it is in that ear alone, 30 degrees off is about 5 dB, the usual full pan of other games), and the ears sit at the eye (ears()).
# Measured on the 4.7.2 build: the pan is global x panning_strength x the sideways share, so each player keeps panning_strength 1.0
# (2.0 with the 1.0 global would fold back to half strength).

const PAN_FULL := 1.0                   # audio/general/3d_panning_strength x panning_strength: a sound straight to one side is in that ear only


# A positional player child of `parent`. `unit_size` is the distance at full loudness, `reach_m` where it ends (0 = no end),
# `cutoff_hz` the distance low-pass. `falloff` false keeps the level at any distance and only pans it (far thunder, whose level is set
# by its own volume_db and band bus). `occluded` false keeps the player out of the world_sounds group (never shed or muffled by cover).
static func make(parent: Node, bus: String, unit_size: float, reach_m: float, cutoff_hz: float = 5000.0, falloff: bool = true, occluded: bool = true) -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.bus = bus
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE if falloff else AudioStreamPlayer3D.ATTENUATION_DISABLED
	player.unit_size = unit_size
	player.max_distance = reach_m
	player.attenuation_filter_cutoff_hz = cutoff_hz
	parent.add_child(player)

	if occluded:
		player.add_to_group("world_sounds")

	return player


# The ears: an AudioListener3D on the eye node, facing the way the eye faces. Without it Godot hears from the current camera, which in
# third person sits up to the view distance behind and above the head, so a sound beside the player came from ahead, near ones lost
# their side and every distance was off by the camera's.
static func ears(eye: Node3D) -> AudioListener3D:
	var listener: AudioListener3D = AudioListener3D.new()
	listener.name = "Ears"
	eye.add_child(listener)
	listener.make_current()
	return listener


# Front or behind (coordinator for Dave, 23 Nov 2026): plain stereo pans a sound 30 degrees ahead and 30 degrees behind the same way, so
# a sound behind the ears goes through a darker, slightly softer copy of its bus, the usual cue of stereo games (the head's shadow takes
# the top off a sound from behind): a high shelf of REAR_SHELF_DB above REAR_SHELF_HZ and REAR_DB of level. Chosen with hysteresis on
# rear_share (0 beside or ahead, 1 straight behind), when a voice starts and at each sound_occlusion scan.
const REAR_PREFIX := "Rear_"
const REAR_HOMES := ["Foley", "Nature"]   # the buses of steps, calls, blows, work and doors; beds, wind, thunder and echoes keep theirs
const REAR_DB := -1.5
const REAR_SHELF_DB := -5.0
const REAR_SHELF_HZ := 4000.0
const REAR_ON := 0.55                     # about 125 degrees off the face: goes darker
const REAR_OFF := 0.35                    # about 110 degrees: back to the open bus


# 0 for a source ahead of the ears or beside them, rising to 1 straight behind, on the level (height says nothing of front or back).
static func rear_share(listener: Transform3D, at: Vector3) -> float:
	var to: Vector3 = at - listener.origin
	to.y = 0.0
	var face: Vector3 = -listener.basis.z
	face.y = 0.0

	if to.length() < 0.5 or face.length() < 0.001:
		return 0.0

	return clampf(-face.normalized().dot(to.normalized()), 0.0, 1.0)


# The darker copy of `home`, made on first use: it sends into `home`, so the sliders and the cave and band effects downstream still apply.
static func rear_bus(home: String) -> String:
	var bus_name: String = REAR_PREFIX + home

	if AudioServer.get_bus_index(bus_name) < 0:
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, home)
		AudioServer.set_bus_volume_db(index, REAR_DB)
		var shelf: AudioEffectHighShelfFilter = AudioEffectHighShelfFilter.new()
		shelf.cutoff_hz = REAR_SHELF_HZ
		shelf.gain = db_to_linear(REAR_SHELF_DB)
		AudioServer.add_bus_effect(index, shelf)

	return bus_name


# Puts a world voice on the rear copy of its bus while it is behind the ears and back on its own bus in front. True when it is behind.
# Voices on other buses (beds, a band bus, the muted bus) are left alone.
static func place_rear(player: AudioStreamPlayer3D, share: float) -> bool:
	var bus: String = String(player.bus)
	var home: String = bus.trim_prefix(REAR_PREFIX)

	if not home in REAR_HOMES:
		return false

	var behind: bool = share >= (REAR_OFF if bus != home else REAR_ON)
	var want: String = rear_bus(home) if behind else home

	if want != bus:
		player.bus = want

	return behind


static func remove_rear_buses() -> void:
	for home in REAR_HOMES:
		var index: int = AudioServer.get_bus_index(REAR_PREFIX + home)

		if index >= 0:
			AudioServer.remove_bus(index)
