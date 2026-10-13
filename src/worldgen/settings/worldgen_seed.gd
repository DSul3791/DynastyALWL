class_name WorldgenSeed
extends RefCounted

# Deterministic seeds for the world generator.
#
# Everything is built on SHA-256, so results are the same on every
# machine, Godot version and operating system. The functions here match
# WorldDefinition.seed_from_text() and WorldDefinition._derive_tile_seed(),
# so tile seeds agree with the ones already stored in region files.


# Master seed from the world's seed phrase. Positive 31-bit integer.
static func master_seed(seed_text: String) -> int:
	return _digest_to_int(seed_text.sha256_buffer()) & 0x7fffffff


# Seed of one tile. Kept below 2^30 so stage offsets added to it still
# fit the 32-bit seed that FastNoiseLite accepts.
static func tile_seed(master: int, tile_x: int, tile_z: int) -> int:
	var key: String = "tile:%d:%d:%d" % [master, tile_x, tile_z]
	return _digest_to_int(key.sha256_buffer()) & 0x3fffffff


# Seed for any named purpose at a tile, for example
# purpose_seed(master, "matrix", 3, 4) or an island id.
static func purpose_seed(
	master: int,
	purpose: String,
	tile_x: int = 0,
	tile_z: int = 0,
	extra: int = 0
) -> int:
	var key: String = "%s:%d:%d:%d:%d" % [purpose, master, tile_x, tile_z, extra]
	return _digest_to_int(key.sha256_buffer()) & 0x3fffffff


# A random number generator seeded for one purpose. Using a separate
# generator for every purpose means that changing one tile or one pass
# never changes the random choices made anywhere else.
static func rng_for(
	master: int,
	purpose: String,
	tile_x: int = 0,
	tile_z: int = 0,
	extra: int = 0
) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = purpose_seed(master, purpose, tile_x, tile_z, extra)
	return rng


static func _digest_to_int(digest: PackedByteArray) -> int:
	return (
		(digest[0] << 24)
		| (digest[1] << 16)
		| (digest[2] << 8)
		| digest[3]
	)
