class_name BathysScienceLessonDiagram
extends BathysLessonDiagram

signal oxygen_changed(value: float)
signal helium_changed(value: float)
var gas_drag: int = -1

signal time_changed(value: float)
signal temperature_changed(value: float)

const VIOLET := Color("b5a3f3")
var dalton_depth: float = 20.0
var oxygen_percent: float = 21.0
var helium_percent: float = 0.0
var gas_pressure: float = 3.0
var half_times: float = 1.0
var temperature_c: float = 20.0
var salinity: float = 35.0

func _ready() -> void:
	super._ready()
	focus_mode = FOCUS_ALL

func adapt() -> void:
	if lesson in ["boyle", "snell"]:
		super.adapt()
		return
	custom_minimum_size.y = 530 if comparison_visible and lesson in ["henry", "density"] and size.x < 620 else 330
	tooltip_text = {"dalton": "Drag vertically to change depth", "henry": "Drag along the curve to explore elapsed half-times", "density": "Drag along the curve to change temperature"}.get(lesson, "")
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		var amount: float = (1 if event.keycode in [KEY_RIGHT, KEY_DOWN] else -1) * (1 if event.shift_pressed else 0.1)
		if lesson == "boyle": depth_changed.emit(clampf(depth_m + amount, 0, 40))
		elif lesson == "snell": angle_changed.emit(clampf(angle_deg + amount, 0, 89))
		else: return
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed: grab_focus()
	if lesson == "dalton" and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		gas_drag = -1
		if event.pressed:
			var index: int = floori((event.position.x - 42) / maxf(1, size.x - 60) * 4)
			if index in [0, 2]: gas_drag = index
	super._gui_input(event)

func manipulate(at: Vector2) -> void:
	match lesson:
		"dalton":
			if gas_drag in [0, 2]:
				var pressure: float = (1 - clampf((at.y - 64) / (size.y - 138), 0, 1)) * 5
				var fraction: float = clampf(pressure / pressure_at(dalton_depth) * 100, 0, 100)
				if gas_drag == 0: oxygen_changed.emit(fraction)
				else: helium_changed.emit(fraction)
				return
			depth_changed.emit(clampf((1.0 - (at.y - 64) / (size.y - 138)) * 50.0 - 10.0, 0, 40))
		"henry":
			if not comparison_visible: return
			var plot: Rect2 = graph_rect("henry")
			if at.x >= plot.position.x - 20 and at.y >= plot.position.y - 20:
				time_changed.emit(clampf((at.x - plot.position.x) / plot.size.x * 5.0, 0, 5))
		"density":
			var plot: Rect2 = graph_rect("density")
			if at.x <= plot.end.x + 20:
				temperature_changed.emit(clampf((at.x - plot.position.x) / plot.size.x * 35.0, 0, 35))
		_: super.manipulate(at)

func _draw() -> void:
	if lesson in ["boyle", "snell"]:
		super._draw()
		return
	draw_style_box(BathysUiStyle.box(Color("08232f"), BathysUiStyle.EDGE, 10, 0), Rect2(Vector2.ZERO, size))
	match lesson:
		"dalton": draw_dalton()
		"henry": draw_henry()
		"density": draw_density()

