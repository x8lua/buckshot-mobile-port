extends CanvasLayer

var enabled = OS.has_feature("ios") or OS.has_feature("mobile_demo") or OS.get_cmdline_user_args().has("--mobile-preview")
var valid_tap = false
var quality = 1
var fps_limit = 30
var _fingers = {}
var _finger = -1
var _origin = Vector2.ZERO
var _position = Vector2.ZERO
var _cancelled = false
var _mouse_down = false
var _pause_root: Control
var _pause_button: Button
var _resume_button: Button
var _safe_bounds = Rect2(Vector2.ZERO, Vector2(960, 540))
var _backgrounded = false
var _was_paused = false
var _name_dialog: ConfirmationDialog
var _name_edit: LineEdit
var _name_error: Label
var _signature: Node
var _translation_controls = {}
const SETTINGS_PATH = "user://buckshot_mobile.cfg"
const CHECKPOINT_PATH = "user://buckshot_mobile_checkpoint.shell"
const TAP_SLOP = 18.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	if not enabled:
		return
	Input.emulate_mouse_from_touch = false
	Input.emulate_touch_from_mouse = false
	_register_translations()
	_load_settings()
	_build_controls()
	get_tree().node_added.connect(_on_node_added)
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()
	Engine.max_fps = fps_limit

func _input(event):
	if OS.has_feature("mobile_demo") and event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION:
		var touch: InputEvent
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			touch = InputEventScreenTouch.new()
			touch.index = 0
			touch.position = event.position
			touch.pressed = event.pressed
		elif event is InputEventMouseMotion and _mouse_down:
			touch = InputEventScreenDrag.new()
			touch.index = 0
			touch.position = event.position
			touch.relative = event.relative
		if touch:
			get_viewport().push_input(touch, true)
			get_viewport().set_input_as_handled()
			return
	if enabled and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and valid_tap and not get_tree().paused:
		if _click_dealer_abandon(event.position):
			get_viewport().set_input_as_handled()
			return
		_dealer_taps = 0
		if _click_shell_panel(event.position):
			get_viewport().set_input_as_handled()
			return
	if not enabled or _backgrounded:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_fingers[event.index] = true
			if _fingers.size() == 1:
				_finger = event.index
				_origin = event.position
				_position = event.position
				_cancelled = false
				_send_motion(_position)
				_send_button(_position, true)
			else:
				_cancel_touch()
		else:
			_fingers.erase(event.index)
			if event.index == _finger:
				_position = event.position
				valid_tap = not _cancelled and not event.canceled and _origin.distance_to(_position) <= TAP_SLOP
				_send_motion(_position)
				if _mouse_down: _send_button(_position, false, not valid_tap)
				valid_tap = false
				_finger = -1
			if _fingers.is_empty(): _cancelled = false
	elif event is InputEventScreenDrag and event.index == _finger:
		_position = event.position
		if _origin.distance_to(_position) > TAP_SLOP:
			_cancel_touch()
		else:
			_send_motion(_position)

func _send_motion(position: Vector2):
	var motion = InputEventMouseMotion.new()
	motion.device = InputEvent.DEVICE_ID_EMULATION
	motion.position = position
	motion.global_position = position
	get_viewport().push_input(motion, true)

func _send_button(position: Vector2, pressed: bool, cancelled = false):
	_mouse_down = pressed
	var button = InputEventMouseButton.new()
	button.device = InputEvent.DEVICE_ID_EMULATION
	button.position = position
	button.global_position = position
	button.button_index = MOUSE_BUTTON_LEFT
	button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	button.pressed = pressed
	button.canceled = cancelled
	get_viewport().push_input(button, true)

func _cancel_touch():
	_cancelled = true
	valid_tap = false
	if _mouse_down: _send_button(_position, false, true)

func _reset_touches():
	_cancel_touch()
	_fingers.clear()
	_finger = -1

