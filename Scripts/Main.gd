extends Control

const BG := Color("071c29")
const INK := Color("f5fbf7")
const AQUA := Color("72e9dd")
const AMBER := Color("ffb96f")
const RED := Color("ff6676")
const SETTINGS_PATH := "user://settings.json"

const PLAN_PATH := "user://plan.json"

var language_button: Button
var route_count_label: Label
var settings_dialog: ConfirmationDialog
var settings_inputs: Dictionary = {}
var settings_route_inputs: Dictionary = {}
var left_divider: BathysPanelDivider
var right_divider: BathysPanelDivider
var tank_panel_width: float = 275
var route_panel_width: float = 370
var tank_panel_height: float = 320
var route_panel_height: float = 400
var panel_drag_origin: Vector2 = Vector2.ZERO
var panel_drag_extent: float = 0
var settings_error: Label
var metric_cards: Dictionary = {}
var visible_metrics: Array[String] = ["depthM"]
var metric_grid: GridContainer
var metrics_menu: PopupMenu
var inspection: PanelContainer
var inspection_overlay: Control
var saved_state: String = ""
var save_state_label: Label
var feedback_label: Label
var content_box: BoxContainer
var header_box: HFlowContainer
var bottom_panel: PanelContainer
var playback_controls: Array[Control] = []
var center_panel: PanelContainer
var left_panel: PanelContainer
var right_panel: PanelContainer
var selected_event: int = -1
var inspection_location: Dictionary = {}
var inspection_interpolated: bool = false
var site: BathysSite
var graphs: Array[BathysMetricGraph] = []
var metric_values: Dictionary = {}
var range_gauges: Dictionary = {}
var view_hint: Label
var view_buttons: Dictionary = {}
var plan: Dictionary = {}
var frames: Array[Dictionary] = []
var legs: Array[Dictionary] = []
var undo_stack: Array[String] = []
var redo_stack: Array[String] = []
var map: BathysSatelliteMap
var lake: BathysLakeViewport
var view_container: Control
var view_3d: bool = false
var status_label: Label
var view_label: Label
var metric_label: Label
var telemetry_label: Label
var tank_list: VBoxContainer
var route_list: VBoxContainer
var site_list: VBoxContainer
var tissue_list: VBoxContainer
var tissue_scale_bar: float = 1.5
var graph: BathysMetricGraph
var scrubber: HSlider
var play_button: Button
var speed_picker: OptionButton
var playing: bool = false
var playback_time: float = 0.0
var speed: float = 1.0
var telemetry_elapsed: float = 0.0
var last_shown_index: int = -1
var fps_samples: Array[float] = []
var fps_context: String = "2D"
var fps_logged: Dictionary = {}
var import_callback: JavaScriptObject
var expanded_routes: Dictionary = {}
var expanded_tanks: Dictionary = {}
var tank_readouts: Array[Dictionary] = []
var route_summaries: Array[Label] = []
var route_drop_slots: Array[BathysRouteDropSlot] = []
var route_drag_id: String = ""
var route_drag_position: Vector2 = Vector2.ZERO
var route_drop_boundary: int = -1
var route_refresh_pending: bool = false
var site_readout: Label
var model_readout: Label
var sim_debounce: float = -1.0
var simulation_revision: int = 0
var simulation_busy: bool = false

func _ready() -> void:
	var started: int = Time.get_ticks_msec()
	site = BathysSite.new()
	if not site.load_packaged():
		push_error("Packaged site data could not be loaded.")
		return
	plan = BathysPlan.empty(site)
	plan["name"] = tr(str(plan["name"]))
	plan["limits"] = load_limit_preferences()
	plan["routeDefaults"] = load_route_preferences()
	saved_state = JSON.stringify(plan)
	build_ui()
	I18n.language_changed.connect(_on_language_changed)
	map.site = site
	map.set_waterline(float((plan["environment"] as Dictionary)["waterlineAltitudeNf02M"]))
	refresh_all()
	status_label.text = tr("%s · %d measured cells · %d interpolated cells") % [site.name, site.measured_count, site.interpolated_count]
	print("BATHYS_STARTUP_MS=", Time.get_ticks_msec() - started)
	if OS.has_feature("web"):
		print("BATHYS_PAGE_READY_MS=", JavaScriptBridge.eval("performance.now()", true))
	request_simulation()
	get_viewport().size_changed.connect(adapt_layout)
	call_deferred("adapt_layout")

func _process(delta: float) -> void:
	if not route_drag_id.is_empty():
		update_route_drag(delta)
	if sim_debounce >= 0.0:
		sim_debounce -= delta
		if sim_debounce < 0.0:
			apply_inline_changes(true)
	if playing and not frames.is_empty():
		playback_time = minf(float(frames[-1]["timeS"]), playback_time + delta * speed)
		show_frame(playback_time)
		if playback_time >= float(frames[-1]["timeS"]):
			playing = false
			play_button.text = "PLAY"
	telemetry_elapsed += delta
	if telemetry_elapsed >= 1.0 and telemetry_label != null:
		var fps: float = Engine.get_frames_per_second()
		telemetry_label.text = "%.0f FPS" % fps
		if not fps_logged.has(fps_context):
			fps_samples.append(fps)
			if fps_samples.size() >= 5:
				var total: float = 0.0
				for sample: float in fps_samples:
					total += sample
				print("BATHYS_FPS_", fps_context, "_AVG=", total / fps_samples.size())
				fps_logged[fps_context] = true
		telemetry_elapsed = 0.0

func report_web_memory(context: String) -> void:
	if not OS.has_feature("web"):
		return
	var bytes: Variant = JavaScriptBridge.eval("typeof engine !== 'undefined' && engine.rtenv ? engine.rtenv.HEAPU8.buffer.byteLength : 0", true)
	if bytes is float or bytes is int:
		print("BATHYS_WASM_MEMORY_", context, "_MB=", float(bytes) / 1048576.0)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).ctrl_pressed:
		var key: InputEventKey = event as InputEventKey
		if key.keycode == KEY_Z and not key.shift_pressed:
			undo()
		elif key.keycode == KEY_Y or (key.keycode == KEY_Z and key.shift_pressed):
			redo()

