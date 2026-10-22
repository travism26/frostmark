## What the built upgrades put in the outpost yard, as data: each upgrade's look declared by
## its id, and a pure function from the list of built upgrades to the pieces to draw. Pure
## data like the ring-look table: no nodes, no scene, no rendering, no sim and nothing saved.
## WorldDressing builds the meshes from the pieces; GameRoot redraws them whenever the built
## list changes, so the yard looks the same on every load.
##
## Upgrades in one line build up one spot, and a later step adds to it beside the earlier
## step's piece. An unbuilt upgrade, or one with no look, draws nothing.
class_name YardLook
extends RefCounted

## Where each line builds, in the yard: `at` [x, z] on the ground and `turn` about the up axis.
## A spot's own frame runs x along the wall and z out into the yard.
## The stash corner: along the west wall, south of the stash, each step of the line south
## of the one before (a spot's +x runs north here).
const SPOTS := {
	"stash_corner": {"at": [-8.55, -4.4], "turn": PI * 0.5},
	# The armoury: along the east wall, between the wood pile and the tent's fence.
	"east_wall": {"at": [8.6, 1.7], "turn": -PI * 0.5},
	# The winch: just inside the south gate, west of the path and the signpost, far enough
	# in from the palisade that the wall never hides it from the camera.
	"south_gate": {"at": [-5.0, 6.9], "turn": PI},
	# The smithy: the north band, east of the workbench; its back is the north wall.
	"smithy": {"at": [0.9, -7.4], "turn": 0.0},
}

## The hand-made meshes a part can name (WorldDressing builds them), beside the kit models.
const MESHES := ["shelf_rack", "hatch", "iron_chest", "weapon_rack", "winch_frame", "forge_hearth", "furnace_stack"]

## Each upgrade's look: its `line` and `step` in that line, the `spot` it builds in, its
## `offset` [x, z] in the spot's frame, its `size` [along, out] on the ground, and its
## `parts`. A part is a kit `model` scaled to `height` (snow-capped from `snow_from`, 1.1 for
## none) or a hand-made `mesh` of `size` [along, high, out]; it stands at `at` [x, z] in the
## piece's frame, `y` above the ground, turned by `turn`.
const LOOKS := {
	# A timber shelf rack against the wall, crates and a keg on its boards and crates on top,
	# so it reads as stores from the camera above. Boards stand at 0.14, 0.67 and 1.2 m.
	"stash_shelves": {
		"line": "stash", "step": 1, "spot": "stash_corner", "offset": [0.0, 0.0], "size": [2.2, 0.7],
		"parts": [
			{"mesh": "shelf_rack", "size": [2.2, 1.4, 0.66], "at": [0.0, 0.0], "y": 0.0, "turn": 0.0},
			{"model": Props.SURVIVAL + "box.glb", "height": 0.42, "snow_from": 1.1, "at": [-0.55, 0.02], "y": 0.17, "turn": 0.1},
			{"model": Props.SURVIVAL + "box.glb", "height": 0.38, "snow_from": 1.1, "at": [0.45, -0.02], "y": 0.17, "turn": -0.15},
			{"model": Props.SURVIVAL + "barrel.glb", "height": 0.42, "snow_from": 1.1, "at": [-0.4, 0.02], "y": 0.7, "turn": 0.0},
			{"model": Props.SURVIVAL + "box.glb", "height": 0.4, "snow_from": 1.1, "at": [0.4, 0.0], "y": 0.7, "turn": 0.2},
			{"model": Props.SURVIVAL + "box.glb", "height": 0.46, "snow_from": 1.1, "at": [-0.5, 0.0], "y": 1.23, "turn": 0.12},
			{"model": Props.SURVIVAL + "box.glb", "height": 0.36, "snow_from": 1.1, "at": [0.15, 0.03], "y": 1.23, "turn": -0.25},
			{"model": Props.SURVIVAL + "box.glb", "height": 0.3, "snow_from": 1.1, "at": [0.7, -0.02], "y": 1.23, "turn": 0.35},
		],
	},
	# A trapdoor to the cellar in the yard floor, south of the shelves, with a stack of casks
	# against the wall between them: the stores have gone below ground.
	"stash_cellar": {
		"line": "stash", "step": 2, "spot": "stash_corner", "offset": [-2.3, 0.3], "size": [2.0, 1.3],
		"parts": [
			{"mesh": "hatch", "size": [1.0, 0.1, 0.9], "at": [-0.42, 0.15], "y": 0.0, "turn": 0.0},
			{"model": Props.SURVIVAL + "barrel.glb", "height": 0.62, "snow_from": 0.8, "at": [0.3, -0.36], "y": 0.0, "turn": 0.3},
			{"model": Props.SURVIVAL + "barrel.glb", "height": 0.62, "snow_from": 0.8, "at": [0.74, -0.36], "y": 0.0, "turn": 1.1},
			{"model": Props.SURVIVAL + "barrel.glb", "height": 0.6, "snow_from": 0.8, "at": [0.55, 0.1], "y": 0.0, "turn": 2.0},
			{"model": Props.SURVIVAL + "barrel.glb", "height": 0.58, "snow_from": 0.7, "at": [0.52, -0.3], "y": 0.62, "turn": 0.6},
		],
	},
	# An iron-bound chest, longer and darker than the stash, south of the cellar: the last
	# step of the corner, its lock facing the yard.
	"stash_vault": {
		"line": "stash", "step": 3, "spot": "stash_corner", "offset": [-4.4, 0.12], "size": [1.4, 0.95],
		"parts": [
			{"mesh": "iron_chest", "size": [1.2, 0.72, 0.78], "at": [0.0, 0.0], "y": 0.0, "turn": 0.0},
		],
	},
	# A timber weapon rack against the wall, swords and spears standing in it and a painted
	# shield hung at its middle, with a crate of spare gear at one end.
	"armoury": {
		"line": "armoury", "step": 1, "spot": "east_wall", "offset": [0.0, 0.0], "size": [2.8, 0.6],
		"parts": [
			{"mesh": "weapon_rack", "size": [2.3, 1.7, 0.55], "at": [-0.2, 0.0], "y": 0.0, "turn": 0.0},
			{"model": Props.SURVIVAL + "box.glb", "height": 0.45, "snow_from": 0.8, "at": [1.15, 0.0], "y": 0.0, "turn": 0.2},
		],
	},
	# A winch frame with an iron-banded drum and its chain run out to an anchor stone, to one
	# side of the gate path. Low, so it never hides the character from the camera.
	"ring_two_gate": {
		"line": "winch", "step": 1, "spot": "south_gate", "offset": [0.0, 0.0], "size": [2.0, 1.2],
		"parts": [
			{"mesh": "winch_frame", "size": [2.0, 1.6, 1.2], "at": [0.0, 0.0], "y": 0.0, "turn": 0.0},
		],
	},
	# A stone hearth with a bed of glowing coals, bellows on its west side and a short flue at
	# its back, a quench bucket beside it: the smithy's first step, in front of the spot.
	"forge": {
		"line": "smithing", "step": 1, "spot": "smithy", "offset": [0.0, 0.6], "size": [1.6, 1.1],
		"parts": [
			{"mesh": "forge_hearth", "size": [1.2, 0.85, 0.95], "at": [-0.15, 0.0], "y": 0.0, "turn": 0.0},
			{"model": Props.SURVIVAL + "bucket.glb", "height": 0.34, "snow_from": 1.1, "at": [0.6, 0.25], "y": 0.0, "turn": 0.4},
		],
	},
	# The forge grown big: a hooped stone stack with a glowing tap at its foot and a chimney
	# whose mouth glows, behind the forge against the north wall. The tallest thing in the
	# yard, and north of everything the player walks to, so the camera always sees past it.
	"blast_furnace": {
		"line": "smithing", "step": 2, "spot": "smithy", "offset": [0.0, -0.8], "size": [1.5, 1.3],
		"parts": [
			{"mesh": "furnace_stack", "size": [1.4, 4.4, 1.2], "at": [0.0, 0.0], "y": 0.0, "turn": 0.0},
		],
	},
}


