class_name BathysTankGlyph
extends Control

var oxygen_percent: float = 21.0

func _ready() -> void:
	custom_minimum_size = Vector2(54, 94)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var edge := Color("bed1d3")
	var stripe := Color("64bce5") if oxygen_percent >= 40 else Color("65dfd3")
	draw_style_box(BathysUiStyle.box(Color("304e56"), Color("304e56"), 6, 0), Rect2(10,16,34,74))
	draw_style_box(BathysUiStyle.box(edge, edge, 5, 0), Rect2(12,12,30,73))
	draw_rect(Rect2(18,3,18,9), edge)
	draw_rect(Rect2(23,0,8,4), Color("dce9e9"))
	draw_rect(Rect2(16,18,22,58), Color("779ba1"))
	draw_style_box(BathysUiStyle.box(stripe, stripe, 3, 0), Rect2(12,39,30,25))
	draw_string(ThemeDB.fallback_font, Vector2(17,56), "%.0f%%" % oxygen_percent, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("07303a"))
	draw_line(Vector2(18,17), Vector2(18,37), Color(1,1,1,0.45), 2)
