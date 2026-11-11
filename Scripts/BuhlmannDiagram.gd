class_name BathysBuhlmannDiagram
extends BathysLessonDiagram

signal compartment_selected(index: int)
signal exposure_time_changed(minutes: float)
signal preview_depth_changed(depth: float)

const VIOLET := Color("b5a3f3")
const RED := Color("ff6676")
var state: Dictionary = {}
var selected: int = 0
var exposure_depth: float = 30.0
var exposure_minutes: float = 30.0
var low: float = 0.3
var high: float = 0.85
var ascent: bool = false

func _ready() -> void:
	super._ready()
	focus_mode = Control.FOCUS_ALL

func adapt() -> void:
	custom_minimum_size.y = 620 if comparison_visible and size.x < 680 else 360
	tooltip_text = "Select a compartment · Left/Right keys to compare · Drag the curve to explore" if comparison_visible else "Select a tissue bar"
	queue_redraw()

func section(index: int) -> Rect2:
	if not comparison_visible: return Rect2(Vector2.ZERO, size)
	if size.x < 680:
		return Rect2(0, index * 310, size.x, 310)
	return Rect2(index * size.x * 0.5, 0, size.x * 0.5, size.y)

func bars_rect() -> Rect2:
	var area: Rect2 = section(0)
	return Rect2(area.position + Vector2(40, 61), area.size - Vector2(57, 122))

func curve_rect() -> Rect2:
	var area: Rect2 = section(1)
	return Rect2(area.position + Vector2(48, 61), area.size - Vector2(73, 141))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_LEFT, KEY_RIGHT]:
		compartment_selected.emit(clampi(selected + (-1 if event.keycode == KEY_LEFT else 1), 0, 15))
		accept_event()
	else:
		super._gui_input(event)

func manipulate(at: Vector2) -> void:
	if state.is_empty(): return
	grab_focus()
	var bars: Rect2 = bars_rect()
	if bars.grow(12).has_point(at):
		compartment_selected.emit(clampi(int((at.x - bars.position.x) / bars.size.x * 16), 0, 15))
		return
	var plot: Rect2 = curve_rect()
	if plot.grow(14).has_point(at):
		var fraction: float = clampf((at.x - plot.position.x) / plot.size.x, 0, 1)
		if ascent: preview_depth_changed.emit(fraction * 40)
		else: exposure_time_changed.emit(fraction * 120)

func _draw() -> void:
	draw_style_box(BathysUiStyle.box(Color("08232f"), BathysUiStyle.EDGE, 10, 0), Rect2(Vector2.ZERO, size))
	if state.is_empty(): return
	draw_compartments()
	if comparison_visible:
		if ascent: draw_gradient()
		else: draw_loading()
	if has_focus():
		draw_style_box(BathysUiStyle.box(Color(0, 0, 0, 0), AQUA, 10, 0), Rect2(Vector2.ONE, size - Vector2(2, 2)))

func draw_compartments() -> void:
	var area: Rect2 = section(0)
	var plot: Rect2 = bars_rect()
	var model: BathysTissue = state["model"]
	words(area.position + Vector2(16, 25), "16 theoretical compartments", INK, 13)
	words(area.position + Vector2(16, 44), "Select a bar to inspect its half-time", MUTED, 11)
	var scale: float = maxf(1, float(state["inspired"]))
	for i: int in 16:
		scale = maxf(scale, model.n2[i])
		if ascent:
			scale = maxf(scale, BathysTissue.allowed_inert(i, model.n2[i], 0, model.ambient_bar, state["gf"]))
	scale = ceilf((scale + 0.15) * 2) / 2
	for i: int in 3:
		var y: float = plot.end.y - plot.size.y * i / 2.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(0.4, 0.65, 0.7, 0.16))
		words(Vector2(plot.position.x - 32, y + 4), "%.1f" % (scale * i / 2), MUTED, 10)
	words(Vector2(plot.position.x - 30, plot.position.y - 7), "bar", MUTED, 9)
	var step: float = plot.size.x / 16
	for i: int in 16:
		var x: float = plot.position.x + step * i + 2
		var width: float = maxf(3, step - 4)
		var color: Color = AQUA
		var limit: float = BathysTissue.allowed_inert(i, model.n2[i], 0, model.ambient_bar, state["gf"])
		if ascent and model.n2[i] > limit + 1e-8: color = RED
		var height: float = plot.size.y * model.n2[i] / scale
		draw_rect(Rect2(x, plot.end.y - height, width, height), color * Color(1, 1, 1, 0.65))
		if i == selected:
			draw_rect(Rect2(x - 1, plot.position.y - 2, width + 2, plot.size.y + 4), AQUA, false, 1.5)
		if ascent:
			var y: float = plot.end.y - plot.size.y * limit / scale
			draw_line(Vector2(x - 1, y), Vector2(x + width + 1, y), AMBER, 2)
			if i + 1 == int(state["controller"]): draw_circle(Vector2(x + width * 0.5, plot.end.y + 26), 3, AMBER)
		words(Vector2(x - 1, plot.end.y + 16), str(i + 1), INK if i == selected else MUTED, 9)
	if not ascent:
		var inspired_y: float = plot.end.y - plot.size.y * float(state["inspired"]) / scale
		draw_dashed_line(Vector2(plot.position.x, inspired_y), Vector2(plot.end.x, inspired_y), AMBER, 1.5, 4)
		words(Vector2(plot.position.x, plot.end.y + 38), "Fast → slow · N₂ pressure in bar", MUTED, 11)
	else:
		words(Vector2(plot.position.x, plot.end.y + 42), "Amber ticks: GF limits · dot: ceiling controller", AMBER, 10)

