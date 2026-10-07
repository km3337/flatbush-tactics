class_name FTStageMap
extends Resource

## A generated stage: its lines, which all end at the shared Last Stop.
## Built by FTStageGenerator from the run's RNG.

@export var lines: Array[FTLine] = []
@export var last_stop: FTStation

## Every station once (transfer stations are on two lines). Excludes detour
## stops and the Last Stop.
func stations() -> Array[FTStation]:
	var result: Array[FTStation] = []
	for line in lines:
		for station in line.stations:
			if station != last_stop and station not in result:
				result.append(station)
	return result

## Stops on a line from `from_depth` up to the Last Stop, as text:
## "4 STOPS: 2 BATTLE · 1 ELITE · 1 UNKNOWN". Hidden stops count as unknown.
func summary(line_index: int, from_depth := 0) -> String:
	var line := lines[line_index]
	var counts := {}
	var unknown := 0
	for depth in range(from_depth, line.length()):
		var station := line.stations[depth]
		if station.hidden:
			unknown += 1
		else:
			counts[station.kind] = counts.get(station.kind, 0) + 1
	var parts := PackedStringArray()
	for kind in [FTStation.Kind.BATTLE, FTStation.Kind.ELITE, FTStation.Kind.EVENT, FTStation.Kind.SHOP]:
		if counts.has(kind):
			parts.append("%d %s" % [counts[kind], FTStation.Kind.keys()[kind]])
	if unknown:
		parts.append("%d UNKNOWN" % unknown)
	return "%d STOPS: %s" % [line.length() - from_depth, "  ·  ".join(parts)]

func transfers() -> Array[FTStation]:
	return stations().filter(func(s: FTStation): return s.is_transfer())

## Readable dump for debugging and test output, e.g.
## "Q  ⚔ Church Av > ? Beverley Rd [5] > ... > ■ Last Stop".
func describe() -> String:
	var out := PackedStringArray()
	for i in lines.size():
		var line := lines[i]
		var parts := PackedStringArray()
		for station in line.stations:
			var text := "%s %s" % [station.icon(), station.display_name]
			if station.hidden:
				text = "(cone) " + text
			if station.has_detour():
				text += " {detour: %d ?}" % station.detour_stops.size()
			if station.is_transfer() and station != last_stop:
				var other: int = station.line_indices[0] if station.line_indices[1] == i else station.line_indices[1]
				text += " [%s]" % lines[other].bullet
			parts.append(text)
		out.append("%-2s %s" % [line.bullet, " > ".join(parts)])
	return "\n".join(out)
