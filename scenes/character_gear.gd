## The character's visible gear, placed by GearLayout from the equipment slots: the item in use
## in the hand (a bow in the left, a staff upright in the right), the tool slung on the back
## while the hands are free of it, each worn armour piece in its place (the helm on the
## head, the body on the chest, the legs on the hips and shins), the quiver on the back over the
## right shoulder and the cape behind the body, hung on the CharacterView's bone slots so it
## swings with the animation. While the view chops, mines or fishes, the tool
## moves to the right hand (the rod tipped forward over the water) and the weapon is put away.
## A piece shows because it is worn. What it draws, its colours, shape and numbers, comes from
## its GearLook entry (`scenes/gear_look.gd`), so progress reads at a glance from the top-down
## camera and a look is tuned there, not here.
##
## The armour shapes are static builders (`head_piece`, `body_piece`, `hips_piece`,
## `shin_piece`, `quiver_piece`, `cape_piece`) so the shader warm-up can draw one of every
## armour look (`samples`) before play; the node mounts them on the view. The barbarian's own
## cape is hidden while a body or a cape is worn.
##
## The back is worn in layers: the body piece, then the cape over it, then the quiver and the
## slung tool over both. Each layer keeps its look's place when nothing is under it and is moved
## back just far enough to stand clear of what is (`hang_cape`, `hang_quiver`, `hang_sling`),
## so any cape hangs over any body piece and any quiver over any cape, whatever their sets.
##
## The kit builders (`peaked_hood`, `under_robe`, `cloak`, `collar`, `stacked_plates`,
## `crystal`, `fin`, `prism_stack`, `studs`, `edge_trim`, `quiver`, `sash`, `ruff`, `faulds`,
## `tassets`, `seam`, `shard_crown`, `antlers`, `plumes`, `broadsword`, `bearded_axe`,
## `greatsword`, `forge_hammer`, `glaive`, `cleaver`, `longbow`) are the layered, non-round shapes the set
## looks are built from. Each takes a look (its shape's numbers, from `GearLook.numbers` or
## `GearLook.piece`) and a palette, names its root after its shape, and draws at least two
## tones (a base plus a darker underside or a lighter trim) so it reads lit from above. Which
## palette field a part takes is the look's tone number (`tone`, `edge_tone`...), or a Color
## of the look's own. A look's `glow` above 0 draws the builder's highlight in the palette's
## glow colour, shining that bright, through `Props.flat`. A crystal, a shard crown or a forge
## hammer carries the one small light and the few motes a top set is allowed (`_glow_fx`), and
## only when its look asks for them.
##
## A piece's `layers` are built the same way and added under its root, so a set helm is a
## helm with studs, cheek guards and a crest layered on from its one entry; no builder knows
## a set's numbers.
##
## Presentation only: GameRoot hands it the equipment slots from the state after every
## `equipped` event and on load. The slots come lazily from a sibling CharacterView, so the
## gear node may be added before or after the view.
extends Node3D

## The names of the armour shape nodes, so a test can tell which shape a slot drew.
const SHAPE_HELM := GearLook.SHAPE_HELM
const SHAPE_FUR_HOOD := GearLook.SHAPE_FUR_HOOD
const SHAPE_VEST := GearLook.SHAPE_VEST
const SHAPE_FUR_COAT := GearLook.SHAPE_FUR_COAT
const SHAPE_KILT := GearLook.SHAPE_KILT
const SHAPE_FUR_LEGGINGS := GearLook.SHAPE_FUR_LEGGINGS
const SHAPE_GREAVE := GearLook.SHAPE_GREAVE
const SHAPE_FUR_BAND := GearLook.SHAPE_FUR_BAND
const SHAPE_PEAKED_HOOD := GearLook.SHAPE_PEAKED_HOOD
const SHAPE_UNDER_ROBE := GearLook.SHAPE_UNDER_ROBE
const SHAPE_CLOAK := GearLook.SHAPE_CLOAK
const SHAPE_COLLAR := GearLook.SHAPE_COLLAR
const SHAPE_STACKED_PLATES := GearLook.SHAPE_STACKED_PLATES
const SHAPE_CRYSTAL := GearLook.SHAPE_CRYSTAL
const SHAPE_FIN := GearLook.SHAPE_FIN
const SHAPE_PRISM_STACK := GearLook.SHAPE_PRISM_STACK
const SHAPE_STUDS := GearLook.SHAPE_STUDS
const SHAPE_EDGE_TRIM := GearLook.SHAPE_EDGE_TRIM
const SHAPE_QUIVER := GearLook.SHAPE_QUIVER
## The bone slot the quiver and the cape hang from, the body's and the slung tool's own.
const QUIVER_SLOT := "chest"
const CAPE_SLOT := "chest"
## How far apart two layers on the back stand, and how many points along a piece are checked.
const BACK_GAP := 0.02
const CLEAR_STEPS := 8
## How far a slung tool's haft stands proud of its sling line toward the back it lies on.
const HAFT_DEPTH := 0.04
const SHAPE_SASH := GearLook.SHAPE_SASH
const SHAPE_RUFF := GearLook.SHAPE_RUFF
const SHAPE_FAULDS := GearLook.SHAPE_FAULDS
const SHAPE_TASSETS := GearLook.SHAPE_TASSETS
const SHAPE_BROADSWORD := GearLook.SHAPE_BROADSWORD
const SHAPE_BEARDED_AXE := GearLook.SHAPE_BEARDED_AXE
const SHAPE_GREATSWORD := GearLook.SHAPE_GREATSWORD
const SHAPE_SEAM := GearLook.SHAPE_SEAM
const SHAPE_SHARD_CROWN := GearLook.SHAPE_SHARD_CROWN
const SHAPE_ANTLERS := GearLook.SHAPE_ANTLERS
const SHAPE_FORGE_HAMMER := GearLook.SHAPE_FORGE_HAMMER
const SHAPE_GLAIVE := GearLook.SHAPE_GLAIVE
const SHAPE_CLEAVER := GearLook.SHAPE_CLEAVER
const SHAPE_LONGBOW := GearLook.SHAPE_LONGBOW
const SHAPE_PLUMES := GearLook.SHAPE_PLUMES
## The names of a two-sided builder's side nodes, so a test can measure each side.
const SIDE_LEFT := "Left"
const SIDE_RIGHT := "Right"
## The names of the glow nodes a crystal, a shard crown or a forge hammer carries when its look
## asks for them.
const GLOW_LIGHT := "Light"
const GLOW_MOTES := "Motes"

var _shown := {}  # place -> what is drawn there (`_draw_key`)
var _pieces := {}  # place -> the nodes drawn for it, to free when it changes
var _equipment := {}
var _view: CharacterView


func _init() -> void:
	for place in GearLayout.PLACES:
		_shown[place] = null
		_pieces[place] = []
	set_process(false)


## Redraws whichever places changed since the last call.
func show_equipment(equipment: Dictionary) -> void:
	_equipment = equipment.duplicate()
	_redraw()


## Follows the view into and out of work, so the tool changes hands with the clip.
func _process(_delta: float) -> void:
	_redraw()


func _redraw() -> void:
	var view := _find_view()
	if view == null:
		set_process(true)  # waiting for the CharacterView to turn up
		return
	var layout := GearLayout.place(_equipment, view.is_working())
	for place in GearLayout.PLACES:
		var item: String = layout[place]
		var key := _draw_key(place, layout)
		if _shown[place] == key:
			continue
		_shown[place] = key
		for node in _pieces[place]:
			(node as Node).queue_free()
		_pieces[place] = []
		if place == GearLayout.BODY or place == GearLayout.CAPE:
			# The barbarian's cape would hide the vest, and would hang through a worn cape.
			view.set_part_visible("Barbarian_Cape", layout[GearLayout.BODY] == "" and layout[GearLayout.CAPE] == "")
		if item == "" or not ItemTable.has(item):
			continue
		match place:
			GearLayout.HAND:
				if ItemTable.ITEMS[item]["slot"] == ItemTable.SLOT_TOOL:
					_build_held_tool(view, place, item)
				else:
					_build_weapon(view, place, item)
			GearLayout.HEAD:
				_build_helm(view, place, item)
			GearLayout.BODY:
				_build_body(view, place, item)
			GearLayout.LEGS:
				_build_legs(view, place, item)
			GearLayout.BACK:
				_build_slung_tool(view, place, item, layout)
			GearLayout.QUIVER:
				var quiver := quiver_piece(item, layout[GearLayout.BODY], layout[GearLayout.CAPE])
				_mount(view, place, QUIVER_SLOT).add_child(quiver)
			GearLayout.CAPE:
				_mount(view, place, CAPE_SLOT).add_child(cape_piece(item, layout[GearLayout.BODY]))
	set_process(_equipment.get(ItemTable.SLOT_TOOL, "") != "")


## What a place's drawing depends on: its item and, for a layer on the back, the layers under
## it, so it is redrawn to stand clear when one of them changes.
static func _draw_key(place: String, layout: Dictionary) -> String:
	match place:
		GearLayout.CAPE:
			return "%s|%s" % [layout[place], layout[GearLayout.BODY]]
		GearLayout.QUIVER, GearLayout.BACK:
			return "%s|%s|%s" % [layout[place], layout[GearLayout.BODY], layout[GearLayout.CAPE]]
	return layout[place]


func _find_view() -> CharacterView:
	if _view != null and is_instance_valid(_view):
		return _view
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is CharacterView:
			_view = child
			return _view
	return null


## A node in the view's `slot_name` mount frame, remembered under `place` so it goes when the
## item does.
func _mount(view: CharacterView, place: String, slot_name: String) -> Node3D:
	var holder := view.mount(slot_name)
	_pieces[place].append(holder)
	return holder


