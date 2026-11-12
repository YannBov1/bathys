class_name BathysTransportDiagram
extends BathysLessonDiagram

signal parameter_changed(key: String, value: float)
const VIOLET := Color("b5a3f3")
var kind: String = "viscosity"
var params: Dictionary = {}
var result: Dictionary = {}

var stage: int = 0
var phase: float = 0
var curve: Array[float] = []
var reference_curve: Array[float] = []
var plot_key: String = "temperature"
var x_min: float = 0
var x_max: float = 35
var x_caption: String = ""
var y_caption: String = ""
var picked: String = ""
var pickup := Vector2.ZERO
var original: Dictionary = {}

func _ready() -> void:
	super._ready()
	focus_mode = FOCUS_ALL
	mouse_filter = MOUSE_FILTER_PASS

func adapt() -> void:
	custom_minimum_size.y = (700 if size.x < 660 else 370) if comparison_visible else 340
	tooltip_text = "Drag the white grips or the object; arrow keys adjust the selected parameter"
	queue_redraw()

func section(index: int) -> Rect2:
	if not comparison_visible: return Rect2(Vector2.ZERO, size)
	return Rect2(0, index * 350, size.x, 350) if size.x < 660 else Rect2(index * size.x / 2, 0, size.x / 2, size.y)

func graph() -> Rect2:
	var area: Rect2 = section(1)
	return Rect2(area.position + Vector2(54, 64), area.size - Vector2(78, 133))

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	phase = fposmod(phase + delta * 0.4, 1.4)
	queue_redraw()

func plate_y() -> float:
	return 252 - (30 + 5 * float(params.get("gap", 5)))

func tube() -> Rect2:
	var width: float = section(0).size.x
	var height: float = 6 + 4 * float(params.get("diameter", 10))
	return Rect2(36, 168 - height / 2, (width - 100) * (0.4 + 0.6 * (float(params.get("length", 0.3)) - 0.1) / 0.9), height)

func cold_x() -> float:
	return 104 + maxf(30, section(0).size.x - 180) * (float(params.get("gap", 5)) - 1) / 19

func source_position() -> Vector2:
	var area: Rect2 = section(0)
	var radius: float = 48 + (float(params.get("range", 10)) - 1) / 19 * minf(40, area.size.x * 0.2)
	var angle: float = deg_to_rad(params.get("bearing", 55))
	return Vector2(area.size.x / 2, 166) + Vector2(sin(angle), -cos(angle)) * radius

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			picked = ""
			pickup = event.position
			original = params.duplicate()
			var area: Rect2 = section(0)
			if comparison_visible and graph().grow(10).has_point(event.position) and not (kind == "sound" and stage == 1): picked = "plot"
			elif area.has_point(event.position):
				match kind:
					"viscosity":
						if event.position.distance_to(Vector2(area.size.x - 24, plate_y())) < 25: picked = "gap"
						elif Rect2(30, plate_y() - 30, area.size.x - 62, 42).has_point(event.position): picked = "speed"
					"flow":
						var rect: Rect2 = tube()
						if event.position.distance_to(Vector2(rect.get_center().x, rect.position.y - 15)) < 25: picked = "diameter"
						elif event.position.distance_to(Vector2(rect.end.x + 12, 168)) < 25: picked = "length"
						elif rect.has_point(event.position) or Rect2(36, 57, area.size.x - 70, 25).has_point(event.position): picked = "flow"
					"heat_transfer":
						if stage == 0 and Rect2(cold_x() - 6, 94, 52, 148).has_point(event.position): picked = "gap"
						elif stage == 1 and event.position.distance_to(Vector2(area.size.x - 58, 76)) < 27: picked = "speed"
						elif stage == 2 and (Rect2(34, 99, 38, 139).has_point(event.position) or event.position.distance_to(Vector2(52, 253)) < 27): picked = "emissivity"
					"thermal_properties":
						if stage == 0 and (Rect2(area.size.x * 0.29 - 40, 115, 80, 145).has_point(event.position) or event.position.distance_to(Vector2(area.size.x * 0.29, 285)) < 27): picked = "energy"
						elif stage == 1 and Rect2(cold_x() - 6, 94, 52, 148).has_point(event.position): picked = "gap"
					"sound":
						if stage == 3 and event.position.distance_to(source_position()) < 29: picked = "source"
						elif stage == 2 and Rect2(area.size.x - 78, 144, 58, 68).has_point(event.position): picked = "range"
						elif stage == 0:
							var x: float = 130 + (area.size.x - 180) * float(params["range"]) / 100
							if Rect2(x - 28, 106, 56, 48).has_point(event.position) or Rect2(x - 28, 216, 56, 48).has_point(event.position): picked = "range"
			if picked.is_empty(): return
			grab_focus()
			change_at(event.position)
		else:
			if picked.is_empty(): return
			picked = ""
		accept_event()
	elif event is InputEventMouseMotion and not picked.is_empty():
		change_at(event.position)
		accept_event()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		var key: String = "bearing" if kind == "sound" and stage == 3 else plot_key
		var increment: float = 1 if key in ["bearing", "temperature", "flow", "range"] else 0.1
		parameter_changed.emit(key, float(params[key]) + (-increment if event.keycode in [KEY_LEFT, KEY_UP] else increment))
		accept_event()

