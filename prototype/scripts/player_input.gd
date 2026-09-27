class_name FTPlayerInput
extends Node

signal shoot_requested(screen_position: Vector2)
signal reload_requested

@export var minimum_swipe_distance := 90.0
@export var maximum_tap_travel := 28.0
var touch_start := Vector2.ZERO
var tracking_touch := false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reload"):
		reload_requested.emit()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		shoot_requested.emit(event.position)
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start = event.position
			tracking_touch = true
		elif tracking_touch:
			_finish_touch(event.position)
			tracking_touch = false

func _finish_touch(end_position: Vector2) -> void:
	var delta := end_position - touch_start
	# Swipe down to reload. Easy to swap direction later.
	if delta.y > minimum_swipe_distance and abs(delta.y) > abs(delta.x):
		reload_requested.emit()
	elif delta.length() <= maximum_tap_travel:
		shoot_requested.emit(end_position)
