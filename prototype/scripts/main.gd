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
	preload("res://encounters/test_tunnel.tres"),
	preload("res://encounters/test_elite.tres"),
	preload("res://encounters/dark_droid.tres"),
]

## Battle music, looped. Elite fights and the Last Stop use ELITE_MUSIC.
const BATTLE_MUSIC: AudioStream = preload("res://assets/music/battle_go_crazy.mp3")
const ELITE_MUSIC: AudioStream = preload("res://assets/music/elite_synkro.mp3")

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
@export var music_volume_db := -6.0
## When the fight ends (won or downed) the music fades out over this long.
@export var music_fade_seconds := 3.0
var music: AudioStreamPlayer
## The freelancer's shot sound; a few can overlap so quick shots don't cut
## each other off.
var shot_sound: AudioStreamPlayer
@onready var weapon: FTWeapon = $Weapon
@onready var input: FTPlayerInput = $PlayerInput
@onready var hud: FTHud = $HUD
@onready var cover: FTCover = $Cover
@onready var player: FTPlayer = $Player
@onready var biome_label: Label = $HUD/BiomeLabel
@onready var background_art: TextureRect = $BackgroundArt
@onready var director: FTEncounterDirector = $Enemies
var wave_text := ""
var is_down := false
var is_cleared := false
## The BATTLE START banner is up: no enemies yet, no shooting or reloading.
var is_starting := false
var buffered_shot := Vector2.ZERO
var has_buffered_shot := false
## Lobbed projectiles, drawn above the cover so they're visible while ducked.
var projectile_layer: CanvasLayer
## Lob projectiles still circling their thrower: FTEnemy -> FTLobProjectile.
var orbiting := {}
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
	weapon.ammo_changed.connect(hud.update_ammo)
	weapon.arsenal_changed.connect(hud.update_arsenal)
	weapon.empty_triggered.connect(hud.show_reload)
	weapon.reload_started.connect(hud.hide_reload)
	weapon.reload_finished.connect(hud.hide_reload)
	weapon.load_arsenal(Run.arsenal, Run.rng)
	weapon.fired.connect(_on_weapon_fired)
	shot_sound = AudioStreamPlayer.new()
	shot_sound.stream = Run.freelancer.fire_sound
	shot_sound.max_polyphony = 4
	add_child(shot_sound)
	player.health_changed.connect(_on_player_health_changed)
	player.downed.connect(_on_player_downed)
	_on_player_health_changed(player.health, player.max_health)
	projectile_layer = CanvasLayer.new()
	projectile_layer.layer = cover.layer  # same layer, added later: drawn on top
	add_child(projectile_layer)
	director.enemy_spawned.connect(_on_enemy_spawned)
	director.wave_started.connect(_on_wave_started)
	director.cleared.connect(_on_encounter_cleared)
	_set_biome(biome)
	hud.update_money(Run.money)
	get_viewport().size_changed.connect(_center_battlefield)
	_center_battlefield()
	var station := Run.current_station
	var encounter: FTEncounter = station.encounter if station and station.encounter else STOPS[Run.stop_index % STOPS.size()]
	_start_music(encounter)
	# Doors slide open, then BATTLE START; enemies arrive once it's gone.
	is_starting = true
	await FTClosingDoors.add_to(hud).open()
	await hud.show_battle_start()
	is_starting = false
	Run.trigger(&"on_battle_start", [self])
	director.start(encounter)
	var extra := Run.take_extra_enemies()
	if extra > 0:  # an event set up an ambush
		director.add_extra_enemies(Run.STAGE_CONFIG.ambush_enemy, extra)
		hud.show_info_text("AMBUSH!", "+%d %s" % [extra, "ENEMY" if extra == 1 else "ENEMIES"])

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
	# Cosmetic, so it doesn't draw from the run's seeded RNG.
	var backdrop: FTBackdrop = biome.backdrops.pick_random() if not biome.backdrops.is_empty() else null
	director.backdrop = backdrop
	background_art.texture = backdrop.texture if backdrop else null
	_center_battlefield()
	_update_status_label()

func _start_music(encounter: FTEncounter) -> void:
	var stream := BATTLE_MUSIC
	if encounter.tier >= FTEncounter.Tier.ELITE:
		stream = ELITE_MUSIC
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	music = AudioStreamPlayer.new()
	music.stream = stream
	music.volume_db = music_volume_db
	add_child(music)
	music.play()

