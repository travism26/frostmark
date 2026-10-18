## The character's visible gear, placed by GearLayout from the equipment slots: the item in use
## in the hand (a bow in the left, a staff upright in the right), the tool slung on the back
## while the hands are free of it and the armour on the chest, each in its tier's colour
## (wood, bronze, iron, steel) and hung on the CharacterView's bone slots so it swings with the
## animation. While the view chops, mines or fishes, the tool moves to the right hand (the rod
## tipped forward over the water) and the weapon is put away. Armour also changes the
## silhouette by tier (a vest, then pauldrons, then a helm), so progress reads at a glance
## from the top-down camera.
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
			GearLayout.BODY:
				_build_armour(view, place, item)
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
	var colour := _tier_colour(item)
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


## A vest round the chest; from bronze, pauldrons on the shoulders; from iron, a helm.
func _build_armour(view: CharacterView, place: String, item: String) -> void:
	var colour := _tier_colour(item)
	var rank := ItemTable.tier_rank(ItemTable.tier(item))
	var chest := _mount(view, place, "chest")
	var vest := CylinderMesh.new()
	vest.top_radius = 0.34
	vest.bottom_radius = 0.36
	vest.height = 0.5
	vest.radial_segments = 8
	vest.material = Props.flat(colour)
	Figures.part(chest, vest, Vector3(0, -0.06, 0))
	if rank >= 1:
		for side in [-1, 1]:
			var pad := Figures.part(chest, Props.box(Vector3(0.26, 0.1, 0.32), colour.lightened(0.1)), Vector3(side * 0.4, 0.16, 0))
			pad.rotation.z = side * -0.35
	if rank >= 2:
		var head := _mount(view, place, "head")
		var helm := SphereMesh.new()
		helm.radius = 0.47
		helm.height = 0.42
		helm.radial_segments = 8
		helm.rings = 3
		helm.is_hemisphere = true
		helm.material = Props.flat(colour)
		Figures.part(head, helm, Vector3(0, 0.4, 0))
		var band := CylinderMesh.new()
		band.top_radius = 0.48
		band.bottom_radius = 0.48
		band.height = 0.08
		band.radial_segments = 8
		band.material = Props.flat(colour.darkened(0.2))
		Figures.part(head, band, Vector3(0, 0.42, 0))


## The tool slung across the back: Kenney's axe or pickaxe, or the fishing rod.
func _build_slung_tool(view: CharacterView, place: String, item: String) -> void:
	var colour := _tier_colour(item)
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
	var colour := _tier_colour(item)
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


static func _tier_colour(item: String) -> Color:
	return TIER_COLORS.get(ItemTable.tier(item), Color.MAGENTA)
