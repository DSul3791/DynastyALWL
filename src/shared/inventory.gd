extends RefCounted

# A player's inventory: slots of {item number, count}. Pure data, no
# scene code, so the server (which owns it) and the client (which shows it)
# use the same rules. Number 0 means an empty slot. A container has a fixed
# number of slots; a pack grows when it is full (grows, trim).

const BASE_SLOTS := 30         # a container's slots, and a pack's fewest: the hotbar 10 and the backpack 20 (Dave 12 Nov 2026 23:06Z)
const FORMAT := 4               # 2 added wear per slot; 3 the instance data after the slots (inst_bytes); 4 the slot count after the format byte
# A pack is never full (Dave 12 Nov 2026 23:06Z: "slots should be almost endless... a minimum of 20 and if they add more stuff just start
# adding more slots... they are limited by weight really"): it adds GROW_STEP slots when nothing fits, and gives empty ones back at its end.
const GROW_STEP := 5
const MAX_SLOTS := 250          # the slot index and the changed-slot count in inventory_slots are one byte each
const MAX_D_CAP := 1000000       # max_d travels in the JSON block, not the u16 wear: a +2 Tempered steel spade passes 65535

var table
var numbers: PackedInt32Array = PackedInt32Array()
var counts: PackedInt32Array = PackedInt32Array()
var slot_count: int = BASE_SLOTS      # the slots this inventory has; a pack's changes as it fills (grows)
var usable: int = BASE_SLOTS          # slots in use: a small container only fills its first few; a pack uses all of them
var grows: bool = false               # a pack (pack()): add() makes room instead of leaving any over; weight is the pack's only limit
var bag_from: int = 0                 # new items go to slots from here first, then from slot 0 (a pack: the backpack slots after the hotbar, see pack())
var stack_all: bool = false           # a store that stacks every item to the u16 count (a fire's wood store); not saved, the owner sets it each time
var wear: PackedInt32Array = PackedInt32Array()      # uses spent so far, tools only (stack 1); 0 for anything else
var fav: PackedInt32Array = PackedInt32Array()       # favourites (inventory step 3, a pack only): the item number a slot was favourited with, 0 none; see is_fav
const HOTBAR_KEYS := 10
var hotbar_slots: int = 0             # a pack's first slots are its hotbar (keys 1 to 9 and 0 are slots 0 to 9; Dave, playtest 12 Nov 2026 TEST-008); 0 for a container
# Per-instance data (catalog Phase 1b, master s2.2, s2.9, s4 items 2, 15, 16): {} for a plain item, else only the keys that are not default:
# sharp (sharpness used, int), max_d (current maximum durability, int; absent = the row's durability), temper (1), craft (1 or 2, fixed at craft time),
# magic (two Strings, "" empty; a slot is filled only while empty and nothing clears it), bag (a bag's contents, catalog Phase 5: rows in the
# to_json_array shape, src/shared/bag_rules.gd; a row's own inst never holds a bag). A slot with an instance never merges.
var inst: Array = []


func _init(item_table = null, slots: int = BASE_SLOTS) -> void:
	table = item_table
	slot_count = 0
	usable = 0
	_resize(clampi(slots, 1, MAX_SLOTS))


# To n slots: new ones are empty, ones past n are gone (callers only cut empty ones). An inventory that used all its slots still does.
func _resize(n: int) -> void:
	var was: int = slot_count
	var all_used: bool = usable >= was
	numbers.resize(n)
	counts.resize(n)
	wear.resize(n)
	fav.resize(n)
	inst.resize(n)

	for i in range(was, n):
		numbers[i] = 0
		counts[i] = 0
		wear[i] = 0
		fav[i] = 0
		inst[i] = {}

	slot_count = n
	usable = n if all_used else mini(usable, n)


