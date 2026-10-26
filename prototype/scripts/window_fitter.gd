extends Node

## Desktop only (autoload). Opens the window as large as the monitor allows
## while keeping the game's portrait shape: it fills the usable screen height
## (title bar and taskbar included) and the game scales to fit exactly. The
## scale isn't a whole number (e.g. ~1.3x on a 1080p monitor), so some art
## pixels come out 1px bigger than others. Re-fits when the monitor changes
## shape (e.g. rotated to portrait) or the window moves to another monitor;
## manual resizes are left alone. Phones and web fill the screen on their own.

## How often to check the monitor, in seconds.
const CHECK_SECONDS := 0.5

var base_size := Vector2(
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
	# Leave room for the title bar and borders.
	var decorations := DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
	var room := Vector2(screen_rect.size - decorations)
	var scale := minf(room.x / base_size.x, room.y / base_size.y)
	var size := Vector2i((base_size * scale).floor())
	DisplayServer.window_set_size(size)
	# Centre the whole window (borders included). Positions set the client
	# area, which sits this far inside the outer frame (title bar on top).
	var inset := DisplayServer.window_get_position() - DisplayServer.window_get_position_with_decorations()
	var outer := size + decorations
	DisplayServer.window_set_position(screen_rect.position + (screen_rect.size - outer) / 2 + inset)
