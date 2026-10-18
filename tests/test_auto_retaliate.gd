## Auto-retaliate: a player standing idle who is hit fights back with the weapon in hand,
## a walk always wins, the style is never switched for them, and off means off.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

## Five metres north of the bandit archer: inside its sight and its bow's reach, and well
## away from both wolf packs.
const NEAR_ARCHER := [14.5, 23.5]


## A player standing idle five metres from the archer with `weapon` in hand and `pack`.
func _beside_archer(weapon: String, pack: Array = []) -> Sim:
	var sim := SimScript.new()
	H.place(sim, NEAR_ARCHER)
	H.arm(sim, weapon, pack)
	sim.drain_events()
	return sim


## Steps until the archer's first blow lands, and returns that tick's events.
func _until_hit(sim: Sim) -> Array[Dictionary]:
	for i in 20:
		var events := H.run_stamped(sim, 1)
		if not H.where(events, Vocab.EV_HIT, "attacker", "archer_1").is_empty():
			return events
	return []


func test_it_is_on_for_a_new_sim() -> void:
	assert_true(SimScript.new().auto_retaliate)


func test_an_idle_player_fights_back_against_whoever_hit_them() -> void:
	var sim := _beside_archer("wooden_bow", [{"item": "arrows", "count": 20}])
	assert_false(_until_hit(sim).is_empty(), "the archer shoots an idle player")
	assert_eq(sim.state["player"]["activity"], {"kind": Vocab.ATTACK, "object_id": "archer_1"})
	var events := H.run_stamped(sim, 4)
	var mine := H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER)
	assert_true(mine.size() > 0, "the player shoots back")
	assert_eq(mine[0]["target"], "archer_1")


func test_it_closes_in_like_an_attack_when_the_weapon_is_short() -> void:
	var sim := _beside_archer("wooden_club")
	_until_hit(sim)
	assert_eq(sim.state["player"]["activity"].get("object_id"), "archer_1")
	var events := H.run_stamped(sim, 10)
	var mine := H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER)
	assert_true(mine.size() > 0, "the club walks up and lands")
	assert_eq(mine[0]["style"], CombatTable.STYLE_MELEE)


func test_it_never_switches_style() -> void:
	# A club in the pack would beat the archer up close; the bow stays in hand all the same.
	var sim := _beside_archer("wooden_bow", [{"item": "wooden_club", "count": 1}, {"item": "arrows", "count": 20}])
	_until_hit(sim)
	var events := H.run_stamped(sim, 8)
	assert_eq(sim.player_weapon(), "wooden_bow")
	assert_eq(H.of_kind(events, Vocab.EV_EQUIPPED).size(), 0)
	var mine := H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER)
	assert_true(mine.size() > 0)
	for hit in mine:
		assert_eq(hit["style"], CombatTable.STYLE_RANGED)


func test_off_means_the_player_stands_still() -> void:
	var sim := _beside_archer("wooden_bow", [{"item": "arrows", "count": 20}])
	assert_true(sim.command(Vocab.SET_AUTO_RETALIATE, {"on": false})["ok"])
	assert_false(sim.auto_retaliate)
	_until_hit(sim)
	var events := H.run_stamped(sim, 6)
	assert_true(sim.state["player"]["activity"].is_empty())
	assert_eq(H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER).size(), 0)
	assert_true(sim.command(Vocab.SET_AUTO_RETALIATE, {"on": true})["ok"])
	_until_hit(sim)
	assert_eq(sim.state["player"]["activity"].get("object_id"), "archer_1", "and back on, it fights again")


func test_a_walking_player_keeps_walking() -> void:
	var sim := _beside_archer("wooden_bow", [{"item": "arrows", "count": 20}])
	# Walk the long way along the archer's front, inside its reach the whole time.
	assert_true(sim.command(Vocab.MOVE_TO, {"pos": [4.5, 23.5]})["ok"])
	var events := H.run_stamped(sim, 3)
	assert_false(H.where(events, Vocab.EV_HIT, "attacker", "archer_1").is_empty(), "shot while walking")
	assert_true(sim.state["player"]["activity"].is_empty(), "the walk goes on")
	assert_eq(H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER).size(), 0)


func test_a_move_click_wins_over_retaliation() -> void:
	var sim := _beside_archer("wooden_bow", [{"item": "arrows", "count": 20}])
	_until_hit(sim)
	assert_eq(sim.state["player"]["activity"].get("kind"), Vocab.ATTACK)
	assert_true(sim.command(Vocab.MOVE_TO, {"pos": [14.5, 14.5]})["ok"])
	assert_true(sim.state["player"]["activity"].is_empty(), "the walk replaced the fight at once")
	var events := H.run_stamped(sim, 2)
	assert_eq(H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER).size(), 0)
	assert_true(sim.is_moving(), "and the player is on the way")


func test_it_holds_back_when_attack_would_refuse() -> void:
	var sim := _beside_archer("wooden_bow")  # no arrows
	var hit := _until_hit(sim)
	assert_false(hit.is_empty())
	assert_true(sim.state["player"]["activity"].is_empty(), "a bow with no arrows does not fight back")
	assert_eq(H.of_kind(hit, Vocab.EV_COMMAND_REJECTED).size(), 0, "and says nothing about it")


func test_it_is_not_in_the_save() -> void:
	var sim := SimScript.new()
	sim.command(Vocab.SET_AUTO_RETALIATE, {"on": false})
	assert_false(JSON.stringify(sim.snapshot()).contains("retaliate"))
	var code: String = sim.command(Vocab.EXPORT_SAVE)["code"]
	var other := SimScript.new()
	assert_true(other.command(Vocab.IMPORT_SAVE, {"code": code})["ok"])
	assert_true(other.auto_retaliate, "a loaded save keeps the browser's setting")
	sim.command(Vocab.NEW_CHARACTER, {"previous": ""})
	assert_false(sim.auto_retaliate, "so does a new character")


func test_bad_args_are_refused() -> void:
	var sim := SimScript.new()
	assert_eq(sim.command(Vocab.SET_AUTO_RETALIATE, {})["reason"], Vocab.REASON_BAD_ARGS)
	assert_eq(sim.command(Vocab.SET_AUTO_RETALIATE, {"on": 0})["reason"], Vocab.REASON_BAD_ARGS)
	assert_true(sim.auto_retaliate)
