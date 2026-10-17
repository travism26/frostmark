## Builders for the living figures: the enemies of rings one and two as animated CC0 models
## (KayKit Adventurers for the bandits and the frost witch, a KayKit Skeleton for the ruin
## stalker, the Quaternius wolf and yeti; credited in docs/assets/CREDITS.md) and the hand-held
## pieces the player and the bandits share (a bow of staves, a club, a frost staff, the KayKit
## sword, Kenney's axe and pickaxe, the Quaternius fishing rod).
##
## Presentation only. `enemy` returns a FigureBody standing on the ground at its origin with a
## `height` metadata for the click volume and labels; the captain carries nodes named
## `captain_sabre`, `captain_bow` and `captain_staff` that GameRoot shows by his stance. Hand pieces are
## authored in a FigureBody `mount` frame: +Y up, -Z forward, the grip on the origin.
class_name Figures
extends RefCounted

const ADVENTURERS := "res://assets/models/kaykit_adventurers/"
const SKELETONS := "res://assets/models/kaykit_skeletons/"
const QUATERNIUS := "res://assets/models/quaternius/"
const SURVIVAL := "res://assets/models/kenney_survival/"

## Rig heights in model units (measured from the skinned rest pose): a KayKit adventurer's
## body without its hat, the Quaternius wolf and yeti with their armatures' scale and turn
## applied.
const KAYKIT_HEIGHT := 2.2
const WOLF_HEIGHT := 2.7
const YETI_HEIGHT := 2.83

const HUMANOID_CLIPS := {
	"idle": "Idle", "walk": "Walking_A", "run": "Running_A",
	"melee": "1H_Melee_Attack_Chop", "ranged": "2H_Ranged_Shoot", "magic": "1H_Melee_Attack_Slice_Horizontal",
	"flinch": "Hit_A", "death": "Death_A",
}
const WITCH_CLIPS := {
	"idle": "Idle", "walk": "Walking_A", "run": "Running_A",
	"melee": "1H_Melee_Attack_Chop", "ranged": "Spellcast_Shoot", "magic": "Spellcast_Shoot",
	"flinch": "Hit_A", "death": "Death_A",
}
const WOLF_CLIPS := {
	"idle": "Idle", "walk": "Walk", "run": "Gallop", "melee": "Attack", "ranged": "Attack", "death": "Death",
}
const YETI_CLIPS := {
	"idle": "CharacterArmature|Idle", "walk": "CharacterArmature|Walk", "run": "CharacterArmature|Run",
	"melee": "CharacterArmature|Weapon", "flinch": "CharacterArmature|HitReact", "death": "CharacterArmature|Death",
}
## The yeti's fur and face repainted in old ice: Quaternius ships it dark and half-metallic.
const YETI_PAINT := {
	"Yeti_Main": Color("#dfe8f3"), "Yeti_Secondary": Color("#5b86b0"), "Eye_White": Color("#f2f5ff"),
	"Eye_Black": Color("#101420"), "Yeti_Teeth": Color("#efe6cf"), "Tongue": Color("#7a2f4a"),
}

const COLOR_STRING := Color(0.92, 0.9, 0.82)
const COLOR_GRIP := Color(0.25, 0.17, 0.11)
const COLOR_ARCHER := Color(0.55, 0.16, 0.14)  # the rogue redrawn in bandit red
const COLOR_CAPTAIN_CAPE := Color(0.62, 0.08, 0.08)
const COLOR_WOLF := Color(1.45, 1.5, 1.6)  # the grey coat lifted towards snow
const COLOR_WITCH := Color("#6670b3")  # the mage in a rimed blue-violet
const COLOR_BONE := Color(0.86, 0.82, 0.72)
const COLOR_IRON := Color(0.30, 0.32, 0.36)
const ROGUE_SPARES := ["Knife", "Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable"]
const MAGE_SPARES := ["Spellbook", "Spellbook_open", "1H_Wand", "2H_Staff"]


