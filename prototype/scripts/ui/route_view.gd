class_name FTRouteView
extends Control

## The "Stopping at" list on the route screen, styled after the MTA countdown
## screens: one vertical line in the route's colour, a dot per stop, the
## current stop in a white pill, stop icons on the left and transfer bullets
## after the name. Stops already passed collapse into a "Previous stops" row.
## Detour stops still to play show in orange before the line resumes.

const ROW_HEIGHT := 28.0
const ICON_X := 40.0
const LINE_X := 74.0
const NAME_X := 92.0
const DOT_RADIUS := 6.0
const TEXT := Color(0.93, 0.95, 1.0)
const DIM_TEXT := Color(0.6, 0.66, 0.8)
const DETOUR := Color(1.0, 0.55, 0.15)
const PILL_TEXT := Color(0.05, 0.1, 0.2)

## Rows: {station, kind: "previous" | "current" | "detour" | "next"}.
func rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var line := Run.current_line()
	if Run.route_depth > 0:
		result.append({"kind": "previous"})
	if Run.current_station:
		result.append({"kind": "current", "station": Run.current_station})
	for station in Run.detour_queue:
		result.append({"kind": "detour", "station": station})
	for depth in range(Run.route_depth + 1, line.stations.size()):
		result.append({"kind": "next", "station": line.stations[depth]})
	return result

func _draw() -> void:
	var line := Run.current_line()
	if line == null:
		return
	var font := get_theme_default_font()
	var list := rows()
	var y0 := ROW_HEIGHT / 2.0
	# The route line runs through every row.
	draw_line(Vector2(LINE_X, y0), Vector2(LINE_X, y0 + (list.size() - 1) * ROW_HEIGHT), line.color, 6.0)
	for i in list.size():
		var row: Dictionary = list[i]
		var y := y0 + i * ROW_HEIGHT
		if row.kind == "previous":
			for k in 2:  # chevrons, like the countdown screen
				var cy := y - 5 + k * 6
				draw_polyline(PackedVector2Array([Vector2(LINE_X - 5, cy), Vector2(LINE_X, cy + 4), Vector2(LINE_X + 5, cy)]), TEXT, 2.0)
			draw_string(font, Vector2(NAME_X, y + 4), "Previous stops", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, DIM_TEXT)
			continue
		var station: FTStation = row.station
		var color := DETOUR if row.kind == "detour" else TEXT
		FTStopIcons.draw(self, station, Vector2(ICON_X, y), 1.0, color)
		if row.kind == "detour":
			draw_line(Vector2(LINE_X, y - ROW_HEIGHT / 2.0), Vector2(LINE_X, y + ROW_HEIGHT / 2.0), DETOUR, 6.0)
		draw_circle(Vector2(LINE_X, y), DOT_RADIUS, Color.WHITE)
		var name := station.display_name
		if row.kind == "detour":
			name = "Detour: " + name
		var text_color := color
		if row.kind == "current":
			var width := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			var pill := Rect2(Vector2(NAME_X - 6, y - 10), Vector2(width + 12, 20))
			draw_rect(pill, Color.WHITE)
			text_color = PILL_TEXT
		draw_string(font, Vector2(NAME_X, y + 5), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, text_color)
		if station.is_transfer() and station.kind != FTStation.Kind.LAST_STOP:
			var other: int = station.line_indices[0] if station.line_indices[1] == Run.line_index else station.line_indices[1]
			var width := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			FTStopIcons.draw_bullet(self, Run.stage.lines[other], Vector2(NAME_X + width + 16, y), 8.0)
