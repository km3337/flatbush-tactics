class_name FTPlayerInput
extends Node

signal reload_requested
## A press (mouse button or finger) went down; the charge shot builds while
## it's held (`holding`, at `hold_position`).
signal hold_started(screen_position: Vector2)
## The press came up: shots fire here. `tap` is a mouse click or a touch that
## didn't travel; the battle decides between a normal and a charged shot.
signal hold_released(screen_position: Vector2, tap: bool)
## The press turned into a swipe (reload); no charged shot.
signal hold_cancelled

@export var minimum_swipe_distance := 90.0
## A reload swipe is a quick flick: the finger is down at most this long.
## Slower drags aim (the reticle follows) and fire on release.
@export var maximum_swipe_seconds := 0.25
@export var maximum_tap_travel := 28.0
var touch_start := Vector2.ZERO
var touch_start_msec := 0
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
			_start_hold(event.position)
		elif holding:
			holding = false
			hold_released.emit(event.position, true)
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
			touch_start_msec = Time.get_ticks_msec()
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
	if _is_reload_flick(delta, (Time.get_ticks_msec() - touch_start_msec) / 1000.0):
		hold_cancelled.emit()
		reload_requested.emit()
	else:
		hold_released.emit(end_position, delta.length() <= maximum_tap_travel)

## Flick down, left or right to reload; up is left free. Easy to change.
func _is_reload_flick(delta: Vector2, seconds: float) -> bool:
	if seconds > maximum_swipe_seconds or delta.length() < minimum_swipe_distance:
		return false
	var mostly_up := delta.y < 0.0 and absf(delta.y) > absf(delta.x)
	return not mostly_up
