class_name BathysOpticsPlots
extends BathysLessonDiagram

signal probe_changed(value: float)
signal range_changed(value: float)
var stage: int = 0
var engine: BathysUnderwaterOptics
var params: Dictionary = {}
var result: Dictionary = {}
var curves: Array[Vector3] = []
const VIOLET := Color("b5a3f3")
const RED := Color("f18e87")

func adapt() -> void:
	custom_minimum_size.y = 125 if stage == 0 else (600 if size.x < 660 else 350)
	mouse_default_cursor_shape = Control.CURSOR_ARROW if stage == 0 else Control.CURSOR_DRAG
	tooltip_text = "" if stage == 0 else "Drag the spectral plot to select a wavelength" if stage == 1 else "Drag the model plot to change viewing distance"
	queue_redraw()

func _draw() -> void:
	draw_style_box(BathysUiStyle.box(Color("08232f"), BathysUiStyle.EDGE, 10, 0), Rect2(Vector2.ZERO, size))
	if params.is_empty() or result.is_empty(): return
	match stage:
		0: geometry()
		1: spectra(); phase_plot()
		2: coefficients(); components()

func panel(index: int) -> Rect2:
	if size.x < 660: return Rect2(0, index * 300, size.x, 300)
	return Rect2(index * size.x * 0.5, 0, size.x * 0.5, size.y)

func plot(index: int) -> Rect2:
	var area: Rect2 = panel(index)
	return Rect2(area.position + Vector2(47, 51), area.size - Vector2(72, 111))

func manipulate(at: Vector2) -> void:
	if stage == 0 or not plot(0).grow(10).has_point(at): return
	var p: Rect2 = plot(0)
	var f: float = clampf((at.x - p.position.x) / p.size.x, 0, 1)
	if stage == 1: probe_changed.emit(400 + f * 300)
	else: range_changed.emit(clampf(f * 15, 0.2, 15))

func axes(rect: Rect2, xmin: float, xmax: float, ymin: float, ymax: float, unit: String) -> void:
	for i: int in 3:
		var f: float = i / 2.0
		var y: float = rect.end.y - rect.size.y * f
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0.4, 0.65, 0.7, 0.16))
		words(Vector2(rect.position.x - 34, y + 4), "%.2f" % lerpf(ymin, ymax, f), MUTED, 10)
		words(Vector2(rect.position.x + rect.size.x * f - 7, rect.end.y + 20), "%.0f" % lerpf(xmin, xmax, f), MUTED, 10)
	draw_line(rect.position, Vector2(rect.position.x, rect.end.y), MUTED)
	draw_line(Vector2(rect.position.x, rect.end.y), rect.end, MUTED)
	words(rect.position + Vector2(-30, -12), unit, MUTED, 10)

func geometry() -> void:
	words(Vector2(15, 21), "Schematic light paths", INK, 12)
	var camera := Vector2(45, 83)
	var target := Vector2(size.x - 46, 83)
	draw_rect(Rect2(camera - Vector2(14, 10), Vector2(28, 20)), MUTED, false, 1.5)
	draw_circle(camera + Vector2(7, 0), 4, AQUA)
	draw_rect(Rect2(target - Vector2(10, 18), Vector2(20, 36)), AQUA, false, 2)
	arrow(target - Vector2(14, 0), camera + Vector2(20, 0), AQUA)
	words(Vector2(size.x * 0.44, 103), tr("View: %.1f m") % float(params["range"]), AQUA, 11)
	arrow(Vector2(target.x, 31), target - Vector2(0, 22), AMBER)
	words(Vector2(size.x - 166, 33), tr("Depth: %.1f m") % float(params["depth"]), AMBER, 11)
	if bool(params["torch"]):
		var lamp: Vector2 = camera - Vector2(0, float(params["baseline"]) * 32)
		draw_circle(lamp, 4, AMBER)
		arrow(lamp + Vector2(7, 0), target - Vector2(13, 3), AMBER)
		for i: int in 9:
			var s: float = (i + 1) / 10.0
			draw_circle(camera.lerp(target, s) + Vector2(0, sin(i * 2.4) * 8), 1.7, VIOLET)
		words(Vector2(16, 118), "Torch → object → camera; nearby particles also send light back", MUTED, 10)
	else:
		words(Vector2(16, 118), "Daylight loses wavelengths on the way down and on the way to you", MUTED, 10)