func make_label(value: String, font_size: int = 14, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_color_override("font_color", color)
	node.add_theme_font_size_override("font_size", font_size)
	return node

func make_button(value: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = value
	node.custom_minimum_size.y = 31
	node.focus_mode = Control.FOCUS_ALL
	node.pressed.connect(callback)
	return node

func clear_children(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

func icon_button(icon: String, tooltip: String, callback: Callable) -> Button:
	var node: Button = make_button("", callback)
	node.icon = load("res://Assets/Icons/" + icon + ".svg") as Texture2D
	node.custom_minimum_size = Vector2(34, 31)
	node.tooltip_text = tooltip
	return node

func build_ui() -> void:
	theme = BathysUiStyle.create_theme()
	var backdrop := ColorRect.new()
	backdrop.color = BG
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var page_scroll := ScrollContainer.new()
	page_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(page_scroll)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	page_scroll.add_child(root)
	var header: PanelContainer = BathysUiStyle.panel(BG, 12)
	header.custom_minimum_size.y = 62
	root.add_child(header)
	var heading := HFlowContainer.new()
	header_box = heading
	header.add_child(heading)
	var logo := TextureRect.new()
	logo.name = "BathysLogo"
	logo.texture = load("res://Assets/Brand/bathys-256.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.custom_minimum_size = Vector2(40, 40)
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.tooltip_text = "Bathys · Lac des Îles"
	heading.add_child(logo)
	heading.add_child(make_label("BATHYS", 24))
	heading.add_child(make_label("/  LAC DES ÎLES", 14, AQUA))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(spacer)
	var identity := VBoxContainer.new()
	identity.custom_minimum_size.x = 260
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(identity)
	var plan_name := LineEdit.new()
	plan_name.text = str(plan.get("name", "Untitled scenario"))
	plan_name.name = "PlanName"
	plan_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	plan_name.placeholder_text = tr("Scenario name")
	plan_name.text_changed.connect(func(value: String) -> void: plan["name"] = value; update_saved_state())
	identity.add_child(plan_name)
	save_state_label = make_label("New scenario · Load opens plan files", 12, BathysUiStyle.MUTED)
	identity.add_child(save_state_label)
	for action: Array in [["folder", "LOAD", "Open a plan file or the saved plan on this device", show_load_menu], ["save", "SAVE", "Save the plan as a JSON file", export_plan], ["image", "EXPORT", "Export the current map view as JPG", export_map_jpg]]:
		var button := make_button(str(action[1]), action[3])
		button.name = str(action[1]).capitalize() + "Action"
		button.icon = load("res://Assets/Icons/" + str(action[0]) + ".svg")
		button.tooltip_text = str(action[2])
		heading.add_child(button)
	heading.add_child(icon_button("settings", "Settings", open_settings))
	language_button = icon_button("flag-" + I18n.language, "Language: English", show_language_menu)
	language_button.name = "LanguageSelector"
	heading.add_child(language_button)
	update_language_button()
	var content := BoxContainer.new()
	content_box = content
	content.add_theme_constant_override("separation", 0)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)
	var tanks_panel: PanelContainer = BathysUiStyle.panel()
	left_panel = tanks_panel
	tanks_panel.custom_minimum_size.x = 290
	content.add_child(tanks_panel)
	tank_list = scroll_column(tanks_panel)
	left_divider = create_panel_divider(true)
	content.add_child(left_divider)
	var center: PanelContainer = BathysUiStyle.panel()
	center_panel = center
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(center)
	var center_stack: VBoxContainer = BathysUiStyle.column(center, 8)
	var view_bar := HBoxContainer.new()
	center_stack.add_child(view_bar)
	var view_title := make_label("DIVE SITE MODEL", 16)
	view_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_title.visible = false
	view_bar.add_child(view_title)
	view_label = make_label("", 11, AQUA)
	view_label.visible = false
	view_bar.add_child(view_label)
	var group := ButtonGroup.new()
	for mode: String in ["3D", "SATELLITE", "BATHYMETRY"]:
		var button: Button
		if mode == "3D":
			button = make_button(mode, show_3d)
		elif mode == "SATELLITE":
			button = make_button("2D SATELLITE", func() -> void: set_bathymetry(false))
		else:
			button = make_button("2D BATHYMETRY", func() -> void: set_bathymetry(true))
		button.toggle_mode = true
		button.button_group = group
		button.add_theme_font_size_override("font_size", 11)
		view_buttons[mode] = button
		view_bar.add_child(button)
	view_bar.add_child(icon_button("home", "Reset camera / map", home_view))
	var view_frame: PanelContainer = BathysUiStyle.panel(Color("09232d"), 0)
	view_frame.clip_contents = true
	view_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_stack.add_child(view_frame)
	view_container = Control.new()
	view_container.clip_contents = true
	view_container.custom_minimum_size = Vector2(150, 120)
	view_frame.add_child(view_container)
	map = BathysSatelliteMap.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.poi_clicked.connect(on_poi_clicked)
	map.terrain_clicked.connect(on_terrain_clicked)
	map.pick_rejected.connect(func(message: String) -> void: status_label.text = message)
	view_container.add_child(map)
	var legend := HBoxContainer.new()
	center_stack.add_child(legend)
	for entry: Array in [["0–10", "54b9b1"], ["10–20", "379f9d"], ["20–30", "1b7083"], ["30–40 m", "154966"]]:
		legend.add_child(make_label(str(entry[0]), 11, Color(str(entry[1]))))
	var north := make_label("N  ·  TRUE BEARINGS", 10, BathysUiStyle.MUTED)
	north.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	north.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	legend.add_child(north)
	view_hint = BathysUiStyle.wrapped("", 11)
	center_stack.add_child(view_hint)
	right_divider = create_panel_divider(false)
	content.add_child(right_divider)
	var right: PanelContainer = BathysUiStyle.panel(BathysUiStyle.PANEL, 4)
	right_panel = right
	right.custom_minimum_size.x = 390
	content.add_child(right)
	var tabs := TabContainer.new()
	right.add_child(tabs)
	route_list = scroll_column(tabs, "ROUTE")
	bind_route_drop_target(route_list)
	site_list = scroll_column(tabs, "SITE")
	tissue_list = scroll_column(tabs, "TISSUES")
	var bottom: PanelContainer = BathysUiStyle.panel(BG, 9)
	bottom_panel = bottom
	bottom.custom_minimum_size.y = 350
	root.add_child(bottom)
	var playback: VBoxContainer = BathysUiStyle.column(bottom, 6)
	var live_heading := HFlowContainer.new()
	feedback_label = BathysUiStyle.wrapped("", 14, AMBER)
	feedback_label.visible = false
	playback.add_child(feedback_label)
	playback.add_child(live_heading)
	live_heading.add_child(make_label("LIVE DIVE PHYSIOLOGY", 15))
	status_label = make_label("", 11, BathysUiStyle.MUTED)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	live_heading.add_child(status_label)
	telemetry_label = make_label("", 11, AQUA)
	telemetry_label.visible = false
	live_heading.add_child(telemetry_label)
	var metrics_row := HBoxContainer.new()
	playback.add_child(metrics_row)
	var cards := GridContainer.new()
	metric_grid = cards
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metrics_row.add_child(cards)
	var add_metric := make_button("+", func() -> void: open_metrics_menu())
	add_metric.tooltip_text = "Choose physiology readouts"
	add_metric.custom_minimum_size.x = 40
	add_metric.size_flags_vertical = Control.SIZE_FILL
	metrics_row.add_child(add_metric)
	metrics_menu = PopupMenu.new()
	add_child(metrics_menu)
	metrics_menu.id_pressed.connect(toggle_metric)
	for entry: Array in [["DEPTH", "depthM", "m"], ["AMBIENT", "ambientBar", "bar abs"], ["LEADING GF", "leadingGf", "%"], ["NDL", "ndlS", "min"], ["TTS", "ttsS", "min"], ["CEILING", "ceilingM", "m"], ["CNS", "cnsPercent", "%"], ["ppO₂", "ppO2Bar", "bar"], ["GAS DENSITY", "densityGPerL", "g/L"], ["NARCOSIS · END", "endM", "m"], ["OTU", "otu", "OTU"], ["WATER TEMPERATURE", "waterTempC", "°C"], ["APPLIED GF", "currentGf", "%"], ["CONTROLLING TISSUE", "controllingCompartment", "compartment"], ["FIRST STOP", "firstStopM", "m"], ["ACTIVE GAS", "tankId", ""], ["GAS USED", "usedSurfaceL", "surface L"]]:
		var card: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 6)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards.add_child(card)
		metric_cards[str(entry[1])] = card
		card.visible = str(entry[1]) in visible_metrics
		var stack: VBoxContainer = BathysUiStyle.column(card, 1)
		var metric_title := HBoxContainer.new()
		stack.add_child(metric_title)
		var caption := make_label(str(entry[0]), 12, BathysUiStyle.MUTED)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		metric_title.add_child(caption)
		var remove := make_button("×", func() -> void: toggle_metric(metric_cards.keys().find(str(entry[1]))))
		remove.tooltip_text = "Hide readout"
		remove.custom_minimum_size = Vector2(18, 16)
		remove.add_theme_font_size_override("font_size", 12)
		for state: String in ["normal", "hover", "pressed", "focus"]:
			remove.add_theme_stylebox_override(state, BathysUiStyle.box(Color(0, 0, 0, 0), AQUA if state != "normal" else Color(0, 0, 0, 0), 3, 0))
		metric_title.add_child(remove)
		var value := make_label("—", 21, AQUA)
		value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var reading := HBoxContainer.new()
		reading.add_theme_constant_override("separation", 5)
		stack.add_child(reading)
		reading.add_child(value)
		var unit := make_label(str(entry[2]), 11, BathysUiStyle.MUTED)
		unit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		reading.add_child(unit)
		metric_values[str(entry[1])] = value
		if str(entry[1]) in ["ppO2Bar", "densityGPerL", "endM"]:
			var gauge := BathysGasRangeGauge.new()
			if entry[1] == "ppO2Bar":
				gauge.working_min = 0.16
				gauge.working_max = 1.4
				gauge.rest_max = 1.6
				gauge.chart_max = 1.9
				gauge.min_caption = "0.16"
				gauge.working_caption = "1.4"
				gauge.rest_caption = "1.6"
			elif entry[1] == "densityGPerL":
				gauge.working_max = 5.2
				gauge.rest_max = 6.2
				gauge.chart_max = 7.2
				gauge.working_caption = "5.2"
				gauge.rest_caption = "6.2"
			else:
				gauge.working_max = 30
				gauge.rest_max = 30
				gauge.chart_max = 40
				gauge.working_caption = "30"
			stack.add_child(gauge)
			range_gauges[str(entry[1])] = gauge
			card.tooltip_text = "Reference display guidance only. Exertion and individual response are not measured."
	var controls := HBoxContainer.new()
	playback.add_child(controls)
	playback_controls.append(controls)
	play_button = make_button("PLAY", toggle_play)
	play_button.icon = load("res://Assets/Icons/play.svg")
	controls.add_child(play_button)
	metric_label = make_label("00:00 / 00:00", 13)
	controls.add_child(metric_label)
	scrubber = HSlider.new()
	scrubber.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrubber.step = 0.01
	scrubber.value_changed.connect(seek)
	controls.add_child(scrubber)
	speed_picker = OptionButton.new()
	for item: String in ["0.5×", "1×", "2×", "4×", "8×"]:
		speed_picker.add_item(item)
	speed_picker.select(1)
	speed_picker.item_selected.connect(func(index: int) -> void: speed = [0.5, 1.0, 2.0, 4.0, 8.0][index])
	controls.add_child(speed_picker)
	var plot_buttons := HFlowContainer.new()
	playback.add_child(plot_buttons)
	playback_controls.append(plot_buttons)
	plot_buttons.add_child(make_label("PLOTS", 11, BathysUiStyle.MUTED))
	var plot_scroll := ScrollContainer.new()
	plot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	plot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	plot_scroll.custom_minimum_size.y = 145
	playback.add_child(plot_scroll)
	playback_controls.append(plot_scroll)
	var plot_stack: VBoxContainer = BathysUiStyle.column(plot_scroll, 8)
	for metric: String in ["depth", "tts", "ndl", "cns", "otu"]:
		var chart := BathysMetricGraph.new()
		chart.metric = metric
		chart.custom_minimum_size.y = 130
		chart.seek_requested.connect(seek)
		plot_stack.add_child(chart)
		graphs.append(chart)
		chart.visible = metric == "depth"
		var jump := make_button(metric.to_upper(), func() -> void:
			for item: BathysMetricGraph in graphs:
				item.visible = item.metric == metric)
		jump.add_theme_font_size_override("font_size", 11)
		plot_buttons.add_child(jump)
	graph = graphs[0]
	var warning := make_label("EDUCATIONAL SOFTWARE ONLY · Do not use for real dive decisions. Survey datum and water level require confirmation. © swisstopo SWISSIMAGE", 11, AMBER)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(warning)
	set_bathymetry(false)
	set_playback_available(false)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.addEventListener('beforeunload', function(e) { if(window.bathysHasChanges) { e.preventDefault(); e.returnValue = ''; } });", true)

func scroll_column(parent: Node, title: String = "") -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title if not title.is_empty() else "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	return BathysUiStyle.column(scroll, 8)

func set_bathymetry(enabled: bool) -> void:
	view_3d = false
	map.show()
	if lake != null:
		lake.hide()
		lake.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	map.show_bathymetry = enabled
	view_label.text = ""
	update_view_buttons("BATHYMETRY" if enabled else "SATELLITE")
	view_hint.text = "Drag to pan · Wheel to zoom · Click a point to inspect"
	fps_context = "2D"
	fps_samples.clear()

func show_3d() -> void:
	if lake == null:
		var started: int = Time.get_ticks_msec()
		lake = BathysLakeViewport.new()
		lake.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lake.poi_clicked.connect(on_poi_clicked)
		lake.terrain_clicked.connect(on_terrain_clicked)
		lake.pick_rejected.connect(func(message: String) -> void: status_label.text = message)
		view_container.add_child(lake)
		lake.load_site(site, float((plan["environment"] as Dictionary)["waterlineAltitudeNf02M"]))
		var compass := BathysCompass.new()
		compass.lake = lake
		lake.hud.add_child(compass)
		lake.set_route(route_array())
		if not frames.is_empty():
			var frame: Dictionary = current_frame()
			lake.set_diver(float(frame["latitudeDeg"]), float(frame["longitudeDeg"]), float(frame["depthM"]))
		print("BATHYS_TERRAIN_LOAD_MS=", Time.get_ticks_msec() - started)
	report_web_memory("3D")
	view_3d = true
	fps_context = "3D"
	fps_samples.clear()
	map.hide()
	lake.show()
	lake.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view_label.text = ""
	update_view_buttons("3D")
	view_hint.text = "Drag to orbit · Right drag to pan · Wheel to zoom · Click to inspect"

func home_view() -> void:
	if view_3d and lake != null:
		lake.reset_view()
	else:
		map.reset_view()

func update_view_buttons(selected: String) -> void:
	for mode: String in view_buttons:
		(view_buttons[mode] as Button).set_pressed_no_signal(mode == selected)

func route_array() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for item: Variant in plan.get("waypoints", []):
		output.append(item as Dictionary)
	return output

func refresh_all() -> void:
	map.set_route(route_array())
	if lake != null:
		lake.set_route(route_array())
	refresh_route()
	refresh_site()
	refresh_tanks()
	refresh_tissues()
	refresh_vitals()

func refresh_route() -> void:
	if not route_drag_id.is_empty():
		route_refresh_pending = true
		return
	route_drop_slots.clear()
	route_list.add_theme_constant_override("separation", 0)
	clear_children(route_list)
	route_summaries.clear()
	route_list.add_child(make_label("ROUTE TIMELINE", 16))
	route_list.add_child(BathysUiStyle.wrapped("Inspect a map point, then choose Add waypoint. Use + between events to insert a hold or gas switch. The route starts at Dive entrance. Ctrl+Z undo · Ctrl+Y redo."))
	var history := HBoxContainer.new()
	route_list.add_child(history)
	history.add_child(icon_button("undo", "Undo · Ctrl+Z", undo))
	history.add_child(icon_button("redo", "Redo · Ctrl+Y", redo))
	var route: Array = plan.get("waypoints", []) as Array
	var switches: int = 0
	for item: Variant in route:
		if (item as Dictionary).get("kind") == "switch":
			switches += 1
	route_count_label = make_label(BathysI18n.text("%d waypoints / holds · %d gas switches") % [route.size()-switches, switches], 11, BathysUiStyle.MUTED)
	history.add_child(route_count_label)
	if route.is_empty():
		route_list.add_child(BathysUiStyle.wrapped("Your route is empty. Inspect the map to choose your first destination."))
	add_insertion_slot(0)
	for index: int in route.size():
		var waypoint: Dictionary = route[index] as Dictionary
		var kind: String = str(waypoint.get("kind", "travel"))
		var card: PanelContainer = BathysUiStyle.panel(Color("123d47") if kind == "switch" else BathysUiStyle.CARD, 7)
		if index == selected_event:
			card.add_theme_stylebox_override("panel", BathysUiStyle.box(Color("44323a"), AMBER))
		card.name = "Route_" + str(index)
		bind_route_drop_target(card)
		route_list.add_child(card)
		var row: VBoxContainer = BathysUiStyle.column(card, 5)
		var header := HBoxContainer.new()
		row.add_child(header)
		var event_icon := TextureRect.new()
		event_icon.name = "EventTypeIcon"
		var icon_name: String = {"travel": "event-swim", "hold": "event-clock", "switch": "event-gas-switch"}.get(kind, "event-swim")
		event_icon.texture = load("res://Assets/Icons/" + icon_name + ".svg")
		event_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		event_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		event_icon.custom_minimum_size = Vector2(28, 28)
		event_icon.tooltip_text = {"travel": "Waypoint", "hold": "Hold", "switch": "Gas switch"}.get(kind, "Waypoint")
		header.add_child(event_icon)
		var details := VBoxContainer.new()
		var waypoint_id: String = str(waypoint.get("id", index))
		details.name = "InlineEditor"
		details.visible = bool(expanded_routes.get(waypoint_id, false))
		var name_input: LineEdit = inline_name(header, waypoint)
		name_input.editable = details.visible
		details.visibility_changed.connect(func() -> void: name_input.editable = details.visible)
		header.add_child(editor_toggle(details, expanded_routes, waypoint_id, waypoint, false, name_input))
		var handle := BathysRouteDragHandle.new()
		handle.name = "DragHandle"
		handle.event_id = waypoint_id
		handle.owner_id = get_instance_id()
		handle.event_name = str(waypoint.get("name", ""))
		handle.event_icon = event_icon.texture
		handle.source_card = card
		handle.started.connect(func(id: String) -> void:
			route_drag_id = id
			route_drag_position = handle.get_global_rect().get_center())
		handle.finished.connect(func() -> void: call_deferred("finish_route_drag"))
		handle.keyboard_move.connect(func(id: String, direction: int) -> void:
			var source: int = route_index_by_id(id)
			if source >= 0:
				move_route(source, direction)
				call_deferred("focus_route_handle", id))
		header.add_child(handle)
		header.add_child(icon_button("trash", "Remove event", func() -> void: remove_route(index)))
		var summary: Label = BathysUiStyle.wrapped("", 11)
		row.add_child(summary)
		route_summaries.append(summary)
		add_insertion_slot(index + 1)
		row.add_child(details)
		if kind == "switch":
			details.add_child(make_label("GAS", 10, BathysUiStyle.MUTED))
			gas_selector(details, waypoint, "tankId")
			bind_route_card_drop_targets(card)
			continue
		var grid: GridContainer = inline_grid(details)
		if kind == "travel":
			inline_number(grid, "targetDepthM", "TARGET DEPTH", waypoint, 0, 100, 0.1, "m")
			inline_number(grid, "speedMPerMin", "SWIM SPEED", waypoint, 1, 60, 0.5, "m/min")
		else:
			details.add_child(BathysUiStyle.wrapped("At the preceding position and depth.", 11))
			inline_number(grid, "holdSeconds", "DURATION", waypoint, 1, 7200, 30, "s")
		inline_number(grid, "sacLPerMin", "SAC", waypoint, 1, 100, 0.5, "L/min")
		if kind == "travel":
			var position := VBoxContainer.new()
			position.visible = false
			details.add_child(make_button("WGS84 POSITION", func() -> void: position.visible = not position.visible))
			details.add_child(position)
			var coordinates: GridContainer = inline_grid(position)
			inline_number(coordinates, "latitudeDeg", "LATITUDE N", waypoint, -90, 90, 0.00000001, "°")
			inline_number(coordinates, "longitudeDeg", "LONGITUDE E", waypoint, -180, 180, 0.00000001, "°")
		bind_route_card_drop_targets(card)
	update_route_summaries()

func update_route_summaries() -> void:
	var route: Array = plan.get("waypoints", []) as Array
	var active: String = tank_name(str(plan.get("initialTankId", "")))
	for index: int in mini(route.size(), route_summaries.size()):
		var waypoint: Dictionary = route[index] as Dictionary
		var kind: String = str(waypoint.get("kind", "travel"))
		var summary: String
		if kind == "switch":
			active = tank_name(str(waypoint.get("tankId", "")))
			var depth: float = float(legs[index]["startDepthM"]) if index < legs.size() else 0.0
			summary = BathysI18n.text("%s at %.1f m") % [active, depth]
		elif index < legs.size():
			var leg: Dictionary = legs[index]
			summary = BathysI18n.text("%.1f m · %.1f min") % [float(leg["targetDepthM"]), float(leg["durationS"])/60] if kind == "hold" else BathysI18n.text("%.0f m · %03.0f° true · %.1f to %.1f m · %.1f min") % [float(leg["distanceM"]), float(leg["bearingTrueDeg"]), float(leg["startDepthM"]), float(leg["targetDepthM"]), float(leg["durationS"])/60]
			summary += BathysI18n.text("\n%s · SAC %.0f L/min") % [active, float(waypoint.get("sacLPerMin", 18))]
			if kind == "travel":
				summary += " · %.0f m/min" % float(waypoint.get("speedMPerMin", 12))
		else:
			summary = BathysI18n.text("Target depth %.1f m") % float(waypoint.get("targetDepthM", 0))
		route_summaries[index].text = summary

func tank_name(tank_id: String) -> String:
	for entry: Variant in plan.get("tanks", []):
		var tank: Dictionary = entry as Dictionary
		if str(tank.get("id", "")) == tank_id:
			return str(tank.get("name", tank_id))
	return tank_id

func refresh_site() -> void:
	clear_children(site_list)
	site_list.add_child(make_label("SITE & ENVIRONMENT", 16))
	site_list.add_child(BathysUiStyle.wrapped("NavSurf 2015 · 0.5 m measured survey. Elevations use NF02; depth is relative to the editable waterline."))
	var env: Dictionary = plan.get("environment", {}) as Dictionary
	site_list.add_child(make_label("WATER & ATMOSPHERE", 12, AQUA))
	site_readout = BathysUiStyle.wrapped("", 11)
	site_list.add_child(site_readout)
	model_readout = BathysUiStyle.wrapped("", 11)
	update_site_readout()
	build_environment_editor(site_list, env)

func refresh_tanks() -> void:
	clear_children(tank_list)
	tank_readouts.clear()
	tank_list.add_child(make_label("TANKS · LIVE SPG", 16))
	tank_list.add_child(BathysUiStyle.wrapped("Gauge pressure · red arc marks reserve. Gas metrics follow playback depth. MOD uses the working ppO₂ limit in Settings.", 11))
	if (plan["tanks"] as Array).is_empty():
		tank_list.add_child(BathysUiStyle.wrapped("No gases selected. Add a tank and enter its mix and pressures to simulate your route."))
	tank_list.add_child(make_label("START GAS", 10, BathysUiStyle.MUTED))
	if not (plan["tanks"] as Array).is_empty():
		gas_selector(tank_list, plan, "initialTankId")
	tank_list.add_child(make_button("+ ADD TANK", add_tank))
	var tanks: Array = plan["tanks"] as Array
	for index: int in tanks.size():
		var tank: Dictionary = tanks[index] as Dictionary
		var tank_id: String = str(tank["id"])
		var card: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 9)
		card.name = "Tank_" + str(index)
		tank_list.add_child(card)
		var column: VBoxContainer = BathysUiStyle.column(card, 5)
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 4)
		column.add_child(header)
		var glyph := BathysTankGlyph.new()
		glyph.oxygen_percent = float(tank.get("o2", 0.21))*100
		header.add_child(glyph)
		var title: VBoxContainer = BathysUiStyle.column(header, 3)
		var name_input: LineEdit = inline_name(title, tank, true)
		var mix: Label = make_label("", 10, AQUA)
		title.add_child(mix)
		var details := VBoxContainer.new()
		details.name = "InlineEditor"
		details.visible = bool(expanded_tanks.get(tank_id, false))
		name_input.editable = details.visible
		details.visibility_changed.connect(func() -> void: name_input.editable = details.visible)
		title.add_child(editor_toggle(details, expanded_tanks, tank_id, tank, true, name_input))
		var dial := BathysSpgDial.new()
		header.add_child(dial)
		var metrics: Label = BathysUiStyle.wrapped("", 10)
		column.add_child(metrics)
		column.add_child(details)
		var grid: GridContainer = inline_grid(details)
		inline_number(grid, "volumeL", "VOLUME", tank, 1, 40, 0.5, "L")
		inline_number(grid, "startGaugeBar", "START SPG", tank, 1, 400, 1, "bar g")
		inline_number(grid, "reserveGaugeBar", "RESERVE", tank, 0, 399, 1, "bar g")
		inline_number(grid, "o2", "O₂", tank, 0, 100, 1, "%", 100)
		var nitrogen := inline_number(grid, "n2", "N₂ (BALANCE)", tank, 0, 100, 1, "%", 100)
		nitrogen.editable = false
		inline_number(grid, "he", "He", tank, 0, 100, 1, "%", 100)
		details.add_child(BathysUiStyle.wrapped("Set oxygen and helium; nitrogen fills the remaining percentage automatically.", 10))
		var remove := icon_button("trash", "Remove tank", func() -> void: remove_tank(index))
		remove.size_flags_horizontal = Control.SIZE_SHRINK_END
		details.add_child(remove)
		tank_readouts.append({"mix":mix, "glyph":glyph, "dial":dial, "metrics":metrics})
	update_tank_readouts()

