class_name FTLineSelect
extends Control

## Stage start: pick a train line on the stage map, then board it. The map
## is taller than the screen: it opens on the Last Stop, holds, then glides
## down to the first stops (tap or any key skips). After that the player can
## scroll (drag, mouse wheel, Up/Down) and tap any part of a line (or press
## 1/2/3) to highlight it and see its summary; BOARD locks it in.
## Starts a run if none is active.

const KIND_WORDS := {
	FTStation.Kind.BATTLE: "BATTLE",
	FTStation.Kind.ELITE: "ELITE",
	FTStation.Kind.EVENT: "EVENT",
	FTStation.Kind.SHOP: "SHOP",
}
const PAN_HOLD_SECONDS := 1.0
const PAN_SECONDS := 3.0
const WHEEL_STEP := 60.0
const KEY_STEP := 90.0
## A press that moves further than this is a drag (scroll), not a tap.
const DRAG_THRESHOLD := 8.0

@onready var map_clip: Control = %MapClip
@onready var map_view: FTStageMapView = %MapView
@onready var summary: Label = %Summary
@onready var board_button: Button = %BoardButton

var scroll := 0.0
var panning := true
var pan_tween: Tween
var press_position := Vector2.ZERO
var pressing := false
var dragging := false

func _ready() -> void:
	if not Run.active:
		Run.start_run()
	map_view.show_stage(Run.stage)
	map_clip.gui_input.connect(_on_map_input)
	board_button.pressed.connect(_board)
	select_line(-1)
	summary.text = ""
	_set_scroll(0.0)
	# Hold on the Last Stop, then glide down to where the lines start.
	pan_tween = create_tween()
	pan_tween.tween_interval(PAN_HOLD_SECONDS)
	pan_tween.tween_method(_set_scroll, 0.0, max_scroll(), PAN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pan_tween.tween_callback(_end_pan)

func max_scroll() -> float:
	return maxf(map_view.content_height() - map_clip.size.y, 0.0)

func _set_scroll(value: float) -> void:
	scroll = clampf(value, 0.0, max_scroll())
	map_view.position.y = -roundf(scroll)  # whole pixels

func _end_pan() -> void:
	if not panning:
		return
	panning = false
	if pan_tween:
		pan_tween.kill()
	_set_scroll(max_scroll())
	select_line(map_view.selected)

func _on_map_input(event: InputEvent) -> void:
	if panning:
		if (event is InputEventMouseButton and event.pressed) or event is InputEventScreenTouch:
			_end_pan()
			map_clip.accept_event()
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_set_scroll(scroll - WHEEL_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				_set_scroll(scroll + WHEEL_STEP)
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					pressing = true
					dragging = false
					press_position = event.position
				elif pressing:
					pressing = false
					if not dragging:  # a tap: select the line under it
						var line := map_view.line_at(event.position + Vector2(0, scroll))
						if line >= 0:
							select_line(line)
		map_clip.accept_event()
	elif event is InputEventMouseMotion and pressing:
		if dragging or event.position.distance_to(press_position) > DRAG_THRESHOLD:
			dragging = true
			_set_scroll(scroll - event.relative.y)
		map_clip.accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if panning:
		_end_pan()
		get_viewport().set_input_as_handled()
		return
	match event.physical_keycode:
		KEY_UP, KEY_W:
			_set_scroll(scroll - KEY_STEP)
		KEY_DOWN, KEY_S:
			_set_scroll(scroll + KEY_STEP)
		KEY_ENTER, KEY_KP_ENTER:
			if not event.echo and not board_button.disabled:
				_board()
		_:
			var index: int = event.physical_keycode - KEY_1
			if event.echo or index < 0 or index >= Run.stage.lines.size():
				return
			select_line(index)
	get_viewport().set_input_as_handled()

func select_line(index: int) -> void:
	map_view.select(index)
	board_button.disabled = index < 0 or panning
	if index < 0:
		summary.text = "TAP A LINE TO SEE ITS STOPS  ·  DRAG TO SCROLL"
		board_button.text = "CHOOSE A LINE"
		_style_button(Color(0.3, 0.3, 0.32), Color(0.75, 0.75, 0.78))
		return
	var line := Run.stage.lines[index]
	summary.text = "%s LINE  ·  %d STOPS TO THE LAST STOP\n%s" % [line.bullet, line.length(), _describe(index)]
	board_button.text = "BOARD THE %s" % line.bullet
	_style_button(line.color, line.text_color)

# "3 BATTLE · 1 ELITE · 2 EVENT · 1 SHOP · 1 UNKNOWN" plus any transfers.
func _describe(index: int) -> String:
	var line := Run.stage.lines[index]
	var counts := {}
	var unknown := 0
	var transfers := PackedStringArray()
	for depth in line.length():
		var station := line.stations[depth]
		if station.hidden:
			unknown += 1
		else:
			counts[station.kind] = counts.get(station.kind, 0) + 1
		if station.is_transfer():
			var other: int = station.line_indices[0] if station.line_indices[1] == index else station.line_indices[1]
			transfers.append("%s AT %s" % [Run.stage.lines[other].bullet, station.display_name.to_upper()])
	var parts := PackedStringArray()
	for kind in KIND_WORDS:
		if counts.has(kind):
			parts.append("%d %s" % [counts[kind], KIND_WORDS[kind]])
	if unknown:
		parts.append("%d UNKNOWN" % unknown)
	var text := "  ·  ".join(parts)
	if not transfers.is_empty():
		text += "\nTRANSFER TO " + ", ".join(transfers)
	return text

func _style_button(background: Color, text_color: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = background.lightened(0.1) if state == "hover" else background
		style.set_corner_radius_all(4)
		board_button.add_theme_stylebox_override(state, style)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		board_button.add_theme_color_override(color_name, text_color)

# The route is locked in; ride to the first stop.
func _board() -> void:
	if map_view.selected < 0 or panning:
		return
	board_button.disabled = true
	Run.board(map_view.selected)
