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
		var dmg: Variant = ab.damage if ab.damage_mode != "percent" else "%d%% max HP" % roundi(ab.damage_pct * 100.0)
		f.store_csv_line(PackedStringArray(["ability", age.index, ab.id, ab.display_name, "%s/%s" % [ab.shape, ab.aim], "", ab.damage_type, ab.xp_cost, "", dmg, ab.pulse_interval, ab.width, "", "", "", "mode=%s pulses=%d telegraph=%s knockback=%s slow=%s/%ss" % [ab.damage_mode, ab.pulses, ab.telegraph, ab.knockback, ab.slow, ab.slow_time]]))
		f.store_csv_line(PackedStringArray(["age", age.index, age.display_name.to_lower(), age.display_name, "", "", "", age.evolve_cost, age.base_max_hp, "", "", "", "", "", "", ""]))
	f.close()
	print("wrote ", out)
	quit()
