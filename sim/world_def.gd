## The world as data: a walkability grid, named regions and typed object placements.
##
## A WorldDef is static authoring data. The simulation reads it for path-finding and region
## lookups; the presentation reads the same solids and objects to draw the grey-box world,
## so the two can never disagree about where a wall is. It has no Godot scene dependency.
##
## Coordinates are ground-plane metres as `[x, z]` arrays (plain data, JSON-safe). The grid
## has `cols` x `rows` square cells of `cell_size`, with cell (0, 0) at `origin`; cell
## centres therefore sit at origin + (i + 0.5) * cell_size.
class_name WorldDef
extends RefCounted

const KIND_WALL := "wall"
const KIND_CLIFF := "cliff"
const KIND_OUTCROP := "outcrop"
const KIND_DECOR := "decor"
const KIND_RUIN := "ruin"
const KIND_RIDGE := "ridge"
const KIND_GATE := "gate"
const KIND_FIRE := "fire"
const KIND_STASH := "stash"
const KIND_WORKBENCH := "workbench"
const KIND_TREE := "tree"
const KIND_FROST_PINE := "frost_pine"
const KIND_COPPER_ROCK := "copper_rock"
const KIND_TIN_ROCK := "tin_rock"
const KIND_IRON_ROCK := "iron_rock"
const KIND_ICE_CRYSTAL := "ice_crystal"
const KIND_FISHING_HOLE := "fishing_hole"
const KIND_ICE_HOLE := "ice_hole"
const KIND_COAL_ROCK := "coal_rock"
const KIND_RICH_IRON_ROCK := "rich_iron_rock"
const KIND_DEEP_HOLE := "deep_hole"
const KIND_RING_GATE := "ring_gate"
const KIND_WAYSTONE := "waystone"
const KIND_WAY_OUT := "way_out"

const REGION_OUTPOST := "outpost"
const REGION_INNER_RING := "inner_ring"
const REGION_RING_ONE := "ring_one"
const REGION_RING_TWO := "ring_two"
const REGION_RING_THREE := "ring_three"
const REGION_RING_ONE_DUNGEON := "ring_one_dungeon"

## A gentle dungeon has a fire and a death chest just inside its mouth; a deep one has neither.
const DUNGEON_GENTLE := "gentle"
const DUNGEON_DEEP := "deep"

## Where ring two ends and ring three begins: the outside of ring two's southern cliffs.
const RING_TWO_FAR := 128.0
## The middle of the gate to ring three, along ring two's southern cliff.
const RING_THREE_GATE_X := -40.0
## Where the rings end eastward: the outside of their eastern cliffs. The dungeons lie past it.
const RINGS_EAST := 64.0
## The middle of the ring-one dungeon's mouth, along ring one's east cliff.
const RING_ONE_DUNGEON_MOUTH_Z := -47.0

## The dungeons, by id (ADR 0001, *Dungeons share the world grid*): each a pocket of the grid
## east of the rings, fenced off by cliffs and reached only through its mouth. The sim reads
## only this table, never per-dungeon constants. Each entry names:
##   label     what the presentation calls it
##   ring      the ring its mouth opens from
##   depth     DUNGEON_GENTLE or DUNGEON_DEEP
##   region    its region, ahead of the rings in `regions`; the sim gives it a band of its own
##   mouth     its mouth: a ring gate with no upgrade and no guardian, so always open, whose
##             `outward` points into the dungeon
##   reserved  where the pieces still to come will stand, as [x, z] spots, so they are placed
##             without colliding: `fire` and `chest` just inside the mouth, `fights` the lane
##             of fight spots from the mouth to the boss (each more than a fight's noise and
##             every ring-one sight from the next and from the fire), `nodes` two spots that
##             are only reached past a fight, `boss_room` [min, max] at the far end with the
##             `boss` spot in it, and `way_out` in the boss room.
##   boss      the enemy id of its boss, placed at the `boss` spot
##   way_out   the object id of its way out, at the `way_out` spot: shut while the boss stands,
##             open from its fall until it comes back
##   set_down  where the way out sets the player down, as [x, z]: ring-one ground on the
##             outpost side of the dungeon, outside the outpost and short of every ring gate
## The fire (gentle only: the id of an ordinary fire object) and the death chest join the entry
## itself as they are built.
##
## The ring-one dungeon runs from the mouth in ring one's east cliff (x 60 to 64) to the cliffs
## at x 108, and from z -60 to 60. Three cave walls part it into four legs: east along the
## first, back west along the second, east along the third, and west along the fourth to the
## boss room in its west end.
const DUNGEONS := {
	"ring_one_dungeon": {
		"label": "The ring-one dungeon", "ring": REGION_RING_ONE, "depth": DUNGEON_GENTLE,
		"region": REGION_RING_ONE_DUNGEON, "mouth": "ring_one_dungeon_mouth",
		"fire": "ring_one_dungeon_fire",
		"reserved": {
			"fire": [69.0, -42.0], "chest": [69.0, -53.0],
			"fights": [[96.0, -38.0], [80.0, -26.0], [90.0, 10.0], [92.0, 40.0]],
			"nodes": [[68.0, -24.0], [104.0, 17.0]],
			"boss_room": [[64.0, 24.0], [84.0, 60.0]], "boss": [73.0, 44.0], "way_out": [66.5, 57.5],
		},
		"boss": "ring_one_dungeon_boss", "way_out": "ring_one_dungeon_way_out", "set_down": [44.5, -44.5],
	},
}

var cell_size := 1.0
var cols := 176
var rows := 256
var origin: Array = [-64.0, -64.0]
var spawn: Array = [0.5, 4.5]
## Where a player wakes after dying: beside the outpost fire.
var rescue: Array = [0.5, 1.5]

