class_name FTStatGear
extends FTGear

## Data-only gear that changes one stat: value * multiply + add.

@export var stat: StringName = &""
@export var multiply := 1.0
@export var add := 0.0

func modify_stat(s: StringName, value: float) -> float:
	if s == stat:
		return value * multiply + add
	return value