# A pack gives back the empty slots at its end, GROW_STEP at a time, down to BASE_SLOTS (the hotbar and 20 backpack slots).
# True when it shrank (the server then sends the whole pack, since a slot update cannot say a slot is gone).
func trim() -> bool:
	if not grows:
		return false

	var last: int = slot_count - 1

	while last >= BASE_SLOTS and numbers[last] == 0:
		last -= 1

	var want: int = BASE_SLOTS + ceili(float(maxi(last + 1 - BASE_SLOTS, 0)) / float(GROW_STEP)) * GROW_STEP

	if want >= slot_count:
		return false

	_resize(want)
	return true


# A copy with the same slots, kind and contents: a trial run of an add or a move that must not touch the real one.
func copy():
	var out = load("res://src/shared/inventory.gd").new(table, slot_count)
	out.usable = usable
	out.bag_from = bag_from
	out.hotbar_slots = hotbar_slots
	out.grows = grows
	out.stack_all = stack_all
	out.from_json_array(to_json_array())
	return out


# A player's pack: slots 0 to 9 are the hotbar, real slots (an item is in the hotbar or in the backpack, never both); pickups fill the
# backpack first (Dave, playtest 12 Nov 2026 TEST-008; this replaces the 8 Nov pointer hotbar, row 24 of OVERNIGHT_DECISIONS_8NOV.md).
static func pack(item_table):
	var inv = load("res://src/shared/inventory.gd").new(item_table)
	inv.hotbar_slots = HOTBAR_KEYS
	inv.bag_from = HOTBAR_KEYS
	inv.grows = true
	return inv


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

	if (table.spoilage().get("exact_age", []) as Array).has(table.id_of(number)):
		return wear_a == wear_b   # a food board (master s3.15) joins only its own age: a fresh board never extends an old one

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


# `first`: only the slots from there up to usable take it (a station's output slots come after its input slots, master s2.5).
# A pack (grows) leaves nothing over: what does not fit gets new slots at the end, up to MAX_SLOTS. The caller checks the weight first.
func add(number: int, count: int, item_wear: int = 0, item_inst: Dictionary = {}, first: int = 0) -> int:
	if number <= 0 or count <= 0 or table == null:
		return count

	var stack: int = 65535 if stack_all else table.stack_of(number)
	var left: int = count

	for i in range(first, usable):
		if left > 0 and item_inst.is_empty() and inst[i].is_empty() and numbers[i] == number and counts[i] < stack and _mergeable(number, wear[i], item_wear):
			var put: int = mini(left, stack - counts[i])
			wear[i] = _joined_age(number, wear[i], counts[i], item_wear, put)
			counts[i] += put
			left -= put

	left = _fill_empty(number, left, stack, item_wear, item_inst, maxi(bag_from, first))

	# A pack grows its backpack before anything new goes into an empty hotbar slot: the hotbar holds what the player puts there and the
	# tools that go up by themselves (Dave 12 Nov 2026 23:03Z and 23:06Z). Only a pack at MAX_SLOTS falls back to the hotbar.
	if left > 0 and grows and slot_count < MAX_SLOTS:
		var from: int = slot_count
		var stacks: int = ceili(float(left) / float(maxi(stack, 1)))
		_resize(mini(slot_count + ceili(float(stacks) / float(GROW_STEP)) * GROW_STEP, MAX_SLOTS))
		left = _fill_empty(number, left, stack, item_wear, item_inst, from)

	if left > 0 and first < bag_from:
		left = _fill_empty(number, left, stack, item_wear, item_inst, first)

	return left


func _fill_empty(number: int, left: int, stack: int, item_wear: int, item_inst: Dictionary, from: int) -> int:
	for i in range(from, usable):
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
	for i in slot_count:
		if numbers[i] != 0:
			return false

	return true


func count_of(number: int, plain_only: bool = false, ready_only: bool = false) -> int:
	var total: int = 0

	for i in slot_count:
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
		for i in range(slot_count - 1, -1, -1):
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


