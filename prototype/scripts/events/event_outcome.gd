class_name FTEventOutcome
extends Resource

## One possible result of a choice: text to show, then effects in order.

@export var weight := 1.0
@export_multiline var text := ""
@export var effects: Array[FTEventEffect] = []

## Applies every effect; returns the lines to show under the text
## (e.g. "-$14", "-2 HP", "GEAR: Walkman").
func apply() -> PackedStringArray:
	var lines := PackedStringArray()
	for effect in effects:
		var line := effect.apply()
		if line != "":
			lines.append(line)
	return lines
