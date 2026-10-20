extends RefCounted

# A player's inventory: fixed slots of {item number, count}. Pure data, no
# scene code, so the server (which owns it) and the client (which shows it)
# use the same rules. Number 0 means an empty slot.

const SLOTS := 30
const FORMAT := 1

var table
var numbers: PackedInt32Array = PackedInt32Array()
var counts: PackedInt32Array = PackedInt32Array()


func _init(item_table = null) -> void:
	table = item_table
	numbers.resize(SLOTS)
	counts.resize(SLOTS)


# Add as many as fit (fills partial stacks first). Returns how many were left over.
func add(number: int, count: int) -> int:
	if number <= 0 or count <= 0 or table == null:
		return count

	var stack: int = table.stack_of(number)
	var left: int = count

	for i in SLOTS:
		if left > 0 and numbers[i] == number and counts[i] < stack:
			var put: int = mini(left, stack - counts[i])
			counts[i] += put
			left -= put

	for i in SLOTS:
		if left > 0 and numbers[i] == 0:
			var put: int = mini(left, stack)
			numbers[i] = number
			counts[i] = put
			left -= put

	return left


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

	return true


# Remove from one slot; returns {number, count} actually taken.
func take_from_slot(slot: int, count: int) -> Dictionary:
	if slot < 0 or slot >= SLOTS or numbers[slot] == 0 or count <= 0:
		return {"number": 0, "count": 0}

	var take: int = mini(count, counts[slot])
	var number: int = numbers[slot]
	counts[slot] -= take

	if counts[slot] == 0:
		numbers[slot] = 0

	return {"number": number, "count": take}


# Move a slot onto another: merge when the same item, else swap.
func move(from_slot: int, to_slot: int) -> void:
	if from_slot == to_slot or from_slot < 0 or to_slot < 0 or from_slot >= SLOTS or to_slot >= SLOTS or numbers[from_slot] == 0:
		return

	if numbers[to_slot] == numbers[from_slot] and table != null:
		var room: int = table.stack_of(numbers[to_slot]) - counts[to_slot]
		var put: int = mini(room, counts[from_slot])
		counts[to_slot] += put
		counts[from_slot] -= put

		if counts[from_slot] == 0:
			numbers[from_slot] = 0

		return

	var n: int = numbers[to_slot]
	var c: int = counts[to_slot]
	numbers[to_slot] = numbers[from_slot]
	counts[to_slot] = counts[from_slot]
	numbers[from_slot] = n
	counts[from_slot] = c


func to_bytes() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(1 + SLOTS * 6)
	out[0] = FORMAT

	for i in SLOTS:
		out.encode_u32(1 + i * 6, numbers[i])
		out.encode_u16(1 + i * 6 + 4, counts[i])

	return out


func from_bytes(bytes: PackedByteArray) -> bool:
	if bytes.size() != 1 + SLOTS * 6 or bytes[0] != FORMAT:
		return false

	for i in SLOTS:
		numbers[i] = bytes.decode_u32(1 + i * 6)
		counts[i] = bytes.decode_u16(1 + i * 6 + 4)

	return true


# JSON form for the server save file: [[number, count], ...] with empty slots as [0, 0].
func to_json_array() -> Array:
	var out: Array = []

	for i in SLOTS:
		out.append([numbers[i], counts[i]])

	return out


func from_json_array(data: Array) -> void:
	for i in mini(SLOTS, data.size()):
		numbers[i] = int(data[i][0])
		counts[i] = int(data[i][1])
