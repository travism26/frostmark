## The character's visible gear, placed by GearLayout from the equipment slots: the item in use
## in the hand (a bow in the left, a staff upright in the right), the tool slung on the back
## while the hands are free of it, and each worn armour piece in its place (the helm on the
## head, the body on the chest, the legs on the hips and shins), each in its tier's colour
## (wood, bronze, iron, steel) and hung on the CharacterView's bone slots so it swings with the
## animation; a fur piece, which has no tier, in fur. While the view chops, mines or fishes, the tool moves to the right hand (the rod
## tipped forward over the water) and the weapon is put away. A piece shows because it is worn,
## whatever its tier; the tier changes its shape (pauldrons on a body from bronze, a band on a
## helm from bronze and a nose guard from iron, greaves under the kilt from iron), so progress
## reads at a glance from the top-down camera.
##
## Presentation only: GameRoot hands it the equipment slots from the state after every
## `equipped` event and on load. The slots come lazily from a sibling CharacterView, so the
## gear node may be added before or after the view.
extends Node3D

const TIER_COLORS := {
	ItemTable.TIER_WOODEN: Color(0.55, 0.38, 0.22),
	ItemTable.TIER_BRONZE: Color(0.82, 0.52, 0.22),
	ItemTable.TIER_IRON: Color(0.58, 0.62, 0.68),
	ItemTable.TIER_STEEL: Color(0.42, 0.50, 0.62),
}
## Tierless armour is fur, drawn in a pelt grey-brown on the metal shapes.
const FUR_COLOR := Color(0.56, 0.48, 0.40)

## How far up its own height a tool in the hand is gripped.
const TOOL_GRIP := 0.22

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
	var colour := colour_of(item)
	var style: String = ItemTable.ITEMS[item].get("style", CombatTable.STYLE_MELEE)
	if style == CombatTable.STYLE_RANGED:
		_mount(view, place, "handslot_l").add_child(Figures.bow(colour, 1.1))
		return
	if style == CombatTable.STYLE_MAGIC:
		_mount(view, place, "handslot_r").add_child(Figures.staff(colour))
		return
	if ItemTable.tier(item) == ItemTable.TIER_WOODEN:
		_mount(view, place, "handslot_r").add_child(Figures.club(colour))
		return
	var hand := view.bone_slot("handslot_r")
	if hand == null:
		return
	var sword := Figures.sword(colour, 1.0, view.model_scale())
	hand.add_child(sword)
	_pieces[place].append(sword)


## A vest round the chest; from bronze, pauldrons on the shoulders.
func _build_body(view: CharacterView, place: String, item: String) -> void:
	var colour := colour_of(item)
	var chest := _mount(view, place, "chest")
	var vest := CylinderMesh.new()
	vest.top_radius = 0.34
	vest.bottom_radius = 0.36
	vest.height = 0.5
	vest.radial_segments = 8
	vest.material = Props.flat(colour)
	Figures.part(chest, vest, Vector3(0, -0.06, 0))
	if _rank(item) >= 1:
		for side in [-1, 1]:
			var pad := Figures.part(chest, Props.box(Vector3(0.26, 0.1, 0.32), colour.lightened(0.1)), Vector3(side * 0.4, 0.16, 0))
			pad.rotation.z = side * -0.35


## A dome over the crown; from bronze, a band round its rim; from iron, a nose guard.
func _build_helm(view: CharacterView, place: String, item: String) -> void:
	var colour := colour_of(item)
	var rank := _rank(item)
	var head := _mount(view, place, "head")
	var helm := SphereMesh.new()
	helm.radius = 0.47
	helm.height = 0.42
	helm.radial_segments = 8
	helm.rings = 3
	helm.is_hemisphere = true
	helm.material = Props.flat(colour)
	Figures.part(head, helm, Vector3(0, 0.4, 0))
	if rank >= 1:
		var band := CylinderMesh.new()
		band.top_radius = 0.48
		band.bottom_radius = 0.48
		band.height = 0.08
		band.radial_segments = 8
		band.material = Props.flat(colour.darkened(0.2))
		Figures.part(head, band, Vector3(0, 0.42, 0))
	if rank >= 2:
		Figures.part(head, Props.box(Vector3(0.07, 0.2, 0.06), colour.darkened(0.2)), Vector3(0, 0.34, -0.47))


## A kilt round the hips; from iron, greaves on both shins as well.
func _build_legs(view: CharacterView, place: String, item: String) -> void:
	var colour := colour_of(item)
	var hips := _mount(view, place, "hips")
	var kilt := CylinderMesh.new()
	kilt.top_radius = 0.38
	kilt.bottom_radius = 0.46
	kilt.height = 0.26
	kilt.radial_segments = 8
	kilt.material = Props.flat(colour.darkened(0.1))
	Figures.part(hips, kilt, Vector3(0, -0.08, 0))
	if _rank(item) < 2:
		return
	for side in ["l", "r"]:
		var shin := _mount(view, place, "lowerleg_" + side)
		var greave := CylinderMesh.new()
		greave.top_radius = 0.16
		greave.bottom_radius = 0.14
		greave.height = 0.22
		greave.radial_segments = 8
		greave.material = Props.flat(colour)
		Figures.part(shin, greave, Vector3(0, -0.12, 0))


## The tool slung across the back: Kenney's axe or pickaxe, or the fishing rod.
func _build_slung_tool(view: CharacterView, place: String, item: String) -> void:
	var colour := colour_of(item)
	var sling := Node3D.new()
	sling.position = Vector3(0.12, -0.38, 0.34)
	sling.rotation.z = 0.5
	_mount(view, place, "chest").add_child(sling)
	if ItemTable.tool(item) == ItemTable.TOOL_ROD:
		var rod := Figures.rod(colour, 1.4)
		rod.position = Vector3(0, 0.2, 0)
		sling.add_child(rod)
		return
	var tool := Figures.tool(ItemTable.tool(item), colour, 0.95)
	tool.rotation.y = PI * 0.5  # the head stands off the back, not into it
	sling.add_child(tool)


## The tool in the right hand: the rod tipped forward over the water, or the axe or pickaxe
## gripped low on its haft the way the barbarian held his own axe, so the chop clip swings it.
func _build_held_tool(view: CharacterView, place: String, item: String) -> void:
	var colour := colour_of(item)
	if ItemTable.tool(item) == ItemTable.TOOL_ROD:
		var rod := Figures.rod(colour, 1.4)
		rod.rotation.x = -1.0  # tipped forward over the water
		_mount(view, place, "handslot_r").add_child(rod)
		return
	var hand := view.bone_slot("handslot_r")
	if hand == null:
		return
	var height := 0.85
	var grip := Node3D.new()
	grip.scale = Vector3.ONE / view.model_scale()
	hand.add_child(grip)
	_pieces[place].append(grip)
	var tool := Figures.tool(ItemTable.tool(item), colour, height)
	tool.position.y = -height * TOOL_GRIP
	grip.add_child(tool)


static func _rank(item: String) -> int:
	return ItemTable.tier_rank(ItemTable.tier(item))


## The colour `item` is drawn in: its tier's, fur for tierless armour, magenta for anything
## else so a missing colour shows.
static func colour_of(item: String) -> Color:
	if ItemTable.tier(item) == "" and ItemTable.ARMOUR_SLOTS.has(ItemTable.slot(item)):
		return FUR_COLOR
	return TIER_COLORS.get(ItemTable.tier(item), Color.MAGENTA)
