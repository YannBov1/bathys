class_name BathysWorkspaceSwitch
extends Button

var map_icon: Texture2D = preload("res://Assets/Icons/workspace-map.svg")
var book_icon: Texture2D = preload("res://Assets/Icons/learn-book.svg")

func _ready() -> void:
	name = "WorkspaceSwitch"
	toggle_mode = true
	custom_minimum_size = Vector2(100, 38)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggled.connect(func(_selected: bool) -> void: update_hint(); queue_redraw())
	update_hint()

func update_hint() -> void:
	tooltip_text = "Return to dive workspace" if button_pressed else "Open learning workspace"

func _draw() -> void:
	var selected := Rect2(Vector2(size.x * 0.5 if button_pressed else 3.0, 3), Vector2(size.x * 0.5 - 3, size.y - 6))
	draw_style_box(BathysUiStyle.box(Color("287873"), BathysUiStyle.AQUA, 5, 0), selected)
	draw_texture_rect(map_icon, Rect2(size.x * 0.25 - 12, size.y * 0.5 - 12, 24, 24), false, Color.WHITE if not button_pressed else Color(1, 1, 1, 0.5))
	draw_texture_rect(book_icon, Rect2(size.x * 0.75 - 12, size.y * 0.5 - 12, 24, 24), false, Color.WHITE if button_pressed else Color(1, 1, 1, 0.5))