## Gatherable node kinds: the skill they train and the level it needs, the tool they need (and
## the lowest tool tier that works, "" for any), what one success yields, how many yields a
## node holds before it is depleted, the ticks until it regrows, and the experience per
## success. `tier` 1 nodes are the inner ring's, and ring one's mine; `tier` 2 nodes grow in
## ring one, need more skill and pay more; `tier` 3 nodes lie in ring two's ruins and pay more
## again. Placed objects of these kinds get a matching entry in the state.
const NODE_KINDS := {
	KIND_TREE: {
		"tier": 1, "skill": "woodcutting", "level": 1, "tool": "axe", "tool_tier": "", "item": "logs",
		"yield": 4, "respawn_ticks": 90, "xp": 10,
	},
	KIND_COPPER_ROCK: {
		"tier": 1, "skill": "mining", "level": 1, "tool": "pickaxe", "tool_tier": "", "item": "copper_ore",
		"yield": 4, "respawn_ticks": 100, "xp": 10,
	},
	KIND_TIN_ROCK: {
		"tier": 1, "skill": "mining", "level": 1, "tool": "pickaxe", "tool_tier": "", "item": "tin_ore",
		"yield": 4, "respawn_ticks": 100, "xp": 10,
	},
	KIND_FISHING_HOLE: {
		"tier": 1, "skill": "fishing", "level": 1, "tool": "rod", "tool_tier": "", "item": "raw_fish",
		"yield": 6, "respawn_ticks": 80, "xp": 10,
	},
	# Mined for the frost shards a staff casts with, once mining is past its first level.
	KIND_ICE_CRYSTAL: {
		"tier": 1, "skill": "mining", "level": 2, "tool": "pickaxe", "tool_tier": "", "item": "ice_crystal",
		"yield": 3, "respawn_ticks": 120, "xp": 14,
	},
	KIND_FROST_PINE: {
		"tier": 2, "skill": "woodcutting", "level": 3, "tool": "axe", "tool_tier": "", "item": "logs",
		"yield": 6, "respawn_ticks": 120, "xp": 16,
	},
	KIND_IRON_ROCK: {
		"tier": 2, "skill": "mining", "level": 3, "tool": "pickaxe", "tool_tier": "bronze", "item": "iron_ore",
		"yield": 3, "respawn_ticks": 150, "xp": 18,
	},
	KIND_ICE_HOLE: {
		"tier": 2, "skill": "fishing", "level": 3, "tool": "rod", "tool_tier": "", "item": "raw_trout",
		"yield": 5, "respawn_ticks": 120, "xp": 16,
	},
	KIND_COAL_ROCK: {
		"tier": 3, "skill": "mining", "level": 5, "tool": "pickaxe", "tool_tier": "bronze", "item": "coal",
		"yield": 4, "respawn_ticks": 150, "xp": 22,
	},
	KIND_RICH_IRON_ROCK: {
		"tier": 3, "skill": "mining", "level": 6, "tool": "pickaxe", "tool_tier": "bronze", "item": "iron_ore",
		"yield": 5, "respawn_ticks": 160, "xp": 24,
	},
	KIND_DEEP_HOLE: {
		"tier": 3, "skill": "fishing", "level": 5, "tool": "rod", "tool_tier": "", "item": "raw_char",
		"yield": 5, "respawn_ticks": 140, "xp": 22,
	},
}

## Blocking geometry: {id, kind, min: [x, z], max: [x, z], height}. `kind` is a wall (the
## outpost palisade), a cliff (the world's ice edges), an outcrop (a rock in the field), a
## ruin (ring two's broken walls and pillars), a ridge (ring three's pressure ridges in the
## ice) or decor (the tent in the yard).
var solids: Array = []
## Interactable placements by id: {kind, label, min, max, height, blocks}.
var objects: Dictionary = {}
## Named regions in precedence order: {name, polygon: [[x, z], ...]}. First match wins.
var regions: Array = []
## Enemy placements by id: {kind, home: [x, z], pack}. The kind's stats are in CombatTable;
## enemies sharing a `pack` notice the player together. Every placement gets a state entry.
var enemies: Dictionary = {}

var _blocked := PackedByteArray()
## GridPath's native A* grid over `_blocked`, built on the first route and dropped by bake().
var path_grid: AStarGrid2D = null


