class_name FTRewardCache
extends Control

## The loot after a fight: a lockbox that drops onto the shut doors and has
## to be shot open (`hits_needed` shots). Its straps and glow tell the best
## rarity inside, like Vampire Survivors' chests. Each shot jolts it and
## cracks it, with light leaking through; the last one blows the lid off in a
## beam of light. Placeholder drawn in code on a 2x pixel grid; real art can
## replace `_draw_box`.

signal opened

## Art pixels are drawn this big.
const PX := 3.0
## The box in art pixels.
const ART := Vector2(40, 32)
const OUTLINE := Color8(37, 19, 26)
const BODY := Color8(86, 88, 123)
const BODY_DARK := Color8(61, 37, 59)
const LID := Color8(167, 172, 186)
const SHINE := Color8(230, 222, 202)
const KEYHOLE := Color8(37, 19, 26)
## Strap/lock colour and light colour by rarity (FTGear.Rarity).
const BANDS := [Color8(167, 172, 186), Color8(88, 128, 204), Color8(255, 213, 105)]
const GLOWS := [Color8(230, 222, 202), Color8(155, 240, 253), Color8(255, 213, 105)]

var rarity := FTGear.Rarity.COMMON
var hits_needed := 3
var hits := 0
var is_open := false
var prompt: Label
var since_shown := 0.0
var flash := 0.0
var shake := Vector2.ZERO
var lid_lift := 0.0
var lid_angle := 0.0
var beam := 0.0
var cracks: Array[PackedVector2Array] = []

func _init() -> void:
	size = ART * PX
	pivot_offset = Vector2(size.x / 2.0, size.y)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt = Label.new()
	prompt.text = "SHOOT IT OPEN!"
	prompt.add_theme_font_size_override("font_size", 16)
	prompt.add_theme_constant_override("outline_size", 4)
	prompt.add_theme_color_override("font_outline_color", OUTLINE)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.size = Vector2(240, 16)
	prompt.position = Vector2((size.x - prompt.size.x) / 2.0, size.y + 28)
	prompt.visible = false
	add_child(prompt)

func glow_color() -> Color:
	return GLOWS[rarity]

## Falls from above onto `land_at` (top-left), bounces, and shows the prompt.
func drop_in(land_at: Vector2) -> void:
	position = land_at - Vector2(0, 260)
	var tween := create_tween()
	tween.tween_property(self, "position", land_at, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	FTRewardSfx.play(self, &"thud")
	FTRewardBurst.spawn(get_parent(), global_position + Vector2(size.x / 2.0, size.y), [SHINE, LID], 14, Vector2(40, 110), 0.4, Vector2.UP, PI * 0.9, 2.0, 200.0)
	scale = Vector2(1.25, 0.75)
	var squash := create_tween()
	squash.tween_property(self, "scale", Vector2(0.9, 1.1), 0.08)
	squash.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await squash.finished
	prompt.visible = true
	since_shown = 0.0

## A shot landed on the box. Returns true when this one opens it.
func hit() -> bool:
	if is_open:
		return false
	hits += 1
	flash = 1.0
	_add_crack()
	FTRewardSfx.play(self, &"crack", 1.0 + 0.18 * (hits - 1))
	FTRewardBurst.spawn(get_parent(), global_position + size / 2.0, [glow_color(), SHINE], 6 + hits * 3, Vector2(60, 150), 0.45, Vector2.UP, PI * 1.4)
	var jolt := create_tween()
	var push := 3.0 + hits
	for x in [push, -push, push * 0.5, 0.0]:
		jolt.tween_property(self, "shake", Vector2(x, -absf(x) * 0.5), 0.035)
	if hits >= hits_needed:
		_burst_open()
		return true
	return false

func _burst_open() -> void:
	is_open = true
	prompt.visible = false
	FTRewardSfx.play(self, &"open")
	var colors := [glow_color(), SHINE, Color.WHITE]
	var center := global_position + Vector2(size.x / 2.0, 12.0 * PX)
	FTRewardBurst.spawn(get_parent(), center, colors, 40 + 20 * rarity, Vector2(120, 300), 0.9, Vector2.UP, PI * 1.1, 2.0, 320.0)
	if rarity == FTGear.Rarity.RARE:
		FTRewardBurst.spawn(get_parent(), center, [Color8(209, 133, 30), glow_color()], 30, Vector2(200, 380), 1.1, Vector2.UP, PI * 0.5, 4.0, 300.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "lid_lift", 70.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "lid_angle", -0.9, 0.45)
	tween.tween_property(self, "beam", 1.0, 0.12)
	tween.chain().tween_interval(0.35)
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)
	await get_tree().create_timer(0.25).timeout
	opened.emit()

