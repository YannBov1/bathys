extends Control

const BG := Color("071c29")
const INK := Color("f5fbf7")
const AQUA := Color("72e9dd")
const AMBER := Color("ffb96f")
const RED := Color("ff6676")
const PLAN_PATH := "user://plan.json"

var site: BathysSite
var graphs: Array[BathysMetricGraph] = []
var metric_values: Dictionary = {}
var range_gauges: Dictionary = {}
var extra_label: Label
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
	plan = BathysPlan.example(site)
	if FileAccess.file_exists(PLAN_PATH):
		var restored: Dictionary = BathysPlan.from_json(FileAccess.get_file_as_string(PLAN_PATH), site)
		if BathysPlan.validate(restored, false).is_empty():
			plan = restored
	build_ui()
	map.site = site
	map.set_waterline(float((plan["environment"] as Dictionary)["waterlineAltitudeNf02M"]))
	refresh_all()
	status_label.text = "%s · %d measured cells · %d interpolated cells" % [site.name, site.measured_count, site.interpolated_count]
	print("BATHYS_STARTUP_MS=", Time.get_ticks_msec() - started)
	if OS.has_feature("web"):
		print("BATHYS_PAGE_READY_MS=", JavaScriptBridge.eval("performance.now()", true))
	request_simulation()
	call_deferred("show_3d")

