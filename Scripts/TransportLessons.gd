class_name BathysTransportLessons
extends VBoxContainer

const KINDS := ["viscosity", "flow", "heat_transfer", "thermal_properties", "sound"]
const TITLES := {"viscosity": "Dynamic viscosity", "flow": "Laminar & turbulent flow", "heat_transfer": "Conduction, convection & radiation", "thermal_properties": "Heat capacity & conductivity", "sound": "Sound in water"}
const INTROS := {
	"viscosity": "Slide one plate over another. Watch the layers follow, then compare liquids and gases as you warm them.",
	"flow": "Open a tube, change the flow and watch orderly layers give way to mixing. Compare gas density with viscosity.",
	"heat_transfer": "Heat can cross matter, travel with moving fluid or radiate across a gap. Separate the mechanisms before comparing water and air.",
	"thermal_properties": "Storing heat and conducting it are different properties. Give equal samples the same energy, then compare how heat crosses a layer.",
	"sound": "Follow sound through water. Explore travel time, reflection, spreading, absorption and the timing cues between two ears."}
var kind: String = "viscosity"
var experiments: Dictionary = {}
var inputs: Dictionary = {}
var diagram: BathysTransportDiagram
var stages: HFlowContainer
var stage_buttons: Array[Button] = []
var medium_picker: OptionButton
var material_picker: OptionButton
var basis_picker: OptionButton
var boundary_picker: OptionButton
var result: Dictionary = {}
var formula: Label
var explanation: Label
var assumptions: Label
var source_links: HFlowContainer
var control_bank: Control

func parameters() -> Dictionary:
	return experiments[kind]

func _ready() -> void:
	add_theme_constant_override("separation", 9)
	size_flags_horizontal = SIZE_EXPAND_FILL
	for key: String in KINDS:
		experiments[key] = {"stage": 0, "medium": 0, "material": 0, "basis": 0, "boundary": 0,
			"temperature": 20.0, "depth": 0.0, "oxygen": 21.0, "helium": 0.0, "gap": 5.0,
			"speed": 0.2, "diameter": 10.0, "length": 0.3, "flow": 20.0, "hot": 32.0,
			"area": 0.02, "emissivity": 0.95, "energy": 100.0, "range": 10.0,
			"frequency": 10.0, "salinity": 0.0, "bearing": 55.0}
	experiments["flow"].merge({"medium": 2, "depth": 30.0}, true)
	experiments["heat_transfer"].merge({"temperature": 10.0, "hot": 45.0}, true)
	stages = HFlowContainer.new()
	add_child(stages)
	diagram = BathysTransportDiagram.new()
	diagram.parameter_changed.connect(func(key: String, value: float) -> void: (inputs[key] as HSlider).value = value)
	add_child(diagram)
	control_bank = VBoxContainer.new()
	control_bank.hide()
	add_child(control_bank)
	medium_picker = make_picker(["Water", "Air", "Gas mixture"], "medium")
	material_picker = make_picker(["Water", "Aluminium", "Copper", "Gas mixture"], "material")
	basis_picker = make_picker(["Equal mass · 50 g", "Equal initial volume · 50 mL"], "basis")
	boundary_picker = make_picker(["Air", "Water", "Steel"], "boundary")
	for spec: Array in [
		["temperature", 0, 35, 0.1], ["depth", 0, 60, 0.1], ["oxygen", 0, 100, 0.1], ["helium", 0, 100, 0.1],
		["gap", 1, 20, 0.1], ["speed", 0.01, 1, 0.01], ["diameter", 6, 30, 0.1], ["length", 0.1, 1, 0.01], ["flow", 0.1, 60, 0.1],
		["hot", 35, 80, 0.1], ["area", 0.005, 0.05, 0.001], ["emissivity", 0.05, 1, 0.01], ["energy", 0, 200, 1],
		["range", 1, 100, 0.1], ["frequency", 0.1, 100, 0.1], ["salinity", 0, 40, 0.1], ["bearing", -180, 180, 0.1]]:
		var slider := HSlider.new()
		slider.min_value = spec[1]
		slider.max_value = spec[2]
		slider.step = spec[3]
		slider.value_changed.connect(func(value: float) -> void:
			parameters()[spec[0]] = value
			if spec[0] == "oxygen": parameters()["helium"] = minf(parameters()["helium"], 100 - value)
			if spec[0] == "helium": parameters()["oxygen"] = minf(parameters()["oxygen"], 100 - value)
			refresh())
		control_bank.add_child(slider)
		inputs[spec[0]] = slider
	formula = BathysUiStyle.wrapped("", 15, BathysUiStyle.AQUA)
	formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(formula)
	explanation = BathysUiStyle.wrapped("", 13, BathysUiStyle.TEXT)
	add_child(explanation)
	assumptions = BathysUiStyle.wrapped("", 11)
	add_child(assumptions)
	source_links = HFlowContainer.new()
	add_child(source_links)
	for entry: Array in [["Gas viscosity ↗", "https://www.grc.nasa.gov/WWW/winddocs/user/keywords/viscosity.html"], ["Water viscosity ↗", "https://iapws.org/technical-guidance/release/LiquidWater"], ["Heat transfer ↗", "https://openstax.org/books/university-physics-volume-2/pages/1-6-mechanisms-of-heat-transfer"], ["Sound models ↗", "https://resource.npl.co.uk/acoustics/techguides/soundseawater/"]]:
		var link := LinkButton.new()
		link.text = entry[0]
		link.pressed.connect(func() -> void: OS.shell_open(entry[1]))
		source_links.add_child(link)
	resized.connect(adapt)
	get_node("/root/I18n").language_changed.connect(update_text)
	activate(kind)