# `plain_only`: units with instance data do not count (building costs never take them), and neither does container water.
func count_fill(number: int, plain_only: bool = false) -> int:
	var fills: PackedInt32Array = fills_of(number)
	var total: int = 0

	for i in slot_count:
		if numbers[i] != 0 and fills.has(numbers[i]) and not (plain_only and not inst[i].is_empty()) and not maturing_at(i):
			total += counts[i]

	return total if plain_only else total + liquid_units(number)


# Liquid ingredients (GOALS-REPAIR GA-04): an item with a table "unit_ml" (water) is also filled by the fresh water in this inventory's containers
# (capacity_ml items keep their water in `wear`, in mL; a container only ever holds fresh water, a drink at salt water is refused), pooled across them:
# two half-full skins make a unit. Recipes and the crafting stock use count_fill / remove_fill, so they see it; count_of / has stay literal.
# shortcut: pooled per inventory (the pack, each chest), so 300 mL in the pack and 300 mL in a chest do not make a unit; revisit if players hit it.
func liquid_ml() -> int:
	var total: int = 0

	if table == null or not table.has_method("container_cap"):
		return 0

	for i in slot_count:
		if numbers[i] != 0 and table.container_cap(numbers[i]) > 0:
			total += mini(wear[i], table.container_cap(numbers[i]))

	return total


func liquid_units(number: int) -> int:
	var unit: int = table.liquid_unit_ml(number) if table != null and table.has_method("liquid_unit_ml") else 0
	return floori(float(liquid_ml()) / float(unit)) if unit > 0 else 0


# Takes `ml` of water out of the containers, the one in slot `first` (-1 none) before the others, then slot by slot; the containers stay, empty ones too.
# False and no change when they hold less.
func drain_liquid(ml: int, first: int = -1) -> bool:
	if ml <= 0 or liquid_ml() < ml:
		return false

	var order: Array = range(slot_count)

	if first >= 0 and first < slot_count:
		order.erase(first)
		order.push_front(first)

	var left: int = ml

	for i in order:
		if left > 0 and numbers[i] != 0 and table.container_cap(numbers[i]) > 0:
			var take: int = mini(left, mini(wear[i], table.container_cap(numbers[i])))
			wear[i] -= take
			left -= take

	return true


# Pours `ml` back into containers with room, slot by slot; returns what no container had room for.
func pour_liquid(ml: int) -> int:
	var left: int = ml

	if table == null or not table.has_method("container_cap"):
		return left

	for i in slot_count:
		if left > 0 and numbers[i] != 0 and table.container_cap(numbers[i]) > 0:
			var put: int = mini(left, maxi(table.container_cap(numbers[i]) - wear[i], 0))
			wear[i] += put
			left -= put

	return left


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

	if left > 0:   # a liquid ingredient: what the stacks lacked comes out of the containers; the row lets a refund pour it back (never mint the item)
		var ml: int = left * table.liquid_unit_ml(number)
		drain_liquid(ml)
		taken_inst.append([number, {"liquid_ml": ml}, 0, left])

	return true


# Remove from one slot; returns {number, count, wear, inst} actually taken.
func take_from_slot(slot: int, count: int) -> Dictionary:
	if slot < 0 or slot >= slot_count or numbers[slot] == 0 or count <= 0:
		return {"number": 0, "count": 0}

	var take: int = mini(count, counts[slot])
	var number: int = numbers[slot]
	var item_wear: int = wear[slot]
	var item_inst: Dictionary = inst[slot].duplicate(true)
	counts[slot] -= take

	if counts[slot] == 0:
		clear_slot(slot)

	return {"number": number, "count": take, "wear": item_wear, "inst": item_inst}


# Move a slot onto another: merge when the same item, else swap. A full pack takes a move to just past its end (free_bag_slot) by growing.
func move(from_slot: int, to_slot: int) -> void:
	if to_slot == slot_count and from_slot >= 0 and from_slot < slot_count and numbers[from_slot] != 0 and free_bag_slot() == slot_count:
		make_room()

	if from_slot == to_slot or from_slot < 0 or to_slot < 0 or from_slot >= slot_count or to_slot >= slot_count or numbers[from_slot] == 0:
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
	return slot >= 0 and slot < slot_count and numbers[slot] != 0 and fav[slot] == numbers[slot]