func spectra() -> void:
	var rect: Rect2 = plot(0)
	words(panel(0).position + Vector2(16, 25), "Spectral water properties", INK, 13)
	var profile: Dictionary = engine.water(params)
	var maximum: float = 0.1
	for i: int in engine.wavelengths.size(): maximum = maxf(maximum, float(profile["a"][i]) + float(profile["b"][i]))
	maximum *= 1.08
	axes(rect, 400, 700, 0, maximum, "m⁻¹")
	for key: String in ["a", "b", "c", "kd"]:
		var points := PackedVector2Array()
		for i: int in engine.wavelengths.size():
			var value: float = float(profile["a"][i]) + float(profile["b"][i]) if key == "c" else float(profile[key][i])
			points.append(Vector2(rect.position.x + rect.size.x * i / (engine.wavelengths.size() - 1), rect.end.y - rect.size.y * value / maximum))
		draw_polyline(points, {"a": AMBER, "b": VIOLET, "c": AQUA, "kd": MUTED}[key], 2, true)
	var x: float = rect.position.x + rect.size.x * (float(params["probe"]) - 400) / 300
	draw_dashed_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), INK, 1, 4)
	words(Vector2(rect.position.x, rect.end.y + 40), "Wavelength · nm", MUTED, 11)
	words(Vector2(rect.position.x, rect.end.y + 56), "c = a + b; Kd is a different quantity", MUTED, 10)

func phase_plot() -> void:
	var rect: Rect2 = plot(1)
	words(panel(1).position + Vector2(16, 25), "HG phase function · logarithmic scale", INK, 12)
	axes(rect, 0, 180, -3, 3, "log₁₀ p")
	var points := PackedVector2Array()
	for i: int in 181:
		var value: float = log(BathysUnderwaterOptics.phase_hg(cos(deg_to_rad(i)), params["g"])) / log(10)
		points.append(Vector2(rect.position.x + rect.size.x * i / 180, rect.end.y - rect.size.y * (value + 3) / 6))
	draw_polyline(points, AMBER, 2, true)
	var cone_width: float = rect.size.x * float(params["cone"]) / 180
	draw_rect(Rect2(rect.position, Vector2(cone_width, rect.size.y)), Color(0.44, 0.9, 0.85, 0.12))
	words(Vector2(rect.position.x, rect.end.y + 40), "0° forward · 180° backward", MUTED, 11)
	words(Vector2(rect.position.x, rect.end.y + 56), "Chosen surrogate, not a measured Jerlov phase", MUTED, 10)

func coefficients() -> void:
	var rect: Rect2 = plot(0)
	words(panel(0).position + Vector2(16, 25), "Effective Y coefficients / range", INK, 12)
	var maximum: float = 0.1
	for point: Vector3 in curves: maximum = maxf(maximum, maxf(point.x, maxf(point.y, point.z)))
	maximum *= 1.08
	axes(rect, 0, 15, 0, maximum, "m⁻¹")
	for channel: int in 3:
		var line := PackedVector2Array()
		for i: int in curves.size():
			var distance: float = 0.2 + 14.8 * i / (curves.size() - 1)
			line.append(Vector2(rect.position.x + rect.size.x * distance / 15, rect.end.y - rect.size.y * curves[i][channel] / maximum))
		draw_polyline(line, [INK, RED, AQUA][channel], 2, true)
	var x: float = rect.position.x + rect.size.x * float(params["range"]) / 15
	draw_dashed_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), MUTED, 1, 4)
	words(Vector2(rect.position.x, rect.end.y + 40), "Viewing distance · m", MUTED, 11)
	words(Vector2(rect.position.x, rect.end.y + 56), "Ambient-only, linear CIE Y; not camera RGB fits", MUTED, 10)

func components() -> void:
	var area: Rect2 = panel(1)
	words(area.position + Vector2(16, 25), "White-target signal budget", INK, 12)
	var forward: float = result["forward_share"]
	var back: float = result["veil_share"]
	var shares: Array[float] = [maxf(0, 1 - forward - back), forward, back]
	var x: float = area.position.x + 35
	var y: float = area.position.y + 74
	var width: float = area.size.x - 70
	for i: int in 3:
		var w: float = width * shares[i]
		if w > 0: draw_rect(Rect2(x, y, w, 44), [AQUA, AMBER, VIOLET][i])
		x += w
		words(area.position + Vector2(25, 150 + i * 28), tr(["Direct: %.1f%%", "Forward halo: %.1f%%", "Backscatter: %.1f%%"][i]) % (shares[i] * 100), [AQUA, AMBER, VIOLET][i], 13)
	words(area.position + Vector2(16, area.size.y - 25), "Light fractions, not visibility probabilities", MUTED, 11)
