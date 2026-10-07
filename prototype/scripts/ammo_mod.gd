class_name FTAmmoMod
extends Resource

## One kind of round in a freelancer's arsenal. The base class is a plain
## round with no effect; subclasses override `on_hit`. Rounds are shared
## templates (the arsenal can hold the same one many times), so any state
## lives on the enemy, not here. Tunable numbers are @exports on subclasses.

@export var id: StringName = &"plain"
@export var display_name := "Plain"
@export_multiline var description := "No effect."
@export var rarity := FTGear.Rarity.COMMON
## Round colour in the ammo row, and the placeholder icon colour.
@export var color := Color(0.92, 0.9, 0.82)
@export var abbreviation := "PL"
@export var icon: Texture2D

## Called after the round's shot damage has landed (the enemy may be dead).
func on_hit(_battle: FTBattle, _enemy: FTEnemy) -> void:
	pass
