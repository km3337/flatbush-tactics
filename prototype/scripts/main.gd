class_name FTBattle
extends Node

const BIOMES: Array[FTBiome] = [
	preload("res://biomes/street.tres"),
	preload("res://biomes/subway_platform.tres"),
	preload("res://biomes/subway_car.tres"),
]
# Only when the battle is launched directly (no route): alternate these.
const STOPS: Array[FTEncounter] = [
	preload("res://encounters/test_street.tres"),
	preload("res://encounters/test_elite.tres"),
]

const RESTART_SECONDS := 1.5
## After picking a reward, long enough to read its pop-up.
const REWARD_SECONDS := 2.0
## CLEARED shows on its own this long before the reward picker opens.
const CLEARED_BEAT_SECONDS := 0.8
# Battlefield is the minimum visible area (the project's base resolution).
# Taller/wider screens show extra space around it; with the "expand" stretch aspect
# that space appears right/bottom, so the layer is re-centred.
const BATTLEFIELD_SIZE := Vector2(360, 640)
const GEAR_SOURCE_HEADERS := {
	FTGear.Source.START: "STARTING GEAR",                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
	FTGear.Source.ELITE: "ELITE REWARD",
	FTGear.Source.EVENT: "NEW GEAR",
}

@export var biome: FTBiome = BIOMES[0]
@onready var weapon: FTWeapon = $Weapon
@onready var input: FTPlayerInput = $PlayerInput
@onready var hud: FTHud = $HUD
@onready var cover: FTCover = $Cover
@onready var player: FTPlayer = $Player
@onready var biome_label: Label = $HUD/BiomeLabel
@onready var director: FTEncounterDirector = $Enemies
var wave_text := ""
var is_down := false
var is_cleared := false
var buffered_shot := Vector2.ZERO
var has_buffered_shot := false
func _ready() -> void:
	if not Run.active:
		Run.start_run()  # battle launched directly, e.g. from the editor
	hud.set_gear(Run.gear)
	if not Run.starting_gear_announced and not Run.gear.is_empty():
		hud.show_gear_info(Run.gear[0], GEAR_SOURCE_HEADERS[FTGear.Source.START])
		Run.starting_gear_announced = true
	Run.gear_added.connect(_on_gear_added)
	_apply_gear_stats()
	player.health = Run.current_hp()  # HP carries between stops
	hud.setup_ammo(weapon.magazine_size)
	input.shoot_requested.connect(_on_shoot_requested)
	input.reload_requested.connect(_on_reload_requested)
	weapon.fired.connect(hud.show_shot_feedback)
	weapon.ammo_changed.connect(hud.update_ammo)
	weapon.arsenal_changed.connect(hud.update_arsenal)
	weapon.empty_triggered.connect(hud.show_reload)
	weapon.reload_started.connect(hud.hide_reload)
	weapon.reload_finished.connect(hud.hide_reload)
	weapon.load_arsenal(Run.arsenal, Run.rng)
	weapon.fired.connect(_on_weapon_fired)
	player.health_changed.connect(_on_player_health_changed)
	player.downed.connect(_on_player_downed)
	_on_player_health_changed(player.health, player.max_health)
	director.enemy_spawned.connect(_on_enemy_spawned)
	director.wave_started.connect(_on_wave_started)
	director.cleared.connect(_on_encounter_cleared)
	_set_biome(biome)
	Run.trigger(&"on_battle_start", [self])
	var station := Run.current_station
	director.start(station.encounter if station and station.encounter else STOPS[Run.stop_index % STOPS.size()])
	var extra := Run.take_extra_enemies()
	if extra > 0:  # an event set up an ambush
		director.add_extra_enemies(Run.STAGE_CONFIG.ambush_enemy, extra)
		hud.show_info_text("AMBUSH!", "+%d %s" % [extra, "ENEMY" if extra == 1 else "ENEMIES"])
	hud.update_money(Run.money)
	get_viewport().size_changed.connect(_center_battlefield)
	_center_battlefield()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# Prototype-only: B cycles biomes to compare cover looks.
	if event.physical_keycode == KEY_B:
		_set_biome(BIOMES[(BIOMES.find(biome) + 1) % BIOMES.size()])
		get_viewport().set_input_as_handled()
	# Prototype-only: G grants gear the way an event would.
	elif event.physical_keycode == KEY_G:
		Run.grant_random_gear(FTGear.Source.EVENT)
		get_viewport().set_input_as_handled()

