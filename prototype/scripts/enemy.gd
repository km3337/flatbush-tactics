class_name FTEnemy
extends ColorRect

## An enemy that can be shot, periodically winds up and fires at the player.
## Stats (and optionally art) come from its FTEnemyType; the
## FTEncounterDirector places it in a slot. On death it emits `died` and
## frees itself.
## - With art (`type.sheet`): an animated sprite standing with its feet at the
##   bottom-centre of the slot; the node's rect becomes the sheet's hitbox.
##   Animations: idle, windup (stretched to the wind-up time), attack, hit,
##   death, strafe (while swaying; mirrored for left). Any the sheet lacks
##   fall back to idle (death: fade out). Stunned enemies glitch (shader)
##   with a stun effect over their head (`STUN_FX_*` if that art exists,
##   else placeholder stars).
## - Without art: a coloured rectangle that turns orange to wind up and grey
##   when stunned.
## Hitting it during the wind-up is a counter; staggerable enemies are then
## stunned: the attack is cancelled and they can't move or attack.
## Non-staggerable enemies take the hit but still fire.
## Ammo modifiers put statuses on it (burn, toxic, freeze), listed under it.

signal attacked
signal died
## Lobbing enemies (type.attack == LOB): the projectile appears and circles
## them for the wind-up, then is thrown when they attack.
signal lob_readied
signal lob_thrown

const WINDUP_COLOR := Color(1.0, 0.62, 0.1)
const STUN_COLOR := Color(0.45, 0.45, 0.5)
## Wind-up tint for sprites whose sheet has no windup animation.
const WINDUP_TINT := Color(1.0, 0.6, 0.25)
const STATUS_COLORS := {"burn": "#ff7326", "toxic": "#73e640", "freeze": "#73ccff"}
const GLITCH_SHADER := preload("res://shaders/glitch.gdshader")
## Shared stun effect, looped over the head of any stunned enemy with art.
## Export it from Aseprite to these paths and it's picked up automatically.
const STUN_FX_SHEET := "res://assets/fx/stun_fx.png"
const STUN_FX_DATA := "res://assets/fx/stun_fx.json"

const WOBBLE_SECONDS := 1.0
const DIGITIZE_SECONDS := 0.6

var type: FTEnemyType
var slot: StringName = &""
## Whole-number art scale for this slot (near slots draw at 2x).
var art_scale := 1
## Still arriving (wobble / digitize): can't be shot, doesn't attack.
var entering := false
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
# Art (null when the type has none).
var sheet: FTSpriteSheet
var sprite: AnimatedSprite2D
var stun_fx: AnimatedSprite2D
var windup_speed := 1.0
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
	if type.sheet and type.sheet_data:
		_setup_sprite()
	home = position
	time = randf() * TAU
	health_label = Label.new()
	health_label.add_theme_font_size_override("font_size", 8)
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.position = Vector2(0, -15)
	health_label.size = Vector2(size.x, 13)
	add_child(health_label)
	status_label = RichTextLabel.new()
	status_label.bbcode_enabled = true
	status_label.scroll_active = false
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.add_theme_font_size_override("normal_font_size", 8)
	status_label.position = Vector2(-10, size.y + 2)
	status_label.size = Vector2(size.x + 20, 14)
	add_child(status_label)
	if stun_fx == null:
		for i in 3:
			var star := Label.new()
			star.text = "★"
			star.add_theme_font_size_override("font_size", 16)
			star.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
			star.visible = false
			add_child(star)
			stars.append(star)
	_spawn()
	_start_entrance()

# Swap the rectangle for the sheet's sprite: feet on the bottom-centre of the
# slot, and this node's rect becomes the hitbox (what shots test against).
func _setup_sprite() -> void:
	sheet = FTSpriteSheet.load_sheet(type.sheet, type.sheet_data)
	var s := float(art_scale)
	var feet := position + Vector2(size.x / 2.0, size.y)
	size = sheet.hitbox.size * s
	position = (feet - (sheet.pivot - sheet.hitbox.position) * s).round()
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = sheet.frames
	sprite.centered = false
	sprite.scale = Vector2(s, s)
	sprite.position = -sheet.hitbox.position * s
	var glitch := ShaderMaterial.new()
	glitch.shader = GLITCH_SHADER
	sprite.material = glitch
	sprite.animation_finished.connect(_on_animation_finished)
	add_child(sprite)
	if ResourceLoader.exists(STUN_FX_SHEET) and ResourceLoader.exists(STUN_FX_DATA):
		var fx := FTSpriteSheet.load_sheet(load(STUN_FX_SHEET), load(STUN_FX_DATA))
		stun_fx = AnimatedSprite2D.new()
		stun_fx.sprite_frames = fx.frames
		stun_fx.centered = false
		# Bottom-centre of the effect sits on top of the head (hitbox top).
		stun_fx.position = (Vector2(size.x / 2.0, 0) - Vector2(fx.frame_size.x / 2.0, fx.frame_size.y)).round()
		stun_fx.visible = false
		add_child(stun_fx)

