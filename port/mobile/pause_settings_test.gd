extends SceneTree
var failed = false
func _initialize():
    run.call_deferred()
func check(value, label):
    print("CHECK ", label, " ", "PASS" if value else "FAIL")
    failed = failed or not value
func tap(point):
    for pressed in [true, false]:
        var event = InputEventScreenTouch.new()
        event.position = point
        event.index = 0
        event.pressed = pressed
        root.push_input(event, true)
        await process_frame
func run():
    await process_frame
    root.size = Vector2i(1920,1080)
    root.content_scale_size = Vector2i(960,540)
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
    change_scene_to_file("res://scenes/menu.tscn")
    await create_timer(2).timeout
    var mobile = root.get_node("MobileRuntime")
    var menu = current_scene.get_node("standalone managers/menu manager")
    menu.SkipIntro()
    await create_timer(1).timeout
    await tap(mobile._pause_button.get_global_rect().get_center())
    check(paused,"pause via touch")
    var column = mobile._resume_button.get_parent()
    var settings = []
    for control in column.get_children():
        if control is OptionButton or control is HBoxContainer: settings.append(control)
    for setting in settings:
        if setting is OptionButton:
            await tap(setting.get_global_rect().get_center())
            check(not setting.get_popup().visible, "settings cannot trap input in popup")
            setting.get_popup().hide()
        else:
            for button in setting.get_children():
                await tap(button.get_global_rect().get_center())
                check(button.button_pressed, "touch selects " + button.text)
                check(paused, "settings keep gameplay paused")
                if setting == settings[0]:
                    check(mobile.quality == button.get_index(), "quality callback updates runtime")
                else:
                    check(mobile.fps_limit == (30 if button.get_index() == 0 else 60), "FPS callback updates runtime")
                    check(Engine.max_fps == mobile.fps_limit, "engine FPS limit applied")
    await tap(mobile._resume_button.get_global_rect().get_center())
    check(not paused,"resume after changing settings")
    if paused: mobile._toggle_pause()
    await tap(menu.buttons[1].get_parent().get_global_rect().get_center())
    check(menu.currentScreen == "sub options","game menu works after settings")
    menu.ReturnToLastScreen()
    await tap(mobile._pause_button.get_global_rect().get_center())
    await tap(column.get_child(column.get_child_count()-1).get_global_rect().get_center())
    await process_frame
    check(not paused,"main menu clears pause")
    check(current_scene.scene_file_path == "res://scenes/menu.tscn","main menu route remains usable")
    print("PAUSE_SETTINGS_RESULT ","FAIL" if failed else "PASS")
    quit(1 if failed else 0)