func set_fav(slot: int, on: bool) -> void:
	if slot >= 0 and slot < slot_count:
		fav[slot] = numbers[slot] if on else 0


# The pack slot a hotbar key is (keys 1 to 9 and 0 are slots 0 to 9), -1 when that slot is empty or this is not a pack.
func key_slot(key: int) -> int:
	return key if key >= 0 and key < hotbar_slots and numbers[key] != 0 else -1


# Whether this slot is a hotbar slot holding an item (the server's "on the hotbar" for tools: an axe to chop, a hammer to build).
func on_hotbar(slot: int) -> bool:
	return slot >= 0 and slot < hotbar_slots and numbers[slot] != 0


# The first empty backpack slot (after the hotbar). A full pack names the slot just past its end, which move() adds; -1 for a full
# container (or a pack at MAX_SLOTS).
func free_bag_slot() -> int:
	for slot in range(hotbar_slots, usable):
		if numbers[slot] == 0:
			return slot

	return slot_count if grows and slot_count < MAX_SLOTS else -1


# An empty backpack slot to put something in, growing a full pack by a step for it; -1 when there is none (a full container, MAX_SLOTS).
func make_room() -> int:
	var free: int = free_bag_slot()

	if free == slot_count:
		_resize(mini(slot_count + GROW_STEP, MAX_SLOTS))

	return free


# One byte per slot, 1 for a favourite: what the client is sent (protocol 99 favourites).
func fav_flags() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(slot_count)

	for i in slot_count:
		out[i] = 1 if is_fav(i) else 0

	return out


# Format 4: the format byte, the slot count byte, 8 bytes per slot (u32 number, u16 count, u16 wear), then the instance data of the slots that have one (inst_bytes).
func to_bytes() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(2 + slot_count * 8)
	out[0] = FORMAT
	out[1] = slot_count
	var map: Dictionary = {}

	for i in slot_count:
		out.encode_u32(2 + i * 8, numbers[i])
		out.encode_u16(2 + i * 8 + 4, counts[i])
		out.encode_u16(2 + i * 8 + 6, mini(wear[i], 65535))

		if not inst_of(i).is_empty():
			map[i] = inst[i]

	out.append_array(inst_bytes(map))
	return out


# Takes the sender's slot count (a pack that grew or shrank, a body's remains that hold a large pack).
func from_bytes(bytes: PackedByteArray) -> bool:
	if bytes.size() < 2 or bytes[0] != FORMAT or bytes[1] < 1:
		return false

	var n: int = bytes[1]
	var head: int = 2 + n * 8

	if bytes.size() < head + 2 or bytes.size() != head + 2 + bytes.decode_u16(head):
		return false

	var map: Dictionary = inst_from_bytes(bytes, head)
	_resize(n)

	for i in slot_count:
		numbers[i] = bytes.decode_u32(2 + i * 8)
		counts[i] = bytes.decode_u16(2 + i * 8 + 4)
		wear[i] = bytes.decode_u16(2 + i * 8 + 6)
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
# `in_bag`: the instance of something inside a bag, which never holds a bag of its own (no nesting, master s3.9 rule 3).
static func clean_inst(raw: Variant, in_bag: bool = false) -> Dictionary:
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

	var bag: Variant = raw.get("bag", [])

	if not in_bag and typeof(bag) == TYPE_ARRAY:
		var rows: Array = []

		for row in (bag as Array).slice(0, BASE_SLOTS):
			rows.append(_clean_row(row))

		while not rows.is_empty() and int(rows.back()[0]) == 0:
			rows.pop_back()

		if not rows.is_empty():
			out["bag"] = rows

	return out


