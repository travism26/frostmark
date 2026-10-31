## When the snow takes a pile (#234): the countdown shown on hover and the blink of its last
## minute. Pure functions of the ticks left, so the drawing code only asks.
class_name PileTimer
extends RefCounted

## A pile blinks this many times a second in its last minute.
const BLINK_HZ := 2.0


## Whole seconds left of `ticks_left` ticks, rounded up so a pile never reads 0:00 while it lies.
static func seconds_left(ticks_left: int) -> int:
	return ceili(maxf(0.0, ticks_left) * Sim.TICK_SECONDS)


## "4:07" for a pile with that many ticks left.
static func countdown(ticks_left: int) -> String:
	var s := seconds_left(ticks_left)
	return "%d:%02d" % [s / 60, s % 60]


## Whether the snow is about to take the pile: its last minute.
static func fading(ticks_left: int) -> bool:
	return ticks_left <= Sim.LOOT_FADE_TICKS


## Whether the pile is drawn now: always until its last minute, then it blinks, off for a
## longer share of each blink the closer the snow comes. A plain on/off, since a mesh's
## transparency is not drawn by every renderer. `time` is wall-clock seconds, for the phase only.
static func lit(ticks_left: int, time: float) -> bool:
	if not fading(ticks_left):
		return true
	var near := 1.0 - clampf(float(ticks_left) / Sim.LOOT_FADE_TICKS, 0.0, 1.0)
	var phase := fposmod(time * BLINK_HZ, 1.0)
	return phase < lerpf(0.8, 0.3, near)
