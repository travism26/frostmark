## The back is worn in layers (#161): the body piece, the cape over it, and the quiver and the
## slung tool over both. Pieces come one at a time from different sets and tiers, so every cape
## outline must hang clear of every body piece without floating off it, and the quiver must
## stand clear of the body, any cape and any slung tool, whatever is or is not worn beside it.
## How the layers read on screen is judged from tools/slot_shots.gd.
extends "res://tests/run.gd".TestCase

const GearLookScript := preload("res://scenes/gear_look.gd")
const CharacterGearScript := preload("res://scenes/character_gear.gd")

## How far a cape may stand off the body under it before it reads as floating.
const MAX_CAPE_GAP := 0.08


## Every body worn under the back layers: none, then each body item in the table.
static func _bodies() -> Array[String]:
	var out: Array[String] = [""]
	for item in ItemTable.ITEMS:
		if ItemTable.slot(item) == ItemTable.SLOT_BODY:
			out.append(item)
	return out


## A cloak look of each outline, as the cape slot would hang one.
static func _capes() -> Array[Dictionary]:
	var out: Array[Dictionary] = [{}]
	for outline in GearLookScript.OUTLINES:
		out.append(GearLookScript.numbers({"shape": GearLookScript.SHAPE_CLOAK, "outline": outline}))
	return out


## The z of a hung cape's back face at height `y`, or -INF where the cape does not reach.
static func _cape_back(cape: Dictionary, y: float, x: float) -> float:
	if cape.is_empty() or absf(x) > cape["width"] * 0.5:
		return -INF
	var top: Vector3 = cape["offset"]
	var length: float = maxf(cape["length_left"], cape["length_right"])
	var tilt: float = cape["tilt"]
	if y > top.y or y < top.y - length * cos(tilt):
		return -INF
	var depth: float = cape["thickness"] * (2.0 if cape["outline"] in [GearLookScript.OUTLINE_TAIL, GearLookScript.OUTLINE_BANNER] else 1.0)
	return top.z + (top.y - y) * tan(tilt) + depth * 0.5


## Points down a quiver look's axis, from its foot to its tips.
static func _quiver_axis(look: Dictionary) -> Array[Vector3]:
	var axis := Basis.from_euler(look["tilt"]) * Vector3.UP
	var out: Array[Vector3] = []
	for i in 21:
		out.append((look["offset"] as Vector3) + axis * ((look["length"] + look["tip_length"]) * i / 20.0))
	return out


func test_with_nothing_under_it_a_cape_keeps_its_look_and_a_quiver_its_place() -> void:
	var cape := GearLookScript.numbers({"shape": GearLookScript.SHAPE_CLOAK})
	assert_eq(CharacterGearScript.hang_cape(cape, "")["offset"], cape["offset"], "a cape over the bare back hangs where its look says")
	var quiver := GearLookScript.numbers({"shape": GearLookScript.SHAPE_QUIVER})
	assert_eq(CharacterGearScript.hang_quiver(quiver, "", {})["offset"], quiver["offset"], "a quiver alone sits where its look says")
	for tool in ["steel_axe", "steel_pickaxe", "fishing_rod"]:
		var look := GearLookScript.piece(tool, GearLookScript.PART_TOOL)
		assert_eq(CharacterGearScript.hang_sling(look, {}), look["sling_offset"], "%s slings where it always did with no cape" % tool)


