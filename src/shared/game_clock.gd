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
# A new world starts on day 30 of spring at 08:00.
const START_SECONDS := (30.0 * 24.0 + 8.0) * 3600.0

var seconds: float = START_SECONDS    # game seconds since the world began


func advance(real_seconds: float) -> void:
	seconds += real_seconds * RATIO


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
