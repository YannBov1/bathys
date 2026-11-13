extends SceneTree
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if ok:
		print("LANGUAGE PASS: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func settle(app: Control) -> void:
	while app.simulation_busy:
		await process_frame
	await process_frame
func capture(path: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args():
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	root.size = Vector2i(1280, 1000)
	var localization := root.get_node("I18n")
	if not FileAccess.file_exists(localization.PREFERENCE_PATH):
		check(localization.language == "en", "English is the default independent of system language")
	localization.set_language("en", false)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	app.acknowledge_educational_use()
	await settle(app)
	check(app.language_button.icon.resource_path.ends_with("flag-en.svg"), "English flag is shown initially")
	app.on_poi_clicked(app.site.pois[1])
	app.add_inspected_waypoint()
	app.add_tank()
	await settle(app)
	app.plan["tanks"][0]["name"] = "SAVE"
	app.refresh_tanks()
	app.seek(35)
	app.map.magnification = 1.5
	var plan_before: String = JSON.stringify(app.plan)
	var saved_before: String = app.saved_state
	localization.set_language("fr", false)
	await process_frame
	check(TranslationServer.translate("LOAD") == "CHARGER", "French interface catalog is active")
	check(app.language_button.icon.resource_path.ends_with("flag-fr.svg"), "French flag follows the current language")
	check(JSON.stringify(app.plan) == plan_before and app.saved_state == saved_before, "language switch preserves plan data and saved state")
	check(app.playback_time == 35 and app.map.magnification == 1.5, "language switch preserves playback and zoom")
	check(app.route_summaries[0].text.contains("vrai"), "formatted route summaries update in French")
	check((app.tank_list.find_child("name", true, false) as LineEdit).text == "SAVE", "user-provided names stay unchanged")
	app.show_language_menu()
	await capture("res://Screenshots/language-menu-fr.png")
	for child: Node in app.get_children():
		if child is PopupMenu and child != app.metrics_menu:
			check(child.get_item_text(0) == "English" and child.get_item_text(1) == "Français" and child.is_item_checked(1), "language menu shows native names and current selection")
			child.hide()
	await capture("res://Screenshots/language-french.png")
	app.open_settings()
	await process_frame
	check(app.settings_dialog.tr("Default SAC") == "SAC par défaut", "French settings include route defaults")
	await capture("res://Screenshots/language-settings-fr.png")
	app.settings_dialog.hide()
	app.on_poi_clicked(app.site.pois[2])
	await capture("res://Screenshots/language-location-fr.png")
	app.dismiss_inspection()
	root.size = Vector2i(390, 844)
	app.adapt_layout()
	await capture("res://Screenshots/language-narrow-fr.png")
	await process_frame
	await process_frame
	check(app.content_box.size.x <= 390, "French controls fit the narrow layout")
	root.size = Vector2i(1280, 1000)
	app.adapt_layout()
	localization.set_language("en", false)
	await process_frame
	check(app.language_button.icon.resource_path.ends_with("flag-en.svg") and app.route_summaries[0].text.contains("true"), "switching back restores English and its flag")
	check(JSON.stringify(app.plan) == plan_before, "repeated switching never translates stored content")
	app.apply_limits({"ppO2Min": 0.3, "ppO2WorkingMax": 1.4, "ppO2Max": 1.6, "densityWarning": 5.2, "densityMax": 6.2, "endMax": 30.0}, false)
	await settle(app)
	localization.set_language("fr", false)
	await settle(app)
	check(app.feedback_label.text.contains("plage") and app.feedback_label.text.contains("Étape"), "formatted simulation failures update in French")
	localization.set_language("en", false)
	app.queue_free()
	await process_frame
	print("LANGUAGE_CHECKS failures=", failures)
	quit(0 if failures == 0 else 1)
