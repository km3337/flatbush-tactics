extends FTGear

## Every 3rd counter heals 1 HP. The count carries across battles.

@export var counters_needed := 3
var counters := 0

func on_counter(battle: FTBattle, _enemy: FTEnemy) -> void:
	counters += 1
	if counters < counters_needed:
		return
	counters = 0
	battle.player.heal(1)
	triggered.emit()
