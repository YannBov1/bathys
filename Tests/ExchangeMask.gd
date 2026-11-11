extends "res://Tests/BreathingLearning.gd"

func physics() -> void:
	var p: Dictionary = {"source": 100.0, "initial": 40.0, "area": 1.0, "thickness": 1.0, "permeability": 1.0, "capacity": 1.0, "time": 0.0}
	var state: Dictionary = BathysExchangeModels.exchange(p)
	near(state["receiver"], 40, 1e-12, "Fick receiver begins at its own initial pressure")
	near(state["flux"], 1, 1e-12, "unit geometry and 60 mmHg define one relative initial transfer")
	var initial_case: Dictionary = BathysExchangeModels.exchange(p, 1)
	var faster: Dictionary = p.duplicate()
	faster["area"] = 2.0
	var faster_case: Dictionary = BathysExchangeModels.exchange(faster, 1)
	check(faster_case["initial_flux"] > initial_case["initial_flux"] and faster_case["flux"] < initial_case["flux"] and faster_case["transferred"] > initial_case["transferred"], "faster uptake can leave a smaller later rate while delivering more gas overall")
	p["area"] = 2.0
	near(BathysExchangeModels.exchange(p)["flux"], 2, 1e-12, "doubling area doubles rate at unchanged gradient")
	p["thickness"] = 2.0
	near(BathysExchangeModels.exchange(p)["flux"], 1, 1e-12, "doubling thickness cancels the doubled area")
	p["permeability"] = 2.0
	near(BathysExchangeModels.exchange(p)["flux"], 2, 1e-12, "permeability scales membrane transfer")
	p.merge({"area": 1.0, "thickness": 1.0, "permeability": 1.0, "time": log(2)}, true)
	state = BathysExchangeModels.exchange(p)
	near(state["receiver"], 70, 1e-10, "normalized half-time closes half the initial pressure gap")
	near(state["flux"], 0.5, 1e-12, "transfer rate decreases with the remaining gradient")
	near(state["transferred"], 0.5, 1e-12, "receiver pressure storage conserves transferred amount")
	p["capacity"] = 2.0
	near(BathysExchangeModels.exchange(p)["half_time"], 2 * log(2), 1e-12, "doubling storage doubles equilibration half-time")
	near(BathysExchangeModels.exchange(p, 0)["flux"], 1, 1e-12, "storage changes the time response without changing initial diffusion rate")
	p.merge({"source": 40.0, "initial": 46.0}, true)
	state = BathysExchangeModels.exchange(p)
	check(state["flux"] < 0 and state["receiver"] < 46 and state["receiver"] > 40, "reversed CO2 gradient transfers toward the source without overshooting")
	p["source"] = 46.0
	state = BathysExchangeModels.exchange(p)
	near(state["flux"], 0, 1e-12, "equal partial pressures give zero net exchange")
	near(state["receiver"], 46, 1e-12, "balanced receiver does not change pressure")
	var finite: bool = true
	for area: float in [0.2, 2]:
		for thickness: float in [0.25, 4]:
			for capacity: float in [0.5, 6]:
				p.merge({"source": 1800.0, "initial": 0.0, "area": area, "thickness": thickness, "capacity": capacity, "time": 5.0, "permeability": 3.0}, true)
				state = BathysExchangeModels.exchange(p)
				finite = finite and is_finite(state["flux"]) and float(state["receiver"]) >= 0 and float(state["receiver"]) <= 1800
	check(finite, "all supported barrier/storage extremes stay finite and monotonic")
	var m: Dictionary = {"distance": 1.0, "height": 0.2, "gap": 35.0, "thickness": 4.0, "glass_index": 1.5}
	var mask: Dictionary = BathysMaskOptics.trace(m)
	near(sin(mask["theta_air"]), 1.5 * sin(mask["theta_glass"]), 1e-12, "Snell invariant holds at the glass-air face")
	near(1.5 * sin(mask["theta_glass"]), 1.333 * sin(mask["theta_water"]), 1e-12, "Snell invariant holds at the water-glass face")
	near(float(mask["glass_y"]) + float(m["distance"]) * tan(mask["theta_water"]), 0.1, 1e-12, "three-segment trace reaches the selected real target edge")
	near(float(mask["apparent"]) * tan(mask["theta_air"]), 0.1, 1e-12, "straight-line back projection reaches the same selected edge height")
	check(mask["magnification"] > 1.3 and mask["magnification"] < 1.333 and mask["apparent"] < mask["actual"], "normal flat-mask geometry appears larger in angle and closer")
	check(mask["theta_glass"] < mask["theta_water"] and mask["theta_air"] > mask["theta_glass"], "water-glass bends toward normal and glass-air away")
	m.merge({"water_index": 1.0, "air_index": 1.0, "glass_index": 1.0}, true)
	mask = BathysMaskOptics.trace(m)
	near(mask["magnification"], 1, 1e-12, "index-matched media have no angular magnification")
	near(mask["apparent"], mask["actual"], 1e-12, "index-matched straight rays retain actual distance")
	m.merge({"water_index": 1.333, "glass_index": 1.5, "gap": 0.0, "thickness": 0.0, "height": 0.00001}, true)
	mask = BathysMaskOptics.trace(m)
	near(mask["magnification"], 1.333, 1e-8, "small-angle water-air limit gives the familiar 1.333 angular ratio")
	near(float(mask["apparent"]) / float(mask["actual"]), 1 / 1.333, 1e-8, "small-angle apparent distance approaches inverse water index")
	m.merge({"gap": 35.0, "thickness": 4.0, "height": 0.2}, true)
	var thin: Dictionary = BathysMaskOptics.trace(m)
	m["thickness"] = 12.0
	var thick: Dictionary = BathysMaskOptics.trace(m)
	check(thick["apparent"] > thin["apparent"] and absf(thick["glass_y"] - thin["glass_y"]) > 0.0001, "finite window thickness changes the internal path and projected distance")
	m["glass_index"] = 1.7
	check(absf(float(BathysMaskOptics.trace(m)["theta_air"]) - float(thick["theta_air"])) > 0.00001, "window refractive index affects both-interface endpoint geometry")
	finite = true
	for d: float in [0.5, 3]:
		for height: float in [0.05, 0.4]:
			for gap: float in [15, 80]:
				for index: float in [1.34, 1.7]:
					m.merge({"distance": d, "height": height, "gap": gap, "glass_index": index}, true)
					mask = BathysMaskOptics.trace(m)
					finite = finite and is_finite(mask["magnification"]) and mask["magnification"] > 1 and float(mask["mask_angle"]) < deg_to_rad(60)
	check(finite, "mask controls stay finite and within the comparison angular field at all limits")

