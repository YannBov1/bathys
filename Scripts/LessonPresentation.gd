class_name BathysLessonPresentation
extends Node

var host
var body: VBoxContainer
var toolbar: HBoxContainer
var hint: Label
var chart_button: Button
var note_button: Button
var instruments: HFlowContainer
var range_dock: CenterContainer
var actions: HFlowContainer
var outcome: BoxContainer
var outcome_title: Label
var outcome_value: Label
var widgets: Dictionary = {}
var control_nodes: Array[Control] = []
var note_nodes: Array[Control] = []
var mirrors: Array = []
var diagram: BathysLessonDiagram
var output_source: Label
var output_caption: Label
var signature: String = ""
var active_owner: Control
var graph_available: bool = false

func setup(view, parent: VBoxContainer) -> void:
	host = view
	body = parent
	toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 7)
	body.add_child(toolbar)
	body.move_child(toolbar, 2)
	hint = BathysUiStyle.wrapped("", 12, BathysUiStyle.AQUA)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(hint)
	chart_button = toggle("res://Assets/Icons/lesson-chart.svg", "Show linked chart")
	chart_button.set_pressed_no_signal(true)
	note_button = toggle("res://Assets/Icons/lesson-info.svg", "Explanation, equations and model limits")
	instruments = HFlowContainer.new()
	instruments.alignment = FlowContainer.ALIGNMENT_CENTER
	instruments.add_theme_constant_override("h_separation", 6)
	instruments.add_theme_constant_override("v_separation", 6)
	body.add_child(instruments)
	range_dock = CenterContainer.new()
	body.add_child(range_dock)
	actions = HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 6)
	body.add_child(actions)
	outcome = BoxContainer.new()
	outcome.add_theme_constant_override("separation", 12)
	body.add_child(outcome)
	outcome_title = BathysUiStyle.wrapped("", 12)
	outcome_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outcome.add_child(outcome_title)
	outcome_value = Label.new()
	outcome_value.add_theme_font_size_override("font_size", 21)
	outcome_value.add_theme_color_override("font_color", BathysUiStyle.AQUA)
	outcome.add_child(outcome_value)
	# Short stage names keep the focus on the apparatus, including on phones.
	var short_stages: Dictionary = {"1 · Load tissues": "Loading", "2 · Explore ascent": "Ascent", "1 · Displacement": "Displacement", "2 · Gas at depth": "At depth", "Lungs · blood parcel": "Lungs", "Tissues · storage & release": "Tissues", "Colour & light": "Colour", "Water & scattering": "Water optics", "Why two coefficients?": "Image model", "Boundary & rays": "Refraction", "Mask & apparent size": "Mask"}
	for owner in [host.buhlmann_view, host.buoyancy_view, host.exchange_view, host.optics_view]:
		for button: Button in owner.stage_buttons:
			if button.text.is_empty(): continue
			button.tooltip_text = button.text
			button.text = short_stages.get(button.text, button.text)
	for button: Button in host.snell_buttons:
		if button.text.is_empty(): continue
		button.tooltip_text = button.text
		button.text = short_stages.get(button.text, button.text)
	sync()

func toggle(icon_path: String, description: String) -> Button:
	var button := Button.new()
	button.icon = load(icon_path)
	button.tooltip_text = description
	button.custom_minimum_size = Vector2(34, 34)
	button.toggle_mode = true
	button.toggled.connect(func(_value: bool) -> void: apply_visibility())
	toolbar.add_child(button)
	return button

func expand_all() -> void:
	for button: Button in [chart_button, note_button]: button.button_pressed = true
	sync()

func compact_all() -> void:
	for button: Button in [chart_button, note_button]: button.button_pressed = false
	sync()

