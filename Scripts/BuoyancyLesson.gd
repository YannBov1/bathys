class_name BathysBuoyancyLesson
extends VBoxContainer

var at_depth: bool = false
var seawater: bool = false
var experiments: Dictionary = {
	"object": {"mass": 75.0, "volume": 80.0, "immersion": 100.0, "gas": 6.0, "depth": 10.0, "pressure": 200.0},
	"depth": {"mass": 78.0, "volume": 75.0, "immersion": 100.0, "gas": 6.0, "depth": 10.0, "pressure": 200.0}}
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
var settling: Tween
var cylinder_examples: VBoxContainer
var cylinder_buttons: Array[Button] = []
var cylinder_sources: HFlowContainer
var cylinder_preset_index: int = -1
var cylinder_presets_data: Array[Dictionary] = []
var cylinder_state: Dictionary = {}
var cylinder_trim: Dictionary = {}
const CYLINDER_LIMITS := "Cylinder examples use a 12 L internal capacity, air at 20°C and 200/50 bar gauge (1 bar surface reference). Body masses: Faber 13.3 kg steel and Luxfer P3080V 16.5 kg aluminium; add an illustrative 0.6 kg brass valve. External volume is estimated from internal capacity plus metal volume, using 7.85/2.70 kg/L for steel/aluminium and 8.4 kg/L for brass. Gas mass uses the app’s real-gas model. Shell expansion, regulators and rigging are omitted. The cylinder remains fully submerged and supported; the displayed net force excludes the support reaction. Actual cylinder designs and attachment positions differ."
const CYLINDER_TRIM_LIMITS := "Illustrative sidemount axial model: body and gas act at half the body length; the valve acts 3 cm ahead of the neck; support is 7 cm behind the neck. The buoyancy centre includes the valve volume. Length is 0.612 m for the Luxfer reference and an assumed 0.65 m for steel. A weak elastic restoring moment uses k = 3 N m. The attitude relaxes towards atan(τ₀/k); angles and animation speed are schematic, not measured rigging predictions. Real shell mass distribution, regulators, rear clips, bungees, buoyancy centres, drag and attachment geometry can change the result. Gas is distributed throughout the cylinder, not pooled at the top. Water density uses EOS-80 at 20°C; g = 9.80665 m/s²."


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
	cylinder_examples = VBoxContainer.new()
	add_child(cylinder_examples)
	cylinder_examples.add_child(BathysUiStyle.wrapped("12 L inside · displaced volume includes the shell", 12, BathysUiStyle.AQUA))
	var presets := GridContainer.new()
	presets.columns = 2
	cylinder_examples.add_child(presets)
	for index: int in 4:
		cylinder_presets_data.append(BathysLearningModels.cylinder_buoyancy_preset(index))
		var button := Button.new()
		button.text = ["Steel · 200 bar", "Steel · 50 bar", "Aluminium · 200 bar", "Aluminium · 50 bar"][index]
		button.icon = preload("res://Assets/Icons/cylinder.svg")
		button.add_theme_constant_override("icon_max_width", 18)
		button.custom_minimum_size.y = 36
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.pressed.connect(func() -> void: apply_cylinder_preset(index))
		presets.add_child(button)
		cylinder_buttons.append(button)
	diagram = BathysBuoyancyDiagram.new()
	diagram.size_flags_vertical = Control.SIZE_EXPAND_FILL
	diagram.immersion_changed.connect(func(value: float) -> void: (inputs["immersion"] as HSlider).value = value)
	diagram.cylinder_pressure_changed.connect(set_cylinder_pressure)
	diagram.preview_depth_changed.connect(func(value: float) -> void: (inputs["depth"] as HSlider).value = value)
	diagram.grabbed.connect(stop_settling)
	diagram.released.connect(settle_body)
	add_child(diagram)
	var panel: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 10)
	add_child(panel)
	var controls := BathysUiStyle.column(panel, 4)
	add_slider(controls, "mass", "Total mass · kg", 0.1, 160, 0.001)
	add_slider(controls, "volume", "Rigid body volume · litres", 1, 120, 0.1)
	add_slider(controls, "immersion", "Volume below the surface", 0, 100, 0.01)
	add_slider(controls, "gas", "Trapped gas volume at the surface", 0, 15, 0.1)
	add_slider(controls, "depth", "Depth", 0, 40, 0.1)
	add_slider(controls, "pressure", "Cylinder pressure", 0, 200, 1)
	var waters := HFlowContainer.new()
	controls.add_child(waters)
	var water_group := ButtonGroup.new()
	for index: int in 2:
		var button := Button.new()
		button.text = ["Fresh water · 20°C", "Sea water · 20°C"][index]
		button.toggle_mode = true
		button.button_group = water_group
		button.pressed.connect(func() -> void: stop_settling(); seawater = index == 1; refresh())
		waters.add_child(button)
		water_buttons.append(button)
	var actions := HFlowContainer.new()
	controls.add_child(actions)
	floating_button = Button.new()
	floating_button.text = "Find floating equilibrium"
	floating_button.tooltip_text = "Set the submerged fraction so displaced water weighs the same as the body"
	floating_button.pressed.connect(func() -> void:
		stop_settling()
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
	cylinder_sources = HFlowContainer.new()
	add_child(cylinder_sources)
	for source: Array in [["Steel cylinder data ↗", "https://faber-italy.com/wp-content/uploads/2023/04/Press-Release-Faber-new-scuba-design_eng-1.pdf"], ["Aluminium cylinder data ↗", "https://luxfercylinders.com/wp-content/uploads/2023/10/LUXFER-SCUBA-SPEC-SHEET-2022.pdf"], ["Rotation & equilibrium ↗", "https://openstax.org/books/university-physics-volume-1/pages/12-1-conditions-for-static-equilibrium"]]:
		var link := LinkButton.new()
		link.text = source[0]
		link.pressed.connect(func() -> void: OS.shell_open(source[1]))
		cylinder_sources.add_child(link)
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
	slider.value_changed.connect(func(number: float) -> void:
		stop_settling()
		if key == "pressure":
			set_cylinder_pressure(number)
			return
		if not at_depth and key in ["mass", "volume"]: cylinder_preset_index = -1
		parameters()[key] = number
		refresh()
		if key in ["mass", "volume"] and not at_depth: settle_body())
	block.add_child(slider)
	inputs[key] = slider
	if key == "immersion":
		slider.drag_started.connect(stop_settling)
		slider.drag_ended.connect(func(_changed: bool) -> void: settle_body())

func set_stage(value: bool) -> void:
	stop_settling()
	at_depth = value
	cylinder_examples.visible = not at_depth
	cylinder_sources.visible = not at_depth
	for index: int in 2: stage_buttons[index].set_pressed_no_signal(index == (1 if at_depth else 0))
	for key: String in blocks: (blocks[key] as Control).visible = key in (["mass", "volume", "gas", "depth"] if at_depth else ["mass", "volume", "immersion"])
	floating_button.visible = not at_depth
	balance_button.visible = at_depth
	refresh()
	adapt()

func apply_cylinder_preset(index: int) -> void:
	if index < 0 or index >= 4: return
	stop_settling()
	cylinder_preset_index = index
	var preset: Dictionary = cylinder_presets_data[index]
	experiments["object"]["mass"] = preset["mass"]
	experiments["object"]["volume"] = preset["volume"]
	experiments["object"]["immersion"] = 100.0
	experiments["object"]["pressure"] = preset["pressure"]
	cylinder_state = preset
	diagram.cylinder_tilt_deg = 0
	diagram.cylinder_keyboard_hold = false
	diagram.dragging = false
	refresh()
	diagram.adapt()

func set_cylinder_pressure(pressure: float) -> void:
	if cylinder_preset_index < 0 or at_depth: return
	cylinder_state = BathysLearningModels.cylinder_buoyancy_state(cylinder_preset_index < 2, roundf(pressure))
	experiments["object"]["pressure"] = cylinder_state["pressure"]
	experiments["object"]["mass"] = cylinder_state["mass"]
	experiments["object"]["volume"] = cylinder_state["volume"]
	experiments["object"]["immersion"] = 100.0
	refresh()

func stop_settling() -> void:
	if is_instance_valid(settling): settling.kill()

func settle_body() -> void:
	if at_depth or cylinder_preset_index >= 0 or not is_visible_in_tree(): return
	stop_settling()
	var target: float = clampf(float(parameters()["mass"]) / (density * float(parameters()["volume"]) / 1000) * 100, 0, 100)
	# A damped visual relaxation toward force balance, not a hydrodynamic solver.
	settling = create_tween()
	settling.tween_method(func(value: float) -> void: parameters()["immersion"] = value; refresh(), float(parameters()["immersion"]), target, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func adapt() -> void:
	readouts.columns = 1 if size.x < 450 else (2 if size.x < 700 else 4)
	diagram.adapt()

func refresh() -> void:
	var params: Dictionary = parameters()
	for index: int in cylinder_buttons.size():
		cylinder_buttons[index].set_pressed_no_signal(cylinder_preset_index >= 0 and (index < 2) == (cylinder_preset_index < 2) and is_equal_approx(float(cylinder_presets_data[index]["pressure"]), float(experiments["object"]["pressure"])))
		var preset: Dictionary = cylinder_presets_data[index]
		cylinder_buttons[index].tooltip_text = tr("12 L cylinder · %.2f kg total · %.2f L external · air %.2f kg") % [preset["mass"], preset["volume"], preset["gas_mass"]]
	density = float(BathysLearningModels.water_properties(20, 35 if seawater else 0)["density"])
	result = BathysLearningModels.buoyancy_at_depth(params["mass"], params["volume"], params["gas"], params["depth"], density) if at_depth else BathysLearningModels.buoyancy(params["mass"], params["volume"], params["immersion"], density)
	for key: String in inputs:
		(inputs[key] as HSlider).set_value_no_signal(params[key])
		(values[key] as Label).text = "%.0f bar" % params[key] if key == "pressure" else "%.3f kg" % params[key] if key == "mass" else ("%.2f%%" % params[key] if key == "immersion" else ("%.1f m" % params[key] if key == "depth" else "%.1f L" % params[key]))
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
	var previous_mode: bool = diagram.cylinder_mode
	diagram.cylinder_mode = cylinder_preset_index >= 0 and not at_depth
	diagram.cylinder_pressure = int(params["pressure"]) if diagram.cylinder_mode else 0
	if diagram.cylinder_mode:
		cylinder_trim = BathysLearningModels.cylinder_trim(cylinder_state, density)
		diagram.cylinder_state = cylinder_state
		diagram.cylinder_balance = cylinder_trim
	diagram.cylinder_steel = cylinder_preset_index < 2
	if previous_mode != diagram.cylinder_mode: diagram.adapt()
	diagram.queue_redraw()
	numbers[0].text = "%.2f" % float(result["displaced_l"])
	numbers[1].text = "%.1f" % float(result["buoyant_force"])
	numbers[2].text = "%.1f" % float(result["weight"])
	numbers[3].text = "%+.1f" % (0.0 if absf(float(result["net_force"])) < 0.05 else float(result["net_force"]))
	var tendency: String = "Balanced forces" if absf(float(result["net_force"])) < 0.05 else ("Tends to rise" if float(result["net_force"]) > 0 else "Tends to sink")
	insight.text = tr("%s · displaced water density: %.1f kg/m³") % [tr(tendency), density]
	formula.text = "Fᵦ = ρwater × g × Vdisplaced\n\nW = m × g"
	if at_depth:
		explanation.text = "The rigid body keeps its volume, but the same trapped gas shrinks as pressure rises. Descend and buoyancy decreases; ascend and it increases. Balance at one depth, then drag the diver without changing mass or adding gas."
		assumptions.text = "Teaching body, fully submerged: fixed rigid volume plus a flexible gas space at constant temperature; gas mass is neglected. Vgas = Vsurface / Pabsolute (surface = 1 bar). Pressure uses the selected uniform water density. No venting, inflation, suit compression, motion or real weighting advice."
	else:
		explanation.text = "Buoyancy equals the weight of displaced water, not the object's weight. Only the submerged volume counts. A floating body settles with buoyancy equal to weight; a fully submerged rigid body keeps the same buoyancy at any depth in uniform water."
		assumptions.text = "Schematic rigid body held at the selected immersion; release eases toward floating balance (or full immersion for a sinking body), using a visual relaxation rather than simulated fluid motion. Air buoyancy and surface tension are omitted. Fresh/sea water densities use the app’s EOS-80 approximation at 20°C; g = 9.80665 m/s². Forces are in newtons, not kilograms."
		if cylinder_preset_index >= 0:
			formula.text = "Fᵦ = ρwater × g × Vdisplaced\n\nFnet = Fᵦ − W\n\nτ₀ = Fᵦ(xB − xP) − W(xG − xP)\n\nτ(θ) = τ₀ cos θ − k sin θ"
			explanation.text = "Total lift and rotation are different. Buoyancy acts at the centre of displaced volume; weight acts at the centre of mass. A heavy valve shifts the centre of mass towards the neck. About the support, the base can tend to rise even while the whole cylinder is still negative. Change pressure, or lift the base and release it."
			assumptions.text = tr(CYLINDER_LIMITS) + "\n\n" + tr(CYLINDER_TRIM_LIMITS)
