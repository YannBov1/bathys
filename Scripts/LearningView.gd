class_name BathysLearningView
extends MarginContainer

const BOYLE_SOURCE := "https://www.grc.nasa.gov/www/BGH/boyle.html"
const SNELL_SOURCE := "https://openstax.org/books/university-physics-volume-3/pages/1-4-total-internal-reflection"
const TOPICS := [["boyle", "Boyle’s law"], ["snell", "Snell’s law"], ["dalton", "Dalton’s law"], ["henry", "Henry’s law"], ["density", "Water density"], ["gas_density", "Gas density"], ["oxygen", "Oxygen toxicity"], ["narcosis", "Nitrogen narcosis"], ["buhlmann", "Bühlmann model"], ["buoyancy", "Archimedes & buoyancy"], ["colour", "Colour underwater"], ["charles", "Charles’s law"], ["ideal_gas", "Ideal gas law"], ["real_gas", "Real gases & compressibility"], ["joule_thomson", "Joule–Thomson & cooling"], ["fick", "Fick’s law & gas exchange"], ["viscosity", "Dynamic viscosity"], ["flow", "Laminar & turbulent flow"], ["heat_transfer", "Heat transfer"], ["thermal_properties", "Heat capacity & conductivity"], ["sound", "Sound in water"]]
const CATEGORIES := [["Physics of diving", ["boyle", "charles", "ideal_gas", "real_gas", "joule_thomson", "snell", "colour", "dalton", "henry", "density", "buoyancy", "gas_density", "viscosity", "flow", "heat_transfer", "thermal_properties", "sound"]], ["Physiology", ["fick", "oxygen", "narcosis"]], ["Models & risk", ["buhlmann"]]]
const SOURCES := {
	"viscosity": "https://www.grc.nasa.gov/WWW/winddocs/user/keywords/viscosity.html",
	"flow": "https://openstax.org/books/university-physics-volume-1/pages/14-7-viscosity-and-turbulence",
	"heat_transfer": "https://openstax.org/books/university-physics-volume-2/pages/1-6-mechanisms-of-heat-transfer",
	"thermal_properties": "https://openstax.org/books/chemistry-atoms-first/pages/9-1-energy-basics",
	"sound": "https://resource.npl.co.uk/acoustics/techguides/soundseawater/",
	"fick": "https://openstax.org/books/anatomy-and-physiology-2e/pages/22-4-gas-exchange",
	"charles": "https://openstax.org/books/chemistry/pages/9-2-relating-pressure-volume-amount-and-temperature-the-ideal-gas-law",
	"ideal_gas": "https://openstax.org/books/college-physics/pages/13-3-the-ideal-gas-law",
	"real_gas": "https://openstax.org/books/chemistry-2e/pages/9-6-non-ideal-gas-behavior",
	"joule_thomson": "https://interaktiv.chemie.uni-mainz.de/vpcgp/jt-man.en.html",
	"colour": "https://openaccess.thecvf.com/content_cvpr_2018/html/Akkaynak_A_Revised_Underwater_CVPR_2018_paper.html",
	"buoyancy": "https://openstax.org/books/university-physics-volume-1/pages/14-4-archimedes-principle-and-buoyancy",
	"boyle": BOYLE_SOURCE, "snell": SNELL_SOURCE,
	"dalton": "https://openstax.org/books/chemistry-2e/pages/9-3-stoichiometry-of-gaseous-substances-mixtures-and-reactions",
	"henry": "https://openstax.org/books/chemistry/pages/11-3-solubility",
	"density": "https://www.vliz.be/imisdocs/publications/ocrd/122840.pdf",
	"oxygen": "https://dan.org/health-medicine/health-resources/diseases-conditions/oxygen-toxicity/",
	"narcosis": "https://dan.org/alert-diver/article/breathing-gases/",
	"gas_density": "https://dan.org/alert-diver/article/performance-under-pressure/",
	"buhlmann": "https://www.shearwater.com/wp-content/uploads/2022/05/Petrel-3_Technical_Manual_RevB.pdf"}
