extends TestCase
## The figure kit must drop into another project: nothing under addons/figure_kit/ may name a class
## defined outside it (comments included — a copied kit must not point at code that isn't there).

const KIT := "res://addons/figure_kit/"


func test_kit_names_no_game_class() -> void:
	var files := Array(DirAccess.get_files_at(KIT)).filter(func(f: String) -> bool: return f.ends_with(".gd"))
	check(files.size() >= 1, "the kit has scripts")
	var game: Array[String] = []
	for c in ProjectSettings.get_global_class_list():
		if not String(c.path).begins_with(KIT):
			game.append(String(c["class"]))
	for f in files:
		var src := FileAccess.get_file_as_string(KIT + f)
		for name in game:
			check(RegEx.create_from_string("\b%s\b" % name).search(src) == null, "%s names game class %s" % [f, name])
