extends "res://mobile/gameplay_test.gd"

func _before_bathroom(interaction):
	var intro = interaction.intro
	var camera = interaction.mouseRay
	_check(not FileAccess.file_exists(intro.unlocker.savepath), "fresh save has no story completion unlock")
	_check(intro.parent_pills.visible and intro.intbranch_pillbottle.interactionAllowed, "pill available on first launch")
	await _capture("fresh-save-pill")
	await _click_branch(camera, intro.intbranch_pillbottle, "pill bottle")
	var ready = await _wait_until(func(): return intro.intbranch_pillno.interactionAllowed and intro.cursor.cursor_visible, 5.0)
	_check(ready, "pill confirmation opens")
	if ready: await _click_branch(camera, intro.intbranch_pillno, "decline pill")
	await _wait_until(func(): return intro.intbranch_pillbottle.interactionAllowed and intro.cursor.cursor_visible, 5.0)
	_check(not intro.roundManager.endless, "declining pill keeps story mode")
	_check(not intro.intbranch_crt.interactionAllowed and not intro.btn_screen.visible, "declining pill leaves online terminal disabled")
	await _click_branch(camera, intro.intbranch_pillbottle, "pill bottle again")
	ready = await _wait_until(func(): return intro.intbranch_pillyes.interactionAllowed and intro.cursor.cursor_visible, 5.0)
	_check(ready, "pill confirmation reopens")
	if ready: await _click_branch(camera, intro.intbranch_pillyes, "accept pill")
	ready = await _wait_until(func(): return intro.roundManager.endless and intro.intbranch_bathroomdoor.interactionAllowed and intro.cursor.cursor_visible, 6.0)
	_check(ready, "pill enters original endless mode without story completion")
	await _capture("endless-enabled")
