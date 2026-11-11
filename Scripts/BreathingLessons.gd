class_name BathysBreathingLessons
extends VBoxContainer

var kind: String = "oxygen"
var experiments: Dictionary = {
	"oxygen": {"depth": 30.0, "oxygen": 32.0, "helium": 0.0, "time": 30.0, "temperature": 20.0},
	"narcosis": {"depth": 40.0, "oxygen": 21.0, "helium": 0.0, "time": 30.0, "temperature": 20.0},
	"gas_density": {"depth": 40.0, "oxygen": 18.0, "helium": 45.0, "time": 30.0, "temperature": 20.0}}
var oxygen_narcotic: bool = true
var diagram: BathysBreathingDiagram
var inputs: Dictionary = {}
var values: Dictionary = {}
var control_blocks: Dictionary = {}
var preset_rows: Dictionary = {}
var convention_block: VBoxContainer
var convention: OptionButton
var readouts: GridContainer
var titles: Array[Label] = []
var numbers: Array[Label] = []
var formula: Label
var insight: Label
var explanation: Label
var assumptions: Label
var result: Dictionary = {}
var density_signature: String = ""

func _ready() -> void:
	add_theme_constant_override("separation", 9)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	diagram = BathysBreathingDiagram.new()
	diagram.size_flags_vertical = Control.SIZE_EXPAND_FILL
	diagram.lesson_depth_changed.connect(func(value: float) -> void: (inputs["depth"] as HSlider).value = value)
	add_child(diagram)
	var panel: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 10)
	add_child(panel)
	var controls := BathysUiStyle.column(panel, 4)
	add_slider(controls, "depth", "Depth", 80, 0.1)
	add_slider(controls, "oxygen", "Oxygen fraction", 100, 0.1)
	add_slider(controls, "helium", "Helium fraction", 100, 0.1)
	add_slider(controls, "time", "Exposure duration", 240, 0.5)
	add_slider(controls, "temperature", "Gas temperature · not water temperature", 35, 0.1)
	convention_block = BathysUiStyle.column(controls, 2)
	convention_block.add_child(BathysUiStyle.wrapped("Count as narcotic", 12, BathysUiStyle.TEXT))
	convention = OptionButton.new()
	convention.name = "NarcosisConvention"
	convention.add_item("N₂ + O₂")
	convention.add_item("N₂ only")
	convention.item_selected.connect(func(index: int) -> void: oxygen_narcotic = index == 0; refresh())
	convention_block.add_child(convention)
	add_presets(controls, "oxygen", [["Air at 30 m", 30.0, 21.0, 0.0], ["Nitrox at 30 m", 30.0, 32.0, 0.0], ["O₂ at 6 m", 6.0, 100.0, 0.0]])
	for topic: String in ["narcosis", "gas_density"]:
		add_presets(controls, topic, [["Air · 21/0", -1.0, 21.0, 0.0], ["Nitrox · 32/0", -1.0, 32.0, 0.0], ["Trimix · 18/45", -1.0, 18.0, 45.0]])
	readouts = GridContainer.new()
	add_child(readouts)
	for i: int in 3:
		var card: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 8)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		readouts.add_child(card)
		var stack := BathysUiStyle.column(card, 2)
		var caption: Label = BathysUiStyle.wrapped("", 11)
		stack.add_child(caption)
		titles.append(caption)
		var value := Label.new()
		value.add_theme_color_override("font_color", BathysUiStyle.AQUA)
		stack.add_child(value)
		numbers.append(value)
	formula = BathysUiStyle.wrapped("", 15, BathysUiStyle.AQUA)
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
	get_node("/root/I18n").language_changed.connect(refresh)
	set_lesson(kind)

func parameters() -> Dictionary:
	return experiments[kind] as Dictionary

