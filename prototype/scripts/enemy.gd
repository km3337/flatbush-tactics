class_name FTEnemy
extends ColorRect

## Placeholder enemy: a red rectangle that can be shot, periodically winds up
## (turns orange) and fires at the player, and respawns after dying.
## Hitting it during the wind-up is a counter; staggerable enemies are then
## stunned (grey): the attack is cancelled and they can't move or attack.
## Non-staggerable enemies take the hit but still fire.

signal attacked

@export var max_health := 3
@export var attack_interval := Vector2(2.5, 5.0)
@export var windup_seconds := 0.7
@export var respawn_seconds := 2.5
## Horizontal patrol distance in pixels; 0 stands still.
@export var sway := 0.0
@export var sway_speed := 1.2
@export var base_color := Color(0.82, 0.18, 0.2)
@export var windup_color := Color(1.0, 0.62, 0.1)
@export var staggerable := false
@export var stun_seconds := 1.5
@export var stun_color := Color(0.45, 0.45, 0.5)

var health := 0
var alive := false
var winding_up := false
var attack_timer := 0.0
var respawn_timer := 0.0
var stun_timer := 0.0
var home := Vector2.ZERO
var time := 0.0
var health_label: Label
var stars: Array[Label] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	home = position
	time = randf() * TAU
	health_label = Label.new()
	health_label.add_theme_font_size_override("font_size", 16)
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.position = Vector2(0, -24)
	health_label.size = Vector2(size.x, 20)
	add_child(health_label)
	for i in 3:
		var star := Label.new()
		star.text = "★"
		star.add_theme_font_size_override("font_size", 20)
		star.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
		star.visible = false
		add_child(star)
		stars.append(star)
	_spawn()

func _process(delta: float) -> void:
	if not alive:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_spawn()
		return
	if stun_timer > 0.0:
		stun_timer -= delta
		_orbit_stars()
		if stun_timer <= 0.0:
			color = base_color
			_set_stars_visible(false)
			_reset_attack_timer()
		return
	if sway > 0.0:
		time += delta
		position.x = home.x + sin(time * sway_speed) * sway
	attack_timer -= delta
	if attack_timer > 0.0:
		return
	if winding_up:
		winding_up = false
		color = base_color
		attacked.emit()
		_reset_attack_timer()
	else:
		winding_up = true
		color = windup_color
		attack_timer = windup_seconds

func contains(screen_position: Vector2) -> bool:
	return alive and get_global_rect().has_point(screen_position)

## Returns true if the hit was a counter (landed during the wind-up).
func take_hit() -> bool:
	if not alive:
		return false
	var countered := winding_up
	# Only staggerable enemies lose their attack; others still fire.
	if countered and staggerable:
		winding_up = false
		stun_timer = stun_seconds
		color = stun_color
		_set_stars_visible(true)
		_orbit_stars()
	health -= 1
	_update_health_label()
	modulate = Color(3, 3, 3)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.12)
	if health <= 0:
		_die()
	return countered

func _spawn() -> void:
	health = max_health
	alive = true
	winding_up = false
	stun_timer = 0.0
	_set_stars_visible(false)
	visible = true
	color = base_color
	modulate = Color.WHITE
	_update_health_label()
	_reset_attack_timer()

func _die() -> void:
	alive = false
	winding_up = false
	stun_timer = 0.0
	_set_stars_visible(false)
	respawn_timer = respawn_seconds
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): visible = false)

func _reset_attack_timer() -> void:
	attack_timer = randf_range(attack_interval.x, attack_interval.y)

func _update_health_label() -> void:
	health_label.text = "●".repeat(health)

# Placeholder daze: stars circling above the head while stunned.
func _orbit_stars() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var center := Vector2(size.x / 2.0, -46.0)
	for i in stars.size():
		var angle := t * 4.0 + TAU * i / stars.size()
		var offset := Vector2(cos(angle) * 30.0, sin(angle) * 9.0)
		stars[i].position = center + offset - stars[i].size / 2.0

func _set_stars_visible(on: bool) -> void:
	for star in stars:
		star.visible = on
