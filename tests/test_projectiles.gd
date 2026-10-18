## Shots in flight, from the pure functions GameRoot drives them with: a bow throws an arrow
## and a staff a frost shard, a monster's shot arrives on its blow's tick, a shot flies from
## shooter to target, and it lands on a hit, drops past the target on a miss and never hangs
## in the air. How it looks is judged by hand.
extends "res://tests/run.gd".TestCase

const ProjectilesScript := preload("res://scenes/projectiles.gd")


func test_a_bow_throws_an_arrow_and_a_staff_a_frost_shard() -> void:
	assert_eq(ProjectilesScript.kind_for(CombatTable.STYLE_RANGED), ProjectilesScript.ARROW)
	assert_eq(ProjectilesScript.kind_for(CombatTable.STYLE_MAGIC), ProjectilesScript.SHARD)
	assert_eq(ProjectilesScript.kind_for(CombatTable.STYLE_MELEE), "", "a blade throws nothing")


func test_every_weapon_with_ammunition_has_a_projectile() -> void:
	var weapons: Array = CombatTable.NATURAL_WEAPONS.keys() + ItemTable.ITEMS.keys()
	for id in weapons:
		var style: String = CombatTable.weapon(id)["style"]
		if style != CombatTable.STYLE_MELEE:
			assert_ne(ProjectilesScript.kind_for(style), "", "%s throws something" % id)


func test_a_shot_is_seen_and_lands_before_the_next_blow() -> void:
	assert_eq(ProjectilesScript.flight_seconds(0.0), ProjectilesScript.FLIGHT_MIN, "a point-blank shot is still seen")
	assert_true(ProjectilesScript.flight_seconds(10.0) <= Sim.TICK_SECONDS, "the longest reach lands inside a tick")
	var last := 0.0
	for m in 13:
		var s := ProjectilesScript.flight_seconds(float(m))
		assert_true(s >= last, "a longer shot is never quicker")
		last = s


func test_a_monsters_shot_arrives_on_its_blows_tick() -> void:
	for distance in [1.0, 4.0, 8.0, 10.0]:
		for until_blow in [0.5, 0.3]:
			var flight := ProjectilesScript.flight_seconds(distance)
			var arrives := ProjectilesScript.launch_delay(distance, until_blow) + flight
			assert_almost_eq(arrives, maxf(until_blow, flight), 0.0001, "%s m with %s s to go" % [distance, until_blow])
	assert_eq(ProjectilesScript.launch_delay(10.0, 0.05), 0.0, "late, it leaves at once and waits at the target")


func test_a_shot_flies_from_shooter_to_target() -> void:
	var from := Vector3(0, 1.2, 0)
	var to := Vector3(8, 1.0, 0)
	for kind in [ProjectilesScript.ARROW, ProjectilesScript.SHARD]:
		assert_eq(ProjectilesScript.point(from, to, 0.0, kind), from, "%s leaves the shooter" % kind)
		assert_eq(ProjectilesScript.point(from, to, 1.0, kind), to, "%s reaches the target" % kind)
	var mid_arrow := ProjectilesScript.point(from, to, 0.5, ProjectilesScript.ARROW)
	var mid_shard := ProjectilesScript.point(from, to, 0.5, ProjectilesScript.SHARD)
	assert_true(mid_arrow.y > from.lerp(to, 0.5).y, "an arrow lobs")
	assert_almost_eq(mid_shard.y, from.lerp(to, 0.5).y, 0.0001, "a shard flies straight")


func test_a_players_shot_lands_as_it_arrives() -> void:
	var shot := _shot(0.0, 0.2, true)
	assert_eq(ProjectilesScript.phase(_at(shot, 0.1)), ProjectilesScript.FLYING)
	assert_eq(ProjectilesScript.phase(_at(shot, 0.2)), ProjectilesScript.LANDED)


