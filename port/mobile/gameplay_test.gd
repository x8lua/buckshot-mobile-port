extends "res://mobile/smoke_test.gd"

func _wait_until(predicate: Callable, seconds: float) -> bool:
	var elapsed = 0.0
	while elapsed < seconds:
		if predicate.call(): return true
		await create_timer(0.1).timeout
		elapsed += 0.1
	return false

func _click_branch(camera: Camera3D, branch: Node, label: String):
	var point = _target_point(camera, branch.get_parent())
	_check(point.x >= 0, label + " visible collider")
	if point.x >= 0:
		_tap(point)
		await process_frame

func _run():
	image_dir = OS.get_environment("BUCKSHOT_TEST_OUTPUT")
	if image_dir.is_empty(): image_dir = ProjectSettings.globalize_path("user://gameplay-tests")
	DirAccess.make_dir_recursive_absolute(image_dir)
	await process_frame
	var mobile = root.get_node("MobileRuntime")
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(5.0).timeout
	var interaction = _find(current_scene, "InteractionManager")
	var camera = interaction.mouseRay
	var intro = interaction.intro
	await _click_branch(camera, intro.intbranch_bathroomdoor, "bathroom door")
	var ready = await _wait_until(func(): return intro.intbranch_backroomdoor.interactionAllowed, 15.0)
	_check(ready, "backroom door becomes available")
	if ready: await _click_branch(camera, intro.intbranch_backroomdoor, "backroom door")
	var signature = interaction.sign
	ready = await _wait_until(func(): return signature.intrbranch_waiver.interactionAllowed, 40.0)
	_check(ready, "waiver becomes available")
	if ready: await _click_branch(camera, signature.intrbranch_waiver, "waiver")
	ready = await _wait_until(func(): return mobile._name_dialog.visible, 8.0)
	_check(ready, "native name dialog opens")
	if ready:
		mobile._name_edit.text = "mobile"
		mobile._submit_name()
		await _wait_until(func(): return signature.roundManager.playerData.hasSignedWaiver, 10.0)
		_check(signature.roundManager.playerData.hasSignedWaiver, "original waiver accepts mobile name")
		_check(signature.roundManager.playerData.playername.strip_edges() == "mobile", "name written to original player data")
	await _capture("signed-waiver")
	var gun_branch = null
	for branch in interaction.shotgun.perm.interactionBranchArray:
		if branch.interactionAlias == "shotgun": gun_branch = branch
	ready = await _wait_until(func(): return gun_branch.interactionAllowed and interaction.cursor.cursor_visible, 60.0)
	_check(ready, "first round exposes shotgun")
	await _capture("first-round")
	if ready:
		await _click_branch(camera, gun_branch, "shotgun")
		await create_timer(0.7).timeout
		_check(not gun_branch.interactionAllowed, "shotgun pickup disables repeat pickup")
		var choice = null
		for child in interaction.decision.colliderArray:
			for sibling in child.get_parent().get_children():
				if sibling is InteractionBranch and sibling.interactionAlias == "text dealer": choice = sibling
		_check(choice != null, "dealer shot target exists")
		if choice:
			var shots_before = interaction.shotgun.roundManager.playerData.stat_shotsFired
			await _click_branch(camera, choice, "dealer target")
			ready = await _wait_until(func(): return interaction.shotgun.roundManager.playerData.stat_shotsFired > shots_before, 20.0)
			_check(ready, "touch fires original shotgun sequence")
		await _capture("after-shot")
	var save = _find(current_scene, "SaveFileManager")
	save.SaveGame()
	save.LoadGame()
	_check(save.roundManager.playerData.hasSignedWaiver, "waiver survives save reload")
	var report = FileAccess.open(image_dir.path_join("gameplay-results.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": results, "failures": failures}, "\t"))
	report.close()
	print("GAMEPLAY_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