func update_tank_readouts() -> void:
	var frame: Dictionary = current_frame()
	var tanks: Array = plan.get("tanks", []) as Array
	for index: int in mini(tanks.size(), tank_readouts.size()):
		var tank: Dictionary = tanks[index] as Dictionary
		var nodes: Dictionary = tank_readouts[index]
		var mix: Label = nodes["mix"] as Label
		mix.text = "O₂ %.0f · N₂ %.0f · He %.0f" % [float(tank.get("o2", 0.21))*100, float(tank.get("n2", 0.79))*100, float(tank.get("he", 0))*100]
		var glyph: BathysTankGlyph = nodes["glyph"] as BathysTankGlyph
		glyph.oxygen_percent = float(tank.get("o2", 0.21))*100
		glyph.queue_redraw()
		var dial: BathysSpgDial = nodes["dial"] as BathysSpgDial
		dial.maximum_bar = maxf(200, ceilf(float(tank.get("startGaugeBar", 200))/50)*50)
		dial.reserve_bar = float(tank.get("reserveGaugeBar", 50))
		var gauge: float = float(tank.get("startGaugeBar", 200))
		if frame.has("tankGaugeBar") and index < (frame["tankGaugeBar"] as Array).size() and sim_debounce < 0:
			gauge = float((frame["tankGaugeBar"] as Array)[index])
		dial.set_pressure(gauge)
		var metrics: Label = nodes["metrics"] as Label
		var total: float = float(tank.get("o2",0)) + float(tank.get("n2",0)) + float(tank.get("he",0))
		if absf(total-1)>0.0001:
			metrics.text = BathysI18n.text("Balance O₂, N₂ and He to 100%.")
			continue
		if frame.is_empty():
			metrics.text = "Plan inputs need attention."
			continue
		var env: Dictionary = plan["environment"] as Dictionary
		var ambient: float = float(frame["ambientBar"])
		var temperature: float = float(frame["waterTempC"])
		var working_pp: float = float(BathysPlan.limits_for(plan)["ppO2WorkingMax"])
		var mod_pressure: float = working_pp / maxf(0.001, float(tank.get("o2", 0.21)))
		var mod_text: String = ">150" if mod_pressure > BathysPhysics.ambient_bar(env, 150) else "%.0f" % BathysPhysics.depth_at_bar(env, mod_pressure)
		metrics.text = BathysI18n.text("ppO₂ %.2f · ppN₂ %.2f bar\nMOD%s %s m · density %.1f g/L · END %.0f m%s") % [float(tank.get("o2",0.21))*ambient, float(tank.get("n2",0.79))*ambient, " (%.2f)" % working_pp, mod_text, BathysPhysics.gas_density(tank,ambient,temperature), BathysPhysics.end_m(tank,ambient), tr(" · ACTIVE") if tank["id"]==frame.get("tankId") else ""]
	# Keep gas names current without replacing a focused selector.
	for selector: Node in find_children("*", "OptionButton", true, false):
		var choice: OptionButton = selector as OptionButton
		if choice.name not in ["tankId", "initialTankId"]:
			continue
		for i: int in choice.item_count:
			choice.set_item_text(i, tank_name(str(choice.get_item_metadata(i))))

