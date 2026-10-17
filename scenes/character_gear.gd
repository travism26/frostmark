## The character's visible gear: the weapon in the right hand (a bow in the left, a staff
## upright in the right), the armour on the chest and the tool on the back, each in its
## tier's colour (wood, bronze, iron, steel) and hung on the CharacterView's bone slots so it
## swings with the animation. The fishing rod rides the back until the view plays its fishing
## clip, then sits in the right hand. Armour also changes the silhouette by tier (a vest, then
## pauldrons, then a helm), so progress reads at a glance from the top-down camera.
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

var _shown := {}  # slot -> item currently drawn
var _pieces := {}  # slot -> the nodes drawn for it, to free when it changes
var _equipment := {}
var _view: CharacterView
var _rod: Node3D  # the fishing rod, moved between its back sling and the hand
var _rod_sling: Node3D
var _rod_hand: Node3D


func _init() -> void:
	for slot in ItemTable.EQUIPMENT_SLOTS:
		_shown[slot] = null
		_pieces[slot] = []
	set_process(false)


## Redraws whichever slots changed since the last call.
func show_equipment(equipment: Dictionary) -> void:
	_equipment = equipment.duplicate()
	_redraw()


func _process(_delta: float) -> void:
	var view := _find_view()
	if view == null:
		_redraw()  # waiting for the CharacterView to turn up
		return
	if _rod == null:
		set_process(false)
		return
	var holder := _rod_hand if view.current_clip() == CharacterView.CLIP_FISH else _rod_sling
	if _rod.get_parent() != holder:
		_rod.reparent(holder, false)


func _redraw() -> void:
	var view := _find_view()
	if view == null:
		set_process(true)
		return
	for slot in ItemTable.EQUIPMENT_SLOTS:
		var item: String = _equipment.get(slot, "")
		if _shown[slot] == item:
			continue
		_shown[slot] = item
		for node in _pieces[slot]:
			(node as Node).queue_free()
		_pieces[slot] = []
		if slot == ItemTable.SLOT_TOOL:
			_rod = null
		if slot == ItemTable.SLOT_ARMOUR:
			view.set_part_visible("Barbarian_Cape", item == "")  # the cape would hide the vest
		if item == "" or not ItemTable.has(item):
			continue
		match slot:
			ItemTable.SLOT_WEAPON:
				_build_weapon(view, slot, item)
			ItemTable.SLOT_ARMOUR:
				_build_armour(view, slot, item)
			ItemTable.SLOT_TOOL:
				_build_tool(view, slot, item)
	set_process(_rod != null)


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


## A node in the view's `slot_name` mount frame, remembered under `slot` so it goes when the
## item does.
func _mount(view: CharacterView, slot: String, slot_name: String) -> Node3D:
	var holder := view.mount(slot_name)
	_pieces[slot].append(holder)
	return holder


func _build_weapon(view: CharacterView, slot: String, item: String) -> void:
	var colour := _tier_colour(item)
	var style: String = ItemTable.ITEMS[item].get("style", CombatTable.STYLE_MELEE)
	if style == CombatTable.STYLE_RANGED:
		_mount(view, slot, "handslot_l").add_child(Figures.bow(colour, 1.1))
		return
	if style == CombatTable.STYLE_MAGIC:
		_mount(view, slot, "handslot_r").add_child(Figures.staff(colour))
		return
	if ItemTable.tier(item) == ItemTable.TIER_WOODEN:
		_mount(view, slot, "handslot_r").add_child(Figures.club(colour))
		return
	var hand := view.bone_slot("handslot_r")
	if hand == null:
		return
	var sword := Figures.sword(colour, 1.0, view.model_scale())
	hand.add_child(sword)
	_pieces[slot].append(sword)


## A vest round the chest; from bronze, pauldrons on the shoulders; from iron, a helm.
func _build_armour(view: CharacterView, slot: String, item: String) -> void:
	var colour := _tier_colour(item)
	var rank := ItemTable.tier_rank(ItemTable.tier(item))
	var chest := _mount(view, slot, "chest")
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
		var head := _mount(view, slot, "head")
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


## The tool slung across the back: Kenney's axe or pickaxe, or the fishing rod, which moves to
## the right hand, tipped forward over the water, while the fishing clip plays.
func _build_tool(view: CharacterView, slot: String, item: String) -> void:
	var colour := _tier_colour(item)
	var back := _mount(view, slot, "chest")
	var sling := Node3D.new()
	sling.position = Vector3(0.12, -0.38, 0.34)
	sling.rotation.z = 0.5
	back.add_child(sling)
	match ItemTable.tool(item):
		ItemTable.TOOL_ROD:
			_rod = Figures.rod(colour, 1.4)
			_rod_sling = Node3D.new()
			_rod_sling.position = Vector3(0, 0.2, 0)
			sling.add_child(_rod_sling)
			_rod_sling.add_child(_rod)
			_rod_hand = Node3D.new()
			_rod_hand.rotation.x = -1.0  # tipped forward over the water
			_mount(view, slot, "handslot_r").add_child(_rod_hand)
		_:
			var tool := Figures.tool(ItemTable.tool(item), colour, 0.95)
			tool.rotation.y = PI * 0.5  # the head stands off the back, not into it
			sling.add_child(tool)


static func _tier_colour(item: String) -> Color:
	return TIER_COLORS.get(ItemTable.tier(item), Color.MAGENTA)
