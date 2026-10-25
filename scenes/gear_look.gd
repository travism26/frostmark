## What each piece of gear looks like on the character, keyed by item id: the one place a
## gear look is tuned. CharacterGear reads every colour, shape and number from here, so
## changing how a set looks is an edit to its entries and a re-shoot with
## `tools/gear_shots.gd`, never a hunt through the builders. Pure data, like the sim: no
## nodes, no scene, no rendering.
##
## An entry holds a `palette` and, for each part the item draws, a piece: a Dictionary
## naming its `shape` and only the numbers it changes from that shape's defaults in SHAPES.
## A helm draws on PART_HEAD, a body on PART_BODY, legs on PART_HIPS and PART_SHIN (an empty
## shin piece leaves the shin bare), a weapon on PART_WEAPON and a tool on PART_TOOL.
##
## An item with no entry draws the plain shape of its slot all in magenta, so a missing look
## shows.
class_name GearLook
extends RefCounted

const PART_HEAD := "head"
const PART_BODY := "body"
const PART_HIPS := "hips"
const PART_SHIN := "shin"
const PART_WEAPON := "weapon"
const PART_TOOL := "tool"

## The shapes, also the names of the armour nodes so a test can tell which shape a slot drew.
const SHAPE_HELM := "Helm"
const SHAPE_FUR_HOOD := "FurHood"
const SHAPE_VEST := "Vest"
const SHAPE_FUR_COAT := "FurCoat"
const SHAPE_KILT := "Kilt"
const SHAPE_FUR_LEGGINGS := "FurLeggings"
const SHAPE_GREAVE := "Greave"
const SHAPE_FUR_BAND := "FurBand"
const SHAPE_CLUB := "Club"
const SHAPE_SWORD := "Sword"
const SHAPE_BOW := "Bow"
const SHAPE_STAFF := "Staff"
const SHAPE_AXE := "Axe"
const SHAPE_PICKAXE := "Pickaxe"
const SHAPE_ROD := "Rod"

## Every palette carries exactly these fields.
##   base         Color  the piece itself: a dome, vest, greave or fur wrap, a blade or haft
##   dark         Color  the underside: the kilt under the vest
##   trim         Color  bands and edges: a helm's band and nose guard, fur's pale ruff, hem
##                       and shin band
##   accent       Color  raised pieces: pauldrons, the pale hoop framing a fur hood's face
##   glow         Color  what a glowing part shines in: a staff's crystal
##   glow_energy  float  how bright the glow is; 0 draws it unlit
const PALETTE_FIELDS := ["base", "dark", "trim", "accent", "glow", "glow_energy"]

const WOOD := {
	"base": Color(0.55, 0.38, 0.22), "dark": Color(0.495, 0.342, 0.198),
	"trim": Color(0.44, 0.304, 0.176), "accent": Color(0.595, 0.442, 0.298),
	"glow": Color(0.55, 0.85, 1.0), "glow_energy": 1.5,
}
const BRONZE := {
	"base": Color(0.82, 0.52, 0.22), "dark": Color(0.738, 0.468, 0.198),
	"trim": Color(0.656, 0.416, 0.176), "accent": Color(0.838, 0.568, 0.298),
	"glow": Color(0.55, 0.85, 1.0), "glow_energy": 1.5,
}
const IRON := {
	"base": Color(0.58, 0.62, 0.68), "dark": Color(0.522, 0.558, 0.612),
	"trim": Color(0.464, 0.496, 0.544), "accent": Color(0.622, 0.658, 0.712),
	"glow": Color(0.55, 0.85, 1.0), "glow_energy": 1.5,
}
const STEEL := {
	"base": Color(0.42, 0.50, 0.62), "dark": Color(0.378, 0.45, 0.558),
	"trim": Color(0.336, 0.40, 0.496), "accent": Color(0.478, 0.55, 0.658),
	"glow": Color(0.55, 0.85, 1.0), "glow_energy": 1.5,
}
## A pelt grey-brown with a pale trim.
const FUR := {
	"base": Color(0.56, 0.48, 0.40), "dark": Color(0.504, 0.432, 0.36),
	"trim": Color(0.80, 0.74, 0.64), "accent": Color(0.714, 0.662, 0.61),
	"glow": Color.BLACK, "glow_energy": 0.0,
}
const MISSING := {
	"base": Color.MAGENTA, "dark": Color.MAGENTA, "trim": Color.MAGENTA, "accent": Color.MAGENTA,
	"glow": Color.MAGENTA, "glow_energy": 0.0,
}