func build_environment_editor(parent: Node, env: Dictionary) -> void:
	var grid: GridContainer = inline_grid(parent)
	inline_number(grid, "waterlineAltitudeNf02M", "WATERLINE", env, 0, 3000, 0.01, "m NF02")
	inline_number(grid, "salinityGPerKg", "SALINITY", env, 0, 40, 0.5, "g/kg")
	inline_number(grid, "surfaceTempC", "SURFACE WATER", env, 0, 40, 0.5, "°C")
	inline_number(grid, "tempDropCPerM", "TEMP DROP", env, 0, 2, 0.01, "°C/m")
	inline_number(grid, "minTempC", "MIN WATER", env, 0, 40, 0.5, "°C")
	parent.add_child(BathysUiStyle.wrapped("478.50 m NF02 is an illustrative reference, not a measured lake level. Waterline controls both survey depth and ISA surface pressure. Density uses the UNESCO model.", 11))
	parent.add_child(make_label("DECOMPRESSION SETTINGS", 12, AQUA))
	parent.add_child(model_readout)
	var deco: GridContainer = inline_grid(parent)
	inline_number(deco, "gfLow", "GF LOW", plan, 1, 100, 1, "%", 100)
	inline_number(deco, "gfHigh", "GF HIGH", plan, 1, 100, 1, "%", 100)
	inline_number(deco, "descentMPerMin", "DESCENT", plan, 1, 40, 0.5, "m/min")
	inline_number(deco, "ascentMPerMin", "ASCENT", plan, 1, 30, 0.5, "m/min")

func update_site_readout() -> void:
	if not is_instance_valid(site_readout):
		return
	var env: Dictionary = plan["environment"] as Dictionary
	if is_instance_valid(model_readout):
		model_readout.text = BathysI18n.text("ZH-L16C · GF %.0f / %.0f\nAscent %.1f m/min · descent %.1f m/min") % [float(plan["gfLow"])*100,float(plan["gfHigh"])*100,float(plan["ascentMPerMin"]),float(plan["descentMPerMin"])]
	site_readout.text = BathysI18n.text("Surface pressure  %.5f bar absolute\nDensity at 0 / 20 m  %.1f / %.1f kg/m³\nMetres per bar at 0 / 20 m  %.2f / %.2f") % [BathysPhysics.surface_bar(env), BathysPhysics.water_density(env,0), BathysPhysics.water_density(env,20), 100000/(BathysPhysics.water_density(env,0)*BathysPhysics.G), 100000/(BathysPhysics.water_density(env,20)*BathysPhysics.G)]

func remove_tank(index: int) -> void:
	var tanks: Array = plan["tanks"] as Array
	var tank: Dictionary = tanks[index] as Dictionary
	var tank_id: String = str(tank["id"])
	if tank_id == str(plan["initialTankId"]) and tanks.size() > 1:
		status_label.text = "Choose another starting gas before removing this tank."
		return
	for item: Variant in plan["waypoints"]:
		if str((item as Dictionary).get("tankId", "")) == tank_id:
			status_label.text = "Reassign gas switches before removing this tank."
			return
	snapshot()
	tanks.remove_at(index)
	if str(plan["initialTankId"]) == tank_id:
		plan["initialTankId"] = (tanks[0] as Dictionary)["id"] if not tanks.is_empty() else ""
	changed()

func refresh_tissues() -> void:
	clear_children(tissue_list)
	tissue_list.add_child(make_label("ZH-L16C · 16 TISSUES", 16))
	tissue_list.add_child(BathysUiStyle.wrapped("One shared pressure scale. N₂ turquoise · He violet · amber tick: current GF limit. Trends compare the preceding second.", 11))
	var frame: Dictionary = current_frame()
	if frame.is_empty():
		return
	var n2: PackedFloat64Array = frame["tissueN2Bar"] as PackedFloat64Array
	var he: PackedFloat64Array = frame["tissueHeBar"] as PackedFloat64Array
	var ambient: float = float(frame["ambientBar"])
	var gf: float = float(frame["currentGf"])
	var index: int = BathysSimulation.frame_index_at(frames, playback_time)
	var previous_index: int = index - 1
	while previous_index >= 0 and float(frames[previous_index]["timeS"]) >= float(frame["timeS"]) - 1e-9:
		previous_index -= 1
	var previous: Dictionary = frames[previous_index] if previous_index >= 0 else frame
	var prior_n2: PackedFloat64Array = previous["tissueN2Bar"] as PackedFloat64Array
	var prior_he: PackedFloat64Array = previous["tissueHeBar"] as PackedFloat64Array
	for i: int in 16:
		var limit: float = BathysTissue.allowed_inert(i, n2[i], he[i], ambient, clampf(gf, 0.001, 1.0))
		var tissue_card: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 6)
		tissue_list.add_child(tissue_card)
		var tissue_row: VBoxContainer = BathysUiStyle.column(tissue_card, 3)
		var gases := HBoxContainer.new()
		gases.add_theme_constant_override("separation", 4)
		tissue_row.add_child(gases)
		gases.add_child(make_label("%02d · N₂ %.3f" % [i+1,n2[i]], 11, AQUA))
		add_trend_arrow(gases, n2[i]-prior_n2[i], AQUA)
		gases.add_child(make_label("He %.3f" % he[i], 11, Color("b5a3f3")))
		add_trend_arrow(gases, he[i]-prior_he[i], Color("b5a3f3"))
		var limit_label := make_label("GF %.0f%% %.2f bar" % [gf*100,limit], 10, AMBER)
		limit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		limit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		gases.add_child(limit_label)
		var bar := BathysTissueBar.new()
		bar.n2_bar = n2[i]
		bar.he_bar = he[i]
		bar.limit_bar = limit
		bar.scale_max_bar = tissue_scale_bar
		tissue_row.add_child(bar)

func add_trend_arrow(parent: Node, delta: float, color: Color) -> void:
	var arrow := BathysTrendArrow.new()
	arrow.trend = 1 if delta>1e-6 else (-1 if delta < -1e-6 else 0)
	arrow.ink = color if arrow.trend >= 0 else Color("8db9f3")
	arrow.tooltip_text = "Increasing" if arrow.trend>0 else ("Decreasing" if arrow.trend<0 else "Unchanged")
	parent.add_child(arrow)

func refresh_vitals() -> void:
	update_gas_gauges()
	var frame: Dictionary = current_frame()
	for key: String in metric_values:
		var label: Label = metric_values[key] as Label
		var value: Variant = frame.get(key)
		if value == null:
			label.text = "99+" if key == "ndlS" and not frame.is_empty() and float(frame.get("depthM", 0)) >= 0.1 else "—"
		elif key == "ndlS":
			label.text = "—" if float(frame.get("depthM", 0)) < 0.1 else "%.0f" % (float(value) / 60)
		elif key == "ttsS":
			label.text = "%.1f" % (float(value) / 60)
		elif key in ["leadingGf", "currentGf"]:
			label.text = "%.0f" % maxf(0, float(value)*100)
		elif key == "tankId":
			label.text = tank_name(str(value))
		elif key == "controllingCompartment":
			label.text = "%d" % int(value)
		else:
			label.text = ("%.2f" if key in ["ambientBar", "ppO2Bar"] else "%.1f") % float(value)
		if range_gauges.has(key):
			var gauge: BathysGasRangeGauge = range_gauges[key] as BathysGasRangeGauge
			gauge.current_value = NAN if value == null else float(value)
			gauge.queue_redraw()
			label.add_theme_color_override("font_color", AQUA if value == null or (float(value) >= gauge.working_min and float(value) <= gauge.working_max) else (AMBER if float(value) <= gauge.rest_max and float(value) >= gauge.working_min else RED))

func current_frame() -> Dictionary:
	if frames.is_empty():
		return {}
	return frames[BathysSimulation.frame_index_at(frames, playback_time)]

func show_frame(time_s: float) -> void:
	if frames.is_empty():
		return
	playback_time = clampf(time_s, 0.0, float(frames[-1]["timeS"]))
	var index: int = BathysSimulation.frame_index_at(frames, playback_time)
	scrubber.set_value_no_signal(playback_time)
	var frame: Dictionary = frames[index]
	var next: Dictionary = frames[mini(index + 1, frames.size() - 1)]
	var interval: float = float(next["timeS"]) - float(frame["timeS"])
	var ratio: float = clampf((playback_time - float(frame["timeS"])) / interval, 0, 1) if interval > 0 else 0.0
	var lat: float = lerpf(float(frame["latitudeDeg"]), float(next["latitudeDeg"]), ratio)
	var lon: float = lerpf(float(frame["longitudeDeg"]), float(next["longitudeDeg"]), ratio)
	var depth: float = lerpf(float(frame["depthM"]), float(next["depthM"]), ratio)
	map.set_diver(lat, lon)
	if lake != null:
		lake.set_diver(lat, lon, depth)
	for chart: BathysMetricGraph in graphs:
		chart.current_time = playback_time
		chart.queue_redraw()
	metric_label.text = "%02d:%02d / %02d:%02d" % [int(playback_time / 60), int(playback_time) % 60, int(float(frames[-1]["timeS"]) / 60), int(float(frames[-1]["timeS"])) % 60]
	if index == last_shown_index:
		return
	last_shown_index = index
	update_tank_readouts()
	refresh_tissues()
	refresh_vitals()

func seek(value: float) -> void:
	show_frame(value)

func toggle_play() -> void:
	if frames.is_empty():
		return
	if playback_time >= float(frames[-1]["timeS"]):
		seek(0.0)
	playing = not playing
	play_button.text = "PAUSE" if playing else "PLAY"
	play_button.icon = load("res://Assets/Icons/pause.svg" if playing else "res://Assets/Icons/play.svg")

