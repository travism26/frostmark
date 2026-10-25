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
## `crystal`, `fin`, `prism_stack`, `studs`, `edge_trim`, `quiver`) are the layered, non-round shapes
## the set looks are built from. Each takes a look (its shape's numbers, from
## `GearLook.numbers` or `GearLook.piece`) and a palette, names its root after its shape,
## and draws at least two tones (a base plus a darker underside or a lighter trim) so it reads
## lit from above. A look's `glow` above 0 draws the builder's highlight in the palette's glow
## colour, shining that bright, through `Props.flat`. A crystal alone carries the one small
## light and the few motes a top set is allowed, and only when its look asks for them.
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
## The names of a two-sided builder's side nodes, so a test can measure each side.
const SIDE_LEFT := "Left"
const SIDE_RIGHT := "Right"
## The names of the glow nodes a crystal carries when its look asks for them.
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


## What `item` draws on the head: a helm or a fur hood.
static func head_piece(item: String) -> Node3D:
	var look := GearLook.piece(item, GearLook.PART_HEAD)
	if look["shape"] == SHAPE_FUR_HOOD:
		return _fur_hood(look, GearLook.palette(item))
	return _helm(look, GearLook.palette(item))


## What `item` draws on the chest: a vest or a fur coat.
static func body_piece(item: String) -> Node3D:
	var look := GearLook.piece(item, GearLook.PART_BODY)
	if look["shape"] == SHAPE_FUR_COAT:
		return _fur_coat(look, GearLook.palette(item))
	return _vest(look, GearLook.palette(item))


## What `item` draws on the hips: a kilt or fur leggings.
static func hips_piece(item: String) -> Node3D:
	var look := GearLook.piece(item, GearLook.PART_HIPS)
	if look["shape"] == SHAPE_FUR_LEGGINGS:
		return _wrap(SHAPE_FUR_LEGGINGS, look, GearLook.palette(item)["base"])
	return _wrap(SHAPE_KILT, look, GearLook.palette(item)["dark"])


## What `item` draws on each shin: a greave, a fur band, or null for a bare shin.
static func shin_piece(item: String) -> Node3D:
	var look := GearLook.piece(item, GearLook.PART_SHIN)
	if look.is_empty():
		return null
	var colours := GearLook.palette(item)
	var shin := _wrap(look["shape"], look, colours["base"])
	if look["shape"] == SHAPE_FUR_BAND:
		Figures.part(shin, _cylinder(look["band_radius"], look["band_radius"], look["band_height"], look["segments"], colours["trim"]), Vector3(0, look["band_y"], 0))
	return shin


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
	Figures.part(head, _dome(look, colours["base"]), Vector3(0, look["y"], 0))
	if look["band"]:
		Figures.part(head, _cylinder(look["band_radius"], look["band_radius"], look["band_height"], look["segments"], colours["trim"]), Vector3(0, look["band_y"], 0))
	if look["nose_guard"]:
		Figures.part(head, Props.box(look["nose_size"], colours["trim"]), look["nose_offset"])
	return head


## A rounded hood: a full round crown, a drape down the back of the head and a pale hoop
## framing the face.
static func _fur_hood(look: Dictionary, colours: Dictionary) -> Node3D:
	var hood := Node3D.new()
	hood.name = SHAPE_FUR_HOOD
	Figures.part(hood, _dome(look, colours["base"]), Vector3(0, look["y"], 0))
	var back := Figures.part(hood, _dome(look, colours["base"]), look["drape_offset"])
	back.rotation.x = PI * 0.5  # the dome points behind the head, down the neck
	var hoop := _torus(look["hoop_inner"], look["hoop_outer"], look["hoop_rings"], look["hoop_segments"], colours["accent"])
	var face := Figures.part(hood, hoop, look["hoop_offset"])
	face.rotation.x = PI * 0.5  # a hoop framing the face, flush with the crown's front edge
	return hood


## A vest round the chest, with a pad on each shoulder when the look has pauldrons.
static func _vest(look: Dictionary, colours: Dictionary) -> Node3D:
	var chest := _wrap(SHAPE_VEST, look, colours["base"])
	if look["pauldrons"]:
		for side in [-1, 1]:
			var pad := Figures.part(chest, Props.box(look["pauldron_size"], colours["accent"]), Vector3(side * look["pauldron_x"], look["pauldron_y"], 0))
			pad.rotation.z = side * -look["pauldron_tilt"]
	return chest


