extends Node

## Plays the reward screen without fighting: starts a battle, wins it after
## BATTLE START, then shoots the cache and picks the second card of each
## choice with simulated taps. For checking the reward screen's look and
## feel, e.g. with Movie Maker:
##   Godot --path prototype --write-movie /tmp/frames/f.png --fixed-fps 30 \
##     --quit-after 600 res://tests/reward_preview.tscn -- elite full
## User args (after --): `elite` = an elite fight (gear + ammo), `full` = a
## full arsenal (adds the remove-a-round pick), `seed=N`, `manual` = no
## simulated taps (play it yourself).

const MAIN: PackedScene = preload("res://scenes/Main.tscn")
const ELITE_STOP := 2  # FTBattle.STOPS: test_elite

var args := OS.get_cmdline_user_args()
var battle: FTBattle

func _ready() -> void:
	var run_seed := 1
	for arg in args:
		if arg.begins_with("seed="):
			run_seed = int(arg.substr(5))
	Run.start_run(run_seed)
	if "elite" in args:
		Run.stop_index = ELITE_STOP
	if "full" in args:
		while not Run.is_arsenal_over_capacity() and Run.arsenal.size() < Run.arsenal_capacity():
			var mod = Run.AMMO_POOL.mods[Run.arsenal.size() % 2]
			Run.add_round(mod)
	battle = MAIN.instantiate()
	add_child(battle)
	await get_tree().create_timer(2.4).timeout
	battle.director.cleared.emit()
	if "manual" in args:
		return
	var hud := battle.hud
	while is_inside_tree():
		await get_tree().process_frame
		match hud.reward_phase:
			&"cache":
				await get_tree().create_timer(0.5).timeout
				while hud.reward_phase == &"cache":
					_tap(hud.cache.get_global_rect().get_center() + Vector2(randf_range(-16, 16), randf_range(-12, 12)))
					await get_tree().create_timer(0.35).timeout
			&"pick":
				await get_tree().create_timer(1.0).timeout
				var card: FTRewardCard = hud.cards[mini(1, hud.cards.size() - 1)]
				var at := card.global_position + Vector2(150, 36)
				_move(at)
				await get_tree().create_timer(0.6).timeout
				_tap(at)
				while hud.reward_phase == &"pick":
					await get_tree().process_frame

func _move(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion, true)

func _tap(at: Vector2) -> void:
	_move(at)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		click.global_position = at
		get_viewport().push_input(click, true)
