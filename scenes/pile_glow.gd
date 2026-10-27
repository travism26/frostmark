## A rare drop's glow on the ground, drawn over its pile in its band's colour (RarityLook): a
## soft pool of light on the snow and a halo around the crate for a rare, super rare or ultra
## rare item, and for super rare and ultra rare a tall light column, seen from further off. It
## is a child of the pile's node, so it lasts as long as the pile is drawn and goes with it,
## picked up or taken by the snow. Unshaded and additive, with no light, so the web renderer
## copes. An uncommon or band-less pile has none.
class_name PileGlow
extends Node3D

const POOL_RADIUS := 0.85
const POOL_ALPHA := 0.7
const HALO_SIZE := 1.1
const HALO_HEIGHT := 0.2  # the crate's middle
const HALO_ALPHA := 0.55
const COLUMN_WIDTH := 0.55
const COLUMN_HEIGHT := 9.0
const COLUMN_ALPHA := 0.6
const LIFT := 0.03  # above the snow, clear of z-fighting

## The bands tall enough to send up a column.
const COLUMN_BANDS: Array[String] = [ItemTable.RARITY_SUPER_RARE, ItemTable.RARITY_ULTRA_RARE]

static var _disc_texture: Texture2D
static var _beam_texture: Texture2D

var colour: Color
var column: MeshInstance3D  # null for a band with no column


## The glow for a pile of an item in rarity band `band`, or null when the band shows none.
static func of_band(band: String) -> PileGlow:
	var tint: Variant = RarityLook.colour(band)
	if tint == null:
		return null
	var glow := PileGlow.new()
	glow.name = "pile_glow"
	glow.colour = tint
	var pool := _quad(_disc_tex(), Color(tint, POOL_ALPHA), BaseMaterial3D.BILLBOARD_DISABLED)
	(pool.mesh as QuadMesh).orientation = PlaneMesh.FACE_Y
	pool.scale = Vector3(POOL_RADIUS * 2.0, 1.0, POOL_RADIUS * 2.0)
	pool.position.y = LIFT
	glow.add_child(pool)
	var halo := _quad(_disc_tex(), Color(tint, HALO_ALPHA), BaseMaterial3D.BILLBOARD_ENABLED)
	halo.scale = Vector3(HALO_SIZE, HALO_SIZE, 1.0)
	halo.position.y = HALO_HEIGHT
	glow.add_child(halo)
	if COLUMN_BANDS.has(band):
		glow.column = _quad(_beam_tex(), Color(tint, COLUMN_ALPHA), BaseMaterial3D.BILLBOARD_FIXED_Y)
		glow.column.name = "column"
		glow.column.scale = Vector3(COLUMN_WIDTH, COLUMN_HEIGHT, 1.0)
		glow.column.position.y = COLUMN_HEIGHT * 0.5
		glow.add_child(glow.column)
	return glow


static func _quad(tex: Texture2D, tint: Color, billboard: BaseMaterial3D.BillboardMode) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = tex
	mat.albedo_color = tint
	mat.billboard_mode = billboard
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


## A soft disc, brightest at its heart, drawn once.
static func _disc_tex() -> Texture2D:
	if _disc_texture == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var r := Vector2((x + 0.5) / n * 2.0 - 1.0, (y + 0.5) / n * 2.0 - 1.0).length()
				var a := pow(clampf(1.0 - r, 0.0, 1.0), 1.6)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_disc_texture = ImageTexture.create_from_image(img)
	return _disc_texture


## An upright beam, soft at its sides, strongest at its foot and fading out at its top.
static func _beam_tex() -> Texture2D:
	if _beam_texture == null:
		var w := 32
		var h := 128
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			var up := 1.0 - (y + 0.5) / h  # 0 at the foot, 1 at the top
			var fade := pow(1.0 - up, 1.4)
			for x in w:
				var across := absf((x + 0.5) / w * 2.0 - 1.0)
				var side := pow(clampf(1.0 - across, 0.0, 1.0), 1.5)
				img.set_pixel(x, y, Color(1, 1, 1, side * fade))
		_beam_texture = ImageTexture.create_from_image(img)
	return _beam_texture
