class_name BathysExchangeLesson
extends VBoxContainer

var context: String = "lungs"
var experiments: Dictionary = {
	"lungs": {"source": 100.0, "initial": 40.0, "area": 1.0, "thickness": 1.0, "permeability": 1.0, "capacity": 1.0, "time": 1.0, "inert": false},
	"tissues": {"source": 100.0, "initial": 40.0, "area": 1.0, "thickness": 1.0, "permeability": 1.0, "capacity": 3.0, "time": 1.0, "inert": false}}
var diagram: BathysExchangeDiagram
var result: Dictionary = {}
var stage_buttons: Array[Button] = []
var inputs: Dictionary = {}
var values: Dictionary = {}
var blocks: Dictionary = {}
var preset_rows: Dictionary = {}
var readouts: GridContainer
var numbers: Array[Label] = []
var formula: Label
var insight: Label
var explanation: Label
var assumptions: Label

func parameters() -> Dictionary:
	return experiments[context]

func _ready() -> void:
	add_theme_constant_override("separation", 9)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stages := HFlowContainer.new()
	add_child(stages)
	var group := ButtonGroup.new()
	for key: String in ["lungs", "tissues"]:
		var button := Button.new()
		button.icon = load("res://Assets/Icons/exchange-" + key + ".svg")
		button.tooltip_text = "Lungs ↔ blood" if key == "lungs" else "Blood ↔ tissues"
		button.custom_minimum_size = Vector2(108, 48)
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(set_context.bind(key))
		stages.add_child(button)
		stage_buttons.append(button)
	diagram = BathysExchangeDiagram.new()
	diagram.parameter_changed.connect(func(key: String, value: float) -> void: (inputs[key] as HSlider).value = value)
	add_child(diagram)
	var panel: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 10)
	add_child(panel)
	var controls := BathysUiStyle.column(panel, 4)
	add_slider(controls, "source", "Source partial pressure · mmHg", 0, 200, 0.5)
	add_slider(controls, "initial", "Initial receiver partial pressure · mmHg", 0, 200, 0.5)
	add_slider(controls, "area", "Exchange area · relative", 0.2, 2, 0.05)
	add_slider(controls, "thickness", "Barrier thickness · relative", 0.25, 4, 0.05)
	add_slider(controls, "permeability", "Effective permeability · relative", 0.25, 3, 0.05)
	add_slider(controls, "capacity", "Receiver gas storage · relative", 0.5, 6, 0.1)
	add_slider(controls, "time", "Contact / elapsed time · reference intervals", 0, 5, 0.01)
	controls.add_child(BathysUiStyle.wrapped("Pressure presets do not set gas permeability.", 11))
	add_presets(controls, "lungs", [["Lung O₂ · into blood", {"source": 100.0, "initial": 40.0}], ["Lung CO₂ · out of blood", {"source": 40.0, "initial": 46.0}]])
	add_presets(controls, "tissues", [["Tissue O₂ delivery", {"source": 100.0, "initial": 40.0, "inert": false}], ["Tissue CO₂ return", {"source": 40.0, "initial": 46.0, "inert": false}], ["Inert gas · uptake", {"source": 1500.0, "initial": 570.0, "inert": true}], ["Inert gas · release", {"source": 570.0, "initial": 1500.0, "inert": true}]])
	readouts = GridContainer.new()
	add_child(readouts)
	for title: String in ["Current source − receiver · ΔP", "Rate now / initially · relative", "Equilibration half-time · τ₀"]:
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
	formula = BathysUiStyle.wrapped("Q̇ ∝ A × κ × ΔP / δ\n\nκ includes mobility and solubility", 14, BathysUiStyle.AQUA)
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
	set_context(context)

func add_slider(parent: Node, key: String, title: String, minimum: float, maximum: float, increment: float) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	parent.add_child(block)
	blocks[key] = block
	var row := HBoxContainer.new()
	block.add_child(row)
	var label: Label = BathysUiStyle.wrapped(title, 12, BathysUiStyle.TEXT)
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
	slider.tooltip_text = title
	slider.value_changed.connect(func(number: float) -> void: parameters()[key] = number; refresh())
	block.add_child(slider)
	inputs[key] = slider

func add_presets(parent: Node, key: String, entries: Array) -> void:
	var row := HFlowContainer.new()
	parent.add_child(row)
	preset_rows[key] = row
	for entry: Array in entries:
		var button := Button.new()
		button.text = str(entry[0])
		button.pressed.connect(func() -> void: parameters().merge(entry[1], true); refresh())
		row.add_child(button)

func set_context(key: String) -> void:
	context = key
	for i: int in 2: stage_buttons[i].set_pressed_no_signal((i == 1) == (context == "tissues"))
	for id: String in preset_rows: (preset_rows[id] as Control).visible = id == context
	(blocks["capacity"] as Control).visible = context == "tissues"
	diagram.tissues = context == "tissues"
	refresh()
	adapt()

func refresh() -> void:
	var p: Dictionary = parameters()
	for key: String in inputs:
		var slider: HSlider = inputs[key]
		slider.set_block_signals(true)
		if key in ["source", "initial"]: slider.max_value = 1800 if p["inert"] else 200
		slider.set_value_no_signal(p[key])
		slider.set_block_signals(false)
		(values[key] as Label).text = "%.1f mmHg" % float(p[key]) if key in ["source", "initial"] else ("%.2f τ₀" % float(p[key]) if key == "time" else "%.2f×" % float(p[key]))
	result = BathysExchangeModels.exchange(p)
	diagram.params = p
	diagram.result = result
	diagram.queue_redraw()
	update_text()

func adapt() -> void:
	readouts.columns = 1 if size.x < 560 else 3
	diagram.adapt()

func update_text() -> void:
	if result.is_empty(): return
	numbers[0].text = "%+.1f mmHg" % float(result["gradient"])
	numbers[1].text = "%+.3f / %+.3f" % [result["flux"], result["initial_flux"]]
	for index: int in 2: numbers[index].add_theme_color_override("font_color", BathysExchangeDiagram.VIOLET if float(result["flux"]) < 0 else BathysUiStyle.AQUA)
	numbers[2].text = "%.2f τ₀" % float(result["half_time"])
	insight.text = "At the same pressure gradient, more area or permeability increases transfer; a thicker barrier reduces it. Each gas follows its own partial-pressure gradient. Reverse that gradient and the net arrow reverses."
	explanation.text = "In the lung example, a finite blood parcel approaches a maintained alveolar pressure. In tissues, extra gas-storage capacity slows the pressure change at the same initial transfer rate. Scrub time: as the receiver equilibrates, the gradient and net transfer shrink. Faster equilibration can leave a smaller current rate despite a larger initial rate."
	assumptions.text = "Teaching model: uniform barrier, fixed source and one well-mixed finite receiver. κ combines diffusion mobility and solubility; storage C is independent. A, κ, δ and C are relative; τ₀ is an arbitrary reference interval, not a human transit time. Rate 1 means the initial 100→40 mmHg reference at unit geometry. Presets set pressure examples only, not gas-specific permeabilities. No haemoglobin binding, CO₂ chemistry, ventilation/perfusion or metabolism; real flow and consumption maintain gradients. This is diffusion, not Fick’s cardiac-output principle or a calibrated tissue/decompression model."
