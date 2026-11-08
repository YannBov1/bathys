class_name BathysSpgDial
extends Control

var gauge_bar: float = 200.0
var maximum_bar: float = 220.0
var reserve_bar: float = 50.0

func _ready() -> void:
	custom_minimum_size = Vector2(100.0, 100.0)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) * 0.43
	draw_circle(center, radius, Color("08232d"))
	draw_arc(center, radius - 3.0, deg_to_rad(135.0), deg_to_rad(405.0), 60, Color("426978"), 5.0)
	var reserve_fraction: float = clampf(reserve_bar / maxf(1.0, maximum_bar), 0.0, 1.0)
	draw_arc(center, radius - 3.0, deg_to_rad(135.0), deg_to_rad(135.0 + 270.0 * reserve_fraction), 24, Color("ff6676"), 5.0)
	for i: int in 11:
		var angle: float = deg_to_rad(135.0 + 270.0 * i / 10.0)
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		draw_line(center + direction * (radius - 13.0), center + direction * (radius - 5.0), Color("dcefeb"), 1.0)
	var angle: float = deg_to_rad(135.0 + 270.0 * clampf(gauge_bar / maxf(1.0, maximum_bar), 0.0, 1.0))
	draw_line(center, center + Vector2(cos(angle), sin(angle)) * (radius - 18.0), Color("ffb96f"), 2.5)
	draw_circle(center, 4.0, Color("ffb96f"))
	var font: Font = ThemeDB.fallback_font
	var caption: String = "%.0f bar" % gauge_bar
	var width: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(font, center + Vector2(-width / 2.0, radius * 0.53), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f5fbf7"))
