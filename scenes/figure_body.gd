## One animated figure: a glTF model with an AnimationPlayer and a Skeleton3D, scaled to a
## height in metres, standing on this node's origin and facing its local -Z (the game's
## forward). It picks its own clip: Idle while still, the walk or run clip while its global
## position changes between frames (so GameRoot keeps moving the node and nothing else), a
## one-shot attack on `strike(style)`, paced so the blow lands one simulation tick after the
## telegraph, a held `wind_up(style)` the next strike resumes from, a `flinch()` when hit and
## the death clip on `die()`. Gear hangs off the rig's BoneAttachment3D slots through
## `bone_slot` and `mount`, so it moves with the animation.
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
## Seconds a wind-up stays raised when no strike follows it (the target stepped away).
const HOLD_MAX := 1.6
## The strike clip is never paced further than this from its authored speed.
const PACE_MIN := 0.6
const PACE_MAX := 2.2

## Clip names by role: idle, walk, run, melee, ranged, magic, flinch, death.
var clips := {}
## Speed in m/s from which the run clip plays instead of the walk clip.
var run_speed := 3.5
var height := 1.8
## Where in the strike clip (0 to 1) the blow lands; `strike` paces the clip so this point
## comes one tick after the call.
var impact := 0.45
## Where in the strike clip a wind-up holds, weapon raised.
var raise := 0.2
## Metres the model throws itself forward on a strike (a wolf's bite); 0 keeps it planted.
var lunge := 0.0

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
var _held := false  # a wind-up waiting at `raise` for its strike
var _hold_left := 0.0
var _lunge_tween: Tween


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
	if _held:
		_hold_wind_up(delta)
	_refresh()


func is_moving() -> bool:
	return _move_hold > 0.0 or _speed >= MIN_SPEED


## Plays the attack clip for a `style` ("melee", "ranged" or "magic") once, then returns to
## the base clip. The clip is paced so its `impact` point comes one tick (the blow) after the
## telegraph that called this; a held wind-up resumes from where it stopped. A rig without a
## magic clip sweeps its melee one.
func strike(style: String) -> void:
	if _dead or _player == null:
		return
	var clip := _strike_clip(style)
	if clip == "":
		return
	var length := _player.get_animation(clip).length
	var from := 0.0
	if _held and _player.current_animation == clip:
		from = _player.current_animation_position
	_held = false
	_one_shot = clip
	_current = clip
	if _player.current_animation == clip:
		_player.play(clip)
		_player.seek(from, true)
	else:
		_player.play(clip, BLEND)
	var to_blow := maxf(length * impact - from, 0.05)
	_player.speed_scale = clampf(to_blow / Sim.TICK_SECONDS, PACE_MIN, PACE_MAX)
	if lunge > 0.0:
		_lunge()


## Raises the strike clip for `style` to its `raise` point over one tick and holds it there
## (the troll winding up its crush) until the next `strike` resumes it, or for `HOLD_MAX`
## seconds when no blow follows.
func wind_up(style: String) -> void:
	if _dead or _player == null:
		return
	var clip := _strike_clip(style)
	if clip == "":
		return
	var length := _player.get_animation(clip).length
	_one_shot = clip
	_current = clip
	_held = true
	_hold_left = HOLD_MAX
	_player.play(clip, BLEND)
	_player.seek(0.0, true)
	_player.speed_scale = clampf(length * raise / Sim.TICK_SECONDS, PACE_MIN, PACE_MAX)


## A blow taken: the flinch clip once, unless a strike or wind-up has the body.
func flinch() -> void:
	if _dead or _player == null or _one_shot != "":
		return
	var clip: String = clips.get("flinch", "")
	if clip == "" or not _player.has_animation(clip):
		return
	_one_shot = clip
	_current = clip
	_player.speed_scale = 1.0
	_player.play(clip, BLEND)


## The clip now playing, by name ("" before the first).
func current_clip() -> String:
	return _current


