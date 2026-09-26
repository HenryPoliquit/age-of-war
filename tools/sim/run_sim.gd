extends SceneTree
## Balance harness (GDD §15.2). Runs AI-vs-AI suites headless, checks every PRD §6 sim target,
## writes reports/sim_report.md (+ .json), and exits non-zero if any target fails.
##
##   tools/godot --headless --path . -s tools/sim/run_sim.gd -- --matches=20 --seed=1 --workers=4
## Options: --matches=N (per pairing, default 20)  --seed=S  --workers=K (processes, default 4)
##          --out=DIR (default reports)  plus SimJobs data overrides (--set=…, --scale=…) for
##          what-if runs; overrides are listed in the report and never written to data/.

const PERSONALITIES := ["tactician", "rusher", "turtle", "economist"]
const SPAM := ["spam_vanguard", "spam_ranged", "spam_heavy", "spam_siege"]

var matches := 20
var base_seed := 1
var workers := 4
var out_dir := "reports"
var _seed_counter := 0
var _jobs := []


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--matches="):
			matches = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seed="):
			base_seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--workers="):
			workers = int(arg.get_slice("=", 1))
		elif arg.begins_with("--out="):
			out_dir = arg.get_slice("=", 1)
	var overrides := SimJobs.apply_overrides(OS.get_cmdline_user_args(), GameData.get_default())
	var t0 := Time.get_ticks_msec()

	for i in PERSONALITIES.size():
		for j in range(i + 1, PERSONALITIES.size()):
			_series("rr", PERSONALITIES[i], PERSONALITIES[j], matches)
	_series("mirror", "tactician", "tactician", matches * 3, true)
	_series("fast_strong", "fast_age", "strong_age", matches * 2)
	for bot in SPAM:
		_series("spam", bot, "tactician", matches)
	_series("turtle_mirror", "turtle", "turtle", matches)
	var results := SimJobs.run_all(_jobs, workers, SimJobs.passthrough_args())

	var by := {}
	for r in results:
		if not by.has(r.suite):
			by[r.suite] = []
		by[r.suite].append(r)
	var round_robin: Array = by.rr
	var mirror: Array = by.mirror
	var fast_strong: Array = by.fast_strong
	var spam: Array = by.spam
	var turtle: Array = by.turtle_mirror

	var checks := []
	var metrics := {}
	var main_pool := round_robin + mirror + fast_strong

	var esc := _share(main_pool, func(r): return r.escalated)
	metrics["escalation"] = esc
	checks.append(_check("Stalemates", "Share of AI-vs-AI matches reaching escalation (15:00)", "< 10%", _pct(esc), esc < 0.10))

	var med_len := _median(mirror.map(func(r): return r.duration))
	metrics["median_length"] = med_len
	checks.append(_check("Match length", "Median match duration, Tactician vs. Tactician", "10–14 min", _mmss(med_len), med_len >= 600.0 and med_len <= 840.0))

	var a6 := []
	for r in mirror:
		for s in 2:
			var t: float = r.age_times[s][5]
			a6.append(t if t >= 0.0 else INF)
	var med_a6 := _median(a6)
	var reached := _share(a6, func(t): return t < INF)
	metrics["median_age6"] = med_a6 if med_a6 < INF else 9999.0
	metrics["age6_reached"] = reached
	checks.append(_check("Pacing", "Median time a balanced AI reaches Age 6", "10:00–12:00", "%s (%s of sides reach it)" % [_mmss(med_a6), _pct(reached)], med_a6 >= 600.0 and med_a6 <= 720.0))

	var agg := {}
	var pair_rates := {}
	for r in round_robin:
		for s in 2:
			var p: String = r.names[s]
			if not agg.has(p):
				agg[p] = [0.0, 0]
			agg[p][0] += _score(r, s)
			agg[p][1] += 1
		var a_name: String = r.names[r.pair_a]
		var b_name: String = r.names[1 - int(r.pair_a)]
		var key := "%s vs %s" % [a_name, b_name]
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
	metrics["personality"] = {}
	for p in PERSONALITIES:
		metrics["personality"][p] = agg[p][0] / agg[p][1]
	checks.append(_check("Balance", "Each personality's aggregate win rate (Hard vs. Hard)", "40–60%", ", ".join(agg_txt), agg_ok))
	var pair_ok := true
	var pair_txt := []
	for k in pair_rates:
		var rate: float = pair_rates[k][0] / pair_rates[k][1]
		pair_ok = pair_ok and rate >= 0.3 and rate <= 0.7
		pair_txt.append("%s %s" % [k, _pct(rate)])
	metrics["pairs"] = {}
	for k in pair_rates:
		metrics["pairs"][k] = pair_rates[k][0] / pair_rates[k][1]
	checks.append(_check("Balance", "Any single personality pairing (first-named side's win rate)", "30–70%", "; ".join(pair_txt), pair_ok))

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
	for d in ["horde", "elite", "bastion", "siegecraft"]:
		if not doc.has(d) or doc[d][1] == 0:
			doc_txt.append("%s n/a" % d)
			continue
		var rate: float = doc[d][0] / doc[d][1]
		if not metrics.has("doctrines"):
			metrics["doctrines"] = {}
		metrics["doctrines"][d] = rate
		doc_ok = doc_ok and rate >= 0.4 and rate <= 0.6
		doc_txt.append("%s %s (n=%d)" % [d, _pct(rate), doc[d][1]])
	checks.append(_check("Balance", "Win rate of each doctrine (Tactician mirror, random picks)", "40–60%", ", ".join(doc_txt), doc_ok))

	var fast_rate := 0.0
	for r in fast_strong:
		fast_rate += _score(r, r.pair_a)
	fast_rate /= fast_strong.size()
	metrics["fast_vs_strong"] = fast_rate
	checks.append(_check("Decisions", "Fast-age vs. strong-age Tactician (fast-age win rate)", "40–60%", _pct(fast_rate), fast_rate >= 0.4 and fast_rate <= 0.6))

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
		if not metrics.has("spam"):
			metrics["spam"] = {}
		metrics["spam"][bot] = w / n
		spam_txt.append("%s %s" % [bot.trim_prefix("spam_"), _pct(w / n)])
	checks.append(_check("Dominant units", "Single-role spam vs. Tactician (Hard), spam win rate", "< 30% each", ", ".join(spam_txt), spam_ok))

	var t_esc := _share(turtle, func(r): return r.escalated)
	var t_max := 0.0
	for r in turtle:
		t_max = maxf(t_max, r.duration)
	metrics["turtle_escalation"] = t_esc
	metrics["turtle_longest"] = t_max
	checks.append(_check("Worst-case defence", "Turtle vs. Turtle, both Bastion", "< 25% reach escalation; none > 18:00", "%s escalate; longest %s" % [_pct(t_esc), _mmss(t_max)], t_esc < 0.25 and t_max <= 1080.0))

	var all_ok := true
	for c in checks:
		all_ok = all_ok and c.pass
	var elapsed := (Time.get_ticks_msec() - t0) / 1000.0
	var units := {}
	var deaths := PackedFloat32Array()
	deaths.resize(12)
	for r in results:
		for k in r.units:
			if not units.has(k):
				units[k] = {"spawned": 0, "gold": 0.0, "dealt": 0.0, "absorbed": 0.0}
			for f in ["spawned", "gold", "dealt", "absorbed"]:
				units[k][f] += r.units[k][f]
		for i in 12:
			deaths[i] += r.deaths[i]
	var report := _markdown(checks, all_ok, main_pool, mirror, elapsed, units, deaths, overrides, results.size())
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f := FileAccess.open(out_dir.path_join("sim_report.md"), FileAccess.WRITE)
	f.store_string(report)
	f.close()
	var jf := FileAccess.open(out_dir.path_join("sim_report.json"), FileAccess.WRITE)
	jf.store_string(JSON.stringify({"pass": all_ok, "matches_per_pairing": matches, "seed": base_seed, "overrides": overrides, "checks": checks, "metrics": metrics, "units": units, "deaths": Array(deaths)}, "  "))
	jf.close()
	print(report)
	quit(0 if all_ok else 1)