func run() -> void:
	physics()
	root.size = Vector2i(1280, 1050)
	var localization := root.get_node("I18n")
	localization.set_language("en", false)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	await settle(app)
	var before: String = JSON.stringify(app.plan)
	var history: int = app.undo_stack.size()
	app.set_learning_mode(true)
	await layout()
	var view: BathysLearningView = app.learning_view
	await choose(view, "fick")
	var lesson: BathysExchangeLesson = view.exchange_view
	check(lesson.visible and not view.diagram.visible and view.CATEGORIES[1][1].has("fick"), "Fick lesson opens under physiology with its own controls")
	await capture("res://Screenshots/learning-fick-lungs-en.png")
	var rect: Rect2 = lesson.diagram.plot_rect()
	await click(lesson.diagram.global_position + rect.position + rect.size * Vector2(0.5, 0.5))
	near(lesson.parameters()["time"], 2.5, 0.02, "draggable equilibration curve scrubs contact time")
	lesson.inputs["area"].value = 2
	near(lesson.result["initial_flux"], 2, 1e-12, "area slider updates initial rate and the equilibration curve")
	view.lesson_scroll.ensure_control_visible(lesson.preset_rows["lungs"])
	await layout()
	await click(lesson.preset_rows["lungs"].get_child(1).get_global_rect().get_center())
	check(lesson.result["flux"] < 0, "CO2 pressure example reverses the net transfer arrow")
	await capture("res://Screenshots/learning-fick-co2-en.png")
	view.lesson_scroll.scroll_vertical = 0
	await layout()
	await click(lesson.stage_buttons[1].get_global_rect().get_center())
	check(lesson.context == "tissues" and lesson.blocks["capacity"].visible and lesson.parameters()["area"] == 1, "tissue stage exposes storage with independent experiment state")
	lesson.preset_rows["tissues"].get_child(2).pressed.emit()
	check(lesson.parameters()["inert"] and lesson.inputs["source"].max_value == 1800 and lesson.result["flux"] > 0, "inert-gas uptake expands the pressure range and loads tissue")
	await capture("res://Screenshots/learning-fick-tissues-en.png")
	lesson.preset_rows["tissues"].get_child(3).pressed.emit()
	check(lesson.result["flux"] < 0, "inert-gas release follows the reversed tissue gradient")
	view.lesson_scroll.ensure_control_visible(lesson.inputs["capacity"])
	await layout()
	lesson.inputs["capacity"].grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	Input.parse_input_event(key)
	await layout()
	key.pressed = false
	Input.parse_input_event(key)
	check(lesson.parameters()["capacity"] > 3, "storage slider supports keyboard adjustment")
	await choose(view, "snell")
	check(view.diagram.visible and not view.mask_view.visible, "original single-boundary Snell experiment remains the default")
	view.from_water = true
	view.slider.value = 60
	check(view.readout_values[1].text == "No transmitted ray", "existing total internal reflection experiment remains intact")
	await click(view.snell_buttons[1].get_global_rect().get_center())
	var mask: BathysMaskLesson = view.mask_view
	check(view.snell_mask and mask.visible and not view.diagram.visible and not view.readouts.visible, "mask stage replaces the single-boundary controls")
	await capture("res://Screenshots/learning-mask-en.png")
	var previous: float = mask.result["theta_glass"]
	mask.inputs["glass_index"].value = 1.7
	check(mask.result["theta_glass"] < previous, "changing window index updates the internal ray angle")
	var eye_x: float = 30
	var scale: float = mask.diagram.scene_scale()
	await click(mask.diagram.global_position + Vector2(eye_x + (0.8 + 0.039) * scale, 190))
	near(mask.params["distance"], 0.8, 0.02, "dragging the real-object view changes distance")
	mask.inputs["height"].value = 0.4
	mask.inputs["distance"].value = 0.5
	mask.inputs["gap"].value = 15
	mask.inputs["thickness"].value = 12
	await capture("res://Screenshots/learning-mask-near-en.png")
	await click(view.snell_buttons[0].get_global_rect().get_center())
	check(view.diagram.visible and not mask.visible and view.angle_deg == 60 and view.from_water, "boundary stage restores its previous ray settings")
	await click(view.snell_buttons[1].get_global_rect().get_center())
	near(mask.params["height"], 0.4, 1e-12, "mask geometry survives switching stages")
	localization.set_language("fr", false)
	await layout()
	check(TranslationServer.translate(view.title_label.text).contains("masque") and TranslationServer.translate(mask.insight.text).contains("angle"), "mask title and explanation translate into French")
	await capture("res://Screenshots/learning-mask-fr.png")
	view.select_lesson("fick")
	check(lesson.context == "tissues" and lesson.parameters()["inert"], "tissue state survives other topics and languages")
	await capture("res://Screenshots/learning-fick-tissues-fr.png")
	lesson.set_context("lungs")
	check(lesson.parameters()["area"] == 2 and lesson.parameters()["source"] == 40, "lung pressure and area are retained separately")
	await capture("res://Screenshots/learning-fick-lungs-fr.png")
	root.size = Vector2i(390, 900)
	await layout()
	for context: String in ["lungs", "tissues"]:
		lesson.set_context(context)
		view.lesson_scroll.scroll_vertical = 0
		await layout()
		check(view.get_combined_minimum_size().x <= 390 and lesson.readouts.columns == 1, "French phone Fick controls fit in " + context)
		await capture("res://Screenshots/learning-fick-" + context + "-fr-phone.png")
		view.lesson_scroll.scroll_vertical = 600
		await capture("res://Screenshots/learning-fick-" + context + "-fr-phone-plot.png")
		view.lesson_scroll.scroll_vertical = 10000
		await capture("res://Screenshots/learning-fick-" + context + "-fr-phone-bottom.png")
	view.select_lesson("snell")
	await layout()
	check(view.snell_mask and mask.visible and view.get_combined_minimum_size().x <= 390 and mask.diagram.custom_minimum_size.y == 940, "French phone stacks mask overview, interface zoom and apparent-size comparison")
	await capture("res://Screenshots/learning-mask-fr-phone.png")
	view.lesson_scroll.scroll_vertical = 550
	await capture("res://Screenshots/learning-mask-fr-phone-zoom.png")
	view.lesson_scroll.scroll_vertical = 10000
	await capture("res://Screenshots/learning-mask-fr-phone-bottom.png")
	var index: int = view.topic_picker.get_item_index(15)
	view.topic_picker.select(index)
	view.topic_picker.item_selected.emit(index)
	check(view.lesson == "fick", "compact topic selector preserves existing IDs and selects the new physiology lesson")
	view.select_lesson("boyle")
	check(view.diagram.visible and not mask.visible and not lesson.visible and not view.snell_tabs.visible, "leaving both experiments restores generic lesson sections")
	app.set_learning_mode(false)
	check(JSON.stringify(app.plan) == before and app.undo_stack.size() == history, "exchange and mask experiments do not change the scenario or history")
	localization.set_language("en", false)
	app.queue_free()
	await layout()
	print("EXCHANGE MASK failures=", failures)
	quit(1 if failures else 0)
