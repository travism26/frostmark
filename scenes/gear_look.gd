## What each piece of gear looks like on the character, keyed by item id: the one place a
## gear look is tuned. CharacterGear reads every colour, shape and number from here, so
## changing how a set looks is an edit to its entries and a re-shoot with
## `tools/gear_shots.gd`, never a hunt through the builders. Pure data, like the sim: no
## nodes, no scene, no rendering.
##
## An entry holds a `palette` and, for each part the item draws, a piece: a Dictionary
## naming its `shape` and only the numbers it changes from that shape's defaults in SHAPES.
## A helm draws on PART_HEAD, a body on PART_BODY, legs on PART_HIPS and PART_SHIN (an empty
## shin piece leaves the shin bare), a weapon on PART_WEAPON, a tool on PART_TOOL, a quiver on
## PART_QUIVER and a cape on PART_CAPE (a cloak shape, hung from the chest behind the body).
##
## An item with no entry draws the plain shape of its slot all in magenta, so a missing look
## shows.
##
## The kit shapes (a peaked hood, an under-robe with coat panels, a cloak, a collar, stacked
## plates, a crystal, a fin, a prism stack, studs, edge trim and a quiver) are the layered, non-round
## pieces the set looks are built from. Each has its numbers in SHAPES like any other shape and
## a builder of the same name in CharacterGear; KIT_SAMPLES holds one look of each for the
## shader warm-up and the kit shots.
class_name GearLook
extends RefCounted

const PART_HEAD := "head"
const PART_BODY := "body"
const PART_HIPS := "hips"
const PART_SHIN := "shin"
const PART_WEAPON := "weapon"
const PART_TOOL := "tool"
const PART_QUIVER := "quiver"
const PART_CAPE := "cape"

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
## The kit shapes (#160).
const SHAPE_PEAKED_HOOD := "PeakedHood"
const SHAPE_UNDER_ROBE := "UnderRobe"
const SHAPE_CLOAK := "Cloak"
const SHAPE_COLLAR := "Collar"
const SHAPE_STACKED_PLATES := "StackedPlates"
const SHAPE_CRYSTAL := "Crystal"
const SHAPE_FIN := "Fin"
const SHAPE_PRISM_STACK := "PrismStack"
const SHAPE_STUDS := "Studs"
const SHAPE_EDGE_TRIM := "EdgeTrim"
## The quiver slot's shape (#161).
const SHAPE_QUIVER := "Quiver"
const KIT_SHAPES := [
	SHAPE_PEAKED_HOOD, SHAPE_UNDER_ROBE, SHAPE_CLOAK, SHAPE_COLLAR, SHAPE_STACKED_PLATES,
	SHAPE_CRYSTAL, SHAPE_FIN, SHAPE_PRISM_STACK, SHAPE_STUDS, SHAPE_EDGE_TRIM, SHAPE_QUIVER,
]
## A cloak's outline: one straight hem, two halves parting in a V, a ragged hem, a long
## centre tail, or a banner on a pole rising over the shoulders.
const OUTLINE_PLAIN := "plain"
const OUTLINE_FORKED := "forked"
const OUTLINE_TORN := "torn"
const OUTLINE_TAIL := "tail"
const OUTLINE_BANNER := "banner"
const OUTLINES := [OUTLINE_PLAIN, OUTLINE_FORKED, OUTLINE_TORN, OUTLINE_TAIL, OUTLINE_BANNER]
## A collar's kind: a high collar, a jagged ice collar, a stone back-plate, or an upright hoop.
const COLLAR_HIGH := "high"
const COLLAR_JAGGED := "jagged"
const COLLAR_PLATE := "plate"
const COLLAR_HOOP := "hoop"
const COLLARS := [COLLAR_HIGH, COLLAR_JAGGED, COLLAR_PLATE, COLLAR_HOOP]
## What shows above a quiver's cap band: arrow shafts with fletching, or crystal shard tips.
const TIPS_FLETCHING := "fletching"
const TIPS_SHARDS := "shards"
const QUIVER_TIPS := [TIPS_FLETCHING, TIPS_SHARDS]

