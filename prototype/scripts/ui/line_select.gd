class_name FTLineSelect
extends Control

## Stage start: pick a train line on the stage map, then board it. Tapping a
## line (or pressing 1/2/3) highlights it and shows its summary; BOARD locks
## the line in. Starts a run if none is active.

const KIND_WORDS := {
	FTStation.Kind.BATTLE: "BATTLE",
	FTStation.Kind.ELITE: "ELITE",
	FTStation.Kind.EVENT: "EVENT",
	FTStation.Kind.SHOP: "SHOP",
}

@onready var map_view: FTStageMapView = %MapView
@onready var summary: Label = %Summary
@onready var board_button: Button = %BoardButton

func _ready() -> void:
	if not Run.active:
		Run.start_run()
	map_view.show_stage(Run.stage)
	map_view.line_tapped.connect(select_line)
	board_button.pressed.connect(_board)
	select_line(-1)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var index: int = event.physical_keycode - KEY_1
	if index >= 0 and index < Run.stage.lines.size():
		select_line(index)
		get_viewport().set_input_as_handled()
	elif event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] and not board_button.disabled:
		_board()
		get_viewport().set_input_as_handled()

func select_line(index: int) -> void:
	map_view.select(index)
	board_button.disabled = index < 0
	if index < 0:
		summary.text = "TAP A LINE TO SEE ITS STOPS"
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
	if map_view.selected < 0:
		return
	board_button.disabled = true
	Run.board(map_view.selected)