func test_every_cape_hangs_clear_of_every_body_piece_without_floating() -> void:
	for body in _bodies():
		var under: Array[AABB] = []
		if body != "":
			var piece := CharacterGearScript.body_piece(body)
			under = CharacterGearScript.mesh_bounds(piece)
			piece.free()
		for outline in GearLookScript.OUTLINES:
			var look := CharacterGearScript.hang_cape(GearLookScript.numbers({"shape": GearLookScript.SHAPE_CLOAK, "outline": outline}), body)
			var cloak := CharacterGearScript.cloak(look, GearLookScript.KIT)
			for p in _edge_points(cloak):
				for box in under:
					if p.y < box.position.y or p.y > box.end.y or p.x < box.position.x or p.x > box.end.x:
						continue
					assert_true(p.z >= box.end.z, "a %s cape clears %s (%.3f behind %.3f at y %.2f)" % [outline, body, p.z, box.end.z, p.y])
			cloak.free()
			if body == "":
				continue
			# The cape's front face where it meets the body most closely: no further off than a hem.
			var top: Vector3 = look["offset"]
			var tilt: float = look["tilt"]
			var gap := INF
			for box in under:
				var y := minf(box.end.y, top.y)
				if y < box.position.y:
					continue
				gap = minf(gap, top.z - look["thickness"] * 0.5 + (top.y - y) * tan(tilt) - box.end.z)
			assert_true(gap <= MAX_CAPE_GAP, "a %s cape hangs on %s, not %.3f off it" % [outline, body, gap])


## Points along every edge of every mesh's box under `node`, in `node`'s frame: the true corners
## and edges of a box, turned with its parts rather than squared to the axes.
static func _edge_points(node: Node3D) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var n: Node = mesh
		while n != node:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var box := (mesh as MeshInstance3D).mesh.get_aabb()
		for i in 8:
			for axis in 3:
				if i & (1 << axis):
					continue
				var a := box.get_endpoint(i)
				var b := box.get_endpoint(i | (1 << axis))
				for k in 11:
					out.append(t * a.lerp(b, k / 10.0))
	return out


func test_the_quiver_stands_clear_of_the_body_and_any_cape() -> void:
	var quiver := GearLookScript.numbers({"shape": GearLookScript.SHAPE_QUIVER})
	var radius: float = quiver["radius"]
	for body in _bodies():
		var under: Array[AABB] = []
		if body != "":
			var piece := CharacterGearScript.body_piece(body)
			under = CharacterGearScript.mesh_bounds(piece)
			piece.free()
		for cape in _capes():
			var hung := CharacterGearScript.hang_cape(cape, body) if not cape.is_empty() else {}
			var look := CharacterGearScript.hang_quiver(quiver, body, hung)
			var name := "over %s and a %s cape" % [body, hung.get("outline", "no")]
			for p in _quiver_axis(look):
				for box in under:
					if p.y < box.position.y or p.y > box.end.y or p.x + radius < box.position.x or p.x - radius > box.end.x:
						continue
					assert_true(p.z - radius >= box.end.z, "the quiver %s clears the body at y %.2f" % [name, p.y])
				assert_true(p.z - radius >= _cape_back(hung, p.y, p.x - radius) and p.z - radius >= _cape_back(hung, p.y, p.x + radius), "the quiver %s stands over the cape at y %.2f" % [name, p.y])


func test_the_quiver_is_clear_of_every_slung_tool() -> void:
	var quiver := GearLookScript.numbers({"shape": GearLookScript.SHAPE_QUIVER})
	var reach: float = quiver["radius"] + CharacterGearScript.HAFT_DEPTH
	for body in _bodies():
		for cape in _capes():
			var hung := CharacterGearScript.hang_cape(cape, body) if not cape.is_empty() else {}
			var axis := _quiver_axis(CharacterGearScript.hang_quiver(quiver, body, hung))
			for tool in ["steel_axe", "steel_pickaxe", "fishing_rod"]:
				var look := GearLookScript.piece(tool, GearLookScript.PART_TOOL)
				var from := CharacterGearScript.hang_sling(look, hung)
				var roll: float = look["sling_roll"]
				var length: float = look.get("slung_height", look.get("length", 1.0))
				var nearest := INF
				for i in 41:
					var t := from + Vector3(-sin(roll), cos(roll), 0) * (length * i / 40.0)
					for q in axis:
						nearest = minf(nearest, t.distance_to(q))
				assert_true(nearest >= reach, "the quiver over %s and a %s cape is clear of the slung %s (%.3f apart)" % [body, hung.get("outline", "no"), tool, nearest])
