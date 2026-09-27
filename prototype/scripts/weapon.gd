class_name FTWeapon
extends Node

signal fired(screen_position: Vector2)
signal ammo_changed(current: int, maximum: int)
signal empty_triggered
signal reload_started
signal reload_finished

@export var magazine_size := 6
@export var reload_seconds := 0.65
var ammo := 0
var is_reloading := false

func _ready() -> void:
	ammo = magazine_size
	ammo_changed.emit(ammo, magazine_size)

func fire(screen_position: Vector2) -> void:
	if is_reloading:
		return
	if ammo <= 0:
		empty_triggered.emit()
		return
	ammo -= 1
	fired.emit(screen_position)
	ammo_changed.emit(ammo, magazine_size)
	if ammo == 0:
		empty_triggered.emit()

func reload() -> void:
	if is_reloading or ammo == magazine_size:
		return
	is_reloading = true
	reload_started.emit()
	await get_tree().create_timer(reload_seconds).timeout
	ammo = magazine_size
	is_reloading = false
	ammo_changed.emit(ammo, magazine_size)
	reload_finished.emit()
