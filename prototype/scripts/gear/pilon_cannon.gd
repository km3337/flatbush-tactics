extends FTGear

## Ali's signature gear: each shot that hits has a `chance` to explode,
## dealing `splash_damage` to every other enemy within `radius` pixels.

@export var chance := 0.15
@export var radius := 80.0
@export var splash_damage := 1
@export var blast_color := Color(0.55, 0.85, 1.0)

func on_shot_hit(battle: FTBattle, enemy: FTEnemy) -> void:
	if Run.rng.randf() >= chance:
		return
	triggered.emit()
	FTBlast.explode(battle, enemy, radius, splash_damage, blast_color)
