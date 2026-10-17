## The ring-look table: one look per ring and for the outpost, colder and darker the farther
## out, blended across a fixed band at every boundary so nothing jumps.
extends "res://tests/run.gd".TestCase

const WorldDefScript := preload("res://sim/world_def.gd")
const RingLookScript := preload("res://scenes/ring_look.gd")

## A point deep inside each ring: farther than the blend band from any boundary.
const DEEP := {
	WorldDef.REGION_OUTPOST: Vector2(0.5, 0.5),
	WorldDef.REGION_INNER_RING: Vector2(0.5, 17.0),
	WorldDef.REGION_RING_ONE: Vector2(0.5, 42.0),
	WorldDef.REGION_RING_TWO: Vector2(0.5, 100.0),
}


func test_every_ring_and_the_outpost_has_a_complete_look() -> void:
	var w := WorldDefScript.outpost()
	var rings := RingLookScript.rings(w)
	assert_eq(rings, [WorldDef.REGION_OUTPOST, WorldDef.REGION_INNER_RING, WorldDef.REGION_RING_ONE, WorldDef.REGION_RING_TWO])
	for ring in rings:
		var look := RingLookScript.entry(ring)
		for field in RingLookScript.FIELDS:
			assert_true(look.has(field), "%s has %s" % [ring, field])
		assert_eq(look.keys().size(), RingLookScript.FIELDS.size(), "%s carries only the known fields" % ring)
		assert_true(look["ambience"] is String and look["ambience"] != "", "%s names an ambience cue" % ring)
		for field in ["fog_distance", "snow_density", "wind", "aurora", "sun_energy", "ambient_energy"]:
			assert_true(look[field] is float, "%s.%s is a number" % [ring, field])
		for field in ["tint", "sky", "fog_color", "sun_color", "ambient_color"]:
			assert_true(look[field] is Color, "%s.%s is a colour" % [ring, field])
		assert_true(look["wind_direction"] is Vector2, "%s.wind_direction is a vector" % ring)
		assert_almost_eq((look["wind_direction"] as Vector2).length(), 1.0, 0.02, "%s.wind_direction is a heading" % ring)


func test_looks_get_colder_and_darker_outward() -> void:
	var w := WorldDefScript.outpost()
	var rings := RingLookScript.rings(w)
	for i in range(1, rings.size()):
		var inner := RingLookScript.entry(rings[i - 1])
		var outer := RingLookScript.entry(rings[i])
		assert_true(RingLookScript.brightness(outer) < RingLookScript.brightness(inner), "%s is darker than %s" % [rings[i], rings[i - 1]])
		assert_true(RingLookScript.warmth(outer) < RingLookScript.warmth(inner), "%s is colder than %s" % [rings[i], rings[i - 1]])
		assert_true(float(outer["snow_density"]) > float(inner["snow_density"]), "snow thickens into %s" % rings[i])
		assert_true(float(outer["fog_distance"]) < float(inner["fog_distance"]), "fog closes in into %s" % rings[i])
		assert_true(float(outer["wind"]) >= float(inner["wind"]), "the wind does not drop into %s" % rings[i])
	assert_eq(float(RingLookScript.entry(WorldDef.REGION_OUTPOST)["aurora"]), 0.0, "no aurora over the outpost")
	assert_true(float(RingLookScript.entry(WorldDef.REGION_RING_TWO)["aurora"]) > float(RingLookScript.entry(WorldDef.REGION_INNER_RING)["aurora"]), "the aurora hangs over the outer rings")


func test_deep_inside_a_ring_the_look_is_the_entry() -> void:
	var w := WorldDefScript.outpost()
	for ring in DEEP:
		assert_eq(w.region_at(DEEP[ring]), ring, "%s is deep in its ring" % [DEEP[ring]])
		var look := RingLookScript.at(w, DEEP[ring])
		assert_eq(look, RingLookScript.entry(ring), "the look deep in the %s is its entry" % ring)