func _build_controls():
	_pause_button = Button.new()
	_pause_button.text = "II"
	_pause_button.tooltip_text = tr("PAUSE")
	_pause_button.custom_minimum_size = Vector2(36, 36)
	_pause_button.size = Vector2(36, 36)
	_pause_button.add_theme_font_size_override("font_size", 18)
	_pause_button.pressed.connect(_toggle_pause)
	add_child(_pause_button)
	_pause_root = Control.new()
	_pause_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_root.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_pause_root.hide()
	add_child(_pause_root)
	var shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_root.add_child(shade)
	var column = VBoxContainer.new()
	column.position = Vector2(300, 38)
	column.size = Vector2(360, 464)
	column.add_theme_constant_override("separation", 12)
	_pause_root.add_child(column)
	var heading = Label.new()
	_localize(heading, "PAUSE")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 26)
	column.add_child(heading)
	_resume_button = _command(column, "RESUME", _toggle_pause)
	var quality_label = Label.new()
	_localize(quality_label, "QUALITY")
	column.add_child(quality_label)
	# Keep settings inside the paused canvas: PopupMenu is a separate Window
	# and can capture touch releases away from this runtime's mouse bridge.
	_inline_choices(column, ["LOW", "STANDARD"], quality, _set_quality)
	var fps_label = Label.new()
	fps_label.text = "FPS"
	column.add_child(fps_label)
	_inline_choices(column, ["30", "60"], 0 if fps_limit == 30 else 1, _set_fps)
	_command(column, "MAIN MENU", _return_to_menu)
	_name_dialog = ConfirmationDialog.new()
	_localize(_name_dialog, "NAME")
	_name_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	_name_dialog.dialog_hide_on_ok = false
	_name_dialog.size = Vector2i(360, 160)
	_name_dialog.confirmed.connect(_submit_name)
	_name_dialog.canceled.connect(func():
		if _name_edit.has_focus(): _name_edit.release_focus()
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide())
	add_child(_name_dialog)
	var name_column = VBoxContainer.new()
	_name_dialog.add_child(name_column)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 6
	_name_edit.virtual_keyboard_enabled = true
	_name_edit.custom_minimum_size = Vector2(340, 48)
	_name_edit.text_submitted.connect(func(_text): _submit_name())
	name_column.add_child(_name_edit)
	_name_error = Label.new()
	name_column.add_child(_name_error)

func _command(parent: Node, label: String, action: Callable) -> Button:
	var button = Button.new()
	_localize(button, label)
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _inline_choices(parent: Node, labels: Array, selected: int, action: Callable):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var group = ButtonGroup.new()
	group.allow_unpress = false
	for index in labels.size():
		var button = Button.new()
		_localize(button, labels[index])
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = index == selected
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(action.bind(index))
		row.add_child(button)

func _set_fps(index: int):
	fps_limit = 30 if index == 0 else 60
	Engine.max_fps = fps_limit
	_save_settings()

func _toggle_pause():
	if _abandoning: return
	_dealer_taps = 0
	_reset_touches()
	var paused = not get_tree().paused
	get_tree().paused = paused
	_pause_root.visible = paused
	_pause_button.visible = not paused
	if paused: _resume_button.grab_focus()

func _return_to_menu():
	_reset_touches()
	save_checkpoint_from_scene()
	get_tree().paused = false
	_pause_root.hide()
	_pause_button.show()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func has_checkpoint() -> bool:
	return FileAccess.file_exists(CHECKPOINT_PATH)

func discard_story_checkpoint(manager: Node):
	var data = load_checkpoint()
	if not data.is_empty() and not bool(data.get("endless", false)):
		clear_checkpoint()
		_reset_run_data(manager)

func load_checkpoint() -> Dictionary:
	if not has_checkpoint(): return {}
	var file = FileAccess.open(CHECKPOINT_PATH, FileAccess.READ)
	if file == null: return {}
	var value = file.get_var()
	file.close()
	return value if value is Dictionary else {}

func clear_checkpoint():
	if has_checkpoint():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CHECKPOINT_PATH))

