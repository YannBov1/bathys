extends "res://Tests/BreathingLearning.gd"

func capture(path: String) -> void:
	if "--visual" in OS.get_cmdline_user_args(): await point(Vector2(2, 2))
	await super.capture(path)

func drag(from: Vector2, to: Vector2) -> void:
	await point(from)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from
	down.global_position = from
	Input.parse_input_event(down)
	await layout()
	for i: int in 5:
		var motion := InputEventMouseMotion.new()
		motion.position = from.lerp(to, (i + 1) / 5.0)
		motion.global_position = motion.position
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
		await layout()
	down.pressed = false
	down.position = to
	down.global_position = to
	Input.parse_input_event(down)
	await layout()

func visible_sliders(node: Node) -> int:
	var count: int = 1 if node is HSlider and node.is_visible_in_tree() else 0
	for child: Node in node.get_children(): count += visible_sliders(child)
	return count

func visible_paragraphs(node: Node) -> int:
	var count: int = 1 if node is Label and node.is_visible_in_tree() and node.text.length() > 120 else 0
	for child: Node in node.get_children(): count += visible_paragraphs(child)
	return count

func run() -> void:
	root.size = Vector2i(1280, 1050)
	var localization := root.get_node("I18n")
	localization.set_language("en", false)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	var view: BathysLearningView = app.learning_view
	var ui: BathysLessonPresentation = view.presentation
	check(not ui.note_button.button_pressed and not ui.parameter_button.button_pressed and ui.chart_button.button_pressed, "fresh lessons enable linked charts while keeping text and precise controls optional")
	await settle(app)
	app.set_learning_mode(true)
	var before: String = JSON.stringify(app.plan)
	var history: int = app.undo_stack.size()
	ui.compact_all()
	for topic: Array in view.TOPICS:
		view.select_lesson(topic[0])
		await layout()
		check(visible_sliders(view) == 0 and visible_paragraphs(view) == 0 and not view.intro_label.visible, "compact " + str(topic[0]) + " has no slider wall or explanatory paragraphs")
		check(not ui.diagram.comparison_visible and ui.diagram.custom_minimum_size.y <= 380, "compact " + str(topic[0]) + " starts on one focused visual")
		await capture("res://Screenshots/intuition-" + str(topic[0]) + "-en.png")
	view.select_lesson("boyle")
	await layout()
	var diagram: BathysScienceLessonDiagram = view.diagram
	var scene: Rect2 = diagram.bubble_rect()
	var start := diagram.global_position + Vector2(scene.size.x * 0.43, 96 + (scene.size.y - 150) * view.depth_m / 40)
	await drag(start, diagram.global_position + Vector2(scene.size.x * 0.43, 96 + (scene.size.y - 150) * 25 / 40))
	near(view.depth_m, 25, 0.1, "bubble is the primary depth control")
	ui.chart_button.button_pressed = true
	await layout()
	check(diagram.comparison_visible and visible_sliders(view) == 0, "linked chart can open without opening a parameter panel")
	await capture("res://Screenshots/intuition-boyle-chart-en.png")
	ui.chart_button.button_pressed = false
	ui.note_button.button_pressed = true
	await layout()
	check(view.formula_label.is_visible_in_tree() and view.assumptions_label.is_visible_in_tree() and view.source_button.is_visible_in_tree(), "equations, assumptions and references remain one click away")
	ui.note_button.button_pressed = false
	view.select_lesson("dalton")
	await layout()
	var water: BathysLessonInstrument = ui.widgets["depth"]
	await click(water.global_position + Vector2(water.size.x / 2, 46 + 73 * 0.5))
	near(view.dalton_depth, 20, 0.1, "water ruler sets depth directly")
	var plot := Rect2(42, 64, diagram.size.x - 60, diagram.size.y - 138)
	var x: float = plot.position.x + plot.size.x * 0.125
	start = diagram.global_position + Vector2(x, plot.end.y - plot.size.y * 3 * view.oxygen_percent / 100 / 5)
	await drag(start, diagram.global_position + Vector2(x, plot.end.y - plot.size.y * 1.5 / 5))
	near(view.oxygen_percent, 50, 0.2, "oxygen bar is an editable mixture control")
	view.select_lesson("density")
	await layout()
	var density_rect: Rect2 = diagram.graph_rect("density")
	await click(diagram.global_position + density_rect.position + density_rect.size * Vector2(4.0 / 35, 0.5))
	near(view.temperature_c, 4, 0.11, "primary water-density curve sets temperature directly")
	view.select_lesson("charles")
	await layout()
	var thermal: BathysThermalLessons = view.thermal_view
	var thermometer: BathysLessonInstrument = ui.widgets["temperature"]
	check(thermometer.get_parent().get_parent() == thermal.diagram, "thermometer sits beside the gas apparatus")
	var initial: float = thermal.parameters()["temperature"]
	var fraction: float = (initial + 100) / 450
	await click(thermometer.global_position + Vector2(thermometer.size.x / 2, 111 - fraction * 65))
	near(thermal.parameters()["temperature"], initial, 0.051, "pressing the mercury handle does not jump the temperature")
	await drag(thermometer.global_position + Vector2(thermometer.size.x / 2, 111 - fraction * 65), thermometer.global_position + Vector2(thermometer.size.x / 2, 111 - (180.0 / 450) * 65))
	await create_timer(0.08).timeout
	near(thermal.parameters()["temperature"], 80, 0.06, "dragging mercury heats the gas")
	var gas_diagram: BathysThermalDiagram = thermal.diagram
	start = gas_diagram.global_position + Vector2(gas_diagram.section(0).size.x * 0.42, 284 - float(thermal.result["volume"]) * 73)
	await drag(start, gas_diagram.global_position + Vector2(gas_diagram.section(0).size.x * 0.42, 284 - 2 * 73))
	await create_timer(0.08).timeout
	near(thermal.result["volume"], 2, 0.001, "piston itself controls the Charles experiment")
	await capture("res://Screenshots/intuition-charles-drag-en.png")
	view.select_lesson("ideal_gas")
	await layout()
	var reference_pressure: float = thermal.result["pressure"]
	var rect: Rect2 = gas_diagram.vessel_rect()
	start = gas_diagram.global_position + Vector2(rect.end.x, rect.get_center().y)
	var edge: float = gas_diagram.section(0).size.x / 2 + gas_diagram.section(0).size.x * 0.175 * pow(0.5, 1.0 / 3.0)
	await drag(start, gas_diagram.global_position + Vector2(edge, rect.get_center().y))
	await create_timer(0.08).timeout
	near(thermal.result["pressure"], reference_pressure * 2, 0.01, "dragging the vessel wall changes volume and pressure together")
	view.select_lesson("fick")
	await layout()
	var exchange: BathysExchangeLesson = view.exchange_view
	var membrane: BathysExchangeDiagram = exchange.diagram
	var mid: float = membrane.section(0).size.x / 2
	await drag(membrane.global_position + Vector2(mid + 13, 177), membrane.global_position + Vector2(mid + 20, 177))
	near(exchange.parameters()["thickness"], 2, 0.051, "barrier side handle changes diffusion thickness")
	await drag(membrane.global_position + Vector2(mid, 209.5), membrane.global_position + Vector2(mid, 225.75))
	near(exchange.parameters()["area"], 1.5, 0.051, "barrier vertical handle changes active exchange area")
	var clock: BathysLessonInstrument = ui.widgets["time"]
	clock.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	Input.parse_input_event(key)
	await layout()
	key.pressed = false
	Input.parse_input_event(key)
	check(exchange.parameters()["time"] > 1, "visual instruments retain keyboard access")
	await capture("res://Screenshots/intuition-fick-drag-en.png")
	view.select_lesson("colour")
	await layout()
	var optics: BathysOpticsLesson = view.optics_view
	var target := Vector2(85 + 3.0 / 15 * (optics.plots.size.x - 145), 62 + 10.0 / 30 * (optics.plots.size.y - 112))
	var destination := Vector2(85 + 7.0 / 15 * (optics.plots.size.x - 145), 62 + 20.0 / 30 * (optics.plots.size.y - 112))
	await drag(optics.plots.global_position + target, optics.plots.global_position + destination)
	optics.flush_update()
	near(optics.params["depth"], 20, 0.11, "underwater colour target changes depth without a slider")
	near(optics.params["range"], 7, 0.11, "same target gesture changes viewing distance")
	optics.set_stage(1)
	await layout()
	check(ui.widgets["g"].is_visible_in_tree(), "scattering instrument stays accessible with optional charts")
	var spectrum: Rect2 = optics.plots.plot(0)
	await click(optics.plots.global_position + spectrum.position + spectrum.size * Vector2(0.25, 0.5))
	optics.flush_update()
	check(optics.plots.probe_touched, "touching a spectrum reveals selected wavelength values")
	ui.chart_button.button_pressed = true
	await layout()
	check(ui.widgets["g"].is_visible_in_tree(), "phase plot and its scattering control appear together")
	await capture("res://Screenshots/intuition-scattering-en.png")
	ui.chart_button.button_pressed = false
	optics.set_stage(0)
	view.select_lesson("buhlmann")
	view.buhlmann_view.set_stage(true)
	await layout()
	var low: BathysLessonInstrument = ui.widgets["low"]
	var high: BathysLessonInstrument = ui.widgets["high"]
	view.buhlmann_view.inputs["low"].value = 95
	await layout()
	check(high.last_value == 95 and low.last_value == 95, "coupled visual controls redraw when model constraints update another value silently")
	view.select_lesson("snell")
	view.set_snell_stage(true)
	await layout()
	var mask: BathysMaskLesson = view.mask_view
	var rail_start: Vector2 = mask.diagram.global_position + Vector2(75 + (mask.params["distance"] - 0.5) / 2.5 * (mask.diagram.size.x - 115), 94)
	await drag(rail_start, mask.diagram.global_position + Vector2(75 + (2.0 - 0.5) / 2.5 * (mask.diagram.size.x - 115), 94))
	near(mask.params["distance"], 2, 0.011, "mask comparison has a directly draggable target")
	ui.parameter_button.button_pressed = true
	await layout()
	check(visible_sliders(view) == 5 and not ui.instruments.is_visible_in_tree(), "precise settings remain available without duplicate instruments")
	mask.inputs["thickness"].value = 8
	ui.parameter_button.button_pressed = false
	await layout()
	near(mask.params["thickness"], 8, 1e-12, "closing precise settings keeps the experiment state")
	localization.set_language("fr", false)
	await layout()
	root.size = Vector2i(390, 900)
	await layout()
	for topic: Array in view.TOPICS:
		view.select_lesson(topic[0])
		await layout()
		check(view.get_combined_minimum_size().x <= 390 and visible_sliders(view) == 0 and visible_paragraphs(view) == 0, "French compact phone layout fits " + str(topic[0]))
		await capture("res://Screenshots/intuition-" + str(topic[0]) + "-fr-phone.png")
	view.select_lesson("colour")
	await layout()
	var compare: BathysColourCompare = view.optics_view.compare_handle
	check(compare.is_visible_in_tree() and not view.optics_view.preview_box.get_child(0).visible, "phone colour preview combines reference and underwater image into one comparison")
	var split_before: float = compare.split
	await drag(compare.global_position + Vector2(compare.size.x * 0.1, compare.size.y * 0.2), compare.global_position + Vector2(compare.size.x * 0.1, compare.size.y * 0.8))
	near(compare.split, split_before, 1e-10, "vertical scroll intent does not move the colour divider")
	await drag(compare.global_position + Vector2(compare.size.x * split_before, compare.size.y / 2), compare.global_position + Vector2(compare.size.x * 0.8, compare.size.y / 2))
	near(compare.split, 0.8, 0.01, "colour comparison divider is directly draggable")
	ui.parameter_button.button_pressed = true
	await layout()
	check(not compare.visible and view.optics_view.preview_box.get_child(0).visible, "expanded colour view restores both original reference panes")
	ui.parameter_button.button_pressed = false
	await capture("res://Screenshots/intuition-colour-compare-fr-phone.png")
	view.select_lesson("charles")
	await layout()
	check(TranslationServer.translate(ui.hint.text).contains("mercure"), "gesture cue translates into French")
	ui.chart_button.button_pressed = true
	await layout()
	check(view.get_combined_minimum_size().x <= 390, "optional stacked charts retain phone width")
	ui.note_button.button_pressed = true
	await layout()
	check(view.thermal_view.assumptions.is_visible_in_tree() and TranslationServer.translate(view.thermal_view.assumptions.text).begins_with("Modèle"), "full French model information stays available")
	ui.compact_all()
	app.set_learning_mode(false)
	check(JSON.stringify(app.plan) == before and app.undo_stack.size() == history, "presentation and gestures leave the scenario and undo history untouched")
	localization.set_language("en", false)
	app.queue_free()
	await layout()
	print("LESSON INTUITION failures=", failures)
	quit(1 if failures else 0)
