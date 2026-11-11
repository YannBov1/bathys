class_name BathysBuhlmannLesson
extends VBoxContainer

var ascent: bool = false
var exposure_depth: float = 30.0
var exposure_minutes: float = 30.0
var preview_depth: float = 9.0
var wait_minutes: float = 0.0
var gf_low: float = 30.0
var gf_high: float = 85.0
var selected: int = 0
var state: Dictionary = {}
var profile: BathysBuhlmannProfile
var diagram: BathysBuhlmannDiagram
var stage_buttons: Array[Button] = []
var compartment_picker: OptionButton
var summary_label: Label
var status_label: Label
var explanation: Label
var assumptions: Label
var formula: Label
var loading_controls: VBoxContainer
var ascent_controls: VBoxContainer
var inputs: Dictionary = {}
var values: Dictionary = {}
var readouts: GridContainer
var readout_titles: Array[Label] = []
var readout_values: Array[Label] = []

func _ready() -> void:
	add_theme_constant_override("separation", 9)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var stages := HFlowContainer.new()
	add_child(stages)
	var group := ButtonGroup.new()
	for index: int in 2:
		var button := Button.new()
		button.text = ["1 · Load tissues", "2 · Explore ascent"][index]
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(func() -> void: set_stage(index == 1))
		stages.add_child(button)
		stage_buttons.append(button)
	var inspect_row := HBoxContainer.new()
	add_child(inspect_row)
	var caption: Label = BathysUiStyle.wrapped("Inspect a compartment", 12, BathysUiStyle.TEXT)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspect_row.add_child(caption)
	compartment_picker = OptionButton.new()
	compartment_picker.name = "BuhlmannCompartment"
	compartment_picker.item_selected.connect(select_compartment)
	inspect_row.add_child(compartment_picker)
	for i: int in 16: compartment_picker.add_item("")
	summary_label = BathysUiStyle.wrapped("", 12)
	add_child(summary_label)
	profile = BathysBuhlmannProfile.new()
	profile.parameter_changed.connect(func(key: String, value: float) -> void: (inputs[key] as HSlider).value = value)
	add_child(profile)
	diagram = BathysBuhlmannDiagram.new()
	diagram.size_flags_vertical = Control.SIZE_EXPAND_FILL
	diagram.compartment_selected.connect(select_compartment)
	diagram.exposure_time_changed.connect(func(value: float) -> void: (inputs["exposure_time"] as HSlider).value = value)
	diagram.preview_depth_changed.connect(func(value: float) -> void: (inputs["preview_depth"] as HSlider).value = value)
	add_child(diagram)
	var panel: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 10)
	add_child(panel)
	var controls := BathysUiStyle.column(panel, 5)
	loading_controls = BathysUiStyle.column(controls, 4)
	add_slider(loading_controls, "exposure_depth", "Exposure depth", 0, 40, 0.1, func(value: float) -> void: exposure_depth = value; refresh())
	add_slider(loading_controls, "exposure_time", "Time at exposure depth", 0, 120, 0.1, func(value: float) -> void: exposure_minutes = value; refresh())
	var presets := HFlowContainer.new()
	loading_controls.add_child(presets)
	for entry: Array in [["Short exposure · 10 min", 10.0], ["Long exposure · 60 min", 60.0]]:
		var button := Button.new()
		button.text = str(entry[0])
		button.pressed.connect(func() -> void: exposure_minutes = float(entry[1]); refresh())
		presets.add_child(button)
	ascent_controls = BathysUiStyle.column(controls, 4)
	add_slider(ascent_controls, "preview_depth", "Preview depth · instant pressure step", 0, 40, 0.1, func(value: float) -> void: preview_depth = value; refresh())
	add_slider(ascent_controls, "wait", "Wait at preview depth", 0, 120, 0.1, func(value: float) -> void: wait_minutes = value; refresh())
	add_slider(ascent_controls, "low", "GF Low · deeper anchor", 1, 100, 1, func(value: float) -> void:
		gf_low = value
		gf_high = maxf(gf_high, value)
		refresh())
	add_slider(ascent_controls, "high", "GF High · surface", 1, 100, 1, func(value: float) -> void:
		gf_high = value
		gf_low = minf(gf_low, value)
		refresh())
	readouts = GridContainer.new()
	add_child(readouts)
	for i: int in 4:
		var card: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 8)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		readouts.add_child(card)
		var stack := BathysUiStyle.column(card, 2)
		var title: Label = BathysUiStyle.wrapped("", 11)
		stack.add_child(title)
		readout_titles.append(title)
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 20)
		value.add_theme_color_override("font_color", BathysUiStyle.AQUA)
		stack.add_child(value)
		readout_values.append(value)
	formula = BathysUiStyle.wrapped("", 14, BathysUiStyle.AQUA)
	formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(formula)
	var info: PanelContainer = BathysUiStyle.panel(Color("143c43"), 10)
	add_child(info)
	var text_stack := BathysUiStyle.column(info, 5)
	status_label = BathysUiStyle.wrapped("", 13, BathysUiStyle.TEXT)
	text_stack.add_child(status_label)
	explanation = BathysUiStyle.wrapped("", 12)
	text_stack.add_child(explanation)
	assumptions = BathysUiStyle.wrapped("", 11)
	add_child(assumptions)
	resized.connect(adapt)
	get_node("/root/I18n").language_changed.connect(refresh)
	set_stage(false)