## An enemy of `kind`: a 1 m wolf that lunges with its bite, a hooded archer with a bow, a
## frost witch (the wide-hatted mage in blue-violet with a staff), a ruin stalker (a bare
## skeleton with a bone bow), an ice troll (the yeti, 3.1 m of pale fur with an ice club) or
## the armoured captain with a sabre, a war bow and a rime staff (one shown at a time, by his
## stance).
static func enemy(kind: String) -> FigureBody:
	match kind:
		"wolf":
			var wolf := FigureBody.new()
			wolf.setup(QUATERNIUS + "wolf.glb", WOLF_HEIGHT, 1.0, WOLF_CLIPS)
			wolf.run_speed = 2.0
			wolf.lunge = 0.8
			wolf.tint(COLOR_WOLF)
			return wolf
		"bandit_captain":
			var captain := humanoid("knight.glb", 1.8 * 1.15, ["1H_Sword_Offhand", "2H_Sword", "Badge_Shield", "Rectangle_Shield", "Round_Shield", "Spike_Shield"])
			FigureBody.tint_meshes(captain.bone_slot("chest"), COLOR_CAPTAIN_CAPE)
			var sabre := captain.bone_slot("handslot_r").get_node("1H_Sword") as Node3D
			sabre.name = "captain_sabre"
			sabre.scale = Vector3.ONE * 0.7
			var bow_hand := captain.mount("handslot_l", "captain_bow")
			bow_hand.add_child(bow(Props.COLOR_DARK_WOOD, 1.4))
			var staff_hand := captain.mount("handslot_r", "captain_staff")
			staff_hand.add_child(staff(Props.COLOR_DARK_WOOD, 1.7))
			return captain
		"frost_witch":
			var witch := humanoid("mage.glb", 1.8, MAGE_SPARES, WITCH_CLIPS)
			witch.recolour(COLOR_WITCH)
			witch.impact = 0.4
			witch.mount("handslot_r", "staff").add_child(staff(Props.COLOR_WOOD, 1.5))
			return witch
		"ruin_stalker":
			var stalker := humanoid("skeleton_minion.glb", 1.8, [], HUMANOID_CLIPS, SKELETONS)
			stalker.impact = 0.3
			stalker.mount("handslot_l", "bow").add_child(bow(COLOR_BONE, 1.2))
			return stalker
		"ice_troll":
			var troll := FigureBody.new()
			troll.setup(QUATERNIUS + "yeti.glb", YETI_HEIGHT, 3.1, YETI_CLIPS)
			troll.paint(YETI_PAINT)
			troll.run_speed = 2.5
			troll.impact = 0.5
			troll.raise = 0.25
			var ice_club := club(Props.COLOR_ICE)
			ice_club.scale = Vector3.ONE * 2.2
			troll.mount("Middle1.R", "club").add_child(ice_club)
			return troll
		_:
			var archer := humanoid("rogue_hooded.glb", 1.8, ROGUE_SPARES)
			archer.recolour(COLOR_ARCHER)
			archer.mount("handslot_l", "bow").add_child(bow(Props.COLOR_WOOD, 1.1))
			return archer


## A KayKit character `file` (an adventurer unless `folder` says otherwise) scaled to `height`
## metres, facing -Z, with the attached parts named in `hidden` (spare weapons, shields) put
## away.
static func humanoid(file: String, height: float, hidden: Array, clips := HUMANOID_CLIPS, folder := ADVENTURERS) -> FigureBody:
	var figure := FigureBody.new()
	figure.setup(folder + file, KAYKIT_HEIGHT, height, clips)
	figure.hide_parts(hidden)
	return figure


## One attached mesh out of a KayKit glb (the knight's `1H_Sword`), detached from its rig so
## it can hang on another figure's slot. Its transform is the one it had in its own slot.
static func kaykit_part(file: String, part_name: String) -> MeshInstance3D:
	var scene: PackedScene = load(ADVENTURERS + file)
	var inner: Node3D = scene.instantiate()
	var part := inner.find_child(part_name, true, false) as MeshInstance3D
	if part != null:
		part.get_parent().remove_child(part)
		part.owner = null
	inner.free()
	return part


