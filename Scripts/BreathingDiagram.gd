class_name BathysBreathingDiagram
extends BathysLessonDiagram

signal lesson_depth_changed(depth: float)
var kind: String = "oxygen"
var depth: float = 30.0
var oxygen: float = 32.0
var helium: float = 0.0
var minutes: float = 30.0
var temperature: float = 20.0
var oxygen_narcotic: bool = true
var samples: PackedVector2Array = PackedVector2Array()
var air_samples: PackedVector2Array = PackedVector2Array()
var density_result: Dictionary = {}

func adapt() -> void:
	custom_minimum_size.y = 560 if comparison_visible and size.x < 660 else 340
	tooltip_text = "Drag the plot to change depth" if comparison_visible else ("Drag the actual depth marker" if kind == "narcosis" else "Use the instruments below")
	queue_redraw()

func panel(index: int) -> Rect2:
	if not comparison_visible: return Rect2(Vector2.ZERO, size)
	if size.x < 660: return Rect2(0, index * 280, size.x, 280)
	return Rect2(index * size.x * 0.5, 0, size.x * 0.5, size.y)

func plot_rect() -> Rect2:
	var area: Rect2 = panel(1 if kind == "gas_density" else 0)
	return Rect2(area.position + Vector2(43, 56), area.size - Vector2(66, 124))

func manipulate(at: Vector2) -> void:
	if not comparison_visible and kind != "narcosis": return
	var plot: Rect2 = plot_rect()
	if plot.grow(16).has_point(at):
		if kind == "narcosis":
			var comparison: Dictionary = BathysLearningModels.narcosis_comparison(depth, oxygen, helium, oxygen_narcotic)
			lesson_depth_changed.emit(clampf((at.y - plot.position.y) / plot.size.y * maxf(80, ceilf(float(comparison["end_m"]) / 10) * 10), 0, 80))
		else:
			lesson_depth_changed.emit(clampf((at.x - plot.position.x) / plot.size.x * 80, 0, 80))

func rebuild_density() -> void:
	# Cache expensive real-gas samples when parameters change, never on hover/redraw.
	samples.clear()
	air_samples.clear()
	if kind == "gas_density":
		for i: int in 41:
			var result: Dictionary = BathysLearningModels.breathing_density(i * 2, oxygen, helium, temperature)
			samples.append(Vector2(i * 2, result["density"]))
			air_samples.append(Vector2(i * 2, result["air_density"]))
		density_result = BathysLearningModels.breathing_density(depth, oxygen, helium, temperature)
	queue_redraw()

func axes(plot: Rect2, maximum: float, unit: String) -> void:
	for i: int in 3:
		var y: float = plot.end.y - plot.size.y * i / 2.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(0.4, 0.65, 0.7, 0.16))
		words(Vector2(plot.position.x - 31, y + 4), "%.1f" % (maximum * i / 2), MUTED, 10)
		words(Vector2(plot.position.x + plot.size.x * i / 2.0 - 5, plot.end.y + 18), str(i * 40), MUTED, 10)
	draw_line(plot.position, Vector2(plot.position.x, plot.end.y), MUTED)
	draw_line(Vector2(plot.position.x, plot.end.y), plot.end, MUTED)
	words(Vector2(plot.position.x - 27, plot.position.y - 10), unit, MUTED, 10)
	words(Vector2(plot.position.x, plot.end.y + 38), "Depth · m", MUTED, 11)

func _draw() -> void:
	draw_style_box(BathysUiStyle.box(Color("08232f"), BathysUiStyle.EDGE, 10, 0), Rect2(Vector2.ZERO, size))
	match kind:
		"oxygen": draw_oxygen()
		"narcosis": draw_narcosis()
		"gas_density": draw_density()

