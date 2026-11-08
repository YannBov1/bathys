class_name BathysCompass
extends Control

var lake: BathysLakeViewport

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(54, 54)

func _process(_delta: float) -> void:
	if lake != null:
		position = Vector2(lake.size.x - 66, 10)
	queue_redraw()

func _draw() -> void:
	var center := Vector2(27, 27)
	draw_circle(center, 26, Color(0.05, 0.19, 0.24, 0.9))
	draw_arc(center, 25, 0, TAU, 40, Color(0.36, 0.69, 0.7, 0.7), 1.2, true)
	var direction := Vector2.UP
	if lake != null and lake.camera != null:
		var north := Vector3(0, 0, -1)
		direction = Vector2(north.dot(lake.camera.global_basis.x), -north.dot(lake.camera.global_basis.y)).normalized()
	var side := Vector2(-direction.y, direction.x)
	draw_colored_polygon(PackedVector2Array([center + direction * 18, center - direction * 7 + side * 5, center - direction * 7 - side * 5]), Color("65e3d6"))
	draw_string(ThemeDB.fallback_font, center - direction * 18 + Vector2(-4, 4), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e6f8f4"))