func restore_checkpoint(manager: Node) -> bool:
	var data = load_checkpoint()
	if data.is_empty() or not is_instance_valid(manager): return false
	if not bool(data.get("endless", false)):
		clear_checkpoint()
		_reset_run_data(manager)
		return false
	var player_data = manager.get("playerData")
	manager.set("endless", bool(data.get("endless", false)))
	player_data.set("currentBatchIndex", int(data.get("current_batch_index", 0)))
	player_data.set("playername", str(data.get("player_name", player_data.get("playername"))))
	player_data.set("hasSignedWaiver", true)
	manager.set("mobile_resume_pending", true)
	manager.set("mobile_resume_round", int(data.get("current_round", 0)))
	manager.set("mobile_resume_health_player", int(data.get("health_player", 0)))
	manager.set("mobile_resume_health_opponent", int(data.get("health_opponent", 0)))
	manager.set("mobile_resume_sequence", data.get("sequence", []).duplicate())
	manager.set("mobile_resume_known_shells", data.get("known_shells", []).duplicate())
	manager.set("playerCurrentTurnItemArray", data.get("items", []).duplicate())
	manager.set("barrelSawedOff", bool(data.get("barrel_sawed_off", false)))
	manager.set("dealerCuffed", bool(data.get("dealer_cuffed", false)))
	manager.set("playerCuffed", bool(data.get("player_cuffed", false)))
	manager.set("double_or_nothing_rounds_beat", int(data.get("double_rounds", 0)))
	manager.set("prevscore", int(data.get("score", 0)))
	manager.set("dealerAtTable", true)
	manager.set("dealerHasGreeted", true)
	return true

