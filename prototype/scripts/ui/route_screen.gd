class_name FTRouteScreen
extends Control

## Between stops: an MTA countdown-style screen showing where you are, the
## stops ahead on your line, and your HP / gear / arsenal. CONTINUE (or Space /
## Enter) leaves for the next stop.

@onready var welcome: Label = %Welcome
@onready var status: Label = %Status
@onready var destination: Label = %Destination
@onready var bullet: Control = %Bullet
@onready var route_view: FTRouteView = %RouteView
@onready var continue_button: Button = %ContinueButton

func _ready() -> void:
	var line := Run.current_line()
	var here := Run.current_station
	welcome.text = "Welcome to %s" % (here.display_name if here else "the platform")
	status.text = "HP %d/%d   $%d   GEAR %d   ARSENAL %d/%d" % [Run.current_hp(), Run.max_hp(), Run.money, Run.gear.size(), Run.arsenal.size(), Run.arsenal_capacity()]
	destination.text = "to %s" % Run.stage.last_stop.display_name
	bullet.draw.connect(func(): FTStopIcons.draw_bullet(bullet, line, bullet.size / 2.0, 20.0))
	var next := Run.upcoming_station()
	continue_button.text = "CONTINUE TO %s" % next.display_name.to_upper()
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = line.color.lightened(0.1) if state == "hover" else line.color
		style.set_corner_radius_all(4)
		continue_button.add_theme_stylebox_override(state, style)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		continue_button.add_theme_color_override(color_name, line.text_color)
	continue_button.pressed.connect(_continue)
	route_view.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_continue()

func _continue() -> void:
	if continue_button.disabled:
		return
	continue_button.disabled = true
	Run.depart()