func _series(suite: String, a: String, b: String, n: int, random_doctrines := false) -> void:
	for k in n:
		_seed_counter += 1
		# Alternate sides so any left/right asymmetry cancels out.
		var a_left := k % 2 == 0
		_jobs.append({"suite": suite, "left": a if a_left else b, "right": b if a_left else a,
			"seed": base_seed * 100003 + _seed_counter, "random_doctrines": random_doctrines, "pair_a": 0 if a_left else 1})


## 1 for a win, 0.5 for a draw, 0 for a loss.
func _score(r: Dictionary, side: int) -> float:
	if int(r.winner) == side:
		return 1.0
	return 0.5 if int(r.winner) == MatchSim.DRAW else 0.0


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


func _markdown(checks: Array, ok: bool, pool: Array, mirror: Array, elapsed: float, units: Dictionary, deaths: PackedFloat32Array, overrides: Array, total: int) -> String:
	var lines := []
	lines.append("# Balance sim report")
	lines.append("")
	var passed := checks.filter(func(c): return c.pass).size()
	lines.append("**Result: %s (%d/%d targets)** — %d matches per pairing, seed %d, %d matches total." % [
		"PASS" if ok else "FAIL", passed, checks.size(), matches, base_seed, total])
	if not overrides.is_empty():
		lines.append("")
		lines.append("What-if overrides (not in data/): `%s`" % "`, `".join(overrides))
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
	lines.append("## Where units die (share of gold lost, by distance from the dying unit's own gate)")
	lines.append("")
	var total_dead := 0.0
	for v in deaths:
		total_dead += v
	lines.append("| Lane | " + " | ".join(range(12).map(func(i): return "%d%%" % (i * 100 / 12))) + " |")
	lines.append("| --- |" + " --- |".repeat(12))
	lines.append("| Lost | " + " | ".join(Array(deaths).map(func(v): return _pct(v / maxf(1.0, total_dead)))) + " |")
	lines.append("")
	lines.append("## Per-unit trade efficiency (all suites)")
	lines.append("")
	lines.append("| Unit | Spawned | Damage dealt / gold | Damage absorbed / gold |")
	lines.append("| --- | --- | --- | --- |")
	var ids := units.keys()
	ids.sort()
	for id in ids:
		var t: Dictionary = units[id]
		if t.gold <= 0.0:
			continue
		lines.append("| %s | %d | %.2f | %.2f |" % [id, t.spawned, t.dealt / t.gold, t.absorbed / t.gold])
	lines.append("")
	return "\n".join(lines)