func _build_weapon(view: CharacterView, place: String, item: String) -> void:
	var look := GearLook.piece(item, GearLook.PART_WEAPON)
	var colours := GearLook.palette(item)
	match look["shape"]:
		GearLook.SHAPE_BOW:
			_mount(view, place, "handslot_l").add_child(Figures.bow(colours["base"], look["length"]))
			return
		GearLook.SHAPE_STAFF:
			var staff := Figures.staff(colours["base"], look["length"], colours["glow"], colours["glow_energy"])
			_mount(view, place, "handslot_r").add_child(staff)
			return
		GearLook.SHAPE_CLUB:
			_mount(view, place, "handslot_r").add_child(Figures.club(colours["base"]))
			return
	if GearLook.WEAPON_SHAPES.has(look["shape"]):
		# a kit bow goes in the left hand like the tier bows, the rest in the right
		_mount(view, place, "handslot_l" if GearLook.BOW_SHAPES.has(look["shape"]) else "handslot_r").add_child(weapon_piece(item))
		return
	var hand := view.bone_slot("handslot_r")
	if hand == null:
		return
	var sword := Figures.sword(colours["base"], look["length"], view.model_scale())
	hand.add_child(sword)
	_pieces[place].append(sword)


func _build_body(view: CharacterView, place: String, item: String) -> void:
	_mount(view, place, "chest").add_child(body_piece(item))


func _build_helm(view: CharacterView, place: String, item: String) -> void:
	_mount(view, place, "head").add_child(head_piece(item))


func _build_legs(view: CharacterView, place: String, item: String) -> void:
	_mount(view, place, "hips").add_child(hips_piece(item))
	for side in ["l", "r"]:
		var shin := shin_piece(item)
		if shin == null:
			return
		_mount(view, place, "lowerleg_" + side).add_child(shin)


## What `item` draws on the head: a helm or a fur hood, with its layers.
static func head_piece(item: String) -> Node3D:
	return _part_piece(item, GearLook.PART_HEAD)


## What `item` draws on the chest: a vest or a fur coat, with its layers.
static func body_piece(item: String) -> Node3D:
	return _part_piece(item, GearLook.PART_BODY)


## What `item` draws on the hips: a kilt or fur leggings, with its layers.
static func hips_piece(item: String) -> Node3D:
	return _part_piece(item, GearLook.PART_HIPS)


## What `item` draws on each shin: a greave, a fur band, or null for a bare shin.
static func shin_piece(item: String) -> Node3D:
	if GearLook.piece(item, GearLook.PART_SHIN).is_empty():
		return null
	return _part_piece(item, GearLook.PART_SHIN)


## What `item` draws in the hand when its weapon is a kit shape (a broadsword, a bearded axe,
## a greatsword, a forge hammer, a glaive, a cleaver, a longbow), or null for a weapon drawn
## from a model (a sword, a bow, a staff, a club).
static func weapon_piece(item: String) -> Node3D:
	var look := GearLook.piece(item, GearLook.PART_WEAPON)
	if not GearLook.WEAPON_SHAPES.has(look["shape"]):
		return null
	return _part_piece(item, GearLook.PART_WEAPON)


## The piece `item` draws on `part`: its shape built from its look in its palette, with each
## of the look's layers built the same way under it.
static func _part_piece(item: String, part: String) -> Node3D:
	var look := GearLook.piece(item, part)
	var colours := GearLook.palette(item)
	var root: Node3D = builder(look["shape"]).call(look, colours)
	for layer in GearLook.layers(look):
		root.add_child(builder(layer["shape"]).call(layer, colours))
	return root


## The builder for any shape in the look table: a kit builder, or one of the tier and fur
## shapes. Every builder takes a look and a palette.
static func builder(shape: String) -> Callable:
	var kit := kit_builder(shape)
	if kit.is_valid():
		return kit
	match shape:
		SHAPE_HELM:
			return _helm
		SHAPE_FUR_HOOD:
			return _fur_hood
		SHAPE_VEST:
			return _vest
		SHAPE_FUR_COAT:
			return _fur_coat
		SHAPE_FUR_BAND:
			return _banded_wrap
	return func(look: Dictionary, colours: Dictionary) -> Node3D: return _wrap(shape, look, _tone(look, colours, "tone"))


## What `item` draws on the back over the right shoulder: a quiver, standing clear of the body
## item and the cape item worn under it ("" for none).
static func quiver_piece(item: String, body := "", cape := "") -> Node3D:
	var hung := hang_cape(GearLook.piece(cape, GearLook.PART_CAPE), body) if cape != "" else {}
	return quiver(hang_quiver(GearLook.piece(item, GearLook.PART_QUIVER), body, hung), GearLook.palette(item))


## What `item` draws hung behind the body: a cloak, standing clear of the body item worn under
## it ("" for none).
static func cape_piece(item: String, body := "") -> Node3D:
	return cloak(hang_cape(GearLook.piece(item, GearLook.PART_CAPE), body), GearLook.palette(item))


## A cloak `look` moved back just far enough that, leaning `tilt` back from its `offset`, it
## stands clear of what `body` draws on the chest from its top to its hem.
static func hang_cape(look: Dictionary, body: String) -> Dictionary:
	var tilt: float = look["tilt"]
	var length: float = maxf(look["length_left"], look["length_right"])
	var shift := _clearance(look["offset"], Vector3(0, -cos(tilt), sin(tilt)), length, look["thickness"] * 0.5, look["width"] * 0.5, _body_bounds(body))
	var out := look.duplicate()
	out["offset"] = (look["offset"] as Vector3) + Vector3(0, 0, shift)
	return out


## A quiver `look` moved back just far enough that its case stands clear of what `body` draws
## on the chest and of `cape`, a cape look already hung (`hang_cape`), or {} for none.
static func hang_quiver(look: Dictionary, body: String, cape: Dictionary) -> Dictionary:
	var under := _body_bounds(body)
	under.append_array(_cape_bounds(cape))
	var axis := Basis.from_euler(look["tilt"]) * Vector3.UP
	var tip: float = look["tip_length"]
	var radius: float = look["radius"]
	var shift := _clearance(look["offset"], axis, look["length"] + tip, radius, radius, under)
	var out := look.duplicate()
	out["offset"] = (look["offset"] as Vector3) + Vector3(0, 0, shift)
	return out


## Where a tool look's sling sits: its own `sling_offset`, moved back just far enough that the
## tool, slung `slung_height` long up its `sling_roll`, lies over `cape`, a cape look already
## hung, or {} for none.
static func hang_sling(look: Dictionary, cape: Dictionary) -> Vector3:
	var roll: float = look["sling_roll"]
	var height: float = look.get("slung_height", look.get("length", 1.0))
	var shift := _clearance(look["sling_offset"], Vector3(-sin(roll), cos(roll), 0), height, HAFT_DEPTH, HAFT_DEPTH, _cape_bounds(cape))
	return (look["sling_offset"] as Vector3) + Vector3(0, 0, shift)


## How far a straight piece must move back (+Z) to stand clear of every box in `under`: it runs
## `length` from `from` along `dir`, reaching `depth` toward the back it lies on and `half_width`
## to either side, and is checked at CLEAR_STEPS + 1 points along its length.
static func _clearance(from: Vector3, dir: Vector3, length: float, depth: float, half_width: float, under: Array[AABB]) -> float:
	var shift := 0.0
	for i in CLEAR_STEPS + 1:
		var p := from + dir * (length * i / CLEAR_STEPS)
		for box in under:
			if p.y < box.position.y or p.y > box.end.y:
				continue
			if p.x + half_width < box.position.x or p.x - half_width > box.end.x:
				continue
			shift = maxf(shift, box.end.z + BACK_GAP + depth - p.z)
	return shift


## The bounds of every part `body` draws on the chest, in the chest mount's frame, or none for "".
static func _body_bounds(body: String) -> Array[AABB]:
	if body == "":
		return []
	var piece := body_piece(body)
	var out := mesh_bounds(piece)
	piece.free()
	return out


## A hung cape look as boxes down its length, each as deep as the cloak (twice that, for a tail
## or banner set behind it), or none for {}.
static func _cape_bounds(cape: Dictionary) -> Array[AABB]:
	var out: Array[AABB] = []
	if cape.is_empty():
		return out
	var tilt: float = cape["tilt"]
	var length: float = maxf(cape["length_left"], cape["length_right"])
	var half: float = cape["width"] * 0.5
	var depth: float = cape["thickness"] * (2.0 if cape["outline"] in [GearLook.OUTLINE_TAIL, GearLook.OUTLINE_BANNER] else 1.0)
	var top: Vector3 = cape["offset"]
	var dir := Vector3(0, -cos(tilt), sin(tilt))
	for i in CLEAR_STEPS:
		var a := top + dir * (length * i / CLEAR_STEPS)
		var b := top + dir * (length * (i + 1) / CLEAR_STEPS)
		out.append(AABB(Vector3(-half, b.y, a.z - depth * 0.5), Vector3(half * 2.0, a.y - b.y, b.z - a.z + depth)))
	return out


## The bounds of every mesh under `node`, in `node`'s frame.
static func mesh_bounds(node: Node3D) -> Array[AABB]:
	var out: Array[AABB] = []
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var n: Node = mesh
		while n != node:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		out.append(t * (mesh as MeshInstance3D).mesh.get_aabb())
	return out


## A dome over the crown, with a band round its rim and a nose guard when the look has them.
static func _helm(look: Dictionary, colours: Dictionary) -> Node3D:
	var head := Node3D.new()
	head.name = SHAPE_HELM
	Figures.part(head, _dome(look, _tone(look, colours, "tone")), Vector3(0, look["y"], 0))
	if look["band"]:
		Figures.part(head, _cylinder(look["band_radius"], look["band_radius"], look["band_height"], look["segments"], _tone(look, colours, "band_tone")), Vector3(0, look["band_y"], 0))
	if look["nose_guard"]:
		Figures.part(head, _box(look["nose_size"], _tone(look, colours, "nose_tone")), look["nose_offset"])
	return head


## A rounded hood: a full round crown, a drape down the back of the head and a pale hoop
## framing the face.
static func _fur_hood(look: Dictionary, colours: Dictionary) -> Node3D:
	var hood := Node3D.new()
	hood.name = SHAPE_FUR_HOOD
	var tone := _tone(look, colours, "tone")
	Figures.part(hood, _dome(look, tone), Vector3(0, look["y"], 0))
	var back := Figures.part(hood, _dome(look, tone), look["drape_offset"])
	back.rotation.x = PI * 0.5  # the dome points behind the head, down the neck
	var hoop := _torus(look["hoop_inner"], look["hoop_outer"], look["hoop_rings"], look["hoop_segments"], _tone(look, colours, "hoop_tone"))
	var face := Figures.part(hood, hoop, look["hoop_offset"])
	face.rotation.x = PI * 0.5  # a hoop framing the face, flush with the crown's front edge
	return hood


