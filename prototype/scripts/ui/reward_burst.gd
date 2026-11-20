class_name FTRewardBurst
extends Node2D

## A one-shot spray of square pixels (sparks, coins' glints, debris) for the
## reward screen. Positions snap to whole pixels. Frees itself when every
## particle has faded. Cosmetic: uses the global RNG, never the run's.

var particles: Array[Dictionary] = []
var gravity := 260.0
var drag := 1.5

## `count` pixels from `at` (global), in `colors`, flying out at a speed
## between `speed.x` and `speed.y` px/s. `direction` + `spread` aim them
## (spread TAU = every way); `life` is how long the slowest lasts.
static func spawn(parent: Node, at: Vector2, colors: Array, count := 16, speed := Vector2(60, 160), life := 0.6, direction := Vector2.UP, spread := TAU, size := 2.0, gravity_px := 260.0) -> FTRewardBurst:
	var burst := FTRewardBurst.new()
	burst.gravity = gravity_px
	burst.z_index = 10
	for i in count:
		var angle := direction.angle() + randf_range(-spread / 2.0, spread / 2.0)
		var lifetime := life * randf_range(0.6, 1.0)
		burst.particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2.from_angle(angle) * randf_range(speed.x, speed.y),
			"life": lifetime,
			"max": lifetime,
			"color": colors[i % colors.size()],
			"size": size if randf() < 0.7 else size * 2.0,
		})
	parent.add_child(burst)
	burst.global_position = at.round()
	return burst

func _process(delta: float) -> void:
	var alive := false
	for p in particles:
		if p.life <= 0.0:
			continue
		alive = true
		p.life -= delta
		p.vel.y += gravity * delta
		p.vel *= maxf(0.0, 1.0 - drag * delta)
		p.pos += p.vel * delta
	if not alive:
		queue_free()
	queue_redraw()

func _draw() -> void:
	for p in particles:
		if p.life <= 0.0:
			continue
		var color: Color = p.color
		# Hold full brightness, then blink out over the last third.
		var left: float = p.life / p.max
		if left < 0.33 and int(left * 30.0) % 2 == 0:
			continue
		var s: float = p.size
		draw_rect(Rect2((p.pos - Vector2(s, s) / 2.0).round(), Vector2(s, s)), color)
