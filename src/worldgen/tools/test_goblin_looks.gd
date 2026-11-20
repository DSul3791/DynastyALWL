extends SceneTree

# The goblin looks (data/animals/models.json goblin variants, src/client/animal_view.gd; Dave 20 Nov 2026: Vrixa Thornfang is a named Ragtooth
# camp goblin, and so is Grikka Ragtooth; wild goblins keep the two looks). Checks, on the real models and data:
# - the goblin row has four looks, Skritch, Rukz, Vrixa and Grikka, and only the last two are marked wild: false;
# - every clip name a look's row names is a clip in that look's own file;
# - make_goblin draws each look by its body number, and a wild goblin is never drawn as Vrixa or Grikka;
# - every Ragtooth member's body is a look that exists, Vrixa's and Grikka's are their own;
# - no goblin mesh casts its shadow double-sided (docs/design/CHARACTER_MESHES.md).
#   godot --headless --path . --script res://src/worldgen/tools/test_goblin_looks.gd

const AnimalViewScript := preload("res://src/client/animal_view.gd")
const TribesScript := preload("res://src/stream/server_tribes.gd")

const SCENES := [
	"res://assets/creatures/goblin_skritch/Goblin_Skritch_Ragtooth.glb",
	"res://assets/creatures/goblin_rukz/Goblin_Rukz_The_Scavenger.glb",
	"res://assets/creatures/goblin_vrixa/Goblin_Vrixa_Thornfang.glb",
	"res://assets/creatures/goblin_grikka/Goblin_Grikka_Ragtooth.glb",
]

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var models: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/models.json")) as Dictionary)["species"]
	var looks: Array = models["goblin"]["variants"]
	check(looks.size() == SCENES.size(), "the goblin has %d looks (%d)" % [SCENES.size(), looks.size()])

	for k in mini(looks.size(), SCENES.size()):
		check(str(looks[k]["scene"]) == SCENES[k], "look %d is %s" % [k, SCENES[k].get_file()])
		check(bool(looks[k].get("wild", true)) == (k < 2), "look %d is %s" % [k, "for wild goblins too" if k < 2 else "for the camp only"])

	var view = AnimalViewScript.new()

	for k in SCENES.size():
		var body: Node3D = view.make_goblin(k, 7)
		check(body != null, "make_goblin(%d) draws a body" % k)

		if body == null:
			continue

		var row: Dictionary = body.get_meta("model_row", {})
		check(str(row.get("scene", "")) == SCENES[k], "make_goblin(%d) is %s" % [k, SCENES[k].get_file()])
		var players: Array = body.find_children("*", "AnimationPlayer", true, false)
		check(not players.is_empty(), "%s has an animation player" % SCENES[k].get_file())

		if not players.is_empty():
			for role in (looks[k]["clips"] as Dictionary):
				var clip: String = str(looks[k]["clips"][role])
				check(view._clip_full(players[0], row, clip) != "", "%s has its %s clip %s" % [SCENES[k].get_file(), role, clip])

		for m in body.find_children("*", "MeshInstance3D", true, false):
			check((m as MeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED, "%s casts a one-sided shadow" % SCENES[k].get_file())

		body.free()

	var wild_seen: Dictionary = {}

	for id in 12:
		var wild: Node3D = view._make_for_species(AnimalViewScript.GOBLIN_SPECIES, id)

		if wild != null:
			wild_seen[str((wild.get_meta("model_row", {}) as Dictionary).get("scene", ""))] = true
			wild.free()

	check(wild_seen.has(SCENES[0]) and wild_seen.has(SCENES[1]), "wild goblins wear both wild looks (%s)" % str(wild_seen.keys()))
	check(not wild_seen.has(SCENES[2]) and not wild_seen.has(SCENES[3]), "no wild goblin is drawn as Vrixa or Grikka")
	view.free()

	var tribes: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(TribesScript.PATH)) as Dictionary)["tribes"]
	var named: Dictionary = {}

	for m in tribes["ragtooth"]["members"]:
		check(int(m.get("body", 0)) >= 0 and int(m.get("body", 0)) < looks.size(), "%s's body %d is a goblin look" % [m["id"], int(m.get("body", 0))])

		named[str(m["id"])] = m

	check(named.has("vrixa") and str(named["vrixa"]["name"]) == "Vrixa" and int(named["vrixa"]["body"]) == 2, "Vrixa is a Ragtooth camp goblin with her own look")
	check(named.has("grikka") and str(named["grikka"]["name"]) == "Grikka" and int(named["grikka"]["body"]) == 3, "Grikka is a Ragtooth camp goblin with her own look")
	print("goblin looks: %d failures" % failures)
	quit(1 if failures > 0 else 0)