func _strike_clip(style: String) -> String:
	var key := "ranged" if style == CombatTable.STYLE_RANGED else "magic" if style == CombatTable.STYLE_MAGIC else "melee"
	var clip: String = clips.get(key, clips.get("melee", ""))
	if clip == "" or not _player.has_animation(clip):
		return ""
	return clip


func _hold_wind_up(delta: float) -> void:
	var clip := _player.current_animation
	if clip != _one_shot or clip == "":
		_held = false
		return
	var hold_at := _player.get_animation(clip).length * raise
	if _player.is_playing() and _player.current_animation_position >= hold_at:
		_player.pause()
	_hold_left -= delta
	if _hold_left <= 0.0:  # nobody to hit: lower the weapon
		_held = false
		_one_shot = ""
		_current = ""
		_player.speed_scale = 1.0
		_refresh()


func _lunge() -> void:
	if _lunge_tween != null:
		_lunge_tween.kill()
	_model.position = Vector3.ZERO
	_lunge_tween = create_tween()
	_lunge_tween.tween_property(_model, "position:z", -lunge, 0.3).set_delay(Sim.TICK_SECONDS - 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_lunge_tween.tween_property(_model, "position:z", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Plays the death clip and holds its last frame until `revive()`.
func die() -> void:
	if _dead:
		return
	_dead = true
	_one_shot = ""
	_held = false
	if _lunge_tween != null:
		_lunge_tween.kill()
	if _model != null:
		_model.position = Vector3.ZERO
	var clip: String = clips.get("death", "")
	if _player != null and clip != "" and _player.has_animation(clip):
		_player.speed_scale = 1.0
		_player.play(clip, BLEND)
		_current = clip


func revive() -> void:
	if not _dead:
		return
	_dead = false
	_current = ""
	_refresh()


## The rig's BoneAttachment3D named `slot_name` (handslot_l, handslot_r, head, chest on a
## KayKit adventurer). A rig that ships without one gets it made on the bone of that name
## (the skeletons' `handslot.r`, the yeti's `Middle1.R`); null when there is no such bone.
func bone_slot(slot_name: String) -> Node3D:
	if _skeleton == null:
		return null
	var slot := _skeleton.get_node_or_null(slot_name) as Node3D
	if slot != null:
		return slot
	var bone := _skeleton.find_bone(slot_name)
	if bone < 0:
		bone = _skeleton.find_bone(slot_name.replace("_", "."))
	if bone < 0:
		return null
	var attach := BoneAttachment3D.new()
	attach.name = slot_name
	attach.bone_name = _skeleton.get_bone_name(bone)
	_skeleton.add_child(attach)
	return attach


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


## Repaints the model's materials flat and matte, and gives each whose name begins with a key
## of `colours` that colour (Quaternius monsters ship dark, half-metallic colours that read as
## shadow under the dusk sun).
func paint(colours: Dictionary) -> void:
	paint_meshes(_model, colours)


static var _tints := {}  # "material id|colour" -> tinted copy
static var _shade_shader: Shader


static func paint_meshes(root: Node, colours: Dictionary) -> void:
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
			var key := "paint|%d|%d" % [src.get_instance_id(), colours.hash()]
			if not _tints.has(key):
				var m := src.duplicate() as StandardMaterial3D
				m.metallic = 0.0
				m.roughness = 1.0
				m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				var name := String(src.resource_name)
				for prefix in colours:
					if name.begins_with(prefix):
						m.albedo_color = colours[prefix]
				_tints[key] = m
			mi.set_surface_override_material(i, _tints[key])


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
	_player.speed_scale = 1.0
	_player.play(clip, BLEND)
	_current = clip


func _on_clip_finished(clip: String) -> void:
	if clip == _one_shot:
		_one_shot = ""
		_held = false
		_player.speed_scale = 1.0
	_current = ""  # a finished one-shot or activity clip restarts the base clip
	_refresh()


func _frame_of(node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != self:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
