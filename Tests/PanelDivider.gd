extends SceneTree
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if ok:
		print("DIVIDER PASS: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func layout() -> void:
	await process_frame
	await process_frame
func drag_handle(handle: Control, destination: Vector2) -> void:
	var start: Vector2 = handle.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = start
	press.global_position = start
	press.pressed = true
	root.push_input(press, true)
	var motion := InputEventMouseMotion.new()
	motion.position = destination
	motion.global_position = destination
	motion.relative = destination - start
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	await layout()
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = destination
	release.global_position = destination
	release.pressed = false
	root.push_input(release, true)
	await layout()
func run() -> void:
	root.size = Vector2i(1280, 900)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	app.acknowledge_educational_use()
	await layout()
	var bounds: Rect2 = app.content_box.get_global_rect()
	var y: float = app.left_divider.get_global_rect().get_center().y
	var original: float = app.left_panel.size.x
	await drag_handle(app.left_divider, Vector2(bounds.position.x + 400, y))
	check(app.left_panel.size.x > original + 50, "dragging left divider resizes tanks")
	await drag_handle(app.left_divider, Vector2(bounds.position.x + 1, y))
	check(not app.left_panel.visible and app.left_divider.is_visible_in_tree(), "dragging tanks to left edge collapses them and retains handle")
	await drag_handle(app.left_divider, Vector2(bounds.position.x + 350, y))
	check(app.left_panel.visible and app.left_panel.size.x >= 350, "dragging from collapsed left edge restores tanks")
	await drag_handle(app.right_divider, Vector2(bounds.end.x - 1, y))
	check(not app.right_panel.visible and app.right_divider.is_visible_in_tree(), "dragging route divider to right edge collapses it")
	await drag_handle(app.right_divider, Vector2(bounds.end.x - 430, y))
	check(app.right_panel.visible and app.right_panel.size.x >= 430, "dragging from collapsed right edge restores route panel")
	check(app.left_divider.mouse_default_cursor_shape == Control.CURSOR_HSIZE and app.right_divider.mouse_default_cursor_shape == Control.CURSOR_HSIZE, "both dividers show horizontal resize cursor")
	check(not app.left_divider.active and not app.right_divider.active, "release ends drag even after collapse")
	var bar: Control = app.view_buttons["3D"].get_parent()
	var buttons: int = 0
	for child: Node in bar.get_children():
		if child is Button:
			buttons += 1
	check(buttons == 4 and app.view_buttons["3D"].position.x == 0, "map toolbar contains only its original four controls")
	root.size = Vector2i(390, 844)
	app.adapt_layout()
	await layout()
	check(app.left_divider.horizontal and app.right_divider.horizontal, "stacked panels use vertical resize cursors")
	app.left_divider.toggle_requested.emit()
	await layout()
	check(not app.left_panel.visible and app.left_divider.is_visible_in_tree(), "stacked layout keeps collapsed handle accessible")
	print("DIVIDER_CHECKS failures=", failures)
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