## The world, as rings around the outpost. The walled outpost has one gate on its south side,
## the fire, the stash and the workbench. The inner ring (out to 24 m) is safe but cold: pines
## south and north of the walls, four spots of one copper and one tin rock 15 to 22 m out (one
## per compass side, beside its landmark), two fishing holes together to the north and two ice
## crystals north-east and north-west. Ring one (out to the cliffs at
## 60 m) holds the wolf packs, bandit archers and two frost witches, the better nodes (frost
## pines west, iron in two spots of two rocks east and south-west, ice holes in three spots of
## two north, east and west), a mine of three copper and three tin rocks against the west cliff
## that witch 2 guards and, at its far southern edge, the gate to ring two
## with the bandit captain standing at it. Ring two lies beyond that gate and nowhere else: a
## band of ruins south of the cliffs (see `_ring_two`). Ring three lies beyond a second gate in
## ring two's southern cliffs: the glacier (see `_ring_three`). Ring one is only reached by
## walking through the inner ring.
static func outpost() -> WorldDef:
	var w := WorldDef.new()
	var half := 10.0
	var t := 1.0  # wall thickness in metres
	var gate_half_width := 2.0
	w.solids = [
		_solid("wall_north", [-half, -half], [half, -half + t]),
		_solid("wall_east", [half - t, -half], [half, half]),
		_solid("wall_west", [-half, -half], [-half + t, half]),
		_solid("wall_south_west", [-half, half - t], [-gate_half_width, half]),
		_solid("wall_south_east", [gate_half_width, half - t], [half, half]),
		# The keeper's tent in the south-east corner of the yard.
		_solid("tent", [6.0, 6.0], [9.0, 9.0], 1.6, KIND_DECOR),
	]
	# Ring one's outer edge: ice cliffs on all four sides, open only at the ring-two gate and the
	# dungeon's mouth, so the only way between ring one and ring two is through the gate.
	var edge := 60.0
	var c := 4.0  # cliff thickness
	w.solids.append_array([
		_solid("cliff_north", [-edge - c, -edge - c], [edge + c, -edge], 3.0, KIND_CLIFF),
		_solid("cliff_east_north", [edge, -edge - c], [edge + c, RING_ONE_DUNGEON_MOUTH_Z - 2.0], 3.0, KIND_CLIFF),
		_solid("cliff_east_south", [edge, RING_ONE_DUNGEON_MOUTH_Z + 2.0], [edge + c, edge + c], 3.0, KIND_CLIFF),
		_solid("cliff_west", [-edge - c, -edge - c], [-edge, edge + c], 3.0, KIND_CLIFF),
		_solid("cliff_south_west", [-edge - c, edge], [-gate_half_width, edge + c], 3.0, KIND_CLIFF),
		_solid("cliff_south_east", [gate_half_width, edge], [edge + c, edge + c], 3.0, KIND_CLIFF),
	])
	# Rock outcrops in ring one, so the walk out is a route and not a straight line.
	var outcrops := [
		[[-6.0, 34.0], [-2.0, 38.0]], [[5.0, 39.0], [9.0, 42.0]], [[-22.0, 32.0], [-18.0, 35.0]],
		[[21.0, 34.0], [26.0, 36.0]], [[-34.0, -32.0], [-30.0, -28.0]], [[28.0, -30.0], [33.0, -27.0]],
		[[-30.0, 48.0], [-25.0, 52.0]], [[26.0, 50.0], [30.0, 54.0]], [[-51.0, -10.0], [-47.0, -6.0]],
		[[48.0, -14.0], [52.0, -11.0]], [[-8.0, 48.0], [-4.0, 50.0]], [[33.0, 8.0], [36.0, 12.0]],
	]
	for i in outcrops.size():
		w.solids.append(_solid("outcrop_%d" % (i + 1), outcrops[i][0], outcrops[i][1], 1.8, KIND_OUTCROP))
	w.objects = {
		"gate": {
			"kind": KIND_GATE, "label": "Gate", "blocks": false, "height": 0.1,
			"min": [-gate_half_width, half - t], "max": [gate_half_width, half],
			"outward": [0.0, 1.0],
		},
		"fire": {
			"kind": KIND_FIRE, "label": "Fire", "blocks": true, "height": 0.6,
			"min": [-1.0, -1.0], "max": [1.0, 1.0],
		},
		"stash": {
			"kind": KIND_STASH, "label": "Stash", "blocks": true, "height": 1.0,
			"min": [-7.0, -7.0], "max": [-5.0, -6.0],
		},
		"workbench": {
			"kind": KIND_WORKBENCH, "label": "Workbench", "blocks": true, "height": 1.0,
			"min": [-3.0, -7.0], "max": [-1.0, -6.0],
		},
		# Barred until the captain has fallen and the outpost has built its winch. It always
		# blocks the walkability grid: an open gate is passed by walking up to it (see Sim).
		"ring_two_gate": {
			"kind": KIND_RING_GATE, "label": "Gate to ring two", "blocks": true, "height": 3.5,
			"min": [-gate_half_width, edge], "max": [gate_half_width, edge + 2.0],
			"guardian": "captain", "upgrade": "ring_two_gate", "outward": [0.0, 1.0],
		},
	}
	# Pines, one metre square: six between 4 m and 12 m south of the gate, four north of the walls.
	var trees := [
		[-7.0, 14.0], [-3.0, 17.0], [3.0, 14.0], [6.0, 19.0], [-8.0, 20.0], [1.0, 21.0],
		[-6.0, -15.0], [5.0, -14.0], [-13.0, -18.0], [12.0, -19.0],
	]
	for i in trees.size():
		_place(w, "tree_%d" % (i + 1), KIND_TREE, "Pine", trees[i], [1.0, 1.0], 3.0)
	# One copper and one tin rock in a spot on each side, north, east, south and west, each beside
	# that side's landmark (RingDressing.LANDMARKS) and out of earshot of every enemy home. The
	# south spot sits east of the cairn, which the near wolves would hear. Ids 1 to 3 were the
	# rocks that stood against the walls, so the spots number on from 4.
	var copper := [[2.5, -21.5], [15.5, 12.5], [3.0, 20.0], [-22.0, -3.5]]
	for i in copper.size():
		_place(w, "copper_%d" % (i + 4), KIND_COPPER_ROCK, "Copper rock", copper[i], [2.0, 2.0], 1.0)
	var tin := [[2.5, -18.0], [18.0, 9.0], [3.0, 16.5], [-18.5, -3.5]]
	for i in tin.size():
		_place(w, "tin_%d" % (i + 4), KIND_TIN_ROCK, "Tin rock", tin[i], [2.0, 2.0], 1.0)
	_place(w, "fishing_hole", KIND_FISHING_HOLE, "Fishing hole", [-1.0, -19.0], [2.0, 2.0], 0.1)
	_place(w, "fishing_hole_2", KIND_FISHING_HOLE, "Fishing hole", [-4.5, -19.0], [2.0, 2.0], 0.1)
	var crystals := [[16.0, -14.0], [-18.0, -13.0]]
	for i in crystals.size():
		_place(w, "ice_crystal_%d" % (i + 1), KIND_ICE_CRYSTAL, "Ice crystal", crystals[i], [1.0, 1.0], 1.4)
	# The mine: three copper and three tin rocks together against the west cliff, north of the
	# watch post and clear of its ground, with witch 2 at its mouth. They are ordinary rocks;
	# the mine pays because six stand together. The spots before it number 4 to 7.
	var mine_copper := [[-59.0, -35.0], [-53.0, -35.0], [-56.0, -32.0]]
	for i in mine_copper.size():
		_place(w, "copper_%d" % (i + 8), KIND_COPPER_ROCK, "Copper rock", mine_copper[i], [2.0, 2.0], 1.0)
	var mine_tin := [[-56.0, -35.0], [-59.0, -32.0], [-53.0, -32.0]]
	for i in mine_tin.size():
		_place(w, "tin_%d" % (i + 8), KIND_TIN_ROCK, "Tin rock", mine_tin[i], [2.0, 2.0], 1.0)
	var frost := [[-42.0, 8.0], [-46.0, 13.0], [-39.0, 15.0], [-44.0, 3.0]]
	for i in frost.size():
		_place(w, "frost_pine_%d" % (i + 1), KIND_FROST_PINE, "Frost pine", frost[i], [1.0, 1.0], 4.0)
	# Iron in two spots of two rocks, twelve ore between them (the winch's cost): east by the
	# archer camp, where the old cluster stood, and south-west by the far wolf pack, clear of the
	# cliff and the road south. iron_1 and iron_2 stay in the east spot; iron_3 stood apart from
	# them and is gone, so the south-west spot numbers on from 4.
	var iron := {"iron_1": [40.0, 6.0], "iron_2": [43.5, 7.5], "iron_4": [-38.0, 40.0], "iron_5": [-34.5, 41.5]}
	for id in iron:
		_place(w, id, KIND_IRON_ROCK, "Iron rock", iron[id], [2.0, 2.0], 1.2)
	# Trout in three spots of two holes, north (the old hole and one more), east and west, and
	# none on the road south, where fishing would mean standing still within the archers' and
	# the captain's reach.
	var ice_holes := [[-9.0, -43.0], [-12.5, -43.0], [42.0, -8.0], [45.5, -8.0], [-34.0, -5.0], [-37.5, -5.0]]
	_place(w, "ice_hole", KIND_ICE_HOLE, "Ice hole", ice_holes[0], [2.0, 2.0], 0.1)
	for i in range(1, ice_holes.size()):
		_place(w, "ice_hole_%d" % (i + 1), KIND_ICE_HOLE, "Ice hole", ice_holes[i], [2.0, 2.0], 0.1)
	# Ring one's waystone stands near the far southern road, out of sight of the captain and the
	# archer flanking the road east, so the long walk back from his gate can be skipped.
	_place(w, "ring_one_waystone", KIND_WAYSTONE, "Waystone", [12.0, 54.0], [1.0, 1.0], 2.2)
	# Ring one's enemies. The near groups sit just past the southern pines: two wolves south-west,
	# a pack of three farther west, a bandit archer south-east. Chopping the south-western pine is
	# loud enough for the near pack to hear. Farther out: an archer camp by the iron, a pack among
	# the frost pines, a pack by the north ice holes, two archers flanking the road south, a frost witch
	# out on each northern flank (witch 2 at the mouth of the mine), and the captain at the
	# ring-two gate. Every group sits more than a fight's noise (CombatTable.NOISE_FIGHT) from the
	# next, so each is fought on its own.
	var placements := [
		["wolf_1", "wolf", [-7.5, 28.5], "west_pack"],
		["wolf_2", "wolf", [-5.5, 29.5], "west_pack"],
		["wolf_3", "wolf", [-25.5, 27.5], "far_pack"],
		["wolf_4", "wolf", [-27.5, 28.5], "far_pack"],
		["wolf_5", "wolf", [-24.5, 29.5], "far_pack"],
		["archer_1", "bandit_archer", [14.5, 28.5], "archer_1"],
		["archer_2", "bandit_archer", [37.5, 27.5], "east_camp"],
		["archer_3", "bandit_archer", [47.5, 24.5], "east_camp"],
		["wolf_6", "wolf", [-45.5, 25.5], "pine_pack"],
		["wolf_7", "wolf", [-47.5, 27.5], "pine_pack"],
		["wolf_8", "wolf", [10.5, -43.5], "north_pack"],
		["wolf_9", "wolf", [12.5, -41.5], "north_pack"],
		["wolf_10", "wolf", [8.5, -45.5], "north_pack"],
		["archer_4", "bandit_archer", [-15.5, 44.5], "archer_4"],
		["archer_5", "bandit_archer", [17.5, 45.5], "archer_5"],
		["witch_1", "frost_witch", [38.5, -24.5], "witch_1"],
		["witch_2", "frost_witch", [-54.5, -28.5], "witch_2"],
		["captain", "bandit_captain", [0.5, 56.5], "captain"],
	]
	for p in placements:
		w.enemies[p[0]] = {"kind": p[1], "home": p[2], "pack": p[3]}
	_ring_two(w)
	_ring_three(w)
	_ring_one_dungeon(w)
	var far: Array = [w.origin[0] + w.cols * w.cell_size, w.origin[1] + w.rows * w.cell_size]
	# Ring two runs from the grid's west edge to the rings' east edge (RINGS_EAST) and the
	# outside of its southern cliffs, so ring one's own cliffs and ring two's count as ring two;
	# ring three is everything south of them. The dungeons come first, so no ring's rectangle
	# can claim their ground; the cliffs east of the rings and outside every dungeon lie in no
	# region. The ring-one dungeon's region takes in its mouth's own cells, so a walk through
	# the mouth goes from ring one straight into the dungeon and never through ring two's.
	var mouth_z := RING_ONE_DUNGEON_MOUTH_Z
	w.regions = [
		{"name": REGION_RING_ONE_DUNGEON, "polygon": [
			[RINGS_EAST, -edge - c], [far[0], -edge - c], [far[0], edge + c], [RINGS_EAST, edge + c],
			[RINGS_EAST, mouth_z + 2.0], [edge, mouth_z + 2.0], [edge, mouth_z - 2.0], [RINGS_EAST, mouth_z - 2.0],
		]},
		{"name": REGION_OUTPOST, "polygon": _rect_polygon([-half, -half], [half, half])},
		{"name": REGION_INNER_RING, "polygon": _rect_polygon([-24.0, -24.0], [24.0, 24.0])},
		{"name": REGION_RING_ONE, "polygon": _rect_polygon([-edge, -edge], [edge, edge])},
		{"name": REGION_RING_TWO, "polygon": _rect_polygon(w.origin, [RINGS_EAST, RING_TWO_FAR])},
		{"name": REGION_RING_THREE, "polygon": _rect_polygon([w.origin[0], RING_TWO_FAR], [RINGS_EAST, far[1]])},
	]
	w.bake()
	return w


