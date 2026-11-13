extends "res://Tests/LessonIntuition.gd"

var active_touches: Dictionary = {}
var tapped: int = 0

func touch(index: int, pressed: bool, at: Vector2, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	event.canceled = canceled
	if pressed: active_touches[index] = at
	else: active_touches.erase(index)
	Input.parse_input_event(event)
	await layout()

func move_touch(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	event.relative = at - Vector2(active_touches[index])
	active_touches[index] = at
	Input.parse_input_event(event)
	await layout()

func run() -> void:
	root.size = Vector2i(1280, 1000)
	root.get_node("I18n").set_language("en", false)
	var app: Control = load("res://Main.tscn").instantiate()
	root.add_child(app)
	await layout()
	check(app.educational_notice.visible and not app.educational_use_acknowledged, "new app session requires explicit educational-use acknowledgement")
	check(app.educational_notice.exclusive and not app.educational_notice.dialog_close_on_escape, "notice blocks the workspace and Escape dismissal")
	await capture("res://Screenshots/notice-en.png")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await layout()
	check(app.educational_notice.visible and not app.educational_use_acknowledged, "Escape does not agree to the notice")
	await click(app.tank_list.get_child(3).get_global_rect().get_center())
	check(app.plan["tanks"].is_empty() and app.educational_notice.visible, "clicking behind the notice does not create a tank or dismiss it")
	app.educational_notice.hide()
	app.educational_notice.canceled.emit()
	await layout()
	check(app.educational_notice.visible, "cancel requests cannot bypass the required acknowledgement")
	root.size = Vector2i(390, 780)
	app.educational_notice.language_picker.select(1)
	app.educational_notice.language_picker.item_selected.emit(1)
	await layout()
	check(root.get_node("I18n").language == "fr" and TranslationServer.translate(BathysEducationalNotice.NOTICE).begins_with("Bathys est"), "French can be chosen before agreeing")
	check(app.educational_notice.size.x <= 390 and app.educational_notice.size.y < 780, "French notice fits a phone")
	await capture("res://Screenshots/notice-fr-phone.png")
	root.size = Vector2i(780, 390)
	await layout()
	check(app.educational_notice.size.y <= 390 and app.educational_notice.get_ok_button().is_visible_in_tree(), "landscape phone keeps the notice action available with scrolling text")
	await capture("res://Screenshots/notice-fr-landscape.png")
	root.size = Vector2i(390, 780)
	await layout()
	var agree_at: Vector2 = Vector2(app.educational_notice.position) + app.educational_notice.get_ok_button().get_global_rect().get_center()
	await click(agree_at)
	await layout()
	check(app.educational_use_acknowledged and not app.educational_notice.visible, "explicit agreement opens the workspace")
	var repeated_warning: bool = false
	for label: Node in app.find_children("*", "Label", true, false):
		if label.is_visible_in_tree() and label.text.begins_with("EDUCATIONAL SOFTWARE ONLY"): repeated_warning = true
	check(not repeated_warning, "repeated warning footer is absent")
	app.show_educational_notice()
	await layout()
	check(app.educational_notice.dialog_close_on_escape and app.educational_notice.ok_button_text == "Close", "limits can be reopened without requiring a second agreement")
	app.educational_notice.hide()
	root.size = Vector2i(1280, 1000)
	root.get_node("I18n").set_language("en", false)
	await settle(app)
	var before_plan: String = JSON.stringify(app.plan)
	var before_history: int = app.undo_stack.size()
	var map: BathysSatelliteMap = app.map
	var center: Vector2 = map.global_position + map.size / 2
	await touch(0, true, center)
	await move_touch(0, center + Vector2(30, 20))
	await touch(0, false, center + Vector2(30, 20))
	near(map.pan.x, 30, 0.1, "one-finger 2D drag pans horizontally")
	near(map.pan.y, 20, 0.1, "one-finger 2D drag pans vertically")
	check(not is_instance_valid(app.inspection_overlay) or not app.inspection_overlay.visible, "2D drag does not inspect the map")
	map.reset_view()
	await touch(0, true, center - Vector2(40, 0))
	await touch(1, true, center + Vector2(40, 0))
	await move_touch(0, center - Vector2(70, 0))
	await move_touch(1, center + Vector2(70, 0))
	await touch(0, false, center - Vector2(70, 0))
	await touch(1, false, center + Vector2(70, 0))
	near(map.magnification, 1.75, 0.01, "two-finger 2D pinch scales continuously")
	check(map.navigation.touches.is_empty(), "all fingers are cleared after a pinch")
	var magnify := InputEventMagnifyGesture.new()
	magnify.position = center
	magnify.factor = 1.2
	var zoom_before: float = map.magnification
	var location_before: PackedFloat64Array = map.unproject(map.size / 2)
	Input.parse_input_event(magnify)
	await layout()
	near(map.magnification, zoom_before * 1.2, 0.01, "2D trackpad magnify event zooms")
	var location_after: PackedFloat64Array = map.unproject(map.size / 2)
	near(location_after[0], location_before[0], 1e-8, "2D zoom preserves the geographic point at its anchor")
	zoom_before = map.magnification
	Input.parse_input_event(magnify.duplicate())
	Input.parse_input_event(magnify.duplicate())
	await layout()
	near(map.magnification, zoom_before * 1.2 * 1.2, 0.01, "identical consecutive trackpad samples are preserved within one frame")
	var pan := InputEventPanGesture.new()
	pan.position = center
	pan.delta = Vector2(1, 0.5)
	var pan_before: Vector2 = map.pan
	Input.parse_input_event(pan)
	await layout()
	check(map.pan != pan_before, "2D trackpad pan event translates the map")
	map.reset_view()
	await layout()
	var poi: Dictionary = app.site.pois[1]
	var point_at: Vector2 = map.global_position + map.project(poi["latitudeDeg"], poi["longitudeDeg"])
	await touch(0, true, point_at)
	await touch(0, false, point_at)
	check(is_instance_valid(app.inspection_overlay) and app.inspection_overlay.visible, "a touch tap opens location information exactly once")
	var add_waypoint: Button = app.inspection.get_child(0).get_child(3)
	await touch(0, true, add_waypoint.get_global_rect().get_center())
	await touch(0, false, add_waypoint.get_global_rect().get_center())
	check(app.plan["waypoints"].size() == 1, "touch-to-mouse emulation remains available for ordinary popup buttons")
	app.undo()
	await settle(app)
	app.dismiss_inspection()
	app.show_3d()
	await layout()
	var lake: BathysLakeViewport = app.lake
	lake.navigation.tap.connect(func(_at: Vector2) -> void: tapped += 1)
	center = lake.global_position + lake.size / 2
	var yaw_before: float = lake.yaw
	var pitch_before: float = lake.pitch
	await touch(0, true, center)
	await move_touch(0, center + Vector2(30, 20))
	await touch(0, false, center + Vector2(30, 20))
	near(lake.yaw, yaw_before - 0.18, 0.001, "one-finger 3D drag rotates azimuth")
	near(lake.pitch, pitch_before + 0.12, 0.001, "one-finger 3D drag tilts elevation")
	var target_before: Vector3 = lake.target
	var distance_before: float = lake.distance
	yaw_before = lake.yaw
	await touch(2, true, center - Vector2(40, 0))
	await touch(7, true, center + Vector2(40, 0))
	await move_touch(2, center - Vector2(40, 0) + Vector2(25, 20))
	await move_touch(7, center + Vector2(40, 0) + Vector2(25, 20))
	await touch(2, false, active_touches[2])
	await touch(7, false, active_touches[7])
	check(not lake.target.is_equal_approx(target_before), "two-finger 3D drag translates the camera target")
	near(lake.distance, distance_before, 0.01, "parallel two-finger drag preserves final zoom")
	near(lake.yaw, yaw_before, 0.001, "parallel two-finger drag preserves final azimuth")
	await touch(0, true, center - Vector2(40, 0))
	await touch(1, true, center + Vector2(40, 0))
	await move_touch(0, center - Vector2(80, 0))
	await move_touch(1, center + Vector2(80, 0))
	await touch(0, false, active_touches[0])
	await touch(1, false, active_touches[1])
	near(lake.distance, distance_before / 2, 0.01, "two-finger 3D pinch doubles the magnification")
	yaw_before = lake.yaw
	await touch(0, true, center - Vector2(40, 0))
	await touch(1, true, center + Vector2(40, 0))
	await move_touch(0, center - Vector2(0, 40))
	await move_touch(1, center + Vector2(0, 40))
	await touch(0, false, active_touches[0])
	await touch(1, false, active_touches[1])
	near(lake.yaw, yaw_before + PI / 2, 0.001, "two-finger twist rotates 3D azimuth")
	check(tapped == 0 and lake.navigation.touches.is_empty(), "orbit, pinch, pan and twist never emit a location tap")
	var before: Vector3 = lake.target
	pan.position = center
	Input.parse_input_event(pan)
	await layout()
	check(not lake.target.is_equal_approx(before), "3D trackpad pan gesture translates the camera")
	distance_before = lake.distance
	magnify.position = center
	Input.parse_input_event(magnify)
	await layout()
	near(lake.distance, distance_before / 1.2, 0.01, "3D trackpad pinch event zooms")
	var wheel := InputEventMouseButton.new()
	wheel.position = center
	wheel.global_position = center
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.factor = 0.1
	distance_before = lake.distance
	Input.parse_input_event(wheel)
	await layout()
	near(lake.distance, distance_before / pow(1.16, 0.1), 0.01, "fractional wheel deltas provide smooth laptop zoom")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.shift_pressed = true
	mouse.position = center
	mouse.global_position = center
	Input.parse_input_event(mouse)
	await layout()
	var motion := InputEventMouseMotion.new()
	motion.position = center + Vector2(30, 0)
	motion.global_position = motion.position
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.shift_pressed = true
	before = lake.target
	yaw_before = lake.yaw
	Input.parse_input_event(motion)
	await layout()
	mouse.position = motion.position
	mouse.pressed = false
	Input.parse_input_event(mouse)
	await layout()
	check(not lake.target.is_equal_approx(before) and is_equal_approx(lake.yaw, yaw_before), "Shift-drag pans 3D using only the trackpad's left button")
	await touch(0, true, center)
	await touch(0, false, center, true)
	check(tapped == 0 and lake.navigation.touches.is_empty(), "canceled contacts do not inspect or leave a stuck gesture")
	await touch(0, true, center)
	app.cancel_map_navigation()
	await touch(0, false, center)
	check(tapped == 0 and lake.navigation.touches.is_empty(), "browser cancellation before its plain release cannot create a ghost tap")
	app.home_view()
	await capture("res://Screenshots/navigation-3d-en.png")
	root.size = Vector2i(390, 900)
	await layout()
	await capture("res://Screenshots/navigation-3d-phone.png")
	check(JSON.stringify(app.plan) == before_plan and app.undo_stack.size() == before_history, "navigation and acknowledgement preserve plan data and history")
	app.queue_free()
	await layout()
	app = load("res://Main.tscn").instantiate()
	root.add_child(app)
	await layout()
	check(app.educational_notice.visible and not app.educational_use_acknowledged, "a new app instance asks again instead of persisting consent")
	app.acknowledge_educational_use()
	app.queue_free()
	await layout()
	print("MAP NAVIGATION failures=", failures)
	quit(1 if failures else 0)