func test_a_monsters_shot_waits_its_turn_then_lands_on_a_hit() -> void:
	var shot := _shot(0.3, 0.2, null)
	assert_eq(ProjectilesScript.phase(_at(shot, 0.1)), ProjectilesScript.WAITING, "the bow is still drawing")
	assert_eq(ProjectilesScript.phase(_at(shot, 0.4)), ProjectilesScript.FLYING)
	assert_eq(ProjectilesScript.phase(_at(shot, 0.52)), ProjectilesScript.HOLDING, "at the target, waiting for the tick")
	shot["result"] = true
	assert_eq(ProjectilesScript.phase(shot), ProjectilesScript.LANDED, "the hit lands it")


func test_a_miss_drops_past_the_target() -> void:
	var shot := _shot(0.3, 0.2, null)
	_at(shot, 0.5)
	shot["result"] = false
	shot["missed_at"] = 0.5
	assert_eq(ProjectilesScript.phase(shot), ProjectilesScript.HOLDING, "it carries on past them")
	assert_eq(ProjectilesScript.phase(_at(shot, 0.5 + ProjectilesScript.MISS_SECONDS)), ProjectilesScript.DROPPED, "into the snow")


func test_a_shot_no_blow_answers_drops_instead_of_hanging() -> void:
	var shot := _shot(0.3, 0.2, null)
	assert_eq(ProjectilesScript.phase(_at(shot, 0.5 + ProjectilesScript.GRACE)), ProjectilesScript.DROPPED)


func test_every_look_is_there_to_warm_up() -> void:
	var all := ProjectilesScript.samples()
	assert_eq(all.get_child_count(), 8, "an arrow, a shard and each puff each way")
	for node in all.find_children("*", "MeshInstance3D", true, false):
		assert_true((node as MeshInstance3D).mesh != null, "%s has a mesh" % node.name)
	all.free()


func test_every_shot_and_puff_of_a_look_shares_its_resources() -> void:
	# A fresh material per shot let the browser drop its compiled shader between shots, so
	# every arrow froze the game while it compiled again (seconds in Firefox).
	for make in [ProjectilesScript.arrow, ProjectilesScript.shard]:
		var first: Node3D = make.call()
		var second: Node3D = make.call()
		for part in ["Body", "Trail"]:
			var a := first.get_node(part) as MeshInstance3D
			var b := second.get_node(part) as MeshInstance3D
			assert_eq(a.mesh, b.mesh, "%s %s shares its mesh" % [first.name, part])
			assert_eq(a.material_override, b.material_override, "%s %s shares its material" % [first.name, part])
		var body := (first.get_node("Body") as MeshInstance3D).mesh
		var again := (second.get_node("Body") as MeshInstance3D).mesh
		assert_eq(body.surface_get_material(0), again.surface_get_material(0), "%s body shares its material" % first.name)
		first.free()
		second.free()
	for kind in [ProjectilesScript.ARROW, ProjectilesScript.SHARD, ""]:
		for reduced in [false, true]:
			var first := ProjectilesScript.puff(kind, reduced)
			var second := ProjectilesScript.puff(kind, reduced)
			assert_eq(first.mesh, second.mesh, "puff %s %s shares its quad and material" % [kind, reduced])
			assert_eq(first.color_ramp, second.color_ramp, "and its ramp")
			assert_eq(first.scale_amount_curve, second.scale_amount_curve, "and its curve")
			first.free()
			second.free()


func test_a_puff_bursts_once_and_reduced_motion_only_fades() -> void:
	for kind in [ProjectilesScript.ARROW, ProjectilesScript.SHARD, ""]:
		var p := ProjectilesScript.puff(kind, false)
		assert_true(p.one_shot and not p.emitting, "it waits to be thrown once")
		assert_true(p.amount > 1 and p.initial_velocity_max > 0.0, "it bursts")
		p.free()
		var calm := ProjectilesScript.puff(kind, true)
		assert_eq(calm.amount, 1, "one glow")
		assert_eq(calm.initial_velocity_max, 0.0, "that does not move")
		calm.free()


static func _shot(delay: float, seconds: float, result: Variant) -> Dictionary:
	return {"delay": delay, "seconds": seconds, "time": 0.0, "result": result}


static func _at(shot: Dictionary, time: float) -> Dictionary:
	shot["time"] = time
	return shot