func draw_oxygen() -> void:
	var result: Dictionary = BathysLearningModels.oxygen_exposure(depth, oxygen, minutes)
	if comparison_visible:
		var left: Rect2 = panel(0)
		words(left.position + Vector2(16, 26), "Oxygen pressure / depth", INK)
		var plot: Rect2 = plot_rect()
		var maximum: float = maxf(2, ceili(9 * oxygen / 100))
		axes(plot, maximum, "bar")
		var y_start: float = plot.end.y - plot.size.y * 1.6 / maximum
		draw_rect(Rect2(Vector2(plot.position.x, y_start), Vector2(plot.size.x, plot.size.y * 1.1 / maximum)), Color(1, 0.72, 0.43, 0.08))
		draw_dashed_line(Vector2(plot.position.x, y_start), Vector2(plot.end.x, y_start), AMBER, 1.5, 5)
		var points := PackedVector2Array()
		for i: int in 81:
			points.append(Vector2(plot.position.x + plot.size.x * i / 80, plot.end.y - plot.size.y * (1 + i / 10.0) * oxygen / 100 / maximum))
		draw_polyline(points, AQUA, 2.5, true)
		draw_circle(Vector2(plot.position.x + plot.size.x * depth / 80, plot.end.y - plot.size.y * float(result["pp_o2"]) / maximum), 5, AQUA)
		words(Vector2(plot.position.x, plot.end.y + 55), "Amber: end of CNS table", AMBER, 11)
	var right: Rect2 = panel(1)
	words(right.position + Vector2(16, 26), "CNS exposure index", INK)
	var center: Vector2 = right.position + Vector2(right.size.x * 0.5, right.size.y * 0.42)
	var radius: float = minf(63, right.size.y * 0.2)
	draw_arc(center, radius, 0, TAU, 80, BathysUiStyle.EDGE, 9, true)
	if bool(result["cns_valid"]):
		var index: float = float(result["cns"])
		if index > 0:
			draw_arc(center, radius, -PI / 2, -PI / 2 + TAU * minf(1, index / 100), 80, AMBER, 9, true)
		var text: String = "%.0f%%" % index
		var width: float = ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		words(center + Vector2(-width / 2, 7), text, INK, 22)
		# The clock is elapsed time divided by the table's exposure allocation.
		var allocation: Variant = result["allocation_min"]
		if allocation != null:
			var caption: String = tr("%.1f / %.1f table min") % [minutes, float(allocation)]
			var caption_width: float = ThemeDB.fallback_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			words(center + Vector2(-caption_width / 2, radius + 24), caption, MUTED, 11)
		else:
			words(center + Vector2(-65, radius + 24), "No accrual in this table", MUTED, 11)
	else:
		words(center + Vector2(-14, 8), "—", AMBER, 24)
	var counter: Vector2 = right.position + Vector2(18, right.size.y - 63)
	words(counter, tr("Pulmonary exposure: %.1f OTU") % float(result["otu"]), AQUA, 14)
	words(counter + Vector2(0, 23), "Indexes, not illness probabilities", MUTED, 11)
	if not bool(result["cns_valid"]): words(counter + Vector2(0, 41), "CNS: outside table (>1.6 bar)", AMBER, 11)

func draw_narcosis() -> void:
	var result: Dictionary = BathysLearningModels.narcosis_comparison(depth, oxygen, helium, oxygen_narcotic)
	var plot: Rect2 = plot_rect()
	words(panel(0).position + Vector2(16, 26), "Actual depth / equivalent air depth", INK, 12)
	var y0: float = plot.position.y
	var depth_scale: float = maxf(80, ceilf(float(result["end_m"]) / 10) * 10)
	for i: int in 3:
		var y: float = y0 + plot.size.y * i / 2.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(0.4, 0.65, 0.7, 0.16))
		words(Vector2(plot.position.x - 26, y + 4), "%.0f" % (depth_scale * i / 2), MUTED, 10)
	var depths: Array[float] = [depth, float(result["end_m"])]
	for i: int in 2:
		var x: float = plot.position.x + plot.size.x * (0.28 if i == 0 else 0.75)
		var h: float = plot.size.y * depths[i] / depth_scale
		draw_rect(Rect2(x - 22, y0, 44, plot.size.y), Color("10323d"))
		draw_rect(Rect2(x - 22, y0, 44, h), Color("246a76") if i == 0 else Color("367a70"))
		draw_line(Vector2(x - 26, y0 + h), Vector2(x + 26, y0 + h), AQUA if i == 0 else AMBER, 2)
		if i == 0: grip(Vector2(x, y0 + h), true)
		words(Vector2(x - 22, plot.end.y + 20), "Actual" if i == 0 else "END", INK, 11)
		words(Vector2(x - 22, plot.end.y + 38), "≤0 m" if i == 1 and bool(result["below_surface"]) else "%.1f m" % depths[i], AQUA if i == 0 else AMBER, 12)
	if not comparison_visible: return
	var right: Rect2 = panel(1)
	words(right.position + Vector2(16, 26), "Below air’s surface reference" if bool(result["below_surface"]) else "Same counted gas pressure", INK, 12)
	var maximum: float = 9.0
	var bar_area := Rect2(right.position + Vector2(44, 65), right.size - Vector2(77, 140))
	var selected_pressure: float = result["narcotic_pressure"]
	var air_pressure: float = (1 + float(result["end_m"]) / 10) * float(result["air_fraction"])
	for i: int in 2:
		var x: float = bar_area.position.x + bar_area.size.x * (0.25 if i == 0 else 0.75)
		var h: float = bar_area.size.y * (selected_pressure if i == 0 else air_pressure) / maximum
		draw_rect(Rect2(x - 24, bar_area.end.y - h, 48, h), AQUA * Color(1, 1, 1, 0.6) if i == 0 else AMBER * Color(1, 1, 1, 0.6))
		words(Vector2(x - 32, bar_area.end.y + 21), "Mix" if i == 0 else ("Air at surface" if bool(result["below_surface"]) else "Air at END"), INK, 11)
		words(Vector2(x - 32, bar_area.end.y + 41), "%.2f bar" % (selected_pressure if i == 0 else air_pressure), MUTED, 12)
	words(Vector2(right.position.x + 16, right.end.y - 10), "Comparison, not an impairment score", MUTED, 11)

