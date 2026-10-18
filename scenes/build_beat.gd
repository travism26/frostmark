## The build beat: when the player builds an upgrade that has a yard piece, the camera eases
## onto the new piece, the piece rises out of the ground with a puff of snow and dust, and the
## camera eases back to the player, all inside DURATION. Presentation only: GameRoot starts it
## on the built event (never on load, so a loaded yard just stands there), asks it each frame
## where the camera should look, and cancels it the moment the player clicks to move. It
## never holds input back and never touches the simulation or the save.
class_name BuildBeat
extends Node3D

const PARTICLES := "res://assets/particles/kenney_particle_pack/"
const DUST := preload(PARTICLES + "smoke_01.png")

## The whole beat, in seconds: the camera eases onto the piece over CAMERA_IN, the piece
## rises from RISE_FROM to RISE_TO, and the camera eases back over the last CAMERA_OUT.
const DURATION := 1.5
const CAMERA_IN := 0.35
const CAMERA_OUT := 0.35
const RISE_FROM := 0.1
const RISE_TO := 1.15
## The puff: fresh snow and yard earth, thrown up around the footprint and settling.
const COLOR_SNOW := Color(0.94, 0.96, 1.0)
const COLOR_DUST := Color(0.62, 0.55, 0.46)
const PUFF_SECONDS := 1.1

## Whether the beat moves the camera; off with reduced motion, so the piece just rises.
var moves_camera := true
var _piece: Node3D  # the piece rising, or null when no beat is playing
var _focus := Vector3.ZERO
var _height := 0.0
var _time := 0.0


## Plays the beat for `node`, the yard piece WorldDressing built from `piece`, ending any beat
## still playing first.
func start(node: Node3D, piece: Dictionary) -> void:
	cancel()
	_piece = node
	_focus = focus(piece)
	_height = height(piece)
	_time = 0.0
	_piece.position.y = -sink(0.0, _height)
	var dust := puff(piece)
	add_child(dust)
	dust.finished.connect(dust.queue_free)
	dust.emitting = true


## Ends the beat now: the piece stands in its final place and the camera is the player's again.
## The puff, already thrown, settles on its own.
func cancel() -> void:
	if _piece != null and is_instance_valid(_piece):
		_piece.position.y = 0.0
	_piece = null


func is_playing() -> bool:
	return _piece != null


## Where the camera rig should stand this frame, given where the player is drawn.
func camera_point(player: Vector3) -> Vector3:
	if _piece == null or not moves_camera:
		return player
	return player.lerp(_focus, camera_weight(_time))


func _process(delta: float) -> void:
	if _piece == null:
		return
	if not is_instance_valid(_piece):
		_piece = null
		return
	_time += delta
	if _time >= DURATION:
		cancel()
		return
	_piece.position.y = -sink(_time, _height)


## How far the camera has eased from the player onto the piece, 0 to 1, `t` seconds into the beat.
static func camera_weight(t: float) -> float:
	if t <= 0.0 or t >= DURATION:
		return 0.0
	return smoothstep(0.0, CAMERA_IN, t) * (1.0 - smoothstep(DURATION - CAMERA_OUT, DURATION, t))


## How far below the ground a piece `piece_height` tall stands `t` seconds into the beat:
## all of it at first, rising fast and slowing as it settles, none from RISE_TO on.
static func sink(t: float, piece_height: float) -> float:
	var risen := clampf((t - RISE_FROM) / (RISE_TO - RISE_FROM), 0.0, 1.0)
	return piece_height * pow(1.0 - risen, 3.0)


## The ground point the camera eases onto: the middle of the piece's footprint.
static func focus(piece: Dictionary) -> Vector3:
	return Vector3(piece["at"].x, 0.0, piece["at"].y)


## How tall a piece stands: the top of its highest part.
static func height(piece: Dictionary) -> float:
	var top := 0.0
	for part in piece["parts"]:
		var tall: float = part["height"] if part.has("height") else part["size"][1]
		top = maxf(top, part.get("y", 0.0) + tall)
	return top


## A one-shot puff of snow and dust over the piece's footprint, not yet emitting.
static func puff(piece: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Puff"
	var size: Vector2 = piece["size"]
	p.position = Vector3(piece["at"].x, 0.15, piece["at"].y)
	p.rotation.y = piece["turn"]
	p.amount = clampi(int(16.0 + size.x * size.y * 6.0), 16, 40)
	p.lifetime = PUFF_SECONDS
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.85
	p.randomness = 0.5
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(size.x * 0.5 + 0.2, 0.1, size.y * 0.5 + 0.2)
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, -1.6, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.angle_min = -90.0
	p.angle_max = 90.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.scale_amount_curve = FireFx._curve([[0.0, 0.5], [0.3, 1.0], [1.0, 1.6]])
	p.color_initial_ramp = FireFx._ramp([[0.0, COLOR_SNOW], [0.6, COLOR_SNOW], [1.0, COLOR_DUST]])
	p.color_ramp = FireFx._ramp([[0.0, Color(1, 1, 1, 0.0)], [0.12, Color(1, 1, 1, 0.85)], [1.0, Color(1, 1, 1, 0.0)]])
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	quad.material = FireFx._billboard(DUST, Color.WHITE, false)
	p.mesh = quad
	return p
