## What the world looks like at a point: one look per ring and one for the outpost, in a
## table every visual system reads (lighting, fog, snowfall, dressing) so none keeps per-ring
## constants of its own. Pure data, like the sim: no nodes, no scene, no rendering.
##
## A look is a Dictionary with every field in FIELDS. `at(world, pos)` resolves the ring
## through the world definition's region lookup and blends the two looks across a fixed
## band at every boundary, so nothing jumps as the player walks out. Each ring out is
## colder and darker than the one inside it: the look is the danger signal. Out to ring two
## the snow, the wind and the fog thicken too; ring three's glacier breaks that, a clear night
## under the full aurora, so it reads as a place apart and not as more blizzard. A dungeon
## has a look of its own, darker and closer than the ring it opens from, which blends with
## that ring's only across its mouth.
##
## The world definition names the rings "regions"; new code says ring.
class_name RingLook
extends RefCounted

## The band, centred on a ring boundary, across which two looks blend.
const BLEND_METRES := 8.0

## Every look carries exactly these fields.
##   tint            Color  palette tint for the snow and the colour grade
##   sky             Color  the sky (the clear colour behind the fog)
##   fog_color       Color  the fog
##   fog_distance    float  metres past the character before the fog closes in
##   sun_color       Color  the dusk sun
##   sun_energy      float
##   ambient_color   Color  the sky's light in the shadows (blue-violet)
##   ambient_energy  float
##   snow_density    float  0 (none) to 1 (the blizzard)
##   wind            float  0 (still) to 1 (the blizzard's wind)
##   wind_direction  Vector2 where the wind blows to, on the ground plane (x east, y south)
##   aurora          float  0 (none) to 1 (full) in the sky
##   ambience        String the ambience cue for the ring
##   snow_tone       Color  the ground's snow, painted by position so the tone steps at a
##                          ring edge (the tint above follows the character and blends)
##   stone           Color  the ring's stone: its standing stones, cairns and ruins
##   foliage         Color  the ring's needles and bushes, greener in than out
##   density         float  0 (bare) to 1 (the most cluttered ring): how much dressing
##                          the scatter pass lays down
##   drift           float  0 (flat) to 1 (deep): how high the snow drifts lie
const FIELDS := [
	"tint", "sky", "fog_color", "fog_distance", "sun_color", "sun_energy",
	"ambient_color", "ambient_energy", "snow_density", "wind", "wind_direction", "aurora",
	"ambience", "snow_tone", "stone", "foliage", "density", "drift",
]

