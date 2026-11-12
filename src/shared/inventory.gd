extends RefCounted

# A player's inventory: fixed slots of {item number, count}. Pure data, no
# scene code, so the server (which owns it) and the client (which shows it)
# use the same rules. Number 0 means an empty slot.

const SLOTS := 30
const FORMAT := 3               # 2 added wear per slot; 3 the instance data after the slots (inst_bytes)
const MAX_D_CAP := 1000000       # max_d travels in the JSON block, not the u16 wear: a +2 Tempered steel spade passes 65535

var table
var numbers: PackedInt32Array = PackedInt32Array()
var counts: PackedInt32Array = PackedInt32Array()
var usable: int = SLOTS               # slots in use: a small container only fills its first few
var bag_from: int = 0                 # new items go to slots from here first, then from slot 0 (the pack fills from slot 0 since the pointer hotbar, inventory step 4)
var stack_all: bool = false           # a store that stacks every item to the u16 count (a fire's wood store); not saved, the owner sets it each time
var wear: PackedInt32Array = PackedInt32Array()      # uses spent so far, tools only (stack 1); 0 for anything else
var fav: PackedInt32Array = PackedInt32Array()       # favourites (inventory step 3, a pack only): the item number a slot was favourited with, 0 none; see is_fav
const HOTBAR_KEYS := 10
var hotbar: PackedInt32Array = PackedInt32Array()    # the pointer hotbar (inventory step 4, a pack only): keys 1 to 9 and 0 each hold an item number, 0 none; see key_slot
# Per-instance data (catalog Phase 1b, master s2.2, s2.9, s4 items 2, 15, 16): {} for a plain item, else only the keys that are not default:
# sharp (sharpness used, int), max_d (current maximum durability, int; absent = the row's durability), temper (1), craft (1 or 2, fixed at craft time),
# magic (two Strings, "" empty; a slot is filled only while empty and nothing clears it). A slot with an instance never merges.
var inst: Array = []


func _init(item_table = null) -> void:
	table = item_table
	numbers.resize(SLOTS)
	counts.resize(SLOTS)
	wear.resize(SLOTS)
	fav.resize(SLOTS)
	hotbar.resize(HOTBAR_KEYS)
	inst.resize(SLOTS)

	for i in SLOTS:
		inst[i] = {}


# Add as many as fit (fills partial stacks first). Returns how many were left over.
# Stacks of food only join when their ages are close (spoilage.json merge_gap of the shelf life); a join averages the age.
func _mergeable(number: int, wear_a: int, wear_b: int) -> bool:
	if table == null:
		return true

	if table.wood_class(number) != "":   # wet wood (cooking.json wet_wood): stacks join when their drying left is within wet_merge_h
		return absi(wear_a - wear_b) < int(round(float(table.wet_wood().get("wet_merge_h", 2.0)) * 10.0))

	var life: int = table.shelf_units(number)

	if life == 0:
		return true

	# A sealed food (item_table.gd ready_units) never joins across its ready age, and a Maturing batch joins only its own age, so batches sealed
	# at different times stay apart and none ripens early by averaging (master s3.14 [D14]).
	var ready: int = table.ready_units(number) if table.has_method("ready_units") else 0

	if ready > 0 and mini(wear_a, wear_b) < ready:
		return wear_a == wear_b

	return absi(wear_a - wear_b) <= int(float(life) * float(table.spoilage().get("merge_gap", 0.1)))


func _joined_age(number: int, wear_a: int, count_a: int, wear_b: int, count_b: int) -> int:
	if table != null and table.wood_class(number) != "":
		return maxi(wear_a, wear_b)   # a join keeps the wetter: never drier than it is

	if table == null or table.shelf_units(number) == 0:
		return wear_a

	return int(round(float(wear_a * count_a + wear_b * count_b) / float(maxi(count_a + count_b, 1))))