var dalton_depth: float = 20.0
var oxygen_percent: float = 21.0
var helium_percent: float = 0.0
var gas_pressure: float = 3.0
var half_times: float = 1.0
var temperature_c: float = 20.0
var salinity: float = 0.0
var extra_controls: Dictionary = {}
var extra_sliders: Dictionary = {}
var extra_values: Dictionary = {}
var presentation: BathysLessonPresentation
var navigation_heading: Label
var topic_scroll: ScrollContainer
var lesson_scroll: ScrollContainer
var topic_stack: VBoxContainer
var topic_picker: OptionButton
var exchange_view: BathysExchangeLesson
var mask_view: BathysMaskLesson
var snell_mask: bool = false
var snell_tabs: HFlowContainer
var snell_buttons: Array[Button] = []
var transport_view: BathysTransportLessons
var thermal_view: BathysThermalLessons
var optics_view: BathysOpticsLesson
var buoyancy_view: BathysBuoyancyLesson
var breathing_view: BathysBreathingLessons
var buhlmann_view: BathysBuhlmannLesson
var standard_sections: Array[Control] = []
var lesson: String = "boyle"
var depth_m: float = 10.0
var angle_deg: float = 30.0
var from_water: bool = false
var layout: BoxContainer
var navigation: PanelContainer
var topic_buttons: Dictionary = {}
var title_label: Label
var intro_label: Label
var diagram: BathysScienceLessonDiagram
var control_label: Label
var control_value: Label
var slider: HSlider
var presets: HBoxContainer
var direction_picker: OptionButton
var critical_button: Button
var readouts: GridContainer
var readout_titles: Array[Label] = []
var readout_values: Array[Label] = []
var formula_label: Label
var insight_label: Label
var relevance_label: Label
var assumptions_label: Label
var source_button: LinkButton