func _process(_delta: float) -> void:
	if not is_instance_valid(host) or not host.is_visible_in_tree(): return
	var key: String = str([host.lesson, host.snell_mask, host.thermal_view.kind, host.breathing_view.kind,
		host.buoyancy_view.at_depth, host.buoyancy_view.cylinder_preset_index >= 0, host.buhlmann_view.ascent, host.optics_view.stage, host.exchange_view.context, host.thermal_view.parameters().get("solve", 0), host.transport_view.parameters().get("stage", 0), host.transport_view.parameters().get("medium", 0), host.transport_view.parameters().get("material", 0), host.transport_view.parameters().get("basis", 0), host.transport_view.parameters().get("boundary", 0)])
	if key != signature:
		signature = key
		sync()
	apply_visibility()
	if is_instance_valid(output_source):
		outcome_title.text = output_caption.text if is_instance_valid(output_caption) else ""
		outcome_value.text = output_source.text
	for entry: Array in mirrors:
		if entry[0] is OptionButton:
			(entry[1] as OptionButton).select((entry[0] as OptionButton).selected)
			(entry[1] as OptionButton).tooltip_text = (entry[0] as OptionButton).get_item_text((entry[0] as OptionButton).selected)
		elif entry[0].has_meta("gas_mixture"):
			var gas: Vector2 = entry[0].get_meta("gas_mixture")
			var current: Dictionary = host.breathing_view.parameters()
			(entry[1] as BaseButton).toggle_mode = true
			(entry[1] as BaseButton).set_pressed_no_signal(absf(float(current["oxygen"]) - gas.x) < 0.001 and absf(float(current["helium"]) - gas.y) < 0.001)
		elif (entry[0] as BaseButton).toggle_mode:
			(entry[1] as BaseButton).set_pressed_no_signal((entry[0] as BaseButton).button_pressed)

func clear_children(node: Node) -> void:
	for child: Node in node.get_children(): node.remove_child(child); child.queue_free()

func top(node: Control, owner: Control) -> Control:
	var current: Control = node
	while current.get_parent() != owner and current.get_parent() is Control: current = current.get_parent()
	return current

func notes(owner: Control, entries: Array) -> void:
	for node: Control in entries:
		if is_instance_valid(node) and not note_nodes.has(node): note_nodes.append(node)

func instrument(key: String, input: HSlider, shape: String, caption: String, suffix: String) -> void:
	var widget := BathysLessonInstrument.new()
	widget.bind(input, shape, caption, suffix)
	if key == "range" and host.lesson == "colour": range_dock.add_child(widget)
	else: instruments.add_child(widget)
	widgets[key] = widget

func mixture(o2: HSlider, he: HSlider) -> void:
	var tank := BathysLessonGasMixture.new()
	tank.bind(o2, he)
	instruments.add_child(tank)
	widgets["mixture"] = tank

func extra_parameters(inputs: Dictionary, keys: Array) -> void:
	var styles: Dictionary = {
		"temperature": ["temperature", "Temperature", "°C", "lesson-thermometer"],
		"depth": ["depth", "Depth", "m", "buoyancy-diver"],
		"exposure_depth": ["depth", "Exposure depth", "m", "buoyancy-diver"],
		"exposure_time": ["clock", "Exposure time", "min", "event-clock"],
		"wait": ["clock", "Wait", "min", "event-clock"],
		"time": ["clock", "Time", "", "event-clock"],
		"volume": ["amount", "Volume", "L", "law-ideal_gas"],
		"range": ["distance", "Viewing distance", "m", "lesson-eye"],
		"distance": ["distance", "Object distance", "m", "lesson-eye"],
		"height": ["length", "Object height", "m", "lesson-ruler"],
		"gap": ["length", "Air gap", "mm", "lesson-ruler"],
		"thickness": ["length", "Barrier thickness", "×", "lesson-ruler"],
		"glass_index": ["wave", "Window index", "", "law-snell"],
		"area": ["length", "Exchange area", "×", "law-fick"],
		"permeability": ["flow", "Permeability", "×", "law-fick"],
		"capacity": ["amount", "Gas storage", "×", "cylinder"],
		"power": ["light", "Torch strength", "×", "lesson-torch"],
		"exposure": ["light", "Exposure", "EV", "lesson-eye"],
		"probe": ["wave", "Wavelength", "nm", "law-colour"],
		"g": ["flow", "Forward bias", "", "law-colour"],
		"diffuse": ["light", "Diffuse light", "", "law-colour"],
		"cone": ["length", "Halo acceptance", "°", "law-snell"],
		"pressure": ["gauge", "Pressure", "bar", "law-boyle"]}
	for key: String in keys:
		if not inputs.has(key): continue
		var style: Array = styles.get(key, ["gauge", key.capitalize(), "", "settings"])
		if key == "thickness" and host.lesson == "snell": style = ["length", "Window thickness", "mm", "lesson-ruler"]
		if not widgets.has(key): instrument(key, inputs[key], style[0], style[1], style[2])

