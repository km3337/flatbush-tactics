class_name FTWeapon
extends Node

## The freelancer's gun, loaded from their arsenal like a deck of cards.
## At battle start the arsenal is shuffled into the draw pile. Firing spends
## the chambered round (magazine[0]) into the discard pile. Reloading keeps
## unfired rounds and tops the magazine up from the draw pile; when the draw
## pile runs out, the discard pile is reshuffled into it.

signal fired(screen_position: Vector2)
signal ammo_changed(magazine: Array[FTAmmoMod], maximum: int)
signal arsenal_changed(draw_count: int, discard_count: int)
signal empty_triggered
signal reload_started
signal reload_finished

## Set from the freelancer (plus gear) at battle start.
@export var magazine_size := 5
@export var reload_seconds := 0.65
## Seconds after a shot before the next one can fire.
@export var fire_cooldown := 0.4
var cooldown_left := 0.0
var magazine: Array[FTAmmoMod] = []  # [0] fires next
var draw_pile: Array[FTAmmoMod] = []
var discard_pile: Array[FTAmmoMod] = []
## The round that just fired; valid while `fired` is being handled.
var last_fired: FTAmmoMod
var is_reloading := false
var rng := RandomNumberGenerator.new()

var ammo: int:
	get: return magazine.size()

func load_arsenal(rounds: Array[FTAmmoMod], random: RandomNumberGenerator) -> void:
	rng = random
	draw_pile = rounds.duplicate()
	_shuffle(draw_pile)
	discard_pile.clear()
	magazine.clear()
	_top_up()
	_emit_changes()

func _process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)

func is_cooling_down() -> bool:
	return cooldown_left > 0.0

## 1 right after a shot, falling to 0 when the next shot is ready.
func cooldown_ratio() -> float:
	return cooldown_left / fire_cooldown if fire_cooldown > 0.0 else 0.0

func fire(screen_position: Vector2) -> void:
	if is_reloading or is_cooling_down():
		return
	if magazine.is_empty():
		empty_triggered.emit()
		return
	cooldown_left = fire_cooldown
	last_fired = magazine.pop_front()
	discard_pile.append(last_fired)
	fired.emit(screen_position)
	_emit_changes()
	if magazine.is_empty():
		empty_triggered.emit()

func reload() -> void:
	if is_reloading or magazine.size() >= magazine_size:
		return
	is_reloading = true
	reload_started.emit()
	await get_tree().create_timer(reload_seconds).timeout
	_top_up()
	is_reloading = false
	_emit_changes()
	reload_finished.emit()

func _top_up() -> void:
	while magazine.size() < magazine_size:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				return  # whole arsenal is already in the magazine
			draw_pile = discard_pile
			discard_pile = []
			_shuffle(draw_pile)
		magazine.append(draw_pile.pop_back())

# Fisher-Yates with the run's RNG, so a seeded run deals the same rounds.
func _shuffle(pile: Array[FTAmmoMod]) -> void:
	for i in range(pile.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := pile[i]
		pile[i] = pile[j]
		pile[j] = swap

func _emit_changes() -> void:
	ammo_changed.emit(magazine, magazine_size)
	arsenal_changed.emit(draw_pile.size(), discard_pile.size())
