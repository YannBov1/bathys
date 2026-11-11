class_name BathysOpticsLesson
extends VBoxContainer

var params: Dictionary = {"water": 2, "depth": 10.0, "range": 3.0, "torch": false,
	"power": 8.0, "baseline": 0.6, "g": 0.9, "diffuse": 0.7, "cone": 3.0, "probe": 550.0, "exposure": 0.0}
var engine := BathysUnderwaterOptics.new()
var stage: int = 0
var result: Dictionary = {}
var stage_buttons: Array[Button] = []
var water_picker: OptionButton
var component_picker: OptionButton
var torch_switch: CheckBox
var preview_box: BoxContainer
var compare_handle: BathysColourCompare
var preview_aspects: Array[AspectRatioContainer] = []
var preview_materials: Array[ShaderMaterial] = []
var plots: BathysOpticsPlots
var inputs: Dictionary = {}
var values: Dictionary = {}
var blocks: Dictionary = {}
var readouts: GridContainer
var titles: Array[Label] = []
var numbers: Array[Label] = []
var legend: HFlowContainer
var status: Label
var explanation: Label
var assumptions: Label
var formula: Label
var phase_info: Label
var examples: HFlowContainer
var dirty_time: float = -1
var curve_signature: String = ""

func _ready() -> void:
	add_theme_constant_override("separation", 9)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tabs := HFlowContainer.new()
	add_child(tabs)
	var group := ButtonGroup.new()
	for index: int in 3:
		var button := Button.new()
		button.text = ["Colour & light", "Water & scattering", "Why two coefficients?"][index]
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(set_stage.bind(index))
		tabs.add_child(button)
		stage_buttons.append(button)
	water_picker = OptionButton.new()
	water_picker.name = "OpticalWaterType"
	for label: String in ["Jerlov IB · clearer oceanic", "Jerlov II · oceanic", "Jerlov III · less clear oceanic", "Jerlov 1C · clearer coastal", "Jerlov 3C · coastal", "Jerlov 5C · less clear coastal"]: water_picker.add_item(label)
	water_picker.select(params["water"])
	water_picker.item_selected.connect(func(index: int) -> void: params["water"] = index; request_refresh())
	add_child(water_picker)
	preview_box = BoxContainer.new()
	preview_box.add_theme_constant_override("separation", 8)
	add_child(preview_box)
	for index: int in 2:
		var card: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 7)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview_box.add_child(card)
		var stack := BathysUiStyle.column(card, 4)
		stack.add_child(BathysUiStyle.wrapped("Surface reference · fixed D65" if index == 0 else "Received light · synthetic target", 12, BathysUiStyle.TEXT))
		var aspect := AspectRatioContainer.new()
		aspect.ratio = 2.2
		preview_aspects.append(aspect)
		aspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(aspect)
		var image := ColorRect.new()
		image.custom_minimum_size = Vector2(130, 65)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = preload("res://Shaders/OpticsTarget.gdshader")
		material.set_shader_parameter("reference", index == 0)
		image.material = material
		preview_materials.append(material)
		aspect.add_child(image)
		if index == 1:
			compare_handle = BathysColourCompare.new()
			compare_handle.material_target = material
			image.add_child(compare_handle)
			compare_handle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			compare_handle.hide()
	component_picker = OptionButton.new()
	component_picker.name = "OpticsComponent"
	for text: String in ["All received light · D + F + B", "Direct only · D", "Forward halo only · F", "Backscatter only · B", "Object signal without veil · D + F"]: component_picker.add_item(text)
	component_picker.item_selected.connect(func(index: int) -> void: preview_materials[1].set_shader_parameter("component", index))
	add_child(component_picker)
	plots = BathysOpticsPlots.new()
	plots.engine = engine
	plots.probe_changed.connect(func(value: float) -> void: (inputs["probe"] as HSlider).value = value)
	plots.depth_changed.connect(func(value: float) -> void: (inputs["depth"] as HSlider).value = value)
	plots.range_changed.connect(func(value: float) -> void: (inputs["range"] as HSlider).value = value)
	add_child(plots)
	legend = HFlowContainer.new()
	legend.add_theme_constant_override("h_separation", 16)
	legend.add_theme_constant_override("v_separation", 6)
	add_child(legend)
	var panel: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 10)
	add_child(panel)
	var controls := BathysUiStyle.column(panel, 4)
	add_slider(controls, "depth", "Depth below the surface", 0, 30, 0.1)
	add_slider(controls, "range", "Camera → target distance", 0.2, 15, 0.1)
	add_slider(controls, "exposure", "Display exposure · no white balance", -2, 4, 0.1)
	torch_switch = CheckBox.new()
	torch_switch.text = "Add a white torch"
	torch_switch.toggled.connect(func(value: bool) -> void: params["torch"] = value; update_visibility(); request_refresh())
	controls.add_child(torch_switch)
	add_slider(controls, "power", "Torch strength at 1 m · relative to surface daylight", 0, 20, 0.1)
	add_slider(controls, "baseline", "Torch offset from camera", 0, 1.5, 0.05)
	add_slider(controls, "probe", "Probe wavelength", 400, 700, 5)
	add_slider(controls, "g", "HG asymmetry g · chosen phase assumption", 0, 0.98, 0.01)
	add_slider(controls, "diffuse", "Diffuse share of ambient light · chosen assumption", 0, 1, 0.05)
	add_slider(controls, "cone", "Forward-halo acceptance half-angle · surrogate", 0.5, 10, 0.5)
	examples = HFlowContainer.new()
	controls.add_child(examples)
	for example: Array in [["Near in clearer water", 0, 5.0, 1.0, false], ["Far in coastal water", 4, 10.0, 8.0, false], ["Torch close to target", 2, 20.0, 1.5, true]]:
		var button := Button.new()
		button.text = str(example[0])
		button.pressed.connect(func() -> void:
			params["water"] = example[1]
			params["depth"] = example[2]
			params["range"] = example[3]
			params["torch"] = example[4]
			update_visibility()
			flush_update())
		examples.add_child(button)
	readouts = GridContainer.new()
	add_child(readouts)
	for i: int in 4:
		var card: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 8)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		readouts.add_child(card)
		var stack := BathysUiStyle.column(card, 2)
		var caption: Label = BathysUiStyle.wrapped("", 11)
		stack.add_child(caption)
		titles.append(caption)
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 20)
		value.add_theme_color_override("font_color", BathysUiStyle.AQUA)
		stack.add_child(value)
		numbers.append(value)
	phase_info = BathysUiStyle.wrapped("", 11)
	add_child(phase_info)
	formula = BathysUiStyle.wrapped("", 14, BathysUiStyle.AQUA)
	formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(formula)
	var info: PanelContainer = BathysUiStyle.panel(Color("143c43"), 10)
	add_child(info)
	var text := BathysUiStyle.column(info, 5)
	status = BathysUiStyle.wrapped("", 13, BathysUiStyle.TEXT)
	text.add_child(status)
	explanation = BathysUiStyle.wrapped("", 12)
	text.add_child(explanation)
	assumptions = BathysUiStyle.wrapped("", 11)
	add_child(assumptions)
	var references := HFlowContainer.new()
	add_child(references)
	for entry: Array in [["Revised image model ↗", "https://openaccess.thecvf.com/content_cvpr_2018/html/Akkaynak_A_Revised_Underwater_CVPR_2018_paper.html"], ["Measured-data IOPs ↗", "https://doi.org/10.1364/AO.470464"], ["Coefficient provenance ↗", "https://zenodo.org/records/23149627"]]:
		var link := LinkButton.new()
		link.text = str(entry[0])
		link.pressed.connect(func() -> void: OS.shell_open(str(entry[1])))
		references.add_child(link)
	resized.connect(adapt)
	get_node("/root/I18n").language_changed.connect(update_text)
	update_visibility()
	update_text()