## Each shape's numbers (metres and radians in the part's mount frame, segment counts) and
## switches, as drawn when a piece changes none of them.
const SHAPES := {
	# A dome over the crown; `band` adds a band round its rim, `nose_guard` a guard down the nose.
	SHAPE_HELM: {
		"radius": 0.47, "height": 0.42, "y": 0.4, "segments": 8, "rings": 3,
		"band": false, "band_radius": 0.48, "band_height": 0.08, "band_y": 0.42,
		"nose_guard": false, "nose_size": Vector3(0.07, 0.2, 0.06), "nose_offset": Vector3(0, 0.34, -0.47),
	},
	# A round crown, a drape down the back of the head and a hoop framing the face.
	SHAPE_FUR_HOOD: {
		"radius": 0.5, "height": 0.5, "segments": 10, "rings": 4, "y": 0.34,
		"drape_offset": Vector3(0, 0.24, 0.02),
		"hoop_inner": 0.38, "hoop_outer": 0.5, "hoop_rings": 10, "hoop_segments": 6,
		"hoop_offset": Vector3(0, 0.2, -0.36),
	},
	# A vest round the chest; `pauldrons` adds a pad on each shoulder.
	SHAPE_VEST: {
		"top_radius": 0.34, "bottom_radius": 0.36, "height": 0.5, "segments": 8, "y": -0.06,
		"pauldrons": false, "pauldron_size": Vector3(0.26, 0.1, 0.32), "pauldron_x": 0.4,
		"pauldron_y": 0.16, "pauldron_tilt": 0.35,
	},
	# A bulky coat flaring to the hem, a thick collar ruff and a hem band.
	SHAPE_FUR_COAT: {
		"top_radius": 0.40, "bottom_radius": 0.46, "height": 0.6, "segments": 10, "y": -0.1,
		"ruff_inner": 0.24, "ruff_outer": 0.54, "ruff_rings": 10, "ruff_segments": 6, "ruff_y": 0.22,
		"hem_radius": 0.47, "hem_height": 0.08, "hem_y": -0.38,
	},
	# A kilt flaring from the hips.
	SHAPE_KILT: {"top_radius": 0.38, "bottom_radius": 0.46, "height": 0.26, "segments": 8, "y": -0.08},
	# A close wrap round the hips.
	SHAPE_FUR_LEGGINGS: {"top_radius": 0.40, "bottom_radius": 0.41, "height": 0.3, "segments": 10, "y": -0.1},
	# A greave round the shin.
	SHAPE_GREAVE: {"top_radius": 0.16, "bottom_radius": 0.14, "height": 0.22, "segments": 8, "y": -0.12},
	# A wrap down the shin with a thick band at its top.
	SHAPE_FUR_BAND: {
		"top_radius": 0.165, "bottom_radius": 0.15, "height": 0.24, "segments": 8, "y": -0.12,
		"band_radius": 0.19, "band_height": 0.12, "band_y": -0.04,
	},
	SHAPE_CLUB: {},
	SHAPE_SWORD: {"length": 1.0},
	SHAPE_BOW: {"length": 1.1},
	SHAPE_STAFF: {"length": 1.5},
	# Gripped `grip` up its `held_height` in the hand; slung across the back at `slung_height`,
	# in a sling frame at `sling_offset` on the chest rolled by `sling_roll`.
	SHAPE_AXE: {
		"held_height": 0.85, "grip": 0.22, "slung_height": 0.95,
		"sling_offset": Vector3(0.12, -0.38, 0.34), "sling_roll": 0.5,
	},
	SHAPE_PICKAXE: {
		"held_height": 0.85, "grip": 0.22, "slung_height": 0.95,
		"sling_offset": Vector3(0.12, -0.38, 0.34), "sling_roll": 0.5,
	},
	# `length` tall, tipped `held_tilt` forward over the water in the hand; slung `slung_lift`
	# up the sling frame.
	SHAPE_ROD: {
		"length": 1.4, "held_tilt": -1.0, "slung_lift": 0.2,
		"sling_offset": Vector3(0.12, -0.38, 0.34), "sling_roll": 0.5,
	},
}