func save_checkpoint(manager: Node) -> void:
	if not enabled or _abandoning or not is_instance_valid(manager): return
	var rounds = manager.get("roundArray")
	if not rounds is Array or rounds.is_empty(): return
	var data = {
		"version": 1,
		"endless": bool(manager.get("endless")),
		"current_batch_index": int(manager.get("playerData").get("currentBatchIndex")),
		"current_round": int(manager.get("currentRound")),
		"health_player": int(manager.get("health_player")),
		"health_opponent": int(manager.get("health_opponent")),
		"barrel_sawed_off": bool(manager.get("barrelSawedOff")),
		"dealer_cuffed": bool(manager.get("dealerCuffed")),
		"player_cuffed": bool(manager.get("playerCuffed")),
		"player_name": str(manager.get("playerData").get("playername")),
		"sequence": manager.get("shellSpawner").get("sequenceArray").duplicate(),
		"known_shells": manager.get("dealerAI").get("sequenceArray_knownShell").duplicate(),
		"items": manager.get("playerCurrentTurnItemArray").duplicate(),
		"double_rounds": int(manager.get("double_or_nothing_rounds_beat")),
		"score": int(manager.get("prevscore"))
	}
	var file = FileAccess.open(CHECKPOINT_PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()

func save_checkpoint_from_scene():
	var scene = get_tree().current_scene
	if not is_instance_valid(scene): return
	var manager = scene.get_node_or_null("standalone managers/round manager")
	if manager: save_checkpoint(manager)

func _notification(what):
	if not enabled or not is_inside_tree():
		return
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		for control in _translation_controls:
			if is_instance_valid(control): _update_translation(control, _translation_controls[control])
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_checkpoint_from_scene()
		return
	if not OS.has_feature("ios"):
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _backgrounded: return
		_backgrounded = true
		save_checkpoint_from_scene()
		_was_paused = get_tree().paused
		_reset_touches()
		get_tree().paused = true
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if not _backgrounded: return
		_backgrounded = false
		get_tree().paused = _was_paused
		_update_safe_area()

func _update_safe_area():
	if not is_instance_valid(_pause_button): return
	_safe_bounds = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	if OS.has_feature("ios"):
		var safe_pixels = Rect2(DisplayServer.get_display_safe_area())
		var transform = get_viewport().get_screen_transform().affine_inverse()
		_safe_bounds = _safe_bounds.intersection(transform * safe_pixels)
	_pause_button.position = Vector2(_safe_bounds.end.x - 46, _safe_bounds.position.y + 8)

func _set_quality(index: int):
	quality = clampi(index, 0, 1)
	_apply_quality(get_tree().root)
	_save_settings()

func _on_node_added(node: Node):
	if node is MeshInstance3D: _readable_table.call_deferred(node)
	if node is PipelineManager: _preserve_shell_colors.call_deferred(node)
	if node is ShellSpawner: _attach_shell_replay.call_deferred(node)
	if node is ShellClass: _brighten_shell.call_deferred(node)
	if node is DealerIntelligence: _brighten_dealer.call_deferred(node)
	if node is ShellExamine: _shell_examine = node
	if node is Light3D: _apply_quality.call_deferred(node)

func _apply_quality(node: Node):
	if not is_instance_valid(node): return
	if node is Light3D:
		if not node.has_meta("mobile_original_shadow"):
			node.set_meta("mobile_original_shadow", node.shadow_enabled)
		node.shadow_enabled = quality == 1 and node.get_meta("mobile_original_shadow")
	for child in node.get_children(): _apply_quality(child)

func _load_settings():
	var settings = ConfigFile.new()
	if settings.load(SETTINGS_PATH) != OK: return
	quality = clampi(int(settings.get_value("video", "quality", 1)), 0, 1)
	fps_limit = 60 if int(settings.get_value("video", "fps", 30)) == 60 else 30

func _save_settings():
	var settings = ConfigFile.new()
	settings.set_value("video", "quality", quality)
	settings.set_value("video", "fps", fps_limit)
	var error = settings.save(SETTINGS_PATH)
	if error != OK: push_error("Mobile settings could not be saved: %s" % error)

func configure_menu(menu: Node):
	for index in [3, 9, 16, 18, 22]:
		menu.buttons[index].get_parent().hide()
		menu.buttons[index].ui.hide()
	for index in [2, 3, 4, 5]:
		menu.buttons_options[index].get_parent().hide()
		menu.buttons_options[index].ui.hide()
	menu.optionmanager.ui_windowed.hide()
	menu.optionmanager.ui_fullscreen.hide()

func begin_name_entry(signature: Node):
	_signature = signature
	_name_edit.text = ""
	_name_error.text = ""
	_name_dialog.popup_centered()
	_name_dialog.position.y = int(_safe_bounds.position.y + 64)
	_name_edit.grab_focus.call_deferred()

func _submit_name():
	if not is_instance_valid(_signature):
		_name_dialog.hide()
		return
	var name_text = _name_edit.text.strip_edges().to_lower()
	var valid = not name_text.is_empty() and name_text.length() <= 6 and name_text not in ["god", "dealer"]
	for character in name_text:
		if character < "a" or character > "z": valid = false
	if not valid:
		_name_error.text = tr("INVALID NAME")
		return
	while _signature.markerIndex > 0: _signature.Input_Backspace()
	for character in name_text: _signature.GetInput(character, "")
	_signature.GetInput("", "enter")
	_name_dialog.hide()
	_name_edit.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()

func _localize(control: Node, key: String):
	_translation_controls[control] = key
	_update_translation(control, key)

func _update_translation(control: Node, key: String):
	if control is Window:
		control.title = tr(key)
	elif control is OptionButton:
		var keys = control.get_meta("mobile_option_keys", [])
		for index in keys.size(): control.set_item_text(index, tr(keys[index]))
	else:
		control.text = tr(key)

func _register_translations():
	var words = {
		"EN": {"PAUSE": "PAUSE", "RESUME": "RESUME", "QUALITY": "QUALITY", "LOW": "LOW", "STANDARD": "STANDARD", "MAIN MENU": "MAIN MENU", "NAME": "NAME", "INVALID NAME": "Use 1-6 letters (A-Z)."},
		"ZHT": {"PAUSE": "暫停", "RESUME": "繼續", "QUALITY": "畫質", "LOW": "低", "STANDARD": "標準", "MAIN MENU": "主選單", "NAME": "姓名", "INVALID NAME": "請輸入 1-6 個英文字母。"},
		"ZHS": {"PAUSE": "暂停", "RESUME": "继续", "QUALITY": "画质", "LOW": "低", "STANDARD": "标准", "MAIN MENU": "主菜单", "NAME": "姓名", "INVALID NAME": "请输入 1-6 个英文字母。"}}
	for locale in words:
		var table = Translation.new()
		table.set_locale(locale)
		for key in words[locale]: table.add_message(key, words[locale][key])
		TranslationServer.add_translation(table)
# Object-local emission preserves the room darkness. No added light or exposure.
var _shell_spawner: ShellSpawner
var _shell_examine: ShellExamine
var _shell_panel: StaticBody3D
var _shell_batch_id := 0
var _shell_replay_available := false
var _shell_replay_busy := false
var _shell_display_sequence: Array = []
var _dealer_animator: AnimationPlayer
var _dealer_visual: Node3D
var _dealer_readable_materials: Array = []
var _dealer_hitbox: StaticBody3D
var _dealer_taps := 0
var _abandoning := false
var _abandon_stage := ""
var _abandon_echo: AudioStreamPlayer
const ABANDON_ECHO_BUS = "MobileAbandonEcho"

func _readable_table(mesh: MeshInstance3D):
	if not is_instance_valid(mesh) or mesh.mesh == null: return
	for surface in mesh.mesh.get_surface_count():
		var original = mesh.get_active_material(surface)
		if not original is StandardMaterial3D or original.albedo_texture == null: continue
		var texture_path = original.albedo_texture.resource_path.to_lower()
		if not texture_path.contains("tabletop felt") or original.has_meta("mobile_table_readability"): continue
		var material = original.duplicate() as StandardMaterial3D
		material.emission_enabled = true
		material.emission = material.albedo_color
		material.emission_texture = material.albedo_texture
		material.emission_energy_multiplier = 0.16
		material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		material.set_meta("mobile_table_readability", true)
		mesh.set_surface_override_material(surface, material)

func _brighten_mesh(mesh: MeshInstance3D, energy: float):
	if not is_instance_valid(mesh) or mesh.mesh == null: return
	for surface in mesh.mesh.get_surface_count():
		var original = mesh.get_active_material(surface)
		if not original is StandardMaterial3D or original.has_meta("mobile_local_readability"): continue
		var material = original.duplicate() as StandardMaterial3D
		material.emission_enabled = true
		material.emission = material.albedo_color
		material.emission_texture = material.albedo_texture
		material.emission_energy_multiplier = energy
		material.set_meta("mobile_local_readability", true)
		mesh.set_surface_override_material(surface, material)

func _brighten_shell(shell: ShellClass):
	if is_instance_valid(shell): _readable_shell_mesh(shell.mesh)

func _readable_shell_mesh(mesh: MeshInstance3D):
	if not is_instance_valid(mesh) or mesh.mesh == null: return
	_brighten_mesh(mesh, 0.32) # Brass keeps its original shaded appearance.
	if mesh.mesh.get_surface_count() < 2: return
	var original = mesh.get_active_material(1)
	if not original is StandardMaterial3D or original.has_meta("mobile_shell_color"): return
	var material = original.duplicate() as StandardMaterial3D
	# Only the colored casing ignores the dark room, including in the magnifier.
	# Keep original red/blue albedo; no global exposure or illumination changes.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = false
	material.albedo_color = Color(original.albedo_color.r * 0.55, original.albedo_color.g * 0.55, original.albedo_color.b * 0.55, original.albedo_color.a)
	material.set_meta("mobile_shell_color", true)
	mesh.set_surface_override_material(1, material)

func _brighten_dealer(dealer: DealerIntelligence):
	if not is_instance_valid(dealer): return
	_dealer_readable_materials.clear()
	for mesh in [dealer.dealermesh_normal, dealer.dealermesh_crushed]:
		_brighten_mesh(mesh, 0.12)
		# Both original head meshes use surface 1 for grey teeth (Material.001).
		var teeth = mesh.get_active_material(1).duplicate() as StandardMaterial3D
		teeth.emission_energy_multiplier = 0.50
		mesh.set_surface_override_material(1, teeth)
		_dealer_readable_materials.append([mesh.get_active_material(0), 0.12])
		_dealer_readable_materials.append([teeth, 0.50])
	var animator = dealer.roundManager.animator_dealer
	var visual = animator.get_parent() as Node3D
	_dealer_animator = animator
	_dealer_visual = visual
	_dealer_hitbox = StaticBody3D.new()
	_dealer_hitbox.name = "MobileDealerAbandonHitbox"
	var head = dealer.dealermesh_normal as MeshInstance3D
	var bounds = _posed_head_bounds(head)
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = bounds.size
	collision.shape = shape
	collision.position = bounds.get_center()
	_dealer_hitbox.add_child(collision)
	head.add_child(_dealer_hitbox)
	if not animator.has_meta("mobile_dealer_visibility"):
		animator.set_meta("mobile_dealer_visibility", true)
		animator.animation_started.connect(_dealer_animation_started.bind(visual))
		animator.animation_finished.connect(_dealer_animation_finished.bind(visual))
		# The original hide animation teleports the model instead of hiding it.
		var returning = animator.get_animation("dealer return to table")
		var table_position = returning.track_get_key_value(0, returning.track_get_key_count(0) - 1)
		visual.visible = visual.position.distance_to(table_position) < 0.05

func _posed_head_bounds(head: MeshInstance3D) -> AABB:
	# Imported vertices live in bind space. Apply the skin exactly as rendering
	# does so the collision covers the visible face rather than the unposed mesh.
	var skeleton = head.get_parent() as Skeleton3D
	var transforms: Array[Transform3D] = []
	for bind in head.skin.get_bind_count():
		var bone = head.skin.get_bind_bone(bind)
		if bone < 0: bone = skeleton.find_bone(head.skin.get_bind_name(bind))
		transforms.append(skeleton.get_bone_global_pose(bone) * head.skin.get_bind_pose(bind))
	var bounds = AABB()
	var initialized = false
	for surface in head.mesh.get_surface_count():
		var arrays = head.mesh.surface_get_arrays(surface)
		var vertices = arrays[Mesh.ARRAY_VERTEX]
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		var influences = weights.size() / vertices.size()
		for vertex in vertices.size():
			var point = Vector3.ZERO
			for influence in int(influences):
				var index = vertex * int(influences) + influence
				point += (transforms[bones[index]] * vertices[vertex]) * weights[index]
			point = head.transform.affine_inverse() * point
			if not initialized:
				bounds = AABB(point, Vector3.ZERO)
				initialized = true
			else: bounds = bounds.expand(point)
	return bounds

func _preserve_shell_colors(pipeline: PipelineManager):
	if not is_instance_valid(pipeline) or pipeline.scene != "main": return
	var rect = pipeline.overlay.get_node_or_null("BackBufferCopy/ColorRect")
	if rect and rect.material is ShaderMaterial:
		rect.material = rect.material.duplicate()
		rect.material.set_shader_parameter("preserve_shell_colors", true)

func _dealer_animation_started(animation: StringName, visual: Node3D):
	if not is_instance_valid(visual): return
	if animation == &"hide dealer":
		visual.visible = false
	elif animation == &"dealer return to table":
		visual.visible = true
		_set_dealer_readability(0.0)

func _dealer_animation_finished(animation: StringName, visual: Node3D):
	if is_instance_valid(visual) and animation == &"dealer return to table":
		visual.visible = true
		_set_dealer_readability(1.0)
	elif is_instance_valid(visual) and animation == &"dealer fly away":
		visual.visible = false

func _set_dealer_readability(amount: float):
	for entry in _dealer_readable_materials:
		entry[0].emission_energy_multiplier = entry[1] * amount

func _attach_shell_replay(spawner: ShellSpawner):
	if not is_instance_valid(spawner) or not spawner.spawnParent is MeshInstance3D: return
	_shell_spawner = spawner
	# Keep the original lower table edge while including the dealer for direct taps.
	var camera = spawner.roundManager.camera
	for index in camera.socketArray.size():
		if camera.socketArray[index].socketName == "home":
			var socket = camera.socketArray[index].duplicate()
			socket.rot.x = -39.0
			socket.fov = 86.0
			camera.socketArray[index] = socket
	_abandoning = false
	_abandon_stage = ""
	_dealer_taps = 0
	_pause_button.show()
	_shell_batch_id = 0
	_shell_replay_available = false
	_shell_replay_busy = false
	_shell_display_sequence = []
	_shell_panel = StaticBody3D.new()
	_shell_panel.name = "MobileShellReplayPanel"
	var bounds = (spawner.spawnParent as MeshInstance3D).get_aabb()
	var shape = BoxShape3D.new()
	shape.size = bounds.size.max(Vector3(0.15, 0.08, 0.15))
	var collision = CollisionShape3D.new()
	collision.shape = shape
	collision.position = bounds.get_center()
	_shell_panel.add_child(collision)
	spawner.spawnParent.add_child(_shell_panel)

func _process(_delta):
	if not enabled: return
	if is_instance_valid(_dealer_hitbox):
		_dealer_hitbox.collision_layer = 1 if _table_idle() else 0
	if is_instance_valid(_dealer_animator) and _dealer_animator.is_playing():
		var animation = _dealer_animator.current_animation
		if animation in ["dealer return to table", "dealer fly away"]:
			var length = _dealer_animator.current_animation_length
			var progress = clampf(_dealer_animator.current_animation_position / maxf(length, 0.001), 0, 1)
			var amount = progress if animation == "dealer return to table" else 1.0 - progress
			_set_dealer_readability(amount)
	_update_shell_batch()
	if is_instance_valid(_shell_examine) and _shell_examine.shellParent.visible:
		_readable_shell_mesh(_shell_examine.mesh)

func _update_shell_batch():
	if not is_instance_valid(_shell_spawner) or _shell_spawner.spawnedShellObjectArray.is_empty(): return
	var first = _shell_spawner.spawnedShellObjectArray[0]
	if not is_instance_valid(first): return
	var identity = first.get_instance_id()
	if identity == _shell_batch_id: return
	_shell_batch_id = identity
	_shell_display_sequence = _shell_spawner.sequenceArray.duplicate()
	_shell_replay_available = true

func _can_replay_shells() -> bool:
	if not _shell_replay_available or _shell_replay_busy or get_tree().paused: return false
	return _table_idle()

func _table_idle() -> bool:
	if _abandoning or _shell_replay_busy or get_tree().paused: return false
	if not is_instance_valid(_shell_spawner): return false
	var rm = _shell_spawner.roundManager
	if not is_instance_valid(rm) or not is_instance_valid(rm.deskUI_shotgun) or not rm.deskUI_shotgun.visible: return false
	if not rm.cursor.cursor_visible or (rm.camera.moving and rm.camera.elapsed < rm.camera.dur) or rm.camera.activeSocket != "home": return false
	for branch in rm.perm.interactionBranchArray:
		if branch.interactionAlias == "shotgun": return branch.interactionAllowed and not branch.interactionInvalid
	return false

func _click_shell_panel(position: Vector2) -> bool:
	if not is_instance_valid(_shell_panel): return false
	var cam = get_viewport().get_camera_3d()
	if not is_instance_valid(cam): return false
	var start = cam.project_ray_origin(position)
	var end = start + cam.project_ray_normal(position) * 200.0
	var hit = cam.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start, end))
	if hit.get("collider") != _shell_panel: return false
	_update_shell_batch()
	if _can_replay_shells(): _replay_shells()
	return true

