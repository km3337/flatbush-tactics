class_name FTMaxHealthEffect
extends FTEventEffect

## Raise max HP for the rest of the run, and heal by the same amount.

@export var amount := 1

func apply() -> String:
	var hp_before := Run.current_hp()
	Run.bonus_max_hp += amount
	Run.hp = mini(hp_before + amount, Run.max_hp())
	return "+%d MAX HP" % amount
