class_name FTEncounterDirector
extends Control

## Runs one FTEncounter: spawns its waves into named slots, starts each later
## wave when its trigger is met, and emits `cleared` once every wave has
## arrived and every enemy is dead. A spawn whose slot is still taken waits
## until that slot frees up. Enemies are children of this node, so later
## spawns draw on top.

signal enemy_spawned(enemy: FTEnemy)
signal wave_started(number: int, total: int)
signal cleared

## Where enemies can stand inside the 360x640 battlefield, above the
## instructions/ammo band at the bottom. Far slots reach into the top 35% that
## stays visible (blurred) while in cover; near slots are fully behind the
## cover. Rect size fakes depth (near = bigger).
@export var slots: Dictionary[StringName, Rect2] = {
	&"far_left": Rect2(20, 164, 50, 85),
	&"far_center": Rect2(155, 142, 45, 75),
	&"far_right": Rect2(280, 178, 45, 75),
	&"near_center": Rect2(145, 334, 60, 100),
	&"near_right": Rect2(260, 370, 50, 85),
}
@export var encounter: FTEncounter
## Prototype-only: restart the encounter instead of finishing it.
@export var endless := false

var enemies: Array[FTEnemy] = []  # includes ones still fading out
var pending: Array[FTSpawn] = []  # waiting for their slot to free up
var next_wave := 0
var wave_clock := 0.0  # seconds since the last wave arrived
var running := false

func start(new_encounter: FTEncounter = encounter) -> void:
	encounter = new_encounter
	next_wave = 0
	pending.clear()
	running = true
	_start_next_wave()

## Ambush: add `count` extra enemies of `type` to the wave that's starting,
## in slots the encounter isn't using if possible (else they wait for one).
func add_extra_enemies(type: FTEnemyType, count: int) -> void:
	var used := pending.map(func(s: FTSpawn): return s.slot)
	used.append_array(enemies.map(func(e: FTEnemy): return e.slot))
	var free := slots.keys().filter(func(k): return k not in used)
	for i in count:
		var spawn := FTSpawn.new()
		spawn.enemy_type = type
		spawn.slot = free[i] if i < free.size() else slots.keys()[i % slots.size()]
		pending.append(spawn)
	_place_pending()

func alive_count() -> int:
	return enemies.filter(func(e: FTEnemy): return e.alive).size()

func _process(delta: float) -> void:
	if not running:
		return
	wave_clock += delta
	_place_pending()
	if next_wave < encounter.waves.size():
		if _trigger_met(encounter.waves[next_wave]):
			_start_next_wave()
	elif pending.is_empty() and alive_count() == 0:
		running = false
		cleared.emit()
		if endless:
			start()

func _trigger_met(wave: FTWave) -> bool:
	match wave.trigger:
		FTWave.Trigger.ALIVE_AT_MOST:
			return alive_count() + pending.size() <= int(wave.trigger_value)
		FTWave.Trigger.AFTER_SECONDS:
			return wave_clock >= wave.trigger_value
		_:
			return alive_count() == 0 and pending.is_empty()

func _start_next_wave() -> void:
	var wave := encounter.waves[next_wave]
	next_wave += 1
	wave_clock = 0.0
	pending.append_array(wave.spawns)
	wave_started.emit(next_wave, encounter.waves.size())
	_place_pending()

func _place_pending() -> void:
	var i := 0
	while i < pending.size():
		var spawn := pending[i]
		if not slots.has(spawn.slot):
			push_error("Encounter '%s' uses unknown slot '%s'" % [encounter.display_name, spawn.slot])
			pending.remove_at(i)
		elif _slot_taken(spawn.slot):
			i += 1
		else:
			pending.remove_at(i)
			_spawn(spawn)

# Dying enemies hold their slot until they finish fading out.
func _slot_taken(slot: StringName) -> bool:
	return enemies.any(func(e: FTEnemy): return e.slot == slot)

func _spawn(spawn: FTSpawn) -> void:
	var rect := slots[spawn.slot]
	var enemy := FTEnemy.new()
	enemy.type = spawn.enemy_type
	enemy.slot = spawn.slot
	enemy.position = rect.position
	enemy.size = rect.size
	add_child(enemy)
	enemies.append(enemy)
	enemy.tree_exiting.connect(enemies.erase.bind(enemy))
	enemy_spawned.emit(enemy)