func test_the_look_blends_across_every_boundary() -> void:
	var w := WorldDefScript.outpost()
	# Southward from the fire: the outpost wall at 10 m, the stakes at 24 m, the cliffs at 60 m.
	var crossings := [
		[10.0, WorldDef.REGION_OUTPOST, WorldDef.REGION_INNER_RING],
		[24.0, WorldDef.REGION_INNER_RING, WorldDef.REGION_RING_ONE],
		[60.0, WorldDef.REGION_RING_ONE, WorldDef.REGION_RING_TWO],
	]
	for c in crossings:
		var edge: float = c[0]
		var inside := Vector2(0.5, edge - 0.1)
		var outside := Vector2(0.5, edge + 0.1)
		assert_eq(w.region_at(inside), c[1])
		assert_eq(w.region_at(outside), c[2])
		var a := RingLookScript.at(w, inside)
		var b := RingLookScript.at(w, outside)
		assert_true(RingLookScript.distance(a, b) < 0.05, "no jump between %s and %s (%.3f)" % [c[1], c[2], RingLookScript.distance(a, b)])
		var far_in := RingLookScript.at(w, Vector2(0.5, edge - RingLookScript.BLEND_METRES))
		var far_out := RingLookScript.at(w, Vector2(0.5, edge + RingLookScript.BLEND_METRES))
		assert_eq(far_in, RingLookScript.entry(c[1]), "a band inside the %s boundary is the %s entry" % [c[1], c[1]])
		assert_eq(far_out, RingLookScript.entry(c[2]), "a band past the %s boundary is the %s entry" % [c[1], c[2]])
		# On the boundary itself the look is halfway between the two entries.
		var mid := RingLookScript.at(w, Vector2(0.5, edge))
		var halfway := RingLookScript.blend(RingLookScript.entry(c[1]), RingLookScript.entry(c[2]), 0.5)
		assert_true(RingLookScript.distance(mid, halfway) < 0.01, "halfway across the %s boundary" % c[1])


func test_the_look_never_jumps_on_the_walk_out() -> void:
	var w := WorldDefScript.outpost()
	var previous := RingLookScript.at(w, Vector2(0.5, 0.5))
	var z := 0.5
	while z < 120.0:
		z += 0.25
		var look := RingLookScript.at(w, Vector2(0.5, z))
		assert_true(RingLookScript.distance(previous, look) < 0.08, "a quarter metre at z=%.2f changes the look by %.3f" % [z, RingLookScript.distance(previous, look)])
		previous = look


func test_past_the_last_ring_the_last_look_holds() -> void:
	var w := WorldDefScript.outpost()
	var beyond := Vector2(100.0, 100.0)
	assert_eq(w.region_at(beyond), "", "past every region")
	assert_eq(RingLookScript.at(w, beyond), RingLookScript.entry(WorldDef.REGION_RING_TWO))
	assert_eq(RingLookScript.at(w, Vector2(0.5, 500.0)), RingLookScript.entry(WorldDef.REGION_RING_TWO))


func test_blend_lerps_numbers_and_colours_and_picks_the_nearer_cue() -> void:
	var a := RingLookScript.entry(WorldDef.REGION_OUTPOST)
	var b := RingLookScript.entry(WorldDef.REGION_RING_TWO)
	assert_eq(RingLookScript.blend(a, b, 0.0), a)
	assert_eq(RingLookScript.blend(a, b, 1.0), b)
	var mid := RingLookScript.blend(a, b, 0.5)
	assert_almost_eq(float(mid["fog_distance"]), (float(a["fog_distance"]) + float(b["fog_distance"])) * 0.5)
	assert_almost_eq(float(mid["snow_density"]), (float(a["snow_density"]) + float(b["snow_density"])) * 0.5)
	assert_true((mid["wind_direction"] as Vector2).is_equal_approx((a["wind_direction"] as Vector2).lerp(b["wind_direction"], 0.5)), "the wind turns across the band")
	assert_true((mid["tint"] as Color).is_equal_approx((a["tint"] as Color).lerp(b["tint"], 0.5)))
	assert_eq(RingLookScript.blend(a, b, 0.49)["ambience"], a["ambience"])
	assert_eq(RingLookScript.blend(a, b, 0.51)["ambience"], b["ambience"])
	assert_eq(RingLookScript.distance(a, a), 0.0)
	assert_true(RingLookScript.distance(a, b) > 0.5, "the outpost and ring two look nothing alike")
