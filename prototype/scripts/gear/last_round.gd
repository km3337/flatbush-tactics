extends FTGear

## The last round in the magazine deals double damage.

func modify_shot_damage(battle: FTBattle, _enemy: FTEnemy, _countered: bool, damage: int) -> int:
	# Ammo is already spent when the shot lands, so 0 means this was the last.
	if battle.weapon.ammo != 0:
		return damage
	triggered.emit()
	return damage * 2
