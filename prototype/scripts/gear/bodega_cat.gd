extends FTGear

## The first hit you take each battle does no damage.

var used := false

func on_battle_start(_battle: FTBattle) -> void:
	used = false

func modify_damage_taken(_battle: FTBattle, amount: int) -> int:
	if used or amount <= 0:
		return amount
	used = true
	triggered.emit()
	return 0
