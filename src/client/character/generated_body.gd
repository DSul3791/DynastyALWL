extends Node3D

# A drop-in stand-in for the old RagdollBody (src/client/ragdoll_body.gd) built from the generated body of body_generator.gd (Sonny, plan 8 of
# CHARACTER_DESIGN_VISION.md Part 8). It offers the methods and properties the game uses on the player body: skeleton, body_mesh, animation_player, hand_mount_r,
# hand_mount_l, head_mount, play, current, is_one_shot_playing, dress, set_shoulder_log. The clips are the old rig clips, converted by clip_converter.gd.
# NOT used by the game unless the client is started with --generated-body (see terrain_client.gd `_make_avatar`); off by default and untested in the running game.
# Known gaps: worn clothing pieces (worn_look.gd addresses the old bone names) are not hung on this body; the first-person arms model is still the old one.

const Generator := preload("res://src/client/character/body_generator.gd")
const Converter := preload("res://src/client/character/clip_converter.gd")
const RagdollScript := preload("res://src/client/ragdoll_body.gd")

const SHADER := """
shader_type spatial;
uniform vec3 skin_color : source_color = vec3(0.78, 0.62, 0.5);
uniform vec3 hair_color : source_color = vec3(0.25, 0.16, 0.09);
uniform vec3 lips_color : source_color = vec3(0.7, 0.4, 0.38);
uniform vec3 tunic_color : source_color = vec3(0.4, 0.34, 0.28);
uniform vec3 trouser_color : source_color = vec3(0.25, 0.22, 0.2);
uniform vec3 boot_color : source_color = vec3(0.14, 0.11, 0.09);
void fragment() {
	int id = int(floor(COLOR.a * 8.0));
	vec3 c = skin_color;
	if (id == 1) { c = hair_color; }
	else if (id == 2) { c = lips_color; }
	else if (id == 3) { c = tunic_color; }
	else if (id == 4) { c = trouser_color; }
	else if (id == 5) { c = boot_color; }
	ALBEDO = c;
	ROUGHNESS = 0.85;
}
"""

static var _shader: Shader
static var _library: AnimationLibrary       # the converted clips, built once and shared by every generated body

var arms_only: bool = false
var skeleton: Skeleton3D
var body_mesh: MeshInstance3D
var animation_player: AnimationPlayer
var hand_mount_r: Marker3D
var hand_mount_l: Marker3D
var head_mount: Marker3D
var genome: Dictionary = {}
var face: Node3D
var _material: ShaderMaterial
var _log: MeshInstance3D


func _init(genome_in: Dictionary = {}, voxel: float = 0.04, fingers: bool = true, use_cache: bool = false) -> void:
	name = "GeneratedBody"
	genome = genome_in if not genome_in.is_empty() else Generator.make_genome("average")
	var made: Dictionary = Generator.make_node(genome, voxel, fingers, use_cache)
	var rig: Node3D = made["node"]
	skeleton = made["skeleton"]
	rig.remove_child(skeleton)
	rig.free()
	add_child(skeleton)
	body_mesh = skeleton.get_node("Body") as MeshInstance3D
	face = skeleton.get_node("Face")
	set_meta("worn_fit", Generator.worn_fit(genome))
	_build_material()
	_build_mounts()
	_build_animations()


func _build_material() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER

	_material = ShaderMaterial.new()
	_material.shader = _shader
	body_mesh.material_override = _material
	dress(genome["skin"], genome["tunic"], genome["trousers"], genome["boots"])
	_material.set_shader_parameter("hair_color", genome["hair"])
	_material.set_shader_parameter("lips_color", genome["lips"])


func _mount(bone: String, mount_name: String, offset: Vector3, axes: Basis) -> Marker3D:
	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = "Attach_" + mount_name
	skeleton.add_child(attachment)
	attachment.bone_name = bone
	var marker: Marker3D = Marker3D.new()
	marker.name = mount_name
	marker.transform = Transform3D(axes, offset)
	attachment.add_child(marker)
	return marker


# A held tool origin is the grip, 7 cm below the wrist; its -Z points out along the fingers (the same as the old body, assets/character/README.md).
func _build_mounts() -> void:
	var grip: Basis = Basis(Vector3.RIGHT, -PI * 0.5)
	var hk: float = Generator.m(float(genome["hands"]), 0.8, 1.5)
	hand_mount_r = _mount("RightHand", "HandMount_R", Vector3(0.0, -0.07 * hk, 0.0), grip)
	hand_mount_l = _mount("LeftHand", "HandMount_L", Vector3(0.0, -0.07 * hk, 0.0), grip)
	var hs: float = Generator.m(float(genome["head"]), 0.85, 1.4)
	head_mount = _mount("Head", "HeadMount", Vector3(0.0, 0.14 * hs, 0.0), Basis.IDENTITY)


# The old clips (idle walk jog run crouch sit lie swing swing_fp jab throw use carry_idle carry_walk) converted to the generated skeleton. They come from a
# temporary old body, which is freed again. The hips position is in units of hips height; motion_scale turns it back into metres.
func _build_animations() -> void:
	if _library == null:
		var old: Node3D = RagdollScript.new()
		_library = Converter.convert_library(old.animation_player)
		old.free()

	skeleton.motion_scale = skeleton.get_bone_rest(skeleton.find_bone("Hips")).origin.y
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	animation_player.add_animation_library("", _library)
	animation_player.play("idle")


# The animation to show; one-shot animations (swing jab throw use) run once and hold their last frame, which is the rest pose.
func play(animation: String, speed: float = 1.0, blend: float = 0.15) -> void:
	if animation_player != null and animation_player.has_animation(animation):
		animation_player.play(animation, blend, speed)


func current() -> String:
	return String(animation_player.current_animation) if animation_player != null else ""


func is_one_shot_playing() -> bool:
	return animation_player != null and animation_player.is_playing() and animation_player.get_animation(animation_player.current_animation).loop_mode == Animation.LOOP_NONE


# Paints the body: skin, coat (the tunic), trousers and shoes (boots), one shader material, as the dress method of the old body.
func dress(skin_color: Color, coat: Color, trousers: Color, shoes: Color = Color(0.14, 0.11, 0.09)) -> void:
	_material.set_shader_parameter("skin_color", skin_color)
	_material.set_shader_parameter("tunic_color", coat)
	_material.set_shader_parameter("trouser_color", trousers)
	_material.set_shader_parameter("boot_color", shoes)


# A large log across the right shoulder: shown or hidden, `length` and `radius` in metres.
func set_shoulder_log(length: float, radius: float, color: Color = Color(0.32, 0.23, 0.15)) -> void:
	if length <= 0.0:
		if _log != null:
			_log.visible = false

		return

	if _log == null:
		var attachment: BoneAttachment3D = BoneAttachment3D.new()
		attachment.name = "Attach_ShoulderLog"
		skeleton.add_child(attachment)
		attachment.bone_name = "Chest"
		_log = MeshInstance3D.new()
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = color
		_log.material_override = material
		attachment.add_child(_log)

	(_log.material_override as StandardMaterial3D).albedo_color = color
	var cyl: CylinderMesh = _log.mesh as CylinderMesh if _log.mesh != null else CylinderMesh.new()
	cyl.top_radius = radius * 0.8
	cyl.bottom_radius = radius
	cyl.height = length
	cyl.radial_segments = 12
	_log.mesh = cyl
	_log.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_log.position = Vector3(0.18, 0.2, 0.15)
	_log.visible = true
