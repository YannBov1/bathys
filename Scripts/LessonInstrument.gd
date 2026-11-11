class_name BathysLessonInstrument
extends Control

var source: HSlider
var kind: String = "gauge"
var caption: String = ""
var unit: String = ""
var held: bool = false
var last_value: float = NAN
var last_minimum: float = NAN
var last_maximum: float = NAN

func bind(input: HSlider, shape: String, title: String, suffix: String) -> void:
	source = input
	kind = shape
	caption = title
	unit = suffix
	custom_minimum_size = Vector2(230, 96) if kind in ["distance", "length", "light", "wave", "flow"] else Vector2(94, 148)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_VSIZE if kind in ["temperature", "depth", "amount", "salt"] else (Control.CURSOR_HSIZE if kind in ["distance", "length", "light", "wave", "flow"] else Control.CURSOR_POINTING_HAND)
	tooltip_text = tr(caption) + " · " + tr("Drag or use arrow keys")
	source.value_changed.connect(func(_value: float) -> void: queue_redraw())
	source.changed.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func _process(_delta: float) -> void:
	if not is_instance_valid(source) or not is_visible_in_tree(): return
	if source.value != last_value or source.min_value != last_minimum or source.max_value != last_maximum:
		last_value = source.value
		last_minimum = source.min_value
		last_maximum = source.max_value
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		tooltip_text = tr(caption) + " · " + tr("Drag or use arrow keys")
		queue_redraw()
	if what in [NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT]: queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not is_instance_valid(source): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if kind in ["distance", "length", "light", "wave", "flow"]:
				if event.position.y < 34 or event.position.y > 74: return
			var vertical: bool = kind in ["temperature", "depth", "amount", "salt"]
			var distance: float = event.position.distance_to(Vector2(size.x / 2, 86))
			if vertical and (absf(event.position.x - size.x / 2) > 27 or event.position.y < 40 or event.position.y > 128): return
			if kind not in ["distance", "length", "light", "wave", "flow"] and not vertical and (distance < 10 or distance > 43): return
		held = event.pressed
		if held: grab_focus(); change_at(event.position)
		accept_event()
	elif event is InputEventMouseMotion and held:
		change_at(event.position)
		accept_event()
	elif event is InputEventKey and event.pressed:
		var increment: float = maxf(source.step, 0.01) * (10 if event.shift_pressed else 1)
		match event.keycode:
			KEY_RIGHT, KEY_UP: source.value += increment
			KEY_LEFT, KEY_DOWN: source.value -= increment
			KEY_HOME: source.value = source.min_value
			KEY_END: source.value = source.max_value
			_: return
		accept_event()

func change_at(at: Vector2) -> void:
	var fraction: float
	if kind in ["distance", "length", "light", "wave", "flow"]:
		fraction = clampf((at.x - 38) / (size.x - 76), 0, 1)
	elif kind == "clock":
		fraction = clampf(fposmod((at - Vector2(size.x / 2, 86)).angle() + PI / 2, TAU) / deg_to_rad(350), 0, 1)
	elif kind in ["temperature", "depth", "amount", "salt"]:
		fraction = clampf((111 - at.y) / 65, 0, 1) if kind == "temperature" else (clampf((at.y - 46) / 73, 0, 1) if kind == "depth" else clampf((121 - at.y) / (66 if kind == "salt" else 73), 0, 1))
	else:
		var angle: float = rad_to_deg((at - Vector2(size.x / 2, 86)).angle())
		if angle > 30.001: angle -= 360
		fraction = clampf((angle + 210) / 240, 0, 1)
	source.value = lerpf(source.min_value, source.max_value, fraction)

