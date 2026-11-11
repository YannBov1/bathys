extends "res://Tests/BreathingLearning.gd"

func physics() -> void:
	var engine := BathysUnderwaterOptics.new()
	check(engine.wavelengths.size() == 61 and engine.data["waters"].size() == 6, "offline spectra contain six traceable marine profiles at 5 nm")
	var profile: Dictionary = engine.water({"water": 2})
	near(profile["a"][26], 0.0806, 1e-10, "Jerlov III absorption at 530 nm matches the primary workbook")
	near(profile["b"][26], 0.291, 1e-10, "Jerlov III scattering at 530 nm matches the primary workbook")
	near(profile["kd"][26], 0.1168, 1e-10, "historical Jerlov III Kd at 530 nm matches the primary table")
	check(profile["iop_status"][0] == "model_extrapolation" and profile["iop_status"][3] == "ok", "measurement-band provenance flags survive export")
	for g: float in [0.0, 0.9, 0.98]:
		var integral: float = 0
		for i: int in 8192:
			var theta: float = PI * (i + 0.5) / 8192
			integral += engine.phase_hg(cos(theta), g) * sin(theta) * 2 * PI * PI / 8192
		near(integral, 1, 0.00003, "HG integrates to unit solid-angle probability at g = " + str(g))
		near(engine.cone_fraction(g, PI), 1, 1e-10, "full-sphere acceptance is unity")
		near(engine.cone_fraction(g, 0), 0, 1e-10, "zero cone accepts no scattered light")
	near(engine.phase_hg(0.3, 0), 1 / (4 * PI), 1e-12, "zero asymmetry gives isotropic scattering")
	near(engine.cone_fraction(0, PI / 2), 0.5, 1e-12, "isotropic scattering divides equally between hemispheres")
	var pure_absorb: PackedFloat64Array = engine.path_ambient(0.1, 0, 1, 10, 0.9, 0.7)
	near(pure_absorb[0], 0, 1e-12, "absorption without scattering produces no veil")
	var path: PackedFloat64Array = engine.path_ambient(0.1, 0.3, 2, 3, 0.9, 0.7)
	near(path[0] / path[1], 1 - exp(-0.4 * 3), 1e-12, "monochromatic path radiance obeys its source-term solution")
	check(engine.path_ambient(0.1, 0.3, 2, 10, 0.9, 0.7)[0] > path[0], "ambient backscatter grows toward its asymptote")
	for g: float in [0, 0.9, 0.98]:
		var recovered: float = engine.cone_fraction(g, deg_to_rad(10))
		var sum: float = exp(-0.4 * 8) + exp(-0.1 * 8) * (1 - exp(-0.3 * 8)) * recovered
		check(sum <= exp(-0.1 * 8) + 1e-12, "halo surrogate cannot exceed absorption-only energy bound")
	var p: Dictionary = {"water": 2, "depth": 0.0, "range": 0.0}
	var surface: Dictionary = engine.evaluate(p)
	near(surface["daylight_y"], 1, 0.000001, "surface daylight Y is normalized to unity")
	near(surface["transmission_y"], 1, 0.000001, "zero viewing path transmits the whole object signal")
	near(surface["back"].length(), 0, 1e-10, "zero viewing path has no backscatter")
	near(surface["forward"][1].length(), 0, 1e-10, "zero viewing path has no forward halo")
	check(surface["diagnostic"]["white"] == null, "zero-range effective coefficient is explicitly undefined")
	var white: Vector3 = surface["reference"][1]
	check(absf(white.x - 0.75) < 0.015 and absf(white.y - 0.75) < 0.015 and absf(white.z - 0.75) < 0.015, "truncated D65/CIE reference stays nearly neutral in linear sRGB")
	p["depth"] = 20.0
	p["range"] = 3.0
	var deep: Dictionary = engine.evaluate(p)
	check(float(deep["daylight_y"]) < 0.2 and float(deep["transmission_y"]) < 1, "depth and horizontal range attenuate distinct light paths")
	p["range"] = 8.0
	check(float(engine.evaluate(p)["transmission_y"]) < float(deep["transmission_y"]), "more viewing distance reduces direct transmission")
	p["depth"] = 0.0
	var short: Dictionary = engine.diagnostic(p, 1)
	var far: Dictionary = engine.diagnostic(p, 10)
	check(absf(short["white"] - short["red"]) > 0.01, "wideband direct attenuation depends on target reflectance")
	check(absf(short["white"] - short["back"]) > 0.001, "wideband direct and backscatter attenuation differ")
	check(absf(short["white"] - far["white"]) > 0.001, "effective direct coefficient changes with range")
	p.merge({"water": 2, "depth": 20.0, "range": 1.5, "torch": false}, true)
	var dark_red: Vector3 = engine.evaluate(p)["direct"][2]
	p["torch"] = true
	var lit_red: Vector3 = engine.evaluate(p)["direct"][2]
	check(lit_red.length() > dark_red.length() * 10, "nearby white torch restores a strong red signal lost from deep ambient light")
	var on_axis: float = engine.lamp_backscatter(0.1, 0.3, 3, 0, 8, 0.9)
	var off_axis: float = engine.lamp_backscatter(0.1, 0.3, 3, 0.8, 8, 0.9)
	check(off_axis < on_axis * 0.5 and engine.lamp_target(0.4, 3, 0.8, 8) > 0, "off-axis torch reduces nearby backscatter while illuminating the target")
	p["torch"] = true
	p["power"] = 0.0
	var unlit: Dictionary = engine.evaluate(p)
	p["torch"] = false
	var ambient: Dictionary = engine.evaluate(p)
	near((unlit["direct"][1] - ambient["direct"][1]).length(), 0, 1e-12, "zero-power torch returns exactly to ambient illumination")
	var finite: bool = true
	for water: int in 6:
		for depth: float in [0, 30]:
			p.merge({"water": water, "depth": depth, "range": 15.0, "g": 0.98, "torch": true, "power": 20.0}, true)
			var value: Dictionary = engine.evaluate(p)
			for rgb: Vector3 in value["direct"]: finite = finite and rgb.is_finite()
			finite = finite and (value["back"] as Vector3).is_finite() and is_finite(value["diagnostic"]["back"])
			finite = finite and float(value["veil_share"]) >= 0 and float(value["veil_share"]) <= 1
	check(finite, "all presets remain finite at supported depth, range and torch extremes")

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
	await choose(view, "colour")
	var lesson: BathysOpticsLesson = view.optics_view
	check(lesson.visible and not view.diagram.visible and not lesson.result.is_empty(), "colour lesson opens in physics with its own spectral model")
	check(lesson.plots.tooltip_text.contains("Drag the target"), "optical scene advertises direct target dragging")
	var original_transmission: float = lesson.result["transmission_y"]
	(lesson.inputs["range"] as HSlider).value = 4
	await create_timer(0.08).timeout
	check(float(lesson.result["transmission_y"]) < original_transmission, "coalesced slider updates refresh the preview while exploring")
	lesson.params["range"] = 3.0
	lesson.water_picker.select(4)
	lesson.water_picker.item_selected.emit(4)
	lesson.flush_update()
	check(lesson.params["water"] == 4 and lesson.result["transmission_y"] < original_transmission, "water selector applies the coastal optical table")
	lesson.params["water"] = 2
	lesson.flush_update()
	await capture("res://Screenshots/learning-colour-light-en.png")
	view.lesson_scroll.ensure_control_visible(lesson.torch_switch)
	await layout()
	await click(lesson.torch_switch.get_global_rect().get_center())
	lesson.flush_update()
	check(lesson.params["torch"] and lesson.blocks["baseline"].visible, "torch exposes lighting geometry controls")
	view.lesson_scroll.scroll_vertical = 0
	await capture("res://Screenshots/learning-colour-torch-en.png")
	lesson.component_picker.select(3)
	lesson.component_picker.item_selected.emit(3)
	check(lesson.preview_materials[1].get_shader_parameter("component") == 3, "component selector isolates the backscatter veil")
	await capture("res://Screenshots/learning-colour-backscatter-en.png")
	lesson.component_picker.select(0)
	lesson.component_picker.item_selected.emit(0)
	await click(lesson.stage_buttons[1].get_global_rect().get_center())
	check(lesson.stage == 1 and lesson.blocks["g"].visible and not lesson.preview_box.visible and not lesson.blocks["range"].visible, "water stage reveals phase assumptions and hides scene controls")
	await capture("res://Screenshots/learning-colour-properties-en.png")
	var rect: Rect2 = lesson.plots.plot(0)
	await click(lesson.plots.global_position + rect.position + rect.size * Vector2(0.5, 0.5))
	lesson.flush_update()
	near(lesson.params["probe"], 550, 5, "spectral plot supports direct wavelength selection")
	(lesson.inputs["g"] as HSlider).value = 0.5
	lesson.flush_update()
	check(lesson.result["back_fraction"] > 0.1, "phase slider updates backward scattering probability")
	await click(lesson.stage_buttons[2].get_global_rect().get_center())
	check(lesson.stage == 2 and lesson.plots.curves.size() == 51 and lesson.readouts.columns == 3, "model stage plots separate integrated coefficients")
	await capture("res://Screenshots/learning-colour-model-en.png")
	rect = lesson.plots.plot(0)
	await click(lesson.plots.global_position + rect.position + rect.size * Vector2(0.5, 0.5))
	lesson.flush_update()
	near(lesson.params["range"], 7.5, 0.1, "coefficient plot supports direct viewing-range control")
	view.lesson_scroll.ensure_control_visible(lesson.inputs["range"])
	await layout()
	lesson.inputs["range"].grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	Input.parse_input_event(key)
	await layout()
	key.pressed = false
	Input.parse_input_event(key)
	check(lesson.params["range"] > 7.5, "viewing-range slider supports keyboard adjustment")
	localization.set_language("fr", false)
	await layout()
	check(TranslationServer.translate(view.title_label.text) == "Les couleurs sous l’eau" and lesson.explanation.text.contains("CIE Y"), "French title and model explanation translate")
	view.lesson_scroll.scroll_vertical = 0
	await capture("res://Screenshots/learning-colour-model-fr.png")
	var previous_range: float = lesson.params["range"]
	lesson.params["range"] = 15.0
	lesson.flush_update()
	check(lesson.assumptions.text.begins_with("Modèle") and lesson.assumptions.text.contains("qualitativement"), "conditional thick-water model notes remain fully French")
	lesson.params["range"] = previous_range
	lesson.flush_update()
	root.size = Vector2i(390, 900)
	await layout()
	check(view.get_combined_minimum_size().x <= 390 and lesson.plots.custom_minimum_size.y == 600, "French phone layout stacks the two model plots")
	await capture("res://Screenshots/learning-colour-model-fr-phone.png")
	for stage: int in [0, 1]:
		lesson.set_stage(stage)
		view.lesson_scroll.scroll_vertical = 0
		await layout()
		check(view.get_combined_minimum_size().x <= 390 and lesson.readouts.columns == 1, "French controls fit phone width in stage " + str(stage))
		await capture("res://Screenshots/learning-colour-stage%d-fr-phone.png" % stage)
	view.select_lesson("boyle")
	check(not lesson.visible and view.diagram.visible, "generic lessons restore after leaving colour")
	view.select_lesson("colour")
	check(lesson.stage == 1 and lesson.params["torch"], "lesson exploration state survives switching topics")
	app.set_learning_mode(false)
	check(JSON.stringify(app.plan) == before and app.undo_stack.size() == history, "optical exploration never changes the dive plan or undo history")
	localization.set_language("en", false)
	app.queue_free()
	await layout()
	print("OPTICS LEARNING failures: ", failures)
	quit(1 if failures else 0)
