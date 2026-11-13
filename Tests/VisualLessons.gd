extends "res://Tests/LessonIntuition.gd"

func run() -> void:
	root.size = Vector2i(1280, 1050)
	var localization := root.get_node("I18n")
	localization.set_language("en", false)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	app.acknowledge_educational_use()
	await settle(app)
	app.set_learning_mode(true)
	var view: BathysLearningView = app.learning_view
	var ui: BathysLessonPresentation = view.presentation
	ui.note_button.button_pressed = false
	var before: String = JSON.stringify(app.plan)
	for topic: Array in view.TOPICS:
		view.select_lesson(topic[0])
		await layout()
		check(ui.toolbar.get_child_count() == 3 and visible_sliders(view) == 0, "only chart and information toggles remain: " + topic[0])
		await capture("res://Screenshots/visual-only-" + topic[0] + "-en.png")
	view.select_lesson("ideal_gas")
	await layout()
	check(ui.widgets["volume"].is_visible_in_tree(), "fixed-volume instrument is shown by default")
	var thermal: BathysThermalLessons = view.thermal_view
	check(thermal.formula.text.contains("Pressure × volume: PV") and thermal.formula.text.contains("nRT =") and not thermal.formula.text.contains("J ="), "ideal equation labels both compared products")
	ui.note_button.button_pressed = true
	await layout()
	view.lesson_scroll.ensure_control_visible(thermal.formula)
	await capture("res://Screenshots/visual-only-ideal-formula-en.png")
	ui.note_button.button_pressed = false
	view.lesson_scroll.scroll_vertical = 0
	thermal.solve_picker.select(1)
	thermal.solve_picker.item_selected.emit(1)
	await layout()
	check(ui.widgets["pressure"].is_visible_in_tree() and not ui.widgets.has("volume"), "fixed-pressure mode swaps in the pressure instrument")
	await capture("res://Screenshots/visual-only-ideal-pressure-en.png")
	view.select_lesson("colour")
	var optics: BathysOpticsLesson = view.optics_view
	optics.torch_switch.button_pressed = true
	optics.flush_update()
	optics.plots.adapt()
	await layout()
	check(ui.widgets["power"].is_visible_in_tree() and ui.widgets["exposure"].is_visible_in_tree() and not ui.widgets.has("baseline"), "torch power and exposure are visible; offset has no duplicate instrument")
	view.lesson_scroll.ensure_control_visible(optics.plots)
	await layout()
	var old_depth: float = optics.params["depth"]
	var old_range: float = optics.params["range"]
	var old_offset: float = optics.params["baseline"]
	var from: Vector2 = optics.plots.global_position + optics.plots.torch_position()
	await drag(from, from + Vector2(0, 16))
	optics.flush_update()
	near(optics.params["baseline"], minf(1.5, old_offset + 0.5), 0.051, "vertical torch drag changes physical offset")
	near(optics.params["depth"], old_depth, 0.001, "torch drag keeps fish depth unchanged")
	near(optics.params["range"], old_range, 0.001, "torch drag keeps fish range unchanged")
	var torch_key := InputEventKey.new()
	torch_key.keycode = KEY_UP
	torch_key.pressed = true
	Input.parse_input_event(torch_key)
	await layout()
	near(optics.params["baseline"], minf(1.5, old_offset + 0.5) - 0.05, 0.051, "selected torch has keyboard offset control")
	torch_key.pressed = false
	Input.parse_input_event(torch_key)
	optics.inputs["depth"].value = 30
	optics.inputs["baseline"].value = 1.5
	optics.flush_update()
	await layout()
	check(optics.plots.torch_position().y + 16 < optics.plots.size.y, "torch remains inside the scene at deepest depth and largest offset")
	await capture("res://Screenshots/visual-only-torch-drag-en.png")
	view.select_lesson("buoyancy")
	var buoy: BathysBuoyancyLesson = view.buoyancy_view
	buoy.set_stage(false)
	await layout()
	buoy.inputs["immersion"].value = 100
	var original: float = buoy.parameters()["immersion"]
	await focus_visual(view, buoy.inputs["mass"])
	var key := InputEventKey.new()
	key.keycode = KEY_HOME
	key.pressed = true
	Input.parse_input_event(key)
	await create_timer(1).timeout
	check(buoy.parameters()["immersion"] < original and absf(float(buoy.result["net_force"])) < 0.001, "mass instrument moves the body toward its new floating level")
	buoy.inputs["mass"].value = 40
	await create_timer(1).timeout
	original = buoy.parameters()["immersion"]
	buoy.inputs["volume"].value = 100
	await create_timer(1).timeout
	check(buoy.parameters()["immersion"] < original and absf(float(buoy.result["net_force"])) < 0.001, "volume instrument moves the body toward its new floating level")
	view.lesson_scroll.scroll_vertical = 0
	await capture("res://Screenshots/visual-only-floating-en.png")
	view.select_lesson("fick")
	await layout()
	var exchange: BathysExchangeLesson = view.exchange_view
	for button: Button in exchange.stage_buttons: check(button.text.is_empty() and button.icon != null and not button.tooltip_text.is_empty(), "exchange context uses anatomical icons with tooltips")
	check(ui.widgets["area"].is_visible_in_tree() and ui.widgets["thickness"].is_visible_in_tree() and ui.widgets["permeability"].is_visible_in_tree(), "all lung instruments appear directly")
	exchange.set_context("tissues")
	await layout()
	check(ui.widgets["capacity"].is_visible_in_tree(), "tissue storage instrument appears directly")
	exchange.inputs["area"].value = 2
	exchange.inputs["thickness"].value = 3
	await capture("res://Screenshots/visual-only-fick-barrier-en.png")
	exchange.inputs["area"].value = 0.2
	exchange.inputs["thickness"].value = 0.25
	view.lesson_scroll.ensure_control_visible(exchange.diagram)
	await layout()
	var midpoint: float = exchange.diagram.section(0).size.x / 2
	from = exchange.diagram.global_position + Vector2(midpoint + (12 + 14 * 0.25) / 2, 177)
	await drag(from, from + Vector2(7, 0))
	near(exchange.parameters()["thickness"], 1.25, 0.051, "thin membrane thickness handle remains draggable at the smallest exchange area")
	near(exchange.parameters()["area"], 0.2, 0.001, "thickness gesture does not capture the nearby area handle")
	view.select_lesson("buhlmann")
	var lesson: BathysBuhlmannLesson = view.buhlmann_view
	lesson.set_stage(true)
	await layout()
	for name: String in ["exposure_depth", "exposure_time", "wait"]: check(ui.widgets[name].is_visible_in_tree(), "ascent instrument is visible: " + name)
	var profile: BathysBuhlmannProfile = lesson.profile
	view.lesson_scroll.ensure_control_visible(profile)
	await layout()
	var plot: Rect2 = profile.chart()
	from = profile.global_position + profile.handle(1)
	await drag(from, from + Vector2(plot.size.x * 10 / profile.time_scale, -plot.size.y * 5 / 40))
	near(lesson.exposure_depth, 25, 0.11, "profile exposure corner sets depth")
	near(lesson.exposure_minutes, 40, 0.11, "profile exposure corner sets duration")
	from = profile.global_position + profile.handle(2)
	await drag(from, from + Vector2(plot.size.x * 20 / profile.time_scale, plot.size.y * 3 / 40))
	near(lesson.preview_depth, 12, 0.11, "profile wait corner sets preview depth")
	near(lesson.wait_minutes, 20, 0.11, "profile wait corner sets waiting time")
	var expected: Dictionary = BathysBuhlmannLessonModel.snapshot(25, 40, 12, 20, lesson.gf_low / 100, lesson.gf_high / 100, true)
	near((lesson.state["model"] as BathysTissue).n2[4], (expected["model"] as BathysTissue).n2[4], 1e-9, "profile edits use the existing pressure-step tissue calculation")
	profile.grab_focus()
	key.keycode = KEY_3
	Input.parse_input_event(key)
	key = key.duplicate()
	key.keycode = KEY_RIGHT
	Input.parse_input_event(key)
	await layout()
	check(lesson.wait_minutes > 20, "profile corners support keyboard editing")
	view.lesson_scroll.scroll_vertical = 0
	await capture("res://Screenshots/visual-only-buhlmann-profile-en.png")
	localization.set_language("fr", false)
	root.size = Vector2i(390, 900)
	for topic: Array in view.TOPICS:
		view.select_lesson(topic[0])
		await layout()
		check(view.get_combined_minimum_size().x <= 390 and visible_sliders(view) == 0, "visual-only French phone layout fits: " + topic[0])
		await capture("res://Screenshots/visual-only-" + topic[0] + "-fr-phone.png")
	view.select_lesson("ideal_gas")
	await layout()
	ui.note_button.button_pressed = true
	await layout()
	view.lesson_scroll.ensure_control_visible(thermal.formula)
	await capture("res://Screenshots/visual-only-ideal-formula-fr-phone.png")
	ui.note_button.button_pressed = false
	view.select_lesson("colour")
	await layout()
	view.lesson_scroll.scroll_vertical = 10000
	await capture("res://Screenshots/visual-only-colour-instruments-fr-phone.png")
	view.select_lesson("fick")
	await layout()
	view.lesson_scroll.scroll_vertical = 10000
	await capture("res://Screenshots/visual-only-fick-instruments-fr-phone.png")
	check(JSON.stringify(app.plan) == before and app.undo_stack.is_empty(), "visual lesson edits preserve plan and history")
	localization.set_language("en", false)
	app.queue_free()
	await layout()
	print("VISUAL LESSONS failures=", failures)
	quit(1 if failures else 0)