func _set_biome(new_biome: FTBiome) -> void:
	biome = new_biome
	cover.apply_biome(biome)
	_update_status_label()

func _update_status_label() -> void:
	biome_label.text = "BIOME: %s   %s" % [biome.display_name.to_upper(), wave_text]

# Rebuilt from the freelancer's base stats every time, so gear stacks in
# pickup order. Gaining max HP also heals by the same amount.
func _apply_gear_stats() -> void:
	var freelancer := Run.freelancer
	weapon.magazine_size = roundi(Run.modify_stat(&"magazine_size", freelancer.magazine_size))
	weapon.reload_seconds = Run.modify_stat(&"reload_seconds", freelancer.reload_seconds)
	weapon.fire_cooldown = Run.modify_stat(&"fire_cooldown", freelancer.fire_cooldown)
	var old_max := player.max_health
	player.max_health = Run.max_hp()
	player.health = clampi(player.health + player.max_health - old_max, 0, player.max_health)

func _on_gear_added(gear: FTGear, source: FTGear.Source) -> void:
	hud.add_gear(gear)
	hud.show_gear_info(gear, GEAR_SOURCE_HEADERS[source])
	_apply_gear_stats()
	hud.update_ammo(weapon.magazine, weapon.magazine_size)
	_on_player_health_changed(player.health, player.max_health)

# Space / swipe down toggles cover: going in reloads, and the player is locked
# in until the reload finishes.
func _on_reload_requested() -> void:
	if is_down or is_cleared:
		return
	if cover.in_cover:
		if not weapon.is_reloading:
			cover.exit()
		return
	has_buffered_shot = false  # ducking cancels a queued shot
	cover.enter()
	weapon.reload()

# Taps do nothing while in cover, or once the battle is over. A tap during
# the shot cooldown is remembered (only the latest) and fires the moment the
# cooldown ends.
func _on_shoot_requested(screen_position: Vector2) -> void:
	if not _can_shoot():
		return
	if weapon.is_cooling_down():
		buffered_shot = screen_position
		has_buffered_shot = true
		return
	weapon.fire(screen_position)

func _can_shoot() -> bool:
	return not (is_down or is_cleared or cover.in_cover or weapon.is_reloading)

func _process(_delta: float) -> void:
	Reticle.cooldown_ratio = weapon.cooldown_ratio()
	if has_buffered_shot and not weapon.is_cooling_down():
		has_buffered_shot = false
		if _can_shoot():
			weapon.fire(buffered_shot)

func _exit_tree() -> void:
	Reticle.cooldown_ratio = 0.0

func _center_battlefield() -> void:
	var visible_size := get_viewport().get_visible_rect().size
	director.position = ((visible_size - BATTLEFIELD_SIZE) / 2.0).floor()

func _on_enemy_spawned(enemy: FTEnemy) -> void:
	enemy.attacked.connect(_on_enemy_attacked)
	enemy.died.connect(_on_enemy_died.bind(enemy))
	cover.track_enemy(enemy)

# Any kill counts: shots, burn ticks, thunder arcs.
func _on_enemy_died(enemy: FTEnemy) -> void:
	hud.react("kill")
	Run.trigger(&"on_kill", [self, enemy])

func _on_wave_started(number: int, total: int) -> void:
	var elite := director.encounter.tier == FTEncounter.Tier.ELITE
	wave_text = "%sWAVE %d/%d" % ["ELITE " if elite else "", number, total]
	_update_status_label()

