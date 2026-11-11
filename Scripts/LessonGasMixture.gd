class_name BathysLessonGasMixture
extends Control

var oxygen: HSlider
var helium: HSlider
var boundary: int = -1
var keyboard_boundary: int = 0
var last_mix := Vector2(-1, -1)
const TOP: float = 20
const HEIGHT: float = 122

func bind(o2: HSlider, he: HSlider) -> void:
	oxygen = o2
	helium = he
	custom_minimum_size = Vector2(134, 176)
	focus_mode = FOCUS_ALL
	mouse_filter = MOUSE_FILTER_PASS
	mouse_default_cursor_shape = CURSOR_VSIZE
	tooltip_text = "Drag the dividers · O₂ + N₂ + He = 100%"

func _process(_delta: float) -> void:
	var mix := Vector2(oxygen.value, helium.value)
	if mix != last_mix:
		last_mix = mix
		queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT, NOTIFICATION_TRANSLATION_CHANGED]: queue_redraw()

func divider(index: int) -> float:
	return TOP + HEIGHT * (oxygen.value if index == 0 else 100 - helium.value) / 100

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.position.x < 16 or event.position.x > size.x - 10 or event.position.y < TOP - 12 or event.position.y > TOP + HEIGHT + 12: return
			var upper: Vector2 = Vector2(17, divider(0))
			var lower: Vector2 = Vector2(size.x - 19, divider(1))
			boundary = 0 if event.position.distance_to(upper) <= event.position.distance_to(lower) else 1
			keyboard_boundary = boundary
			grab_focus()
			change_at(event.position.y)
		else: boundary = -1
		accept_event()
	elif event is InputEventMouseMotion and boundary >= 0:
		change_at(event.position.y)
		accept_event()
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_LEFT, KEY_RIGHT]: keyboard_boundary = 1 - keyboard_boundary
		elif event.keycode in [KEY_UP, KEY_DOWN]:
			var offset: float = (-1 if event.keycode == KEY_UP else 1) * (1 if event.shift_pressed else 0.1)
			boundary = keyboard_boundary
			change_at(divider(boundary) + offset)
			boundary = -1
		else: return
		accept_event()
		queue_redraw()

func change_at(y: float) -> void:
	var value: float = clampf((y - TOP) / HEIGHT * 100, 0, 100)
	if boundary == 0: oxygen.value = minf(value, 100 - helium.value)
	else: helium.value = minf(100 - value, 100 - oxygen.value)

func _draw() -> void:
	if not is_instance_valid(oxygen): return
	var aqua: Color = BathysUiStyle.AQUA
	var ink: Color = BathysUiStyle.TEXT
	draw_style_box(BathysUiStyle.box(BathysUiStyle.CARD, aqua if has_focus() else BathysUiStyle.EDGE, 9, 0), Rect2(Vector2.ONE, size - Vector2(2, 2)))
	var left: float = 22
	var width: float = size.x - 48
	var fractions: Array[float] = [oxygen.value, maxf(0, 100 - oxygen.value - helium.value), helium.value]
	var colors: Array[Color] = [aqua, Color("607b86"), Color("b5a3f3")]
	var labels: Array[String] = ["O₂", "N₂", "He"]
	draw_rect(Rect2(size.x / 2 - 6, 9, 12, 8), ink)
	draw_style_box(BathysUiStyle.box(Color("123b48"), ink, 9, 0), Rect2(left, 19, width, 125))
	var y: float = TOP
	for i: int in 3:
		var height: float = fractions[i] * HEIGHT / 100
		draw_rect(Rect2(left + 1, y, width - 2, height), Color(colors[i], 0.42))
		# Labels remain legible even when a section is almost empty.
		var baseline: float = 155 + i * 0
		var label: String = labels[i] + " %.0f%%" % fractions[i]
		var font_size: int = 10
		var label_width: float = ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if height >= 16: draw_string(ThemeDB.fallback_font, Vector2(left + (width - label_width) / 2, y + height / 2 + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
		else: draw_string(ThemeDB.fallback_font, Vector2(7 + i * 42, baseline + 10), labels[i] + " %.0f" % fractions[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, colors[i])
		y += height
	for i: int in 2:
		var at: float = divider(i)
		draw_line(Vector2(left - 5, at), Vector2(left + width + 7, at), ink, 2)
		draw_circle(Vector2(left - 5 if i == 0 else left + width + 7, at), 5, aqua if not has_focus() or i == keyboard_boundary else ink)
