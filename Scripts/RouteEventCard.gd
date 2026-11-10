class_name BathysRouteEventCard
extends PanelContainer

signal started(event_id: String)
signal finished
signal keyboard_move(event_id: String, direction: int)

var event_id: String
var owner_id: int
var event_name: String
var event_icon: Texture2D
var dragging: bool = false

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = "Drag to reorder · Alt+Up/Down"

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		grab_focus()
	elif event is InputEventKey and event.pressed and event.alt_pressed and event.keycode in [KEY_UP, KEY_DOWN]:
		keyboard_move.emit(event_id, -1 if event.keycode == KEY_UP else 1)
		accept_event()

func _get_drag_data(at: Vector2) -> Variant:
	if not can_start_drag_at(at):
		return null
	var preview: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 10)
	preview.custom_minimum_size.x = 240
	preview.modulate.a = 0.9
	preview.position = Vector2(-260, -60)
	var row := HBoxContainer.new()
	preview.add_child(row)
	var glyph := TextureRect.new()
	glyph.texture = event_icon
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.custom_minimum_size = Vector2(28, 28)
	row.add_child(glyph)
	var caption := Label.new()
	var name_input: LineEdit = find_child("name", true, false) as LineEdit
	var current_name: String = name_input.text if name_input != null else event_name
	caption.text = current_name if not current_name.is_empty() else tr("Route event")
	caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	caption.clip_text = true
	caption.custom_minimum_size.x = 170
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.add_theme_color_override("font_color", BathysUiStyle.TEXT)
	row.add_child(caption)
	var preview_root := Control.new()
	preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_root.add_child(preview)
	set_drag_preview(preview_root)
	dragging = true
	modulate.a = 0.4
	started.emit(event_id)
	return {"type": "bathys_route_event", "owner": owner_id, "id": event_id}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and dragging:
		dragging = false
		modulate.a = 1.0
		finished.emit()

func can_start_drag_at(at: Vector2) -> bool:
	var global_at: Vector2 = get_global_transform() * at
	for child: Node in find_children("*", "Control", true, false):
		if child is Control and child.is_visible_in_tree() and child.get_global_rect().has_point(global_at) and is_interactive_control(child):
			return false
	return true

func is_interactive_control(control: Control) -> bool:
	var current: Node = control
	while current != null and current != self:
		if current is BaseButton or current is Range or current is TextEdit:
			return true
		if current is LineEdit and current.editable:
			return true
		current = current.get_parent()
	return false
