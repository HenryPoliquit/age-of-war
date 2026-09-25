extends SceneTree
## Balance harness (GDD §15.2). Runs AI-vs-AI suites headless, checks every PRD §6 sim target,
## writes reports/sim_report.md (+ .json), and exits non-zero if any target fails.
##
##   tools/godot --headless --path . -s tools/sim/run_sim.gd -- --matches=20 --seed=1
## Options: --matches=N (per pairing, default 20)  --seed=S  --logs (write every match log to logs/sim/)
##          --out=DIR (default reports)

const PERSONALITIES: Array[StringName] = [&"tactician", &"rusher", &"turtle", &"economist"]
const SPAM: Array[StringName] = [&"spam_vanguard", &"spam_ranged", &"spam_heavy", &"spam_siege"]

var data: GameData
var matches := 20
var base_seed := 1
var write_logs := false
var out_dir := "reports"
var _seed_counter := 0
var _unit_totals := {}


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--matches="):
			matches = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seed="):
			base_seed = int(arg.get_slice("=", 1))
		elif arg == "--logs":
			write_logs = true
		elif arg.begins_with("--out="):
			out_dir = arg.get_slice("=", 1)
	data = GameData.get_default()
	var t0 := Time.get_ticks_msec()

	var round_robin := []
	for i in PERSONALITIES.size():
		for j in range(i + 1, PERSONALITIES.size()):
			round_robin.append_array(_series("rr", PERSONALITIES[i], PERSONALITIES[j], matches))
	var mirror := _series("mirror", &"tactician", &"tactician", matches * 2, true)
	var fast_strong := _series("fast_strong", &"fast_age", &"strong_age", matches * 2)
	var spam := []
	for bot in SPAM:
		spam.append_array(_series("spam", bot, &"tactician", matches))
	var turtle := _series("turtle_mirror", &"turtle", &"turtle", matches)

	var checks := []
	var main_pool := round_robin + mirror + fast_strong

	# Stalemates
	var esc := _share(main_pool, func(r): return r.escalated)
	checks.append(_check("Stalemates", "Share of AI-vs-AI matches reaching escalation (15:00)", "< 10%", _pct(esc), esc < 0.10))

	# Match length
	var med_len := _median(mirror.map(func(r): return r.duration))
	checks.append(_check("Match length", "Median match duration, Tactician vs. Tactician", "10–14 min", _mmss(med_len), med_len >= 600.0 and med_len <= 840.0))

	# Pacing
	var a6 := []
	for r in mirror:
		for s in 2:
			var t: float = r.age_times[s][5]
			a6.append(t if t >= 0.0 else INF)
	var med_a6 := _median(a6)
	var reached := _share(a6, func(t): return t < INF)
	checks.append(_check("Pacing", "Median time a balanced AI reaches Age 6", "10:00–12:00", "%s (%s of sides reach it)" % [_mmss(med_a6), _pct(reached)], med_a6 >= 600.0 and med_a6 <= 720.0))

	# Personality aggregate and pairings
	var agg := {}
	var pair_rates := {}
	for r in round_robin:
		for s in 2:
			var p: StringName = r.names[s]
			if not agg.has(p):
				agg[p] = [0.0, 0]
			agg[p][0] += _score(r, s)
			agg[p][1] += 1
		var key := "%s vs %s" % [r.names[0] if r.pair_a == 0 else r.names[1], r.names[1] if r.pair_a == 0 else r.names[0]]
		if not pair_rates.has(key):
			pair_rates[key] = [0.0, 0]
		pair_rates[key][0] += _score(r, r.pair_a)
		pair_rates[key][1] += 1
	var agg_ok := true
	var agg_txt := []
	for p in PERSONALITIES:
		var rate: float = agg[p][0] / agg[p][1]
		agg_ok = agg_ok and rate >= 0.4 and rate <= 0.6
		agg_txt.append("%s %s" % [p, _pct(rate)])
	checks.append(_check("Balance", "Each personality's aggregate win rate (Hard vs. Hard)", "40–60%", ", ".join(agg_txt), agg_ok))
	var pair_ok := true
	var pair_txt := []
	for k in pair_rates:
		var rate: float = pair_rates[k][0] / pair_rates[k][1]
		pair_ok = pair_ok and rate >= 0.3 and rate <= 0.7
		pair_txt.append("%s %s" % [k, _pct(rate)])
	checks.append(_check("Balance", "Any single personality pairing (first-named side's win rate)", "30–70%", "; ".join(pair_txt), pair_ok))

	# Doctrines (Tactician mirror with random picks, games where exactly one side took the doctrine)
	var doc := {}
	for r in mirror:
		for s in 2:
			for d in r.doctrines[s]:
				if d in r.doctrines[1 - s]:
					continue
				if not doc.has(d):
					doc[d] = [0.0, 0]
				doc[d][0] += _score(r, s)
				doc[d][1] += 1
	var doc_ok := true
	var doc_txt := []
	for d in [&"horde", &"elite", &"bastion", &"siegecraft"]:
		if not doc.has(d) or doc[d][1] == 0:
			doc_txt.append("%s n/a" % d)
			continue
		var rate: float = doc[d][0] / doc[d][1]
		doc_ok = doc_ok and rate >= 0.4 and rate <= 0.6
		doc_txt.append("%s %s (n=%d)" % [d, _pct(rate), doc[d][1]])
	checks.append(_check("Balance", "Win rate of each doctrine (Tactician mirror, random picks)", "40–60%", ", ".join(doc_txt), doc_ok))

	# Decisions
	var fast_rate := 0.0
	for r in fast_strong:
		fast_rate += _score(r, r.pair_a)
	fast_rate /= fast_strong.size()
	checks.append(_check("Decisions", "Fast-age vs. strong-age Tactician (fast-age win rate)", "40–60%", _pct(fast_rate), fast_rate >= 0.4 and fast_rate <= 0.6))

	# Dominant units
	var spam_ok := true
	var spam_txt := []
	for bot in SPAM:
		var w := 0.0
		var n := 0
		for r in spam:
			if r.names[r.pair_a] == bot:
				w += _score(r, r.pair_a)
				n += 1
		spam_ok = spam_ok and w / n < 0.3
		spam_txt.append("%s %s" % [String(bot).trim_prefix("spam_"), _pct(w / n)])
	checks.append(_check("Dominant units", "Single-role spam vs. Tactician (Hard), spam win rate", "< 30% each", ", ".join(spam_txt), spam_ok))

	# Worst-case defence
	var t_esc := _share(turtle, func(r): return r.escalated)
	var t_max := 0.0
	for r in turtle:
		t_max = maxf(t_max, r.duration)
	checks.append(_check("Worst-case defence", "Turtle vs. Turtle, both Bastion", "< 25% reach escalation; none > 18:00", "%s escalate; longest %s" % [_pct(t_esc), _mmss(t_max)], t_esc < 0.25 and t_max <= 1080.0))

	var all_ok := true
	for c in checks:
		all_ok = all_ok and c.pass
	var elapsed := (Time.get_ticks_msec() - t0) / 1000.0
	var report := _markdown(checks, all_ok, main_pool, mirror, elapsed)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f := FileAccess.open(out_dir.path_join("sim_report.md"), FileAccess.WRITE)
	f.store_string(report)
	f.close()
	var jf := FileAccess.open(out_dir.path_join("sim_report.json"), FileAccess.WRITE)
	jf.store_string(JSON.stringify({"pass": all_ok, "matches_per_pairing": matches, "seed": base_seed, "checks": checks, "units": _unit_totals}, "  "))
	jf.close()
	print(report)
	quit(0 if all_ok else 1)