## Ring two: the ruins south of the ring-two gate, from the cliffs at 64 m to the cliffs at
## 124 m, walled in on every side but for the gate to ring three in its southern cliffs. A yard with an old brazier opens behind the gate. A broken
## outer wall crosses the ring with three gaps, the chokepoints. Past it a frozen lake with deep
## holes lies west under a troll, coal seams and ruined pillars lie east among ruin stalkers, and
## a roofless keep in the middle holds rich iron and a pair of trolls. Farther south, past the
## keep, a troll and a stalker keep the far ruins. No group sits within a fight's noise of the
## next.
static func _ring_two(w: WorldDef) -> void:
	var near := 64.0
	var far := 124.0
	var side := 60.0
	var c := 4.0
	var gate_x := RING_THREE_GATE_X
	w.solids.append_array([
		_solid("cliff_ring_two_west", [-side - c, near], [-side, far + c], 3.0, KIND_CLIFF),
		_solid("cliff_ring_two_east", [side, near], [side + c, far + c], 3.0, KIND_CLIFF),
		_solid("cliff_ring_two_south_west", [-side, far], [gate_x - 2.0, far + c], 3.0, KIND_CLIFF),
		_solid("cliff_ring_two_south_east", [gate_x + 2.0, far], [side, far + c], 3.0, KIND_CLIFF),
	])
	# Barred until the outpost builds its hoist; it has no guardian. It stands in the outer
	# half of the cliff, so the alcove in front of it is ring two's and a walk through it
	# either way ends clear of the line between the rings. It always blocks the grid.
	w.objects["ring_three_gate"] = {
		"kind": KIND_RING_GATE, "label": "Gate to ring three", "blocks": true, "height": 3.5,
		"min": [gate_x - 2.0, RING_TWO_FAR - 2.0], "max": [gate_x + 2.0, RING_TWO_FAR],
		"upgrade": "ring_three_gate", "outward": [0.0, 1.0],
	}
	# The broken outer wall at 78 m, open at x -34 to -30, -3 to 3 and 30 to 34; then the keep,
	# a square from x -16 to 16 and z 92 to 112, with a door north, west and south-east.
	var ruins := [
		[[-side, 78.0], [-34.0, 79.0]], [[-30.0, 78.0], [-3.0, 79.0]],
		[[3.0, 78.0], [30.0, 79.0]], [[34.0, 78.0], [side, 79.0]],
		[[-16.0, 92.0], [-2.0, 93.0]], [[2.0, 92.0], [16.0, 93.0]],
		[[-16.0, 93.0], [-15.0, 100.0]], [[-16.0, 103.0], [-15.0, 112.0]],
		[[15.0, 93.0], [16.0, 112.0]],
		[[-16.0, 111.0], [6.0, 112.0]], [[10.0, 111.0], [15.0, 112.0]],
		# Pillars among the coal seams east, to corner a stalker against.
		[[31.0, 92.0], [32.5, 93.5]], [[48.0, 82.0], [49.5, 83.5]],
		[[33.0, 108.0], [34.5, 109.5]], [[53.0, 96.0], [54.5, 97.5]],
	]
	for i in ruins.size():
		w.solids.append(_solid("ruin_%d" % (i + 1), ruins[i][0], ruins[i][1], 2.2, KIND_RUIN))
	w.objects["brazier"] = {
		"kind": KIND_FIRE, "label": "Brazier", "blocks": true, "height": 0.6,
		"min": [5.0, 68.0], "max": [6.5, 69.5],
	}
	var holes := [[-47.0, 86.0], [-41.0, 97.0], [-52.0, 104.0]]
	for i in holes.size():
		_place(w, "deep_hole_%d" % (i + 1), KIND_DEEP_HOLE, "Deep hole", holes[i], [2.0, 2.0], 0.1)
	var coal := [[38.0, 84.0], [46.0, 90.0], [40.0, 98.0], [50.0, 104.0], [20.0, 116.0]]
	for i in coal.size():
		_place(w, "coal_%d" % (i + 1), KIND_COAL_ROCK, "Coal seam", coal[i], [2.0, 2.0], 1.2)
	var rich := [[-9.0, 97.0], [6.0, 98.0], [-2.0, 106.0]]
	for i in rich.size():
		_place(w, "rich_iron_%d" % (i + 1), KIND_RICH_IRON_ROCK, "Rich iron vein", rich[i], [2.0, 2.0], 1.4)
	# Ring two's waystone stands in the far ruins south of the keep, between the troll and the
	# stalker that keep them and out of sight of both.
	_place(w, "ring_two_waystone", KIND_WAYSTONE, "Waystone", [0.0, 118.0], [1.0, 1.0], 2.2)
	var placements := [
		["stalker_1", "ruin_stalker", [-32.5, 72.5], "stalker_1"],
		["troll_1", "ice_troll", [-44.5, 94.5], "troll_1"],
		["stalker_2", "ruin_stalker", [0.5, 86.5], "stalker_2"],
		["troll_2", "ice_troll", [-5.5, 103.5], "keep"],
		["troll_3", "ice_troll", [4.5, 105.5], "keep"],
		["stalker_3", "ruin_stalker", [44.5, 94.5], "east_ruins"],
		["stalker_4", "ruin_stalker", [36.5, 104.5], "east_ruins"],
		["troll_4", "ice_troll", [-30.5, 116.5], "troll_4"],
		["stalker_5", "ruin_stalker", [28.5, 117.5], "stalker_5"],
	]
	for p in placements:
		w.enemies[p[0]] = {"kind": p[1], "home": p[2], "pack": p[3]}