## A coat: a bulky body flaring to the hem, a thick pale collar ruff and a pale hem.
static func _fur_coat(look: Dictionary, colours: Dictionary) -> Node3D:
	var coat := _wrap(SHAPE_FUR_COAT, look, colours["base"])
	Figures.part(coat, _torus(look["ruff_inner"], look["ruff_outer"], look["ruff_rings"], look["ruff_segments"], colours["trim"]), Vector3(0, look["ruff_y"], 0))
	Figures.part(coat, _cylinder(look["hem_radius"], look["hem_radius"], look["hem_height"], look["segments"], colours["trim"]), Vector3(0, look["hem_y"], 0))
	return coat


## A node named `shape` holding one cylinder from the look's radii, height and segments, `y`
## down its frame: a vest, a kilt, leggings, a greave or a shin's wrap.
static func _wrap(shape: String, look: Dictionary, colour: Color) -> Node3D:
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


static func _dome(look: Dictionary, colour: Color) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = look["radius"]
	mesh.height = look["height"]
	mesh.radial_segments = look["segments"]
	mesh.rings = look["rings"]
	mesh.is_hemisphere = true
	mesh.material = Props.flat(colour)
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
	Figures.part(hood, _dome(look, colours["base"]), Vector3(0, look["y"], 0))
	var peak := Node3D.new()
	peak.position = look["peak_offset"]
	peak.rotation.x = look["peak_tilt"]  # the fin's tip sweeps up and back
	hood.add_child(peak)
	var spike := Figures.part(peak, _cone(look["peak_width"] * 0.5, look["peak_length"], 4, colours["base"]), Vector3(0, look["peak_length"] * 0.5, 0))
	spike.scale.x = 0.5  # a fin, not a horn
	var drape := Figures.part(hood, _cylinder(look["drape_radius"], look["drape_radius"] * 0.9, look["drape_height"], look["segments"], colours["dark"]), look["drape_offset"])
	drape.rotation.x = PI * 0.5  # the drape points behind the head, down the neck
	var hoop := _torus(look["hoop_inner"], look["hoop_outer"], look["hoop_rings"], look["hoop_segments"], _highlight(look, colours))
	var face := Figures.part(hood, hoop, look["hoop_offset"])
	face.rotation.x = PI * 0.5  # a hoop framing the face, flush with the crown's front edge
	return hood


## A flaring under-robe in the dark tone under a coat shell set back so the robe shows at the
## open front, two front panels hanging from the coat's hem each its own length (`Left` and
## `Right`), and bands up the robe from its hem in the highlight.
static func under_robe(look: Dictionary, colours: Dictionary) -> Node3D:
	var robe := _wrap(SHAPE_UNDER_ROBE, look, colours["dark"])
	Figures.part(robe, _cylinder(look["coat_top_radius"], look["coat_bottom_radius"], look["coat_height"], look["segments"], colours["base"]), Vector3(0, look["coat_y"], look["coat_back"]))
	for side in [[-1, SIDE_LEFT, look["panel_left"]], [1, SIDE_RIGHT, look["panel_right"]]]:
		var panel := Node3D.new()
		panel.name = side[1]
		panel.position = Vector3(side[0] * look["panel_x"], look["panel_top"], look["panel_z"])
		panel.rotation.z = side[0] * -look["panel_flare"]  # the panels hang apart at the hem
		panel.rotation.x = -look["panel_lean"]  # and lean forward, clear of the robe's flare
		robe.add_child(panel)
		var length: float = side[2]
		Figures.part(panel, _box(Vector3(look["panel_width"], length, look["panel_thickness"]), colours["base"]), Vector3(0, -length * 0.5, 0))
	var top: float = look["y"] + look["height"] * 0.5
	var band := _highlight(look, colours)
	for i in int(look["bands"]):
		var y: float = look["band_from"] + i * look["band_step"]
		var radius: float = lerpf(look["top_radius"], look["bottom_radius"], clampf((top - y) / look["height"], 0.0, 1.0)) + 0.012
		Figures.part(robe, _cylinder(radius, radius, look["band_height"], look["segments"], band), Vector3(0, y, 0))
	return robe


