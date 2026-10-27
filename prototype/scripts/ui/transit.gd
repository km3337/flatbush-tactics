class_name FTTransit
extends Control

## Placeholder transit sequence between stops. Kristian's animation replaces
## the visuals (objects past the subway window, MTA-style next-stop sign).
## The doors opening is played by the stop itself (FTClosingDoors.open()), so
## the ride ends straight into it. Keep this contract:
##   - Read where the train is going from `Run.upcoming_station()`;
##     `Run.is_detouring()` is true when it's a detour stop (show the service
##     change).
##   - When the ride ends, call `_arrive()`. It moves the run to the stop,
##     asks about a transfer if the stop has one, then opens the encounter.
## Tap, Space or Enter skips the ride.
## The ride to the Last Stop plays the conductor's announcement and lasts as
## long as it does (skipping cuts it off).

const RIDE_SECONDS := 2.0
## Freesound 86938 by jerk01, "last stop".
const LAST_STOP_ANNOUNCEMENT: AudioStream = preload("res://assets/sfx/last_stop.wav")
const WINDOW := Rect2(20, 50, 320, 230)
const SIGN := Rect2(20, 318, 320, 118)
const LED_RED := Color(1.0, 0.18, 0.12)
const LED_ORANGE := Color(1.0, 0.55, 0.12)
const LED_GREEN := Color(0.3, 0.95, 0.35)

var station: FTStation
## How long the train rides (longer to the Last Stop).
var ride_seconds := RIDE_SECONDS
var announcement: AudioStreamPlayer
var detour := false
var time := 0.0
var arrived := false
var streaks: Array[Vector3] = []  # x, y, width
## Line indices offered by the transfer prompt (empty = no prompt).
var prompt_lines: Array[int] = []

func _ready() -> void:
	station = Run.upcoming_station()
	detour = Run.is_detouring()
	if station.kind == FTStation.Kind.LAST_STOP:
		# The ride lasts as long as the announcement.
		ride_seconds = maxf(RIDE_SECONDS, LAST_STOP_ANNOUNCEMENT.get_length())
		announcement = AudioStreamPlayer.new()
		announcement.stream = LAST_STOP_ANNOUNCEMENT
		announcement.volume_db = -6.0
		add_child(announcement)
		announcement.play()
	for i in 14:
		streaks.append(Vector3(randf_range(0, WINDOW.size.x), randf_range(10, WINDOW.size.y - 10), randf_range(20, 90)))

func _process(delta: float) -> void:
	if arrived:
		return
	time += delta
	for i in streaks.size():
		streaks[i].x -= delta * 900.0 * (0.5 + streaks[i].z / 90.0)
		if streaks[i].x + streaks[i].z < 0:
			streaks[i] = Vector3(WINDOW.size.x, randf_range(10, WINDOW.size.y - 10), randf_range(20, 90))
	queue_redraw()
	if time >= ride_seconds:
		_arrive()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_skip()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not prompt_lines.is_empty():
		var index: int = event.physical_keycode - KEY_1
		if index >= 0 and index < prompt_lines.size():
			get_viewport().set_input_as_handled()
			_choose_line(prompt_lines[index])
	elif event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_skip()

func _skip() -> void:
	if not arrived:
		time = maxf(time, ride_seconds)
		if announcement:
			announcement.stop()

func _origin() -> Vector2:
	return ((size - Vector2(360, 640)) / 2.0).floor()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.07, 0.08))
	var o := _origin()
	var font := get_theme_default_font()
	# Subway car window with things rushing past.
	draw_rect(Rect2(o + WINDOW.position, WINDOW.size), Color(0.1, 0.16, 0.27))
	for s in streaks:
		draw_rect(Rect2(o + WINDOW.position + Vector2(maxf(s.x, 0), s.y), Vector2(minf(s.z, WINDOW.size.x - maxf(s.x, 0)), 3)), Color(0.75, 0.8, 0.9, 0.5))
	draw_rect(Rect2(o + WINDOW.position, WINDOW.size), Color(0.45, 0.47, 0.5), false, 6.0)
	# LED next-stop sign.
	var sign := Rect2(o + SIGN.position, SIGN.size)
	draw_rect(sign, Color(0.03, 0.03, 0.03))
	draw_rect(sign, Color(0.25, 0.25, 0.27), false, 3.0)
	var blink := fmod(time, 0.5) < 0.3
	if detour:
		if blink:
			draw_string(font, sign.position + Vector2(14, 30), "SERVICE CHANGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, LED_RED)
		draw_string(font, sign.position + Vector2(14, 58), "Detour via", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, LED_ORANGE)
	else:
		draw_string(font, sign.position + Vector2(14, 30), "Next Stop", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, LED_RED)
	draw_string(font, sign.position + Vector2(14, 84), station.display_name, HORIZONTAL_ALIGNMENT_LEFT, 260, 16, LED_ORANGE)
	FTStopIcons.draw(self, station, sign.position + Vector2(296, 78), 1.0, LED_ORANGE)
	if station.is_transfer() and station.kind != FTStation.Kind.LAST_STOP and not detour:
		var other: int = station.line_indices[0] if station.line_indices[1] == Run.line_index else station.line_indices[1]
		draw_string(font, sign.position + Vector2(14, 106), "Transfer to the %s" % Run.stage.lines[other].bullet, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, LED_GREEN)

func _arrive() -> void:
	arrived = true
	Run.arrive()
	var other := Run.transfer_line()
	if other < 0:
		Run.enter_current_stop()
		return
	_show_transfer_prompt(other)

# At a transfer station, before its encounter: stay or switch lines.
func _show_transfer_prompt(other: int) -> void:
	var panel := ColorRect.new()
	panel.color = Color(0.04, 0.08, 0.16, 0.95)
	panel.position = _origin() + Vector2(10, 150)
	panel.size = Vector2(340, 300)
	add_child(panel)
	var title := Label.new()
	title.text = "TRANSFER AVAILABLE\n%s" % Run.current_station.display_name.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.position = Vector2(0, 14)
	title.size = Vector2(340, 44)
	panel.add_child(title)
	var depth := Run.route_depth + 1
	var options: Array[int] = [Run.line_index, other]
	prompt_lines = options
	for i in options.size():
		var line := Run.stage.lines[options[i]]
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.position = Vector2(16, 80 + i * 104)
		button.size = Vector2(308, 92)
		button.add_theme_font_size_override("font_size", 8)
		var verb := "STAY ON THE %s" if i == 0 else "TRANSFER TO THE %s"
		button.text = "%d  %s\n%s" % [i + 1, verb % line.bullet, Run.stage.summary(options[i], depth)]
		for state in ["normal", "hover", "pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = line.color.lightened(0.1) if state == "hover" else line.color
			style.set_corner_radius_all(4)
			button.add_theme_stylebox_override(state, style)
		for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
			button.add_theme_color_override(color_name, line.text_color)
		button.pressed.connect(_choose_line.bind(options[i]))
		panel.add_child(button)

func _choose_line(index: int) -> void:
	if prompt_lines.is_empty():
		return
	prompt_lines.clear()
	if index != Run.line_index:
		Run.transfer_to(index)
	Run.enter_current_stop()