func _process(delta: float) -> void:
	if not alive or entering:
		return
	_tick_statuses(delta)
	if not alive:
		return  # burned to death
	if stun_timer > 0.0:
		stun_timer -= delta
		_orbit_stars()
		if stun_timer <= 0.0:
			_end_stun()
		return
	var frozen := freeze_timer > 0.0
	if type.sway > 0.0 and not frozen:
		time += delta
		position.x = home.x + sin(time * type.sway_speed) * type.sway
	if sprite:
		_update_movement_animation(frozen)
		if winding_up:
			sprite.speed_scale = windup_speed * (freeze_windup_speed if frozen else 1.0)
	attack_timer -= delta * (freeze_windup_speed if winding_up and frozen else 1.0)
	if attack_timer > 0.0:
		return
	if winding_up:
		winding_up = false
		_set_color(type.base_color)
		if type.attack == FTEnemyType.Attack.LOB:
			lob_thrown.emit()
		else:
			attacked.emit()
		if not _play(&"attack"):
			_play_idle()
		_reset_attack_timer()
	else:
		winding_up = true
		_set_color(WINDUP_COLOR)
		attack_timer = type.windup_seconds
		if type.attack == FTEnemyType.Attack.LOB:
			lob_readied.emit()
		if sheet and _play(&"windup"):
			# Stretch the wind-up animation over the actual wind-up time.
			windup_speed = sheet.length(&"windup") / maxf(type.windup_seconds, 0.01)
			sprite.speed_scale = windup_speed
		elif sprite:
			# No wind-up art: tint orange so the attack can still be read and
			# countered.
			sprite.self_modulate = WINDUP_TINT

func contains(screen_position: Vector2) -> bool:
	return alive and not entering and get_global_rect().has_point(screen_position)

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
		_start_stun()
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
	elif sprite and not winding_up and stun_timer <= 0.0:
		_play(&"hit")

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

func apply_freeze(seconds: float, windup_speed_: float) -> void:
	if not alive:
		return
	freeze_timer = max(freeze_timer, seconds)
	freeze_windup_speed = windup_speed_
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
	_set_color(type.base_color)
	_play_idle()
	_update_health_label()
	_reset_attack_timer()

func _die() -> void:
	alive = false
	winding_up = false
	stun_timer = 0.0
	_set_stars_visible(false)
	_set_glitch(0.0)
	if stun_fx:
		stun_fx.visible = false
	died.emit()
	var tween := create_tween()
	if sprite and _play(&"death"):
		tween.tween_interval(sheet.length(&"death"))
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

func _reset_attack_timer() -> void:
	attack_timer = randf_range(type.attack_interval.x, type.attack_interval.y)

func _update_health_label() -> void:
	health_label.text = "●".repeat(health)

# --- Entrance ---------------------------------------------------------------

func _start_entrance() -> void:
	match type.entrance:
		FTEnemyType.Entrance.WOBBLE:
			_begin_entrance()
			var tween := create_tween()
			tween.tween_method(_wobble_step, 0.0, 1.0, WOBBLE_SECONDS)
			tween.tween_callback(_finish_entrance)
		FTEnemyType.Entrance.DIGITIZE:
			_begin_entrance()
			var target: CanvasItem = sprite if sprite else self
			if target.material == null:  # rectangles get the shader just for this
				var rect_mat := ShaderMaterial.new()
				rect_mat.shader = GLITCH_SHADER
				rect_mat.set_shader_parameter("pixel_uv", Vector2.ONE / size)
				target.material = rect_mat
			var mat := target.material as ShaderMaterial
			mat.set_shader_parameter("reveal", 0.0)
			var tween := create_tween()
			tween.tween_method(func(r: float): mat.set_shader_parameter("reveal", r), 0.0, 1.0, DIGITIZE_SECONDS)
			tween.tween_callback(_finish_entrance)

