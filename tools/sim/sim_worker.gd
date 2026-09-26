extends SceneTree
## Worker process for SimJobs.run_all: runs a slice of jobs and writes their results as JSON.


func _init() -> void:
	var jobs_path := ""
	var out_path := ""
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--jobs="):
			jobs_path = a.trim_prefix("--jobs=")
		elif a.begins_with("--out="):
			out_path = a.trim_prefix("--out=")
	var data := GameData.get_default()
	SimJobs.apply_overrides(args, data)
	var jobs: Array = JSON.parse_string(FileAccess.get_file_as_string(jobs_path))
	var results := []
	for j in jobs:
		results.append(SimJobs.run_job(data, j))
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(results))
	f.close()
	quit()
