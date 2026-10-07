class_name FTStageMapView
extends Control

## Draws a stage map in the style of a printed MTA map, inside a 360x640
## frame: one vertical coloured line per train line, stop dots with
## placeholder icons, white transfer bars joining shared stations, route
## bullets at the bottom (where you start) and the Last Stop at the top. The
## selected line stays bright, with station names in a column on the right;
## the others dim. Tap near a line (or its bullet) to emit `line_tapped`.
## Icons come from FTStopIcons (drawn in code until there's art).

signal line_tapped(index: int)

const LAST_STOP_Y := 62.0
const TOP_STOP_Y := 128.0
const BOTTOM_STOP_Y := 468.0
const BULLET_Y := 504.0
const FIRST_COLUMN_X := 46.0
const COLUMN_GAP := 58.0
const NAME_X := 196.0
const LINE_WIDTH := 7.0
const DOT_RADIUS := 10.0
const BULLET_RADIUS := 15.0
const TAP_DISTANCE := 26.0
const INK := Color(0.08, 0.08, 0.09)
const PAPER := Color(0.96, 0.94, 0.89)
const DIM_ALPHA := 0.28

var stage: FTStageMap
var selected := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func show_stage(map: FTStageMap) -> void:
	stage = map
	queue_redraw()

func select(index: int) -> void:
	selected = index
	queue_redraw()

func column_x(line: int) -> float:
	return FIRST_COLUMN_X + line * COLUMN_GAP

func row_y(depth: int) -> float:
	var n := stage.lines[0].length()
	return lerpf(BOTTOM_STOP_Y, TOP_STOP_Y, float(depth) / float(maxi(n - 1, 1)))

func last_stop_position() -> Vector2:
	return Vector2((column_x(0) + column_x(stage.lines.size() - 1)) / 2.0, LAST_STOP_Y)

func _gui_input(event: InputEvent) -> void:
	if stage == null or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var pos: Vector2 = event.position
	if pos.y < LAST_STOP_Y or pos.y > BULLET_Y + BULLET_RADIUS + 8.0:
		return
	for i in stage.lines.size():
		if absf(pos.x - column_x(i)) <= TAP_DISTANCE:
			line_tapped.emit(i)
			accept_event()
			return

func _alpha(line: int) -> float:
	return 1.0 if selected < 0 or selected == line else DIM_ALPHA

func _draw() -> void:
	if stage == null:
		return
	var order := range(stage.lines.size())
	if selected >= 0:  # selected line draws on top
		order.erase(selected)
		order.append(selected)
	for i in order:
		_draw_line_path(i)
	_draw_last_stop()
	for t in stage.transfers():
		_draw_transfer_bar(t)
	for i in order:
		var line := stage.lines[i]
		for depth in line.length():
			_draw_stop(line.stations[depth], Vector2(column_x(i), row_y(depth)), _alpha(i))
		_draw_bullet(line, Vector2(column_x(i), BULLET_Y), _alpha(i))
	if selected >= 0:
		_draw_names(selected)

func _draw_line_path(i: int) -> void:
	var line := stage.lines[i]
	var color := Color(line.color, _alpha(i))
	var x := column_x(i)
	var top := row_y(line.length() - 1)
	var end := last_stop_position()
	# Straight up through the stops, then bend in to the Last Stop.
	var points := PackedVector2Array([
		Vector2(x, BULLET_Y), Vector2(x, top), Vector2(x, top - 22.0),
		Vector2(end.x + (x - end.x) * 0.25, end.y + 22.0), end + Vector2(0, 14),
	])
	draw_polyline(points, color, LINE_WIDTH, true)

func _draw_last_stop() -> void:
	var pos := last_stop_position()
	var rect := Rect2(pos - Vector2(52, 14), Vector2(104, 28))
	draw_rect(rect, INK)
	var font := get_theme_default_font()
	draw_string(font, Vector2(rect.position.x, pos.y + 5), "LAST STOP", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 13, PAPER)

# MTA-style transfer connector (white with a black outline) joining the
# shared station's dots on its two lines. It arches above the row so it
# doesn't run through a stop on a line in between.
func _draw_transfer_bar(station: FTStation) -> void:
	var xs := station.line_indices.map(func(li): return column_x(li))
	var y := row_y(station.depth)
	var alpha := 1.0 if selected < 0 or selected in station.line_indices else DIM_ALPHA
	var top := y - DOT_RADIUS - 8.0
	var path := PackedVector2Array([Vector2(xs.min(), y), Vector2(xs.min(), top), Vector2(xs.max(), top), Vector2(xs.max(), y)])
	draw_polyline(path, Color(INK, alpha), 8.0)
	draw_polyline(path, Color(Color.WHITE, alpha), 4.0)

func _draw_stop(station: FTStation, pos: Vector2, alpha: float) -> void:
	draw_circle(pos, DOT_RADIUS, Color(Color.WHITE, alpha))
	draw_arc(pos, DOT_RADIUS, 0, TAU, 24, Color(INK, alpha), 2.0, true)
	FTStopIcons.draw(self, station, pos, alpha)

func _draw_bullet(line: FTLine, pos: Vector2, alpha: float) -> void:
	FTStopIcons.draw_bullet(self, line, pos, BULLET_RADIUS, alpha)

# Names of the selected line's stops, one per row, plus a small bullet for
# the other line at transfer stations.
func _draw_names(i: int) -> void:
	var line := stage.lines[i]
	var font := get_theme_default_font()
	for depth in line.length():
		var station := line.stations[depth]
		var y := row_y(depth)
		draw_line(Vector2(column_x(i) + DOT_RADIUS + 2, y), Vector2(NAME_X - 4, y), Color(line.color, 0.5), 1.0)
		draw_string(font, Vector2(NAME_X, y + 4), station.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
		if station.is_transfer():
			var other: int = station.line_indices[0] if station.line_indices[1] == i else station.line_indices[1]
			var width := font.get_string_size(station.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			var bullet_pos := Vector2(NAME_X + width + 12, y)
			draw_circle(bullet_pos, 7, stage.lines[other].color)
			draw_string(font, bullet_pos + Vector2(-7, 4), stage.lines[other].bullet, HORIZONTAL_ALIGNMENT_CENTER, 14, 10, stage.lines[other].text_color)
