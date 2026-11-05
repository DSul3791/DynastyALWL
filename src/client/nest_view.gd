extends Node3D
# Inland bird nests (MikeW 5 Nov; spots: server_animals.nest_spots_near, protocol 91 net.nests). The server sends every grouse and
# songbird nest within send_radius_m of the player whenever the set changes; every call redraws the whole set. The look is
# basic_look.gd's ground "nest" (a ring of dry grass round a hollow, pale eggs in it), drawn larger as on the beach (shore_props.gd):
# a grouse scrape in heather and long grass is wide and low; a songbird cup is smaller and a little darker. In the kind's laying
# seasons (data/items/nests.json) the nest shows eggs; out of season it is an old empty nest, as the server says when you look in.
# A nest robbed this season still shows eggs here: the robbed record is on the server only. One MultiMesh per kind and season look,
# so all nests are at most four draw calls.
#
# Shared with Jason's nest calls (5 Nov): spots and kinds are the last set the server sent, kind 0 grouse, 1 songbird; nearest()
# finds the closest one.

const BasicLook := preload("res://src/client/basic_look.gd")

const KINDS := ["grouse", "songbird"]
const SCALE := {"grouse": 2.4, "songbird": 1.5}            # the item look is about 0.2 m across: a grouse scrape about 0.5 m, a songbird cup about 0.3 m
const TINT := {"grouse": Color(0.66, 0.565, 0.353), "songbird": Color(0.478, 0.392, 0.251)}   # dry grass and heather; a cup of darker twigs and moss
const SINK := 0.02                                          # sunk a little so the rim never floats on a slope

var spots: PackedVector3Array = PackedVector3Array()
var kinds: PackedByteArray = PackedByteArray()
var _season: String = ""
var _seasons: Dictionary = {}                               # kind -> the seasons it lays in (nests.json)
var _multi: Dictionary = {}                                 # "kind:full" or "kind:empty" -> MultiMeshInstance3D


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/nests.json"))
	var rows: Dictionary = parsed.get("kinds", {}) if typeof(parsed) == TYPE_DICTIONARY else {}

	for kind in KINDS:
		_seasons[kind] = rows.get(kind, {}).get("seasons", [])


func on_nests(points: PackedVector3Array, kind_ids: PackedByteArray) -> void:
	spots = points
	kinds = kind_ids
	_redraw()


# Called with the game season (terrain_client, beside the shore props); a change of season swaps eggs in or out.
func set_season(season: String) -> void:
	if season != _season:
		_season = season
		_redraw()


# The index of the nearest nest within reach metres of a point (flat distance), or -1.
func nearest(point: Vector3, reach: float) -> int:
	var best: int = -1
	var best_d: float = reach

	for i in spots.size():
		var d: float = Vector2(spots[i].x - point.x, spots[i].z - point.z).length()

		if d <= best_d:
			best_d = d
			best = i

	return best


func _redraw() -> void:
	var groups: Dictionary = {}

	for i in spots.size():
		var kind: String = KINDS[clampi(int(kinds[i]) if i < kinds.size() else 0, 0, KINDS.size() - 1)]
		var key: String = kind + (":full" if _seasons.get(kind, []).has(_season) else ":empty")

		if not groups.has(key):
			groups[key] = []

		groups[key].append(spots[i])

	for key in _multi:
		if not groups.has(key):
			_multi[key].multimesh.instance_count = 0

	for key in groups:
		var kind: String = str(key).get_slice(":", 0)
		var mm: MultiMesh = _multi_for(str(key)).multimesh
		var at_list: Array = groups[key]
		var size: float = float(SCALE[kind])
		mm.instance_count = at_list.size()

		for i in at_list.size():
			var at: Vector3 = at_list[i]
			var seed_v: float = fposmod(sin(at.x * 12.9898 + at.z * 78.233) * 43758.5453, 1.0)
			var each: float = size * (0.9 + 0.2 * seed_v)
			var nest_basis: Basis = Basis(Vector3.UP, seed_v * TAU).scaled(Vector3.ONE * each)
			mm.set_instance_transform(i, Transform3D(nest_basis, at + Vector3(0.0, 0.055 * each + 0.005 - SINK, 0.0)))   # the look's floor sits 0.055 below its middle, as shore_props lifts it


func _multi_for(key: String) -> MultiMeshInstance3D:
	if not _multi.has(key):
		var kind: String = key.get_slice(":", 0)
		var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
		instance.name = "Nests_" + key.replace(":", "_")
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = BasicLook.mesh("nest", TINT[kind], 1.0, ["empty"] if key.ends_with(":empty") else [])
		instance.multimesh = multi
		add_child(instance)
		_multi[key] = instance

	return _multi[key]