func change_at(at: Vector2) -> void:
	if picked == "plot":
		parameter_changed.emit(plot_key, lerpf(x_min, x_max, clampf((at.x - graph().position.x) / graph().size.x, 0, 1)))
		return
	if picked == "source":
		var offset: Vector2 = at - Vector2(section(0).size.x / 2, 166)
		parameter_changed.emit("bearing", rad_to_deg(atan2(offset.x, -offset.y)))
		parameter_changed.emit("range", clampf(1 + (offset.length() - 48) / minf(40, section(0).size.x * 0.2) * 19, 1, 20))
		return
	var delta_position: Vector2 = at - pickup
	var value: float = original.get(picked, 0)
	match picked:
		"gap": value -= delta_position.y / 5 if kind == "viscosity" else -delta_position.x / maxf(30, section(0).size.x - 180) * 19
		"speed": value += delta_position.x / maxf(80, section(0).size.x - 100)
		"diameter": value -= delta_position.y / 2
		"length": value += delta_position.x / maxf(80, (section(0).size.x - 100) * 0.6) * 0.9
		"flow": value += delta_position.x / maxf(80, section(0).size.x - 100) * 60
		"energy": value -= delta_position.y / 100 * (1 if int(params["basis"]) == 1 else 200)
		"emissivity": value += delta_position.x / maxf(80, section(0).size.x - 100)
		"range": value += delta_position.x / maxf(80, section(0).size.x - 100) * (1000 if stage == 2 else 100)
	parameter_changed.emit(picked, value)

func _draw() -> void:
	draw_style_box(BathysUiStyle.box(Color("08232f"), BathysUiStyle.EDGE, 10, 0), Rect2(Vector2.ZERO, size))
	if result.is_empty(): return
	match kind:
		"viscosity": draw_shear()
		"flow": draw_pipe()
		"heat_transfer": draw_heat()
		"thermal_properties": draw_material()
		"sound": draw_sound()
	if comparison_visible:
		if kind == "sound" and stage == 1: draw_reflection_budget()
		else: draw_curve()

func wrapped_words(at: Vector2, message: String, width: float, color: Color = MUTED, font_size: int = 11) -> void:
	var line: String = ""
	var y: float = at.y
	for word: String in tr(message).split(" "):
		var trial: String = line + (" " if not line.is_empty() else "") + word
		if ThemeDB.fallback_font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and not line.is_empty():
			words(Vector2(at.x, y), line, color, font_size)
			y += font_size + 3
			line = word
		else: line = trial
	words(Vector2(at.x, y), line, color, font_size)

