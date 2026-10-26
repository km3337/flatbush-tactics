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
## Burrowing enemies (type.burrows): it just went underground. The director
## moves it to another floor slot (`relocate`) before it rises again.
signal burrowed
## Enough counter hits landed during the wind-up: the attack won't happen
## (its circling/charging projectile should go too).
signal attack_cancelled

const WINDUP_COLOR := Color(1.0, 0.62, 0.1)
const STUN_COLOR := Color(0.45, 0.45, 0.5)
## One on/off blink of a flashing wind-up (type.windup_flash).
const FLASH_PERIOD := 0.16
## Rise / sink time when the sheet has no emerge / burrow animation.
const BURROW_TWEEN_SECONDS := 0.25
## A burrower sinks this long after firing (lets the attack frame show).
const BURROW_DELAY := 0.35
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
var stun_fx_size := Vector2.ZERO
var windup_speed := 1.0
## Burrowers: between firing and rising again (sinking, underground, rising).
var burrowing := false
## Counter hits landed during the current wind-up.
var counter_hits_taken := 0
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
	if type.arc_size != Vector2.ZERO:
		# Arcs swing around the middle of the screen, whatever the slot.
		position.x = roundf((FTBattle.BATTLEFIELD_SIZE.x - size.x) / 2.0)
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
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = sheet.frames
	sprite.centered = false
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
		stun_fx_size = fx.frame_size
		stun_fx.visible = false
		add_child(stun_fx)
	_fit_sprite(Rect2(position, size))

## Sizes the sprite for `art_scale` with its feet on the bottom-centre of
## `slot_rect`; this node's rect becomes the hitbox.
func _fit_sprite(slot_rect: Rect2) -> void:
	var s := float(art_scale)
	var feet := slot_rect.position + Vector2(slot_rect.size.x / 2.0, slot_rect.size.y)
	size = sheet.hitbox.size * s
	position = (feet - (sheet.pivot - sheet.hitbox.position) * s).round()
	sprite.scale = Vector2(s, s)
	sprite.position = -sheet.hitbox.position * s
	if stun_fx:
		# Bottom-centre of the effect sits on top of the head (hitbox top).
		stun_fx.position = (Vector2(size.x / 2.0, 0) - Vector2(stun_fx_size.x / 2.0, stun_fx_size.y)).round()

## Moves to another slot (burrowers hop between floor slots while
## underground).
func relocate(slot_rect: Rect2, new_art_scale: int) -> void:
	art_scale = new_art_scale
	if sheet:
		_fit_sprite(slot_rect)
	else:
		position = slot_rect.position
		size = slot_rect.size
	home = position
	z_index = int(slot_rect.end.y)
	pivot_offset = Vector2(size.x / 2.0, size.y)
	health_label.size.x = size.x
	status_label.position.y = size.y + 2
	status_label.size.x = size.x + 20

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
	if burrowing:
		return  # firing done; sinking, underground or rising
	var frozen := freeze_timer > 0.0
	if type.sway > 0.0 and not frozen:
		time += delta
		position.x = home.x + sin(time * type.sway_speed) * type.sway
	if type.arc_size != Vector2.ZERO and not frozen:
		time += delta
		var p := sin(time * type.arc_speed)
		var reach := minf(type.arc_size.x, home.x)  # stays on screen
		position = (home + Vector2(p * reach, -p * p * type.arc_size.y)).round()
	if sprite:
		_update_movement_animation(frozen)
		if winding_up:
			sprite.speed_scale = windup_speed * (freeze_windup_speed if frozen else 1.0)
	if winding_up and type.windup_flash:
		var on := fmod(attack_timer, FLASH_PERIOD) > FLASH_PERIOD / 2.0
		if sprite:
			sprite.self_modulate = type.windup_tint if on else Color.WHITE
		else:
			color = type.windup_tint if on else type.base_color
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
		if type.burrows:
			_burrow()
	else:
		winding_up = true
		counter_hits_taken = 0
		_set_color(WINDUP_COLOR)
		attack_timer = type.windup_seconds
		if type.attack == FTEnemyType.Attack.LOB:
			lob_readied.emit()
		var has_windup_art := sheet != null and _play(&"windup")
		if has_windup_art:
			# Stretch the wind-up animation over the actual wind-up time.
			windup_speed = sheet.length(&"windup") / maxf(type.windup_seconds, 0.01)
			sprite.speed_scale = windup_speed
		if sprite and (not has_windup_art or type.windup_flash):
			# Without wind-up art, the tint is how the attack can be read and
			# countered.
			sprite.self_modulate = type.windup_tint

func contains(screen_position: Vector2) -> bool:
	return alive and not entering and not burrowing and get_global_rect().has_point(screen_position)

## A shot from the player. Spends toxic stacks for bonus damage. Returns true
## if the hit was a counter (landed during the wind-up).
func take_hit(damage := 1) -> bool:
	if not alive:
		return false
	var countered := winding_up
	if countered:
		register_counter_hit()
	damage += toxic_stacks
	toxic_stacks = 0
	take_damage(damage)
	return countered

## A hit during the wind-up (on this enemy or its projectile). After
## `type.counter_hits` of them (one for staggerable enemies by default) the
## attack is cancelled, and staggerable enemies are stunned. Non-staggerable
## enemies without `counter_hits` still fire. Returns true if cancelled.
func register_counter_hit() -> bool:
	if not winding_up:
		return false
	counter_hits_taken += 1
	var needed := type.counter_hits if type.counter_hits > 0 else (1 if type.staggerable else 0)
	if needed == 0 or counter_hits_taken < needed:
		return false
	winding_up = false
	attack_cancelled.emit()
	if type.staggerable:
		stun_timer = type.stun_seconds
		_start_stun()
	else:
		_set_color(type.base_color)
		_play_idle()
		_reset_attack_timer()
	return true

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
	# Bosses would be a long row of dots: show the number instead.
	health_label.text = "●".repeat(health) if type.max_health <= 10 else "%d/%d" % [health, type.max_health]

# --- Entrance ---------------------------------------------------------------

func _start_entrance() -> void:
	if type.burrows:
		# Burrowers always arrive by rising out of the ground.
		_begin_entrance()
		_emerge()
		return
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

# --- Burrowing --------------------------------------------------------------

# After firing: sink, wait underground (hidden, can't be hit; the director
# moves it to another floor slot), then rise again.
func _burrow() -> void:
	burrowing = true
	var tween := create_tween()
	tween.tween_interval(BURROW_DELAY)
	tween.tween_callback(func(): pivot_offset = Vector2(size.x / 2.0, size.y))
	if sheet and sheet.has(&"burrow"):
		tween.tween_callback(_play.bind(&"burrow"))
		tween.tween_interval(sheet.length(&"burrow"))
	else:
		tween.tween_property(self, "scale:y", 0.0, BURROW_TWEEN_SECONDS)
	tween.tween_callback(func():
		visible = false
		burrowed.emit())
	tween.tween_interval(type.burrow_seconds)
	tween.tween_callback(func():
		if alive:
			_begin_entrance()
			_emerge())

# Rise out of the ground, then act like any arrived enemy.
func _emerge() -> void:
	burrowing = false
	visible = true
	position = home
	var tween := create_tween()
	if sheet and _play(&"emerge"):
		scale = Vector2.ONE
		tween.tween_interval(sheet.length(&"emerge"))
	else:
		scale = Vector2(1.0, 0.0)
		tween.tween_property(self, "scale:y", 1.0, BURROW_TWEEN_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(func():
		_finish_entrance()
		_play_idle())

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
