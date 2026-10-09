extends "res://mobile/pill_test.gd"

func _after_first_shot(interaction):
	Engine.time_scale = 4.0
	var rounds = interaction.shotgun.roundManager
	var gun = null
	for branch in interaction.shotgun.perm.interactionBranchArray:
		if branch.interactionAlias == "shotgun": gun = branch
	for accept in [true, false]:
		await _before_first_round(interaction, gun)
		var settled = await _wait_until(func(): return gun.interactionAllowed and rounds.cursor.cursor_visible, 30.0)
		_check(settled, "original player turn settled before transition fixture")
		if not settled: break
		rounds.perm.SetInteractionPermissions(false)
		# Fixture represents a completed batch; this is transition coverage, not a played victory.
		rounds.playerData.currentBatchIndex = 2
		rounds.EndMainBatch()
		var ready = await _wait_until(func(): return rounds.intbranch_yes.interactionAllowed and rounds.cursor.cursor_visible, 20.0)
		_check(ready, "completed-batch fixture opens double-or-nothing choice")
		await _capture("double-choice-yes" if accept else "double-choice-no")
		if ready:
			await _click_branch(interaction.mouseRay, rounds.intbranch_yes if accept else rounds.intbranch_no, "double choice")
			_check(not rounds.intbranch_yes.interactionAllowed and not rounds.intbranch_no.interactionAllowed, "double choice prevents repeated response")
			if accept:
				ready = await _wait_until(func(): return rounds.playerData.currentBatchIndex == 0, 6.0)
				_check(ready, "double yes restarts original endless batch")
			else:
				ready = await _wait_until(func(): return interaction.brief.intbranch_L.interactionAllowed, 12.0)
				_check(ready and interaction.brief.ending.endless_overwriting, "double no starts original cashout briefcase")
				for branch in [interaction.brief.intbranch_L, interaction.brief.intbranch_R, interaction.brief.intbranch_lid]:
					ready = await _wait_until(func(): return branch.interactionAllowed and rounds.cursor.cursor_visible, 5.0)
					_check(ready, "cashout " + branch.interactionAlias + " available")
					if ready: await _click_branch(interaction.mouseRay, branch, branch.interactionAlias)
				ready = await _wait_until(func(): return interaction.brief.ending.waitingForInput, 50.0)
				_check(ready, "cashout reaches original congratulations")
				await _capture("cashout-ending")
				rounds.playerData.currentBatchIndex = 0
				if ready:
					_tap(Vector2(480, 270))
					ready = await _wait_until(func(): return current_scene != null and current_scene.scene_file_path == "res://scenes/menu.tscn", 20.0)
					_check(ready, "cashout valid touch returns to menu")
		if is_instance_valid(rounds): rounds.playerData.currentBatchIndex = 0
	if current_scene == null or current_scene.scene_file_path != "res://scenes/menu.tscn":
		root.get_node("MobileRuntime")._return_to_menu()
	await process_frame
	var report = FileAccess.open(image_dir.path_join("mode-transition-results.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"fixture": "Completed batch injected; no natural victory claim", "checks": results, "failures": failures}, "\t"))
	report.close()
	print("MODE_TRANSITION_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	Engine.time_scale = 1.0