func _process(delta: float) -> void:
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
	node.focus_mode = Control.FOCUS_NONE
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
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	var header: PanelContainer = BathysUiStyle.panel(BG, 12)
	header.custom_minimum_size.y = 62
	root.add_child(header)
	var heading := HBoxContainer.new()
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
	heading.add_child(make_label("SION · SWITZERLAND  •  EDUCATIONAL MODEL", 11, BathysUiStyle.MUTED))
	heading.add_child(make_button("SAVE PLAN", save_plan))
	heading.add_child(make_button("LOAD PLAN", load_plan))
	heading.add_child(icon_button("download", "Export plan JSON", export_plan))
	heading.add_child(icon_button("upload", "Import plan JSON", import_plan))
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)
	var tanks_panel: PanelContainer = BathysUiStyle.panel()
	tanks_panel.custom_minimum_size.x = 290
	content.add_child(tanks_panel)
	tank_list = scroll_column(tanks_panel)
	var center: PanelContainer = BathysUiStyle.panel()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(center)
	var center_stack: VBoxContainer = BathysUiStyle.column(center, 8)
	var view_bar := HBoxContainer.new()
	center_stack.add_child(view_bar)
	var view_title := make_label("DIVE SITE MODEL", 16)
	view_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_bar.add_child(view_title)
	view_label = make_label("", 11, AQUA)
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
	view_hint = make_label("", 11, BathysUiStyle.MUTED)
	center_stack.add_child(view_hint)
	var right: PanelContainer = BathysUiStyle.panel(BathysUiStyle.PANEL, 4)
	right.custom_minimum_size.x = 390
	content.add_child(right)
	var tabs := TabContainer.new()
	right.add_child(tabs)
	route_list = scroll_column(tabs, "ROUTE")
	site_list = scroll_column(tabs, "SITE")
	tissue_list = scroll_column(tabs, "TISSUES")
	var bottom: PanelContainer = BathysUiStyle.panel(BG, 9)
	bottom.custom_minimum_size.y = 350
	root.add_child(bottom)
	var playback: VBoxContainer = BathysUiStyle.column(bottom, 6)
	var live_heading := HBoxContainer.new()
	playback.add_child(live_heading)
	live_heading.add_child(make_label("LIVE DIVE PHYSIOLOGY", 15))
	status_label = make_label("", 11, BathysUiStyle.MUTED)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	live_heading.add_child(status_label)
	telemetry_label = make_label("", 11, AQUA)
	live_heading.add_child(telemetry_label)
	var cards := HBoxContainer.new()
	playback.add_child(cards)
	for entry: Array in [["DEPTH", "depthM", "m"], ["AMBIENT", "ambientBar", "bar abs"], ["LEADING GF", "leadingGf", "%"], ["NDL", "ndlS", "min"], ["TTS", "ttsS", "min"], ["CEILING", "ceilingM", "m"], ["CNS", "cnsPercent", "%"], ["ppO₂", "ppO2Bar", "bar"], ["GAS DENSITY", "densityGPerL", "g/L"], ["NARCOSIS · END", "endM", "m"]]:
		var card: PanelContainer = BathysUiStyle.panel(BathysUiStyle.CARD, 7)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards.add_child(card)
		var stack: VBoxContainer = BathysUiStyle.column(card, 1)
		stack.add_child(make_label(str(entry[0]), 10, BathysUiStyle.MUTED))
		var value := make_label("—", 21, AQUA)
		stack.add_child(value)
		metric_values[str(entry[1])] = value
		stack.add_child(make_label(str(entry[2]), 10, BathysUiStyle.MUTED))
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
	extra_label = make_label("", 11, BathysUiStyle.MUTED)
	playback.add_child(extra_label)
	var controls := HBoxContainer.new()
	playback.add_child(controls)
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
	var plot_buttons := HBoxContainer.new()
	playback.add_child(plot_buttons)
	plot_buttons.add_child(make_label("PLOTS", 11, BathysUiStyle.MUTED))
	var plot_scroll := ScrollContainer.new()
	plot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	plot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	playback.add_child(plot_scroll)
	var plot_stack: VBoxContainer = BathysUiStyle.column(plot_scroll, 8)
	for metric: String in ["depth", "tts", "ndl", "cns", "otu"]:
		var chart := BathysMetricGraph.new()
		chart.metric = metric
		chart.custom_minimum_size.y = 130
		chart.seek_requested.connect(seek)
		plot_stack.add_child(chart)
		graphs.append(chart)
		var jump := make_button(metric.to_upper(), func() -> void: plot_scroll.scroll_vertical = int(chart.position.y))
		jump.add_theme_font_size_override("font_size", 11)
		plot_buttons.add_child(jump)
	graph = graphs[0]
	var warning := make_label("EDUCATIONAL SOFTWARE ONLY · Do not use for real dive decisions. Survey datum and water level require confirmation. © swisstopo SWISSIMAGE", 11, AMBER)
	root.add_child(warning)
	set_bathymetry(false)

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
	view_hint.text = "Drag to pan · Wheel to zoom · Click a POI or surveyed bed to add"
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
	view_hint.text = "Drag to orbit · Right drag to pan · Wheel to zoom · Click to add"

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
	clear_children(route_list)
	route_summaries.clear()
	route_list.add_child(make_label("ROUTE TIMELINE", 16))
	route_list.add_child(BathysUiStyle.wrapped("Click terrain or a marker to append. Small gap fills are marked as interpolated. Ctrl+Z undo · Ctrl+Y redo."))
	var actions := HBoxContainer.new()
	route_list.add_child(actions)
	actions.add_child(make_button("+ HOLD", add_hold))
	actions.add_child(make_button("+ GAS SWITCH", add_switch))
	actions.add_child(make_button("ENTRANCE", func() -> void: on_poi_clicked(site.pois[0])))
	actions.add_child(icon_button("trash", "Clear route", clear_route))
	var history := HBoxContainer.new()
	route_list.add_child(history)
	history.add_child(icon_button("undo", "Undo · Ctrl+Z", undo))
	history.add_child(icon_button("redo", "Redo · Ctrl+Y", redo))
	var route: Array = plan.get("waypoints", []) as Array
	var switches: int = 0
	for item: Variant in route:
		if (item as Dictionary).get("kind") == "switch":
			switches += 1
	history.add_child(make_label("%d waypoints / holds · %d gas switches" % [route.size()-switches, switches], 11, BathysUiStyle.MUTED))
	for index: int in route.size():
		var waypoint: Dictionary = route[index] as Dictionary
		var kind: String = str(waypoint.get("kind", "travel"))
		var card: PanelContainer = BathysUiStyle.panel(Color("123d47") if kind == "switch" else BathysUiStyle.CARD, 7)
		card.name = "Route_" + str(index)
		route_list.add_child(card)
		var row: VBoxContainer = BathysUiStyle.column(card, 5)
		var header := HBoxContainer.new()
		row.add_child(header)
		header.add_child(make_label("%02d" % (index + 1), 15, AQUA if kind == "switch" else AMBER))
		var details := VBoxContainer.new()
		var waypoint_id: String = str(waypoint.get("id", index))
		details.name = "InlineEditor"
		details.visible = bool(expanded_routes.get(waypoint_id, false))
		if kind == "switch":
			gas_selector(header, waypoint, "tankId")
		else:
			inline_name(header, waypoint)
			var edit := make_button("EDIT", func() -> void:
				details.visible = not details.visible
				expanded_routes[waypoint_id] = details.visible)
			edit.tooltip_text = "Expand waypoint settings"
			edit.add_theme_font_size_override("font_size", 11)
			header.add_child(edit)
		header.add_child(icon_button("up", "Move event earlier", func() -> void: move_route(index, -1)))
		header.add_child(icon_button("down", "Move event later", func() -> void: move_route(index, 1)))
		header.add_child(icon_button("trash", "Remove event", func() -> void: remove_route(index)))
		var summary: Label = BathysUiStyle.wrapped("", 11)
		row.add_child(summary)
		route_summaries.append(summary)
		if kind == "switch":
			details.free()
			continue
		row.add_child(details)
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
			summary = "GAS SWITCH · %s at %.1f m · 0 s · position unchanged" % [active, depth]
		elif index < legs.size():
			var leg: Dictionary = legs[index]
			summary = "HOLD · %.1f m · %.1f min" % [float(leg["targetDepthM"]), float(leg["durationS"])/60] if kind == "hold" else "%.0f m · %03.0f° true · %.1f to %.1f m · %.1f min" % [float(leg["distanceM"]), float(leg["bearingTrueDeg"]), float(leg["startDepthM"]), float(leg["targetDepthM"]), float(leg["durationS"])/60]
			summary += "\n%s · SAC %.0f L/min" % [active, float(waypoint.get("sacLPerMin", 18))]
			if kind == "travel":
				summary += " · %.0f m/min" % float(waypoint.get("speedMPerMin", 12))
		else:
			summary = "%s · target %.1f m" % [kind.to_upper(), float(waypoint.get("targetDepthM", 0))]
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
	tank_list.add_child(BathysUiStyle.wrapped("Gauge pressure · red arc marks reserve. Gas metrics follow playback depth; MOD uses ppO₂ 1.4 bar.", 11))
	tank_list.add_child(make_label("START GAS", 10, BathysUiStyle.MUTED))
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
		inline_name(title, tank, true)
		var mix: Label = make_label("", 10, AQUA)
		title.add_child(mix)
		var details := VBoxContainer.new()
		details.name = "InlineEditor"
		details.visible = bool(expanded_tanks.get(tank_id, false))
		title.add_child(make_button("EDIT", func() -> void:
			details.visible = not details.visible
			expanded_tanks[tank_id] = details.visible))
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
		inline_number(grid, "n2", "N₂", tank, 0, 100, 1, "%", 100)
		inline_number(grid, "he", "He", tank, 0, 100, 1, "%", 100)
		details.add_child(BathysUiStyle.wrapped("Fractions must total 100%. Change one, then balance another.", 10))
		details.add_child(make_button("REMOVE TANK", func() -> void: remove_tank(index)))
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
			metrics.text = "Balance O₂, N₂ and He to 100%."
			continue
		if frame.is_empty():
			metrics.text = "Plan inputs need attention."
			continue
		var env: Dictionary = plan["environment"] as Dictionary
		var ambient: float = float(frame["ambientBar"])
		var temperature: float = float(frame["waterTempC"])
		var mod_pressure: float = 1.4 / maxf(0.001, float(tank.get("o2", 0.21)))
		var mod_text: String = ">150" if mod_pressure > BathysPhysics.ambient_bar(env, 150) else "%.0f" % BathysPhysics.depth_at_bar(env, mod_pressure)
		metrics.text = "ppO₂ %.2f · ppN₂ %.2f bar\nMOD₁.₄ %s m · density %.1f g/L · END %.0f m%s" % [float(tank.get("o2",0.21))*ambient, float(tank.get("n2",0.79))*ambient, mod_text, BathysPhysics.gas_density(tank,ambient,temperature), BathysPhysics.end_m(tank,ambient), " · ACTIVE" if tank["id"]==frame.get("tankId") else ""]
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
		model_readout.text = "ZH-L16C · GF %.0f / %.0f\nAscent %.1f m/min · descent %.1f m/min" % [float(plan["gfLow"])*100,float(plan["gfHigh"])*100,float(plan["ascentMPerMin"]),float(plan["descentMPerMin"])]
	site_readout.text = "Surface pressure  %.5f bar absolute\nDensity at 0 / 20 m  %.1f / %.1f kg/m³\nMetres per bar at 0 / 20 m  %.2f / %.2f" % [BathysPhysics.surface_bar(env), BathysPhysics.water_density(env,0), BathysPhysics.water_density(env,20), 100000/(BathysPhysics.water_density(env,0)*BathysPhysics.G), 100000/(BathysPhysics.water_density(env,20)*BathysPhysics.G)]

