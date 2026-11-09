extends SceneTree
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if ok:
		print("PANEL PASS: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func settle(app: Control) -> void:
	while app.simulation_busy:
		await process_frame
	await process_frame
	await process_frame
func run() -> void:
	root.size = Vector2i(1280, 900)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	await settle(app)
	var original_width: float = app.view_container.size.x
	app.toggle_side_panel(true)
	await process_frame
	await process_frame
	check(not app.left_panel.visible and app.view_container.size.x > original_width, "collapsing tanks expands the map")
	var left_hidden_width: float = app.view_container.size.x
	app.toggle_side_panel(false)
	await process_frame
	await process_frame
	check(not app.right_panel.visible and app.view_container.size.x > left_hidden_width, "collapsing both panels gives map full width")
	check(app.left_divider.is_visible_in_tree() and app.right_divider.is_visible_in_tree(), "edge resize handles remain accessible")
	app.toggle_side_panel(true)
	app.toggle_side_panel(false)
	await process_frame
	await process_frame
	check(app.left_panel.visible and app.right_panel.visible and is_equal_approx(app.view_container.size.x, original_width), "expanding panels restores original layout")
	app.on_poi_clicked(app.site.pois[1])
	app.add_inspected_waypoint()
	await settle(app)
	var existing: Dictionary = app.plan["waypoints"][0].duplicate(true)
	var defaults := {"sacLPerMin": 22.5, "speedMPerMin": 9.5}
	check(app.apply_limits(BathysPlan.default_limits(), false, defaults), "new route defaults apply atomically with settings")
	await settle(app)
	check(app.plan["waypoints"][0] == existing, "changing defaults preserves existing events")
	app.on_poi_clicked(app.site.pois[2])
	app.add_inspected_waypoint()
	await settle(app)
	check(app.plan["waypoints"][1]["sacLPerMin"] == 22.5 and app.plan["waypoints"][1]["speedMPerMin"] == 9.5, "new waypoint inherits SAC and swim speed")
	app.insert_event(1, false)
	await settle(app)
	check(app.plan["waypoints"][1]["kind"] == "hold" and app.plan["waypoints"][1]["sacLPerMin"] == 22.5, "inserted hold inherits default SAC")
	var restored: Dictionary = BathysPlan.from_json(JSON.stringify(app.plan), app.site)
	check(BathysPlan.route_defaults_for(restored) == defaults, "route defaults survive plan-file round trip")
	check(not app.apply_limits(BathysPlan.default_limits(), false, {"sacLPerMin": 0, "speedMPerMin": 9}), "invalid route defaults are rejected")
	check(app.metric_cards["depthM"].size.y <= 65, "ordinary metric card is at most 65 pixels tall")
	app.toggle_metric(7)
	await process_frame
	await process_frame
	check(app.metric_cards["ppO2Bar"].size.y <= 95, "gas guidance card stays compact")
	app.open_settings()
	await process_frame
	check(app.settings_route_inputs.size() == 2, "settings includes both route defaults")
	app.settings_dialog.hide()
	root.size = Vector2i(390, 844)
	app.adapt_layout()
	await process_frame
	var expanded_height: float = app.content_box.custom_minimum_size.y
	app.toggle_side_panel(true)
	app.toggle_side_panel(false)
	await process_frame
	check(app.content_box.custom_minimum_size.y < expanded_height and app.left_divider.is_visible_in_tree() and app.right_divider.is_visible_in_tree(), "narrow layout releases collapsed panel space and retains toggles")
	print("PANEL_WORKFLOW failures=", failures)
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