func add(number: int, count: int, item_wear: int = 0, item_inst: Dictionary = {}) -> int:
	if number <= 0 or count <= 0 or table == null:
		return count

	var stack: int = 65535 if stack_all else table.stack_of(number)
	var left: int = count

	for i in usable:
		if left > 0 and item_inst.is_empty() and inst[i].is_empty() and numbers[i] == number and counts[i] < stack and _mergeable(number, wear[i], item_wear):
			var put: int = mini(left, stack - counts[i])
			wear[i] = _joined_age(number, wear[i], counts[i], item_wear, put)
			counts[i] += put
			left -= put

	for pass_from in [bag_from, 0]:
		for i in range(pass_from, usable):
			if left > 0 and numbers[i] == 0:
				var put: int = mini(left, stack)
				numbers[i] = number
				counts[i] = put
				wear[i] = item_wear
				fav[i] = 0
				inst[i] = item_inst.duplicate(true)
				left -= put

	return left


func is_empty() -> bool:
	for i in SLOTS:
		if numbers[i] != 0:
			return false

	return true


func count_of(number: int, plain_only: bool = false, ready_only: bool = false) -> int:
	var total: int = 0

	for i in SLOTS:
		if numbers[i] == number and not (plain_only and not inst[i].is_empty()) and not (ready_only and maturing_at(i)):
			total += counts[i]

	return total


# A Maturing stack (item_table.gd ready_units): it is not eaten, sold or used as an ingredient until Ready (master s3.14 [D14]).
func maturing_at(i: int) -> bool:
	return table != null and numbers[i] != 0 and table.has_method("maturing") and table.maturing(numbers[i], wear[i])


func has(number: int, count: int) -> bool:
	return count_of(number) >= count


# Take `count` of an item (from the last slots first, plain stacks before instances). False and no change if there is not enough.
# Each part taken from a slot is appended to `taken` as [number, inst, wear, count], in the order taken, so a refund can give back as it
# was what is still owed (the craft queue). `ready_only`: Maturing stacks are left alone (an ingredient take).
func remove(number: int, count: int, taken: Array = [], ready_only: bool = false) -> bool:
	if count <= 0 or count_of(number, false, ready_only) < count:
		return false

	var left: int = count

	for plain in [true, false]:
		for i in range(SLOTS - 1, -1, -1):
			if left > 0 and numbers[i] == number and inst[i].is_empty() == plain and not (ready_only and maturing_at(i)):
				var take: int = mini(left, counts[i])

				taken.append([number, inst[i].duplicate(true), wear[i], take])

				counts[i] -= take
				left -= take

				if counts[i] == 0:
					clear_slot(i)

	return true


# Empties a slot of everything it carries (number, count, wear, favourite, instance).
func clear_slot(i: int) -> void:
	numbers[i] = 0
	counts[i] = 0
	wear[i] = 0
	fav[i] = 0
	inst[i] = {}


# Ingredient counting (guide finding F-16, Tyler 31 Oct 2026): an ingredient that names a group (plain `log`, `wooden_block`, `firewood`: item_table.gd
# load_groups) is filled by the id itself or any member (log_oak ...). Recipes, the craft queue, the planner, blueprint costs and the client recipe list use
# these three; count_of / has / remove stay literal (one item number), so nothing else changes meaning.
func fills_of(number: int) -> PackedInt32Array:
	if table != null and table.has_method("group_members"):
		var members: PackedInt32Array = table.group_members(number)

		if not members.is_empty():
			return members

	return PackedInt32Array([number])


# `plain_only`: units with instance data do not count (building costs never take them).
func count_fill(number: int, plain_only: bool = false) -> int:
	var fills: PackedInt32Array = fills_of(number)
	var total: int = 0

	for i in SLOTS:
		if numbers[i] != 0 and fills.has(numbers[i]) and not (plain_only and not inst[i].is_empty()) and not maturing_at(i):
			total += counts[i]

	return total


func has_fill(number: int, count: int) -> bool:
	return count_fill(number) >= count


# Takes `count` for an ingredient: the group's lowest member first (ItemTable.spend_order: tier, material, value; own id first on a tie), then the next.
# False and no change if the pack holds too few. An id that is no group is taken as itself.
# `plain_only` (building costs): only units without instance data are taken, at most each member's plain count, so an instance never fills a cost.
func remove_fill(number: int, count: int, taken_inst: Array = [], plain_only: bool = false) -> bool:
	if count <= 0 or count_fill(number, plain_only) < count:
		return false

	var left: int = count
	var spend: PackedInt32Array = table.spend_order(number) if table != null and table.has_method("spend_order") else PackedInt32Array()

	for fill in (spend if not spend.is_empty() else fills_of(number)):
		if left > 0:
			var taken: int = mini(left, count_of(fill, plain_only, true))

			if taken > 0:
				remove(fill, taken, taken_inst, true)
				left -= taken

	return true