func request_simulation() -> void:
	simulation_revision += 1
	var revision: int = simulation_revision
	simulation_busy = true
	# Cross a render frame so route changes appear before calculation.
	await get_tree().process_frame
	await get_tree().process_frame
	if revision == simulation_revision and is_inside_tree():
		recompute(true, revision)

func recompute(cooperative: bool = false, revision: int = -1) -> void:
	if revision < 0:
		simulation_revision += 1
		revision = simulation_revision
	simulation_busy = true
	sim_debounce = -1
	playing = false
	play_button.text = "PLAY"
	play_button.icon = load("res://Assets/Icons/play.svg")
	selected_event = -1
	if not (plan["waypoints"] as Array).any(func(item: Variant) -> bool: return (item as Dictionary).get("kind", "travel") != "switch"):
		feedback_label.visible = false
		set_playback_available(false)
		frames.clear()
		legs.clear()
		playback_time = 0
		scrubber.set_value_no_signal(0)
		scrubber.max_value = 0
		metric_label.text = "00:00 / 00:00"
		for chart: BathysMetricGraph in graphs:
			chart.frames = []
			chart.legs = []
			chart.queue_redraw()
		refresh_vitals()
		(metric_values["depthM"] as Label).text = "0.0"
		(metric_values["ambientBar"] as Label).text = "%.2f" % BathysPhysics.surface_bar(plan["environment"] as Dictionary)
		update_tank_readouts()
		for entry: Dictionary in tank_readouts:
			(entry["metrics"] as Label).text = "Add a route to preview gas metrics."
		refresh_tissues()
		update_route_summaries()
		var entrance: Dictionary = site.pois[0]
		map.set_diver(float(entrance["latitudeDeg"]), float(entrance["longitudeDeg"]))
		if lake != null:
			lake.set_diver(float(entrance["latitudeDeg"]), float(entrance["longitudeDeg"]), 0)
		simulation_busy = false
		status_label.text = "Route empty · inspect the map to begin"
		return
	var started: int = Time.get_ticks_msec()
	var result: Dictionary
	if cooperative:
		var captured_plan: Dictionary = plan.duplicate(true)
		result = await BathysSimulation.run(site, captured_plan, get_tree(), func() -> bool: return revision != simulation_revision)
	else:
		result = await BathysSimulation.run(site, plan)
	if revision != simulation_revision or bool(result.get("cancelled", false)):
		return
	simulation_busy = false
	frames.clear()
	legs.clear()
	if str(result.get("error", "")) != "":
		playing = false
		play_button.text = "PLAY"
		play_button.icon = load("res://Assets/Icons/play.svg")
		status_label.text = "Simulation needs attention"
		feedback_label.text = tr(str(result["error"])) + tr(" Edit the route or tank settings, then the simulation will update.")
		feedback_label.visible = true
		selected_event = int(result.get("eventIndex", -1))
		if selected_event >= 0:
			var route: Array = plan["waypoints"]
			feedback_label.text = tr("Event: %s · ") % str(route[selected_event].get("name", tr("Waypoint"))) + feedback_label.text
			expanded_routes[str(route[selected_event]["id"])] = true
		refresh_route()
		metric_label.text = "Simulation unavailable"
		scrubber.set_value_no_signal(0)
		scrubber.max_value = 0
		for chart: BathysMetricGraph in graphs:
			chart.frames = []
			chart.queue_redraw()
		refresh_vitals()
		update_tank_readouts()
		refresh_tissues()
		graph.queue_redraw()
		return
	for frame: Variant in result["frames"]:
		frames.append(frame as Dictionary)
	for leg: Variant in result["legs"]:
		legs.append(leg as Dictionary)
	for chart: BathysMetricGraph in graphs:
		chart.frames = frames
		chart.legs = legs
		chart.queue_redraw()
	update_route_summaries()
	for card: Node in route_list.get_children():
		if card is PanelContainer:
			(card as PanelContainer).remove_theme_stylebox_override("panel")
	tissue_scale_bar = compute_tissue_scale()
	scrubber.max_value = float(result["durationS"])
	playback_time = minf(playback_time, float(result["durationS"]))
	last_shown_index = -1
	show_frame(playback_time)
	feedback_label.visible = false
	set_playback_available(true)
	status_label.text = "Simulation up to date"
	print("BATHYS_SIM_MS=", Time.get_ticks_msec() - started)
	if OS.has_feature("web"):
		print("BATHYS_PAGE_SIM_READY_MS=", JavaScriptBridge.eval("performance.now()", true))
	report_web_memory("SIM")

func compute_tissue_scale() -> float:
	var maximum: float = 1.5
	for frame: Dictionary in frames:
		var n2: PackedFloat64Array = frame["tissueN2Bar"] as PackedFloat64Array
		var he: PackedFloat64Array = frame["tissueHeBar"] as PackedFloat64Array
		for i: int in n2.size():
			maximum = maxf(maximum, n2[i] + he[i])
			maximum = maxf(maximum, BathysTissue.allowed_inert(i, n2[i], he[i], float(frame["ambientBar"]), clampf(float(frame["currentGf"]), 0.001, 1.0)))
	return ceilf(maximum * 1.08 * 2.0) / 2.0

func snapshot() -> void:
	undo_stack.append(JSON.stringify(plan))
	if undo_stack.size() > 100:
		undo_stack.remove_at(0)
	redo_stack.clear()

func restore_from_stack(source: Array[String], destination: Array[String]) -> void:
	if source.is_empty():
		return
	destination.append(JSON.stringify(plan))
	plan = BathysPlan.from_json(source.pop_back(), site)
	(find_child("PlanName", true, false) as LineEdit).text = str(plan.get("name", "Untitled scenario"))
	map.set_waterline(float((plan["environment"] as Dictionary)["waterlineAltitudeNf02M"]))
	if lake != null:
		lake.set_waterline(float((plan["environment"] as Dictionary)["waterlineAltitudeNf02M"]))
	refresh_all()
	status_label.text = "Simulating restored plan…"
	update_saved_state()
	request_simulation()

func undo() -> void:
	restore_from_stack(undo_stack, redo_stack)

func redo() -> void:
	restore_from_stack(redo_stack, undo_stack)

func changed(route_only: bool = false) -> void:
	update_saved_state()
	BathysPlan.anchor_holds(plan, site)
	map.set_waterline(float((plan["environment"] as Dictionary)["waterlineAltitudeNf02M"]))
	if lake != null:
		lake.set_waterline(float((plan["environment"] as Dictionary)["waterlineAltitudeNf02M"]))
	if route_only:
		map.set_route(route_array())
		if lake != null:
			lake.set_route(route_array())
		refresh_route()
	else:
		refresh_all()
	status_label.text = "Simulating edited plan…"
	request_simulation()

func on_poi_clicked(poi: Dictionary) -> void:
	inspect_location(poi, false)

func on_terrain_clicked(lat: float, lon: float, depth: float, interpolated: bool) -> void:
	inspect_location({"name": "Surveyed lakebed", "latitudeDeg": lat, "longitudeDeg": lon, "depthM": depth}, interpolated)

func add_hold() -> void:
	snapshot()
	var event: Dictionary = BathysPlan.hold(tr("Hold"))
	apply_route_defaults(event)
	(plan["waypoints"] as Array).append(event)
	changed()

func add_switch() -> void:
	var tanks: Array = plan["tanks"] as Array
	var active: String = str(plan["initialTankId"])
	for item: Variant in plan["waypoints"]:
		var waypoint: Dictionary = item as Dictionary
		if waypoint.get("kind") == "switch":
			active = str(waypoint["tankId"])
	for entry: Variant in tanks:
		var tank: Dictionary = entry as Dictionary
		if str(tank["id"]) != active:
			snapshot()
			(plan["waypoints"] as Array).append(BathysPlan.gas_switch(str(tank["id"]), tr("Switch to ") + str(tank["name"])))
			changed()
			return
	status_label.text = "Add a second tank before placing a gas switch."

func clear_route() -> void:
	snapshot()
	plan["waypoints"] = []
	changed()

func move_route(index: int, direction: int) -> void:
	var route: Array = plan["waypoints"] as Array
	var target: int = index + direction
	if target < 0 or target >= route.size():
		return
	snapshot()
	var item: Variant = route[index]
	route[index] = route[target]
	route[target] = item
	changed()

func remove_route(index: int) -> void:
	snapshot()
	(plan["waypoints"] as Array).remove_at(index)
	changed()

func inline_number(grid: GridContainer, key: String, caption: String, target: Dictionary,
		minimum: float, maximum: float, step: float, suffix: String, factor: float = 1.0) -> SpinBox:
	grid.add_child(make_label(caption, 10, BathysUiStyle.MUTED))
	var input := SpinBox.new()
	input.name = key
	var help: Dictionary = {"sacLPerMin": "Surface air consumption: gas used per minute at surface pressure.", "gfLow": "Gradient factor used for deeper decompression stops. Low must not exceed High.", "gfHigh": "Gradient factor approaching the surface. High must be at least Low.", "waterlineAltitudeNf02M": "Illustrative lake elevation in the NF02 datum; affects depth and atmospheric pressure.", "reserveGaugeBar": "Simulation stops if this tank would fall below its reserve.", "targetDepthM": "Depth below the selected waterline, independent of lakebed depth."}
	input.tooltip_text = str(help.get(key, tr(caption).capitalize() + " (" + tr(suffix) + ")"))
	input.min_value = minimum
	input.max_value = maximum
	input.step = step
	input.set_meta("source_suffix", suffix)
	input.suffix = tr(suffix)
	input.value = float(target.get(key, minimum / factor)) * factor
	input.select_all_on_focus = true
	input.custom_minimum_size = Vector2(90, 30)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(input)
	input.value_changed.connect(func(value: float) -> void: commit_inline(target, key, value / factor))
	return input

func inline_grid(parent: Node) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 5)
	parent.add_child(grid)
	return grid

func inline_name(parent: Node, target: Dictionary, tank: bool = false) -> LineEdit:
	var input := LineEdit.new()
	input.name = "name"
	input.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	input.add_theme_color_override("font_uneditable_color", INK)
	input.text = str(target.get("name", ""))
	input.custom_minimum_size = Vector2(65, 28)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(input)
	var commit: Callable = func() -> void:
		if input.text == str(target.get("name", "")):
			return
		commit_inline(target, "name", input.text)
		if tank:
			for item: Variant in plan["waypoints"]:
				var waypoint: Dictionary = item as Dictionary
				if waypoint.get("kind") == "switch" and waypoint.get("tankId") == target.get("id"):
					waypoint["name"] = tr("Switch to ") + input.text
	input.set_meta("commit_edit", commit)
	input.text_submitted.connect(func(_value: String) -> void: commit.call())
	input.focus_exited.connect(commit)
	return input

func commit_inline(target: Dictionary, key: String, value: Variant) -> void:
	if target.get(key) == value:
		return
	snapshot()
	simulation_revision += 1
	target[key] = value
	if target.has("o2") and key in ["o2", "he"]:
		var other: String = "he" if key == "o2" else "o2"
		target[key] = minf(float(value), 1.0 - float(target[other]))
		target["n2"] = maxf(0, 1.0 - float(target["o2"]) - float(target["he"]))
		var tanks: Array = plan["tanks"]
		var index: int = tanks.find(target)
		var card := tank_list.get_node_or_null("Tank_" + str(index))
		if card != null:
			for field: String in ["o2", "n2", "he"]:
				var input := card.find_child(field, true, false) as SpinBox
				input.set_value_no_signal(float(target[field]) * 100)
	if key in ["latitudeDeg", "longitudeDeg"] and target.has("poiId"):
		target["poiId"] = null
	BathysPlan.anchor_holds(plan, site)
	playing = false
	play_button.text = "PLAY"
	play_button.icon = load("res://Assets/Icons/play.svg")
	sim_debounce = 0.35
	update_saved_state()
	status_label.text = "Updating simulation…"
	update_tank_readouts()
	update_site_readout()