func _ready() -> void:
	name = "LearningView"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 8)
	layout = BoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	add_child(layout)
	navigation = BathysUiStyle.panel(BathysUiStyle.PANEL, 12)
	layout.add_child(navigation)
	var nav := BathysUiStyle.column(navigation, 12)
	navigation_heading = label("LEARN & EXPLORE", 12, BathysUiStyle.AQUA)
	nav.add_child(navigation_heading)
	var group := ButtonGroup.new()
	topic_scroll = ScrollContainer.new()
	topic_scroll.name = "LessonNavigationScroll"
	topic_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	topic_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	topic_scroll.follow_focus = true
	nav.add_child(topic_scroll)
	topic_stack = BathysUiStyle.column(topic_scroll, 8)
	topic_picker = OptionButton.new()
	topic_picker.name = "CompactTopics"
	topic_picker.fit_to_longest_item = false
	topic_picker.clip_text = true
	topic_picker.item_selected.connect(func(index: int) -> void: select_lesson(str(TOPICS[topic_picker.get_item_id(index)][0])))
	nav.add_child(topic_picker)
	for category: Array in CATEGORIES:
		var caption: Label = BathysUiStyle.wrapped(str(category[0]), 12, BathysUiStyle.AQUA)
		caption.name = "Category_" + str(category[0]).replace(" ", "_")
		topic_stack.add_child(caption)
		topic_picker.add_separator(str(category[0]))
		topic_picker.set_item_id(topic_picker.item_count - 1, -100 - topic_picker.item_count)
		for key: String in category[1]:
			var topic_index: int = -1
			for index: int in TOPICS.size():
				if str(TOPICS[index][0]) == key: topic_index = index
			var button := Button.new()
			button.name = "Topic_" + key
			button.text = str(TOPICS[topic_index][1])
			if key in BathysTransportLessons.KINDS:
				button.clip_text = true
				button.tooltip_text = button.text
			button.icon = load("res://Assets/Icons/law-" + key + ".svg")
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size.y = 45
			button.toggle_mode = true
			button.button_group = group
			button.pressed.connect(select_lesson.bind(key))
			topic_stack.add_child(button)
			topic_buttons[key] = button
			topic_picker.add_icon_item(button.icon, button.text, topic_index)
	lesson_scroll = ScrollContainer.new()
	lesson_scroll.name = "LessonContentScroll"
	lesson_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lesson_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lesson_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(lesson_scroll)
	var lesson_panel: PanelContainer = BathysUiStyle.panel(BathysUiStyle.PANEL, 16)
	lesson_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lesson_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lesson_scroll.add_child(lesson_panel)
	var body := BathysUiStyle.column(lesson_panel, 10)
	title_label = BathysUiStyle.wrapped("", 26, BathysUiStyle.TEXT)
	body.add_child(title_label)
	intro_label = BathysUiStyle.wrapped("", 14, BathysUiStyle.TEXT)
	body.add_child(intro_label)
	buhlmann_view = BathysBuhlmannLesson.new()
	buhlmann_view.hide()
	body.add_child(buhlmann_view)
	breathing_view = BathysBreathingLessons.new()
	breathing_view.hide()
	body.add_child(breathing_view)
	buoyancy_view = BathysBuoyancyLesson.new()
	buoyancy_view.hide()
	body.add_child(buoyancy_view)
	optics_view = BathysOpticsLesson.new()
	optics_view.hide()
	body.add_child(optics_view)
	thermal_view = BathysThermalLessons.new()
	thermal_view.hide()
	body.add_child(thermal_view)
	exchange_view = BathysExchangeLesson.new()
	exchange_view.hide()
	body.add_child(exchange_view)
	transport_view = BathysTransportLessons.new()
	transport_view.hide()
	body.add_child(transport_view)
	snell_tabs = HFlowContainer.new()
	snell_tabs.hide()
	body.add_child(snell_tabs)
	var snell_group := ButtonGroup.new()
	for index: int in 2:
		var button := Button.new()
		button.text = "Boundary & rays" if index == 0 else "Mask & apparent size"
		button.toggle_mode = true
		button.button_group = snell_group
		button.pressed.connect(set_snell_stage.bind(index == 1))
		snell_tabs.add_child(button)
		snell_buttons.append(button)
	mask_view = BathysMaskLesson.new()
	mask_view.hide()
	body.add_child(mask_view)
	diagram = BathysScienceLessonDiagram.new()
	diagram.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(diagram)
	diagram.oxygen_changed.connect(func(value: float) -> void: (extra_sliders["oxygen"] as HSlider).value = value)
	diagram.helium_changed.connect(func(value: float) -> void: (extra_sliders["helium"] as HSlider).value = value)
	diagram.depth_changed.connect(func(value: float) -> void: slider.value = value)
	diagram.angle_changed.connect(func(value: float) -> void: slider.value = value)
	diagram.time_changed.connect(func(value: float) -> void: (extra_sliders["time"] as HSlider).value = value)
	diagram.temperature_changed.connect(func(value: float) -> void: slider.value = value)
	var controls: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 10)
	body.add_child(controls)
	var controls_stack := BathysUiStyle.column(controls, 6)
	var row := HBoxContainer.new()
	controls_stack.add_child(row)
	control_label = BathysUiStyle.wrapped("", 13, BathysUiStyle.TEXT)
	control_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control_label)
	control_value = label("", 18, BathysUiStyle.AQUA)
	row.add_child(control_value)
	slider = HSlider.new()
	slider.name = "LessonSlider"
	slider.step = 0.1
	slider.custom_minimum_size.y = 24
	slider.value_changed.connect(func(value: float) -> void:
		match lesson:
			"boyle": depth_m = value
			"snell": angle_deg = value
			"dalton": dalton_depth = value
			"henry": gas_pressure = value
			"density": temperature_c = value
		update_values())
	controls_stack.add_child(slider)
	presets = HBoxContainer.new()
	controls_stack.add_child(presets)
	for depth: int in [0, 10, 20, 30, 40]:
		var button := Button.new()
		button.text = "%d m" % depth
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: slider.value = depth)
		presets.add_child(button)
	var optics_controls := HFlowContainer.new()
	optics_controls.name = "OpticsControls"
	controls_stack.add_child(optics_controls)
	direction_picker = OptionButton.new()
	direction_picker.name = "LightDirection"
	direction_picker.add_item("Air → water")
	direction_picker.add_item("Water → air")
	direction_picker.item_selected.connect(func(index: int) -> void: from_water = index == 1; update_values())
	optics_controls.add_child(direction_picker)
	critical_button = Button.new()
	critical_button.text = "Explore the critical angle"
	critical_button.pressed.connect(func() -> void:
		from_water = true
		direction_picker.select(1)
		slider.value = BathysLessonDiagram.critical_angle()
		update_values())
	optics_controls.add_child(critical_button)
	add_extra_slider(controls_stack, "oxygen", "Oxygen fraction", 100, 0.1, func(value: float) -> void:
		oxygen_percent = value
		helium_percent = minf(helium_percent, 100 - value)
		update_values())
	add_extra_slider(controls_stack, "helium", "Helium fraction", 100, 0.1, func(value: float) -> void:
		helium_percent = value
		oxygen_percent = minf(oxygen_percent, 100 - value)
		update_values())
	add_extra_slider(controls_stack, "time", "Elapsed half-times · exchange example", 5, 0.1, func(value: float) -> void:
		half_times = value
		update_values())
	add_extra_slider(controls_stack, "salinity", "Salinity · approximately g/kg", 40, 0.1, func(value: float) -> void:
		salinity = value
		update_values())
	add_presets(controls_stack, "mixtures", [["Air · 21/0", 21.0, 0.0], ["Nitrox · 32/0", 32.0, 0.0], ["Trimix · 18/45", 18.0, 45.0]], func(entry: Array) -> void:
		oxygen_percent = float(entry[1])
		helium_percent = float(entry[2])
		update_values())
	add_presets(controls_stack, "pressure_steps", [["1 → 4 bar", 4.0], ["1 → 0.5 bar", 0.5]], func(entry: Array) -> void:
		half_times = 0
		slider.value = float(entry[1])
		update_values())
	add_presets(controls_stack, "waters", [["Fresh · 4°C", 4.0, 0.0], ["Fresh · 20°C", 20.0, 0.0], ["Sea · 20°C", 20.0, 35.0]], func(entry: Array) -> void:
		salinity = float(entry[2])
		slider.value = float(entry[1])
		update_values())
	readouts = GridContainer.new()
	readouts.columns = 3
	body.add_child(readouts)
	for i: int in 4:
		var card: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 8)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		readouts.add_child(card)
		var stack := BathysUiStyle.column(card, 2)
		var caption: Label = BathysUiStyle.wrapped("", 11)
		stack.add_child(caption)
		readout_titles.append(caption)
		var value: Label = label("", 20, BathysUiStyle.AQUA)
		stack.add_child(value)
		readout_values.append(value)
	formula_label = label("", 17, BathysUiStyle.AQUA)
	formula_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(formula_label)
	var insight: PanelContainer = BathysUiStyle.panel(Color("143c43"), 10)
	body.add_child(insight)
	var insight_stack := BathysUiStyle.column(insight, 5)
	insight_label = BathysUiStyle.wrapped("", 14, BathysUiStyle.TEXT)
	insight_stack.add_child(insight_label)
	relevance_label = BathysUiStyle.wrapped("", 12)
	insight_stack.add_child(relevance_label)
	assumptions_label = BathysUiStyle.wrapped("", 11)
	body.add_child(assumptions_label)
	source_button = LinkButton.new()
	source_button.text = "Model reference ↗"
	source_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	source_button.pressed.connect(func() -> void: OS.shell_open(str(SOURCES[lesson])))
	body.add_child(source_button)
	resized.connect(adapt_layout)
	get_node("/root/I18n").language_changed.connect(update_values)
	standard_sections.assign([diagram, controls, readouts, formula_label, insight, assumptions_label])
	presentation = BathysLessonPresentation.new()
	add_child(presentation)
	presentation.setup(self, body)
	select_lesson("boyle")
	call_deferred("adapt_layout")

