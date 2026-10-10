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
    root.size = Vector2i(1920, 1080)
    root.content_scale_size = Vector2i(960, 540)
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
    change_scene_to_file("res://scenes/menu.tscn")
    await create_timer(2).timeout
    var mobile = root.get_node("MobileRuntime")
    var menu = current_scene.get_node("standalone managers/menu manager")
    menu.SkipIntro()
    await create_timer(1).timeout
    print("TRANSFORM ", root.get_screen_transform())
    await tap(menu.buttons[1].get_parent().get_global_rect().get_center())
    check(menu.currentScreen == "sub options", "scaled viewport options tap")
    menu.ReturnToLastScreen()
    await tap(mobile._pause_button.get_global_rect().get_center())
    check(paused, "pause via touch")
    await tap(mobile._resume_button.get_global_rect().get_center())
    check(not paused, "resume via touch")
    if paused: mobile._toggle_pause()
    await tap(menu.buttons[1].get_parent().get_global_rect().get_center())
    check(menu.currentScreen == "sub options", "options after resume")
    print("TOUCH_RESULT ", "FAIL" if failed else "PASS")
    quit(1 if failed else 0)
