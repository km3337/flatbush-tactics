class_name FTTargetBox
extends Control

## The out-of-cover attack marker: red corner brackets locked onto an enemy
## winding up, a blinking WARNING tag, and a bar that drains until it fires.
## FTCover places one per enemy. Drawn in code on whole pixels; swap in art
## later.

const RED := Color(1.0, 0.13, 0.2)
const DARK := Color(0.06, 0.05, 0.08)
const TEXT := "WARNING"
const CORNER := 12.0
const LINE := 2.0
## Space above the box for the tag, and below it for the bar.
const TAG_HEIGHT := 12.0
const BAR_HEIGHT := 2.0
const BAR_GAP := 3.0
const BLINK_SECONDS := 0.1
## The brackets start this far out and snap in.
const LOCK_GROW := 14.0
const LOCK_SECONDS := 0.12

var lock := 0.0
## Share of the wind-up still to go, 1 down to 0.
var left := 1.0
var tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## The box just appeared: the brackets snap onto the target.
func lock_on() -> void:
	if tween:
		tween.kill()
	lock = 1.0
	tween = create_tween()
	tween.tween_property(self, "lock", 0.0, LOCK_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Frames `target` (kept inside `screen`, with room for the tag and bar).
func frame(target: Rect2, windup_left: float, screen: Rect2) -> void:
	var room := screen.grow_individual(-2.0, -(TAG_HEIGHT + 2.0), -2.0, -(BAR_GAP + BAR_HEIGHT + 2.0))
	var box := target.intersection(room)
	position = box.position.round()
	size = box.size.round()
	left = windup_left
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size).grow(roundf(lock * LOCK_GROW))
	_draw_corners(r, DARK, LINE + 2.0)
	_draw_corners(r, RED, LINE)
	_draw_tag(r.position)
	var bar := Rect2(r.position.x, r.end.y + BAR_GAP, roundf(r.size.x * left), BAR_HEIGHT)
	draw_rect(bar.grow(1.0), DARK)
	draw_rect(bar, RED)

func _draw_corners(r: Rect2, color: Color, width: float) -> void:
	var inset := (width - LINE) / 2.0
	var length := minf(CORNER, minf(r.size.x, r.size.y) / 2.0) + inset * 2.0
	var a := r.position - Vector2.ONE * inset
	var b := r.end + Vector2.ONE * inset
	for x_end in [false, true]:
		for y_end in [false, true]:
			var corner := Vector2(b.x if x_end else a.x, b.y if y_end else a.y)
			var across := Vector2(corner.x - length if x_end else corner.x, corner.y - width if y_end else corner.y)
			var down := Vector2(corner.x - width if x_end else corner.x, corner.y - length if y_end else corner.y)
			draw_rect(Rect2(across, Vector2(length, width)), color)
			draw_rect(Rect2(down, Vector2(width, length)), color)

# A solid tag on the box's top-left corner, swapping colours as it blinks,
# then three hazard ticks.
func _draw_tag(at: Vector2) -> void:
	var font := get_theme_default_font()
	var width := ceilf(font.get_string_size(TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x) + 4.0
	var tag := Rect2(at + Vector2(0, -TAG_HEIGHT), Vector2(width, TAG_HEIGHT - 1.0))
	var on := fmod(Time.get_ticks_msec() / 1000.0, BLINK_SECONDS * 2.0) < BLINK_SECONDS
	draw_rect(tag, RED if on else DARK)
	draw_string(font, tag.position + Vector2(2, 9), TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, DARK if on else RED)
	for i in 3:
		draw_rect(Rect2(tag.end.x + 2.0 + i * 4.0, tag.position.y, 2.0, tag.size.y), RED)
