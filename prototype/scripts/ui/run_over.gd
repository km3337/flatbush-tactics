extends FTSimpleScreen

## The player went down. Shows where and what was lost; NEW RUN starts over
## at Line Select.

func _setup() -> void:
	background_color = Color(0.12, 0.03, 0.04)
	title_color = Color(0.95, 0.3, 0.3)
	title = "RUN OVER"
	var where := Run.current_station.display_name if Run.current_station else "the platform"
	var line := Run.current_line()
	var lines := PackedStringArray()
	lines.append("Went down at %s%s." % [where, " on the %s" % line.bullet if line else ""])
	lines.append("%d stop%s cleared." % [Run.stops_cleared, "" if Run.stops_cleared == 1 else "s"])
	if not Run.gear.is_empty():
		lines.append("\nGear lost:\n" + ", ".join(Run.gear.map(func(g: FTGear): return g.display_name)))
	body = "\n".join(lines)
	button_text = "NEW RUN"

func _on_button() -> void:
	Run.new_run()
