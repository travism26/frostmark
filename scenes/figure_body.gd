## One animated figure: a glTF model with an AnimationPlayer and a Skeleton3D, scaled to a
## height in metres, standing on this node's origin and facing its local -Z (the game's
## forward). It picks its own clip: Idle while still, the walk or run clip while its global
## position changes between frames (so GameRoot keeps moving the node and nothing else), a
## one-shot attack on `strike(style)` and the death clip on `die()`. Gear hangs off the rig's
## BoneAttachment3D slots through `bone_slot` and `mount`, so it moves with the animation.
##
## Presentation only: the simulation never sees this node.
class_name FigureBody
extends Node3D

const BLEND := 0.15
## Seconds a figure keeps its walk clip after the last frame it moved, so a stutter in the
## interpolation never flickers it back to idle.
const MOVE_HOLD := 0.2
const MIN_SPEED := 0.3  # m/s below which a figure is standing
const TELEPORT := 6.0  # a jump this far in one frame is a placement, not a step
const LOOPED := ["idle", "walk", "run"]

## Clip names by role: idle, walk, run, melee, ranged, death.
var clips := {}
## Speed in m/s from which the run clip plays instead of the walk clip.
var run_speed := 3.5
var height := 1.8

var _model: Node3D
var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _last_pos := Vector3.ZERO
var _placed := false
var _move_hold := 0.0
var _speed := 0.0
var _one_shot := ""  # a clip playing once over the base clip
var _dead := false
var _current := ""


## Loads the model at `path`, whose rig stands `model_height` units tall, and scales it to
## `figure_height` metres. Models that face +Z (KayKit, Quaternius) are turned round.
func setup(path: String, model_height: float, figure_height: float, role_clips: Dictionary, faces_plus_z := true) -> void:
	clips = role_clips
	height = figure_height
	set_meta("height", figure_height)
	var scene: PackedScene = load(path)
	_model = scene.instantiate()
	var s := figure_height / maxf(model_height, 0.001)
	_model.scale = Vector3.ONE * s
	if faces_plus_z:
		_model.rotation.y = PI
	add_child(_model)
	_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _player != null:
		for role in LOOPED:
			var clip: String = clips.get(role, "")
			if clip != "" and _player.has_animation(clip):
				_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		_player.animation_finished.connect(_on_clip_finished)


func _ready() -> void:
	_refresh()


func _process(delta: float) -> void:
	var pos := global_position
	if _placed:
		var step := pos.distance_to(_last_pos)
		if step > TELEPORT:
			_speed = 0.0
			_move_hold = 0.0
		elif delta > 0.0:
			var speed := step / delta
			if speed >= MIN_SPEED:
				_speed = speed
				_move_hold = MOVE_HOLD
			else:
				_move_hold -= delta
				if _move_hold <= 0.0:
					_speed = 0.0
	_last_pos = pos
	_placed = true
	_refresh()


func is_moving() -> bool:
	return _move_hold > 0.0 or _speed >= MIN_SPEED


## Plays the attack clip for a `style` ("melee" or "ranged") once, then returns to the base clip.
func strike(style: String) -> void:
	if _dead or _player == null:
		return
	var clip: String = clips.get("ranged" if style == CombatTable.STYLE_RANGED else "melee", "")
	if clip == "" or not _player.has_animation(clip):
		return
	_one_shot = clip
	if _player.current_animation == clip and _player.is_playing():
		_player.seek(0.0)
	else:
		_player.play(clip, BLEND)
	_current = clip


## Plays the death clip and holds its last frame until `revive()`.
func die() -> void:
	if _dead:
		return
	_dead = true
	_one_shot = ""
	var clip: String = clips.get("death", "")
	if _player != null and clip != "" and _player.has_animation(clip):
		_player.play(clip, BLEND)
		_current = clip


func revive() -> void:
	if not _dead:
		return
	_dead = false
	_current = ""
	_refresh()


## The rig's BoneAttachment3D named `slot_name` (handslot_l, handslot_r, head, chest on a
## KayKit rig), or null.
func bone_slot(slot_name: String) -> Node3D:
	if _skeleton == null:
		return null
	return _skeleton.get_node_or_null(slot_name) as Node3D


