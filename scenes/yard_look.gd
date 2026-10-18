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
## The stash corner: along the west wall, south of the stash.
const SPOTS := {
	"stash_corner": {"at": [-8.55, -4.4], "turn": PI * 0.5},
}

## The hand-made meshes a part can name (WorldDressing builds them), beside the kit models.
const MESHES := ["shelf_rack"]

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
