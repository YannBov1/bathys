class_name BathysBuhlmannProfile
extends BathysLessonDiagram

signal parameter_changed(key: String, value: float)
var exposure_depth: float = 30
var exposure_minutes: float = 30
var preview_depth: float = 9
var wait_minutes: float = 0
var ascent: bool = false
var active_handle: int = 1
var grabbed_handle: int = -1
var start_pointer := Vector2.ZERO
var start_values := Vector4.ZERO
var time_scale: float = 120

func _ready() -> void:
	super._ready()
	focus_mode = FOCUS_ALL
	mouse_filter = MOUSE_FILTER_PASS

func adapt() -> void:
	custom_minimum_size.y = 236
	tooltip_text = "Drag profile corners: depth ↕, time ↔. Keys 1–3 select a handle."
	queue_redraw()

func chart() -> Rect2:
	return Rect2(46, 43, maxf(40, size.x - 72), 116)

func update_scale() -> void:
	if grabbed_handle < 0: time_scale = clampf(ceilf((exposure_minutes + (wait_minutes if ascent else 0) + 10) / 60) * 60, 120, 240)

func sample(minutes: float, depth: float) -> Vector2:
	var rect: Rect2 = chart()
	return rect.position + rect.size * Vector2(minutes / time_scale, depth / 40)

func handle(index: int) -> Vector2:
	if index == 0: return sample(exposure_minutes / 2, exposure_depth)
	if index == 1: return sample(exposure_minutes, exposure_depth)
	var at: Vector2 = sample(exposure_minutes + wait_minutes, preview_depth)
	# Separate coincident zero-wait handles without inventing elapsed time.
	at.x = maxf(at.x, sample(exposure_minutes, preview_depth).x + 18)
	at.x = minf(chart().end.x, at.x)
	return at

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			grabbed_handle = -1
			var distance: float = 24
			for index: int in (3 if ascent else 2):
				var candidate: float = event.position.distance_to(handle(index))
				if candidate <= distance: grabbed_handle = index; distance = candidate
			if grabbed_handle < 0:
				var first := sample(0, exposure_depth)
				var last := sample(exposure_minutes, exposure_depth)
				if event.position.x >= first.x and event.position.x <= last.x and absf(event.position.y - first.y) < 15: grabbed_handle = 0
				elif ascent and event.position.x >= last.x and event.position.x <= sample(exposure_minutes + wait_minutes, preview_depth).x and absf(event.position.y - sample(0, preview_depth).y) < 15: grabbed_handle = 2
			if grabbed_handle < 0: return
			active_handle = grabbed_handle
			start_pointer = event.position
			start_values = Vector4(exposure_depth, exposure_minutes, preview_depth, wait_minutes)
			grab_focus()
		else:
			if grabbed_handle < 0: return
			grabbed_handle = -1
			update_scale()
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and grabbed_handle >= 0:
		var delta_position: Vector2 = event.position - start_pointer
		var change_depth: float = delta_position.y / chart().size.y * 40
		var change_time: float = delta_position.x / chart().size.x * time_scale
		if grabbed_handle in [0, 1]: parameter_changed.emit("exposure_depth", clampf(start_values.x + change_depth, 0, 40))
		if grabbed_handle == 1: parameter_changed.emit("exposure_time", clampf(start_values.y + change_time, 0, 120))
		if grabbed_handle == 2:
			parameter_changed.emit("preview_depth", clampf(start_values.z + change_depth, 0, 40))
			parameter_changed.emit("wait", clampf(start_values.w + change_time, 0, 120))
		accept_event()
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_1, KEY_2, KEY_3]: active_handle = mini(int(event.keycode - KEY_1), 2 if ascent else 1)
		elif event.keycode in [KEY_UP, KEY_DOWN]:
			var key: String = "preview_depth" if active_handle == 2 else "exposure_depth"
			var value: float = preview_depth if active_handle == 2 else exposure_depth
			parameter_changed.emit(key, clampf(value + (-1 if event.keycode == KEY_UP else 1) * (1 if event.shift_pressed else 0.1), 0, 40))
		elif event.keycode in [KEY_LEFT, KEY_RIGHT] and active_handle != 0:
			var key: String = "wait" if active_handle == 2 else "exposure_time"
			var value: float = wait_minutes if active_handle == 2 else exposure_minutes
			parameter_changed.emit(key, clampf(value + (-1 if event.keycode == KEY_LEFT else 1) * (1 if event.shift_pressed else 0.1), 0, 120))
		else: return
		queue_redraw()
		accept_event()

func _draw() -> void:
	update_scale()
	var rect: Rect2 = chart()
	draw_style_box(BathysUiStyle.box(Color("08232f"), AQUA if has_focus() else BathysUiStyle.EDGE, 10, 0), Rect2(Vector2.ZERO, size))
	words(Vector2(16, 25), "Dive profile · instantaneous depth steps", INK, 12)
	draw_rect(rect, Color("0b3747"))
	for depth: int in [0, 20, 40]:
		var y: float = sample(0, depth).y
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(MUTED, 0.2))
		words(Vector2(9, y + 4), "%d m" % depth, MUTED, 10)
	for index: int in 3:
		var x: float = rect.position.x + rect.size.x * index / 2
		words(Vector2(x - 5, rect.end.y + 19), "%.0f" % (time_scale * index / 2), MUTED, 10)
	words(Vector2(rect.end.x - 20, rect.end.y + 33), "min", MUTED, 10)
	var first := sample(0, exposure_depth)
	var transition := sample(exposure_minutes, exposure_depth)
	draw_dashed_line(sample(0, 0), first, AMBER, 1.5, 4)
	draw_line(first, transition, AMBER, 3, true)
	if ascent:
		var preview := sample(exposure_minutes, preview_depth)
		var end := sample(exposure_minutes + wait_minutes, preview_depth)
		draw_dashed_line(transition, preview, AQUA, 1.5, 4)
		draw_line(preview, end, AQUA, 3, true)
		if wait_minutes < 1: draw_dashed_line(end, handle(2), MUTED, 1, 3)
	for index: int in (3 if ascent else 2):
		var at: Vector2 = handle(index)
		if index == 0: grip(at, true)
		else:
			draw_circle(at, 7, Color("123b48"))
			draw_arc(at, 7, 0, TAU, 24, AMBER if index == 1 else AQUA, 2, true)
			draw_line(at + Vector2(10, 0), at + Vector2(16, 0), INK)
			draw_line(at + Vector2(0, 10), at + Vector2(0, 16), INK)
	words(Vector2(16, 207), tr("Exposure: %.1f m / %.1f min") % [exposure_depth, exposure_minutes], AMBER, 11)
	if ascent: words(Vector2(16, 226), tr("Wait: %.1f m / %.1f min") % [preview_depth, wait_minutes], AQUA, 11)