## The looks, by region name.
const LOOKS := {
	WorldDef.REGION_OUTPOST: {
		"tint": Color(1.00, 0.95, 0.88), "sky": Color(0.36, 0.30, 0.44),
		"fog_color": Color(0.54, 0.46, 0.60), "fog_distance": 80.0,
		"sun_color": Color(1.00, 0.80, 0.60), "sun_energy": 1.05,
		"ambient_color": Color(0.52, 0.47, 0.70), "ambient_energy": 0.55,
		"snow_density": 0.12, "wind": 0.1, "wind_direction": Vector2(0.98, 0.2), "aurora": 0.0, "ambience": "hearth",
		"snow_tone": Color(1.00, 0.95, 0.88), "stone": Color(0.58, 0.54, 0.52),
		"foliage": Color(0.38, 0.54, 0.42), "density": 0.3, "drift": 0.2,
	},
	WorldDef.REGION_INNER_RING: {
		"tint": Color(0.93, 0.94, 1.00), "sky": Color(0.29, 0.29, 0.46),
		"fog_color": Color(0.56, 0.57, 0.74), "fog_distance": 64.0,
		"sun_color": Color(1.00, 0.76, 0.58), "sun_energy": 0.95,
		"ambient_color": Color(0.46, 0.45, 0.72), "ambient_energy": 0.58,
		"snow_density": 0.25, "wind": 0.25, "wind_direction": Vector2(0.96, 0.28), "aurora": 0.2, "ambience": "calm",
		"snow_tone": Color(0.95, 0.96, 1.00), "stone": Color(0.58, 0.61, 0.70),
		"foliage": Color(0.40, 0.56, 0.48), "density": 0.45, "drift": 0.3,
	},
	WorldDef.REGION_RING_ONE: {
		"tint": Color(0.82, 0.86, 0.97), "sky": Color(0.21, 0.24, 0.40),
		"fog_color": Color(0.44, 0.49, 0.66), "fog_distance": 46.0,
		"sun_color": Color(0.96, 0.70, 0.56), "sun_energy": 0.8,
		"ambient_color": Color(0.38, 0.42, 0.70), "ambient_energy": 0.6,
		"snow_density": 0.6, "wind": 0.6, "wind_direction": Vector2(0.9, 0.44), "aurora": 0.6, "ambience": "wind",
		"snow_tone": Color(0.80, 0.85, 0.97), "stone": Color(0.46, 0.50, 0.62),
		"foliage": Color(0.30, 0.44, 0.44), "density": 0.8, "drift": 0.7,
	},
	WorldDef.REGION_RING_TWO: {
		"tint": Color(0.60, 0.63, 0.78), "sky": Color(0.07, 0.08, 0.16),
		"fog_color": Color(0.20, 0.22, 0.34), "fog_distance": 30.0,
		"sun_color": Color(0.80, 0.60, 0.58), "sun_energy": 0.5,
		"ambient_color": Color(0.28, 0.30, 0.50), "ambient_energy": 0.56,
		"snow_density": 1.0, "wind": 1.0, "wind_direction": Vector2(0.78, 0.63), "aurora": 1.0, "ambience": "blizzard",
		"snow_tone": Color(0.56, 0.60, 0.78), "stone": Color(0.34, 0.37, 0.50),
		"foliage": Color(0.22, 0.28, 0.36), "density": 1.0, "drift": 1.0,
	},
	# The glacier under the aurora: blue-white ice under a violet sky, lit green by the aurora
	# rather than the sun, the snow thinned so the sky shows. Bare: ice shards and drifts, few
	# stones, nothing growing.
	WorldDef.REGION_RING_THREE: {
		"tint": Color(0.56, 0.66, 0.84), "sky": Color(0.11, 0.07, 0.21),
		"fog_color": Color(0.16, 0.24, 0.34), "fog_distance": 36.0,
		"sun_color": Color(0.55, 0.80, 0.80), "sun_energy": 0.32,
		"ambient_color": Color(0.34, 0.30, 0.58), "ambient_energy": 0.6,
		"snow_density": 0.45, "wind": 0.7, "wind_direction": Vector2(0.6, 0.8), "aurora": 1.0, "ambience": "glacier",
		"snow_tone": Color(0.70, 0.84, 0.98), "stone": Color(0.40, 0.48, 0.62),
		"foliage": Color(0.20, 0.30, 0.34), "density": 0.6, "drift": 0.5,
	},
	# The ring-one dungeon: a cave under the cliffs, darker and closer than ring one. No sky
	# shows, so there is no aurora and almost no snow or wind; what light there is comes cold
	# off the rock, and the fog closes in a few strides past the character.
	WorldDef.REGION_RING_ONE_DUNGEON: {
		"tint": Color(0.50, 0.52, 0.64), "sky": Color(0.03, 0.03, 0.06),
		"fog_color": Color(0.08, 0.09, 0.14), "fog_distance": 22.0,
		"sun_color": Color(0.60, 0.56, 0.62), "sun_energy": 0.3,
		"ambient_color": Color(0.22, 0.23, 0.36), "ambient_energy": 0.48,
		"snow_density": 0.04, "wind": 0.08, "wind_direction": Vector2(0.9, 0.44), "aurora": 0.0, "ambience": "cave",
		"snow_tone": Color(0.50, 0.53, 0.64), "stone": Color(0.30, 0.31, 0.38),
		"foliage": Color(0.18, 0.22, 0.26), "density": 0.5, "drift": 0.15,
	},
}


## The rings in the world definition's order, innermost first (the outpost, then outward).
## Dungeons are not rings: they sit beside their ring rather than around it.
static func rings(world: WorldDef) -> Array[String]:
	var out: Array[String] = []
	for r in ring_regions(world):
		out.append(r["name"])
	return out


## The world definition's regions without the dungeons', in its order.
static func ring_regions(world: WorldDef) -> Array:
	return world.regions.filter(func(r: Dictionary) -> bool: return WorldDef.dungeon_of_region(r["name"]) == "")


## The table's look for `ring`, as a fresh copy.
static func entry(ring: String) -> Dictionary:
	assert(LOOKS.has(ring), "no look for ring %s" % ring)
	return (LOOKS[ring] as Dictionary).duplicate()


## The look at `pos`: the ring's entry, blended with the neighbouring ring's across the
## band at a boundary, or a dungeon's entry, blended with its ring's across its mouth. Past
## the last ring's edge the last look holds.
static func at(world: WorldDef, pos: Vector2) -> Dictionary:
	for id in WorldDef.DUNGEONS:
		var dungeon: Dictionary = WorldDef.DUNGEONS[id]
		if world.objects.has(dungeon["mouth"]):
			var t := _mouth_blend(world, dungeon, pos)
			if t > 0.0:
				return blend(_ring_at(world, _ring_side(world, dungeon["mouth"], pos)), entry(dungeon["region"]), t)
	return _ring_at(world, pos)


