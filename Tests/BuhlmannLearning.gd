extends "res://Tests/LearningUi.gd"

func click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	await layout()
	await super.click(at)

func near(actual: float, expected: float, tolerance: float, message: String) -> void:
	check(absf(actual - expected) <= tolerance, message + " (" + str(actual) + ")")

func run() -> void:
	root.size = Vector2i(1280, 1100)
	var localization := root.get_node("I18n")
	localization.set_language("en", false)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	app.acknowledge_educational_use()
	await settle(app)
	var before: String = JSON.stringify(app.plan)
	app.map.magnification = 1.6
	app.set_learning_mode(true)
	await layout()
	var view: BathysLearningView = app.learning_view
	view.topic_scroll.ensure_control_visible(view.topic_buttons["buhlmann"])
	await layout()
	await click((view.topic_buttons["buhlmann"] as Button).get_global_rect().get_center())
	var lesson: BathysBuhlmannLesson = view.buhlmann_view
	check(view.lesson == "buhlmann" and lesson.visible and not view.diagram.visible and not view.readouts.visible, "Bühlmann navigation opens a dedicated interactive lesson")
	check(not lesson.ascent and lesson.loading_controls.visible and not lesson.ascent_controls.visible, "lesson starts with tissue loading controls")
	check((lesson.state["model"] as BathysTissue).n2.size() == 16, "all sixteen ZH-L16C compartments are displayed")
	var initial: float = 0.740467
	var target: float = 3.110467
	var loaded: BathysTissue = BathysBuhlmannLessonModel.loaded_tissues(30, 4)
	near(loaded.n2[0], (initial + target) / 2, 1e-10, "four-minute nitrogen compartment closes half its gap in four minutes")
	loaded = BathysBuhlmannLessonModel.loaded_tissues(30, 27)
	near(loaded.n2[4], (initial + target) / 2, 1e-10, "twenty-seven-minute compartment closes half its gap in twenty-seven minutes")
	check(loaded.n2[0] > loaded.n2[4] and loaded.n2[4] > loaded.n2[15], "same exposure gives fast and slow compartments different loading")
	(lesson.inputs["exposure_time"] as HSlider).value = 4
	check(lesson.readout_values[0].text == "4.0 min" and lesson.readout_values[2].text == "50.0%", "half-time and gap readouts follow the time slider")
	var bars: Rect2 = lesson.diagram.bars_rect()
	await click(lesson.diagram.global_position + bars.position + Vector2(bars.size.x * 4.5 / 16, bars.size.y * 0.5))
	check(lesson.selected == 4 and lesson.compartment_picker.selected == 4, "clicking a tissue bar selects that compartment")
	lesson.diagram.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	Input.parse_input_event(key)
	await layout()
	check(lesson.selected == 5, "keyboard arrows compare neighbouring compartments")
	key.pressed = false
	Input.parse_input_event(key)
	lesson.compartment_picker.select(4)
	lesson.compartment_picker.item_selected.emit(4)
	check(lesson.selected == 4, "compartment picker selects a tissue without relying on the diagram")
	var plot: Rect2 = lesson.diagram.curve_rect()
	await click(lesson.diagram.global_position + plot.position + Vector2(plot.size.x * 0.25, plot.size.y * 0.5))
	near(lesson.exposure_minutes, 30, 0.1, "dragging loading curve changes elapsed exposure")
	await capture("res://Screenshots/learning-buhlmann-loading-en.png")
	await click(lesson.stage_buttons[1].get_global_rect().get_center())
	check(lesson.ascent and lesson.ascent_controls.visible and not lesson.loading_controls.visible, "ascent stage shows depth, wait and GF controls")
	var snapshot: Dictionary = lesson.state
	var model: BathysTissue = snapshot["model"]
	var frozen: BathysTissue = snapshot["loaded"]
	near(model.n2[0], frozen.n2[0], 1e-10, "instant depth preview preserves tissue gas at zero wait")
	check(float(snapshot["anchor_m"]) > 0 and fmod(float(snapshot["anchor_m"]), 3) == 0, "frozen GF Low anchor uses the initial ceiling rounded up to three metres")
	var m_value: float = BathysTissue.allowed_inert(0, model.n2[0], 0, 1, 1)
	near(m_value, 1.2599 + 1 / 0.5050, 1e-10, "nitrogen M-value uses the real a and b coefficients")
	var limit: float = BathysTissue.allowed_inert(0, model.n2[0], 0, 1, 0.3)
	near(limit, 1 + 0.3 * (m_value - 1), 1e-10, "GF scales the gap above ambient pressure")
	check(absf(limit - m_value * 0.3) > 0.5, "GF is not applied as a percentage of the whole M-value")
	near(BathysTissue.allowed_inert(0, model.n2[0], 0, 1, 0), 1, 1e-10, "zero GF boundary is ambient pressure")
	var anchor: float = snapshot["anchor_m"]
	(lesson.inputs["preview_depth"] as HSlider).value = 0
	near(float(lesson.state["gf"]), 0.85, 1e-10, "GF High applies at the surface")
	check(float(lesson.state["ceiling_m"]) > 0 and lesson.status_label.text.contains("shallower"), "surface preview identifies the current model ceiling")
	(lesson.inputs["preview_depth"] as HSlider).value = anchor
	near(float(lesson.state["gf"]), 0.3, 1e-10, "GF Low applies at the deeper anchor")
	(lesson.inputs["preview_depth"] as HSlider).value = anchor / 2
	near(float(lesson.state["gf"]), 0.575, 1e-10, "GF interpolates halfway between anchor and surface")
	(lesson.inputs["preview_depth"] as HSlider).value = 9
	await capture("res://Screenshots/learning-buhlmann-gradient-en.png")
	plot = lesson.diagram.curve_rect()
	await click(lesson.diagram.global_position + plot.position + Vector2(plot.size.x * 0.25, plot.size.y * 0.5))
	near(lesson.preview_depth, 10, 0.1, "dragging gradient graph changes ambient-pressure preview")
	(lesson.inputs["preview_depth"] as HSlider).value = 9
	var before_wait: BathysTissue = (lesson.state["model"] as BathysTissue).clone()
	(lesson.inputs["wait"] as HSlider).value = 20
	var after_wait: BathysTissue = lesson.state["model"]
	check(after_wait.n2[0] < before_wait.n2[0] and after_wait.n2[15] > before_wait.n2[15], "waiting can unload fast compartments while slow compartments still load")
	near(float(lesson.state["anchor_m"]), anchor, 1e-10, "waiting retains the frozen illustration anchor")
	var reference: BathysTissue = before_wait.clone()
	reference.advance(1.9, 1200, {"o2": 0.21, "n2": 0.79, "he": 0.0})
	near(after_wait.n2[4], reference.n2[4], 1e-10, "wait uses actual tissue exchange from the loaded state")
	var maximum: float = -INF
	var controller: int = 0
	var gf: float = lesson.state["gf"]
	for i: int in 16:
		var ceiling: float = (after_wait.n2[i] - gf * BathysTissue.N_A[i]) / (1 + gf * (1 / BathysTissue.N_B[i] - 1))
		if ceiling > maximum:
			maximum = ceiling
			controller = i + 1
	near(float(lesson.state["ceiling_m"]), maxf(0, (maximum - 1) * 10), 1e-10, "ceiling is set by the most restrictive compartment")
	check(int(lesson.state["controller"]) == (controller if maximum > 1 else 0), "readout identifies the actual ceiling controller")
	var low_ceiling: float = after_wait.ceiling(0.3)[0]
	check(low_ceiling >= after_wait.ceiling(0.85)[0], "lower GF gives an equal or deeper ceiling for unchanged loading")
	(lesson.inputs["low"] as HSlider).value = 95
	check(lesson.gf_low == 95 and lesson.gf_high == 95, "raising GF Low preserves Low no higher than High")
	(lesson.inputs["high"] as HSlider).value = 60
	check(lesson.gf_low == 60 and lesson.gf_high == 60, "lowering GF High maintains valid ordering")
	(lesson.inputs["low"] as HSlider).value = 30
	(lesson.inputs["high"] as HSlider).value = 85
	await capture("res://Screenshots/learning-buhlmann-wait-en.png")
	localization.set_language("fr", false)
	await layout()
	check(lesson.summary_label.text.contains("ancrage") and TranslationServer.translate(lesson.explanation.text).contains("valeur M"), "live summary and model explanations translate to French")
	check(lesson.wait_minutes == 20 and lesson.selected == 4, "language changes preserve the experiment")
	await capture("res://Screenshots/learning-buhlmann-gradient-fr.png")
	lesson.set_stage(false)
	await capture("res://Screenshots/learning-buhlmann-loading-fr.png")
	root.size = Vector2i(390, 900)
	await layout()
	check(view.get_combined_minimum_size().x <= 390 and lesson.diagram.custom_minimum_size.y == 620, "French phone layout stacks the tissue bars and loading graph")
	await capture("res://Screenshots/learning-buhlmann-loading-fr-phone.png")
	lesson.set_stage(true)
	app.learning_view.lesson_scroll.scroll_vertical = 0
	await layout()
	check(view.get_combined_minimum_size().x <= 390 and lesson.readouts.columns == 1, "GF controls and readouts fit the phone width")
	await capture("res://Screenshots/learning-buhlmann-gradient-fr-phone.png")
	app.learning_view.lesson_scroll.scroll_vertical = 10000
	await layout()
	await capture("res://Screenshots/learning-buhlmann-gradient-fr-phone-bottom.png")
	view.select_lesson("henry")
	check(not lesson.visible and view.diagram.visible and view.readouts.visible, "previous lessons restore their original diagrams and controls")
	view.select_lesson("buhlmann")
	check(lesson.ascent and lesson.wait_minutes == 20 and lesson.selected == 4, "Bühlmann experiment survives topic switching")
	app.set_learning_mode(false)
	await layout()
	check(JSON.stringify(app.plan) == before and app.undo_stack.is_empty() and app.map.magnification == 1.6, "Bühlmann lesson leaves dive scenario, history and map untouched")
	# Edge case: no initial supersaturation needs no GF Low anchor.
	var surface: Dictionary = BathysBuhlmannLessonModel.snapshot(0, 0, 0, 120, 0.3, 0.85, true)
	check(surface["anchor_m"] == 0 and surface["ceiling_m"] == 0 and surface["controller"] == 0, "surface equilibrium has no ceiling or artificial controller")
	near(surface["gf"], 0.85, 1e-10, "unneeded deep anchor falls back to GF High")
	localization.set_language("en", false)
	app.queue_free()
	await layout()
	quit(1 if failures else 0)
