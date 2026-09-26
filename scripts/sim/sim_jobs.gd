class_name SimJobs
extends RefCounted
## Runs batches of headless AI-vs-AI matches, optionally across worker processes, and returns
## JSON-safe results. Shared by the balance harness and the experiment tool.
##
## Job: {suite, left, right, left_diff, right_diff, seed, random_doctrines, left_docs, right_docs, pair_a}
## Temporary data overrides (applied in every worker, never saved):
##   --set=rules.forge_income_bonus=0.1          --set=doctrines/horde.unit_cost_mult=0.75
##   --scale=units:role=heavy.hp=0.9             --scale=turrets:kind=sentry.damage=0.8
##   --scale=ages:index=*.base_max_hp=1.5

const WORKER := "res://tools/sim/sim_worker.gd"


static func apply_overrides(args: PackedStringArray, data: GameData) -> Array[String]:
	var applied: Array[String] = []
	for a in args:
		if a.begins_with("--set="):
			var spec := a.trim_prefix("--set=")
			var lhs := spec.get_slice("=", 0)
			var value: Variant = str_to_var(spec.get_slice("=", 1))
			var path := lhs.get_base_dir().path_join(lhs.get_file().get_basename()) if lhs.contains("/") else lhs.get_basename()
			var prop := lhs.get_extension()
			var res: Resource = data.rules if path == "rules" else load("res://data/%s.tres" % path)
			assert(res != null and prop in res, "bad --set: " + spec)
			res.set(prop, value)
			applied.append(spec)
		elif a.begins_with("--scale="):
			var spec := a.trim_prefix("--scale=")
			# The filter itself contains "=", so the multiplier is after the last one.
			var eq := spec.rfind("=")
			var lhs := spec.substr(0, eq)
			var mult := float(spec.substr(eq + 1))
			var kind := lhs.get_slice(":", 0)
			var rest := lhs.get_slice(":", 1)
			var filt := rest.get_slice(".", 0)
			var prop := rest.get_slice(".", 1)
			var fkey := filt.get_slice("=", 0)
			var fval := filt.get_slice("=", 1)
			for age in data.ages:
				var items: Array = [age] if kind == "ages" else (age.units if kind == "units" else age.turrets)
				for r in items:
					if fval == "*" or str(r.get(fkey)) == fval:
						var v: Variant = r.get(prop)
						r.set(prop, roundi(v * mult) if v is int else v * mult)
			applied.append(spec)
	return applied


static func run_job(data: GameData, job: Dictionary) -> Dictionary:
	var left := {"personality": StringName(job.left), "difficulty": StringName(job.get("left_diff", "hard")), "doctrines": job.get("left_docs", [])}
	var right := {"personality": StringName(job.right), "difficulty": StringName(job.get("right_diff", "hard")), "doctrines": job.get("right_docs", [])}
	var r := MatchRunner.run(data, left, right, int(job.seed), job.get("random_doctrines", false), int(job.get("start_age", 1)))
	var log: MatchLog = r.log
	var docs := []
	for side_docs in r.doctrines:
		docs.append(side_docs.map(func(d): return String(d)))
	var units := {}
	for side_stats in log.unit_stats:
		for id in side_stats:
			var k := String(id)
			var st: Dictionary = side_stats[id]
			if not units.has(k):
				units[k] = {"spawned": 0, "gold": 0.0, "dealt": 0.0, "absorbed": 0.0}
			for f in ["spawned", "gold", "dealt", "absorbed"]:
				units[k][f] += st[f]
	return {
		"suite": job.get("suite", ""),
		"names": [job.left, job.right],
		"pair_a": job.get("pair_a", 0),
		"seed": job.seed,
		"winner": r.winner,
		"duration": r.duration,
		"escalated": r.escalated,
		"age_times": [Array(r.age_times[0]), Array(r.age_times[1])],
		"final_ages": r.final_ages,
		"doctrines": docs,
		"units": units,
		"deaths": Array(log.deaths),
		"base_damage": Array(log.base_damage),
	}


## Runs every job; with workers > 1 splits them across child Godot processes.
static func run_all(jobs: Array, workers: int, passthrough: PackedStringArray) -> Array:
	if workers <= 1 or jobs.size() < 4:
		var data := GameData.get_default()
		var out := []
		for j in jobs:
			out.append(run_job(data, j))
		return out
	var tmp := OS.get_cache_dir().path_join("timefront_sim_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(tmp)
	var pids := []
	var outs := []
	for w in workers:
		var slice := []
		for i in range(w, jobs.size(), workers):
			slice.append(jobs[i])
		var jf := tmp.path_join("jobs_%d.json" % w)
		var of := tmp.path_join("out_%d.json" % w)
		var f := FileAccess.open(jf, FileAccess.WRITE)
		f.store_string(JSON.stringify(slice))
		f.close()
		var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", WORKER, "--", "--jobs=" + jf, "--out=" + of])
		args.append_array(passthrough)
		pids.append(OS.create_process(OS.get_executable_path(), args))
		outs.append(of)
	while pids.any(func(p): return OS.is_process_running(p)):
		OS.delay_msec(200)
	var results := []
	for of in outs:
		var txt := FileAccess.get_file_as_string(of)
		var parsed: Variant = JSON.parse_string(txt)
		assert(parsed is Array, "worker failed: " + of)
		results.append_array(parsed)
	# Restore job order so reports don't depend on scheduling.
	var order := {}
	for i in jobs.size():
		order[int(jobs[i].seed)] = i
	results.sort_custom(func(a, b): return order[int(a.seed)] < order[int(b.seed)])
	return results


## Pass-through args for workers: every data override given to the parent.
static func passthrough_args() -> PackedStringArray:
	var out := PackedStringArray()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--set=") or a.begins_with("--scale="):
			out.append(a)
	return out
