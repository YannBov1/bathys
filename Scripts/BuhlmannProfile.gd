class_name BathysBuhlmannProfile
extends BathysLessonDiagram

signal scrubbed(minutes: float)
signal editing_started
signal playback_toggled
var cursor_minutes: float = 30
var cursor_depth: float = 30
var scrubbing: bool = false
var play_button: Button

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
	play_button = Button.new()
	play_button.custom_minimum_size = Vector2(32, 32)
	play_button.icon = preload("res://Assets/Icons/play.svg")
	play_button.add_theme_stylebox_override("normal", BathysUiStyle.box(BathysUiStyle.CARD, BathysUiStyle.EDGE, 7, 4))
	play_button.add_theme_stylebox_override("hover", BathysUiStyle.box(Color("1c4854"), AQUA, 7, 4))
	play_button.add_theme_stylebox_override("pressed", BathysUiStyle.box(Color("2d8e8c"), AQUA, 7, 4))
	play_button.add_theme_stylebox_override("focus", BathysUiStyle.box(Color(0, 0, 0, 0), AQUA, 7, 4))
	play_button.pressed.connect(func() -> void: playback_toggled.emit())
	add_child(play_button)
	adapt()

func adapt() -> void:
	custom_minimum_size.y = 264
	tooltip_text = "Drag corners to edit; scrub the time rail. Space: play/pause. Keys 1–3: edit handles; 4: playhead."
	if is_instance_valid(play_button):
		play_button.position = Vector2(size.x - 40, 5)
		play_button.size = Vector2(32, 32)
	queue_redraw()

func set_playing(value: bool) -> void:
	if not is_instance_valid(play_button): return
	play_button.icon = preload("res://Assets/Icons/pause.svg") if value else preload("res://Assets/Icons/play.svg")
	play_button.tooltip_text = "Pause profile" if value else "Play profile · 2 dive minutes per second"
	play_button.disabled = exposure_minutes + (wait_minutes if ascent else 0) <= 0

func seek_at(x: float) -> void:
	var elapsed: float = clampf((x - chart().position.x) / chart().size.x * time_scale, 0, exposure_minutes + (wait_minutes if ascent else 0))
	scrubbed.emit(elapsed)

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
			scrubbing = false
			grabbed_handle = -1
			if absf(event.position.y - 202) <= 15 and event.position.x >= chart().position.x - 12 and event.position.x <= chart().end.x + 12:
				scrubbing = true
			else:
				var distance: float = 20
				for index: int in (3 if ascent else 2):
					var candidate: float = event.position.distance_to(handle(index))
					if candidate <= distance: grabbed_handle = index; distance = candidate
				if grabbed_handle < 0 and chart().grow(4).has_point(event.position): scrubbing = true
			if scrubbing:
				active_handle = 3
				grab_focus()
				seek_at(event.position.x)
				accept_event()
				return
			if grabbed_handle < 0: return
			active_handle = grabbed_handle
			start_pointer = event.position
			start_values = Vector4(exposure_depth, exposure_minutes, preview_depth, wait_minutes)
			editing_started.emit()
			grab_focus()
		else:
			if scrubbing:
				scrubbing = false
				accept_event()
				return
			if grabbed_handle < 0: return
			grabbed_handle = -1
			update_scale()
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and scrubbing:
		seek_at(event.position.x)
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
		if event.keycode == KEY_SPACE:
			playback_toggled.emit()
		elif event.keycode == KEY_4: active_handle = 3
		elif active_handle == 3 and event.keycode in [KEY_HOME, KEY_END, KEY_LEFT, KEY_RIGHT]:
			var value: float = 0 if event.keycode == KEY_HOME else (exposure_minutes + (wait_minutes if ascent else 0) if event.keycode == KEY_END else cursor_minutes + (-1 if event.keycode == KEY_LEFT else 1) * (1 if event.shift_pressed else 0.1))
			scrubbed.emit(value)
		elif event.keycode in [KEY_1, KEY_2, KEY_3]: active_handle = mini(int(event.keycode - KEY_1), 2 if ascent else 1)
		elif active_handle != 3 and event.keycode in [KEY_UP, KEY_DOWN]:
			var key: String = "preview_depth" if active_handle == 2 else "exposure_depth"
			var value: float = preview_depth if active_handle == 2 else exposure_depth
			parameter_changed.emit(key, clampf(value + (-1 if event.keycode == KEY_UP else 1) * (1 if event.shift_pressed else 0.1), 0, 40))
		elif event.keycode in [KEY_LEFT, KEY_RIGHT] and active_handle in [1, 2]:
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
	words(Vector2(16, 25), "Dive profile", INK, 12)
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
	words(Vector2(16, 238), tr("Exposure: %.1f m / %.1f min") % [exposure_depth, exposure_minutes], AMBER, 11)
	if ascent: words(Vector2(16, 257), tr("Wait: %.1f m / %.1f min") % [preview_depth, wait_minutes], AQUA, 11)

	# The playhead uses its own rail, independent of the editable profile handles.
	var total: float = exposure_minutes + (wait_minutes if ascent else 0)
	var end_x: float = sample(total, 0).x
	var cursor: Vector2 = sample(cursor_minutes, cursor_depth)
	draw_line(Vector2(rect.position.x, 202), Vector2(end_x, 202), MUTED, 3)
	draw_line(Vector2(rect.position.x, 202), Vector2(cursor.x, 202), INK, 3)
	draw_circle(Vector2(cursor.x, 202), 6, INK)
	draw_dashed_line(Vector2(cursor.x, rect.position.y), Vector2(cursor.x, rect.end.y), INK, 1, 3)
	draw_circle(cursor, 4, INK)
	words(Vector2(rect.position.x, 221), tr("%.1f / %.1f min") % [cursor_minutes, total], INK, 10)
	words(Vector2(maxf(rect.position.x + 100, end_x - 34), 221), "%.1f m" % cursor_depth, AQUA, 10)