# Show CLEARED, pay out rewards (elite gear, then ammo), then hand back to
# the run (route screen, or Stage Clear after the Last Stop).
func _on_encounter_cleared() -> void:
	if director.endless or is_down:
		return
	is_cleared = true
	var pay := Run.roll_fight_money(director.encounter)
	Run.money += pay
	hud.update_money(Run.money)
	hud.show_cleared(pay)
	await get_tree().create_timer(CLEARED_BEAT_SECONDS).timeout
	var wait := RESTART_SECONDS
	if director.encounter.tier == FTEncounter.Tier.ELITE:
		var choices := Run.roll_gear_choices(FTGear.Source.ELITE)
		if not choices.is_empty():
			hud.show_choice(choices, "ELITE REWARD\nCHOOSE ONE")
			var picked: FTGear = await hud.choice_made
			Run.add_gear(picked, FTGear.Source.ELITE)
			wait = REWARD_SECONDS
	if await _offer_ammo_reward():
		wait = REWARD_SECONDS
	await get_tree().create_timer(wait).timeout
	if Run.current_station:
		Run.complete_stop()
	else:  # launched directly: loop the test encounters
		Run.stop_index += 1
		get_tree().reload_current_scene()

# Every fight offers 1 of 3 ammo modifiers (skippable). The new round goes
# into the arsenal; if that puts it over capacity, the player removes one.
func _offer_ammo_reward() -> bool:
	var mods := Run.roll_ammo_choices()
	if mods.is_empty():
		return false
	hud.show_choice(mods, "AMMO REWARD\nARSENAL %d/%d" % [Run.arsenal.size(), Run.arsenal_capacity()], true)
	var picked: FTAmmoMod = await hud.choice_made
	if picked == null:
		return false
	Run.add_round(picked)
	if not Run.is_arsenal_over_capacity():
		hud.show_gear_info(picked, "ADDED TO ARSENAL")
		return true
	# One card per kind of round in the arsenal, with how many of each.
	var kinds: Array[FTAmmoMod] = []
	var counts: Array[String] = []
	for owned in Run.arsenal:
		if owned not in kinds:
			kinds.append(owned)
	for kind in kinds:
		counts.append("  x%d" % Run.arsenal.count(kind))
	hud.show_choice(kinds, "ARSENAL FULL\nREMOVE A ROUND", false, counts)
	var removed: FTAmmoMod = await hud.choice_made
	Run.remove_round(removed)
	hud.show_gear_info(picked, "ADDED TO ARSENAL (REMOVED 1 %s)" % removed.display_name.to_upper())
	return true

func _on_weapon_fired(screen_position: Vector2) -> void:
	var shot_round := weapon.last_fired
	# Last in the list draws on top, so check from the back.
	var enemies := director.enemies
	for i in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[i]
		if enemy.contains(screen_position):
			var damage := Run.shot_damage(self, enemy, enemy.winding_up)
			var countered := enemy.take_hit(damage)
			if countered:
				hud.show_counter()
				Run.trigger(&"on_counter", [self, enemy])
			shot_round.on_hit(self, enemy)
			Run.trigger(&"on_shot_hit", [self, enemy])
			# A kill already reacted through `died`.
			if enemy.alive:
				hud.react("counter" if countered else "hit_enemy")
			return
	hud.react("miss")

# Cover fully protects for now; partial cover can come later.
func _on_enemy_attacked() -> void:
	if is_down or is_cleared:
		return
	if cover.in_cover:
		hud.show_blocked()
		return
	var damage := Run.damage_taken(self, 1)
	if damage <= 0:
		return  # gear absorbed it; its icon pulses
	hud.show_player_hit()
	player.take_damage(damage)
	if not is_down:
		hud.react("got_hit")

func _on_player_health_changed(current: int, maximum: int) -> void:
	hud.update_health(current, maximum, player.is_low())
	Run.hp = current

# Going down ends the run (Run Over screen; all gear is lost).
func _on_player_downed() -> void:
	is_down = true
	hud.show_down()
	await get_tree().create_timer(RESTART_SECONDS).timeout
	Run.lose_run()