func picker(source: OptionButton, minimum_width: float = 144) -> void:
	var copy := OptionButton.new()
	copy.custom_minimum_size.x = minimum_width
	copy.fit_to_longest_item = false
	copy.clip_text = true
	var short_names: Dictionary = {"Solve pressure · rigid volume": "Fixed volume", "Solve volume · fixed pressure": "Fixed pressure", "Real-gas throttle · h constant": "Real throttle", "Ideal-gas throttle · h constant": "Ideal throttle", "Ideal expansion with work · s constant": "Work expansion"}
	for i: int in source.item_count:
		var label: String = source.get_item_text(i)
		copy.add_item(short_names.get(label, label))
	copy.select(source.selected)
	copy.item_selected.connect(func(index: int) -> void: source.select(index); source.item_selected.emit(index))
	actions.add_child(copy)
	mirrors.append([source, copy])

func action(source: BaseButton, caption: String = "") -> void:
	var button := Button.new()
	button.text = source.text if caption.is_empty() else caption
	button.toggle_mode = source.toggle_mode
	button.set_pressed_no_signal(source.button_pressed)
	if source is CheckBox:
		button.toggled.connect(func(value: bool) -> void: source.button_pressed = value)
	else: button.pressed.connect(func() -> void: source.pressed.emit())
	actions.add_child(button)
	mirrors.append([source, button])

func presets(row: Control, captions: Array = []) -> void:
	for i: int in row.get_child_count():
		if row.get_child(i) is BaseButton: action(row.get_child(i), str(captions[i]) if i < captions.size() else "")

func output(readout_values: Array, index: int) -> void:
	output_source = readout_values[index]
	var stack: Control = output_source.get_parent()
	output_caption = stack.get_child(0) if stack.get_child_count() > 1 else null