## A fin hung from the shoulders behind the body the way the barbarian's cape hangs, in two
## halves (`Left` and `Right`) each its own length, leaning `tilt` back. Its `outline` is
## plain (a hem band across each half), forked (the halves part in a V), torn (a ragged hem of
## dark teeth), tail (a long centre tail) or banner (a narrow panel on a pole over the
## shoulders).
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
	var hem := _highlight(look, colours)
	for side in [[-1, SIDE_LEFT, look["length_left"]], [1, SIDE_RIGHT, look["length_right"]]]:
		var panel := Node3D.new()
		panel.name = side[1]
		hang.add_child(panel)
		if outline == GearLook.OUTLINE_FORKED:
			panel.rotation.z = side[0] * look["fork"]  # each half swings out from the centre line
		var length: float = side[2]
		Figures.part(panel, _box(Vector3(half, length, thickness), colours["base"]), Vector3(side[0] * half * 0.5, -length * 0.5, 0))
		if outline == GearLook.OUTLINE_TORN:
			var teeth := int(look["teeth"])
			for i in teeth:
				var tooth := Figures.part(panel, _cone(look["tooth"] * 0.4, look["tooth"], 4, colours["dark"]), Vector3(side[0] * half * (i + 0.5) / teeth, -length - look["tooth"] * 0.5, 0))
				tooth.rotation.x = PI  # the points hang down
		else:
			Figures.part(panel, _box(Vector3(half, look["hem"], thickness + 0.01), hem), Vector3(side[0] * half * 0.5, -length + look["hem"] * 0.5, 0))
	match outline:
		GearLook.OUTLINE_TAIL:
			var length: float = maxf(look["length_left"], look["length_right"]) + look["tail_length"]
			Figures.part(hang, _box(Vector3(look["tail_width"], length, thickness), colours["base"]), Vector3(0, -length * 0.5, thickness * 0.5))
			Figures.part(hang, _box(Vector3(look["tail_width"], look["hem"], thickness + 0.01), hem), Vector3(0, -length + look["hem"] * 0.5, thickness * 0.5))
		GearLook.OUTLINE_BANNER:
			var rise: float = look["banner_rise"]
			Figures.part(hang, _cylinder(0.02, 0.02, rise + 0.2, 6, colours["dark"]), Vector3(0, rise * 0.5 - 0.1, thickness))
			Figures.part(hang, _box(Vector3(look["banner_width"], rise, thickness), colours["base"]), Vector3(look["banner_width"] * 0.5, rise * 0.5, thickness))
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
	var top := _highlight(look, colours)
	var teeth := int(look["teeth"])
	if kind == GearLook.COLLAR_HOOP:
		var ring := Figures.part(stand, _torus(look["hoop_inner"], look["hoop_outer"], look["hoop_rings"], look["hoop_segments"], colours["base"]), Vector3(0, look["hoop_outer"], 0))
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
	Figures.part(stand, _box(Vector3(width, height, thickness), colours["base"]), Vector3(0, height * 0.5, 0))
	Figures.part(stand, _box(Vector3(width + 0.04, height - 0.02, thickness), colours["dark"]), Vector3(0, height * 0.5 - 0.01, thickness))
	if kind == GearLook.COLLAR_JAGGED:
		for i in teeth:
			Figures.part(stand, _cone(look["tooth"] * 0.4, look["tooth"], 4, top), Vector3(width * ((i + 0.5) / teeth - 0.5), height + look["tooth"] * 0.5, 0))
	else:
		Figures.part(stand, _box(Vector3(width, 0.04, thickness + 0.02), top), Vector3(0, height, 0))
	return root


