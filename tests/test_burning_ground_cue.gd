## Burning ground on screen, from the cues alone: a `burning_started` event draws a glowing orange
## patch with flames where the blow landed, and it stays until its `burning_out` event.
extends "res://tests/run.gd".TestCase

const CombatCuesScript := preload("res://scenes/combat_cues.gd")

const RING := {
	"kind": SimVocab.EV_BURNING_STARTED, "patch_id": "burn_1", "enemy_id": "foe", "damage": 5, "until": 9,
	"mark": {"shape": CombatTable.MARK_RING, "centre": [4.0, -2.0], "radius": 3.0},
}
const FRONT := {
	"kind": SimVocab.EV_BURNING_STARTED, "patch_id": "burn_2", "enemy_id": "foe", "damage": 4, "until": 9,
	"mark": {"shape": CombatTable.MARK_FRONT, "centre": [4.0, -2.0], "radius": 4.0, "facing": [1.0, 0.0], "arc": 120.0},
}


func _is_orange(c: Color) -> bool:
	return c.a > 0.0 and c.r > 0.8 and c.g > 0.25 and c.g < 0.65 and c.b < 0.3


func test_a_patch_shows_from_its_start_event_until_its_out_event() -> void:
	for e: Dictionary in [RING, FRONT]:
		var cues: CombatCues = CombatCuesScript.new()
		var id: String = e["patch_id"]
		assert_false(cues.has_patch(id), "nothing before it starts")
		cues.burn(e)
		assert_true(cues.has_patch(id), "%s: shown from its start" % e["mark"]["shape"])
		assert_true(_is_orange(cues.patch_colour(id)), "%s: a glowing orange" % e["mark"]["shape"])
		assert_true(cues.flame_count(id) >= 3, "%s: with flames on it" % e["mark"]["shape"])
		cues.expire_marks(100)
		assert_true(cues.has_patch(id), "%s: a mark's expiry does not put it out" % e["mark"]["shape"])
		cues.put_out(id)
		assert_false(cues.has_patch(id), "%s: gone at its out event" % e["mark"]["shape"])
		assert_eq(cues.patch_colour(id).a, 0.0)
		cues.free()


func test_the_patch_lies_where_the_blow_landed() -> void:
	var cues: CombatCues = CombatCuesScript.new()
	cues.burn(RING, 0.5)
	var ground := (cues.get_child(0) as Node3D).get_child(0) as MeshInstance3D
	assert_almost_eq(ground.position.x, 4.0)
	assert_almost_eq(ground.position.z, -2.0)
	assert_almost_eq(ground.scale.x, 6.0, 0.0001, "as wide as the mark")
	assert_true(ground.position.y > 0.5, "on the ground, just above it")
	cues.free()


func test_flames_stand_inside_the_mark() -> void:
	for e: Dictionary in [RING, FRONT]:
		for p in CombatCuesScript._flame_spots(e["mark"]):
			assert_true(CombatTable.in_mark(e["mark"], p), "%s: a flame at %s" % [e["mark"]["shape"], p])


func test_reduced_motion_holds_the_flames_still() -> void:
	var cues: CombatCues = CombatCuesScript.new()
	cues.reduced_motion = true
	cues.burn(RING)
	var a := cues.patch_colour("burn_1")
	cues._process(0.37)
	assert_eq(cues.patch_colour("burn_1"), a)
	cues.free()