func sync() -> void:
	if not is_instance_valid(host) or not is_instance_valid(toolbar): return
	clear_children(instruments)
	clear_children(range_dock)
	clear_children(actions)
	widgets.clear()
	mirrors.clear()
	control_nodes.clear()
	note_nodes.clear()
	output_source = null
	output_caption = null
	graph_available = true
	var key: String = host.lesson
	var owner: Control = body
	if key in ["boyle", "snell", "dalton", "henry", "density"] and not (key == "snell" and host.snell_mask):
		diagram = host.diagram
		control_nodes.append(host.standard_sections[1])
		notes(owner, [host.readouts, host.formula_label, host.insight_label.get_parent().get_parent(), host.assumptions_label])
		match key:
			"boyle": hint.text = "Drag the bubble ↕"
			"snell":
				hint.text = "Drag the light source"
				graph_available = false
				picker(host.direction_picker)
				action(host.critical_button, "Critical angle")
			"dalton":
				hint.text = "Drag the O₂ or He bar"
				graph_available = false
				instrument("depth", host.slider, "depth", "Depth", "m")
				mixture(host.extra_sliders["oxygen"], host.extra_sliders["helium"])
			"henry":
				hint.text = "Turn pressure; scrub the clock"
				instrument("pressure", host.slider, "gauge", "Pressure", "bar")
				instrument("time", host.extra_sliders["time"], "clock", "Time", "t½")
			"density":
				hint.text = "Warm the water; add salt"
				instrument("temperature", host.slider, "temperature", "Temperature", "°C")
				instrument("salinity", host.extra_sliders["salinity"], "salt", "Salt", "g/kg")
	elif key in BathysTransportLessons.KINDS:
		var view: BathysTransportLessons = host.transport_view
		owner = view
		diagram = view.diagram
		control_nodes.append(view.control_bank)
		notes(owner, [view.formula, view.explanation, view.assumptions, view.source_links])
		var p: Dictionary = view.parameters()
		hint.text = {"viscosity": "Drag the plate or its gap", "flow": "Drag the tube edges or flow arrow", "heat_transfer": "Change the layer, flow or surface finish", "thermal_properties": "Give both samples the same energy", "sound": "Drag the source or explore the chart"}[key]
		if key == "sound" and int(p["stage"]) == 0: hint.text = "Drag the diver to change distance"
		for spec: Array in view.instruments(): instrument(spec[0], view.inputs[spec[0]], spec[1], spec[2], spec[3])
		if key in ["viscosity", "flow"] or key == "heat_transfer" and int(p["stage"]) != 2: picker(view.medium_picker)
		elif key == "thermal_properties":
			picker(view.material_picker)
			if int(p["stage"]) == 0: picker(view.basis_picker, 300)
		elif key == "sound" and int(p["stage"]) == 1: picker(view.boundary_picker)
		if view.uses_mixture(): mixture(view.inputs["oxygen"], view.inputs["helium"])
	elif key in BathysThermalLessons.KINDS:
		var view: BathysThermalLessons = host.thermal_view
		owner = view
		diagram = view.diagram
		control_nodes.append(top(view.inputs["temperature"], owner))
		notes(owner, [view.readouts, view.formula, view.insight.get_parent().get_parent(), view.assumptions])
		instrument("temperature", view.inputs["temperature"], "temperature", "Temperature", "°C")
		if key == "ideal_gas": extra_parameters(view.inputs, ["volume" if int(view.parameters().get("solve", 0)) == 0 else "pressure"])
		match key:
			"charles": hint.text = "Drag the mercury or piston"
			"ideal_gas":
				hint.text = "Resize the vessel; heat the gas"
				picker(view.solve_picker)
				instrument("amount", view.inputs["amount"], "amount", "Gas amount", "mol")
			"real_gas":
				hint.text = "Turn pressure; compare the volumes"
				picker(view.gas_picker)
				instrument("pressure", view.inputs["pressure"], "gauge", "Pressure", "bar")
			"joule_thomson":
				hint.text = "Change inlet and outlet pressure"
				picker(view.process_picker)
				picker(view.gas_picker)
				instrument("inlet", view.inputs["inlet"], "gauge", "Inlet", "bar")
				instrument("outlet", view.inputs["outlet"], "gauge", "Outlet", "bar")
	elif key in ["oxygen", "narcosis", "gas_density"]:
		var view: BathysBreathingLessons = host.breathing_view
		owner = view
		diagram = view.diagram
		control_nodes.append(top(view.inputs["depth"], owner))
		notes(owner, [view.readouts, view.formula, view.insight.get_parent().get_parent(), view.assumptions])
		if key == "narcosis":
			hint.text = "Drag the actual depth marker"
			mixture(view.inputs["oxygen"], view.inputs["helium"])
			picker(view.convention)
		else:
			instrument("depth", view.inputs["depth"], "depth", "Depth", "m")
			if key == "gas_density":
				hint.text = "Compare a litre; change depth or heat"
				instrument("temperature", view.inputs["temperature"], "temperature", "Temperature", "°C")
				presets(view.preset_rows[key])
				mixture(view.inputs["oxygen"], view.inputs["helium"])
			else:
				hint.text = "Change depth, oxygen and time"
				mixture(view.inputs["oxygen"], view.inputs["helium"])
				instrument("time", view.inputs["time"], "clock", "Time", "min")
				output(view.numbers, 0)
	elif key == "buoyancy":
		var view: BathysBuoyancyLesson = host.buoyancy_view
		owner = view
		diagram = view.diagram
		control_nodes.append(top(view.inputs["mass"], owner))
		notes(owner, [view.readouts, view.formula, view.insight.get_parent().get_parent(), view.assumptions])
		if not view.at_depth: notes(owner, [view.cylinder_sources])
		hint.text = "Drag the diver ↕" if view.at_depth else ("Lift the base, then release · change pressure" if view.cylinder_preset_index >= 0 else "Drag the body through the surface")
		instrument("mass", view.inputs["mass"], "gauge", "Mass", "kg")
		instrument("volume", view.inputs["volume"], "amount", "Volume", "L")
		if not view.at_depth and view.cylinder_preset_index >= 0: instrument("pressure", view.inputs["pressure"], "pressure", "Cylinder pressure", "bar")
		if view.at_depth: instrument("gas", view.inputs["gas"], "amount", "Trapped gas", "L")
		if view.at_depth: action(view.balance_button, "Balance here")
		for i: int in 2: action(view.water_buttons[i], "Fresh water" if i == 0 else "Sea water")
		output(view.numbers, 3)
	elif key == "buhlmann":
		var view: BathysBuhlmannLesson = host.buhlmann_view
		owner = view
		diagram = view.diagram
		control_nodes.append(top(view.inputs["exposure_depth"], owner))
		control_nodes.append(view.compartment_picker.get_parent())
		notes(owner, [view.readouts, view.formula, view.status_label.get_parent().get_parent(), view.assumptions, view.summary_label])
		hint.text = "Select a tissue; change exposure"
		instrument("depth", view.inputs["preview_depth" if view.ascent else "exposure_depth"], "depth", "Depth", "m")
		if view.ascent:
			instrument("low", view.inputs["low"], "gauge", "GF Low", "%")
			instrument("high", view.inputs["high"], "gauge", "GF High", "%")
		else: instrument("time", view.inputs["exposure_time"], "clock", "Time", "min")
		extra_parameters(view.inputs, ["exposure_depth", "exposure_time", "wait"] if view.ascent else [])
		output(view.readout_values, 1)
	elif key == "fick":
		var view: BathysExchangeLesson = host.exchange_view
		owner = view
		diagram = view.diagram
		control_nodes.append(top(view.inputs["source"], owner))
		notes(owner, [view.readouts, view.formula, view.insight.get_parent().get_parent(), view.assumptions])
		hint.text = "Stretch the exchange area or barrier"
		instrument("source", view.inputs["source"], "gauge", "Source", "mmHg")
		instrument("initial", view.inputs["initial"], "gauge", "Start", "mmHg")
		instrument("time", view.inputs["time"], "clock", "Time", "τ₀")
		extra_parameters(view.inputs, ["area", "thickness", "permeability", "capacity"] if view.context == "tissues" else ["area", "thickness", "permeability"])
		presets(view.preset_rows[view.context], ["O₂", "CO₂"] if view.context == "lungs" else ["O₂", "CO₂", "Uptake", "Release"])
		output(view.numbers, 1)
	elif key == "colour":
		var view: BathysOpticsLesson = host.optics_view
		owner = view
		diagram = view.plots
		control_nodes.append(top(view.inputs["depth"], owner))
		notes(owner, [view.readouts, view.formula, view.status.get_parent().get_parent(), view.assumptions])
		if view.stage == 1: note_nodes.append(view.phase_info)
		# Source links are the final flow row; retain all of them in the explanation view.
		for child: Node in view.get_children():
			if child is HFlowContainer and child.get_child_count() > 0 and child.get_child(0) is LinkButton: note_nodes.append(child)
		match view.stage:
			0:
				hint.text = "Drag the target through the water"
				graph_available = false
				action(view.torch_switch, "Torch")
				extra_parameters(view.inputs, ["exposure", "power"])
			1:
				hint.text = "Touch a wavelength"
				instrument("g", view.inputs["g"], "gauge", "Forward bias", "")
				extra_parameters(view.inputs, ["probe", "diffuse", "cone"])
			2:
				hint.text = "Drag the range marker"
				instrument("range", view.inputs["range"], "distance", "Viewing distance", "m")
				instrument("depth", view.inputs["depth"], "depth", "Depth", "m")
	else: # Mask stage of Snell.
		var view: BathysMaskLesson = host.mask_view
		owner = view
		diagram = view.diagram
		control_nodes.append(top(view.inputs["distance"], owner))
		notes(owner, [view.readouts, view.insight.get_parent().get_parent(), view.assumptions])
		for child: Node in view.get_children():
			if child is Label and child != view.assumptions: note_nodes.append(child)
		hint.text = "Drag the target ↔"
		extra_parameters(view.inputs, ["height", "gap", "thickness", "glass_index"])
		output(view.numbers, 2)
	active_owner = owner
	if range_dock.get_parent() != owner: range_dock.reparent(owner)
	owner.move_child(range_dock, diagram.get_index())
	for node: Control in [actions, instruments, outcome]:
		if node.get_parent() != owner: node.reparent(owner)
		owner.move_child(node, diagram.get_index() + 1 + [actions, instruments, outcome].find(node))
	chart_button.tooltip_text = "Show linked chart"
	if key == "snell" and host.snell_mask: chart_button.tooltip_text = "Show ray paths"
	elif key == "density": chart_button.tooltip_text = "Compare water columns"
	elif key == "buoyancy" and not host.buoyancy_view.at_depth: chart_button.tooltip_text = "Base angle / cylinder pressure" if host.buoyancy_view.cylinder_preset_index >= 0 else "Show displaced water"
	elif key == "colour": chart_button.tooltip_text = "Show scattering directions" if host.optics_view.stage == 1 else "Show signal budget"
	apply_visibility()