func add_slider(parent: Node, key: String, caption: String, maximum: float, step_size: float) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	parent.add_child(block)
	control_blocks[key] = block
	var row := HBoxContainer.new()
	block.add_child(row)
	var title: Label = BathysUiStyle.wrapped(caption, 12, BathysUiStyle.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var value := Label.new()
	value.add_theme_color_override("font_color", BathysUiStyle.AQUA)
	row.add_child(value)
	values[key] = value
	var slider := HSlider.new()
	slider.name = "Breathing_" + key
	slider.max_value = maximum
	slider.step = step_size
	slider.custom_minimum_size.y = 23
	slider.tooltip_text = caption
	slider.value_changed.connect(func(number: float) -> void:
		var params: Dictionary = parameters()
		params[key] = number
		if key == "oxygen": params["helium"] = minf(params["helium"], 100 - number)
		if key == "helium": params["oxygen"] = minf(params["oxygen"], 100 - number)
		refresh())
	block.add_child(slider)
	inputs[key] = slider

func add_presets(parent: Node, topic: String, entries: Array) -> void:
	var row := HFlowContainer.new()
	parent.add_child(row)
	preset_rows[topic] = row
	for entry: Array in entries:
		var button := Button.new()
		button.text = str(entry[0])
		button.set_meta("gas_mixture", Vector2(entry[2], entry[3]))
		button.pressed.connect(func() -> void:
			var params: Dictionary = parameters()
			if float(entry[1]) >= 0: params["depth"] = float(entry[1])
			params["oxygen"] = float(entry[2])
			params["helium"] = float(entry[3])
			refresh())
		row.add_child(button)

func set_lesson(topic: String) -> void:
	if topic not in experiments: return
	kind = topic
	for key: String in control_blocks:
		(control_blocks[key] as Control).visible = key in {"oxygen": ["depth", "oxygen", "time"], "narcosis": ["depth", "oxygen", "helium"], "gas_density": ["depth", "oxygen", "helium", "temperature"]}[kind]
	for key: String in preset_rows: (preset_rows[key] as Control).visible = key == kind
	convention_block.visible = kind == "narcosis"
	convention.visible = kind == "narcosis"
	convention.select(0 if oxygen_narcotic else 1)
	diagram.kind = kind
	refresh()
	adapt()

func adapt() -> void:
	readouts.columns = 1 if size.x < 450 else 3
	diagram.adapt()

func refresh() -> void:
	var params: Dictionary = parameters()
	for key: String in inputs:
		(inputs[key] as HSlider).set_value_no_signal(params[key])
		(values[key] as Label).text = "%.1f%%" % params[key] if key in ["oxygen", "helium"] else ("%.1f m" % params[key] if key == "depth" else ("%.1f min" % params[key] if key == "time" else "%.1f°C" % params[key]))
	for value: Label in numbers: value.add_theme_font_size_override("font_size", 20)
	diagram.depth = params["depth"]
	diagram.oxygen = params["oxygen"]
	diagram.helium = params["helium"]
	diagram.minutes = params["time"]
	diagram.temperature = params["temperature"]
	diagram.oxygen_narcotic = oxygen_narcotic
	match kind:
		"oxygen":
			result = BathysLearningModels.oxygen_exposure(params["depth"], params["oxygen"], params["time"])
			titles[0].text = "Oxygen partial pressure"
			titles[1].text = "CNS exposure index"
			titles[2].text = "Pulmonary exposure · OTU"
			numbers[0].text = "%.2f bar" % float(result["pp_o2"])
			numbers[1].text = "%.1f%%" % float(result["cns"]) if bool(result["cns_valid"]) else tr("Outside table")
			if not bool(result["cns_valid"]): numbers[1].add_theme_font_size_override("font_size", 14)
			numbers[2].text = "%.1f" % float(result["otu"])
			formula.text = "ppO₂ = F O₂ × P · 1 OTU = 1 min at 1 ata O₂"
			insight.text = "Oxygen affects the brain and lungs differently. CNS and OTU are separate exposure indexes, not probabilities of a seizure or lung injury."
			explanation.text = "CNS toxicity can cause convulsions; prolonged oxygen exposure can affect the lungs. A CNS reading of 100% is a table exposure allocation, not a symptom threshold. Responses vary, and zero clock accrual does not mean a gas is suitable to breathe."
			assumptions.text = "Model: constant depth and dry O₂ fraction, 1 bar + depth/10. Uses the app’s historical NOAA-style CNS table in bar, only through 1.6 bar; no extrapolation above it. OTU uses oxygen pressure in ata. Single exposure, no recovery or prior loading. These indexes do not predict individual tolerance."
		"narcosis":
			result = BathysLearningModels.narcosis_comparison(params["depth"], params["oxygen"], params["helium"], oxygen_narcotic)
			titles[0].text = "Nitrogen partial pressure"
			titles[1].text = "Equivalent narcotic depth"
			titles[2].text = "Counted narcotic fraction"
			numbers[0].text = "%.2f bar" % float(result["pp_n2"])
			numbers[1].text = "≤0 m" if bool(result["below_surface"]) else "%.1f m" % float(result["end_m"])
			numbers[2].text = "%.1f%%" % (float(result["fraction"]) * 100)
			formula.text = "END = 10 × (P × F narcotic / F air − 1)"
			insight.text = "Higher inert-gas partial pressure can impair attention, judgement and coordination. END compares a gas with air; it does not measure how impaired a person will be."
			explanation.text = "Replace some nitrogen with helium and compare at the same depth. Change the oxygen assumption: when O₂ and N₂ are counted equally, nitrox has the same END as air. CO₂ retention, effort and individual response are not captured by END."
			assumptions.text = "Model: ideal dry mixture, 1 bar + depth/10. Choose N₂ + O₂ or N₂ only; helium is treated as non-narcotic. Below the air surface reference, END is shown as ≤0 m. Excludes HPNS and individual symptoms. This comparison does not assess oxygen or decompression limits."
		"gas_density":
			result = BathysLearningModels.breathing_density(params["depth"], params["oxygen"], params["helium"], params["temperature"])
			titles[0].text = "Gas density"
			titles[1].text = "Compared with air"
			titles[2].text = "Ambient pressure"
			numbers[0].text = "%.2f g/L" % float(result["density"])
			numbers[1].text = "%.2f×" % float(result["ratio"])
			numbers[2].text = "%.1f bar" % float(result["ambient"])
			formula.text = "Density = mass / volume · ideal trend: ρ ∝ P × molar mass / T (kelvin)"
			insight.text = "One litre contains more gas mass at greater pressure. Helium lowers mixture density; cooling the gas raises it. Denser gas can increase breathing effort and hinder CO₂ elimination."
			explanation.text = "Compare equal one-litre volumes and the density curves. The 5.2 and 6.2 g/L lines are published planning references from breathing/CO₂ studies, not a prediction of breathing effort or a guarantee of safety. Equipment, flow and workload also matter."
			assumptions.text = "Model: app’s Peng–Robinson real-gas calculation for dry O₂/N₂/He, uniform gas temperature in °C, 1 bar + depth/10. Air comparison uses the same pressure and temperature. Dot sizes/counts are schematic; they illustrate molecular mass and compression. Density references are fixed teaching values, independent of scenario settings."
			var signature: String = str([params["oxygen"], params["helium"], params["temperature"]])
			if signature != density_signature:
				density_signature = signature
				diagram.rebuild_density()
			diagram.density_result = result
	diagram.queue_redraw()
