class_name BathysSpgDial
extends Control

var gauge_bar: float = 200.0
var maximum_bar: float = 220.0
var reserve_bar: float = 50.0
var needle_bar: float = 200.0
var initialized: bool = false

func set_pressure(value: float) -> void:
	gauge_bar = maxf(0, value)
	if not initialized:
		needle_bar = gauge_bar
		initialized = true
	set_process(absf(needle_bar-gauge_bar)>0.05)
	queue_redraw()

func _process(delta: float) -> void:
	needle_bar += (gauge_bar-needle_bar)*(1-exp(-12*delta))
	if absf(needle_bar-gauge_bar)<0.05:
		needle_bar = gauge_bar
		set_process(false)
	queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(94.0, 94.0)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_pressure(gauge_bar)

func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0 - 5.0
	draw_circle(center, radius, Color("799da5"))
	draw_circle(center, radius - 3, Color("163844"))
	draw_circle(center, radius - 6, Color("061b27"))
	draw_arc(center, radius - 8.0, deg_to_rad(135.0), deg_to_rad(405.0), 60, Color("426978"), 4.0, true)
	var reserve_fraction: float = clampf(reserve_bar / maxf(1.0, maximum_bar), 0.0, 1.0)
	draw_arc(center, radius - 8.0, deg_to_rad(135.0), deg_to_rad(135.0 + 270.0 * reserve_fraction), 24, Color("ff6676"), 4.0, true)
	for i: int in 11:
		var angle: float = deg_to_rad(135.0 + 270.0 * i / 10.0)
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		draw_line(center + direction * (radius - 13.0), center + direction * (radius - 5.0), Color("dcefeb"), 1.0)
	var angle: float = deg_to_rad(135.0 + 270.0 * clampf(needle_bar / maxf(1.0, maximum_bar), 0.0, 1.0))
	draw_line(center, center + Vector2(cos(angle), sin(angle)) * (radius - 18.0), Color("ffb96f"), 2.5)
	draw_circle(center, 4.0, Color("ffb96f"))
	var font: Font = ThemeDB.fallback_font
	var caption: String = "%.0f" % gauge_bar
	draw_string(font, center + Vector2(-31, 25), caption, HORIZONTAL_ALIGNMENT_CENTER, 62, 15, Color("71e5d9"))
	draw_string(font, center + Vector2(-31, 35), "bar g", HORIZONTAL_ALIGNMENT_CENTER, 62, 9, Color("91b6b9"))