## How far into a dungeon's look `pos` is, 0 (none of it) to 1 (all of it). Its walls part it
## from the rings everywhere but the mouth, so the band is centred on the mouth: half a mouth
## (t = 0.5) on the mouth itself, all the ring's half a band out from it and all the
## dungeon's half a band in.
static func _mouth_blend(world: WorldDef, dungeon: Dictionary, pos: Vector2) -> float:
	var half := BLEND_METRES * 0.5
	var off := world.distance_to_object(dungeon["mouth"], pos)
	if world.region_at(pos) == dungeon["region"]:
		return 1.0 if off >= half else 0.5 + 0.5 * off / half
	return 0.0 if off >= half else 0.5 - 0.5 * off / half


## Where to read the ring's half of a blend across a mouth: `pos` itself on the ring's side of
## the mouth's middle, its mirror through the middle on the dungeon's (a mouth's `outward`
## points into its dungeon), so the ring's half never reads the dungeon's ground.
static func _ring_side(world: WorldDef, mouth: String, pos: Vector2) -> Vector2:
	var o: Dictionary = world.objects[mouth]
	var outward := Vector2(o["outward"][0], o["outward"][1])
	var past := (pos - world.object_center(mouth)).dot(outward)
	return pos - outward * 2.0 * past if past > 0.0 else pos


## The ring look at `pos`, as if there were no dungeons.
##
## A ring's polygon holds the rings inside it, so the next ring out starts at this ring's
## edge; ring three's lies beside ring two's instead, so it starts at its own. The gap to the
## next ring is whichever of the two is farther.
static func _ring_at(world: WorldDef, pos: Vector2) -> Dictionary:
	var regions := ring_regions(world)
	var names := rings(world)
	var depth: Array[float] = []  # signed distance to each ring's polygon: negative inside
	var index := -1
	for i in names.size():
		depth.append(_signed_distance(_polygon(regions[i]), pos))
		if index < 0 and depth[i] <= 0.0:
			index = i
	if index < 0:
		return entry(names.back())
	var half := BLEND_METRES * 0.5
	var gap := maxf(-depth[index], depth[index + 1]) if index + 1 < names.size() else INF
	if gap < half:
		return blend(entry(names[index]), entry(names[index + 1]), (half - gap) / BLEND_METRES)
	if index > 0 and depth[index - 1] < half:
		return blend(entry(names[index - 1]), entry(names[index]), (depth[index - 1] + half) / BLEND_METRES)
	return entry(names[index])


## `a` at t = 0 through `b` at t = 1: colours, vectors and numbers interpolate, the cue is
## the nearer.
static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	if t <= 0.0:
		return a.duplicate()
	if t >= 1.0:
		return b.duplicate()
	var out := {}
	for field in FIELDS:
		var x: Variant = a[field]
		var y: Variant = b[field]
		if x is Color:
			out[field] = (x as Color).lerp(y, t)
		elif x is Vector2:
			out[field] = (x as Vector2).lerp(y, t)
		elif x is float:
			out[field] = lerpf(x, y, t)
		else:
			out[field] = x if t < 0.5 else y
	return out


## How far apart two looks are, 0 for the same look and about 1 for opposite colours; the
## cue does not count. Fog distance is measured per hundred metres.
static func distance(a: Dictionary, b: Dictionary) -> float:
	var worst := 0.0
	for field in FIELDS:
		var x: Variant = a[field]
		var y: Variant = b[field]
		if x is Color:
			var c := x as Color
			var d := y as Color
			worst = maxf(worst, maxf(maxf(absf(c.r - d.r), absf(c.g - d.g)), absf(c.b - d.b)))
		elif x is Vector2:
			worst = maxf(worst, (x as Vector2).distance_to(y))
		elif x is float:
			var scale := 100.0 if field == "fog_distance" else 1.0
			worst = maxf(worst, absf(x - y) / scale)
	return worst


## How bright a look is: the tint's luminance times the light the sun and the sky give.
static func brightness(look: Dictionary) -> float:
	var lit := _luminance(look["sun_color"]) * float(look["sun_energy"]) + _luminance(look["ambient_color"]) * float(look["ambient_energy"])
	return _luminance(look["tint"]) * lit


## How warm a look is: red over blue, across the tint, the sun, the shadows and the fog.
static func warmth(look: Dictionary) -> float:
	var total := 0.0
	for field in ["tint", "sun_color", "ambient_color", "fog_color"]:
		var c := look[field] as Color
		total += c.r - c.b
	return total / 4.0


static func _luminance(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


static func _polygon(region: Dictionary) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for p in region["polygon"]:
		poly.append(Vector2(p[0], p[1]))
	return poly


## Distance from `pos` to the polygon's edge, negative inside it.
static func _signed_distance(poly: PackedVector2Array, pos: Vector2) -> float:
	var nearest := INF
	for i in poly.size():
		var on_edge := Geometry2D.get_closest_point_to_segment(pos, poly[i], poly[(i + 1) % poly.size()])
		nearest = minf(nearest, on_edge.distance_to(pos))
	return -nearest if Geometry2D.is_point_in_polygon(pos, poly) else nearest