## Ring three: the glacier south of ring two's southern cliffs, from 128 m to the cliffs at
## 188 m and from x -60 to 60, walled in by cliffs on the west, east and south. Its gate sits
## in the south-west of ring two's cliff, out of sight of every ring-two home and a stretch of
## ruins from ring two's waystone; there is no waystone past it. A fire burns a few metres in
## from the gate, as the brazier does in ring two. Pressure ridges break the ice into lanes, so
## a kiting enemy has walls to be cornered against. No nodes: its enemies bring their own loot.
static func _ring_three(w: WorldDef) -> void:
	var near := RING_TWO_FAR
	var far := 188.0
	var side := 60.0
	var c := 4.0
	w.solids.append_array([
		_solid("cliff_ring_three_west", [-side - c, near], [-side, far + c], 3.0, KIND_CLIFF),
		_solid("cliff_ring_three_east", [side, near], [side + c, far + c], 3.0, KIND_CLIFF),
		_solid("cliff_ring_three_south", [-side, far], [side, far + c], 3.0, KIND_CLIFF),
	])
	var ridges := [
		[[-28.0, 142.0], [-12.0, 143.5]], [[8.0, 138.0], [9.5, 153.0]], [[22.0, 160.0], [40.0, 161.5]],
		[[-48.0, 158.0], [-46.5, 174.0]], [[-14.0, 170.0], [4.0, 171.5]], [[44.0, 140.0], [45.5, 152.0]],
		# The Frost tyrant's hollow at the far south-west, open to the east.
		[[-33.0, 176.0], [-17.0, 177.5]], [[-34.5, 176.0], [-33.0, 186.0]],
	]
	for i in ridges.size():
		w.solids.append(_solid("ridge_%d" % (i + 1), ridges[i][0], ridges[i][1], 2.0, KIND_RIDGE))
	var gate_x := RING_THREE_GATE_X
	w.objects["ring_three_fire"] = {
		"kind": KIND_FIRE, "label": "Fire", "blocks": true, "height": 0.6,
		"min": [gate_x + 5.0, 132.0], "max": [gate_x + 6.5, 133.5],
	}
	# Snowveil archers: a pair in the lee of the ridge that runs down the middle of the ring and
	# one alone in the lee of the west cliff, each group more than a fight's noise from the next
	# so they are fought one at a time.
	var placements := [
		["veil_archer_1", "snowveil_archer", [11.5, 145.5], "ridge_pair"],
		["veil_archer_2", "snowveil_archer", [11.5, 147.5], "ridge_pair"],
		["veil_archer_3", "snowveil_archer", [-54.5, 166.5], "cliff_archer"],
	]
	# Frostbound knights, the first kind met: a pair a little way past the fire and one alone
	# farther in, each group more than a fight's noise from the next and out of sight of the fire.
	placements.append_array([
		["frost_knight_1", "frostbound_knight", [-24.5, 152.0], "knight_pair"],
		["frost_knight_2", "frostbound_knight", [-24.5, 154.5], "knight_pair"],
		["frost_knight_3", "frostbound_knight", [-8.0, 180.0], "knight_alone"],
	])
	# Aurora seers, three alone in the south half of the ring between the archers and the far
	# cliff, each more than a fight's noise from every other group.
	placements.append_array([
		["seer_1", "aurora_seer", [30.5, 166.5], "seer_1"],
		["seer_2", "aurora_seer", [50.5, 177.5], "seer_2"],
		["seer_3", "aurora_seer", [-34.5, 170.5], "seer_3"],
	])
	# The Frost tyrant, ring three's boss, alone in a hollow of ridges at the far south-west of
	# the ring, more than a fight's noise from every other group.
	placements.append(["frost_tyrant", "frost_tyrant", [-24.0, 183.0], "tyrant"])
	for p in placements:
		w.enemies[p[0]] = {"kind": p[1], "home": p[2], "pack": p[3]}


