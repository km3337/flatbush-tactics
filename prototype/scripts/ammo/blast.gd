class_name FTBlast
extends RefCounted

## An explosion at an enemy: every other living enemy within `radius` pixels
## takes `damage`. Not a shot: no counters, no toxic spend. Used by the
## Explosive round and the Pilon Cannon gear.

static func explode(battle: FTBattle, enemy: FTEnemy, radius: float, damage: int, color: Color) -> void:
	var center := enemy.get_global_rect().get_center()
	_draw_blast(battle, center, radius, color)
	for other in battle.director.enemies.duplicate():
		if other != enemy and other.alive and not other.entering and center.distance_to(other.get_global_rect().get_center()) <= radius:
			other.take_damage(damage)

# Placeholder blast: a ring that grows and fades.
static func _draw_blast(battle: FTBattle, center: Vector2, radius: float, color: Color) -> void:
	var ring := Control.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.position = center - battle.director.global_position
	ring.draw.connect(func():
		var t: float = ring.get_meta("t", 0.0)
		ring.draw_arc(Vector2.ZERO, radius * (0.3 + 0.7 * t), 0, TAU, 32, Color(color, 1.0 - t), 4.0))
	battle.director.add_child(ring)
	var tween := ring.create_tween()
	tween.tween_method(func(t: float): ring.set_meta("t", t); ring.queue_redraw(), 0.0, 1.0, 0.3)
	tween.tween_callback(ring.queue_free)
