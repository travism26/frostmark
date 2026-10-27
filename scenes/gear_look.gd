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
## tassets, a seam, a shard crown, antlers, plumes, a pouch, and the hand-held weapons: a
## broadsword, a bearded axe, a greatsword, a forge hammer, a glaive, a cleaver, a longbow and
## a mage staff) are the layered, non-round pieces the set looks are built from. Each has its
## numbers in SHAPES like any other shape and a builder of the same name in CharacterGear;
## KIT_SAMPLES holds one look of each for the shader warm-up and the kit shots.
##
## Glow is emission only (#250): a top set's palette sets `trim_glow`, so its trims shine, and
## its entries may light a shape's highlight with `glow`. Tiers and the mid to high sets keep
## plain materials. Nothing on the character carries a light or particles, so the web build
## stays smooth. Each piece glows on its own, so a top-set piece shines beside any other.
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
## The ranged set shape (#164): a bow built from its look, held like the tier bows.
const SHAPE_LONGBOW := "Longbow"
## The ranged top set shape (#165): a fan of feathers, a crest or a wing.
const SHAPE_PLUMES := "Plumes"
## The magic set shapes (#166).
const SHAPE_POUCH := "Pouch"
const SHAPE_MAGE_STAFF := "MageStaff"
const KIT_SHAPES := [
	SHAPE_PEAKED_HOOD, SHAPE_UNDER_ROBE, SHAPE_CLOAK, SHAPE_COLLAR, SHAPE_STACKED_PLATES,
	SHAPE_CRYSTAL, SHAPE_FIN, SHAPE_PRISM_STACK, SHAPE_STUDS, SHAPE_EDGE_TRIM, SHAPE_QUIVER,
	SHAPE_SASH, SHAPE_RUFF, SHAPE_FAULDS, SHAPE_TASSETS, SHAPE_SEAM, SHAPE_SHARD_CROWN, SHAPE_ANTLERS,
	SHAPE_BROADSWORD, SHAPE_BEARDED_AXE, SHAPE_GREATSWORD, SHAPE_FORGE_HAMMER, SHAPE_GLAIVE, SHAPE_CLEAVER,
	SHAPE_LONGBOW, SHAPE_PLUMES,
	SHAPE_POUCH, SHAPE_MAGE_STAFF,
]
## The kit shapes held in the hand: each is a whole weapon, gripped in the right hand, or in
## the left for the BOW_SHAPES, held as the tier bows are.
const WEAPON_SHAPES := [
	SHAPE_BROADSWORD, SHAPE_BEARDED_AXE, SHAPE_GREATSWORD, SHAPE_FORGE_HAMMER, SHAPE_GLAIVE, SHAPE_CLEAVER,
	SHAPE_LONGBOW, SHAPE_MAGE_STAFF,
]
const BOW_SHAPES := [SHAPE_LONGBOW]
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
## A collar's kind: a high collar, a jagged ice collar, a stone back-plate, or an upright hoop
## (a halo) with flame fins on its rim.
const COLLAR_HIGH := "high"
const COLLAR_JAGGED := "jagged"
const COLLAR_PLATE := "plate"
const COLLAR_HOOP := "hoop"
const COLLARS := [COLLAR_HIGH, COLLAR_JAGGED, COLLAR_PLATE, COLLAR_HOOP]
## What shows above a quiver's cap band: arrow shafts with fletching, or crystal shard tips.
const TIPS_FLETCHING := "fletching"
const TIPS_SHARDS := "shards"
const QUIVER_TIPS := [TIPS_FLETCHING, TIPS_SHARDS]
## A mage staff's head: one raw shard lashed to the shaft, two fork arms holding a floating
## prism, a hoop cradling a large prism with a small one riding above it, or the top sets'
## heads (#167): one long greatshard with two side shards, a brazier cup holding three prisms,
## two curved antler tines round a prism with a feather and a bead cord hanging, or a broken
## pillar top with a prism in the break.
const HEAD_LASHED := "lashed"
const HEAD_FORKED := "forked"
const HEAD_RING := "ring"
const HEAD_SHARD := "shard"
const HEAD_BRAZIER := "brazier"
const HEAD_ANTLER := "antler"
const HEAD_PILLAR := "pillar"
const STAFF_HEADS := [HEAD_LASHED, HEAD_FORKED, HEAD_RING, HEAD_SHARD, HEAD_BRAZIER, HEAD_ANTLER, HEAD_PILLAR]

## Every palette carries exactly these fields.
##   base         Color  the piece itself: a dome, vest, greave or fur wrap, a blade or haft
##   dark         Color  the underside: the kilt under the vest
##   trim         Color  bands and edges: a helm's band and nose guard, fur's pale ruff, hem
##                       and shin band
##   accent       Color  raised pieces: pauldrons, the pale hoop framing a fur hood's face
##   glow         Color  what a glowing part shines in: a staff's crystal, and a kit shape's
##                       highlight whenever its look's `glow` is above 0
##   glow_energy  float  how bright the staff's glow is; 0 draws it unlit (every tier's is 0:
##                       tiers keep plain materials)
##   trim_glow    float  how bright every part drawn in the trim shines, in the trim colour; 0
##                       keeps the trim plain. Only the top sets' palettes set it (#250), so
##                       the hardest gear to make glows on the character, piece by piece
const PALETTE_FIELDS := ["base", "dark", "trim", "accent", "glow", "glow_energy", "trim_glow"]

