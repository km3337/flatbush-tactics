extends FTSimpleScreen

## The Last Stop is beaten: the run is won. Run.complete_stop() has already
## saved the record (FTRecords). NEW RUN starts over at Line Select.

func _setup() -> void:
	title_color = Color(1.0, 0.85, 0.2)
	title = "LAST STOP\nSTAGE CLEAR"
	var lines := PackedStringArray()
	lines.append("Run won on the %s with %d/%d HP." % [Run.current_line().bullet, Run.current_hp(), Run.max_hp()])
	lines.append("%d stops cleared." % Run.stops_cleared)
	if not Run.gear.is_empty():
		lines.append("\nWinning gear:\n" + ", ".join(Run.gear.map(func(g: FTGear): return g.display_name)))
	var rounds := {}
	for mod in Run.arsenal:
		rounds[mod.display_name] = rounds.get(mod.display_name, 0) + 1
	var parts := PackedStringArray()
	for name in rounds:
		parts.append("%s x%d" % [name, rounds[name]])
	lines.append("\nArsenal:\n" + ", ".join(parts))
	lines.append("\nRecord saved (%d win%s so far)." % [FTRecords.load_wins().size(), "" if FTRecords.load_wins().size() == 1 else "s"])
	body = "\n".join(lines)
	button_text = "NEW RUN"

func _on_button() -> void:
	Run.new_run()
