## What stands on the ground in each ring, as data: the landmarks the player steers by (one
## per compass direction per ring), the scatter each ring gets (how much of what, scaled by
## the ring look's `density`), the markers at the ring edges, the lakes, and how the ruin
## solids and the enemy packs read. Pure data like the sim: no nodes, no scene, no rendering.
## WorldDressing builds the meshes from it; tests check it against the world definition.
##
## Dressing is presentation only and never blocks: a landmark stands where a path rarely
## runs, and every landmark's foot is reachable by click-to-move (see tests/test_dressing.gd).
class_name RingDressing
extends RefCounted

const DIRECTIONS := ["north", "east", "south", "west"]

## The landmarks: `kind` (a RuinKit piece), `at` [x, z] on the ground, `turn` about the up
## axis and a `size` the piece reads (a length, a radius or a height).
## The inner ring: a fallen pine north, a split rock east, a cairn south by the road, a dead
## giant west. Ring one: a frozen waterfall down the north cliff, a fallen giant pine east
## past the iron, the caravan wreck south on the road to the gate, a ruined watch post west.
## Ring two: a collapsed tower in the gate yard (north), a fallen arch over the east gap in
## the outer wall, a ring of old stones around the waystone in the far ruins (south), a spire
## of ice on the frozen lake (west).
const LANDMARKS := {
	WorldDef.REGION_INNER_RING: {
		"north": {"kind": "fallen_pine", "at": [9.0, -21.5], "turn": 0.35, "size": 7.0},
		"east": {"kind": "split_rock", "at": [22.0, 16.0], "turn": 0.8, "size": 3.0},
		"south": {"kind": "cairn", "at": [-10.5, 22.5], "turn": 0.0, "size": 2.0},
		"west": {"kind": "dead_giant", "at": [-21.5, -9.0], "turn": 0.0, "size": 7.0},
	},
	WorldDef.REGION_RING_ONE: {
		"north": {"kind": "frozen_waterfall", "at": [-20.0, -60.0], "turn": 0.0, "size": 5.0},
		"east": {"kind": "fallen_pine", "at": [51.0, -3.0], "turn": PI * 0.5, "size": 9.0},
		"south": {"kind": "caravan_wreck", "at": [6.5, 45.5], "turn": 0.15, "size": 3.0},
		"west": {"kind": "watch_post", "at": [-54.0, -20.0], "turn": 0.3, "size": 4.0},
	},
	WorldDef.REGION_RING_TWO: {
		"north": {"kind": "tower_base", "at": [-24.0, 66.5], "turn": 0.0, "size": 2.6},
		"east": {"kind": "fallen_arch", "at": [32.0, 78.5], "turn": 0.0, "size": 4.0},
		"south": {"kind": "stone_ring", "at": [0.5, 118.5], "turn": 0.0, "size": 4.8},
		"west": {"kind": "ice_spire", "at": [-55.0, 95.0], "turn": 0.0, "size": 4.5},
	},
}

## The scatter pass, per ring: `what` is a piece WorldDressing knows how to lay down, `count`
## is how many at a density of 1 (the ring look's `density` scales it), `spacing` keeps them
## apart, `scale` is the size range, and `band` (optional) is the reach from the world's
## centre they keep to, so pines stay off the walked routes of a ring.
const SCATTER := {
	WorldDef.REGION_INNER_RING: [
		{"what": "drift", "count": 50, "spacing": 2.5},
		{"what": "rock", "count": 36, "spacing": 1.6, "scale": [0.7, 1.4]},
		{"what": "stone", "count": 24, "spacing": 1.8, "scale": [0.8, 1.5]},
		{"what": "bush", "count": 24, "spacing": 1.6, "scale": [0.8, 1.3]},
		{"what": "log", "count": 18, "spacing": 1.8, "scale": [0.9, 1.3]},
		{"what": "stump", "count": 14, "spacing": 1.8, "scale": [0.9, 1.3]},
		{"what": "pine_small", "count": 16, "spacing": 3.0, "scale": [0.85, 1.15], "band": [15.0, 24.0]},
	],
	WorldDef.REGION_RING_ONE: [
		{"what": "drift", "count": 50, "spacing": 2.5},
		{"what": "rock", "count": 30, "spacing": 1.6, "scale": [0.8, 1.6]},
		{"what": "stone", "count": 14, "spacing": 1.8, "scale": [0.8, 1.6]},
		{"what": "bush", "count": 12, "spacing": 1.6, "scale": [0.8, 1.3]},
		{"what": "log", "count": 16, "spacing": 1.8, "scale": [0.9, 1.3]},
		{"what": "stump", "count": 14, "spacing": 1.8, "scale": [0.9, 1.3]},
		{"what": "dead_tree", "count": 36, "spacing": 3.0, "scale": [0.8, 1.3]},
		{"what": "pine_small", "count": 16, "spacing": 3.0, "scale": [0.85, 1.15], "band": [30.0, 60.0]},
		{"what": "pine_tall", "count": 40, "spacing": 3.0, "scale": [0.85, 1.15], "band": [38.0, 60.0]},
	],
	WorldDef.REGION_RING_TWO: [
		{"what": "drift", "count": 30, "spacing": 2.5},
		{"what": "rubble", "count": 34, "spacing": 2.2, "scale": [0.8, 1.4]},
		{"what": "ice_shard", "count": 30, "spacing": 2.4, "scale": [0.7, 1.5]},
		{"what": "stone", "count": 18, "spacing": 1.8, "scale": [0.8, 1.6]},
		{"what": "dead_tree", "count": 16, "spacing": 3.0, "scale": [0.8, 1.3]},
	],
}

