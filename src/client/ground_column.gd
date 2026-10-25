extends RefCounted

# The rule for diving the streaming viewer to the ground under a player who is high up (Spawn column first, 25 Oct). `column` is true while the player flies or
# waits for ground. The ground (surface) must be known and more than MIN_HEIGHT_M BELOW the player: a player in a cave or tunnel has the surface ABOVE, so
# he is never pulled to it, and a normal join (spawn + 28 m) is under the limit.

const MIN_HEIGHT_M := 40.0


static func dive(column: bool, ground_y: float, player_y: float) -> bool:
	return column and not is_nan(ground_y) and ground_y < player_y - MIN_HEIGHT_M
