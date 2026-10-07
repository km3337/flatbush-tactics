class_name FTSpawn
extends Resource

## One enemy in a wave: what it is and which named spawn slot it stands in.

@export var enemy_type: FTEnemyType
## Must match a slot name on the FTEncounterDirector.
@export var slot: StringName = &""
