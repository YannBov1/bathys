class_name BathysBuoyancyDiagram
extends BathysLessonDiagram

signal released
signal grabbed

signal immersion_changed(value: float)
signal preview_depth_changed(value: float)
signal cylinder_pressure_changed(value: float)

var at_depth: bool = false
var body_volume_l: float = 80.0
var mass_kg: float = 75.0
var immersion: float = 100.0
var depth: float = 10.0
var surface_gas_l: float = 6.0
var water_density: float = 998.2
var result: Dictionary = {}
var diver_icon: Texture2D = preload("res://Assets/Icons/buoyancy-diver.svg")
var cylinder_pressure: int = 0
var cylinder_steel: bool = false
var cylinder_mode: bool = false
var cylinder_state: Dictionary = {}
var cylinder_balance: Dictionary = {}
var cylinder_tilt_deg: float = 0
var cylinder_drag_target: String = ""
var cylinder_keyboard_hold: bool = false
var cylinder_curve_key: String = ""
var cylinder_curve_angles := PackedFloat64Array()

func _ready() -> void:
	super._ready()
	focus_mode = Control.FOCUS_ALL

func _process(delta: float) -> void:
	if not cylinder_mode or at_depth or not is_visible_in_tree() or cylinder_balance.is_empty(): return
	if not dragging and not cylinder_keyboard_hold:
		var target: float = cylinder_balance["angle_deg"]
		if absf(cylinder_tilt_deg - target) > 0.01:
			cylinder_tilt_deg = lerpf(cylinder_tilt_deg, target, 1 - exp(-5 * delta))
			queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if cylinder_mode and not at_depth and event is InputEventKey and event.pressed:
		if event.keycode in [KEY_UP, KEY_DOWN, KEY_HOME, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]: cylinder_keyboard_hold = false
			else:
				cylinder_keyboard_hold = true
				cylinder_tilt_deg = 0 if event.keycode == KEY_HOME else clampf(cylinder_tilt_deg + (5 if event.keycode == KEY_UP else -5), -75, 75)
			queue_redraw()
			accept_event()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grabbed.emit()
		if cylinder_mode and not at_depth:
			grab_focus()
			cylinder_keyboard_hold = false
			cylinder_drag_target = "pressure" if comparison_visible and cylinder_curve_rect().grow(16).has_point(event.position) else "tilt"
	super._gui_input(event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		cylinder_drag_target = ""
		released.emit()

func adapt() -> void:
	if cylinder_mode and not at_depth:
		custom_minimum_size.y = (880 if size.x < 660 else 440) if comparison_visible else 440
		tooltip_text = "Lift the base and release. Up/Down tilt; Enter releases. Drag the pressure curve to empty the cylinder."
		queue_redraw()
		return
	custom_minimum_size.y = (580 if size.x < 660 else 350) if comparison_visible else 300
	tooltip_text = "Drag the body to change immersion" if not at_depth else "Drag in the water or along the curve to change depth"
	queue_redraw()

func section(index: int) -> Rect2:
	if not comparison_visible: return Rect2(Vector2.ZERO, size)
	if size.x < 660:
		var height: float = 440 if cylinder_mode and not at_depth else 290
		return Rect2(0, index * height, size.x, height)
	return Rect2(index * size.x * 0.5, 0, size.x * 0.5, size.y)

func waterline_y() -> float:
	return 144.0

func body_size() -> Vector2:
	# A schematic three-dimensional body's projected dimensions follow V^(1/3).
	return Vector2(86, 100) * pow(body_volume_l / 80, 1.0 / 3.0)

func curve_rect() -> Rect2:
	var area: Rect2 = section(1)
	return Rect2(area.position + Vector2(51, 56), area.size - Vector2(77, 120))

func manipulate(at: Vector2) -> void:
	if cylinder_mode and not at_depth:
		if cylinder_drag_target == "pressure":
			var plot: Rect2 = cylinder_curve_rect()
			cylinder_pressure_changed.emit(clampf((at.x - plot.position.x) / plot.size.x * 200, 0, 200))
		elif section(0).has_point(at):
			var direction: Vector2 = at - cylinder_pivot()
			cylinder_tilt_deg = clampf(-rad_to_deg(atan2(direction.y, maxf(1, direction.x))), -75, 75)
			queue_redraw()
		return
	var area: Rect2 = section(0)
	if area.has_point(at):
		if at_depth:
			preview_depth_changed.emit(clampf((at.y - 100) / (area.size.y - 182) * 40, 0, 40))
		else:
			# Drag the centre through the surface; the block scales as volume changes.
			var height: float = body_size().y
			immersion_changed.emit(clampf((at.y - waterline_y() + height / 2) / height * 100, 0, 100))
	elif at_depth and curve_rect().grow(15).has_point(at):
		var plot: Rect2 = curve_rect()
		preview_depth_changed.emit(clampf((at.x - plot.position.x) / plot.size.x * 40, 0, 40))

func _draw() -> void:
	draw_style_box(BathysUiStyle.box(Color("08232f"), BathysUiStyle.EDGE, 10, 0), Rect2(Vector2.ZERO, size))
	if result.is_empty(): return
	if cylinder_mode and not at_depth:
		draw_cylinder()
		if comparison_visible: draw_cylinder_curve()
		return
	draw_body()
	if comparison_visible:
		if at_depth: draw_depth_curve()
		else: draw_displaced_water()

func draw_body() -> void:
	var area: Rect2 = section(0)
	var surface_y: float = 55 if at_depth else waterline_y()
	draw_rect(Rect2(1, surface_y, area.size.x - 2, area.size.y - surface_y - 1), Color("0b3747"))
	draw_line(Vector2(1, surface_y), Vector2(area.end.x - 1, surface_y), AQUA, 2)
	words(Vector2(16, 26), "Gas compression at depth" if at_depth else "Only submerged volume displaces water", INK, 12)
	var x: float = area.size.x * 0.46
	var center_y: float
	if at_depth:
		center_y = 100 + (area.size.y - 182) * depth / 40
		draw_texture_rect(diver_icon, Rect2(x - 32, center_y - 25, 64, 50), false)
		var gas_l: float = result["gas_volume_l"]
		var radius: float = 22 * pow(maxf(0, gas_l) / 6, 1.0 / 3.0)
		if radius > 0:
			var gas_center := Vector2(x - 64, maxf(surface_y + radius + 4, center_y - 40))
			draw_circle(gas_center, radius, Color(0.44, 0.9, 0.85, 0.13))
			draw_arc(gas_center, radius, 0, TAU, 48, AQUA, 2, true)
		for value: int in [0, 20, 40]:
			var y: float = 100 + (area.size.y - 182) * value / 40.0
			words(Vector2(area.end.x - 44, y + 4), "%d m" % value, MUTED, 10)
		words(Vector2(16, area.end.y - 17), tr("Trapped gas: %.2f L") % gas_l, AQUA, 13)
	else:
		var dimensions: Vector2 = body_size()
		var top: float = surface_y - dimensions.y * (1 - immersion / 100)
		center_y = top + dimensions.y / 2
		var body := Rect2(x - dimensions.x / 2, top, dimensions.x, dimensions.y)
		draw_style_box(BathysUiStyle.box(Color("45606b") if cylinder_pressure == 0 or cylinder_steel else Color("74919c"), INK, 6, 0), body)
		if cylinder_pressure > 0:
			draw_texture_rect(preload("res://Assets/Icons/cylinder.svg"), Rect2(body.get_center() - Vector2(12, 22), Vector2(24, 28)), false)
			words(body.get_center() + Vector2(-18, 20), "%d bar" % cylinder_pressure, INK, 10)
		words(Vector2(16, surface_y - 14), "Air", MUTED, 11)
		words(Vector2(16, surface_y + 24), "Water", MUTED, 11)
		words(Vector2(16, area.end.y - 17), "Drag the body through the surface", MUTED, 11)
	grip(Vector2(x + (53 if at_depth else -body_size().x / 2 - 20), center_y), true)
	var buoyant: float = result["buoyant_force"]
	var weight: float = result["weight"]
	var scale: float = maxf(200 if cylinder_pressure > 0 else 1250, maxf(buoyant, weight))
	var up_length: float = buoyant / scale * 44
	var down_length: float = weight / scale * 44
	if up_length > 0.1:
		arrow(Vector2(x - 102, center_y), Vector2(x - 102, center_y - up_length), AQUA, 3)
		words(Vector2(x - 113, maxf(49, center_y - up_length - 8)), "Fᵦ", AQUA, 13)
	arrow(Vector2(x + 80, center_y), Vector2(x + 80, center_y + down_length), AMBER, 3)
	words(Vector2(x + 72, center_y + down_length + 17), "W", AMBER, 13)

func draw_displaced_water() -> void:
	var area: Rect2 = section(1)
	words(area.position + Vector2(16, 26), "Weight of displaced water", INK, 13)
	var bucket := Rect2(area.position + Vector2(area.size.x * 0.32, 63), Vector2(area.size.x * 0.32, area.size.y - 142))
	draw_rect(bucket, Color("10323d"))
	var capacity: float = 20 if cylinder_pressure > 0 else 120
	var height: float = bucket.size.y * float(result["displaced_l"]) / capacity
	if height > 0:
		draw_rect(Rect2(bucket.position.x, bucket.end.y - height, bucket.size.x, height), Color("388e98"))
		draw_line(Vector2(bucket.position.x, bucket.end.y - height), Vector2(bucket.end.x, bucket.end.y - height), AQUA, 2)
	draw_line(bucket.position, Vector2(bucket.position.x, bucket.end.y), MUTED)
	draw_line(Vector2(bucket.position.x, bucket.end.y), bucket.end, MUTED)
	draw_line(Vector2(bucket.end.x, bucket.position.y), bucket.end, MUTED)
	for litres: int in [0, int(capacity / 2), int(capacity)]:
		var y: float = bucket.end.y - bucket.size.y * litres / capacity
		words(Vector2(bucket.end.x + 12, y + 4), "%d L" % litres, MUTED, 10)
	words(area.position + Vector2(18, area.size.y - 50), tr("%.1f L → %.2f kg of water") % [result["displaced_l"], result["displaced_mass"]], AQUA, 13)
	words(area.position + Vector2(18, area.size.y - 25), tr("Its weight gives %.1f N of buoyancy") % result["buoyant_force"], MUTED, 11)

func draw_depth_curve() -> void:
	var area: Rect2 = section(1)
	var plot: Rect2 = curve_rect()
	words(area.position + Vector2(16, 26), "Buoyancy and weight / depth", INK, 12)
	var low: float = float(result["weight"])
	var high: float = low
	var forces: PackedFloat64Array = PackedFloat64Array()
	for i: int in 81:
		var force: float = BathysLearningModels.buoyancy_at_depth(mass_kg, body_volume_l, surface_gas_l, i * 0.5, water_density)["buoyant_force"]
		forces.append(force)
		low = minf(low, force)
		high = maxf(high, force)
	var padding: float = maxf(10, (high - low) * 0.1)
	low = floorf((low - padding) / 10) * 10
	high = ceilf((high + padding) / 10) * 10
	words(Vector2(plot.position.x - 29, plot.position.y - 11), "N", MUTED, 10)
	for i: int in 3:
		var y: float = plot.end.y - plot.size.y * i / 2.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(0.4, 0.65, 0.7, 0.16))
		words(Vector2(plot.position.x - 38, y + 4), "%.0f" % lerpf(low, high, i / 2.0), MUTED, 10)
		words(Vector2(plot.position.x + plot.size.x * i / 2.0 - 5, plot.end.y + 19), str(i * 20), MUTED, 10)
	draw_line(plot.position, Vector2(plot.position.x, plot.end.y), MUTED)
	draw_line(Vector2(plot.position.x, plot.end.y), plot.end, MUTED)
	var points := PackedVector2Array()
	for i: int in forces.size():
		points.append(Vector2(plot.position.x + plot.size.x * i / 80, plot.end.y - plot.size.y * (forces[i] - low) / (high - low)))
	draw_polyline(points, AQUA, 2.5, true)
	var weight_y: float = plot.end.y - plot.size.y * (float(result["weight"]) - low) / (high - low)
	draw_dashed_line(Vector2(plot.position.x, weight_y), Vector2(plot.end.x, weight_y), AMBER, 1.5, 4)
	draw_circle(Vector2(plot.position.x + plot.size.x * depth / 40, plot.end.y - plot.size.y * (float(result["buoyant_force"]) - low) / (high - low)), 5, AQUA)
	words(Vector2(plot.position.x, plot.end.y + 38), "Depth · m", MUTED, 11)
	words(Vector2(plot.position.x, plot.end.y + 55), "Aqua: buoyancy · amber: weight", MUTED, 11)


