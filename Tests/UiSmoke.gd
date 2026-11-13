extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
	else:
		print("UI PASS: ", message)

func _initialize() -> void:
	call_deferred("run")

func wait_for_simulation(app: Control) -> void:
	while app.simulation_busy:
		await process_frame

func run() -> void:
	var app: Control = load("res://Main.tscn").instantiate() as Control
	root.add_child(app)
	app.acknowledge_educational_use()
	app.plan = BathysPlan.example(app.site)
	app.refresh_all()
	app.request_simulation()
	await process_frame
	await process_frame
	await wait_for_simulation(app)
	check(app.frames.size() > 1000, "simulation initializes in the complete interface")
	check(app.metric_values.size() == 17, "all seventeen physiology readouts remain available")
	check(app.graphs.size() == 5, "five synchronized plots are available")
	check(not app.has_method("add_poi") and not app.has_method("edit_poi"), "POI mutation is removed")
	var count: int = (app.plan["waypoints"] as Array).size()
	app.add_hold()
	await process_frame
	check((app.plan["waypoints"] as Array).size() == count + 1, "hold action updates route")
	app.undo()
	await process_frame
	await wait_for_simulation(app)
	check((app.plan["waypoints"] as Array).size() == count, "undo restores route")
	app.seek(300.5)
	for chart: BathysMetricGraph in app.graphs:
		check(is_equal_approx(chart.current_time, 300.5), "plot cursor follows scrub: " + chart.metric)
		check(chart.frames.size() == app.frames.size(), "plot receives simulated frames: " + chart.metric)
	var tts: BathysMetricGraph = app.graphs[1]
	check(is_equal_approx(float(tts.value_at({"ttsS": 120.0})), 2.0), "TTS graph converts seconds to minutes")
	var ndl: BathysMetricGraph = app.graphs[2]
	check(ndl.value_at({"depthM": 0.0, "ndlS": 900.0}) == null, "NDL is unavailable at surface")
	check(is_equal_approx(float(ndl.value_at({"depthM": 10.0, "ndlS": null})), 99.0), "unbounded NDL follows reference chart convention")
	app.show_3d()
	app.set_bathymetry(true)
	check(app.map.visible and not app.lake.visible, "2D switching hides the 3D scene")
	app.show_3d()
	check(app.lake.visible and not app.map.visible, "3D switching restores terrain")
	check(not app.has_method("edit_fields"), "dialog editor path is removed")
	var route_input: SpinBox = app.route_list.find_child("sacLPerMin", true, false) as SpinBox
	var tank_input: SpinBox = app.tank_list.find_child("startGaugeBar", true, false) as SpinBox
	check(route_input != null and tank_input != null, "route and tank inline inputs exist")
	var original_sac: float = route_input.value
	route_input.value = original_sac + 0.5
	check(is_equal_approx(float((app.plan["waypoints"] as Array)[0]["sacLPerMin"]), original_sac + 0.5), "inline route input updates plan")
	app.apply_inline_changes()
	check(is_instance_valid(route_input), "simulation preserves route input instance")
	check(is_instance_valid(tank_input), "simulation preserves tank input instance")
	tank_input.value = 320
	check(is_equal_approx(float((app.tank_readouts[0]["dial"] as BathysSpgDial).maximum_bar), 350), "inline pressure updates dial scale")
	app.apply_inline_changes()
	app.seek(700.0)
	check(is_instance_valid(tank_input), "playback preserves tank editor instance")
	var salinity: SpinBox = app.site_list.find_child("salinityGPerKg", true, false) as SpinBox
	salinity.value = 5
	check(is_equal_approx(float((app.plan["environment"] as Dictionary)["salinityGPerKg"]), 5), "inline environment input updates plan")
	check(app.site_readout.text.contains("1002."), "environment readout responds to salinity")
	app.apply_inline_changes()
	check(is_instance_valid(salinity), "simulation preserves environment input instance")
	check(app.tissue_list.find_children("*", "Control", true, false).filter(func(node: Node) -> bool: return node is BathysTrendArrow).size() == 32, "tissues display two arrow symbols per compartment")
	app.undo()
	await process_frame
	await wait_for_simulation(app)
	check(is_equal_approx(float((app.plan["environment"] as Dictionary)["salinityGPerKg"]), 0), "undo restores inline environment edit")
	var gf: SpinBox = app.site_list.find_child("gfLow", true, false) as SpinBox
	gf.value = 35
	check(app.model_readout.text.contains("35 /"), "model summary follows inline gradient factor edit")
	app.apply_inline_changes()
	app.add_switch()
	await process_frame
	check(str((app.plan["waypoints"] as Array)[-1]["tankId"]) == str(app.plan["initialTankId"]), "new switch chooses a different gas from current stage")
	app.clear_route()
	await process_frame
	await wait_for_simulation(app)
	check(app.frames.is_empty() and app.metric_label.text == "00:00 / 00:00", "empty route resets playback cleanly")
	check(app.status_label.text.begins_with("Route empty"), "empty route displays start hint")
	print("UI_SMOKE failures=", failures)
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

