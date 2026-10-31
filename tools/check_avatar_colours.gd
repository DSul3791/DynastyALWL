extends SceneTree

# Headless check (Sonny, 30 Oct 2026): in the game the generated body wears the skin and the tunic, trousers and boots colours the player chose in the creator (AvatarDriver.dress),
# the old body keeps its fixed colours, and a worn item still colours its slot over the choice.
#   godot --headless --path . --script res://tools/check_avatar_colours.gd
# Exit code 1 on any failure.

const Driver := preload("res://src/client/character/avatar_driver.gd")
const GeneratedBody := preload("res://src/client/character/generated_body.gd")
const Generator := preload("res://src/client/character/body_generator.gd")

var _fails: int = 0
var _checked: int = 0


class TableStub:
	extends RefCounted

	func id_of(_n: int) -> String:
		return ""

	func entry(_id: String) -> Dictionary:
		return {}


class ItemsStub:
	extends RefCounted
	var worn: Array = []
	var table: RefCounted = TableStub.new()


func _initialize() -> void:
	var g: Dictionary = Generator.make_genome("average", Color(0.3, 0.2, 0.15), Color(0.1, 0.1, 0.1), Color(0.8, 0.1, 0.1), Color(0.1, 0.8, 0.1), Color(0.1, 0.1, 0.8))
	var body: Node3D = GeneratedBody.new(g, 0.07, false)
	root.add_child(body)
	Driver.dress(body, ItemsStub.new())
	var mat: ShaderMaterial = body.body_mesh.material_override as ShaderMaterial
	_ok((mat.get_shader_parameter("skin_color") as Color).is_equal_approx(Color(0.3, 0.2, 0.15)), "the game skin is the creator's skin")
	_ok((mat.get_shader_parameter("tunic_color") as Color).is_equal_approx(Color(0.8, 0.1, 0.1)), "the tunic is the creator's tunic colour")
	_ok((mat.get_shader_parameter("trouser_color") as Color).is_equal_approx(Color(0.1, 0.8, 0.1)), "the trousers are the creator's")
	_ok((mat.get_shader_parameter("boot_color") as Color).is_equal_approx(Color(0.1, 0.1, 0.8)), "the boots are the creator's")
	var base: Dictionary = {"coat": Color(1, 0, 0), "trousers": Color(0, 1, 0), "shoes": Color(0, 0, 1)}
	var plain: Dictionary = Driver.outfit_colors([], TableStub.new(), base)
	_ok(plain["coat"] == Color(1, 0, 0) and plain["trousers"] == Color(0, 1, 0) and plain["shoes"] == Color(0, 0, 1), "with nothing worn the base colours stand")
	var defaults: Dictionary = Driver.outfit_colors([], TableStub.new())
	_ok(defaults["coat"] == Driver.COAT and defaults["shoes"] == Driver.SHOES, "and without a base the fixed colours are as they were")
	var old: Node3D = load("res://src/client/ragdoll_body.gd").new()
	root.add_child(old)
	_ok(old.get("genome") == null, "the old body has no genome, so it keeps the fixed colours")
	print("checked %d cases, %d failures" % [_checked, _fails])
	quit(1 if _fails > 0 else 0)


func _ok(ok: bool, what: String) -> void:
	_checked += 1

	if not ok:
		_fails += 1
		print("FAIL  " + what)
