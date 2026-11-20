extends RefCounted

# The body models a player picks from in the character creator (Dave 17 Nov 2026: "remove the gender selection in the character creation and remove gender from character.
# we will simply provide various model meshes people can choose from"). A character stores only the id of its model. To offer another mesh, add a row here.
# Labels are plain names, never a gender (provisional BM-1 in docs/CHARACTER_SYSTEM.md).

const DEFAULT := "body_1"
const DEFAULT_GLB := "res://assets/character/Humanoid/Dynasty_Base_Male.glb"
const DEFAULT_PARTS_GLB := "res://assets/character/Humanoid/Dynasty_Base_Male_Parts_Split.glb"

# id -> label, the body glb and the first-person arm parts glb. Each model's file holds every clip CLIP_MAP plays (dynasty_body.gd), on the same 24 Mixamo bones.
# body_2: Dave's female player character (Playercharacter_Female_01.glb, 20 Nov 2026: "she should be the female selection now and be fully adjustable"). Her file
# (Dave's Dynasty_Female_Complete_Rigged_99_Actions_v2, 20 Nov 2026) holds 99 clips: her own 4 and body_1's set retargeted to her rig. Her first-person arms are still body_1's parts (no parts file for her yet).
const MODELS := {
	"body_1": {"label": "Body 1", "glb": DEFAULT_GLB, "parts_glb": DEFAULT_PARTS_GLB},
	"body_2": {"label": "Body 2", "glb": "res://assets/character/Humanoid/Playercharacter_Female_01.glb", "parts_glb": DEFAULT_PARTS_GLB},
}


static func ids() -> Array:
	return MODELS.keys()


static func has(id: String) -> bool:
	return MODELS.has(id)


static func label(id: String) -> String:
	return str(MODELS.get(id, MODELS[DEFAULT])["label"])


static func glb(id: String) -> String:
	return str(MODELS.get(id, MODELS[DEFAULT])["glb"])

