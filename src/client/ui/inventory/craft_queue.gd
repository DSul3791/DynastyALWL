extends RefCounted

# The crafting queue under the recipe list (step 1 of docs/design/INVENTORY_CRAFTING_REPORT.md: inventory_view.gd split into four parts).
# One button per queued craft, head first; pressing one cancels it and the server hands back what it cost.
# The queue itself (craft_entries, the head's finish time) stays on the view: the network fills it and the work sounds read it.

const Net := preload("res://src/stream/terrain_net.gd")
const InventoryLook := preload("res://src/client/ui/inventory/inventory_look.gd")

var view            # the InventoryView that owns this part (src/client/inventory_view.gd): the state it shows, the text sizes and the network
var root: Control   # the top control this part built


func _init(owner_view) -> void:
	view = owner_view


# The queue's box under the recipe list; hidden while nothing is queued.
func build() -> Control:
	view._queue_box = VBoxContainer.new()
	view._queue_box.visible = false
	root = view._queue_box
	return root


# One button per queued craft; pressing it cancels the entry and the server hands back what it cost.
func rebuild() -> void:
	if view._queue_box == null:
		return

	for child in view._queue_box.get_children():
		child.queue_free()

	view._queue_head_button = null

	if view.craft_entries.is_empty():
		view._queue_box.visible = false
		return

	view._queue_box.visible = true
	var title: Label = Label.new()
	title.text = "Crafting queue  (press one to cancel it)"
	view._style(title, view.BODY_PX - 4)
	view._queue_box.add_child(title)

	for i in view.craft_entries.size():
		var button: Button = Button.new()
		button.text = queue_text(i)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		view._style(button, view.BODY_PX - 4)
		var index: int = i
		button.pressed.connect(func(): view.net.inventory_action.rpc_id(1, Net.ACT_CRAFT_CANCEL, index, 0, 0, Vector3.ZERO))
		view._queue_box.add_child(button)

		if i == 0:
			view._queue_head_button = button

			# A gold ring at the head's left fills as the craft works (look doc section 9).
			var ring_px: int = view._px(view.BODY_PX)
			var ring: Control = InventoryLook.craft_ring(view, ring_px)
			button.add_child(ring)
			ring.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
			ring.offset_left = -float(ring_px) - view._px(6)
			ring.offset_right = -view._px(6)
			ring.offset_top = -float(ring_px) * 0.5
			ring.offset_bottom = float(ring_px) * 0.5


func queue_text(index: int) -> String:
	var entry: Array = view.craft_entries[index]
	var text: String = str(view.recipes.recipe(int(entry[0])).get("name", "?"))

	if int(entry[1]) > 1:
		text += "  x%d" % int(entry[1])

	if index == 0:
		text += "   %.0f s" % ceilf(maxf(float(view._craft_head_end_msec - Time.get_ticks_msec()) / 1000.0, 0.0))

	return text