## Every palette carries exactly these fields.
##   base         Color  the piece itself: a dome, vest, greave or fur wrap, a blade or haft
##   dark         Color  the underside: the kilt under the vest
##   trim         Color  bands and edges: a helm's band and nose guard, fur's pale ruff, hem
##                       and shin band
##   accent       Color  raised pieces: pauldrons, the pale hoop framing a fur hood's face
##   glow         Color  what a glowing part shines in: a staff's crystal, and a kit shape's
##                       highlight whenever its look's `glow` is above 0
##   glow_energy  float  how bright the staff's glow is; 0 draws it unlit
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
## The kit samples' colours: dusk violet under bone, lit aurora green.
const KIT := {
	"base": Color(0.24, 0.18, 0.42), "dark": Color(0.16, 0.12, 0.30),
	"trim": Color(0.91, 0.89, 0.82), "accent": Color(0.55, 0.48, 0.35),
	"glow": Color(0.50, 0.94, 0.77), "glow_energy": 1.5,
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
	# The kit shapes. Every one draws at least two tones, a base plus a darker underside or a
	# lighter trim, so it reads lit from above without a texture; `glow` above 0 draws its
	# highlight in the palette's glow colour, shining that bright. Metres and radians in the
	# part's mount frame (+X right, +Y up, -Z forward).
	# A hood crown with a peak fin swept back from its top, a drape down the neck in the dark
	# tone and a hoop trimming the face opening, so the head is a teardrop from above.
	SHAPE_PEAKED_HOOD: {
		"radius": 0.5, "height": 0.5, "segments": 10, "rings": 4, "y": 0.34,
		"peak_length": 0.6, "peak_width": 0.36, "peak_tilt": 1.2, "peak_offset": Vector3(0, 0.62, 0.2),
		"drape_radius": 0.46, "drape_height": 0.4, "drape_offset": Vector3(0, 0.2, 0.1),
		"hoop_inner": 0.4, "hoop_outer": 0.47, "hoop_rings": 10, "hoop_segments": 6,
		"hoop_offset": Vector3(0, 0.2, -0.36), "glow": 0.0,
	},
	# A flaring under-robe in the dark tone with `bands` bands up from its hem, under a coat
	# shell set `coat_back` behind the body so the robe shows at the open front, and two
	# front panels hanging from the coat's hem, each its own length and flared apart.
	SHAPE_UNDER_ROBE: {
		"top_radius": 0.36, "bottom_radius": 0.56, "height": 1.05, "segments": 10, "y": -0.35,
		"coat_top_radius": 0.4, "coat_bottom_radius": 0.52, "coat_height": 0.6, "coat_y": -0.12, "coat_back": 0.1,
		"panel_left": 0.55, "panel_right": 0.4, "panel_width": 0.2, "panel_thickness": 0.04,
		"panel_x": 0.17, "panel_z": -0.46, "panel_top": -0.3, "panel_flare": 0.12, "panel_lean": 0.2,
		"bands": 2, "band_height": 0.05, "band_from": -0.75, "band_step": 0.2, "glow": 0.0,
	},
	# A fin hung from the shoulders behind the body, in two halves each its own length, with
	# a hem band; `outline` picks plain, forked, torn, tail or banner.
	SHAPE_CLOAK: {
		"width": 0.6, "length_left": 0.9, "length_right": 0.9, "thickness": 0.04,
		"offset": Vector3(0, 0.2, 0.36), "tilt": 0.12, "hem": 0.05,
		"outline": OUTLINE_PLAIN, "fork": 0.22, "teeth": 3, "tooth": 0.12,
		"tail_length": 0.45, "tail_width": 0.25, "banner_rise": 0.7, "banner_width": 0.3, "glow": 0.0,
	},
	# An upright plate behind the neck leaning `tilt` back, over a dark backing, with a lit
	# top edge: `kind` picks a high collar, a jagged collar with `teeth` points, a wider
	# thicker back-plate, or an upright hoop with `teeth` fins on its rim.
	SHAPE_COLLAR: {
		"kind": COLLAR_HIGH, "width": 0.64, "height": 0.5, "thickness": 0.05,
		"offset": Vector3(0, 0.26, 0.3), "tilt": 0.45, "teeth": 5, "tooth": 0.18,
		"hoop_inner": 0.3, "hoop_outer": 0.4, "hoop_rings": 10, "hoop_segments": 6, "glow": 0.0,
	},
	# Two or three plates on each shoulder, the top one in the base tone and each lower one
	# darker, `step` further out and down and `grow` larger; each side has its own count and
	# size, and a lit trim runs along the top plate's outer edge.
	SHAPE_STACKED_PLATES: {
		"plates_left": 2, "plates_right": 2,
		"size_left": Vector3(0.28, 0.08, 0.32), "size_right": Vector3(0.28, 0.08, 0.32),
		"x": 0.4, "y": 0.18, "tilt": 0.35, "step": Vector3(0.05, -0.07, 0), "grow": 0.1, "trim": 0.03, "glow": 0.0,
	},
	# A prism with `facets` sides, its tip in the glow colour over a dark root, tilted by
	# `tilt`; `light` adds one small light at the tip and `motes` a few glowing motes.
	SHAPE_CRYSTAL: {
		"facets": 4, "length": 0.3, "radius": 0.06, "root": 0.3, "offset": Vector3.ZERO, "tilt": Vector3.ZERO,
		"glow": 1.0, "light": false, "light_energy": 1.0, "light_range": 3.0,
		"motes": false, "motes_count": 4, "motes_radius": 0.25, "motes_size": 0.03, "motes_rise": 0.3,
	},
	# A thin flat plate standing up from its root, `size` wide, long and thick, with a lit
	# edge along its tip, or `teeth` points there when `jagged`.
	SHAPE_FIN: {
		"size": Vector3(0.14, 0.3, 0.04), "offset": Vector3.ZERO, "tilt": Vector3.ZERO,
		"jagged": false, "teeth": 3, "tooth": 0.06, "edge": 0.025, "glow": 0.0,
	},
	# `count` prisms stacked end to end, each `bend` further round and `taper` as wide as the
	# one below, from a dark root through the base tone to an accent (or lit) tip.
	SHAPE_PRISM_STACK: {
		"count": 3, "length": 0.45, "radius": 0.07, "facets": 4, "bend": 0.35, "taper": 0.7,
		"offset": Vector3.ZERO, "tilt": Vector3.ZERO, "glow": 0.0,
	},
	# `count` small spheres in the accent tone spaced over `arc` of a dark band of `radius`,
	# centred on the front.
	SHAPE_STUDS: {
		"count": 5, "radius": 0.42, "arc": PI, "y": -0.28, "stud": 0.035, "band_height": 0.05, "segments": 10, "glow": 0.0,
	},
	# A thin raised rim in the trim tone round a plate `size` across (x and z) and `size.y`
	# tall, over a dark shadow line, so the plate catches a highlight from above; `round`
	# draws it as a hoop of `radius` instead.
	SHAPE_EDGE_TRIM: {
		"size": Vector3(0.3, 0.03, 0.34), "offset": Vector3.ZERO, "tilt": Vector3.ZERO, "lip": 0.025,
		"round": false, "radius": 0.37, "segments": 10, "glow": 0.0,
	},
	# A case `length` long on the back, its root at `offset` low on the shoulder blade and turned
	# by `tilt` so its mouth tops the right shoulder, clear of a tool slung the other way: a
	# dark foot, a cap band round the mouth, and `tip_count` fletched shafts or shard tips
	# standing `tip_length` out of it.
	SHAPE_QUIVER: {
		"length": 0.6, "radius": 0.09, "segments": 8, "offset": Vector3(0.16, -0.22, 0.42),
		"tilt": Vector3(0.12, 0, -0.42), "foot": 0.06, "band_height": 0.05,
		"tips": TIPS_FLETCHING, "tip_count": 3, "tip_length": 0.16, "glow": 0.0,
	},
}

