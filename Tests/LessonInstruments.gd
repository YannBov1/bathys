extends "res://Tests/LessonIntuition.gd"

func run() -> void:
	root.size = Vector2i(1280, 1050)
	var localization := root.get_node("I18n")
	localization.set_language("en", false)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	app.acknowledge_educational_use()
	var view: BathysLearningView = app.learning_view
	var ui: BathysLessonPresentation = view.presentation
	check(ui.chart_button.button_pressed, "linked charts start enabled")
	await settle(app)
	ui.note_button.button_pressed = false
	app.set_learning_mode(true)
	var before: String = JSON.stringify(app.plan)
	for topic: Array in view.TOPICS:
		view.select_lesson(topic[0])
		await layout()
		check(visible_sliders(view) == 0 and ui.toolbar.get_child_count() == 3, "visual controls work without precise drawer: " + topic[0])
		await capture("res://Screenshots/instruments-" + topic[0] + "-en.png")
	view.select_lesson("henry")
	await layout()
	var clock: BathysLessonInstrument = ui.widgets["time"]
	await click(clock.global_position + Vector2(clock.size.x / 2 + 23, 86))
	near(view.half_times, snappedf(lerpf(clock.source.min_value, clock.source.max_value, 90.0 / 350), clock.source.step), 0.01, "clock hand uses a whole dial instead of a pressure-gauge sweep")
	view.select_lesson("gas_density")
	await layout()
	var tank: BathysLessonGasMixture = ui.widgets["mixture"]
	var params: Dictionary = view.breathing_view.parameters()
	await drag(tank.global_position + Vector2(17, tank.divider(0)), tank.global_position + Vector2(60, tank.TOP + tank.HEIGHT * 0.3))
	near(params["oxygen"], 30, 0.11, "tank upper divider directly changes O₂")
	await drag(tank.global_position + Vector2(tank.size.x - 19, tank.divider(1)), tank.global_position + Vector2(60, tank.TOP + tank.HEIGHT * 0.5))
	near(params["helium"], 50, 0.11, "tank lower divider directly changes He")
	await drag(tank.global_position + Vector2(17, tank.divider(0)), tank.global_position + Vector2(60, tank.TOP + tank.HEIGHT * 0.95))
	check(params["oxygen"] + params["helium"] <= 100 and params["oxygen"] >= 0 and params["helium"] >= 0, "mixture separators cannot create negative nitrogen or exceed 100%")
	await drag(tank.global_position + Vector2(tank.size.x - 19, tank.divider(1)), tank.global_position + Vector2(tank.size.x - 19, tank.TOP + tank.HEIGHT * 0.6))
	near(params["helium"], 40, 0.11, "opposite-side handle remains usable when nitrogen is zero")
	tank.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_UP
	key.pressed = true
	Input.parse_input_event(key)
	await layout()
	check(params["helium"] > 40 and params["oxygen"] == 50, "keyboard edits the last selected tank separator")
	await capture("res://Screenshots/instruments-mixture-en.png")
	view.select_lesson("colour")
	view.optics_view.set_stage(2)
	await layout()
	var distance: BathysLessonInstrument = ui.widgets["range"]
	check(distance.get_parent().get_index() < view.optics_view.plots.get_index(), "distance ruler precedes the image-model plots")
	await drag(distance.global_position + Vector2(38, 55), distance.global_position + Vector2(38 + (distance.size.x - 76) * 0.75, 55))
	view.optics_view.flush_update()
	near(view.optics_view.params["range"], 11.3, 0.1, "horizontal eye-to-fish ruler changes range with precise controls hidden")
	await capture("res://Screenshots/instruments-image-model-en.png")
	view.optics_view.set_stage(0)
	view.optics_view.torch_switch.button_pressed = true
	await layout()
	check(ui.widgets.has("exposure") and ui.widgets.has("power") and not ui.widgets.has("baseline"), "lighting instruments start visible and offset uses the diagram")
	for name: String in ["exposure", "power"]:
		var widget: BathysLessonInstrument = ui.widgets[name]
		view.lesson_scroll.ensure_control_visible(widget)
		await layout()
		check(widget.is_visible_in_tree(), "lighting instrument needs no toggle")
		await click(widget.global_position + Vector2(widget.size.x - 38, 55))
		near(widget.source.value, widget.source.max_value, 0.001, "visual lighting rail reaches the full parameter range")
	view.lesson_scroll.ensure_control_visible(view.optics_view.plots)
	await layout()
	await capture("res://Screenshots/instruments-torch-en.png")
	view.select_lesson("buoyancy")
	var buoy: BathysBuoyancyLesson = view.buoyancy_view
	buoy.set_stage(false)
	await layout()
	buoy.inputs["mass"].value = 40
	buoy.inputs["volume"].value = 80
	var at := buoy.diagram.global_position + Vector2(buoy.diagram.section(0).size.x * 0.46, buoy.diagram.waterline_y() + 25)
	await click(at)
	await create_timer(1.0).timeout
	near(buoy.result["net_force"], 0, 0.001, "released body settles to physical floating fraction")
	near(buoy.parameters()["immersion"], 40 / (buoy.density * 0.08) * 100, 0.001, "equilibrium uses the selected mass, volume and water density")
	buoy.inputs["mass"].value = 100
	buoy.inputs["immersion"].value = 20
	buoy.settle_body()
	await create_timer(1.0).timeout
	check(buoy.parameters()["immersion"] == 100 and buoy.result["net_force"] < 0, "denser body reaches full immersion and retains downward force")
	buoy.inputs["mass"].value = 40
	buoy.inputs["immersion"].value = 10
	buoy.settle_body()
	buoy.set_stage(true)
	var saved: float = buoy.experiments["object"]["immersion"]
	await create_timer(1.0).timeout
	near(buoy.experiments["object"]["immersion"], saved, 0.001, "changing stages cancels settling without altering the other experiment")
	localization.set_language("fr", false)
	root.size = Vector2i(390, 900)
	for topic: Array in view.TOPICS:
		view.select_lesson(topic[0])
		await layout()
		check(view.get_combined_minimum_size().x <= 390, "default linked-chart French phone layout fits: " + topic[0])
		await capture("res://Screenshots/instruments-" + topic[0] + "-fr-phone.png")
	view.select_lesson("colour")
	view.optics_view.set_stage(2)
	await layout()
	check(view.get_combined_minimum_size().x <= 390 and ui.widgets["range"].is_visible_in_tree(), "image-model distance ruler fits a phone")
	await capture("res://Screenshots/instruments-image-model-fr-phone.png")
	view.select_lesson("snell")
	view.set_snell_stage(true)
	await layout()
	for name: String in ["height", "gap", "thickness", "glass_index"]:
		check(ui.widgets[name].is_visible_in_tree() and view.get_combined_minimum_size().x <= 390, "French mask instruments are visible and fit a phone")
	await capture("res://Screenshots/instruments-mask-fr-phone.png")
	check(JSON.stringify(app.plan) == before and app.undo_stack.is_empty(), "visual instrument edits leave the dive plan and history untouched")
	localization.set_language("en", false)
	app.queue_free()
	await layout()
	print("LESSON INSTRUMENTS failures=", failures)
	quit(1 if failures else 0)
