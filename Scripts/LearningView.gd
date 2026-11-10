class_name BathysLearningView
extends MarginContainer

const BOYLE_SOURCE := "https://www.grc.nasa.gov/www/BGH/boyle.html"
const SNELL_SOURCE := "https://openstax.org/books/university-physics-volume-3/pages/1-4-total-internal-reflection"
var lesson: String = "boyle"
var depth_m: float = 10.0
var angle_deg: float = 30.0
var from_water: bool = false
var layout: BoxContainer
var navigation: PanelContainer
var topic_buttons: Dictionary = {}
var title_label: Label
var intro_label: Label
var diagram: BathysLessonDiagram
var control_label: Label
var control_value: Label
var slider: HSlider
var presets: HBoxContainer
var direction_picker: OptionButton
var critical_button: Button
var readouts: GridContainer
var readout_titles: Array[Label] = []
var readout_values: Array[Label] = []
var formula_label: Label
var insight_label: Label
var relevance_label: Label
var assumptions_label: Label
var source_button: LinkButton

func _ready() -> void:
	name = "LearningView"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 8)
	layout = BoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	add_child(layout)
	navigation = BathysUiStyle.panel(BathysUiStyle.PANEL, 12)
	layout.add_child(navigation)
	var nav := BathysUiStyle.column(navigation, 12)
	nav.add_child(label("LEARN & EXPLORE", 12, BathysUiStyle.AQUA))
	var group := ButtonGroup.new()
	for item: Array in [["boyle", "Boyle’s law"], ["snell", "Snell’s law"]]:
		var key: String = str(item[0])
		var button := Button.new()
		button.name = "Topic_" + key
		button.text = str(item[1])
		button.icon = load("res://Assets/Icons/law-" + key + ".svg")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 48
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(select_lesson.bind(key))
		nav.add_child(button)
		topic_buttons[key] = button
	var lesson_panel: PanelContainer = BathysUiStyle.panel(BathysUiStyle.PANEL, 16)
	lesson_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(lesson_panel)
	var body := BathysUiStyle.column(lesson_panel, 10)
	title_label = label("", 26)
	body.add_child(title_label)
	intro_label = BathysUiStyle.wrapped("", 14, BathysUiStyle.TEXT)
	body.add_child(intro_label)
	diagram = BathysLessonDiagram.new()
	diagram.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(diagram)
	diagram.depth_changed.connect(func(value: float) -> void: slider.value = value)
	diagram.angle_changed.connect(func(value: float) -> void: slider.value = value)
	var controls: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 10)
	body.add_child(controls)
	var controls_stack := BathysUiStyle.column(controls, 6)
	var row := HBoxContainer.new()
	controls_stack.add_child(row)
	control_label = BathysUiStyle.wrapped("", 13, BathysUiStyle.TEXT)
	control_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control_label)
	control_value = label("", 18, BathysUiStyle.AQUA)
	row.add_child(control_value)
	slider = HSlider.new()
	slider.name = "LessonSlider"
	slider.step = 0.1
	slider.custom_minimum_size.y = 24
	slider.value_changed.connect(func(value: float) -> void:
		if lesson == "boyle": depth_m = value
		else: angle_deg = value
		update_values())
	controls_stack.add_child(slider)
	presets = HBoxContainer.new()
	controls_stack.add_child(presets)
	for depth: int in [0, 10, 20, 30, 40]:
		var button := Button.new()
		button.text = "%d m" % depth
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: slider.value = depth)
		presets.add_child(button)
	var optics_controls := HFlowContainer.new()
	optics_controls.name = "OpticsControls"
	controls_stack.add_child(optics_controls)
	direction_picker = OptionButton.new()
	direction_picker.name = "LightDirection"
	direction_picker.add_item("Air → water")
	direction_picker.add_item("Water → air")
	direction_picker.item_selected.connect(func(index: int) -> void: from_water = index == 1; update_values())
	optics_controls.add_child(direction_picker)
	critical_button = Button.new()
	critical_button.text = "Explore the critical angle"
	critical_button.pressed.connect(func() -> void:
		from_water = true
		direction_picker.select(1)
		slider.value = BathysLessonDiagram.critical_angle()
		update_values())
	optics_controls.add_child(critical_button)
	readouts = GridContainer.new()
	readouts.columns = 3
	body.add_child(readouts)
	for i: int in 3:
		var card: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 8)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		readouts.add_child(card)
		var stack := BathysUiStyle.column(card, 2)
		var caption: Label = BathysUiStyle.wrapped("", 11)
		stack.add_child(caption)
		readout_titles.append(caption)
		var value: Label = label("", 20, BathysUiStyle.AQUA)
		stack.add_child(value)
		readout_values.append(value)
	formula_label = label("", 17, BathysUiStyle.AQUA)
	formula_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(formula_label)
	var insight: PanelContainer = BathysUiStyle.panel(Color("143c43"), 10)
	body.add_child(insight)
	var insight_stack := BathysUiStyle.column(insight, 5)
	insight_label = BathysUiStyle.wrapped("", 14, BathysUiStyle.TEXT)
	insight_stack.add_child(insight_label)
	relevance_label = BathysUiStyle.wrapped("", 12)
	insight_stack.add_child(relevance_label)
	assumptions_label = BathysUiStyle.wrapped("", 11)
	body.add_child(assumptions_label)
	source_button = LinkButton.new()
	source_button.text = "Model reference ↗"
	source_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	source_button.pressed.connect(func() -> void: OS.shell_open(BOYLE_SOURCE if lesson == "boyle" else SNELL_SOURCE))
	body.add_child(source_button)
	resized.connect(adapt_layout)
	get_node("/root/I18n").language_changed.connect(update_values)
	select_lesson("boyle")
	call_deferred("adapt_layout")

