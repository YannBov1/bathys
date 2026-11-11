class_name BathysThermalDiagram
extends BathysLessonDiagram

signal parameter_changed(key: String, value: float)
var primary_drag: bool = false
var kind: String = "charles"
var params: Dictionary = {}
var result: Dictionary = {}
var curve := PackedVector2Array()
var bounds := Rect2(0, 0, 650, 2.3)
var plot_title: String = ""
var plot_footer: String = ""
var line_colour: Color = AQUA
const VIOLET := Color("b5a3f3")

func adapt() -> void:
	custom_minimum_size.y = (720 if size.x < 660 else 380) if comparison_visible else 320
	mouse_default_cursor_shape = Control.CURSOR_DRAG if comparison_visible or kind in ["charles", "ideal_gas"] else Control.CURSOR_ARROW
	tooltip_text = "Drag the curve to change temperature" if kind in ["charles", "ideal_gas"] else ("Drag the curve to change pressure" if kind == "real_gas" else "Drag the curve to change outlet pressure")
	if not comparison_visible: tooltip_text = "Drag the piston" if kind == "charles" else ("Drag the vessel edge" if kind == "ideal_gas" else "Use the instruments below")
	queue_redraw()

func section(index: int) -> Rect2:
	if not comparison_visible: return Rect2(Vector2.ZERO, size)
	if size.x < 660: return Rect2(0, index * 360, size.x, 360)
	return Rect2(index * size.x / 2, 0, size.x / 2, size.y)

func plot_rect() -> Rect2:
	var area: Rect2 = section(1)
	return Rect2(area.position + Vector2(50, 67), area.size - Vector2(76, 143))

func locate(point: Vector2) -> Vector2:
	var rect: Rect2 = plot_rect()
	return rect.position + Vector2((point.x - bounds.position.x) / bounds.size.x * rect.size.x, (bounds.end.y - point.y) / bounds.size.y * rect.size.y)

func vessel_rect() -> Rect2:
	var area: Rect2 = section(0)
	var volume_mode: bool = int(params.get("solve", 0)) == 1
	var ratio: float = pow(float(result.get("volume", 2.5)) / 2.5, 1.0 / 3.0)
	var width: float = clampf(area.size.x * 0.35 * ratio, area.size.x * 0.16, area.size.x * 0.65)
	var height: float = clampf(110 * ratio, 55, 170) if volume_mode else 145
	return Rect2((area.size.x - width) / 2, 280 - height, width, height)

func _gui_input(event: InputEvent) -> void:
	if not comparison_visible and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and result.has("volume"):
		primary_drag = false
		if kind == "charles": primary_drag = event.position.distance_to(Vector2(section(0).size.x * 0.42, 284 - float(result["volume"]) * 73)) < 32
		elif kind == "ideal_gas":
			var rect: Rect2 = vessel_rect()
			primary_drag = event.position.distance_to(Vector2(rect.end.x, rect.get_center().y)) < 32
	super._gui_input(event)
	if event is InputEventMouseButton and not event.pressed: primary_drag = false

func manipulate(at: Vector2) -> void:
	if result.is_empty(): return
	if not comparison_visible:
		if primary_drag and kind == "charles": parameter_changed.emit("temperature", clampf((284 - at.y) / 73 * 293.15 - 273.15, -100, 350))
		elif primary_drag and kind == "ideal_gas":
			var radius: float = maxf(2, at.x - section(0).size.x / 2)
			var volume: float = 2.5 * pow(radius / (section(0).size.x * 0.175), 3)
			if int(params["solve"]) == 0: parameter_changed.emit("volume", volume)
			else: parameter_changed.emit("pressure", float(params["amount"]) * BathysThermalModels.R * float(result["kelvin"]) / (100 * volume))
		return
	var rect: Rect2 = plot_rect()
	if rect.grow(12).has_point(at):
		var value: float = bounds.position.x + clampf((at.x - rect.position.x) / rect.size.x, 0, 1) * bounds.size.x
		parameter_changed.emit("temperature" if kind in ["charles", "ideal_gas"] else ("pressure" if kind == "real_gas" else "outlet"), value - 273.15 if kind in ["charles", "ideal_gas"] else value)
	elif kind == "charles" and section(0).has_point(at):
		parameter_changed.emit("temperature", clampf((285 - at.y) / 170, 0, 1) * 450 - 100)

func wrapped_words(at: Vector2, text: String, width: float, colour: Color = MUTED, font_size: int = 11) -> void:
	if not comparison_visible and text.length() > 58: return
	var line: String = ""
	var y: float = at.y
	for word: String in tr(text).split(" "):
		var trial: String = line + (" " if not line.is_empty() else "") + word
		if ThemeDB.fallback_font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and not line.is_empty():
			words(Vector2(at.x, y), line, colour, font_size)
			y += font_size + 3
			line = word
		else: line = trial
	words(Vector2(at.x, y), line, colour, font_size)

