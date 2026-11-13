extends "res://Tests/MapNavigation.gd"

func run() -> void:
	var density: float = BathysLearningModels.water_properties(20, 0)["density"]
	var attitudes: Array[float] = []
	for index: int in 4:
		var state: Dictionary = BathysLearningModels.cylinder_buoyancy_preset(index)
		var balance: Dictionary = BathysLearningModels.cylinder_trim(state, density)
		attitudes.append(balance["angle_deg"])
		var angle: float = deg_to_rad(balance["angle_deg"])
		near(float(balance["moment"]) * cos(angle) - float(balance["stiffness"]) * sin(angle), 0, 1e-9, "rotated attitude balances turning and elastic moments")
		check(balance["cm"] < balance["cb"], "valve shifts the mass centre neckward relative to buoyancy")
		print("TRIM ", index, " angle=", balance["angle_deg"], " torque=", balance["moment"], " net=", balance["net_force"])
	check(attitudes[0] < attitudes[2] and attitudes[2] < attitudes[1] and attitudes[1] < 0 and attitudes[3] > 0, "four reference presets have distinct supported attitudes")
	var middle: Dictionary = BathysLearningModels.cylinder_trim(BathysLearningModels.cylinder_buoyancy_state(false, 100), density)
	check(middle["moment"] > 0 and middle["net_force"] < 0, "part-filled aluminium can have a rising base while remaining negative overall")
	for steel: bool in [true, false]:
		var previous: float = -90
		for pressure: int in [200, 150, 100, 50, 0]:
			var balance: Dictionary = BathysLearningModels.cylinder_trim(BathysLearningModels.cylinder_buoyancy_state(steel, pressure), density)
			check(balance["angle_deg"] > previous, "using air continuously increases base-up tendency")
			previous = balance["angle_deg"]
	root.size = Vector2i(1440, 1050)
	root.get_node("I18n").set_language("en", false)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	app.acknowledge_educational_use()
	await settle(app)
	var before: String = JSON.stringify(app.plan)
	var history: int = app.undo_stack.size()
	app.set_learning_mode(true)
	var view: BathysLearningView = app.learning_view
	view.select_lesson("buoyancy")
	var lesson: BathysBuoyancyLesson = view.buoyancy_view
	var ui: BathysLessonPresentation = view.presentation
	ui.note_button.button_pressed = false
	for index: int in 4:
		lesson.apply_cylinder_preset(index)
		await create_timer(1.5).timeout
		await layout()
		check(lesson.diagram.cylinder_mode and ui.widgets.has("pressure"), "selecting a preset shows the supported cylinder and pressure gauge")
		near(lesson.diagram.cylinder_tilt_deg, attitudes[index], 0.2, "preset animates to its own attitude")
		await capture("res://Screenshots/trim-preset-" + str(index) + ".png")
	lesson.inputs["pressure"].value = 100
	await create_timer(1.5).timeout
	check(lesson.diagram.cylinder_tilt_deg > 10 and lesson.result["net_force"] < 0 and lesson.parameters()["immersion"] == 100, "pressure gauge shows tail-up rotation without floating the supported cylinder")
	await capture("res://Screenshots/trim-aluminium-100.png")
	var diagram: BathysBuoyancyDiagram = lesson.diagram
	var start: Vector2 = diagram.global_position + diagram.cylinder_base()
	var target: Vector2 = diagram.global_position + diagram.cylinder_pivot() + Vector2(150, 80)
	await drag(start, target)
	check(diagram.cylinder_tilt_deg < 0, "dragging the base directly tilts the cylinder")
	await create_timer(1.5).timeout
	check(diagram.cylinder_tilt_deg > 10, "release returns towards the supported attitude")
	var plot: Rect2 = diagram.cylinder_curve_rect()
	await click(diagram.global_position + Vector2(plot.position.x + plot.size.x * 0.25, plot.get_center().y))
	near(lesson.parameters()["pressure"], 50, 1, "dragging or touching the chart changes cylinder pressure")
	check(lesson.cylinder_buttons[3].button_pressed, "returning to reserve highlights its preset")
	view.lesson_scroll.ensure_control_visible(diagram)
	await layout()
	diagram.grab_focus()
	for code: int in [KEY_HOME, KEY_UP]:
		var key := InputEventKey.new()
		key.pressed = true
		key.keycode = code
		Input.parse_input_event(key)
		await layout()
	near(diagram.cylinder_tilt_deg, 5, 0.01, "keyboard can hold and tilt the base")
	var release := InputEventKey.new()
	release.pressed = true
	release.keycode = KEY_ENTER
	Input.parse_input_event(release)
	await create_timer(1.5).timeout
	check(diagram.cylinder_tilt_deg > 30 and not diagram.cylinder_keyboard_hold, "Enter releases the cylinder")
	ui.note_button.button_pressed = true
	await layout()
	check(lesson.assumptions.text.contains("3 N m") and lesson.assumptions.text.contains("not measured"), "information explains the illustrative support and angle limits")
	await capture("res://Screenshots/trim-model-info.png")
	ui.note_button.button_pressed = false
	lesson.set_stage(true)
	await layout()
	check(not diagram.cylinder_mode and not ui.widgets.has("pressure"), "gas-at-depth experiment keeps its original instruments")
	lesson.set_stage(false)
	await layout()
	check(diagram.cylinder_mode and ui.widgets.has("pressure"), "returning to displacement retains cylinder state")
	root.get_node("I18n").set_language("fr", false)
	root.size = Vector2i(390, 900)
	lesson.apply_cylinder_preset(3)
	await create_timer(1.5).timeout
	await layout()
	check(view.get_combined_minimum_size().x <= 390 and TranslationServer.translate("Neck support") == "Appui au col", "French cylinder experiment fits a phone")
	await capture("res://Screenshots/trim-fr-phone.png")
	view.lesson_scroll.ensure_control_visible(diagram)
	await layout()
	view.lesson_scroll.scroll_vertical += roundi(diagram.global_position.y - view.lesson_scroll.global_position.y)
	await layout()
	await capture("res://Screenshots/trim-scene-fr-phone.png")
	# A single-touch drag uses the same scene manipulation as the other lessons.
	start = diagram.global_position + diagram.cylinder_base()
	target = diagram.global_position + diagram.cylinder_pivot() + Vector2(130, 40)
	await touch(0, true, start)
	await move_touch(0, target)
	await touch(0, false, target)
	check(diagram.cylinder_tilt_deg < 0 and not diagram.dragging, "touch can tilt and release the base on a phone")
	await create_timer(1.5).timeout
	view.lesson_scroll.ensure_control_visible(ui.widgets["pressure"])
	await layout()
	await capture("res://Screenshots/trim-instruments-fr-phone.png")
	lesson.inputs["mass"].value += 1
	await layout()
	check(not diagram.cylinder_mode and not ui.widgets.has("pressure"), "manual mass edits return to the free-body experiment")
	check(JSON.stringify(app.plan) == before and app.undo_stack.size() == history, "cylinder trim experiment leaves scenario and history unchanged")
	root.get_node("I18n").set_language("en", false)
	app.queue_free()
	await layout()
	print("CYLINDER TRIM failures=", failures)
	quit(1 if failures else 0)
