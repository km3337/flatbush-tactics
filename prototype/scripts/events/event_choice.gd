class_name FTEventChoice
extends Resource

## One button on an event. Picking it rolls one of `outcomes` by weight.

@export var label := "Choice"
## Disabled (with "NO CASH") unless the player has at least this much money.
@export var requires_money := 0
@export var outcomes: Array[FTEventOutcome] = []

func roll(rng: RandomNumberGenerator) -> FTEventOutcome:
	var weights := PackedFloat32Array()
	for outcome in outcomes:
		weights.append(outcome.weight)
	return outcomes[rng.rand_weighted(weights)]
