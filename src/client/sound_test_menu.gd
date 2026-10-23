class_name SoundTestMenu
extends RefCounted

# The Esc > Settings "Sound test" buttons (and the fire step the --fire test uses). Moved out of terrain_client.gd; it
# only plays sounds through the client's `sound` and says what it did in the menu note.

var time_at: int = -1                    # "Sound test time"; -1 follows the game clock
var weather_at: int = -1                 # "Sound test weather"; -1 follows the weather state
var _client
var _town_on: bool = false
var _exertion_at: int = -1
var _fire_at: int = -1
var _spear_at: int = -1
var _interior_at: int = -1
var _gear_at: int = -1
var _creature_at: int = -1
var _hit_at: int = -1
var sound:
	get: return _client.sound
var body:
	get: return _client.body
var camera:
	get: return _client.camera
var _menu_note: Label:
	get: return _client.game_menu.note


func setup(client) -> void:
	_client = client


func _menu_button(parent: VBoxContainer, text: String, action: Callable) -> Button:
	return _client.game_menu._button(parent, text, action)


func add_buttons(settings: VBoxContainer) -> void:      # `settings` is the list the buttons are added to
	_menu_button(settings, "Sound test time: change", func():
		var order: Array = [["day", 14.0, "autumn"], ["dawn", 6.0, "autumn"], ["dusk", 18.4, "autumn"], ["night", 23.0, "autumn"], ["winter day", 12.0, "winter"], ["summer dawn", 5.0, "summer"], ["spring night", 22.0, "spring"], ["clock runs", -1.0, "autumn"], ["world clock", -2.0, ""]]
		time_at = (time_at + 1) % order.size()
		var pick: Array = order[time_at]
		if float(pick[1]) == -2.0:
			time_at = -1
			_menu_note.text = "Nature sounds follow the world clock again."
			return

		sound.ambient.conditions["season"] = pick[2]
		sound.ambient.clock_runs = float(pick[1]) == -1.0

		if float(pick[1]) >= 0.0:
			sound.ambient.conditions["hour"] = pick[1]

		_menu_note.text = "Nature sounds now play as: %s (a test setting; the sky does not follow)" % pick[0])
	_menu_button(settings, "Sound test: town sounds", func():
		_town_on = not _town_on
		var here: Vector3 = body.global_position
		sound.town.set_sources([
			{"id": 1, "kind": "fire", "at": here + Vector3(6, 0, 0), "strength": 1.0},
			{"id": 2, "kind": "hammering", "at": here + Vector3(0, 0, 25), "strength": 1.0},
			{"id": 3, "kind": "crowd", "at": here + Vector3(-20, 0, 0), "strength": 1.0},
			{"id": 4, "kind": "bell", "at": here + Vector3(0, 20, -60), "strength": 1.0},
		] if _town_on else [])

		if _town_on:
			sound.town.ring_bell(here + Vector3(0, 20, -60), 3)

		_menu_note.text = "Town sounds %s (a test: a fire, a smith, a crowd and a bell placed around you)" % ("on" if _town_on else "off"))
	_menu_button(settings, "Sound test: creature calls", func():
		var kinds: Array = sound.creatures.KINDS.keys()
		var moods: Array = ["idle", "alert", "threat"]
		_creature_at = (_creature_at + 1) % (kinds.size() * moods.size())
		@warning_ignore("integer_division")
		var kind: String = kinds[_creature_at / moods.size()]
		var mood: String = moods[_creature_at % moods.size()]
		var distance: float = (float(sound.creatures.KINDS[kind]["dist"][0]) + float(sound.creatures.KINDS[kind]["dist"][1])) * 0.5
		var played: bool = sound.creatures.call_nearby(kind, mood, distance)
		_menu_note.text = "Creature call: %s, %s, about %.0f m away%s (press again for the next)" % [kind, mood, distance, "" if played else " (did not play)"])
	_menu_button(settings, "Sound test: spear", func():
		_spear_at = (_spear_at + 1) % 6
		var eye: Vector3 = camera.global_position
		var ahead: Vector3 = -camera.global_transform.basis.z

		if _spear_at == 0:
			sound.spear.jab(eye + ahead * 1.0)
			_menu_note.text = "Spear jab (press again: throws into wood, stone, soil, flesh, then hits right here)"
		elif _spear_at <= 4:
			var material: String = sound.spear.MATERIALS[_spear_at - 1]
			sound.spear.throw(eye + ahead, eye + ahead * 30.0, 28.0, material)
			_menu_note.text = "Spear thrown 30 m ahead into %s" % material
		else:
			sound.spear.hit("wood", eye + ahead * 2.0, 1.0)
			_menu_note.text = "Spear hits wood two metres ahead")
	_menu_button(settings, "Sound test: fire", func():
		_fire_at = (_fire_at + 1) % 7
		_menu_note.text = fire_step(_fire_at, body.global_position + -camera.global_transform.basis.z * 3.0) + " (press again for the next)")
	_menu_button(settings, "Sound test: exertion", func():
		_exertion_at = (_exertion_at + 1) % 7
		var levels: Array = [0.0, 0.35, 0.6, 0.9, 1.0, 1.6]
		var notes: Array = ["Rested: silent", "Light exertion: soft slow breaths", "Hard exertion: clear quick breaths, heartbeat starts", "Severe exertion: gasps and a strong heartbeat", "Exhausted: fastest gasps (then it follows your running again)", "Over-exerted: racing heart, great chest heaves", "Faint demo, 27 s: over-exertion, forced slow-down, faint (world fades, only the heart, gone in 3 s), waking with the heart racing"]

		if _exertion_at == 6:
			sound.breath.demo()
		else:
			sound.breath.set_exertion(levels[_exertion_at])
		_menu_note.text = "%s (press again for the next)" % notes[_exertion_at])
	_menu_button(settings, "Sound test: interior", func():
		_interior_at = (_interior_at + 1) % 5
		var here: Vector3 = body.global_position + -camera.global_transform.basis.z * 2.0
		var step: int = _interior_at
		var notes: Array = ["Inside a house (press again: door open, door close, chest, then back outside)", "Door opens", "Door closes", "Chest opens", "Back outside"]
		var objects: Array = ["", "door_open", "door_close", "chest_open", ""]

		if step == 0:
			sound.interior.set_inside(1.0, "house")
		elif step == 4:
			sound.interior.set_inside(0.0)
		else:
			sound.interior.object(objects[step], here)

		_menu_note.text = notes[step])
	_menu_button(settings, "Sound test: gear", func():
		var sets: Array = [[], ["cloth"], ["leather", "hobnail"], ["chain", "iron"], ["plate", "iron"]]
		_gear_at = (_gear_at + 1) % sets.size()
		sound.gear.set_worn(sets[_gear_at])
		_menu_note.text = "Gear worn: %s (walk to hear it on every step)" % (", ".join(sets[_gear_at]) if not sets[_gear_at].is_empty() else "none"))
	_menu_button(settings, "Sound test: swimming", func():
		sound.swim.demo()
		_menu_note.text = "A scripted swim: a splash, strokes, going under, surfacing (10 s; a test of the sounds)")
	_menu_button(settings, "Sound test: tool hit", func():
		_hit_at = (_hit_at + 1) % (sound.hits.TOOLS.size() * sound.hits.MATERIALS.size())
		var tool: String = sound.hits.TOOLS[_hit_at / sound.hits.MATERIALS.size()]
		var material: String = sound.hits.MATERIALS[_hit_at % sound.hits.MATERIALS.size()]
		sound.hits.hit(tool, material, body.global_position + -camera.global_transform.basis.z * 2.0, 1.0)
		_menu_note.text = "Tool hit: %s on %s (press again for the next; a test of the sounds, no tools exist yet)" % [tool, material])
	_menu_button(settings, "Sound test weather: change", func():
		var kinds: Array = sound.weather.KINDS.keys()
		weather_at += 1

		if weather_at >= kinds.size():
			weather_at = -1
			_menu_note.text = "Weather sounds follow the game's weather"
			return

		sound.weather.set_weather(kinds[weather_at], 1.0)
		_menu_note.text = "Weather sounds now play: %s (a test setting; the sky, ground, rain and snow follow it too). Press again until it follows the game's weather." % kinds[weather_at])


