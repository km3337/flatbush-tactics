class_name FTPlayer
extends Node

## Player health. Shown as pips on the HUD; hitting 0 downs the player.

signal health_changed(current: int, maximum: int)
signal downed

@export var max_health := 5
## At or below this HP the portrait switches to its low-HP state.
@export var low_health_threshold := 2
var health := 0

func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)

func is_low() -> bool:
	return health <= low_health_threshold

func take_damage(amount := 1) -> void:
	if health <= 0:
		return
	health = max(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		downed.emit()
