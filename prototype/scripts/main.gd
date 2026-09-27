extends Node

@onready var weapon: FTWeapon = $Weapon
@onready var input: FTPlayerInput = $PlayerInput
@onready var hud: FTHud = $HUD

func _ready() -> void:
	hud.setup_ammo(weapon.magazine_size)
	input.shoot_requested.connect(weapon.fire)
	input.reload_requested.connect(weapon.reload)
	weapon.fired.connect(hud.show_shot_feedback)
	weapon.ammo_changed.connect(hud.update_ammo)
	weapon.empty_triggered.connect(hud.show_reload)
	weapon.reload_started.connect(hud.hide_reload)
	weapon.reload_finished.connect(hud.hide_reload)
	hud.update_ammo(weapon.ammo, weapon.magazine_size)
