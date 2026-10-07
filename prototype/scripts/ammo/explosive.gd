extends FTAmmoMod

## The hit explodes: every other enemy within `radius` pixels of the target
## takes `splash_damage`.

@export var radius := 80.0
@export var splash_damage := 1
@export var blast_color := Color(1.0, 0.6, 0.2)

func on_hit(battle: FTBattle, enemy: FTEnemy) -> void:
	FTBlast.explode(battle, enemy, radius, splash_damage, blast_color)