func make_picker(labels: Array, key: String) -> OptionButton:
	var picker := OptionButton.new()
	picker.fit_to_longest_item = false
	picker.clip_text = true
	for label: String in labels: picker.add_item(label)
	picker.item_selected.connect(func(index: int) -> void:
		parameters()[key] = index
		if key == "basis": parameters()["energy"] = 0.5 if index == 1 else 100.0
		activate(kind))
	control_bank.add_child(picker)
	return picker

func activate(topic: String) -> void:
	kind = topic
	for child: Node in stages.get_children(): stages.remove_child(child); child.queue_free()
	stage_buttons.clear()
	var icons: Array = {"viscosity": [], "flow": [], "heat_transfer": ["transport-conduction", "transport-convection", "transport-radiation"], "thermal_properties": ["transport-capacity", "transport-conduction"], "sound": ["transport-sound", "transport-reflection", "transport-attenuation", "transport-localization"]}[kind]
	var captions: Array = {"viscosity": [], "flow": [], "heat_transfer": ["Conduction", "Convection", "Radiation"], "thermal_properties": ["Heat storage", "Thermal conductivity"], "sound": ["Travel time", "Reflection & transmission", "Spreading & absorption", "Direction cues"]}[kind]
	for i: int in icons.size():
		var button := Button.new()
		button.icon = load("res://Assets/Icons/" + str(icons[i]) + ".svg")
		button.tooltip_text = captions[i]
		button.toggle_mode = true
		button.set_pressed_no_signal(i == int(parameters()["stage"]))
		button.custom_minimum_size = Vector2(48, 42)
		button.pressed.connect(func() -> void: set_stage(i))
		stages.add_child(button)
		stage_buttons.append(button)
	stages.visible = not icons.is_empty()
	for i: int in source_links.get_child_count():
		source_links.get_child(i).visible = (kind == "sound") if i == 3 else (kind in ["heat_transfer", "thermal_properties"] if i == 2 else kind in ["viscosity", "flow", "heat_transfer", "thermal_properties"])
	var p: Dictionary = parameters()
	for input: HSlider in inputs.values(): input.set_block_signals(true)
	(inputs["speed"] as HSlider).min_value = 0 if kind == "viscosity" else 0.01
	(inputs["temperature"] as HSlider).max_value = 30 if kind == "heat_transfer" else (34 if kind == "sound" and int(p["stage"]) == 2 else 35)
	(inputs["range"] as HSlider).max_value = 1000 if kind == "sound" and int(p["stage"]) == 2 else (20 if kind == "sound" and int(p["stage"]) == 3 else 100)
	(inputs["energy"] as HSlider).step = 0.01 if int(p["basis"]) == 1 else 1
	(inputs["energy"] as HSlider).max_value = 1 if int(p["basis"]) == 1 else 200
	for input: HSlider in inputs.values(): input.set_block_signals(false)
	refresh()
	adapt()

func set_stage(index: int) -> void:
	parameters()["stage"] = index
	activate(kind)

