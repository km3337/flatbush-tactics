class_name FTAmbushEffect
extends FTEventEffect

## The next battle spawns extra enemies (added to its first wave).

@export var extra_enemies := 1

func apply() -> String:
	Run.extra_enemies_next_battle += extra_enemies
	return ""  # a surprise: hinted in the outcome text, revealed in the fight
