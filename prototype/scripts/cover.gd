class_name FTCover
extends CanvasLayer

## Player cover. Drawn above the world (enemies) and below the HUD. Ducking is
## a step sideways behind a pillar: it slides in from the right and covers the
## right `coverage` of the screen, the world leans `lean_pixels` the other way,
## and the rest stays visible but blurred, so enemies show through as soft
## shapes. The biome only sets its look. While in cover, a "!" is drawn
## (unblurred) over each enemy that is winding up an attack, and flashes red
## when that shot is blocked. Out of cover, those enemies get an FTTargetBox.

signal entered_cover
signal exited_cover

const PILLAR_EDGE_WIDTH := 6.0

@export var slide_seconds := 0.14
## Fraction of the screen width the pillar blocks, from the right edge in.
@export_range(0.0, 1.0) var coverage := 0.4
## How far the world shifts left while behind the pillar. Backgrounds are 20px
## wider than the base screen on each side, so keep this under that.
@export var lean_pixels := 16.0
## Blur radius in game pixels for the uncovered part while in cover.
@export var blur_radius := 1.5
@export var warning_color := Color(1.0, 0.62, 0.1)
@export var blocked_color := Color(1.0, 0.2, 0.2)
@export var blocked_flash_seconds := 0.3
@onready var blur: ColorRect = $Blur
@onready var shield: ColorRect = $Shield
@onready var cover_label: Label = $Shield/CoverLabel
var edge: ColorRect
var in_cover := false
var biome: FTBiome
var slide_tween: Tween
var blur_tween: Tween
var lean := 0.0
var warnings := {}  # FTEnemy -> Label
var target_boxes := {}  # FTEnemy -> FTTargetBox
var blocked_until := {}  # FTEnemy -> time (seconds) the blocked flash ends

func _ready() -> void:
	shield.visible = false
	blur.visible = false
	cover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Placeholder: a lit edge facing the room, until there's pillar art.
	edge = ColorRect.new()
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.anchor_bottom = 1.0
	edge.offset_right = PILLAR_EDGE_WIDTH
	shield.add_child(edge)

func _exit_tree() -> void:
	get_viewport().canvas_transform = Transform2D.IDENTITY  # outlives the scene

func track_enemy(enemy: FTEnemy) -> void:
	var label := Label.new()
	label.text = "!"
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(35, 50)
	label.pivot_offset = label.size / 2.0
	label.visible = false
	add_child(label)
	warnings[enemy] = label
	var box := FTTargetBox.new()
	box.visible = false
	add_child(box)
	target_boxes[enemy] = box
	enemy.attacked.connect(_on_enemy_attacked.bind(enemy))
	enemy.tree_exiting.connect(_untrack_enemy.bind(enemy))

func _untrack_enemy(enemy: FTEnemy) -> void:
	warnings[enemy].queue_free()
	warnings.erase(enemy)
	target_boxes[enemy].queue_free()
	target_boxes.erase(enemy)
	blocked_until.erase(enemy)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for enemy: FTEnemy in warnings:
		_update_target_box(enemy)
		var label: Label = warnings[enemy]
		var blocked: bool = blocked_until.get(enemy, 0.0) > now
		label.visible = in_cover and enemy.alive and (enemy.winding_up or blocked)
		if not label.visible:
			continue
		label.position = enemy.get_global_rect().get_center() - label.size / 2.0 - Vector2(lean, 0.0)
		if blocked:
			label.add_theme_color_override("font_color", blocked_color)
			label.scale = Vector2(1.4, 1.4)
			label.modulate.a = 1.0
		else:
			label.add_theme_color_override("font_color", warning_color)
			label.scale = Vector2.ONE
			label.modulate.a = 0.6 + 0.4 * sin(now * 18.0)

func _update_target_box(enemy: FTEnemy) -> void:
	var box: FTTargetBox = target_boxes[enemy]
	var active := not in_cover and enemy.alive and enemy.winding_up
	if active and not box.visible:
		box.lock_on()
	box.visible = active
	if active:
		var left := clampf(enemy.attack_timer / maxf(enemy.type.windup_seconds, 0.01), 0.0, 1.0)
		box.frame(enemy.get_global_rect(), left, Rect2(Vector2.ZERO, _viewport_size()))

func _on_enemy_attacked(enemy: FTEnemy) -> void:
	if in_cover:
		blocked_until[enemy] = Time.get_ticks_msec() / 1000.0 + blocked_flash_seconds

func apply_biome(new_biome: FTBiome) -> void:
	biome = new_biome
	shield.color = biome.cover_color
	edge.color = biome.cover_color.lightened(0.3)
	cover_label.text = "%s\n%s" % [biome.cover_name.to_upper(), biome.display_name.to_lower()]
	if in_cover:
		_kill_tween()
		_place_shield()

func enter() -> void:
	if in_cover:
		return
	in_cover = true
	_kill_tween()
	_place_shield()
	var rest_x := shield.position.x
	shield.position.x = _viewport_size().x
	shield.visible = true
	slide_tween = create_tween().set_parallel()
	slide_tween.tween_property(shield, "position:x", rest_x, slide_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	slide_tween.tween_method(_set_lean, lean, lean_pixels, slide_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fade_blur(1.0)
	entered_cover.emit()

func exit() -> void:
	if not in_cover:
		return
	in_cover = false
	_kill_tween()
	slide_tween = create_tween().set_parallel()
	slide_tween.tween_property(shield, "position:x", _viewport_size().x, slide_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slide_tween.tween_method(_set_lean, lean, 0.0, slide_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slide_tween.chain().tween_callback(func(): shield.visible = false)
	_fade_blur(0.0)
	exited_cover.emit()

## The pillar is still sliding (the world hasn't settled: shots wait for it).
func is_moving() -> bool:
	return slide_tween != null and slide_tween.is_running()

func _place_shield() -> void:
	var size := _viewport_size()
	shield.position = Vector2(roundf(size.x * (1.0 - coverage)), 0.0)
	shield.size = Vector2(size.x - shield.position.x, size.y)

# The world is on the viewport's canvas, so this shifts it without touching
# the HUD or any enemy's position. Whole pixels, to stay on the art's grid.
func _set_lean(amount: float) -> void:
	lean = roundf(amount)
	get_viewport().canvas_transform = Transform2D(0.0, Vector2(-lean, 0.0))

# Blur fades with the cover slide. Its radius is converted from game pixels to
# screen pixels, since the game is drawn at the window's integer scale.
func _fade_blur(target: float) -> void:
	if blur_tween:
		blur_tween.kill()
	var material := blur.material as ShaderMaterial
	var scale := get_viewport().get_final_transform().get_scale().x
	material.set_shader_parameter("radius_px", blur_radius * scale)
	blur.visible = true
	blur_tween = create_tween()
	blur_tween.tween_method(func(v: float): material.set_shader_parameter("strength", v),
		material.get_shader_parameter("strength"), target, slide_seconds)
	if target == 0.0:
		blur_tween.tween_callback(func(): blur.visible = false)

func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size

func _kill_tween() -> void:
	if slide_tween:
		slide_tween.kill()
