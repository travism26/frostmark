## When to nudge the player about their save code: a reminder after a long stretch of play,
## and a warning when the browser stops keeping saves (storage full, or blocked as in some
## private browsing). The save code is the fallback that always works, so both point at it.
##
## One SaveWatch lives for a session and is never saved: a fresh session starts the count
## again. It counts ticks of play, not wall-clock time, so a paused game (title, death or
## ending screen) does not count down. Engine-free like sim/.
class_name SaveWatch
extends RefCounted

## 45 minutes of play at Sim.TICK_SECONDS (0.5 s).
const REMINDER_TICKS := 5400
## 15 minutes of play while the browser is not keeping saves: the code is the only save then.
const REMINDER_TICKS_UNSTORED := 1800

## Whether the last browser-save write held. Starts true until a write says otherwise.
var storage_ok := true
var _since := 0  # ticks of play since the player last saw their code or waved a reminder off


## Advances one tick of play. True exactly on the tick a reminder falls due; the count then
## starts again, so an ignored reminder comes back one interval later.
func advance() -> bool:
	_since += 1
	if _since < interval():
		return false
	_since = 0
	return true


## Ticks between reminders right now.
func interval() -> int:
	return REMINDER_TICKS if storage_ok else REMINDER_TICKS_UNSTORED


## Ticks left until the next reminder.
func ticks_left() -> int:
	return maxi(0, interval() - _since)


## The player opened or copied their code, or dismissed a reminder: start the count again.
func code_seen() -> void:
	_since = 0


## Records whether a browser-save write held. True when this write is the one that failed
## after storage was fine (or at the first write), so the warning shows once per failure,
## not at every save point. A later write that holds clears it.
func stored(ok: bool) -> bool:
	var newly_failed := storage_ok and not ok
	storage_ok = ok
	return newly_failed
