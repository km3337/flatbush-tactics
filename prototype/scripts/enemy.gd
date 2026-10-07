class_name FTEnemy
extends ColorRect

## Placeholder enemy: a coloured rectangle that can be shot, periodically winds
## up (turns orange) and fires at the player. Stats come from its FTEnemyType;
## the FTEncounterDirector places it in a slot. On death it fades out, emits
## `died` and frees itself.
## Hitting it during the wind-up is a counter; staggerable enemies are then
## stunned (grey): the attack is cancelled and they can't move or attack.
## Non-staggerable enemies take the hit but still fire.
## Ammo modifiers put statuses on it (burn, toxic, freeze), listed under it.

signal attacked
signal died

const WINDUP_COLOR := Color(1.0, 0.62, 0.1)
const STUN_COLOR := Color(0.45, 0.45, 0.5)
const STATUS_COLORS := {"burn": "#ff7326", "toxic": "#73e640", "freeze": "#73ccff"}

var type: FTEnemyType
var slot: StringName = &""
var health := 0
var alive := false
var winding_up := false
var attack_timer := 0.0
var stun_timer := 0.0
var home := Vector2.ZERO
var time := 0.0
var health_label: Label
var status_label: RichTextLabel
var stars: Array[Label] = []
# Statuses from ammo modifiers.
var burn_ticks_left := 0
var burn_tick_timer := 0.0
var burn_tick_seconds := 1.5
var burn_damage := 0
var toxic_stacks := 0
var freeze_timer := 0.0
var freeze_windup_speed := 1.0

func _ready() -> void:
	if type == null:
		type = FTEnemyType.new()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	home = position
	time = randf() * TAU
	health_label = Label.new()
	health_label.add_theme_font_size_override("font_size", 11)
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.position = Vector2(0, -15)
	health_label.size = Vector2(size.x, 13)
	add_child(health_label)
	status_label = RichTextLabel.new()
	status_label.bbcode_enabled = true
	status_label.scroll_active = false
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.add_theme_font_size_override("normal_font_size", 9)
	status_label.position = Vector2(-10, size.y + 2)
	status_label.size = Vector2(size.x + 20, 14)
	add_child(status_label)
	for i in 3:
		var star := Label.new()
		star.text = "★"
		star.add_theme_font_size_override("font_size", 14)
		star.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
		star.visible = false
		add_child(star)
		stars.append(star)
	_spawn()

func _process(delta: float) -> void:
	if not alive:
		return
	_tick_statuses(delta)
	if not alive:
		return  # burned to death
	if stun_timer > 0.0:
		stun_timer -= delta
		_orbit_stars()
		if stun_timer <= 0.0:
			color = type.base_color
			_set_stars_visible(false)
			_reset_attack_timer()
		return
	var frozen := freeze_timer > 0.0
	if type.sway > 0.0 and not frozen:
		time += delta
		position.x = home.x + sin(time * type.sway_speed) * type.sway
	attack_timer -= delta * (freeze_windup_speed if winding_up and frozen else 1.0)
	if attack_timer > 0.0:
		return
	if winding_up:
		winding_up = false
		color = type.base_color
		attacked.emit()
		_reset_attack_timer()
	else:
		winding_up = true
		color = WINDUP_COLOR
		attack_timer = type.windup_seconds

func contains(screen_position: Vector2) -> bool:
	return alive and get_global_rect().has_point(screen_position)

## A shot from the player. Spends toxic stacks for bonus damage. Returns true
## if the hit was a counter (landed during the wind-up).
func take_hit(damage := 1) -> bool:
	if not alive:
		return false
	var countered := winding_up
	# Only staggerable enemies lose their attack; others still fire.
	if countered and type.staggerable:
		winding_up = false
		stun_timer = type.stun_seconds
		color = STUN_COLOR
		_set_stars_visible(true)
		_orbit_stars()
	damage += toxic_stacks
	toxic_stacks = 0
	take_damage(damage)
	return countered

## Damage that isn't a shot (burn ticks, thunder arcs): no counter, and toxic
## stacks are kept.
func take_damage(amount: int) -> void:
	if not alive:
		return
	health = max(health - amount, 0)
	_update_health_label()
	_update_status_label()
	modulate = Color(3, 3, 3)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.12)
	if health <= 0:
		_die()

## Restarts the burn if already burning.
func apply_burn(damage: int, tick_seconds: float, ticks: int) -> void:
	if not alive:
		return
	burn_damage = damage
	burn_tick_seconds = tick_seconds
	burn_tick_timer = tick_seconds
	burn_ticks_left = ticks
	_update_status_label()

func add_toxic(stacks: int) -> void:
	if not alive:
		return
	toxic_stacks += stacks
	_update_status_label()

func apply_freeze(seconds: float, windup_speed: float) -> void:
	if not alive:
		return
	freeze_timer = max(freeze_timer, seconds)
	freeze_windup_speed = windup_speed
	_update_status_label()

func _tick_statuses(delta: float) -> void:
	if freeze_timer > 0.0:
		freeze_timer -= delta
		if freeze_timer <= 0.0:
			_update_status_label()
	if burn_ticks_left > 0:
		burn_tick_timer -= delta
		if burn_tick_timer <= 0.0:
			burn_tick_timer += burn_tick_seconds
			burn_ticks_left -= 1
			take_damage(burn_damage)

func _update_status_label() -> void:
	var parts: PackedStringArray = []
	if burn_ticks_left > 0:
		parts.append("[color=%s]BURN[/color]" % STATUS_COLORS.burn)
	if toxic_stacks > 0:
		parts.append("[color=%s]TOX%d[/color]" % [STATUS_COLORS.toxic, toxic_stacks])
	if freeze_timer > 0.0:
		parts.append("[color=%s]FRZ[/color]" % STATUS_COLORS.freeze)
	status_label.text = "[center]%s[/center]" % " ".join(parts)

func _spawn() -> void:
	health = type.max_health
	alive = true
	winding_up = false
	stun_timer = 0.0
	_set_stars_visible(false)
	color = type.base_color
	_update_health_label()
	_reset_attack_timer()

func _die() -> void:
	alive = false
	winding_up = false
	stun_timer = 0.0
	_set_stars_visible(false)
	died.emit()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

func _reset_attack_timer() -> void:
	attack_timer = randf_range(type.attack_interval.x, type.attack_interval.y)

func _update_health_label() -> void:
	health_label.text = "●".repeat(health)

# Placeholder daze: stars circling above the head while stunned.
func _orbit_stars() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var center := Vector2(size.x / 2.0, -30.0)
	for i in stars.size():
		var angle := t * 4.0 + TAU * i / stars.size()
		var offset := Vector2(cos(angle) * 20.0, sin(angle) * 6.0)
		stars[i].position = center + offset - stars[i].size / 2.0

func _set_stars_visible(on: bool) -> void:
	for star in stars:
		star.visible = on
