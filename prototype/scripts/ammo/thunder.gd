extends FTAmmoMod

## The hit arcs to the nearest other enemy for `chain_damage`. Chain damage
## isn't a shot: it doesn't counter or spend toxic stacks.

@export var chain_damage := 1
@export var arc_color := Color(0.6, 0.85, 1.0)

func on_hit(battle: FTBattle, enemy: FTEnemy) -> void:
	var from := enemy.get_global_rect().get_center()
	var target: FTEnemy = null
	var best := INF
	for other in battle.director.enemies:
		if other == enemy or not other.alive:
			continue
		var distance := from.distance_to(other.get_global_rect().get_center())
		if distance < best:
			best = distance
			target = other
	if target == null:
		return
	_draw_arc(battle, from, target.get_global_rect().get_center())
	target.take_damage(chain_damage)

# Placeholder arc: a line between the two enemies that fades out.
func _draw_arc(battle: FTBattle, from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = arc_color
	var offset := battle.director.global_position
	line.points = [from - offset, (from + to) / 2.0 - offset + Vector2(randf_range(-8, 8), randf_range(-8, 8)), to - offset]
	battle.director.add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.25)
	tween.tween_callback(line.queue_free)