## A bow `length` metres tall held by its grip: an arc of staves bulging up and a string.
static func bow(colour: Color, length := 1.1) -> Node3D:
	var root := Node3D.new()
	var segments := 6
	var depth := length * 0.17
	for i in segments:
		var a := lerpf(-1.0, 1.0, (i + 0.5) / segments)
		var stave := part(root, Props.box(Vector3(0.06, 0.06, length / segments * 1.1), colour), Vector3(0, depth * (1.0 - a * a), a * length * 0.5))
		stave.rotation.x = atan2(2.0 * depth * a, length)
	part(root, Props.box(Vector3(0.015, 0.015, length), COLOR_STRING), Vector3(0, -0.02, 0))
	return root


## A club: a grip swelling into a heavy head, pointing forward.
static func club(colour: Color) -> Node3D:
	var root := Node3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.09
	shaft.bottom_radius = 0.04
	shaft.height = 0.75
	shaft.radial_segments = 6
	shaft.material = Props.flat(colour)
	var head := part(root, shaft, Vector3(0, 0, -0.3))
	head.rotation.x = -PI * 0.5  # the cylinder's +Y (the heavy end) points to -Z
	return root


## A staff held upright by its grip: a shaft in the tier's colour rising a metre over the
## hand, a frost crystal turned on its corner at the top.
static func staff(colour: Color, length := 1.5) -> Node3D:
	var root := Node3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.035
	shaft.bottom_radius = 0.045
	shaft.height = length
	shaft.radial_segments = 6
	shaft.material = Props.flat(colour)
	part(root, shaft, Vector3(0, length * 0.5 - 0.35, 0))
	var crystal := BoxMesh.new()
	crystal.size = Vector3(0.16, 0.16, 0.16)
	crystal.material = Props.flat(Props.COLOR_FROST, 1.5)
	var tip := part(root, crystal, Vector3(0, length - 0.3, 0))
	tip.rotation = Vector3(0.6, 0.8, 0.0)
	return root


## The KayKit one-handed sword tinted `colour`, `length` metres long on a figure whose model
## is drawn at `model_scale`. Add it straight to a `handslot_r` slot: it carries its own grip
## offset.
static func sword(colour: Color, length: float, model_scale: float) -> Node3D:
	var blade := kaykit_part("knight.glb", "1H_Sword")
	if blade == null:
		return Node3D.new()
	FigureBody.tint_meshes(blade, colour)
	blade.scale = Vector3.ONE * (length / (1.78 * model_scale))
	return blade


## The Quaternius fishing rod standing `length` metres tall, its grip on the origin, its wood
## in `colour` and its fittings in dark iron.
static func rod(colour: Color, length := 1.4) -> Node3D:
	var model: Node3D = (load(QUATERNIUS + "fishing_rod.glb") as PackedScene).instantiate()
	var bounds := Props._bounds(model)
	model.scale = Vector3.ONE * (length / maxf(bounds.size.y, 0.001))
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			var metal := src != null and String(src.resource_name).begins_with("Metal")
			mi.set_surface_override_material(i, Props.flat(COLOR_IRON if metal else colour))
	return model


## Kenney's axe or pickaxe standing `height` metres tall on its origin, tinted `colour`.
static func tool(kind: String, colour: Color, height := 0.7) -> Node3D:
	var file := "tool-pickaxe.glb" if kind == ItemTable.TOOL_PICKAXE else "tool-axe.glb"
	return Props.model(SURVIVAL + file, height, 0.95, colour)


static func part(parent: Node3D, mesh: Mesh, offset: Vector3) -> MeshInstance3D:
	var p := MeshInstance3D.new()
	p.mesh = mesh
	p.position = offset
	parent.add_child(p)
	return p
