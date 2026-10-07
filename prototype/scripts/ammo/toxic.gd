extends FTAmmoMod

## Adds toxic stacks. Your next shot on that enemy deals +1 damage per stack
## and clears them. A toxic shot spends the old stacks, then adds its own.

@export var stacks := 1

func on_hit(_battle: FTBattle, enemy: FTEnemy) -> void:
	enemy.add_toxic(stacks)