func label(value: String, font_size: int = 14, color: Color = BathysUiStyle.TEXT) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result

func adapt_layout() -> void:
	layout.vertical = size.x < 760
	navigation.custom_minimum_size.x = 0 if layout.vertical else 208
	readouts.columns = 1 if size.x < 450 else 3
	diagram.adapt()

func select_lesson(key: String) -> void:
	if key not in ["boyle", "snell"]:
		return
	lesson = key
	for topic: String in topic_buttons:
		(topic_buttons[topic] as Button).set_pressed_no_signal(topic == lesson)
	slider.set_block_signals(true)
	slider.max_value = 40 if lesson == "boyle" else 89
	slider.value = depth_m if lesson == "boyle" else angle_deg
	slider.set_block_signals(false)
	presets.visible = lesson == "boyle"
	direction_picker.get_parent().visible = lesson == "snell"
	diagram.lesson = lesson
	diagram.adapt()
	update_values()

func update_values() -> void:
	var boyle: bool = lesson == "boyle"
	title_label.text = "Boyle’s law" if boyle else "Snell’s law"
	intro_label.text = "Take the same trapped gas deeper. More pressure squeezes it into less space." if boyle else "Light changes direction at the water surface. Change its angle and follow the ray."
	control_label.text = "Depth" if boyle else "Angle of incidence · from the normal"
	slider.tooltip_text = "Depth · Left/Right to adjust" if boyle else "Angle of incidence · Left/Right to adjust"
	control_value.text = "%.1f m" % depth_m if boyle else "%.1f°" % angle_deg
	diagram.depth_m = depth_m
	diagram.angle_deg = angle_deg
	diagram.from_water = from_water
	diagram.queue_redraw()
	readout_values[1].add_theme_font_size_override("font_size", 20)
	if boyle:
		var pressure: float = BathysLessonDiagram.pressure_at(depth_m)
		var volume: float = BathysLessonDiagram.volume_at(depth_m)
		readout_titles[0].text = "Absolute pressure"
		readout_titles[1].text = "Gas volume"
		readout_titles[2].text = "Surface volume remaining"
		readout_values[0].text = "%.2f bar" % pressure
		readout_values[1].text = "%.2f L" % volume
		readout_values[2].text = "%.0f%%" % (volume * 100)
		formula_label.text = "P₁ × V₁ = P₂ × V₂"
		insight_label.text = tr("At %.1f m, pressure is %.1f× the surface pressure and the gas occupies %.0f%% of its original volume.") % [depth_m, pressure, volume * 100]
		relevance_label.text = "On ascent, trapped gas expands. This explains changes in buoyancy and why divers must never hold their breath. Try moving from 20 m back to the surface."
		assumptions_label.text = "Model: fixed gas amount and temperature, flexible gas space. Starts at 1 L and 1 bar absolute; adds approximately 1 bar per 10 m. Independent of the lake scenario."
	else:
		var result: Dictionary = BathysLessonDiagram.refraction(angle_deg, from_water)
		var tir: bool = bool(result["tir"])
		readout_titles[0].text = "Incident angle θ₁"
		readout_titles[1].text = "Refracted angle θ₂"
		readout_titles[2].text = "Critical angle · water → air"
		readout_values[0].text = "%.1f°" % angle_deg
		readout_values[1].text = tr("No transmitted ray") if tir else "%.1f°" % float(result["angle"])
		readout_values[1].add_theme_font_size_override("font_size", 14 if tir else 20)
		readout_values[2].text = "%.1f°" % BathysLessonDiagram.critical_angle()
		formula_label.text = "n₁ sin θ₁ = n₂ sin θ₂"
		if tir:
			insight_label.text = "Total internal reflection: the light stays in the water and reflects at the same angle."
		elif from_water:
			insight_label.text = "Water → air: the ray bends away from the normal. Beyond 48.6°, it reflects back into the water."
		else:
			insight_label.text = "Air → water: the ray bends toward the normal. At 0°, it continues straight."
		relevance_label.text = "Looking up underwater, the world above fits inside Snell’s window, a cone about 97° wide. Outside it, the surface acts like a mirror."
		assumptions_label.text = "Model: flat air–water boundary; n = 1.000 in air and 1.333 in water. Angles are measured from the normal (dashed line). Partial reflection below the critical angle is omitted."
