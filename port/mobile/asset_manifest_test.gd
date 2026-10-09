extends SceneTree

var files = {}

func _initialize():
	_build.call_deferred()

func _visit(path: String):
	if not path.begins_with("res://") or files.has(path): return
	if not FileAccess.file_exists(path):
		push_error("Missing dependency: " + path)
		return
	files[path] = true
	for dependency in ResourceLoader.get_dependencies(path):
		_visit(dependency.get_slice("::", dependency.get_slice_count("::") - 1))
	if FileAccess.file_exists(path + ".import"):
		files[path + ".import"] = true
		var config = ConfigFile.new()
		if config.load(path + ".import") == OK:
			var destinations = config.get_value("deps", "dest_files", [])
			for destination in destinations: _visit(destination)
			for key in config.get_section_keys("remap"):
				if key.begins_with("path"): _visit(config.get_value("remap", key))
	if FileAccess.file_exists(path + ".remap"):
		files[path + ".remap"] = true
		var remap = ConfigFile.new()
		if remap.load(path + ".remap") == OK: _visit(remap.get_value("remap", "path", ""))

func _build():
	for scene in ["menu", "main", "heaven", "death", "win"]:
		_visit("res://scenes/" + scene + ".tscn")
	_visit("res://default_bus_layout.tres")
	_visit("res://misc/icon1.png")
	_visit("res://misc/CR White splash.png")
	for locale in ["EN", "BR", "DE", "EE", "ES LATAM", "ES", "FR", "IT", "JA", "KO", "PL", "PT", "RU", "TR", "UA", "ZHS", "ZHT"]:
		_visit("res://localization/Buckshot Roulette - Localization Sheet - Sheet47." + locale + ".translation")
	var output = FileAccess.open(OS.get_environment("BUCKSHOT_MANIFEST"), FileAccess.WRITE)
	output.store_string(JSON.stringify(files.keys(), "\t"))
	output.close()
	print("ASSET_MANIFEST ", files.size())
	quit()
