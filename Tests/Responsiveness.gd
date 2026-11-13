extends SceneTree

var failed: int = 0

func check(condition: bool, title: String) -> void:
	if condition:
		print("PASS ", title)
	else:
		failed += 1
		push_error(title)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var site := BathysSite.new()
	check(site.load_packaged(), "site loads")
	var plan: Dictionary = BathysPlan.example(site)
	var baseline: Dictionary = await BathysSimulation.run(site, plan)
	var start_frame: int = Engine.get_process_frames()
	var cooperative: Dictionary = await BathysSimulation.run(site, plan, self)
	check(Engine.get_process_frames() > start_frame + 2, "calculation yields across rendered frames")
	check(JSON.stringify(cooperative) == JSON.stringify(baseline), "all cooperative simulation frames exactly match synchronous results")
	start_frame = Engine.get_process_frames()
	var cancelled: Dictionary = await BathysSimulation.run(site, plan, self,
		func() -> bool: return Engine.get_process_frames() > start_frame)
	check(bool(cancelled.get("cancelled", false)), "superseded calculation cancels at next batch")
	var app: Control = load("res://Main.tscn").instantiate() as Control
	root.add_child(app)
	app.acknowledge_educational_use()
	app.plan = BathysPlan.example(app.site)
	app.refresh_all()
	app.request_simulation()
	while app.simulation_busy:
		await process_frame
	app.clear_route()
	while app.simulation_busy:
		await process_frame
	app.on_poi_clicked(site.pois[1])
	app.add_inspected_waypoint()
	check(app.map.route.size() == 1 and app.simulation_busy, "map route updates before simulation completes")
	await process_frame
	check(app.map.route.size() == 1 and app.frames.is_empty(), "waypoint is drawable on the first frame before calculation")
	app.on_poi_clicked(site.pois[2])
	app.add_inspected_waypoint()
	while app.simulation_busy:
		await process_frame
	check(app.legs.size() == 2, "rapid successive clicks retain both waypoints and only publish latest simulation")
	check(app.site_list.find_children("*", "PanelContainer", true, false).is_empty(), "Site controls have no nested panels")
	check(not app.has_method("focus_poi"), "removed Site POI section has no remaining handler")
	app.queue_free()
	await process_frame
	print("RESPONSIVENESS failures=", failed)
	quit(0 if failed == 0 else 1)
