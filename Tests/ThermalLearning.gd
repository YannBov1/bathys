extends "res://Tests/BreathingLearning.gd"

func physics() -> void:
	var model := BathysThermalModels.new()
	var cold: Dictionary = model.charles(20)
	near(cold["volume"], 1, 1e-12, "Charles reference is one litre at 293.15 K")
	near(model.charles(40)["volume"], 313.15 / 293.15, 1e-12, "20 to 40 Celsius gives 6.8 percent volume growth, not double")
	near(model.charles(313.15)["volume"], 2, 1e-12, "doubling kelvin doubles volume")
	near(model.charles(313.15)["speed"], sqrt(2), 1e-12, "molecular speed scales with the square root of absolute temperature")
	var p: Dictionary = {"temperature": 0.0, "amount": 1.0, "pressure": 1.0, "volume": 22.71095464, "solve": 1}
	var ideal: Dictionary = model.ideal(p)
	near(ideal["volume"], 22.7109546411497, 1e-8, "one mole at zero Celsius and one bar occupies 22.711 litres")
	near(ideal["pv"], ideal["nrt"], 1e-10, "bar litre conversion retains the PV = nRT energy identity")
	p["volume"] = ideal["volume"]
	p["solve"] = 0
	near(model.ideal(p)["pressure"], 1, 1e-10, "pressure and volume solutions invert each other")
	p["volume"] = float(ideal["volume"]) / 2
	near(model.ideal(p)["pressure"], 2, 1e-10, "halving rigid volume doubles ideal pressure at fixed n and T")
	p["amount"] = 2.0
	near(model.ideal(p)["pressure"], 4, 1e-10, "doubling gas amount doubles ideal pressure")
	var eos_match: bool = true
	var thermo_identity: bool = true
	for gas: int in 3:
		var x: Array = model.fractions(gas)
		var mixture: Dictionary = {"o2": x[0], "n2": x[1], "he": x[2]}
		for t: float in [253.15, 293.15, 353.15]:
			for pressure: float in [0.1, 1, 50, 200, 300]:
				var state: Dictionary = model.real(gas, pressure, t)
				var rho: float = BathysPhysics.gas_density(mixture, pressure, t - 273.15)
				var expected_z: float = pressure * 100000 * BathysPhysics.molar_mass(mixture) / (1000 * rho * model.R * t)
				eos_match = eos_match and absf(float(state["z"]) - expected_z) < 1e-9
				var h_p: float = (float(model.real(gas, pressure + 0.001, t)["h"]) - float(model.real(gas, pressure - 0.001, t)["h"])) / 200
				var v_t: float = (float(model.real(gas, pressure, t + 0.02)["molar_l"]) - float(model.real(gas, pressure, t - 0.02)["molar_l"])) / 40
				thermo_identity = thermo_identity and absf(h_p - (float(state["molar_l"]) / 1000 - t * v_t)) < 2e-8
	check(eos_match, "real-gas Z agrees with the existing planner density EOS across all gases and supported limits")
	check(thermo_identity, "enthalpy departure satisfies dH/dP = V minus T dV/dT independently of the root solver")
	var low: Dictionary = model.real(1, 0.001, 293.15)
	near(low["z"], 1, 0.000001, "dilute gas approaches the ideal limit")
	var helium: Dictionary = model.real(2, 300, 293.15)
	check(helium["z"] > 1.05 and helium["moles_12l"] < helium["ideal_moles_12l"], "positive Z departure reduces the gas amount in a fixed cylinder")
	near(helium["molar_l"] / helium["ideal_l"], helium["z"], 1e-12, "paired equal-mole volumes have ratio Z")
	near(helium["moles_12l"] / helium["ideal_moles_12l"], 1 / float(helium["z"]), 1e-12, "fixed-cylinder amount ratio is inverse Z")
	var nitrogen: Dictionary = model.cooling(1, 200, 10, 293.15, 0)
	var warm_helium: Dictionary = model.cooling(2, 200, 10, 293.15, 0)
	check(nitrogen["delta"] < 0 and nitrogen["mu"] > 0, "room-temperature nitrogen cools during the real-gas throttle")
	check(warm_helium["delta"] > 0 and warm_helium["mu"] < 0, "room-temperature helium warms during the real-gas throttle")
	near(model.cooling(0, 200, 10, 293.15, 1)["delta"], 0, 1e-12, "ideal-gas throttling conserves temperature")
	near(model.cooling(0, 100, 100, 293.15, 0)["delta"], 0, 1e-12, "no pressure drop has no throttling temperature change")
	var work: Dictionary = model.cooling(2, 200, 10, 293.15, 2)
	check(work["delta"] < 0 and work["work"] > 0, "ideal helium expansion doing work cools, despite its real throttle warming")
	near(work["tout"], 293.15 * pow(0.05, 0.4), 1e-10, "monatomic ideal isentropic exponent is two fifths")
	check(absf(float(nitrogen["delta"]) - float(nitrogen["mu"]) * (10 - 200)) > 1, "finite throttling is not a constant inlet-mu extrapolation")
	var all_valid: bool = true
	for gas: int in 3:
		for t: float in [253.15, 293.15, 353.15]:
			for pin: float in [2, 200, 300]:
				for pout: float in [1, pin]:
					var state: Dictionary = model.cooling(gas, pin, pout, t, 0)
					all_valid = all_valid and is_finite(state["tout"]) and float(state["tout"]) >= 180 and absf(state["h_error"]) < 0.00001
	check(all_valid, "all real-throttle endpoints remain single-phase and conserve enthalpy across the supported domain")