## The ring-one dungeon: the pocket east of ring one's east cliff, from x 64 to the cliffs at
## 108 and z -60 to 60 (see DUNGEONS), and the cliffs that fill the rest of the grid east of
## the rings, so the only new ground that can be walked is the dungeon's. Its mouth stands in
## ring one's east cliff, a long way north of the road to the captain and out of the frost
## witches' sight; it fills the cliff's whole depth, so a walk through it either way ends clear
## of both sides. The walls between the legs are the cave's own rock.
static func _ring_one_dungeon(w: WorldDef) -> void:
	var near := RINGS_EAST
	var far := 108.0
	var edge := 60.0
	var c := 4.0
	var grid_far: Array = [w.origin[0] + w.cols * w.cell_size, w.origin[1] + w.rows * w.cell_size]
	w.solids.append_array([
		_solid("cliff_dungeon_north", [near, -edge - c], [grid_far[0], -edge], 3.0, KIND_CLIFF),
		_solid("cliff_dungeon_east", [far, -edge], [grid_far[0], edge], 3.0, KIND_CLIFF),
		# Everything east of rings two and three, for the dungeons still to come.
		_solid("cliff_far_east", [near, edge], grid_far, 3.0, KIND_CLIFF),
		_solid("dungeon_wall_1", [near, -34.0], [96.0, -32.0], 3.0, KIND_CLIFF),
		_solid("dungeon_wall_2", [76.0, -6.0], [far, -4.0], 3.0, KIND_CLIFF),
		_solid("dungeon_wall_3", [near, 22.0], [96.0, 24.0], 3.0, KIND_CLIFF),
		# The boss room's east wall, open at its south end.
		_solid("dungeon_wall_4", [84.0, 24.0], [86.0, 52.0], 3.0, KIND_CLIFF),
	])
	var z := RING_ONE_DUNGEON_MOUTH_Z
	w.objects[DUNGEONS["ring_one_dungeon"]["mouth"]] = {
		"kind": KIND_RING_GATE, "label": "Dungeon mouth", "blocks": true, "height": 3.5,
		"min": [edge, z - 2.0], "max": [near, z + 2.0], "outward": [1.0, 0.0],
	}
	# The dungeon's one fire, 5 m in from the mouth like ring two's brazier. Nothing past it.
	var fire: Array = DUNGEONS["ring_one_dungeon"]["reserved"]["fire"]
	w.objects[DUNGEONS["ring_one_dungeon"]["fire"]] = {
		"kind": KIND_FIRE, "label": "Fire", "blocks": true, "height": 0.6,
		"min": [fire[0] - 0.75, fire[1] - 0.75], "max": [fire[0] + 0.75, fire[1] + 0.75],
	}
	# Two iron rocks, each at a reserved node spot and reached only past a fight.
	var nodes: Array = DUNGEONS["ring_one_dungeon"]["reserved"]["nodes"]
	for i in nodes.size():
		_place(w, "dungeon_iron_%d" % (i + 1), KIND_IRON_ROCK, "Iron rock", [nodes[i][0] - 1.0, nodes[i][1] - 1.0], [2.0, 2.0], 1.2)
	# Ring one's own kinds in four groups, one on each reserved fight spot, one in each leg of
	# the lane: wolves, then an archer, then wolves, then two archers. Each group stands on the
	# shortest way through its leg, so no route to a node or the boss slips past it, and is
	# more than a fight's noise (CombatTable.NOISE_FIGHT) and every ring-one kind's sight from
	# the next and from the fire, so each is fought on its own.
	var fights: Array = DUNGEONS["ring_one_dungeon"]["reserved"]["fights"]
	var groups := [
		[["wolf", 0.0, 0.0], ["wolf", 2.0, 1.0]],
		[["bandit_archer", 0.0, 0.0]],
		[["wolf", 0.0, 0.0], ["wolf", 2.0, 1.0]],
		[["bandit_archer", 0.0, 0.0], ["bandit_archer", 2.0, 1.0]],
	]
	for g in groups.size():
		for m in groups[g].size():
			var member: Array = groups[g][m]
			w.enemies["dungeon_%s_%d_%d" % [member[0], g + 1, m + 1]] = {
				"kind": member[0], "home": [fights[g][0] + member[1], fights[g][1] + member[2]],
				"pack": "dungeon_fight_%d" % (g + 1),
			}
	# The boss and the way out, in the boss room. The way out stands in the room's south-west
	# corner and faces north, into the room; `outward` only turns its look.
	var dungeon: Dictionary = DUNGEONS["ring_one_dungeon"]
	var r: Dictionary = dungeon["reserved"]
	w.enemies[dungeon["boss"]] = {"kind": "great_wolf", "home": r["boss"], "pack": dungeon["boss"]}
	var at: Array = r["way_out"]
	w.objects[dungeon["way_out"]] = {
		"kind": KIND_WAY_OUT, "label": "Way out", "blocks": true, "height": 3.0,
		"min": [at[0] - 1.0, at[1] - 1.0], "max": [at[0] + 1.0, at[1] + 1.0], "outward": [0.0, -1.0],
	}