func add_extra_slider(parent: Node, key: String, caption: String, maximum: float, step_size: float, callback: Callable) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	parent.add_child(block)
	extra_controls[key] = block
	var row := HBoxContainer.new()
	block.add_child(row)
	var caption_label: Label = BathysUiStyle.wrapped(caption, 12, BathysUiStyle.TEXT)
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption_label)
	var value: Label = label("", 14, BathysUiStyle.AQUA)
	row.add_child(value)
	extra_values[key] = value
	var input := HSlider.new()
	input.name = "Lesson_" + key
	input.max_value = maximum
	input.step = step_size
	input.custom_minimum_size.y = 24
	input.tooltip_text = caption
	input.value_changed.connect(callback)
	block.add_child(input)
	extra_sliders[key] = input

func add_presets(parent: Node, key: String, entries: Array, callback: Callable) -> void:
	var row := HFlowContainer.new()
	parent.add_child(row)
	extra_controls[key] = row
	for entry: Array in entries:
		var button := Button.new()
		button.text = str(entry[0])
		button.pressed.connect(func() -> void: callback.call(entry))
		row.add_child(button)

func label(value: String, font_size: int = 14, color: Color = BathysUiStyle.TEXT) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result

func adapt_layout() -> void:
	layout.vertical = size.x < 760
	navigation.custom_minimum_size = Vector2(0, 60) if layout.vertical else Vector2(228, 0)
	navigation_heading.visible = not layout.vertical
	topic_picker.add_theme_constant_override("icon_max_width", 22 if layout.vertical else 32)
	navigation.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if layout.vertical else Control.SIZE_EXPAND_FILL
	topic_scroll.visible = not layout.vertical
	topic_stack.visible = not layout.vertical
	topic_picker.visible = layout.vertical
	readouts.columns = 1 if size.x < 450 else (4 if lesson == "dalton" else 3)
	diagram.adapt()
	buhlmann_view.adapt()
	breathing_view.adapt()
	buoyancy_view.adapt()
	optics_view.adapt()
	thermal_view.adapt()
	exchange_view.adapt()
	mask_view.adapt()
	transport_view.adapt()

