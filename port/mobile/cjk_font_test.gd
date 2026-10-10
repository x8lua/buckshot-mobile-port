extends SceneTree

var failures = []
func _initialize(): run.call_deferred()
func check(value, label):
	print("CHECK ", label, " ", "PASS" if value else "FAIL")
	if not value: failures.append(label)
func run():
	await process_frame
	var mobile = root.get_node("MobileRuntime")
	check(mobile.CJK_FONT != null, "Traditional Chinese font loads")
	var label = Label.new()
	label.text = "暫停／繼續／畫質"
	mobile.add_child(label)
	mobile._localize(label, "PAUSE")
	await process_frame
	check(label.has_theme_font_override("font"), "runtime Chinese controls use CJK fallback")
	check(label.text != "", "Chinese text remains UTF-8 characters")
	label.queue_free()
	print("CJK_FONT_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
