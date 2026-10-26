class_name FTLobProjectile
extends Node2D

## A lobbed attack (e.g. the Heavy's). It appears when the enemy starts its
## wind-up and circles around it (`orbit()`), then gets flung out when the
## enemy attacks (`launch()`): it arcs over the top of the screen and falls
## toward the player, growing as it gets closer. One shot pops it at any
## point (`pop()`); popping it while it's still circling cancels the attack.
## If it reaches the player it emits `landed` and deals `damage` even behind
## cover. Lives on a layer above the cover, so it stays visible (and sharp)
## while the player is ducked.
## Charged variant (`charge`): sits in front of the thrower and swells over the
## wind-up instead of circling (the Dark Droid's).
## The thrower's type sets size, colour, and whether it can be shot in flight.
## Placeholder drawn in code: a goo blob with a dark outline.

signal landed(projectile: FTLobProjectile)

const ORBIT_RADIUS := 6.0
## A charged lob swells from ORBIT_RADIUS to this over the wind-up.
const CHARGE_RADIUS := 16.0
## Radius when it reaches the player. It grows with perspective (size ~
## 1/distance), so slowly at first and fast in the last moments.
const END_RADIUS := 56.0
const ORBIT_SPEED := 7.0  # radians per second
const SHINE := Color(1.0, 0.92, 0.95)
const OUTLINE := Color(0.12, 0.04, 0.08)

var fill := Color(0.95, 0.45, 0.62)
var sheet: Texture2D
var sheet_frames := 1
var fps := 12.0
## Multiplies every radius.
var size_scale := 1.0
var charge := false
var charge_seconds := 1.0
var shootable_in_flight := true
var damage := 2
var duration := 1.5
var elapsed := 0.0
var radius := ORBIT_RADIUS
var popped := false
var launched := false
var _owner: FTEnemy
var _angle := 0.0
var _from := Vector2.ZERO
var _apex := Vector2.ZERO
var _to := Vector2.ZERO
var _start_radius := ORBIT_RADIUS

## Circle around (or charge in front of) `enemy` until launched, styled by
## its type.
func orbit(enemy: FTEnemy) -> void:
	_owner = enemy
	var t := enemy.type
	charge = t.lob_charge
	charge_seconds = t.windup_seconds
	size_scale = t.lob_size
	fill = t.lob_color
	sheet = t.lob_sheet
	sheet_frames = maxi(t.lob_sheet_frames, 1)
	fps = t.lob_fps
	shootable_in_flight = t.lob_shootable_in_flight
	radius = ORBIT_RADIUS * size_scale
	_angle = randf() * TAU
	position = _orbit_point()

## The enemy that's holding / threw it.
func thrower() -> FTEnemy:
	return _owner if is_instance_valid(_owner) else null

## Fling it from where it is toward `to` (a screen position: the player).
func launch(to: Vector2, seconds: float, hit_damage: int) -> void:
	launched = true
	_from = position
	_to = to
	duration = seconds
	damage = hit_damage
	elapsed = 0.0
	_start_radius = radius
	# Control point well above both ends, so it rises then falls toward you.
	_apex = Vector2((_from.x + to.x) / 2.0, maxf(minf(_from.y, to.y) - 220.0, 30.0))

func _process(delta: float) -> void:
	if popped:
		return
	elapsed += delta
	if not launched:
		if not is_instance_valid(_owner) or not _owner.alive:
			queue_free()  # the thrower is gone: it fizzles
			return
		_angle += ORBIT_SPEED * delta
		if charge:
			var c := minf(elapsed / maxf(charge_seconds, 0.01), 1.0)
			radius = roundf(lerpf(ORBIT_RADIUS, CHARGE_RADIUS, c) * size_scale)
		position = _orbit_point()
		queue_redraw()
		return
	var t := minf(elapsed / duration, 1.0)
	var a := _from.lerp(_apex, t)
	var b := _apex.lerp(_to, t)
	position = a.lerp(b, t).round()
	# Distance shrinks linearly; on-screen size is inversely proportional.
	var distance := lerpf(1.0, _start_radius / (END_RADIUS * size_scale), t)
	radius = roundf(_start_radius / distance)
	queue_redraw()
	if t >= 1.0:
		landed.emit(self)
		queue_free()

# A flattened circle around the thrower's body, so it reads as going around
# it in depth.
func _orbit_point() -> Vector2:
	var rect := _owner.get_global_rect()
	if charge:  # in front of its body, a little low
		return (rect.get_center() + Vector2(0, rect.size.y * 0.2)).round()
	var r := maxf(rect.size.x, rect.size.y) * 0.5 + 6.0
	return (rect.get_center() + Vector2(cos(_angle) * r, sin(_angle) * r * 0.4)).round()

## Whether a shot at `point` hits it (a little forgiving).
func contains(point: Vector2) -> bool:
	if launched and not shootable_in_flight:
		return false
	return not popped and position.distance_to(point) <= radius + 4.0

## Shot down: burst and disappear.
func pop() -> void:
	popped = true
	var tween := create_tween()
	tween.tween_method(func(r: float): radius = r; queue_redraw(), radius, radius * 2.0, 0.15)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)

func _draw() -> void:
	if popped:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 24, SHINE, 2.0)
		return
	if sheet:
		var cell := sheet.get_height()
		var frame := int(elapsed * fps) % sheet_frames
		draw_texture_rect_region(sheet, Rect2(-radius, -radius, radius * 2.0, radius * 2.0), Rect2(frame * cell, 0, cell, cell))
		return
	var wobble := 1.0 + 0.08 * sin(elapsed * 18.0)
	draw_circle(Vector2.ZERO, radius + 2.0, OUTLINE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(wobble, 2.0 - wobble))
	draw_circle(Vector2.ZERO, radius, fill)
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2(-radius * 0.35, -radius * 0.35).round(), maxf(radius * 0.25, 1.0), SHINE)