func add_slider(parent: Node, key: String, caption: String, minimum: float, maximum: float, step_size: float, callback: Callable) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	parent.add_child(block)
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
	slider.name = "Buhlmann_" + key
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step_size
	slider.custom_minimum_size.y = 23
	slider.tooltip_text = caption
	slider.value_changed.connect(callback)
	block.add_child(slider)
	inputs[key] = slider

func set_stage(value: bool) -> void:
	ascent = value
	for i: int in 2: stage_buttons[i].set_pressed_no_signal(i == (1 if ascent else 0))
	loading_controls.visible = not ascent
	ascent_controls.visible = ascent
	readouts.get_child(3).visible = ascent
	refresh()
	adapt()

func select_compartment(index: int) -> void:
	selected = clampi(index, 0, 15)
	compartment_picker.select(selected)
	refresh()

func adapt() -> void:
	readouts.columns = 1 if size.x < 450 else (4 if ascent else 3)
	diagram.adapt()

func refresh() -> void:
	state = BathysBuhlmannLessonModel.snapshot(exposure_depth, exposure_minutes, preview_depth,
		wait_minutes, gf_low / 100, gf_high / 100, ascent)
	var model: BathysTissue = state["model"]
	for key: String in inputs:
		var value: float = {"exposure_depth": exposure_depth, "exposure_time": exposure_minutes,
			"preview_depth": preview_depth, "wait": wait_minutes, "low": gf_low, "high": gf_high}[key]
		(inputs[key] as HSlider).set_value_no_signal(value)
		(values[key] as Label).text = "%.0f%%" % value if key in ["low", "high"] else ("%.1f m" % value if key in ["exposure_depth", "preview_depth"] else "%.1f min" % value)
	for i: int in 16:
		compartment_picker.set_item_text(i, tr("%d · N₂ t½ %.1f min") % [i + 1, BathysTissue.N_HALF[i]])
	compartment_picker.select(selected)
	profile.exposure_depth = exposure_depth
	profile.exposure_minutes = exposure_minutes
	profile.preview_depth = preview_depth
	profile.wait_minutes = wait_minutes
	profile.ascent = ascent
	profile.queue_redraw()
	diagram.state = state
	diagram.selected = selected
	diagram.exposure_depth = exposure_depth
	diagram.exposure_minutes = exposure_minutes
	diagram.low = gf_low / 100
	diagram.high = gf_high / 100
	diagram.ascent = ascent
	diagram.queue_redraw()
	readout_values[2].add_theme_font_size_override("font_size", 20)
	if not ascent:
		summary_label.text = "Air exposure · all compartments start at surface equilibrium. Select fast and slow compartments to compare."
		readout_titles[0].text = "Selected N₂ half-time"
		readout_titles[1].text = "Selected tissue N₂"
		readout_titles[2].text = "Gap to equilibrium closed"
		readout_values[0].text = "%.1f min" % BathysTissue.N_HALF[selected]
		readout_values[1].text = "%.3f bar" % model.n2[selected]
		readout_values[2].text = "%.1f%%" % ((1 - pow(0.5, exposure_minutes / BathysTissue.N_HALF[selected])) * 100) if exposure_depth > 0 else "—"
		formula.text = "One half-time: 50%\n\ntwo: 75%\n\nthree: 87.5% of the pressure gap"
		status_label.text = "Fast compartments respond quickly; slow ones keep loading for much longer. Half-time describes closing half the remaining pressure gap, not reaching full saturation."
		explanation.text = "These are 16 mathematical compartments, not 16 organs. The amber line is inspired nitrogen pressure; each bar follows its own half-time. Next, explore ascent with this same gas loading."
		assumptions.text = "Model: app’s ZH-L16C nitrogen half-times and coefficients; air (79% N₂), water vapour 0.0627 bar, 1 bar at the surface, +1 bar/10 m. Instantaneous depth steps omit travel gas exchange. Independent of your scenario."
	else:
		summary_label.text = tr("Loaded at %.1f m for %.1f min · frozen GF Low anchor: %.1f m") % [exposure_depth, exposure_minutes, state["anchor_m"]]
		readout_titles[0].text = "Applied gradient factor"
		readout_titles[1].text = "Selected tissue N₂"
		readout_titles[2].text = "Snapshot ceiling"
		readout_titles[3].text = "Ceiling controller"
		readout_values[0].text = "%.1f%%" % (float(state["gf"]) * 100)
		readout_values[1].text = "%.3f bar" % model.n2[selected]
		readout_values[2].text = "%.1f m" % float(state["ceiling_m"])
		readout_values[3].text = tr("C%d") % int(state["controller"]) if int(state["controller"]) > 0 else "—"
		formula.text = "GF limit = ambient + GF × (M-value − ambient)"
		status_label.text = "Preview is shallower than the model ceiling: at least one compartment exceeds its GF limit." if preview_depth + 1e-8 < float(state["ceiling_m"]) else "Preview meets the snapshot GF limits. Waiting changes gas loading and can change the controlling compartment."
		explanation.text = "The M-value is a compartment’s baseline pressure limit at a given ambient pressure. GF scales the gap above ambient, not tissue gas or the probability of decompression sickness. GF Low applies at the deeper anchor; GF High at the surface. Waiting can unload fast compartments while slow ones still load."
		assumptions.text = "Pressure-step experiment, not an ascent schedule. The anchor is the initial GF Low ceiling rounded up to 3 m, with tissues frozen; it stays fixed while you preview depth and wait on air. GF interpolates from that anchor to the surface. M-values and GF limits are model boundaries, not guarantees against decompression sickness."