func _add_crack() -> void:
	# Jagged line across the body, in art pixels.
	var points := PackedVector2Array()
	var p := Vector2(randf_range(6, 34), randf_range(15, 20))
	points.append(p)
	for i in randi_range(3, 4):
		p += Vector2(randf_range(-5, 5), randf_range(2, 4))
		p = p.clamp(Vector2(3, 14), Vector2(37, 30))
		points.append(p.round())
	cracks.append(points)

func _process(delta: float) -> void:
	since_shown += delta
	flash = maxf(0.0, flash - delta * 6.0)
	if prompt.visible:
		prompt.modulate.a = 1.0 if fmod(since_shown, 0.8) < 0.55 else 0.0
	queue_redraw()

func _r(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(Vector2(x, y) * PX + shake.round(), Vector2(w, h) * PX), color)

func _draw() -> void:
	var glow := glow_color()
	var pulse := 0.5 + 0.5 * sin(since_shown * TAU * (1.0 + hits * 0.5))
	# Light column once it bursts.
	if beam > 0.0:
		var w := lerpf(4.0, 28.0, beam) * (1.0 - 0.6 * (1.0 - modulate.a))
		var beam_color := glow
		beam_color.a = 0.45
		draw_rect(Rect2(Vector2(ART.x / 2.0 - w / 2.0, -400.0 / PX) * PX, Vector2(w, 400.0 / PX + 14.0) * PX), beam_color)
		beam_color = Color.WHITE
		beam_color.a = 0.8
		draw_rect(Rect2(Vector2(ART.x / 2.0 - w / 6.0, -400.0 / PX) * PX, Vector2(w / 3.0, 400.0 / PX + 14.0) * PX), beam_color)
	# Glow behind the box: stepped rings, brighter with every crack.
	var strength := (0.12 + 0.05 * hits) * (0.6 + 0.4 * pulse)
	for ring in [6, 4, 2]:
		var c := glow
		c.a = strength * (1.0 - ring / 8.0)
		_r(-ring, 6 - ring, ART.x + ring * 2, ART.y - 6 + ring * 2, c)
	# Shadow.
	var shadow := OUTLINE
	shadow.a = 0.6
	_r(3, ART.y - 1, ART.x - 6, 2, shadow)
	_draw_box(glow)
	if flash > 0.0:
		var white := Color(1, 1, 1, flash * 0.8)
		_r(1, 12, ART.x - 2, ART.y - 13, white)

func _draw_box(glow: Color) -> void:
	var band: Color = BANDS[rarity]
	# Body.
	_r(1, 12, 38, 20, OUTLINE)
	_r(2, 13, 36, 18, BODY)
	_r(2, 27, 36, 4, BODY_DARK)
	_r(8, 13, 4, 18, band)
	_r(28, 13, 4, 18, band)
	# Light leaking through the cracks.
	for crack in cracks:
		for i in crack.size() - 1:
			var a := crack[i] * PX + shake.round()
			var b := crack[i + 1] * PX + shake.round()
			draw_line(a, b, glow, PX)
	# Lid (lifts and tips off when opened).
	var lid_origin := Vector2(1, 13) * PX + shake.round()
	draw_set_transform(lid_origin + Vector2(0, -lid_lift), lid_angle, Vector2.ONE)
	var lid := [
		[Vector2(0, -8), Vector2(38, 9), OUTLINE],
		[Vector2(1, -7), Vector2(36, 7), LID],
		[Vector2(1, -7), Vector2(36, 1), SHINE],
		[Vector2(7, -7), Vector2(4, 7), band],
		[Vector2(27, -7), Vector2(4, 7), band],
		[Vector2(15, -4), Vector2(8, 8), OUTLINE],
		[Vector2(16, -3), Vector2(6, 6), band],
		[Vector2(18, -2), Vector2(2, 3), KEYHOLE],
	]
	for part in lid:
		draw_rect(Rect2(part[0] * PX, part[1] * PX), part[2])
	draw_set_transform(Vector2.ZERO)
	if lid_lift > 0.0:
		# Open: the glow pours out of the top.
		var inside := glow
		inside.a = 0.9
		_r(2, 12, 36, 2, inside)