# Remove from one slot; returns {number, count, wear, inst} actually taken.
func take_from_slot(slot: int, count: int) -> Dictionary:
	if slot < 0 or slot >= SLOTS or numbers[slot] == 0 or count <= 0:
		return {"number": 0, "count": 0}

	var take: int = mini(count, counts[slot])
	var number: int = numbers[slot]
	var item_wear: int = wear[slot]
	var item_inst: Dictionary = inst[slot].duplicate(true)
	counts[slot] -= take

	if counts[slot] == 0:
		clear_slot(slot)

	return {"number": number, "count": take, "wear": item_wear, "inst": item_inst}


# Move a slot onto another: merge when the same item, else swap.
func move(from_slot: int, to_slot: int) -> void:
	if from_slot == to_slot or from_slot < 0 or to_slot < 0 or from_slot >= SLOTS or to_slot >= SLOTS or numbers[from_slot] == 0:
		return

	if numbers[to_slot] == numbers[from_slot] and inst[to_slot].is_empty() and inst[from_slot].is_empty() and table != null and _mergeable(numbers[to_slot], wear[to_slot], wear[from_slot]):
		var room: int = table.stack_of(numbers[to_slot]) - counts[to_slot]
		var put: int = mini(room, counts[from_slot])
		wear[to_slot] = _joined_age(numbers[to_slot], wear[to_slot], counts[to_slot], wear[from_slot], put)
		counts[to_slot] += put
		counts[from_slot] -= put

		if counts[from_slot] == 0:
			clear_slot(from_slot)

		return

	var n: int = numbers[to_slot]
	var c: int = counts[to_slot]
	var w: int = wear[to_slot]
	var f: int = fav[to_slot]
	var d: Dictionary = inst[to_slot]
	inst[to_slot] = inst[from_slot]
	inst[from_slot] = d
	numbers[to_slot] = numbers[from_slot]
	counts[to_slot] = counts[from_slot]
	wear[to_slot] = wear[from_slot]
	fav[to_slot] = fav[from_slot]   # a favourite goes with its stack
	numbers[from_slot] = n
	counts[from_slot] = c
	wear[from_slot] = w
	fav[from_slot] = f


# A favourite stack (inventory step 3): Sort, Store all and Stack to nearby leave it where it is. The flag holds the item number it was set with,
# so a slot that empties (or gets something else by a direct write) is no longer a favourite.
func is_fav(slot: int) -> bool:
	return slot >= 0 and slot < SLOTS and numbers[slot] != 0 and fav[slot] == numbers[slot]


func set_fav(slot: int, on: bool) -> void:
	if slot >= 0 and slot < SLOTS:
		fav[slot] = numbers[slot] if on else 0


# The pointer hotbar (inventory step 4): a key holds an item number, not a slot, so sorting and moving never change it. The key points at the pack
# slot holding that item, an unbroken one first, then the first in pack order; -1 when the key is empty or none is in the pack (the key keeps its
# item, dimmed, and the next one picked up comes back to it).
func key_slot(key: int) -> int:
	if key < 0 or key >= hotbar.size() or hotbar[key] == 0:
		return -1

	var first: int = -1
	var number: int = hotbar[key]

	for slot in SLOTS:
		if numbers[slot] != number:
			continue

		if max_durability(slot) <= 0 or wear[slot] < max_durability(slot):
			return slot

		if first < 0:
			first = slot

	if first < 0 and table != null:
		var other: int = _flame_twin(number)

		if other > 0:
			return numbers.find(other)

	return first


# A torch and the same torch put out (items.json "doused_item" and "relit_item") are one item to a key: rain turns the slot into the other one
# while the key keeps the number it was given, and "Press its key to light it again" must still find it (the doused torch was lost to its key).
func _flame_twin(number: int) -> int:
	var entry: Dictionary = table.entry(table.id_of(number))
	var twin: String = str(entry.get("doused_item", entry.get("relit_item", "")))
	return table.number_of(twin) if twin != "" else 0


