extends RefCounted

# One place for the settings of a world sound that comes from somewhere (client only; Dave 2026-10-23: every sound out in the world is
# directional, only the player's own body and the UI stay flat). A positional player on the sound's own bus, so the Esc volume sliders
# and the cave and air band filters keep working, in the group "world_sounds" (sound_occlusion.gd dulls it behind hills and in forest, the
# voice budget may shed it). Distances: voices 30 to 60 m, fire 15 m, tree wind 40 m, doors and chests 25 m, thunder 400 m and more.

const REFERENCE_M := 12.0               # a typical unit_size: the distance at which the sound is at its set loudness


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


# Where a source sits left or right of a listener: -1 hard left, 0 centre or straight behind or ahead, +1 hard right, from the listener's
# transform (the rig prints this for each player; it is the pan a positional player is given).
static func pan_of(listener: Transform3D, at: Vector3) -> float:
	var local: Vector3 = listener.affine_inverse() * at
	var flat: float = Vector2(local.x, local.z).length()
	return local.x / flat if flat > 0.001 else 0.0