## A vest round the chest, with a pad on each shoulder when the look has pauldrons.
static func _vest(look: Dictionary, colours: Dictionary) -> Node3D:
	var chest := _wrap(SHAPE_VEST, look, _tone(look, colours, "tone"))
	if look["pauldrons"]:
		for side in [-1, 1]:
			var pad := Figures.part(chest, _box(look["pauldron_size"], _tone(look, colours, "pauldron_tone")), Vector3(side * look["pauldron_x"], look["pauldron_y"], 0))
			pad.rotation.z = side * -look["pauldron_tilt"]
	return chest


## A coat: a bulky body flaring to the hem, a thick pale collar ruff and a pale hem.
static func _fur_coat(look: Dictionary, colours: Dictionary) -> Node3D:
	var coat := _wrap(SHAPE_FUR_COAT, look, _tone(look, colours, "tone"))
	var trim := _tone(look, colours, "trim_tone")
	Figures.part(coat, _torus(look["ruff_inner"], look["ruff_outer"], look["ruff_rings"], look["ruff_segments"], trim), Vector3(0, look["ruff_y"], 0))
	Figures.part(coat, _cylinder(look["hem_radius"], look["hem_radius"], look["hem_height"], look["segments"], trim), Vector3(0, look["hem_y"], 0))
	return coat


## A wrap down the shin with a thick band at its top: a fur band, a greave with a rim.
static func _banded_wrap(look: Dictionary, colours: Dictionary) -> Node3D:
	var shin := _wrap(SHAPE_FUR_BAND, look, _tone(look, colours, "tone"))
	Figures.part(shin, _cylinder(look["band_radius"], look["band_radius"], look["band_height"], look["segments"], _tone(look, colours, "band_tone")), Vector3(0, look["band_y"], 0))
	return shin


## A node named `shape` holding one cylinder from the look's radii, height and segments, `y`
## down its frame: a vest, a kilt, leggings, a greave or a shin's wrap.
static func _wrap(shape: String, look: Dictionary, colour: Variant) -> Node3D:
	var root := Node3D.new()
	root.name = shape
	Figures.part(root, _cylinder(look["top_radius"], look["bottom_radius"], look["height"], look["segments"], colour), Vector3(0, look["y"], 0))
	return root


## A cylinder drawn in `look`: a Color, or a material already made (a highlight).
static func _cylinder(top: float, bottom: float, height: float, segments: int, look: Variant) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.material = look if look is Material else Props.flat(look)
	return mesh


## A dome drawn in `look`: a Color, or a material already made.
static func _dome(numbers: Dictionary, look: Variant) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = numbers["radius"]
	mesh.height = numbers["height"]
	mesh.radial_segments = numbers["segments"]
	mesh.rings = numbers["rings"]
	mesh.is_hemisphere = true
	mesh.material = look if look is Material else Props.flat(look)
	return mesh


## A torus drawn in `look`: a Color, or a material already made (a highlight).
static func _torus(inner: float, outer: float, rings: int, segments: int, look: Variant) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = rings
	mesh.ring_segments = segments
	mesh.material = look if look is Material else Props.flat(look)
	return mesh

## The kit builder for `shape`, or an invalid Callable for a shape that is not a kit shape.
static func kit_builder(shape: String) -> Callable:
	match shape:
		SHAPE_PEAKED_HOOD:
			return peaked_hood
		SHAPE_UNDER_ROBE:
			return under_robe
		SHAPE_CLOAK:
			return cloak
		SHAPE_COLLAR:
			return collar
		SHAPE_STACKED_PLATES:
			return stacked_plates
		SHAPE_CRYSTAL:
			return crystal
		SHAPE_FIN:
			return fin
		SHAPE_PRISM_STACK:
			return prism_stack
		SHAPE_STUDS:
			return studs
		SHAPE_EDGE_TRIM:
			return edge_trim
		SHAPE_QUIVER:
			return quiver
		SHAPE_SASH:
			return sash
		SHAPE_RUFF:
			return ruff
		SHAPE_FAULDS:
			return faulds
		SHAPE_TASSETS:
			return tassets
		SHAPE_BROADSWORD:
			return broadsword
		SHAPE_BEARDED_AXE:
			return bearded_axe
		SHAPE_GREATSWORD:
			return greatsword
		SHAPE_SEAM:
			return seam
		SHAPE_SHARD_CROWN:
			return shard_crown
		SHAPE_ANTLERS:
			return antlers
		SHAPE_FORGE_HAMMER:
			return forge_hammer
		SHAPE_GLAIVE:
			return glaive
		SHAPE_CLEAVER:
			return cleaver
		SHAPE_LONGBOW:
			return longbow
		SHAPE_PLUMES:
			return plumes
	return Callable()


## One of each kit shape, built from its GearLook.KIT_SAMPLES look in the kit palette.
static func kit_samples() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for own in GearLook.KIT_SAMPLES:
		out.append(kit_builder(own["shape"]).call(GearLook.numbers(own), GearLook.KIT))
	return out


## A hood crown with a peak fin swept back from its top (the head is a teardrop from above,
## not a disc), a drape down the neck in the dark tone and a hoop trimming the face opening.
static func peaked_hood(look: Dictionary, colours: Dictionary) -> Node3D:
	var hood := Node3D.new()
	hood.name = SHAPE_PEAKED_HOOD
	var tone := _tone(look, colours, "tone")
	Figures.part(hood, _dome(look, tone), Vector3(0, look["y"], 0))
	var peak := Node3D.new()
	peak.position = look["peak_offset"]
	peak.rotation.x = look["peak_tilt"]  # the fin's tip sweeps up and back
	hood.add_child(peak)
	var spike := Figures.part(peak, _cone(look["peak_width"] * 0.5, look["peak_length"], 4, tone), Vector3(0, look["peak_length"] * 0.5, 0))
	spike.scale.x = 0.5  # a fin, not a horn
	var drape := Figures.part(hood, _cylinder(look["drape_radius"], look["drape_radius"] * 0.9, look["drape_height"], look["segments"], _tone(look, colours, "drape_tone")), look["drape_offset"])
	drape.rotation.x = PI * 0.5  # the drape points behind the head, down the neck
	var hoop := _torus(look["hoop_inner"], look["hoop_outer"], look["hoop_rings"], look["hoop_segments"], _highlight(look, colours, "hoop_tone"))
	var face := Figures.part(hood, hoop, look["hoop_offset"])
	face.rotation.x = PI * 0.5  # a hoop framing the face, flush with the crown's front edge
	return hood


## A flaring under-robe in the dark tone under a coat shell set back so the robe shows at the
## open front, two front panels hanging from the coat's hem each its own length (`Left` and
## `Right`), and bands up the robe from its hem in the highlight.
static func under_robe(look: Dictionary, colours: Dictionary) -> Node3D:
	var robe := _wrap(SHAPE_UNDER_ROBE, look, _tone(look, colours, "robe_tone"))
	var tone := _tone(look, colours, "tone")
	Figures.part(robe, _cylinder(look["coat_top_radius"], look["coat_bottom_radius"], look["coat_height"], look["segments"], tone), Vector3(0, look["coat_y"], look["coat_back"]))
	for side in [[-1, SIDE_LEFT, look["panel_left"]], [1, SIDE_RIGHT, look["panel_right"]]]:
		var panel := Node3D.new()
		panel.name = side[1]
		panel.position = Vector3(side[0] * look["panel_x"], look["panel_top"], look["panel_z"])
		panel.rotation.z = side[0] * -look["panel_flare"]  # the panels hang apart at the hem
		panel.rotation.x = -look["panel_lean"]  # and lean forward, clear of the robe's flare
		robe.add_child(panel)
		var length: float = side[2]
		Figures.part(panel, _box(Vector3(look["panel_width"], length, look["panel_thickness"]), tone), Vector3(0, -length * 0.5, 0))
	var top: float = look["y"] + look["height"] * 0.5
	var band := _highlight(look, colours, "band_tone")
	for i in int(look["bands"]):
		var y: float = look["band_from"] + i * look["band_step"]
		var radius: float = lerpf(look["top_radius"], look["bottom_radius"], clampf((top - y) / look["height"], 0.0, 1.0)) + 0.012
		Figures.part(robe, _cylinder(radius, radius, look["band_height"], look["segments"], band), Vector3(0, y, 0))
	return robe


