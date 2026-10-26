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
## instructions/ammo band at the bottom. Enemies with art stand with their
## feet on the bottom-centre of the slot. Far slots reach into the top 35%
## that stays visible (blurred) while in cover; near slots are behind the
## cover. Rect size fakes depth for enemies without art (near = bigger).
@export var slots: Dictionary[StringName, Rect2] = {
	&"far_left": Rect2(20, 184, 50, 85),
	&"far_center": Rect2(155, 162, 45, 75),
	&"far_right": Rect2(280, 198, 45, 75),
	&"near_center": Rect2(85, 394, 60, 100),
	&"near_right": Rect2(255, 430, 50, 85),
}
## Whole-number scale for enemy art per slot (missing = 1): far slots draw
## at 2x, near slots at 3x so enemies there read as right in front of you.
@export var slot_scales: Dictionary[StringName, int] = {
	&"far_left": 2,
	&"far_center": 2,
	&"far_right": 2,
	&"near_center": 3,
	&"near_right": 3,
}
@export var encounter: FTEncounter
## The battle's background: walkers stand on its floor (ground_slots);
## floaters, and slots it doesn't list, use `slots` above.
var backdrop: FTBackdrop
## Prototype-only: restart the encounter instead of finishing it.
@export var endless := false

var enemies: Array[FTEnemy] = []  # includes ones still fading out
var pending: Array[FTSpawn] = []  # waiting for their slot to free up
var next_wave := 0
var wave_clock := 0.0  # seconds since the last wave arrived
var running := false
## Summoners past their health threshold: FTEnemy -> {summons, cooldown}.
var summoners := {}

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
	_update_summons(delta)
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

## Where an enemy of `type` stands in `slot`: on the backdrop's floor, or in
## the air for floaters.
func slot_rect(slot: StringName, type: FTEnemyType) -> Rect2:
	if not type.floats and backdrop and backdrop.ground_slots.has(slot):
		return backdrop.ground_slots[slot]
	return slots[slot]

# Summoners at or below their health threshold keep `summon_count` summons
# alive: the first ones arrive at once, replacements `summon_refill_seconds`
# after one dies. Summons take free slots, furthest from the summoner first.
func _update_summons(delta: float) -> void:
	for e in summoners.keys():
		if not is_instance_valid(e) or not e.alive:
			summoners.erase(e)
	for enemy: FTEnemy in enemies.duplicate():  # spawning adds to `enemies`
		var t := enemy.type
		if not enemy.alive or enemy.entering or t.summon_type == null or t.summon_count <= 0:
			continue
		if enemy.health > t.max_health * t.summon_below_health:
			continue
		var state: Dictionary = summoners.get_or_add(enemy, {"summons": [], "cooldown": 0.0})
		state.summons = state.summons.filter(func(s): return is_instance_valid(s) and s.alive)
		if state.summons.size() >= t.summon_count:
			state.cooldown = t.summon_refill_seconds
			continue
		state.cooldown -= delta
		if state.cooldown > 0.0:
			continue
		var free := slots.keys().filter(func(k: StringName):
			return not _slot_taken(k) and not pending.any(func(s: FTSpawn): return s.slot == k))
		if free.is_empty():
			continue
		var own_y := slot_rect(enemy.slot, t).end.y
		free.sort_custom(func(a, b): return absf(slots[a].end.y - own_y) > absf(slots[b].end.y - own_y))
		var spawn := FTSpawn.new()
		spawn.enemy_type = t.summon_type
		spawn.slot = free[0]
		var summon := _spawn(spawn)
		var arc_speed := t.summon_type.arc_speed
		if not state.summons.is_empty() and arc_speed > 0.0:
			# Arcing summons share one path: start on the far side from the
			# last one so they don't stack.
			summon.time = state.summons[-1].time + PI / arc_speed
		state.summons.append(summon)

# A burrower went underground: it rises next in a random free slot (not one
# a waiting spawn needs). If none is free it rises where it was.
func _on_burrowed(enemy: FTEnemy) -> void:
	var free := slots.keys().filter(func(k: StringName):
		return k != enemy.slot and not _slot_taken(k) and not pending.any(func(s: FTSpawn): return s.slot == k))
	if free.is_empty():
		return
	var new_slot: StringName = free.pick_random()
	enemy.slot = new_slot
	enemy.relocate(slot_rect(new_slot, enemy.type), slot_scales.get(new_slot, 1))

# Dying enemies hold their slot until they finish fading out.
func _slot_taken(slot: StringName) -> bool:
	return enemies.any(func(e: FTEnemy): return e.slot == slot)

func _spawn(spawn: FTSpawn) -> FTEnemy:
	var rect := slot_rect(spawn.slot, spawn.enemy_type)
	var enemy := FTEnemy.new()
	enemy.type = spawn.enemy_type
	enemy.slot = spawn.slot
	enemy.art_scale = slot_scales.get(spawn.slot, 1)
	enemy.position = rect.position
	enemy.size = rect.size
	enemy.z_index = int(rect.end.y)  # lower feet = nearer = drawn in front
	if spawn.enemy_type.burrows:
		enemy.burrowed.connect(_on_burrowed.bind(enemy))
	add_child(enemy)
	enemies.append(enemy)
	enemy.tree_exiting.connect(enemies.erase.bind(enemy))
	enemy_spawned.emit(enemy)
	return enemy
