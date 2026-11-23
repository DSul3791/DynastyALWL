extends RefCounted
# The one game clock (Technical direction, 2026-10-20; DESIGN_IDEAS 7.2 and 7.6).
# The server owns the counter and sends it in the welcome message; every client keeps
# its own copy and advances it at the same ratio. Sky, sun, sounds and weather read
# hour(), season() and day_of_year(); nothing else keeps time. The counter only
# advances while the server runs (it is saved by the server).

const RATIO := 24.0              # game hours per real hour: a game day is one real hour
const DAYS_PER_YEAR := 365
const SEASON_NAMES := ["spring", "summer", "autumn", "winter"]
const SECONDS_PER_DAY := 86400.0
# A new world starts on day 100 (early summer) at 08:00 (moderator, 31 Oct 2026: from day 30 of spring nothing with berries or nuts was in season for about 62 real hours).
const START_SECONDS := (100.0 * 24.0 + 8.0) * 3600.0

var seconds: float = START_SECONDS    # game seconds since the world began


var _sync_seconds: float = 0.0
var _sync_msec: int = -1


# Clients: take the server's value once, then follow the machine's own tick counter, so
# a slow or paused frame never makes the copy drift from the server.
func sync(server_seconds: float) -> void:
	seconds = server_seconds
	_sync_seconds = server_seconds
	_sync_msec = Time.get_ticks_msec()


func tick() -> void:
	if _sync_msec >= 0:
		seconds = _sync_seconds + float(Time.get_ticks_msec() - _sync_msec) / 1000.0 * RATIO


# Server: the counter advances by the frame time.
func advance(real_seconds: float) -> void:
	seconds += real_seconds * RATIO


var _follow_usec: int = -1


# Server, each frame: the counter advances by the real time since the last call (`now_usec`, Time.get_ticks_usec), not the frame's delta.
# Godot clips a long frame's delta (about 0.13 s however long the frame took: a 3 s freeze gave 0.18 s), so the server's clock fell behind
# the clients' (which follow their own tick counter from the welcome) by every hitch and freeze: players who joined at different times saw
# different times of day, and the sky disagreed with the server's crops, fires and seasons (two players see the same world, 23 Nov 2026).
# The server's own frame timers (a fire's burn, animals, NPCs) still run on the clipped delta, so in a freeze they fall behind the clock.
func follow(now_usec: int) -> void:
	if _follow_usec >= 0 and now_usec > _follow_usec:
		advance(float(now_usec - _follow_usec) / 1000000.0)

	_follow_usec = now_usec


func hour() -> float:
	return fposmod(seconds, SECONDS_PER_DAY) / 3600.0


func day_of_year() -> int:
	return int(floorf(seconds / SECONDS_PER_DAY)) % DAYS_PER_YEAR


func year() -> int:
	return int(floorf(seconds / (SECONDS_PER_DAY * float(DAYS_PER_YEAR))))


func season_index() -> int:
	return day_of_year() * SEASON_NAMES.size() / DAYS_PER_YEAR


func season() -> String:
	return SEASON_NAMES[season_index()]
