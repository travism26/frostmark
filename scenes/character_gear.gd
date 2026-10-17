## The character's visible gear: the weapon in hand, the armour on the body and the tool on
## the back, each built in its tier's material (wood, bronze, iron). Armour also changes the
## silhouette by tier (a plank vest, then pauldrons, then a helm), so progress reads at a
## glance from the top-down camera.
##
## Presentation only: GameRoot hands it the equipment slots from the state after every
## `equipped` event and on load. The character faces local -Z, so the right hand is +X and
## the back is +Z.
extends Node3D

const TIER_COLORS := {
	ItemTable.TIER_WOODEN: Color(0.55, 0.38, 0.22),
	ItemTable.TIER_BRONZE: Color(0.82, 0.52, 0.22),
	ItemTable.TIER_IRON: Color(0.66, 0.69, 0.74),
}
const COLOR_GRIP := Color(0.25, 0.17, 0.11)
const COLOR_STRING := Color(0.92, 0.9, 0.82)

var _shown := {}  # slot -> item currently drawn
var _slots := {}  # slot -> Node3D holding that slot's meshes


func _ready() -> void:
	for slot in ItemTable.EQUIPMENT_SLOTS:
		var holder := Node3D.new()
		holder.name = slot.capitalize()
		add_child(holder)
		_slots[slot] = holder
		_shown[slot] = null


## Redraws whichever slots changed since the last call.
func show_equipment(equipment: Dictionary) -> void:
	for slot in ItemTable.EQUIPMENT_SLOTS:
		var item: String = equipment.get(slot, "")
		if _shown[slot] == item:
			continue
		_shown[slot] = item
		var holder: Node3D = _slots[slot]
		for child in holder.get_children():
			child.queue_free()
		if item == "" or not ItemTable.has(item):
			continue
		match slot:
			ItemTable.SLOT_WEAPON:
				_build_weapon(holder, item)
			ItemTable.SLOT_ARMOUR:
				_build_armour(holder, item)
			ItemTable.SLOT_TOOL:
				_build_tool(holder, item)


func _build_weapon(holder: Node3D, item: String) -> void:
	var colour := _tier_colour(item)
	var style: String = ItemTable.ITEMS[item].get("style", "melee")
	if style == CombatTable.STYLE_RANGED:
		# A bow held upright in the left hand: an arc of staves and a string.
		var bow := Node3D.new()
		bow.position = Vector3(-0.45, 1.0, -0.15)
		holder.add_child(bow)
		var segments := 6
		for i in segments:
			var a := lerpf(-1.0, 1.0, (i + 0.5) / segments)
			var stave := _part(bow, Props.box(Vector3(0.06, 0.24, 0.06), colour), Vector3(0, a * 0.55, -0.18 * (1.0 - a * a)))
			stave.rotation.x = a * 0.6
		_part(bow, Props.box(Vector3(0.015, 1.1, 0.015), COLOR_STRING), Vector3(0, 0, 0.02))
		return
	if style == CombatTable.STYLE_MAGIC:
		# A staff held upright in the right hand: a shaft in the tier's material, a frost crystal on top.
		var staff := Node3D.new()
		staff.position = Vector3(0.45, 0.95, -0.15)
		holder.add_child(staff)
		_part(staff, Props.box(Vector3(0.06, 1.5, 0.06), colour), Vector3.ZERO)
		var tip := _part(staff, Props.box(Vector3(0.16, 0.16, 0.16), Props.COLOR_FROST), Vector3(0, 0.82, 0))
		tip.rotation = Vector3(0.6, 0.8, 0.0)
		return
	var hand := Node3D.new()
	hand.position = Vector3(0.45, 0.85, -0.1)
	hand.rotation.x = -0.5
	holder.add_child(hand)
	if ItemTable.tier(item) == ItemTable.TIER_WOODEN:
		# A club: a grip swelling into a heavy head.
		var shaft := CylinderMesh.new()
		shaft.top_radius = 0.09
		shaft.bottom_radius = 0.04
		shaft.height = 0.75
		shaft.radial_segments = 6
		shaft.material = Props.flat(colour)
		_part(hand, shaft, Vector3(0, 0.35, 0))
		return
	# A sword: blade, crossguard and grip.
	_part(hand, Props.box(Vector3(0.09, 0.85, 0.025), colour), Vector3(0, 0.55, 0))
	_part(hand, Props.box(Vector3(0.28, 0.05, 0.07), colour.darkened(0.3)), Vector3(0, 0.12, 0))
	_part(hand, Props.box(Vector3(0.05, 0.18, 0.05), COLOR_GRIP), Vector3(0, 0.02, 0))


func _build_armour(holder: Node3D, item: String) -> void:
	var colour := _tier_colour(item)
	var rank := ItemTable.tier_rank(ItemTable.tier(item))
	var vest := CylinderMesh.new()
	vest.top_radius = 0.38
	vest.bottom_radius = 0.40
	vest.height = 0.62
	vest.radial_segments = 8
	vest.material = Props.flat(colour)
	_part(holder, vest, Vector3(0, 1.0, 0))
	if rank >= 1:
		for side in [-1, 1]:
			var pad := _part(holder, Props.box(Vector3(0.26, 0.12, 0.34), colour.lightened(0.1)), Vector3(side * 0.36, 1.33, 0))
			pad.rotation.z = side * -0.35
	if rank >= 2:
		var helm := SphereMesh.new()
		helm.radius = 0.3
		helm.height = 0.36
		helm.radial_segments = 8
		helm.rings = 3
		helm.is_hemisphere = true
		helm.material = Props.flat(colour)
		_part(holder, helm, Vector3(0, 1.55, 0))


func _build_tool(holder: Node3D, item: String) -> void:
	var colour := _tier_colour(item)
	var back := Node3D.new()
	back.position = Vector3(0.1, 1.05, 0.38)
	back.rotation.z = 0.6
	holder.add_child(back)
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.025
	shaft.bottom_radius = 0.025
	shaft.radial_segments = 5
	shaft.material = Props.flat(COLOR_GRIP if ItemTable.tool(item) != ItemTable.TOOL_ROD else colour)
	match ItemTable.tool(item):
		ItemTable.TOOL_AXE:
			shaft.height = 0.7
			_part(back, shaft, Vector3.ZERO)
			_part(back, Props.box(Vector3(0.22, 0.16, 0.04), colour), Vector3(0.1, 0.3, 0))
		ItemTable.TOOL_PICKAXE:
			shaft.height = 0.7
			_part(back, shaft, Vector3.ZERO)
			_part(back, Props.box(Vector3(0.5, 0.07, 0.05), colour), Vector3(0, 0.33, 0))
		ItemTable.TOOL_ROD:
			shaft.height = 1.3
			_part(back, shaft, Vector3(0, 0.3, 0))


static func _tier_colour(item: String) -> Color:
	return TIER_COLORS.get(ItemTable.tier(item), Color.MAGENTA)


static func _part(parent: Node3D, mesh: Mesh, offset: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = offset
	parent.add_child(part)
	return part
