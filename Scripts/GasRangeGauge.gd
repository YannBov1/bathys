class_name BathysGasRangeGauge
extends Control

var working_min: float = 0.0
var working_max: float = 1.0
var rest_max: float = 1.0
var chart_max: float = 2.0
var current_value: float = NAN
var min_caption: String = ""
var working_caption: String = ""
var rest_caption: String = ""

func _ready() -> void:
	custom_minimum_size = Vector2(0.0, 31.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func x_at(value: float) -> float:
	return 2.0 + maxf(1.0, size.x - 4.0) * clampf(value / chart_max, 0.0, 1.0)

func segment(a: float, b: float, color: Color) -> void:
	var left: float = x_at(a)
	var right: float = x_at(b)
	if right > left:
		draw_rect(Rect2(left, 3.0, right - left, 6.0), color)

func caption(text: String, threshold: float, baseline: float) -> void:
	if text.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var x: float = x_at(threshold)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_line(Vector2(x, 9.0), Vector2(x, 13.0), Color("dcefeb"), 1.0)
	draw_string(font, Vector2(clampf(x - width / 2.0, 2.0, size.x - width - 2.0), baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("dcefeb"))

func _draw() -> void:
	draw_rect(Rect2(2.0, 3.0, maxf(1.0, size.x - 4.0), 6.0), Color("08232d"))
	segment(0.0, working_min, Color("ff8b83"))
	segment(working_min, working_max, Color("64dfd4"))
	segment(working_max, rest_max, Color("fab36e"))
	segment(rest_max, chart_max, Color("ff8b83"))
	if not is_nan(current_value):
		var marker: float = x_at(current_value)
		draw_line(Vector2(marker, 0.0), Vector2(marker, 12.0), Color("dcefeb"), 2.0)
	caption(min_caption, working_min, 20.0)
	caption(working_caption, working_max, 20.0)
	if rest_max > working_max:
		caption(rest_caption, rest_max, 29.0)
