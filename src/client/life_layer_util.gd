extends RefCounted

# Small helpers shared by the animal life layer's hooks in animal_view.gd (docs/design/REVIEW_NOTES.md): the one-shot particle
# effects (puffs, splashes, spouts, steam), the transparent material they use, and the Rig the looks turn.

const RIG := "Rig"      # the node every model and code body puts its whole body under (animal_view.gd _make_model); looks turn it


# The node under which an animal's body turns, or null.
static func rig(node: Node3D) -> Node3D:
	return node.get_node_or_null(RIG) as Node3D


# Starts a one-shot particle effect at a place and frees it once its particles are gone (lifetime plus `margin` seconds).
static func fire_once(parent: Node3D, particles: CPUParticles3D, at: Vector3, margin: float) -> void:
	parent.add_child(particles)
	particles.global_position = at
	particles.emitting = true
	parent.get_tree().create_timer(particles.lifetime + margin).timeout.connect(particles.queue_free)


# A see-through particle material of one colour; `unshaded` for spray, steam and spouts that should not take the scene's shadows.
static func see_through(colour: Color, unshaded: bool = false) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	return mat