func apply_inline_changes(cooperative: bool = false) -> void:
	sim_debounce = -1
	BathysPlan.anchor_holds(plan, site)
	map.set_waterline(float((plan["environment"] as Dictionary)["waterlineAltitudeNf02M"]))
	map.set_route(route_array())
	if lake != null:
		lake.set_waterline(float((plan["environment"] as Dictionary)["waterlineAltitudeNf02M"]))
		lake.set_route(route_array())
	if cooperative:
		request_simulation()
	else:
		recompute()

func gas_selector(parent: Node, target: Dictionary, key: String) -> OptionButton:
	var choice := OptionButton.new()
	choice.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.name = key
	for item: Variant in plan["tanks"]:
		var tank: Dictionary = item as Dictionary
		choice.add_item(str(tank["name"]))
		choice.set_item_metadata(choice.item_count - 1, str(tank["id"]))
		if tank["id"] == target.get(key):
			choice.select(choice.item_count - 1)
	parent.add_child(choice)
	choice.item_selected.connect(func(index: int) -> void:
		commit_inline(target, key, choice.get_item_metadata(index))
		if target.get("kind") == "switch":
			target["name"] = tr("Switch to ") + tank_name(str(target[key]))
			var input := parent.get_parent().find_child("name", true, false) as LineEdit
			if input != null:
				input.text = str(target["name"]))
	return choice

func add_tank() -> void:
	snapshot()
	var tank_id: String = BathysPlan.id()
	if (plan["tanks"] as Array).is_empty():
		plan["initialTankId"] = tank_id
	(plan["tanks"] as Array).append({"id": tank_id, "name": tr("New tank"), "volumeL": 12.0,
		"startGaugeBar": 200.0, "reserveGaugeBar": 50.0, "o2": 0.21, "n2": 0.79, "he": 0.0})
	expanded_tanks[tank_id] = true
	changed()

func save_plan() -> void:
	BathysPlan.anchor_holds(plan, site)
	var error: String = BathysPlan.validate(plan, false)
	if not error.is_empty():
		status_label.text = error
		return
	var file: FileAccess = FileAccess.open(PLAN_PATH, FileAccess.WRITE)
	if file == null:
		status_label.text = "Could not save plan."
		return
	file.store_string(JSON.stringify(plan, "  "))
	file.close()
	saved_state = JSON.stringify(plan)
	update_saved_state()
	status_label.text = "Saved on this device."

func load_plan() -> void:
	if not FileAccess.file_exists(PLAN_PATH):
		status_label.text = "No saved plan in browser storage."
		return
	accept_plan(FileAccess.get_file_as_string(PLAN_PATH), true)

func accept_plan(text: String, from_device: bool = false) -> void:
	var loaded: Dictionary = BathysPlan.from_json(text, site)
	var error: String = BathysPlan.validate(loaded, false)
	if not error.is_empty():
		status_label.text = tr("Plan import failed: ") + tr(error)
		return
	snapshot()
	plan = loaded
	playing = false
	play_button.text = "PLAY"
	playback_time = 0.0
	changed()
	if from_device:
		saved_state = JSON.stringify(plan)
	update_saved_state()
	var name_input := find_child("PlanName", true, false) as LineEdit
	name_input.text = str(plan.get("name", "Untitled scenario"))
	status_label.text = "Plan loaded."

func export_plan() -> void:
	var error: String = BathysPlan.validate(plan, false)
	if not error.is_empty():
		status_label.text = error
		return
	var bytes: PackedByteArray = JSON.stringify(plan, "  ").to_utf8_buffer()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(bytes, str(plan.get("name", "bathys-plan")).validate_filename() + ".json", "application/json")
		save_plan()
		status_label.text = "Plan file download requested; backup saved on this device."
	else:
		var chooser := FileDialog.new()
		chooser.access = FileDialog.ACCESS_FILESYSTEM
		chooser.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		chooser.filters = PackedStringArray([tr("*.json ; JSON plans")])
		chooser.current_file = str(plan.get("name", "bathys-plan")).validate_filename() + ".json"
		add_child(chooser)
		chooser.file_selected.connect(func(path: String) -> void:
			var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_buffer(bytes)
				file.close()
				save_plan()
			else:
				status_label.text = "Could not write the plan file."
			chooser.queue_free())
		chooser.canceled.connect(func() -> void: chooser.queue_free())
		chooser.popup_centered_ratio()

func import_plan() -> void:
	if OS.has_feature("web"):
		import_callback = JavaScriptBridge.create_callback(on_import_callback)
		var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
		window.bathysPlanImport = import_callback
		JavaScriptBridge.eval("""(() => { const input = document.createElement('input'); input.type = 'file'; input.accept = '.json,application/json'; input.onchange = async () => { if (input.files.length) { try { window.bathysPlanImport(await input.files[0].text()); } catch (e) { window.bathysPlanImport(''); } } }; input.click(); })();""", true)
	else:
		var chooser := FileDialog.new()
		chooser.access = FileDialog.ACCESS_FILESYSTEM
		chooser.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		chooser.filters = PackedStringArray([tr("*.json ; JSON plans")])
		add_child(chooser)
		chooser.file_selected.connect(func(path: String) -> void:
			accept_plan(FileAccess.get_file_as_string(path))
			chooser.queue_free())
		chooser.canceled.connect(func() -> void: chooser.queue_free())
		chooser.popup_centered_ratio()

func on_import_callback(args: Array) -> void:
	if args.is_empty() or str(args[0]).is_empty():
		status_label.text = "Could not read selected plan."
		return
	accept_plan(str(args[0]))










func update_saved_state() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.bathysHasChanges = " + ("true" if JSON.stringify(plan) != saved_state else "false"), true)
	if save_state_label != null:
		save_state_label.text = "Unsaved changes · Save a plan file" if JSON.stringify(plan) != saved_state else "No unsaved changes"

func adapt_layout() -> void:
	if content_box == null:
		return
	var narrow: bool = get_viewport_rect().size.x < 1100
	content_box.vertical = narrow
	var ordered: Array = [center_panel, left_divider, left_panel, right_divider, right_panel] if narrow else [left_panel, left_divider, center_panel, right_divider, right_panel]
	for index: int in ordered.size():
		content_box.move_child(ordered[index], index)
	left_divider.horizontal = narrow
	right_divider.horizontal = narrow
	left_panel.custom_minimum_size = Vector2(0 if narrow else tank_panel_width, tank_panel_height if narrow else 0)
	right_panel.custom_minimum_size = Vector2(0 if narrow else route_panel_width, route_panel_height if narrow else 0)
	center_panel.custom_minimum_size.y = 350
	content_box.custom_minimum_size.y = (370 + (tank_panel_height if left_panel.visible else 0) + (route_panel_height if right_panel.visible else 0)) if narrow else 390
	var minimum_card_width: float = 160
	for key: String in visible_metrics:
		minimum_card_width = maxf(minimum_card_width, (metric_cards[key] as Control).get_combined_minimum_size().x)
	metric_grid.columns = maxi(1, mini(visible_metrics.size(), int((get_viewport_rect().size.x - 70) / minimum_card_width)))

func open_metrics_menu() -> void:
	metrics_menu.clear()
	var names: Array = ["Depth", "Ambient pressure", "Leading gradient factor", "No decompression limit", "Time to surface", "Ceiling", "CNS exposure", "Oxygen partial pressure", "Gas density", "Equivalent narcotic depth", "OTU exposure", "Water temperature", "Applied gradient factor", "Controlling tissue", "First stop depth", "Active gas", "Gas used"]
	for index: int in metric_cards.size():
		metrics_menu.add_check_item(str(names[index]), index)
		metrics_menu.set_item_checked(index, str(metric_cards.keys()[index]) in visible_metrics)
	metrics_menu.position = Vector2i(get_global_mouse_position())
	metrics_menu.popup()

func toggle_metric(index: int) -> void:
	var key: String = str(metric_cards.keys()[index])
	if key in visible_metrics:
		if visible_metrics.size() == 1:
			status_label.text = "Keep at least one readout visible."
			return
		visible_metrics.erase(key)
	else:
		visible_metrics.append(key)
	(metric_cards[key] as Control).visible = key in visible_metrics
	adapt_layout()

func inspect_location(location: Dictionary, interpolated: bool) -> void:
	if is_instance_valid(inspection_overlay) and inspection_overlay.visible:
		dismiss_inspection()
		return
	if is_instance_valid(inspection_overlay):
		inspection_overlay.queue_free()
	inspection_location = location.duplicate(true)
	inspection_interpolated = interpolated
	# A full-size input surface consumes the dismissal click before it reaches the map.
	inspection_overlay = Control.new()
	inspection_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inspection_overlay.z_index = 100
	inspection_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(inspection_overlay)
	inspection_overlay.gui_input.connect(_on_inspection_outside_input)
	inspection = BathysUiStyle.panel(BathysUiStyle.CARD, 12)
	inspection.add_theme_stylebox_override("panel", BathysUiStyle.box(BathysUiStyle.CARD, AQUA, 10, 12))
	inspection.mouse_filter = Control.MOUSE_FILTER_STOP
	inspection_overlay.add_child(inspection)
	var body := VBoxContainer.new()
	body.custom_minimum_size.x = 265
	inspection.add_child(body)
	body.add_child(make_label(tr(str(location.get("name", "Lakebed"))), 18, AQUA))
	body.add_child(make_label((BathysI18n.text("Reference depth %.1f m") if location.has("id") else BathysI18n.text("Lakebed depth %.1f m")) % float(location.get("depthM", 0)), 16))
	body.add_child(make_label("%.6f° N  ·  %.6f° E" % [float(location["latitudeDeg"]), float(location["longitudeDeg"])], 12))
	body.add_child(make_button("Add waypoint", add_inspected_waypoint))
	inspection.reset_size()
	var viewport_size := get_viewport_rect().size
	var popup_size := inspection.get_combined_minimum_size()
	var at := get_global_mouse_position()
	at.x = clampf(at.x, 0, maxf(0, viewport_size.x - popup_size.x))
	at.y = clampf(at.y, 0, maxf(0, viewport_size.y - popup_size.y))
	inspection.position = at

func _on_inspection_outside_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and not event.pressed) or (event is InputEventScreenTouch and not event.pressed):
		dismiss_inspection()
		inspection_overlay.accept_event()

func dismiss_inspection() -> void:
	if is_instance_valid(inspection_overlay):
		inspection_overlay.hide()

func add_insertion_slot(index: int) -> void:
	var slot := BathysRouteDropSlot.new()
	route_drop_slots.append(slot)
	bind_route_drop_target(slot)
	slot.name = "Insertion_" + str(index)
	slot.custom_minimum_size.y = 12
	route_list.add_child(slot)
	var button := Button.new()
	button.text = "+"
	button.pressed.connect(func() -> void: insertion_menu(index))
	button.tooltip_text = "Insert a hold or gas switch here"
	button.add_theme_font_size_override("font_size", 12)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, BathysUiStyle.box(Color(0, 0, 0, 0), AQUA if state != "normal" else Color(0, 0, 0, 0), 3, 0))
	button.custom_minimum_size = Vector2(32, 12)
	slot.add_child(button)
	bind_route_drop_target(button)