func activate() -> void:
	flush_update()
	adapt()

func _process(delta: float) -> void:
	if dirty_time < 0 or not is_visible_in_tree(): return
	dirty_time -= delta
	if dirty_time <= 0: flush_update()

func add_slider(parent: Node, key: String, text: String, minimum: float, maximum: float, step_size: float) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	parent.add_child(block)
	blocks[key] = block
	var row := HBoxContainer.new()
	block.add_child(row)
	var caption: Label = BathysUiStyle.wrapped(text, 12, BathysUiStyle.TEXT)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var value := Label.new()
	value.add_theme_color_override("font_color", BathysUiStyle.AQUA)
	row.add_child(value)
	values[key] = value
	var input := HSlider.new()
	input.name = "Optics_" + key
	input.min_value = minimum
	input.max_value = maximum
	input.step = step_size
	input.custom_minimum_size.y = 23
	input.tooltip_text = text
	input.value_changed.connect(func(number: float) -> void: params[key] = number; request_refresh())
	block.add_child(input)
	inputs[key] = input

func request_refresh() -> void:
	if dirty_time < 0: dirty_time = 0.025
	update_control_values()

func set_stage(value: int) -> void:
	stage = clampi(value, 0, 2)
	update_visibility()
	flush_update()
	adapt()

