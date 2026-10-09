extends "res://mobile/gameplay_test.gd"

func _after_first_shot(interaction):
	var rounds = interaction.shotgun.roundManager
	var gun = null
	for branch in interaction.shotgun.perm.interactionBranchArray:
		if branch.interactionAlias == "shotgun": gun = branch
	var ready = await _wait_until(func(): return gun.interactionAllowed and rounds.cursor.cursor_visible, 35.0)
	_check(ready, "player turn settled before lethal-shot fixture")
	if not ready: return
	# Reproduce a lethal dealer shot through the original shooting/death routines.
	rounds.perm.SetInteractionPermissions(false)
	rounds.health_player = 1
	rounds.wireIsCut_player = false
	rounds.shellSpawner.sequenceArray.clear()
	rounds.shellSpawner.sequenceArray.append("live")
	rounds.dealerAI.Shoot("player")
	ready = await _wait_until(func(): return not is_instance_valid(interaction), 15.0)
	_check(ready, "lethal dealer shot leaves original scene")
	ready = await _wait_until(func():
		if not current_scene or current_scene.scene_file_path != "res://scenes/main.tscn": return false
		var replacement = _find(current_scene, "InteractionManager")
		return replacement != null and replacement.intro.intbranch_bathroomdoor.interactionAllowed, 40.0)
	_check(ready, "story death returns to playable bathroom")
	if ready:
		var replacement = _find(current_scene, "InteractionManager")
		_check(replacement.intro.intbranch_pillbottle.interactionAllowed, "pill remains available after story death")
		await _capture("revival-bathroom")
	print("DEATH_TRANSITION_FIXTURE lethal dealer shot injected; no natural loss claim")