## Ring edges carry markers so a player knows they have crossed without a label. The safe
## ring's edge is lined with rough standing stones every `BOUNDARY_SPACING` metres, with two
## pennant posts where the road south crosses it; the gate to ring two is flanked, on the
## far side, by two carved stones in the ruins' own hand.
const BOUNDARY_SPACING := 6.0
const ROAD_POSTS := [[-2.6, 24.0], [2.6, 24.0]]
const GATE_STONES := [[-3.4, 65.5], [3.4, 65.5]]

## Frozen lakes: a sheet of ice laid under the holes in it.
const LAKES := {
	WorldDef.REGION_RING_TWO: [{"at": [-46.0, 95.0], "radius": 13.0}],
}

## The mines, per ring: the ore kinds whose veins streak the pieces, and the pieces that make
## the rocks read as a mine from a distance. Each piece has a `kind`, the ground it covers
## (`at` [x, z] and `half` [x, z] extents, which the scatter pass keeps clear like a
## landmark's) and a `turn`. Ring one's mine stands against the west cliff north of the watch
## post: a rock face with a boarded-up adit on the cliff behind the rocks, ore-streaked
## boulders north and east of them and spoil heaps either side of witch 2. Every piece stands
## clear of every rock, so a rock is never hidden and the walk in stays open.
const MINES := {
	WorldDef.REGION_RING_ONE: {
		"ores": [WorldDef.KIND_COPPER_ROCK, WorldDef.KIND_TIN_ROCK],
		"pieces": [
			{"kind": "mine_face", "at": [-62.15, -32.5], "half": [1.8, 6.0], "turn": 0.0},
			{"kind": "ore_boulder", "at": [-57.5, -38.6], "half": [1.3, 1.3], "turn": 0.4},
			{"kind": "ore_boulder", "at": [-52.5, -38.0], "half": [1.0, 1.0], "turn": 1.7},
			{"kind": "ore_boulder", "at": [-47.5, -35.0], "half": [1.1, 1.1], "turn": 2.9},
			{"kind": "spoil_heap", "at": [-48.4, -31.0], "half": [1.2, 1.0], "turn": 0.3},
			{"kind": "spoil_heap", "at": [-58.7, -25.5], "half": [1.2, 1.0], "turn": 1.2},
		],
	},
}

## The enemy kinds whose homes get a camp, and what kind of camp.
const CAMP_KINDS := {"wolf": "wolf_den", "bandit_archer": "bandit_camp"}


## The rings that get dressing, innermost first (the outpost is dressed by hand).
static func rings() -> Array[String]:
	return [WorldDef.REGION_INNER_RING, WorldDef.REGION_RING_ONE, WorldDef.REGION_RING_TWO]


## The landmark at `ring`/`direction`.
static func landmark(ring: String, direction: String) -> Dictionary:
	return LANDMARKS[ring][direction]


## Every mine piece in every ring, each with its ring's ores beside it as `ores`.
static func mine_pieces() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ring in MINES:
		for piece in MINES[ring]["pieces"]:
			var p: Dictionary = piece.duplicate()
			p["ores"] = MINES[ring]["ores"]
			out.append(p)
	return out


## The ground a mine piece covers, as [min, max] corners.
static func piece_ground(piece: Dictionary) -> Array[Vector2]:
	var at := Vector2(piece["at"][0], piece["at"][1])
	var half := Vector2(piece["half"][0], piece["half"][1])
	return [at - half, at + half]


## How many of a scatter entry the ring gets at the look's density.
static func scaled_count(entry: Dictionary, density: float) -> int:
	return int(round(int(entry["count"]) * density))


## Which kit piece dresses a ruin solid: a pillar when the footprint is small both ways,
## otherwise a broken wall.
static func ruin_piece(solid: Dictionary) -> String:
	var w: float = solid["max"][0] - solid["min"][0]
	var d: float = solid["max"][1] - solid["min"][1]
	return "pillar" if w <= 2.0 and d <= 2.0 else "wall"


## The camps the enemy placements imply: one per pack of wolves (a den) or bandit archers (a
## camp), at the pack's centre, with how many live there. Trolls, stalkers, witches and the
## captain keep no camp.
static func camps(world: WorldDef) -> Array[Dictionary]:
	var packs := {}
	for id in world.enemies:
		var e: Dictionary = world.enemies[id]
		if not CAMP_KINDS.has(e["kind"]):
			continue
		var pack: String = e["pack"]
		if not packs.has(pack):
			packs[pack] = {"kind": CAMP_KINDS[e["kind"]], "pack": pack, "homes": []}
		(packs[pack]["homes"] as Array).append(Vector2(e["home"][0], e["home"][1]))
	var out: Array[Dictionary] = []
	for pack in packs:
		var homes: Array = packs[pack]["homes"]
		var centre := Vector2.ZERO
		for h in homes:
			centre += h
		centre /= homes.size()
		out.append({"kind": packs[pack]["kind"], "pack": pack, "at": centre, "size": homes.size()})
	return out


## The centre of a ring's region, for telling its compass directions apart.
static func ring_centre(world: WorldDef, ring: String) -> Vector2:
	for r in world.regions:
		if r["name"] == ring:
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for p in r["polygon"]:
				lo = lo.min(Vector2(p[0], p[1]))
				hi = hi.max(Vector2(p[0], p[1]))
			if ring == WorldDef.REGION_RING_TWO:
				# Ring two's polygon is the whole world; its walkable ruins lie south of the cliffs.
				return Vector2(0.0, 94.0)
			return (lo + hi) * 0.5
	return Vector2.ZERO


## The compass direction of `pos` from `centre`.
static func direction_of(centre: Vector2, pos: Vector2) -> String:
	var d := pos - centre
	if absf(d.x) > absf(d.y):
		return "east" if d.x > 0.0 else "west"
	return "south" if d.y > 0.0 else "north"
