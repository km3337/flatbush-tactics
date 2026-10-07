extends Node

## Generates many stages and checks every rule from STAGE_NOTES.md holds.
## Run headless after changing the generator or stages/stage_1.tres:
##   godot --headless --path prototype res://tests/test_stage_generator.tscn
## Exit code = number of failed checks.

const CONFIG: FTStageConfig = preload("res://stages/stage_1.tres")
const SEEDS := 2000

var fails := 0

func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		if fails <= 20:
			print("FAIL " + msg)

func _ready() -> void:
	var K := FTStation.Kind
	var kind_counts := {}
	var transfers_seen := {1: 0, 2: 0}
	var detour_lengths := {1: 0, 2: 0}
	var lines_with_detour := 0
	for s in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var map := FTStageGenerator.generate(CONFIG, rng)
		var tag := "seed %d" % s
		check(map.lines.size() == CONFIG.line_count, tag + ": line count")
		var bullets := map.lines.map(func(l): return l.bullet)
		check(bullets.size() == {}.merged(_as_set(bullets)).size(), tag + ": bullets unique")
		check(map.last_stop.kind == K.LAST_STOP and map.last_stop.encounter != null, tag + ": last stop")
		var names := []
		for station in map.stations():
			names.append(station.display_name)
			for d in station.detour_stops:
				names.append(d.display_name)
		check(names.size() == _as_set(names).size(), tag + ": station names unique")

		for i in map.lines.size():
			var line := map.lines[i]
			var lt := "%s line %s" % [tag, line.bullet]
			check(line.length() == CONFIG.stops_per_line, lt + ": length")
			check(line.stations[-1] == map.last_stop, lt + ": ends at the Last Stop")
			var kinds := []
			for depth in line.length():
				var st := line.stations[depth]
				kinds.append(st.kind)
				kind_counts[st.kind] = kind_counts.get(st.kind, 0) + 1
				check(st.depth == depth, lt + ": depth field")
				check(i in st.line_indices, lt + ": station knows its line")
				check((st.encounter != null) == (st.kind in [K.BATTLE, K.ELITE]), lt + ": encounter only on fights")
				check((st.shop != null) == (st.kind == K.SHOP), lt + ": shop kind only on shops")
				if st.kind == K.ELITE:
					check(depth >= CONFIG.first_elite_depth, lt + ": no early elite")
				if depth > 0:
					check(not (st.kind == K.SHOP and kinds[depth - 1] == K.SHOP), lt + ": no shop after shop")
			check(kinds[0] == K.BATTLE, lt + ": first stop is a battle")
			check(kinds[-1] in [K.EVENT, K.SHOP], lt + ": rest before the Last Stop")
			check(kinds.has(K.SHOP), lt + ": has a shop")
			check(kinds.has(K.ELITE), lt + ": has an elite")
			var hidden := line.stations.filter(func(st): return st.hidden).size()
			check(hidden >= CONFIG.hidden_per_line.x and hidden <= CONFIG.hidden_per_line.y, lt + ": hidden count %d" % hidden)
			check(not line.stations[0].hidden, lt + ": first stop not hidden")
			if line.stations.any(func(st): return st.has_detour()):
				lines_with_detour += 1

		var transfers := map.transfers()
		check(transfers.size() >= CONFIG.transfer_count.x and transfers.size() <= CONFIG.transfer_count.y, tag + ": transfer count %d" % transfers.size())
		transfers_seen[transfers.size()] = transfers_seen.get(transfers.size(), 0) + 1
		for t in transfers:
			check(t.line_indices.size() == 2, tag + ": transfer on exactly 2 lines")
			check(t.depth > 0 and t.depth < CONFIG.stops_per_line, tag + ": transfer not first/last")
			check(not t.hidden and not t.has_detour(), tag + ": transfer not hidden")
			for li in t.line_indices:
				check(map.lines[li].stations[t.depth] == t, tag + ": transfer at same depth on both lines")

		var detours := map.stations().filter(func(st): return st.has_detour())
		check(detours.size() == CONFIG.detour_count, tag + ": detour count %d" % detours.size())
		for d in detours:
			check(d.hidden, tag + ": detour on a hidden stop")
			var length: int = d.detour_stops.size()
			check(length >= CONFIG.detour_length.x and length <= CONFIG.detour_length.y, tag + ": detour length")
			detour_lengths[length] = detour_lengths.get(length, 0) + 1
			check(d.detour_stops.all(func(x): return x.kind == K.EVENT), tag + ": detour stops are ?")

	# Same seed -> same map.
	var a := RandomNumberGenerator.new()
	a.seed = 42
	var b := RandomNumberGenerator.new()
	b.seed = 42
	check(FTStageGenerator.generate(CONFIG, a).describe() == FTStageGenerator.generate(CONFIG, b).describe(), "same seed gives the same map")

	var total := 0
	for k in kind_counts:
		total += kind_counts[k]
	print("Stop mix over %d stages: battle %.0f%%  event %.0f%%  elite %.0f%%  shop %.0f%%" % [SEEDS,
		100.0 * kind_counts.get(K.BATTLE, 0) / total, 100.0 * kind_counts.get(K.EVENT, 0) / total,
		100.0 * kind_counts.get(K.ELITE, 0) / total, 100.0 * kind_counts.get(K.SHOP, 0) / total])
	print("Transfers per stage: %s   Detour lengths: %s   Lines with the detour: %.0f%%" % [transfers_seen, detour_lengths, 100.0 * lines_with_detour / (SEEDS * CONFIG.line_count)])
	for s in [1, 2]:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		print("\nExample (seed %d):\n%s" % [s, FTStageGenerator.generate(CONFIG, rng).describe()])
	print("\nRESULT: %s (%d failures)" % ["OK" if fails == 0 else "FAILED", fails])
	get_tree().quit(fails)

func _as_set(list: Array) -> Dictionary:
	var d := {}
	for x in list:
		d[x] = true
	return d
