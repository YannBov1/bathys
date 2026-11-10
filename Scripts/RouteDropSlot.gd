class_name BathysRouteDropSlot
extends CenterContainer

var highlighted: bool = false

func set_highlight(value: bool) -> void:
	if highlighted == value:
		return
	highlighted = value
	for child: Node in get_children():
		if child is Control:
			child.modulate.a = 0.0 if highlighted else 1.0
	queue_redraw()

func _draw() -> void:
	if highlighted:
		var y: float = size.y / 2
		draw_line(Vector2(5, y), Vector2(size.x - 5, y), BathysUiStyle.AQUA, 2)
		draw_circle(Vector2(5, y), 3, BathysUiStyle.AQUA)