func refresh() -> void:
	var p: Dictionary = parameters()
	for key: String in inputs:
		var input: HSlider = inputs[key]
		input.set_value_no_signal(p[key])
		p[key] = input.value
	for pair: Array in [[medium_picker, "medium"], [material_picker, "material"], [basis_picker, "basis"], [boundary_picker, "boundary"]]: pair[0].select(p[pair[1]])
	result = evaluate(p)
	if kind == "heat_transfer" and int(p["stage"]) != 2:
		var reference: Dictionary = p.duplicate()
		reference["medium"] = 1
		result["air_heat"] = BathysTransportModels.heat_transfer(reference, p["stage"])["heat"]
	elif kind == "thermal_properties" and int(p["stage"]) == 1:
		var reference: Dictionary = p.duplicate()
		reference["material"] = 3
		reference["oxygen"] = 21
		reference["helium"] = 0
		result["air_heat"] = BathysTransportModels.thermal_properties(reference, 1)["heat"]
	diagram.kind = kind
	diagram.stage = p["stage"]
	diagram.params = p
	diagram.result = result
	diagram.curve.clear()
	diagram.reference_curve.clear()
	var config: Array = plot_config()
	diagram.plot_key = config[0]
	diagram.x_min = config[1]
	diagram.x_max = config[2]
	diagram.x_caption = config[3]
	diagram.y_caption = config[4]
	for i: int in 61:
		var selected: Dictionary = p.duplicate()
		selected[config[0]] = lerpf(config[1], config[2], i / 60.0)
		diagram.curve.append(plot_value(selected))
		if kind in ["viscosity", "thermal_properties"] or kind == "heat_transfer" and int(p["stage"]) != 2:
			if kind == "thermal_properties": selected["material"] = 3; selected["oxygen"] = 21; selected["helium"] = 0
			else: selected["medium"] = 1
			diagram.reference_curve.append(plot_value(selected))
		elif kind == "sound" and int(p["stage"]) in [0, 2, 3]:
			var data: Dictionary = evaluate(selected)
			diagram.reference_curve.append(data["air_c"] if int(p["stage"]) == 0 else (data["spread"] if int(p["stage"]) == 2 else data["delay_air"]))
	diagram.queue_redraw()
	update_text()

func evaluate(p: Dictionary) -> Dictionary:
	match kind:
		"viscosity": return BathysTransportModels.shear(p)
		"flow": return BathysTransportModels.pipe(p)
		"heat_transfer": return BathysTransportModels.heat_transfer(p, p["stage"])
		"thermal_properties": return BathysTransportModels.thermal_properties(p, p["stage"])
	return BathysTransportModels.sound(p, p["stage"])

func plot_config() -> Array:
	var stage: int = parameters()["stage"]
	match kind:
		"viscosity": return ["temperature", 0.0, 35.0, "Temperature · °C", "Viscosity · mPa·s"]
		"flow": return ["flow", 0.1, 60.0, "Flow · L/min", "Pressure loss · Pa"]
		"heat_transfer":
			if stage == 0: return ["gap", 1.0, 20.0, "Layer thickness · mm", "Heat transfer · W"]
			if stage == 1: return ["speed", 0.01, 1.0, "Fluid speed · m/s", "Heat transfer · W"]
			return ["hot", 35.0, 80.0, "Surface temperature · °C", "Radiated heat · W"]
		"thermal_properties": return ["energy", 0.0, float((inputs["energy"] as HSlider).max_value), "Added energy · J", "Temperature rise · K"] if stage == 0 else ["gap", 1.0, 20.0, "Layer thickness · mm", "Heat transfer · W"]
	if stage == 0: return ["temperature", 0.0, 35.0, "Temperature · °C", "Sound speed · m/s"]
	if stage == 2: return ["range", 1.0, 1000.0, "Source distance · m", "Loss from 1 m · dB"]
	return ["bearing", -180.0, 180.0, "Bearing · °", "Arrival difference · µs"]

func plot_value(p: Dictionary) -> float:
	var data: Dictionary = evaluate(p)
	match kind:
		"viscosity": return data["properties"]["mu"] * 1000
		"flow": return data["pressure"]
		"heat_transfer": return data["heat"]
		"thermal_properties": return data["rise"] if int(p["stage"]) == 0 else data["heat"]
	return data["c"] if int(p["stage"]) == 0 else (data["loss"] if int(p["stage"]) == 2 else data["delay_water"])

