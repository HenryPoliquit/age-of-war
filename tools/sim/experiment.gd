extends SceneTree
## Quick what-if matchups for balance work. Prints win rate, lengths, escalation and age pacing.
##   tools/godot --headless --path . -s tools/sim/experiment.gd -- --a=tactician --b=spam_heavy --n=40
## Options: --a=/--b= personality ids, --docs-a=horde,bastion / --docs-b=… (force doctrines),
##          --diff-a=/--diff-b= difficulty, --random-docs, --start-age=N, --n=matches, --seed=S, --workers=K,
##          plus SimJobs data overrides (--set=…, --scale=…).


func _init() -> void:
	var a := "tactician"
	var b := "tactician"
	var docs_a := []
	var docs_b := []
	var diff_a := "hard"
	var diff_b := "hard"
	var n := 40
	var seed := 7
	var workers := 4
	var random_docs := false
	var start_age := 1
	for arg in OS.get_cmdline_user_args():
		var v := arg.get_slice("=", 1)
		if arg.begins_with("--a="): a = v
		elif arg.begins_with("--b="): b = v
		elif arg.begins_with("--docs-a="): docs_a = v.split(",")
		elif arg.begins_with("--docs-b="): docs_b = v.split(",")
		elif arg.begins_with("--diff-a="): diff_a = v
		elif arg.begins_with("--diff-b="): diff_b = v
		elif arg.begins_with("--n="): n = int(v)
		elif arg.begins_with("--seed="): seed = int(v)
		elif arg.begins_with("--workers="): workers = int(v)
		elif arg == "--random-docs": random_docs = true
		elif arg.begins_with("--start-age="): start_age = int(v)
	var overrides := SimJobs.apply_overrides(OS.get_cmdline_user_args(), GameData.get_default())
	var jobs := []
	for k in n:
		var a_left := k % 2 == 0
		jobs.append({"suite": "x", "left": a if a_left else b, "right": b if a_left else a,
			"left_diff": diff_a if a_left else diff_b, "right_diff": diff_b if a_left else diff_a,
			"left_docs": docs_a if a_left else docs_b, "right_docs": docs_b if a_left else docs_a,
			"seed": seed * 1009 + k, "random_doctrines": random_docs, "pair_a": 0 if a_left else 1, "start_age": start_age})
	var t0 := Time.get_ticks_msec()
	var results := SimJobs.run_all(jobs, workers, SimJobs.passthrough_args())
	var wins := 0.0
	var durs := []
	var esc := 0
	var a6 := []
	var deaths := PackedFloat32Array()
	deaths.resize(12)
	for r in results:
		var sa: int = r.pair_a
		wins += 1.0 if int(r.winner) == sa else (0.5 if int(r.winner) == MatchSim.DRAW else 0.0)
		durs.append(r.duration)
		esc += 1 if r.escalated else 0
		for s in 2:
			a6.append(r.age_times[s][5] if r.age_times[s][5] >= 0.0 else 9999.0)
		for i in 12:
			deaths[i] += r.deaths[i]
	durs.sort()
	a6.sort()
	var total := 0.0
	for v in deaths:
		total += v
	print("%s vs %s  n=%d  %s  (%.0fs)" % [a, b, n, " ".join(overrides), (Time.get_ticks_msec() - t0) / 1000.0])
	print("  %s win rate: %d%%   median length %s   escalated %d%%   median Age 6 %s" % [
		a, roundi(wins / n * 100.0), _mmss(durs[durs.size() / 2]), roundi(100.0 * esc / n), _mmss(a6[a6.size() / 2])])
	print("  deaths by lane (own gate → enemy gate): " + " ".join(Array(deaths).map(func(v): return "%2d" % roundi(100.0 * v / maxf(1.0, total)))))
	quit()


func _mmss(t: float) -> String:
	return "never" if t >= 9999.0 else "%d:%02d" % [int(t) / 60, int(t) % 60]
