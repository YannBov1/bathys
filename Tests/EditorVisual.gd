extends SceneTree
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
	await process_frame
	app.plan = BathysPlan.example(app.site)
	app.plan["waypoints"] = [app.plan["waypoints"][0], BathysPlan.hold("Hold", 30), BathysPlan.gas_switch("stage", "Switch to Stage")]
	BathysPlan.anchor_holds(app.plan, app.site)
	app.refresh_all()
	app.request_simulation()
	while app.simulation_busy:
		await process_frame
	await capture("res://Screenshots/editor-tools.png")
	var card: Node = app.tank_list.get_node("Tank_0")
	card.find_child("EditorToggle", true, false).pressed.emit()
	card = app.route_list.get_node("Route_0")
	card.find_child("EditorToggle", true, false).pressed.emit()
	await capture("res://Screenshots/editor-validate.png")
	card.find_child("EditorToggle", true, false).pressed.emit()
	card = app.route_list.get_node("Route_2")
	card.find_child("EditorToggle", true, false).pressed.emit()
	await capture("res://Screenshots/editor-gas-switch.png")
	quit()

