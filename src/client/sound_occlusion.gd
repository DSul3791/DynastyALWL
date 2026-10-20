extends Node

# Muffling for sounds in the world (client only): a call, a stream or a dig sound behind a hill
# or far off through dense forest loses its high end, the way it does in real life.
#
# Every world sound (a 3D player in the group "world_sounds") gets a low-pass cutoff:
# - Forest: a share of the trees around the player (AmbientLife.weights["forest"]) times how
#   far the source is dulls it (the trunks and leaves in between), down to 45 % of the cutoff.
# - Hills (Mid and High only): one voxel ray from the head to the source; ground in the way drops
#   the cutoff to HILL_HZ. Low skips the ray: it has the forest filter only.
# Updated every SCAN_SEC and eased, so nothing jumps. Nothing is done while flying (admin tool).
# A voxel ray reads the loaded ground data, so it works past the distance with physics colliders.

const EASE_TICK_SEC := 0.05            # the cutoff easing runs at 20 Hz
const SCAN_SEC := 0.5
const OPEN_HZ := 9000.0                 # the distance filter's cutoff for a clear path
const HILL_HZ := 700.0                  # behind a hill
const FOREST_FLOOR := 0.45              # dense forest at long range: this share of the cutoff
const FOREST_FULL_M := 80.0             # distance at which the forest dulling is full
const NEAR_M := 8.0                     # closer than this nothing is muffled
const MARGIN_M := 1.5                   # ground this close to the source does not count as in the way
const EASE_PER_SEC := 3.0               # of the way to the target cutoff per second

var occluded: int = 0                   # sources behind a hill at the last scan (HUD)
var filtered: int = 0                   # sources with a cutoff below open at the last scan

var _stage                              # SoundStage (tier, ambient weights)
var _tool: VoxelTool
var _ease_acc: float = 0.0
var _scan_left: float = 0.0
var _targets: Dictionary = {}           # player instance id -> target cutoff


func setup(stage, terrain: VoxelLodTerrain) -> void:
	_stage = stage
	_tool = terrain.get_voxel_tool()
	_tool.channel = VoxelBuffer.CHANNEL_SDF


func update(delta: float, body: CharacterBody3D, flying: bool) -> void:
	_scan_left -= delta

	if _scan_left <= 0.0:
		_scan_left = SCAN_SEC
		_scan(body, flying)

	_ease_acc += delta

	if _ease_acc < EASE_TICK_SEC:
		return

	var ease_k: float = clampf(_ease_acc * EASE_PER_SEC, 0.0, 1.0)
	_ease_acc = 0.0

	for node in get_tree().get_nodes_in_group("world_sounds"):
		var player: AudioStreamPlayer3D = node as AudioStreamPlayer3D

		if player != null and _targets.has(player.get_instance_id()):
			player.attenuation_filter_cutoff_hz = lerpf(player.attenuation_filter_cutoff_hz, float(_targets[player.get_instance_id()]), ease_k)


func _scan(body: CharacterBody3D, flying: bool) -> void:
	_targets.clear()
	occluded = 0
	filtered = 0
	var head: Vector3 = body.global_position + Vector3(0.0, 0.6, 0.0)
	var forest: float = float(_stage.ambient.weights["forest"])

	for node in get_tree().get_nodes_in_group("world_sounds"):
		var player: AudioStreamPlayer3D = node as AudioStreamPlayer3D

		if player == null or not player.playing:
			continue

		var to: Vector3 = player.global_position - head
		var distance: float = to.length()
		var cutoff: float = OPEN_HZ

		if distance > NEAR_M and not flying:
			cutoff *= lerpf(1.0, FOREST_FLOOR, forest * clampf(distance / FOREST_FULL_M, 0.0, 1.0))

			if _stage.preset["occlusion_rays"]:
				var hit = _tool.raycast(head, to / distance, distance)

				if hit != null and hit.distance < distance - MARGIN_M:
					cutoff *= HILL_HZ / OPEN_HZ
					occluded += 1

		if cutoff < OPEN_HZ - 1.0:
			filtered += 1

		_targets[player.get_instance_id()] = cutoff
