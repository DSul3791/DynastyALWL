extends RefCounted

# The hair styles a player picks from in the character creator (Dave 20 Nov 2026: "everyone is allowed to use any hair style and or facial hair on males or females.
# we won't label them male and female we will just include them all in the lineup on the hair selection page"). One lineup for every body model; no style is tied to one.
# A character keeps the id of its style in its genome as "hair_model" ("" is no hair) and in its share code (body_generator.gd, code version 5).
#
# To add a style: run tools/hair/prepare_hair.py on Dave's model (it cuts out Meshy's mannequin head, fits the hair to Body 1's head and makes the textures 2K), put the
# glb here in assets/character/Hair/, import it once with its textures VRAM Compressed (docs/design/CHARACTER_MESHES.md), and add a row below. Every body model wears it
# through its own "hair_fit" (body_models.gd), so a new style needs no per-body numbers.
# Labels are plain names of the cut, never a gender.

const NONE := ""
const NONE_LABEL := "No hair"

# id -> label and the hair glb (Body 1 model space, metres; dynasty_body.gd hangs it on the head bone). Ids are saved in share codes: never rename one, only add.
const STYLES := {
	"crew_cut": {"label": "Crew cut", "glb": "res://assets/character/Hair/Hair_CrewCut.glb"},
	"short_curly": {"label": "Short curly", "glb": "res://assets/character/Hair/Hair_ShortCurly.glb"},
	"slicked_back": {"label": "Slicked back", "glb": "res://assets/character/Hair/Hair_SlickedBack.glb"},
	"medium_bob": {"label": "Medium bob", "glb": "res://assets/character/Hair/Hair_MediumBob.glb"},
	"medium_shag": {"label": "Medium shag", "glb": "res://assets/character/Hair/Hair_MediumShag.glb"},
	"medium_swept_back": {"label": "Medium swept back", "glb": "res://assets/character/Hair/Hair_MediumSweptBack.glb"},
}


# The lineup in the creator: no hair first, then every style in the order above.
static func lineup() -> Array:
	return [NONE] + STYLES.keys()


static func has(id: String) -> bool:
	return STYLES.has(id)


static func label(id: String) -> String:
	return str(STYLES[id]["label"]) if STYLES.has(id) else NONE_LABEL


static func glb(id: String) -> String:
	return str(STYLES[id]["glb"]) if STYLES.has(id) else ""