func title(message: String) -> void:
	wrapped_words(Vector2(16, 27), message, section(0).size.x - 32, INK, 13)

func compact(number: float) -> String:
	var magnitude: float = absf(number)
	if magnitude < 0.00000001: return "0"
	if magnitude >= 10000 or magnitude < 0.01:
		var exponent: int = floori(log(magnitude) / log(10))
		return "%.2f" % (number / pow(10, exponent)) + "e" + str(exponent)
	return ("%.0f" if magnitude >= 100 else ("%.1f" if magnitude >= 10 else ("%.2f" if magnitude >= 1 else "%.3f"))) % number

func value(at: Vector2, number: float, unit: String, color: Color = AQUA) -> void:
	words(at, compact(number / 1000 if unit == "W" and absf(number) >= 1000 else number) + " " + ("kW" if unit == "W" and absf(number) >= 1000 else unit), color, 17)

func medium_name() -> String:
	return ["Water", "Air", "Gas mixture"][int(params["medium"])]

func draw_shear() -> void:
	var width: float = section(0).size.x
	title("Slide the plate; layers follow")
	words(Vector2(18, 60), medium_name(), AQUA, 12)
	var top: float = plate_y()
	var height: float = 252 - top
	draw_rect(Rect2(40, top, width - 88, height), Color("164552"))
	for row: int in 7:
		var f: float = (row + 0.5) / 7
		var y: float = 252 - f * height
		draw_line(Vector2(42, y), Vector2(width - 50, y), Color(AQUA, 0.2))
		for i: int in 5:
			var x: float = 44 + fposmod(i / 5.0 + phase * float(params["speed"]) * f, 1) * (width - 100)
			draw_circle(Vector2(x, y), 2, AQUA)
		arrow(Vector2(52, y), Vector2(52 + f * float(params["speed"]) * 90, y), AQUA, 1)
	draw_line(Vector2(35, 253), Vector2(width - 43, 253), MUTED, 6)
	draw_line(Vector2(35, top), Vector2(width - 43, top), INK, 6)
	grip(Vector2(width - 65, top - 15))
	grip(Vector2(width - 24, top), true)
	var resistance: float = 20 + 70 * float(result["stress"]) / (float(result["stress"]) + 0.03)
	arrow(Vector2(width - 50, top - 42), Vector2(width - 50 - resistance, top - 42), AMBER, 3)
	value(Vector2(18, 94), float(result["properties"]["mu"]) * 1000, "mPa·s")
	value(Vector2(18, 291), float(result["force"]) * 1000, "mN", AMBER)
	words(Vector2(18, 316), tr("Kinematic viscosity: %.2f mm²/s") % (float(result["nu"]) * 1e6), MUTED, 11)

func draw_pipe() -> void:
	title("Open the tube; change the flow")
	var rect: Rect2 = tube()
	draw_rect(rect, Color("164552"))
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), INK, 3)
	draw_line(Vector2(rect.position.x, rect.end.y), rect.end, INK, 3)
	var turbulent: float = result["fraction"]
	for row: int in 7:
		var f: float = (row + 0.5) / 7
		var local_speed: float = lerpf(2 * (1 - pow((f - 0.5) * 2, 2)), 1, turbulent)
		for i: int in 7:
			var x: float = rect.position.x + fposmod(i / 7.0 + phase * local_speed, 1) * rect.size.x
			var y: float = rect.position.y + f * rect.size.y + sin(x * 0.13 + phase * 18 + row) * rect.size.y * 0.04 * turbulent
			draw_circle(Vector2(x, y), 2, AQUA.lerp(AMBER, turbulent))
	for i: int in int(turbulent * 4): draw_arc(rect.position + rect.size * Vector2((i + 1) / 5.0, 0.5), rect.size.y * 0.2, phase * TAU + i, phase * TAU + i + 4, 20, AMBER, 1, true)
	grip(Vector2(rect.get_center().x, rect.position.y - 15), true)
	grip(Vector2(rect.end.x + 12, 168))
	arrow(Vector2(42, 68), Vector2(100 + float(params["flow"]) / 60 * (section(0).size.x - 150), 68), AQUA, 3)
	words(Vector2(18, 55), tr(str(result["regime"])) + "   Re %.0f" % result["re"], AMBER if turbulent > 0 else AQUA, 14)
	value(Vector2(18, 277), float(result["pressure"]) / (1000 if float(result["pressure"]) >= 1000 else 1), "kPa" if float(result["pressure"]) >= 1000 else "Pa", AMBER)
	words(Vector2(18, 303), tr("Mean speed: %.2f m/s") % result["velocity"], AQUA, 12)
	words(Vector2(18, 324), "Straight smooth tube · schematic motion", MUTED, 10)