# One step of the fire sound test (button and --fire): returns what it did.
func fire_step(step: int, at: Vector3) -> String:
	sound.fire.hold_manual(12.0)
	var fire := {"id": 1, "at": at, "size": 0.3, "lit": true, "open": true}
	var note: String = ""

	if step == 0:
		fire["lit"] = false
		sound.weather.set_weather("clear", 1.0)
		sound.fire.set_fires([fire])
		note = "Unlit fire placed three metres ahead (silent)"
	elif step == 1:
		sound.fire.set_fires([fire])
		note = "Fire lit: small embers"
	elif step == 2:
		fire["size"] = 1.0
		sound.fire.set_fires([fire])
		note = "Fire grows to a bonfire"
	elif step == 3:
		fire["size"] = 1.0
		sound.weather.set_weather("rain", 1.0)
		sound.fire.set_fires([fire])
		note = "Rain starts on the open fire (sizzle)"
	elif step == 4:
		fire["lit"] = false
		sound.fire.set_fires([fire])
		note = "Fire put out (hiss)"
	elif step == 5:
		sound.weather.set_weather("clear", 1.0)
		sound.fire.set_fires([fire])
		note = "Fire lit again, rain gone"
	else:
		sound.fire.set_fires([])
		note = "Fire removed (fades)"

	return note
