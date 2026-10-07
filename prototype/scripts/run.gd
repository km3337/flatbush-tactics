class_name FTRun
extends Node

## Autoload `Run`: state that lasts for one run and survives scene reloads.
## Owns the freelancer, their arsenal (ammo rounds), the gear list, HP, the
## stage map and the player's place on it; rolls rewards; fans gear hooks out
## to every owned gear; and moves between the run's screens:
##   Freelancer Select -> Line Select -> Transit -> stop (battle / event /
##   shop) -> Route -> Transit
##   -> ... -> Last Stop -> Stage Clear   (going down -> Run Over)
##   New Run returns to Freelancer Select.
## Gear and arsenal pickups are lost when the run ends, win or lose.

signal gear_added(gear: FTGear, source: FTGear.Source)

const GEAR_POOL: FTGearPool = preload("res://gear/gear_pool.tres")
const AMMO_POOL: FTAmmoPool = preload("res://ammo/ammo_pool.tres")
## Only one freelancer so far; picking one belongs on a run-start screen.
const DEFAULT_FREELANCER: FTFreelancer = preload("res://freelancers/ali.tres")
const STAGE_CONFIG: FTStageConfig = preload("res://stages/stage_1.tres")
const EVENT_POOL: FTEventPool = preload("res://events/event_pool.tres")
const FREELANCER_SELECT_SCENE := "res://scenes/FreelancerSelect.tscn"
const LINE_SELECT_SCENE := "res://scenes/LineSelect.tscn"
const ROUTE_SCENE := "res://scenes/Route.tscn"
const TRANSIT_SCENE := "res://scenes/Transit.tscn"
const BATTLE_SCENE := "res://scenes/Main.tscn"
const EVENT_SCENE := "res://scenes/Event.tscn"
const SHOP_SCENE := "res://scenes/Shop.tscn"
const RUN_OVER_SCENE := "res://scenes/RunOver.tscn"
const STAGE_CLEAR_SCENE := "res://scenes/StageClear.tscn"
const RARITY_WEIGHTS := {
	FTGear.Rarity.COMMON: 60.0,
	FTGear.Rarity.UNCOMMON: 30.0,
	FTGear.Rarity.RARE: 10.0,
}

var active := false
var freelancer: FTFreelancer
## Every round the freelancer owns; the weapon deals from this each battle.
var arsenal: Array[FTAmmoMod] = []
var gear: Array[FTGear] = []
## Shown once, by the first battle's HUD.
var starting_gear_announced := false
## Current HP, carried between stops. -1 = full (before the first fight).
var hp := -1
## Max HP gained from events this run (gear adds its own through stats).
var bonus_max_hp := 0
var money := 0
## Extra enemies the next battle adds to its first wave (event ambushes).
var extra_enemies_next_battle := 0
## Events already seen this run; not offered again until all have been.
var seen_events: Array[StringName] = []
## The current stage's map, and the line the player is riding (-1 = not yet).
var stage: FTStageMap
var line_index := -1
## Index on the current line of the last line station reached (-1 = boarded,
## not arrived anywhere yet). Detour stops don't move it.
var route_depth := -1
## The stop the player is at (line station or detour stop).
var current_station: FTStation
## Forced ? stops still to play before rejoining the line.
var detour_queue: Array[FTStation] = []
var detours_taken: Array[FTStation] = []
var stops_cleared := 0
## Only used when a battle is launched directly (no route): which test
## encounter to play next.
var stop_index := 0
var run_seed := 0
var rng := RandomNumberGenerator.new()

## Seeded so a run (and its rolls and shuffles) can be replayed.
func start_run(new_seed: int = randi(), new_freelancer: FTFreelancer = DEFAULT_FREELANCER) -> void:
	run_seed = new_seed
	rng.seed = new_seed
	hp = -1
	bonus_max_hp = 0
	money = new_freelancer.starting_money
	extra_enemies_next_battle = 0
	seen_events.clear()
	route_depth = -1
	current_station = null
	detour_queue.clear()
	detours_taken.clear()
	stops_cleared = 0
	freelancer = new_freelancer
	# Meta progression hook: rounds that carry over between runs would be
	# added to this starting arsenal.
	arsenal = freelancer.starting_arsenal.duplicate()
	gear.clear()
	starting_gear_announced = false
	stop_index = 0
	active = true
	if freelancer.starting_gear:
		add_gear(freelancer.starting_gear, FTGear.Source.START)
	else:
		grant_random_gear(FTGear.Source.START)
	stage = FTStageGenerator.generate(STAGE_CONFIG, rng)
	line_index = -1

