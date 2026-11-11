class_name BathysBuoyancyDiagram
extends BathysLessonDiagram

signal immersion_changed(value: float)
signal preview_depth_changed(value: float)

var at_depth: bool = false
var body_volume_l: float = 80.0
var mass_kg: float = 75.0
var immersion: float = 100.0
var depth: float = 10.0
var surface_gas_l: float = 6.0
var water_density: float = 998.2
var result: Dictionary = {}
var diver_icon: Texture2D = preload("res://Assets/Icons/buoyancy-diver.svg")

func adapt() -> void:
	custom_minimum_size.y = 580 if size.x < 660 else 350
	tooltip_text = "Drag the body to change immersion" if not at_depth else "Drag in the water or along the curve to change depth"
	queue_redraw()

func section(index: int) -> Rect2:
	if size.x < 660: return Rect2(0, index * 290, size.x, 290)
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
	draw_body()
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
			draw_circle(Vector2(x + 15, center_y - 20), radius, Color(0.44, 0.9, 0.85, 0.13))
			draw_arc(Vector2(x + 15, center_y - 20), radius, 0, TAU, 48, AQUA, 2, true)
		for value: int in [0, 20, 40]:
			var y: float = 100 + (area.size.y - 182) * value / 40.0
			words(Vector2(area.end.x - 44, y + 4), "%d m" % value, MUTED, 10)
		words(Vector2(16, area.end.y - 17), tr("Trapped gas: %.2f L") % gas_l, AQUA, 13)
	else:
		var dimensions: Vector2 = body_size()
		var top: float = surface_y - dimensions.y * (1 - immersion / 100)
		center_y = top + dimensions.y / 2
		var body := Rect2(x - dimensions.x / 2, top, dimensions.x, dimensions.y)
		draw_style_box(BathysUiStyle.box(Color("45606b"), INK, 6, 0), body)
		if immersion > 0:
			draw_rect(Rect2(body.position.x + 1, surface_y, body.size.x - 2, maxf(0, dimensions.y * immersion / 100 - 1)), Color("388e98"))
		words(Vector2(16, surface_y - 14), "Air", MUTED, 11)
		words(Vector2(16, surface_y + 24), "Water", MUTED, 11)
		words(Vector2(16, area.end.y - 17), "Drag the body through the surface", MUTED, 11)
	var buoyant: float = result["buoyant_force"]
	var weight: float = result["weight"]
	var scale: float = maxf(1250, maxf(buoyant, weight))
	var up_length: float = buoyant / scale * 44
	var down_length: float = weight / scale * 44
	if up_length > 0.1:
		arrow(Vector2(x - 80, center_y), Vector2(x - 80, center_y - up_length), AQUA, 3)
		words(Vector2(x - 91, maxf(49, center_y - up_length - 8)), "Fᵦ", AQUA, 13)
	arrow(Vector2(x + 80, center_y), Vector2(x + 80, center_y + down_length), AMBER, 3)
	words(Vector2(x + 72, center_y + down_length + 17), "W", AMBER, 13)

func draw_displaced_water() -> void:
	var area: Rect2 = section(1)
	words(area.position + Vector2(16, 26), "Weight of displaced water", INK, 13)
	var bucket := Rect2(area.position + Vector2(area.size.x * 0.32, 63), Vector2(area.size.x * 0.32, area.size.y - 142))
	draw_rect(bucket, Color("10323d"))
	var height: float = bucket.size.y * float(result["displaced_l"]) / 120
	if height > 0:
		draw_rect(Rect2(bucket.position.x, bucket.end.y - height, bucket.size.x, height), Color("388e98"))
		draw_line(Vector2(bucket.position.x, bucket.end.y - height), Vector2(bucket.end.x, bucket.end.y - height), AQUA, 2)
	draw_line(bucket.position, Vector2(bucket.position.x, bucket.end.y), MUTED)
	draw_line(Vector2(bucket.position.x, bucket.end.y), bucket.end, MUTED)
	draw_line(Vector2(bucket.end.x, bucket.position.y), bucket.end, MUTED)
	for litres: int in [0, 60, 120]:
		var y: float = bucket.end.y - bucket.size.y * litres / 120.0
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