# Whether a hotbar key points at the item in this slot (the server's "on the hotbar" for tools: an axe to chop, a hammer to build).
func on_hotbar(slot: int) -> bool:
	return slot >= 0 and slot < SLOTS and numbers[slot] != 0 and hotbar.has(numbers[slot])


# The key whose pointer lands on this pack slot (the gold key number on the pack slot), or -1.
func key_of_slot(slot: int) -> int:
	if slot < 0 or slot >= SLOTS or numbers[slot] == 0:
		return -1

	var key: int = hotbar.find(numbers[slot])

	if key < 0 and table != null and _flame_twin(numbers[slot]) > 0:
		key = hotbar.find(_flame_twin(numbers[slot]))   # a torch whose key was given its lit or doused twin

	return key if key >= 0 and key_slot(key) == slot else -1


# One byte per slot, 1 for a favourite: what the client is sent (protocol 99 favourites).
func fav_flags() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(SLOTS)

	for i in SLOTS:
		out[i] = 1 if is_fav(i) else 0

	return out


# Format 3: the format byte, 8 bytes per slot (u32 number, u16 count, u16 wear), then the instance data of the slots that have one (inst_bytes).
func to_bytes() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(1 + SLOTS * 8)
	out[0] = FORMAT
	var map: Dictionary = {}

	for i in SLOTS:
		out.encode_u32(1 + i * 8, numbers[i])
		out.encode_u16(1 + i * 8 + 4, counts[i])
		out.encode_u16(1 + i * 8 + 6, mini(wear[i], 65535))

		if not inst_of(i).is_empty():
			map[i] = inst[i]

	out.append_array(inst_bytes(map))
	return out


func from_bytes(bytes: PackedByteArray) -> bool:
	var head: int = 1 + SLOTS * 8

	if bytes.size() < head + 2 or bytes[0] != FORMAT or bytes.size() != head + 2 + bytes.decode_u16(head):
		return false

	var map: Dictionary = inst_from_bytes(bytes, head)

	for i in SLOTS:
		numbers[i] = bytes.decode_u32(1 + i * 8)
		counts[i] = bytes.decode_u16(1 + i * 8 + 4)
		wear[i] = bytes.decode_u16(1 + i * 8 + 6)
		inst[i] = map.get(i, {}) if numbers[i] != 0 else {}

	return true


# The instance data of some slots on the wire: u16 byte length, then UTF-8 JSON {"slot": inst} (length 0 for none). Inventory bytes, slot updates
# and the worn list all carry it this way (protocol 106).
static func inst_bytes(map: Dictionary) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray([0, 0])

	if map.is_empty():
		return out

	var text: PackedByteArray = JSON.stringify(map).to_utf8_buffer()

	if text.size() > 65535:
		push_error("inventory: instance data of %d bytes does not fit the u16 length; sent without it" % text.size())
		return out

	out.encode_u16(0, text.size())
	out.append_array(text)
	return out


# {slot int: inst} from inst_bytes at byte `at`; {} when there is none or it does not read.
static func inst_from_bytes(bytes: PackedByteArray, at: int) -> Dictionary:
	var out: Dictionary = {}

	if at < 0 or at + 2 > bytes.size():
		return out

	var n: int = bytes.decode_u16(at)

	if n == 0 or at + 2 + n > bytes.size():
		return out

	var parsed: Variant = JSON.parse_string(bytes.slice(at + 2, at + 2 + n).get_string_from_utf8())

	if typeof(parsed) == TYPE_DICTIONARY:
		for key in parsed:
			if str(key).is_valid_int():
				out[int(key)] = clean_inst(parsed[key])

	return out