func axes(plot: Rect2, x_max: float, y_max: float, start_x: float = 0) -> void:
	for i: int in 3:
		var fraction: float = i / 2.0
		var y: float = plot.end.y - plot.size.y * fraction
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(0.4, 0.65, 0.7, 0.16))
		words(Vector2(plot.position.x - 29, y + 4), "%.1f" % (y_max * fraction), MUTED, 10)
		words(Vector2(plot.position.x + plot.size.x * fraction - 10, plot.end.y + 18), "%.0f" % lerpf(start_x, x_max, fraction), MUTED, 10)
	words(Vector2(plot.position.x - 28, plot.position.y - 7), "bar", MUTED, 9)
	draw_line(plot.position, Vector2(plot.position.x, plot.end.y), MUTED)
	draw_line(Vector2(plot.position.x, plot.end.y), plot.end, MUTED)

func draw_loading() -> void:
	var area: Rect2 = section(1)
	var plot: Rect2 = curve_rect()
	var half_time: float = BathysTissue.N_HALF[selected]
	words(area.position + Vector2(16, 25), "Selected compartment: loading curve", INK, 12)
	words(area.position + Vector2(16, 44), tr("N₂ half-time: %.1f min") % half_time, AQUA, 12)
	var target: float = float(state["inspired"])
	var initial: float = (1.0 - BathysPhysics.WATER_VAPOUR_BAR) * 0.79
	var scale: float = maxf(1, target + 0.2)
	axes(plot, 120, scale)
	var target_y: float = plot.end.y - plot.size.y * target / scale
	draw_dashed_line(Vector2(plot.position.x, target_y), Vector2(plot.end.x, target_y), AMBER, 1.5, 4)
	var points := PackedVector2Array()
	for i: int in 121:
		var value: float = target + (initial - target) * pow(0.5, i / half_time)
		points.append(Vector2(plot.position.x + plot.size.x * i / 120, plot.end.y - plot.size.y * value / scale))
	draw_polyline(points, AQUA, 2.5, true)
	var value: float = (state["model"] as BathysTissue).n2[selected]
	draw_circle(Vector2(plot.position.x + plot.size.x * exposure_minutes / 120, plot.end.y - plot.size.y * value / scale), 5, AQUA)
	if half_time <= 120:
		var x: float = plot.position.x + plot.size.x * half_time / 120
		draw_dashed_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), MUTED, 1, 4)
		words(Vector2(x + 4, plot.end.y - 5), "t½", MUTED, 11)
	words(Vector2(plot.position.x, plot.end.y + 37), "Time at depth · min", MUTED, 11)
	words(Vector2(plot.position.x, plot.end.y + 55), "Dashed amber: inspired N₂ target", AMBER, 11)

func draw_gradient() -> void:
	var area: Rect2 = section(1)
	var plot: Rect2 = curve_rect()
	var model: BathysTissue = state["model"]
	words(area.position + Vector2(16, 25), "Tissue N₂ / ambient pressure", INK, 12)
	words(area.position + Vector2(16, 44), tr("Compartment %d · t½ %.1f min") % [selected + 1, BathysTissue.N_HALF[selected]], AQUA, 11)
	var maximum: float = ceilf(BathysTissue.allowed_inert(selected, model.n2[selected], 0, 5, 1) + 0.2)
	axes(plot, 5, maximum, 1)
	var m_curve := PackedVector2Array()
	var gf_curve := PackedVector2Array()
	var ambient_curve := PackedVector2Array()
	for i: int in 101:
		var ambient: float = 1 + i * 0.04
		var x: float = plot.position.x + plot.size.x * i / 100
		var gf: float = BathysDeco.gf_at((ambient - 1) * 10, state["anchor_m"], low, high)
		m_curve.append(Vector2(x, plot.end.y - plot.size.y * BathysTissue.allowed_inert(selected, model.n2[selected], 0, ambient, 1) / maximum))
		gf_curve.append(Vector2(x, plot.end.y - plot.size.y * BathysTissue.allowed_inert(selected, model.n2[selected], 0, ambient, gf) / maximum))
		ambient_curve.append(Vector2(x, plot.end.y - plot.size.y * ambient / maximum))
	draw_polyline(ambient_curve, MUTED, 1.5, true)
	draw_polyline(m_curve, VIOLET, 2, true)
	draw_polyline(gf_curve, AMBER, 2.5, true)
	var point := Vector2(plot.position.x + plot.size.x * (model.ambient_bar - 1) / 4, plot.end.y - plot.size.y * model.n2[selected] / maximum)
	var allowed: float = BathysTissue.allowed_inert(selected, model.n2[selected], 0, model.ambient_bar, state["gf"])
	draw_dashed_line(Vector2(plot.position.x, point.y), point, AQUA, 1, 4)
	draw_circle(point, 5, RED if model.n2[selected] > allowed + 1e-8 else AQUA)
	words(Vector2(plot.position.x, plot.end.y + 37), "Ambient pressure · bar", MUTED, 11)
	var m_label: String = tr("Violet: M-value")
	words(Vector2(plot.position.x, plot.end.y + 54), m_label, VIOLET, 11)
	var legend_width: float = ThemeDB.fallback_font.get_string_size(m_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	words(Vector2(plot.position.x + legend_width + 12, plot.end.y + 54), "Amber: GF limit", AMBER, 11)
	words(Vector2(plot.position.x, plot.end.y + 70), "Grey: ambient · dot: tissue N₂", MUTED, 11)