func centered(y: float, text: String, color: Color, font_size: int = 12) -> void:
	var translated: String = tr(text)
	var width: float = ThemeDB.fallback_font.get_string_size(translated, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if width > size.x - 8:
		font_size = maxi(8, floori(font_size * (size.x - 8) / width))
		width = ThemeDB.fallback_font.get_string_size(translated, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(ThemeDB.fallback_font, Vector2((size.x - width) / 2, y), translated, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	if not is_instance_valid(source): return
	var aqua: Color = BathysUiStyle.AQUA
	var amber := Color("ffb96f")
	var ink: Color = BathysUiStyle.TEXT
	draw_style_box(BathysUiStyle.box(BathysUiStyle.CARD, aqua if has_focus() or get_local_mouse_position().is_finite() and Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()) else BathysUiStyle.EDGE, 9, 0), Rect2(Vector2.ONE, size - Vector2(2, 2)))
	centered(21, caption, ink, 12)
	var fraction: float = clampf((source.value - source.min_value) / maxf(0.00001, source.max_value - source.min_value), 0, 1)
	var x: float = size.x / 2
	if kind == "temperature":
		centered(36, "%.2f K" % (source.value + 273.15), BathysUiStyle.MUTED, 10)
		draw_style_box(BathysUiStyle.box(Color("092430"), BathysUiStyle.MUTED, 7, 0), Rect2(x - 9, 40, 18, 76))
		var color: Color = Color("61bce6").lerp(amber, fraction)
		draw_rect(Rect2(x - 5, 111 - fraction * 65, 10, fraction * 65), color)
		draw_circle(Vector2(x, 115), 9, BathysUiStyle.MUTED)
		draw_circle(Vector2(x, 115), 6.5, color)
		for i: int in 5: draw_line(Vector2(x + 13, 46 + i * 16), Vector2(x + 19, 46 + i * 16), BathysUiStyle.MUTED)
		draw_circle(Vector2(x, 111 - fraction * 65), 5, ink)
	elif kind == "depth":
		draw_rect(Rect2(x - 20, 42, 40, 79), Color("15515f"))
		draw_line(Vector2(x - 25, 42), Vector2(x + 25, 42), aqua, 2)
		for i: int in 5: draw_line(Vector2(x + 22, 46 + i * 18), Vector2(x + 28, 46 + i * 18), BathysUiStyle.MUTED)
		var y: float = 46 + fraction * 73
		draw_texture_rect(preload("res://Assets/Icons/buoyancy-diver.svg"), Rect2(x - 16, y - 10, 32, 20), false)
		draw_circle(Vector2(x - 23, y), 4, ink)
	elif kind == "salt":
		# A perforated metal lid and tapered glass shaker distinguish salt from gas.
		var body := PackedVector2Array([Vector2(x - 16, 55), Vector2(x + 16, 55), Vector2(x + 22, 121), Vector2(x - 22, 121)])
		draw_colored_polygon(body, Color("092430"))
		draw_style_box(BathysUiStyle.box(Color("607b86"), ink, 5, 0), Rect2(x - 18, 40, 36, 16))
		for i: int in 3: draw_circle(Vector2(x - 10 + i * 10, 45), 2, Color("092430"))
		draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[0]]), aqua, 1.5, true)
		var level: float = 121 - 66 * fraction
		for i: int in 45:
			var at := Vector2(x - 15 + fposmod(i * 0.618, 1) * 30, 59 + fposmod(i * 0.414, 1) * 59)
			if at.y >= level: draw_rect(Rect2(at, Vector2(2.5, 2.5)), ink)
		draw_line(Vector2(x - 18, level), Vector2(x + 18, level), aqua, 2)
		draw_circle(Vector2(x, level), 5, ink)
	elif kind == "amount":
		var rect := Rect2(x - 21, 43, 42, 78)
		draw_rect(rect, Color("092430"))
		draw_rect(Rect2(rect.position.x, rect.end.y - 73 * fraction, rect.size.x, 73 * fraction), Color(aqua, 0.35))
		draw_rect(rect, aqua, false, 1.5)
		for i: int in int(5 + 22 * fraction):
			var at := Vector2(x - 15 + fposmod(i * 0.618, 1) * 30, 50 + fposmod(i * 0.414, 1) * 62)
			if kind == "salt": draw_rect(Rect2(at, Vector2(3, 3)), ink)
			else: draw_circle(at, 2, aqua)
		draw_circle(Vector2(x, rect.end.y - 73 * fraction), 5, ink)
	elif kind in ["distance", "length", "light", "wave", "flow"]:
		var left := Vector2(38, 55)
		var right := Vector2(size.x - 38, 55)
		var at: Vector2 = left.lerp(right, fraction)
		draw_line(left, right, BathysUiStyle.EDGE, 4)
		draw_line(left, at, aqua, 4)
		for i: int in 9:
			var tick := left.lerp(right, i / 8.0)
			draw_line(tick + Vector2(0, 8), tick + Vector2(0, 12), BathysUiStyle.MUTED)
		if kind == "distance":
			draw_texture_rect(preload("res://Assets/Icons/lesson-eye.svg"), Rect2(9, 43, 24, 24), false)
			draw_texture_rect(preload("res://Assets/Icons/lesson-fish.svg"), Rect2(at - Vector2(13, 12), Vector2(26, 24)), false)
		elif kind == "light":
			draw_texture_rect(preload("res://Assets/Icons/lesson-torch.svg"), Rect2(8, 42, 25, 25), false)
			draw_circle(at, 7, amber)
			for i: int in 8:
				var d := Vector2.from_angle(i * TAU / 8)
				draw_line(at + d * 10, at + d * 14, amber)
		elif kind == "wave":
			var points := PackedVector2Array()
			for i: int in 25: points.append(Vector2(8 + i, 55 + sin(i * 0.5) * 7))
			draw_polyline(points, aqua, 2, true)
			draw_circle(at, 6, ink)
		elif kind == "flow":
			for i: int in 3:
				var y: float = 48 + i * 7
				draw_line(Vector2(8, y), Vector2(28, y), aqua, 2)
				draw_line(Vector2(24, y - 3), Vector2(28, y), aqua, 2)
			draw_circle(at, 6, ink)
		else:
			draw_line(at + Vector2(0, -9), at + Vector2(0, 9), ink, 3)
			for sign_value: int in [-1, 1]:
				var tip := at + Vector2(sign_value * 12, 0)
				draw_line(tip, tip + Vector2(-sign_value * 4, -4), aqua, 2)
				draw_line(tip, tip + Vector2(-sign_value * 4, 4), aqua, 2)
	elif kind == "clock":
		var center := Vector2(x, 86)
		draw_circle(center, 31, Color("092430"))
		draw_arc(center, 31, -PI / 2, -PI / 2 + maxf(0.001, fraction) * deg_to_rad(350), 60, aqua, 3, true)
		for i: int in 12:
			var d := Vector2.from_angle(-PI / 2 + i * TAU / 12)
			draw_line(center + d * 25, center + d * 29, ink, 1.5)
		draw_line(center, center + Vector2.from_angle(-PI / 2 + fraction * TAU / 12) * 13, ink, 3, true)
		var tip: Vector2 = center + Vector2.from_angle(-PI / 2 + fraction * deg_to_rad(350)) * 22
		draw_line(center, tip, aqua, 2, true)
		draw_circle(tip, 4, ink)
		draw_rect(Rect2(x - 5, 45, 10, 5), aqua)
		draw_circle(center, 3, ink)
	else:
		var center := Vector2(x, 86)
		draw_arc(center, 31, deg_to_rad(-210), deg_to_rad(30), 48, BathysUiStyle.EDGE, 5, true)
		draw_arc(center, 31, deg_to_rad(-210), deg_to_rad(-210 + maxf(0.001, fraction) * 240), 48, aqua, 5, true)
		for i: int in 5:
			var direction := Vector2.from_angle(deg_to_rad(-210 + i * 60))
			draw_line(center + direction * 34, center + direction * 38, BathysUiStyle.MUTED)
		var tip: Vector2 = center + Vector2.from_angle(deg_to_rad(-210 + fraction * 240)) * 27
		draw_line(center, tip, amber, 2, true)
		draw_circle(tip, 5, ink)
		draw_circle(center, 3, aqua)
	var digits: int = 0 if source.step >= 1 else (1 if source.step >= 0.1 else (2 if source.step >= 0.01 else 3))
	var value_text: String = (("%." + str(digits) + "f") % source.value) + (" " + unit if not unit.is_empty() else "")
	centered(88 if kind in ["distance", "length", "light", "wave", "flow"] else 139, value_text, aqua, 13)
