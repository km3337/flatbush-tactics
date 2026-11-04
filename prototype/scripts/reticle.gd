extends CanvasLayer

## Autoload `Reticle`: the game's cursor, on every screen. Drawn in game
## pixels (so it scales with the window like the art) and hides the system
## cursor over the window. Styled after Sin and Punishment's: a glowing core,
## a ring broken into four arcs, and ticks through the gaps. Firing snaps the
## ring in and spins the arcs a quarter turn; a hit flashes it red. While the
## weapon cools down, a dashed arc under the ring drains (the battle sets
## `cooldown_ratio`). While a charge shot builds (`charge_ratio`), the
## reticle turns yellow and a yellow halo grows around it; once full the halo
## pulses.
## On touch there's no cursor: the reticle sits where the last tap landed.
## Placeholder drawn in code; swap in art later.

const RING_RADIUS := 11.0
## Each of the four arcs spans this much; the gaps sit on the ticks.
const ARC_SPAN := deg_to_rad(56.0)
const TICK_INNER := 8.0
const TICK_OUTER := 16.0
## White line width; the dark outline is 2px wider.
const LINE_WIDTH := 2.0
const CORE_RADIUS := 2.0
const GLOW_RADIUS := 4.0
const BAR_RADIUS := 19.0
const BAR_WIDTH := 2.0
const BAR_DASHES := 8
const WHITE := Color(1, 1, 1)
const GLOW := Color(0.61, 0.94, 0.99)  # Lux2k light cyan
const HIT := Color(0.91, 0.27, 0.27)  # Lux2k red
const CHARGE := Color(1.0, 0.84, 0.41)  # Lux2k gold
const HALO_RADIUS := 15.0
const HALO_PULSE_HZ := 6.0
const OUTLINE := Color(0.06, 0.05, 0.08)
const BAR := GLOW

## Firing: the ring snaps in by SNAP_PIXELS and eases back over SNAP_SECONDS
## while the arcs spin a quarter turn over SPIN_SECONDS.
const SNAP_PIXELS := 4.0
const SNAP_SECONDS := 0.18
const SPIN_SECONDS := 0.22
## Hit: red, a white blink, red again, then back to white over HIT_SECONDS.
const HIT_SECONDS := 0.34

## 1 = just fired, 0 = ready. Set each frame by the battle; 0 elsewhere.
var cooldown_ratio := 0.0
## 0 = not charging, 1 = charge shot ready. Set each frame by the battle.
var charge_ratio := 0.0
var canvas: Control
var shown := false
var since_fired := INF
var since_hit := INF

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

## A shot went off.
func fired() -> void:
	since_fired = 0.0

## That shot hit an enemy or a projectile.
func hit_confirmed() -> void:
	since_hit = 0.0

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton:
		shown = true
	# A real mouse (not a touch's emulated one): hide the system cursor so only
	# the reticle shows. Covers touch-capable PCs and browsers, where _ready
	# skips hiding it.
	if event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION and Input.mouse_mode != Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_MOUSE_EXIT:
			shown = false
		NOTIFICATION_WM_MOUSE_ENTER:
			shown = true

func _process(delta: float) -> void:
	since_fired += delta
	since_hit += delta
	canvas.queue_redraw()

func _ring_color() -> Color:
	if since_hit >= HIT_SECONDS:
		return WHITE.lerp(CHARGE, charge_ratio) if charge_ratio > 0.0 else WHITE
	if since_hit < 0.06:
		return HIT
	if since_hit < 0.12:
		return WHITE
	if since_hit < 0.2:
		return HIT
	return HIT.lerp(WHITE, (since_hit - 0.2) / (HIT_SECONDS - 0.2))

func _draw_reticle() -> void:
	if not shown:
		return
	# Whole pixels (even line widths sit on pixel corners), so the reticle
	# stays on the pixel grid.
	var c := canvas.get_viewport().get_mouse_position().round()
	var snap := 1.0 - clampf(since_fired / SNAP_SECONDS, 0.0, 1.0)
	var radius := roundf(RING_RADIUS - SNAP_PIXELS * snap * snap)
	var spin := ease(clampf(since_fired / SPIN_SECONDS, 0.0, 1.0), 0.4) * PI / 2.0 if since_fired < SPIN_SECONDS else 0.0
	var ring := _ring_color()
	# Charging: a yellow halo outside the ring, thicker as it fills; pulsing
	# once full.
	if charge_ratio > 0.0:
		var alpha := 0.35 + 0.35 * charge_ratio
		if charge_ratio >= 1.0:
			alpha = 0.45 + 0.4 * (0.5 + 0.5 * cos(Time.get_ticks_msec() / 1000.0 * TAU * HALO_PULSE_HZ))
		var halo_width := roundf(1.0 + 3.0 * charge_ratio) * 2.0
		canvas.draw_arc(c, HALO_RADIUS + halo_width / 2.0 - (RING_RADIUS - radius), 0, TAU, 40, Color(CHARGE, alpha), halo_width, false)
	# Glowing core: a cyan halo around a white dot (red on a hit, yellow
	# while charging).
	canvas.draw_circle(c, GLOW_RADIUS + 1.0, OUTLINE, true, -1.0, false)
	canvas.draw_circle(c, GLOW_RADIUS, GLOW if ring == WHITE else ring, true, -1.0, false)
	canvas.draw_circle(c, CORE_RADIUS, WHITE, true, -1.0, false)
	# Four arcs centred on the diagonals, and ticks through the gaps; white
	# with a dark outline so it reads on light and dark screens.
	var tick_in := TICK_INNER - (RING_RADIUS - radius)
	var tick_out := TICK_OUTER - (RING_RADIUS - radius)
	for pass_ in 2:
		var color := OUTLINE if pass_ == 0 else ring
		var width := LINE_WIDTH + 2.0 if pass_ == 0 else LINE_WIDTH
		for i in 4:
			var mid := PI / 4.0 + i * PI / 2.0 + spin
			canvas.draw_arc(c, radius, mid - ARC_SPAN / 2.0, mid + ARC_SPAN / 2.0, 12, color, width, false)
		for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			canvas.draw_line(c + dir * tick_in, c + dir * tick_out, color, width)
	# Cooldown: a dashed arc around the bottom half, draining from right to left.
	if cooldown_ratio > 0.0:
		var left := PI * clampf(cooldown_ratio, 0.0, 1.0)
		var step := PI / BAR_DASHES
		for i in BAR_DASHES:
			var start := PI - i * step
			var end := maxf(start - step * 0.65, PI - left)
			if end >= start:
				break
			canvas.draw_arc(c, BAR_RADIUS, start, end, 6, OUTLINE, BAR_WIDTH + 2.0, false)
			canvas.draw_arc(c, BAR_RADIUS, start, end, 6, BAR, BAR_WIDTH, false)