func select_lesson(key: String) -> void:
	if key not in SOURCES:
		return
	lesson = key
	source_button.visible = lesson != "colour"
	lesson_scroll.set_deferred("scroll_vertical", 0)
	transport_view.visible = lesson in BathysTransportLessons.KINDS
	buhlmann_view.visible = lesson == "buhlmann"
	buoyancy_view.visible = lesson == "buoyancy"
	optics_view.visible = lesson == "colour"
	thermal_view.visible = lesson in BathysThermalLessons.KINDS
	exchange_view.visible = lesson == "fick"
	breathing_view.visible = lesson in ["oxygen", "narcosis", "gas_density"]
	for section: Control in standard_sections:
		section.visible = lesson not in BathysTransportLessons.KINDS and lesson not in ["buhlmann", "oxygen", "narcosis", "gas_density", "buoyancy", "colour", "charles", "ideal_gas", "real_gas", "joule_thomson", "fick"]
	sync_snell_sections()
	for index: int in TOPICS.size():
		if str(TOPICS[index][0]) == lesson: topic_picker.select(topic_picker.get_item_index(index))
	for topic: String in topic_buttons:
		(topic_buttons[topic] as Button).set_pressed_no_signal(topic == lesson)
	if lesson in BathysTransportLessons.KINDS or lesson in ["buhlmann", "oxygen", "narcosis", "gas_density", "buoyancy", "colour", "charles", "ideal_gas", "real_gas", "joule_thomson", "fick"]:
		if lesson in BathysTransportLessons.KINDS: transport_view.activate(lesson)
		if lesson in ["oxygen", "narcosis", "gas_density"]: breathing_view.set_lesson(lesson)
		if lesson == "colour": optics_view.activate()
		if lesson in BathysThermalLessons.KINDS: thermal_view.activate(lesson)
		update_values()
		adapt_layout()
		return
	slider.set_block_signals(true)
	slider.max_value = {"boyle": 40.0, "snell": 89.0, "dalton": 40.0, "henry": 5.0, "density": 35.0}[lesson]
	slider.value = {"boyle": depth_m, "snell": angle_deg, "dalton": dalton_depth, "henry": gas_pressure, "density": temperature_c}[lesson]
	slider.set_block_signals(false)
	presets.visible = lesson == "boyle"
	direction_picker.get_parent().visible = lesson == "snell"
	for index: int in TOPICS.size():
		if str(TOPICS[index][0]) == lesson: topic_picker.select(topic_picker.get_item_index(index))
	for control_key: String in extra_controls:
		(extra_controls[control_key] as Control).visible = control_key in {"boyle": [], "snell": [], "dalton": ["oxygen", "helium", "mixtures"], "henry": ["time", "pressure_steps"], "density": ["salinity", "waters"]}[lesson]
	readout_values[3].get_parent().get_parent().visible = lesson == "dalton"
	diagram.lesson = lesson
	diagram.adapt()
	update_values()
	adapt_layout()

