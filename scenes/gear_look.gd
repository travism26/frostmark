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
## A piece may carry `layers`: more pieces drawn on the same part over the first, each a
## Dictionary of the same form (a shape and its own numbers, placed by that shape's offset,
## tilt or y in the part's mount frame). That is how a set piece stacks a band, studs, cheek
## guards or a crest on a helm, or a sash, a ruff and pauldrons on a vest: every layer is in
## the entry, so the whole piece is tuned here. A layer draws on its own part only, so a piece
## never depends on what the other slots wear.
##
## A shape's tone numbers (`tone`, `band_tone`, `edge_tone` and the like) name the palette
## field a part is drawn in, or carry a Color of their own for a set that needs a fifth
## material (a blood-red sash, a brass axe cap, a lit rim tint). A tier look never sets them.
##
## An item with no entry draws the plain shape of its slot all in magenta, so a missing look
## shows.
##
## The kit shapes (a peaked hood, an under-robe with coat panels, a cloak, a collar, stacked
## plates, a crystal, a fin, a prism stack, studs, edge trim, a quiver, a sash, a ruff, faulds,
## tassets, a seam, a shard crown, antlers, and the hand-held weapons: a broadsword, a bearded
## axe, a greatsword, a forge hammer, a glaive and a cleaver) are the layered, non-round pieces
## the set looks are built from. Each has its numbers in SHAPES like any other shape and a
## builder of the same name in CharacterGear; KIT_SAMPLES holds one look of each for the shader
## warm-up and the kit shots.
##
## A top set's light and particles are look numbers too: a crystal, a shard crown or a forge
## hammer carries one small light (`light`) or a few motes (`motes`) only when its entry asks,
## so a set's glow is tuned here and a piece worn alone keeps its own.
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
## The melee set shapes (#162).
const SHAPE_SASH := "Sash"
const SHAPE_RUFF := "Ruff"
const SHAPE_FAULDS := "Faulds"
const SHAPE_TASSETS := "Tassets"
const SHAPE_BROADSWORD := "Broadsword"
const SHAPE_BEARDED_AXE := "BeardedAxe"
const SHAPE_GREATSWORD := "Greatsword"
## The melee top set shapes (#163).
const SHAPE_SEAM := "Seam"
const SHAPE_SHARD_CROWN := "ShardCrown"
const SHAPE_ANTLERS := "Antlers"
const SHAPE_FORGE_HAMMER := "ForgeHammer"
const SHAPE_GLAIVE := "Glaive"
const SHAPE_CLEAVER := "Cleaver"
const KIT_SHAPES := [
	SHAPE_PEAKED_HOOD, SHAPE_UNDER_ROBE, SHAPE_CLOAK, SHAPE_COLLAR, SHAPE_STACKED_PLATES,
	SHAPE_CRYSTAL, SHAPE_FIN, SHAPE_PRISM_STACK, SHAPE_STUDS, SHAPE_EDGE_TRIM, SHAPE_QUIVER,
	SHAPE_SASH, SHAPE_RUFF, SHAPE_FAULDS, SHAPE_TASSETS, SHAPE_SEAM, SHAPE_SHARD_CROWN, SHAPE_ANTLERS,
	SHAPE_BROADSWORD, SHAPE_BEARDED_AXE, SHAPE_GREATSWORD, SHAPE_FORGE_HAMMER, SHAPE_GLAIVE, SHAPE_CLEAVER,
]
## The kit shapes held in the hand: each is a whole weapon, gripped in the right hand.
const WEAPON_SHAPES := [SHAPE_BROADSWORD, SHAPE_BEARDED_AXE, SHAPE_GREATSWORD, SHAPE_FORGE_HAMMER, SHAPE_GLAIVE, SHAPE_CLEAVER]
## The kit shapes that may carry the one small light and the few motes a top set is allowed.
const GLOW_FX_SHAPES := [SHAPE_CRYSTAL, SHAPE_SHARD_CROWN, SHAPE_FORGE_HAMMER]
## The key a piece's extra layers sit under.
const LAYERS := "layers"
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
## The melee sets' palettes (#162, the approved board on #157). None has a staff, so
## glow_energy is 0; Ruinwarden's glow is the colour its chest rune and fuller shine in.
## Hearthguard: blue steel, its recessed band, brass trim, leather straps.
const HEARTHGUARD := {
	"base": Color("#7d8aa3"), "dark": Color("#5c6880"),
	"trim": Color("#d9a64a"), "accent": Color("#8a5a2b"),
	"glow": Color.BLACK, "glow_energy": 0.0,
}
## Wolfmark: dark iron and its shade, pale fur trim, the grey pelt; the blood sash and brass
## cap are the pieces' own colours.
const WOLFMARK := {
	"base": Color("#4e5668"), "dark": Color("#363c4c"),
	"trim": Color("#d8ccb8"), "accent": Color("#8c8070"),
	"glow": Color.BLACK, "glow_energy": 0.0,
}
## Ruinwarden: old gold over its dark, verdigris trim, the crimson plume, the rune's glow.
const RUINWARDEN := {
	"base": Color("#b08a3c"), "dark": Color("#4a3a1e"),
	"trim": Color("#5f8a7a"), "accent": Color("#a8302a"),
	"glow": Color("#6fe3c8"), "glow_energy": 0.0,
}
## The lit rim tints the sets' plates catch (the third tint of a material, beside its base and
## its recessed shade), and the sets' extra materials.
const HEARTHGUARD_LIT := Color("#9aa6bc")
const WOLFMARK_BLOOD := Color("#a8302a")
const WOLFMARK_BLOOD_DARK := Color("#731f1b")
const WOLFMARK_BRASS := Color("#c9963f")
const WOLFMARK_ASH := Color("#a89a7c")
const RUINWARDEN_LIT := Color("#d4b05c")
const RUINWARDEN_VERDIGRIS_LIT := Color("#7fae9c")
const RUINWARDEN_PLUME_DARK := Color("#731f1b")
const RUINWARDEN_PLUME_LIT := Color("#d8514a")
## The melee top sets' palettes (#163, the approved board on #157). The glow is the colour a
## set's seams, shard tips, trim or cracks shine in (the only melee sets allowed a light or
## particles); Trollbone has none, on purpose. None has a staff, so glow_energy is 0.
## Emberheart: forge black and its recessed shade, dark bronze bands and straps, horn.
const EMBERHEART := {
	"base": Color("#2e2a33"), "dark": Color("#1c1921"),
	"trim": Color("#8a3a1a"), "accent": Color("#3a3340"),
	"glow": Color("#ff7a1f"), "glow_energy": 0.0,
}
## Hoarfrost: ice over the dark-blue harness, white fur, ice shade.
const HOARFROST := {
	"base": Color("#cfe3f2"), "dark": Color("#3a4a6a"),
	"trim": Color("#f1ece2"), "accent": Color("#a9d4ef"),
	"glow": Color("#7fd4ff"), "glow_energy": 0.0,
}
## Auroral: dusk violet and its shade, lilac trim, pale antler.
const AURORAL := {
	"base": Color("#3f3670"), "dark": Color("#2a2350"),
	"trim": Color("#b08cff"), "accent": Color("#e8dcc0"),
	"glow": Color("#6ff0b0"), "glow_energy": 0.0,
}
## Trollbone: hide, dark, bone, blood.
const TROLLBONE := {
	"base": Color("#4a3a2e"), "dark": Color("#2a2238"),
	"trim": Color("#e8dcc0"), "accent": Color("#a3302a"),
	"glow": Color.BLACK, "glow_energy": 0.0,
}
## The top sets' lit rim tints and extra materials.
const EMBERHEART_LIT := Color("#46404e")
const EMBERHEART_BRONZE_LIT := Color("#a85a2c")
const HOARFROST_LIT := Color("#eef6fc")
const HOARFROST_HARNESS_LIT := Color("#55688c")
const AURORAL_LIT := Color("#574b98")
const AURORAL_ANTLER_LIT := Color("#f6efdc")
const TROLLBONE_BONE_DARK := Color("#b8a98c")
const TROLLBONE_BONE_LIT := Color("#f6efdc")
const TROLLBONE_HIDE_LIT := Color("#62503f")
const TROLLBONE_BLOOD_DARK := Color("#731f1b")

