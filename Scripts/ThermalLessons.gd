class_name BathysThermalLessons
extends VBoxContainer

const KINDS := ["charles", "ideal_gas", "real_gas", "joule_thomson"]
var kind: String = "charles"
var experiments: Dictionary = {
	"charles": {"temperature": 20.0},
	"ideal_gas": {"temperature": 20.0, "amount": 0.1, "pressure": 1.0, "volume": 2.5, "solve": 0},
	"real_gas": {"temperature": 20.0, "pressure": 300.0, "gas": 0},
	"joule_thomson": {"temperature": 20.0, "inlet": 200.0, "outlet": 10.0, "gas": 0, "process": 0}}
var result: Dictionary = {}
var diagram: BathysThermalDiagram
var inputs: Dictionary = {}
var values: Dictionary = {}
var blocks: Dictionary = {}
var preset_rows: Dictionary = {}
var gas_picker: OptionButton
var solve_picker: OptionButton
var process_picker: OptionButton
var readouts: GridContainer
var titles: Array[Label] = []
var numbers: Array[Label] = []
var formula: Label
var insight: Label
var explanation: Label
var assumptions: Label
var dirty_time: float = -1
var signature: String = ""

func parameters() -> Dictionary:
	return experiments[kind]

func _ready() -> void:
	add_theme_constant_override("separation", 9)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diagram = BathysThermalDiagram.new()
	diagram.parameter_changed.connect(func(key: String, value: float) -> void:
		var slider: HSlider = inputs[key]
		slider.value = clampf(value, slider.min_value, slider.max_value))
	add_child(diagram)
	var panel: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 10)
	add_child(panel)
	var controls := BathysUiStyle.column(panel, 4)
	solve_picker = picker(controls, ["Solve pressure · rigid volume", "Solve volume · fixed pressure"])
	solve_picker.item_selected.connect(func(index: int) -> void: parameters()["solve"] = index; activate(kind))
	process_picker = picker(controls, ["Real-gas throttle · h constant", "Ideal-gas throttle · h constant", "Ideal expansion with work · s constant"])
	process_picker.item_selected.connect(func(index: int) -> void: parameters()["process"] = index; refresh())
	gas_picker = picker(controls, BathysThermalModels.GAS_NAMES)
	gas_picker.item_selected.connect(func(index: int) -> void: parameters()["gas"] = index; request_refresh())
	add_slider(controls, "temperature", "Gas temperature", -100, 350, 0.05)
	add_slider(controls, "amount", "Gas amount · moles", 0.02, 0.4, 0.001)
	add_slider(controls, "volume", "Rigid vessel volume · litres", 0.2, 15, 0.05)
	add_slider(controls, "pressure", "Pressure · absolute bar", 0.1, 300, 0.1)
	add_slider(controls, "inlet", "Inlet pressure · absolute bar", 2, 300, 1)
	add_slider(controls, "outlet", "Outlet pressure · absolute bar", 1, 200, 1)
	add_presets(controls, "charles", [["20°C reference", {"temperature": 20.0}], ["40°C · not twice as hot", {"temperature": 40.0}], ["Double kelvin", {"temperature": 313.15}]])
	add_presets(controls, "ideal_gas", [["Reference state", {"amount": 0.1, "temperature": 20.0, "volume": 2.5}], ["Half the volume", {"amount": 0.1, "temperature": 20.0, "volume": 1.25, "solve": 0}], ["Warm sealed gas", {"amount": 0.1, "temperature": 60.0, "volume": 2.5, "solve": 0}]])
	add_presets(controls, "real_gas", [["Low pressure", {"pressure": 1.0}], ["200 bar", {"pressure": 200.0}], ["300 bar", {"pressure": 300.0}]])
	add_presets(controls, "joule_thomson", [["Nitrogen cooling", {"gas": 1, "process": 0}], ["Helium warming", {"gas": 2, "process": 0}], ["Ideal throttle", {"process": 1}]])
	readouts = GridContainer.new()
	add_child(readouts)
	for i: int in 3:
		var card: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 8)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		readouts.add_child(card)
		var column := BathysUiStyle.column(card, 2)
		var title: Label = BathysUiStyle.wrapped("", 11)
		column.add_child(title)
		titles.append(title)
		var number := Label.new()
		number.add_theme_font_size_override("font_size", 20)
		number.add_theme_color_override("font_color", BathysUiStyle.AQUA)
		column.add_child(number)
		numbers.append(number)
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
	get_node("/root/I18n").language_changed.connect(update_text)
	activate(kind)

