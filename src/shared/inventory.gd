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

	for i in usable:
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