func cylinder_pivot() -> Vector2:
	return section(0).position + Vector2(75, 200)

func cylinder_pixels_per_metre() -> float:
	return minf(150, section(0).size.x - 145) / float(cylinder_state.get("length", 0.65))

func cylinder_point(axial_m: float, side_px: float = 0) -> Vector2:
	var relative := Vector2((axial_m - float(cylinder_balance.get("pivot", 0.07))) * cylinder_pixels_per_metre(), side_px)
	return cylinder_pivot() + relative.rotated(-deg_to_rad(cylinder_tilt_deg))

func cylinder_base() -> Vector2:
	return cylinder_point(float(cylinder_state.get("length", 0.65)))

func cylinder_curve_rect() -> Rect2:
	var area: Rect2 = section(1)
	return Rect2(area.position + Vector2(48, 60), area.size - Vector2(72, 128))

func draw_cylinder() -> void:
	if cylinder_balance.is_empty(): return
	var area: Rect2 = section(0)
	draw_rect(Rect2(area.position + Vector2(1, 45), area.size - Vector2(2, 46)), Color("0b3747"))
	words(area.position + Vector2(16, 26), "Supported cylinder · schematic rigging", INK, 12)
	var pivot: Vector2 = cylinder_pivot()
	var ppm: float = cylinder_pixels_per_metre()
	var length: float = float(cylinder_state["length"]) * ppm
	var front: float = -float(cylinder_balance["pivot"]) * ppm
	var radius: float = 20 if cylinder_steel else 25
	# The horizontal reference and neck support stay fixed while the base moves.
	draw_dashed_line(pivot - Vector2(30, 0), pivot + Vector2(length - 10, 0), Color(0.57, 0.71, 0.73, 0.4), 1, 5)
	draw_line(pivot - Vector2(0, 70), pivot, MUTED, 2, true)
	draw_arc(pivot - Vector2(0, 76), 6, 0, TAU, 24, MUTED, 2, true)
	words(pivot + Vector2(-55, -89), "Neck support", MUTED, 11)
	draw_set_transform(pivot, -deg_to_rad(cylinder_tilt_deg))
	draw_style_box(BathysUiStyle.box(Color("45606b") if cylinder_steel else Color("74919c"), INK, int(radius), 0), Rect2(front, -radius, length, radius * 2))
	draw_line(Vector2(front + length - 15, -radius + 4), Vector2(front + length - 15, radius - 4), Color("28515b"), 4, true)
	draw_style_box(BathysUiStyle.box(Color("c8a96b"), INK, 3, 0), Rect2(front - 17, -8, 21, 16))
	draw_line(Vector2(front - 9, -15), Vector2(front - 9, 15), AMBER, 4, true)
	var band: float = clampf(float(cylinder_pressure) / 200, 0, 1)
	draw_line(Vector2(front + 24, 0), Vector2(front + length - 30, 0), Color("12323d"), 9, true)
	if band > 0:
		draw_line(Vector2(front + 24, 0), Vector2(front + 24 + (length - 54) * band, 0), AQUA, 7, true)
	draw_set_transform(Vector2.ZERO)
	draw_circle(pivot, 5, Color("071c29"))
	draw_arc(pivot, 6, 0, TAU, 24, INK, 2, true)
	# Opposing forces use their own axial centres, not an arbitrary screen gap.
	var cb: Vector2 = cylinder_point(cylinder_balance["cb"], -radius - 4)
	var cm: Vector2 = cylinder_point(cylinder_balance["cm"], radius + 4)
	var buoyancy_centre: Vector2 = cylinder_point(cylinder_balance["cb"])
	var mass_centre: Vector2 = cylinder_point(cylinder_balance["cm"])
	draw_dashed_line(buoyancy_centre, cb, AQUA, 1, 3)
	draw_dashed_line(mass_centre, cm, AMBER, 1, 3)
	draw_circle(buoyancy_centre, 3, AQUA)
	draw_circle(mass_centre, 2, AMBER)
	var up_length: float = float(result["buoyant_force"]) / 200 * 44
	var down_length: float = float(result["weight"]) / 200 * 44
	arrow(cb, Vector2(cb.x, maxf(area.position.y + 60, cb.y - up_length)), AQUA, 2.5)
	arrow(cm, cm + Vector2(0, down_length), AMBER, 2.5)
	words(Vector2(cb.x - 10, maxf(area.position.y + 57, cb.y - up_length - 7)), "Fᵦ", AQUA, 12)
	words(cm + Vector2(-3, down_length + 15), "W", AMBER, 12)
	grip(cylinder_point(cylinder_state["length"], radius + 19), true)
	words(area.position + Vector2(16, area.size.y - 63), tr("%s · %d bar") % [tr("Steel" if cylinder_steel else "Aluminium"), cylinder_pressure], INK, 13)
	var up: bool = float(cylinder_balance["moment"]) > 0
	words(area.position + Vector2(16, area.size.y - 40), "Base tends to rise" if up else "Base tends to drop", AQUA if up else AMBER, 13)
	words(area.position + Vector2(16, area.size.y - 19), "Whole cylinder: positive" if float(result["net_force"]) > 0 else "Whole cylinder: negative", MUTED, 11)