## A fin hung from the shoulders behind the body the way the barbarian's cape hangs, in two
## halves (`Left` and `Right`) each its own length, leaning `tilt` back. Its `outline` is
## plain (a hem band across each half), forked (the halves part in a V), torn (a ragged hem of
## dark teeth), tail (a long centre tail) or banner (a narrow panel on a pole over the
## shoulders). `lining` above 0 draws a `lining_tone` lining behind each half, showing that
## much round its edges.
static func cloak(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_CLOAK
	var hang := Node3D.new()
	hang.position = look["offset"]
	hang.rotation.x = -look["tilt"]  # the hem swings out behind
	root.add_child(hang)
	var outline: String = look["outline"]
	var half: float = look["width"] * 0.5
	var thickness: float = look["thickness"]
	var hem := _highlight(look, colours, "hem_tone")
	var tone := _tone(look, colours, "tone")
	var tooth_tone := _tone(look, colours, "tooth_tone")
	var lining: float = look["lining"]
	for side in [[-1, SIDE_LEFT, look["length_left"]], [1, SIDE_RIGHT, look["length_right"]]]:
		var panel := Node3D.new()
		panel.name = side[1]
		hang.add_child(panel)
		if outline == GearLook.OUTLINE_FORKED:
			panel.rotation.z = side[0] * look["fork"]  # each half swings out from the centre line
		var length: float = side[2]
		Figures.part(panel, _box(Vector3(half, length, thickness), tone), Vector3(side[0] * half * 0.5, -length * 0.5, 0))
		if lining > 0.0:
			# wider and longer than the half and thinner, so it shows as a rim round its edges
			Figures.part(panel, _box(Vector3(half + lining, length + lining, thickness * 0.6), _tone(look, colours, "lining_tone")), Vector3(side[0] * (half + lining) * 0.5, -(length + lining) * 0.5, 0))
		if outline == GearLook.OUTLINE_TORN:
			var teeth := int(look["teeth"])
			for i in teeth:
				var tooth := Figures.part(panel, _cone(look["tooth"] * 0.4, look["tooth"], 4, tooth_tone), Vector3(side[0] * half * (i + 0.5) / teeth, -length - look["tooth"] * 0.5, 0))
				tooth.rotation.x = PI  # the points hang down
		else:
			Figures.part(panel, _box(Vector3(half, look["hem"], thickness + 0.01), hem), Vector3(side[0] * half * 0.5, -length + look["hem"] * 0.5, 0))
	match outline:
		GearLook.OUTLINE_TAIL:
			var length: float = maxf(look["length_left"], look["length_right"]) + look["tail_length"]
			Figures.part(hang, _box(Vector3(look["tail_width"], length, thickness), tone), Vector3(0, -length * 0.5, thickness * 0.5))
			Figures.part(hang, _box(Vector3(look["tail_width"], look["hem"], thickness + 0.01), hem), Vector3(0, -length + look["hem"] * 0.5, thickness * 0.5))
		GearLook.OUTLINE_BANNER:
			var rise: float = look["banner_rise"]
			Figures.part(hang, _cylinder(0.02, 0.02, rise + 0.2, 6, tooth_tone), Vector3(0, rise * 0.5 - 0.1, thickness))
			Figures.part(hang, _box(Vector3(look["banner_width"], rise, thickness), tone), Vector3(look["banner_width"] * 0.5, rise * 0.5, thickness))
			Figures.part(hang, _box(Vector3(look["banner_width"], look["hem"], thickness + 0.01), hem), Vector3(look["banner_width"] * 0.5, rise - look["hem"] * 0.5, thickness))
	return root


## An upright plate behind the neck leaning `tilt` back over a dark backing, with its top edge
## in the highlight: a high collar, a jagged collar with `teeth` points along its top, a
## wider thicker stone back-plate, or an upright hoop with `teeth` fins on its rim.
static func collar(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_COLLAR
	var stand := Node3D.new()
	stand.position = look["offset"]
	stand.rotation.x = look["tilt"]  # the top leans back from the neck
	root.add_child(stand)
	var kind: String = look["kind"]
	var width: float = look["width"]
	var height: float = look["height"]
	var thickness: float = look["thickness"]
	var top := _highlight(look, colours, "edge_tone")
	var tone := _tone(look, colours, "tone")
	var teeth := int(look["teeth"])
	if kind == GearLook.COLLAR_HOOP:
		var ring := Figures.part(stand, _torus(look["hoop_inner"], look["hoop_outer"], look["hoop_rings"], look["hoop_segments"], tone), Vector3(0, look["hoop_outer"], 0))
		ring.rotation.x = PI * 0.5  # the hoop stands up behind the head
		var mid: float = (look["hoop_inner"] + look["hoop_outer"]) * 0.5
		for i in teeth:
			var a := PI * 0.5 + (i - (teeth - 1) * 0.5) * (PI * 0.8 / maxf(teeth - 1, 1))
			var flame := Figures.part(stand, _cone(look["tooth"] * 0.3, look["tooth"], 4, top), Vector3(cos(a) * mid, look["hoop_outer"] + sin(a) * mid, 0))
			flame.rotation.z = a - PI * 0.5  # each fin points out along the rim
		return root
	if kind == GearLook.COLLAR_PLATE:
		width *= 1.2
		thickness *= 2.0
	Figures.part(stand, _box(Vector3(width, height, thickness), tone), Vector3(0, height * 0.5, 0))
	Figures.part(stand, _box(Vector3(width + 0.04, height - 0.02, thickness), _tone(look, colours, "back_tone")), Vector3(0, height * 0.5 - 0.01, thickness))
	if kind == GearLook.COLLAR_JAGGED:
		for i in teeth:
			Figures.part(stand, _cone(look["tooth"] * 0.4, look["tooth"], 4, top), Vector3(width * ((i + 0.5) / teeth - 0.5), height + look["tooth"] * 0.5, 0))
	else:
		Figures.part(stand, _box(Vector3(width, 0.04, thickness + 0.02), top), Vector3(0, height, 0))
	return root


## Two or three plates on each shoulder (`Left` and `Right`): the top plate in `tone`, each
## lower one in `under_tone`, `step` further out and down and `grow` larger, with the
## highlight along the top plate's outer edge. Each side has its own count and size. `round`
## plates are domes, the highlight a hoop round the top one's foot.
static func stacked_plates(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_STACKED_PLATES
	var edge := _highlight(look, colours, "trim_tone")
	var top := _tone(look, colours, "tone")
	var under := _tone(look, colours, "under_tone")
	var round: bool = look["round"]
	for side in [[-1, SIDE_LEFT, look["plates_left"], look["size_left"]], [1, SIDE_RIGHT, look["plates_right"], look["size_right"]]]:
		var s: int = side[0]
		var shoulder := Node3D.new()
		shoulder.name = side[1]
		shoulder.position = Vector3(s * look["x"], look["y"], 0)
		shoulder.rotation.z = s * -look["tilt"]  # the plates slope down the arm
		root.add_child(shoulder)
		var size: Vector3 = side[3]
		var step: Vector3 = look["step"]
		for i in int(side[2]):
			var plate_size: Vector3 = size * (1.0 + float(look["grow"]) * i)
			var colour: Variant = top if i == 0 else under
			var at := Vector3(s * step.x * i, step.y * i, step.z * i)
			if round:
				var dome := SphereMesh.new()
				dome.radius = plate_size.x * 0.5
				dome.height = plate_size.y * 2.0
				dome.radial_segments = 8
				dome.rings = 3
				dome.is_hemisphere = true
				dome.material = colour if colour is Material else Props.flat(colour)
				Figures.part(shoulder, dome, at)
			else:
				Figures.part(shoulder, _box(plate_size, colour), at)
		var trim: float = look["trim"]
		if round:
			Figures.part(shoulder, _torus(size.x * 0.5 - trim, size.x * 0.5 + trim * 0.5, 8, 4, edge), Vector3.ZERO)
		else:
			Figures.part(shoulder, _box(Vector3(trim, trim, size.z + 0.01), edge), Vector3(s * (size.x - trim) * 0.5, (size.y + trim) * 0.5, 0))
	return root


## A prism with `facets` sides: its tip in the glow colour shining at `glow` over a dark root,
## at `offset` turned by `tilt`. `light` adds the one small light a piece may carry, at the
## tip, and `motes` a few glowing motes drifting up round it.
static func crystal(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_CRYSTAL
	var stand := Node3D.new()
	stand.position = look["offset"]
	stand.rotation = look["tilt"]
	root.add_child(stand)
	var length: float = look["length"]
	var join: float = length * look["root"]
	var facets := int(look["facets"])
	var colour: Color = colours["glow"]
	var glow: float = look["glow"]
	Figures.part(stand, _cone(look["radius"], length - join, facets, Props.flat(colour, glow)), Vector3(0, join + (length - join) * 0.5, 0))
	Figures.part(stand, _cylinder(look["radius"], look["radius"] * 0.5, join, facets, _tone(look, colours, "root_tone")), Vector3(0, join * 0.5, 0))
	_glow_fx(stand, look, colour, glow, join)
	return root


## The one small light and the few motes a top set's piece may carry, each only when `look`
## asks (`light`, `motes`), hung under `stand` at `y` in `colour` (the palette's glow): a warm
## point that lights the snow round the wearer, and `motes_count` glowing specks drifting up
## from a sphere of `motes_radius` round the piece, as bright as `glow` or brighter.
static func _glow_fx(stand: Node3D, look: Dictionary, colour: Color, glow: float, y: float) -> void:
	if look["light"]:
		var light := OmniLight3D.new()
		light.name = GLOW_LIGHT
		light.light_color = colour
		light.light_energy = look["light_energy"]
		light.omni_range = look["light_range"]
		light.omni_attenuation = 1.3
		light.position.y = y
		stand.add_child(light)
	if look["motes"]:
		var motes := CPUParticles3D.new()
		motes.name = GLOW_MOTES
		motes.amount = int(look["motes_count"])
		motes.lifetime = 2.0
		motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		motes.emission_sphere_radius = look["motes_radius"]
		motes.direction = Vector3.UP
		motes.spread = 30.0
		motes.gravity = Vector3.ZERO
		motes.initial_velocity_min = look["motes_rise"] * 0.5
		motes.initial_velocity_max = look["motes_rise"]
		motes.scale_amount_min = 0.4
		motes.scale_amount_max = 1.0
		var mote := BoxMesh.new()
		mote.size = Vector3.ONE * look["motes_size"]
		mote.material = Props.flat(colour, maxf(glow, 1.0))
		motes.mesh = mote
		motes.position.y = y
		stand.add_child(motes)


## A thin flat plate standing up from its root at `offset`, turned by `tilt`: `size` wide,
## long and thick, with the highlight along its tip edge, or `teeth` points there when
## `jagged`. Crests, wings, ears, banners, masks, feathers and pelt flaps.
static func fin(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_FIN
	var stand := Node3D.new()
	stand.position = look["offset"]
	stand.rotation = look["tilt"]
	root.add_child(stand)
	var size: Vector3 = look["size"]
	Figures.part(stand, _box(size, _tone(look, colours, "tone")), Vector3(0, size.y * 0.5, 0))
	var edge := _highlight(look, colours, "edge_tone")
	if look["jagged"]:
		var teeth := int(look["teeth"])
		for i in teeth:
			Figures.part(stand, _cone(look["tooth"] * 0.4, look["tooth"], 4, edge), Vector3(size.x * ((i + 0.5) / teeth - 0.5), size.y + look["tooth"] * 0.5, 0))
	else:
		Figures.part(stand, _box(Vector3(size.x, look["edge"], size.z + 0.01), edge), Vector3(0, size.y, 0))
	return root


## `count` prisms stacked end to end from `offset`, each `bend` further round and `taper` as
## wide as the one below, from a dark root through the base tone to an accent tip (the glow
## colour, lit, when `glow` is above 0). Horns, tusks and antler tines.
static func prism_stack(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_PRISM_STACK
	var stand := Node3D.new()
	stand.position = look["offset"]
	stand.rotation = look["tilt"]
	root.add_child(stand)
	var count := int(look["count"])
	var step: float = look["length"] / count
	var radius: float = look["radius"]
	var facets := int(look["facets"])
	var parent := stand
	for i in count:
		var joint := Node3D.new()
		if i > 0:
			joint.position = Vector3(0, step, 0)
			joint.rotation.x = look["bend"]
		parent.add_child(joint)
		var colour := _tone(look, colours, "root_tone" if i == 0 else "tone")
		var next: float = radius * float(look["taper"])
		var mesh: Mesh
		if i == count - 1:
			mesh = _cone(radius, step, facets, _highlight(look, colours, "tip_tone"))
		else:
			mesh = _cylinder(next, radius, step, facets, colour)
		Figures.part(joint, mesh, Vector3(0, step * 0.5, 0))
		radius = next
		parent = joint
	return root


## `count` small spheres in the accent tone (the glow colour, lit, when `glow` is above 0)
## spaced over `arc` of a dark band of `radius`, centred on the front, in `rows` rows each
## `row_step` lower; `band` off draws the studs alone. Rivets, studs, bead belts, lace knots
## and a column of chest studs.
static func studs(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_STUDS
	var radius: float = look["radius"]
	var y: float = look["y"]
	if look["band"]:
		Figures.part(root, _cylinder(radius, radius, look["band_height"], look["segments"], _tone(look, colours, "band_tone")), Vector3(0, y, 0))
	var count := int(look["count"])
	var arc: float = look["arc"]
	var stud := SphereMesh.new()
	stud.radius = look["stud"]
	stud.height = look["stud"] * 2.0
	stud.radial_segments = 6
	stud.rings = 3
	stud.material = _highlight(look, colours, "stud_tone")
	for row in int(look["rows"]):
		for i in count:
			var a := (i - (count - 1) * 0.5) * (arc / maxf(count - 1, 1))
			Figures.part(root, stud, Vector3(sin(a) * radius, y - row * float(look["row_step"]), -cos(a) * radius))
	return root


## A thin raised rim in the trim tone (the glow colour, lit, when `glow` is above 0) round a
## plate `size` across and `size.y` tall, over a dark shadow line just below it, so the
## plate catches a highlight line from above; `round` makes it a hoop of `radius`.
static func edge_trim(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_EDGE_TRIM
	var stand := Node3D.new()
	stand.position = look["offset"]
	stand.rotation = look["tilt"]
	root.add_child(stand)
	var size: Vector3 = look["size"]
	var lip: float = look["lip"]
	var rim := _highlight(look, colours, "tone")
	var shadow := _tone(look, colours, "shadow_tone")
	if look["round"]:
		var radius: float = look["radius"]
		Figures.part(stand, _cylinder(radius + lip, radius + lip, size.y, look["segments"], rim), Vector3.ZERO)
		Figures.part(stand, _cylinder(radius + lip + 0.01, radius + lip + 0.01, size.y * 0.6, look["segments"], shadow), Vector3(0, -size.y * 0.6, 0))
		return root
	for edge in [[Vector3(size.x, 0, 0), Vector3(size.x + lip, size.y, lip)], [Vector3(0, 0, size.z), Vector3(lip, size.y, size.z + lip)]]:
		for s in [-1, 1]:
			var at: Vector3 = (edge[0] as Vector3) * 0.5 * s
			var rail: Vector3 = edge[1]
			Figures.part(stand, _box(rail, rim), at)
			Figures.part(stand, _box(rail + Vector3(0.01, -size.y * 0.4, 0.01), shadow), at + Vector3(0, -size.y * 0.6, 0))
	return root


## A case on the back from its root at `offset`, turned by `tilt`: a `foot_tone` foot, the
## case in `tone`, a cap band round its mouth in the highlight (`band_tone`), and `tip_count`
## tips standing out of the mouth, spread across it: `shaft_tone` shafts with fletching fins
## in `fletch_tone`, or shard tips in `tip_tone` (the band, the fletching and the shards the
## glow colour, lit, when `glow` is above 0).
static func quiver(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_QUIVER
	var stand := Node3D.new()
	stand.position = look["offset"]
	stand.rotation = look["tilt"]
	root.add_child(stand)
	var length: float = look["length"]
	var radius: float = look["radius"]
	var foot: float = look["foot"]
	var segments := int(look["segments"])
	Figures.part(stand, _cylinder(radius * 0.85, radius * 0.75, foot, segments, _tone(look, colours, "foot_tone")), Vector3(0, foot * 0.5, 0))
	Figures.part(stand, _cylinder(radius, radius * 0.85, length - foot, segments, _tone(look, colours, "tone")), Vector3(0, foot + (length - foot) * 0.5, 0))
	var band: float = look["band_height"]
	Figures.part(stand, _cylinder(radius + 0.012, radius + 0.012, band, segments, _highlight(look, colours, "band_tone")), Vector3(0, length - band * 0.5, 0))
	var tips := int(look["tip_count"])
	var tip: float = look["tip_length"]
	var shard := _highlight(look, colours, "tip_tone")
	for i in tips:
		var x := radius * 0.55 * ((i + 0.5) / tips * 2.0 - 1.0)
		var z := radius * 0.25 * (1 if i % 2 == 0 else -1)  # staggered, not a row of pickets
		if look["tips"] == GearLook.TIPS_SHARDS:
			Figures.part(stand, _cone(radius * 0.35, tip, 4, shard), Vector3(x, length + tip * 0.5, z))
			continue
		Figures.part(stand, _cylinder(0.012, 0.012, tip, 4, _tone(look, colours, "shaft_tone")), Vector3(x, length + tip * 0.5, z))
		Figures.part(stand, _box(Vector3(0.05, tip * 0.55, 0.012), _highlight(look, colours, "fletch_tone")), Vector3(x, length + tip * 0.7, z))
	return root


## A strap from one shoulder across the chest to the opposite hip: a box at `offset` rolled
## `roll` round the body and leaning `lean` into the chest, in `tone`, a rail along each edge
## in the highlight (`edge_tone`) over a wider `shadow_tone` strip behind it, and a buckle
## plate in `buckle_tone` at its middle when the look has one.
static func sash(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_SASH
	var strap := Node3D.new()
	strap.position = look["offset"]
	strap.rotation.x = -look["lean"]  # the strap lies along the chest's slope
	strap.rotation.z = look["roll"]  # and runs shoulder to hip
	root.add_child(strap)
	var width: float = look["width"]
	var length: float = look["length"]
	var thickness: float = look["thickness"]
	var edge: float = look["edge"]
	Figures.part(strap, _box(Vector3(width, length, thickness), _tone(look, colours, "tone")), Vector3.ZERO)
	Figures.part(strap, _box(Vector3(width + edge * 2.0, length, thickness * 0.5), _tone(look, colours, "shadow_tone")), Vector3(0, 0, thickness * 0.3))
	var rail := _highlight(look, colours, "edge_tone")
	for s in [-1, 1]:
		Figures.part(strap, _box(Vector3(edge, length, thickness + 0.01), rail), Vector3(s * (width - edge) * 0.5, 0, 0))
	if look["buckle"]:
		Figures.part(strap, _box(look["buckle_size"], _tone(look, colours, "buckle_tone")), Vector3(0, 0, -thickness * 0.5))
	return root


## A thick hoop round the shoulders or neck at `y` in `tone`, with a thin hoop in the
## highlight (`trim_tone`) along its inner edge: a fur mantle, a gorget, a collar ruff.
static func ruff(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_RUFF
	var inner: float = look["inner"]
	var outer: float = look["outer"]
	var trim: float = look["trim"]
	var thick: float = (outer - inner) * 0.5
	Figures.part(root, _torus(inner, outer, look["rings"], look["segments"], _tone(look, colours, "tone")), Vector3(0, look["y"], 0))
	Figures.part(root, _torus(inner, inner + trim, look["rings"], look["segments"], _highlight(look, colours, "trim_tone")), Vector3(0, look["y"] + thick * 0.5, 0))
	return root


## `count` plates stacked down the hips from `y`, each `step` lower, `height` tall and `grow`
## wider than the one above, flaring `flare` to its hem, alternating `tone` and `alt_tone`,
## with a rim line in the highlight (`rim_tone`) along each plate's top and a `shadow_tone`
## line under its hem: overlapping faulds.
static func faulds(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_FAULDS
	var rim := _highlight(look, colours, "rim_tone")
	var shadow := _tone(look, colours, "shadow_tone")
	var height: float = look["height"]
	var flare: float = look["flare"]
	var segments := int(look["segments"])
	for i in int(look["count"]):
		var radius: float = look["radius"] + float(look["grow"]) * i
		var y: float = look["y"] - float(look["step"]) * i
		var tone := _tone(look, colours, "tone" if i % 2 == 0 else "alt_tone")
		Figures.part(root, _cylinder(radius, radius + flare, height, segments, tone), Vector3(0, y, 0))
		Figures.part(root, _cylinder(radius + 0.005, radius + 0.005, look["rim"], segments, rim), Vector3(0, y + height * 0.5, 0))
		Figures.part(root, _cylinder(radius + flare + 0.008, radius + flare + 0.008, look["rim"], segments, shadow), Vector3(0, y - height * 0.5, 0))
	return root


## `count` flat plates hung from the hips at `y`, `radius` out, over `arc` centred on the
## front, each `size` wide, long and thick, its hem leaning out `flare`, in `tone` with the
## highlight (`edge_tone`) along its hem over a `shadow_tone` backing, and a `belt_tone` band
## they hang from when the look has one: tassets.
static func tassets(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_TASSETS
	var radius: float = look["radius"]
	var y: float = look["y"]
	if look["belt"]:
		Figures.part(root, _cylinder(radius, radius, look["belt_height"], look["segments"], _tone(look, colours, "belt_tone")), Vector3(0, y, 0))
	var count := int(look["count"])
	var arc: float = look["arc"]
	var size: Vector3 = look["size"]
	var edge: float = look["edge"]
	var tone := _tone(look, colours, "tone")
	var shadow := _tone(look, colours, "shadow_tone")
	var hem := _highlight(look, colours, "edge_tone")
	for i in count:
		var a := (i - (count - 1) * 0.5) * (arc / maxf(count - 1, 1))
		var plate := Node3D.new()
		plate.position = Vector3(sin(a) * radius, y, -cos(a) * radius)
		plate.rotation.y = -a  # the plate faces out from the hip
		plate.rotation.x = float(look["flare"])  # and its hem swings out
		root.add_child(plate)
		Figures.part(plate, _box(size, tone), Vector3(0, -size.y * 0.5, 0))
		Figures.part(plate, _box(Vector3(size.x + 0.02, size.y - 0.02, size.z * 0.5), shadow), Vector3(0, -size.y * 0.5 + 0.01, size.z * 0.4))
		Figures.part(plate, _box(Vector3(size.x, edge, size.z + 0.01), hem), Vector3(0, -size.y + edge * 0.5, 0))
	return root


## A broadsword held point up in the hand's mount frame, turned by `tilt`: a wide blade in
## `tone` ending in a flat tip, a `fuller_tone` groove down each face (the highlight), a
## crosswise guard `rise` above the hand in `guard_tone`, a round grip below it in
## `grip_tone` and a `pommel_tone` ball at its end.
static func broadsword(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_BROADSWORD
	var hilt := Node3D.new()
	hilt.rotation = look["tilt"]
	root.add_child(hilt)
	var rise: float = look["rise"]
	var length: float = look["blade_length"]
	var width: float = look["blade_width"]
	var thickness: float = look["blade_thickness"]
	var tip: float = look["tip"]
	var blade := _tone(look, colours, "tone")
	Figures.part(hilt, _box(Vector3(width, length, thickness), blade), Vector3(0, rise + length * 0.5, 0))
	var point := Figures.part(hilt, _cone(width * 0.5, tip, 4, blade), Vector3(0, rise + length + tip * 0.5, 0))
	point.rotation.y = PI * 0.25  # the four-sided point's edges line up with the blade's faces
	point.scale.z = thickness / width
	Figures.part(hilt, _box(Vector3(look["fuller_width"], length * 0.75, thickness + 0.01), _highlight(look, colours, "fuller_tone")), Vector3(0, rise + length * 0.45, 0))
	Figures.part(hilt, _box(look["guard_size"], _tone(look, colours, "guard_tone")), Vector3(0, rise, 0))
	var grip: float = look["grip_length"]
	Figures.part(hilt, _cylinder(look["grip_radius"], look["grip_radius"], grip, 6, _tone(look, colours, "grip_tone")), Vector3(0, rise - grip * 0.5, 0))
	Figures.part(hilt, _ball(look["pommel"], _tone(look, colours, "pommel_tone")), Vector3(0, rise - grip, 0))
	return root


## A bearded axe held head up in the hand's mount frame, turned by `tilt`: a haft in
## `haft_tone` with a `cap_tone` cap at its top, a thin tall head in `tone` set forward from
## the haft under the cap, its beard hanging from the head's far end in `beard_tone`, and the
## edge down its front in the highlight (`edge_tone`).
static func bearded_axe(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_BEARDED_AXE
	var haft := Node3D.new()
	haft.rotation = look["tilt"]
	root.add_child(haft)
	var rise: float = look["rise"]
	var length: float = look["haft_length"]
	var radius: float = look["haft_radius"]
	var cap: float = look["cap"]
	var top := rise + length
	Figures.part(haft, _cylinder(radius, radius * 1.1, length, 6, _tone(look, colours, "haft_tone")), Vector3(0, rise + length * 0.5, 0))
	Figures.part(haft, _cylinder(radius * 1.3, radius * 1.3, cap, 6, _tone(look, colours, "cap_tone")), Vector3(0, top + cap * 0.5, 0))
	var head: Vector3 = look["head_size"]
	var beard: float = look["beard"]
	var edge: float = look["edge"]
	Figures.part(haft, _box(head, _tone(look, colours, "tone")), Vector3(0, top - head.y * 0.5, -head.z * 0.5))
	Figures.part(haft, _box(Vector3(head.x, beard, head.z * 0.45), _tone(look, colours, "beard_tone")), Vector3(0, top - head.y - beard * 0.5, -head.z * 0.775))
	Figures.part(haft, _box(Vector3(head.x + 0.01, head.y + beard, edge), _highlight(look, colours, "edge_tone")), Vector3(0, top - (head.y + beard) * 0.5, -head.z - edge * 0.5))
	return root


## A greatsword held point up in the hand's mount frame, turned by `tilt`, taller than the
## figure: a long blade in `tone` with a `ridge_tone` ridge down its middle and a
## `fuller_tone` fuller (the highlight) either side of the ridge's root, ending in a tall tip,
## over a wide `guard_tone` guard whose quillons droop, a long two-hand grip in `grip_tone`
## with a `ring_tone` ring at its middle and a `pommel_tone` ball at its end.
static func greatsword(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_GREATSWORD
	var hilt := Node3D.new()
	hilt.rotation = look["tilt"]
	root.add_child(hilt)
	var rise: float = look["rise"]
	var length: float = look["blade_length"]
	var width: float = look["blade_width"]
	var thickness: float = look["blade_thickness"]
	var tip: float = look["tip"]
	var blade := _tone(look, colours, "tone")
	Figures.part(hilt, _box(Vector3(width, length, thickness), blade), Vector3(0, rise + length * 0.5, 0))
	var point := Figures.part(hilt, _cone(width * 0.5, tip, 4, blade), Vector3(0, rise + length + tip * 0.5, 0))
	point.rotation.y = PI * 0.25
	point.scale.z = thickness / width
	Figures.part(hilt, _box(Vector3(look["ridge_width"], length, thickness + 0.012), _tone(look, colours, "ridge_tone")), Vector3(0, rise + length * 0.5, 0))
	var fuller := _highlight(look, colours, "fuller_tone")
	var fuller_length: float = look["fuller_length"]
	Figures.part(hilt, _box(Vector3(look["fuller_width"], fuller_length, thickness + 0.02), fuller), Vector3(0, rise + fuller_length * 0.5 + 0.05, 0))
	var guard: Vector3 = look["guard_size"]
	var guard_tone := _tone(look, colours, "guard_tone")
	Figures.part(hilt, _box(Vector3(guard.x * 0.4, guard.y, guard.z), guard_tone), Vector3(0, rise, 0))
	for s in [-1, 1]:
		var quillon := Figures.part(hilt, _box(Vector3(guard.x * 0.35, guard.y, guard.z), guard_tone), Vector3(s * guard.x * 0.34, rise - guard.x * 0.17 * sin(look["quillon_droop"]), 0))
		quillon.rotation.z = s * look["quillon_droop"]  # the quillons droop toward the grip
	var grip: float = look["grip_length"]
	var grip_radius: float = look["grip_radius"]
	Figures.part(hilt, _cylinder(grip_radius, grip_radius, grip, 6, _tone(look, colours, "grip_tone")), Vector3(0, rise - grip * 0.5, 0))
	Figures.part(hilt, _cylinder(grip_radius * 1.3, grip_radius * 1.3, 0.03, 6, _tone(look, colours, "ring_tone")), Vector3(0, rise - grip * 0.5, 0))
	Figures.part(hilt, _ball(look["pommel"], _tone(look, colours, "pommel_tone")), Vector3(0, rise - grip, 0))
	return root


## A raised strip `size` wide, tall and thick at `offset` turned by `tilt`, its face toward
## -Z, drawn whole in the highlight (`tone`: the glow colour, lit, when `glow` is above 0)
## over a `shadow_tone` backing `lip` wider behind it, so the strip reads as cut into the
## plate: a glowing seam or crack, an eye slit, an eye socket, a lashing.
static func seam(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_SEAM
	var stand := Node3D.new()
	stand.position = look["offset"]
	stand.rotation = look["tilt"]
	root.add_child(stand)
	var size: Vector3 = look["size"]
	var lip: float = look["lip"]
	Figures.part(stand, _box(size, _highlight(look, colours, "tone")), Vector3.ZERO)
	Figures.part(stand, _box(Vector3(size.x + lip * 2.0, size.y + lip * 2.0, size.z * 0.5), _tone(look, colours, "shadow_tone")), Vector3(0, 0, size.z * 0.5))
	return root


## `count` shards standing round a ring of `radius` at `offset` turned by `tilt`, spread over
## `arc` (a full turn for a crown, less for a cluster centred on the front), each leaning out
## `lean` and every other one `short` as long as its neighbours: a `facets`-sided shard in
## `tone` with the top `tip` of its length in the highlight (`tip_tone`: the glow colour,
## lit, when `glow` is above 0). A frost crown, a crystal cluster. `light` and `motes` as a
## crystal takes them, at the ring's centre.
static func shard_crown(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_SHARD_CROWN
	var stand := Node3D.new()
	stand.position = look["offset"]
	stand.rotation = look["tilt"]
	root.add_child(stand)
	var count := int(look["count"])
	var radius: float = look["radius"]
	var arc: float = look["arc"]
	var length: float = look["length"]
	var shard: float = look["shard"]
	var facets := int(look["facets"])
	var tip: float = look["tip"]
	var tone := _tone(look, colours, "tone")
	var point := _highlight(look, colours, "tip_tone")
	var ring := is_equal_approx(arc, TAU)
	for i in count:
		var a: float = i * arc / count if ring else (i - (count - 1) * 0.5) * (arc / maxf(count - 1, 1))
		var spike := Node3D.new()
		spike.position = Vector3(sin(a) * radius, 0, -cos(a) * radius)
		spike.rotation.y = -a  # the shard faces out from the ring
		spike.rotation.x = -look["lean"]  # and leans out
		stand.add_child(spike)
		var long: float = length if i % 2 == 0 else length * float(look["short"])
		var body: float = long * (1.0 - tip)
		Figures.part(spike, _cylinder(shard * 0.6, shard, body, facets, tone), Vector3(0, body * 0.5, 0))
		Figures.part(spike, _cone(shard * 0.6, long - body, facets, point), Vector3(0, body + (long - body) * 0.5, 0))
	_glow_fx(stand, look, colours["glow"], look["glow"], 0.0)
	return root


## Two antlers (`Left` and `Right`) `x` either side of `offset` turned by `tilt`: each a thin
## `facets`-sided beam its own length (`length_left`, `length_right`) leaning out `spread` and
## back `sweep`, with its own count of tines (`tines_left`, `tines_right`) branching forward
## `tine_spread` along it, each `tine_length` long and swinging to alternate sides of the
## beam; the beams and tines in `tone` with every tip in the highlight (`tip_tone`: the glow
## colour, lit, when `glow` is above 0).
static func antlers(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_ANTLERS
	var stand := Node3D.new()
	stand.position = look["offset"]
	stand.rotation = look["tilt"]
	root.add_child(stand)
	var radius: float = look["radius"]
	var facets := int(look["facets"])
	var tone := _tone(look, colours, "tone")
	var point := _highlight(look, colours, "tip_tone")
	var tine_length: float = look["tine_length"]
	var tine_radius: float = look["tine_radius"]
	for side in [[-1, SIDE_LEFT, look["length_left"], look["tines_left"]], [1, SIDE_RIGHT, look["length_right"], look["tines_right"]]]:
		var s: int = side[0]
		var beam := Node3D.new()
		beam.name = side[1]
		beam.position = Vector3(s * look["x"], 0, 0)
		beam.rotation = Vector3(look["sweep"], 0, -s * look["spread"])  # out to its side and back
		stand.add_child(beam)
		var length: float = side[2]
		var shaft: float = length * 0.8
		Figures.part(beam, _cylinder(radius * 0.6, radius, shaft, facets, tone), Vector3(0, shaft * 0.5, 0))
		Figures.part(beam, _cone(radius * 0.6, length - shaft, facets, point), Vector3(0, shaft + (length - shaft) * 0.5, 0))
		var tines := int(side[3])
		for i in tines:
			var joint := Node3D.new()
			joint.position = Vector3(0, shaft * (i + 1) / (tines + 1), 0)
			joint.rotation = Vector3(-look["tine_spread"], 0, s * 0.3 * (1 if i % 2 == 0 else -1))  # forward, to alternate sides
			beam.add_child(joint)
			var stem: float = tine_length * 0.6
			Figures.part(joint, _cylinder(tine_radius * 0.7, tine_radius, stem, facets, tone), Vector3(0, stem * 0.5, 0))
			Figures.part(joint, _cone(tine_radius * 0.7, tine_length - stem, facets, point), Vector3(0, stem + (tine_length - stem) * 0.5, 0))
	return root


## A forge hammer held head up in the hand's mount frame, turned by `tilt`: a haft
## `haft_length` long in `haft_tone` with a ball at its foot, a block head `head_size` across
## (x along the hand, y tall, z deep) in `tone` sitting on the haft's top, a band `band` wide
## round the head `band_x` of its half-width out each side in `band_tone`, and `cracks`
## strips `crack` wide leaning across its faces in the highlight (`crack_tone`: the glow
## colour, lit, when `glow` is above 0). `light` and `motes` as a crystal takes them, at the
## head.
static func forge_hammer(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_FORGE_HAMMER
	var hilt := Node3D.new()
	hilt.rotation = look["tilt"]
	root.add_child(hilt)
	var rise: float = look["rise"]
	var length: float = look["haft_length"]
	var radius: float = look["haft_radius"]
	var top := rise + length
	var head: Vector3 = look["head_size"]
	var band_tone := _tone(look, colours, "band_tone")
	Figures.part(hilt, _cylinder(radius, radius * 1.1, length, 6, _tone(look, colours, "haft_tone")), Vector3(0, rise + length * 0.5, 0))
	Figures.part(hilt, _ball(radius * 1.6, band_tone), Vector3(0, rise, 0))
	Figures.part(hilt, _box(head, _tone(look, colours, "tone")), Vector3(0, top + head.y * 0.5, 0))
	var band: float = look["band"]
	for s in [-1, 1]:
		Figures.part(hilt, _box(Vector3(band, head.y + 0.012, head.z + 0.012), band_tone), Vector3(s * head.x * look["band_x"], top + head.y * 0.5, 0))
	var cracks := int(look["cracks"])
	var crack := _highlight(look, colours, "crack_tone")
	for i in cracks:
		var x := head.x * 0.25 * ((i + 0.5) / cracks * 2.0 - 1.0)
		var strip := Figures.part(hilt, _box(Vector3(look["crack"], head.y * 0.75, head.z + 0.014), crack), Vector3(x, top + head.y * 0.5, 0))
		strip.rotation.z = 0.35 * (1 if i % 2 == 0 else -1)  # the cracks lean, no two the same way
	_glow_fx(hilt, look, colours["glow"], look["glow"], top + head.y * 0.5)
	return root


## A glaive held blade up in the hand's mount frame, turned by `tilt`: a long haft
## `haft_length` long in `haft_tone` with a `cap_tone` ball at its foot and a `ferrule` tall
## ferrule in `ferrule_tone` under the blade; the blade `blade_length` long and `blade_width`
## across standing off one side of the haft's top, leaning `curve` out and ending in a `tip`
## bent further, in `tone` with a `back` wide spine in `back_tone` along the haft side and the
## edge `edge` wide along its far side in the highlight (`edge_tone`: the glow colour, lit,
## when `glow` is above 0).
static func glaive(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_GLAIVE
	var hilt := Node3D.new()
	hilt.rotation = look["tilt"]
	root.add_child(hilt)
	var rise: float = look["rise"]
	var length: float = look["haft_length"]
	var radius: float = look["haft_radius"]
	var top := rise + length
	var ferrule: float = look["ferrule"]
	Figures.part(hilt, _cylinder(radius, radius * 1.1, length, 6, _tone(look, colours, "haft_tone")), Vector3(0, rise + length * 0.5, 0))
	Figures.part(hilt, _ball(radius * 1.5, _tone(look, colours, "cap_tone")), Vector3(0, rise, 0))
	Figures.part(hilt, _cylinder(radius * 1.4, radius * 1.4, ferrule, 6, _tone(look, colours, "ferrule_tone")), Vector3(0, top - ferrule * 0.5, 0))
	var blade := Node3D.new()
	blade.position = Vector3(0, top, 0)
	blade.rotation.z = look["curve"]  # the blade leans out from the haft
	hilt.add_child(blade)
	var width: float = look["blade_width"]
	var long: float = look["blade_length"]
	var thickness: float = look["blade_thickness"]
	var back: float = look["back"]
	var edge: float = look["edge"]
	var tone := _tone(look, colours, "tone")
	Figures.part(blade, _box(Vector3(width, long, thickness), tone), Vector3(-width * 0.5, long * 0.5, 0))
	Figures.part(blade, _box(Vector3(back, long, thickness + 0.006), _tone(look, colours, "back_tone")), Vector3(-back * 0.5, long * 0.5, 0))
	Figures.part(blade, _box(Vector3(edge, long, thickness + 0.01), _highlight(look, colours, "edge_tone")), Vector3(-width + edge * 0.5, long * 0.5, 0))
	var joint := Node3D.new()
	joint.position = Vector3(-width * 0.5, long, 0)
	joint.rotation.z = look["curve"] * 0.9  # the tip bends on round
	blade.add_child(joint)
	var tip: float = look["tip"]
	var point := Figures.part(joint, _cone(width * 0.5, tip, 4, tone), Vector3(0, tip * 0.5, 0))
	point.rotation.y = PI * 0.25  # the four-sided point's edges line up with the blade's faces
	point.scale.z = thickness / width
	return root


## A cleaver held blade up in the hand's mount frame, turned by `tilt`: a short grip
## `grip_length` long in `grip_tone` with a `wrap` tall wrap round it in `wrap_tone` and a
## `back_tone` ball at its end, and a broad blade `blade_length` long and `blade_width` across
## off the grip, leaning `curve` out over the knuckles, swelling to a belly at its far end and
## ending in a `tip`, in `tone` with a `back` wide spine in `back_tone` and the edge `edge`
## wide along the belly in the highlight (`edge_tone`: the glow colour, lit, when `glow` is
## above 0).
static func cleaver(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_CLEAVER
	var hilt := Node3D.new()
	hilt.rotation = look["tilt"]
	root.add_child(hilt)
	var rise: float = look["rise"]
	var grip: float = look["grip_length"]
	var grip_radius: float = look["grip_radius"]
	var back_tone := _tone(look, colours, "back_tone")
	Figures.part(hilt, _cylinder(grip_radius, grip_radius, grip, 6, _tone(look, colours, "grip_tone")), Vector3(0, rise - grip * 0.5, 0))
	Figures.part(hilt, _cylinder(grip_radius * 1.25, grip_radius * 1.25, look["wrap"], 6, _tone(look, colours, "wrap_tone")), Vector3(0, rise - grip * 0.5, 0))
	Figures.part(hilt, _ball(grip_radius * 1.4, back_tone), Vector3(0, rise - grip, 0))
	var blade := Node3D.new()
	blade.position = Vector3(0, rise, 0)
	blade.rotation.z = -look["curve"]  # the blade sweeps out over the knuckles
	hilt.add_child(blade)
	var width: float = look["blade_width"]
	var long: float = look["blade_length"]
	var thickness: float = look["blade_thickness"]
	var tone := _tone(look, colours, "tone")
	Figures.part(blade, _box(Vector3(width, long, thickness), tone), Vector3(width * 0.2, long * 0.5, 0))
	Figures.part(blade, _box(Vector3(width * 0.6, long * 0.5, thickness), tone), Vector3(width * 0.7, long * 0.65, 0))
	var tip: float = look["tip"]
	var point := Figures.part(blade, _cone(width * 0.5, tip, 4, tone), Vector3(width * 0.2, long + tip * 0.5, 0))
	point.rotation.y = PI * 0.25
	point.scale.z = thickness / width
	var back: float = look["back"]
	Figures.part(blade, _box(Vector3(back, long, thickness + 0.006), back_tone), Vector3(-width * 0.3 + back * 0.5, long * 0.5, 0))
	var edge: float = look["edge"]
	Figures.part(blade, _box(Vector3(edge, long * 0.55, thickness + 0.01), _highlight(look, colours, "edge_tone")), Vector3(width - edge * 0.5, long * 0.65, 0))
	return root


## A bow held by its grip in the left hand's mount frame, the frame of the tier bows
## (Figures.bow): `segments` staves along Z bulging `depth` toward +Y, the outermost bent
## `tip_bend` further back for a recurve, the string below them in `string_tone`, a round grip
## in `grip_tone` round the middle, a ball nock at each tip in `nock_tone` (the highlight)
## and, when `cap_length` is above 0, a limb cap that long at each tip in `cap_tone`. The
## highlight also draws the string when `lit_string` is on, an `edge` thick strip along the
## back of every stave when `edge` is above 0, and a shard `shard` long standing off each tip
## when `shard` is above 0.
static func longbow(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_LONGBOW
	var length: float = look["length"]
	var depth: float = look["depth"]
	var segments := int(look["segments"])
	var stave: float = look["stave"]
	var wood := _tone(look, colours, "tone")
	var edge: float = look["edge"]
	var nock := _highlight(look, colours, "nock_tone")
	for i in segments:
		var a := lerpf(-1.0, 1.0, (i + 0.5) / segments)
		var piece := Figures.part(root, _box(Vector3(stave, stave, length / segments * 1.1), wood), Vector3(0, depth * (1.0 - a * a), a * length * 0.5))
		piece.rotation.x = atan2(2.0 * depth * a, length)
		if i == 0 or i == segments - 1:
			piece.rotation.x += signf(a) * float(look["tip_bend"])
		if edge > 0.0:
			# a lit strip along the stave's back, the side away from the string
			var strip := Figures.part(root, _box(Vector3(stave * 0.6, edge, length / segments * 1.1 + 0.004), nock), piece.position + Vector3(0, stave * 0.5, 0))
			strip.rotation.x = piece.rotation.x
	Figures.part(root, _box(Vector3(look["string"], look["string"], length), nock if look["lit_string"] else _tone(look, colours, "string_tone")), Vector3(0, -0.02, 0))
	var grip := Figures.part(root, _cylinder(look["grip_radius"], look["grip_radius"], look["grip_length"], 6, _tone(look, colours, "grip_tone")), Vector3(0, depth * 0.95, 0))
	grip.rotation.x = PI * 0.5  # the grip lies along the staves
	var cap_length: float = look["cap_length"]
	var shard: float = look["shard"]
	for side: float in [-1.0, 1.0]:
		Figures.part(root, _ball(look["nock"], nock), Vector3(0, 0, side * length * 0.5))
		if shard > 0.0:
			var point := Figures.part(root, _cone(look["nock"] * 0.9, shard, 4, nock), Vector3(0, 0, side * (length * 0.5 + shard * 0.5)))
			point.rotation.x = -side * PI * 0.5  # the shard points on along the limb
		if cap_length <= 0.0:
			continue
		var a: float = side * (1.0 - cap_length / length)
		var cap := Figures.part(root, _box(Vector3(stave * 1.4, stave * 1.4, cap_length), _tone(look, colours, "cap_tone")), Vector3(0, depth * (1.0 - a * a), a * length * 0.5))
		cap.rotation.x = atan2(2.0 * depth * a, length) + side * float(look["tip_bend"])
	return root


## `count` feathers fanning from `offset` turned by `tilt`, spread over `arc` about the stand's
## +Y in its X-Y plane: each a thin plate `length` long, `width` wide and `thickness` thick in
## `tone` with a `quill_tone` quill down its middle and a ball `tip` across at its end in the
## highlight (`tip_tone`: the glow colour, lit, when `glow` is above 0). A crest above the
## head, a wing off a shoulder (laid flat by its tilt).
static func plumes(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_PLUMES
	var stand := Node3D.new()
	stand.position = look["offset"]
	stand.rotation = look["tilt"]
	root.add_child(stand)
	var count := int(look["count"])
	var arc: float = look["arc"]
	var length: float = look["length"]
	var width: float = look["width"]
	var thickness: float = look["thickness"]
	var tone := _tone(look, colours, "tone")
	var quill := _tone(look, colours, "quill_tone")
	var point := _highlight(look, colours, "tip_tone")
	for i in count:
		var a := (i - (count - 1) * 0.5) * (arc / maxf(count - 1, 1))
		var feather := Node3D.new()
		feather.rotation.z = -a  # fanned out from the middle feather
		stand.add_child(feather)
		Figures.part(feather, _box(Vector3(width, length, thickness), tone), Vector3(0, length * 0.5, 0))
		Figures.part(feather, _box(Vector3(width * 0.3, length * 0.85, thickness + 0.008), quill), Vector3(0, length * 0.45, 0))
		Figures.part(feather, _ball(look["tip"], point), Vector3(0, length, 0))
	return root


## The material a look's `key` tone names: the palette field it names, or the Color it
## carries.
static func _tone(look: Dictionary, colours: Dictionary, key: String) -> StandardMaterial3D:
	var tone: Variant = look[key]
	return Props.flat(tone if tone is Color else colours[tone])


## The tone a builder's highlight is drawn in: the palette's glow colour shining at the look's
## `glow` when that is above 0, else the look's `key` tone.
static func _highlight(look: Dictionary, colours: Dictionary, key: String) -> StandardMaterial3D:
	var glow: float = look["glow"]
	if glow > 0.0:
		return Props.flat(colours["glow"], glow)
	return _tone(look, colours, key)


## A ball of `radius` drawn in `look`: a Color, or a material already made.
static func _ball(radius: float, look: Variant) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = look if look is Material else Props.flat(look)
	return mesh


## A box drawn in `look`: a Color, or a material already made (a highlight).
static func _box(size: Vector3, look: Variant) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = look if look is Material else Props.flat(look)
	return mesh


## A prism tapering to a point: a cylinder with `facets` sides and no top, drawn in `look`
## (a Color, or a material already made).
static func _cone(radius: float, height: float, facets: int, look: Variant) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = facets
	mesh.rings = 1
	mesh.material = look if look is Material else Props.flat(look)
	return mesh



## One of every armour look (every helm, body, legs, quiver and cape in the item table, metal
## and fur, with whatever each puts on the shin), every weapon built from a kit shape, and one
## of each kit shape, a quiver and a cloak, a light and motes included, for the warm-up to
## compile before play.
static func samples() -> Node3D:
	var all := Node3D.new()
	for sample in kit_samples():
		all.add_child(sample)
	for item in ItemTable.ITEMS:
		match ItemTable.slot(item):
			ItemTable.SLOT_HELM:
				all.add_child(head_piece(item))
			ItemTable.SLOT_BODY:
				all.add_child(body_piece(item))
			ItemTable.SLOT_LEGS:
				all.add_child(hips_piece(item))
				var shin := shin_piece(item)
				if shin != null:
					all.add_child(shin)
			ItemTable.SLOT_QUIVER:
				all.add_child(quiver_piece(item))
			ItemTable.SLOT_CAPE:
				all.add_child(cape_piece(item))
			ItemTable.SLOT_WEAPON:
				var weapon := weapon_piece(item)
				if weapon != null:
					all.add_child(weapon)
	return all


## The tool slung across the back, over any cape: Kenney's axe or pickaxe, or the fishing rod.
func _build_slung_tool(view: CharacterView, place: String, item: String, layout: Dictionary) -> void:
	var look := GearLook.piece(item, GearLook.PART_TOOL)
	var colour: Color = GearLook.palette(item)["base"]
	var cape: String = layout[GearLayout.CAPE]
	var sling := Node3D.new()
	sling.position = hang_sling(look, hang_cape(GearLook.piece(cape, GearLook.PART_CAPE), layout[GearLayout.BODY]) if cape != "" else {})
	sling.rotation.z = look["sling_roll"]
	_mount(view, place, "chest").add_child(sling)
	if look["shape"] == GearLook.SHAPE_ROD:
		var rod := Figures.rod(colour, look["length"])
		rod.position = Vector3(0, look["slung_lift"], 0)
		sling.add_child(rod)
		return
	var tool := Figures.tool(_tool_kind(look), colour, look["slung_height"])
	tool.rotation.y = PI * 0.5  # the head stands off the back, not into it
	sling.add_child(tool)


## The tool in the right hand: the rod tipped forward over the water, or the axe or pickaxe
## gripped low on its haft the way the barbarian held his own axe, so the chop clip swings it.
func _build_held_tool(view: CharacterView, place: String, item: String) -> void:
	var look := GearLook.piece(item, GearLook.PART_TOOL)
	var colour: Color = GearLook.palette(item)["base"]
	if look["shape"] == GearLook.SHAPE_ROD:
		var rod := Figures.rod(colour, look["length"])
		rod.rotation.x = look["held_tilt"]
		_mount(view, place, "handslot_r").add_child(rod)
		return
	var hand := view.bone_slot("handslot_r")
	if hand == null:
		return
	var height: float = look["held_height"]
	var grip := Node3D.new()
	grip.scale = Vector3.ONE / view.model_scale()
	hand.add_child(grip)
	_pieces[place].append(grip)
	var tool := Figures.tool(_tool_kind(look), colour, height)
	tool.position.y = -height * look["grip"]
	grip.add_child(tool)


## The Kenney model a tool look draws: the pickaxe or the axe.
static func _tool_kind(look: Dictionary) -> String:
	return ItemTable.TOOL_PICKAXE if look["shape"] == GearLook.SHAPE_PICKAXE else ItemTable.TOOL_AXE


## The colour `item` is drawn in: its look's base, magenta when it has no look so a missing
## one shows.
static func colour_of(item: String) -> Color:
	return GearLook.palette(item)["base"]
