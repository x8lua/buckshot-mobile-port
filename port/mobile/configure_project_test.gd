extends SceneTree

func _initialize():
	var translations = PackedStringArray()
	for locale in ["EN", "BR", "DE", "EE", "ES LATAM", "ES", "FR", "IT", "JA", "KO", "PL", "PT", "RU", "TR", "UA", "ZHS", "ZHT"]:
		translations.append("res://localization/Buckshot Roulette - Localization Sheet - Sheet47." + locale + ".translation")
	ProjectSettings.set_setting("internationalization/locale/translations", translations)
	ProjectSettings.set_setting("internationalization/locale/fallback", "EN")
	var error = ProjectSettings.save()
	print("PROJECT_SETTINGS_SAVE ", error)
	quit(0 if error == OK else 1)