func picker(parent: Node, items: Array) -> OptionButton:
	var node := OptionButton.new()
	node.fit_to_longest_item = false
	node.clip_text = true
	for text: String in items: node.add_item(text)
	parent.add_child(node)
	return node

func add_slider(parent: Node, key: String, caption: String, minimum: float, maximum: float, increment: float) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	parent.add_child(block)
	blocks[key] = block
	var row := HBoxContainer.new()
	block.add_child(row)
	var label: Label = BathysUiStyle.wrapped(caption, 12, BathysUiStyle.TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value := Label.new()
	value.add_theme_color_override("font_color", BathysUiStyle.AQUA)
	value.add_theme_font_size_override("font_size", 12)
	row.add_child(value)
	values[key] = value
	var slider := HSlider.new()
	slider.name = "Thermal_" + key
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = increment
	slider.custom_minimum_size.y = 23
	slider.tooltip_text = caption
	slider.value_changed.connect(func(number: float) -> void:
		parameters()[key] = number
		if key == "inlet": parameters()["outlet"] = minf(number, parameters()["outlet"])
		request_refresh())
	block.add_child(slider)
	inputs[key] = slider

func add_presets(parent: Node, topic: String, entries: Array) -> void:
	var row := HFlowContainer.new()
	parent.add_child(row)
	preset_rows[topic] = row
	for entry: Array in entries:
		var button := Button.new()
		button.text = str(entry[0])
		button.pressed.connect(func() -> void: parameters().merge(entry[1], true); activate(kind))
		row.add_child(button)

func activate(topic: String) -> void:
	kind = topic
	var p: Dictionary = parameters()
	for key: String in blocks:
		(blocks[key] as Control).visible = key in {"charles": ["temperature"], "ideal_gas": ["temperature", "amount", "volume" if int(p.get("solve", 0)) == 0 else "pressure"], "real_gas": ["temperature", "pressure"], "joule_thomson": ["temperature", "inlet", "outlet"]}[kind]
	for key: String in preset_rows: (preset_rows[key] as Control).visible = key == kind
	gas_picker.visible = kind in ["real_gas", "joule_thomson"]
	solve_picker.visible = kind == "ideal_gas"
	process_picker.visible = kind == "joule_thomson"
	diagram.kind = kind
	refresh()
	adapt()

func request_refresh() -> void:
	if dirty_time < 0: dirty_time = 0.025
	sync_controls()

func _process(delta: float) -> void:
	if dirty_time < 0 or not is_visible_in_tree(): return
	dirty_time -= delta
	if dirty_time <= 0: refresh()

func sync_controls() -> void:
	var p: Dictionary = parameters()
	for key: String in inputs:
		var slider: HSlider = inputs[key]
		slider.set_block_signals(true)
		if key == "temperature":
			slider.min_value = -100 if kind == "charles" else (-50 if kind == "ideal_gas" else -20)
			slider.max_value = 350 if kind == "charles" else (150 if kind == "ideal_gas" else 80)
		if key == "pressure": slider.max_value = 10 if kind == "ideal_gas" else 300
		if key == "outlet": slider.max_value = p.get("inlet", 200)
		slider.set_value_no_signal(p.get(key, slider.min_value))
		slider.set_block_signals(false)
		var value: float = p.get(key, 0)
		(values[key] as Label).text = "%.2f°C · %.2f K" % [value, value + 273.15] if key == "temperature" else ("%.3f mol" % value if key == "amount" else ("%.2f L" % value if key == "volume" else "%.1f bar" % value))
	gas_picker.select(p.get("gas", 0))
	solve_picker.select(p.get("solve", 0))
	process_picker.select(p.get("process", 0))

func refresh() -> void:
	dirty_time = -1
	sync_controls()
	var p: Dictionary = parameters()
	match kind:
		"charles": result = BathysThermalModels.charles(p["temperature"])
		"ideal_gas": result = BathysThermalModels.ideal(p)
		"real_gas": result = BathysThermalModels.real(p["gas"], p["pressure"], float(p["temperature"]) + 273.15)
		_: result = BathysThermalModels.cooling(p["gas"], p["inlet"], p["outlet"], float(p["temperature"]) + 273.15, p["process"])
	diagram.params = p
	diagram.result = result
	var next_signature: String = str([kind, p["temperature"], p.get("gas"), p.get("inlet"), p.get("process"), p.get("solve"), p.get("amount"), p.get("volume"), p.get("pressure") if kind == "ideal_gas" else 0])
	if next_signature != signature:
		signature = next_signature
		rebuild_curve()
	update_text()
	diagram.queue_redraw()

func rebuild_curve() -> void:
	var p: Dictionary = parameters()
	diagram.curve.clear()
	match kind:
		"charles":
			diagram.bounds = Rect2(0, 0, 650, 2.3)
			for t: float in [173.15, 623.15]: diagram.curve.append(Vector2(t, t / 293.15))
		"ideal_gas":
			for t: float in [223.15, 423.15]:
				var trial: Dictionary = p.duplicate()
				trial["temperature"] = t - 273.15
				var state: Dictionary = BathysThermalModels.ideal(trial)
				diagram.curve.append(Vector2(t, state["pressure"] if int(p["solve"]) == 0 else state["volume"]))
			diagram.bounds = Rect2(223.15, 0, 200, diagram.curve[1].y * 1.1)
		"real_gas":
			var ymin: float = 1
			var ymax: float = 1
			for i: int in 51:
				var pressure: float = 0.1 + i * 299.9 / 50
				var z: float = BathysThermalModels.real(p["gas"], pressure, float(p["temperature"]) + 273.15)["z"]
				ymin = minf(ymin, z)
				ymax = maxf(ymax, z)
				diagram.curve.append(Vector2(pressure, z))
			diagram.bounds = Rect2(0, ymin - 0.03, 300, ymax - ymin + 0.06)
		_:
			var ymin: float = float(p["temperature"]) + 273.15
			var ymax: float = ymin
			for i: int in 31:
				var pressure: float = 1 + i * (float(p["inlet"]) - 1) / 30
				var state: Dictionary = BathysThermalModels.cooling(p["gas"], p["inlet"], pressure, float(p["temperature"]) + 273.15, p["process"])
				diagram.curve.append(Vector2(pressure, state["tout"]))
				ymin = minf(ymin, state["tout"])
				ymax = maxf(ymax, state["tout"])
			diagram.bounds = Rect2(1, ymin - 5, float(p["inlet"]) - 1, ymax - ymin + 10)

func adapt() -> void:
	readouts.columns = 1 if size.x < 560 else 3
	diagram.adapt()

func update_text() -> void:
	if result.is_empty(): return
	var p: Dictionary = parameters()
	diagram.line_colour = BathysUiStyle.AQUA
	match kind:
		"charles":
			titles[0].text = "Gas volume · fixed 1 bar"
			titles[1].text = "Absolute temperature"
			titles[2].text = "Volume / 20°C reference"
			numbers[0].text = "%.3f L" % float(result["volume"])
			numbers[1].text = "%.2f K" % float(result["kelvin"])
			numbers[2].text = "%.3f×" % float(result["ratio"])
			formula.text = "V₁ / T₁ = V₂ / T₂\n\nT(K) = T(°C) + 273.15"
			insight.text = "Warm the same gas at fixed pressure: the piston rises. Cooling shrinks its volume. Particle count stays the same; temperature changes molecular motion."
			explanation.text = "20°C to 40°C is only 293.15 K to 313.15 K, so volume grows by about 6.8%. Doubling kelvin doubles volume. The origin belongs to the ideal mathematical extrapolation, not an achievable zero-volume gas."
			assumptions.text = "Model: fixed gas amount, frictionless piston, constant 1 bar absolute, ideal equilibrium states. Starts with 1 L at 20°C. Dashed extension is outside the experiment range; real gases condense before reaching absolute zero. Arrows are schematic, with speed scaling as √T."
			diagram.plot_title = "Volume · L versus temperature · K"
			diagram.plot_footer = "Solid: experiment range. Dashed: ideal extrapolation toward 0 K."
		"ideal_gas":
			for i: int in 3: titles[i].text = ["Absolute pressure", "Gas volume", "Gas amount"][i]
			numbers[0].text = "%.3f bar" % float(result["pressure"])
			numbers[1].text = "%.3f L" % float(result["volume"])
			numbers[2].text = "%.3f mol" % float(result["moles"])
			formula.text = tr("PV = nRT\n\nPressure × volume: PV = %.2f J\n\nGas amount × R × temperature: nRT = %.2f J") % [result["pv"], result["nrt"]]
			insight.text = "Pressure, volume, temperature and gas amount are linked. In a rigid vessel, adding gas or heating raises pressure. At fixed pressure, the volume must grow instead."
			explanation.text = "Choose which variable responds. Then vary one input while holding the others steady. The curve keeps n and either V or P fixed. A mole counts gas particles; it is not a fixed volume. Always use absolute pressure and kelvin."
			assumptions.text = "Model: ideal dry gas, uniform equilibrium temperature, no finite molecular volume or attraction. R = 8.314462618 J/(mol·K); 1 bar·L = 100 J. This is an equation of state, not a heating-rate or high-pressure cylinder prediction."
			diagram.plot_title = "Pressure · bar abs versus temperature · K" if int(p["solve"]) == 0 else "Volume · L versus temperature · K"
			diagram.plot_footer = "Fixed n and V · pressure responds" if int(p["solve"]) == 0 else "Fixed n and P · volume responds"
		"real_gas":
			for i: int in 3: titles[i].text = ["Compressibility factor Z", "Gas in 12 L · real model", "Gas in 12 L · ideal model"][i]
			numbers[0].text = "%.4f" % float(result["z"])
			numbers[1].text = "%.2f mol" % float(result["moles_12l"])
			numbers[2].text = "%.2f mol" % float(result["ideal_moles_12l"])
			formula.text = "Z = PV / nRT\n\nn real = n ideal / Z"
			insight.text = "Real molecules attract each other and occupy space. Z = 1 is ideal behaviour. Z below or above 1 means a smaller or larger molar volume at the same pressure and temperature."
			explanation.text = "The paired vessels contain the same mole. The 12 L readouts ask a different question: how much gas fits in the same rigid volume? At Z > 1, the ideal calculation overestimates that amount. Compare gases, pressure and temperature; Z is not the bulk compressibility κT."
			assumptions.text = "Model: Peng–Robinson, same dry O₂/N₂/He constants and zero-interaction mixing as the planner. Air is 21% O₂ / 79% N₂. 253.15–353.15 K, 0.1–300 bar absolute, single phase. Cubic EOS predictions are approximations, particularly for helium; no phase equilibrium or cylinder-rating calculation."
			diagram.plot_title = "Z versus absolute pressure · bar"
			diagram.plot_footer = "Amber dashed line: ideal gas Z = 1"
		_:
			titles[0].text = "Outlet gas temperature"
			titles[1].text = "Outlet minus inlet"
			titles[2].text = "Shaft work out · J/mol" if int(p["process"]) == 2 else "Inlet μJT · K/bar"
			numbers[0].text = "%.1f°C" % (float(result["tout"]) - 273.15)
			numbers[1].text = "%+.2f K" % float(result["delta"])
			numbers[2].text = "%.1f" % float(result["work"]) if int(p["process"]) == 2 else "%+.3f" % float(result["mu"])
			formula.text = "T₂ / T₁ = (P₂ / P₁)^((γ − 1) / γ)\n\nideal, reversible" if int(p["process"]) == 2 else "h₁ = h₂\n\nμJT = (∂T / ∂P)h\n\npositive μ + pressure drop → cooling"
			insight.text = "A pressure drop does not always cool a gas. A real-gas throttle can cool or warm it; an ideal-gas throttle keeps the same temperature. Expansion doing work is a different process."
			explanation.text = "Try nitrogen, then helium: at these inlet temperatures their throttling trends differ. The real-gas curve solves constant enthalpy; the inlet μJT is only a local slope, not a constant to multiply across the whole pressure drop. The work comparison is an ideal reversible expander, not a throttle."
			assumptions.text = "Model: insulated steady flow, negligible inlet/outlet kinetic and potential energy changes. Real throttle uses Peng–Robinson enthalpy departure plus constant ideal Cp (7R/2 for air/N₂, 5R/2 for He). Ideal work comparison has constant γ and omits phase change. No water/metal heat exchange, cylinder blowdown, flow-rate or regulator-icing prediction."
			diagram.plot_title = "Outlet temperature · K versus outlet pressure · bar"
			diagram.plot_footer = "Read from high to low pressure ←; inlet is the right endpoint."
			if int(p["process"]) == 2: diagram.line_colour = AMBER_COLOUR
			if float(result["tout"]) < 180: assumptions.text = tr(assumptions.text) + " " + tr("This ideal comparison reaches cryogenic temperatures; a real gas may change phase.")
	diagram.queue_redraw()

const AMBER_COLOUR := Color("ffb96f")