func draw_cylinder_curve() -> void:
	var key: String = str([cylinder_steel, water_density])
	if key != cylinder_curve_key:
		cylinder_curve_key = key
		cylinder_curve_angles.clear()
		for i: int in 101:
			var state: Dictionary = BathysLearningModels.cylinder_buoyancy_state(cylinder_steel, i * 2)
			cylinder_curve_angles.append(BathysLearningModels.cylinder_trim(state, water_density)["angle_deg"])
	var area: Rect2 = section(1)
	var plot: Rect2 = cylinder_curve_rect()
	words(area.position + Vector2(16, 26), "Base angle / cylinder pressure", INK, 12)
	for angle: float in [-60, 0, 60]:
		var y: float = plot.get_center().y - plot.size.y * angle / 150
		draw_dashed_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color("28515b"), 1, 5)
		words(Vector2(plot.position.x - 35, y + 4), "%+.0f°" % angle, MUTED, 10)
	var points := PackedVector2Array()
	for i: int in cylinder_curve_angles.size():
		points.append(Vector2(plot.position.x + plot.size.x * i / 100, plot.get_center().y - plot.size.y * cylinder_curve_angles[i] / 150))
	draw_polyline(points, AQUA, 2.5, true)
	for pressure: int in [0, 100, 200]:
		words(Vector2(plot.position.x + plot.size.x * pressure / 200 - 8, plot.end.y + 21), str(pressure), MUTED, 11)
	var marker := Vector2(plot.position.x + plot.size.x * cylinder_pressure / 200, plot.get_center().y - plot.size.y * float(cylinder_balance["angle_deg"]) / 150)
	draw_dashed_line(Vector2(marker.x, plot.end.y), marker, AMBER, 1, 4)
	draw_circle(marker, 6, AMBER)
	words(Vector2(plot.position.x, plot.end.y + 43), "Cylinder pressure · bar", MUTED, 11)
	words(Vector2(plot.position.x, plot.end.y + 61), "+ base up     − base down", AQUA, 11)
