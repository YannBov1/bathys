class_name BathysTissueBar
extends Control

var n2_bar: float = 0.0
var he_bar: float = 0.0
var limit_bar: float = 0.0
var scale_max_bar: float = 1.5

func _ready() -> void:
	custom_minimum_size = Vector2(0.0, 12.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var scale: float = maxf(1.5, scale_max_bar)
	var x_n: float = maxf(0.0, n2_bar) / scale * size.x
	var x_h: float = maxf(0.0, he_bar) / scale * size.x
	var x_limit: float = maxf(0.0, limit_bar) / scale * size.x
	draw_rect(Rect2(Vector2.ZERO, size), Color("08242e"))
	draw_rect(Rect2(Vector2.ZERO, Vector2(minf(size.x, x_n), size.y)), Color("65d9d1"))
	if x_h > 0.0:
		draw_rect(Rect2(Vector2(minf(size.x, x_n), 0.0), Vector2(minf(x_h, maxf(0.0, size.x - x_n)), size.y)), Color("b5a3f3"))
	draw_line(Vector2(x_limit, 0.0), Vector2(x_limit, size.y), Color("ffb46a"), 2.0)
	if n2_bar + he_bar > limit_bar:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.25, 0.18, 0.22))
