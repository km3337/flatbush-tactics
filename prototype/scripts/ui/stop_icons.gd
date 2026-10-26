class_name FTStopIcons
extends RefCounted

## Placeholder stop icons drawn in code (sword, crossed swords, ?, $,
## construction cone for hidden stops, black square for the Last Stop),
## shared by every screen that shows stops. Swap for textures once there's
## art. `pos` is the icon's centre; icons fit in about 14x14.

const INK := Color(0.08, 0.08, 0.09)
const ELITE_RED := Color(0.7, 0.08, 0.1)
const CONE := Color(1.0, 0.45, 0.05)

static func draw(canvas: CanvasItem, station: FTStation, pos: Vector2, alpha := 1.0, ink := INK) -> void:
	ink = Color(ink, alpha)
	if station.hidden:
		draw_cone(canvas, pos, alpha)
		return
	match station.kind:
		FTStation.Kind.BATTLE:
			_sword(canvas, pos, 1.0, ink)
		FTStation.Kind.ELITE:
			var red := Color(ELITE_RED, alpha) if ink.get_luminance() < 0.5 else Color(1.0, 0.35, 0.35, alpha)
			_sword(canvas, pos, 1.0, red)
			_sword(canvas, pos, -1.0, red)
		FTStation.Kind.EVENT, FTStation.Kind.SHOP:
			var text := "?" if station.kind == FTStation.Kind.EVENT else "$"
			canvas.draw_string(canvas.get_theme_default_font(), pos + Vector2(-10, 4), text, HORIZONTAL_ALIGNMENT_CENTER, 20, 8, ink)  # 7px caps, centred
		FTStation.Kind.LAST_STOP:
			canvas.draw_rect(Rect2(pos - Vector2(5, 5), Vector2(10, 10)), ink)

static func draw_cone(canvas: CanvasItem, pos: Vector2, alpha := 1.0) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -7), pos + Vector2(5, 5), pos + Vector2(-5, 5)]), Color(CONE, alpha))
	canvas.draw_line(pos + Vector2(-3, 1), pos + Vector2(3, 1), Color(Color.WHITE, alpha), 2.0)
	canvas.draw_line(pos + Vector2(-6, 6), pos + Vector2(6, 6), Color(CONE, alpha), 2.0)

## A route bullet: coloured circle with the line's letter/number.
static func draw_bullet(canvas: CanvasItem, line: FTLine, pos: Vector2, radius: float, alpha := 1.0) -> void:
	canvas.draw_circle(pos, radius, Color(line.color, alpha))
	var size := 16 if radius >= 12.0 else 8  # the font's 8px grid
	canvas.draw_string(canvas.get_theme_default_font(), pos + Vector2(-radius, roundf(size * 0.4375)), line.bullet, HORIZONTAL_ALIGNMENT_CENTER, radius * 2, size, Color(line.text_color, alpha))

# Diagonal blade with a crossguard; `flip` mirrors it for crossed swords.
static func _sword(canvas: CanvasItem, pos: Vector2, flip: float, color: Color) -> void:
	canvas.draw_line(pos + Vector2(-4 * flip, 4), pos + Vector2(5 * flip, -5), color, 2.0)
	var guard := pos + Vector2(-2 * flip, 2)
	canvas.draw_line(guard + Vector2(-2, -2), guard + Vector2(2, 2), color, 2.0)