func _draw() -> void:
	draw_style_box(BathysUiStyle.box(Color("08232f"), BathysUiStyle.EDGE, 10, 0), Rect2(Vector2.ZERO, size))
	if result.is_empty(): return
	match kind:
		"charles": piston()
		"ideal_gas": ideal_box()
		"real_gas": real_volumes()
		"joule_thomson": flow()
	if comparison_visible: draw_plot()

func particles(rect: Rect2, count: int, kelvin: float, colour: Color = AQUA) -> void:
	var speed: float = 9 * sqrt(kelvin / 293.15)
	for i: int in count:
		var f: Vector2 = Vector2(fposmod(i * 0.618, 1), fposmod(i * 0.414 + 0.2, 1))
		var pos: Vector2 = rect.position + Vector2(10, 10) + (rect.size - Vector2(20, 20)) * f
		draw_circle(pos, 2.1, colour)
		var direction: Vector2 = Vector2.from_angle(i * 2.399)
		draw_line(pos, pos + direction * speed, Color(colour, 0.5), 1, true)

func piston() -> void:
	var area: Rect2 = section(0)
	wrapped_words(Vector2(16, 26), "Movable piston · fixed pressure and gas amount", area.size.x - 32, INK, 12)
	var x: float = area.size.x * 0.42
	var width: float = minf(125, area.size.x * 0.38)
	var bottom: float = 284
	var height: float = float(result["volume"]) * 73
	var chamber := Rect2(x - width / 2, bottom - height, width, height)
	draw_rect(chamber, Color("164b58"))
	draw_line(Vector2(chamber.position.x, 105), Vector2(chamber.position.x, bottom), MUTED, 2)
	draw_line(Vector2(chamber.end.x, 105), Vector2(chamber.end.x, bottom), MUTED, 2)
	draw_line(Vector2(chamber.position.x, bottom), chamber.end, MUTED, 2)
	draw_rect(Rect2(chamber.position - Vector2(5, 4), Vector2(width + 10, 8)), AQUA)
	draw_dashed_line(Vector2(chamber.position.x - 7, bottom - 73), Vector2(chamber.end.x + 7, bottom - 73), AMBER, 1, 4)
	particles(chamber.grow(-5), 24, result["kelvin"])
	grip(Vector2(x, chamber.position.y), true)
	words(Vector2(18, 76), tr("%.2f L") % float(result["volume"]), AQUA, 20)
	words(Vector2(18, 96), "P = 1 bar abs", MUTED, 11)
	wrapped_words(Vector2(18, 310), "Dashed: 1 L at 20°C. Same particles; longer arrows mean faster motion.", area.size.x - 36)

func ideal_box() -> void:
	var area: Rect2 = section(0)
	var volume_mode: bool = int(params["solve"]) == 1
	wrapped_words(Vector2(16, 26), ("Volume responds · pressure fixed" if volume_mode else "Sealed rigid vessel · volume fixed") if comparison_visible else "Move the vessel wall", area.size.x - 32, INK, 12)
	var rect: Rect2 = vessel_rect()
	var height: float = rect.size.y
	draw_rect(rect, Color("164b58"))
	draw_rect(rect, AQUA, false, 2)
	if not comparison_visible: grip(Vector2(rect.end.x, rect.get_center().y))
	particles(rect.grow(-4), clampi(roundi(float(params["amount"]) * 120), 2, 48), result["kelvin"])
	for i: int in 3:
		var y: float = rect.position.y + rect.size.y * (i + 1) / 4
		arrow(Vector2(rect.end.x, y), Vector2(rect.end.x + minf(45, 10 + float(result["pressure"]) * 5), y), AMBER)
	words(Vector2(18, 76), tr("%.2f bar abs") % float(result["pressure"]), AMBER, 18)
	words(Vector2(18, 98), tr("%.2f L") % float(result["volume"]), AQUA, 16)
	wrapped_words(Vector2(18, 315), "Dots and arrows are schematic. In volume mode the drawing uses a relative scale.", area.size.x - 36)

func real_volumes() -> void:
	var area: Rect2 = section(0)
	wrapped_words(Vector2(16, 26), "Same mole, pressure and temperature", area.size.x - 32, INK, 12)
	var width: float = minf(80, area.size.x * 0.24)
	for i: int in 2:
		var x: float = area.size.x * (0.3 if i == 0 else 0.72)
		var height: float = 132 * (1 if i == 0 else float(result["z"]))
		var rect := Rect2(x - width / 2, 258 - height, width, height)
		draw_rect(rect, Color("164b58"))
		draw_rect(rect, MUTED if i == 0 else AQUA, false, 2)
		particles(rect.grow(-4), 16, float(params["temperature"]) + 273.15, MUTED if i == 0 else AQUA)
		words(Vector2(x - width / 2, 286), "Ideal" if i == 0 else "Real · PR", MUTED if i == 0 else AQUA, 12)
		words(Vector2(x - width / 2, 305), tr("%.3f L") % float(result["ideal_l"] if i == 0 else result["molar_l"]), INK, 13)
	draw_dashed_line(Vector2(28, 126), Vector2(area.size.x - 28, 126), AMBER, 1, 4)
	words(Vector2(18, 80), tr("Volume ratio Z = %.3f") % float(result["z"]), AQUA, 17)
	if comparison_visible: wrapped_words(Vector2(18, 337), "A shared relative volume scale makes departures visible.", area.size.x - 36)

