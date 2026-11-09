class_name BathysPanelDivider
extends Control

signal drag_started(position: Vector2)
signal dragged(position: Vector2)
signal toggle_requested
signal nudged(distance: float)

var horizontal: bool = false:
	set(value):
		horizontal = value
		custom_minimum_size = Vector2(0, 10) if value else Vector2(10, 0)
		mouse_default_cursor_shape = Control.CURSOR_VSIZE if value else Control.CURSOR_HSIZE
		queue_redraw()
var active: bool = false
var hovered: bool = false

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	horizontal = horizontal
	tooltip_text = "Drag to resize; drag to the outer edge to collapse. Double-click or press Enter to restore/collapse."
	mouse_entered.connect(func() -> void: hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: hovered = false; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	resized.connect(queue_redraw)

func _draw() -> void:
	var color := Color("72e9dd") if hovered or active or has_focus() else Color("28515b")
	if horizontal:
		draw_line(Vector2(8, size.y / 2), Vector2(size.x - 8, size.y / 2), color, 1)
	else:
		draw_line(Vector2(size.x / 2, 8), Vector2(size.x / 2, size.y - 8), color, 1)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.double_click:
			active = false
			toggle_requested.emit()
		else:
			active = event.pressed
			if active:
				grab_focus()
				drag_started.emit(event.global_position)
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and active:
		dragged.emit(event.global_position)
		accept_event()
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			toggle_requested.emit()
			accept_event()
		elif event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			nudged.emit(-24.0 if event.keycode in [KEY_LEFT, KEY_UP] else 24.0)
			accept_event()
