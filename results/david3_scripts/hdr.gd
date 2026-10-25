extends SceneTree
const TF := preload("res://src/worldgen/tile/tile_file.gd")
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	for p in a:
		var h: Dictionary = TF.read_header(p)
		print("FILE ", p)
		var d: Dictionary = h.duplicate(); d.erase("table"); print(str(d).substr(0, 2500)); var n: int = 0; var names: Array = []; for t in h["table"]: names.append(str(t["name"]) + ":" + str(int(t["size"]))); print(names)
	quit()
