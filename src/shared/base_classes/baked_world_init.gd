# Shared initialization pattern for baked world access classes.
# Both LocalBakedBlockStore and LocalRegionProvider share this init sequence:
#   - reset() all state
#   - validate the incoming dependency (null check + is_ready)
#   - assign the dependency to a member variable
#   - set _is_ready = true
#   - print ready message
#   - return true

class_name BakedWorldInit extends RefCounted


func initialize(
	dependency: Object,
	dependency_name: String,
	close_on_reset: bool = false
) -> bool:
	reset()

	if close_on_reset:
		close()

	if dependency == null:
		push_error("BakedWorldAccess received a null %s." % dependency_name)
		return false

	if not dependency.is_ready():
		push_error("BakedWorldAccess received a %s that is not ready." % dependency_name)
		return false

	# Assign the dependency to our member variable.
	# The caller sets this field; subclasses should have a matching var declaration.
	set_dependency(dependency)

	_is_ready = true

	print(
		"BakedWorldAccess ready.",
	)

	return true


func set_dependency(dependency: Object) -> void:
	# This is called by the subclass after validating readiness.
	# Subclasses override this to assign to their specific member variable.
	pass


var _is_ready: bool = false


func reset() -> void:
	_is_ready = false


func is_ready() -> bool:
	return _is_ready
