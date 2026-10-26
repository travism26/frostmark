## An add's announcement on screen, from the cues alone: an `add_called` event shows where the
## add will enter, a pale ring on the snow at its entry point, until it comes in or leaves.
extends "res://tests/run.gd".TestCase

const CombatCuesScript := preload("res://scenes/combat_cues.gd")

const CALLED := {
	"kind": SimVocab.EV_ADD_CALLED, "enemy_id": "foe_add_1", "enemy_kind": "wolf", "boss_id": "foe",
	"pos": [5.0, -2.0], "at": 7,
}


func test_an_add_announcement_shows_where_it_will_enter() -> void:
	var cues: CombatCues = CombatCuesScript.new()
	assert_eq(cues.call_point("foe_add_1"), null, "nothing before the call")
	cues.call_in(CALLED, 0.5)
	var at: Variant = cues.call_point("foe_add_1")
	assert_true(at is Vector3, "the entry is shown")
	if at is Vector3:
		assert_almost_eq(at.x, 5.0)
		assert_almost_eq(at.z, -2.0)
		assert_true(at.y > 0.5, "on the ground, just above it")
	var mesh := cues.get_child(0) as MeshInstance3D
	var colour := (mesh.material_override as StandardMaterial3D).albedo_color
	assert_true(colour.a > 0.0 and colour.b > colour.r, "pale, not a ground mark's red")
	cues.free()


func test_the_entry_clears_once_the_add_comes_in_or_leaves() -> void:
	var cues: CombatCues = CombatCuesScript.new()
	cues.call_in(CALLED)
	cues.call_in(CALLED.merged({"enemy_id": "foe_add_2", "pos": [-5.0, -2.0]}, true))
	cues.clear_call("foe_add_1")
	assert_eq(cues.call_point("foe_add_1"), null, "the first came in")
	assert_true(cues.call_point("foe_add_2") is Vector3, "the second is still to come")
	cues.call_in(CALLED.merged({"enemy_id": "foe_add_2", "pos": [-6.0, -2.0]}, true))
	assert_almost_eq((cues.call_point("foe_add_2") as Vector3).x, -6.0, 0.0001, "a second call redraws it")
	cues.free()
