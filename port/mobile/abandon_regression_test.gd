extends SceneTree

var failures = []
var backups = {}
const STORY_SAVE = "user://buckshotroulette_main_12.shell"

func _initialize(): run.call_deferred()

func check(value, label):
	print("CHECK ", label, " ", "PASS" if value else "FAIL")
	if not value: failures.append(label)

func tap(position):
	for pressed in [true, false]:
		var event: InputEvent
		if OS.get_cmdline_user_args().has("--windows-mouse-test"):
			event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
		else:
			event = InputEventScreenTouch.new()
			event.index = 0
		event.position = position
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame

func run():
	await process_frame
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(960, 540)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var mobile = root.get_node("MobileRuntime")
	if OS.get_cmdline_user_args().has("--windows-mouse-test"):
		check(OS.has_feature("mobile_demo"), "packaged Windows demo mouse bridge active")
	for path in [mobile.CHECKPOINT_PATH, STORY_SAVE]:
		backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	var sequence: Array[String] = ["live", "blank", "live"]
	var known: Array[bool] = [false, false, false]
	var file = FileAccess.open(mobile.CHECKPOINT_PATH, FileAccess.WRITE)
	file.store_var({"version":1,"endless":false,"current_batch_index":1,"current_round":1,"health_player":3,"health_opponent":2,"sequence":sequence,"known_shells":known,"player_name":"tester","items":[]})
	file.close()
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(12).timeout
	var scene = current_scene
	var rm = scene.get_node("standalone managers/round manager")
	check(mobile._table_idle(), "restored table ready for dealer taps")
	var position = rm.camera.cam.unproject_position(mobile._dealer_hitbox.get_child(0).global_position)
	print("DEALER_TOUCH ", position)
	check(Rect2(Vector2.ZERO, Vector2(960, 540)).has_point(position), "dealer touch target is on screen")
	for count in range(4): await tap(position)
	check(mobile._dealer_taps == 4 and not mobile._abandoning, "four actual touches do not abandon")
	mobile._toggle_pause()
	check(mobile._dealer_taps == 0, "pause resets consecutive taps")
	mobile._toggle_pause()
	await tap(position)
	await tap(Vector2(20, 500))
	check(mobile._dealer_taps == 0, "other touch resets consecutive taps")
	for count in range(5): await tap(position)
	check(mobile._abandoning and mobile._abandon_stage == "grabbing", "fifth actual touch starts abandonment")
	if mobile._abandoning:
		check(not mobile.has_checkpoint(), "checkpoint cleared immediately")
		check(not FileAccess.file_exists(STORY_SAVE), "story run save cleared before execution")
		mobile.save_checkpoint(rm)
		check(not mobile.has_checkpoint(), "save cannot resurrect abandoned checkpoint")
		mobile._toggle_pause()
		check(not paused and not mobile._pause_button.visible, "pause blocked during execution")
		await create_timer(1.8).timeout
		check(mobile._abandon_stage == "aiming" and rm.dealerAI.animator_shotgun.current_animation == "enemy shoot player", "original dealer aiming animation used")
		await create_timer(2.0).timeout
		check(mobile._abandon_stage == "echo" and rm.death.viewblocker.visible, "shot enters black screen with echo")
		var bus = AudioServer.get_bus_index(mobile.ABANDON_ECHO_BUS)
		check(bus >= 0 and AudioServer.get_bus_effect_count(bus) == 1 and AudioServer.get_bus_effect(bus, 0) is AudioEffectDelay, "gunshot routed through echo effect")
		await create_timer(1.8).timeout
		check(current_scene == scene and mobile._abandon_stage == "echo", "bathroom waits for three-second shot tail")
		await create_timer(4.5).timeout
		check(current_scene != scene and current_scene.scene_file_path == "res://scenes/main.tscn", "fresh bathroom scene loaded")
		var fresh_rm = current_scene.get_node("standalone managers/round manager")
		var intro = current_scene.get_node("standalone managers/intro manager")
		check(intro.animator_camera.current_animation == "camera idle bathroom", "camera returned to bathroom")
		check(fresh_rm.playerData.currentBatchIndex == 0 and not fresh_rm.playerData.hasSignedWaiver, "run progression reset")
		check(not mobile.has_checkpoint() and not FileAccess.file_exists(STORY_SAVE), "both run saves removed")
		check(AudioServer.get_bus_index(mobile.ABANDON_ECHO_BUS) == -1 and not mobile._abandoning, "echo bus cleaned and interaction unlocked")
		check(mobile._pause_button.visible, "pause restored in bathroom")
	for path in backups:
		if backups[path] != null:
			file = FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(backups[path])
			file.close()
		elif FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("ABANDON_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
