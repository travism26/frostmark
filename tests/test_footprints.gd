## Footprints: a small pool of prints laid each stride inside the yard and nowhere else, the
## oldest reused once the pool is full.
extends "res://tests/run.gd".TestCase

const WorldDefScript := preload("res://sim/world_def.gd")
const FootprintsScript := preload("res://scenes/footprints.gd")


func _walk(prints: Node, from: Vector2, to: Vector2, steps: int) -> void:
	for i in steps + 1:
		prints.track(from.lerp(to, float(i) / steps))


func test_prints_are_laid_in_the_yard_and_not_in_the_rings() -> void:
	var w := WorldDefScript.outpost()
	var prints := FootprintsScript.new()
	prints.setup(null, w)
	_walk(prints, Vector2(-3.0, 0.5), Vector2(3.0, 0.5), 60)
	assert_true(prints.count() >= 6, "a print every stride across the yard (%d)" % prints.count())
	var in_yard: int = prints.count()
	_walk(prints, Vector2(0.5, 42.0), Vector2(6.5, 42.0), 60)
	assert_eq(prints.count(), in_yard, "none out in ring one")
	_walk(prints, Vector2(-4.0, -3.0), Vector2(4.0, 3.0), 400)
	_walk(prints, Vector2(4.0, 3.0), Vector2(-4.0, -3.0), 400)
	assert_eq(prints.count(), FootprintsScript.POOL, "the pool caps the prints")
	prints.clear()
	assert_eq(prints.count(), 0, "a new game clears them")
	prints.free()
