class_name FTEncounter
extends Resource

## A hand-authored battle: a sequence of waves. Cleared once every wave has
## arrived and every enemy is dead. `tier` is for picking encounters for stops
## on the route later.

enum Tier { EASY, NORMAL, ELITE, BOSS }

@export var display_name := "Encounter"
@export var tier := Tier.NORMAL
@export var waves: Array[FTWave] = []