# An instance from a save or the wire, keeping only known keys with sane values that are not default (anything else reads as plain).
static func clean_inst(raw: Variant) -> Dictionary:
	var out: Dictionary = {}

	if typeof(raw) != TYPE_DICTIONARY:
		return out

	var sharp: int = _whole(raw, "sharp", 0)
	var max_d: int = _whole(raw, "max_d", -1)
	var craft: int = _whole(raw, "craft", 0)

	if sharp > 0:
		out["sharp"] = mini(sharp, 65535)

	if max_d >= 0:
		out["max_d"] = mini(max_d, MAX_D_CAP)

	if _whole(raw, "temper", 0) == 1:
		out["temper"] = 1

	if craft == 1 or craft == 2:
		out["craft"] = craft

	var magic: Variant = raw.get("magic", [])

	if typeof(magic) == TYPE_ARRAY and (magic as Array).size() == 2:
		var two: Array = [str(magic[0]) if typeof(magic[0]) == TYPE_STRING else "", str(magic[1]) if typeof(magic[1]) == TYPE_STRING else ""]

		if two != ["", ""]:
			out["magic"] = two

	return out


static func _whole(raw: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = raw.get(key, fallback)
	return int(value) if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT else fallback


# The instance data of a slot ({} for a plain or empty one).
func inst_of(slot: int) -> Dictionary:
	return inst[slot] if slot >= 0 and slot < SLOTS and numbers[slot] != 0 else {}


# --- Instance API for the catalog's Phase 2c (durability, sharpening, craftsmanship, Tempered; rules in smithing_rules.gd) ---

# A new instance as crafting makes it: craftsmanship 0, 1 or 2 and Tempered. Craftsmanship is fixed here; nothing changes it afterwards.
static func make_inst(craft: int = 0, tempered: bool = false) -> Dictionary:
	return clean_inst({"craft": craft, "temper": 1 if tempered else 0})


# The slot's current maximum durability: its instance's max_d, else the item row's durability (0 for an item that does not wear).
func max_durability(slot: int) -> int:
	if slot < 0 or slot >= SLOTS or numbers[slot] == 0:
		return 0

	if inst[slot].has("max_d"):
		return int(inst[slot]["max_d"])

	return int(table.entry(table.id_of(numbers[slot])).get("durability", 0)) if table != null else 0


# Sharpness used so far on the slot's item (0 = fully sharp).
func sharpness_used(slot: int) -> int:
	return int(inst_of(slot).get("sharp", 0))


# Fills magical slot `index` (0 or 1) of the single item in `slot` with `effect`. Refused (false, nothing changes) when that slot is already
# filled, the effect is empty or the slot holds no single item: an enchantment is never removed, replaced or moved (master s2.9 item 6).
func fill_magic(slot: int, index: int, effect: String) -> bool:
	if slot < 0 or slot >= SLOTS or numbers[slot] == 0 or counts[slot] != 1 or index < 0 or index > 1 or effect == "":
		return false

	var magic: Array = inst[slot].get("magic", ["", ""])

	if str(magic[index]) != "":
		return false

	magic = magic.duplicate()
	magic[index] = effect
	inst[slot]["magic"] = magic
	return true


# JSON form for the server save file: [[number, count, wear], ...] with empty slots as [0, 0, 0], a fourth 1 on a favourite
# (inventory step 3) and a fifth, the instance data, when there is one (the fourth is then written, 0 or 1). Version 1 saves had
# [number, count] only; they load with zero wear.
func to_json_array() -> Array:
	var out: Array = []

	for i in SLOTS:
		var row: Array = [numbers[i], counts[i], wear[i]]

		if is_fav(i) or not inst_of(i).is_empty():
			row.append(1 if is_fav(i) else 0)

		if not inst_of(i).is_empty():
			row.append(inst[i].duplicate(true))

		out.append(row)

	return out


func from_json_array(data: Array) -> void:
	for i in mini(SLOTS, data.size()):
		numbers[i] = table.current_number(int(data[i][0])) if table != null else int(data[i][0])   # a retired item loads as its replacement (renames.json)
		counts[i] = clampi(int(data[i][1]), 0, 65535)   # a hand-edited or out-of-range count is pulled into the u16 range
		wear[i] = int(data[i][2]) if data[i].size() > 2 else 0
		fav[i] = numbers[i] if data[i].size() > 3 and int(data[i][3]) == 1 else 0
		inst[i] = clean_inst(data[i][4]) if data[i].size() > 4 and numbers[i] != 0 else {}
