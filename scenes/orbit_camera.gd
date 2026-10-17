## Orbit camera rig: yaw around the rig with Q/E or a middle-mouse drag, zoom with the
## wheel between fixed limits, pitch fixed top-down-ish. The rig's position is set by
## GameRoot every frame to the character's rendered position. Camera state never enters
## the simulation.
extends Node3D

const MIN_DISTANCE := 14.0
const MAX_DISTANCE := 60.0
const ZOOM_STEP := 3.0
const PITCH_DEGREES := 55.0
const KEY_YAW_SPEED := 2.0     # radians per second while Q or E is held
const DRAG_YAW_SPEED := 0.008  # radians per pixel of middle-mouse drag
## A narrow lens keeps trees and posts upright at the edges of the view.
const FOV_DEGREES := 40.0

var yaw := 0.0
var distance := 32.0

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	camera.fov = FOV_DEGREES
	_update()


func _process(delta: float) -> void:
	var turn := 0.0
	# Typing in a text field (a save code full of q and e) must not spin the camera.
	if get_viewport().gui_get_focus_owner() is TextEdit:
		_update()
		return
	if Input.is_key_pressed(KEY_Q):
		turn += 1.0
	if Input.is_key_pressed(KEY_E):
		turn -= 1.0
	if turn != 0.0:
		yaw = wrapf(yaw + turn * KEY_YAW_SPEED * delta, -PI, PI)
	_update()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
		yaw = wrapf(yaw - event.relative.x * DRAG_YAW_SPEED, -PI, PI)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - ZOOM_STEP, MIN_DISTANCE, MAX_DISTANCE)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + ZOOM_STEP, MIN_DISTANCE, MAX_DISTANCE)
			get_viewport().set_input_as_handled()


func _update() -> void:
	var pitch := deg_to_rad(PITCH_DEGREES)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.global_position = global_position + offset
	camera.look_at(global_position, Vector3.UP)