func _fade_out_music() -> void:
	if music == null or not music.playing:
		return
	var tween := create_tween()
	tween.tween_property(music, "volume_db", -60.0, music_fade_seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(music.stop)

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
	if is_down or is_cleared or is_starting:
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
	return not (is_down or is_cleared or is_starting or cover.in_cover or weapon.is_reloading)

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
	if background_art.texture:
		var art_size := background_art.texture.get_size() * background_art.scale
		background_art.size = background_art.texture.get_size()
		background_art.position = ((visible_size - art_size) / 2.0).floor()

func _on_enemy_spawned(enemy: FTEnemy) -> void:
	enemy.attacked.connect(_on_enemy_attacked)
	enemy.died.connect(_on_enemy_died.bind(enemy))
	enemy.lob_readied.connect(_on_lob_readied.bind(enemy))
	enemy.lob_thrown.connect(_on_lob_thrown.bind(enemy))
	enemy.attack_cancelled.connect(_on_attack_cancelled.bind(enemy))
	cover.track_enemy(enemy)

# Countered for good: its circling / charging projectile bursts.
func _on_attack_cancelled(enemy: FTEnemy) -> void:
	var held = orbiting.get(enemy)
	orbiting.erase(enemy)
	if held != null and is_instance_valid(held) and not held.popped:
		held.pop()

# A lobbing enemy started its wind-up: the projectile appears and circles it.
func _on_lob_readied(enemy: FTEnemy) -> void:
	var lob := FTLobProjectile.new()
	projectile_layer.add_child(lob)
	lob.orbit(enemy)
	lob.landed.connect(_on_lob_landed)
	orbiting[enemy] = lob

# ...and threw it: it arcs toward the player (bottom-centre of the screen).
# If it was shot down while circling, there's nothing to throw.
func _on_lob_thrown(enemy: FTEnemy) -> void:
	var held = orbiting.get(enemy)  # may already be freed (popped)
	orbiting.erase(enemy)
	if held == null or not is_instance_valid(held) or held.popped:
		return
	var lob: FTLobProjectile = held
	var screen := get_viewport().get_visible_rect().size
	lob.launch(Vector2(screen.x / 2.0, screen.y * 0.8), enemy.type.lob_seconds, enemy.type.lob_damage)

# A lob that reaches the player hits even behind cover.
func _on_lob_landed(lob: FTLobProjectile) -> void:
	if is_down or is_cleared:
		return
	var damage := Run.damage_taken(self, lob.damage)
	if damage <= 0:
		return  # gear absorbed it
	hud.show_player_hit()
	player.take_damage(damage)
	if not is_down:
		hud.react("got_hit")

func _clear_projectiles() -> void:
	for lob in projectile_layer.get_children():
		lob.queue_free()
	orbiting.clear()

# Any kill counts: shots, burn ticks, thunder arcs.
func _on_enemy_died(enemy: FTEnemy) -> void:
	hud.react("kill")
	Run.trigger(&"on_kill", [self, enemy])

func _on_wave_started(number: int, total: int) -> void:
	var tier_tag: String = {FTEncounter.Tier.ELITE: "ELITE ", FTEncounter.Tier.BOSS: "BOSS "}.get(director.encounter.tier, "")
	wave_text = "%sWAVE %d/%d" % [tier_tag, number, total]
	_update_status_label()

# Show CLEARED, pay out rewards (elite gear, then ammo), then hand back to
# the run (route screen, or Stage Clear after the Last Stop).
func _on_encounter_cleared() -> void:
	if director.endless or is_down:
		return
	is_cleared = true
	_fade_out_music()
	_clear_projectiles()
	var pay := Run.roll_fight_money(director.encounter)
	Run.money += pay
	hud.update_money(Run.money)
	hud.show_cleared()
	await get_tree().create_timer(CLEARED_BEAT_SECONDS).timeout
	# Doors close over the HUD; reward picks and their pop-ups stay on top.
	var doors := FTClosingDoors.add_to(hud, hud.choice_panel.get_index())
	hud.move_child(hud.gear_info, hud.choice_panel.get_index())
	await doors.close()
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
	if shot_sound.stream:
		shot_sound.play()
	var shot_round := weapon.last_fired
	# Projectiles are in front of everything: they take the shot first.
	for lob: FTLobProjectile in projectile_layer.get_children():
		if lob.contains(screen_position):
			hud.show_hit_effect(screen_position)
			var thrower := lob.thrower()
			if not lob.launched and thrower and thrower.type.counter_hits > 0:
				# Takes several hits (droid or orb) to cancel: this is one.
				thrower.register_counter_hit()
				hud.show_counter()
				hud.react("counter")
				return
			lob.pop()
			hud.react("hit_enemy")
			return
	# Hit the enemy drawn on top: nearest (highest z_index) first, then the
	# latest spawned.
	var enemies := director.enemies.duplicate()
	enemies.reverse()
	enemies.sort_custom(func(a: FTEnemy, b: FTEnemy): return a.z_index > b.z_index)
	for enemy: FTEnemy in enemies:
		if enemy.contains(screen_position):
			var damage := Run.shot_damage(self, enemy, enemy.winding_up)
			var countered := enemy.take_hit(damage)
			if countered:
				hud.show_counter()
				Run.trigger(&"on_counter", [self, enemy])
			hud.show_hit_effect(screen_position)
			shot_round.on_hit(self, enemy)
			Run.trigger(&"on_shot_hit", [self, enemy])
			# A kill already reacted through `died`.
			if enemy.alive:
				hud.react("counter" if countered else "hit_enemy")
			return
	hud.show_shot_feedback(screen_position)
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
	_fade_out_music()
	_clear_projectiles()
	hud.show_down()
	await get_tree().create_timer(RESTART_SECONDS).timeout
	Run.lose_run()
