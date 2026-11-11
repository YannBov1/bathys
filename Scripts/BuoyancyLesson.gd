class_name BathysBuoyancyLesson
extends VBoxContainer

var at_depth: bool = false
var seawater: bool = false
var experiments: Dictionary = {
	"object": {"mass": 75.0, "volume": 80.0, "immersion": 100.0, "gas": 6.0, "depth": 10.0},
	"depth": {"mass": 78.0, "volume": 75.0, "immersion": 100.0, "gas": 6.0, "depth": 10.0}}
var result: Dictionary = {}
var density: float = 998.2
var diagram: BathysBuoyancyDiagram
var stage_buttons: Array[Button] = []
var water_buttons: Array[Button] = []
var inputs: Dictionary = {}
var values: Dictionary = {}
var blocks: Dictionary = {}
var floating_button: Button
var balance_button: Button
var readouts: GridContainer
var numbers: Array[Label] = []
var insight: Label
var explanation: Label
var assumptions: Label
var formula: Label

func parameters() -> Dictionary:
	return experiments["depth" if at_depth else "object"] as Dictionary

func _ready() -> void:
	add_theme_constant_override("separation", 9)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var stages := HFlowContainer.new()
	add_child(stages)
	var group := ButtonGroup.new()
	for index: int in 2:
		var button := Button.new()
		button.text = ["1 · Displacement", "2 · Gas at depth"][index]
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(func() -> void: set_stage(index == 1))
		stages.add_child(button)
		stage_buttons.append(button)
	diagram = BathysBuoyancyDiagram.new()
	diagram.size_flags_vertical = Control.SIZE_EXPAND_FILL
	diagram.immersion_changed.connect(func(value: float) -> void: (inputs["immersion"] as HSlider).value = value)
	diagram.preview_depth_changed.connect(func(value: float) -> void: (inputs["depth"] as HSlider).value = value)
	add_child(diagram)
	var panel: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 10)
	add_child(panel)
	var controls := BathysUiStyle.column(panel, 4)
	add_slider(controls, "mass", "Total mass · kg", 0.1, 160, 0.001)
	add_slider(controls, "volume", "Rigid body volume · litres", 1, 120, 0.1)
	add_slider(controls, "immersion", "Volume below the surface", 0, 100, 0.01)
	add_slider(controls, "gas", "Trapped gas volume at the surface", 0, 15, 0.1)
	add_slider(controls, "depth", "Depth", 0, 40, 0.1)
	var waters := HFlowContainer.new()
	controls.add_child(waters)
	var water_group := ButtonGroup.new()
	for index: int in 2:
		var button := Button.new()
		button.text = ["Fresh water · 20°C", "Sea water · 20°C"][index]
		button.toggle_mode = true
		button.button_group = water_group
		button.pressed.connect(func() -> void: seawater = index == 1; refresh())
		waters.add_child(button)
		water_buttons.append(button)
	var actions := HFlowContainer.new()
	controls.add_child(actions)
	floating_button = Button.new()
	floating_button.text = "Find floating equilibrium"
	floating_button.tooltip_text = "Set the submerged fraction so displaced water weighs the same as the body"
	floating_button.pressed.connect(func() -> void:
		parameters()["immersion"] = float(parameters()["mass"]) / (density * float(parameters()["volume"]) / 1000) * 100
		refresh())
	actions.add_child(floating_button)
	balance_button = Button.new()
	balance_button.text = "Balance at this depth"
	balance_button.tooltip_text = "Set the teaching body's mass equal to its displaced water mass"
	balance_button.pressed.connect(func() -> void: parameters()["mass"] = float(result["displaced_mass"]); refresh())
	actions.add_child(balance_button)
	readouts = GridContainer.new()
	add_child(readouts)
	for caption: String in ["Displaced water · litres", "Buoyant force · N", "Weight · N", "Net vertical force · N"]:
		var card: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 8)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		readouts.add_child(card)
		var column := BathysUiStyle.column(card, 2)
		column.add_child(BathysUiStyle.wrapped(caption, 11))
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
	var info := BathysUiStyle.column(box, 5)
	insight = BathysUiStyle.wrapped("", 13, BathysUiStyle.TEXT)
	info.add_child(insight)
	explanation = BathysUiStyle.wrapped("", 12)
	info.add_child(explanation)
	assumptions = BathysUiStyle.wrapped("", 11)
	add_child(assumptions)
	resized.connect(adapt)
	get_node("/root/I18n").language_changed.connect(refresh)
	set_stage(false)