func remove_tank(index: int) -> void:
	var tanks: Array = plan["tanks"] as Array
	var tank: Dictionary = tanks[index] as Dictionary
	var tank_id: String = str(tank["id"])
	if tank_id == str(plan["initialTankId"]):
		status_label.text = "Choose another starting gas before removing this tank."
		return
	for item: Variant in plan["waypoints"]:
		if str((item as Dictionary).get("tankId", "")) == tank_id:
			status_label.text = "Reassign gas switches before removing this tank."
			return
	if tanks.size() < 2:
		return
	snapshot()
	tanks.remove_at(index)
	if str(plan["initialTankId"]) == tank_id:
		plan["initialTankId"] = (tanks[0] as Dictionary)["id"]
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
		elif key == "leadingGf":
			label.text = "%.0f" % maxf(0, float(value)*100)
		else:
			label.text = ("%.2f" if key in ["ambientBar", "ppO2Bar"] else "%.1f") % float(value)
		if range_gauges.has(key):
			var gauge: BathysGasRangeGauge = range_gauges[key] as BathysGasRangeGauge
			gauge.current_value = NAN if value == null else float(value)
			gauge.queue_redraw()
			label.add_theme_color_override("font_color", AQUA if value == null or (float(value) >= gauge.working_min and float(value) <= gauge.working_max) else (AMBER if float(value) <= gauge.rest_max and float(value) >= gauge.working_min else RED))
	if frame.is_empty():
		extra_label.text = "Plan inputs need attention."
		return
	var first_stop: Variant = frame.get("firstStopM")
	extra_label.text = "OTU %.1f  ·  water %.1f °C  ·  applied GF %.0f%%  ·  compartment %d  ·  first stop %s  ·  active %s  ·  gas used %.1f surface L" % [float(frame["otu"]), float(frame["waterTempC"]), float(frame["currentGf"])*100, int(frame["controllingCompartment"]), "—" if first_stop == null else "%.0f m" % float(first_stop), tank_name(str(frame["tankId"])), float(frame["usedSurfaceL"])]

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
	if not (plan["waypoints"] as Array).any(func(item: Variant) -> bool: return (item as Dictionary).get("kind", "travel") != "switch"):
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
		extra_label.text = "Click terrain or a POI to start a route."
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
		status_label.text = "Route empty · click the map to add a waypoint"
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
		status_label.text = str(result["error"])
		metric_label.text = "Simulation unavailable"
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
	tissue_scale_bar = compute_tissue_scale()
	scrubber.max_value = float(result["durationS"])
	playback_time = minf(playback_time, float(result["durationS"]))
	last_shown_index = -1
	show_frame(playback_time)
	status_label.text = "Simulated %d frames in %.2f s · %d route events" % [frames.size(), float(Time.get_ticks_msec() - started) / 1000.0, legs.size()]
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
	map.set_waterline(float((plan["environment"] as Dictionary)["waterlineAltitudeNf02M"]))
	if lake != null:
		lake.set_waterline(float((plan["environment"] as Dictionary)["waterlineAltitudeNf02M"]))
	refresh_all()
	status_label.text = "Simulating restored plan…"
	request_simulation()

