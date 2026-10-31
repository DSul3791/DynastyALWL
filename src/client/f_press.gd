extends RefCounted

# What the F key does (Dave: put the carried log down by pressing F twice, like setting a pet down from your shoulder): with a log on the shoulder and no chest, station or remains in reach, the first F
# shows a hint and a second F within WINDOW_MS puts the log down; with something to open in reach, or no log, F opens it as before. Pure, so the headless check can test the 0.6 s window.

const WINDOW_MS := 600


# "open" (open the container or station beside you), "hint" (first F with a log: tell the player), "drop" (second F in time: lay the log down).
static func decide(carrying: bool, container_near: bool, now_ms: int, last_f_ms: int, window_ms: int = WINDOW_MS) -> String:
	if not carrying or container_near:
		return "open"

	if last_f_ms >= 0 and now_ms - last_f_ms <= window_ms:
		return "drop"

	return "hint"