func instruments() -> Array:
	var p: Dictionary = parameters()
	match kind:
		"viscosity": return [["temperature", "temperature", "Temperature", "°C"], ["speed", "flow", "Plate speed", "m/s"], ["gap", "length", "Layer thickness", "mm"]]
		"flow":
			var specs: Array = [["temperature", "temperature", "Temperature", "°C"], ["flow", "flow", "Flow", "L/min"], ["diameter", "length", "Tube diameter", "mm"], ["length", "length", "Tube length", "m"]]
			if int(p["medium"]) != 0: specs.append(["depth", "depth", "Depth", "m"])
			return specs
		"heat_transfer":
			var specs: Array = [["temperature", "temperature", "Surroundings", "°C"], ["area", "length", "Surface area", "m²"]]
			if int(p["stage"]) == 0: specs.append(["gap", "length", "Layer thickness", "mm"])
			elif int(p["stage"]) == 1: specs.append(["speed", "flow", "Fluid speed", "m/s"])
			else: specs.append_array([["hot", "temperature", "Warm surface", "°C"], ["emissivity", "finish", "Surface finish", "ε"]])
			return specs
		"thermal_properties": return [["energy", "energy", "Added energy", "J"]] if int(p["stage"]) == 0 else [["gap", "length", "Layer thickness", "mm"]]
	if int(p["stage"]) == 1: return [["temperature", "temperature", "Temperature", "°C"], ["salinity", "salt", "Salt", "g/kg"]]
	if int(p["stage"]) == 2: return [["temperature", "temperature", "Temperature", "°C"], ["frequency", "wave", "Frequency", "kHz"], ["range", "sound_distance", "Source distance", "m"]]
	var specs: Array = [["temperature", "temperature", "Temperature", "°C"], ["salinity", "salt", "Salt", "g/kg"], ["range", "sound_distance", "Source distance", "m"]]
	if int(p["stage"]) == 0: specs.append(["depth", "depth", "Depth", "m"])
	return specs

func uses_mixture() -> bool:
	return int(parameters()["material"]) == 3 if kind == "thermal_properties" else kind != "sound" and int(parameters()["medium"]) == 2 and not (kind == "heat_transfer" and int(parameters()["stage"]) == 2)

func adapt() -> void:
	if is_instance_valid(diagram): diagram.adapt()