func draw_layer(properties: Dictionary, hot: float, cold: float, heat: float) -> void:
	var x: float = cold_x()
	draw_rect(Rect2(55, 106, x - 55, 124), Color("23525f"))
	draw_rect(Rect2(44, 99, 12, 138), AMBER)
	draw_rect(Rect2(x, 99, 12, 138), Color("61bce6"))
	for row: int in 4:
		arrow(Vector2(62, 125 + row * 28), Vector2(x - 5, 125 + row * 28), AMBER, 1 + 4 * heat / (heat + 25))
	grip(Vector2(x + 22, 168))
	words(Vector2(30, 84), "%.1f°C" % hot, AMBER, 13)
	words(Vector2(x - 10, 84), "%.1f°C" % cold, AQUA, 13)
	value(Vector2(18, 279), heat, "W", AMBER)
	if result.has("air_heat"): words(Vector2(maxf(145, section(0).size.x * 0.49), 279), tr("Air: %s W") % compact(result["air_heat"]), MUTED, 12)
	words(Vector2(18, 307), tr("Conductivity: %s W/(m·K)") % compact(properties["k"]), AQUA, 12)

func draw_heat() -> void:
	match stage:
		0:
			title("Conduction · through a still layer")
			words(Vector2(18, 58), medium_name(), AQUA, 12)
			draw_layer(result["properties"], 32, params["temperature"], result["heat"])
		1:
			title("Convection · warmed fluid moves away")
			words(Vector2(18, 57), medium_name(), AQUA, 12)
			var width: float = section(0).size.x
			for row: int in 6:
				var y: float = 115 + row * 20
				for i: int in 4:
					var x: float = 20 + fposmod(i / 4.0 + phase * float(params["speed"]), 1) * (width - 40)
					arrow(Vector2(x - 8, y), Vector2(x + 8, y), AQUA if x < width / 2 else AMBER, 1.5)
			var sample_rect := Rect2(width / 2 - 22, 117, 44, 105)
			draw_style_box(BathysUiStyle.box(Color("a05f3a"), AMBER, 8, 0), sample_rect)
			words(sample_rect.position + Vector2(0, 59), "32°C", INK, 14)
			grip(Vector2(width - 58, 76))
			value(Vector2(18, 278), result["heat"], "W", AMBER)
			words(Vector2(maxf(145, width * 0.49), 278), tr("Air: %s W") % compact(result["air_heat"]), MUTED, 12)
			words(Vector2(18, 306), tr("Heat-transfer coefficient: %.0f W/(m²·K)") % result["h"], AQUA, 11)
		2:
			title("Radiation · across an air/vacuum gap")
			var width: float = section(0).size.x
			var finish: Color = Color("c0d0d5").lerp(Color("1d252a"), params["emissivity"])
			draw_rect(Rect2(42, 106, 20, 126), finish)
			draw_rect(Rect2(width - 65, 106, 20, 126), Color("31849c"))
			for row: int in 4:
				var points := PackedVector2Array()
				for i: int in 41: points.append(Vector2(68 + (width - 145) * i / 40, 120 + row * 29 + sin(i * 0.7 - phase * 15) * 5))
				draw_polyline(points, Color(AMBER, 0.25 + float(params["emissivity"]) * 0.75), 2, true)
			words(Vector2(24, 85), "%.1f°C" % params["hot"], AMBER, 13)
			words(Vector2(width - 95, 85), "%.1f°C" % params["temperature"], AQUA, 13)
			grip(Vector2(52, 253))
			value(Vector2(18, 291), result["heat"], "W", AMBER)
			words(Vector2(18, 317), "Net radiative exchange", MUTED, 11)

