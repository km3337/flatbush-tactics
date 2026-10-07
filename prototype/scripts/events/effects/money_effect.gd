class_name FTMoneyEffect
extends FTEventEffect

## Gain or spend money: a random amount in `amount` (negative = spend). You
## can't go below $0; if you can't cover it, you pay everything you have.

@export var amount := Vector2i(-10, -5)

func apply() -> String:
	var roll := Run.rng.randi_range(amount.x, amount.y)
	if roll >= 0:
		Run.money += roll
		return "+$%d" % roll
	var paid := mini(-roll, Run.money)
	Run.money -= paid
	return "-$%d%s" % [paid, " (all you had)" if paid < -roll else ""]