func update_visibility() -> void:
	for i: int in 3: stage_buttons[i].set_pressed_no_signal(stage == i)
	preview_box.visible = stage == 0
	component_picker.visible = stage == 0
	torch_switch.visible = stage == 0
	examples.visible = stage == 0
	for key: String in blocks:
		(blocks[key] as Control).visible = key in (["depth", "range", "exposure"] if stage == 0 else (["probe", "g", "diffuse", "cone"] if stage == 1 else ["depth", "range"]))
	for key: String in ["power", "baseline"]: (blocks[key] as Control).visible = stage == 0 and bool(params["torch"])
	readouts.get_child(3).visible = stage == 1
	phase_info.visible = stage == 1
	legend.visible = stage != 0
	for child: Node in legend.get_children():
		legend.remove_child(child)
		child.queue_free()
	var entries: Array = [["Absorption a", BathysOpticsPlots.AMBER], ["Scattering b", BathysOpticsPlots.VIOLET], ["Beam c = a + b", BathysUiStyle.AQUA], ["Diffuse Kd", BathysUiStyle.MUTED]] if stage == 1 else [["White target · βD", Color.WHITE], ["Red target · βD", BathysOpticsPlots.RED], ["Backscatter · βB", BathysUiStyle.AQUA]]
	for entry: Array in entries:
		var caption := Label.new()
		caption.text = str(entry[0])
		caption.add_theme_font_size_override("font_size", 11)
		caption.add_theme_color_override("font_color", entry[1])
		legend.add_child(caption)
	plots.stage = stage
	plots.adapt()

func update_control_values() -> void:
	water_picker.select(params["water"])
	torch_switch.set_pressed_no_signal(params["torch"])
	for key: String in inputs:
		(inputs[key] as HSlider).set_value_no_signal(params[key])
		var number: float = params[key]
		(values[key] as Label).text = ("%.0f nm" % number if key == "probe" else ("%.1f°" % number if key == "cone" else ("%.1f m" % number if key in ["depth", "range", "baseline"] else ("%+.1f EV" % number if key == "exposure" else "%.2f" % number))))

func flush_update() -> void:
	dirty_time = -1
	update_control_values()
	var chosen: Dictionary = params.duplicate()
	if stage == 2: chosen["torch"] = false
	result = engine.evaluate(chosen)
	if stage == 0:
		for material: ShaderMaterial in preview_materials:
			material.set_shader_parameter("direct_colours", result["direct"])
			material.set_shader_parameter("forward_colours", result["forward"])
			material.set_shader_parameter("reference_colours", result["reference"])
			material.set_shader_parameter("backscatter", result["back"])
			material.set_shader_parameter("sigma", result["sigma"])
			material.set_shader_parameter("exposure", pow(2, params["exposure"]))
	plots.params = params
	plots.result = result
	if stage == 2:
		var signature: String = str([params["water"], params["depth"], params["g"], params["diffuse"]])
		if signature != curve_signature:
			curve_signature = signature
			plots.curves.clear()
			for i: int in 51:
				var value: Dictionary = engine.diagnostic(params, 0.2 + i * 14.8 / 50)
				plots.curves.append(Vector3(value["white"], value["red"], value["back"]))
	plots.queue_redraw()
	update_text()

