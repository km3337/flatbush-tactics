class_name FTHealthEffect
extends FTEventEffect

## Heal or hurt: a random amount in `amount` (negative = damage). Damage
## never takes you below `min_hp_left`, so events can't end a run.

@export var amount := Vector2i(-2, -1)
@export var min_hp_left := 1

func apply() -> String:
	var roll := Run.rng.randi_range(amount.x, amount.y)
	var before := Run.current_hp()
	var after := clampi(before + roll, mini(min_hp_left, before), Run.max_hp())
	Run.hp = after
	var change := after - before
	if change == 0:
		return ""
	return "%+d HP" % change
