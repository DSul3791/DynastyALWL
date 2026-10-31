extends SceneTree

# Headless check (Sonny, 30 Oct 2026): the local character store (src/client/character/character_store.gd), the active-character genome of my_character.gd and the
# character select page's list, selection, rename and delete. Uses user://characters_test, never the real characters.
#   godot --headless --path . --script res://tools/check_character_store.gd
# Exit code 1 on any failure.

const Store := preload("res://src/client/character/character_store.gd")
const MyCharacter := preload("res://src/client/character/my_character.gd")
const Generator := preload("res://src/client/character/body_generator.gd")
const Select := preload("res://scenes/character_select/character_select.tscn")
const TEST_DIR := "user://characters_test"

var _fails: int = 0
var _checked: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	Store.dir = TEST_DIR
	_wipe()
	_check_store()
	await _check_page()
	_wipe()
	print("checked %d cases, %d failures" % [_checked, _fails])
	quit(1 if _fails > 0 else 0)


func _ok(ok: bool, what: String) -> void:
	_checked += 1

	if not ok:
		_fails += 1
		print("FAIL  " + what)


func _wipe() -> void:
	if DirAccess.dir_exists_absolute(TEST_DIR):
		for file in DirAccess.get_files_at(TEST_DIR):
			DirAccess.remove_absolute(TEST_DIR + "/" + file)


func _code(preset: String) -> String:
	return Generator.encode(Generator.make_genome(preset))


func _check_store() -> void:
	_ok(Store.list().is_empty() and Store.count() == 0 and Store.active().is_empty(), "an empty store has no characters and no active one")
	_ok(Store.add("", _code("average")) == "" and Store.add(" Hob", _code("average")) == "" and Store.add("X".repeat(25), _code("average")) == "", "empty, padded and too long names are refused")
	_ok(Store.add("Hob", "not a code") == "", "a broken body code is refused")
	_ok(Store.count() == 0, "refused characters are not saved")
	var a: String = Store.add("Hob Fennel", _code("average"))
	var b: String = Store.add("Wren", _code("lean"))
	var c: String = Store.add("Brock", _code("broad"))
	_ok(a != "" and b != "" and c != "" and a != b and b != c, "three characters save with different ids")
	var names: Array = []

	for one in Store.list():
		names.append(one["name"])

	_ok(names == ["Hob Fennel", "Wren", "Brock"], "the list is oldest first (%s)" % str(names))
	_ok(Store.get_character(b)["code"] == _code("lean") and not Store.get_character(b)["genome"].is_empty(), "a character keeps its share code and decodes")
	_ok(Store.active()["name"] == "Brock", "with no choice made the newest character is active")
	_ok(Store.set_active(a) and Store.active_id() == a and Store.active()["name"] == "Hob Fennel", "set_active picks one")
	_ok(not Store.set_active("nope"), "an unknown id cannot be made active")
	var genome: Dictionary = MyCharacter.genome()
	_ok(not genome.is_empty() and Generator.encode(genome) == _code("average"), "my_character.genome() is the active character's genome")
	Store.set_active(c)
	_ok(Generator.encode(MyCharacter.genome()) == _code("broad"), "and follows a change of active character")
	_ok(Store.rename(b, "Wren Ash") and Store.get_character(b)["name"] == "Wren Ash" and Store.get_character(b)["code"] == _code("lean"), "rename changes the name and keeps the body")
	_ok(not Store.rename(b, "") and not Store.rename("nope", "Zed") and Store.get_character(b)["name"] == "Wren Ash", "a bad rename changes nothing")
	var junk := FileAccess.open(TEST_DIR + "/junk.json", FileAccess.WRITE)
	junk.store_string("{not a character")
	junk.close()
	var broken := FileAccess.open(TEST_DIR + "/5.json", FileAccess.WRITE)
	broken.store_string("{\"name\": \"Ghost\", \"genome_code\": \"bad\", \"base\": {}}")
	broken.close()
	_ok(Store.count() == 3, "files that are not characters are skipped")
	_ok(Store.delete(c) and Store.count() == 2 and Store.get_character(c).is_empty(), "delete removes the character")
	_ok(Store.active_id() == "" and Store.active()["name"] == "Wren Ash", "deleting the active character falls back to the newest")
	_ok(not Store.delete(c), "deleting twice says no")
	_ok(Store.delete(a) and Store.delete(b) and Store.active().is_empty(), "deleting the rest empties the store")
	_check_identity()
	Store.add("Name with 24 characters ok", _code("average"))
	_ok(Store.count() == 0, "a 26 character name is refused")
	_ok(Store.add("Name with 24 characters.", _code("average")) != "", "a 24 character name is accepted")
	_wipe()


