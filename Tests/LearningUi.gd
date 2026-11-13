extends SceneTree

var failures: int = 0

func check(ok: bool, message: String) -> void:
	if ok: print("LEARNING PASS: ", message)
	else:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func layout() -> void:
	for i: int in 5:
		await process_frame

func settle(app: Control) -> void:
	await layout()
	if is_instance_valid(app.learning_view.presentation): app.learning_view.presentation.expand_all()
	while app.simulation_busy or app.sim_debounce >= 0:
		await process_frame
	await layout()

func click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
		await layout()

func focus_visual(view: BathysLearningView, source: HSlider) -> void:
	for widget: Control in view.presentation.widgets.values():
		if widget is BathysLessonInstrument and widget.source == source:
			view.lesson_scroll.ensure_control_visible(widget)
			await layout()
			widget.grab_focus()
			return
	check(false, "source has a visible keyboard instrument")

func capture(path: String) -> void:
	await layout()
	if "--visual" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	root.size = Vector2i(1280, 1000)
	var localization := root.get_node("I18n")
	localization.set_language("en", false)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	app.acknowledge_educational_use()
	await settle(app)
	check(not app.learning_mode and not app.learning_view.visible, "dive workspace is the default")
	check(app.workspace_switch.text.is_empty() and app.workspace_switch.tooltip_text == "Open learning workspace", "header switch has icons and a descriptive tooltip")
	app.plan = BathysPlan.example(app.site)
	app.plan["waypoints"] = [app.plan["waypoints"][0]]
	app.refresh_all()
	app.request_simulation()
	await settle(app)
	app.seek(35)
	app.map.magnification = 1.6
	app.right_panel.hide()
	var before: String = JSON.stringify(app.plan)
	var history: int = app.undo_stack.size()
	app.playing = true
	await click(app.workspace_switch.get_global_rect().get_center())
	check(app.learning_mode and app.learning_view.visible and not app.content_box.visible and not app.bottom_panel.visible, "switch opens a dedicated learning workspace")
	check(not app.playing and app.playback_time >= 35, "entering a lesson pauses simulation")
	var paused_time: float = app.playback_time
	check(not app.find_child("PlanName", true, false).is_visible_in_tree() and app.language_button.is_visible_in_tree(), "learning header keeps language selection and hides scenario actions")
	var view: BathysLearningView = app.learning_view
	check(view.topic_buttons.size() == 21 and view.lesson == "boyle", "left navigation includes all twenty-one lessons")
	view.slider.value = 0
	check(view.readout_values[0].text == "1.00 bar" and view.readout_values[1].text == "1.00 L", "surface reference is one litre at one bar absolute")
	view.slider.value = 10
	check(view.readout_values[0].text == "2.00 bar" and view.readout_values[1].text == "0.50 L" and view.diagram.depth_m == 10, "ten metres doubles pressure and halves volume")
	view.slider.value = 30
	check(view.readout_values[1].text == "0.25 L", "thirty metres gives a quarter of the surface volume")
	view.slider.value = 10
	await capture("res://Screenshots/learning-boyle-en.png")
	var scene: Rect2 = view.diagram.bubble_rect()
	await click(view.diagram.global_position + Vector2(scene.size.x * 0.3, 96 + (scene.size.y - 150) * 0.5))
	check(is_equal_approx(view.depth_m, 20), "direct interaction in the water updates the depth slider")
	view.diagram.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	Input.parse_input_event(key)
	await layout()
	check(view.depth_m > 20, "direct scene supports keyboard adjustment")
	key.pressed = false
	Input.parse_input_event(key)
	await click((view.topic_buttons["snell"] as Button).get_global_rect().get_center())
	check(view.lesson == "snell" and not view.presets.visible, "topic button selects optics controls")
	view.slider.value = 30
	check(absf(float(BathysLessonDiagram.refraction(30, false)["angle"]) - 22.03) < 0.02, "air to water at thirty degrees refracts to about twenty-two degrees")
	check(not bool(BathysLessonDiagram.refraction(30, false)["tir"]), "air-to-water ray is transmitted")
	await click(view.diagram.global_position + view.diagram.size * 0.5 + Vector2(-70, -70))
	check(absf(view.angle_deg - 45) < 0.2, "dragging the incident side updates the ray angle")
	view.direction_picker.select(1)
	view.direction_picker.item_selected.emit(1)
	view.slider.value = 30
	check(float(BathysLessonDiagram.refraction(30, true)["angle"]) > 30, "water-to-air ray bends away from the normal")
	check(absf(BathysLessonDiagram.critical_angle() - 48.6066) < 0.001, "critical angle follows the chosen refractive indices")
	view.slider.value = 60
	check(view.readout_values[1].text == "No transmitted ray" and bool(BathysLessonDiagram.refraction(60, true)["tir"]), "above the critical angle the diagram shows total internal reflection")
	await capture("res://Screenshots/learning-snell-en.png")
	localization.set_language("fr", false)
	await layout()
	check(TranslationServer.translate(view.title_label.text) == "Loi de Snell-Descartes" and TranslationServer.translate(view.insight_label.text).contains("Réflexion"), "lesson headings and live explanations translate into French")
	check(view.angle_deg == 60 and view.from_water, "language switch preserves experiment settings")
	await capture("res://Screenshots/learning-snell-fr.png")
	view.select_lesson("boyle")
	check(view.depth_m > 20 and view.readout_values[1].get_theme_font_size("font_size") == 20, "returning to a lesson restores experiment state and numeric styling")
	root.size = Vector2i(560, 1000)
	await layout()
	check(view.layout.vertical and view.diagram.custom_minimum_size.y == 510, "narrow layout stacks navigation and the pressure-volume graph")
	check(view.get_combined_minimum_size().x <= 560 and view.diagram.size.x <= 560, "French learning view fits a narrow window")
	await capture("res://Screenshots/learning-boyle-fr-narrow.png")
	root.size = Vector2i(390, 900)
	view.select_lesson("snell")
	await layout()
	check(view.get_combined_minimum_size().x <= 390 and view.readouts.columns == 1, "French angle controls and readouts fit a phone width")
	await capture("res://Screenshots/learning-snell-fr-phone.png")
	app.learning_view.lesson_scroll.scroll_vertical = 10000
	await layout()
	await capture("res://Screenshots/learning-snell-fr-phone-bottom.png")
	view.select_lesson("boyle")
	root.size = Vector2i(1280, 1000)
	await layout()
	app.set_learning_mode(false)
	await layout()
	check(not app.learning_view.visible and app.content_box.visible and app.bottom_panel.visible, "switch returns to the dive workspace")
	check(JSON.stringify(app.plan) == before and app.undo_stack.size() == history, "learning experiments do not modify the plan or undo history")
	check(app.playback_time == paused_time and app.map.magnification == 1.6 and not app.right_panel.visible, "returning preserves time, map zoom and collapsed panels")
	app.set_learning_mode(true)
	await layout()
	check(view.lesson == "boyle" and view.depth_m > 20, "experiments survive workspace switching")
	localization.set_language("en", false)
	app.queue_free()
	await layout()
	quit(1 if failures else 0)