## The id of the dungeon whose region is `region`, or "" for a ring, the outpost or nowhere.
static func dungeon_of_region(region: String) -> String:
	for id in DUNGEONS:
		if DUNGEONS[id]["region"] == region:
			return id
	return ""


## The id of the dungeon whose mouth is the object `object_id`, or "".
static func dungeon_of_mouth(object_id: String) -> String:
	for id in DUNGEONS:
		if DUNGEONS[id]["mouth"] == object_id:
			return id
	return ""


## The id of the dungeon whose way out is the object `object_id`, or "".
static func dungeon_of_way_out(object_id: String) -> String:
	for id in DUNGEONS:
		if DUNGEONS[id]["way_out"] == object_id:
			return id
	return ""


static func _place(w: WorldDef, id: String, kind: String, label: String, at: Array, size: Array, height: float) -> void:
	w.objects[id] = {
		"kind": kind, "label": label, "blocks": true, "height": height,
		"min": [at[0], at[1]], "max": [at[0] + size[0], at[1] + size[1]],
	}


static func _solid(id: String, min_xz: Array, max_xz: Array, height := 2.5, kind := KIND_WALL) -> Dictionary:
	return {"id": id, "kind": kind, "min": min_xz, "max": max_xz, "height": height}


static func _rect_polygon(min_xz: Array, max_xz: Array) -> Array:
	return [
		[min_xz[0], min_xz[1]], [max_xz[0], min_xz[1]],
		[max_xz[0], max_xz[1]], [min_xz[0], max_xz[1]],
	]