func _begin_entrance() -> void:
	entering = true
	health_label.visible = false
	pivot_offset = Vector2(size.x / 2.0, size.y)  # scale/rotate about the feet

# Grow in from the back: starts small, high up and dim, and waddles side to
# side as it drops into the slot. (In-between sizes are off the pixel grid,
# but only for this second.)
func _wobble_step(t: float) -> void:
	var e := 1.0 - pow(1.0 - t, 2.0)  # ease out
	scale = Vector2.ONE * lerpf(0.3, 1.0, e)
	rotation = sin(t * PI * 6.0) * 0.15 * (1.0 - t)
	position = home + Vector2(sin(t * PI * 5.0) * 8.0 * (1.0 - t), lerpf(-90.0, 0.0, e))
	modulate = Color(0.45, 0.45, 0.55).lerp(Color.WHITE, e)

func _finish_entrance() -> void:
	if not alive:
		return
	entering = false
	scale = Vector2.ONE
	rotation = 0.0
	position = home
	modulate = Color.WHITE
	health_label.visible = true
	_reset_attack_timer()  # a fair moment before the first wind-up

# --- Stun -------------------------------------------------------------------

func _start_stun() -> void:
	_set_color(STUN_COLOR)
	if sprite:
		if not _play(&"stunned"):
			# No stun animation: freeze on the hit pose (or idle) and glitch.
			if not _play(&"hit"):
				_play_idle()
		_set_glitch(1.0)
	if stun_fx:
		stun_fx.visible = true
		stun_fx.play()
	else:
		_set_stars_visible(true)
		_orbit_stars()

func _end_stun() -> void:
	_set_color(type.base_color)
	_set_stars_visible(false)
	_set_glitch(0.0)
	if stun_fx:
		stun_fx.visible = false
		stun_fx.stop()
	_play_idle()
	_reset_attack_timer()

func _set_glitch(amount: float) -> void:
	if sprite:
		(sprite.material as ShaderMaterial).set_shader_parameter("strength", amount)

# Placeholder daze: stars circling above the head while stunned.
func _orbit_stars() -> void:
	if stars.is_empty():
		return
	var t := Time.get_ticks_msec() / 1000.0
	var center := Vector2(size.x / 2.0, -30.0)
	for i in stars.size():
		var angle := t * 4.0 + TAU * i / stars.size()
		var offset := Vector2(cos(angle) * 20.0, sin(angle) * 6.0)
		stars[i].position = center + offset - stars[i].size / 2.0

func _set_stars_visible(on: bool) -> void:
	for star in stars:
		star.visible = on

# --- Art --------------------------------------------------------------------

## Rectangles show the colour; enemies with art stay transparent (and drop
## any wind-up tint when the wind-up ends).
func _set_color(c: Color) -> void:
	color = c if sprite == null else Color(0, 0, 0, 0)
	if sprite and c != WINDUP_COLOR:
		sprite.self_modulate = Color.WHITE

## Plays an animation if the sheet has drawn frames for it.
func _play(animation: StringName) -> bool:
	if sprite == null or not sheet.has(animation):
		return false
	sprite.speed_scale = 1.0
	sprite.flip_h = false
	sprite.play(animation)
	return true

func _play_idle() -> void:
	if sprite and sheet.has(&"idle"):
		sprite.speed_scale = 1.0
		sprite.play(&"idle")

# While idling, a swaying enemy uses its strafe animation, mirrored when it
# moves left (strafe is drawn moving right).
func _update_movement_animation(frozen: bool) -> void:
	if winding_up or sprite.animation not in [&"idle", &"strafe"]:
		return
	if type.sway > 0.0 and not frozen and sheet.has(&"strafe"):
		if sprite.animation != &"strafe":
			sprite.play(&"strafe")
		sprite.flip_h = cos(time * type.sway_speed) < 0.0
	elif sprite.animation != &"idle":
		sprite.flip_h = false
		sprite.play(&"idle")

# One-shot animations (attack, hit) return to idle; wind-up, stun and death
# hold their last frame.
func _on_animation_finished() -> void:
	if alive and not winding_up and stun_timer <= 0.0 and sprite.animation in [&"attack", &"hit"]:
		_play_idle()