func _series(suite: String, a: StringName, b: StringName, n: int, random_doctrines := false) -> Array:
	var out := []
	for k in n:
		_seed_counter += 1
		var seed := base_seed * 100003 + _seed_counter
		# Alternate sides so any left/right asymmetry cancels out.
		var a_left := k % 2 == 0
		var left := {"personality": a if a_left else b, "difficulty": &"hard"}
		var right := {"personality": b if a_left else a, "difficulty": &"hard"}
		var r := MatchRunner.run(data, left, right, seed, random_doctrines)
		r.names = [left.personality, right.personality]
		r.pair_a = 0 if a_left else 1
		r.suite = suite
		_accumulate_units(r.log)
		if write_logs:
			r.log.save_json("res://logs/sim/%s_%s_vs_%s_%d.json" % [suite, left.personality, right.personality, seed])
		r.erase("log")
		out.append(r)
	return out


func _accumulate_units(log: MatchLog) -> void:
	for side_stats in log.unit_stats:
		for id in side_stats:
			var st: Dictionary = side_stats[id]
			var key := String(id)
			if not _unit_totals.has(key):
				_unit_totals[key] = {"spawned": 0, "gold": 0.0, "dealt": 0.0, "absorbed": 0.0}
			var t: Dictionary = _unit_totals[key]
			t.spawned += st.spawned
			t.gold += st.gold
			t.dealt += st.dealt
			t.absorbed += st.absorbed