## Rasterises solids and blocking objects into the walkability grid. Call after editing them.
func bake() -> void:
	path_grid = null
	_blocked = PackedByteArray()
	_blocked.resize(cols * rows)
	_blocked.fill(0)
	for s in solids:
		_block_rect(s["min"], s["max"])
	for id in objects:
		var o: Dictionary = objects[id]
		if o.get("blocks", true):
			_block_rect(o["min"], o["max"])


## Blocks every cell whose centre lies inside the rectangle, visiting only the cells it spans.
func _block_rect(min_xz: Array, max_xz: Array) -> void:
	var lo := cell_of(Vector2(min_xz[0], min_xz[1]))
	var hi := cell_of(Vector2(max_xz[0], max_xz[1]))
	for y in range(maxi(0, lo.y), mini(rows, hi.y + 1)):
		for x in range(maxi(0, lo.x), mini(cols, hi.x + 1)):
			var c := cell_center(Vector2i(x, y))
			if c.x >= min_xz[0] and c.x < max_xz[0] and c.y >= min_xz[1] and c.y < max_xz[1]:
				_blocked[y * cols + x] = 1


# --- Grid queries ---------------------------------------------------------------------

func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor((pos.x - origin[0]) / cell_size)),
		int(floor((pos.y - origin[1]) / cell_size))
	)


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(
		origin[0] + (cell.x + 0.5) * cell_size,
		origin[1] + (cell.y + 0.5) * cell_size
	)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


func is_walkable_cell(cell: Vector2i) -> bool:
	return in_bounds(cell) and _blocked[cell.y * cols + cell.x] == 0


## One byte per cell, row-major from cell (0, 0), 1 where the cell is blocked. For hot loops
## that cannot afford a call per cell; everything else asks is_walkable_cell().
func blocked_cells() -> PackedByteArray:
	return _blocked


func is_walkable(pos: Vector2) -> bool:
	return is_walkable_cell(cell_of(pos))


## True when `pos` and the points `margin` metres to each side of it are all walkable,
## so a path can hug a wall without visually clipping into it.
func is_walkable_with_margin(pos: Vector2, margin: float) -> bool:
	return (
		is_walkable(pos)
		and is_walkable(pos + Vector2(margin, 0))
		and is_walkable(pos - Vector2(margin, 0))
		and is_walkable(pos + Vector2(0, margin))
		and is_walkable(pos - Vector2(0, margin))
	)


## The walkable cell nearest to `pos` within `max_radius` cells (Chebyshev), or null.
## The cell containing `pos` itself wins when it is walkable.
func nearest_walkable_cell(pos: Vector2, max_radius: int) -> Variant:
	var home := cell_of(pos)
	if is_walkable_cell(home):
		return home
	var best: Variant = null
	var best_d := INF
	for r in range(1, max_radius + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := home + Vector2i(dx, dy)
				if not is_walkable_cell(c):
					continue
				var d := cell_center(c).distance_squared_to(pos)
				if d < best_d:
					best_d = d
					best = c
		if best != null:
			return best
	return best


## Cells that an actor may stand on to interact with an object: the object's own cells
## when it does not block, otherwise the walkable ring of cells around its footprint.
func approach_cells(object_id: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not objects.has(object_id):
		return out
	var o: Dictionary = objects[object_id]
	var lo := cell_of(Vector2(o["min"][0], o["min"][1]))
	var hi := cell_of(Vector2(o["max"][0] - 0.001, o["max"][1] - 0.001))
	var pad := 0 if not o.get("blocks", true) else 1
	for y in range(lo.y - pad, hi.y + pad + 1):
		for x in range(lo.x - pad, hi.x + pad + 1):
			var c := Vector2i(x, y)
			if is_walkable_cell(c):
				out.append(c)
	return out


## Ids of every placed object whose kind is a gatherable node, in placement order.
func node_ids() -> Array[String]:
	var out: Array[String] = []
	for id in objects:
		if NODE_KINDS.has(objects[id]["kind"]):
			out.append(id)
	return out


## Ids of every placed object of `kind`, in placement order.
func objects_of_kind(kind: String) -> Array[String]:
	var out: Array[String] = []
	for id in objects:
		if objects[id]["kind"] == kind:
			out.append(id)
	return out


## Distance from `pos` to the nearest point of the object's footprint (0 when inside it).
func distance_to_object(object_id: String, pos: Vector2) -> float:
	var o: Dictionary = objects[object_id]
	var nearest := Vector2(
		clampf(pos.x, o["min"][0], o["max"][0]),
		clampf(pos.y, o["min"][1], o["max"][1])
	)
	return nearest.distance_to(pos)


func object_center(object_id: String) -> Vector2:
	var o: Dictionary = objects[object_id]
	return Vector2((o["min"][0] + o["max"][0]) * 0.5, (o["min"][1] + o["max"][1]) * 0.5)


# --- Regions ------------------------------------------------------------------------

## Name of the first region whose polygon contains `pos`, or "" outside every region.
func region_at(pos: Vector2) -> String:
	for r in regions:
		var poly := PackedVector2Array()
		for p in r["polygon"]:
			poly.append(Vector2(p[0], p[1]))
		if Geometry2D.is_point_in_polygon(pos, poly):
			return r["name"]
	return ""
