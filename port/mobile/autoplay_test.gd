extends "res://mobile/gameplay_test.gd"

var used_items = {}
var completed_story = false

func _collect_branches(node: Node, output: Array):
	if node is InteractionBranch: output.append(node)
	for child in node.get_children(): _collect_branches(child, output)

func _after_first_shot(interaction):
	var rounds = interaction.shotgun.roundManager
	var camera = interaction.mouseRay
	var gun = null
	for branch in interaction.shotgun.perm.interactionBranchArray:
		if branch.interactionAlias == "shotgun": gun = branch
	var branches = []
	_collect_branches(current_scene, branches)
	var last_action = ""
	var stuck = 0.0
	for tick in range(2400):
		# Accelerated integration run using the actual scenes and input path.
		Engine.time_scale = 4.0
		await create_timer(0.5).timeout
		if not is_instance_valid(interaction): break
		if rounds.playerData.currentBatchIndex >= 3:
			completed_story = true
			break
		if not interaction.cursor.cursor_visible:
			continue
		var candidates = []
		for branch in interaction.itemManager.items_dynamicInteractionArray:
			if is_instance_valid(branch) and branch.interactionAllowed and not branch.interactionInvalid and not used_items.has(branch.itemName):
				if branch.itemName in ["handcuffs", "cigarettes", "handsaw", "magnifying glass", "beer", "inverter", "burner phone"]:
					candidates.append(branch)
		if interaction.itemManager.interaction_intake.interactionAllowed:
			candidates.append(interaction.itemManager.interaction_intake)
		for branch in branches:
			if not is_instance_valid(branch) or not branch.interactionAllowed or branch.interactionInvalid: continue
			if branch.isGrid:
				candidates.append(branch)
			elif branch.interactionAlias == "item" and not used_items.has(branch.itemName):
				if branch.itemName in ["handcuffs", "cigarettes", "handsaw", "magnifying glass", "beer", "inverter", "burner phone"]:
					candidates.append(branch)
		var target_alias = "text dealer"
		if not rounds.shellSpawner.sequenceArray.is_empty() and rounds.shellSpawner.sequenceArray[0] == "blank":
			target_alias = "text you"
		if not interaction.fs_dec:
			for branch in branches:
				if is_instance_valid(branch) and branch.interactionAlias == target_alias and branch.interactionAllowed:
					candidates.append(branch)
		if gun.interactionAllowed: candidates.append(gun)
		var acted = false
		for branch in candidates:
			var point = _target_point(camera, branch.get_parent())
			if point.x < 0: continue
			var alias = branch.itemName if branch.interactionAlias == "item" else branch.interactionAlias
			_tap(point)
			await process_frame
			if alias != last_action:
				print("AUTOPLAY ", alias, " batch=", rounds.playerData.currentBatchIndex, " round=", rounds.currentRound)
			last_action = alias
			if branch.interactionAlias == "item" and not branch.interactionAllowed: used_items[alias] = true
			acted = true
			stuck = 0.0
			break
		if not acted:
			stuck += 0.5
			if stuck > 45.0:
				print("AUTOPLAY_STALLED batch=", rounds.playerData.currentBatchIndex, " candidates=", candidates.size())
				await _capture("autoplay-stalled")
				break
	Engine.time_scale = 1.0
	_check(completed_story, "accelerated full story reaches final batch completion")
	print("AUTOPLAY_ITEMS ", used_items.keys())
	await _capture("autoplay-final")
