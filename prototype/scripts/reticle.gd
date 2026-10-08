extends CanvasLayer

## Autoload `Reticle`: the game's cursor, on every screen. Drawn in game
## pixels (so it scales with the window like the art) and hides the system
## cursor over the window. While the weapon cools down, a red bar wraps the
## bottom of the ring and drains (the battle sets `cooldown_ratio`).
## On touch there's no cursor: the reticle sits where the last tap landed.
## Placeholder drawn in code; swap in art later.

const RING_RADIUS := 10.0
const TICK_LENGTH := 8.0
## White line width; the dark outline is 2px wider.
const LINE_WIDTH := 2.0
const BAR_RADIUS := 16.0
const BAR_WIDTH := 4.0
const WHITE := Color(1, 1, 1)
const OUTLINE := Color(0.06, 0.05, 0.08)
const BAR := Color(0.95, 0.15, 0.2)

## 1 = just fired, 0 = ready. Set each frame by the battle; 0 elsewhere.
var cooldown_ratio := 0.0
var canvas: Control
var shown := false

func _ready() -> void:
	layer = 100  # above every screen and the HUD
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(_draw_reticle)
	add_child(canvas)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.is_touchscreen_available() and not OS.has_feature("pc"):
		shown = false  # appears on the first tap
	else:
		shown = true
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton:
		shown = true

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_MOUSE_EXIT:
			shown = false
		NOTIFICATION_WM_MOUSE_ENTER:
			shown = true

func _process(_delta: float) -> void:
	canvas.queue_redraw()

func _draw_reticle() -> void:
	if not shown:
		return
	# Whole pixels (even line widths sit on pixel corners), so the reticle
	# stays on the pixel grid.
	var c := canvas.get_viewport().get_mouse_position().round()
	# Ring + four ticks + centre dot, white with a dark outline so it reads
	# on light and dark screens.
	for pass_ in 2:
		var color := OUTLINE if pass_ == 0 else WHITE
		var width := LINE_WIDTH + 2.0 if pass_ == 0 else LINE_WIDTH
		canvas.draw_arc(c, RING_RADIUS, 0, TAU, 40, color, width, false)
		for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			canvas.draw_line(c + dir * (RING_RADIUS - TICK_LENGTH / 2.0), c + dir * (RING_RADIUS + TICK_LENGTH / 2.0), color, width)
		var dot := width
		canvas.draw_rect(Rect2(c - Vector2.ONE * dot / 2.0, Vector2.ONE * dot), color)
	# Cooldown: a red arc around the bottom half, draining from right to left.
	if cooldown_ratio > 0.0:
		var start := PI
		var end := PI - PI * clampf(cooldown_ratio, 0.0, 1.0)
		canvas.draw_arc(c, BAR_RADIUS, start, end, 32, OUTLINE, BAR_WIDTH + 2.0, false)
		canvas.draw_arc(c, BAR_RADIUS, start, end, 32, BAR, BAR_WIDTH, false)
