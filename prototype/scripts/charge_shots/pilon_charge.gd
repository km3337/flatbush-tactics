extends FTChargeShot

## Ali's charge shot: always sets off the Pilon Cannon's explosion, with the
## gear's own radius and damage. If Ali still owns the gear, its icon pulses.

const PILON_CANNON: FTGear = preload("res://gear/pilon_cannon.tres")

func on_hit(battle: FTBattle, enemy: FTEnemy) -> void:
	for g in Run.gear:
		if g.id == PILON_CANNON.id:
			g.explode(battle, enemy)
			return
	PILON_CANNON.explode(battle, enemy)