func run() -> void:
	physics()
	root.size = Vector2i(1280, 1050)
	var localization := root.get_node("I18n")
	localization.set_language("en", false)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	app.acknowledge_educational_use()
	await settle(app)
	var before: String = JSON.stringify(app.plan)
	var history: int = app.undo_stack.size()
	app.set_learning_mode(true)
	await layout()
	var view: BathysLearningView = app.learning_view
	await choose(view, "charles")
	var lesson: BathysThermalLessons = view.thermal_view
	check(lesson.visible and not view.diagram.visible and lesson.kind == "charles", "Charles lesson opens with its dedicated piston experiment")
	await capture("res://Screenshots/learning-charles-en.png")
	var rect: Rect2 = lesson.diagram.plot_rect()
	await click(lesson.diagram.global_position + rect.position + rect.size * Vector2(0.5, 0.5))
	lesson.refresh()
	near(lesson.result["kelvin"], 325, 0.06, "dragging the Charles curve selects absolute temperature")
	lesson.preset_rows["charles"].get_child(2).pressed.emit()
	near(lesson.result["volume"], 2, 1e-12, "double-kelvin preset moves piston to twice the reference volume")
	await capture("res://Screenshots/learning-charles-double-en.png")
	await choose(view, "ideal_gas")
	var reference_pressure: float = lesson.result["pressure"]
	(lesson.inputs["volume"] as HSlider).value = 1.25
	await create_timer(0.08).timeout
	near(lesson.result["pressure"], reference_pressure * 2, 1e-9, "vessel-volume slider updates the live ideal pressure")
	lesson.solve_picker.select(1)
	lesson.solve_picker.item_selected.emit(1)
	check(lesson.blocks["pressure"].visible and not lesson.blocks["volume"].visible, "volume-solve mode reveals pressure as the input")
	await capture("res://Screenshots/learning-ideal_gas-en.png")
	await focus_visual(view, lesson.inputs["amount"])
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	Input.parse_input_event(key)
	await layout()
	key.pressed = false
	Input.parse_input_event(key)
	check(lesson.parameters()["amount"] > 0.1, "mole slider supports keyboard adjustment")
	await choose(view, "real_gas")
	lesson.gas_picker.select(2)
	lesson.gas_picker.item_selected.emit(2)
	lesson.refresh()
	check(lesson.result["z"] > 1, "gas selector changes the real-gas model to helium")
	rect = lesson.diagram.plot_rect()
	await click(lesson.diagram.global_position + rect.position + rect.size * Vector2(0.5, 0.5))
	lesson.refresh()
	near(lesson.parameters()["pressure"], 150, 0.11, "dragging the Z curve selects pressure")
	await capture("res://Screenshots/learning-real_gas-en.png")
	await choose(view, "joule_thomson")
	check(lesson.result["delta"] < 0 and lesson.diagram.curve.size() == 31, "real throttle opens with a constant-enthalpy path")
	rect = lesson.diagram.plot_rect()
	await click(lesson.diagram.global_position + rect.position + rect.size * Vector2(0.5, 0.5))
	lesson.refresh()
	near(lesson.parameters()["outlet"], 100.5, 1, "dragging the thermal path selects outlet pressure")
	(lesson.inputs["inlet"] as HSlider).value = 50
	lesson.refresh()
	check(lesson.parameters()["outlet"] <= 50 and lesson.inputs["outlet"].max_value == 50, "outlet remains no greater than inlet when pressure is reduced")
	lesson.parameters().merge({"inlet": 200.0, "outlet": 10.0, "gas": 1}, true)
	lesson.refresh()
	await capture("res://Screenshots/learning-joule_thomson-en.png")
	lesson.gas_picker.select(2)
	lesson.gas_picker.item_selected.emit(2)
	lesson.refresh()
	check(lesson.result["delta"] > 0, "helium selector visibly changes cooling into warming")
	await capture("res://Screenshots/learning-joule-thomson-helium-en.png")
	for process: int in [1, 2]:
		lesson.process_picker.select(process)
		lesson.process_picker.item_selected.emit(process)
		check(absf(lesson.result["delta"]) < 1e-10 if process == 1 else lesson.result["work"] > 0, "process selector separates ideal throttle from ideal work expansion")
		await capture("res://Screenshots/learning-joule-thomson-process%d-en.png" % process)
	localization.set_language("fr", false)
	await layout()
	check(lesson.assumptions.text.begins_with("Modèle") and lesson.assumptions.text.contains("cryogéniques"), "conditional low-temperature model notes remain fully French")
	check(TranslationServer.translate(view.title_label.text).contains("refroidissement") and TranslationServer.translate(lesson.insight.text).contains("étranglement"), "French Joule–Thomson title and process explanation translate")
	for topic: String in lesson.KINDS:
		view.select_lesson(topic)
		await layout()
		await capture("res://Screenshots/learning-" + topic + "-fr.png")
	root.size = Vector2i(390, 900)
	await layout()
	for topic: String in lesson.KINDS:
		view.select_lesson(topic)
		await layout()
		check(view.get_combined_minimum_size().x <= 390 and lesson.readouts.columns == 1 and lesson.diagram.custom_minimum_size.y == 720, "French phone layout fits and stacks " + topic)
		await capture("res://Screenshots/learning-" + topic + "-fr-phone.png")
		view.lesson_scroll.scroll_vertical = 10000
		await layout()
		await capture("res://Screenshots/learning-" + topic + "-fr-phone-bottom.png")
	view.select_lesson("ideal_gas")
	var saved_ideal: Dictionary = lesson.parameters().duplicate()
	lesson.parameters().merge({"temperature": 150.0, "amount": 0.4, "pressure": 0.1}, true)
	lesson.refresh()
	view.lesson_scroll.scroll_vertical = 0
	await layout()
	check(view.get_combined_minimum_size().x <= 390 and lesson.result["volume"] > 100, "large computed ideal volume still fits the phone layout")
	await capture("res://Screenshots/learning-ideal-gas-max-volume-fr-phone.png")
	lesson.parameters().merge(saved_ideal, true)
	lesson.refresh()
	var index: int = view.topic_picker.get_item_index(12)
	view.topic_picker.select(index)
	view.topic_picker.item_selected.emit(index)
	check(lesson.kind == "ideal_gas" and int(lesson.parameters()["solve"]) == 1, "compact topic IDs preserve the new lessons and their independent state")
	view.select_lesson("charles")
	near(lesson.parameters()["temperature"], 313.15, 1e-10, "Charles experiment survives switching among other thermal lessons")
	view.select_lesson("colour")
	check(not lesson.visible and view.optics_view.visible, "other dedicated lessons restore normally")
	view.select_lesson("boyle")
	check(view.diagram.visible and not lesson.visible, "generic lesson controls restore normally")
	app.set_learning_mode(false)
	check(JSON.stringify(app.plan) == before and app.undo_stack.size() == history, "thermal experiments preserve scenario data and undo history")
	localization.set_language("en", false)
	app.queue_free()
	await layout()
	print("THERMAL LEARNING failures=", failures)
	quit(1 if failures else 0)
