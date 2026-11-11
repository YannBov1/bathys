extends "res://Tests/LessonIntuition.gd"

func timeline_point(profile: BathysBuhlmannProfile, minutes: float) -> Vector2:
	return profile.global_position + Vector2(profile.sample(minutes, 0).x, 202)

func run() -> void:
	root.size = Vector2i(1280, 1100)
	var localization := root.get_node("I18n")
	localization.set_language("en", false)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	await settle(app)
	app.set_learning_mode(true)
	var view: BathysLearningView = app.learning_view
	view.presentation.note_button.button_pressed = false
	view.select_lesson("buhlmann")
	var lesson: BathysBuhlmannLesson = view.buhlmann_view
	lesson.set_stage(true)
	lesson.inputs["exposure_depth"].value = 30
	lesson.inputs["exposure_time"].value = 30
	lesson.inputs["preview_depth"].value = 9
	lesson.inputs["wait"].value = 20
	await layout()
	var profile: BathysBuhlmannProfile = lesson.profile
	var definition := Vector4(lesson.exposure_depth, lesson.exposure_minutes, lesson.preview_depth, lesson.wait_minutes)
	var plan_before: String = JSON.stringify(app.plan)
	var initial: float = (1 - BathysPhysics.WATER_VAPOUR_BAR) * 0.79
	for minute: float in [0.0, 4.0, 29.999, 30.0, 40.0, 50.0]:
		var sample_at: Dictionary = BathysBuhlmannLessonModel.at_time(30, 30, 9, 20, 0.3, 0.85, true, minute)
		var reference: Dictionary = BathysBuhlmannLessonModel.snapshot(30, minf(minute, 30), 9, maxf(0, minute - 30), 0.3, 0.85, minute >= 30)
		for index: int in 16:
			near((sample_at["model"] as BathysTissue).n2[index], (reference["model"] as BathysTissue).n2[index], 1e-12, "sample matches tissue solution at %.3f min, compartment %d" % [minute, index + 1])
	await click(timeline_point(profile, 0))
	near(lesson.cursor_minutes, 0, 0.01, "time rail reaches the beginning")
	near((lesson.state["model"] as BathysTissue).n2[0], initial, 1e-10, "scrubbing to zero restores initial surface-equilibrated tissues")
	await drag(timeline_point(profile, 0), timeline_point(profile, 4))
	near(lesson.cursor_minutes, 4, 0.02, "dragging the time rail scrubs time")
	var expected: BathysTissue = BathysBuhlmannLessonModel.loaded_tissues(30, 4)
	near((lesson.state["model"] as BathysTissue).n2[0], expected.n2[0], 1e-5, "four-minute compartment is half loaded at its half-time")
	check(not lesson.diagram.ascent and lesson.diagram.exposure_minutes == lesson.cursor_minutes, "loading bars and curve show the cursor state during exposure")
	await capture("res://Screenshots/profile-playback-loading-en.png")
	await click(timeline_point(profile, 40))
	var sampled: Dictionary = BathysBuhlmannLessonModel.snapshot(30, 30, 9, 10, 0.3, 0.85, true)
	near((lesson.state["model"] as BathysTissue).n2[0], (sampled["model"] as BathysTissue).n2[0], 1e-5, "wait playback advances from the fully loaded exposure state")
	near(lesson.profile.cursor_depth, 9, 1e-10, "playhead depth follows the wait segment")
	check(lesson.diagram.ascent, "wait playback displays the matching GF comparison")
	var after: float = (lesson.state["model"] as BathysTissue).n2[0]
	await click(timeline_point(profile, 10))
	expected = BathysBuhlmannLessonModel.loaded_tissues(30, 10)
	near((lesson.state["model"] as BathysTissue).n2[0], expected.n2[0], 1e-5, "backward scrubbing recomputes exactly without accumulated integration error")
	check(Vector4(lesson.exposure_depth, lesson.exposure_minutes, lesson.preview_depth, lesson.wait_minutes) == definition, "scrubbing leaves the profile definition untouched")
	# A click in the plot away from the edit handles is also a seek gesture.
	await click(profile.global_position + Vector2(profile.sample(8, 0).x, profile.chart().position.y + 8))
	near(lesson.cursor_minutes, 8, 0.02, "profile background supports direct time selection")
	await click(profile.play_button.get_global_rect().get_center())
	check(lesson.playing and profile.play_button.icon.resource_path.ends_with("pause.svg"), "play button starts animation and becomes pause")
	var playing_from: float = lesson.cursor_minutes
	var tissue_before_play: float = (lesson.state["model"] as BathysTissue).n2[0]
	await create_timer(0.2).timeout
	check(lesson.cursor_minutes > playing_from and (lesson.state["model"] as BathysTissue).n2[0] > tissue_before_play, "playback advances cursor and tissue loading")
	await click(profile.play_button.get_global_rect().get_center())
	var paused_at: float = lesson.cursor_minutes
	await create_timer(0.15).timeout
	near(lesson.cursor_minutes, paused_at, 1e-12, "pause freezes the cursor")
	check(not lesson.playing and profile.play_button.icon.resource_path.ends_with("play.svg"), "pause restores the play icon")
	lesson.seek_profile(lesson.total_minutes() - 0.05)
	lesson.toggle_playback()
	await create_timer(0.1).timeout
	check(not lesson.playing and lesson.cursor_minutes == lesson.total_minutes(), "playback stops exactly at the profile end")
	sampled = BathysBuhlmannLessonModel.snapshot(30, 30, 9, 20, 0.3, 0.85, true)
	near((lesson.state["model"] as BathysTissue).n2[15], (sampled["model"] as BathysTissue).n2[15], 1e-10, "playback endpoint matches the original snapshot model")
	lesson.toggle_playback()
	check(lesson.playing and lesson.cursor_minutes == 0, "play at the end restarts at the beginning")
	lesson.seek_profile(4)
	profile.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_4
	key.pressed = true
	Input.parse_input_event(key)
	await layout()
	key = key.duplicate()
	key.keycode = KEY_RIGHT
	Input.parse_input_event(key)
	await layout()
	near(lesson.cursor_minutes, 4.1, 0.001, "keyboard playhead moves in bounded increments")
	key.pressed = false
	Input.parse_input_event(key)
	lesson.toggle_playback()
	view.select_lesson("fick")
	await layout()
	check(not lesson.playing, "leaving the lesson pauses its playback")
	var exchange: BathysExchangeLesson = view.exchange_view
	var regions: Array[Rect2] = [exchange.diagram.reservoir_rect(0), exchange.diagram.reservoir_rect(1)]
	exchange.inputs["area"].value = 0.2
	exchange.inputs["thickness"].value = 4
	check(exchange.diagram.reservoir_rect(0) == regions[0] and exchange.diagram.reservoir_rect(1) == regions[1], "changing barrier geometry preserves lung and blood region sizes and positions")
	await capture("res://Screenshots/profile-fixed-reservoirs-en.png")
	view.select_lesson("dalton")
	await layout()
	var tank: BathysLessonGasMixture = view.presentation.widgets["mixture"]
	view.extra_sliders["helium"].value = 0
	view.lesson_scroll.ensure_control_visible(tank)
	await layout()
	await drag(tank.global_position + Vector2(17, tank.divider(0)), tank.global_position + Vector2(17, 20))
	near(view.oxygen_percent, 0, 0.001, "oxygen divider reaches the tank's physical top without a dead zone")
	near(tank.divider(0), 20, 0.001, "zero oxygen divider aligns with the top interior edge")
	await capture("res://Screenshots/profile-mixture-top-en.png")
	localization.set_language("fr", false)
	await layout()
	for pair: Array in [["Fairy", "Fée"], ["Computer", "Ordinateur"], ["Freediving Buoy", "Bouée d'apnée"], ["Scilure Tree", "Arbre à scilure"], ["Scilure tree", "Arbre à scilure"]]:
		check(TranslationServer.translate(pair[0]) == pair[1], "French POI translation: " + pair[0])
	view.select_lesson("buhlmann")
	lesson.seek_profile(40)
	await layout()
	await capture("res://Screenshots/profile-playback-wait-fr.png")
	root.size = Vector2i(390, 900)
	await layout()
	check(view.get_combined_minimum_size().x <= 390 and profile.play_button.get_global_rect().end.x <= 390, "French profile and playback button fit a phone")
	await click(timeline_point(profile, 5))
	near(lesson.cursor_minutes, 5, 0.02, "phone profile scrubbing follows the same time scale")
	await capture("res://Screenshots/profile-playback-fr-phone.png")
	view.select_lesson("fick")
	await layout()
	await capture("res://Screenshots/profile-fixed-reservoirs-fr-phone.png")
	app.set_learning_mode(false)
	await layout()
	for poi: Dictionary in app.site.pois:
		if poi["name"] in ["Fairy", "Computer", "Freediving Buoy", "Scilure Tree"]:
			app.on_poi_clicked(poi)
			await layout()
			check(TranslationServer.translate(poi["name"]) != poi["name"], "map POI title has a French caption")
			app.dismiss_inspection()
	check(JSON.stringify(app.plan) == plan_before and app.undo_stack.is_empty(), "lesson playback and scrubbing preserve the dive plan and history")
	localization.set_language("en", false)
	app.queue_free()
	await layout()
	print("PROFILE PLAYBACK failures=", failures)
	quit(1 if failures else 0)
