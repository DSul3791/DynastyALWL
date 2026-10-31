extends RefCounted

# A player's inventory: fixed slots of {item number, count}. Pure data, no
# scene code, so the server (which owns it) and the client (which shows it)
# use the same rules. Number 0 means an empty slot.

const SLOTS := 30
const FORMAT := 2               # 2 added wear per slot

var table
var numbers: PackedInt32Array = PackedInt32Array()
var counts: PackedInt32Array = PackedInt32Array()
var usable: int = SLOTS               # slots in use: a small container only fills its first few
var bag_from: int = 0                 # a player's pack: new items go to slots from here first, the hotbar (0 to 9) only when the bag is full
var wear: PackedInt32Array = PackedInt32Array()      # uses spent so far, tools only (stack 1); 0 for anything else


func _init(item_table = null) -> void:
	table = item_table
	numbers.resize(SLOTS)
	counts.resize(SLOTS)
	wear.resize(SLOTS)


# Add as many as fit (fills partial stacks first). Returns how many were left over.
# Stacks of food only join when their ages are close (spoilage.json merge_gap of the shelf life); a join averages the age.
func _mergeable(number: int, wear_a: int, wear_b: int) -> bool:
	if table == null:
		return true

	var life: int = table.shelf_units(number)
	return life == 0 or absi(wear_a - wear_b) <= int(float(life) * float(table.spoilage().get("merge_gap", 0.1)))


func _joined_age(number: int, wear_a: int, count_a: int, wear_b: int, count_b: int) -> int:
	if table == null or table.shelf_units(number) == 0:
		return wear_a

	return int(round(float(wear_a * count_a + wear_b * count_b) / float(maxi(count_a + count_b, 1))))


func add(number: int, count: int, item_wear: int = 0) -> int:
	if number <= 0 or count <= 0 or table == null:
		return count

	var stack: int = table.stack_of(number)
	var left: int = count

	for i in usable:
		if left > 0 and numbers[i] == number and counts[i] < stack and _mergeable(number, wear[i], item_wear):
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
				left -= put

	return left


func is_empty() -> bool:
	for i in SLOTS:
		if numbers[i] != 0:
			return false

	return true


func count_of(number: int) -> int:
	var total: int = 0

	for i in SLOTS:
		if numbers[i] == number:
			total += counts[i]

	return total


func has(number: int, count: int) -> bool:
	return count_of(number) >= count


# Take `count` of an item (from the last slots first). False and no change if there is not enough.
func remove(number: int, count: int) -> bool:
	if count <= 0 or not has(number, count):
		return false

	var left: int = count

	for i in range(SLOTS - 1, -1, -1):
		if left > 0 and numbers[i] == number:
			var take: int = mini(left, counts[i])
			counts[i] -= take
			left -= take

			if counts[i] == 0:
				numbers[i] = 0
				wear[i] = 0

	return true


# Ingredient counting (guide finding F-16, Tyler 31 Oct 2026): an ingredient that names a group (plain `log`, `wooden_block`, `firewood`: item_table.gd
# load_groups) is filled by the id itself or any member (log_oak ...). Recipes, the craft queue, the planner, blueprint costs and the client recipe list use
# these three; count_of / has / remove stay literal (one item number), so nothing else changes meaning.
func fills_of(number: int) -> PackedInt32Array:
	if table != null and table.has_method("group_members"):
		var members: PackedInt32Array = table.group_members(number)

		if not members.is_empty():
			return members

	return PackedInt32Array([number])


func count_fill(number: int) -> int:
	var fills: PackedInt32Array = fills_of(number)
	var total: int = 0

	for i in SLOTS:
		if numbers[i] != 0 and fills.has(numbers[i]):
			total += counts[i]

	return total


func has_fill(number: int, count: int) -> bool:
	return count_fill(number) >= count


# Takes `count` for an ingredient: the id itself first, then the group members in the order of the group. False and no change if the pack holds too few.
func remove_fill(number: int, count: int) -> bool:
	if count <= 0 or not has_fill(number, count):
		return false

	var left: int = count

	for fill in fills_of(number):
		if left > 0:
			var taken: int = mini(left, count_of(fill))

			if taken > 0:
				remove(fill, taken)
				left -= taken

	return true


# Remove from one slot; returns {number, count} actually taken.
func take_from_slot(slot: int, count: int) -> Dictionary:
	if slot < 0 or slot >= SLOTS or numbers[slot] == 0 or count <= 0:
		return {"number": 0, "count": 0}

	var take: int = mini(count, counts[slot])
	var number: int = numbers[slot]
	var item_wear: int = wear[slot]
	counts[slot] -= take

	if counts[slot] == 0:
		numbers[slot] = 0
		wear[slot] = 0

	return {"number": number, "count": take, "wear": item_wear}


# Move a slot onto another: merge when the same item, else swap.
func move(from_slot: int, to_slot: int) -> void:
	if from_slot == to_slot or from_slot < 0 or to_slot < 0 or from_slot >= SLOTS or to_slot >= SLOTS or numbers[from_slot] == 0:
		return

	if numbers[to_slot] == numbers[from_slot] and table != null and _mergeable(numbers[to_slot], wear[to_slot], wear[from_slot]):
		var room: int = table.stack_of(numbers[to_slot]) - counts[to_slot]
		var put: int = mini(room, counts[from_slot])
		wear[to_slot] = _joined_age(numbers[to_slot], wear[to_slot], counts[to_slot], wear[from_slot], put)
		counts[to_slot] += put
		counts[from_slot] -= put

		if counts[from_slot] == 0:
			numbers[from_slot] = 0
			wear[from_slot] = 0

		return

	var n: int = numbers[to_slot]
	var c: int = counts[to_slot]
	var w: int = wear[to_slot]
	numbers[to_slot] = numbers[from_slot]
	counts[to_slot] = counts[from_slot]
	wear[to_slot] = wear[from_slot]
	numbers[from_slot] = n
	counts[from_slot] = c
	wear[from_slot] = w


func to_bytes() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(1 + SLOTS * 8)
	out[0] = FORMAT

	for i in SLOTS:
		out.encode_u32(1 + i * 8, numbers[i])
		out.encode_u16(1 + i * 8 + 4, counts[i])
		out.encode_u16(1 + i * 8 + 6, mini(wear[i], 65535))

	return out


func from_bytes(bytes: PackedByteArray) -> bool:
	if bytes.size() != 1 + SLOTS * 8 or bytes[0] != FORMAT:
		return false

	for i in SLOTS:
		numbers[i] = bytes.decode_u32(1 + i * 8)
		counts[i] = bytes.decode_u16(1 + i * 8 + 4)
		wear[i] = bytes.decode_u16(1 + i * 8 + 6)

	return true


# JSON form for the server save file: [[number, count, wear], ...] with empty slots as [0, 0, 0]. Version 1
# saves had [number, count] only; they load with zero wear.
func to_json_array() -> Array:
	var out: Array = []

	for i in SLOTS:
		out.append([numbers[i], counts[i], wear[i]])

	return out


func from_json_array(data: Array) -> void:
	for i in mini(SLOTS, data.size()):
		numbers[i] = int(data[i][0])
		counts[i] = int(data[i][1])
		wear[i] = int(data[i][2]) if data[i].size() > 2 else 0
