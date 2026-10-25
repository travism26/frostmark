## The character's visible gear, placed by GearLayout from the equipment slots: the item in use
## in the hand (a bow in the left, a staff upright in the right), the tool slung on the back
## while the hands are free of it, and each worn armour piece in its place (the helm on the
## head, the body on the chest, the legs on the hips and shins), hung on the CharacterView's
## bone slots so it swings with the animation. While the view chops, mines or fishes, the tool
## moves to the right hand (the rod tipped forward over the water) and the weapon is put away.
## A piece shows because it is worn. What it draws, its colours, shape and numbers, comes from
## its GearLook entry (`scenes/gear_look.gd`), so progress reads at a glance from the top-down
## camera and a look is tuned there, not here.
##
## The armour shapes are static builders (`head_piece`, `body_piece`, `hips_piece`,
## `shin_piece`) so the shader warm-up can draw one of every armour look (`samples`) before
## play; the node mounts them on the view.
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

var _shown := {}  # place -> item currently drawn there
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
		if _shown[place] == item:
			continue
		_shown[place] = item
		for node in _pieces[place]:
			(node as Node).queue_free()
		_pieces[place] = []
		if place == GearLayout.BODY:
			view.set_part_visible("Barbarian_Cape", item == "")  # the cape would hide the vest
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
				_build_slung_tool(view, place, item)
	set_process(_equipment.get(ItemTable.SLOT_TOOL, "") != "")


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


static func _cylinder(top: float, bottom: float, height: float, segments: int, colour: Color) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.material = Props.flat(colour)
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


static func _torus(inner: float, outer: float, rings: int, segments: int, colour: Color) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = rings
	mesh.ring_segments = segments
	mesh.material = Props.flat(colour)
	return mesh


## One of every armour look (every helm, body and legs in the item table, metal and fur,
## with whatever each puts on the shin), for the warm-up to compile before play.
static func samples() -> Node3D:
	var all := Node3D.new()
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
	return all


## The tool slung across the back: Kenney's axe or pickaxe, or the fishing rod.
func _build_slung_tool(view: CharacterView, place: String, item: String) -> void:
	var look := GearLook.piece(item, GearLook.PART_TOOL)
	var colour: Color = GearLook.palette(item)["base"]
	var sling := Node3D.new()
	sling.position = look["sling_offset"]
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
