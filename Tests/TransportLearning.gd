extends "res://Tests/LessonIntuition.gd"

func run() -> void:
	root.size = Vector2i(1280, 1050)
	root.get_node("I18n").set_language("en", false)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	await settle(app)
	app.set_learning_mode(true)
	var view: BathysLearningView = app.learning_view
	view.presentation.note_button.button_pressed = false
	check(view.TOPICS.size() == 21, "five physics topics extend navigation without replacing earlier lessons")
	for kind: String in BathysTransportLessons.KINDS:
		view.select_lesson(kind)
		await layout()
		check(view.transport_view.is_visible_in_tree() and not view.diagram.visible and visible_sliders(view) == 0, "visual-only transport lesson opens: " + kind)
		await capture("res://Screenshots/transport-" + kind + "-en.png")
		for index: int in view.transport_view.stage_buttons.size():
			view.transport_view.set_stage(index)
			await layout()
			check(view.get_combined_minimum_size().x <= 1280, "desktop stage fits: " + kind + str(index))
			await capture("res://Screenshots/transport-" + kind + "-" + str(index) + "-en.png")
	var lesson: BathysTransportLessons = view.transport_view
	var ui: BathysLessonPresentation = view.presentation
	var plan_before: String = JSON.stringify(app.plan)
	var history_before: int = app.undo_stack.size()
	view.select_lesson("viscosity")
	await layout()
	var scene: BathysTransportDiagram = lesson.diagram
	var width: float = scene.section(0).size.x
	var untouched: String = JSON.stringify(lesson.parameters())
	await drag(scene.global_position + Vector2(30, 320), scene.global_position + Vector2(70, 320))
	check(JSON.stringify(lesson.parameters()) == untouched, "dragging empty scene space does not alter the experiment")
	var from := scene.global_position + Vector2(width - 65, scene.plate_y() - 15)
	await drag(from, from + Vector2((width - 100) * 0.25, 0))
	near(lesson.parameters()["speed"], 0.45, 0.011, "moving the plate changes its speed")
	from = scene.global_position + Vector2(width - 24, scene.plate_y())
	await drag(from, from + Vector2(0, -25))
	near(lesson.parameters()["gap"], 10, 0.11, "plate spacing follows its vertical grip")
	var water_mu: float = lesson.result["properties"]["mu"]
	lesson.inputs["temperature"].value = 35
	check(lesson.result["properties"]["mu"] < water_mu, "thermometer changes the liquid viscosity and force")
	lesson.medium_picker.select(2)
	lesson.medium_picker.item_selected.emit(2)
	await layout()
	check(ui.widgets.has("mixture"), "dilute-gas comparison exposes the shared mixture tank")
	await focus_visual(view, lesson.inputs["temperature"])
	var key := InputEventKey.new()
	key.keycode = KEY_HOME
	key.pressed = true
	Input.parse_input_event(key)
	await layout()
	near(lesson.parameters()["temperature"], 0, 0.001, "transport thermometer supports keyboard endpoints")
	key.pressed = false
	Input.parse_input_event(key)
	view.select_lesson("flow")
	await layout()
	var rect: Rect2 = scene.tube()
	from = scene.global_position + Vector2(rect.get_center().x, rect.position.y - 15)
	await drag(from, from + Vector2(0, -10))
	near(lesson.parameters()["diameter"], 15, 0.11, "tube opening directly controls diameter")
	rect = scene.tube()
	from = scene.global_position + Vector2(rect.end.x + 12, 168)
	await drag(from, from + Vector2((scene.section(0).size.x - 100) * 0.6 / 0.9 * 0.2, 0))
	near(lesson.parameters()["length"], 0.5, 0.011, "tube end controls physical length")
	lesson.inputs["flow"].value = 0.1
	check(lesson.result["regime"] == "Laminar", "slow-flow example produces ordered layers")
	lesson.inputs["flow"].value = 60
	check(lesson.result["regime"] == "Turbulent", "fast-flow example produces mixing")
	await capture("res://Screenshots/transport-flow-drag-en.png")
	view.select_lesson("heat_transfer")
	lesson.set_stage(0)
	await layout()
	from = scene.global_position + Vector2(scene.cold_x() + 22, 168)
	await drag(from, from + Vector2(maxf(30, scene.section(0).size.x - 180) * 5 / 19, 0))
	near(lesson.parameters()["gap"], 10, 0.11, "dragging the cold face thickens the conducting layer")
	var transfer: float = lesson.result["heat"]
	lesson.medium_picker.select(1)
	lesson.medium_picker.item_selected.emit(1)
	check(lesson.result["heat"] < transfer / 20, "air-water comparison keeps layer geometry fixed")
	lesson.set_stage(2)
	await layout()
	check(not lesson.uses_mixture() and ui.widgets.has("emissivity") and ui.widgets.has("hot"), "radiation has surface-temperature and finish instruments")
	var finish: BathysLessonInstrument = ui.widgets["emissivity"]
	view.lesson_scroll.ensure_control_visible(finish)
	await layout()
	await drag(finish.global_position + Vector2(38, 55), finish.global_position + Vector2(38 + (finish.size.x - 76) * 0.5, 55))
	near(lesson.parameters()["emissivity"], 0.53, 0.011, "surface finish visually controls emissivity")
	view.select_lesson("thermal_properties")
	lesson.set_stage(0)
	await layout()
	lesson.material_picker.select(3)
	lesson.material_picker.item_selected.emit(3)
	await layout()
	check(ui.widgets.has("mixture") and ui.widgets.has("energy"), "gas storage exposes mixture and energy instruments")
	lesson.inputs["oxygen"].value = 0
	lesson.inputs["helium"].value = 100
	lesson.basis_picker.select(1)
	lesson.basis_picker.item_selected.emit(1)
	await layout()
	near(lesson.parameters()["energy"], 0.5, 0.001, "equal-volume comparison uses a suitable energy range without an input-signal jump")
	var energy: BathysLessonInstrument = ui.widgets["energy"]
	view.lesson_scroll.ensure_control_visible(energy)
	await layout()
	await drag(energy.global_position + Vector2(energy.size.x / 2, 121 - 73 * 0.5), energy.global_position + Vector2(energy.size.x / 2, 121 - 73 * 0.75))
	near(lesson.parameters()["energy"], 0.75, 0.011, "battery-shaped control adds heat visually")
	check(lesson.result["rise"] > 0 and lesson.result["properties"]["cp"] > 5000, "helium sample preserves its physical heat capacity")
	await capture("res://Screenshots/transport-helium-storage-en.png")
	lesson.set_stage(1)
	await layout()
	await capture("res://Screenshots/transport-helium-conduction-en.png")
	view.select_lesson("sound")
	lesson.set_stage(1)
	await layout()
	lesson.boundary_picker.select(1)
	lesson.boundary_picker.item_selected.emit(1)
	near(lesson.result["reflection"], 0, 1e-12, "water-water interface removes reflection")
	lesson.boundary_picker.select(2)
	lesson.boundary_picker.item_selected.emit(2)
	check(lesson.result["reflection"] > 0.8, "steel interface has a distinct reflection")
	lesson.set_stage(2)
	await layout()
	lesson.inputs["range"].value = 1000
	var attenuation: float = lesson.result["absorption"]
	lesson.inputs["frequency"].value = 100
	check(lesson.result["absorption"] > attenuation and scene.reference_curve.size() == 61, "frequency changes absorption independently of spreading")
	await capture("res://Screenshots/transport-sound-high-frequency-en.png")
	lesson.set_stage(3)
	await layout()
	view.lesson_scroll.scroll_vertical = 0
	await layout()
	from = scene.global_position + scene.source_position()
	var head := Vector2(scene.section(0).size.x / 2, 166)
	await drag(from, scene.global_position + head + Vector2(70, 0))
	near(lesson.parameters()["bearing"], 90, 0.11, "sound source can be dragged around the head")
	check(absf(lesson.result["delay_water"]) < absf(lesson.result["delay_air"]), "source motion updates both timing cues")
	ui.chart_button.button_pressed = false
	await layout()
	check(scene.custom_minimum_size.y <= 380, "transport comparison can hide while the experiment remains compact")
	ui.note_button.button_pressed = true
	await layout()
	check(lesson.assumptions.is_visible_in_tree() and lesson.source_links.is_visible_in_tree(), "full model limits and primary references remain available")
	ui.note_button.button_pressed = false
	ui.chart_button.button_pressed = true
	root.get_node("I18n").set_language("fr", false)
	root.size = Vector2i(390, 900)
	for kind: String in BathysTransportLessons.KINDS:
		view.select_lesson(kind)
		await layout()
		var count: int = maxi(1, lesson.stage_buttons.size())
		for stage: int in count:
			if not lesson.stage_buttons.is_empty(): lesson.set_stage(stage)
			await layout()
			check(view.get_combined_minimum_size().x <= 390 and visible_sliders(view) == 0 and visible_paragraphs(view) == 0, "French visual-only phone stage fits: " + kind + str(stage))
			check(TranslationServer.translate(view.title_label.text) != view.title_label.text, "French title: " + kind)
			await capture("res://Screenshots/transport-" + kind + "-" + str(stage) + "-fr-phone.png")
			view.lesson_scroll.scroll_vertical = 10000
			await layout()
			await capture("res://Screenshots/transport-" + kind + "-" + str(stage) + "-instruments-fr-phone.png")
			view.lesson_scroll.scroll_vertical = 0
	view.select_lesson("heat_transfer")
	lesson.set_stage(1)
	ui.note_button.button_pressed = true
	await layout()
	check(TranslationServer.translate(lesson.assumptions.text).begins_with("Surfaces"), "French scientific limits retain the convection model distinctions")
	view.lesson_scroll.scroll_vertical = 10000
	await capture("res://Screenshots/transport-heat-notes-fr-phone.png")
	ui.note_button.button_pressed = false
	view.select_lesson("flow")
	near(lesson.parameters()["diameter"], 15, 0.11, "transport state survives stage, language and topic changes")
	check(JSON.stringify(app.plan) == plan_before and app.undo_stack.size() == history_before, "all new experiments preserve the dive plan and undo history")
	root.get_node("I18n").set_language("en", false)
	app.queue_free()
	await layout()
	print("TRANSPORT LEARNING failures=", failures)
	quit(1 if failures else 0)