## Two or three plates on each shoulder (`Left` and `Right`): the top plate in the base tone,
## each lower one darker, `step` further out and down and `grow` larger, with the highlight
## along the top plate's outer edge. Each side has its own count and size.
static func stacked_plates(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_STACKED_PLATES
	var edge := _highlight(look, colours)
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
			var colour: Color = colours["base"] if i == 0 else colours["dark"]
			Figures.part(shoulder, _box(plate_size, colour), Vector3(s * step.x * i, step.y * i, step.z * i))
		var trim: float = look["trim"]
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
	Figures.part(stand, _cylinder(look["radius"], look["radius"] * 0.5, join, facets, colours["dark"]), Vector3(0, join * 0.5, 0))
	if look["light"]:
		var light := OmniLight3D.new()
		light.name = GLOW_LIGHT
		light.light_color = colour
		light.light_energy = look["light_energy"]
		light.omni_range = look["light_range"]
		light.omni_attenuation = 1.3
		light.position.y = join
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
		motes.position.y = join
		stand.add_child(motes)
	return root


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
	Figures.part(stand, _box(size, colours["base"]), Vector3(0, size.y * 0.5, 0))
	var edge := _highlight(look, colours)
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
		var colour: Color = colours["dark"] if i == 0 else colours["base"]
		var next: float = radius * float(look["taper"])
		var mesh: Mesh
		if i == count - 1:
			mesh = _cone(radius, step, facets, _highlight(look, colours, "accent"))
		else:
			mesh = _cylinder(next, radius, step, facets, colour)
		Figures.part(joint, mesh, Vector3(0, step * 0.5, 0))
		radius = next
		parent = joint
	return root


## `count` small spheres in the accent tone (the glow colour, lit, when `glow` is above 0)
## spaced over `arc` of a dark band of `radius`, centred on the front. Rivets, studs and bead
## belts.
static func studs(look: Dictionary, colours: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = SHAPE_STUDS
	var radius: float = look["radius"]
	Figures.part(root, _cylinder(radius, radius, look["band_height"], look["segments"], colours["dark"]), Vector3(0, look["y"], 0))
	var count := int(look["count"])
	var arc: float = look["arc"]
	var stud := SphereMesh.new()
	stud.radius = look["stud"]
	stud.height = look["stud"] * 2.0
	stud.radial_segments = 6
	stud.rings = 3
	stud.material = _highlight(look, colours, "accent")
	for i in count:
		var a := (i - (count - 1) * 0.5) * (arc / maxf(count - 1, 1))
		Figures.part(root, stud, Vector3(sin(a) * radius, look["y"], -cos(a) * radius))
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
	var rim := _highlight(look, colours)
	var shadow := Props.flat(colours["dark"])
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


## A case on the back from its root at `offset`, turned by `tilt`: a dark foot, the case in the
## base tone, a cap band round its mouth in the highlight, and `tip_count` tips standing out of
## the mouth, spread across it: dark shafts with fletching fins in the trim, or shard tips in the
## accent (the glow colour, lit, when `glow` is above 0).
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
	Figures.part(stand, _cylinder(radius * 0.85, radius * 0.75, foot, segments, colours["dark"]), Vector3(0, foot * 0.5, 0))
	Figures.part(stand, _cylinder(radius, radius * 0.85, length - foot, segments, colours["base"]), Vector3(0, foot + (length - foot) * 0.5, 0))
	var band: float = look["band_height"]
	Figures.part(stand, _cylinder(radius + 0.012, radius + 0.012, band, segments, _highlight(look, colours)), Vector3(0, length - band * 0.5, 0))
	var tips := int(look["tip_count"])
	var tip: float = look["tip_length"]
	var shard := _highlight(look, colours, "accent")
	for i in tips:
		var x := radius * 0.55 * ((i + 0.5) / tips * 2.0 - 1.0)
		var z := radius * 0.25 * (1 if i % 2 == 0 else -1)  # staggered, not a row of pickets
		if look["tips"] == GearLook.TIPS_SHARDS:
			Figures.part(stand, _cone(radius * 0.35, tip, 4, shard), Vector3(x, length + tip * 0.5, z))
			continue
		Figures.part(stand, _cylinder(0.012, 0.012, tip, 4, colours["dark"]), Vector3(x, length + tip * 0.5, z))
		Figures.part(stand, _box(Vector3(0.05, tip * 0.55, 0.012), colours["trim"]), Vector3(x, length + tip * 0.7, z))
	return root


## The tone a builder's highlight is drawn in: the palette's glow colour shining at the look's
## `glow` when that is above 0, else the palette's `field` (the trim unless told otherwise).
static func _highlight(look: Dictionary, colours: Dictionary, field := "trim") -> StandardMaterial3D:
	var glow: float = look["glow"]
	if glow > 0.0:
		return Props.flat(colours["glow"], glow)
	return Props.flat(colours[field])


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
## and fur, with whatever each puts on the shin) and one of each kit shape, a quiver and a
## cloak, a light and motes included, for the warm-up to compile before play.
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
