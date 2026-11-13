extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func capture(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	root.size = Vector2i(1280, 900)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	app.acknowledge_educational_use()
	await process_frame
	app.adapt_layout()
	await capture("res://Screenshots/ux-empty.png")
	app.on_poi_clicked(app.site.pois[1])
	await capture("res://Screenshots/ux-inspection.png")
	app.dismiss_inspection()
	root.size = Vector2i(390, 844)
	app.adapt_layout()
	await capture("res://Screenshots/ux-narrow.png")
	root.size = Vector2i(1280, 900)
	app.adapt_layout()
	app.on_poi_clicked(app.site.pois[1])
	app.add_inspected_waypoint()
	app.add_tank()
	while app.simulation_busy:
		await process_frame
	for i: int in range(10, 17):
		app.toggle_metric(i)
	await capture("res://Screenshots/ux-compact-route.png")
	quit()
