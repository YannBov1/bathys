extends SceneTree
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if ok:
		print("DRAG PASS: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func layout() -> void:
	await process_frame
	await process_frame
func settle(app: Control) -> void:
	while app.simulation_busy:
		await process_frame
	await layout()
func begin_drag(surface: Control, from: Vector2 = Vector2.INF) -> void:
	var start: Vector2 = surface.get_global_rect().get_center() if from == Vector2.INF else from
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = start
	press.global_position = start
	press.pressed = true
	Input.parse_input_event(press)
	await layout()
	var motion := InputEventMouseMotion.new()
	motion.position = start + Vector2(0, 18)
	motion.global_position = motion.position
	motion.relative = Vector2(0, 18)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	await layout()
func move_drag(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.relative = at - root.get_mouse_position()
	motion.position = at
	motion.global_position = at
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	await layout()
func release_drag(at: Vector2) -> void:
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = at
	release.global_position = at
	release.pressed = false
	Input.parse_input_event(release)
	await layout()
func ids(app: Control) -> Array:
	return app.plan["waypoints"].map(func(item: Dictionary) -> String: return str(item["id"]))
func run() -> void:
	root.size = Vector2i(1280, 1400)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	await settle(app)
	var example: Dictionary = BathysPlan.example(app.site)
	var last: Dictionary = BathysPlan.waypoint_at_poi(app.site.pois[2])
	last["targetDepthM"] = 18.0
	example["waypoints"] = [example["waypoints"][0], BathysPlan.hold("Hold", 30), BathysPlan.gas_switch("stage", "Switch"), last]
	app.plan = example
	BathysPlan.anchor_holds(app.plan, app.site)
	app.refresh_all()
	app.request_simulation()
	await settle(app)
	var original: Array = ids(app)
	var history_size: int = app.undo_stack.size()
	var surface: Control = app.route_list.get_node("Route_0")
	await begin_drag(surface)
	check(root.gui_is_dragging() and app.route_drag_id == original[0], "drag starts from the non-editable card body")
	var destination: Vector2 = app.route_drop_slots[-1].get_global_rect().get_center()
	await move_drag(destination)
	check(app.route_drop_slots[-1].highlighted, "drop indicator marks end boundary")
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Screenshots/route-drag-preview.png")
	await release_drag(destination)
	await settle(app)
	check(ids(app) == [original[1], original[2], original[3], original[0]], "dropping at end moves one event without swapping intervening events")
	check(app.undo_stack.size() == history_size + 1 and app.route_drag_id.is_empty(), "one drop creates one undo step and ends drag")
	check(app.plan["waypoints"][0]["targetDepthM"] == 0.0, "moved hold is anchored to its new preceding position")
	app.undo()
	await settle(app)
	check(ids(app) == original, "undo restores complete event order")
	surface = app.route_list.get_node("Route_3")
	await begin_drag(surface)
	destination = app.route_drop_slots[0].get_global_rect().get_center()
	await move_drag(destination)
	await release_drag(destination)
	await settle(app)
	check(ids(app) == [original[3], original[0], original[1], original[2]], "drag can move upward to the first boundary")
	var before: Array = ids(app)
	history_size = app.undo_stack.size()
	surface = app.route_list.get_node("Route_0")
	await begin_drag(surface)
	destination = app.map.get_global_rect().get_center()
	await move_drag(destination)
	await release_drag(destination)
	await settle(app)
	check(ids(app) == before and app.undo_stack.size() == history_size and app.route_drag_id.is_empty(), "dropping outside route cancels without changing plan or history")
	surface = app.route_list.get_node("Route_0")
	await begin_drag(surface)
	destination = app.route_drop_slots[1].get_global_rect().get_center()
	await move_drag(destination)
	await release_drag(destination)
	await settle(app)
	check(ids(app) == before and app.undo_stack.size() == history_size, "dropping next to itself is a no-op")
	check(not app.valid_route_drag({"type": "bathys_route_event", "owner": 0, "id": original[0]}), "foreign drag payloads are ignored")
	app.expanded_routes[original[0]] = true
	app.refresh_route()
	await layout()
	surface = app.route_list.get_node("Route_3")
	await begin_drag(surface)
	var target_field: Control = app.route_list.get_node("Route_0").find_child("name", true, false)
	destination = target_field.get_global_rect().get_center()
	await move_drag(destination)
	await release_drag(destination)
	await settle(app)
	check(ids(app)[0] == original[2], "drop over a name field inserts the gas switch before that card")
	var expanded_card: Control = app.route_list.get_node("Route_" + str(app.route_index_by_id(original[0])))
	check(expanded_card.find_child("InlineEditor", true, false).visible, "expanded editors stay open by event ID after a move")
	before = ids(app)
	history_size = app.undo_stack.size()
	surface = app.route_list.get_node("Route_0")
	await begin_drag(surface)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await layout()
	check(not root.gui_is_dragging() and app.route_drag_id.is_empty() and ids(app) == before and app.undo_stack.size() == history_size, "Escape cancels without modifying the route")
	surface = app.route_list.get_node("Route_0")
	surface.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_DOWN
	key.alt_pressed = true
	key.pressed = true
	Input.parse_input_event(key)
	await settle(app)
	check(ids(app)[1] == before[0], "focused card supports Alt+Down without arrow buttons")
	key = InputEventKey.new()
	key.keycode = KEY_UP
	key.alt_pressed = true
	key.pressed = true
	Input.parse_input_event(key)
	await settle(app)
	check(ids(app) == before, "keyboard move keeps focus for a subsequent move")
	for index: int in 18:
		app.plan["waypoints"].append(BathysPlan.hold("Extra", 5))
	BathysPlan.anchor_holds(app.plan, app.site)
	app.refresh_route()
	await layout()
	var scroll: ScrollContainer = app.route_list.get_parent()
	scroll.scroll_vertical = 0
	await layout()
	surface = app.route_list.get_node("Route_0")
	await begin_drag(surface)
	destination = scroll.get_global_rect().end - Vector2(30, 6)
	await move_drag(destination)
	for index: int in 30:
		await process_frame
	check(scroll.scroll_vertical > 0, "long routes scroll automatically near the edge")
	await move_drag(app.map.get_global_rect().get_center())
	await release_drag(app.map.get_global_rect().get_center())
	print("DRAG_CHECKS failures=", failures)
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
