extends RefCounted

# Lag logs (Steve, 2 Nov 2026): settled water was asked for again every 3 s. terrain_client waits this long between water re-asks.
# Kept out of terrain_client.gd so it can be tested in the cloud, where stock Godot has no Voxel Tools to load the client.


# The wait before the next water re-ask: back to min_msec when the last one brought changed water, else twice as long up to max_msec.
# Settled water (the server says "moved" but sends nothing new) is asked about less and less.
static func wait_after(wait_msec: int, new_chunks: int, min_msec: int, max_msec: int) -> int:
	if new_chunks > 0:
		return min_msec

	return mini(wait_msec * 2, max_msec)
