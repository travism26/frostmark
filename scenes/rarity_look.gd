## The rarity bands' colours, the one place they are tuned: blue for rare, purple for super
## rare, gold for ultra rare. Uncommon and band-less items have none. Everything that shows
## rarity reads its colour here: the pack and stash slot tint, the tooltip name and the glow
## of a pile on the ground. Pure data, like GearLook: no nodes, no scene.
class_name RarityLook
extends RefCounted

const COLOURS := {
	ItemTable.RARITY_RARE: Color(0.33, 0.58, 1.0),
	ItemTable.RARITY_SUPER_RARE: Color(0.72, 0.42, 1.0),
	ItemTable.RARITY_ULTRA_RARE: Color(1.0, 0.78, 0.26),
}


## A band's colour, or null for uncommon, "" or anything unknown.
static func colour(band: String) -> Variant:
	return COLOURS.get(band)


## The colour of the band `kind` belongs to, or null when it shows no rarity.
static func of_item(kind: String) -> Variant:
	return colour(ItemTable.rarity(kind))
