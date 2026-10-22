## The click marker, from the events a click drained: one cross on the ground where the
## simulation sends the character, or one ring under what was clicked with its label up, held
## until arrival or the next click; a refused click flashes red and fades. How it looks is
## judged by hand.
extends "res://tests/run.gd".TestCase

const ClickMarkerScript := preload("res://scenes/click_marker.gd")


func _path_set(to: Array, object_id := "") -> Array[Dictionary]:
	return [{"kind": SimVocab.EV_PATH_SET, "from": [0.0, 0.0], "to": to, "length": 5.0, "object_id": object_id}]


func _rejected(reason: String) -> Array[Dictionary]:
	return [{"kind": SimVocab.EV_COMMAND_REJECTED, "command": SimVocab.MOVE_TO, "reason": reason, "args": {}}]


func _visible_marks(marker: Node) -> int:
	var n := 0
	for child in marker.get_children():
		if (child as Node3D).visible:
			n += 1
	return n


func test_a_ground_click_marks_the_simulations_destination_not_the_ray() -> void:
	var marker := ClickMarkerScript.new()
	marker.mark(_path_set([3.5, 4.5]), Vector3(3.9, 0.0, 5.2))
	assert_eq(marker.showing(), ClickMarkerScript.SHOWING_GROUND)
	assert_almost_eq(marker.point().x, 3.5, 0.0001, "on the snapped point, off the wall")
	assert_almost_eq(marker.point().z, 4.5, 0.0001)
	assert_true(marker.held(), "it holds until arrival")
	marker.advance(30.0)
	assert_eq(marker.showing(), ClickMarkerScript.SHOWING_GROUND, "still there however long the walk")
	marker.clear()
	assert_eq(marker.showing(), ClickMarkerScript.SHOWING_NONE, "arrival clears it")
	assert_eq(_visible_marks(marker), 0)
	marker.free()


func test_the_real_simulation_answers_a_click_with_the_destination() -> void:
	var sim := Sim.new()
	sim.command(SimVocab.NEW_CHARACTER)
	sim.drain_events()
	var here := sim.player_pos()
	sim.command(SimVocab.MOVE_TO, {"pos": [here.x + 2.0, here.y]})
	var marker := ClickMarkerScript.new()
	marker.mark(sim.drain_events(), Vector3(here.x + 2.0, 0.0, here.y))
	assert_eq(marker.showing(), ClickMarkerScript.SHOWING_GROUND)
	var last: Array = sim.state["player"]["path"][-1]
	assert_almost_eq(marker.point().x, float(last[0]), 0.0001, "on the path's last point")
	assert_almost_eq(marker.point().z, float(last[1]), 0.0001)
	marker.free()


func test_an_object_click_rings_it_and_pins_its_label_until_cleared() -> void:
	var marker := ClickMarkerScript.new()
	var label := Label3D.new()
	label.visible = false
	marker.mark(_path_set([1.0, 1.0], "stash"), Vector3(2.0, 0.0, 2.0), 0.5, label)
	assert_eq(marker.showing(), ClickMarkerScript.SHOWING_TARGET)
	assert_almost_eq(marker.point().x, 2.0, 0.0001, "under the object, not where the character stops")
	assert_true(label.visible and label.get_meta("pinned"), "its label stays up")
	marker.advance(30.0)
	assert_eq(marker.showing(), ClickMarkerScript.SHOWING_TARGET, "held until arrival")
	assert_eq(marker.clear(), label, "clearing hands the label back to the hover")
	assert_false(label.visible or label.get_meta("pinned"), "and unpins it")
	label.free()
	marker.free()


func test_only_one_mark_shows_at_a_time() -> void:
	var marker := ClickMarkerScript.new()
	var label := Label3D.new()
	marker.mark(_path_set([1.0, 1.0], "tree_1"), Vector3(2.0, 0.0, 2.0), 0.5, label)
	marker.mark(_path_set([6.0, 1.0]), Vector3(6.0, 0.0, 1.0))
	assert_eq(_visible_marks(marker), 1, "the next click replaces the last")
	assert_eq(marker.showing(), ClickMarkerScript.SHOWING_GROUND)
	assert_false(label.get_meta("pinned"), "the last target's label is let go")
	marker.mark(_path_set([1.0, 1.0], "tree_1"), Vector3(2.0, 0.0, 2.0), 0.5, label)
	assert_eq(_visible_marks(marker), 1)
	label.free()
	marker.free()


func test_a_refused_click_flashes_red_and_fades() -> void:
	var marker := ClickMarkerScript.new()
	marker.mark(_rejected(SimVocab.REASON_UNREACHABLE), Vector3(4.0, 0.0, 4.0))
	assert_eq(marker.showing(), ClickMarkerScript.SHOWING_REJECTED)
	assert_almost_eq(marker.point().x, 4.0, 0.0001, "where the click landed")
	assert_false(marker.held(), "it does not wait for an arrival that will not come")
	marker.advance(ClickMarkerScript.FLASH_SECONDS + 0.01)
	assert_eq(marker.showing(), ClickMarkerScript.SHOWING_NONE, "gone once faded")
	marker.free()


func test_an_enemy_click_only_pops_and_leaves_its_label_to_the_fight() -> void:
	var marker := ClickMarkerScript.new()
	var label := Label3D.new()
	label.visible = false
	marker.mark([], Vector3(5.0, 0.0, 5.0), 0.65, label, true)
	assert_eq(marker.showing(), ClickMarkerScript.SHOWING_TARGET)
	assert_false(marker.held())
	assert_false(label.visible, "the fight pins its own label")
	marker.advance(ClickMarkerScript.FLASH_SECONDS + 0.01)
	assert_eq(marker.showing(), ClickMarkerScript.SHOWING_NONE)
	label.free()
	marker.free()


func test_the_mark_pops_unless_motion_is_reduced() -> void:
	var marker := ClickMarkerScript.new()
	marker.mark(_path_set([1.0, 1.0]), Vector3.ZERO)
	var settled := ClickMarkerScript.CROSS_RADIUS * 2.0
	assert_true(marker.size() > settled * 1.5, "it starts big")
	marker.advance(ClickMarkerScript.POP_SECONDS)
	assert_almost_eq(marker.size(), settled, 0.0001, "and settles")
	marker.reduced_motion = true
	marker.mark(_path_set([1.0, 1.0]), Vector3.ZERO)
	assert_almost_eq(marker.size(), settled, 0.0001, "with reduced motion it appears at its size")
	marker.free()
