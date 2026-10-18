## The build beat's timing and where it looks, from the pure functions GameRoot drives it
## with: the camera eases onto the piece and back inside the beat, the piece starts under the
## ground and stands in place by the end, and every piece a built upgrade puts in the yard
## has a height to rise from and a puff. How it looks is judged by hand.
extends "res://tests/run.gd".TestCase

const BuildBeatScript := preload("res://scenes/build_beat.gd")
const YardLookScript := preload("res://scenes/yard_look.gd")


func test_the_beat_lasts_about_a_second_and_a_half() -> void:
	assert_true(BuildBeatScript.DURATION >= 1.2 and BuildBeatScript.DURATION <= 1.8, "about 1.5 s")
	assert_true(BuildBeatScript.RISE_TO <= BuildBeatScript.DURATION, "the piece has risen before the beat ends")
	assert_true(BuildBeatScript.CAMERA_IN + BuildBeatScript.CAMERA_OUT < BuildBeatScript.DURATION, "the camera holds on the piece between its eases")


func test_the_camera_eases_onto_the_piece_and_back_to_the_player() -> void:
	assert_eq(BuildBeatScript.camera_weight(0.0), 0.0, "the camera starts on the player")
	assert_almost_eq(BuildBeatScript.camera_weight(BuildBeatScript.DURATION * 0.5), 1.0, 0.0001, "it holds on the piece mid-beat")
	assert_eq(BuildBeatScript.camera_weight(BuildBeatScript.DURATION), 0.0, "it is back on the player when the beat ends")
	assert_eq(BuildBeatScript.camera_weight(BuildBeatScript.DURATION + 1.0), 0.0, "and stays there")
	var last := 0.0
	for i in 11:
		var w := BuildBeatScript.camera_weight(BuildBeatScript.CAMERA_IN * i / 10.0)
		assert_true(w >= last, "the ease in never swings back")
		last = w


func test_the_piece_rises_out_of_the_ground_into_its_place() -> void:
	assert_eq(BuildBeatScript.sink(0.0, 2.0), 2.0, "it starts wholly under the ground")
	assert_eq(BuildBeatScript.sink(BuildBeatScript.RISE_TO, 2.0), 0.0, "it stands in place once risen")
	assert_eq(BuildBeatScript.sink(BuildBeatScript.DURATION, 2.0), 0.0)
	var last := 2.0
	for i in 21:
		var depth := BuildBeatScript.sink(BuildBeatScript.DURATION * i / 20.0, 2.0)
		assert_true(depth <= last, "it only ever rises")
		last = depth


func test_every_yard_piece_has_a_height_a_focus_and_a_puff() -> void:
	for piece in YardLookScript.pieces(UpgradeTable.ids()):
		assert_true(BuildBeatScript.height(piece) > 0.3, "%s stands tall enough to rise" % piece["upgrade"])
		var at: Vector2 = piece["at"]
		assert_eq(BuildBeatScript.focus(piece), Vector3(at.x, 0.0, at.y), "the camera eases onto %s's footprint" % piece["upgrade"])
		var dust := BuildBeatScript.puff(piece)
		assert_true(dust.one_shot and not dust.emitting, "%s's puff waits to be thrown once" % piece["upgrade"])
		assert_true(dust.mesh != null and dust.mesh.surface_get_material(0) != null, "the puff has a look to warm up")
		dust.free()


func test_waystones_have_no_piece_so_no_beat() -> void:
	assert_true(YardLookScript.pieces(["waystone"]).is_empty(), "waystones show only the banner")
