extends Node

const BIOMES: Array[FTBiome] = [
	preload("res://biomes/street.tres"),
	preload("res://biomes/subway_platform.tres"),
	preload("res://biomes/subway_car.tres"),
]

# Placeholder enemy layout (720x1280 portrait): [rect, sway, staggerable].
# Kept below the cover's top peek strip so no enemy is visible while in cover,
# and above the instructions/ammo band at the bottom.
const ENEMY_LAYOUT := [
	[Rect2(60, 420, 70, 130), 0.0, true],
	[Rect2(300, 280, 60, 110), 60.0, false],
	[Rect2(320, 640, 80, 150), 0.0, true],
	[Rect2(530, 420, 60, 110), 70.0, true],
	[Rect2(560, 780, 70, 130), 0.0, false],
]
const RESTART_SECONDS := 1.5

@export var biome: FTBiome = BIOMES[0]
@onready var weapon: FTWeapon = $Weapon
@onready var input: FTPlayerInput = $PlayerInput
@onready var hud: FTHud = $HUD
@onready var cover: FTCover = $Cover
@onready var player: FTPlayer = $Player
@onready var biome_label: Label = $BiomeLabel
@onready var enemy_layer: Control = $Enemies
var enemies: Array[FTEnemy] = []
var is_down := false

func _ready() -> void:
	hud.setup_ammo(weapon.magazine_size)
	input.shoot_requested.connect(_on_shoot_requested)
	input.reload_requested.connect(_on_reload_requested)
	weapon.fired.connect(hud.show_shot_feedback)
	weapon.ammo_changed.connect(hud.update_ammo)
	weapon.empty_triggered.connect(hud.show_reload)
	weapon.reload_started.connect(hud.hide_reload)
	weapon.reload_finished.connect(hud.hide_reload)
	hud.update_ammo(weapon.ammo, weapon.magazine_size)
	weapon.fired.connect(_on_weapon_fired)
	player.health_changed.connect(_on_player_health_changed)
	player.downed.connect(_on_player_downed)
	_on_player_health_changed(player.health, player.max_health)
	_set_biome(biome)
	_spawn_enemies()

func _unhandled_input(event: InputEvent) -> void:
	# Prototype-only: B cycles biomes to compare cover looks.
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B:
		_set_biome(BIOMES[(BIOMES.find(biome) + 1) % BIOMES.size()])
		get_viewport().set_input_as_handled()

func _set_biome(new_biome: FTBiome) -> void:
	biome = new_biome
	cover.apply_biome(biome)
	biome_label.text = "BIOME: %s" % biome.display_name.to_upper()

# Space / swipe down toggles cover: going in reloads, and the player is locked
# in until the reload finishes.
func _on_reload_requested() -> void:
	if is_down:
		return
	if cover.in_cover:
		if not weapon.is_reloading:
			cover.exit()
		return
	cover.enter()
	weapon.reload()

# Taps do nothing while in cover.
func _on_shoot_requested(screen_position: Vector2) -> void:
	if is_down or cover.in_cover:
		return
	weapon.fire(screen_position)

func _spawn_enemies() -> void:
	for entry in ENEMY_LAYOUT:
		var enemy := FTEnemy.new()
		enemy.position = entry[0].position
		enemy.size = entry[0].size
		enemy.sway = entry[1]
		enemy.staggerable = entry[2]
		enemy_layer.add_child(enemy)
		enemy.attacked.connect(_on_enemy_attacked)
		enemies.append(enemy)
	cover.track_enemies(enemies)

func _on_weapon_fired(screen_position: Vector2) -> void:
	# Last in the list draws on top, so check from the back.
	for i in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[i]
		if enemy.contains(screen_position):
			var countered := enemy.take_hit()
			if countered:
				hud.show_counter()
			if not enemy.alive:
				hud.react("kill")
			elif countered:
				hud.react("counter")
			else:
				hud.react("hit_enemy")
			return
	hud.react("miss")

# Cover fully protects for now; partial cover can come later.
func _on_enemy_attacked() -> void:
	if is_down:
		return
	if cover.in_cover:
		hud.show_blocked()
		return
	hud.show_player_hit()
	player.take_damage()
	if not is_down:
		hud.react("got_hit")

func _on_player_health_changed(current: int, maximum: int) -> void:
	hud.update_health(current, maximum, player.is_low())

func _on_player_downed() -> void:
	is_down = true
	hud.show_down()
	await get_tree().create_timer(RESTART_SECONDS).timeout
	get_tree().reload_current_scene()