func draw_density() -> void:
	if density_result.is_empty(): return
	var area: Rect2 = panel(0)
	words(area.position + Vector2(16, 26), "Mass of one litre at this depth", INK, 12)
	for i: int in 2:
		var x: float = area.position.x + area.size.x * (0.28 if i == 0 else 0.75)
		var top: float = area.position.y + 66
		var h: float = area.size.y - 143
		var width: float = minf(100, area.size.x * 0.28)
		var box := Rect2(x - width / 2, top, width, h)
		draw_style_box(BathysUiStyle.box(Color("113540"), AQUA if i == 0 else MUTED, 8, 0), box)
		# Schematic particle counts follow P/T; lighter helium gets smaller dots.
		var count: int = clampi(roundi(8 * float(density_result["ambient"]) * 293.15 / (temperature + 273.15)), 1, 80)
		for j: int in count:
			var at: Vector2 = box.position + Vector2(9 + fposmod((j + 1) * 0.618033989, 1) * (width - 18), 10 + fposmod((j + 1) * 0.414213562, 1) * (h - 20))
			draw_circle(at, 2.5 if i == 0 and j < roundi(helium / 100 * count) else 5, AQUA if i == 0 else MUTED)
		words(Vector2(x - 28, box.end.y + 22), "Mix · 1 L" if i == 0 else "Air · 1 L", INK, 11)
		words(Vector2(x - 28, box.end.y + 43), "%.2f g" % float(density_result["density" if i == 0 else "air_density"]), AQUA if i == 0 else MUTED, 15)
	if not comparison_visible: return
	var plot: Rect2 = plot_rect()
	words(panel(1).position + Vector2(16, 26), "Gas density / depth", INK)
	var maximum: float = 8
	for point: Vector2 in samples: maximum = maxf(maximum, point.y + 0.5)
	for point: Vector2 in air_samples: maximum = maxf(maximum, point.y + 0.5)
	maximum = ceilf(maximum)
	axes(plot, maximum, "g/L")
	for entry: Array in [[samples, AQUA], [air_samples, MUTED]]:
		var points := PackedVector2Array()
		for point: Vector2 in entry[0]: points.append(Vector2(plot.position.x + plot.size.x * point.x / 80, plot.end.y - plot.size.y * point.y / maximum))
		draw_polyline(points, entry[1], 2, true)
	for entry: Array in [[5.2, AMBER], [6.2, Color("ff6676")]]:
		var y: float = plot.end.y - plot.size.y * float(entry[0]) / maximum
		draw_dashed_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), entry[1], 1.5, 4)
		words(Vector2(plot.position.x + 3, y - 3), str(entry[0]), entry[1], 10)
	draw_circle(Vector2(plot.position.x + plot.size.x * depth / 80, plot.end.y - plot.size.y * float(density_result["density"]) / maximum), 5, AQUA)
	words(Vector2(plot.position.x, plot.end.y + 55), "Aqua: mix · grey: air", MUTED, 11)
