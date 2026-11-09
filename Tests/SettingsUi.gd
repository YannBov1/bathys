extends SceneTree
var failures: int = 0
func check(ok: bool, title: String) -> void:
	if ok:
		print("SETTINGS PASS: ", title)
	else:
		failures += 1
		push_error(title)
func _initialize() -> void:
	call_deferred("run")
func settle(app: Control) -> void:
	while app.simulation_busy:
		await process_frame
	await process_frame
func stable_map(app: Control, rectangle: Rect2, title: String) -> void:
	var stable: bool = true
	while app.simulation_busy:
		await process_frame
		stable = stable and app.view_container.get_global_rect().is_equal_approx(rectangle)
	await process_frame
	check(stable and app.view_container.get_global_rect().is_equal_approx(rectangle), title)
func run() -> void:
	root.size = Vector2i(1280, 1000)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await settle(app)
	app.on_poi_clicked(app.site.pois[1])
	app.add_inspected_waypoint()
	app.add_tank()
	await settle(app)
	var slot: CenterContainer = app.route_list.get_node("Insertion_0")
	check(slot.get_child(0).modulate.a == 1.0, "insertion + is visible without hover")
	var rectangle: Rect2 = app.view_container.get_global_rect()
	var pan: Vector2 = Vector2(10, -15)
	app.map.pan = pan
	app.map.magnification = 1.5
	app.on_poi_clicked(app.site.pois[2])
	app.add_inspected_waypoint()
	await stable_map(app, rectangle, "adding waypoint preserves map bounds throughout calculation")
	app.add_tank()
	await stable_map(app, rectangle, "adding tank preserves map bounds throughout calculation")
	check(app.map.pan == pan and app.map.magnification == 1.5, "map zoom and pan remain unchanged")
	app.open_settings()
	check(app.settings_inputs.size() == 6, "settings exposes oxygen, density and END limits")
	check(app.settings_inputs["ppO2Min"].has_method("apply"), "settings fields can commit typed values")
	app.settings_dialog.hide()
	var limits: Dictionary = BathysPlan.default_limits()
	limits["densityMax"] = 7.0
	limits["endMax"] = 25.0
	limits["ppO2WorkingMax"] = 1.3
	check(app.apply_limits(limits, false), "valid settings apply atomically")
	await settle(app)
	check(app.range_gauges["ppO2Bar"].working_max == 1.3 and app.range_gauges["densityGPerL"].rest_max == 7.0 and app.range_gauges["endM"].working_max == 25, "gauges follow configured limits")
	var restored: Dictionary = BathysPlan.from_json(JSON.stringify(app.plan), app.site)
	check(restored["limits"] == limits, "limits survive plan file round trip")
	limits["ppO2Min"] = 1.5
	check(not app.apply_limits(limits, false), "contradictory oxygen limits are rejected")
	limits = BathysPlan.default_limits()
	limits["ppO2Min"] = 0.3
	app.apply_limits(limits, false)
	await settle(app)
	check(app.frames.is_empty() and app.feedback_label.text.contains("0.30"), "simulation enforces configured oxygen range")
	check(app.find_child("LoadAction", true, false) != null and app.find_child("SaveAction", true, false) != null and app.find_child("ExportAction", true, false) != null, "header has three named file actions")
	print("SETTINGS_CHECKS failures=", failures)
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