func _replay_shells():
	if not _can_replay_shells(): return
	_shell_replay_available = false
	_shell_replay_busy = true
	var spawner = _shell_spawner
	var rm = spawner.roundManager
	var batch = _shell_batch_id
	rm.perm.SetIndicators(false)
	rm.perm.SetInteractionPermissions(false)
	rm.cursor.SetCursor(false, false)
	rm.ClearDeskUI(true)
	rm.camera.BeginLerp("shell compartment")
	await get_tree().create_timer(0.5, false).timeout
	if not is_instance_valid(spawner): return
	spawner.anim_compartment.play("show shells")
	spawner.PlayLatchSound()
	# Only redisplay the original batch: do not spawn, load, shuffle or reveal the chamber.
	spawner.seq = _shell_display_sequence.duplicate()
	spawner.PlayAudioIndicators()
	var lives = _shell_display_sequence.count("live")
	var blanks = _shell_display_sequence.count("blank")
	var live_text = tr("LIVEROUND") if lives == 1 else tr("LIVEROUNDS")
	var blank_text = tr("BLANKROUND") if blanks == 1 else tr("BLANKROUNDS")
	spawner.dialogue.ShowText_Forever((live_text % str(lives)) + " " + (blank_text % str(blanks)))
	await get_tree().create_timer(2.5, false).timeout
	if not is_instance_valid(spawner): return
	spawner.dialogue.HideText()
	spawner.anim_compartment.play("hide shells")
	spawner.PlayLatchSound()
	await get_tree().create_timer(0.5, false).timeout
	if not is_instance_valid(spawner): return
	rm.camera.BeginLerp("home")
	await get_tree().create_timer(0.6, false).timeout
	if not is_instance_valid(spawner) or batch != _shell_batch_id: return
	rm.perm.SetStackInvalidIndicators()
	rm.cursor.SetCursor(true, true)
	rm.perm.SetIndicators(true)
	rm.perm.SetInteractionPermissions(true)
	rm.SetupDeskUI()
	_shell_replay_busy = false

