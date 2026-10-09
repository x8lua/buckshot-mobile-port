extends SceneTree

var failures = []

func _initialize():
	_check_resources.call_deferred()

func _check_resources():
	for scene in ["menu", "main", "heaven", "death", "win"]:
		var resource = load("res://scenes/" + scene + ".tscn")
		if not resource is PackedScene: failures.append(scene)
		print("RESOURCE ", scene, " ", "PASS" if resource is PackedScene else "FAIL")
	for locale in ["EN", "BR", "DE", "EE", "ES LATAM", "ES", "FR", "IT", "JA", "KO", "PL", "PT", "RU", "TR", "UA", "ZHS", "ZHT"]:
		TranslationServer.set_locale(locale)
		for key in ["LIVEROUND", "LIVEROUNDS", "BLANKROUND", "BLANKROUNDS", "PLAYERWIN"]:
			if not tr(key).contains("%s"): failures.append(locale + ":" + key)
	print("RESOURCE_CHECK ", JSON.stringify({"passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