func update_text() -> void:
	var p: Dictionary = parameters()
	match kind:
		"viscosity":
			formula.text = "τ = μ × U / h\n\nF = τ × A\n\nν = μ / ρ"
			explanation.text = "Viscosity transfers momentum between neighboring layers. A moving plate pulls the fluid along; a thinner gap or faster plate needs more force. Warm water becomes less viscous, while a dilute gas becomes more viscous. Dynamic viscosity μ and density ρ are different properties; their ratio is kinematic viscosity ν."
			assumptions.text = "Steady Newtonian Couette flow between ideal parallel plates, no slip, area 0.02 m²; the drawn motion is schematic. Freshwater viscosity uses IAPWS at 0.1 MPa; gas viscosity uses room-temperature references, Sutherland temperature scaling and Wilke mixing. Gas density is ideal. This is not a calibrated regulator or breathing-resistance model."
		"flow":
			formula.text = "Re = ρ × v × D / μ\n\nΔp = f × (L / D) × ρv² / 2\n\nLaminar: f = 64 / Re"
			explanation.text = "At low Reynolds number, viscosity suppresses disturbances and the layers stay ordered. At higher Reynolds number, mixing and eddies become important. The same volume flow in a narrower tube moves faster and costs more pressure. Helium mainly changes density; it does not simply remove viscosity."
			assumptions.text = "Illustrative steady, fully developed flow in a straight smooth round tube. Laminar below Re 2000; transition 2000–4000 is uncertain; turbulent friction uses smooth-pipe Haaland, with an illustrative blend in transition. Actual onset depends on entry conditions and disturbances. Flow is actual volume at local pressure, not surface SAC. Density is uniform; entrance, bends, valves, pulsation and compressible/choked flow are omitted."
		"heat_transfer":
			if int(p["stage"]) == 0:
				formula.text = "Q̇ = k × A × (T_h − T_c) / d"
				explanation.text = "Conduction passes energy through matter without bulk flow. Compare the same layer of water and air at the same thickness and temperature difference. A larger conductivity means more heat crosses the layer; making it thicker reduces the transfer. The comparison isolates conduction, not total heat loss from a diver."
			elif int(p["stage"]) == 1:
				formula.text = "Q̇ = h × A × (T_h − T_env)\n\nh = Nu × k / D"
				explanation.text = "Moving fluid carries warmed material away and replaces it with cooler material. Increase the flow and watch heat leave faster. Water and air have different conductivity, density, viscosity and heat capacity, so their heat-transfer coefficients differ. The ratio changes with the conditions; there is no universal water-to-air heat-loss multiplier."
			else:
				formula.text = "Q̇ = ε × σ × A × (T_h⁴ − T_c⁴)\n\nUse absolute temperature in kelvin."
				explanation.text = "Thermal radiation carries energy as electromagnetic waves and needs no moving fluid. A dark high-emissivity surface exchanges more radiation than a shiny low-emissivity one at the same temperatures. This is an air/vacuum-gap illustration: water absorbs thermal infrared nearby, so it is not a model of direct radiation across a lake."
			assumptions.text = "Maintained warm and cool surfaces, not a human cooling prediction. Conduction is a uniform motionless slab; convection is forced crossflow over a 0.1 m cylinder using Churchill–Bernstein (natural convection, insulation and clothing excluded). Radiation uses diffuse gray surfaces with view factor 1 and a large surrounding enclosure. Water k is a representative 0.6 W/(m·K), cp 4184 J/(kg·K); gas transport is a dilute-mixture estimate."
		"thermal_properties":
			formula.text = "C = m × cₚ\n\nΔT = Q / C" if int(p["stage"]) == 0 else "Q̇ = k × A × ΔT / d\n\nα = k / (ρ × cₚ)"
			explanation.text = "Heat capacity tells you how much energy changes a sample's temperature. Conductivity tells you how readily heat crosses it. Equal mass and equal initial volume are different comparisons: helium has a high heat capacity per kilogram but very low density. Change the mixture and switch comparisons before drawing a conclusion. Water stores far more heat than the same volume of air."
			assumptions.text = "Room-temperature representative properties, maintained boundaries and no phase changes. Storage compares 50 g or an initial 50 mL with the same added energy; gas samples expand at constant pressure, so cp is used. Conductivity compares a uniform layer, area 0.02 m² and ΔT 20 K; no convection, contact resistance or insulation compression. Gas cp follows ideal translational/rotational degrees of freedom; conductivity uses Eucken with Wilke mixing and is approximate. This illustrates materials, not a drysuit or breathing-gas recommendation."
		"sound":
			match int(p["stage"]):
				0:
					formula.text = "Travel time = distance / sound speed"
					explanation.text = "Sound crosses the same distance much faster in water than in air. Temperature, salinity and pressure change its speed. The moving fronts are slowed for comparison; the displayed travel times use the actual calculated speeds."
				1:
					formula.text = "Z = ρ × c\n\nR = [(Z₂ − Z₁) / (Z₂ + Z₁)]²\n\nT = 1 − R"
					explanation.text = "A large acoustic-impedance mismatch reflects much of the incident intensity. Water-to-air and water-to-water therefore behave very differently. The bars represent energy fractions, not pressure amplitudes; pressure changes sign on reflection toward the lower-impedance medium."
				2:
					formula.text = "Loss from 1 m (dB) = 20 log₁₀(r) + α × (r − 1) / 1000\n\nr: metres    α: dB/km"
					explanation.text = "Spreading distributes the sound over a larger area; absorption converts some acoustic energy to heat. Frequency strongly affects absorption, but close to a diver spreading often dominates. The reference is the level at 1 m in the same medium. Frequencies above 20 kHz are ultrasonic, not a human-audibility demonstration."
				3:
					formula.text = "Δt = (distance to left ear − distance to right ear) / c"
					explanation.text = "Move the source around the head. Faster sound makes the arrival-time difference smaller for the same two-ear spacing. A mirrored source behind the head can give the same delay as one in front. Timing is only one cue: underwater ear coupling, head/body conduction and reflections also matter. This diagram does not predict a person's localization accuracy."
			assumptions.text = "Uniform water, straight direct paths and no multipath or sound-speed gradients. Coppens sound speed uses 0–35°C, salinity 0–40 and depth in kilometres internally. Reflection is a normal-incidence plane wave between lossless half-spaces; steel uses representative longitudinal impedance. Absorption uses Ainslie–McColm reference seawater at salinity 35, pH 8 and depth 10 m; it is not a freshwater/lake calibration. Direction cues use two point receivers 0.18 m apart; head/ear spacing is exaggerated in the drawing. This is not a human auditory model."