func draw_material() -> void:
	if stage == 1:
		title("Conductivity · same layer geometry")
		words(Vector2(18, 58), ["Water", "Aluminium", "Copper", "Gas mixture"][int(params["material"])], AQUA, 12)
		draw_layer(result["properties"], 32, 12, result["heat"])
		return
	title("Same energy · compare temperature rise")
	var air: Dictionary = BathysTransportModels.gas(20)
	var mass: float = 0.05 if int(params["basis"]) == 0 else air["rho"] * 0.00005
	var reference_rise: float = float(params["energy"]) / (mass * air["cp"])
	var maximum: float = maxf(0.001, maxf(result["rise"], reference_rise))
	var width: float = section(0).size.x
	for i: int in 2:
		var center: float = width * (0.29 if i == 0 else 0.74)
		var rise: float = result["rise"] if i == 0 else reference_rise
		draw_style_box(BathysUiStyle.box(Color("164552"), AQUA if i == 0 else MUTED, 8, 0), Rect2(center - 33, 121, 66, 119))
		var height: float = rise / maximum * 92
		draw_rect(Rect2(center + 17, 234 - height, 8, height), AMBER if i == 0 else MUTED)
		words(Vector2(center - 35, 99), ["Water", "Aluminium", "Copper", "Gas mixture"][int(params["material"])] if i == 0 else "Air", AQUA if i == 0 else MUTED, 12)
		var sample_mass: float = result["mass"] if i == 0 else mass
		var density: float = result["properties"]["rho"] if i == 0 else air["rho"]
		var amount: String = compact(sample_mass * 1000) + " g"
		if int(params["basis"]) == 0:
			var litres: float = sample_mass / density * 1000
			amount = compact(litres if litres >= 1 else litres * 1000) + (" L" if litres >= 1 else " mL")
		words(Vector2(center - 34, 114), amount, MUTED, 10)
		words(Vector2(center - 37, 267), "ΔT %s K" % compact(rise), AQUA if i == 0 else MUTED, 14)
		for j: int in 10: draw_circle(Vector2(center - 23 + fposmod(j * 0.618, 1) * 32, 135 + fposmod(j * 0.414, 1) * 92), 2, AQUA if i == 0 else MUTED)
		if i == 0: grip(Vector2(center, 285), true)
	words(Vector2(18, 315), tr("Specific heat: %.0f J/(kg·K)") % result["properties"]["cp"], AQUA, 11)
	words(Vector2(18, 337), tr("Sample capacity: %s J/K") % compact(result["capacity"]), AMBER, 12)

func speaker(at: Vector2, color: Color = AQUA) -> void:
	draw_texture_rect(preload("res://Assets/Icons/transport-sound.svg"), Rect2(at - Vector2(16, 16), Vector2(32, 32)), false, color)

