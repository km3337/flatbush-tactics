class_name FTClosingDoors
extends Control

## Subway doors over a whole screen. Start of a stop: `open()` (they start
## shut and slide apart). End of a stop: `close()`: "Stand clear of the
## closing doors please", bing-bong, and the doors slide shut; `await` it to
## wait until they're shut. The sound plays through the Music autoload so it
## finishes even if the scene changes right after.
## Placeholder doors drawn in code (Lux2k greys/blues); real art can replace
## `_draw_door`.

## assets/sfx/doors_closing.wav: the voice, then the chime at CHIME_AT.
const SOUND: AudioStream = preload("res://assets/sfx/doors_closing.wav")
const CHIME_AT := 2.59
## The doors slide for this long and meet on the chime.
const CLOSE_SECONDS := 0.45
## Bounce when the rubber edges meet.
const SETTLE_SECONDS := 0.15
## When opening, the shut doors hold this long first (so the screen reads
## as "arrived" before they part).
const OPEN_DELAY := 0.2

const STEEL := Color8(167, 172, 186)
const STEEL_DARK := Color8(96, 96, 96)
const GLASS := Color8(86, 88, 123)
const GLASS_SHINE := Color8(155, 240, 253)
const RUBBER := Color8(37, 19, 26)

## 0 = open (off screen), 1 = shut.
var shut := 0.0

## Adds full-screen doors as the top child of `parent` (or at `index`).
static func add_to(parent: Node, index := -1) -> FTClosingDoors:
	var doors := FTClosingDoors.new()
	doors.set_anchors_preset(Control.PRESET_FULL_RECT)
	doors.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(doors)
	if index >= 0:
		parent.move_child(doors, index)
	return doors

## For a screen's _ready: shut doors go on top of everything it builds (added
## at the end of the frame) and slide open.
static func open_over(parent: Node) -> void:
	var doors := FTClosingDoors.new()
	doors.shut = 1.0
	doors.set_anchors_preset(Control.PRESET_FULL_RECT)
	doors.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doors.ready.connect(doors.open, CONNECT_ONE_SHOT)
	parent.add_child.call_deferred(doors)

## The reverse: shut doors slide apart (no announcement), then go away.
func open() -> void:
	_set_shut(1.0)
	var tween := create_tween()
	tween.tween_interval(OPEN_DELAY)
	tween.tween_method(_set_shut, 1.0, 0.0, CLOSE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	queue_free()

func close() -> void:
	Music.play_sound(SOUND)
	await get_tree().create_timer(CHIME_AT - CLOSE_SECONDS).timeout
	var tween := create_tween()
	tween.tween_method(_set_shut, 0.0, 1.0, CLOSE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# The edges hit, spring back a little, and settle.
	tween.tween_method(_set_shut, 1.0, 0.97, SETTLE_SECONDS / 2.0)
	tween.tween_method(_set_shut, 0.97, 1.0, SETTLE_SECONDS / 2.0)
	await tween.finished

func _set_shut(value: float) -> void:
	shut = value
	queue_redraw()

func _draw() -> void:
	if shut <= 0.0:
		return
	var half := ceilf(size.x / 2.0)
	var travel := roundf(half * shut)
	_draw_door(Rect2(travel - half, 0, half, size.y), false)
	_draw_door(Rect2(size.x - travel, 0, half, size.y), true)

# One door panel; `right` mirrors it so the rubber edge faces the middle.
func _draw_door(r: Rect2, right: bool) -> void:
	draw_rect(r, STEEL)
	# Shading along the hinge side.
	var hinge := Rect2(r.end.x - 6, r.position.y, 6, r.size.y) if right else Rect2(r.position.x, r.position.y, 6, r.size.y)
	draw_rect(hinge, STEEL_DARK)
	# Rubber edge where the doors meet.
	var edge := Rect2(r.position.x, r.position.y, 6, r.size.y) if right else Rect2(r.end.x - 6, r.position.y, 6, r.size.y)
	draw_rect(edge, RUBBER)
	# Window in the upper part, with a diagonal shine.
	var window := Rect2(r.position.x + 22, r.position.y + r.size.y * 0.16, r.size.x - 44, r.size.y * 0.3).abs()
	draw_rect(window.grow(3), STEEL_DARK)
	draw_rect(window, GLASS)
	for i in 3:
		var x := window.position.x + 14 + i * 6
		draw_line(Vector2(x, window.position.y + 4), Vector2(x + 24, window.position.y + 28), GLASS_SHINE, 2.0)
	# Kick plate along the bottom.
	draw_rect(Rect2(r.position.x + 10, r.end.y - r.size.y * 0.12, r.size.x - 20, 4), STEEL_DARK)
