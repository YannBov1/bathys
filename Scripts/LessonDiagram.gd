class_name BathysLessonDiagram
extends Control

signal depth_changed(value: float)
signal angle_changed(value: float)

const AQUA := Color("71e5d9")
const AMBER := Color("ffb96f")
const INK := Color("e6f8f4")
const MUTED := Color("91b6b9")
var comparison_visible: bool = true
var lesson: String = "boyle"
var depth_m: float = 10.0
var angle_deg: float = 30.0
var from_water: bool = false
var dragging: bool = false

static func pressure_at(depth: float) -> float:
	# Deliberately simplified sea-level teaching model, independent of the scenario.
	return 1.0 + depth / 10.0

static func volume_at(depth: float) -> float:
	return 1.0 / pressure_at(depth)

static func refraction(angle: float, water_to_air: bool) -> Dictionary:
	var n1: float = 1.333 if water_to_air else 1.0
	var n2: float = 1.0 if water_to_air else 1.333
	var sine: float = n1 / n2 * sin(deg_to_rad(angle))
	return {"tir": sine > 1.0, "angle": rad_to_deg(asin(clampf(sine, -1.0, 1.0))), "n1": n1, "n2": n2}

static func critical_angle() -> float:
	return rad_to_deg(asin(1.0 / 1.333))

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	resized.connect(adapt)
	adapt()

func adapt() -> void:
	custom_minimum_size.y = 510 if comparison_visible and lesson == "boyle" and size.x < 620 else 330
	tooltip_text = "Drag in the water to change depth" if lesson == "boyle" else "Drag on the incoming side to change the ray angle"
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if dragging:
			manipulate(event.position)
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		manipulate(event.position)
		accept_event()

func manipulate(at: Vector2) -> void:
	if lesson == "boyle":
		var scene: Rect2 = bubble_rect()
		if at.x <= scene.end.x:
			depth_changed.emit(clampf((at.y - 96.0) / (scene.size.y - 150.0) * 40.0, 0.0, 40.0))
	else:
		var offset: Vector2 = at - size * 0.5
		if (from_water and offset.y >= 0) or (not from_water and offset.y <= 0):
			angle_changed.emit(clampf(rad_to_deg(atan2(absf(offset.x), absf(offset.y))), 0.0, 89.0))

func grip(at: Vector2, vertical: bool = false) -> void:
	draw_circle(at, 7, Color("123b48"))
	draw_arc(at, 7, 0, TAU, 24, AQUA, 1.5, true)
	var direction: Vector2 = Vector2.DOWN if vertical else Vector2.RIGHT
	var side := Vector2(-direction.y, direction.x)
	for sign_value: float in [-1, 1]:
		var point: Vector2 = at + direction * 13 * sign_value
		draw_polyline(PackedVector2Array([point - direction * 3 * sign_value + side * 3, point, point - direction * 3 * sign_value - side * 3]), AQUA, 1.5, true)

func words(at: Vector2, message: String, color: Color = MUTED, font_size: int = 12) -> void:
	draw_string(ThemeDB.fallback_font, at, tr(message), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func arrow(start: Vector2, end: Vector2, color: Color, width: float = 2.0) -> void:
	if start.distance_to(end) < 1:
		return
	draw_line(start, end, color, width, true)
	var direction: Vector2 = (end - start).normalized()
	var tip: Vector2 = start.lerp(end, 0.7)
	var side := Vector2(-direction.y, direction.x)
	draw_colored_polygon(PackedVector2Array([tip + direction * 7, tip - direction * 5 + side * 4, tip - direction * 5 - side * 4]), color)

func _draw() -> void:
	draw_style_box(BathysUiStyle.box(Color("08232f"), BathysUiStyle.EDGE, 10, 0), Rect2(Vector2.ZERO, size))
	if lesson == "boyle":
		draw_boyle()
	else:
		draw_snell()

func bubble_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size) if not comparison_visible else Rect2(0, 0, size.x if size.x < 620 else size.x * 0.51, 275 if size.x < 620 else size.y)