func _click_dealer_abandon(position: Vector2) -> bool:
	if not is_instance_valid(_dealer_hitbox) or not is_instance_valid(_dealer_visual) or not _dealer_visual.visible: return false
	if not _table_idle(): return false
	var cam = get_viewport().get_camera_3d()
	if not is_instance_valid(cam): return false
	var start = cam.project_ray_origin(position)
	var hit = cam.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start, start + cam.project_ray_normal(position) * 200.0))
	if hit.get("collider") != _dealer_hitbox: return false
	_dealer_taps += 1
	if _dealer_taps == 5: _abandon_run()
	return true

func _start_abandon_echo(source: AudioStreamPlayer2D):
	AudioServer.add_bus()
	var bus = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, ABANDON_ECHO_BUS)
	AudioServer.set_bus_send(bus, source.bus)
	var reverb = AudioEffectReverb.new()
	reverb.room_size = 0.95
	reverb.damping = 0.20
	reverb.spread = 1.0
	reverb.predelay_msec = 65.0
	reverb.predelay_feedback = 0.25
	reverb.dry = 0.80
	reverb.wet = 0.65
	AudioServer.add_bus_effect(bus, reverb)
	_abandon_echo = AudioStreamPlayer.new()
	_abandon_echo.stream = source.stream
	_abandon_echo.volume_db = source.volume_db
	_abandon_echo.bus = ABANDON_ECHO_BUS
	add_child(_abandon_echo)
	_abandon_echo.play()

