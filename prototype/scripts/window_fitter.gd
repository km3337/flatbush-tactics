extends Node

## Desktop only (autoload). Sizes the window to the largest whole-number
## multiple of the base resolution that fits the monitor, centred, so pixels
## stay square with integer scaling. Re-fits when the monitor changes shape
## (e.g. rotated to portrait) or the window moves to another monitor; manual
## resizes are left alone. Phones and web fill the screen on their own.

## How often to check the monitor, in seconds.
const CHECK_SECONDS := 0.5

var base_size := Vector2i(
	ProjectSettings.get_setting("display/window/size/viewport_width"),
	ProjectSettings.get_setting("display/window/size/viewport_height"))
var screen := -1
var screen_rect := Rect2i()

func _ready() -> void:
	if not OS.has_feature("pc") or OS.has_feature("web"):
		queue_free()
		return
	var timer := Timer.new()
	timer.wait_time = CHECK_SECONDS
	timer.timeout.connect(_check_screen)
	add_child(timer)
	timer.start()
	_check_screen()

func _check_screen() -> void:
	var current := DisplayServer.window_get_current_screen()
	var rect := DisplayServer.screen_get_usable_rect(current)
	if current == screen and rect == screen_rect:
		return
	screen = current
	screen_rect = rect
	_fit()

func _fit() -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var scale := maxi(1, mini(screen_rect.size.x / base_size.x, screen_rect.size.y / base_size.y))
	var size := base_size * scale
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(screen_rect.position + (screen_rect.size - size) / 2)
