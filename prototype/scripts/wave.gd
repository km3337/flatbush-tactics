class_name FTWave
extends Resource

## A group of enemies that arrive together. The first wave of an encounter
## always starts immediately; later waves wait for their trigger.

enum Trigger {
	## Every enemy from earlier waves is dead.
	PREVIOUS_CLEARED,
	## No more than `trigger_value` enemies are still alive.
	ALIVE_AT_MOST,
	## `trigger_value` seconds after the previous wave arrived.
	AFTER_SECONDS,
}

@export var spawns: Array[FTSpawn] = []
@export var trigger := Trigger.PREVIOUS_CLEARED
@export var trigger_value := 0.0
