class_name BathysTrendArrow
extends Control

var trend: int = 0
var ink: Color = Color("71e5d9")

func _ready() -> void:
	custom_minimum_size = Vector2(10, 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var a: Vector2
	var b: Vector2
	if trend == 0:
		a = Vector2(1, 8)
		b = Vector2(9, 8)
	else:
		a = Vector2(5, 13 if trend > 0 else 3)
		b = Vector2(5, 3 if trend > 0 else 13)
	var direction: Vector2 = (b - a).normalized()
	var side := Vector2(-direction.y, direction.x)
	draw_line(a, b, ink, 1.2, true)
	draw_polyline(PackedVector2Array([b - direction * 3 + side * 3, b, b - direction * 3 - side * 3]), ink, 1.2, true)
