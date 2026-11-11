class_name BathysColourCompare
extends Control

var material_target: ShaderMaterial
var split: float = 0.5
var held: bool = false
var origin: Vector2
var horizontal_drag: bool = false

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_HSIZE
	tooltip_text = "Drag to compare surface and underwater"

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			held = true
			origin = event.position
			horizontal_drag = event.position.distance_to(Vector2(split * size.x, size.y / 2)) < 20
			grab_focus()
		else:
			if held and event.position.distance_to(origin) < 4: set_split(event.position.x / size.x)
			held = false
		if horizontal_drag: accept_event()
	elif event is InputEventMouseMotion and held:
		var delta: Vector2 = event.position - origin
		if not horizontal_drag and absf(delta.x) > 4 and absf(delta.x) > absf(delta.y): horizontal_drag = true
		if horizontal_drag:
			set_split(event.position.x / size.x)
			accept_event()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_LEFT, KEY_RIGHT]:
		set_split(split + (-0.05 if event.keycode == KEY_LEFT else 0.05))
		accept_event()

func set_split(value: float) -> void:
	split = clampf(value, 0.05, 0.95)
	material_target.set_shader_parameter("compare_split", split)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: queue_redraw()

func _draw() -> void:
	var x: float = split * size.x
	draw_line(Vector2(x, 0), Vector2(x, size.y), Color.WHITE, 1.5)
	draw_circle(Vector2(x, size.y / 2), 10, BathysUiStyle.BG)
	draw_arc(Vector2(x, size.y / 2), 10, 0, TAU, 32, BathysUiStyle.AQUA, 1.5, true)
	for sign_value: float in [-1, 1]:
		var point := Vector2(x + sign_value * 5, size.y / 2)
		draw_polyline(PackedVector2Array([point + Vector2(-sign_value * 3, -3), point, point + Vector2(-sign_value * 3, 3)]), Color.WHITE, 1.5, true)
