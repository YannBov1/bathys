class_name BathysExchangeDiagram
extends BathysThermalDiagram

var barrier_drag: String = ""
var barrier_start := Vector2.ZERO
var barrier_values := Vector2.ZERO
var tissues: bool = false

func adapt() -> void:
	custom_minimum_size.y = (720 if size.x < 660 else 390) if comparison_visible else 300
	tooltip_text = "Drag membrane edges for area and thickness; scrub the curve for time."
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		barrier_drag = ""
		var mid: float = section(0).size.x / 2
		var width: float = 12 + 14 * float(params.get("thickness", 1))
		var area_y: float = 193 + 65 * float(params.get("area", 1)) / 2
		var distance_area: float = event.position.distance_to(Vector2(mid, area_y))
		var distance_width: float = event.position.distance_to(Vector2(mid + width / 2, 177))
		if minf(distance_area, distance_width) < 23:
			barrier_drag = "area" if distance_area <= distance_width else "thickness"
			barrier_start = event.position
			barrier_values = Vector2(params["area"], params["thickness"])
	super._gui_input(event)
	if event is InputEventMouseButton and not event.pressed: barrier_drag = ""

func manipulate(at: Vector2) -> void:
	if not barrier_drag.is_empty():
		if barrier_drag == "area": parameter_changed.emit("area", clampf(barrier_values.x + (at.y - barrier_start.y) * 2 / 65, 0.2, 2))
		else: parameter_changed.emit("thickness", clampf(barrier_values.y + (at.x - barrier_start.x) * 2 / 14, 0.25, 4))
		return
	if not comparison_visible: return
	var rect: Rect2 = plot_rect()
	if rect.grow(12).has_point(at): parameter_changed.emit("time", clampf((at.x - rect.position.x) / rect.size.x * 5, 0, 5))

func _draw() -> void:
	draw_style_box(BathysUiStyle.box(Color("08232f"), BathysUiStyle.EDGE, 10, 0), Rect2(Vector2.ZERO, size))
	if result.is_empty(): return
	membrane()
	if comparison_visible:
		uptake_plot()

func membrane() -> void:
	var area: Rect2 = section(0)
	wrapped_words(Vector2(16, 25), "Blood ↔ tissue" if tissues else "Alveolus ↔ blood parcel", area.size.x - 32, INK, 13)
	var mid: float = area.size.x / 2
	var barrier_width: float = 12 + 14 * float(params["thickness"])
	var active_height: float = 130 * float(params["area"]) / 2
	var top: float = 177 - active_height / 2
	var left: Rect2 = Rect2(18, top, mid - barrier_width / 2 - 24, active_height)
	var right: Rect2 = Rect2(mid + barrier_width / 2 + 6, top, mid - barrier_width / 2 - 24, active_height)
	for i: int in 2:
		var rect: Rect2 = left if i == 0 else right
		var pressure: float = params["source"] if i == 0 else result["receiver"]
		draw_rect(rect, Color("164552") if i == 0 else Color("263c51"))
		draw_rect(rect, AQUA if i == 0 else VIOLET, false, 1.5)
		var label: String = ("Blood" if tissues else "Alveolus") if i == 0 else ("Tissue" if tissues else "Blood parcel")
		wrapped_words(Vector2(rect.position.x + 5, 79), label, rect.size.x - 10, INK, 12)
		words(Vector2(rect.position.x + 5, 98), "%.1f mmHg" % pressure, AQUA if i == 0 else VIOLET, 12)
		for j: int in maxi(2, roundi(14 * float(params["area"]) / 2)):
			var pos: Vector2 = rect.position + Vector2(6, 4) + (rect.size - Vector2(12, 8)) * Vector2(fposmod(j * 0.618, 1), fposmod(j * 0.414, 1))
			draw_circle(pos, 2, AQUA if i == 0 else VIOLET)
			var motion: Vector2 = Vector2.from_angle(j * 2.399) * 6
			draw_line(pos, pos + motion, MUTED, 1)
	var active := Rect2(mid - barrier_width / 2, 177 - active_height / 2, barrier_width, active_height)
	draw_rect(active, Color("357c7a"))
	grip(Vector2(mid + barrier_width / 2, 177))
	draw_line(Vector2(mid, active.end.y), Vector2(mid, active.end.y + 10), AQUA, 1)
	grip(Vector2(mid, active.end.y + 16), true)
	for i: int in 5:
		var y: float = top + active_height * (i + 0.2) / 5
		arrow(Vector2(mid - barrier_width / 2 - 9, y), Vector2(mid + barrier_width / 2 + 9, y), Color(AQUA, 0.3), 1)
		arrow(Vector2(mid + barrier_width / 2 + 9, y + active_height / 20), Vector2(mid - barrier_width / 2 - 9, y + active_height / 20), Color(VIOLET, 0.3), 1)
	var gradient: float = result["gradient"]
	if absf(gradient) > 1e-8:
		var start := Vector2(mid - barrier_width / 2 - 30, 278)
		var end := Vector2(mid + barrier_width / 2 + 30, 278)
		arrow(start if gradient > 0 else end, end if gradient > 0 else start, AQUA if gradient > 0 else VIOLET, 2 + 4 * absf(float(result["flux"])) / (1 + absf(float(result["flux"]))))
	wrapped_words(Vector2(18, 307), "Equal pressures: zero net transfer; random motion continues." if absf(gradient) < 1e-8 else "Net transfer follows partial pressure, not total pressure. Dots are schematic.", area.size.x - 36)
	if comparison_visible: wrapped_words(Vector2(18, 342), "Membrane height: exchange area. Width: thickness.", area.size.x - 36, MUTED, 10)

