class_name BathysMaskLesson
extends VBoxContainer

var params: Dictionary = {"distance": 0.75, "height": 0.3, "gap": 35.0, "thickness": 4.0, "glass_index": 1.5}
var result: Dictionary = {}
var diagram: BathysMaskDiagram
var inputs: Dictionary = {}
var values: Dictionary = {}
var readouts: GridContainer
var numbers: Array[Label] = []
var insight: Label
var explanation: Label
var assumptions: Label

func _ready() -> void:
	add_theme_constant_override("separation", 9)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diagram = BathysMaskDiagram.new()
	diagram.parameter_changed.connect(func(key: String, value: float) -> void: (inputs[key] as HSlider).value = value)
	add_child(diagram)
	var panel: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 10)
	add_child(panel)
	var controls := BathysUiStyle.column(panel, 4)
	add_slider(controls, "distance", "Object distance beyond outer window", 0.5, 3, 0.01)
	add_slider(controls, "height", "Object physical height", 0.05, 0.4, 0.01)
	add_slider(controls, "gap", "Eye → inner window · air gap", 15, 80, 1)
	add_slider(controls, "thickness", "Flat window thickness", 1, 12, 0.5)
	add_slider(controls, "glass_index", "Window refractive index · chosen", 1.34, 1.7, 0.001)
	readouts = GridContainer.new()
	add_child(readouts)
	for title: String in ["Real eye → object distance", "Edge back-projected distance", "Angular size / all-air reference"]:
		var card: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 8)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		readouts.add_child(card)
		var column := BathysUiStyle.column(card, 2)
		column.add_child(BathysUiStyle.wrapped(title, 11))
		var number := Label.new()
		number.add_theme_font_size_override("font_size", 20)
		number.add_theme_color_override("font_color", BathysUiStyle.AQUA)
		column.add_child(number)
		numbers.append(number)
	var formula: Label = BathysUiStyle.wrapped("n_w sin θ_w = n_g sin θ_g = n_a sin θ_a", 15, BathysUiStyle.AQUA)
	formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(formula)
	var box: PanelContainer = BathysUiStyle.panel(Color("143c43"), 10)
	add_child(box)
	var text := BathysUiStyle.column(box, 5)
	insight = BathysUiStyle.wrapped("", 13, BathysUiStyle.TEXT)
	text.add_child(insight)
	explanation = BathysUiStyle.wrapped("", 12)
	text.add_child(explanation)
	assumptions = BathysUiStyle.wrapped("", 11)
	add_child(assumptions)
	resized.connect(adapt)
	get_node("/root/I18n").language_changed.connect(update_text)
	refresh()

func add_slider(parent: Node, key: String, caption: String, minimum: float, maximum: float, increment: float) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	parent.add_child(block)
	var row := HBoxContainer.new()
	block.add_child(row)
	var label: Label = BathysUiStyle.wrapped(caption, 12, BathysUiStyle.TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value := Label.new()
	value.add_theme_color_override("font_color", BathysUiStyle.AQUA)
	row.add_child(value)
	values[key] = value
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = increment
	slider.custom_minimum_size.y = 23
	slider.tooltip_text = caption
	slider.value_changed.connect(func(number: float) -> void: params[key] = number; refresh())
	block.add_child(slider)
	inputs[key] = slider

func refresh() -> void:
	for key: String in inputs:
		(inputs[key] as HSlider).set_value_no_signal(params[key])
		(values[key] as Label).text = "%.0f mm" % float(params[key]) if key == "gap" else ("%.1f mm" % float(params[key]) if key == "thickness" else ("%.3f" % float(params[key]) if key == "glass_index" else "%.2f m" % float(params[key])))
	result = BathysMaskOptics.trace(params)
	diagram.params = params
	diagram.result = result
	diagram.queue_redraw()
	update_text()

func adapt() -> void:
	readouts.columns = 1 if size.x < 560 else 3
	diagram.adapt()

func update_text() -> void:
	if result.is_empty(): return
	numbers[0].text = "%.3f m" % float(result["actual"])
	numbers[1].text = "%.3f m" % float(result["apparent"])
	numbers[2].text = "%.3f×" % float(result["magnification"])
	insight.text = "The same object subtends a larger angle through the mask than in air. Extending incoming rays straight makes it seem closer. Its physical height is unchanged."
	explanation.text = "Water → glass bends toward the normal; glass → mask air bends away. A flat parallel window has no focusing curvature. Near the axis with a small air gap, the familiar limits are about 1.33× angular size and 0.75× apparent distance. Glass thickness, eye spacing and viewing angle change the exact geometry."
	assumptions.text = "Model: pinhole eye, parallel flat window, water n = 1.333 and mask air n = 1.000; selected window index. Exact Snell rays through both faces. Distance is an edge-pair back-projection, not one perfect image plane for all off-axis points. The comparison is with the same object in air, not a bare underwater eye. The air pocket also restores the air–cornea interface; eye focusing is not simulated. No corrective/curved lens, finite mask aperture, dispersion or reflected intensity. Overview distances share one scale; the interface inset exaggerates glass thickness."