func flow() -> void:
	var area: Rect2 = section(0)
	var process: int = params["process"]
	wrapped_words(Vector2(16, 26), "Expansion doing shaft work" if process == 2 else "Insulated steady-flow throttle", area.size.x - 32, INK, 12)
	var mid: float = area.size.x / 2
	for i: int in 2:
		var x: float = 18 if i == 0 else mid + 24
		var width: float = mid - 42
		var temp: float = result["tin"] if i == 0 else result["tout"]
		var tint: Color = Color("226b8a").lerp(Color("b87945"), clampf((temp - 240) / 110, 0, 1))
		draw_rect(Rect2(x, 115, width, 127), Color(tint, 0.35))
		draw_rect(Rect2(x, 115, width, 127), tint, false, 2)
		words(Vector2(x + 7, 139), "Inlet" if i == 0 else "Outlet", INK, 12)
		words(Vector2(x + 7, 169), tr("%.0f bar abs") % float(result["pin"] if i == 0 else result["pout"]), AMBER, 14)
		words(Vector2(x + 7, 198), "%.1f°C" % (temp - 273.15), INK, 16)
		words(Vector2(x + 7, 220), "%.1f K" % temp, MUTED, 11)
	arrow(Vector2(mid - 22, 180), Vector2(mid + 22, 180), AQUA)
	if process == 2:
		draw_circle(Vector2(mid, 180), 15, AMBER, false, 2)
		arrow(Vector2(mid, 160), Vector2(mid, 78), AMBER)
		words(Vector2(mid - 10, 68), "W", AMBER, 14)
	else:
		draw_line(Vector2(mid, 152), Vector2(mid, 208), MUTED, 6)
		for i: int in 5: draw_circle(Vector2(mid, 156 + i * 10), 1.4, AQUA)
	words(Vector2(20, 282), tr("Temperature change: %+.1f K") % float(result["delta"]), AQUA if float(result["delta"]) < -0.01 else AMBER, 17)
	wrapped_words(Vector2(20, 313), "Reversible ideal-gas comparison; phase changes omitted." if process == 2 else "No heat or shaft work. Enthalpy includes flow work: h = u + Pv.", area.size.x - 40)

func draw_plot() -> void:
	var area: Rect2 = section(1)
	var rect: Rect2 = plot_rect()
	wrapped_words(area.position + Vector2(16, 26), plot_title, area.size.x - 32, INK, 12)
	for i: int in 3:
		var f: float = i / 2.0
		var y: float = rect.end.y - rect.size.y * f
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0.4, 0.65, 0.7, 0.17))
		words(Vector2(rect.position.x - 44, y + 4), ("%.2f" if kind == "real_gas" else "%.1f") % (bounds.position.y + bounds.size.y * f), MUTED, 10)
		words(Vector2(rect.position.x + rect.size.x * f - 8, rect.end.y + 20), "%.0f" % (bounds.position.x + bounds.size.x * f), MUTED, 10)
	draw_line(rect.position, Vector2(rect.position.x, rect.end.y), MUTED)
	draw_line(Vector2(rect.position.x, rect.end.y), rect.end, MUTED)
	var points := PackedVector2Array()
	for point: Vector2 in curve: points.append(locate(point))
	if points.size() > 1: draw_polyline(points, line_colour, 2, true)
	if kind == "charles": draw_dashed_line(locate(Vector2.ZERO), locate(Vector2(173.15, 173.15 / 293.15)), MUTED, 1, 4)
	if kind == "real_gas": draw_dashed_line(locate(Vector2(bounds.position.x, 1)), locate(Vector2(bounds.end.x, 1)), AMBER, 1, 5)
	var selected: Vector2
	match kind:
		"charles": selected = Vector2(result["kelvin"], result["volume"])
		"ideal_gas": selected = Vector2(result["kelvin"], result["pressure"] if int(params["solve"]) == 0 else result["volume"])
		"real_gas": selected = Vector2(params["pressure"], result["z"])
		_: selected = Vector2(params["outlet"], result["tout"])
	var pos: Vector2 = locate(selected)
	draw_dashed_line(Vector2(pos.x, rect.position.y), Vector2(pos.x, rect.end.y), INK, 1, 4)
	draw_circle(pos, 4.5, INK)
	wrapped_words(Vector2(rect.position.x, rect.end.y + 42), plot_footer, area.size.x - 66, AMBER if kind == "real_gas" else MUTED, 11)