func set_snell_stage(use_mask: bool) -> void:
	snell_mask = use_mask
	sync_snell_sections()
	if use_mask: mask_view.refresh()
	lesson_scroll.set_deferred("scroll_vertical", 0)
	update_values()
	adapt_layout()

func sync_snell_sections() -> void:
	snell_tabs.visible = lesson == "snell"
	mask_view.visible = lesson == "snell" and snell_mask
	for index: int in 2: snell_buttons[index].set_pressed_no_signal((index == 1) == snell_mask)
	if lesson == "snell":
		for section: Control in standard_sections: section.visible = not snell_mask

func update_values() -> void:
	if lesson in BathysTransportLessons.KINDS:
		title_label.text = BathysTransportLessons.TITLES[lesson]
		intro_label.text = BathysTransportLessons.INTROS[lesson]
		return
	if lesson == "fick":
		title_label.text = "Fick’s law & gas exchange"
		intro_label.text = "Follow a gas across an alveolar or tissue barrier. Change the pressure gradient and the barrier, then watch a finite receiver equilibrate."
		return
	if lesson == "snell" and snell_mask:
		title_label.text = "Snell’s law · the diving mask"
		intro_label.text = "Trace light through water, a flat window and the mask’s air pocket. Compare the same target’s real geometry and angular size."
		return
	if lesson in BathysThermalLessons.KINDS:
		title_label.text = {"charles": "Charles’s law", "ideal_gas": "The ideal gas law", "real_gas": "Real gases & compressibility", "joule_thomson": "Joule–Thomson effect & gas cooling"}[lesson]
		intro_label.text = {"charles": "Warm a fixed gas sample without changing its pressure. Follow its volume and discover why temperature ratios use kelvin.", "ideal_gas": "Connect pressure, volume, temperature and gas amount. Choose what responds, then change one input at a time.", "real_gas": "Explore where PV = nRT departs from a real-gas model. Compare equal moles, then ask how much gas fits in a rigid cylinder.", "joule_thomson": "Follow gas through a pressure drop. Compare real and ideal throttling with expansion that delivers work."}[lesson]
		return
	if lesson == "colour":
		title_label.text = "Colour underwater"
		intro_label.text = "Follow the light from the surface or torch to a coloured target, then through the water to your eye. Separate colour loss, blur and the veil of scattered light."
		return
	if lesson == "buoyancy":
		title_label.text = "Archimedes’ principle & buoyancy"
		intro_label.text = "Displacing water creates an upward force. Explore what changes that force, then add a compressible gas space at depth."
		return
	if lesson in ["oxygen", "narcosis", "gas_density"]:
		title_label.text = {"oxygen": "Oxygen toxicity", "narcosis": "Nitrogen narcosis", "gas_density": "Gas density & breathing"}[lesson]
		intro_label.text = {"oxygen": "Oxygen pressure and exposure time both matter. Explore the brain and lung exposure indexes separately.", "narcosis": "Depth changes gas partial pressures. Compare a mixture with air and explore the assumptions behind equivalent narcotic depth.", "gas_density": "Pressure packs more gas mass into each litre. Explore depth, helium and temperature, then compare with air."}[lesson]
		return
	if lesson == "buhlmann":
		title_label.text = "Bühlmann ZH-L16C"
		intro_label.text = "Sixteen compartments track dissolved inert gas. Explore their half-times, then see how gradient factors change the model’s limits."
		return
	for value: Label in readout_values:
		value.add_theme_font_size_override("font_size", 20)
	for key: String in extra_sliders:
		var number: float = {"oxygen": oxygen_percent, "helium": helium_percent, "time": half_times, "salinity": salinity}[key]
		(extra_sliders[key] as HSlider).set_value_no_signal(number)
		(extra_values[key] as Label).text = "%.1f%%" % number if key in ["oxygen", "helium"] else "%.1f" % number
	diagram.dalton_depth = dalton_depth
	diagram.oxygen_percent = oxygen_percent
	diagram.helium_percent = helium_percent
	diagram.gas_pressure = gas_pressure
	diagram.half_times = half_times
	diagram.temperature_c = temperature_c
	diagram.salinity = salinity
	diagram.queue_redraw()
	if lesson in ["dalton", "henry", "density"]:
		update_science_values()
		return
	var boyle: bool = lesson == "boyle"
	title_label.text = "Boyle’s law" if boyle else "Snell’s law"
	intro_label.text = "Take the same trapped gas deeper. More pressure squeezes it into less space." if boyle else "Light changes direction at the water surface. Change its angle and follow the ray."
	control_label.text = "Depth" if boyle else "Angle of incidence · from the normal"
	slider.tooltip_text = "Depth · Left/Right to adjust" if boyle else "Angle of incidence · Left/Right to adjust"
	control_value.text = "%.1f m" % depth_m if boyle else "%.1f°" % angle_deg
	diagram.depth_m = depth_m
	diagram.angle_deg = angle_deg
	diagram.from_water = from_water
	diagram.queue_redraw()
	readout_values[1].add_theme_font_size_override("font_size", 20)
	if boyle:
		var pressure: float = BathysLessonDiagram.pressure_at(depth_m)
		var volume: float = BathysLessonDiagram.volume_at(depth_m)
		readout_titles[0].text = "Absolute pressure"
		readout_titles[1].text = "Gas volume"
		readout_titles[2].text = "Surface volume remaining"
		readout_values[0].text = "%.2f bar" % pressure
		readout_values[1].text = "%.2f L" % volume
		readout_values[2].text = "%.0f%%" % (volume * 100)
		formula_label.text = "P₁ × V₁ = P₂ × V₂"
		insight_label.text = tr("At %.1f m, pressure is %.1f× the surface pressure and the gas occupies %.0f%% of its original volume.") % [depth_m, pressure, volume * 100]
		relevance_label.text = "On ascent, trapped gas expands. This explains changes in buoyancy and why divers must never hold their breath. Try moving from 20 m back to the surface."
		assumptions_label.text = "Model: fixed gas amount and temperature, flexible gas space. Starts at 1 L and 1 bar absolute; adds approximately 1 bar per 10 m. Independent of the lake scenario."
	else:
		var result: Dictionary = BathysLessonDiagram.refraction(angle_deg, from_water)
		var tir: bool = bool(result["tir"])
		readout_titles[0].text = "Incident angle θ₁"
		readout_titles[1].text = "Refracted angle θ₂"
		readout_titles[2].text = "Critical angle · water → air"
		readout_values[0].text = "%.1f°" % angle_deg
		readout_values[1].text = tr("No transmitted ray") if tir else "%.1f°" % float(result["angle"])
		readout_values[1].add_theme_font_size_override("font_size", 14 if tir else 20)
		readout_values[2].text = "%.1f°" % BathysLessonDiagram.critical_angle()
		formula_label.text = "n₁ sin θ₁ = n₂ sin θ₂"
		if tir:
			insight_label.text = "Total internal reflection: the light stays in the water and reflects at the same angle."
		elif from_water:
			insight_label.text = "Water → air: the ray bends away from the normal. Beyond 48.6°, it reflects back into the water."
		else:
			insight_label.text = "Air → water: the ray bends toward the normal. At 0°, it continues straight."
		relevance_label.text = "Looking up underwater, the world above fits inside Snell’s window, a cone about 97° wide. Outside it, the surface acts like a mirror."
		assumptions_label.text = "Model: flat air–water boundary; n = 1.000 in air and 1.333 in water. Angles are measured from the normal (dashed line). Partial reflection below the critical angle is omitted."

