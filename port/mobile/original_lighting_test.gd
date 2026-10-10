extends SceneTree
var failures = []
func _initialize():
    run.call_deferred()
func check(value, label):
    print("CHECK ", label, " ", "PASS" if value else "FAIL")
    if not value: failures.append(label)
func run():
    await process_frame
    change_scene_to_file("res://scenes/menu.tscn")
    await create_timer(2).timeout
    var mobile = root.get_node("MobileRuntime")
    check(mobile.enabled, "mobile preview enabled")
    check(root.get_node_or_null("MobileFillLight") == null, "no added global fill light")
    var source = FileAccess.get_file_as_string("res://mobile/MobileRuntime.gd")
    check(not source.contains("adjustment_brightness =") and not source.contains("adjustment_contrast ="), "no mobile brightness or contrast override")
    check(not source.contains("DirectionalLight3D.new()"), "mobile does not add scene lighting")
    print("ORIGINAL_LIGHTING_RESULT ", "PASS" if failures.is_empty() else "FAIL")
    quit(0 if failures.is_empty() else 1)