func undo() -> void:
	restore_from_stack(undo_stack, redo_stack)

func redo() -> void:
	restore_from_stack(redo_stack, undo_stack)

func changed(route_only: bool = false) -> void:
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
	snapshot()
	(plan["waypoints"] as Array).append(BathysPlan.waypoint_at_poi(poi))
	changed(true)

func on_terrain_clicked(lat: float, lon: float, depth: float, interpolated: bool) -> void:
	snapshot()
	var waypoint: Dictionary = BathysPlan.waypoint_at_poi({"name": "Interpolated waypoint" if interpolated else "Survey waypoint", "latitudeDeg": lat, "longitudeDeg": lon, "depthM": depth})
	waypoint["poiId"] = null
	(plan["waypoints"] as Array).append(waypoint)
	changed(true)

func add_hold() -> void:
	snapshot()
	(plan["waypoints"] as Array).append(BathysPlan.hold())
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
			(plan["waypoints"] as Array).append(BathysPlan.gas_switch(str(tank["id"]), "Switch to " + str(tank["name"])))
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
	input.min_value = minimum
	input.max_value = maximum
	input.step = step
	input.suffix = suffix
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
					waypoint["name"] = "Switch to " + input.text
	input.text_submitted.connect(func(_value: String) -> void: commit.call())
	input.focus_exited.connect(commit)
	return input

