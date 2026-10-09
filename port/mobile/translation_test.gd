extends SceneTree

func _initialize():
	for locale in ["EN", "ZHT", "en", "zh_TW"]:
		TranslationServer.set_locale(locale)
		print("LOCALE ", locale, " resolved=", TranslationServer.get_locale(), " live=", tr("LIVEROUND"), " win=", tr("PLAYERWIN"))
	for sheet in ["Sheet26", "Sheet47"]:
		var table = load("res://localization/Buckshot Roulette - Localization Sheet - " + sheet + ".EN.translation")
		print("TABLE ", sheet, " ", table.get_class(), " ", table.get_locale(), " live=", table.get_message("LIVEROUND"), " win=", table.get_message("PLAYERWIN"))
	quit()
