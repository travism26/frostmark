## Where a click goes, like RuneScape's click cross: a cross on the ground at the point the
## simulation accepted for a plain move, or a ring under the object, loot pile or fire that
## was clicked, with its label pinned. Either holds until the character arrives or the player
## clicks again. A refused click flashes red where it landed, and a click on an enemy only
## pops a ring briefly, since the fight has its own ring and cue. One shows at a time.
## Presentation only: it reads the events the click drained and nothing reads it back.
class_name ClickMarker
extends Node3D

const SHOWING_NONE := ""
const SHOWING_GROUND := "ground"
const SHOWING_TARGET := "target"
const SHOWING_REJECTED := "rejected"

const CROSS_RADIUS := 0.4
## The ring sits this far outside the clicked thing's footprint.
const RING_MARGIN := 0.25
## The pop: the mark starts this much bigger and settles over POP_SECONDS.
const POP_SCALE := 1.6
const POP_SECONDS := 0.18
## A refused click, or the confirming pop on an enemy, fades out over this long.
const FLASH_SECONDS := 0.6
const LIFT := 0.05  # above the snow and the yard floor, clear of z-fighting
## The interface's ember accent for a click taken, its cold red for one refused.
const COLOR_OK := UiTheme.EMBER
const COLOR_REFUSED := UiTheme.BLOOD

static var _cross_texture: Texture2D
static var _ring_texture: Texture2D

## With reduced motion the mark appears at its size, with no pop.
var reduced_motion := false
var _cross: MeshInstance3D
var _ring: MeshInstance3D
var _showing := SHOWING_NONE
var _label: Object  # the clicked thing's Label3D, pinned while its ring shows; a picked-up pile frees it
var _radius := 0.0
var _age := 0.0
var _brief := false


func _init() -> void:
	name = "ClickMarker"
	_cross = _flat_quad(_cross_tex())
	_ring = _flat_quad(_ring_tex())
	add_child(_cross)
	add_child(_ring)
	_cross.visible = false
	_ring.visible = false


## What shows: SHOWING_NONE, SHOWING_GROUND, SHOWING_TARGET or SHOWING_REJECTED.
func showing() -> String:
	return _showing


## Whether the mark waits for the character to arrive, rather than fading on its own.
func held() -> bool:
	return _showing != SHOWING_NONE and not _brief


## Where the mark sits on the ground.
func point() -> Vector3:
	return _ring.position if _ring.visible else _cross.position


## The mark's size now, in metres across, pop included.
func size() -> float:
	return (_ring if _ring.visible else _cross).scale.x


## Marks a click from what it drained: `events` are the simulation's answer, `at` where the
## ray hit. With no `radius` it was a ground click and the cross goes on the `path_set`
## destination, which a click on a wall has snapped off it. With one, the ring of that radius
## goes round `at` (the centre of what was clicked) and `label` stays up; `brief` makes it a
## pop that fades, for an enemy. A refused click flashes red at `at` instead.
func mark(events: Array[Dictionary], at: Vector3, radius := 0.0, label: Label3D = null, brief := false) -> void:
	clear()
	var destination: Variant = null
	for e in events:
		if e["kind"] == SimVocab.EV_COMMAND_REJECTED:
			_show(_ring if radius > 0.0 else _cross, at, radius, COLOR_REFUSED, true)
			_showing = SHOWING_REJECTED
			return
		if e["kind"] == SimVocab.EV_PATH_SET and destination == null:
			destination = Vector3(e["to"][0], 0.0, e["to"][1])
	if radius > 0.0:
		_show(_ring, at, radius, COLOR_OK, brief)
		_showing = SHOWING_TARGET
		if label != null and not brief:
			_label = label
			label.set_meta("pinned", true)
			label.visible = true
	elif destination != null:
		_show(_cross, destination, 0.0, COLOR_OK, false)
		_showing = SHOWING_GROUND


## Takes the mark away and unpins the label it held up. Returns that label, so the hover
## can show it again if the mouse is still over it.
func clear() -> Label3D:
	var label: Label3D = _label if is_instance_valid(_label) else null
	if label != null:
		label.set_meta("pinned", false)
		label.visible = false
	_label = null
	_cross.visible = false
	_ring.visible = false
	_showing = SHOWING_NONE
	return label


func _process(delta: float) -> void:
	advance(delta)


## Plays the pop and the fade on by `delta` seconds; a fading mark goes once it has faded.
func advance(delta: float) -> void:
	if _showing == SHOWING_NONE:
		return
	_age += delta
	var mesh := _ring if _ring.visible else _cross
	_fit(mesh)
	if _brief:
		var t := clampf(1.0 - _age / FLASH_SECONDS, 0.0, 1.0)
		(mesh.material_override as StandardMaterial3D).albedo_color.a = t
		if t <= 0.0:
			clear()


func _show(mesh: MeshInstance3D, at: Vector3, radius: float, colour: Color, brief: bool) -> void:
	_radius = radius + RING_MARGIN if radius > 0.0 else CROSS_RADIUS
	_age = 0.0
	_brief = brief
	mesh.position = Vector3(at.x, LIFT, at.z)
	(mesh.material_override as StandardMaterial3D).albedo_color = colour
	mesh.visible = true
	_fit(mesh)


func _fit(mesh: MeshInstance3D) -> void:
	var pop := 0.0 if reduced_motion else 1.0 - clampf(_age / POP_SECONDS, 0.0, 1.0)
	var across := _radius * 2.0 * lerpf(1.0, POP_SCALE, pop * pop)
	mesh.scale = Vector3(across, 1.0, across)


static func _flat_quad(tex: Texture2D) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.orientation = PlaneMesh.FACE_Y
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 2
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


## A diagonal cross with a dark rim, drawn once.
static func _cross_tex() -> Texture2D:
	if _cross_texture == null:
		_cross_texture = ImageTexture.create_from_image(_draw(func(u: float, v: float) -> Color:
			var r := Vector2(u, v).length()
			var arm := minf(absf(u - v), absf(u + v)) / sqrt(2.0)  # distance to either diagonal
			var fill := (1.0 - clampf((arm - 0.09) / 0.05, 0.0, 1.0)) * (1.0 - clampf((r - 0.8) / 0.08, 0.0, 1.0))
			var rim := (1.0 - clampf((arm - 0.16) / 0.05, 0.0, 1.0)) * (1.0 - clampf((r - 0.92) / 0.06, 0.0, 1.0))
			var shade := lerpf(0.25, 1.0, fill)
			return Color(shade, shade, shade, maxf(fill, rim * 0.7))))
	return _cross_texture


## A ring with a dark rim on both edges, drawn once, so it reads on snow and on the yard.
static func _ring_tex() -> Texture2D:
	if _ring_texture == null:
		_ring_texture = ImageTexture.create_from_image(_draw(func(u: float, v: float) -> Color:
			var band := absf(Vector2(u, v).length() - 0.84)
			var fill := 1.0 - clampf((band - 0.05) / 0.03, 0.0, 1.0)
			var rim := 1.0 - clampf((band - 0.09) / 0.03, 0.0, 1.0)
			var shade := lerpf(0.25, 1.0, fill)
			return Color(shade, shade, shade, maxf(fill, rim * 0.7))))
	return _ring_texture


## A 64 px texture from a function of the point (-1..1 each way) to its colour, which the
## material's colour then tints.
static func _draw(shape: Callable) -> Image:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var c: Color = shape.call((x + 0.5) / n * 2.0 - 1.0, (y + 0.5) / n * 2.0 - 1.0)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, clampf(c.a, 0.0, 1.0)))
	return img