func draw_sound() -> void:
	var width: float = section(0).size.x
	match stage:
		0:
			title("Same distance · two arrival times")
			var end_x: float = 130 + (width - 180) * float(params["range"]) / 100
			for row: int in 2:
				var y: float = 125 + row * 110
				draw_rect(Rect2(20, y - 35, width - 40, 69), Color("0b3747") if row == 0 else Color("16303b"))
				speaker(Vector2(42, y))
				draw_texture_rect(preload("res://Assets/Icons/buoyancy-diver.svg"), Rect2(end_x - 20, y - 15, 40, 30), false)
				grip(Vector2(end_x, y + 25))
				var progress: float = minf(1, phase * (float(result["c"]) / float(result["air_c"]) if row == 0 else 1))
				var x: float = lerpf(62, end_x - 18, progress)
				draw_line(Vector2(x, y - 23), Vector2(x, y + 23), AQUA if row == 0 else MUTED, 3)
				words(Vector2(25, y - 43), "Water" if row == 0 else "Air", AQUA if row == 0 else MUTED, 12)
				words(Vector2(25, y + 50), "%.1f m/s   %.2f ms" % [result["c"] if row == 0 else result["air_c"], result["water_ms"] if row == 0 else result["air_ms"]], AQUA if row == 0 else MUTED, 12)
			words(Vector2(18, 332), "Wavefronts slowed for comparison", MUTED, 10)
		1:
			title("Impedance mismatch reflects sound")
			var mid: float = width / 2
			draw_rect(Rect2(mid, 69, width - mid - 1, 185), Color("193e48"))
			draw_line(Vector2(mid, 69), Vector2(mid, 254), INK, 2)
			arrow(Vector2(25, 117), Vector2(mid - 9, 117), AMBER, 4)
			arrow(Vector2(mid - 9, 174), Vector2(25, 174), AQUA, 1 + 7 * sqrt(result["reflection"]))
			arrow(Vector2(mid + 9, 215), Vector2(width - 28, 215), VIOLET, 1 + 7 * sqrt(result["transmission"]))
			words(Vector2(18, 58), "Water", AQUA, 12)
			words(Vector2(mid + 13, 58), ["Air", "Water", "Steel"][int(params["boundary"])], VIOLET, 12)
			words(Vector2(18, 82), "Z " + compact(float(result["z"]) / 1e6) + " MRayl", AQUA, 10)
			words(Vector2(mid + 13, 82), "Z " + compact(float(result["z2"]) / 1e6) + " MRayl", VIOLET, 10)
			words(Vector2(18, 291), tr("Reflected: %.2f%%") % (float(result["reflection"]) * 100), AQUA, 16)
			words(Vector2(18, 318), tr("Transmitted: %.2f%%") % (float(result["transmission"]) * 100), VIOLET, 13)
		2:
			title("Spreading and absorption are different")
			words(Vector2(18, 59), "Reference seawater · pH 8", MUTED, 11)
			var source := Vector2(38, 164)
			speaker(source)
			draw_texture_rect(preload("res://Assets/Icons/buoyancy-diver.svg"), Rect2(width - 72, 150, 44, 28), false)
			grip(Vector2(width - 50, 198))
			for i: int in 5:
				var radius: float = 30 + i * (width - 83) / 5
				draw_arc(source, radius, -0.24, 0.24, 28, Color(AQUA, 0.85 / (1 + i) * exp(-float(result["alpha"]) * i / 100)), 2, true)
			value(Vector2(18, 267), result["loss"], "dB", AMBER)
			words(Vector2(18, 294), tr("Spreading %.1f dB   absorption %.2f dB") % [result["spread"], result["absorption"]], AQUA, 11)
			words(Vector2(18, 321), "Ultrasound above 20 kHz", MUTED, 11)
		3:
			title("Move the sound around the head")
			var head := Vector2(width / 2, 166)
			var source: Vector2 = source_position()
			var ghost := Vector2(source.x, head.y * 2 - source.y)
			draw_circle(head, 23, Color("45606b"))
			draw_arc(head, 23, 0, TAU, 40, INK, 1.5, true)
			draw_colored_polygon(PackedVector2Array([head + Vector2(-5, -21), head + Vector2(0, -30), head + Vector2(5, -21)]), INK)
			for sign_value: int in [-1, 1]:
				var ear: Vector2 = head + Vector2(sign_value * 25, 0)
				draw_circle(ear, 5, AQUA)
				draw_dashed_line(source, ear, Color(AQUA, 0.5), 1, 4)
			speaker(source, AMBER)
			if ghost.distance_to(source) > 36:
				draw_arc(ghost, 14, 0, TAU, 32, Color(MUTED, 0.5), 1, true)
				words(ghost + Vector2(-4, 4), "?", MUTED, 12)
			words(Vector2(18, 287), tr("Water Δt: %+.1f µs") % result["delay_water"], AQUA, 15)
			words(Vector2(18, 310), tr("Air Δt: %+.1f µs") % result["delay_air"], MUTED, 13)
			words(Vector2(18, 332), "Mirror source: same timing cue", MUTED, 10)

