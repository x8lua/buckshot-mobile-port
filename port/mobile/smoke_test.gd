extends SceneTree

var failures = []
var results = []
var image_dir = ""

func _initialize():
	_run.call_deferred()

func _check(condition: bool, label: String):
	results.append({"check": label, "passed": condition})
	print("CHECK ", label, " ", "PASS" if condition else "FAIL")
	if not condition: failures.append(label)

func _touch(position: Vector2, pressed: bool, index = 0):
	var event = InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	root.push_input(event, true)

func _tap(position: Vector2):
	_touch(position, true)
	_touch(position, false)

func _capture(label: String):
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var error = root.get_texture().get_image().save_png(image_dir.path_join(label + ".png"))
	_check(error == OK, "screenshot " + label)

func _find(node: Node, type_name: String) -> Node:
	if node.get_class() == type_name: return node
	if node.get_script() and node.get_script().get_global_name() == type_name: return node
	for child in node.get_children():
		var match_node = _find(child, type_name)
		if match_node: return match_node
	return null

func _target_point(camera: Camera3D, target: Node) -> Vector2:
	for y in range(40, 520, 20):
		for x in range(20, 940, 20):
			camera.mouse = Vector2(x, y)
			camera.get_selection()
			if camera.result.has("collider") and camera.result.collider.get_parent() == target:
				return camera.mouse
	return Vector2(-1, -1)

func _run():
	image_dir = OS.get_environment("BUCKSHOT_TEST_OUTPUT")
	if image_dir.is_empty(): image_dir = ProjectSettings.globalize_path("user://mobile-tests")
	DirAccess.make_dir_recursive_absolute(image_dir)
	await process_frame
	var mobile = root.get_node("MobileRuntime")
	_check(mobile.enabled, "mobile preview enabled")
	change_scene_to_file("res://scenes/menu.tscn")
	await create_timer(1.5).timeout
	var menu = _find(current_scene, "MenuManager")
	_check(menu != null, "menu manager loaded")
	menu.SkipIntro()
	await create_timer(1.0).timeout
	_check(not menu.buttons[22].ui.visible, "multiplayer hidden")
	await _capture("menu")
	var point = menu.buttons[1].get_parent().get_global_rect().get_center()
	_tap(point)
	await process_frame
	_check(menu.currentScreen == "sub options", "touch opens options once")
	menu.ReturnToLastScreen()
	_touch(point, true)
	_touch(point + Vector2(4, 0), true, 1)
	_touch(point, false)
	_touch(point + Vector2(4, 0), false, 1)
	await process_frame
	_check(menu.currentScreen == "main", "multitouch cancels command")
	_touch(point, true)
	var drag = InputEventScreenDrag.new()
	drag.index = 0
	drag.position = point + Vector2(70, 0)
	drag.relative = Vector2(70, 0)
	root.push_input(drag, true)
	_touch(drag.position, false)
	await process_frame
	_check(menu.currentScreen == "main", "drag cancels command")
	mobile._toggle_pause()
	_check(paused, "pause freezes scene")
	await _capture("pause")
	mobile._toggle_pause()
	_check(not paused, "resume restores scene")
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(5.0).timeout
	var interaction = _find(current_scene, "InteractionManager")
	_check(interaction != null, "single player scene loaded")
	_check(interaction.intro.intbranch_bathroomdoor.interactionAllowed, "bathroom door available")
	await _capture("bathroom")
	# Test actual scene physics with stale pointer state before tapping the door.
	var camera = interaction.mouseRay
	var target = interaction.intro.intbranch_bathroomdoor.get_parent()
	var collider: CollisionObject3D = null
	for child in target.get_children():
		if child is CollisionObject3D: collider = child
	_check(collider != null, "door collider available")
	if collider:
		var hit_position = _target_point(camera, target)
		_check(hit_position.x >= 0, "visible ray hits door collider")
		camera.mouse = Vector2(-500, -500)
		_tap(hit_position)
		await process_frame
		_check(not interaction.intro.intbranch_bathroomdoor.interactionAllowed, "touch door uses current raycast")
	await create_timer(5.3).timeout
	await _capture("lobby")
	var save = _find(current_scene, "SaveFileManager")
	_check(save != null, "save manager available")
	if save:
		save.SaveGame()
		_check(FileAccess.file_exists(save.savePath), "single player save written")
	var report = FileAccess.open(image_dir.path_join("smoke-results.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": results, "failures": failures}, "\t"))
	report.close()
	print("SMOKE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	current_scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
