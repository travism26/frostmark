## An area blow's ground mark on screen, from the cues alone: a `ground_marked` event draws it
## red where the blow will land, it brightens on the landing tick and it clears after; and the
## word over the enemy's head names the blow.
extends "res://tests/run.gd".TestCase

const GameRootScript := preload("res://scenes/game_root.gd")
const CombatCuesScript := preload("res://scenes/combat_cues.gd")

const FRONT := {
	"kind": SimVocab.EV_GROUND_MARKED, "enemy_id": "foe", "action": "smash", "style": CombatTable.STYLE_MELEE,
	"damage": 20, "heavy": true, "at": 5,
	"mark": {"shape": CombatTable.MARK_FRONT, "centre": [4.0, -2.0], "radius": 3.0, "facing": [1.0, 0.0], "arc": 120.0},
}
const RING := {
	"kind": SimVocab.EV_GROUND_MARKED, "enemy_id": "foe", "action": "smash", "style": CombatTable.STYLE_MELEE,
	"damage": 20, "heavy": true, "at": 5,
	"mark": {"shape": CombatTable.MARK_RING, "centre": [4.0, -2.0], "radius": 2.5},
}
const DROP := {
	"kind": SimVocab.EV_GROUND_MARKED, "enemy_id": "foe", "action": "ice_fall", "style": CombatTable.STYLE_MELEE,
	"damage": 14, "heavy": true, "at": 5,
	"mark": {"shape": CombatTable.MARK_DROP, "centre": [7.0, 3.5], "radius": 2.5},
}


func _is_red(c: Color) -> bool:
	return c.a > 0.0 and c.r > 0.8 and c.g < 0.5 and c.b < 0.5


func test_a_ground_mark_draws_red_brightens_on_landing_and_clears_after() -> void:
	for e: Dictionary in [FRONT, RING, DROP]:
		var cues: CombatCues = CombatCuesScript.new()
		assert_eq(cues.mark_colour("foe").a, 0.0, "nothing before the mark")
		cues.mark(e)
		var told := cues.mark_colour("foe")
		assert_true(_is_red(told), "%s: red from the tick it is told" % e["mark"]["shape"])
		cues.expire_marks(4)
		assert_eq(cues.mark_colour("foe"), told, "%s: still down on the rooted tick" % e["mark"]["shape"])
		cues.expire_marks(5)
		cues.land_mark("foe")
		var landed := cues.mark_colour("foe")
		assert_true(_is_red(landed), "%s: still red on the landing tick" % e["mark"]["shape"])
		assert_true(landed.a > told.a, "%s: and brighter" % e["mark"]["shape"])
		cues.expire_marks(6)
		assert_eq(cues.mark_colour("foe").a, 0.0, "%s: gone the tick after" % e["mark"]["shape"])
		cues.free()


func test_the_mark_lies_where_the_blow_lands() -> void:
	var cues: CombatCues = CombatCuesScript.new()
	cues.mark(FRONT, 0.5)
	var mesh := cues.get_child(0) as MeshInstance3D
	assert_almost_eq(mesh.position.x, 4.0)
	assert_almost_eq(mesh.position.z, -2.0)
	assert_true(mesh.position.y > 0.5, "on the ground, just above it")
	assert_almost_eq(mesh.scale.x, 6.0, 0.0001, "as wide as the mark")
	# A front mark turns to face +x: local +z rotated onto the facing.
	var ahead := (mesh.basis * Vector3(0, 0, 1)).normalized()
	assert_almost_eq(ahead.x, 1.0)
	assert_almost_eq(ahead.z, 0.0)
	cues.free()


func test_a_drop_mark_lies_where_the_player_stood() -> void:
	var cues: CombatCues = CombatCuesScript.new()
	cues.mark(DROP, 0.5)
	var mesh := cues.get_child(0) as MeshInstance3D
	assert_almost_eq(mesh.position.x, 7.0)
	assert_almost_eq(mesh.position.z, 3.5)
	assert_almost_eq(mesh.scale.x, 5.0, 0.0001, "as wide as the mark")
	cues.free()


func test_a_fallen_enemy_s_mark_clears_at_once() -> void:
	var cues: CombatCues = CombatCuesScript.new()
	cues.mark(RING)
	cues.clear_mark("foe")
	assert_eq(cues.mark_colour("foe").a, 0.0)
	cues.free()


func test_the_word_over_its_head_names_the_blow() -> void:
	assert_eq(GameRootScript.cue_text(FRONT), "SMASH!")
