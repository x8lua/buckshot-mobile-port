extends CanvasLayer

var enabled = OS.has_feature("ios") or OS.get_cmdline_user_args().has("--mobile-preview")
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
const SETTINGS_PATH = "user://buckshot_mobile.cfg"
const TAP_SLOP = 18.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	if not enabled:
		return
	Input.emulate_mouse_from_touch = false
	Input.emulate_touch_from_mouse = false
	_load_settings()
	_build_controls()
	get_tree().node_added.connect(_on_node_added)
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()
	Engine.max_fps = fps_limit

func _input(event):
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
	_pause_button.size = Vector2(48, 48)
	_pause_button.add_theme_font_size_override("font_size", 24)
	_pause_button.pressed.connect(_toggle_pause)
	add_child(_pause_button)
	_pause_root = Control.new()
	_pause_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_root.mouse_filter = Control.MOUSE_FILTER_STOP
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
	heading.text = tr("PAUSE")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 26)
	column.add_child(heading)
	_resume_button = _command(column, tr("RESUME"), _toggle_pause)
	var quality_label = Label.new()
	quality_label.text = tr("QUALITY")
	column.add_child(quality_label)
	var quality_selector = OptionButton.new()
	quality_selector.add_item(tr("LOW"))
	quality_selector.add_item(tr("STANDARD"))
	quality_selector.selected = quality
	quality_selector.custom_minimum_size.y = 48
	quality_selector.item_selected.connect(_set_quality)
	column.add_child(quality_selector)
	var fps_label = Label.new()
	fps_label.text = "FPS"
	column.add_child(fps_label)
	var fps_selector = OptionButton.new()
	fps_selector.add_item("30")
	fps_selector.add_item("60")
	fps_selector.selected = 0 if fps_limit == 30 else 1
	fps_selector.custom_minimum_size.y = 48
	fps_selector.item_selected.connect(func(index):
		fps_limit = 30 if index == 0 else 60
		Engine.max_fps = fps_limit
		_save_settings())
	column.add_child(fps_selector)
	_command(column, tr("MAIN MENU"), _return_to_menu)
	_name_dialog = ConfirmationDialog.new()
	_name_dialog.title = tr("NAME")
	_name_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	_name_dialog.dialog_hide_on_ok = false
	_name_dialog.size = Vector2i(360, 160)
	_name_dialog.confirmed.connect(_submit_name)
	_name_dialog.canceled.connect(func():
		if _name_edit.has_focus(): _name_edit.release_focus()
		DisplayServer.virtual_keyboard_hide())
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
	button.text = label
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _toggle_pause():
	_reset_touches()
	var paused = not get_tree().paused
	get_tree().paused = paused
	_pause_root.visible = paused
	_pause_button.visible = not paused
	if paused: _resume_button.grab_focus()

func _return_to_menu():
	_reset_touches()
	get_tree().paused = false
	_pause_root.hide()
	_pause_button.show()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _notification(what):
	if not enabled or not is_inside_tree():
		return
	if not OS.has_feature("ios"):
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _backgrounded: return
		_backgrounded = true
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
	_pause_button.position = Vector2(_safe_bounds.end.x - 60, _safe_bounds.position.y + 12)

func _set_quality(index: int):
	quality = clampi(index, 0, 1)
	_apply_quality(get_tree().root)
	_save_settings()

func _on_node_added(node: Node):
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
	DisplayServer.virtual_keyboard_hide()