func insertion_menu(index: int) -> void:
	var menu := PopupMenu.new()
	add_child(menu)
	menu.add_item("Insert hold", 0)
	menu.add_item("Insert gas switch", 1)
	menu.set_item_disabled(1, (plan["tanks"] as Array).size() < 2)
	menu.set_item_tooltip(1, "Add at least two tanks to switch gases.")
	menu.id_pressed.connect(func(choice: int) -> void: insert_event(index, choice == 1))
	menu.popup_hide.connect(func() -> void: menu.queue_free())
	menu.position = Vector2i(get_global_mouse_position())
	menu.popup()

func insert_event(index: int, switch: bool) -> void:
	var route: Array = plan["waypoints"]
	var event: Dictionary
	if switch:
		var active: String = str(plan["initialTankId"])
		for i: int in mini(index, route.size()):
			if route[i].get("kind") == "switch":
				active = str(route[i]["tankId"])
		for tank: Dictionary in plan["tanks"]:
			if str(tank["id"]) != active:
				event = BathysPlan.gas_switch(str(tank["id"]), tr("Switch to ") + str(tank["name"]))
				break
		if event.is_empty():
			return
	else:
		event = BathysPlan.hold(tr("Hold"))
		apply_route_defaults(event)
	snapshot()
	route.insert(clampi(index, 0, route.size()), event)
	expanded_routes[str(event["id"])] = true
	changed(true)

func add_inspected_waypoint() -> void:
	if inspection_location.is_empty():
		return
	snapshot()
	var waypoint: Dictionary = BathysPlan.waypoint_at_poi(inspection_location)
	apply_route_defaults(waypoint)
	waypoint["name"] = tr(str(waypoint["name"]))
	if not inspection_location.has("id"):
		waypoint["poiId"] = null
		waypoint["name"] = tr("Interpolated waypoint") if inspection_interpolated else tr("Survey waypoint")
	(plan["waypoints"] as Array).append(waypoint)
	dismiss_inspection()
	changed(true)

func new_plan() -> void:
	snapshot()
	plan = BathysPlan.empty(site)
	plan["name"] = tr(str(plan["name"]))
	plan["limits"] = load_limit_preferences()
	plan["routeDefaults"] = load_route_preferences()
	playback_time = 0
	var name_input := find_child("PlanName", true, false) as LineEdit
	name_input.text = str(plan["name"])
	changed()

func set_playback_available(available: bool) -> void:
	for control: Control in playback_controls:
		control.visible = available
	bottom_panel.custom_minimum_size.y = 330 if available else 105

func show_load_menu() -> void:
	var menu := PopupMenu.new()
	add_child(menu)
	menu.add_icon_item(load("res://Assets/Icons/folder.svg"), "Open plan file…", 0)
	menu.add_item("Saved plan on this device", 1)
	menu.set_item_disabled(1, not FileAccess.file_exists(PLAN_PATH))
	menu.id_pressed.connect(func(id: int) -> void:
		if id == 0:
			import_plan()
		else:
			load_plan())
	menu.popup_hide.connect(func() -> void: menu.queue_free())
	menu.position = Vector2i(get_global_mouse_position())
	menu.popup()

func load_limit_preferences() -> Dictionary:
	if FileAccess.file_exists(SETTINGS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if parsed is Dictionary:
			var limits: Dictionary = BathysPlan.limits_for({"limits": parsed.get("limits", parsed)})
			if BathysPlan.validate_limits(limits).is_empty():
				return limits
	return BathysPlan.default_limits()

func open_settings() -> void:
	if is_instance_valid(settings_dialog):
		settings_dialog.queue_free()
	settings_dialog = ConfirmationDialog.new()
	settings_dialog.title = "Settings"
	settings_dialog.ok_button_text = "Apply"
	settings_dialog.dialog_hide_on_ok = false
	add_child(settings_dialog)
	settings_inputs.clear()
	settings_route_inputs.clear()
	var body := VBoxContainer.new()
	body.custom_minimum_size.x = 330
	settings_dialog.add_child(body)
	body.add_child(make_label("GAS LIMITS", 16, AQUA))
	body.add_child(BathysUiStyle.wrapped("Oxygen limits control simulation checks. Density and END limits control the physiology warning bands."))
	var grid := GridContainer.new()
	grid.columns = 2
	body.add_child(grid)
	var limits: Dictionary = BathysPlan.limits_for(plan)
	for entry: Array in [["ppO2Min", "Minimum ppO₂", 0.01, 3.0, 0.01, "bar"], ["ppO2WorkingMax", "Working maximum ppO₂ / MOD", 0.01, 3.0, 0.01, "bar"], ["ppO2Max", "Maximum ppO₂", 0.01, 3.0, 0.01, "bar"], ["densityWarning", "Gas density warning", 0.1, 20.0, 0.1, "g/L"], ["densityMax", "Maximum gas density", 0.1, 20.0, 0.1, "g/L"], ["endMax", "Maximum END", 1.0, 100.0, 1.0, "m"]]:
		grid.add_child(make_label(str(entry[1]), 12))
		var input := SpinBox.new()
		input.name = str(entry[0])
		input.min_value = float(entry[2])
		input.max_value = float(entry[3])
		input.step = float(entry[4])
		input.suffix = str(entry[5])
		input.value = float(limits[str(entry[0])])
		input.custom_minimum_size.x = 100
		grid.add_child(input)
		settings_inputs[str(entry[0])] = input
	body.add_child(make_label("NEW ROUTE EVENTS", 16, AQUA))
	body.add_child(BathysUiStyle.wrapped("Defaults apply to new waypoints and holds. Existing events keep their values."))
	var route_grid := GridContainer.new()
	route_grid.columns = 2
	body.add_child(route_grid)
	var route_defaults: Dictionary = BathysPlan.route_defaults_for(plan)
	for entry: Array in [["sacLPerMin", "Default SAC", 1.0, 100.0, 0.5, "L/min"], ["speedMPerMin", "Default swim speed", 1.0, 60.0, 0.5, "m/min"]]:
		route_grid.add_child(make_label(str(entry[1]), 12))
		var input := SpinBox.new()
		input.name = "Default_" + str(entry[0])
		input.min_value = float(entry[2])
		input.max_value = float(entry[3])
		input.step = float(entry[4])
		input.suffix = str(entry[5])
		input.value = float(route_defaults[str(entry[0])])
		input.custom_minimum_size.x = 100
		route_grid.add_child(input)
		settings_route_inputs[str(entry[0])] = input
	settings_error = BathysUiStyle.wrapped("", 12, RED)
	settings_error.visible = false
	settings_error.custom_minimum_size.x = 330
	settings_error.size.x = 330
	body.add_child(settings_error)
	body.add_child(make_button("Reset limits to defaults", func() -> void:
		var defaults: Dictionary = BathysPlan.default_limits()
		for key: String in settings_inputs:
			(settings_inputs[key] as SpinBox).value = float(defaults[key])))
	body.add_child(make_button("New empty scenario", func() -> void:
		settings_dialog.hide()
		new_plan()))
	settings_dialog.confirmed.connect(func() -> void:
		var edited: Dictionary = {}
		for key: String in settings_inputs:
			var input: SpinBox = settings_inputs[key]
			input.apply()
			edited[key] = input.value
		var error: String = BathysPlan.validate_limits(edited)
		if not error.is_empty():
			settings_error.text = error
			settings_error.visible = true
			return
		var edited_defaults: Dictionary = {}
		for key: String in settings_route_inputs:
			var input: SpinBox = settings_route_inputs[key]
			input.apply()
			edited_defaults[key] = input.value
		error = BathysPlan.validate_route_defaults(edited_defaults)
		if not error.is_empty():
			settings_error.text = error
			settings_error.visible = true
			return
		if apply_limits(edited, true, edited_defaults):
			settings_dialog.hide())
	for child: Node in body.get_children():
		if child is Label:
			(child as Label).custom_minimum_size.x = 330
			(child as Label).size.x = 330
	settings_dialog.popup_centered(Vector2i(380, 590))
	await get_tree().process_frame
	if is_instance_valid(settings_dialog):
		settings_dialog.reset_size()
		settings_dialog.size = Vector2i(380, 590)
		settings_dialog.position = (Vector2i(get_viewport_rect().size) - settings_dialog.size) / 2

func apply_limits(limits: Dictionary, persist: bool = true, route_defaults: Dictionary = {}) -> bool:
	if route_defaults.is_empty():
		route_defaults = BathysPlan.route_defaults_for(plan)
	if not BathysPlan.validate_limits(limits).is_empty() or not BathysPlan.validate_route_defaults(route_defaults).is_empty():
		return false
	snapshot()
	plan["limits"] = limits.duplicate(true)
	plan["routeDefaults"] = route_defaults.duplicate(true)
	if persist:
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"limits": limits, "routeDefaults": route_defaults}))
			file.close()
		else:
			status_label.text = "Limits applied to this plan; could not save preferences on this device."
	changed()
	return true

func update_gas_gauges() -> void:
	var limits: Dictionary = BathysPlan.limits_for(plan)
	for key: String in range_gauges:
		var gauge: BathysGasRangeGauge = range_gauges[key]
		if key == "ppO2Bar":
			gauge.working_min = float(limits["ppO2Min"])
			gauge.working_max = float(limits["ppO2WorkingMax"])
			gauge.rest_max = float(limits["ppO2Max"])
			gauge.min_caption = "%.2f" % gauge.working_min
		elif key == "densityGPerL":
			gauge.working_max = float(limits["densityWarning"])
			gauge.rest_max = float(limits["densityMax"])
		else:
			gauge.working_max = float(limits["endMax"])
			gauge.rest_max = gauge.working_max
		gauge.chart_max = gauge.rest_max * 1.2
		gauge.working_caption = "%.2f" % gauge.working_max if key == "ppO2Bar" else "%.1f" % gauge.working_max
		gauge.rest_caption = "%.2f" % gauge.rest_max if key == "ppO2Bar" else "%.1f" % gauge.rest_max
		gauge.queue_redraw()

func capture_map_jpg() -> PackedByteArray:
	dismiss_inspection()
	var credit := ColorRect.new()
	credit.color = BG
	credit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	credit.offset_top = -24
	credit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view_container.add_child(credit)
	var caption := make_label("BATHYS · Lac des Îles · Educational model · © swisstopo SWISSIMAGE", 10)
	caption.position = Vector2(8, 4)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	credit.add_child(caption)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = get_viewport().get_texture().get_image()
	var rectangle := Rect2i(view_container.get_global_rect())
	var available := Rect2i(Vector2i.ZERO, screenshot.get_size())
	credit.queue_free()
	if not available.encloses(rectangle) or rectangle.size.x <= 0 or rectangle.size.y <= 0:
		status_label.text = "Scroll the map fully into view before exporting."
		return PackedByteArray()
	return screenshot.get_region(rectangle).save_jpg_to_buffer(0.95)

