extends RefCounted

# How worn a boulder looks and how big it is (Dave 21 Nov 2026, play test: "it should crack and start to shrink right from the first hit. it should
# shrink right along with however many stones or ore it has left and crack accordingly"). Before this the size was the cube root of the share left,
# so a rock kept almost all of its size until its last few blows. Now its radius falls in a straight line with the share of stones or ore left,
# from its full radius down to SMALLEST_SHARE of it at the last stone, and it shows cracks from the first blow that took anything. The server
# (reach, what blocks, the drop spot) and the client (the look and its solid shape) both size a rock with these, so they agree.

const SMALLEST_SHARE := 0.2   # a rock down to its last stone is drawn a fifth of its full radius (PROVISIONAL BW-1)
const FIRST_CRACK := 0.2      # crack amount after the first blow: a few fine lines; it rises in a straight line to 1.0 at the last stone (PROVISIONAL BW-2)


# The share of the rock still there: `left` stones of `total`, 0 to 1.
static func share_left(left: int, total: int) -> float:
	return clampf(float(left) / float(maxi(total, 1)), 0.0, 1.0)


# The radius now of a rock of full radius `radius` with `left` of its `total` stones left.
static func radius_now(radius: float, left: int, total: int) -> float:
	return radius * lerpf(SMALLEST_SHARE, 1.0, share_left(left, total))


# The crack amount for the look (inventory_view CRACK_SHADER "crack"): 0 on a whole rock, FIRST_CRACK once anything is taken, 1.0 at the last stone.
static func crack(left: int, total: int) -> float:
	var share: float = share_left(left, total)

	if share >= 1.0:
		return 0.0

	return lerpf(FIRST_CRACK, 1.0, 1.0 - share)