func add_slider(parent: Node, key: String, caption: String, minimum: float, maximum: float, step_size: float) -> void:
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
	row.add_child(value)
	values[key] = value
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step_size
	slider.custom_minimum_size.y = 23
	slider.tooltip_text = caption
	slider.name = "Buoyancy_" + key
	slider.value_changed.connect(func(number: float) -> void: parameters()[key] = number; refresh())
	block.add_child(slider)
	inputs[key] = slider

func set_stage(value: bool) -> void:
	at_depth = value
	for index: int in 2: stage_buttons[index].set_pressed_no_signal(index == (1 if at_depth else 0))
	for key: String in blocks: (blocks[key] as Control).visible = key in (["mass", "volume", "gas", "depth"] if at_depth else ["mass", "volume", "immersion"])
	floating_button.visible = not at_depth
	balance_button.visible = at_depth
	refresh()
	adapt()

func adapt() -> void:
	readouts.columns = 1 if size.x < 450 else (2 if size.x < 700 else 4)
	diagram.adapt()

func refresh() -> void:
	var params: Dictionary = parameters()
	density = float(BathysLearningModels.water_properties(20, 35 if seawater else 0)["density"])
	result = BathysLearningModels.buoyancy_at_depth(params["mass"], params["volume"], params["gas"], params["depth"], density) if at_depth else BathysLearningModels.buoyancy(params["mass"], params["volume"], params["immersion"], density)
	for key: String in inputs:
		(inputs[key] as HSlider).set_value_no_signal(params[key])
		(values[key] as Label).text = "%.3f kg" % params[key] if key == "mass" else ("%.2f%%" % params[key] if key == "immersion" else ("%.1f m" % params[key] if key == "depth" else "%.1f L" % params[key]))
	for index: int in 2: water_buttons[index].set_pressed_no_signal(index == (1 if seawater else 0))
	floating_button.disabled = float(params["mass"]) > density * float(params["volume"]) / 1000
	floating_button.tooltip_text = "This body is denser than water; partial immersion cannot balance its weight" if floating_button.disabled else "Set the submerged fraction so displaced water weighs the same as the body"
	diagram.at_depth = at_depth
	diagram.body_volume_l = params["volume"]
	diagram.mass_kg = params["mass"]
	diagram.immersion = params["immersion"]
	diagram.depth = params["depth"]
	diagram.surface_gas_l = params["gas"]
	diagram.water_density = density
	diagram.result = result
	diagram.queue_redraw()
	numbers[0].text = "%.2f" % float(result["displaced_l"])
	numbers[1].text = "%.1f" % float(result["buoyant_force"])
	numbers[2].text = "%.1f" % float(result["weight"])
	numbers[3].text = "%+.1f" % (0.0 if absf(float(result["net_force"])) < 0.05 else float(result["net_force"]))
	var tendency: String = "Balanced forces" if absf(float(result["net_force"])) < 0.05 else ("Tends to rise" if float(result["net_force"]) > 0 else "Tends to sink")
	insight.text = tr("%s · displaced water density: %.1f kg/m³") % [tr(tendency), density]
	formula.text = "Fᵦ = ρwater × g × Vdisplaced · W = m × g"
	if at_depth:
		explanation.text = "The rigid body keeps its volume, but the same trapped gas shrinks as pressure rises. Descend and buoyancy decreases; ascend and it increases. Balance at one depth, then move the depth slider without changing mass or adding gas."
		assumptions.text = "Teaching body, fully submerged: fixed rigid volume plus a flexible gas space at constant temperature; gas mass is neglected. Vgas = Vsurface / Pabsolute (surface = 1 bar). Pressure uses the selected uniform water density. No venting, inflation, suit compression, motion or real weighting advice."
	else:
		explanation.text = "Buoyancy equals the weight of displaced water, not the object's weight. Only the submerged volume counts. A floating body settles with buoyancy equal to weight; a fully submerged rigid body keeps the same buoyancy at any depth in uniform water."
		assumptions.text = "Schematic rigid body held at the selected immersion; forces indicate tendency, not simulated motion. Air buoyancy and surface tension are omitted. Fresh/sea water densities use the app’s EOS-80 approximation at 20°C; g = 9.80665 m/s². Forces are in newtons, not kilograms."