func _stop_abandon_echo():
	if is_instance_valid(_abandon_echo):
		_abandon_echo.stop()
		_abandon_echo.queue_free()
	var bus = AudioServer.get_bus_index(ABANDON_ECHO_BUS)
	if bus >= 0: AudioServer.remove_bus(bus)

func _reset_run_data(manager: Node):
	var fresh = PlayerData.new()
	for property in fresh.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			manager.playerData.set(property.name, fresh.get(property.name))

func _abandon_run():
	if not _table_idle(): return
	_abandoning = true
	_abandon_stage = "grabbing"
	clear_checkpoint()
	_reset_touches()
	_pause_button.hide()
	var rm = _shell_spawner.roundManager
	var dealer = rm.dealerAI
	rm.death.savefile.ClearSave()
	rm.perm.SetIndicators(false)
	rm.perm.SetInteractionPermissions(false)
	rm.cursor.SetCursor(false, false)
	rm.ClearDeskUI(true)
	rm.musicManager.EndTrack()
	rm.camera.BeginLerp("enemy")
	await get_tree().create_timer(0.8, false).timeout
	if not is_instance_valid(rm): return
	await dealer.GrabShotgun()
	if not is_instance_valid(rm): return
	_abandon_stage = "aiming"
	dealer.animator_shotgun.play("enemy shoot player")
	await get_tree().create_timer(2.0, false).timeout
	if not is_instance_valid(rm): return
	_abandon_stage = "echo"
	var gun = dealer.shotgunShooting
	gun.animator_muzzleFlash.play("muzzle flash fire")
	gun.animator_muzzleFlash_model.play("fire")
	dealer.smoke.SpawnSmoke("barrel")
	dealer.cameraShaker.Shake()
	_start_abandon_echo(gun.speaker_live)
	rm.death.viewblocker.visible = true
	await get_tree().create_timer(3.0, false).timeout
	_stop_abandon_echo()
	if not is_instance_valid(rm): return
	# Clear both save routes and the shared resource before returning to the bathroom.
	# No normal damage/death routine: it would continue the run or enter heaven.
	clear_checkpoint()
	rm.death.savefile.ClearSave()
	_reset_run_data(rm)
	_abandon_stage = "bathroom"
	get_tree().change_scene_to_file("res://scenes/main.tscn")
