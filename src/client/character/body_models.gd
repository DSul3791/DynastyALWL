extends RefCounted

# The body models a player picks from in the character creator (Dave 17 Nov 2026: "remove the gender selection in the character creation and remove gender from character.
# we will simply provide various model meshes people can choose from"). A character stores only the id of its model. To offer another mesh, add a row here.
# Labels are plain letters with a short look note, never a gender (BM-1 in docs/CHARACTER_SYSTEM.md; D-TODO-3, 21 Nov 2026: "Body A" and "Body B" instead of "Body 2").

const DEFAULT := "body_1"
const DEFAULT_GLB := "res://assets/character/Humanoid/Dynasty_Base_Male.glb"
const DEFAULT_PARTS_GLB := "res://assets/character/Humanoid/Dynasty_Base_Male_Parts_Split.glb"

# id -> label, a short look note for the creator's pick ("note"), the body glb and the first-person arm parts glb. Each model's file holds every clip CLIP_MAP plays (dynasty_body.gd), on the same 24 Mixamo bones.
# body_2: Dave's female player character (Playercharacter_Female_01.glb, 20 Nov 2026: "she should be the female selection now and be fully adjustable"). Her file
# (Dave's Dynasty_Female_Complete_Rigged_99_Actions_v2, 20 Nov 2026) holds 99 clips: her own 4 and body_1's set retargeted to her rig. Her first-person arms are still body_1's parts (no parts file for her yet).
# "hair_fit": how this body wears the hair styles (hair_models.gd), which are fitted to body_1's head: a hair point here = body_1 point * scale + offset, model space,
# metres, the skull above the ears box-fitted by tools/hair/body_fit.py. A body without one wears the hair as body_1 does.
const MODELS := {
	"body_1": {"label": "Body A", "note": "sturdy build", "glb": DEFAULT_GLB, "parts_glb": DEFAULT_PARTS_GLB},
	"body_2": {"label": "Body B", "note": "slender build", "glb": "res://assets/character/Humanoid/Playercharacter_Female_01.glb", "parts_glb": DEFAULT_PARTS_GLB,
		"hair_fit": {"scale": Vector3(0.9541, 0.9872, 1.0203), "offset": Vector3(-0.0002, 0.0217, -0.0303)}},
}


static func ids() -> Array:
	return MODELS.keys()


static func has(id: String) -> bool:
	return MODELS.has(id)


static func label(id: String) -> String:
	return str(MODELS.get(id, MODELS[DEFAULT])["label"])


# The creator's pick text: the label and its look note, "Body A, sturdy build".
static func choice(id: String) -> String:
	var row: Dictionary = MODELS.get(id, MODELS[DEFAULT])
	return "%s, %s" % [row["label"], row["note"]] if row.has("note") else str(row["label"])


static func glb(id: String) -> String:
	return str(MODELS.get(id, MODELS[DEFAULT])["glb"])


# This body's hair fit as a model-space transform (the identity for body_1).
static func hair_fit(id: String) -> Transform3D:
	var fit: Dictionary = MODELS.get(id, MODELS[DEFAULT]).get("hair_fit", {})
	return Transform3D(Basis.from_scale(fit.get("scale", Vector3.ONE)), fit.get("offset", Vector3.ZERO))
