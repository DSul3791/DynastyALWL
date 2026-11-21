extends RefCounted

# Camp bandits on the client (animal species 52, docs/design/BANDIT_CAMPS.md stage 2): drawn as the human ragdoll an NPC wears (npc_view.gd
# _make_rig), dressed in the "bandit" outfit (data/npcs/outfits.json) with a rough coat, the clip chosen from the server state and the
# measured speed. Shortcut: no weapon in hand and one outfit for every level; revisit with the toll (stage 4).

const NpcView := preload("res://src/client/npc_view.gd")
const WornSync := preload("res://src/client/worn_sync.gd")
const SIT := 23     # server_bandits.gd: sitting by the fire
const LIE := 24     # asleep by the fire at night
const FLEE := 2
const CHARGE := 11

static var _outfit: Array = []


static func make(id: int) -> Node3D:
	var root: Node3D = Node3D.new()
	var key: String = "bandit_%d" % id
	var ragdoll: Node3D

	if NpcView.DynastyBodyScript.available():
		ragdoll = NpcView.DynastyBodyScript.new()
		ragdoll.set_proportions(NpcView.genome_of(key))
	else:
		ragdoll = NpcView.GeneratedBodyScript.new(NpcView.BodyGenerator.genome_from_seed(key.hash() % NpcView.VARIANTS), 0.045, false, true)

	ragdoll.name = "Rig"
	root.add_child(ragdoll)
	var h: int = key.hash()
	var shade: float = 0.85 + float(h & 255) / 255.0 * 0.3
	var skin: Color = Color(0.78, 0.62, 0.5).lerp(Color(0.5, 0.36, 0.28), float((h >> 8) & 255) / 255.0 * 0.6)
	ragdoll.dress(skin, Color(0.3 * shade, 0.25 * shade, 0.2 * shade), Color(0.22 * shade, 0.19 * shade, 0.16 * shade))

	if _outfit.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(NpcView.OUTFITS_PATH))
		_outfit = WornSync.known_ids((parsed as Dictionary).get("bandit", []) if parsed is Dictionary else [])

	WornSync.apply(ragdoll, _outfit, false)
	ragdoll.play("idle")
	root.set_meta("bandit", true)
	return root


# The clip for the server state and how fast the body moves: sit, lie, run (fleeing or charging), walk, else idle.
static func clip_for(state: int, speed: float) -> String:
	if state == SIT:
		return "sit"

	if state == LIE:
		return "lie"

	if state == FLEE or state == CHARGE or speed > 3.0:
		return "run"

	return "walk" if speed > 0.4 else "idle"


static func animate(node: Node3D, state: int, speed: float) -> void:
	var ragdoll: Node3D = node.get_node("Rig")
	var clip: String = clip_for(state, speed)

	if ragdoll.current() != clip and not ragdoll.is_one_shot_playing():
		ragdoll.play(clip, 1.0, 0.25)