func update_science_values() -> void:
	match lesson:
		"dalton":
			title_label.text = "Dalton’s law"
			intro_label.text = "Each gas contributes part of the pressure. Change depth or the mixture and watch the parts add up."
			control_label.text = "Depth"
			slider.tooltip_text = "Depth · Left/Right to adjust"
			control_value.text = "%.1f m" % dalton_depth
			var pressures: Dictionary = BathysLearningModels.partial_pressures(dalton_depth, oxygen_percent, helium_percent)
			for index: int in 4:
				readout_titles[index].text = ["Total pressure", "Oxygen · ppO₂", "Nitrogen · ppN₂", "Helium · ppHe"][index]
				readout_values[index].text = "%.2f bar" % float(pressures[["total", "o2", "n2", "he"][index]])
			formula_label.text = "pᵢ = Fᵢ × P\n\nP = Σpᵢ"
			insight_label.text = tr("Oxygen stays at %.1f%% of the mixture, but at %.1f m its partial pressure is %.2f bar.") % [oxygen_percent, dalton_depth, pressures["o2"]]
			relevance_label.text = "A percentage alone does not describe gas exposure: depth matters too. Compare air and nitrox at the same depth. Nitrogen fills the fraction left after oxygen and helium."
			assumptions_label.text = "Model: ideal, dry O₂/N₂/He mixture; percentages always total 100%. Uses 1 bar at the surface plus 1 bar per 10 m. These are ambient partial pressures, not cylinder pressure or humidified lung gas."
		"henry":
			title_label.text = "Henry’s law"
			intro_label.text = "Higher gas partial pressure raises the equilibrium amount dissolved in a liquid. Give the gas time to move toward that target."
			control_label.text = "Gas partial pressure above the liquid"
			slider.tooltip_text = "Gas partial pressure · Left/Right to adjust"
			control_value.text = "%.1f bar" % gas_pressure
			readout_titles[0].text = "Gas partial pressure"
			readout_titles[1].text = "Equilibrium concentration"
			readout_titles[2].text = "Concentration now"
			readout_values[0].text = "%.1f bar" % gas_pressure
			readout_values[1].text = "%.2f × ref." % BathysLearningModels.equilibrium(gas_pressure)
			readout_values[2].text = "%.2f × ref." % BathysLearningModels.dissolved(gas_pressure, half_times)
			formula_label.text = "Cₑq = k × pgas"
			insight_label.text = "Henry’s law sets the equilibrium target, not the speed. After each half-time, half of the remaining gap to the target is closed in this exchange example."
			relevance_label.text = "This helps explain inert-gas uptake and release during diving. Try a pressure rise, then a pressure drop. The dots represent dissolved molecules; this is not a bubble or decompression-risk model."
			assumptions_label.text = "Model: fixed temperature, gas and liquid; dilute solution. Reference concentration is equilibrium at 1 bar, with k normalised to 1 reference unit/bar. Time uses a separate one-compartment exponential model, starting at that reference."
		"density":
			title_label.text = "Water density & pressure"
			intro_label.text = "Denser water adds pressure faster with depth. Change temperature and salinity to see how much water gives one extra bar."
			control_label.text = "Water temperature"
			slider.tooltip_text = "Water temperature · Left/Right to adjust"
			control_value.text = "%.1f°C" % temperature_c
			var properties: Dictionary = BathysLearningModels.water_properties(temperature_c, salinity)
			readout_titles[0].text = "Density · kg/m³"
			readout_titles[1].text = "Metres per additional bar"
			readout_titles[2].text = "Water pressure at 10 m · bar"
			readout_values[0].text = "%.2f" % float(properties["density"])
			readout_values[1].text = "%.3f m" % float(properties["metres_per_bar"])
			readout_values[2].text = "%.3f" % float(properties["pressure_at_10m"])
			formula_label.text = "Δp = ρgh\n\nh₁bar = 100000 / (ρg)"
			insight_label.text = "Adding salt increases density and reduces metres per bar. Fresh water is densest near 4°C: cooling it below that makes it slightly less dense."
			relevance_label.text = "One bar is not exactly 10 m in every body of water. The dashed line compares fresh water at 20°C, on the same depth scale. The curve shows temperature effects at your selected salinity."
			assumptions_label.text = "Model: app’s EOS-80 surface-density approximation, salinity approximately g/kg; uniform water, no compression or layering. Uses g = 9.80665 m/s² and 1 bar = 100000 Pa. Pressure increments exclude atmospheric pressure."