# clean_inst for the instance of item `number` as a save loads it: an item that is not a bag (items.json bag_slots 0 or absent) never carries a `bag`.
# This is how an older save's backpack contents are dropped: the two backpacks lost their slots (Dave 13 Nov 2026, "Backpacks do not have slots.
# The only thing they do is give you more carry weight."). A real bag keeps its contents. No table (a bare test inventory): nothing is dropped.
static func clean_inst_of(item_table, number: int, raw: Variant) -> Dictionary:
	var out: Dictionary = clean_inst(raw)

	if out.has("bag") and item_table != null and int(item_table.entry(item_table.id_of(number)).get("bag_slots", 0)) <= 0:
		out.erase("bag")

	return out


# One row of a bag's contents, cleaned: [number, count, wear] and, with an instance, [.., 0, inst] (no favourites in a bag); [0, 0, 0] if unreadable.
static func _clean_row(row: Variant) -> Array:
	if typeof(row) != TYPE_ARRAY or (row as Array).size() < 3 or not (row as Array).slice(0, 3).all(func(v: Variant) -> bool: return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT):
		return [0, 0, 0]

	var number: int = int(row[0])
	var count: int = clampi(int(row[1]), 0, 65535)

	if number <= 0 or count <= 0:
		return [0, 0, 0]

	var out: Array = [number, count, maxi(int(row[2]), 0)]
	var item_inst: Dictionary = clean_inst(row[4], true) if row.size() > 4 else {}

	if not item_inst.is_empty():
		out.append_array([0, item_inst])

	return out


static func _whole(raw: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = raw.get(key, fallback)
	return int(value) if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT else fallback


# The instance data of a slot ({} for a plain or empty one).
func inst_of(slot: int) -> Dictionary:
	return inst[slot] if slot >= 0 and slot < slot_count and numbers[slot] != 0 else {}


# --- Instance API for the catalog's Phase 2c (durability, sharpening, craftsmanship, Tempered; rules in smithing_rules.gd) ---

# A new instance as crafting makes it: craftsmanship 0, 1 or 2 and Tempered. Craftsmanship is fixed here; nothing changes it afterwards.
static func make_inst(craft: int = 0, tempered: bool = false) -> Dictionary:
	return clean_inst({"craft": craft, "temper": 1 if tempered else 0})


# The slot's current maximum durability: its instance's max_d, else the item row's durability (0 for an item that does not wear).
func max_durability(slot: int) -> int:
	if slot < 0 or slot >= slot_count or numbers[slot] == 0:
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
	if slot < 0 or slot >= slot_count or numbers[slot] == 0 or counts[slot] != 1 or index < 0 or index > 1 or effect == "":
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

	for i in slot_count:
		var row: Array = [numbers[i], counts[i], wear[i]]

		if is_fav(i) or not inst_of(i).is_empty():
			row.append(1 if is_fav(i) else 0)

		if not inst_of(i).is_empty():
			row.append(inst[i].duplicate(true))

		out.append(row)

	return out


# Every saved row loads (an inventory with fewer slots gets more, up to MAX_SLOTS); slots past the rows are emptied, and a pack then trims.
func from_json_array(data: Array) -> void:
	if data.size() > slot_count:
		_resize(mini(data.size(), MAX_SLOTS))

	for i in range(mini(slot_count, data.size()), slot_count):
		clear_slot(i)

	for i in mini(slot_count, data.size()):
		numbers[i] = table.current_number(int(data[i][0])) if table != null else int(data[i][0])   # a retired item loads as its replacement (renames.json)
		counts[i] = clampi(int(data[i][1]), 0, 65535)   # a hand-edited or out-of-range count is pulled into the u16 range
		wear[i] = int(data[i][2]) if data[i].size() > 2 else 0
		fav[i] = numbers[i] if data[i].size() > 3 and int(data[i][3]) == 1 else 0
		inst[i] = clean_inst_of(table, numbers[i], data[i][4]) if data[i].size() > 4 and numbers[i] != 0 else {}

	trim()
