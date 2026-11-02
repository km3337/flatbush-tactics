class_name FTStageGenerator
extends RefCounted

## Builds an FTStageMap from an FTStageConfig and the run's RNG (so a seed
## always gives the same map). Steps:
##   1. Stop types per line: runs of fights split by one event or shop, with
##      weighted types, re-rolled until the line follows the rules (see
##      `_line_ok`).
##   2. Transfers: a station shared by two lines at the same depth. Its type
##      comes from one line and must keep the other line valid.
##   3. Hidden stops per line (never transfers), then detours on hidden stops.
##   4. Station objects, names, encounters.

const MAX_TRIES := 500
## Used only if random rolls keep failing the rules (shouldn't happen with
## sane weights): repeated to fill the line, valid at 10 stops.
const FALLBACK_PATTERN := [
	FTStation.Kind.BATTLE, FTStation.Kind.BATTLE, FTStation.Kind.ELITE, FTStation.Kind.SHOP,
	FTStation.Kind.BATTLE, FTStation.Kind.BATTLE, FTStation.Kind.EVENT,
	FTStation.Kind.BATTLE, FTStation.Kind.BATTLE, FTStation.Kind.EVENT,
]

var config: FTStageConfig
var rng: RandomNumberGenerator

static func generate(stage_config: FTStageConfig, random: RandomNumberGenerator) -> FTStageMap:
	var generator := FTStageGenerator.new()
	generator.config = stage_config
	generator.rng = random
	return generator._generate()

func _generate() -> FTStageMap:
	var n := config.stops_per_line
	var kinds: Array = []  # per line: Array of FTStation.Kind, length n
	for i in config.line_count:
		kinds.append(_roll_line_kinds())
	var transfers := _place_transfers(kinds)  # Array of [line_a, line_b, depth]
	var hidden := _pick_hidden(transfers)  # per line: Array of depths

	var names := Array(config.station_names)
	_shuffle(names)
	var map := FTStageMap.new()
	map.last_stop = FTStation.new()
	map.last_stop.display_name = config.last_stop_name
	map.last_stop.kind = FTStation.Kind.LAST_STOP
	map.last_stop.depth = n
	map.last_stop.encounter = config.last_stop_encounter
	var bullets := Array(config.bullets)
	_shuffle(bullets)
	for i in config.line_count:
		var line := FTLine.new()
		var parts: PackedStringArray = bullets[i % bullets.size()].split("|")
		line.bullet = parts[0]
		line.color = Color(parts[1])
		line.text_color = Color(parts[2])
		map.lines.append(line)
		map.last_stop.line_indices.append(i)

	# Depth by depth: each line's own station first, then lines that borrow a
	# transfer station from another line at that depth.
	for depth in n:
		var row: Array[FTStation] = []
		for i in config.line_count:
			var station: FTStation = null
			if _transfer_owner(transfers, i, depth) < 0:
				station = _make_station(kinds[i][depth], depth, names)
				station.line_indices.append(i)
				station.hidden = depth in hidden[i]
			row.append(station)
		for i in config.line_count:
			var owner := _transfer_owner(transfers, i, depth)
			if owner >= 0:
				row[i] = row[owner]
				row[i].line_indices.append(i)
			map.lines[i].stations.append(row[i])
	for line in map.lines:
		line.stations.append(map.last_stop)

	_place_detours(map, names)
	return map

# --- Stop types -------------------------------------------------------------

func _roll_line_kinds() -> Array:
	for attempt in MAX_TRIES:
		var line := _roll_line()
		if _line_ok(line):
			return line
	push_warning("Stage generator fell back to a fixed line pattern")
	var fallback := []
	for depth in config.stops_per_line:
		fallback.append(FALLBACK_PATTERN[depth % FALLBACK_PATTERN.size()])
	fallback[-1] = FTStation.Kind.EVENT
	return fallback

# A run of fights, one event or shop, and again until the line is full.
func _roll_line() -> Array:
	var line := []
	while line.size() < config.stops_per_line:
		var run := rng.randi_range(config.fight_run.x, config.fight_run.y)
		for i in mini(run, config.stops_per_line - line.size() - 1):
			line.append(_roll_fight(line.size()))
		line.append(_roll_break())
	return line

func _roll_fight(depth: int) -> FTStation.Kind:
	if depth == 0 or depth < config.first_elite_depth:
		return FTStation.Kind.BATTLE
	var options: Array[FTStation.Kind] = [FTStation.Kind.BATTLE, FTStation.Kind.ELITE]
	return options[rng.rand_weighted(PackedFloat32Array([config.battle_weight, config.elite_weight]))]