func apply_visibility() -> void:
	if not is_instance_valid(host) or not is_instance_valid(diagram): return
	host.intro_label.visible = note_button.button_pressed
	host.source_button.visible = note_button.button_pressed and host.lesson != "colour"
	chart_button.visible = graph_available
	if host.lesson == "colour" and host.optics_view.stage == 0:
		var view: BathysOpticsLesson = host.optics_view
		var compare: bool = view.size.x < 660 and not note_button.button_pressed
		view.preview_box.get_child(0).visible = not compare
		view.compare_handle.visible = compare
		view.preview_materials[1].set_shader_parameter("compare_split", view.compare_handle.split if compare else -1.0)
		var caption: Label = view.preview_box.get_child(1).get_child(0).get_child(0)
		caption.text = "Surface ↔ underwater" if compare else "Received light · synthetic target"
	if host.lesson == "colour" and host.optics_view.stage == 1 and widgets.has("g"):
		(widgets["g"] as Control).visible = true
		hint.text = "Turn the forward-bias dial" if chart_button.button_pressed else "Touch a wavelength"
	for node: Control in control_nodes: node.hide()
	for node: Control in note_nodes: node.visible = note_button.button_pressed
	if host.lesson == "charles":
		if instruments.get_parent() != diagram: instruments.reparent(diagram)
		var area: Rect2 = (diagram as BathysThermalDiagram).section(0)
		instruments.position = Vector2(minf(area.size.x - 100, area.size.x * 0.42 + 95), 100)
		instruments.size = Vector2(94, 148)
	elif instruments.get_parent() != active_owner:
		instruments.reparent(active_owner)
		active_owner.move_child(instruments, diagram.get_index() + 2)
	var any_instrument: bool = false
	for child: Control in instruments.get_children(): any_instrument = any_instrument or child.visible
	instruments.visible = any_instrument
	actions.visible = actions.get_child_count() > 0
	range_dock.visible = range_dock.get_child_count() > 0
	if host.lesson == "colour" and host.optics_view.stage == 0:
		for key: String in ["power"]:
			(widgets[key] as Control).visible = bool(host.optics_view.params["torch"])
	outcome.vertical = active_owner.size.x < 500
	var close_pair: bool = host.lesson == "buoyancy"
	outcome.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if close_pair else Control.SIZE_FILL
	outcome_title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if close_pair else Control.SIZE_EXPAND_FILL
	outcome_title.autowrap_mode = TextServer.AUTOWRAP_OFF if close_pair else TextServer.AUTOWRAP_WORD_SMART
	outcome.add_theme_constant_override("separation", 4 if close_pair and outcome.vertical else 12)
	outcome.visible = not note_button.button_pressed and is_instance_valid(output_source)
	if diagram.comparison_visible != chart_button.button_pressed:
		diagram.comparison_visible = chart_button.button_pressed
		diagram.adapt()