func _check_identity() -> void:
	_wipe()
	var w: String = Store.add("Wren", _code("lean"), "woman")
	var m: String = Store.add("Brock", _code("broad"), "man")
	var n: String = Store.add("Sky", _code("average"), "non_binary", "she_her", "feminine")
	var p: String = Store.add("Quill", _code("average"), "prefer_not_to_say")
	var one: Dictionary = Store.get_character(w)
	_ok(one["gender"] == "woman" and one["pronouns"] == "she_her" and one["frame"] == "feminine", "a woman defaults to she/her and the feminine frame")
	one = Store.get_character(m)
	_ok(one["gender"] == "man" and one["pronouns"] == "he_him" and one["frame"] == "masculine", "a man defaults to he/him and the masculine frame")
	one = Store.get_character(n)
	_ok(one["gender"] == "non_binary" and one["pronouns"] == "she_her" and one["frame"] == "feminine", "pronouns and frame can be chosen freely whatever the gender")
	one = Store.get_character(p)
	_ok(one["pronouns"] == "they_them" and one["frame"] == "neutral", "prefer not to say defaults to they/them and the neutral frame")
	_ok(Store.add("Zed", _code("average"), "robot") == "" and Store.add("Zed", _code("average"), "man", "it_its") == "" and Store.add("Zed", _code("average"), "man", "he_him", "round") == "", "unknown gender, pronouns or frame are refused")
	_ok(Store.rename(w, "Wren Ash") and Store.get_character(w)["gender"] == "woman" and Store.get_character(w)["pronouns"] == "she_her" and Store.get_character(w)["frame"] == "feminine", "rename keeps gender, pronouns and frame")
	_ok(Store.set_pronouns(m, "they_them") and Store.get_character(m)["pronouns"] == "they_them" and Store.get_character(m)["gender"] == "man" and Store.get_character(m)["name"] == "Brock", "pronouns can be changed later")
	_ok(not Store.set_pronouns(m, "xe") and not Store.set_pronouns("nope", "he_him"), "bad pronouns or an unknown character change nothing")
	# A version 1 file (before gender, pronouns and frame).
	var legacy := FileAccess.open(TEST_DIR + "/1.json", FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"name": "Old Hob", "genome_code": _code("average"), "ancestry": "", "background": "", "fear": 1, "method": "points", "roll_seed": 0, "rerolls": 0, "base": {"luck": 0, "fitness": 0, "strength": 0, "dexterity": 0, "memory": 0, "wisdom": 0, "courage": 0}}))
	legacy.close()
	one = Store.get_character("1")
	_ok(not one.is_empty() and one["gender"] == "prefer_not_to_say" and one["pronouns"] == "they_them" and one["frame"] == "neutral", "a version 1 file loads with the plain defaults")
	_wipe()


func _check_page() -> void:
	var a: String = Store.add("Hob", _code("average"))
	var b: String = Store.add("Wren", _code("lean"))
	Store.set_active(b)
	var page: Control = Select.instantiate()
	page.auto_creator = false
	root.add_child(page)
	await process_frame
	_ok(page._rows.get_child_count() == 2, "the page lists two characters")
	var about: Label = page._rows.get_child(1).find_child("AboutLabel", true, false)
	_ok(about != null and about.text == "Prefer not to say, they/them", "the page shows gender and pronouns under the name")
	_ok(page.selected_id == b and not page._play.disabled, "the active character starts selected and Play is ready")
	(page._rows.get_child(0) as Button).button_pressed = true
	(page._rows.get_child(0) as Button).pressed.emit()
	_ok(page.selected_id == a, "picking a row selects that character")
	page._rename_edit.text = "Hob Long"
	page._rename_selected()
	await process_frame
	_ok(Store.get_character(a)["name"] == "Hob Long" and page._rows.get_child_count() == 2, "rename from the page works and the list is rebuilt")
	_ok(page.selected_id == a, "the selection survives a rename")
	page._delete_selected()
	await process_frame
	_ok(Store.count() == 1 and page._rows.get_child_count() == 1 and page.selected_id == b, "delete from the page removes it and selects the one left")
	page._delete_selected()
	await process_frame
	_ok(Store.count() == 0 and page._play.disabled and page.selected_id == "", "with none left Play is disabled")
	page.queue_free()
	_wipe()