func end_run() -> void:
	active = false
	arsenal.clear()
	gear.clear()
	stage = null
	line_index = -1
	current_station = null

func max_hp() -> int:
	return roundi(modify_stat(&"max_health", freelancer.max_health + bonus_max_hp))

## Money a cleared fight pays, by encounter tier.
func roll_fight_money(encounter: FTEncounter) -> int:
	var span := STAGE_CONFIG.elite_money if encounter.tier >= FTEncounter.Tier.ELITE else STAGE_CONFIG.battle_money
	return rng.randi_range(span.x, span.y)

## Takes (and clears) the extra enemies queued for the next battle.
func take_extra_enemies() -> int:
	var count := extra_enemies_next_battle
	extra_enemies_next_battle = 0
	return count

## An event for a ? stop: weighted, not repeating until every event has been
## seen this run.
func pick_event() -> FTEvent:
	var fresh := EVENT_POOL.events.filter(func(e: FTEvent): return e.id not in seen_events)
	if fresh.is_empty():
		seen_events.clear()
		fresh = EVENT_POOL.events.duplicate()
	var weights := PackedFloat32Array()
	for e: FTEvent in fresh:
		weights.append(e.weight)
	var event: FTEvent = fresh[rng.rand_weighted(weights)]
	seen_events.append(event.id)
	return event

func current_hp() -> int:
	return max_hp() if hp < 0 else mini(hp, max_hp())

# --- Route ------------------------------------------------------------------

## Boarding a line on the Line Select screen locks the route in.
func choose_line(index: int) -> void:
	line_index = index

func current_line() -> FTLine:
	return stage.lines[line_index] if stage and line_index >= 0 else null

## Board and ride to the line's first stop.
func board(index: int) -> void:
	choose_line(index)
	route_depth = -1
	depart()

## Where the train is heading: the next detour stop, else the next station on
## the line.
func upcoming_station() -> FTStation:
	if not detour_queue.is_empty():
		return detour_queue[0]
	return current_line().stations[route_depth + 1]

func is_detouring() -> bool:
	return not detour_queue.is_empty()

## CONTINUE (route screen): leave for the next stop. If the next line station hides a detour, it
## triggers now and its ? stops are played first.
func depart() -> void:
	if detour_queue.is_empty():
		var next := current_line().stations[route_depth + 1]
		if next.has_detour() and next not in detours_taken:
			detours_taken.append(next)
			detour_queue.assign(next.detour_stops)
	_change_scene(TRANSIT_SCENE)

## Called by Transit when the doors open. Hidden stops reveal on arrival.
func arrive() -> void:
	if not detour_queue.is_empty():
		current_station = detour_queue.pop_front()
	else:
		route_depth += 1
		current_station = current_line().stations[route_depth]
	current_station.hidden = false

## The other line at the current station if the player may transfer here,
## else -1. Asked on arrival, before the encounter.
func transfer_line() -> int:
	var s := current_station
	if s == null or s.kind == FTStation.Kind.LAST_STOP or not s.is_transfer() or s not in current_line().stations:
		return -1
	return s.line_indices[0] if s.line_indices[1] == line_index else s.line_indices[1]

## Switch to another line at a transfer station (same depth on both lines).
func transfer_to(index: int) -> void:
	line_index = index

## Open the current stop's encounter.
func enter_current_stop() -> void:
	if current_station.is_fight():
		_change_scene(BATTLE_SCENE)
	elif current_station.kind == FTStation.Kind.EVENT:
		_change_scene(EVENT_SCENE)
	else:
		_change_scene(SHOP_SCENE)

## The stop's encounter is done (fight won, event resolved, shop left).
func complete_stop() -> void:
	stops_cleared += 1
	if current_station and current_station.kind == FTStation.Kind.LAST_STOP:
		FTRecords.add_win(_record())
		_change_scene(STAGE_CLEAR_SCENE)
	else:
		_change_scene(ROUTE_SCENE)

