extends "res://Tests/LessonIntuition.gd"

func run() -> void:
	root.size = Vector2i(1440, 1050)
	root.get_node("I18n").set_language("en", false)
	var source := "<gpx version='1.1'><trk><trkseg><trkpt lat='46.2135' lon='7.3315'><ele>9999</ele></trkpt><trkpt lat='46.2136' lon='7.3316'/></trkseg><trkseg><trkpt lat='46.2137' lon='7.3317'/></trkseg></trk><rte><rtept lat='46.2134' lon='7.3314'/><rtept lat='46.2135' lon='7.3315'/></rte><wpt lat='46.2135' lon='7.3315'/></gpx>"
	var data: Dictionary = BathysGpxOverlay.parse(source)
	check(data["error"].is_empty() and data["segments"].size() == 3 and data["points"].size() == 2 and data["point_count"] == 6, "GPX tracks, separate segments, routes and standalone points are retained")
	var prefixed: Dictionary = BathysGpxOverlay.parse("<g:gpx xmlns:g='http://www.topografix.com/GPX/1/0'><g:trk><g:trkseg><g:trkpt lat='46.21393704' lon='7.33105492'/><g:trkpt lat='46.21393704' lon='7.33105492'/></g:trkseg></g:trk></g:gpx>")
	check(prefixed["error"].is_empty() and prefixed["segments"][0].size() == 2, "prefixed GPX 1.0 and repeated GPS fixes are supported")
	near(prefixed["segments"][0][0], 46.21393704, 1e-10, "latitude retains double precision")
	for invalid: String in ["", "<html/>", "<gpx><trk></gpx>", "<gpx><trk>", "<gpx/>", "<gpx/><gpx/>", "<!DOCTYPE gpx><gpx/>"]:
		check(not BathysGpxOverlay.parse(invalid)["error"].is_empty(), "malformed/empty GPX is rejected: " + invalid)
	var split: Dictionary = BathysGpxOverlay.parse("<gpx><trk><trkseg><trkpt lat='1' lon='2'/><trkpt lat='NaN' lon='2'/><trkpt lat='3' lon='4'/></trkseg></trk></gpx>")
	check(split["skipped"] == 1 and split["segments"].size() == 2, "invalid coordinates create a gap rather than joining unrelated points")
	var synthetic := BathysSite.new()
	synthetic.width = 3
	synthetic.height = 3
	synthetic.spacing = 1
	synthetic.max_n = 2
	synthetic.grid.resize(40 + 3 * 3 * 4)
	for i: int in 9: synthetic.grid.encode_u16(40 + 18 + i * 2, 7000)
	synthetic.grid.encode_u16(40 + 18 + 2, 7200)
	synthetic.grid.encode_u16(40 + 18 + 6, 7300)
	synthetic.grid.encode_u16(40 + 18 + 8, 7700)
	near(BathysGpxOverlay.elevation(BathysGpxOverlay.triangle_at(synthetic, Vector2(0.2, 0.8)), Vector2(0.2, 0.8)), 473.2, 0.0001, "southwest triangle matches the prepared mesh diagonal")
	near(BathysGpxOverlay.elevation(BathysGpxOverlay.triangle_at(synthetic, Vector2(0.8, 0.2)), Vector2(0.8, 0.2)), 472.6, 0.0001, "northeast triangle matches the prepared mesh diagonal")
	synthetic.grid.encode_u16(40 + 18 + 6, 65535)
	check(BathysGpxOverlay.triangle_at(synthetic, Vector2(0.2, 0.8)).is_empty() and not BathysGpxOverlay.triangle_at(synthetic, Vector2(0.8, 0.2)).is_empty(), "missing terrain excludes only the unsupported triangle")
	var cuts: Array[float] = [0, 1]
	BathysGpxOverlay.add_cuts(cuts, 0.2, 3.2, Vector2(0, 1))
	check(cuts.size() == 5, "long track legs split at every crossed mesh boundary")
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	app.acknowledge_educational_use()
	await settle(app)
	app.learning_view.presentation.note_button.button_pressed = false
	var plan_before: String = JSON.stringify(app.plan)
	var history_before: int = app.undo_stack.size()
	var camera_pan := Vector2(10, -15)
	app.map.pan = camera_pan
	app.map.magnification = 1.5
	app.open_settings()
	await layout()
	var tabs: TabContainer = app.settings_dialog.get_node("SettingsTabs")
	tabs.current_tab = 1
	await layout()
	check(app.settings_dialog.find_child("LoadGpx", true, false) != null and app.gpx_overlays.is_empty(), "map settings expose GPX loading without a default track")
	app.import_gpx()
	await layout()
	var chooser: FileDialog = app.settings_dialog.get_node("GpxFileChooser")
	check(chooser.file_mode == FileDialog.FILE_MODE_OPEN_FILES and chooser.filters[0].contains("*.gpx"), "native chooser supports multiple GPX files")
	var folder: String = ProjectSettings.globalize_path("user://gpx-picker-tests")
	DirAccess.make_dir_recursive_absolute(folder)
	for filename: String in ["First.gpx", "Broken.gpx", "Second.gpx"]:
		var fixture := FileAccess.open(folder.path_join(filename), FileAccess.WRITE)
		fixture.store_string("<gpx>" if filename == "Broken.gpx" else source)
		fixture.close()
	chooser.current_dir = folder
	chooser.hide()
	chooser.canceled.emit()
	await layout()
	app.import_gpx()
	await layout()
	chooser = app.settings_dialog.get_node("GpxFileChooser")
	check(chooser.current_dir == folder, "cancelled GPX picker remembers the browsed folder")
	await capture("res://Screenshots/gpx-picker-multiple-en.png")
	chooser.hide()
	chooser.files_selected.emit(PackedStringArray([folder.path_join("First.gpx"), folder.path_join("Broken.gpx"), folder.path_join("Second.gpx")]))
	await layout()
	check(app.gpx_overlays.size() == 2 and app.map.gpx_geometry.size() == 2 and not app.gpx_batch_active, "multiple selection imports all valid files even when a middle file fails")
	check(app.gpx_status.text.contains("Loaded GPX files: 2") and app.gpx_status.text.contains("Broken.gpx"), "batch summary reports success and identifies failed files")
	app.remove_gpx(1)
	app.remove_gpx(0)
	app.settings_dialog.hide()
	app.open_settings()
	await layout()
	tabs = app.settings_dialog.get_node("SettingsTabs")
	tabs.current_tab = 1
	app.import_gpx()
	await layout()
	chooser = app.settings_dialog.get_node("GpxFileChooser")
	check(chooser.current_dir == folder, "selected directory survives closing and reopening settings in the same session")
	chooser.hide()
	chooser.canceled.emit()
	await layout()
	var save_picker := FileDialog.new()
	save_picker.access = FileDialog.ACCESS_FILESYSTEM
	save_picker.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_picker.current_file = "Scenario.json"
	root.add_child(save_picker)
	app.configure_file_directory(save_picker)
	check(save_picker.current_dir == folder, "other desktop file actions reuse the session folder")
	check(save_picker.current_file == "Scenario.json", "restoring a save folder preserves the suggested filename")
	save_picker.queue_free()
	check(app.accept_gpx(source, "Example.gpx"), "GPX import succeeds from the shared native/browser text entry point")
	check(app.map.gpx_geometry.size() == 1 and app.gpx_list.get_child_count() == 1, "2D map and settings list receive the overlay")
	check(not app.accept_gpx("<gpx>", "Broken.gpx") and app.gpx_overlays.size() == 1, "failed imports preserve existing overlays")
	app.on_gpx_callback(["", "Too big.gpx", "large"])
	check(app.gpx_overlays.size() == 1 and app.gpx_status.text.contains("10 MB"), "browser size failures preserve the map and show feedback")
	app.on_gpx_callback([source, "Browser.gpx", ""])
	check(app.gpx_overlays.size() == 2, "browser file callback imports selected text and filename")
	app.remove_gpx(1)
	app.on_gpx_callback(["", "", "begin"])
	app.on_gpx_callback([source, "Browser first.gpx", ""])
	app.on_gpx_callback(["", "Browser failed.gpx", "read"])
	app.on_gpx_callback([source, "Browser second.gpx", ""])
	check(app.gpx_overlays.size() == 3 and app.map.gpx_geometry.size() == 1, "browser batch defers map rebuilding until all files are processed")
	app.on_gpx_callback(["", "", "end"])
	check(app.map.gpx_geometry.size() == 3 and app.gpx_status.text.contains("Browser failed.gpx"), "browser batch keeps valid files and reports read failures")
	app.remove_gpx(2)
	app.remove_gpx(1)
	var prepared: Dictionary = app.gpx_overlays[0]["geometry"]
	check(not prepared["paths"].is_empty(), "lake track has draped geometry")
	var clearance_ok: bool = true
	var samples: int = 0
	for path: PackedVector3Array in prepared["paths"]:
		for i: int in range(1, path.size()):
			var p: Vector3 = (path[i - 1] + path[i]) / 2
			var g: Vector2 = BathysGpxOverlay.grid_at(app.site, Vector2(p.x, -p.z))
			var triangle: Dictionary = BathysGpxOverlay.triangle_at(app.site, g)
			if triangle.is_empty(): continue
			samples += 1
			clearance_ok = clearance_ok and absf(p.y + app.site.waterline - BathysGpxOverlay.elevation(triangle, g) - 1) < 0.01
	check(clearance_ok and samples > 10, "draped track stays 1 m above each terrain triangle, ignoring GPX elevation")
	var examples: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--examples="): examples = arg.trim_prefix("--examples=")
	if not examples.is_empty():
		var selected := PackedStringArray()
		for filename: String in DirAccess.get_files_at(examples):
			if filename.get_extension().to_lower() != "gpx": continue
			selected.append(examples.path_join(filename))
		var count_before: int = app.gpx_overlays.size()
		app.load_gpx_files(selected)
		check(app.gpx_overlays.size() == count_before + selected.size(), "all user example GPX files import together in one batch")
	await capture("res://Screenshots/gpx-settings-en.png")
	app.settings_dialog.confirmed.emit()
	check(not app.settings_dialog.visible and app.undo_stack.size() == history_before, "Done closes map settings without applying dive parameters or adding history")
	app.map.reset_view()
	await layout()
	await capture("res://Screenshots/gpx-satellite-en.png")
	app.set_bathymetry(true)
	await layout()
	await capture("res://Screenshots/gpx-bathymetry-en.png")
	app.show_3d()
	await layout()
	check(app.lake.gpx_root.get_child_count() == app.gpx_overlays.size(), "lazy 3D view receives all overlays")
	var target: Vector3 = app.lake.target
	var distance: float = app.lake.distance
	app.set_gpx_visible(0, false)
	check(app.lake.gpx_root.get_child_count() == app.gpx_overlays.size() - 1 and app.map.gpx_geometry.size() == app.gpx_overlays.size() - 1, "visibility control updates both maps")
	app.set_gpx_visible(0, true)
	app.remove_gpx(0)
	check(app.lake.target == target and app.lake.distance == distance and app.map.pan == Vector2.ZERO, "overlay edits preserve 3D and 2D views")
	app.lake.set_waterline(app.site.waterline + 2)
	near(app.lake.gpx_root.position.y, -2, 0.001, "changing waterline keeps tracks fixed relative to the terrain")
	app.lake.set_waterline(app.site.waterline)
	app.lake.distance = 230
	app.lake.update_camera()
	await capture("res://Screenshots/gpx-3d-en.png")
	root.get_node("I18n").set_language("fr", false)
	root.size = Vector2i(390, 900)
	app.open_settings()
	await layout()
	tabs = app.settings_dialog.get_node("SettingsTabs")
	tabs.current_tab = 1
	await layout()
	check(app.settings_dialog.size.x <= 390 and app.settings_dialog.size.y < 900, "French phone settings stay inside the viewport")
	check(TranslationServer.translate("Map overlays") == "Calques de carte", "new settings and GPX feedback are translated")
	await capture("res://Screenshots/gpx-settings-fr-phone.png")
	tabs.current_tab = 0
	await layout()
	await capture("res://Screenshots/gpx-dive-settings-fr-phone.png")
	app.settings_dialog.hide()
	app.set_learning_mode(true)
	app.learning_view.select_lesson("viscosity")
	await layout()
	var scene: BathysTransportDiagram = app.learning_view.transport_view.diagram
	app.learning_view.transport_view.inputs["speed"].value = 0.5
	var before: float = scene.plate_travel
	scene._process(0.1)
	check(not is_equal_approx(scene.plate_travel, before), "upper plate texture moves at the selected speed")
	app.learning_view.transport_view.inputs["speed"].value = 0
	before = scene.plate_travel
	scene._process(0.1)
	near(scene.plate_travel, before, 0.0001, "plate texture stops at zero speed")
	await capture("res://Screenshots/viscosity-textured-fr-phone.png")
	root.size = Vector2i(1440, 1050)
	root.get_node("I18n").set_language("en", false)
	app.learning_view.transport_view.inputs["speed"].value = 0.5
	await layout()
	await capture("res://Screenshots/viscosity-textured-en.png")
	check(JSON.stringify(app.plan) == plan_before and app.undo_stack.size() == history_before, "GPX overlays and plate animation leave the dive plan and history unchanged")
	app.queue_free()
	await layout()
	print("GPX OVERLAY failures=", failures)
	quit(1 if failures else 0)
