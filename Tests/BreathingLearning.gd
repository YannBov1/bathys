extends "res://Tests/LearningUi.gd"

func near(actual: float, expected: float, tolerance: float, message: String) -> void:
	check(absf(actual - expected) <= tolerance, message + " (" + str(actual) + ")")

func point(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	Input.parse_input_event(event)
	await layout()

func click(at: Vector2) -> void:
	await point(at)
	await super.click(at)

func choose(view: BathysLearningView, key: String) -> void:
	view.topic_scroll.ensure_control_visible(view.topic_buttons[key])
	await layout()
	await click((view.topic_buttons[key] as Button).get_global_rect().get_center())

func wheel(at: Vector2, count: int) -> void:
	await point(at)
	for i: int in count:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN
		event.pressed = true
		Input.parse_input_event(event)
		await layout()

func run() -> void:
	root.size = Vector2i(1280, 1000)
	var localization := root.get_node("I18n")
	localization.set_language("en", false)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	app.acknowledge_educational_use()
	await settle(app)
	var before: String = JSON.stringify(app.plan)
	app.set_learning_mode(true)
	await layout()
	var view: BathysLearningView = app.learning_view
	var lesson: BathysBreathingLessons = view.breathing_view
	check(view.topic_buttons.size() == 21 and view.CATEGORIES.size() == 3, "twenty-one topics are organized into three categories")
	check(view.topic_picker.item_count == 24, "compact selector retains category separators")
	for index: int in view.TOPICS.size():
		check(view.topic_picker.get_item_index(index) >= 0 and not view.topic_picker.is_item_disabled(view.topic_picker.get_item_index(index)), "stable dropdown topic ID " + str(index))
	await choose(view, "oxygen")
	check(view.lesson == "oxygen" and lesson.visible and not view.diagram.visible, "oxygen lesson opens from categorized navigation")
	near(float(lesson.result["pp_o2"]), 1.28, 1e-10, "nitrox 32 at thirty metres gives 1.28 bar oxygen")
	near(float(BathysLearningModels.oxygen_exposure(4, 100, 150)["cns"]), 100, 1e-8, "app CNS table allocates one hundred percent at 1.4 bar for 150 minutes")
	near(float(BathysLearningModels.oxygen_exposure(6, 100, 45)["cns"]), 100, 1e-8, "last table row gives one hundred percent at 1.6 bar for 45 minutes")
	near(float(BathysLearningModels.oxygen_exposure(0.1325, 100, 60)["otu"]), 60, 1e-8, "sixty minutes at one ata gives sixty OTU")
	var outside: Dictionary = BathysLearningModels.oxygen_exposure(7, 100, 60)
	check(not outside["cns_valid"] and outside["cns"] == null, "CNS table is not extrapolated above 1.6 bar")
	near(float(lesson.result["allocation_min"]), 186, 1e-8, "CNS dial shows the interpolated table time allocation")
	await capture("res://Screenshots/learning-oxygen-en.png")
	(lesson.inputs["oxygen"] as HSlider).value = 100
	check(lesson.numbers[1].text == "Outside table", "out-of-table exposure has an explicit UI state")
	await capture("res://Screenshots/learning-oxygen-outside-en.png")
	(lesson.inputs["depth"] as HSlider).value = 4
	(lesson.inputs["time"] as HSlider).value = 150
	check(lesson.numbers[1].text == "100.0%" and lesson.numbers[1].get_theme_font_size("font_size") == 20, "valid CNS counter and styling return after out-of-range exposure")
	await focus_visual(view, lesson.inputs["time"])
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_RIGHT
	Input.parse_input_event(key)
	await layout()
	check(lesson.parameters()["time"] > 150, "exposure-duration slider supports keyboard control")
	key.pressed = false
	Input.parse_input_event(key)
	var plot: Rect2 = lesson.diagram.plot_rect()
	await click(lesson.diagram.global_position + plot.position + plot.size * Vector2(0.25, 0.4))
	near(lesson.parameters()["depth"], 20, 0.1, "oxygen plot supports direct depth adjustment")
	await choose(view, "narcosis")
	check(lesson.kind == "narcosis" and lesson.convention.visible and not lesson.control_blocks["time"].visible, "narcosis shows its own mixture and assumption controls")
	near(float(lesson.result["end_m"]), 40, 1e-10, "air has its actual depth as END")
	(lesson.inputs["oxygen"] as HSlider).value = 32
	near(float(lesson.result["end_m"]), 40, 1e-10, "nitrox END equals air when oxygen and nitrogen count equally")
	lesson.convention.select(1)
	lesson.convention.item_selected.emit(1)
	near(float(lesson.result["end_m"]), 33.0379746835, 1e-8, "nitrogen-only assumption changes nitrox equivalent depth")
	lesson.convention.select(0)
	lesson.convention.item_selected.emit(0)
	(lesson.preset_rows["narcosis"] as Control).get_child(2).pressed.emit()
	near(float(lesson.result["end_m"]), 17.5, 1e-10, "trimix 18/45 at forty metres has END 17.5 under the selected convention")
	await capture("res://Screenshots/learning-narcosis-en.png")
	(lesson.inputs["helium"] as HSlider).value = 100
	check(lesson.parameters()["oxygen"] == 0 and lesson.result["below_surface"] and lesson.numbers[1].text == "≤0 m", "fractions stay valid and below-surface END is not presented as an exact air match")
	plot = lesson.diagram.plot_rect()
	await click(lesson.diagram.global_position + plot.position + plot.size * Vector2(0.5, 0.25))
	near(lesson.parameters()["depth"], 20, 0.1, "narcosis depth columns support direct manipulation")
	await choose(view, "gas_density")
	check(lesson.kind == "gas_density" and lesson.control_blocks["temperature"].visible, "density lesson exposes gas temperature separately from water temperature")
	var air: Dictionary = BathysLearningModels.breathing_density(0, 21, 0, 20)
	var ideal: float = 100000 * (0.21 * 0.0319988 + 0.79 * 0.0280134) / (8.314462618 * 293.15)
	near(float(air["density"]), ideal, 0.01, "surface air density agrees with the dilute ideal-gas limit")
	var deep_air: Dictionary = BathysLearningModels.breathing_density(40, 21, 0, 20)
	check(float(deep_air["density"]) > float(air["density"]) * 4.9, "greater ambient pressure raises gas density")
	check(float(lesson.result["density"]) < float(deep_air["density"]), "helium mixture is lighter than air at the same pressure and temperature")
	await capture("res://Screenshots/learning-gas-density-en.png")
	var warm: float = lesson.result["density"]
	(lesson.inputs["temperature"] as HSlider).value = 0
	check(float(lesson.result["density"]) > warm, "cooling the gas increases its density")
	check(lesson.diagram.samples.size() == 41 and lesson.diagram.air_samples.size() == 41, "real-gas curves are cached for both mixture and air")
	plot = lesson.diagram.plot_rect()
	await click(lesson.diagram.global_position + plot.position + plot.size * Vector2(0.25, 0.4))
	near(lesson.parameters()["depth"], 20, 0.1, "density plot supports depth adjustment")
	check(lesson.diagram.samples.size() == 41, "depth changes retain the cached composition curves")
	# Each column scrolls independently while the shared ribbon stays at the top.
	root.size = Vector2i(1280, 550)
	await layout()
	var ribbon: Vector2 = app.workspace_switch.global_position
	view.lesson_scroll.scroll_vertical = 150
	view.topic_scroll.scroll_vertical = 0
	await layout()
	var content_scroll: int = view.lesson_scroll.scroll_vertical
	await wheel(view.topic_scroll.get_global_rect().get_center(), 3)
	check(view.topic_scroll.scroll_vertical > 0 and view.lesson_scroll.scroll_vertical == content_scroll, "wheel over navigation scrolls only the topic list")
	var nav_scroll: int = view.topic_scroll.scroll_vertical
	await wheel(view.lesson_scroll.global_position + Vector2(12, 120), 3)
	check(view.lesson_scroll.scroll_vertical > content_scroll and view.topic_scroll.scroll_vertical == nav_scroll, "wheel over a lesson scrolls only its content")
	check(app.workspace_switch.global_position == ribbon and app.workspace_switch.is_visible_in_tree(), "ribbon remains fixed while either lesson column scrolls")
	await capture("res://Screenshots/learning-independent-scroll.png")
	app.set_learning_mode(false)
	await layout()
	var planner_ribbon: Vector2 = app.workspace_switch.global_position
	app.page_scroll.scroll_vertical = 200
	await layout()
	check(app.page_scroll.scroll_vertical > 0 and app.workspace_switch.global_position == planner_ribbon, "planner ribbon stays fixed when planner content scrolls")
	app.set_learning_mode(true)
	root.size = Vector2i(1280, 1000)
	localization.set_language("fr", false)
	await layout()
	for topic: String in ["oxygen", "narcosis", "gas_density"]:
		view.select_lesson(topic)
		await layout()
		check(TranslationServer.translate(view.title_label.text) != view.title_label.text and TranslationServer.translate(lesson.assumptions.text) != lesson.assumptions.text, "French content for " + topic)
		await capture("res://Screenshots/learning-" + topic + "-fr.png")
	view.select_lesson("buhlmann")
	view.buhlmann_view.set_stage(true)
	await layout()
	await capture("res://Screenshots/learning-buhlmann-legend-fr.png")
	root.size = Vector2i(390, 900)
	await layout()
	for topic: String in ["oxygen", "narcosis", "gas_density"]:
		var id: int = -1
		for index: int in view.TOPICS.size():
			if view.TOPICS[index][0] == topic: id = index
		var picker_index: int = view.topic_picker.get_item_index(id)
		view.topic_picker.select(picker_index)
		view.topic_picker.item_selected.emit(picker_index)
		await layout()
		check(view.lesson == topic and view.get_combined_minimum_size().x <= 390, "categorized phone picker and French layout for " + topic)
		await capture("res://Screenshots/learning-" + topic + "-fr-phone.png")
		view.lesson_scroll.scroll_vertical = 10000
		await layout()
		await capture("res://Screenshots/learning-" + topic + "-fr-phone-bottom.png")
	check(app.workspace_switch.global_position.y >= 0, "phone ribbon remains visible at the end of a long lesson")
	view.select_lesson("oxygen")
	check(lesson.parameters()["depth"] == 20 and lesson.parameters()["time"] > 150, "oxygen experiment retains state across lessons and language changes")
	view.select_lesson("narcosis")
	check(lesson.parameters()["helium"] == 100 and lesson.parameters()["depth"] == 20, "narcosis experiment retains its own state")
	view.select_lesson("gas_density")
	check(lesson.parameters()["temperature"] == 0 and lesson.parameters()["depth"] == 20, "density experiment retains its own state")
	app.set_learning_mode(false)
	await layout()
	check(JSON.stringify(app.plan) == before and app.undo_stack.is_empty(), "new lessons and scroll changes leave scenario data and history untouched")
	localization.set_language("en", false)
	app.queue_free()
	await layout()
	quit(1 if failures else 0)