## Each shape's numbers (metres and radians in the part's mount frame, segment counts) and
## switches, as drawn when a piece changes none of them.
const SHAPES := {
	# A dome over the crown in `tone`; `band` adds a band round its rim, `nose_guard` a guard
	# down the nose.
	SHAPE_HELM: {
		"radius": 0.47, "height": 0.42, "y": 0.4, "segments": 8, "rings": 3, "tone": "base",
		"band": false, "band_radius": 0.48, "band_height": 0.08, "band_y": 0.42, "band_tone": "trim",
		"nose_guard": false, "nose_size": Vector3(0.07, 0.2, 0.06), "nose_offset": Vector3(0, 0.34, -0.47),
		"nose_tone": "trim",
	},
	# A round crown, a drape down the back of the head and a hoop framing the face.
	SHAPE_FUR_HOOD: {
		"radius": 0.5, "height": 0.5, "segments": 10, "rings": 4, "y": 0.34, "tone": "base",
		"drape_offset": Vector3(0, 0.24, 0.02),
		"hoop_inner": 0.38, "hoop_outer": 0.5, "hoop_rings": 10, "hoop_segments": 6,
		"hoop_offset": Vector3(0, 0.2, -0.36), "hoop_tone": "accent",
	},
	# A vest round the chest in `tone`; `pauldrons` adds a pad on each shoulder.
	SHAPE_VEST: {
		"top_radius": 0.34, "bottom_radius": 0.36, "height": 0.5, "segments": 8, "y": -0.06, "tone": "base",
		"pauldrons": false, "pauldron_size": Vector3(0.26, 0.1, 0.32), "pauldron_x": 0.4,
		"pauldron_y": 0.16, "pauldron_tilt": 0.35, "pauldron_tone": "accent",
	},
	# A bulky coat flaring to the hem, a thick collar ruff and a hem band.
	SHAPE_FUR_COAT: {
		"top_radius": 0.40, "bottom_radius": 0.46, "height": 0.6, "segments": 10, "y": -0.1, "tone": "base",
		"ruff_inner": 0.24, "ruff_outer": 0.54, "ruff_rings": 10, "ruff_segments": 6, "ruff_y": 0.22,
		"hem_radius": 0.47, "hem_height": 0.08, "hem_y": -0.38, "trim_tone": "trim",
	},
	# A kilt flaring from the hips, in the dark tone unless the look says otherwise.
	SHAPE_KILT: {"top_radius": 0.38, "bottom_radius": 0.46, "height": 0.26, "segments": 8, "y": -0.08, "tone": "dark"},
	# A close wrap round the hips.
	SHAPE_FUR_LEGGINGS: {"top_radius": 0.40, "bottom_radius": 0.41, "height": 0.3, "segments": 10, "y": -0.1, "tone": "base"},
	# A greave round the shin.
	SHAPE_GREAVE: {"top_radius": 0.16, "bottom_radius": 0.14, "height": 0.22, "segments": 8, "y": -0.12, "tone": "base"},
	# A wrap down the shin with a thick band at its top: a fur band, or a greave with a trim
	# band or a fur top in `band_tone`.
	SHAPE_FUR_BAND: {
		"top_radius": 0.165, "bottom_radius": 0.15, "height": 0.24, "segments": 8, "y": -0.12, "tone": "base",
		"band_radius": 0.19, "band_height": 0.12, "band_y": -0.04, "band_tone": "trim",
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
		"hoop_offset": Vector3(0, 0.2, -0.36), "tone": "base", "drape_tone": "dark", "hoop_tone": "trim", "glow": 0.0,
	},
	# A flaring under-robe in the dark tone with `bands` bands up from its hem, under a coat
	# shell set `coat_back` behind the body so the robe shows at the open front, and two
	# front panels hanging from the coat's hem, each its own length and flared apart.
	SHAPE_UNDER_ROBE: {
		"top_radius": 0.36, "bottom_radius": 0.56, "height": 1.05, "segments": 10, "y": -0.35,
		"coat_top_radius": 0.4, "coat_bottom_radius": 0.52, "coat_height": 0.6, "coat_y": -0.12, "coat_back": 0.1,
		"panel_left": 0.55, "panel_right": 0.4, "panel_width": 0.2, "panel_thickness": 0.04,
		"panel_x": 0.17, "panel_z": -0.46, "panel_top": -0.3, "panel_flare": 0.12, "panel_lean": 0.2,
		"bands": 2, "band_height": 0.05, "band_from": -0.75, "band_step": 0.2,
		"tone": "base", "robe_tone": "dark", "band_tone": "trim", "glow": 0.0,
	},
	# A fin hung from the shoulders behind the body, in two halves each its own length, with
	# a hem band; `outline` picks plain, forked, torn, tail or banner.
	SHAPE_CLOAK: {
		"width": 0.6, "length_left": 0.9, "length_right": 0.9, "thickness": 0.04,
		"offset": Vector3(0, 0.2, 0.36), "tilt": 0.12, "hem": 0.05,
		"outline": OUTLINE_PLAIN, "fork": 0.22, "teeth": 3, "tooth": 0.12,
		"tail_length": 0.45, "tail_width": 0.25, "banner_rise": 0.7, "banner_width": 0.3,
		"tone": "base", "hem_tone": "trim", "tooth_tone": "dark", "glow": 0.0,
	},
	# An upright plate behind the neck leaning `tilt` back, over a dark backing, with a lit
	# top edge: `kind` picks a high collar, a jagged collar with `teeth` points, a wider
	# thicker back-plate, or an upright hoop with `teeth` fins on its rim.
	SHAPE_COLLAR: {
		"kind": COLLAR_HIGH, "width": 0.64, "height": 0.5, "thickness": 0.05,
		"offset": Vector3(0, 0.26, 0.3), "tilt": 0.45, "teeth": 5, "tooth": 0.18,
		"hoop_inner": 0.3, "hoop_outer": 0.4, "hoop_rings": 10, "hoop_segments": 6,
		"tone": "base", "back_tone": "dark", "edge_tone": "trim", "glow": 0.0,
	},
	# Two or three plates on each shoulder, the top one in `tone` and each lower one in
	# `under_tone`, `step` further out and down and `grow` larger; each side has its own count
	# and size, and a lit trim runs along the top plate's outer edge. `round` makes each plate
	# a dome (a small round pauldron) with the trim as a hoop round its foot.
	SHAPE_STACKED_PLATES: {
		"plates_left": 2, "plates_right": 2,
		"size_left": Vector3(0.28, 0.08, 0.32), "size_right": Vector3(0.28, 0.08, 0.32),
		"x": 0.4, "y": 0.18, "tilt": 0.35, "step": Vector3(0.05, -0.07, 0), "grow": 0.1, "trim": 0.03,
		"round": false, "tone": "base", "under_tone": "dark", "trim_tone": "trim", "glow": 0.0,
	},
	# A prism with `facets` sides, its tip in the glow colour over a dark root, tilted by
	# `tilt`; `light` adds one small light at the tip and `motes` a few glowing motes.
	SHAPE_CRYSTAL: {
		"facets": 4, "length": 0.3, "radius": 0.06, "root": 0.3, "offset": Vector3.ZERO, "tilt": Vector3.ZERO,
		"glow": 1.0, "light": false, "light_energy": 1.0, "light_range": 3.0,
		"motes": false, "motes_count": 4, "motes_radius": 0.25, "motes_size": 0.03, "motes_rise": 0.3,
		"root_tone": "dark",
	},
	# A thin flat plate standing up from its root, `size` wide, long and thick, with a lit
	# edge along its tip, or `teeth` points there when `jagged`.
	SHAPE_FIN: {
		"size": Vector3(0.14, 0.3, 0.04), "offset": Vector3.ZERO, "tilt": Vector3.ZERO,
		"jagged": false, "teeth": 3, "tooth": 0.06, "edge": 0.025, "tone": "base", "edge_tone": "trim", "glow": 0.0,
	},
	# `count` prisms stacked end to end, each `bend` further round and `taper` as wide as the
	# one below, from a dark root through the base tone to an accent (or lit) tip.
	SHAPE_PRISM_STACK: {
		"count": 3, "length": 0.45, "radius": 0.07, "facets": 4, "bend": 0.35, "taper": 0.7,
		"offset": Vector3.ZERO, "tilt": Vector3.ZERO, "root_tone": "dark", "tone": "base", "tip_tone": "accent", "glow": 0.0,
	},
	# `count` small spheres in the accent tone spaced over `arc` of a dark band of `radius`,
	# centred on the front.
	SHAPE_STUDS: {
		"count": 5, "radius": 0.42, "arc": PI, "y": -0.28, "stud": 0.035, "band_height": 0.05, "segments": 10,
		"band_tone": "dark", "stud_tone": "accent", "glow": 0.0,
	},
	# A thin raised rim in the trim tone round a plate `size` across (x and z) and `size.y`
	# tall, over a dark shadow line, so the plate catches a highlight from above; `round`
	# draws it as a hoop of `radius` instead.
	SHAPE_EDGE_TRIM: {
		"size": Vector3(0.3, 0.03, 0.34), "offset": Vector3.ZERO, "tilt": Vector3.ZERO, "lip": 0.025,
		"round": false, "radius": 0.37, "segments": 10, "tone": "trim", "shadow_tone": "dark", "glow": 0.0,
	},
	# The melee set shapes (#162). A strap from one shoulder across the chest to the opposite
	# hip: a box `width` wide, `length` long and `thickness` thick at `offset`, rolled `roll`
	# round the body and leaning `lean` into the chest, in `tone` with a rail along each edge
	# in `edge_tone` (the highlight) over a `shadow_tone` strip; `buckle` adds a plate in
	# `buckle_tone` at its middle.
	SHAPE_SASH: {
		"width": 0.12, "length": 0.74, "thickness": 0.035, "offset": Vector3(0, -0.05, -0.33),
		"roll": 0.6, "lean": 0.1, "edge": 0.015, "tone": "accent", "edge_tone": "trim", "shadow_tone": "dark",
		"buckle": false, "buckle_size": Vector3(0.1, 0.1, 0.03), "buckle_tone": "trim", "glow": 0.0,
	},
	# A thick hoop round the shoulders or neck at `y`, `inner` to `outer` across, in `tone`,
	# with a thin hoop in `trim_tone` (the highlight) along its inner edge: a fur mantle, a
	# gorget, a collar ruff.
	SHAPE_RUFF: {
		"inner": 0.24, "outer": 0.5, "rings": 10, "segments": 6, "y": 0.2, "trim": 0.04,
		"tone": "accent", "trim_tone": "trim", "glow": 0.0,
	},
	# `count` plates stacked down the hips from `y`, each `step` lower, `height` tall and `grow`
	# wider than the one above and flaring `flare` to its hem, alternating `tone` and
	# `alt_tone`, with a rim line in `rim_tone` (the highlight) along each plate's top and a
	# `shadow_tone` line under its hem.
	SHAPE_FAULDS: {
		"count": 3, "y": 0.03, "step": 0.085, "height": 0.1, "radius": 0.385, "grow": 0.035, "flare": 0.03,
		"rim": 0.015, "segments": 8, "tone": "base", "alt_tone": "dark", "rim_tone": "trim", "shadow_tone": "dark", "glow": 0.0,
	},
	# `count` flat plates hung from the hips at `y`, `radius` out, spaced over `arc` centred on
	# the front, each `size` wide, long and thick and leaning out `flare` at the hem, in `tone`
	# with the highlight along its hem edge over a `shadow_tone` backing; `belt` adds a band in
	# `belt_tone` they hang from.
	SHAPE_TASSETS: {
		"count": 3, "arc": PI * 1.1, "y": 0.04, "radius": 0.39, "size": Vector3(0.22, 0.24, 0.035), "flare": 0.18,
		"edge": 0.025, "tone": "base", "edge_tone": "trim", "shadow_tone": "dark",
		"belt": true, "belt_height": 0.06, "belt_tone": "dark", "segments": 8, "glow": 0.0,
	},
	# The weapons are built in the hand's mount frame (the grip on the origin) and turned by
	# `tilt`. The barbarian's hand rests in a T-pose, so when the arm hangs the frame's +Y
	# points out to the side and its -X up the forearm; the default tilt holds the weapon
	# halfway between, point up and out past the shoulder, where the 55-degree camera sees its
	# whole length (straight up it hides under the pauldrons and the head). A broadsword: a wide blade `blade_length`
	# long and `blade_width` across ending in a `tip`, over a crosswise guard `guard_size`
	# `rise` above the hand, a grip `grip_length` long below it and a round pommel; the blade in
	# `tone` with a `fuller_tone` groove down it (the highlight: lit when glow is above 0), the
	# guard and pommel in their tones and the grip in `grip_tone`.
	SHAPE_BROADSWORD: {
		"blade_length": 0.78, "blade_width": 0.13, "blade_thickness": 0.03, "tip": 0.16, "fuller_width": 0.03,
		"guard_size": Vector3(0.3, 0.05, 0.07), "rise": 0.1, "grip_length": 0.2, "grip_radius": 0.03, "pommel": 0.045,
		"tilt": Vector3(0, 0, PI * 0.25), "tone": "base", "fuller_tone": "dark", "guard_tone": "trim", "grip_tone": "accent",
		"pommel_tone": "trim", "glow": 0.0,
	},
	# A bearded axe: a haft `haft_length` long in `haft_tone` with a cap `cap` tall in
	# `cap_tone` at its top, the head `head_size` (thin, tall, long) set forward from the haft
	# just under the cap, in `tone`, its beard `beard` long hanging from the head's far end in
	# `beard_tone`, and the edge in `edge_tone` (the highlight) down its front.
	SHAPE_BEARDED_AXE: {
		"haft_length": 0.95, "haft_radius": 0.03, "rise": 0.1, "cap": 0.06, "head_size": Vector3(0.05, 0.2, 0.26),
		"beard": 0.16, "edge": 0.02, "tilt": Vector3(0, 0, PI * 0.25), "tone": "base", "haft_tone": "accent", "cap_tone": "trim",
		"beard_tone": "dark", "edge_tone": "trim", "glow": 0.0,
	},
	# A greatsword taller than the figure: a long blade `blade_length` long with a ridge down
	# its middle ending in a `tip`, over a wide guard `guard_size` whose quillons droop
	# `quillon_droop`, a two-hand grip `grip_length` long with a ring at its middle and a
	# pommel; the blade in `tone`, the ridge in `ridge_tone`, a fuller in `fuller_tone` (the
	# highlight: the glow colour, lit, when glow is above 0) and the fittings in their tones.
	SHAPE_GREATSWORD: {
		"blade_length": 1.25, "blade_width": 0.14, "blade_thickness": 0.035, "tip": 0.2, "ridge_width": 0.05,
		"fuller_width": 0.025, "fuller_length": 0.9, "guard_size": Vector3(0.4, 0.05, 0.08), "quillon_droop": 0.35,
		"rise": 0.14, "grip_length": 0.36, "grip_radius": 0.032, "pommel": 0.05, "tilt": Vector3(0, 0, PI * 0.25),
		"tone": "base", "ridge_tone": "dark", "fuller_tone": "trim", "guard_tone": "trim", "grip_tone": "dark",
		"ring_tone": "trim", "pommel_tone": "trim", "glow": 0.0,
	},
	# The melee top set shapes (#163). A raised strip `size` wide, tall and thick at `offset`
	# turned by `tilt`, its face toward -Z, drawn whole in the highlight (`tone`: the glow
	# colour, lit, when glow is above 0) over a `shadow_tone` backing `lip` wider behind it: a
	# glowing seam or crack, an eye slit, an eye socket, a lashing.
	SHAPE_SEAM: {
		"size": Vector3(0.03, 0.3, 0.03), "offset": Vector3.ZERO, "tilt": Vector3.ZERO, "lip": 0.012,
		"tone": "trim", "shadow_tone": "dark", "glow": 0.0,
	},
	# `count` shards round a ring of `radius` at `offset` turned by `tilt`, spread over `arc`
	# (a full turn for a crown, less for a cluster centred on the front), each leaning out
	# `lean` and every other one `short` as long as its neighbours: a `facets`-sided shard
	# `shard` across and `length` long in `tone`, the top `tip` of it in the highlight
	# (`tip_tone`: the glow colour, lit, when glow is above 0). `light` and `motes` as a
	# crystal takes them.
	SHAPE_SHARD_CROWN: {
		"count": 7, "radius": 0.36, "arc": TAU, "length": 0.3, "short": 0.65, "shard": 0.05, "facets": 4,
		"lean": 0.35, "tip": 0.45, "offset": Vector3(0, 0.55, 0), "tilt": Vector3.ZERO,
		"tone": "base", "tip_tone": "accent", "glow": 0.0,
		"light": false, "light_energy": 1.0, "light_range": 3.0,
		"motes": false, "motes_count": 5, "motes_radius": 0.3, "motes_size": 0.03, "motes_rise": 0.25,
	},
	# Two antlers (`Left` and `Right`) `x` either side of `offset`, each a thin `facets`-sided
	# beam its own length leaning out `spread` and back `sweep`, with its own count of tines
	# branching forward `tine_spread` along it, `tine_length` long; the beams and tines in
	# `tone` with every tip in the highlight (`tip_tone`: the glow colour, lit, when glow is
	# above 0).
	SHAPE_ANTLERS: {
		"length_left": 0.55, "length_right": 0.55, "radius": 0.035, "facets": 5, "x": 0.22,
		"spread": 0.55, "sweep": 0.3, "tines_left": 3, "tines_right": 2, "tine_length": 0.22,
		"tine_radius": 0.025, "tine_spread": 0.9, "offset": Vector3(0, 0.55, 0.05), "tilt": Vector3.ZERO,
		"tone": "accent", "tip_tone": "trim", "glow": 0.0,
	},
	# A forge hammer, built like the other weapons in the hand's frame and turned by `tilt`: a
	# haft `haft_length` long in `haft_tone` with a cap at its foot, a block head `head_size`
	# across (x along the hand, y tall, z deep) in `tone`, a band `band` wide round it `band_x`
	# of its half-width out each side in `band_tone`, and `cracks` strips `crack` wide across
	# its faces in the highlight (`crack_tone`: the glow colour, lit, when glow is above 0).
	# `light` and `motes` as a crystal takes them, at the head.
	SHAPE_FORGE_HAMMER: {
		"haft_length": 0.9, "haft_radius": 0.035, "rise": 0.1, "head_size": Vector3(0.46, 0.2, 0.2),
		"band": 0.04, "band_x": 0.3, "cracks": 3, "crack": 0.022, "tilt": Vector3(0, 0, PI * 0.25),
		"tone": "base", "haft_tone": "accent", "band_tone": "trim", "crack_tone": "trim", "glow": 0.0,
		"light": false, "light_energy": 1.0, "light_range": 3.0,
		"motes": false, "motes_count": 5, "motes_radius": 0.2, "motes_size": 0.03, "motes_rise": 0.3,
	},
	# A glaive: a long haft `haft_length` long in `haft_tone` with a cap at its foot and a
	# `ferrule` tall ferrule under the blade in `ferrule_tone`; the blade `blade_length` long
	# and `blade_width` across standing off one side of the haft's top, leaning `curve` out and
	# ending in a `tip` bent further, in `tone` with a `back` wide spine in `back_tone` along
	# the haft side and the edge `edge` wide along its far side in the highlight (`edge_tone`:
	# the glow colour, lit, when glow is above 0).
	SHAPE_GLAIVE: {
		"haft_length": 1.3, "haft_radius": 0.03, "rise": 0.1, "ferrule": 0.07, "blade_length": 0.45,
		"blade_width": 0.13, "blade_thickness": 0.03, "curve": 0.4, "tip": 0.2, "edge": 0.022, "back": 0.03,
		"tilt": Vector3(0, 0, PI * 0.25), "tone": "base", "haft_tone": "dark", "ferrule_tone": "trim",
		"cap_tone": "trim", "back_tone": "dark", "edge_tone": "trim", "glow": 0.0,
	},
	# A cleaver: a short grip `grip_length` long in `grip_tone` with a `wrap` tall wrap round
	# it in `wrap_tone`, and a broad blade `blade_length` long and `blade_width` across off the
	# grip, leaning `curve` out, swelling to a belly at its far end and ending in a `tip`, in
	# `tone` with a `back` wide spine in `back_tone` and the edge `edge` wide along the belly in
	# the highlight (`edge_tone`: the glow colour, lit, when glow is above 0).
	SHAPE_CLEAVER: {
		"grip_length": 0.24, "grip_radius": 0.03, "rise": 0.08, "wrap": 0.09, "blade_length": 0.55,
		"blade_width": 0.2, "blade_thickness": 0.035, "curve": 0.3, "tip": 0.18, "edge": 0.022, "back": 0.03,
		"tilt": Vector3(0, 0, PI * 0.25), "tone": "trim", "grip_tone": "base", "wrap_tone": "accent",
		"back_tone": "dark", "edge_tone": "accent", "glow": 0.0,
	},
	# A case `length` long on the back, its root at `offset` low on the shoulder blade and turned
	# by `tilt` so its mouth tops the right shoulder, clear of a tool slung the other way: a
	# dark foot, a cap band round the mouth, and `tip_count` fletched shafts or shard tips
	# standing `tip_length` out of it.
	SHAPE_QUIVER: {
		"length": 0.6, "radius": 0.09, "segments": 8, "offset": Vector3(0.2, -0.15, 0.4),
		"tilt": Vector3(0.12, 0, -0.3), "foot": 0.06, "band_height": 0.05,
		"tips": TIPS_FLETCHING, "tip_count": 3, "tip_length": 0.16, "tone": "base", "foot_tone": "dark",
		"band_tone": "trim", "shaft_tone": "dark", "fletch_tone": "trim", "tip_tone": "accent", "glow": 0.0,
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
	{"shape": SHAPE_SASH, "buckle": true, "glow": 0.8},
	{"shape": SHAPE_RUFF, "glow": 0.6},
	{"shape": SHAPE_FAULDS, "glow": 0.6},
	{"shape": SHAPE_TASSETS, "glow": 0.8},
	{"shape": SHAPE_BROADSWORD, "glow": 0.8},
	{"shape": SHAPE_BEARDED_AXE, "glow": 0.8},
	{"shape": SHAPE_GREATSWORD, "glow": 1.0},
	{"shape": SHAPE_SEAM, "size": Vector3(0.04, 0.28, 0.03), "offset": Vector3(0, -0.05, -0.36), "glow": 1.2},
	{"shape": SHAPE_SHARD_CROWN, "glow": 0.8},
	{"shape": SHAPE_ANTLERS, "length_left": 0.6, "length_right": 0.5, "glow": 0.6},
	{"shape": SHAPE_FORGE_HAMMER, "glow": 1.2},
	{"shape": SHAPE_GLAIVE, "glow": 1.0},
	{"shape": SHAPE_CLEAVER, "glow": 0.8},
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
	# The melee sets (#162). Every colour, size, offset and glow for these is here, so a change
	# after playtesting is an edit to one entry and a re-shoot with tools/gear_shots.gd.
	# Hearthguard (mid): outpost militia plate, blue steel strapped in leather and riveted in
	# brass. No glow.
	"hearthguard_helm": {"palette": HEARTHGUARD, PART_HEAD: {
		# a steel cap under a brass band with a dark groove of brass rivets, a shade line under
		# the band, a brass nasal and a short cheek guard each side
		"shape": SHAPE_HELM, "band": true, "band_height": 0.1, "band_y": 0.41, "nose_guard": true, "nose_size": Vector3(0.08, 0.22, 0.06),
		LAYERS: [
			{"shape": SHAPE_STUDS, "count": 7, "radius": 0.49, "arc": PI * 1.1, "y": 0.42, "stud": 0.032, "band_height": 0.025, "stud_tone": "trim"},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.455, "size": Vector3(0, 0.035, 0), "lip": 0.0, "offset": Vector3(0, 0.365, 0), "tone": "dark"},
			{"shape": SHAPE_FIN, "size": Vector3(0.16, 0.2, 0.05), "offset": Vector3(-0.41, 0.17, -0.2), "tilt": Vector3(0, PI * 0.5, -0.12), "edge": 0.03},
			{"shape": SHAPE_FIN, "size": Vector3(0.16, 0.2, 0.05), "offset": Vector3(0.41, 0.17, -0.2), "tilt": Vector3(0, PI * 0.5, 0.12), "edge": 0.03},
		],
	}},
	"hearthguard_body": {"palette": HEARTHGUARD, PART_BODY: {
		# a steel breastplate with a brass rim at the collar and the hem, a leather cross-strap
		# with a brass buckle, and small round pauldrons stepped over a darker under-plate
		"shape": SHAPE_VEST,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.345, "size": Vector3(0, 0.04, 0), "lip": 0.02, "offset": Vector3(0, 0.18, 0)},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.36, "size": Vector3(0, 0.04, 0), "lip": 0.02, "offset": Vector3(0, -0.29, 0)},
			{"shape": SHAPE_SASH, "buckle": true},
			{"shape": SHAPE_STACKED_PLATES, "round": true, "plates_left": 2, "plates_right": 2, "size_left": Vector3(0.24, 0.08, 0.24), "size_right": Vector3(0.24, 0.08, 0.24), "x": 0.37, "y": 0.17, "step": Vector3(0.04, -0.06, 0), "trim_tone": "trim"},
		],
	}},
	"hearthguard_legs": {"palette": HEARTHGUARD, PART_HIPS: {
		# a leather kilt under a brass belt
		"shape": SHAPE_KILT, "tone": "accent",
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.385, "size": Vector3(0, 0.05, 0), "lip": 0.01, "offset": Vector3(0, 0.04, 0)},
		],
	}, PART_SHIN: {
		# a steel greave with a brass rim at its top
		"shape": SHAPE_FUR_BAND, "band_radius": 0.175, "band_height": 0.04, "band_y": -0.02,
	}},
	"hearthguard_broadsword": {"palette": HEARTHGUARD, PART_WEAPON: {"shape": SHAPE_BROADSWORD}},
	# Wolfmark (mid-high): ring-one hunter's plate, dark iron under a grey wolf pelt, the sash
	# dyed in wolf blood. No glow.
	"wolfmark_helm": {"palette": WOLFMARK, PART_HEAD: {
		# a wolf-pelt hood over a dark iron cap rim, two upright pointed ears, a pale muzzle
		# band over the brow and the pelt's tail down the neck
		"shape": SHAPE_HELM, "tone": "accent", "radius": 0.5, "height": 0.46, "y": 0.38, "band": true,
		"band_tone": "base", "band_radius": 0.5, "band_height": 0.07, "band_y": 0.37,
		LAYERS: [
			{"shape": SHAPE_FIN, "size": Vector3(0.2, 0.2, 0.07), "offset": Vector3(-0.27, 0.64, 0.04), "tilt": Vector3(-0.2, 0, 0.3), "jagged": true, "teeth": 1, "tooth": 0.2, "tone": "accent"},
			{"shape": SHAPE_FIN, "size": Vector3(0.2, 0.2, 0.07), "offset": Vector3(0.27, 0.64, 0.04), "tilt": Vector3(-0.2, 0, -0.3), "jagged": true, "teeth": 1, "tooth": 0.2, "tone": "accent"},
			{"shape": SHAPE_FIN, "size": Vector3(0.4, 0.09, 0.05), "offset": Vector3(0, 0.46, -0.45), "tilt": Vector3(-0.55, 0, 0), "tone": "trim", "edge_tone": "dark", "edge": 0.015},
			{"shape": SHAPE_FIN, "size": Vector3(0.3, 0.3, 0.05), "offset": Vector3(0, 0.4, 0.4), "tilt": Vector3(PI * 0.88, 0, 0), "tone": "accent", "edge_tone": "trim"},
		],
	}},
	"wolfmark_body": {"palette": WOLFMARK, PART_BODY: {
		# a dark iron breastplate under a grey fur mantle with a pale trim, the pelt torn down
		# the back, a blood-red sash and broad pauldrons over a darker under-plate
		"shape": SHAPE_VEST,
		LAYERS: [
			{"shape": SHAPE_CLOAK, "outline": OUTLINE_TORN, "width": 0.56, "length_left": 0.44, "length_right": 0.36, "offset": Vector3(0, 0.2, 0.34), "tilt": 0.15, "teeth": 4, "tooth": 0.1, "tone": "accent", "tooth_tone": "trim"},
			{"shape": SHAPE_SASH, "roll": -0.6, "tone": WOLFMARK_BLOOD, "edge_tone": WOLFMARK_BLOOD_DARK},
			{"shape": SHAPE_STACKED_PLATES, "plates_left": 2, "plates_right": 2, "size_left": Vector3(0.32, 0.09, 0.36), "size_right": Vector3(0.32, 0.09, 0.36), "x": 0.44, "y": 0.18, "step": Vector3(0.05, -0.08, 0)},
			{"shape": SHAPE_RUFF, "inner": 0.22, "outer": 0.46, "y": 0.22},
		],
	}},
	"wolfmark_legs": {"palette": WOLFMARK, PART_HIPS: {
		# iron tassets hung from a dark belt over a dark kilt
		"shape": SHAPE_KILT,
		LAYERS: [{"shape": SHAPE_TASSETS}],
	}, PART_SHIN: {
		# a dark iron greave with a fur top
		"shape": SHAPE_FUR_BAND, "band_tone": "accent", "band_radius": 0.185, "band_height": 0.09, "band_y": -0.03,
	}},
	"wolfmark_axe": {"palette": WOLFMARK, PART_WEAPON: {"shape": SHAPE_BEARDED_AXE, "haft_tone": WOLFMARK_ASH, "cap_tone": WOLFMARK_BRASS}},
	# Ruinwarden (high): old gold dug from the ring-two ruins, verdigris plate, a tall crest, a
	# crimson plume, and one rune that still glows faintly. Glow: the chest rune and the
	# greatsword's fuller only, emissive with no light and no motes.
	"ruinwarden_helm": {"palette": RUINWARDEN, PART_HEAD: {
		# a gold dome under a verdigris band with lit-gold rivets, a tall crest running front
		# to back with a verdigris edge, a crimson plume curling back from its top and a cheek
		# guard each side
		"shape": SHAPE_HELM, "height": 0.46, "band": true, "band_height": 0.07,
		LAYERS: [
			{"shape": SHAPE_STUDS, "count": 5, "radius": 0.49, "arc": PI * 0.9, "y": 0.42, "stud": 0.028, "band_height": 0.02, "band_tone": "trim", "stud_tone": RUINWARDEN_LIT},
			{"shape": SHAPE_FIN, "size": Vector3(0.07, 0.3, 0.56), "offset": Vector3(0, 0.6, 0.02), "tilt": Vector3(0.1, 0, 0), "edge": 0.03},
			{"shape": SHAPE_PRISM_STACK, "count": 3, "length": 0.5, "radius": 0.06, "bend": 0.45, "taper": 0.8, "offset": Vector3(0, 0.88, 0.1), "tilt": Vector3(0.45, 0, 0), "root_tone": RUINWARDEN_PLUME_DARK, "tone": "accent", "tip_tone": RUINWARDEN_PLUME_LIT},
			{"shape": SHAPE_FIN, "size": Vector3(0.16, 0.2, 0.05), "offset": Vector3(-0.41, 0.17, -0.2), "tilt": Vector3(0, PI * 0.5, -0.12), "edge": 0.03},
			{"shape": SHAPE_FIN, "size": Vector3(0.16, 0.2, 0.05), "offset": Vector3(0.41, 0.17, -0.2), "tilt": Vector3(0, PI * 0.5, 0.12), "edge": 0.03},
		],
	}},
	"ruinwarden_body": {"palette": RUINWARDEN, PART_BODY: {
		# layered gold plate: a chest plate with a lit-gold rim round the glowing rune, a gold
		# hem rim, a verdigris gorget and a high collar behind the neck, and big angular
		# pauldrons, three plates on the left and two on the right, alternating gold and
		# verdigris
		"shape": SHAPE_VEST,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "size": Vector3(0.34, 0.03, 0.26), "offset": Vector3(0, 0.0, -0.31), "tilt": Vector3(-1.42, 0, 0), "tone": RUINWARDEN_LIT},
			{"shape": SHAPE_CRYSTAL, "facets": 4, "length": 0.17, "radius": 0.085, "root": 0.3, "offset": Vector3(0, 0.05, -0.33), "tilt": Vector3(-1.1, 0, 0), "glow": 0.8, "root_tone": "trim"},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.36, "size": Vector3(0, 0.04, 0), "lip": 0.02, "offset": Vector3(0, -0.29, 0), "tone": RUINWARDEN_LIT},
			{"shape": SHAPE_RUFF, "inner": 0.2, "outer": 0.4, "y": 0.2, "trim": 0.03, "tone": "trim", "trim_tone": RUINWARDEN_VERDIGRIS_LIT},
			{"shape": SHAPE_COLLAR, "kind": COLLAR_HIGH, "width": 0.5, "height": 0.28, "offset": Vector3(0, 0.22, 0.3), "tone": "trim", "edge_tone": RUINWARDEN_VERDIGRIS_LIT},
			{"shape": SHAPE_STACKED_PLATES, "plates_left": 3, "plates_right": 2, "size_left": Vector3(0.34, 0.09, 0.38), "size_right": Vector3(0.3, 0.09, 0.34), "x": 0.43, "y": 0.2, "tilt": 0.3, "step": Vector3(0.05, -0.08, 0), "under_tone": "trim", "trim_tone": RUINWARDEN_LIT},
		],
	}},
	"ruinwarden_legs": {"palette": RUINWARDEN, PART_HIPS: {
		# three overlapping faulds, gold, verdigris, gold, each with a lit rim, over a dark kilt
		"shape": SHAPE_KILT,
		LAYERS: [{"shape": SHAPE_FAULDS, "alt_tone": "trim", "rim_tone": RUINWARDEN_LIT}],
	}, PART_SHIN: {
		# a gold greave with a verdigris band at its top
		"shape": SHAPE_FUR_BAND, "band_radius": 0.175, "band_height": 0.05, "band_y": -0.02,
	}},
	"ruinwarden_greatsword": {"palette": RUINWARDEN, PART_WEAPON: {"shape": SHAPE_GREATSWORD, "glow": 0.7}},
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


## A look to build from: the numbers of the shape `own` names, with `own`'s laid over them
## (its `layers`, if any, carried along as they are).
static func numbers(own: Dictionary) -> Dictionary:
	var out: Dictionary = (SHAPES[own["shape"]] as Dictionary).duplicate()
	out.merge(own, true)
	return out


## The pieces `look` layers over its shape, each as its own look to build from; [] when it
## has none.
static func layers(look: Dictionary) -> Array:
	var out: Array = []
	for own in look.get(LAYERS, []):
		out.append(numbers(own))
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
