extends SceneTree
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("UX PASS: ", message)
func _initialize() -> void:
	call_deferred("run")
func settle(app: Control) -> void:
	while app.simulation_busy:
		await process_frame
func run() -> void:
	root.size = Vector2i(1280, 900)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	app.acknowledge_educational_use()
	await process_frame
	await settle(app)
	check(app.plan["tanks"].is_empty() and app.plan["waypoints"].is_empty(), "startup has no route or gases")
	check(BathysPlan.validate(app.plan, false).is_empty(), "empty draft can be saved and exported")
	check(app.visible_metrics == ["depthM"], "only depth is shown initially")
	for index: int in range(1, 10):
		app.toggle_metric(index)
	check(app.visible_metrics.size() == 10, "all ten readouts can be added")
	app.toggle_metric(3)
	check(not app.metric_cards["ndlS"].visible and app.visible_metrics.size() == 9, "readout can be removed")
	app.on_poi_clicked(app.site.pois[1])
	check(app.plan["waypoints"].is_empty(), "inspection does not mutate route")
	var initial_location: Dictionary = app.inspection_location.duplicate()
	app.on_poi_clicked(app.site.pois[2])
	check(not app.inspection_overlay.visible and app.inspection_location == initial_location, "outside map click dismisses without inspecting a new point")
	app.on_poi_clicked(app.site.pois[1])
	check(app.inspection.get_child(0).get_child_count() == 4, "location card contains only name, depth, coordinates and Add waypoint")
	await process_frame
	var outside: Vector2 = app.map.get_global_rect().position + Vector2(20, 20)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = outside
		click.global_position = outside
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click, true)
	await process_frame
	check(not app.inspection_overlay.visible and app.inspection_location == initial_location, "full outside click is consumed before map input")
	app.on_poi_clicked(app.site.pois[1])
	app.add_inspected_waypoint()
	await settle(app)
	check(app.plan["waypoints"].size() == 1 and app.feedback_label.visible, "adding a waypoint without gas gives visible guidance")
	app.add_tank()
	await settle(app)
	check(not app.frames.is_empty(), "first explicitly added tank enables simulation")
	var frame: Dictionary = app.current_frame()
	check(app.metric_cards.size() == 17, "seven additional details are available as individual cards")
	check(app.metric_values["tankId"].text == app.tank_name(str(frame["tankId"])), "active gas card displays its name")
	check(app.metric_values["currentGf"].text == "%.0f" % (float(frame["currentGf"]) * 100), "applied GF card displays percentage")
	check(app.route_list.get_node("Insertion_0").size.y <= 18, "insertion gap stays compact")
	app.insert_event(0, false)
	await settle(app)
	check(app.plan["waypoints"][0]["kind"] == "hold" and app.plan["waypoints"][0]["targetDepthM"] == 0, "hold inserts before first waypoint at entrance")
	app.insert_event(2, false)
	await settle(app)
	check(is_equal_approx(app.plan["waypoints"][2]["targetDepthM"], 22.3), "hold inserts after waypoint at preceding depth")
	app.add_tank()
	await settle(app)
	app.insert_event(2, true)
	await settle(app)
	check(app.plan["waypoints"][2]["kind"] == "switch" and app.plan["waypoints"][2]["tankId"] != app.plan["initialTankId"], "switch inserts at chosen boundary with alternate gas")
	app.undo()
	await settle(app)
	check(app.plan["waypoints"][2]["kind"] == "hold", "undo restores inserted event")
	app.plan["tanks"][0]["startGaugeBar"] = 51
	app.request_simulation()
	await settle(app)
	check(app.feedback_label.visible and app.selected_event >= 0, "failed simulation identifies affected route event")
	root.size = Vector2i(390, 844)
	app.adapt_layout()
	await process_frame
	check(app.content_box.vertical and app.content_box.get_child(0) == app.center_panel, "narrow layout puts map first and stacks panels")
	app.new_plan()
	await settle(app)
	check(app.plan["tanks"].is_empty() and app.frames.is_empty(), "new scenario resets to empty draft")
	print("UX_WORKFLOW failures=", failures)
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