func adapt() -> void:
	preview_box.vertical = size.x < 660
	var image_width: float = (size.x if preview_box.vertical else (size.x - 8) / 2) - 14
	for aspect: AspectRatioContainer in preview_aspects:
		aspect.custom_minimum_size.y = maxf(65, image_width / 2.2)
	readouts.columns = 1 if size.x < 450 else (4 if stage == 1 else 3)
	plots.adapt()

func update_text() -> void:
	if result.is_empty(): return
	if stage == 0:
		for i: int in 3: titles[i].text = ["Daylight Y remaining", "White-target direct transmission", "Veil share of white-target signal"][i]
		numbers[0].text = "%.1f%%" % (float(result["daylight_y"]) * 100)
		numbers[1].text = "%.1f%%" % (float(result["transmission_y"]) * 100)
		numbers[2].text = "%.1f%%" % (float(result["veil_share"]) * 100)
		formula.text = "Received = direct + forward halo + backscatter"
		status.text = "Depth changes the light reaching the target. Viewing distance adds another water path. Scattering can blur details and add a veil, even over a nearly black patch."
		explanation.text = "Explore the Jaffe–McGlamery decomposition with the component views. A nearby white torch can reveal colours missing from the ambient light, but it also illuminates particles. Move it off the camera axis and compare. Exposure brightens the remaining signal; it cannot recover absent wavelengths."
	elif stage == 1:
		var profile: Dictionary = engine.water(params)
		var index: int = clampi(roundi((float(params["probe"]) - 400) / 5), 0, 60)
		var a: float = profile["a"][index]
		var b: float = profile["b"][index]
		for i: int in 4:
			titles[i].text = ["Absorption a · m⁻¹", "Scattering b · m⁻¹", "Beam attenuation c · m⁻¹", "Downwelling Kd · m⁻¹"][i]
			numbers[i].text = "%.3f" % [a, b, a + b, profile["kd"][index]][i]
		phase_info.text = tr("HG backward hemisphere: %.2f%% · accepted halo cone: %.2f%% · reduced scattering b′: %.3f m⁻¹") % [float(result["back_fraction"]) * 100, float(result["cone_fraction"]) * 100, b * (1 - float(params["g"]))]
		formula.text = "c = a + b · b′ = b(1 − g) · Kd is not c or b′"
		status.text = "Absorption removes light; scattering redirects it. Kd describes diffuse daylight loss with depth. The phase function describes scattering directions, which a and b alone do not determine. HG g = 0 is isotropic; larger g favours forward scattering."
		explanation.text = "The six marine presets use measured-data-derived a and b spectra; the source models between measured bands. Kd comes from the historical Jerlov class table. HG g, diffuse-light share and the halo cone are separate teaching assumptions, not measured properties of these presets or this lake."
	else:
		var coefficients: Dictionary = result["diagnostic"]
		for i: int in 3:
			titles[i].text = ["White target · effective βD", "Red target · effective βD", "Backscatter · effective βB"][i]
			numbers[i].text = "%.4f m⁻¹" % float(coefficients[["white", "red", "back"][i]])
		formula.text = "D = J exp(−βD r) · B = B∞[1 − exp(−βB r)]"
		status.text = "Broadband direct and backscatter coefficients are different. The direct coefficient also changes with target reflectance and range; it is not one fixed RGB constant for a water class."
		explanation.text = "These diagnostics integrate 61 wavelengths before fitting effective coefficients to linear CIE Y. They compare white and red targets in ambient light only. The spectrum weights of direct light and veiling light differ, as in the revised underwater image model; these are not calibrated camera RGB fits."
	assumptions.text = "Model: uniform water, horizontal viewing, D65 daylight, 400–700 nm at 5 nm, CIE 1931 observer, synthetic Lambertian targets and fixed sRGB exposure. The torch uses single scattering and chosen beam geometry; the forward halo is an energy-bounded Gaussian surrogate, not a measured PSF. No full multiple-scattering RTE, fluorescence, camera noise or visual adaptation."
	var profile: Dictionary = engine.water(params)
	if float(profile["b"][30]) * float(params["range"]) > 3:
		assumptions.text = tr(assumptions.text) + " " + tr("At this optical thickness, multiple scattering is important: treat the preview qualitatively.")
