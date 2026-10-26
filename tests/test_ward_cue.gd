## A ward on screen, from the cues alone: a warded phase's opening stance names the one style
## that hurts the enemy, and a warded blow shows as a pale deflection at the enemy, not a miss.
extends "res://tests/run.gd".TestCase

const GameRootScript := preload("res://scenes/game_root.gd")
const CombatCuesScript := preload("res://scenes/combat_cues.gd")

const WARDED_HIT := {
	"kind": SimVocab.EV_HIT, "attacker": SimVocab.PLAYER, "target": "foe", "amount": 0,
	"style": CombatTable.STYLE_MELEE, "multiplier": 1.0, "health": 240, "warded": CombatTable.STYLE_MAGIC,
}


func test_a_warded_stance_names_the_style_that_hurts() -> void:
	var stance := {
		"kind": SimVocab.EV_ENEMY_STANCE, "enemy_id": "foe", "action": "bear_rears",
		"style": CombatTable.STYLE_MELEE, "at": 4, "ward": CombatTable.STYLE_MAGIC,
	}
	assert_eq(GameRootScript.cue_text(stance), "REARS AND ROARS: ONLY MAGIC")
	assert_eq(GameRootScript.ward_text("the warder", CombatTable.STYLE_MAGIC), "The warder raises a ward: only magic hurts it now.")


func test_a_warded_blow_shows_a_deflection() -> void:
	var cues: CombatCues = CombatCuesScript.new()
	cues.deflect(Vector3(2.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0))
	assert_eq(cues.get_child_count(), 1, "a deflection is drawn")
	var flare := cues.get_child(0) as MeshInstance3D
	var colour := (flare.material_override as StandardMaterial3D).albedo_color
	assert_eq(Color(colour, 1.0), Color(CombatCues.DEFLECT_COLOUR, 1.0), "pale, in the deflection's colour")
	assert_almost_eq(flare.position.x, 2.0, 0.0001, "at the enemy")
	var toward := (flare.basis * Vector3(0, 0, 1)).normalized()
	assert_almost_eq(toward.x, -1.0, 0.0001, "flaring toward the one who struck")
	cues._process(CombatCues.ARC_SECONDS + 0.1)
	assert_true(flare.is_queued_for_deletion(), "and fades out after")
	cues.free()


func test_a_warded_blow_reads_as_a_deflection_not_a_miss() -> void:
	var text := GameRootScript.warded_text("the warder", WARDED_HIT["warded"])
	assert_eq(text, "Your blow glances off the warder's ward. Only magic gets through.")
	assert_false(text.contains("miss"))
