class_name FTPlayerInput
extends Node

signal shoot_requested(screen_position: Vector2)
signal reload_requested
## A press (mouse button or finger) went down; the charge shot builds while
## it's held (`holding`, at `hold_position`).
signal hold_started(screen_position: Vector2)
## The press came up. `tap` is a touch that didn't travel: it fires a normal
## shot unless the charge is full. (A mouse press already fired on the way down.)
signal hold_released(screen_position: Vector2, tap: bool)
## The press turned into a swipe (reload); no charged shot.
signal hold_cancelled

@export var minimum_swipe_distance := 90.0
@export var maximum_tap_travel := 28.0
var touch_start := Vector2.ZERO
var tracking_touch := false
var holding := false
var hold_position := Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reload"):
		reload_requested.emit()
		get_viewport().set_input_as_handled()
		return

	# A touch also arrives as emulated mouse events; the touch branches below
	# handle it, so one tap is one shot and a swipe is never a shot.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if event.pressed:
			shoot_requested.emit(event.position)
			_start_hold(event.position)
		elif holding:
			holding = false
			hold_released.emit(event.position, false)
		return

	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		hold_position = event.position
		return

	if event is InputEventScreenDrag and tracking_touch:
		hold_position = event.position
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start = event.position
			tracking_touch = true
			_start_hold(event.position)
		elif tracking_touch:
			_finish_touch(event.position)
			tracking_touch = false

func _start_hold(screen_position: Vector2) -> void:
	holding = true
	hold_position = screen_position
	hold_started.emit(screen_position)

func _finish_touch(end_position: Vector2) -> void:
	var delta := end_position - touch_start
	holding = false
	# Swipe down to reload. Easy to swap direction later.
	if delta.y > minimum_swipe_distance and abs(delta.y) > abs(delta.x):
		hold_cancelled.emit()
		reload_requested.emit()
	else:
		hold_released.emit(end_position, delta.length() <= maximum_tap_travel)
