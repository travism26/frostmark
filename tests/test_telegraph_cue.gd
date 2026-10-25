## The word over an enemy's head, from the pure function GameRoot shows it with: a telegraph
## or a change of stance names the blow or the stance, shouted with a "!" when heavy, and a
## feint turns it to "Feint".
extends "res://tests/run.gd".TestCase

const GameRootScript := preload("res://scenes/game_root.gd")


func test_a_telegraph_names_its_blow() -> void:
	assert_eq(GameRootScript.cue_text({"kind": SimVocab.EV_ENEMY_TELEGRAPHED, "action": "bite", "heavy": false}), "BITE")
	assert_eq(GameRootScript.cue_text({"kind": SimVocab.EV_ENEMY_TELEGRAPHED, "action": "lunge", "heavy": true}), "LUNGE!")


func test_a_stance_names_itself() -> void:
	assert_eq(GameRootScript.cue_text({"kind": SimVocab.EV_ENEMY_STANCE, "action": "draw_bow"}), "DRAWS HIS BOW")


func test_a_feint_reads_feint() -> void:
	var feint := {
		"kind": SimVocab.EV_ENEMY_FEINTED, "enemy_id": "foe", "action": "lunge",
		"style": CombatTable.STYLE_MELEE, "at": 3,
	}
	assert_eq(GameRootScript.cue_text(feint), "Feint")