## 1 for a win, 0.5 for a draw, 0 for a loss.
func _score(r: Dictionary, side: int) -> float:
	if r.winner == side:
		return 1.0
	return 0.5 if r.winner == MatchSim.DRAW else 0.0


func _share(arr: Array, pred: Callable) -> float:
	if arr.is_empty():
		return 0.0
	var n := 0
	for x in arr:
		if pred.call(x):
			n += 1
	return float(n) / arr.size()


func _median(arr: Array) -> float:
	if arr.is_empty():
		return NAN
	var a := arr.duplicate()
	a.sort()
	var m := a.size() / 2
	if a.size() % 2 == 1:
		return a[m]
	return (a[m - 1] + a[m]) * 0.5


func _check(area: String, metric: String, target: String, value: String, ok: bool) -> Dictionary:
	return {"area": area, "metric": metric, "target": target, "value": value, "pass": ok}


func _pct(x: float) -> String:
	return "%d%%" % roundi(x * 100.0)


func _mmss(t: float) -> String:
	if is_inf(t) or is_nan(t):
		return "never"
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


func _markdown(checks: Array, ok: bool, pool: Array, mirror: Array, elapsed: float) -> String:
	var lines := []
	lines.append("# Balance sim report")
	lines.append("")
	lines.append("**Result: %s** — %d matches per pairing, seed %d, %d matches total, %.0f s." % [
		"PASS" if ok else "FAIL", matches, base_seed, _seed_counter, elapsed])
	lines.append("")
	lines.append("| Area | Metric | Target | Value | |")
	lines.append("| --- | --- | --- | --- | --- |")
	for c in checks:
		lines.append("| %s | %s | %s | %s | %s |" % [c.area, c.metric, c.target, c.value, "✅" if c.pass else "❌"])
	lines.append("")
	lines.append("## Match length distribution (round robin + mirror + fast/strong)")
	lines.append("")
	var buckets := {}
	for r in pool:
		var b := mini(int(r.duration / 120.0), 10)
		buckets[b] = buckets.get(b, 0) + 1
	lines.append("| Minutes | Matches |")
	lines.append("| --- | --- |")
	for b in range(0, 11):
		if buckets.has(b):
			lines.append("| %s | %d |" % ["%d–%d" % [b * 2, b * 2 + 2] if b < 10 else "20+", buckets[b]])
	lines.append("")
	lines.append("## Age arrival, Tactician mirror (median)")
	lines.append("")
	lines.append("| Age | Median arrival | Sides reaching |")
	lines.append("| --- | --- | --- |")
	for age in range(2, 7):
		var ts := []
		for r in mirror:
			for s in 2:
				var t: float = r.age_times[s][age - 1]
				ts.append(t if t >= 0.0 else INF)
		lines.append("| %d | %s | %s |" % [age, _mmss(_median(ts)), _pct(_share(ts, func(t): return t < INF))])
	lines.append("")
	lines.append("## Per-unit trade efficiency (all suites)")
	lines.append("")
	lines.append("| Unit | Spawned | Damage dealt / gold | Damage absorbed / gold |")
	lines.append("| --- | --- | --- | --- |")
	var ids := _unit_totals.keys()
	ids.sort()
	for id in ids:
		var t: Dictionary = _unit_totals[id]
		if t.gold <= 0.0:
			continue
		lines.append("| %s | %d | %.2f | %.2f |" % [id, t.spawned, t.dealt / t.gold, t.absorbed / t.gold])
	lines.append("")
	return "\n".join(lines)
