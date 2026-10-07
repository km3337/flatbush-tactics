extends FTGear

## Counters deal 1 extra damage.

func modify_shot_damage(_battle: FTBattle, _enemy: FTEnemy, countered: bool, damage: int) -> int:
	if not countered:
		return damage
	triggered.emit()
	return damage + 1