const LOOKS := {
	# Tools
	"wooden_axe": {"palette": WOOD, PART_TOOL: {"shape": SHAPE_AXE}},
	"bronze_axe": {"palette": BRONZE, PART_TOOL: {"shape": SHAPE_AXE}},
	"iron_axe": {"palette": IRON, PART_TOOL: {"shape": SHAPE_AXE}},
	"steel_axe": {"palette": STEEL, PART_TOOL: {"shape": SHAPE_AXE}},
	"wooden_pickaxe": {"palette": WOOD, PART_TOOL: {"shape": SHAPE_PICKAXE}},
	"bronze_pickaxe": {"palette": BRONZE, PART_TOOL: {"shape": SHAPE_PICKAXE}},
	"iron_pickaxe": {"palette": IRON, PART_TOOL: {"shape": SHAPE_PICKAXE}},
	"steel_pickaxe": {"palette": STEEL, PART_TOOL: {"shape": SHAPE_PICKAXE}},
	"fishing_rod": {"palette": WOOD, PART_TOOL: {"shape": SHAPE_ROD}},
	# Weapons
	"wooden_club": {"palette": WOOD, PART_WEAPON: {"shape": SHAPE_CLUB}},
	"bronze_sword": {"palette": BRONZE, PART_WEAPON: {"shape": SHAPE_SWORD}},
	"iron_sword": {"palette": IRON, PART_WEAPON: {"shape": SHAPE_SWORD}},
	"steel_sword": {"palette": STEEL, PART_WEAPON: {"shape": SHAPE_SWORD}},
	"wooden_bow": {"palette": WOOD, PART_WEAPON: {"shape": SHAPE_BOW}},
	"bronze_bow": {"palette": BRONZE, PART_WEAPON: {"shape": SHAPE_BOW}},
	"iron_bow": {"palette": IRON, PART_WEAPON: {"shape": SHAPE_BOW}},
	"steel_bow": {"palette": STEEL, PART_WEAPON: {"shape": SHAPE_BOW}},
	"wooden_staff": {"palette": WOOD, PART_WEAPON: {"shape": SHAPE_STAFF}},
	"bronze_staff": {"palette": BRONZE, PART_WEAPON: {"shape": SHAPE_STAFF}},
	"iron_staff": {"palette": IRON, PART_WEAPON: {"shape": SHAPE_STAFF}},
	"steel_staff": {"palette": STEEL, PART_WEAPON: {"shape": SHAPE_STAFF}},
	# Armour: a band on the helm from bronze and a nose guard from iron, pauldrons on the body
	# from bronze, greaves under the kilt from iron.
	"wooden_helm": {"palette": WOOD, PART_HEAD: {"shape": SHAPE_HELM}},
	"wooden_body": {"palette": WOOD, PART_BODY: {"shape": SHAPE_VEST}},
	"wooden_legs": {"palette": WOOD, PART_HIPS: {"shape": SHAPE_KILT}, PART_SHIN: {}},
	"bronze_helm": {"palette": BRONZE, PART_HEAD: {"shape": SHAPE_HELM, "band": true}},
	"bronze_body": {"palette": BRONZE, PART_BODY: {"shape": SHAPE_VEST, "pauldrons": true}},
	"bronze_legs": {"palette": BRONZE, PART_HIPS: {"shape": SHAPE_KILT}, PART_SHIN: {}},
	"iron_helm": {"palette": IRON, PART_HEAD: {"shape": SHAPE_HELM, "band": true, "nose_guard": true}},
	"iron_body": {"palette": IRON, PART_BODY: {"shape": SHAPE_VEST, "pauldrons": true}},
	"iron_legs": {"palette": IRON, PART_HIPS: {"shape": SHAPE_KILT}, PART_SHIN: {"shape": SHAPE_GREAVE}},
	"steel_helm": {"palette": STEEL, PART_HEAD: {"shape": SHAPE_HELM, "band": true, "nose_guard": true}},
	"steel_body": {"palette": STEEL, PART_BODY: {"shape": SHAPE_VEST, "pauldrons": true}},
	"steel_legs": {"palette": STEEL, PART_HIPS: {"shape": SHAPE_KILT}, PART_SHIN: {"shape": SHAPE_GREAVE}},
	# Fur
	"fur_hood": {"palette": FUR, PART_HEAD: {"shape": SHAPE_FUR_HOOD}},
	"fur_coat": {"palette": FUR, PART_BODY: {"shape": SHAPE_FUR_COAT}},
	"fur_legs": {"palette": FUR, PART_HIPS: {"shape": SHAPE_FUR_LEGGINGS}, PART_SHIN: {"shape": SHAPE_FUR_BAND}},
}


static func has(item: String) -> bool:
	return LOOKS.has(item)


## The colours `item` is drawn in, or all magenta when it has no entry.
static func palette(item: String) -> Dictionary:
	return LOOKS[item]["palette"] if LOOKS.has(item) else MISSING


## What `item` draws on `part`: its shape's numbers with the entry's own laid over them, or {}
## for nothing there. An item with no entry, or an entry without the part, draws its slot's
## plain shape.
static func piece(item: String, part: String) -> Dictionary:
	var own: Dictionary = LOOKS.get(item, {}).get(part, _plain(item, part))
	if own.is_empty():
		return {}
	var out: Dictionary = (SHAPES[own["shape"]] as Dictionary).duplicate()
	out.merge(own, true)
	return out


## The shape a part draws with no look to say otherwise: the plainest of its slot.
static func _plain(item: String, part: String) -> Dictionary:
	match part:
		PART_HEAD:
			return {"shape": SHAPE_HELM}
		PART_BODY:
			return {"shape": SHAPE_VEST}
		PART_HIPS:
			return {"shape": SHAPE_KILT}
		PART_WEAPON:
			match ItemTable.ITEMS.get(item, {}).get("style", ""):
				CombatTable.STYLE_RANGED:
					return {"shape": SHAPE_BOW}
				CombatTable.STYLE_MAGIC:
					return {"shape": SHAPE_STAFF}
			return {"shape": SHAPE_SWORD}
		PART_TOOL:
			match ItemTable.tool(item) if ItemTable.has(item) else "":
				ItemTable.TOOL_ROD:
					return {"shape": SHAPE_ROD}
				ItemTable.TOOL_PICKAXE:
					return {"shape": SHAPE_PICKAXE}
			return {"shape": SHAPE_AXE}
	return {}
