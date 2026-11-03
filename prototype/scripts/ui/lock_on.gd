class_name FTLockOn
extends CanvasLayer

## Yellow lock-on over the enemy a charge shot is aimed at: a flat yellow copy
## of its sprite that strengthens as the charge builds and pulses once it's
## full. The battle puts this layer above the cover layer, so it also covers
## the red WARNING box and the orange wind-up tint. Enemies without art get a
## yellow rectangle instead.

const YELLOW := Color(1.0, 0.84, 0.41)  # Lux2k gold
const FLAT_TINT_SHADER: Shader = preload("res://shaders/flat_tint.gdshader")
## Overlay strength: from MIN_ALPHA at lock to MAX_ALPHA when full, then it
## pulses between PULSE_LOW and MAX_ALPHA.
const MIN_ALPHA := 0.25
const MAX_ALPHA := 0.8
const PULSE_LOW := 0.45
const PULSE_HZ := 6.0

var overlay: AnimatedSprite2D
var box: ColorRect

func _ready() -> void:
	follow_viewport_enabled = true  # leans with the world, like the enemies
	overlay = AnimatedSprite2D.new()
	overlay.centered = false
	overlay.material = ShaderMaterial.new()
	overlay.material.shader = FLAT_TINT_SHADER
	overlay.visible = false
	add_child(overlay)
	box = ColorRect.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.color = YELLOW
	box.visible = false
	add_child(box)

## `ratio`: 0 just locked, 1 full.
func show_lock(enemy: FTEnemy, ratio: float) -> void:
	var alpha := lerpf(MIN_ALPHA, MAX_ALPHA, ratio)
	if ratio >= 1.0:
		var wave := 0.5 + 0.5 * cos(Time.get_ticks_msec() / 1000.0 * TAU * PULSE_HZ)
		alpha = lerpf(PULSE_LOW, MAX_ALPHA, wave)
	if enemy.sprite:
		overlay.sprite_frames = enemy.sprite.sprite_frames
		overlay.animation = enemy.sprite.animation
		overlay.frame = enemy.sprite.frame
		overlay.flip_h = enemy.sprite.flip_h
		overlay.global_transform = enemy.sprite.global_transform
		overlay.material.set_shader_parameter("tint", Color(YELLOW, alpha))
		overlay.visible = true
		box.visible = false
	else:
		box.global_position = enemy.global_position
		box.size = enemy.size
		box.color = Color(YELLOW, alpha)
		box.visible = true
		overlay.visible = false

func hide_lock() -> void:
	overlay.visible = false
	box.visible = false