func centered(at: Vector2, message: String, color: Color = INK, font_size: int = 13) -> void:
	var translated: String = tr(message)
	var width: float = ThemeDB.fallback_font.get_string_size(translated, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	words(at - Vector2(width * 0.5, 0), message, color, font_size)

func draw_dalton() -> void:
	var values: Dictionary = BathysLearningModels.partial_pressures(dalton_depth, oxygen_percent, helium_percent)
	var colors: Array[Color] = [AQUA, AMBER, VIOLET]
	var gases: Array[String] = ["O₂", "N₂", "He", "Total"]
	var keys: Array[String] = ["o2", "n2", "he", "total"]
	words(Vector2(18, 27), "Partial pressures add up", INK, 14)
	var plot := Rect2(42, 64, size.x - 60, size.y - 138)
	for i: int in 6:
		var y: float = plot.end.y - plot.size.y * i / 5.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(0.4, 0.65, 0.7, 0.16))
		words(Vector2(12, y + 4), str(i), MUTED, 11)
	words(Vector2(9, 49), "bar", MUTED, 11)
	for i: int in 4:
		var x: float = plot.position.x + plot.size.x * (float(i) + 0.5) / 4.0
		var width: float = plot.size.x / 4 * 0.62
		var fill: float = plot.size.y * float(values[keys[i]]) / 5.0
		draw_style_box(BathysUiStyle.box(Color("10323d"), BathysUiStyle.EDGE, 4, 0), Rect2(x - width * 0.5, plot.position.y, width, plot.size.y))
		if i < 3:
			if fill > 0.1:
				draw_rect(Rect2(x - width * 0.5 + 2, plot.end.y - fill, width - 4, fill), colors[i] * Color(1, 1, 1, 0.65))
		else:
			var y: float = plot.end.y
			for j: int in 3:
				var segment: float = plot.size.y * float(values[keys[j]]) / 5.0
				y -= segment
				if segment > 0.1:
					draw_rect(Rect2(x - width * 0.5 + 2, y, width - 4, segment), colors[j] * Color(1, 1, 1, 0.65))
		if i in [0, 2]: grip(Vector2(x, plot.end.y - fill), true)
		centered(Vector2(x, plot.end.y + 24), gases[i], colors[i] if i < 3 else INK, 15)
		centered(Vector2(x, plot.end.y + 44), "%.2f" % float(values[keys[i]]), colors[i] if i < 3 else INK, 14)
		if i < 3:
			centered(Vector2(x + plot.size.x / 8, plot.get_center().y), "+" if i < 2 else "=", MUTED, 17)
	words(Vector2(18, size.y - 10), "All values in bar absolute", MUTED, 11)

func panel_rect(index: int) -> Rect2:
	if not comparison_visible: return Rect2(Vector2.ZERO, size)
	if size.x < 620:
		return Rect2(0, index * 265, size.x, 265)
	return Rect2(index * size.x * 0.5, 0, size.x * 0.5, size.y)

func graph_rect(kind: String) -> Rect2:
	var area: Rect2 = panel_rect(1 if kind == "henry" else 0)
	return Rect2(area.position + Vector2(57, 51), area.size - Vector2(82, 109))

func chart_grid(plot: Rect2, maximum_x: float, minimum_y: float, maximum_y: float, x_unit: String, y_unit: String) -> void:
	for i: int in 3:
		var fraction: float = i / 2.0
		var y: float = plot.end.y - plot.size.y * fraction
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(0.4, 0.65, 0.7, 0.16))
		words(Vector2(plot.position.x - 46, y + 4), "%.1f" % lerpf(minimum_y, maximum_y, fraction), MUTED, 11)
		var x: float = plot.position.x + plot.size.x * fraction
		words(Vector2(x - 8, plot.end.y + 20), "%.1f" % (maximum_x * fraction), MUTED, 11)
	draw_line(plot.position, Vector2(plot.position.x, plot.end.y), MUTED)
	draw_line(Vector2(plot.position.x, plot.end.y), plot.end, MUTED)
	words(Vector2(plot.end.x - 16, plot.end.y + 39), x_unit, MUTED, 11)
	words(Vector2(plot.position.x - 41, plot.position.y - 10), y_unit, MUTED, 11)