## One look of each kit shape, for the shader warm-up (a light and motes included) and the kit
## shots: unequal sides where a shape has them, a jagged edge, a lit highlight.
const KIT_SAMPLES := [
	{"shape": SHAPE_PEAKED_HOOD, "glow": 0.6},
	{"shape": SHAPE_UNDER_ROBE, "panel_left": 0.6, "panel_right": 0.42, "glow": 1.0},
	{"shape": SHAPE_CLOAK, "outline": OUTLINE_FORKED, "length_left": 0.95, "length_right": 0.8, "glow": 0.8},
	{"shape": SHAPE_COLLAR, "kind": COLLAR_JAGGED, "glow": 1.2},
	{"shape": SHAPE_STACKED_PLATES, "plates_left": 3, "plates_right": 2, "size_left": Vector3(0.32, 0.08, 0.36), "glow": 0.8},
	{"shape": SHAPE_CRYSTAL, "length": 0.45, "radius": 0.1, "glow": 1.6, "light": true, "light_energy": 1.5, "motes": true, "offset": Vector3(0, 0.7, 0)},
	{"shape": SHAPE_FIN, "size": Vector3(0.2, 0.45, 0.04), "jagged": true, "offset": Vector3(0, 0.72, 0.05), "tilt": Vector3(0.4, 0, 0), "glow": 1.0},
	{"shape": SHAPE_PRISM_STACK, "offset": Vector3(0.32, 0.55, 0), "tilt": Vector3(0, 0, -0.7), "glow": 1.2},
	{"shape": SHAPE_STUDS, "glow": 1.0},
	{"shape": SHAPE_EDGE_TRIM, "size": Vector3(0.3, 0.03, 0.3), "offset": Vector3(0, 0.02, -0.37), "tilt": Vector3(-1.45, 0, 0), "glow": 0.6},
	{"shape": SHAPE_QUIVER, "tips": TIPS_SHARDS, "tip_count": 4, "glow": 1.0},
]

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
	return numbers(own)


## A look to build from: the numbers of the shape `own` names, with `own`'s laid over them.
static func numbers(own: Dictionary) -> Dictionary:
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
		PART_QUIVER:
			return {"shape": SHAPE_QUIVER}
		PART_CAPE:
			return {"shape": SHAPE_CLOAK}
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