## What each upgrade is built of, which picks the sound its build makes (AudioCues): every
## upgrade declares one, waystones too, though they draw nothing in the yard. Kept apart from
## LOOKS so a look and its material can land on their own.
const TIMBER := "timber"
const STONE := "stone"
const IRON := "iron"
const MATERIALS := {
	"stash_shelves": TIMBER,
	"forge": STONE,
	"stash_cellar": TIMBER,
	"armoury": IRON,
	"ring_two_gate": TIMBER,
	"blast_furnace": STONE,
	"waystone": STONE,
	"stash_vault": IRON,
}


## The material an upgrade is built of, or "" when it declares none.
static func material(id: String) -> String:
	return MATERIALS.get(id, "")

## The pieces the built upgrades put in the yard, in the upgrade table's order whatever the
## order of `built`. Each piece carries its `upgrade`, `line`, `step` and `spot`, where it
## stands (`at`, a Vector2 on the ground, and `turn`), its `size` on the ground and its
## `parts`, as fresh copies.
static func pieces(built: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in UpgradeTable.ids():
		if not built.has(id) or not LOOKS.has(id):
			continue
		var look: Dictionary = LOOKS[id]
		var spot: Dictionary = SPOTS[look["spot"]]
		var turn: float = spot["turn"]
		var offset := Vector2(look["offset"][0], look["offset"][1])
		out.append({
			"upgrade": id, "line": look["line"], "step": look["step"], "spot": look["spot"],
			"at": Vector2(spot["at"][0], spot["at"][1]) + to_ground(offset, turn), "turn": turn,
			"size": Vector2(look["size"][0], look["size"][1]), "parts": (look["parts"] as Array).duplicate(true),
		})
	return out


## A point in a frame turned `turn` about the up axis, on the ground's axes (x east, y south),
## the way a Node3D's `rotation.y` turns it.
static func to_ground(local: Vector2, turn: float) -> Vector2:
	return Vector2(local.x * cos(turn) + local.y * sin(turn), -local.x * sin(turn) + local.y * cos(turn))


## The corners of a piece's footprint on the ground.
static func footprint(piece: Dictionary) -> PackedVector2Array:
	var half: Vector2 = piece["size"] * 0.5
	var out := PackedVector2Array()
	for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		out.append(piece["at"] + to_ground(corner, piece["turn"]))
	return out