func uptake_plot() -> void:
	var area: Rect2 = section(1)
	var rect: Rect2 = plot_rect()
	wrapped_words(area.position + Vector2(16, 25), "Receiver partial pressure · mmHg", area.size.x - 32, INK, 12)
	var lower: float = minf(params["source"], params["initial"])
	var upper: float = maxf(params["source"], params["initial"])
	var margin: float = maxf(5, (upper - lower) * 0.12)
	lower = maxf(0, lower - margin)
	upper += margin
	bounds = Rect2(0, lower, 5, upper - lower)
	for i: int in 3:
		var f: float = i / 2.0
		var y: float = rect.end.y - rect.size.y * f
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0.4, 0.65, 0.7, 0.17))
		words(Vector2(rect.position.x - 43, y + 4), "%.0f" % (lower + f * (upper - lower)), MUTED, 10)
		words(Vector2(rect.position.x + f * rect.size.x - 5, rect.end.y + 20), "%.1f" % (5 * f), MUTED, 10)
	draw_line(rect.position, Vector2(rect.position.x, rect.end.y), MUTED)
	draw_line(Vector2(rect.position.x, rect.end.y), rect.end, MUTED)
	draw_dashed_line(locate(Vector2(0, params["source"])), locate(Vector2(5, params["source"])), AMBER, 1.5, 5)
	var points := PackedVector2Array()
	for i: int in 61:
		var time: float = i / 12.0
		points.append(locate(Vector2(time, BathysExchangeModels.exchange(params, time)["receiver"])))
	draw_polyline(points, VIOLET, 2, true)
	var point: Vector2 = locate(Vector2(params["time"], result["receiver"]))
	draw_dashed_line(Vector2(point.x, rect.position.y), Vector2(point.x, rect.end.y), INK, 1, 4)
	draw_circle(point, 4, INK)
	wrapped_words(Vector2(rect.position.x, rect.end.y + 42), "Time / reference interval τ₀", area.size.x - 65, MUTED, 11)
	words(Vector2(rect.position.x, rect.end.y + 59), "Source · dashed", AMBER, 10)
	words(Vector2(rect.position.x + rect.size.x * 0.55, rect.end.y + 59), "Receiver · curve", VIOLET, 10)