func commit_inline(target: Dictionary, key: String, value: Variant) -> void:
	if target.get(key) == value:
		return
	snapshot()
	simulation_revision += 1
	target[key] = value
	if key in ["latitudeDeg", "longitudeDeg"] and target.has("poiId"):
		target["poiId"] = null
	BathysPlan.anchor_holds(plan, site)
	playing = false
	play_button.text = "PLAY"
	play_button.icon = load("res://Assets/Icons/play.svg")
	sim_debounce = 0.35
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
			target["name"] = "Switch to " + tank_name(str(target[key])))
	return choice

func add_tank() -> void:
	snapshot()
	var tank_id: String = BathysPlan.id()
	(plan["tanks"] as Array).append({"id": tank_id, "name": "New tank", "volumeL": 12.0,
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
	status_label.text = "Saved plan to browser storage (user://plan.json)."

func load_plan() -> void:
	if not FileAccess.file_exists(PLAN_PATH):
		status_label.text = "No saved plan in browser storage."
		return
	accept_plan(FileAccess.get_file_as_string(PLAN_PATH))

func accept_plan(text: String) -> void:
	var loaded: Dictionary = BathysPlan.from_json(text, site)
	var error: String = BathysPlan.validate(loaded, false)
	if not error.is_empty():
		status_label.text = "Plan import failed: " + error
		return
	snapshot()
	plan = loaded
	playing = false
	play_button.text = "PLAY"
	playback_time = 0.0
	changed()
	status_label.text = "Plan loaded."

func export_plan() -> void:
	var error: String = BathysPlan.validate(plan, false)
	if not error.is_empty():
		status_label.text = error
		return
	var bytes: PackedByteArray = JSON.stringify(plan, "  ").to_utf8_buffer()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(bytes, "bathys-plan.json", "application/json")
		status_label.text = "Plan download requested. Keep this file as a browser-storage backup."
	else:
		var chooser := FileDialog.new()
		chooser.access = FileDialog.ACCESS_FILESYSTEM
		chooser.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		chooser.filters = PackedStringArray(["*.json ; JSON plans"])
		chooser.current_file = "bathys-plan.json"
		add_child(chooser)
		chooser.file_selected.connect(func(path: String) -> void:
			var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_buffer(bytes)
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
		chooser.filters = PackedStringArray(["*.json ; JSON plans"])
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
	save_plan()









