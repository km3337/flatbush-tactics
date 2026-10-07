extends FTAmmoMod

## Slows the enemy for `seconds`: its wind-up runs at `windup_speed` (0.5 =
## takes twice as long) and it stops swaying, so counters are easier.

@export var seconds := 3.0
@export var windup_speed := 0.5

func on_hit(_battle: FTBattle, enemy: FTEnemy) -> void:
	enemy.apply_freeze(seconds, windup_speed)
