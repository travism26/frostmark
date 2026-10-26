## A FigureBody for a model with no rig (the great frost bear): one static mesh, moved in code
## rather than by clips. It rocks on its gait while it walks and breathes while it stands; a
## strike lunges it forward so the blow lands one tick after the telegraph; a wind-up rears it
## onto its hind legs and holds it there, and `slam` brings it crashing down, thrown forward for
## a front mark or straight down for a ring; a flinch shakes it, and it rolls onto its side when
## it dies.
##
## Presentation only: the simulation never sees this node.
class_name BeastBody
extends FigureBody

## How far it rears, nose up, about its hind feet, and how long the slam takes to land.
const REAR_DEGREES := 34.0
const SLAM_SECONDS := 0.14
## Its gait: a bob of this many metres a step, and steps a metre walked.
const GAIT_BOB := 0.07
const STEPS_PER_METRE := 0.9
const BREATH := 0.015

var _pivot: Node3D  # turns it about its hind feet, for rearing and slamming
var _pose: Tween
var _rearing := 0.0  # seconds a rear waits for its slam before it drops back down
var _gait := 0.0
var _clock := 0.0


## Loads the static model at `path`, `model_height` units tall from its feet to its ears with its
## origin `lift` units above its feet and its hind feet `rear` units behind its origin, scaled to
## `figure_height` metres. Like FigureBody.setup, a model facing +Z is turned round. A model
## whose faces are wound inside out (the Poly by Google bear) is `mirrored` across its length,
## which turns its faces outward again; it must be the same on both sides.
func setup_static(path: String, model_height: float, figure_height: float, lift: float, rear: float, mirrored := false, faces_plus_z := true) -> void:
	height = figure_height
	set_meta("height", figure_height)
	_model = Node3D.new()
	_model.scale = Vector3.ONE * (figure_height / maxf(model_height, 0.001))
	if faces_plus_z:
		_model.rotation.y = PI
	add_child(_model)
	_pivot = Node3D.new()
	_pivot.position = Vector3(0.0, 0.0, -rear)
	_model.add_child(_pivot)
	var mesh: Node3D = (load(path) as PackedScene).instantiate()
	mesh.position = Vector3(0.0, lift, rear)
	if mirrored:
		mesh.scale.x = -1.0
	_pivot.add_child(mesh)


func _process(delta: float) -> void:
	super(delta)
	_clock += delta
	if _dead or _pivot == null:
		return
	if _rearing > 0.0:
		_rearing -= delta
		if _rearing <= 0.0:  # nothing landed: drop back onto all fours
			_restart_pose()
			_pose.tween_property(_pivot, "rotation:x", 0.0, 0.3)
	if is_moving():
		_gait += _speed * delta * STEPS_PER_METRE * TAU
		_pivot.position.y = absf(sin(_gait)) * GAIT_BOB / model_scale()
		_pivot.rotation.z = sin(_gait) * 0.05
	else:
		_pivot.position.y = 0.0
		_pivot.rotation.z = 0.0
		_pivot.scale = Vector3(1.0, 1.0 + sin(_clock * 2.0) * BREATH, 1.0)


## A claw blow: it draws back, then lunges a metre forward as the blow lands, a tick from now.
func strike(_style: String) -> void:
	if _dead:
		return
	_rearing = 0.0
	_restart_pose()
	_pose.tween_property(_model, "position:z", 0.25, Sim.TICK_SECONDS - 0.2).set_trans(Tween.TRANS_SINE)
	_pose.parallel().tween_property(_pivot, "rotation:x", deg_to_rad(-8.0), Sim.TICK_SECONDS - 0.2)
	_pose.tween_property(_model, "position:z", -1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_pose.parallel().tween_property(_pivot, "rotation:x", deg_to_rad(6.0), 0.2)
	_pose.tween_property(_model, "position:z", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose.parallel().tween_property(_pivot, "rotation:x", 0.0, 0.35)


## It rears onto its hind legs over one tick and holds there until `slam`.
func wind_up(_style: String) -> void:
	if _dead:
		return
	_rearing = HOLD_MAX
	_restart_pose()
	_pose.tween_property(_pivot, "rotation:x", deg_to_rad(-REAR_DEGREES), Sim.TICK_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## It crashes down from a rear: thrown forward onto the ground in front of it for a front mark,
## straight down with a bounce for a ring.
func slam(shape: String) -> void:
	if _dead:
		return
	_rearing = 0.0
	_restart_pose()
	if _pivot.rotation.x > deg_to_rad(-REAR_DEGREES / 2.0):
		_pose.tween_property(_pivot, "rotation:x", deg_to_rad(-REAR_DEGREES), 0.12)
	var forward := 0.8 if shape == CombatTable.MARK_FRONT else 0.0
	_pose.tween_property(_pivot, "rotation:x", deg_to_rad(8.0), SLAM_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_pose.parallel().tween_property(_model, "position:z", -forward, SLAM_SECONDS)
	if shape == CombatTable.MARK_RING:
		_pose.tween_property(_model, "position:y", 0.25, 0.12).set_ease(Tween.EASE_OUT)
		_pose.tween_property(_model, "position:y", 0.0, 0.12).set_ease(Tween.EASE_IN)
	_pose.tween_property(_pivot, "rotation:x", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	_pose.parallel().tween_property(_model, "position:z", 0.0, 0.4)


## A blow taken: a shudder, unless it is rearing or striking.
func flinch() -> void:
	if _dead or _rearing > 0.0 or (_pose != null and _pose.is_running()):
		return
	_restart_pose()
	_pose.tween_property(_pivot, "rotation:z", 0.08, 0.06)
	_pose.tween_property(_pivot, "rotation:z", -0.06, 0.08)
	_pose.tween_property(_pivot, "rotation:z", 0.0, 0.08)


## It rolls onto its side and sinks a little, and lies there until `revive()`.
func die() -> void:
	if _dead:
		return
	_dead = true
	_rearing = 0.0
	_restart_pose()
	_pivot.scale = Vector3.ONE
	_pose.tween_property(_pivot, "rotation:x", 0.0, 0.2)
	_pose.parallel().tween_property(_model, "position", Vector3.ZERO, 0.2)
	_pose.tween_property(_pivot, "rotation:z", deg_to_rad(88.0), 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_pose.parallel().tween_property(_pivot, "position:y", -0.15 / model_scale(), 0.6)


func revive() -> void:
	if not _dead:
		return
	_dead = false
	_restart_pose()
	_pose.kill()
	_pivot.rotation = Vector3.ZERO
	_pivot.position.y = 0.0
	_model.position = Vector3.ZERO


func _restart_pose() -> void:
	if _pose != null:
		_pose.kill()
	_pose = create_tween()