func draw_boyle() -> void:
	var scene: Rect2 = bubble_rect()
	var column_width: float = scene.size.x
	draw_rect(Rect2(1, 46, column_width - 2, scene.size.y - 47), Color("0b3747"))
	draw_line(Vector2(1, 46), Vector2(column_width - 1, 46), AQUA, 2, true)
	words(Vector2(18, 28), "Air · surface", INK)
	words(Vector2(18, 67), "Water")
	for depth: int in [0, 10, 20, 30, 40]:
		var y: float = 96 + (scene.size.y - 150) * depth / 40.0
		draw_line(Vector2(column_width - 64, y), Vector2(column_width - 54, y), MUTED)
		words(Vector2(column_width - 48, y + 4), "%d m" % depth)
	var center := Vector2(column_width * 0.43, 96 + (scene.size.y - 150) * depth_m / 40.0)
	var radius: float = 40 * pow(volume_at(depth_m), 1.0 / 3.0)
	draw_arc(center, 40, 0, TAU, 72, Color(0.57, 0.71, 0.73, 0.45), 1, true)
	draw_circle(center, radius, Color(0.44, 0.9, 0.85, 0.18))
	draw_arc(center, radius, 0, TAU, 72, AQUA, 2.5, true)
	# The same twelve particles occupy less space as ambient pressure rises.
	for i: int in 12:
		var a: float = float(i) * 2.39996
		var point: Vector2 = center + Vector2(cos(a), sin(a)) * radius * sqrt((float(i) + 0.5) / 12) * 0.82
		draw_circle(point, 2, INK)
	words(center + Vector2(-24, 58), "%.2f L" % volume_at(depth_m), AQUA, 16)
	words(Vector2(18, scene.size.y - 12), "Outline: 1 L at the surface", MUTED, 11)
	grip(center + Vector2(-56, 0), true)
	if not comparison_visible: return
	var graph_box := Rect2(size.x * 0.51, 0, size.x * 0.49, size.y)
	if size.x < 620:
		graph_box = Rect2(0, 284, size.x, size.y - 284)
	var graph_area := Rect2(graph_box.position + Vector2(49, 48), graph_box.size - Vector2(76, 101))
	words(graph_box.position + Vector2(18, 26), "Volume / absolute pressure", INK)
	for i: int in 5:
		var x: float = graph_area.position.x + graph_area.size.x * i / 4.0
		draw_line(Vector2(x, graph_area.position.y), Vector2(x, graph_area.end.y), Color(0.4, 0.65, 0.7, 0.14))
		words(Vector2(x - 4, graph_area.end.y + 19), str(i + 1), MUTED, 11)
	for fraction: float in [0.0, 0.5, 1.0]:
		var y: float = graph_area.end.y - graph_area.size.y * fraction
		draw_line(Vector2(graph_area.position.x, y), Vector2(graph_area.end.x, y), Color(0.4, 0.65, 0.7, 0.14))
		words(Vector2(graph_area.position.x - 33, y + 4), "%.1f" % fraction, MUTED, 11)
	words(Vector2(graph_area.position.x - 30, graph_area.position.y - 10), "L")
	words(Vector2(graph_area.end.x - 18, graph_area.end.y + 37), "bar")
	draw_line(graph_area.position, Vector2(graph_area.position.x, graph_area.end.y), MUTED)
	draw_line(Vector2(graph_area.position.x, graph_area.end.y), graph_area.end, MUTED)
	var points := PackedVector2Array()
	for i: int in 101:
		var pressure: float = 1.0 + float(i) * 0.04
		points.append(Vector2(graph_area.position.x + graph_area.size.x * (pressure - 1) / 4, graph_area.end.y - graph_area.size.y / pressure))
	draw_polyline(points, AQUA, 2.5, true)
	var marker := Vector2(graph_area.position.x + graph_area.size.x * (pressure_at(depth_m) - 1) / 4, graph_area.end.y - graph_area.size.y * volume_at(depth_m))
	draw_dashed_line(Vector2(marker.x, graph_area.end.y), marker, AMBER, 1, 4)
	draw_dashed_line(Vector2(graph_area.position.x, marker.y), marker, AMBER, 1, 4)
	draw_circle(marker, 5, AMBER)

func draw_snell() -> void:
	var center: Vector2 = size * 0.5
	draw_rect(Rect2(1, center.y, size.x - 2, center.y - 1), Color("0b3747"))
	draw_line(Vector2(1, center.y), Vector2(size.x - 1, center.y), AQUA, 2, true)
	draw_dashed_line(Vector2(center.x, 30), Vector2(center.x, size.y - 26), MUTED, 1, 6)
	words(Vector2(18, 26), "Air · n = 1.000", INK)
	words(Vector2(18, size.y - 18), "Water · n = 1.333", INK)
	words(Vector2(center.x + 8, 52), "Normal", MUTED, 11)
	var angle: float = deg_to_rad(angle_deg)
	var result: Dictionary = refraction(angle_deg, from_water)
	var length: float = minf(size.x * 0.43, size.y * 0.5 - 36)
	var sign_y: float = 1.0 if from_water else -1.0
	var start := center + Vector2(-sin(angle), sign_y * cos(angle)) * length
	arrow(start, center, AMBER, 3)
	draw_circle(start, 6, AMBER)
	var incidence_start: float = PI * 0.5 if from_water else -PI * 0.5 - angle
	draw_arc(center, 45, incidence_start, incidence_start + angle, 40, AMBER, 1.5, true)
	words(center + Vector2(-minf(152, center.x - 14), 54 if from_water else -28), "θ₁ = %.1f°" % angle_deg, AMBER, 14)
	if bool(result["tir"]):
		var end := center + Vector2(sin(angle), cos(angle)) * length
		arrow(center, end, AMBER, 3)
		words(center + Vector2(22, 54), "θᵣ = %.1f°" % angle_deg, AMBER, 14)
	else:
		var refracted: float = deg_to_rad(float(result["angle"]))
		var end := center + Vector2(sin(refracted), -sign_y * cos(refracted)) * length
		arrow(center, end, AQUA, 3)
		var refracted_start: float = -PI * 0.5 if from_water else PI * 0.5 - refracted
		draw_arc(center, 60, refracted_start, refracted_start + refracted, 40, AQUA, 1.5, true)
		words(center + Vector2(22, -28 if from_water else 54), "θ₂ = %.1f°" % float(result["angle"]), AQUA, 14)
	draw_circle(center, 4, INK)
