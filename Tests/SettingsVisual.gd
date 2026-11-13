extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func capture(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	root.size = Vector2i(1280, 1000)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	app.acknowledge_educational_use()
	await process_frame
	app.on_poi_clicked(app.site.pois[1])
	app.add_inspected_waypoint()
	app.add_tank()
	while app.simulation_busy:
		await process_frame
	for index: int in [7, 8, 9]:
		app.toggle_metric(index)
	await capture("res://Screenshots/settings-header.png")
	app.toggle_side_panel(true)
	app.toggle_side_panel(false)
	await capture("res://Screenshots/map-panels-collapsed.png")
	app.toggle_side_panel(true)
	app.toggle_side_panel(false)
	await process_frame
	var bytes: PackedByteArray = await app.capture_map_jpg()
	var decoded := Image.new()
	if decoded.load_jpg_from_buffer(bytes) != OK or decoded.get_width() != int(app.view_container.size.x):
		failures += 1
		push_error("2D map JPEG does not match the displayed view")
	else:
		decoded.save_jpg("res://Screenshots/map-export-2d.jpg")
	app.show_3d()
	await process_frame
	bytes = await app.capture_map_jpg()
	if decoded.load_jpg_from_buffer(bytes) != OK:
		failures += 1
		push_error("3D map JPEG did not decode")
	else:
		decoded.save_jpg("res://Screenshots/map-export-3d.jpg")
	app.open_settings()
	await capture("res://Screenshots/gas-settings.png")
	app.settings_inputs["ppO2Min"].get_line_edit().text = "2"
	app.settings_dialog.confirmed.emit()
	if not app.settings_error.visible or not app.settings_dialog.visible:
		failures += 1
		push_error("Invalid settings were not retained for correction")
	print("SETTINGS_VISUAL failures=", failures)
	quit(0 if failures == 0 else 1)
