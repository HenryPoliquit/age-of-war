extends SceneTree
## Exports every unit, turret and ability to one CSV for spreadsheet review (GDD §15.1).
##   tools/godot --headless --path . -s tools/export_csv.gd -- --out=reports/data.csv


func _init() -> void:
	var out := "reports/data.csv"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
	var gd := GameData.get_default()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_csv_line(PackedStringArray(["kind", "age", "id", "name", "role_or_type", "armour", "damage_type", "cost", "hp", "damage", "interval", "range", "min_range", "speed", "train_time", "extra"]))
	for age in gd.ages:
		for u in age.units:
			f.store_csv_line(PackedStringArray(["unit", age.index, u.id, u.display_name, u.role, u.armour, u.damage_type, u.cost, u.hp, u.damage, u.attack_interval, u.range, u.min_range, u.speed, u.train_time, ""]))
		for t in age.turrets:
			f.store_csv_line(PackedStringArray(["turret", age.index, t.id, t.display_name, t.kind, "structure", t.damage_type, t.cost, t.hp, t.damage, t.attack_interval, t.range, t.min_range, "", "", "splash=%s aura=%s slow=%s" % [t.splash, t.aura_radius, t.aura_slow]]))
		var ab := age.ability
		f.store_csv_line(PackedStringArray(["ability", age.index, ab.id, ab.display_name, ab.affects, "", ab.damage_type, "", "", ab.damage, ab.pulse_interval, ab.width, "", "", "", "pulses=%d telegraph=%s knockback=%s armour=%s dur=%s" % [ab.pulses, ab.telegraph, ab.knockback, ab.armour_buff, ab.buff_duration]]))
		f.store_csv_line(PackedStringArray(["age", age.index, age.display_name.to_lower(), age.display_name, "", "", "", age.evolve_cost, age.base_max_hp, "", "", "", "", "", "", "vet_base=%d" % age.veterancy_base_xp]))
	f.close()
	print("wrote ", out)
	quit()
