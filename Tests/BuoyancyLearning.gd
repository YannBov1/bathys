extends "res://Tests/BreathingLearning.gd"

func run() -> void:
	root.size = Vector2i(1280, 1050)
	var localization := root.get_node("I18n")
	localization.set_language("en", false)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	app.acknowledge_educational_use()
	await settle(app)
	var before: String = JSON.stringify(app.plan)
	app.map.magnification = 1.5
	app.set_learning_mode(true)
	await layout()
	var view: BathysLearningView = app.learning_view
	await choose(view, "buoyancy")
	var lesson: BathysBuoyancyLesson = view.buoyancy_view
	check(view.lesson == "buoyancy" and lesson.visible and not view.diagram.visible, "Archimedes lesson opens under physics")
	var force: Dictionary = BathysLearningModels.buoyancy(80, 80, 100, 1000)
	near(force["displaced_l"], 80, 1e-10, "fully submerged body displaces its volume")
	near(force["buoyant_force"], 784.532, 1e-8, "eighty litres of freshwater produces the weight of eighty kilograms in buoyancy")
	near(force["net_force"], 0, 1e-10, "weight equals buoyancy for equal body and displaced-water mass")
	force = BathysLearningModels.buoyancy(80, 80, 50, 1000)
	near(force["displaced_l"], 40, 1e-10, "only the immersed fraction displaces water")
	near(force["buoyant_force"], 392.266, 1e-8, "half immersion halves buoyancy")
	force = BathysLearningModels.buoyancy(80, 80, 0, 1000)
	check(force["buoyant_force"] == 0 and force["net_force"] < 0, "zero immersion has no water buoyancy")
	(lesson.inputs["immersion"] as HSlider).value = 50
	near(lesson.result["displaced_l"], 40, 1e-8, "immersion slider updates displacement readout and bucket")
	var water_y: float = lesson.diagram.waterline_y()
	await click(lesson.diagram.global_position + Vector2(lesson.diagram.section(0).size.x * 0.46, water_y + 25))
	await create_timer(1.0).timeout
	near(lesson.result["net_force"], 0, 1e-6, "released floating body settles to equal buoyancy and weight")
	await capture("res://Screenshots/learning-buoyancy-displacement-en.png")
	lesson.floating_button.pressed.emit()
	near(lesson.result["net_force"], 0, 1e-8, "floating equilibrium matches displaced-water weight to the body")
	check(lesson.parameters()["immersion"] < 100 and lesson.insight.text.begins_with("Balanced"), "floating body balances with partial immersion")
	await capture("res://Screenshots/learning-buoyancy-float-en.png")
	(lesson.inputs["mass"] as HSlider).value = 100
	check(lesson.floating_button.disabled and lesson.result["net_force"] < 0, "denser-than-water body cannot find a partially immersed floating equilibrium")
	(lesson.inputs["mass"] as HSlider).value = 75
	(lesson.inputs["immersion"] as HSlider).value = 100
	var fresh_force: float = lesson.result["buoyant_force"]
	lesson.water_buttons[1].pressed.emit()
	check(float(lesson.result["buoyant_force"]) > fresh_force, "sea water increases buoyancy at unchanged volume")
	await focus_visual(view, lesson.inputs["volume"])
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	Input.parse_input_event(key)
	await layout()
	check(lesson.parameters()["volume"] > 80, "volume slider supports keyboard control")
	key.pressed = false
	Input.parse_input_event(key)
	await click(lesson.stage_buttons[1].get_global_rect().get_center())
	check(lesson.at_depth and lesson.blocks["gas"].visible and not lesson.blocks["immersion"].visible, "second stage isolates fully submerged gas compression")
	var shallow: Dictionary = BathysLearningModels.buoyancy_at_depth(78, 75, 6, 0, 1000)
	var deep: Dictionary = BathysLearningModels.buoyancy_at_depth(78, 75, 6, 100000.0 / 9806.65, 1000)
	near(shallow["gas_volume_l"], 6, 1e-10, "surface gas starts at its stated volume")
	near(deep["gas_volume_l"], 3, 1e-10, "two bar absolute halves the trapped gas volume")
	near(shallow["buoyant_force"] - deep["buoyant_force"], 29.41995, 1e-7, "gas compression removes exactly the corresponding displaced-water buoyancy")
	var rigid_surface: Dictionary = BathysLearningModels.buoyancy_at_depth(78, 75, 0, 0, 1000)
	var rigid_deep: Dictionary = BathysLearningModels.buoyancy_at_depth(78, 75, 0, 40, 1000)
	near(rigid_surface["buoyant_force"], rigid_deep["buoyant_force"], 1e-10, "depth alone does not change buoyancy of a fully submerged rigid body")
	lesson.balance_button.pressed.emit()
	near(lesson.result["net_force"], 0, 1e-8, "depth balance sets the teaching mass to displaced-water mass")
	(lesson.inputs["depth"] as HSlider).value = 20
	check(float(lesson.result["net_force"]) < 0, "descending from balance produces less buoyancy with unchanged trapped gas")
	await capture("res://Screenshots/learning-buoyancy-depth-en.png")
	(lesson.inputs["depth"] as HSlider).value = 0
	check(float(lesson.result["net_force"]) > 0, "ascending from balance expands gas and produces upward net force")
	var plot: Rect2 = lesson.diagram.curve_rect()
	await click(lesson.diagram.global_position + plot.position + plot.size * Vector2(0.5, 0.4))
	near(lesson.parameters()["depth"], 20, 0.1, "dragging the force curve changes preview depth")
	localization.set_language("fr", false)
	await layout()
	check(TranslationServer.translate(view.title_label.text).contains("Archimède") and lesson.insight.text.contains("descendre"), "French lesson title and live force tendency translate")
	await capture("res://Screenshots/learning-buoyancy-depth-fr.png")
	lesson.set_stage(false)
	await capture("res://Screenshots/learning-buoyancy-displacement-fr.png")
	root.size = Vector2i(390, 900)
	await layout()
	check(view.get_combined_minimum_size().x <= 390 and lesson.diagram.custom_minimum_size.y == 580, "French phone layout stacks displacement and water-weight diagrams")
	await capture("res://Screenshots/learning-buoyancy-fr-phone.png")
	lesson.set_stage(true)
	await layout()
	check(view.get_combined_minimum_size().x <= 390 and lesson.readouts.columns == 1, "depth controls and force readouts fit the phone width")
	view.lesson_scroll.scroll_vertical = 10000
	await layout()
	await capture("res://Screenshots/learning-buoyancy-depth-fr-phone-bottom.png")
	view.select_lesson("oxygen")
	check(not lesson.visible and view.breathing_view.visible, "other interactive lessons restore their own controls")
	view.select_lesson("buoyancy")
	check(lesson.at_depth and lesson.parameters()["depth"] == 20 and lesson.seawater, "buoyancy experiment survives topic and language changes")
	app.set_learning_mode(false)
	await layout()
	check(JSON.stringify(app.plan) == before and app.undo_stack.is_empty() and app.map.magnification == 1.5, "buoyancy experiments preserve scenario, undo history and map")
	# The balance action must stay representable at the largest body/gas volumes.
	lesson.set_stage(true)
	(lesson.inputs["depth"] as HSlider).value = 0
	(lesson.inputs["volume"] as HSlider).value = 120
	(lesson.inputs["gas"] as HSlider).value = 15
	lesson.balance_button.pressed.emit()
	check(lesson.parameters()["mass"] <= (lesson.inputs["mass"] as HSlider).max_value, "balance action fits the mass control across the full volume range")
	near(lesson.result["net_force"], 0, 1e-8, "largest-volume body still balances correctly")
	localization.set_language("en", false)
	app.queue_free()
	await layout()
	quit(1 if failures else 0)