func export_map_jpg() -> void:
	var bytes: PackedByteArray = await capture_map_jpg()
	if bytes.is_empty():
		return
	var filename: String = str(plan.get("name", "bathys-map")).validate_filename() + ".jpg"
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(bytes, filename, "image/jpeg")
		status_label.text = "Map JPG download requested."
	else:
		var chooser := FileDialog.new()
		chooser.access = FileDialog.ACCESS_FILESYSTEM
		chooser.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		chooser.filters = PackedStringArray([tr("*.jpg ; JPEG map view")])
		chooser.current_file = filename
		add_child(chooser)
		chooser.file_selected.connect(func(path: String) -> void:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_buffer(bytes)
				file.close()
				status_label.text = "Map JPG saved."
			else:
				status_label.text = "Could not save the map JPG."
			chooser.queue_free())
		chooser.canceled.connect(func() -> void: chooser.queue_free())
		chooser.popup_centered_ratio()


func toggle_side_panel(tanks: bool) -> void:
	var panel: PanelContainer = left_panel if tanks else right_panel
	panel.visible = not panel.visible
	adapt_layout()

func create_panel_divider(tanks: bool) -> BathysPanelDivider:
	var divider := BathysPanelDivider.new()
	divider.name = "TankDivider" if tanks else "RouteDivider"
	divider.drag_started.connect(func(at: Vector2) -> void:
		panel_drag_origin = at
		var panel: PanelContainer = left_panel if tanks else right_panel
		panel_drag_extent = panel.size.y if panel.visible else 0.0)
	divider.dragged.connect(func(at: Vector2) -> void: resize_side_panel(tanks, at))
	divider.toggle_requested.connect(func() -> void: toggle_side_panel(tanks))
	divider.nudged.connect(func(distance: float) -> void:
		var at: Vector2 = divider.get_global_rect().get_center()
		if content_box.vertical:
			panel_drag_origin = at
			var panel: PanelContainer = left_panel if tanks else right_panel
			panel_drag_extent = panel.size.y if panel.visible else 0.0
			at.y += distance
		else:
			at.x += distance
		resize_side_panel(tanks, at))
	return divider

func resize_side_panel(tanks: bool, at: Vector2) -> void:
	var panel: PanelContainer = left_panel if tanks else right_panel
	var extent: float
	if content_box.vertical:
		extent = panel_drag_extent + panel_drag_origin.y - at.y
	else:
		var bounds: Rect2 = content_box.get_global_rect()
		extent = at.x - bounds.position.x if tanks else bounds.end.x - at.x
	if extent <= 36:
		panel.hide()
	elif extent >= 72:
		panel.show()
		if content_box.vertical:
			if tanks:
				tank_panel_height = clampf(extent, 160, 700)
			else:
				route_panel_height = clampf(extent, 180, 800)
		else:
			var other: PanelContainer = right_panel if tanks else left_panel
			var other_width: float = other.size.x if other.visible else 0.0
			var maximum: float = maxf(275 if tanks else 370, content_box.size.x - other_width - 370)
			if tanks:
				tank_panel_width = clampf(extent, 275, maximum)
			else:
				route_panel_width = clampf(extent, 370, maximum)
	adapt_layout()

func load_route_preferences() -> Dictionary:
	if FileAccess.file_exists(SETTINGS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if parsed is Dictionary:
			var defaults: Dictionary = BathysPlan.route_defaults_for(parsed)
			if BathysPlan.validate_route_defaults(defaults).is_empty():
				return defaults
	return BathysPlan.default_route_settings()

func apply_route_defaults(event: Dictionary) -> void:
	var defaults: Dictionary = BathysPlan.route_defaults_for(plan)
	event["sacLPerMin"] = float(defaults["sacLPerMin"])
	event["speedMPerMin"] = float(defaults["speedMPerMin"])

func update_language_button() -> void:
	language_button.icon = load("res://Assets/Icons/flag-" + I18n.language + ".svg")
	language_button.tooltip_text = "Language: French" if I18n.language == "fr" else "Language: English"

func show_language_menu() -> void:
	var menu := PopupMenu.new()
	add_child(menu)
	for index: int in 2:
		var code: String = "en" if index == 0 else "fr"
		menu.add_icon_check_item(load("res://Assets/Icons/flag-" + code + ".svg"), "English" if index == 0 else "Français", index)
		menu.set_item_checked(index, I18n.language == code)
	menu.id_pressed.connect(func(index: int) -> void: I18n.set_language("en" if index == 0 else "fr"))
	menu.popup_hide.connect(func() -> void: menu.queue_free())
	menu.position = Vector2i(language_button.get_global_rect().position + Vector2(0, language_button.size.y))
	menu.popup()

func _on_language_changed() -> void:
	update_language_button()
	(find_child("PlanName", true, false) as LineEdit).placeholder_text = tr("Scenario name")
	for input: Node in find_children("*", "SpinBox", true, false):
		if input.has_meta("source_suffix"):
			(input as SpinBox).suffix = tr(str(input.get_meta("source_suffix")))
	call_deferred("adapt_layout")
	update_saved_state()
	update_route_summaries()
	var route: Array = plan.get("waypoints", [])
	var switches: int = route.filter(func(item: Variant) -> bool: return item.get("kind") == "switch").size()
	route_count_label.text = tr("%d waypoints / holds · %d gas switches") % [route.size() - switches, switches]
	update_site_readout()
	update_tank_readouts()
	refresh_tissues()
	refresh_vitals()
	if feedback_label.visible and not simulation_busy:
		request_simulation()
	elif simulation_busy:
		status_label.text = "Updating simulation…"
	elif frames.is_empty():
		status_label.text = "Route empty · inspect the map to begin"
	else:
		status_label.text = "Simulation up to date"
	map.queue_redraw()
	for chart: BathysMetricGraph in graphs:
		chart.queue_redraw()

func editor_toggle(details: Control, expanded: Dictionary, item_id: String, target: Dictionary,
		tank: bool, name_input: LineEdit) -> Button:
	var button := Button.new()
	button.name = "EditorToggle"
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.custom_minimum_size = Vector2(34, 31)
	button.focus_mode = Control.FOCUS_ALL
	button.toggle_mode = true
	var edit_hint: String = "Edit tank" if tank else {"travel": "Edit waypoint", "hold": "Edit hold", "switch": "Edit gas switch"}.get(str(target.get("kind", "travel")), "Edit waypoint")
	var update_state: Callable = func() -> void:
		button.set_pressed_no_signal(details.visible)
		button.icon = load("res://Assets/Icons/check.svg" if details.visible else "res://Assets/Icons/tools.svg")
		button.tooltip_text = "Validate changes" if details.visible else edit_hint
	button.pressed.connect(func() -> void:
		if details.visible:
			# Commit text still focused in an input before validating the edited item.
			(name_input.get_meta("commit_edit") as Callable).call()
			for input: Node in details.find_children("*", "SpinBox", true, false):
				(input as SpinBox).apply()
			var error: String = validate_editor_target(target, tank)
			var error_label := details.get_node_or_null("EditorError") as Label
			if not error.is_empty():
				if error_label == null:
					error_label = BathysUiStyle.wrapped("", 12, RED)
					error_label.name = "EditorError"
					details.add_child(error_label)
				error_label.text = error
				error_label.show()
				status_label.text = error
				update_state.call()
				return
			if error_label != null:
				error_label.hide()
			if sim_debounce >= 0:
				apply_inline_changes(true)
			details.hide()
		else:
			details.show()
		expanded[item_id] = details.visible
		update_state.call())
	update_state.call()
	return button

func validate_editor_target(target: Dictionary, tank: bool) -> String:
	# Validate this item independently of unfinished settings in other cards.
	if not tank and target.get("kind") == "switch":
		for item: Dictionary in plan.get("tanks", []):
			if item.get("id") == target.get("tankId"):
				return ""
		return "Choose a valid gas for this switch."
	var draft: Dictionary = BathysPlan.empty(site)
	if tank:
		draft["tanks"] = [target.duplicate(true)]
		draft["initialTankId"] = str(target.get("id", ""))
	else:
		draft["waypoints"] = [target.duplicate(true)]
	return BathysPlan.validate(draft, false)

func route_index_by_id(event_id: String) -> int:
	var route: Array = plan.get("waypoints", [])
	for index: int in route.size():
		if str(route[index].get("id", "")) == event_id:
			return index
	return -1

func valid_route_drag(data: Variant) -> bool:
	return data is Dictionary and data.get("type") == "bathys_route_event" and data.get("owner") == get_instance_id() and route_index_by_id(str(data.get("id", ""))) >= 0

func route_boundary_at(at: Vector2) -> int:
	var route: Array = plan.get("waypoints", [])
	for index: int in route.size():
		var card := route_list.get_node_or_null("Route_" + str(index)) as Control
		if card != null and at.y < card.get_global_rect().get_center().y:
			return index
	return route.size()

func highlight_route_drop(boundary: int) -> void:
	route_drop_boundary = boundary
	for index: int in route_drop_slots.size():
		route_drop_slots[index].set_highlight(index == boundary)

func bind_route_drop_target(control: Control) -> void:
	control.set_drag_forwarding(
		func(_at: Vector2) -> Variant: return null,
		func(_at: Vector2, data: Variant) -> bool:
			if not valid_route_drag(data) or not (route_list.get_parent() as Control).get_global_rect().has_point(route_drag_position):
				return false
			highlight_route_drop(route_boundary_at(route_drag_position))
			return true,
		func(_at: Vector2, data: Variant) -> void:
			if valid_route_drag(data):
				reorder_route(str(data["id"]), route_boundary_at(route_drag_position)))

func reorder_route(event_id: String, boundary: int) -> void:
	var source: int = route_index_by_id(event_id)
	if source < 0:
		return
	var route: Array = plan["waypoints"]
	var destination: int = clampi(boundary, 0, route.size())
	if destination > source:
		destination -= 1
	if destination == source:
		return
	snapshot()
	var event: Variant = route.pop_at(source)
	route.insert(destination, event)
	changed(true)

func update_route_drag(delta: float) -> void:
	var scroll := route_list.get_parent() as ScrollContainer
	var bounds: Rect2 = scroll.get_global_rect()
	var mouse: Vector2 = route_drag_position
	if not bounds.has_point(mouse):
		highlight_route_drop(-1)
		return
	var direction: float = 0
	if mouse.y < bounds.position.y + 36:
		direction = -1
	elif mouse.y > bounds.end.y - 36:
		direction = 1
	if direction != 0:
		scroll.scroll_vertical += roundi(direction * 420 * delta)
	highlight_route_drop(route_boundary_at(mouse))

func finish_route_drag() -> void:
	route_drag_id = ""
	highlight_route_drop(-1)
	if route_refresh_pending:
		route_refresh_pending = false
		refresh_route()

func bind_route_card_drop_targets(card: Control) -> void:
	# Buttons and fields stop mouse propagation, so forward their route drops too.
	for child: Node in card.find_children("*", "Control", true, false):
		if child is Control and not child is BathysRouteDragHandle:
			bind_route_drop_target(child)

func focus_route_handle(event_id: String) -> void:
	var index: int = route_index_by_id(event_id)
	var card := route_list.get_node_or_null("Route_" + str(index)) as Control
	if card != null:
		var handle := card.find_child("DragHandle", true, false) as Control
		if handle != null:
			handle.grab_focus()
			(route_list.get_parent() as ScrollContainer).ensure_control_visible(handle)

func _input(event: InputEvent) -> void:
	if not route_drag_id.is_empty() and (event is InputEventMouseMotion or event is InputEventMouseButton):
		route_drag_position = event.global_position
