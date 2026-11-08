class_name FTGestureHand
extends Control

## The tutorial's pointing hand: shows the player what to do with their
## thumb. TAP bobs onto a point and pings a ring there; FLICK presses and
## swipes down. The point can follow something that moves (`follow`).
## Placeholder drawn in code at 2x (12x13 art pixels) until a hand is drawn
## in Aseprite. Animates in real time, so it keeps its pace in slow motion.

enum Gesture { NONE, TAP, FLICK }

const ART_SCALE := 2
## Outline (X) and fill (o); spaces are clear. The fingertip is at FINGERTIP.
const ART := [
	"    XX      ",
	"   XooX     ",
	"   XooX     ",
	"   XooXXX   ",
	"   XooXooXX ",
	"XX XooXooXoX",
	"XoXXoooooooX",
	"XooXoooooooX",
	" XoooooooooX",
	" XoooooooooX",
	"  XoooooooX ",
	"   XooooooX ",
	"   XXXXXXXX ",
]
const FINGERTIP := Vector2(4, 0)
const OUTLINE := Color8(37, 19, 26)
const FILL := Color8(230, 222, 202)
const RING := Color8(255, 214, 92)
const TAP_PERIOD := 1.1
const FLICK_PERIOD := 1.2
const FLICK_DISTANCE := 70.0

var gesture := Gesture.NONE
var point := Vector2.ZERO
## Returns the point to show the gesture at, every frame (or null to keep the
## last one): an enemy's middle, a projectile...
var follow: Callable

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func show_tap(at: Vector2, follow_target: Callable = Callable()) -> void:
	gesture = Gesture.TAP
	point = at
	follow = follow_target
	visible = true

func show_flick(at: Vector2) -> void:
	gesture = Gesture.FLICK
	point = at
	follow = Callable()
	visible = true

func hide_gesture() -> void:
	gesture = Gesture.NONE
	visible = false

func _process(_delta: float) -> void:
	if gesture == Gesture.NONE:
		return
	if follow.is_valid():
		var target = follow.call()
		if target is Vector2:
			point = target
	queue_redraw()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _draw() -> void:
	match gesture:
		Gesture.TAP:
			_draw_tap()
		Gesture.FLICK:
			_draw_flick()

# Hand comes down onto the point, presses (a ring pings out), lifts off.
func _draw_tap() -> void:
	var t := fmod(_now(), TAP_PERIOD) / TAP_PERIOD
	var lift := 0.0
	if t < 0.3:
		lift = lerpf(14.0, 0.0, t / 0.3)
	elif t > 0.65:
		lift = lerpf(0.0, 14.0, (t - 0.65) / 0.35)
	if t >= 0.3 and t < 0.75:
		var r := (t - 0.3) / 0.45
		var ring := RING
		ring.a = 1.0 - r
		draw_arc(point.round(), roundf(lerpf(4.0, 18.0, r)), 0.0, TAU, 24, ring, 2.0, false)
	_draw_hand(point + Vector2(0, lift))

# Press, swipe down fast with a trail, fade out, pause.
func _draw_flick() -> void:
	var t := fmod(_now(), FLICK_PERIOD) / FLICK_PERIOD
	var travel := 0.0
	var alpha := 1.0
	if t >= 0.2 and t < 0.4:
		travel = FLICK_DISTANCE * pow((t - 0.2) / 0.2, 2.0)
	elif t >= 0.4:
		travel = FLICK_DISTANCE
		alpha = maxf(1.0 - (t - 0.4) / 0.25, 0.0)
	if alpha <= 0.0:
		return
	if travel > 6.0:
		var trail := RING
		trail.a = 0.6 * alpha
		draw_rect(Rect2((point + Vector2(-1, 0)).round(), Vector2(2, travel)), trail)
	_draw_hand(point + Vector2(0, travel), alpha)

func _draw_hand(tip: Vector2, alpha := 1.0) -> void:
	var outline := Color(OUTLINE, alpha)
	var fill := Color(FILL, alpha)
	var origin := (tip - FINGERTIP * ART_SCALE - Vector2(ART_SCALE / 2.0, 0)).round()
	for y in ART.size():
		var row: String = ART[y]
		for x in row.length():
			var c := row[x]
			if c == " ":
				continue
			draw_rect(Rect2(origin + Vector2(x, y) * ART_SCALE, Vector2.ONE * ART_SCALE), outline if c == "X" else fill)