func draw_reflection_budget() -> void:
	var area: Rect2 = section(1)
	words(area.position + Vector2(16, 27), "Acoustic intensity fractions", INK, 13)
	var rect: Rect2 = graph()
	for i: int in 3:
		var fraction: float = [1.0, result["reflection"], result["transmission"]][i]
		var x: float = rect.position.x + rect.size.x * (i + 0.5) / 3
		var height: float = rect.size.y * fraction
		draw_rect(Rect2(x - 20, rect.end.y - height, 40, height), [AMBER, AQUA, VIOLET][i])
		words(Vector2(x - 18, rect.end.y + 22), ["In", "Back", "Through"][i], MUTED, 11)
		words(Vector2(x - 20, rect.end.y - height - 7), "%.1f%%" % (fraction * 100), INK, 11)
	words(Vector2(rect.position.x, rect.end.y + 49), "Reflected + transmitted = incident", MUTED, 10)

func draw_curve() -> void:
	var area: Rect2 = section(1)
	var rect: Rect2 = graph()
	wrapped_words(area.position + Vector2(16, 26), y_caption, area.size.x - 32, INK, 12)
	var low: float = 0
	var high: float = 0.0001
	for number: float in curve + reference_curve: low = minf(low, number); high = maxf(high, number)
	if low < 0: low *= 1.08
	high *= 1.08
	for i: int in 3:
		var f: float = i / 2.0
		var y: float = rect.end.y - rect.size.y * f
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(MUTED, 0.2))
		words(Vector2(rect.position.x - 47, y + 4), compact(lerpf(low, high, f)), MUTED, 10)
		words(Vector2(rect.position.x + rect.size.x * f - 7, rect.end.y + 20), compact(lerpf(x_min, x_max, f)), MUTED, 10)
	for index: int in 2:
		var data: Array[float] = curve if index == 0 else reference_curve
		if data.size() < 2: continue
		var points := PackedVector2Array()
		for i: int in data.size(): points.append(Vector2(rect.position.x + rect.size.x * i / (data.size() - 1), rect.end.y - rect.size.y * (data[i] - low) / (high - low)))
		draw_polyline(points, AQUA if index == 0 else MUTED, 2, true)
	var fraction: float = clampf((float(params[plot_key]) - x_min) / (x_max - x_min), 0, 1)
	var index: int = clampi(roundi(fraction * 60), 0, curve.size() - 1)
	var point := Vector2(rect.position.x + rect.size.x * fraction, rect.end.y - rect.size.y * (curve[index] - low) / (high - low))
	draw_dashed_line(Vector2(point.x, rect.position.y), Vector2(point.x, rect.end.y), INK, 1, 4)
	draw_circle(point, 4, INK)
	wrapped_words(Vector2(rect.position.x, rect.end.y + 43), x_caption, rect.size.x, MUTED, 11)
	if not reference_curve.is_empty():
		words(Vector2(rect.position.x, rect.end.y + 60), "Grey: spreading only" if kind == "sound" and stage == 2 else "Grey: air reference", MUTED, 10)