func _roll_break() -> FTStation.Kind:
	var options: Array[FTStation.Kind] = [FTStation.Kind.EVENT, FTStation.Kind.SHOP]
	return options[rng.rand_weighted(PackedFloat32Array([config.event_weight, config.shop_weight]))]

func _is_fight(kind: FTStation.Kind) -> bool:
	return kind in [FTStation.Kind.BATTLE, FTStation.Kind.ELITE]

## The rules every line must follow.
func _line_ok(line: Array) -> bool:
	var n := line.size()
	if line[0] != FTStation.Kind.BATTLE:
		return false
	if _is_fight(line[n - 1]):  # the stop before the Last Stop is never a fight
		return false
	if not line.has(FTStation.Kind.SHOP) or not line.has(FTStation.Kind.ELITE):
		return false
	var run := 0
	var run_has_elite := false
	for depth in n:
		var kind: FTStation.Kind = line[depth]
		if kind == FTStation.Kind.ELITE:
			if depth < config.first_elite_depth or run_has_elite:
				return false  # at most one elite per run of fights
			run_has_elite = true
		if _is_fight(kind):
			run += 1
		else:
			if run < config.fight_run.x or run > config.fight_run.y:
				return false
			run = 0
			run_has_elite = false
	return true

# --- Transfers, hidden stops, detours ---------------------------------------

func _place_transfers(kinds: Array) -> Array:
	var transfers := []
	if config.line_count < 2:
		return transfers
	var count := rng.randi_range(config.transfer_count.x, config.transfer_count.y)
	for t in count:
		for attempt in MAX_TRIES:
			var a := rng.randi_range(0, config.line_count - 1)
			var b := rng.randi_range(0, config.line_count - 2)
			if b >= a:
				b += 1
			var depth := rng.randi_range(1, config.stops_per_line - 1)
			if transfers.any(func(tr): return tr[2] == depth and (tr[0] in [a, b] or tr[1] in [a, b])):
				continue  # one transfer per line per depth
			var merged: Array = kinds[b].duplicate()
			merged[depth] = kinds[a][depth]
			if not _line_ok(merged):
				continue
			kinds[b] = merged
			transfers.append([a, b, depth])
			break
	return transfers

# The line that owns the transfer station `line` borrows at `depth`, or -1.
func _transfer_owner(transfers: Array, line: int, depth: int) -> int:
	for tr in transfers:
		if tr[1] == line and tr[2] == depth:
			return tr[0]
	return -1

func _pick_hidden(transfers: Array) -> Array:
	var hidden := []
	for i in config.line_count:
		var candidates := []
		for depth in range(1, config.stops_per_line):
			if not transfers.any(func(tr): return tr[2] == depth and (tr[0] == i or tr[1] == i)):
				candidates.append(depth)
		_shuffle(candidates)
		var count := mini(rng.randi_range(config.hidden_per_line.x, config.hidden_per_line.y), candidates.size())
		hidden.append(candidates.slice(0, count))
	return hidden

func _place_detours(map: FTStageMap, names: Array) -> void:
	var candidates := map.stations().filter(func(s: FTStation): return s.hidden)
	_shuffle(candidates)
	for i in mini(config.detour_count, candidates.size()):
		var station: FTStation = candidates[i]
		for k in rng.randi_range(config.detour_length.x, config.detour_length.y):
			var detour := _make_station(FTStation.Kind.EVENT, station.depth, names)
			station.detour_stops.append(detour)

# --- Helpers ----------------------------------------------------------------

func _make_station(kind: FTStation.Kind, depth: int, names: Array) -> FTStation:
	var station := FTStation.new()
	station.kind = kind
	station.depth = depth
	station.display_name = names.pop_back() if not names.is_empty() else "Station %d" % depth
	match kind:
		FTStation.Kind.BATTLE:
			station.encounter = _pick(config.battle_encounters)
		FTStation.Kind.ELITE:
			station.encounter = _pick(config.elite_encounters)
		FTStation.Kind.SHOP:
			station.shop = _pick(config.shops)
	return station

func _pick(list: Array) -> Variant:
	return list[rng.randi_range(0, list.size() - 1)] if not list.is_empty() else null

# Fisher-Yates with the run's RNG.
func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = list[i]
		list[i] = list[j]
		list[j] = swap