func draw_henry() -> void:
	var area: Rect2 = panel_rect(0)
	var fluid := Rect2(area.position + Vector2(28, 100), area.size - Vector2(56, 145))
	words(area.position + Vector2(18, 26), "Gas above the liquid", INK)
	words(area.position + Vector2(18, 49), tr("Gas pressure: %.1f bar") % gas_pressure, AMBER, 14)
	draw_rect(fluid, Color("0b3747"))
	draw_line(fluid.position, Vector2(fluid.end.x, fluid.position.y), AQUA, 2)
	var current: float = BathysLearningModels.dissolved(gas_pressure, half_times)
	var count: int = roundi(current * 12)
	for i: int in count:
		# Fixed liquid volume; only the dissolved concentration changes.
		var x: float = fposmod((i + 1) * 0.61803398875, 1.0)
		var y: float = fposmod((i + 1) * 0.41421356237, 1.0)
		draw_circle(fluid.position + Vector2(10 + x * (fluid.size.x - 20), 12 + y * (fluid.size.y - 24)), 3.2, AQUA)
	if absf(gas_pressure - current) > 0.02:
		for i: int in 3:
			var center := Vector2(fluid.position.x + fluid.size.x * (i + 1) / 4, fluid.position.y)
			arrow(center - Vector2(0, 22 if gas_pressure > current else -22), center + Vector2(0, 22 if gas_pressure > current else -22), AMBER, 2)
	words(Vector2(area.position.x + 18, area.end.y - 20), "Dots: dissolved molecules, not bubbles", MUTED, 11)
	if not comparison_visible: return
	var graph_area: Rect2 = panel_rect(1)
	words(graph_area.position + Vector2(18, 26), "Dissolved gas / elapsed half-times", INK)
	var plot: Rect2 = graph_rect("henry")
	chart_grid(plot, 5, 0, 5, "t½", "× ref.")
	var target_y: float = plot.end.y - plot.size.y * gas_pressure / 5
	draw_dashed_line(Vector2(plot.position.x, target_y), Vector2(plot.end.x, target_y), AMBER, 1.5, 5)
	var points := PackedVector2Array()
	for i: int in 101:
		var time: float = i / 20.0
		points.append(Vector2(plot.position.x + plot.size.x * time / 5, plot.end.y - plot.size.y * BathysLearningModels.dissolved(gas_pressure, time) / 5))
	draw_polyline(points, AQUA, 2.5, true)
	var marker := Vector2(plot.position.x + plot.size.x * half_times / 5, plot.end.y - plot.size.y * current / 5)
	draw_circle(marker, 5, AQUA)
	words(Vector2(plot.position.x, plot.end.y + 54), "Dashed: equilibrium target", AMBER, 11)

func draw_density() -> void:
	var properties: Dictionary = BathysLearningModels.water_properties(temperature_c, salinity)
	var area: Rect2 = panel_rect(0)
	words(area.position + Vector2(18, 26), "Density / temperature", INK)
	var plot: Rect2 = graph_rect("density")
	var low: float = 2000
	var high: float = 0
	for i: int in 71:
		var density: float = float(BathysLearningModels.water_properties(i * 0.5, salinity)["density"])
		low = minf(low, density)
		high = maxf(high, density)
	low = floorf(low - 0.3)
	high = ceilf(high + 0.3)
	chart_grid(plot, 35, low, high, "°C", "kg/m³")
	var points := PackedVector2Array()
	for i: int in 101:
		var temperature: float = i * 0.35
		var density: float = float(BathysLearningModels.water_properties(temperature, salinity)["density"])
		points.append(Vector2(plot.position.x + plot.size.x * temperature / 35, plot.end.y - plot.size.y * (density - low) / (high - low)))
	draw_polyline(points, AQUA, 2.5, true)
	var marker := Vector2(plot.position.x + plot.size.x * temperature_c / 35, plot.end.y - plot.size.y * (float(properties["density"]) - low) / (high - low))
	draw_circle(marker, 5, AMBER)
	words(Vector2(plot.position.x, plot.end.y + 54), "Curve: selected salinity", MUTED, 11)
	if not comparison_visible: return
	var water_area: Rect2 = panel_rect(1)
	words(water_area.position + Vector2(18, 26), "Water column for +1 bar", INK)
	var column := Rect2(water_area.position + Vector2(water_area.size.x * 0.28, 49), Vector2(water_area.size.x * 0.38, water_area.size.y - 109))
	draw_rect(column, Color("10323d"))
	var height: float = float(properties["metres_per_bar"]) / 11 * column.size.y
	draw_rect(Rect2(column.position, Vector2(column.size.x, height)), Color("246a76"))
	var reference: float = float(BathysLearningModels.water_properties(20, 0)["metres_per_bar"]) / 11 * column.size.y
	draw_line(column.position, Vector2(column.end.x, column.position.y), AQUA, 2)
	draw_dashed_line(Vector2(column.position.x - 12, column.position.y + reference), Vector2(column.end.x + 12, column.position.y + reference), AMBER, 1.5, 5)
	draw_line(Vector2(column.position.x - 8, column.position.y + height), Vector2(column.end.x + 8, column.position.y + height), AQUA, 2)
	for depth: int in [0, 5, 10]:
		var y: float = column.position.y + column.size.y * depth / 11.0
		words(Vector2(column.end.x + 18, y + 4), "%d m" % depth, MUTED, 11)
	centered(Vector2(column.get_center().x, column.end.y + 21), "%.3f m" % float(properties["metres_per_bar"]), AQUA, 16)
	centered(Vector2(column.get_center().x, column.end.y + 41), "Dashed: fresh water at 20°C", AMBER, 11)
