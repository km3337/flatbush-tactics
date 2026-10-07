extends FTAmmoMod

## Sets the enemy on fire: `tick_damage` every `tick_seconds`, `ticks` times.
## Hitting a burning enemy again restarts the burn.

@export var tick_damage := 1
@export var tick_seconds := 1.5
@export var ticks := 2

func on_hit(_battle: FTBattle, enemy: FTEnemy) -> void:
	enemy.apply_burn(tick_damage, tick_seconds, ticks)
