extends SceneTree
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if ok:
		print("EDITOR PASS: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func settle(app: Control) -> void:
	while app.simulation_busy:
		await process_frame
	await process_frame
func run() -> void:
	root.size = Vector2i(1280, 1000)
	root.get_node("I18n").set_language("en", false)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	app.acknowledge_educational_use()
	await settle(app)
	app.plan = BathysPlan.example(app.site)
	app.refresh_all()
	app.request_simulation()
	await settle(app)
	var card: Control = app.route_list.get_node("Route_0")
	var button: Button = card.find_child("EditorToggle", true, false)
	var details: Control = card.find_child("InlineEditor", true, false)
	var name_input: LineEdit = card.find_child("name", true, false)
	check(button.text.is_empty() and button.icon.resource_path.ends_with("tools.svg") and not details.visible and not name_input.editable, "collapsed waypoint uses tools icon with read-only name")
	button.pressed.emit()
	check(details.visible and name_input.editable and button.icon.resource_path.ends_with("check.svg") and button.tooltip_text == "Validate changes", "opening waypoint switches to validate icon")
	var sac: SpinBox = details.find_child("sacLPerMin", true, false)
	sac.get_line_edit().text = "19.5"
	button.pressed.emit()
	check(not details.visible and app.plan["waypoints"][0]["sacLPerMin"] == 19.5 and button.icon.resource_path.ends_with("tools.svg"), "validate commits pending input and closes waypoint")
	await settle(app)
	card = app.tank_list.get_node("Tank_0")
	button = card.find_child("EditorToggle", true, false)
	details = card.find_child("InlineEditor", true, false)
	button.pressed.emit()
	var reserve: SpinBox = details.find_child("reserveGaugeBar", true, false)
	reserve.get_line_edit().text = "300"
	button.pressed.emit()
	check(details.visible and button.icon.resource_path.ends_with("check.svg") and details.get_node("EditorError").visible, "invalid tank stays open with inline validation error")
	reserve.get_line_edit().text = "50"
	button.pressed.emit()
	check(not details.visible and not details.get_node("EditorError").visible and button.icon.resource_path.ends_with("tools.svg"), "corrected tank validates and returns to tools icon")
	await settle(app)
	card = app.route_list.get_node("Route_2")
	button = card.find_child("EditorToggle", true, false)
	details = card.find_child("InlineEditor", true, false)
	button.pressed.emit()
	check(details.visible and details.find_child("holdSeconds", true, false) != null and button.icon.resource_path.ends_with("check.svg"), "holds use the same edit/validate flow")
	button.pressed.emit()
	card = app.route_list.get_node("Route_4")
	button = card.find_child("EditorToggle", true, false)
	details = card.find_child("InlineEditor", true, false)
	check(not details.visible, "gas selector starts collapsed")
	button.pressed.emit()
	var selector: OptionButton = details.find_child("tankId", true, false)
	check(details.visible and selector != null and button.icon.resource_path.ends_with("check.svg"), "gas switch exposes selector through tools icon")
	selector.select(0)
	selector.item_selected.emit(0)
	button.pressed.emit()
	check(not details.visible and app.plan["waypoints"][4]["tankId"] == app.plan["initialTankId"] and app.plan["waypoints"][4]["name"].contains("Back gas"), "gas selection and generated name validate together")
	root.get_node("I18n").set_language("fr", false)
	check(button.tr("Validate changes") == "Valider les modifications" and button.tr("Edit gas switch") == "Modifier le changement de gaz", "editor tooltips are available in French")
	root.get_node("I18n").set_language("en", false)
	await settle(app)
	print("EDITOR_CHECKS failures=", failures)
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