const WOOD := {
	"base": Color(0.55, 0.38, 0.22), "dark": Color(0.495, 0.342, 0.198),
	"trim": Color(0.44, 0.304, 0.176), "accent": Color(0.595, 0.442, 0.298),
	"glow": Color(0.55, 0.85, 1.0), "glow_energy": 0.0, "trim_glow": 0.0,
}
const BRONZE := {
	"base": Color(0.82, 0.52, 0.22), "dark": Color(0.738, 0.468, 0.198),
	"trim": Color(0.656, 0.416, 0.176), "accent": Color(0.838, 0.568, 0.298),
	"glow": Color(0.55, 0.85, 1.0), "glow_energy": 0.0, "trim_glow": 0.0,
}
const IRON := {
	"base": Color(0.58, 0.62, 0.68), "dark": Color(0.522, 0.558, 0.612),
	"trim": Color(0.464, 0.496, 0.544), "accent": Color(0.622, 0.658, 0.712),
	"glow": Color(0.55, 0.85, 1.0), "glow_energy": 0.0, "trim_glow": 0.0,
}
const STEEL := {
	"base": Color(0.42, 0.50, 0.62), "dark": Color(0.378, 0.45, 0.558),
	"trim": Color(0.336, 0.40, 0.496), "accent": Color(0.478, 0.55, 0.658),
	"glow": Color(0.55, 0.85, 1.0), "glow_energy": 0.0, "trim_glow": 0.0,
}
## A pelt grey-brown with a pale trim.
const FUR := {
	"base": Color(0.56, 0.48, 0.40), "dark": Color(0.504, 0.432, 0.36),
	"trim": Color(0.80, 0.74, 0.64), "accent": Color(0.714, 0.662, 0.61),
	"glow": Color.BLACK, "glow_energy": 0.0, "trim_glow": 0.0,
}
## The kit samples' colours: dusk violet under bone, lit aurora green.
const KIT := {
	"base": Color(0.24, 0.18, 0.42), "dark": Color(0.16, 0.12, 0.30),
	"trim": Color(0.91, 0.89, 0.82), "accent": Color(0.55, 0.48, 0.35),
	"glow": Color(0.50, 0.94, 0.77), "glow_energy": 1.5, "trim_glow": 0.0,
}
const MISSING := {
	"base": Color.MAGENTA, "dark": Color.MAGENTA, "trim": Color.MAGENTA, "accent": Color.MAGENTA,
	"glow": Color.MAGENTA, "glow_energy": 0.0, "trim_glow": 0.0,
}
## The melee sets' palettes (#162, the approved board on #157). None has a staff, so
## glow_energy is 0; Ruinwarden's glow is the colour its chest rune and fuller shine in.
## Hearthguard: blue steel, its recessed band, brass trim, leather straps.
const HEARTHGUARD := {
	"base": Color("#7d8aa3"), "dark": Color("#5c6880"),
	"trim": Color("#d9a64a"), "accent": Color("#8a5a2b"),
	"glow": Color.BLACK, "glow_energy": 0.0, "trim_glow": 0.0,
}
## Wolfmark: dark iron and its shade, pale fur trim, the grey pelt; the blood sash and brass
## cap are the pieces' own colours.
const WOLFMARK := {
	"base": Color("#4e5668"), "dark": Color("#363c4c"),
	"trim": Color("#d8ccb8"), "accent": Color("#8c8070"),
	"glow": Color.BLACK, "glow_energy": 0.0, "trim_glow": 0.0,
}
## Ruinwarden: old gold over its dark, verdigris trim, the crimson plume, the rune's glow.
const RUINWARDEN := {
	"base": Color("#b08a3c"), "dark": Color("#4a3a1e"),
	"trim": Color("#5f8a7a"), "accent": Color("#a8302a"),
	"glow": Color("#6fe3c8"), "glow_energy": 0.0, "trim_glow": 0.0,
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
## set's seams, shard tips, trim or cracks shine in, and every set's trims shine (`trim_glow`,
## #250); Trollbone's glow is only its bone trim. None has a staff, so glow_energy is 0.
## Emberheart: forge black and its recessed shade, dark bronze bands and straps, horn.
const EMBERHEART := {
	"base": Color("#2e2a33"), "dark": Color("#1c1921"),
	"trim": Color("#8a3a1a"), "accent": Color("#3a3340"),
	"glow": Color("#ff7a1f"), "glow_energy": 0.0, "trim_glow": 0.8,
}
## Hoarfrost: ice over the dark-blue harness, white fur, ice shade.
const HOARFROST := {
	"base": Color("#cfe3f2"), "dark": Color("#3a4a6a"),
	"trim": Color("#f1ece2"), "accent": Color("#a9d4ef"),
	"glow": Color("#7fd4ff"), "glow_energy": 0.0, "trim_glow": 0.4,
}
## Auroral: dusk violet and its shade, lilac trim, pale antler.
const AURORAL := {
	"base": Color("#3f3670"), "dark": Color("#2a2350"),
	"trim": Color("#b08cff"), "accent": Color("#e8dcc0"),
	"glow": Color("#6ff0b0"), "glow_energy": 0.0, "trim_glow": 0.6,
}
## Trollbone: hide, dark, bone, blood.
const TROLLBONE := {
	"base": Color("#4a3a2e"), "dark": Color("#2a2238"),
	"trim": Color("#e8dcc0"), "accent": Color("#a3302a"),
	"glow": Color.BLACK, "glow_energy": 0.0, "trim_glow": 0.4,
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
## The magic sets' palettes (#166, the approved round-2 board on #157). Each has a staff, but
## its glow is per part (the shard, the brow prism, the glyph band), so glow_energy is 0 and
## `Figures.staff` is never drawn for a set: the glow colour is what those parts would shine
## in, but a mid to high set keeps plain materials (#250), so none of them is lit.
## Shardweaver: undyed wool and its shade, cream trim, rope; the frost of a raw shard.
const SHARDWEAVER := {
	"base": Color("#5e6d8a"), "dark": Color("#45526b"),
	"trim": Color("#d9d2c2"), "accent": Color("#b59a6a"),
	"glow": Color("#9ecbff"), "glow_energy": 0.0, "trim_glow": 0.0,
}
## Rimecaller: indigo and its shade, frost white, dark ash; frost glow.
const RIMECALLER := {
	"base": Color("#3b4a8c"), "dark": Color("#2b3668"),
	"trim": Color("#cfe2ff"), "accent": Color("#5c4a3a"),
	"glow": Color("#9ecbff"), "glow_energy": 0.0, "trim_glow": 0.0,
}
## Glacier Warden: teal and its shade, silver, iron; ice glow.
const GLACIER_WARDEN := {
	"base": Color("#1f6e7a"), "dark": Color("#154e58"),
	"trim": Color("#c9d7de"), "accent": Color("#39404a"),
	"glow": Color("#8fe6f0"), "glow_energy": 0.0, "trim_glow": 0.0,
}
## The magic sets' extra materials and lit rim tints.
const SHARDWEAVER_PINE := Color("#7a5234")
const SHARDWEAVER_ROPE_DARK := Color("#8a7450")
const RIMECALLER_FROST_LIT := Color("#e8f2ff")
const RIMECALLER_ASH_LIT := Color("#7a6450")
const GLACIER_WARDEN_LIT := Color("#e3ebef")
const GLACIER_WARDEN_IRON_LIT := Color("#4f5866")
## The magic top sets' palettes (#167, the approved round-2 board on #157): the magic sets above
## steel, each with emission in its glow colour on the parts the issue names and its trims
## shining (`trim_glow`, #250), with no light and no motes. Each has a staff, but its glow is
## per part, so glow_energy is 0 and `Figures.staff` is never drawn for a set.
## Hoarfrost Sovereign: glacier white over ice shade, steel blue, pale ice; frost glow.
const HOARFROST_SOVEREIGN := {
	"base": Color("#dbe8fa"), "dark": Color("#9fb6d6"),
	"trim": Color("#5f7fb0"), "accent": Color("#c4dcf5"),
	"glow": Color("#a7e4ff"), "glow_energy": 0.0, "trim_glow": 0.8,
}
## Hearthfire Magus: charcoal over soot, brass, flame; ember glow.
const HEARTHFIRE_MAGUS := {
	"base": Color("#2b2522"), "dark": Color("#1b1614"),
	"trim": Color("#c88a3c"), "accent": Color("#ffc46b"),
	"glow": Color("#ff9e38"), "glow_energy": 0.0, "trim_glow": 0.6,
}
## Aurora Shaman: violet over its shade, bone, antler; aurora glow.
const AURORA_SHAMAN := {
	"base": Color("#3e2f6b"), "dark": Color("#2a1f4d"),
	"trim": Color("#e9e4d2"), "accent": Color("#8b7a5a"),
	"glow": Color("#7ff0c4"), "glow_energy": 0.0, "trim_glow": 0.4,
}
## Ruinwarden (the magic line's): dusk cloth over deep cloth, ruin stone, pillar; rune glow.
const RUINWARDEN_MAGE := {
	"base": Color("#2a2a3e"), "dark": Color("#1b1b2a"),
	"trim": Color("#6c6f86"), "accent": Color("#4a4a5c"),
	"glow": Color("#b784ff"), "glow_energy": 0.0, "trim_glow": 0.8,
}
## The magic top sets' lit rim tints and shaded tones.
const HOARFROST_SOVEREIGN_LIT := Color("#f2f7fd")
const HOARFROST_SOVEREIGN_STEEL_LIT := Color("#7f9bc8")
const HEARTHFIRE_MAGUS_LIT := Color("#3d3530")
const HEARTHFIRE_MAGUS_BRASS_LIT := Color("#e0a655")
const AURORA_SHAMAN_LIT := Color("#54428a")
const AURORA_SHAMAN_BONE_LIT := Color("#f6f3e8")
const AURORA_SHAMAN_BONE_DARK := Color("#c9c2ad")
const RUINWARDEN_MAGE_LIT := Color("#3a3a52")
const RUINWARDEN_MAGE_STONE_LIT := Color("#8b8ea6")
const RUINWARDEN_MAGE_STONE_DARK := Color("#525468")

## The ranged sets' palettes (#164, the approved board on #157). No set glows, so glow is
## black and glow_energy 0 (none has a staff).
## Trapper's Leathers: tanned hide, dark lacing, a pale fur edge, the ash stave.
const TRAPPER := {
	"base": Color("#a8784a"), "dark": Color("#4a3324"),
	"trim": Color("#d8c9a8"), "accent": Color("#8a6a46"),
	"glow": Color.BLACK, "glow_energy": 0.0, "trim_glow": 0.0,
}
## Wolfstalker: the grey wolf pelt over dark leather, bone trim, the yew stave.
const WOLFSTALKER := {
	"base": Color("#9c9ca8"), "dark": Color("#3b2f2a"),
	"trim": Color("#dcd6c0"), "accent": Color("#4f3a2c"),
	"glow": Color.BLACK, "glow_energy": 0.0, "trim_glow": 0.0,
}
## Steelpoint Ranger: smithed steel, dark straps, the amber feather, pine-green leather.
const STEELPOINT := {
	"base": Color("#6b80a0"), "dark": Color("#1f2a24"),
	"trim": Color("#e8a040"), "accent": Color("#2f4a3a"),
	"glow": Color.BLACK, "glow_energy": 0.0, "trim_glow": 0.0,
}
## The ranged sets' lit and shaded tints, and the pale bowstring every bow shares.
const TRAPPER_HIDE_LIT := Color("#c4945e")
const WOLFSTALKER_PELT_DARK := Color("#6e6e7a")
const STEELPOINT_LIT := Color("#8aa0c0")
const STEELPOINT_PINE_LIT := Color("#3f6450")
const STEELPOINT_AMBER_DARK := Color("#b87a28")
const BOWSTRING := Color("#e6e0cc")

## The ranged top sets' palettes (#165, the approved board on #157). Each has one accent glow,
## the colour its tips, hems, eyes, strings or nocks shine in, and its trims shine (`trim_glow`,
## #250): emissive only, no light and no motes. None has a staff, so glow_energy is 0.
## Ember Hawk: charcoal and its char, gold trim, the warm string, ember glow.
const EMBER_HAWK := {
	"base": Color("#2b2422"), "dark": Color("#1a1512"),
	"trim": Color("#c9922e"), "accent": Color("#f3d7a6"),
	"glow": Color("#ffa033"), "glow_energy": 0.0, "trim_glow": 0.6,
}
## Auroral Warden: snow hide over violet lining, silver, a shaded hide, aurora glow.
const AURORAL_WARDEN := {
	"base": Color("#ece9f5"), "dark": Color("#3d2d6b"),
	"trim": Color("#b9c3d6"), "accent": Color("#d4d0e3"),
	"glow": Color("#5ff0c8"), "glow_energy": 0.0, "trim_glow": 0.4,
}
## Ruin Stalker's Shroud: ink and its pitch, bone, ash grey, violet glow.
const RUIN_STALKER := {
	"base": Color("#15141c"), "dark": Color("#0b0a10"),
	"trim": Color("#dcd4bc"), "accent": Color("#6a6878"),
	"glow": Color("#9a6cff"), "glow_energy": 0.0, "trim_glow": 0.4,
}
## Glacier Sovereign: ice hide over deep sea, the crystal face, a shaded ice, frost glow.
const GLACIER_SOVEREIGN := {
	"base": Color("#b7d4ea"), "dark": Color("#1e3a5a"),
	"trim": Color("#d9f0ff"), "accent": Color("#8fb6d6"),
	"glow": Color("#8cd9ff"), "glow_energy": 0.0, "trim_glow": 0.4,
}
## The ranged top sets' lit rim tints and shaded tones.
const EMBER_HAWK_LIT := Color("#3d3431")
const EMBER_HAWK_GOLD_DARK := Color("#8f6a1e")
const AURORAL_WARDEN_SILVER_LIT := Color("#d9e1ec")
const AURORAL_WARDEN_VIOLET_LIT := Color("#5a4791")
const RUIN_STALKER_BONE_DARK := Color("#b4aa8e")
const RUIN_STALKER_BONE_LIT := Color("#f1ebd8")
const RUIN_STALKER_INK_LIT := Color("#2a2836")
const GLACIER_SOVEREIGN_LIT := Color("#edf7ff")
const GLACIER_SOVEREIGN_SEA_LIT := Color("#315a82")

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
	# front panels hanging from the coat's hem, each its own length and flared apart;
	# `panel_edge` above 0 runs an edging strip that wide in `edge_tone` down each panel's
	# inner edge and along its hem.
	SHAPE_UNDER_ROBE: {
		"top_radius": 0.36, "bottom_radius": 0.56, "height": 1.05, "segments": 10, "y": -0.35,
		"coat_top_radius": 0.4, "coat_bottom_radius": 0.52, "coat_height": 0.6, "coat_y": -0.12, "coat_back": 0.1,
		"panel_left": 0.55, "panel_right": 0.4, "panel_width": 0.2, "panel_thickness": 0.04,
		"panel_x": 0.17, "panel_z": -0.46, "panel_top": -0.3, "panel_flare": 0.12, "panel_lean": 0.2,
		"bands": 2, "band_height": 0.05, "band_from": -0.75, "band_step": 0.2, "panel_edge": 0.0,
		"tone": "base", "robe_tone": "dark", "band_tone": "trim", "edge_tone": "trim", "glow": 0.0,
	},
	# A fin hung from the shoulders behind the body, in two halves each its own length, with
	# a hem band; `outline` picks plain, forked, torn, tail or banner. `lining` above 0 shows
	# that much of a `lining_tone` lining round each half's edges, as a cloak lined in another
	# cloth shows it.
	SHAPE_CLOAK: {
		"width": 0.6, "length_left": 0.9, "length_right": 0.9, "thickness": 0.04,
		"offset": Vector3(0, 0.2, 0.36), "tilt": 0.12, "hem": 0.05,
		"outline": OUTLINE_PLAIN, "fork": 0.22, "teeth": 3, "tooth": 0.12,
		"tail_length": 0.45, "tail_width": 0.25, "banner_rise": 0.7, "banner_width": 0.3,
		"lining": 0.0, "tone": "base", "hem_tone": "trim", "tooth_tone": "dark", "lining_tone": "dark", "glow": 0.0,
	},
	# An upright plate behind the neck leaning `tilt` back, over a dark backing, with a lit
	# top edge: `kind` picks a high collar, a jagged collar with `teeth` points, a wider
	# thicker back-plate, or an upright hoop (a halo, in the highlight) with `teeth` flame fins
	# in `tone` on its rim.
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
	# `tilt`; the tip shines only when `glow` is above 0.
	SHAPE_CRYSTAL: {
		"facets": 4, "length": 0.3, "radius": 0.06, "root": 0.3, "offset": Vector3.ZERO, "tilt": Vector3.ZERO,
		"glow": 0.0, "root_tone": "dark",
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
	# centred on the front, in `rows` rows each `row_step` lower than the one above; `band`
	# off leaves the studs alone on the piece under them (lace knots, a toggle, a chest column).
	SHAPE_STUDS: {
		"count": 5, "radius": 0.42, "arc": PI, "y": -0.28, "stud": 0.035, "band_height": 0.05, "segments": 10,
		"rows": 1, "row_step": 0.1, "band": true, "band_tone": "dark", "stud_tone": "accent", "glow": 0.0,
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
	# (`tip_tone`: the glow colour, lit, when glow is above 0).
	SHAPE_SHARD_CROWN: {
		"count": 7, "radius": 0.36, "arc": TAU, "length": 0.3, "short": 0.65, "shard": 0.05, "facets": 4,
		"lean": 0.35, "tip": 0.45, "offset": Vector3(0, 0.55, 0), "tilt": Vector3.ZERO,
		"tone": "base", "tip_tone": "accent", "glow": 0.0,
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
	SHAPE_FORGE_HAMMER: {
		"haft_length": 0.9, "haft_radius": 0.035, "rise": 0.1, "head_size": Vector3(0.46, 0.2, 0.2),
		"band": 0.04, "band_x": 0.3, "cracks": 3, "crack": 0.022, "tilt": Vector3(0, 0, PI * 0.25),
		"tone": "base", "haft_tone": "accent", "band_tone": "trim", "crack_tone": "trim", "glow": 0.0,
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
	# A bow in the left hand's mount frame, held by its grip like the tier bows (Figures.bow):
	# `segments` staves `stave` thick along the frame's Z over `length`, bulging `depth` toward
	# +Y, the outermost bent `tip_bend` further back (a recurve), a `string` thick string
	# below them, a round grip `grip_length` long round the middle in `grip_tone`, a ball
	# `nock` wide at each tip in `nock_tone` (the highlight) and, when `cap_length` is above 0,
	# a limb cap that long at each tip in `cap_tone`. The highlight (the glow colour, lit, when
	# `glow` is above 0) also draws the string when `lit_string` is on, an `edge` thick strip
	# along the back of every stave when `edge` is above 0, and a shard `shard` long standing
	# off each tip when `shard` is above 0.
	SHAPE_LONGBOW: {
		"length": 1.1, "depth": 0.19, "segments": 6, "stave": 0.06, "string": 0.015, "tip_bend": 0.0,
		"grip_length": 0.18, "grip_radius": 0.045, "cap_length": 0.0, "nock": 0.03,
		"lit_string": false, "edge": 0.0, "shard": 0.0,
		"tone": "base", "grip_tone": "dark", "cap_tone": "trim", "nock_tone": "trim", "string_tone": "trim", "glow": 0.0,
	},
	# `count` feathers fanning from `offset` turned by `tilt`, spread over `arc` about the
	# stand's +Y in its X-Y plane: each a thin plate `length` long, `width` wide and `thickness`
	# thick in `tone` with a `quill_tone` quill down its middle and a ball `tip` across at its
	# end in the highlight (`tip_tone`: the glow colour, lit, when `glow` is above 0). A crest
	# above the head, a wing off a shoulder.
	SHAPE_PLUMES: {
		"count": 5, "arc": PI * 0.8, "length": 0.4, "width": 0.07, "thickness": 0.025, "tip": 0.035,
		"offset": Vector3(0, 0.6, 0), "tilt": Vector3.ZERO,
		"tone": "base", "quill_tone": "dark", "tip_tone": "accent", "glow": 0.0,
	},
	# A case `length` long on the back, its root at `offset` low on the shoulder blade and turned
	# by `tilt` so its mouth tops the right shoulder, clear of a tool slung the other way: a
	# dark foot, a cap band round the mouth, and `tip_count` fletched shafts or shard tips
	# standing `tip_length` out of it; the band, the fletching and the shard tips are the
	# highlight (the glow colour, lit, when `glow` is above 0).
	SHAPE_QUIVER: {
		"length": 0.6, "radius": 0.09, "segments": 8, "offset": Vector3(0.2, -0.15, 0.4),
		"tilt": Vector3(0.12, 0, -0.3), "foot": 0.06, "band_height": 0.05,
		"tips": TIPS_FLETCHING, "tip_count": 3, "tip_length": 0.16, "tone": "base", "foot_tone": "dark",
		"band_tone": "trim", "shaft_tone": "dark", "fletch_tone": "trim", "tip_tone": "accent", "glow": 0.0,
	},
	# The magic set shapes (#166). A pouch hung at `offset` turned by `tilt`: a box `size`
	# across in `tone` with a flap `flap` tall across its top front in the highlight
	# (`flap_tone`) over a `shadow_tone` line under the flap, or when `round` a case lying
	# along the stand's Y of `size.x` across and `size.y` long with a cap `cap` long at each
	# end in `flap_tone`: a belt pouch, a satchel, a book pouch, a scroll case.
	SHAPE_POUCH: {
		"size": Vector3(0.16, 0.14, 0.08), "offset": Vector3(0.38, -0.26, -0.1), "tilt": Vector3(0, 0.3, 0),
		"flap": 0.05, "round": false, "cap": 0.035,
		"tone": "accent", "flap_tone": "trim", "shadow_tone": "dark", "glow": 0.0,
	},
	# A mage staff held upright in the right hand like the tier staves (`tilt` zero): a shaft
	# `length` long in `tone` standing `foot` below the hand (`segments` 4 makes it a square
	# pillar), a collar `collar` tall in `collar_tone` under the head and a grip band `grip`
	# tall in `grip_tone` `grip_y` above the hand (0 for none), and a head of three or four
	# parts picked by `head`: lashed, one raw `facets`-sided prism `prism_length` long on the
	# shaft's top with a rope torus `lash` thick round the join in `lash_tone`; forked, two
	# arms `fork_length` long leaning `fork_spread` apart in `fork_tone` with the prism floating
	# `rise` over the shaft in the gap; ring, a hoop `ring_inner` to `ring_outer` across in
	# `ring_tone` standing on the shaft, the prism rising through it and a small prism
	# `small_length` long riding `rise` above its top; shard, the prism on the shaft's top with
	# two small prisms leaning `side_spread` out from its root; brazier, a cup `cup` tall in
	# `cup_tone` flaring to `cup_radius` at its mouth, the prism standing in it between two
	# small prisms leaning `side_spread` apart; antler, two tines `fork_length` long leaning
	# `fork_spread` apart that bend `tine_bend` back in halfway up, the prism floating `rise`
	# over the shaft between them, a feather `feather` long in `feather_tone` hanging from the
	# right tine's root and `beads` beads `bead` across in `bead_tone` strung from the left's;
	# pillar, `teeth` jagged points `tooth` tall round the shaft's broken top with the prism
	# rising from the break. Every prism is the glow colour over a `root_tone` root, lit at
	# `glow`.
	SHAPE_MAGE_STAFF: {
		"head": HEAD_LASHED, "length": 1.5, "foot": 0.35, "radius": 0.04, "segments": 6, "tilt": Vector3.ZERO,
		"collar": 0.05, "collar_radius": 0.065, "grip": 0.12, "grip_y": 0.08, "lash": 0.03,
		"facets": 4, "prism_length": 0.3, "prism_radius": 0.065, "root": 0.3,
		"small_length": 0.14, "small_radius": 0.04, "rise": 0.08, "side_spread": 0.5,
		"fork_length": 0.32, "fork_spread": 0.45, "fork_radius": 0.022, "tine_bend": 0.8,
		"ring_inner": 0.15, "ring_outer": 0.19, "ring_rings": 10, "ring_segments": 6,
		"cup": 0.18, "cup_radius": 0.15, "feather": 0.24, "beads": 3, "bead": 0.02, "teeth": 5, "tooth": 0.12,
		"tone": "accent", "collar_tone": "trim", "grip_tone": "dark", "lash_tone": "trim", "fork_tone": "accent",
		"ring_tone": "trim", "cup_tone": "trim", "feather_tone": "trim", "bead_tone": "trim", "root_tone": "dark", "glow": 0.0,
	},
}

## One look of each kit shape, for the shader warm-up and the kit
## shots: unequal sides where a shape has them, a jagged edge, a lit highlight.
const KIT_SAMPLES := [
	{"shape": SHAPE_PEAKED_HOOD, "glow": 0.6},
	{"shape": SHAPE_UNDER_ROBE, "panel_left": 0.6, "panel_right": 0.42, "glow": 1.0},
	{"shape": SHAPE_CLOAK, "outline": OUTLINE_FORKED, "length_left": 0.95, "length_right": 0.8, "glow": 0.8},
	{"shape": SHAPE_COLLAR, "kind": COLLAR_JAGGED, "glow": 1.2},
	{"shape": SHAPE_STACKED_PLATES, "plates_left": 3, "plates_right": 2, "size_left": Vector3(0.32, 0.08, 0.36), "glow": 0.8},
	{"shape": SHAPE_CRYSTAL, "length": 0.45, "radius": 0.1, "glow": 1.6, "offset": Vector3(0, 0.7, 0)},
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
	{"shape": SHAPE_LONGBOW, "cap_length": 0.12, "tip_bend": 0.3, "glow": 0.8},
	{"shape": SHAPE_PLUMES, "offset": Vector3(0, 0.72, 0.05), "tilt": Vector3(0.3, 0, 0), "glow": 1.0},
	{"shape": SHAPE_POUCH, "size": Vector3(0.2, 0.18, 0.1), "offset": Vector3(-0.4, -0.3, 0.0), "tilt": Vector3(0, -0.4, 0), "glow": 0.6},
	{"shape": SHAPE_MAGE_STAFF, "head": HEAD_RING, "glow": 1.2},
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
	# crimson plume, and one rune in its old teal. No glow: a high set keeps plain materials
	# (#250).
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
		# layered gold plate: a chest plate with a lit-gold rim round the teal rune, a gold
		# hem rim, a verdigris gorget and a high collar behind the neck, and big angular
		# pauldrons, three plates on the left and two on the right, alternating gold and
		# verdigris
		"shape": SHAPE_VEST,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "size": Vector3(0.34, 0.03, 0.26), "offset": Vector3(0, 0.0, -0.31), "tilt": Vector3(-1.42, 0, 0), "tone": RUINWARDEN_LIT},
			{"shape": SHAPE_CRYSTAL, "facets": 4, "length": 0.17, "radius": 0.085, "root": 0.3, "offset": Vector3(0, 0.05, -0.33), "tilt": Vector3(-1.1, 0, 0), "root_tone": "trim"},
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
	"ruinwarden_greatsword": {"palette": RUINWARDEN, PART_WEAPON: {"shape": SHAPE_GREATSWORD, "fuller_tone": RUINWARDEN["glow"]}},
	# The melee top sets (#163). Glow is emission only (#250): each palette's trims shine, and
	# Trollbone's bone trim is its only glow. Every colour, size, offset and glow is here, to be
	# tuned live after playtesting with a re-shoot.
	# Emberheart (top): forge-black plate that carries the outpost fire out into the cold, ember
	# light bleeding through every seam. Glow: emissive seams, cracks, the burning core and the
	# bronze trims.
	"emberheart_helm": {"palette": EMBERHEART, PART_HEAD: {
		# a tall black dome under a dark bronze band with a lit rim above it, an ember eye slit
		# across the face, and two black horns curving out then up, the left the longer, each
		# rooted in a glowing ember ring
		"shape": SHAPE_HELM, "height": 0.44, "band": true, "band_height": 0.07, "band_y": 0.4,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.47, "size": Vector3(0, 0.03, 0), "lip": 0.0, "offset": Vector3(0, 0.46, 0), "tone": EMBERHEART_LIT},
			{"shape": SHAPE_SEAM, "size": Vector3(0.34, 0.035, 0.03), "offset": Vector3(0, 0.33, -0.455), "tilt": Vector3(-0.3, 0, 0), "glow": 1.4},
			{"shape": SHAPE_PRISM_STACK, "count": 3, "length": 0.6, "radius": 0.085, "taper": 0.7, "bend": -0.4, "offset": Vector3(-0.34, 0.62, 0.02), "tilt": Vector3(0.9, -PI * 0.5, 0), "root_tone": "accent", "tone": "accent", "tip_tone": "trim"},
			{"shape": SHAPE_PRISM_STACK, "count": 3, "length": 0.5, "radius": 0.085, "taper": 0.7, "bend": -0.4, "offset": Vector3(0.34, 0.62, 0.02), "tilt": Vector3(0.9, PI * 0.5, 0), "root_tone": "accent", "tone": "accent", "tip_tone": "trim"},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.085, "size": Vector3(0, 0.05, 0), "lip": 0.014, "offset": Vector3(-0.34, 0.62, 0.02), "tilt": Vector3(0.9, -PI * 0.5, 0), "glow": 1.2},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.085, "size": Vector3(0, 0.05, 0), "lip": 0.014, "offset": Vector3(0.34, 0.62, 0.02), "tilt": Vector3(0.9, PI * 0.5, 0), "glow": 1.2},
		],
	}},
	"emberheart_body": {"palette": EMBERHEART, PART_BODY: {
		# black plate with a lit rim at the collar and a bronze rim at the hem, three ember cracks
		# down the chest round a burning core (a six-sided crystal faced forward and up), and big
		# angular pauldrons, three plates on the left and two on the
		# right, their edges lit ember
		"shape": SHAPE_VEST,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.345, "size": Vector3(0, 0.04, 0), "lip": 0.02, "offset": Vector3(0, 0.18, 0), "tone": EMBERHEART_LIT},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.36, "size": Vector3(0, 0.04, 0), "lip": 0.02, "offset": Vector3(0, -0.29, 0)},
			{"shape": SHAPE_SEAM, "size": Vector3(0.03, 0.26, 0.03), "offset": Vector3(-0.12, -0.02, -0.355), "tilt": Vector3(-0.1, 0, 0.35), "glow": 1.3},
			{"shape": SHAPE_SEAM, "size": Vector3(0.03, 0.26, 0.03), "offset": Vector3(0.12, -0.02, -0.355), "tilt": Vector3(-0.1, 0, -0.35), "glow": 1.3},
			{"shape": SHAPE_SEAM, "size": Vector3(0.03, 0.2, 0.03), "offset": Vector3(0, -0.2, -0.37), "glow": 1.3},
			{"shape": SHAPE_CRYSTAL, "facets": 6, "length": 0.14, "radius": 0.08, "root": 0.35, "offset": Vector3(0, 0.03, -0.34), "tilt": Vector3(-1.2, 0, 0), "glow": 1.6, "root_tone": "trim"},
			{"shape": SHAPE_STACKED_PLATES, "plates_left": 3, "plates_right": 2, "size_left": Vector3(0.36, 0.1, 0.4), "size_right": Vector3(0.32, 0.1, 0.36), "x": 0.44, "y": 0.2, "tilt": 0.3, "step": Vector3(0.05, -0.08, 0), "under_tone": "accent", "glow": 1.0},
		],
	}},
	"emberheart_legs": {"palette": EMBERHEART, PART_HIPS: {
		# four black tassets with ember hems hung from a bronze belt over a dark kilt
		"shape": SHAPE_KILT,
		LAYERS: [{"shape": SHAPE_TASSETS, "count": 4, "belt_tone": "trim", "glow": 1.0}],
	}, PART_SHIN: {
		# a black greave with a bronze rim at its top and an ember seam down its front
		"shape": SHAPE_FUR_BAND, "band_radius": 0.175, "band_height": 0.04, "band_y": -0.02,
		LAYERS: [{"shape": SHAPE_SEAM, "size": Vector3(0.025, 0.16, 0.025), "offset": Vector3(0, -0.12, -0.165), "glow": 1.2}],
	}},
	# the forge hammer: a black head cracked with ember, banded in dark bronze on a horn haft
	"emberheart_hammer": {"palette": EMBERHEART, PART_WEAPON: {"shape": SHAPE_FORGE_HAMMER, "glow": 1.5}},
	# Hoarfrost (top): ice plate grown over white fur, a crown of frost shards, crystal shoulders
	# and a blade that is one long icicle. Glow: emissive shard tips, the blade's core and the
	# white fur trims. The dark-blue harness holds the silhouette on pale snow.
	"hoarfrost_helm": {"palette": HOARFROST, PART_HEAD: {
		# a pale ice cap over a dark harness band with a white fur rim, under a tilted crown of seven
		# frost shards glowing faintly blue at the tips
		"shape": SHAPE_HELM, "band": true, "band_tone": "dark", "band_height": 0.07, "band_y": 0.4,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.47, "size": Vector3(0, 0.03, 0), "lip": 0.0, "offset": Vector3(0, 0.46, 0), "tone": "trim"},
			{"shape": SHAPE_SHARD_CROWN, "count": 7, "tone": "accent", "glow": 0.8, "offset": Vector3(0, 0.52, 0), "tilt": Vector3(0.12, 0, -0.1)},
		],
	}},
	"hoarfrost_body": {"palette": HOARFROST, PART_BODY: {
		# an ice breastplate crossed by a dark-blue harness (two straps, lit along their edges),
		# a white fur mantle round the shoulders, a crystal cluster on each shoulder, the left the
		# taller, and a dark harness band at the hem
		"shape": SHAPE_VEST,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.36, "size": Vector3(0, 0.04, 0), "lip": 0.02, "offset": Vector3(0, -0.29, 0), "tone": "dark"},
			{"shape": SHAPE_SASH, "roll": 0.6, "tone": "dark", "edge_tone": HOARFROST_HARNESS_LIT},
			{"shape": SHAPE_SASH, "roll": -0.6, "tone": "dark", "edge_tone": HOARFROST_HARNESS_LIT},
			{"shape": SHAPE_RUFF, "tone": "trim", "trim_tone": HOARFROST_LIT},
			{"shape": SHAPE_SHARD_CROWN, "count": 3, "arc": PI, "radius": 0.06, "lean": 0.5, "length": 0.3, "shard": 0.06, "offset": Vector3(-0.42, 0.22, 0), "tilt": Vector3(0, 0, 0.3), "tone": "accent", "glow": 0.8},
			{"shape": SHAPE_SHARD_CROWN, "count": 3, "arc": PI, "radius": 0.06, "lean": 0.5, "length": 0.24, "shard": 0.06, "offset": Vector3(0.42, 0.22, 0), "tilt": Vector3(0, 0, -0.3), "tone": "accent", "glow": 0.8},
		],
	}},
	"hoarfrost_legs": {"palette": HOARFROST, PART_HIPS: {
		# ice tassets with lit hems hung from a dark harness belt over a dark-blue kilt
		"shape": SHAPE_KILT,
		LAYERS: [{"shape": SHAPE_TASSETS, "edge_tone": HOARFROST_LIT, "shadow_tone": "accent"}],
	}, PART_SHIN: {
		# a white fur boot under an ice band
		"shape": SHAPE_FUR_BAND, "tone": "trim", "band_tone": "base", "band_radius": 0.19, "band_height": 0.1, "band_y": -0.03,
	}},
	# the icicle greatsword: a long pale blade with a glowing core down its whole length (no
	# transparency; the core's emission does the work) on dark harness fittings
	"hoarfrost_greatsword": {"palette": HOARFROST, PART_WEAPON: {"shape": SHAPE_GREATSWORD, "ridge_tone": "accent", "guard_tone": "dark", "grip_tone": "dark", "fuller_length": 1.0, "glow": 1.4}},
	# Auroral (top): dusk-violet plate under the northern lights, antlers of the great stag,
	# swept wing pauldrons and aurora-green trim. Glow: emissive green seams, rims and the blade
	# edge, and the lilac trims.
	"auroral_helm": {"palette": AURORAL, PART_HEAD: {
		# a deep violet dome under a lilac band with a lit rim, pale antlers branching up and out,
		# the left the longer with one more tine
		"shape": SHAPE_HELM, "band": true, "band_height": 0.07, "band_y": 0.4,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.47, "size": Vector3(0, 0.03, 0), "lip": 0.0, "offset": Vector3(0, 0.46, 0), "tone": AURORAL_LIT},
			{"shape": SHAPE_ANTLERS, "length_left": 0.6, "length_right": 0.52, "tines_left": 3, "tines_right": 2, "tip_tone": AURORAL_ANTLER_LIT},
		],
	}},
	"auroral_body": {"palette": AURORAL, PART_BODY: {
		# violet plate with lilac rims at the collar and hem, two aurora-green seams either side
		# of a five-pointed star (a crystal faced forward and up), a shoulder plate each side and a swept wing rising out and up from each, the left
		# the longer, edged in green
		"shape": SHAPE_VEST,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.345, "size": Vector3(0, 0.04, 0), "lip": 0.02, "offset": Vector3(0, 0.18, 0)},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.36, "size": Vector3(0, 0.04, 0), "lip": 0.02, "offset": Vector3(0, -0.29, 0)},
			{"shape": SHAPE_SEAM, "size": Vector3(0.03, 0.3, 0.03), "offset": Vector3(-0.15, -0.04, -0.35), "tilt": Vector3(-0.1, 0, 0), "glow": 1.2},
			{"shape": SHAPE_SEAM, "size": Vector3(0.03, 0.3, 0.03), "offset": Vector3(0.15, -0.04, -0.35), "tilt": Vector3(-0.1, 0, 0), "glow": 1.2},
			{"shape": SHAPE_CRYSTAL, "facets": 5, "length": 0.14, "radius": 0.09, "root": 0.3, "offset": Vector3(0, 0.0, -0.34), "tilt": Vector3(-1.2, 0, 0), "glow": 1.5, "root_tone": "trim"},
			{"shape": SHAPE_STACKED_PLATES, "plates_left": 1, "plates_right": 1, "size_left": Vector3(0.3, 0.08, 0.34), "size_right": Vector3(0.3, 0.08, 0.34), "trim_tone": AURORAL_LIT},
			{"shape": SHAPE_FIN, "size": Vector3(0.3, 0.46, 0.04), "offset": Vector3(-0.42, 0.24, 0.02), "tilt": Vector3(-(PI * 0.5 - 0.5), PI * 0.5, 0), "edge": 0.03, "glow": 1.0},
			{"shape": SHAPE_FIN, "size": Vector3(0.3, 0.38, 0.04), "offset": Vector3(0.42, 0.24, 0.02), "tilt": Vector3(-(PI * 0.5 - 0.5), -PI * 0.5, 0), "edge": 0.03, "glow": 1.0},
		],
	}},
	"auroral_legs": {"palette": AURORAL, PART_HIPS: {
		# three violet faulds with aurora-green rims over a dark kilt
		"shape": SHAPE_KILT,
		LAYERS: [{"shape": SHAPE_FAULDS, "glow": 1.0}],
	}, PART_SHIN: {
		# a violet greave with a lilac band at its top
		"shape": SHAPE_FUR_BAND, "band_radius": 0.175, "band_height": 0.04, "band_y": -0.02,
	}},
	# the glaive: a long violet haft with lilac fittings and a curved lit-violet blade that glows
	# green along its edge
	"auroral_glaive": {"palette": AURORAL, PART_WEAPON: {"shape": SHAPE_GLAIVE, "tone": AURORAL_LIT, "haft_tone": "base", "glow": 1.4}},
	# Trollbone (top): trophies of the ice troll, a tusked skull helm, tusk pauldrons, bone
	# plates lashed over dark hide and a cleaver cut from one tusk. Its only glow is the bone
	# trim (#250); the silhouette says the rest.
	"trollbone_helm": {"palette": TROLLBONE, PART_HEAD: {
		# an ivory skull over a hide band: two dark eye sockets, a toothed jaw guard hanging over
		# the chin, and two tusks curving out then up from the cheeks, the left the longer
		"shape": SHAPE_HELM, "tone": "trim", "radius": 0.49, "height": 0.44, "band": true, "band_tone": "base", "band_radius": 0.5, "band_height": 0.06, "band_y": 0.38,
		LAYERS: [
			{"shape": SHAPE_SEAM, "size": Vector3(0.1, 0.07, 0.03), "offset": Vector3(-0.13, 0.33, -0.455), "tone": "dark", "shadow_tone": TROLLBONE_BONE_DARK},
			{"shape": SHAPE_SEAM, "size": Vector3(0.1, 0.07, 0.03), "offset": Vector3(0.13, 0.33, -0.455), "tone": "dark", "shadow_tone": TROLLBONE_BONE_DARK},
			{"shape": SHAPE_FIN, "size": Vector3(0.3, 0.1, 0.05), "offset": Vector3(0, 0.22, -0.44), "tilt": Vector3(PI, 0, 0), "jagged": true, "teeth": 5, "tooth": 0.06, "tone": "trim", "edge_tone": TROLLBONE_BONE_LIT},
			{"shape": SHAPE_PRISM_STACK, "count": 3, "length": 0.5, "radius": 0.07, "taper": 0.65, "bend": -0.45, "offset": Vector3(-0.4, 0.3, -0.12), "tilt": Vector3(1.2, -PI * 0.5, 0), "root_tone": TROLLBONE_BONE_DARK, "tone": "trim", "tip_tone": TROLLBONE_BONE_LIT},
			{"shape": SHAPE_PRISM_STACK, "count": 3, "length": 0.42, "radius": 0.07, "taper": 0.65, "bend": -0.45, "offset": Vector3(0.4, 0.3, -0.12), "tilt": Vector3(1.2, PI * 0.5, 0), "root_tone": TROLLBONE_BONE_DARK, "tone": "trim", "tip_tone": TROLLBONE_BONE_LIT},
		],
	}},
	"trollbone_body": {"palette": TROLLBONE, PART_BODY: {
		# three bone plates lashed across a dark hide vest under a blood-red wrap, a hide pad on
		# each shoulder and a tusk curving out then up from each, the left the longer
		"shape": SHAPE_VEST,
		LAYERS: [
			{"shape": SHAPE_FIN, "size": Vector3(0.32, 0.09, 0.04), "offset": Vector3(0, 0.08, -0.355), "tilt": Vector3(-0.1, 0, 0), "tone": "trim", "edge_tone": TROLLBONE_BONE_LIT, "edge": 0.02},
			{"shape": SHAPE_FIN, "size": Vector3(0.32, 0.09, 0.04), "offset": Vector3(0, -0.04, -0.355), "tilt": Vector3(-0.1, 0, 0), "tone": "trim", "edge_tone": TROLLBONE_BONE_LIT, "edge": 0.02},
			{"shape": SHAPE_FIN, "size": Vector3(0.32, 0.09, 0.04), "offset": Vector3(0, -0.16, -0.355), "tilt": Vector3(-0.1, 0, 0), "tone": "trim", "edge_tone": TROLLBONE_BONE_LIT, "edge": 0.02},
			{"shape": SHAPE_SASH, "offset": Vector3(0, -0.05, -0.38), "edge_tone": TROLLBONE_BLOOD_DARK},
			{"shape": SHAPE_STACKED_PLATES, "plates_left": 1, "plates_right": 1, "size_left": Vector3(0.3, 0.08, 0.34), "size_right": Vector3(0.3, 0.08, 0.34), "trim_tone": TROLLBONE_HIDE_LIT},
			{"shape": SHAPE_PRISM_STACK, "count": 3, "length": 0.44, "radius": 0.08, "taper": 0.65, "bend": -0.45, "offset": Vector3(-0.42, 0.24, 0), "tilt": Vector3(1.1, -PI * 0.5, 0), "root_tone": TROLLBONE_BONE_DARK, "tone": "trim", "tip_tone": TROLLBONE_BONE_LIT},
			{"shape": SHAPE_PRISM_STACK, "count": 3, "length": 0.36, "radius": 0.08, "taper": 0.65, "bend": -0.45, "offset": Vector3(0.42, 0.24, 0), "tilt": Vector3(1.1, PI * 0.5, 0), "root_tone": TROLLBONE_BONE_DARK, "tone": "trim", "tip_tone": TROLLBONE_BONE_LIT},
		],
	}},
	"trollbone_legs": {"palette": TROLLBONE, PART_HIPS: {
		# bone tassets hung from a hide belt over a hide kilt
		"shape": SHAPE_KILT, "tone": "base",
		LAYERS: [{"shape": SHAPE_TASSETS, "tone": "trim", "edge_tone": TROLLBONE_BONE_LIT, "shadow_tone": TROLLBONE_BONE_DARK, "belt_tone": "base"}],
	}, PART_SHIN: {
		# a bone shin plate strapped on with hide
		"shape": SHAPE_FUR_BAND, "tone": "trim", "band_tone": "base", "band_radius": 0.175, "band_height": 0.05, "band_y": -0.02,
	}},
	# the tusk cleaver: a broad curved ivory blade on a short hide-wrapped grip, bound in blood
	# red. No glow.
	"trollbone_cleaver": {"palette": TROLLBONE, PART_WEAPON: {"shape": SHAPE_CLEAVER, "edge_tone": TROLLBONE_BONE_LIT, "back_tone": TROLLBONE_BONE_DARK}},
	# The ranged sets (#164). As with the melee sets, every colour, size, offset and glow is
	# here. None glows. The ladder steps up by what stands out past the body: a round hood,
	# then ear points with a mantle and a quiver, then a pointed cap with a feather, square
	# pauldrons and greaves.
	# Trapper's Leathers (mid): ring-one hide tanned at the outpost. No glow.
	"trapper_helm": {"palette": TRAPPER, PART_HEAD: {
		# a round hide hood with a pale fur edge round the face, a dark seam ridge running
		# front to back over the crown so the head reads as a hood and not a disc, and two
		# lace knots tied under the chin
		"shape": SHAPE_FUR_HOOD, "hoop_tone": "trim",
		LAYERS: [
			{"shape": SHAPE_FIN, "size": Vector3(0.08, 0.2, 0.64), "offset": Vector3(0, 0.68, 0.0), "edge": 0.03, "tone": "dark", "edge_tone": TRAPPER_HIDE_LIT},
			{"shape": SHAPE_STUDS, "count": 2, "arc": 0.5, "radius": 0.46, "y": -0.2, "stud": 0.04, "band": false, "stud_tone": "dark"},
		],
	}},
	"trapper_body": {"palette": TRAPPER, PART_BODY: {
		# a hide jerkin with a dark belt at the hem, a dark lacing strip down the chest with a
		# pale tie at its top and three pale lace knots down it
		"shape": SHAPE_VEST,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.365, "size": Vector3(0, 0.06, 0), "lip": 0.0, "offset": Vector3(0, -0.28, 0), "tone": "dark"},
			{"shape": SHAPE_FIN, "size": Vector3(0.07, 0.36, 0.03), "offset": Vector3(0, -0.26, -0.37), "edge": 0.03, "tone": "dark", "edge_tone": "trim"},
			{"shape": SHAPE_STUDS, "count": 1, "rows": 3, "row_step": 0.1, "band": false, "y": 0.06, "radius": 0.39, "stud": 0.025, "stud_tone": "trim"},
		],
	}},
	"trapper_legs": {"palette": TRAPPER, PART_HIPS: {
		# a hide hip wrap under a dark belt, with a pale fur edge at its hem
		"shape": SHAPE_KILT, "tone": "base",
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.39, "size": Vector3(0, 0.05, 0), "lip": 0.0, "offset": Vector3(0, 0.03, 0), "tone": "dark"},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.46, "size": Vector3(0, 0.035, 0), "lip": 0.0, "offset": Vector3(0, -0.19, 0), "tone": "trim"},
		],
	}, PART_SHIN: {
		# a hide shin wrap with a dark strap at the knee and a second lower down
		"shape": SHAPE_FUR_BAND, "band_tone": "dark", "band_radius": 0.175, "band_height": 0.05, "band_y": -0.03,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.165, "size": Vector3(0, 0.04, 0), "lip": 0.0, "offset": Vector3(0, -0.17, 0), "tone": "dark"},
		],
	}},
	# an ash recurve: a plain stave with a pale string, dark nocks and a dark grip
	"trapper_bow": {"palette": TRAPPER, PART_WEAPON: {"shape": SHAPE_LONGBOW, "tip_bend": 0.25, "tone": "accent", "nock_tone": "dark", "string_tone": BOWSTRING}},
	# Wolfstalker (mid-high): ring one's wolves, worn. No glow.
	"wolfstalker_helm": {"palette": WOLFSTALKER, PART_HEAD: {
		# a grey pelt hood with a bone-pale face trim, two pointed ears standing up and out
		# from the crown, and a darker snout band hanging over the brow
		"shape": SHAPE_FUR_HOOD, "hoop_tone": "trim",
		LAYERS: [
			{"shape": SHAPE_FIN, "size": Vector3(0.2, 0.22, 0.07), "offset": Vector3(-0.22, 0.74, 0.0), "tilt": Vector3(-0.1, 0, 0.35), "jagged": true, "teeth": 1, "tooth": 0.2, "tone": WOLFSTALKER_PELT_DARK},
			{"shape": SHAPE_FIN, "size": Vector3(0.2, 0.22, 0.07), "offset": Vector3(0.22, 0.74, 0.0), "tilt": Vector3(-0.1, 0, -0.35), "jagged": true, "teeth": 1, "tooth": 0.2, "tone": WOLFSTALKER_PELT_DARK},
			{"shape": SHAPE_FIN, "size": Vector3(0.3, 0.12, 0.08), "offset": Vector3(0, 0.62, -0.4), "tilt": Vector3(-0.7, 0, 0), "edge": 0.02, "tone": WOLFSTALKER_PELT_DARK},
		],
	}},
	"wolfstalker_body": {"palette": WOLFSTALKER, PART_BODY: {
		# a dark leather jerkin under a grey pelt mantle round the shoulders with a bone edge,
		# the pelt torn down the back, one bone toggle on the chest and a yew-brown belt
		"shape": SHAPE_VEST, "tone": "dark",
		LAYERS: [
			{"shape": SHAPE_CLOAK, "outline": OUTLINE_TORN, "width": 0.56, "length_left": 0.42, "length_right": 0.34, "offset": Vector3(0, 0.2, 0.34), "tilt": 0.15, "teeth": 4, "tooth": 0.1, "tone": "base", "tooth_tone": "trim"},
			{"shape": SHAPE_RUFF, "inner": 0.24, "outer": 0.5, "y": 0.2, "tone": "base", "trim_tone": "trim"},
			{"shape": SHAPE_STUDS, "count": 1, "band": false, "y": 0.0, "radius": 0.38, "stud": 0.045, "stud_tone": "trim"},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.365, "size": Vector3(0, 0.05, 0), "lip": 0.0, "offset": Vector3(0, -0.28, 0), "tone": "accent"},
		],
	}},
	"wolfstalker_legs": {"palette": WOLFSTALKER, PART_HIPS: {
		# dark leather hips under a yew-brown belt, a ragged pelt flap hanging behind and a
		# shorter one in front
		"shape": SHAPE_KILT, "tone": "dark",
		LAYERS: [
			{"shape": SHAPE_CLOAK, "outline": OUTLINE_TORN, "width": 0.5, "length_left": 0.3, "length_right": 0.26, "offset": Vector3(0, 0.04, 0.4), "tilt": 0.2, "teeth": 3, "tooth": 0.1, "tone": "base", "tooth_tone": "trim"},
			{"shape": SHAPE_CLOAK, "outline": OUTLINE_TORN, "width": 0.44, "length_left": 0.22, "length_right": 0.26, "offset": Vector3(0, 0.04, -0.4), "tilt": -0.2, "teeth": 3, "tooth": 0.08, "tone": "base", "tooth_tone": "trim"},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.39, "size": Vector3(0, 0.05, 0), "lip": 0.0, "offset": Vector3(0, 0.03, 0), "tone": "accent"},
		],
	}, PART_SHIN: {
		# a dark shin wrap with a bone band at the knee
		"shape": SHAPE_FUR_BAND, "tone": "dark", "band_tone": "trim", "band_radius": 0.185, "band_height": 0.06, "band_y": -0.03,
	}},
	# a dark yew longbow, longer than the others, with bone nocks and a pale string
	"wolfstalker_bow": {"palette": WOLFSTALKER, PART_WEAPON: {"shape": SHAPE_LONGBOW, "length": 1.25, "nock": 0.04, "tone": "accent", "string_tone": BOWSTRING}},
	# a dark leather quiver with a bone cap band, yew shafts and pale fletching
	"wolfstalker_quiver": {"palette": WOLFSTALKER, PART_QUIVER: {"shape": SHAPE_QUIVER, "tone": "dark", "foot_tone": "accent", "band_tone": "trim", "shaft_tone": "accent", "fletch_tone": "trim", "tip_tone": "trim"}},
	# Steelpoint Ranger (high): ring two's smithed steel on a hunter's frame. No glow.
	"steelpoint_helm": {"palette": STEELPOINT, PART_HEAD: {
		# a brimmed steel cap: the dome over a wide thin brim, a dark strap round it above the
		# brim, a pointed crown rising from the top with a lit tip, and one amber feather
		# standing up and out to the right
		"shape": SHAPE_HELM, "band": true, "band_radius": 0.56, "band_height": 0.03, "band_y": 0.4, "band_tone": "base",
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.465, "size": Vector3(0, 0.045, 0), "lip": 0.0, "offset": Vector3(0, 0.46, 0), "tone": "dark"},
			{"shape": SHAPE_PRISM_STACK, "count": 2, "length": 0.44, "radius": 0.3, "facets": 8, "bend": 0.0, "taper": 0.5, "offset": Vector3(0, 0.7, 0), "root_tone": "base", "tip_tone": STEELPOINT_LIT},
			{"shape": SHAPE_FIN, "size": Vector3(0.1, 0.5, 0.03), "offset": Vector3(0.16, 0.74, 0.0), "tilt": Vector3(0.45, 0, -0.55), "edge": 0.06, "tone": "trim", "edge_tone": STEELPOINT_AMBER_DARK},
		],
	}},
	"steelpoint_body": {"palette": STEELPOINT, PART_BODY: {
		# a pine-green leather jerkin with square steel pauldrons stepped over a dark
		# under-plate, a lit steel rim at the collar, three steel studs down the chest and a
		# dark belt at the hem
		"shape": SHAPE_VEST, "tone": "accent",
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.345, "size": Vector3(0, 0.035, 0), "lip": 0.015, "offset": Vector3(0, 0.18, 0), "tone": "base"},
			{"shape": SHAPE_STACKED_PLATES, "plates_left": 2, "plates_right": 2, "size_left": Vector3(0.26, 0.08, 0.3), "size_right": Vector3(0.26, 0.08, 0.3), "x": 0.4, "y": 0.18, "trim_tone": STEELPOINT_LIT},
			{"shape": SHAPE_STUDS, "count": 1, "rows": 3, "row_step": 0.1, "band": false, "y": 0.06, "radius": 0.38, "stud": 0.03, "stud_tone": "base"},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.365, "size": Vector3(0, 0.05, 0), "lip": 0.0, "offset": Vector3(0, -0.28, 0), "tone": "dark"},
		],
	}},
	"steelpoint_legs": {"palette": STEELPOINT, PART_HIPS: {
		# pine leather chaps: two plates hung from a dark belt over pine hips
		"shape": SHAPE_KILT, "tone": "accent",
		LAYERS: [
			{"shape": SHAPE_TASSETS, "count": 2, "arc": PI * 0.6, "size": Vector3(0.2, 0.24, 0.035), "tone": "accent", "edge_tone": STEELPOINT_PINE_LIT},
		],
	}, PART_SHIN: {
		# a steel greave with a lit steel knee plate
		"shape": SHAPE_FUR_BAND, "band_tone": STEELPOINT_LIT, "band_radius": 0.19, "band_height": 0.1, "band_y": -0.03,
	}},
	# a steel-capped recurve: a pine stave with steel limb caps, grip and nocks, a pale string
	"steelpoint_bow": {"palette": STEELPOINT, PART_WEAPON: {"shape": SHAPE_LONGBOW, "tip_bend": 0.35, "cap_length": 0.14, "tone": "accent", "cap_tone": "base", "grip_tone": "base", "nock_tone": "base", "string_tone": BOWSTRING}},
	# a pine leather quiver with a steel foot and cap band, dark shafts and amber fletching
	"steelpoint_quiver": {"palette": STEELPOINT, PART_QUIVER: {"shape": SHAPE_QUIVER, "tone": "accent", "foot_tone": "base", "band_tone": "base", "shaft_tone": "dark", "fletch_tone": "trim", "tip_tone": "base"}},
	# The ranged top sets (#165): the ranged sets above steel, each with one accent glow on its
	# tips, hems, eyes, strings and nocks, emissive only: no light, no motes. Every colour,
	# size, offset and glow is here, to be tuned live after playtesting with a re-shoot. Each
	# keeps one feature past the body (a crest and wings, a banner, a shroud, a crown) and a
	# dark or warm anchor against the snow.
	# Ember Hawk (top): the warmth carried out of the gate, charred leather inlaid with ember
	# glow, a hawk crest and wings on the shoulders. Glow: the crest's and wings' feather tips,
	# the chest chevrons, the knee studs, the bow's limb tips and the quiver's fletching.
	"ember_hawk_helm": {"palette": EMBER_HAWK, PART_HEAD: {
		# a charcoal hawk hood with a gold hoop round the face, a beaked visor jutting from the
		# brow with a gold edge, and a crest of five charred feathers fanning above the crown,
		# tilted a little to the right, each tipped with an ember
		"shape": SHAPE_FUR_HOOD, "hoop_tone": "trim",
		LAYERS: [
			{"shape": SHAPE_FIN, "size": Vector3(0.26, 0.2, 0.05), "offset": Vector3(0, 0.5, -0.4), "tilt": Vector3(-1.0, 0, 0), "edge": 0.025, "tone": "dark", "edge_tone": "trim"},
			{"shape": SHAPE_PLUMES, "count": 5, "arc": PI * 0.85, "length": 0.46, "width": 0.1, "tip": 0.045, "offset": Vector3(0, 0.7, 0.08), "tilt": Vector3(0.35, 0, -0.12), "quill_tone": EMBER_HAWK_LIT, "glow": 1.1},
		],
	}},
	"ember_hawk_body": {"palette": EMBER_HAWK, PART_BODY: {
		# a charred jerkin with a gold collar and a charred belt, two glowing amber chevrons
		# down the chest, and a charcoal pad on each shoulder carrying a wing of three
		# ember-tipped feathers fanned out sideways, the left wing the longer
		"shape": SHAPE_VEST,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.345, "size": Vector3(0, 0.04, 0), "lip": 0.02, "offset": Vector3(0, 0.18, 0)},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.365, "size": Vector3(0, 0.05, 0), "lip": 0.0, "offset": Vector3(0, -0.28, 0), "tone": "dark"},
			{"shape": SHAPE_SEAM, "size": Vector3(0.03, 0.17, 0.03), "offset": Vector3(-0.07, 0.0, -0.36), "tilt": Vector3(-0.1, 0, -0.6), "glow": 1.3},
			{"shape": SHAPE_SEAM, "size": Vector3(0.03, 0.17, 0.03), "offset": Vector3(0.07, 0.0, -0.36), "tilt": Vector3(-0.1, 0, 0.6), "glow": 1.3},
			{"shape": SHAPE_SEAM, "size": Vector3(0.03, 0.17, 0.03), "offset": Vector3(-0.07, -0.15, -0.365), "tilt": Vector3(-0.1, 0, -0.6), "glow": 1.3},
			{"shape": SHAPE_SEAM, "size": Vector3(0.03, 0.17, 0.03), "offset": Vector3(0.07, -0.15, -0.365), "tilt": Vector3(-0.1, 0, 0.6), "glow": 1.3},
			{"shape": SHAPE_STACKED_PLATES, "plates_left": 1, "plates_right": 1, "size_left": Vector3(0.3, 0.08, 0.34), "size_right": Vector3(0.3, 0.08, 0.34), "trim_tone": "trim"},
			{"shape": SHAPE_PLUMES, "count": 3, "arc": 0.9, "length": 0.46, "width": 0.09, "tip": 0.04, "offset": Vector3(-0.5, 0.2, 0.02), "tilt": Vector3(-PI * 0.5, 0.25, PI * 0.5), "quill_tone": EMBER_HAWK_LIT, "glow": 1.1},
			{"shape": SHAPE_PLUMES, "count": 3, "arc": 0.9, "length": 0.38, "width": 0.09, "tip": 0.04, "offset": Vector3(0.5, 0.2, 0.02), "tilt": Vector3(-PI * 0.5, -0.25, -PI * 0.5), "quill_tone": EMBER_HAWK_LIT, "glow": 1.1},
		],
	}},
	"ember_hawk_legs": {"palette": EMBER_HAWK, PART_HIPS: {
		# a charcoal kilt under a charred belt with a gold hem
		"shape": SHAPE_KILT, "tone": "base",
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.39, "size": Vector3(0, 0.05, 0), "lip": 0.0, "offset": Vector3(0, 0.03, 0), "tone": "dark"},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.46, "size": Vector3(0, 0.035, 0), "lip": 0.0, "offset": Vector3(0, -0.19, 0), "shadow_tone": EMBER_HAWK_GOLD_DARK},
		],
	}, PART_SHIN: {
		# a charcoal shin wrap under a charred knee strap, an ember stud at the knee
		"shape": SHAPE_FUR_BAND, "band_tone": "dark", "band_radius": 0.175, "band_height": 0.05, "band_y": -0.03,
		LAYERS: [{"shape": SHAPE_STUDS, "count": 1, "band": false, "radius": 0.18, "y": -0.03, "stud": 0.035, "glow": 1.2}],
	}},
	# the ember bow: a black stave with a gold grip and gold limb caps, a warm string and
	# glowing limb tips
	"ember_hawk_bow": {"palette": EMBER_HAWK, PART_WEAPON: {"shape": SHAPE_LONGBOW, "tip_bend": 0.2, "cap_length": 0.1, "grip_tone": "trim", "cap_tone": "trim", "string_tone": "accent", "glow": 1.3}},
	# a charcoal quiver with a gold foot and cap band, dark shafts and ember fletching
	"ember_hawk_quiver": {"palette": EMBER_HAWK, PART_QUIVER: {"shape": SHAPE_QUIVER, "foot_tone": "trim", "band_tone": "trim", "shaft_tone": "dark", "fletch_tone": "trim", "glow": 1.2}},
	# Auroral Warden (top): a bow blessed under the outer rings' aurora, the magic-hunter in
	# snow-white hide, silver and a banner of green light. Glow: the banner, the kilt's and the
	# mantle's hems, the bowstring and nocks, the quiver's fletching.
	"auroral_warden_helm": {"palette": AURORAL_WARDEN, PART_HEAD: {
		# a white hood lined violet round the face under a silver circlet, and a tall aurora
		# banner rising from the back of the crown, lit in front and plain teal behind, with a
		# violet core up its face, leaning back and a little to the left
		"shape": SHAPE_FUR_HOOD, "hoop_tone": "dark",
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.47, "size": Vector3(0, 0.04, 0), "lip": 0.0, "offset": Vector3(0, 0.5, 0), "shadow_tone": "accent"},
			{"shape": SHAPE_SEAM, "size": Vector3(0.22, 0.76, 0.03), "offset": Vector3(0, 0.98, 0.33), "tilt": Vector3(0.4, 0, 0.1), "lip": 0.0, "shadow_tone": "glow", "glow": 1.2},
			{"shape": SHAPE_FIN, "size": Vector3(0.08, 0.5, 0.04), "offset": Vector3(0, 0.66, 0.15), "tilt": Vector3(0.4, 0, 0.1), "edge": 0.03, "tone": "dark", "edge_tone": AURORAL_WARDEN_VIOLET_LIT},
		],
	}},
	"auroral_warden_body": {"palette": AURORAL_WARDEN, PART_BODY: {
		# a white hide jerkin with a silver rim at the collar and a violet belt, three silver
		# clasps down the chest, and a silver shoulder plate each side, two on the left
		"shape": SHAPE_VEST,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.345, "size": Vector3(0, 0.035, 0), "lip": 0.015, "offset": Vector3(0, 0.18, 0), "shadow_tone": "accent"},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.365, "size": Vector3(0, 0.05, 0), "lip": 0.0, "offset": Vector3(0, -0.28, 0), "tone": "dark"},
			{"shape": SHAPE_STUDS, "count": 1, "rows": 3, "row_step": 0.1, "band": false, "y": 0.06, "radius": 0.38, "stud": 0.03, "stud_tone": "trim"},
			{"shape": SHAPE_STACKED_PLATES, "plates_left": 2, "plates_right": 1, "size_left": Vector3(0.28, 0.08, 0.32), "size_right": Vector3(0.26, 0.08, 0.3), "tone": "trim", "under_tone": "accent", "trim_tone": AURORAL_WARDEN_SILVER_LIT},
		],
	}},
	"auroral_warden_legs": {"palette": AURORAL_WARDEN, PART_HIPS: {
		# a long white kilt under a violet belt, its hem lit aurora green
		"shape": SHAPE_KILT, "tone": "base", "height": 0.34, "bottom_radius": 0.48, "y": -0.12,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.39, "size": Vector3(0, 0.05, 0), "lip": 0.0, "offset": Vector3(0, 0.03, 0), "tone": "dark"},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.48, "size": Vector3(0, 0.035, 0), "lip": 0.0, "offset": Vector3(0, -0.27, 0), "shadow_tone": "accent", "glow": 1.1},
		],
	}, PART_SHIN: {
		# a silver greave with a violet band at its top
		"shape": SHAPE_FUR_BAND, "tone": "trim", "band_tone": "dark", "band_radius": 0.18, "band_height": 0.05, "band_y": -0.03,
	}},
	# the silver bow strung with light: a silver stave with a violet grip, its string and nocks
	# glowing aurora green
	"auroral_warden_bow": {"palette": AURORAL_WARDEN, PART_WEAPON: {"shape": SHAPE_LONGBOW, "tip_bend": 0.3, "tone": "trim", "grip_tone": "dark", "lit_string": true, "glow": 1.3}},
	# a white quiver with a silver cap band and silver foot, dark shafts and glowing fletching
	"auroral_warden_quiver": {"palette": AURORAL_WARDEN, PART_QUIVER: {"shape": SHAPE_QUIVER, "foot_tone": "trim", "band_tone": "trim", "shaft_tone": "dark", "fletch_tone": "trim", "glow": 1.2}},
	# the long white mantle hung behind the body, lined silver along its edges, its hem lit
	# aurora green, the left half the longer
	"auroral_warden_cape": {"palette": AURORAL_WARDEN, PART_CAPE: {"shape": SHAPE_CLOAK, "width": 0.64, "length_left": 1.0, "length_right": 0.92, "hem": 0.06, "lining": 0.03, "lining_tone": "trim", "glow": 1.2}},
	# Ruin Stalker's Shroud (top): the ruin stalker's own hide and bone turned back on it, ink
	# leathers, a bone mask, a tattered shroud. Glow: the mask's eyes and the bow's nocks only.
	"ruin_stalker_helm": {"palette": RUIN_STALKER, PART_HEAD: {
		# a low ink hood with an ash hoop round the face and a fold ridge over the crown, a bone
		# skull mask over the face with two violet-glow eyes, and two short bone spurs curving
		# up from the hood's sides, the left the longer
		"shape": SHAPE_FUR_HOOD, "hoop_tone": "accent",
		LAYERS: [
			{"shape": SHAPE_FIN, "size": Vector3(0.09, 0.14, 0.6), "offset": Vector3(0, 0.72, 0.02), "tilt": Vector3(0.1, 0, 0), "edge": 0.03, "tone": RUIN_STALKER_INK_LIT, "edge_tone": "accent"},
			{"shape": SHAPE_FIN, "size": Vector3(0.32, 0.28, 0.04), "offset": Vector3(0, 0.04, -0.52), "tilt": Vector3(-0.15, 0, 0), "edge": 0.02, "tone": "trim", "edge_tone": RUIN_STALKER_BONE_DARK},
			{"shape": SHAPE_SEAM, "size": Vector3(0.08, 0.06, 0.03), "offset": Vector3(-0.085, 0.25, -0.565), "tilt": Vector3(-0.15, 0, 0), "lip": 0.015, "glow": 1.8},
			{"shape": SHAPE_SEAM, "size": Vector3(0.08, 0.06, 0.03), "offset": Vector3(0.085, 0.25, -0.565), "tilt": Vector3(-0.15, 0, 0), "lip": 0.015, "glow": 1.8},
			{"shape": SHAPE_PRISM_STACK, "count": 2, "length": 0.38, "radius": 0.065, "taper": 0.6, "bend": -0.5, "offset": Vector3(-0.4, 0.5, 0.0), "tilt": Vector3(0.9, -PI * 0.5, 0), "root_tone": RUIN_STALKER_BONE_DARK, "tone": "trim", "tip_tone": RUIN_STALKER_BONE_LIT},
			{"shape": SHAPE_PRISM_STACK, "count": 2, "length": 0.3, "radius": 0.065, "taper": 0.6, "bend": -0.5, "offset": Vector3(0.4, 0.5, 0.0), "tilt": Vector3(0.9, PI * 0.5, 0), "root_tone": RUIN_STALKER_BONE_DARK, "tone": "trim", "tip_tone": RUIN_STALKER_BONE_LIT},
		],
	}},
	"ruin_stalker_body": {"palette": RUIN_STALKER, PART_BODY: {
		# an ink jerkin with an ash rim at the collar and an ash belt, three bone rib plates
		# lashed across the chest, and an ash pad on each shoulder, the left the larger
		"shape": SHAPE_VEST,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.345, "size": Vector3(0, 0.035, 0), "lip": 0.015, "offset": Vector3(0, 0.18, 0), "tone": "accent"},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.365, "size": Vector3(0, 0.05, 0), "lip": 0.0, "offset": Vector3(0, -0.28, 0), "tone": "accent"},
			{"shape": SHAPE_FIN, "size": Vector3(0.32, 0.07, 0.04), "offset": Vector3(0, 0.07, -0.355), "tilt": Vector3(-0.1, 0, 0), "tone": "trim", "edge_tone": RUIN_STALKER_BONE_LIT, "edge": 0.018},
			{"shape": SHAPE_FIN, "size": Vector3(0.32, 0.07, 0.04), "offset": Vector3(0, -0.05, -0.355), "tilt": Vector3(-0.1, 0, 0), "tone": "trim", "edge_tone": RUIN_STALKER_BONE_LIT, "edge": 0.018},
			{"shape": SHAPE_FIN, "size": Vector3(0.32, 0.07, 0.04), "offset": Vector3(0, -0.17, -0.355), "tilt": Vector3(-0.1, 0, 0), "tone": "trim", "edge_tone": RUIN_STALKER_BONE_LIT, "edge": 0.018},
			{"shape": SHAPE_STACKED_PLATES, "plates_left": 1, "plates_right": 1, "size_left": Vector3(0.3, 0.08, 0.34), "size_right": Vector3(0.26, 0.08, 0.3), "tone": "accent", "trim_tone": "trim"},
		],
	}},
	"ruin_stalker_legs": {"palette": RUIN_STALKER, PART_HIPS: {
		# an ink kilt under an ash belt with a hem of bone spikes hanging round it
		"shape": SHAPE_KILT, "tone": "base",
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.39, "size": Vector3(0, 0.05, 0), "lip": 0.0, "offset": Vector3(0, 0.03, 0), "tone": "accent"},
			{"shape": SHAPE_SHARD_CROWN, "count": 7, "arc": TAU, "radius": 0.45, "length": 0.13, "short": 0.75, "shard": 0.04, "lean": PI, "tip": 0.5, "offset": Vector3(0, -0.2, 0), "tone": "trim", "tip_tone": RUIN_STALKER_BONE_LIT},
		],
	}, PART_SHIN: {
		# an ink shin wrap with a bone band at the knee and a second lower down
		"shape": SHAPE_FUR_BAND, "band_tone": "trim", "band_radius": 0.18, "band_height": 0.05, "band_y": -0.03,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.165, "size": Vector3(0, 0.035, 0), "lip": 0.0, "offset": Vector3(0, -0.16, 0), "shadow_tone": RUIN_STALKER_BONE_DARK},
		],
	}},
	# the bone bow: a pale stave with an ink grip, a pale string and violet-glow nocks
	"ruin_stalker_bow": {"palette": RUIN_STALKER, PART_WEAPON: {"shape": SHAPE_LONGBOW, "length": 1.2, "tone": "trim", "grip_tone": "base", "nock": 0.04, "string_tone": BOWSTRING, "glow": 1.3}},
	# an ink quiver with a bone cap band and an ash foot, ash shafts and bone fletching
	"ruin_stalker_quiver": {"palette": RUIN_STALKER, PART_QUIVER: {"shape": SHAPE_QUIVER, "foot_tone": "accent", "band_tone": "trim", "shaft_tone": "accent", "fletch_tone": "trim", "tip_tone": "trim"}},
	# the long tattered shroud trailing behind, ink with bone-pale teeth at its ragged hem, the
	# right half the longer
	"ruin_stalker_cape": {"palette": RUIN_STALKER, PART_CAPE: {"shape": SHAPE_CLOAK, "outline": OUTLINE_TORN, "width": 0.62, "length_left": 0.95, "length_right": 1.05, "tilt": 0.3, "teeth": 4, "tooth": 0.14, "tooth_tone": "trim", "lining": 0.02, "lining_tone": RUIN_STALKER_INK_LIT}},
	# Glacier Sovereign (top): ring two's ice crystals grown into a crown, deep-sea hide under
	# ice plates, crystal spurs on the shoulders and frost shards for arrows. Glow: the crown's
	# spikes, the pauldron spurs, the chest gem, the knee spurs, the bow's limb edges and tips,
	# the quiver's shards.
	"glacier_sovereign_helm": {"palette": GLACIER_SOVEREIGN, PART_HEAD: {
		# a deep-sea hood with an ice hoop round the face under a crown of five crystal spikes
		# across the front of the crown, glowing frost at the tips, tilted a little to the left
		"shape": SHAPE_FUR_HOOD, "tone": "dark", "hoop_tone": "base",
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.49, "size": Vector3(0, 0.04, 0), "lip": 0.0, "offset": Vector3(0, 0.48, 0), "tone": "base", "shadow_tone": GLACIER_SOVEREIGN_SEA_LIT},
			{"shape": SHAPE_SHARD_CROWN, "count": 5, "arc": PI * 1.2, "radius": 0.3, "length": 0.52, "short": 0.72, "shard": 0.08, "lean": 0.45, "tip": 0.45, "offset": Vector3(0, 0.52, -0.02), "tilt": Vector3(0.1, 0, 0.1), "tone": "trim", "glow": 1.1},
		],
	}},
	"glacier_sovereign_body": {"palette": GLACIER_SOVEREIGN, PART_BODY: {
		# an ice-blue jerkin crossed by two deep-sea straps with a lit edge, a deep-sea belt, a
		# frost gem glowing at the chest, and crystal pauldrons, two plates on the left and one
		# on the right, each with a cluster of glowing crystal spurs, the left the taller
		"shape": SHAPE_VEST,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.365, "size": Vector3(0, 0.05, 0), "lip": 0.0, "offset": Vector3(0, -0.28, 0), "tone": "dark"},
			{"shape": SHAPE_SASH, "roll": 0.6, "tone": "dark", "edge_tone": GLACIER_SOVEREIGN_SEA_LIT},
			{"shape": SHAPE_SASH, "roll": -0.6, "tone": "dark", "edge_tone": GLACIER_SOVEREIGN_SEA_LIT},
			{"shape": SHAPE_CRYSTAL, "facets": 6, "length": 0.16, "radius": 0.08, "root": 0.35, "offset": Vector3(0, 0.02, -0.34), "tilt": Vector3(-1.2, 0, 0), "glow": 1.4, "root_tone": "dark"},
			{"shape": SHAPE_STACKED_PLATES, "plates_left": 2, "plates_right": 1, "size_left": Vector3(0.3, 0.09, 0.34), "size_right": Vector3(0.28, 0.09, 0.32), "tone": "trim", "under_tone": "dark", "trim_tone": GLACIER_SOVEREIGN_LIT},
			{"shape": SHAPE_SHARD_CROWN, "count": 3, "arc": PI, "radius": 0.06, "lean": 0.55, "length": 0.3, "shard": 0.06, "offset": Vector3(-0.44, 0.24, 0), "tilt": Vector3(0, 0, 0.3), "tone": "trim", "glow": 1.0},
			{"shape": SHAPE_SHARD_CROWN, "count": 3, "arc": PI, "radius": 0.06, "lean": 0.55, "length": 0.22, "shard": 0.06, "offset": Vector3(0.44, 0.24, 0), "tilt": Vector3(0, 0, -0.3), "tone": "trim", "glow": 1.0},
		],
	}},
	"glacier_sovereign_legs": {"palette": GLACIER_SOVEREIGN, PART_HIPS: {
		# a deep-sea kilt under a deep-sea belt with an ice hem
		"shape": SHAPE_KILT, "tone": "dark",
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.39, "size": Vector3(0, 0.05, 0), "lip": 0.0, "offset": Vector3(0, 0.03, 0), "tone": GLACIER_SOVEREIGN_SEA_LIT},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.46, "size": Vector3(0, 0.04, 0), "lip": 0.0, "offset": Vector3(0, -0.19, 0), "tone": "base", "shadow_tone": "accent"},
		],
	}, PART_SHIN: {
		# an ice greave with a deep-sea band at its top and a glowing crystal spur at the knee
		"shape": SHAPE_FUR_BAND, "band_tone": "dark", "band_radius": 0.18, "band_height": 0.05, "band_y": -0.03,
		LAYERS: [{"shape": SHAPE_SHARD_CROWN, "count": 1, "arc": PI, "radius": 0.17, "length": 0.14, "shard": 0.04, "lean": 1.1, "tip": 0.5, "offset": Vector3(0, -0.02, 0), "tone": "trim", "glow": 1.1}],
	}},
	# the crystal bow: crystal limbs edged in frost glow with a deep-sea grip, a light string,
	# and a frost shard standing off each glowing tip
	"glacier_sovereign_bow": {"palette": GLACIER_SOVEREIGN, PART_WEAPON: {"shape": SHAPE_LONGBOW, "tip_bend": 0.2, "edge": 0.018, "shard": 0.09, "tone": "trim", "grip_tone": "dark", "string_tone": BOWSTRING, "glow": 1.2}},
	# a deep-sea quiver with a pale crystal foot and an ice cap band, bristling with glowing
	# frost shards
	"glacier_sovereign_quiver": {"palette": GLACIER_SOVEREIGN, PART_QUIVER: {"shape": SHAPE_QUIVER, "tone": "dark", "foot_tone": "trim", "band_tone": "base", "tips": TIPS_SHARDS, "tip_count": 4, "tip_tone": "trim", "glow": 1.2}},
	# The magic sets (#166, the approved round-2 board on #157). No light, no motes and no
	# emission (#250): the parts the issue names are drawn in the set's glow colour, unlit.
	"shardweaver_helm": {"palette": SHARDWEAVER, PART_HEAD: {
		# a wool cowl: the rounded hood with a cream hoop at the face, a rope band round the
		# brow, a short drape hanging behind the neck, a cream scarf round the throat with one
		# loose end hanging at the left, so the footprint is a teardrop with a tail, not a disc
		"shape": SHAPE_FUR_HOOD, "hoop_tone": "trim", "hoop_inner": 0.4, "hoop_outer": 0.48,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.49, "size": Vector3(0, 0.05, 0), "lip": 0.0, "offset": Vector3(0, 0.4, 0), "tone": "accent"},
			{"shape": SHAPE_FIN, "size": Vector3(0.34, 0.32, 0.05), "offset": Vector3(0, 0.36, 0.42), "tilt": Vector3(PI * 0.85, 0, 0), "tone": "dark", "edge_tone": "trim"},
			{"shape": SHAPE_RUFF, "inner": 0.3, "outer": 0.46, "y": 0.02, "trim": 0.03, "tone": "trim", "trim_tone": "base"},
			{"shape": SHAPE_FIN, "size": Vector3(0.1, 0.22, 0.04), "offset": Vector3(-0.3, 0.0, -0.28), "tilt": Vector3(PI, 0, 0.3), "tone": "trim", "edge_tone": "accent"},
		],
	}},
	"rimecaller_helm": {"palette": RIMECALLER, PART_HEAD: {
		# a peaked indigo hood: a longer swept-back peak, a frost hoop at the face and one small
		# four-facet prism at the brow, leaning out over the face
		"shape": SHAPE_PEAKED_HOOD, "hoop_tone": "trim", "peak_length": 0.55,
		LAYERS: [
			{"shape": SHAPE_CRYSTAL, "facets": 4, "length": 0.16, "radius": 0.045, "root": 0.3, "offset": Vector3(0, 0.5, -0.44), "tilt": Vector3(-0.9, 0, 0), "root_tone": "trim"},
		],
	}},
	"glacier_warden_helm": {"palette": GLACIER_WARDEN, PART_HEAD: {
		# a peaked teal hood with a silver hoop at the face and a silver band round the brow,
		# under a crest of three prisms fanned up from the crown, the centre tallest and the outer
		# two leaning apart, all ice
		"shape": SHAPE_PEAKED_HOOD, "hoop_tone": "trim", "peak_width": 0.4,
		LAYERS: [
			{"shape": SHAPE_CRYSTAL, "facets": 4, "length": 0.42, "radius": 0.07, "root": 0.25, "offset": Vector3(0, 0.78, -0.05), "tilt": Vector3(-0.15, 0, 0), "root_tone": "trim"},
			{"shape": SHAPE_CRYSTAL, "facets": 4, "length": 0.34, "radius": 0.06, "root": 0.25, "offset": Vector3(-0.17, 0.74, -0.04), "tilt": Vector3(-0.15, 0, 0.55), "root_tone": "trim"},
			{"shape": SHAPE_CRYSTAL, "facets": 4, "length": 0.28, "radius": 0.06, "root": 0.25, "offset": Vector3(0.17, 0.74, -0.04), "tilt": Vector3(-0.15, 0, -0.55), "root_tone": "trim"},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.5, "size": Vector3(0, 0.04, 0), "lip": 0.0, "offset": Vector3(0, 0.42, 0), "tone": "trim"},
		],
	}},
	"shardweaver_body": {"palette": SHARDWEAVER, PART_BODY: {
		# an open wool coat over a dark under-robe, the front panels two lengths (left longer)
		# edged in cream, a rope belt, a pouch on the right hip and a satchel on the left hung
		# from a rope strap across the chest
		"shape": SHAPE_UNDER_ROBE, "bands": 0, "panel_left": 0.55, "panel_right": 0.38, "panel_edge": 0.03,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.4, "size": Vector3(0, 0.05, 0), "lip": 0.0, "offset": Vector3(0, -0.2, 0.05), "tone": "accent"},
			{"shape": SHAPE_POUCH, "size": Vector3(0.14, 0.14, 0.08), "offset": Vector3(0.36, -0.3, -0.12), "tilt": Vector3(0, 0.3, 0), "tone": "accent", "flap_tone": "trim"},
			{"shape": SHAPE_POUCH, "size": Vector3(0.2, 0.18, 0.1), "offset": Vector3(-0.4, -0.34, 0.0), "tilt": Vector3(0, -0.4, 0), "tone": "dark", "flap_tone": "accent"},
			{"shape": SHAPE_SASH, "roll": -0.6, "width": 0.06, "tone": "accent", "edge_tone": SHARDWEAVER_ROPE_DARK},
		],
	}},
	"rimecaller_body": {"palette": RIMECALLER, PART_BODY: {
		# an indigo under-robe with two frost bands and a frost hem under an open indigo coat
		# edged in frost, frost shoulder plates (the left the larger) over dark under-plates, a
		# frost collar behind the neck, a book pouch at the left hip, an unlit vial hanging at
		# the right and a frost belt
		"shape": SHAPE_UNDER_ROBE, "bands": 3, "band_from": -0.85, "band_step": 0.14, "panel_left": 0.5, "panel_right": 0.4, "panel_edge": 0.025,
		LAYERS: [
			{"shape": SHAPE_STACKED_PLATES, "plates_left": 2, "plates_right": 2, "size_left": Vector3(0.3, 0.07, 0.34), "size_right": Vector3(0.26, 0.07, 0.3), "x": 0.4, "y": 0.17, "tone": "trim", "under_tone": "dark", "trim_tone": RIMECALLER_FROST_LIT},
			{"shape": SHAPE_COLLAR, "kind": COLLAR_HIGH, "width": 0.5, "height": 0.3, "offset": Vector3(0, 0.22, 0.3), "tone": "trim", "back_tone": "dark", "edge_tone": RIMECALLER_FROST_LIT},
			{"shape": SHAPE_POUCH, "size": Vector3(0.16, 0.2, 0.07), "offset": Vector3(-0.4, -0.32, -0.06), "tilt": Vector3(0, -0.35, 0), "tone": "accent", "flap_tone": "trim"},
			{"shape": SHAPE_CRYSTAL, "facets": 4, "length": 0.14, "radius": 0.035, "root": 0.35, "offset": Vector3(0.38, -0.24, -0.16), "tilt": Vector3(PI, 0, 0), "root_tone": RIMECALLER_ASH_LIT},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.4, "size": Vector3(0, 0.04, 0), "lip": 0.0, "offset": Vector3(0, -0.22, 0.05), "tone": "trim"},
		],
	}},
	"glacier_warden_body": {"palette": GLACIER_WARDEN, PART_BODY: {
		# a teal under-robe with a silver hem and an ice glyph band under an open teal coat
		# edged in silver, a silver chest plate with an ice glyph, silver upper plates stepped
		# over dark-teal lower plates with a third plate on the left, a tall silver collar and a
		# scroll case slung at the right hip
		"shape": SHAPE_UNDER_ROBE, "bands": 1, "band_from": -0.85, "band_height": 0.06, "panel_left": 0.58, "panel_right": 0.44, "panel_edge": 0.03,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.52, "size": Vector3(0, 0.035, 0), "lip": 0.0, "offset": Vector3(0, -0.62, 0), "tone": GLACIER_WARDEN["glow"]},
			{"shape": SHAPE_FIN, "size": Vector3(0.3, 0.24, 0.03), "offset": Vector3(0, -0.26, -0.465), "tilt": Vector3(0.19, 0, 0), "edge": 0.02, "tone": "trim", "edge_tone": GLACIER_WARDEN_LIT},
			{"shape": SHAPE_SEAM, "size": Vector3(0.03, 0.16, 0.02), "offset": Vector3(0, -0.137, -0.472), "tilt": Vector3(0.19, 0, 0), "tone": GLACIER_WARDEN["glow"]},
			{"shape": SHAPE_SEAM, "size": Vector3(0.12, 0.025, 0.02), "offset": Vector3(0, -0.087, -0.462), "tilt": Vector3(0.19, 0, 0), "tone": GLACIER_WARDEN["glow"]},
			{"shape": SHAPE_STACKED_PLATES, "plates_left": 3, "plates_right": 2, "size_left": Vector3(0.32, 0.08, 0.36), "size_right": Vector3(0.28, 0.08, 0.32), "x": 0.42, "y": 0.18, "tilt": 0.3, "step": Vector3(0.05, -0.08, 0), "tone": "trim", "under_tone": "dark", "trim_tone": GLACIER_WARDEN_LIT},
			{"shape": SHAPE_COLLAR, "kind": COLLAR_HIGH, "width": 0.56, "height": 0.42, "offset": Vector3(0, 0.22, 0.3), "tone": "trim", "back_tone": "dark", "edge_tone": GLACIER_WARDEN_LIT},
			{"shape": SHAPE_POUCH, "round": true, "size": Vector3(0.09, 0.3, 0.09), "offset": Vector3(0.42, -0.36, -0.02), "tilt": Vector3(1.3, 0, 0), "tone": "accent", "flap_tone": "trim"},
		],
	}},
	"shardweaver_legs": {"palette": SHARDWEAVER, PART_HIPS: {
		# wrapped wool leggings with a cream band at the hem
		"shape": SHAPE_FUR_LEGGINGS,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.42, "size": Vector3(0, 0.04, 0), "lip": 0.0, "offset": Vector3(0, -0.22, 0), "tone": "trim"},
		],
	}, PART_SHIN: {
		# a wool shin wrap under a cream puttee
		"shape": SHAPE_FUR_BAND, "band_tone": "trim", "band_radius": 0.19, "band_height": 0.1, "band_y": -0.03,
	}},
	"rimecaller_legs": {"palette": RIMECALLER, PART_HIPS: {
		# indigo leggings with a frost band at the hem
		"shape": SHAPE_FUR_LEGGINGS,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.42, "size": Vector3(0, 0.04, 0), "lip": 0.0, "offset": Vector3(0, -0.22, 0), "tone": "trim"},
		],
	}, PART_SHIN: {
		# an indigo shin wrap with a frost band at the knee and another at the ankle
		"shape": SHAPE_FUR_BAND, "band_tone": "trim", "band_height": 0.05,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.165, "size": Vector3(0, 0.035, 0), "lip": 0.0, "offset": Vector3(0, -0.18, 0), "tone": "trim"},
		],
	}},
	"glacier_warden_legs": {"palette": GLACIER_WARDEN, PART_HIPS: {
		# teal leggings with a silver band at the hem
		"shape": SHAPE_FUR_LEGGINGS,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.42, "size": Vector3(0, 0.04, 0), "lip": 0.0, "offset": Vector3(0, -0.22, 0), "tone": "trim"},
		],
	}, PART_SHIN: {
		# a silver greave with a teal band at the knee and a lit silver knee plate
		"shape": SHAPE_FUR_BAND, "tone": "trim", "band_tone": "base", "band_radius": 0.175, "band_height": 0.05, "band_y": -0.02,
		LAYERS: [
			{"shape": SHAPE_FIN, "size": Vector3(0.12, 0.08, 0.03), "offset": Vector3(0, -0.04, -0.17), "tilt": Vector3(-0.2, 0, 0), "tone": "trim", "edge_tone": GLACIER_WARDEN_LIT},
		],
	}},
	# a pine haft with a rope grip band and one raw four-facet shard lashed on with rope, no
	# collar, the shard glowing faintly
	"shardweaver_staff": {"palette": SHARDWEAVER, PART_WEAPON: {"shape": SHAPE_MAGE_STAFF, "head": HEAD_LASHED, "collar": 0.0, "tone": SHARDWEAVER_PINE, "grip_tone": "accent", "lash_tone": "accent", "root_tone": SHARDWEAVER_ROPE_DARK}},
	# an ash shaft with a frost collar under two fork arms leaning apart, a prism floating in
	# the gap
	"rimecaller_staff": {"palette": RIMECALLER, PART_WEAPON: {"shape": SHAPE_MAGE_STAFF, "head": HEAD_FORKED, "tone": "accent", "fork_tone": "accent", "collar_tone": "trim", "grip_tone": "dark", "root_tone": "trim"}},
	# an iron shaft with a silver collar and a silver hoop on top holding a large prism, a small
	# one floating above the hoop, both shining ice
	"glacier_warden_staff": {"palette": GLACIER_WARDEN, PART_WEAPON: {"shape": SHAPE_MAGE_STAFF, "head": HEAD_RING, "tone": "accent", "ring_tone": "trim", "collar_tone": "trim", "grip_tone": GLACIER_WARDEN_IRON_LIT, "root_tone": "trim"}},
	# a short indigo cloak with a frost hem, the left half the longer
	"rimecaller_cape": {"palette": RIMECALLER, PART_CAPE: {"shape": SHAPE_CLOAK, "width": 0.56, "length_left": 0.5, "length_right": 0.44, "hem": 0.05, "tone": "base", "hem_tone": "trim"}},
	# a long teal cloak with a silver hem, the left half the longer
	"glacier_warden_cape": {"palette": GLACIER_WARDEN, PART_CAPE: {"shape": SHAPE_CLOAK, "width": 0.62, "length_left": 0.98, "length_right": 0.92, "hem": 0.06, "tone": "base", "hem_tone": "trim"}},
	# The magic top sets (#167): the best-of-the-best magic line, each with its own staff head.
	"hoarfrost_sovereign_helm": {"palette": HOARFROST_SOVEREIGN, PART_HEAD: {
		# a bare head under a star crown: a steel-blue circlet round the brow (the barbarian's
		# own hair shows) with five tall ice shards fanned up and out from its front half, the
		# centre and outer ones the taller, all shining frost, a small frost gem at the brow,
		# and a steel ear-guard hanging from the circlet each side
		"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.47, "size": Vector3(0, 0.05, 0), "lip": 0.0, "offset": Vector3(0, 0.44, 0), "tone": "trim", "shadow_tone": HOARFROST_SOVEREIGN_STEEL_LIT,
		LAYERS: [
			{"shape": SHAPE_SHARD_CROWN, "count": 5, "radius": 0.4, "arc": PI * 0.95, "length": 0.44, "short": 0.7, "shard": 0.075, "lean": 0.42, "tip": 0.65, "offset": Vector3(0, 0.58, 0), "tone": "trim", "glow": 1.6},
			{"shape": SHAPE_CRYSTAL, "facets": 4, "length": 0.14, "radius": 0.045, "root": 0.3, "offset": Vector3(0, 0.47, -0.44), "tilt": Vector3(-1.1, 0, 0), "glow": 1.6, "root_tone": "trim"},
			{"shape": SHAPE_FIN, "size": Vector3(0.05, 0.2, 0.16), "offset": Vector3(-0.5, 0.24, 0.02), "tone": "trim", "edge_tone": HOARFROST_SOVEREIGN_STEEL_LIT},
			{"shape": SHAPE_FIN, "size": Vector3(0.05, 0.2, 0.16), "offset": Vector3(0.5, 0.24, 0.02), "tone": "trim", "edge_tone": HOARFROST_SOVEREIGN_STEEL_LIT},
		],
	}},
	"hearthfire_magus_helm": {"palette": HEARTHFIRE_MAGUS, PART_HEAD: {
		# a peaked charcoal hood with a brass hoop at the face and a soot drape, under a brass
		# halo standing up behind the head above the shoulders, its ring glowing ember with three
		# brass flame fins on its rim
		"shape": SHAPE_PEAKED_HOOD, "hoop_tone": "trim", "peak_length": 0.5,
		LAYERS: [
			{"shape": SHAPE_COLLAR, "kind": COLLAR_HOOP, "hoop_inner": 0.32, "hoop_outer": 0.42, "offset": Vector3(0, 0.3, 0.52), "tilt": 0.2, "teeth": 3, "tooth": 0.16, "tone": "trim", "edge_tone": "trim", "glow": 1.0},
		],
	}},
	"aurora_shaman_helm": {"palette": AURORA_SHAMAN, PART_HEAD: {
		# a bare head under a bone circlet (the barbarian's own hair shows) with two antlers
		# rising from it, the left the longer with two tines to the right's one, every tip
		# shining aurora green, and one bone feather laid out flat off the circlet's right
		"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.47, "size": Vector3(0, 0.045, 0), "lip": 0.0, "offset": Vector3(0, 0.44, 0), "tone": "trim", "shadow_tone": AURORA_SHAMAN_BONE_DARK,
		LAYERS: [
			{"shape": SHAPE_ANTLERS, "length_left": 0.65, "length_right": 0.55, "radius": 0.04, "x": 0.3, "spread": 0.6, "tines_left": 2, "tines_right": 1, "offset": Vector3(0, 0.6, 0.0), "tone": "accent", "glow": 1.4},
			{"shape": SHAPE_PLUMES, "count": 1, "length": 0.42, "width": 0.08, "offset": Vector3(0.42, 0.46, 0), "tilt": Vector3(0, 0, -PI * 0.55), "tone": "trim", "quill_tone": "accent", "tip_tone": "accent"},
		],
	}},
	"ruinwarden_mage_helm": {"palette": RUINWARDEN_MAGE, PART_HEAD: {
		# a peaked dusk hood with a pillar-grey hoop and a deep drape, over a ruin-stone mask
		# across the face with two rune-lit eye slits and a dark chin notch, and one small rune
		# prism at the brow leaning out over the mask
		"shape": SHAPE_PEAKED_HOOD, "hoop_tone": "accent", "peak_length": 0.45, "peak_width": 0.3,
		LAYERS: [
			{"shape": SHAPE_FIN, "size": Vector3(0.4, 0.44, 0.1), "offset": Vector3(0, 0.02, -0.5), "edge": 0.03, "tone": "trim", "edge_tone": RUINWARDEN_MAGE_STONE_LIT},
			{"shape": SHAPE_SEAM, "size": Vector3(0.12, 0.035, 0.02), "offset": Vector3(-0.1, 0.3, -0.56), "glow": 1.6},
			{"shape": SHAPE_SEAM, "size": Vector3(0.12, 0.035, 0.02), "offset": Vector3(0.1, 0.3, -0.56), "glow": 1.6},
			{"shape": SHAPE_SEAM, "size": Vector3(0.1, 0.05, 0.02), "offset": Vector3(0, 0.08, -0.56), "tone": "dark", "shadow_tone": "dark"},
			{"shape": SHAPE_CRYSTAL, "facets": 4, "length": 0.16, "radius": 0.045, "root": 0.3, "offset": Vector3(0, 0.52, -0.44), "tilt": Vector3(-0.9, 0, 0), "glow": 1.2, "root_tone": "trim"},
		],
	}},
	"hoarfrost_sovereign_body": {"palette": HOARFROST_SOVEREIGN, PART_BODY: {
		# an ice-shade under-robe with three steel-blue bands under an open white coat edged in
		# steel blue, white shoulder plates stepped over steel-blue under-plates, a jagged pale
		# ice collar behind the neck, a frost shard cluster on each shoulder (the left the fuller),
		# a steel chest plate with a frost gem, a steel belt and three unlit icicles under it
		"shape": SHAPE_UNDER_ROBE, "bands": 3, "band_from": -0.85, "band_step": 0.14, "panel_left": 0.55, "panel_right": 0.42, "panel_edge": 0.03,
		LAYERS: [
			{"shape": SHAPE_STACKED_PLATES, "plates_left": 2, "plates_right": 2, "size_left": Vector3(0.3, 0.07, 0.34), "size_right": Vector3(0.28, 0.07, 0.32), "x": 0.4, "y": 0.17, "tone": "base", "under_tone": "trim", "trim_tone": HOARFROST_SOVEREIGN_LIT},
			{"shape": SHAPE_COLLAR, "kind": COLLAR_JAGGED, "width": 0.6, "height": 0.36, "teeth": 5, "tooth": 0.16, "offset": Vector3(0, 0.22, 0.3), "tone": "accent", "back_tone": "trim", "edge_tone": HOARFROST_SOVEREIGN_LIT},
			{"shape": SHAPE_SHARD_CROWN, "count": 2, "arc": PI * 0.6, "radius": 0.06, "lean": 0.5, "length": 0.3, "shard": 0.06, "offset": Vector3(-0.44, 0.24, 0), "tilt": Vector3(0, 0, 0.3), "tone": "accent", "glow": 1.2},
			{"shape": SHAPE_SHARD_CROWN, "count": 1, "arc": PI * 0.6, "radius": 0.06, "lean": 0.5, "length": 0.24, "shard": 0.06, "offset": Vector3(0.44, 0.22, 0), "tilt": Vector3(0, 0, -0.3), "tone": "accent", "glow": 1.2},
			{"shape": SHAPE_FIN, "size": Vector3(0.22, 0.22, 0.05), "offset": Vector3(0, -0.12, -0.37), "tilt": Vector3(0.19, 0, 0), "tone": "trim", "edge_tone": HOARFROST_SOVEREIGN_STEEL_LIT},
			{"shape": SHAPE_CRYSTAL, "facets": 6, "length": 0.16, "radius": 0.07, "root": 0.3, "offset": Vector3(0, 0.0, -0.38), "tilt": Vector3(-1.2, 0, 0), "glow": 1.6, "root_tone": "trim"},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.41, "size": Vector3(0, 0.05, 0), "lip": 0.0, "offset": Vector3(0, -0.3, 0.05), "tone": "trim"},
			{"shape": SHAPE_CRYSTAL, "facets": 4, "length": 0.16, "radius": 0.04, "root": 0.3, "offset": Vector3(-0.2, -0.33, -0.36), "tilt": Vector3(PI, 0, 0), "glow": 1.0, "root_tone": "trim"},
			{"shape": SHAPE_CRYSTAL, "facets": 4, "length": 0.2, "radius": 0.04, "root": 0.3, "offset": Vector3(0, -0.35, -0.4), "tilt": Vector3(PI, 0, 0), "glow": 1.0, "root_tone": "trim"},
			{"shape": SHAPE_CRYSTAL, "facets": 4, "length": 0.16, "radius": 0.04, "root": 0.3, "offset": Vector3(0.2, -0.33, -0.36), "tilt": Vector3(PI, 0, 0), "glow": 1.0, "root_tone": "trim"},
		],
	}},
	"hearthfire_magus_body": {"palette": HEARTHFIRE_MAGUS, PART_BODY: {
		# a soot under-robe with three glowing ember bands under an open charcoal coat with
		# ember-lit seams, brass shoulder plates (the right the fuller) over soot under-plates
		# with an ember line, a high charcoal collar, a brass chest plate with a flame gem, a
		# brass belt and a dark lantern at the left hip with a lit window
		"shape": SHAPE_UNDER_ROBE, "bands": 3, "band_from": -0.85, "band_step": 0.14, "band_height": 0.03, "panel_left": 0.52, "panel_right": 0.4, "panel_edge": 0.02, "glow": 1.0,
		LAYERS: [
			{"shape": SHAPE_STACKED_PLATES, "plates_left": 1, "plates_right": 2, "size_left": Vector3(0.28, 0.07, 0.32), "size_right": Vector3(0.3, 0.07, 0.34), "x": 0.4, "y": 0.17, "tone": "trim", "under_tone": "dark", "trim_tone": "trim", "glow": 1.0},
			{"shape": SHAPE_COLLAR, "kind": COLLAR_HIGH, "width": 0.52, "height": 0.3, "offset": Vector3(0, 0.22, 0.3), "tone": "base", "back_tone": "dark", "edge_tone": HEARTHFIRE_MAGUS_LIT},
			{"shape": SHAPE_FIN, "size": Vector3(0.24, 0.22, 0.05), "offset": Vector3(0, -0.12, -0.37), "tilt": Vector3(0.19, 0, 0), "tone": "trim", "edge_tone": HEARTHFIRE_MAGUS_BRASS_LIT},
			{"shape": SHAPE_CRYSTAL, "facets": 4, "length": 0.14, "radius": 0.06, "root": 0.3, "offset": Vector3(0, 0.0, -0.38), "tilt": Vector3(-1.2, 0, 0), "glow": 1.4, "root_tone": "trim"},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.41, "size": Vector3(0, 0.05, 0), "lip": 0.0, "offset": Vector3(0, -0.3, 0.05), "tone": "trim"},
			{"shape": SHAPE_POUCH, "size": Vector3(0.12, 0.16, 0.1), "offset": Vector3(-0.42, -0.4, -0.04), "tilt": Vector3(0, -0.4, 0), "tone": "dark", "flap_tone": "trim"},
			{"shape": SHAPE_SEAM, "size": Vector3(0.06, 0.08, 0.02), "offset": Vector3(-0.44, -0.38, -0.1), "tilt": Vector3(0, -0.4, 0), "glow": 1.2},
		],
	}},
	"aurora_shaman_body": {"palette": AURORA_SHAMAN, PART_BODY: {
		# a violet-shade under-robe with an aurora-lit hem under an open violet coat edged in
		# bone, a bone mantle round the shoulders with four bone feathers hanging from each
		# (the left the longer), a bead belt of antler studs on an antler band and one bone
		# charm hanging at the left of the belt
		"shape": SHAPE_UNDER_ROBE, "bands": 0, "panel_left": 0.55, "panel_right": 0.42, "panel_edge": 0.03,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.52, "size": Vector3(0, 0.04, 0), "lip": 0.0, "offset": Vector3(0, -0.62, 0), "glow": 1.0},
			{"shape": SHAPE_RUFF, "inner": 0.26, "outer": 0.54, "y": 0.2, "tone": "trim", "trim_tone": AURORA_SHAMAN_BONE_LIT},
			{"shape": SHAPE_PLUMES, "count": 4, "length": 0.44, "width": 0.09, "arc": 0.9, "offset": Vector3(-0.4, 0.16, 0), "tilt": Vector3(0, 0, PI - 0.5), "tone": "trim", "quill_tone": AURORA_SHAMAN_BONE_DARK, "tip_tone": "accent"},
			{"shape": SHAPE_PLUMES, "count": 4, "length": 0.34, "width": 0.09, "arc": 0.9, "offset": Vector3(0.4, 0.16, 0), "tilt": Vector3(0, 0, -(PI - 0.5)), "tone": "trim", "quill_tone": AURORA_SHAMAN_BONE_DARK, "tip_tone": "accent"},
			{"shape": SHAPE_STUDS, "count": 5, "arc": PI * 0.8, "radius": 0.42, "y": -0.3, "band_tone": "accent", "stud_tone": "trim"},
			{"shape": SHAPE_FIN, "size": Vector3(0.06, 0.14, 0.04), "offset": Vector3(-0.28, -0.34, -0.3), "tilt": Vector3(PI, 0, 0), "tone": "trim", "edge_tone": AURORA_SHAMAN_BONE_DARK},
		],
	}},
	"ruinwarden_mage_body": {"palette": RUINWARDEN_MAGE, PART_BODY: {
		# a deep-dusk under-robe with a rune-lit hem under an open dusk coat edged in ruin stone,
		# ruin-stone shoulder plates (the right the fuller) over dark stone under-plates with a
		# rune line, a jagged stone back-plate behind the neck, a stone chest plate with a rune
		# gem, two stone tassets at the hips, a dark glyph plate hanging at the front with a lit
		# glyph, a stone belt with a dark buckle and a lit stud, and two rune tablets at the left
		"shape": SHAPE_UNDER_ROBE, "bands": 0, "panel_left": 0.55, "panel_right": 0.42, "panel_edge": 0.03,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.52, "size": Vector3(0, 0.035, 0), "lip": 0.0, "offset": Vector3(0, -0.62, 0), "glow": 1.0},
			{"shape": SHAPE_STACKED_PLATES, "plates_left": 2, "plates_right": 3, "size_left": Vector3(0.3, 0.1, 0.34), "size_right": Vector3(0.34, 0.11, 0.38), "x": 0.4, "y": 0.17, "tone": "trim", "under_tone": RUINWARDEN_MAGE_STONE_DARK, "trim_tone": "trim", "glow": 1.0},
			{"shape": SHAPE_COLLAR, "kind": COLLAR_JAGGED, "width": 0.66, "height": 0.4, "teeth": 4, "tooth": 0.14, "offset": Vector3(0, 0.22, 0.3), "tone": "trim", "back_tone": "dark", "edge_tone": RUINWARDEN_MAGE_STONE_LIT},
			{"shape": SHAPE_FIN, "size": Vector3(0.26, 0.28, 0.07), "offset": Vector3(0, -0.16, -0.37), "tilt": Vector3(0.19, 0, 0), "tone": "trim", "edge_tone": RUINWARDEN_MAGE_STONE_LIT},
			{"shape": SHAPE_CRYSTAL, "facets": 4, "length": 0.16, "radius": 0.06, "root": 0.3, "offset": Vector3(0, 0.0, -0.4), "tilt": Vector3(-1.2, 0, 0), "glow": 1.6, "root_tone": "trim"},
			{"shape": SHAPE_TASSETS, "count": 2, "arc": PI * 0.5, "y": -0.48, "radius": 0.5, "size": Vector3(0.18, 0.28, 0.05), "belt": false, "tone": "trim", "edge_tone": RUINWARDEN_MAGE_STONE_LIT, "shadow_tone": "dark"},
			{"shape": SHAPE_FIN, "size": Vector3(0.12, 0.2, 0.04), "offset": Vector3(0, -0.72, -0.5), "tilt": Vector3(0.15, 0, 0), "tone": "dark", "edge_tone": "trim"},
			{"shape": SHAPE_SEAM, "size": Vector3(0.03, 0.1, 0.02), "offset": Vector3(0, -0.62, -0.53), "tilt": Vector3(0.15, 0, 0), "glow": 1.2},
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.41, "size": Vector3(0, 0.05, 0), "lip": 0.0, "offset": Vector3(0, -0.3, 0.05), "tone": "trim"},
			{"shape": SHAPE_FIN, "size": Vector3(0.12, 0.1, 0.03), "offset": Vector3(0, -0.35, -0.42), "tone": RUINWARDEN_MAGE_STONE_DARK, "edge_tone": "trim"},
			{"shape": SHAPE_STUDS, "count": 1, "band": false, "radius": 0.44, "y": -0.3, "stud": 0.025, "glow": 1.0},
			{"shape": SHAPE_FIN, "size": Vector3(0.08, 0.14, 0.03), "offset": Vector3(-0.3, -0.32, -0.3), "tilt": Vector3(PI, 0, 0.2), "tone": "trim", "glow": 0.8},
			{"shape": SHAPE_FIN, "size": Vector3(0.08, 0.14, 0.03), "offset": Vector3(-0.4, -0.34, -0.24), "tilt": Vector3(PI, 0, 0.2), "tone": "trim", "glow": 0.8},
		],
	}},
	"hoarfrost_sovereign_legs": {"palette": HOARFROST_SOVEREIGN, PART_HIPS: {
		# a long pale ice skirt with a steel-blue hem
		"shape": SHAPE_KILT, "height": 0.46, "y": -0.2, "bottom_radius": 0.5, "tone": "accent",
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.5, "size": Vector3(0, 0.04, 0), "lip": 0.0, "offset": Vector3(0, -0.42, 0), "tone": "trim"},
		],
	}, PART_SHIN: {
		# a pale ice shin wrap under a steel-blue band, with one frosted (unlit) shard on the shin
		"shape": SHAPE_FUR_BAND, "tone": "accent", "band_tone": "trim", "band_height": 0.05, "band_y": -0.02,
		LAYERS: [
			{"shape": SHAPE_CRYSTAL, "facets": 4, "length": 0.14, "radius": 0.05, "root": 0.3, "offset": Vector3(0, -0.2, -0.17), "tilt": Vector3(-0.2, 0, 0), "glow": 0.0, "root_tone": "trim"},
		],
	}},
	"hearthfire_magus_legs": {"palette": HEARTHFIRE_MAGUS, PART_HIPS: {
		# charcoal leggings with a brass band at the hem
		"shape": SHAPE_FUR_LEGGINGS,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.42, "size": Vector3(0, 0.04, 0), "lip": 0.0, "offset": Vector3(0, -0.22, 0), "tone": "trim"},
		],
	}, PART_SHIN: {
		# a charcoal shin wrap under a brass band
		"shape": SHAPE_FUR_BAND, "band_tone": "trim", "band_height": 0.06,
	}},
	"aurora_shaman_legs": {"palette": AURORA_SHAMAN, PART_HIPS: {
		# violet leggings with a bone band at the hem
		"shape": SHAPE_FUR_LEGGINGS,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.42, "size": Vector3(0, 0.04, 0), "lip": 0.0, "offset": Vector3(0, -0.22, 0), "tone": "trim"},
		],
	}, PART_SHIN: {
		# a violet shin wrap under a bone puttee
		"shape": SHAPE_FUR_BAND, "band_tone": "trim", "band_radius": 0.2, "band_height": 0.1, "band_y": -0.03,
	}},
	"ruinwarden_mage_legs": {"palette": RUINWARDEN_MAGE, PART_HIPS: {
		# a deep-dusk kilt with a ruin-stone hem over a dark stone shadow line
		"shape": SHAPE_KILT,
		LAYERS: [
			{"shape": SHAPE_EDGE_TRIM, "round": true, "radius": 0.46, "size": Vector3(0, 0.04, 0), "lip": 0.02, "offset": Vector3(0, -0.19, 0), "tone": "trim", "shadow_tone": RUINWARDEN_MAGE_STONE_DARK},
		],
	}, PART_SHIN: {
		# a deep-dusk shin wrap under a stone band, with a square ruin-stone greave block down the
		# shin and a dark stone knee block over it
		"shape": SHAPE_FUR_BAND, "tone": "dark", "band_tone": "trim",
		LAYERS: [
			{"shape": SHAPE_FIN, "size": Vector3(0.2, 0.3, 0.14), "offset": Vector3(0, -0.26, -0.06), "tone": "trim", "edge_tone": RUINWARDEN_MAGE_STONE_LIT},
			{"shape": SHAPE_FIN, "size": Vector3(0.16, 0.1, 0.12), "offset": Vector3(0, 0.0, -0.08), "tone": RUINWARDEN_MAGE_STONE_DARK, "edge_tone": "trim"},
		],
	}},
	# a short steel-blue shaft with a pale ice collar and a dark grip under one great frost shard
	# on its top with two small shards leaning out from the shard's root
	"hoarfrost_sovereign_staff": {"palette": HOARFROST_SOVEREIGN, PART_WEAPON: {"shape": SHAPE_MAGE_STAFF, "head": HEAD_SHARD, "length": 0.95, "foot": 0.35, "tone": "trim", "collar_tone": "accent", "grip_tone": "dark", "prism_length": 0.8, "prism_radius": 0.09, "small_length": 0.22, "small_radius": 0.045, "side_spread": 0.5, "root_tone": "trim", "glow": 1.8}},
	# a soot shaft with a brass collar and grip under a brass brazier cup, a flame prism
	# standing in it between two small flames leaning apart
	"hearthfire_magus_staff": {"palette": HEARTHFIRE_MAGUS, PART_WEAPON: {"shape": SHAPE_MAGE_STAFF, "head": HEAD_BRAZIER, "tone": "dark", "collar_tone": "trim", "grip_tone": "trim", "cup": 0.18, "cup_radius": 0.16, "cup_tone": "trim", "prism_length": 0.3, "prism_radius": 0.08, "small_length": 0.18, "small_radius": 0.05, "side_spread": 0.45, "root_tone": "trim", "glow": 2.0}},
	# a bone shaft with an antler grip and no collar under two bone tines curving in over an
	# aurora prism floating between them, a bone feather hanging from the right tine's root and
	# three bone beads strung from the left's
	"aurora_shaman_staff": {"palette": AURORA_SHAMAN, PART_WEAPON: {"shape": SHAPE_MAGE_STAFF, "head": HEAD_ANTLER, "tone": "trim", "collar": 0.0, "grip_tone": "accent", "fork_length": 0.36, "fork_spread": 0.5, "fork_radius": 0.024, "tine_bend": 0.8, "fork_tone": "trim", "rise": 0.1, "prism_length": 0.28, "prism_radius": 0.07, "feather": 0.24, "feather_tone": "trim", "beads": 3, "bead": 0.02, "bead_tone": "trim", "root_tone": "accent", "glow": 1.6}},
	# a square pillar-stone shaft with a carved stone band and no collar, its top broken into
	# five jagged points with a rune prism rising from the break
	"ruinwarden_mage_staff": {"palette": RUINWARDEN_MAGE, PART_WEAPON: {"shape": SHAPE_MAGE_STAFF, "head": HEAD_PILLAR, "segments": 4, "radius": 0.05, "tone": "accent", "collar": 0.0, "grip": 0.08, "grip_y": 0.5, "grip_tone": "trim", "teeth": 5, "tooth": 0.12, "prism_length": 0.26, "prism_radius": 0.07, "root_tone": "trim", "glow": 1.6}},
	# a long white forked cloak with a steel-blue hem, the left half the longer
	"hoarfrost_sovereign_cape": {"palette": HOARFROST_SOVEREIGN, PART_CAPE: {"shape": SHAPE_CLOAK, "outline": OUTLINE_FORKED, "width": 0.62, "length_left": 1.0, "length_right": 0.92, "hem": 0.06, "tone": "base", "hem_tone": "trim"}},
	# a soot cloak edged in brass with a glowing ember hem, the left half the longer
	"hearthfire_magus_cape": {"palette": HEARTHFIRE_MAGUS, PART_CAPE: {"shape": SHAPE_CLOAK, "width": 0.6, "length_left": 0.92, "length_right": 0.86, "hem": 0.06, "tone": "dark", "lining": 0.02, "lining_tone": "trim", "glow": 1.0}},
	# a long violet cloak with a bone hem and an unlit aurora-green lining showing round its
	# edges, the left half the longer
	"aurora_shaman_cape": {"palette": AURORA_SHAMAN, PART_CAPE: {"shape": SHAPE_CLOAK, "width": 0.6, "length_left": 1.05, "length_right": 0.98, "hem": 0.05, "tone": "base", "hem_tone": "trim", "lining": 0.03, "lining_tone": AURORA_SHAMAN["glow"]}},
	# a narrow deep-dusk banner torn into three ruin-stone teeth at its hem, the left half the
	# longer
	"ruinwarden_mage_cape": {"palette": RUINWARDEN_MAGE, PART_CAPE: {"shape": SHAPE_CLOAK, "outline": OUTLINE_TORN, "width": 0.44, "length_left": 1.0, "length_right": 0.9, "teeth": 3, "tooth": 0.14, "hem": 0.05, "tone": "dark", "tooth_tone": "trim", "hem_tone": "trim"}},
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