## The player went down. Run Over shows what happened; its button ends the
## run and starts a new one.
func lose_run() -> void:
	_change_scene(RUN_OVER_SCENE)

func new_run() -> void:
	end_run()
	_change_scene(FREELANCER_SELECT_SCENE)

## Freelancer Select: start the run as `chosen`, then pick a line.
func choose_freelancer(chosen: FTFreelancer) -> void:
	start_run(randi(), chosen)
	_change_scene(LINE_SELECT_SCENE)

func _change_scene(path: String) -> void:
	get_tree().change_scene_to_file.call_deferred(path)

func _record() -> Dictionary:
	var rounds := {}
	for mod in arsenal:
		rounds[String(mod.id)] = rounds.get(String(mod.id), 0) + 1
	return {
		"time": Time.get_datetime_string_from_system(),
		"seed": run_seed,
		"freelancer": freelancer.display_name,
		"gear": gear.map(func(g: FTGear): return String(g.id)),
		"arsenal": rounds,
		"stops_cleared": stops_cleared,
		"hp_left": current_hp(),
		"money_left": money,
	}

func arsenal_capacity() -> int:
	return roundi(modify_stat(&"arsenal_capacity", freelancer.arsenal_capacity))

func is_arsenal_over_capacity() -> bool:
	return arsenal.size() > arsenal_capacity()

func add_round(mod: FTAmmoMod) -> void:
	arsenal.append(mod)

func remove_round(mod: FTAmmoMod) -> void:
	arsenal.erase(mod)

## Up to `count` different ammo modifiers to offer after a fight, weighted by
## rarity. The arsenal can hold any number of the same modifier.
func roll_ammo_choices(count := 3) -> Array[FTAmmoMod]:
	var picks: Array[FTAmmoMod] = []
	picks.assign(_weighted_picks(AMMO_POOL.mods.duplicate(), count))
	return picks

func has_gear(id: StringName) -> bool:
	return gear.any(func(g: FTGear): return g.id == id)

## Events call this for a specific reward. Returns the owned copy.
func add_gear(template: FTGear, source := FTGear.Source.EVENT) -> FTGear:
	var owned: FTGear = template.duplicate()
	gear.append(owned)
	gear_added.emit(owned, source)
	return owned

## Up to `count` different gear from `source`'s pool that aren't owned yet,
## each weighted by rarity. Fewer (or none) when the pool runs low. These are
## the shared templates: pass the chosen one to add_gear.
func roll_gear_choices(source: FTGear.Source, count := 3) -> Array[FTGear]:
	var candidates := GEAR_POOL.gear.filter(func(g: FTGear):
		return g.sources & source and not has_gear(g.id))
	var picks: Array[FTGear] = []
	picks.assign(_weighted_picks(candidates, count))
	return picks

# Draws up to `count` items from `candidates` (consumed) without repeats,
# weighted by each item's `rarity`.
func _weighted_picks(candidates: Array, count: int) -> Array:
	var picks := []
	while picks.size() < count and not candidates.is_empty():
		var weights := PackedFloat32Array()
		for item in candidates:
			weights.append(RARITY_WEIGHTS[item.rarity])
		picks.append(candidates.pop_at(rng.rand_weighted(weights)))
	return picks

## One random gear from `source`, no choice. Returns null when none are left.
func grant_random_gear(source: FTGear.Source) -> FTGear:
	var picks := roll_gear_choices(source, 1)
	return add_gear(picks[0], source) if picks else null

# --- Hooks, called by the battle -------------------------------------------

func modify_stat(stat: StringName, value: float) -> float:
	for g in gear:
		value = g.modify_stat(stat, value)
	return value

func shot_damage(battle: FTBattle, enemy: FTEnemy, countered: bool) -> int:
	var damage := 1
	for g in gear:
		damage = g.modify_shot_damage(battle, enemy, countered, damage)
	return damage

func damage_taken(battle: FTBattle, amount: int) -> int:
	for g in gear:
		amount = g.modify_damage_taken(battle, amount)
	return amount

## For hooks without a return value: on_battle_start, on_counter, on_kill.
func trigger(hook: StringName, args: Array) -> void:
	for g in gear:
		g.callv(hook, args)