## A fresh node hanging off `slot_name` whose axes are this figure's own (+X right, +Y up, -Z
## forward) with the rig in its rest pose, in metres, with its origin on the bone. Gear built
## in it is authored as if the figure stood in its T-pose and then follows the animation.
func mount(slot_name: String, node_name := "") -> Node3D:
	var slot := bone_slot(slot_name)
	var holder := Node3D.new()
	if node_name != "":
		holder.name = node_name
	if slot == null:
		add_child(holder)
		return holder
	var bone := _skeleton.find_bone((slot as BoneAttachment3D).bone_name)
	var rest := _frame_of(_skeleton) * _skeleton.get_bone_global_rest(bone)
	holder.transform = rest.affine_inverse() * Transform3D(Basis.IDENTITY, rest.origin)
	slot.add_child(holder)
	return holder


## The scale the model was drawn at, so parts added straight to a slot can be sized in metres.
func model_scale() -> float:
	return _model.scale.y if _model != null else 1.0


## Hides parts of the model (the hat, the spare weapons a KayKit glb carries) by node name.
func hide_parts(names: Array) -> void:
	for n in names:
		set_part_visible(n, false)


func set_part_visible(part_name: String, shown: bool) -> void:
	var part := _model.find_child(part_name, true, false) as Node3D
	if part != null:
		part.visible = shown


## Multiplies the colours of every mesh under `root` (the whole model when null) by `colour`.
func tint(colour: Color, root: Node = null) -> void:
	tint_meshes(root if root != null else _model, colour)


## Redraws every mesh under `root` (the whole model when null) in shades of `colour`: the
## texture keeps only its light and dark, so a green hood can turn bandit red.
func recolour(colour: Color, root: Node = null) -> void:
	recolour_meshes(root if root != null else _model, colour)


static var _tints := {}  # "material id|colour" -> tinted copy
static var _shade_shader: Shader


static func recolour_meshes(root: Node, colour: Color) -> void:
	if _shade_shader == null:
		_shade_shader = Shader.new()
		_shade_shader.code = SHADE_SHADER
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as StandardMaterial3D
			var key := "shade|%d|%s" % [src.get_instance_id() if src != null else 0, colour.to_html()]
			if not _tints.has(key):
				var m := ShaderMaterial.new()
				m.shader = _shade_shader
				m.set_shader_parameter("tint", colour)
				m.set_shader_parameter("use_texture", src != null and src.albedo_texture != null)
				if src != null and src.albedo_texture != null:
					m.set_shader_parameter("albedo_texture", src.albedo_texture)
				_tints[key] = m
			mi.set_surface_override_material(i, _tints[key])


const SHADE_SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool use_texture = false;
uniform sampler2D albedo_texture : source_color, filter_nearest;
void fragment() {
	float light = 1.0;
	if (use_texture) {
		vec3 c = texture(albedo_texture, UV).rgb;
		light = 0.35 + 1.4 * dot(c, vec3(0.3, 0.59, 0.11));
	}
	ALBEDO = tint.rgb * light;
	ROUGHNESS = 1.0;
}
"""

static func tint_meshes(root: Node, colour: Color) -> void:
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as StandardMaterial3D
			if src == null:
				continue
			var key := "%d|%s" % [src.get_instance_id(), colour.to_html()]
			if not _tints.has(key):
				var copy := src.duplicate() as StandardMaterial3D
				copy.albedo_color = src.albedo_color * colour
				_tints[key] = copy
			mi.set_surface_override_material(i, _tints[key])


## The clip the figure should be in when nothing one-shot is playing.
func _base_clip() -> String:
	if is_moving():
		return clips.get("run" if _speed >= run_speed else "walk", "")
	return clips.get("idle", "")


func _refresh() -> void:
	if _dead or _one_shot != "" or _player == null:
		return
	_play(_base_clip())


func _play(clip: String) -> void:
	if clip == "" or clip == _current or not _player.has_animation(clip):
		return
	_player.play(clip, BLEND)
	_current = clip


func _on_clip_finished(clip: String) -> void:
	if clip == _one_shot:
		_one_shot = ""
	_current = ""  # a finished one-shot or activity clip restarts the base clip
	_refresh()


func _frame_of(node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != self:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
