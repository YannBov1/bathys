extends Control

const BG := Color("071c29")
const INK := Color("f5fbf7")
const AQUA := Color("72e9dd")
const AMBER := Color("ffb96f")
const RED := Color("ff6676")
const PLAN_PATH := "user://plan.json"
const POI_PATH := "user://site_pois.json"

var site: BathysSite
var source_pois: Array[Dictionary] = []
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
var vitals_list: VBoxContainer
var tissue_scale_bar: float = 1.5
var graph: BathysMetricGraph
var scrubber: HSlider
var play_button: Button
var speed_picker: OptionButton
var graph_picker: OptionButton
var playing: bool = false
var playback_time: float = 0.0
var speed: float = 1.0
var telemetry_elapsed: float = 0.0
var last_shown_index: int = -1
var fps_samples: Array[float] = []
var fps_context: String = "2D"
var fps_logged: Dictionary = {}
var import_callback: JavaScriptObject

func _ready() -> void:
	var started: int = Time.get_ticks_msec()
	site = BathysSite.new()
	if not site.load_packaged():
		push_error("Packaged site data could not be loaded.")
		return
	source_pois = BathysPoiStore.clone_pois(site.pois)
	if FileAccess.file_exists(POI_PATH):
		site.pois = BathysPoiStore.merge(FileAccess.get_file_as_string(POI_PATH), source_pois)
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
	call_deferred("recompute")

func _process(delta: float) -> void:
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
	node.pressed.connect(callback)
	return node

func clear_children(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

func build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = BG
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	var heading := HBoxContainer.new()
	root.add_child(heading)
	var title := make_label("BATHYS  ·  LAC DES ÎLES", 21, AQUA)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	view_label = make_label("2D SATELLITE", 12, AMBER)
	heading.add_child(view_label)
	heading.add_child(make_button("3D", show_3d))
	heading.add_child(make_button("SATELLITE", func() -> void: set_bathymetry(false)))
	heading.add_child(make_button("BATHYMETRY", func() -> void: set_bathymetry(true)))
	heading.add_child(make_button("HOME", home_view))
	heading.add_child(make_button("SAVE", save_plan))
	heading.add_child(make_button("LOAD", load_plan))
	heading.add_child(make_button("EXPORT", export_plan))
	heading.add_child(make_button("IMPORT", import_plan))
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)
	var tanks_panel := PanelContainer.new()
	tanks_panel.custom_minimum_size.x = 210.0
	content.add_child(tanks_panel)
	var tanks_scroll := ScrollContainer.new()
	tanks_panel.add_child(tanks_scroll)
	tank_list = VBoxContainer.new()
	tank_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tanks_scroll.add_child(tank_list)
	view_container = Control.new()
	view_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(view_container)
	map = BathysSatelliteMap.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.poi_clicked.connect(on_poi_clicked)
	map.terrain_clicked.connect(on_terrain_clicked)
	map.pick_rejected.connect(func(message: String) -> void: status_label.text = message)
	view_container.add_child(map)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size.x = 295.0
	content.add_child(tabs)
	var route_scroll := ScrollContainer.new()
	route_scroll.name = "Route"
	tabs.add_child(route_scroll)
	route_list = VBoxContainer.new()
	route_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	route_scroll.add_child(route_list)
	var site_scroll := ScrollContainer.new()
	site_scroll.name = "Site"
	tabs.add_child(site_scroll)
	site_list = VBoxContainer.new()
	site_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	site_scroll.add_child(site_list)
	var tissues_scroll := ScrollContainer.new()
	tissues_scroll.name = "Tissues"
	tabs.add_child(tissues_scroll)
	tissue_list = VBoxContainer.new()
	tissue_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tissues_scroll.add_child(tissue_list)
	var vitals_scroll := ScrollContainer.new()
	vitals_scroll.name = "Vitals"
	tabs.add_child(vitals_scroll)
	vitals_list = VBoxContainer.new()
	vitals_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vitals_scroll.add_child(vitals_list)
	var playback := VBoxContainer.new()
	playback.custom_minimum_size.y = 205.0
	root.add_child(playback)
	var controls := HBoxContainer.new()
	playback.add_child(controls)
	play_button = make_button("PLAY", toggle_play)
	controls.add_child(play_button)
	speed_picker = OptionButton.new()
	for item: String in ["0.5×", "1×", "2×", "4×", "8×"]:
		speed_picker.add_item(item)
	speed_picker.select(1)
	speed_picker.item_selected.connect(func(index: int) -> void: speed = [0.5, 1.0, 2.0, 4.0, 8.0][index])
	controls.add_child(speed_picker)
	scrubber = HSlider.new()
	scrubber.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrubber.step = 0.01
	scrubber.value_changed.connect(func(value: float) -> void: seek(value))
	controls.add_child(scrubber)
	metric_label = make_label("No simulation", 13, AQUA)
	controls.add_child(metric_label)
	graph_picker = OptionButton.new()
	for item: String in ["DEPTH / CEILING", "TTS", "NDL", "CNS", "OTU"]:
		graph_picker.add_item(item)
	graph_picker.item_selected.connect(func(index: int) -> void: choose_graph(index))
	controls.add_child(graph_picker)
	graph = BathysMetricGraph.new()
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.seek_requested.connect(seek)
	playback.add_child(graph)
	var footer := HBoxContainer.new()
	root.add_child(footer)
	status_label = make_label("", 11)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(status_label)
	telemetry_label = make_label("", 11, AQUA)
	footer.add_child(telemetry_label)
	root.add_child(make_label("EDUCATIONAL SOFTWARE ONLY · Do not use for real dive decisions. Survey datum and water level require confirmation. © swisstopo SWISSIMAGE", 11, AMBER))

func set_bathymetry(enabled: bool) -> void:
	view_3d = false
	map.show()
	if lake != null:
		lake.hide()
		lake.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	map.show_bathymetry = enabled
	view_label.text = "2D BATHYMETRY" if enabled else "2D SATELLITE"
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
	view_label.text = "3D TERRAIN"

func home_view() -> void:
	if view_3d and lake != null:
		lake.reset_view()
	else:
		map.reset_view()

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
	route_list.add_child(make_label("ORDERED EVENTS", 16, AQUA))
	var actions := HBoxContainer.new()
	route_list.add_child(actions)
	actions.add_child(make_button("+ HOLD", add_hold))
	actions.add_child(make_button("+ GAS", add_switch))
	actions.add_child(make_button("CLEAR", clear_route))
	var history := HBoxContainer.new()
	route_list.add_child(history)
	history.add_child(make_button("UNDO", undo))
	history.add_child(make_button("REDO", redo))
	var route: Array = plan.get("waypoints", []) as Array
	if route.is_empty():
		route_list.add_child(make_label("Route empty. Click a POI or surveyed bed.", 12, AMBER))
	for index: int in route.size():
		var waypoint: Dictionary = route[index] as Dictionary
		var row := VBoxContainer.new()
		route_list.add_child(row)
		var kind: String = str(waypoint.get("kind", "travel"))
		var description: String = "%d. %s" % [index + 1, str(waypoint.get("name", "Waypoint"))]
		row.add_child(make_label(description, 13, AQUA if kind == "switch" else INK))
		var details: String = "Gas switch · " + str(waypoint.get("tankId", "")) if kind == "switch" else ("Hold · %.0f s" % float(waypoint.get("holdSeconds", 0.0)) if kind == "hold" else "Travel") + " · %.1f m" % float(waypoint.get("targetDepthM", 0.0))
		row.add_child(make_label(details, 11, AMBER))
		var buttons := HBoxContainer.new()
		row.add_child(buttons)
		buttons.add_child(make_button("EDIT", func() -> void: edit_route(index)))
		buttons.add_child(make_button("↑", func() -> void: move_route(index, -1)))
		buttons.add_child(make_button("↓", func() -> void: move_route(index, 1)))
		buttons.add_child(make_button("✕", func() -> void: remove_route(index)))
		route_list.add_child(HSeparator.new())

func refresh_site() -> void:
	clear_children(site_list)
	site_list.add_child(make_label("ENVIRONMENT", 16, AQUA))
	var env: Dictionary = plan.get("environment", {}) as Dictionary
	site_list.add_child(make_label("Waterline %.2f m NF02 · surface %.3f bar" % [float(env.get("waterlineAltitudeNf02M", 478.5)), BathysPhysics.surface_bar(env)], 12))
	site_list.add_child(make_label("Density %.1f kg/m³ · GF %.0f/%.0f" % [BathysPhysics.water_density(env, 0.0), float(plan.get("gfLow", 0.3)) * 100.0, float(plan.get("gfHigh", 0.85)) * 100.0], 12))
	site_list.add_child(make_button("EDIT ENVIRONMENT", edit_environment))
	site_list.add_child(HSeparator.new())
	site_list.add_child(make_label("OBSERVED POINTS", 16, AQUA))
	site_list.add_child(make_button("+ POINT", add_poi))
	for index: int in site.pois.size():
		var poi: Dictionary = site.pois[index]
		var row := HBoxContainer.new()
		site_list.add_child(row)
		var name_button := make_button("%s · %.1f m" % [str(poi.get("name", "Point")), float(poi.get("depthM", 0.0))], func() -> void: focus_poi(poi))
		name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_button)
		row.add_child(make_button("EDIT", func() -> void: edit_poi(index)))
		if index > 0:
			row.add_child(make_button("✕", func() -> void: remove_poi(index)))
	site_list.add_child(make_label("POI depth is observed; survey depth is separate.", 11, AMBER))

func refresh_tanks() -> void:
	clear_children(tank_list)
	tank_list.add_child(make_label("CYLINDERS / SPG", 16, AQUA))
	tank_list.add_child(make_button("+ TANK", add_tank))
	var frame: Dictionary = current_frame()
	var current_id: String = str(frame.get("tankId", plan.get("initialTankId", "")))
	var tank_entries: Array = plan.get("tanks", []) as Array
	for index: int in tank_entries.size():
		var tank: Dictionary = tank_entries[index] as Dictionary
		var label_text: String = str(tank.get("name", "Tank"))
		if str(tank.get("id", "")) == current_id:
			label_text += "  ● ACTIVE"
		tank_list.add_child(make_label(label_text, 13, AQUA))
		var gauge: float = float(tank.get("startGaugeBar", 0.0))
		if frame.has("tankGaugeBar"):
			gauge = float((frame["tankGaugeBar"] as Array)[index])
		var dial := BathysSpgDial.new()
		dial.gauge_bar = gauge
		dial.maximum_bar = maxf(200.0, ceilf(float(tank.get("startGaugeBar", 200.0)) / 50.0) * 50.0)
		dial.reserve_bar = float(tank.get("reserveGaugeBar", 50.0))
		tank_list.add_child(dial)
		tank_list.add_child(make_label("%.1f bar gauge · reserve %.0f" % [gauge, float(tank.get("reserveGaugeBar", 0.0))], 11))
		var ambient: float = float(frame.get("ambientBar", BathysPhysics.surface_bar(plan["environment"] as Dictionary)))
		var temperature: float = float(frame.get("waterTempC", 18.0))
		tank_list.add_child(make_label("O₂ %.0f%% · He %.0f%%" % [float(tank.get("o2", 0.0)) * 100.0, float(tank.get("he", 0.0)) * 100.0], 11))
		tank_list.add_child(make_label("ppO₂ %.2f · density %.2f g/L" % [float(tank.get("o2", 0.0)) * ambient, BathysPhysics.gas_density(tank, ambient, temperature)], 11))
		tank_list.add_child(make_label("END %.1f m" % BathysPhysics.end_m(tank, ambient), 11))
		var mod_pressure: float = 1.4 / maxf(0.001, float(tank.get("o2", 0.21)))
		var mod_text: String = ">150" if mod_pressure > BathysPhysics.ambient_bar(plan["environment"] as Dictionary, 150.0) else "%.0f" % BathysPhysics.depth_at_bar(plan["environment"] as Dictionary, mod_pressure)
		tank_list.add_child(make_label("ppN₂ %.2f bar · MOD₁.₄ %s m" % [float(tank.get("n2", 0.79)) * ambient, mod_text], 11))
		tank_list.add_child(make_button("EDIT TANK", func() -> void: edit_tank(index)))
		tank_list.add_child(HSeparator.new())
	tank_list.add_child(make_button("STARTING GAS: " + str(plan.get("initialTankId", "")), choose_initial_gas))

func refresh_tissues() -> void:
	clear_children(tissue_list)
	tissue_list.add_child(make_label("ZH-L16C TISSUES", 16, AQUA))
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
		var n_arrow: String = "↑" if n2[i] > prior_n2[i] + 1e-6 else ("↓" if n2[i] < prior_n2[i] - 1e-6 else "→")
		var h_arrow: String = "↑" if he[i] > prior_he[i] + 1e-6 else ("↓" if he[i] < prior_he[i] - 1e-6 else "→")
		tissue_list.add_child(make_label("%02d  N₂ %.3f %s · He %.3f %s · GF %.0f%% %.2f bar" % [i + 1, n2[i], n_arrow, he[i], h_arrow, gf * 100.0, limit], 11))
		var bar := BathysTissueBar.new()
		bar.n2_bar = n2[i]
		bar.he_bar = he[i]
		bar.limit_bar = limit
		bar.scale_max_bar = tissue_scale_bar
		tissue_list.add_child(bar)

func refresh_vitals() -> void:
	clear_children(vitals_list)
	vitals_list.add_child(make_label("LIVE DIVE PHYSIOLOGY", 16, AQUA))
	var frame: Dictionary = current_frame()
	if frame.is_empty():
		return
	var ndl: Variant = frame["ndlS"]
	var tts: Variant = frame["ttsS"]
	var first_stop: Variant = frame["firstStopM"]
	vitals_list.add_child(make_label("Depth %.1f m · ambient %.2f bar" % [float(frame["depthM"]), float(frame["ambientBar"])], 13))
	vitals_list.add_child(make_label("Leading GF %.0f%% · applied GF %.0f%%" % [maxf(0.0, float(frame["leadingGf"]) * 100.0), float(frame["currentGf"]) * 100.0], 13))
	vitals_list.add_child(make_label("NDL %s min · TTS %s min" % ["—" if ndl == null else "%.0f" % (float(ndl) / 60.0), "—" if tts == null else "%.1f" % (float(tts) / 60.0)], 13))
	vitals_list.add_child(make_label("Ceiling %.1f m · first stop %s" % [float(frame["ceilingM"]), "—" if first_stop == null else "%.0f m" % float(first_stop)], 13))
	vitals_list.add_child(make_label("CNS %.1f%% · OTU %.1f" % [float(frame["cnsPercent"]), float(frame["otu"])], 13))
	vitals_list.add_child(make_label("Water %.1f °C · compartment %d" % [float(frame["waterTempC"]), int(frame["controllingCompartment"])], 13))
	vitals_list.add_child(make_label("Used %.1f surface L · active %s" % [float(frame["usedSurfaceL"]), str(frame["tankId"])], 13))
	add_guidance("ppO₂", float(frame["ppO2Bar"]), 0.16, 1.4, 1.6, 1.9, "bar", "0.16", "1.4", "1.6")
	add_guidance("Gas density", float(frame["densityGPerL"]), 0.0, 5.2, 6.2, 7.2, "g/L", "", "5.2", "6.2")
	add_guidance("END", float(frame["endM"]), 0.0, 30.0, 30.0, 40.0, "m", "", "30", "")
	vitals_list.add_child(make_label("Reference bands are display guidance; exertion and individual response are not measured.", 11, AMBER))

func add_guidance(title: String, value: float, minimum: float, working: float, rest: float,
		chart: float, unit: String, min_caption: String, work_caption: String, rest_caption: String) -> void:
	var color: Color = RED if value < minimum or value > rest else (AMBER if value > working else AQUA)
	vitals_list.add_child(make_label("%s  %.2f %s" % [title, value, unit], 13, color))
	var gauge := BathysGasRangeGauge.new()
	gauge.working_min = minimum
	gauge.working_max = working
	gauge.rest_max = rest
	gauge.chart_max = chart
	gauge.current_value = value
	gauge.min_caption = min_caption
	gauge.working_caption = work_caption
	gauge.rest_caption = rest_caption
	vitals_list.add_child(gauge)

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
	if index == last_shown_index:
		return
	last_shown_index = index
	var frame: Dictionary = frames[index]
	graph.current_time = playback_time
	graph.queue_redraw()
	map.set_diver(float(frame["latitudeDeg"]), float(frame["longitudeDeg"]))
	if lake != null:
		lake.set_diver(float(frame["latitudeDeg"]), float(frame["longitudeDeg"]), float(frame["depthM"]))
	metric_label.text = "%02d:%02d · %.1f m · ceiling %.1f m · ppO₂ %.2f" % [int(playback_time / 60.0), int(playback_time) % 60, float(frame["depthM"]), float(frame["ceilingM"]), float(frame["ppO2Bar"])]
	refresh_tanks()
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

func choose_graph(index: int) -> void:
	graph.metric = ["depth", "tts", "ndl", "cns", "otu"][index]
	graph.queue_redraw()

func recompute() -> void:
	var started: int = Time.get_ticks_msec()
	var result: Dictionary = BathysSimulation.run(site, plan)
	frames.clear()
	legs.clear()
	if str(result.get("error", "")) != "":
		status_label.text = str(result["error"])
		metric_label.text = "Simulation unavailable"
		graph.frames = []
		graph.queue_redraw()
		return
	for frame: Variant in result["frames"]:
		frames.append(frame as Dictionary)
	for leg: Variant in result["legs"]:
		legs.append(leg as Dictionary)
	graph.frames = frames
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
	call_deferred("recompute")

func undo() -> void:
	restore_from_stack(undo_stack, redo_stack)

func redo() -> void:
	restore_from_stack(redo_stack, undo_stack)

func changed() -> void:
	BathysPlan.anchor_holds(plan, site)
	map.set_waterline(float((plan["environment"] as Dictionary)["waterlineAltitudeNf02M"]))
	if lake != null:
		lake.set_waterline(float((plan["environment"] as Dictionary)["waterlineAltitudeNf02M"]))
	refresh_all()
	status_label.text = "Simulating edited plan…"
	call_deferred("recompute")

func on_poi_clicked(poi: Dictionary) -> void:
	snapshot()
	(plan["waypoints"] as Array).append(BathysPlan.waypoint_at_poi(poi))
	changed()

func on_terrain_clicked(lat: float, lon: float, depth: float, interpolated: bool) -> void:
	snapshot()
	var waypoint: Dictionary = BathysPlan.waypoint_at_poi({"name": "Interpolated waypoint" if interpolated else "Survey waypoint", "latitudeDeg": lat, "longitudeDeg": lon, "depthM": depth})
	waypoint["poiId"] = null
	(plan["waypoints"] as Array).append(waypoint)
	changed()

func add_hold() -> void:
	snapshot()
	(plan["waypoints"] as Array).append(BathysPlan.hold())
	changed()

func add_switch() -> void:
	var tanks: Array = plan["tanks"] as Array
	var selected: String = str((tanks[-1] as Dictionary).get("id", ""))
	snapshot()
	(plan["waypoints"] as Array).append(BathysPlan.gas_switch(selected, "Switch to " + str((tanks[-1] as Dictionary).get("name", selected))))
	changed()

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

func field(key: String, caption: String, value: Variant, minimum: float = -100000.0, maximum: float = 100000.0, step: float = 0.01) -> Dictionary:
	return {"key": key, "caption": caption, "value": value, "minimum": minimum, "maximum": maximum, "step": step}

func edit_fields(title: String, fields: Array[Dictionary], apply: Callable, selector_key: String = "") -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.size = Vector2i(420, 500)
	add_child(dialog)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(390.0, 300.0)
	dialog.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var inputs: Dictionary = {}
	for descriptor: Dictionary in fields:
		var key: String = str(descriptor["key"])
		column.add_child(make_label(str(descriptor["caption"]), 12, AQUA))
		var control: Control
		if key == selector_key:
			var options := OptionButton.new()
			var selected_id: String = str(descriptor["value"])
			for entry: Variant in plan["tanks"]:
				var tank: Dictionary = entry as Dictionary
				options.add_item(str(tank.get("name", "Tank")))
				options.set_item_metadata(options.item_count - 1, str(tank.get("id", "")))
				if str(tank.get("id", "")) == selected_id:
					options.select(options.item_count - 1)
			control = options
		elif descriptor["value"] is String:
			var entry := LineEdit.new()
			entry.text = str(descriptor["value"])
			control = entry
		else:
			var spin := SpinBox.new()
			spin.min_value = float(descriptor["minimum"])
			spin.max_value = float(descriptor["maximum"])
			spin.step = float(descriptor["step"])
			spin.value = float(descriptor["value"])
			spin.select_all_on_focus = true
			control = spin
		column.add_child(control)
		inputs[key] = control
	dialog.confirmed.connect(func() -> void:
		var values: Dictionary = {}
		for key: String in inputs.keys():
			var control: Control = inputs[key] as Control
			if control is LineEdit:
				values[key] = (control as LineEdit).text
			elif control is SpinBox:
				values[key] = (control as SpinBox).value
			elif control is OptionButton:
				var option: OptionButton = control as OptionButton
				values[key] = option.get_item_metadata(option.selected)
		apply.call(values)
		dialog.queue_free())
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered()

func edit_route(index: int) -> void:
	var route: Array = plan["waypoints"] as Array
	var waypoint: Dictionary = route[index] as Dictionary
	var kind: String = str(waypoint.get("kind", "travel"))
	var fields: Array[Dictionary] = [field("name", "Name", str(waypoint.get("name", "Waypoint")))]
	if kind == "switch":
		fields.append(field("tankId", "Gas", str(waypoint.get("tankId", ""))))
	elif kind == "hold":
		fields.append(field("sacLPerMin", "SAC (L/min)", float(waypoint.get("sacLPerMin", 18.0)), 1.0, 100.0))
		fields.append(field("holdSeconds", "Duration (s)", float(waypoint.get("holdSeconds", 180.0)), 1.0, 7200.0, 1.0))
	else:
		fields.append(field("targetDepthM", "Target depth (m)", float(waypoint.get("targetDepthM", 0.0)), 0.0, 100.0))
		fields.append(field("speedMPerMin", "Swim speed (m/min)", float(waypoint.get("speedMPerMin", 12.0)), 1.0, 60.0))
		fields.append(field("sacLPerMin", "SAC (L/min)", float(waypoint.get("sacLPerMin", 18.0)), 1.0, 100.0))
		fields.append(field("latitudeDeg", "Latitude WGS84", float(waypoint.get("latitudeDeg", site.origin_lat)), -90.0, 90.0, 0.0000001))
		fields.append(field("longitudeDeg", "Longitude WGS84", float(waypoint.get("longitudeDeg", site.origin_lon)), -180.0, 180.0, 0.0000001))
	edit_fields("Edit " + kind, fields, func(values: Dictionary) -> void:
		snapshot()
		for key: String in values.keys():
			waypoint[key] = values[key]
		if kind == "travel":
			waypoint["poiId"] = null
		changed(), "tankId" if kind == "switch" else "")

func edit_environment() -> void:
	var env: Dictionary = plan["environment"] as Dictionary
	var fields: Array[Dictionary] = [
		field("waterlineAltitudeNf02M", "Waterline altitude (m NF02)", float(env.get("waterlineAltitudeNf02M", 478.5)), 0.0, 3000.0),
		field("salinityGPerKg", "Salinity (g/kg)", float(env.get("salinityGPerKg", 0.0)), 0.0, 40.0),
		field("surfaceTempC", "Surface temperature (°C)", float(env.get("surfaceTempC", 18.0)), 0.0, 40.0),
		field("minTempC", "Minimum temperature (°C)", float(env.get("minTempC", 5.0)), 0.0, 40.0),
		field("tempDropCPerM", "Temperature drop (°C/m)", float(env.get("tempDropCPerM", 0.2)), 0.0, 2.0),
		field("gfLow", "GF low", float(plan.get("gfLow", 0.3)), 0.01, 1.0),
		field("gfHigh", "GF high", float(plan.get("gfHigh", 0.85)), 0.01, 1.0),
		field("descentMPerMin", "Descent (m/min)", float(plan.get("descentMPerMin", 18.0)), 1.0, 40.0),
		field("ascentMPerMin", "Ascent (m/min)", float(plan.get("ascentMPerMin", 9.0)), 1.0, 30.0)]
	edit_fields("Environment and model", fields, func(values: Dictionary) -> void:
		snapshot()
		for key: String in values.keys():
			if key in ["gfLow", "gfHigh", "descentMPerMin", "ascentMPerMin"]:
				plan[key] = values[key]
			else:
				env[key] = values[key]
		changed())

func save_pois() -> void:
	var file: FileAccess = FileAccess.open(POI_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(BathysPoiStore.save(source_pois, site.pois))
		file.close()
	else:
		status_label.text = "Could not save POI edits."

func add_poi() -> void:
	var poi: Dictionary = {"id": BathysPlan.id(), "name": "New point", "latitudeDeg": site.origin_lat,
		"longitudeDeg": site.origin_lon, "depthM": 0.0, "spreadM": null}
	site.pois.append(poi)
	save_pois()
	refresh_site()
	map.queue_redraw()
	edit_poi(site.pois.size() - 1)

func edit_poi(index: int) -> void:
	var poi: Dictionary = site.pois[index]
	var fields: Array[Dictionary] = [field("name", "Name", str(poi.get("name", "Point"))),
		field("latitudeDeg", "Latitude WGS84", float(poi.get("latitudeDeg", 0.0)), -90.0, 90.0, 0.0000001),
		field("longitudeDeg", "Longitude WGS84", float(poi.get("longitudeDeg", 0.0)), -180.0, 180.0, 0.0000001),
		field("depthM", "Observed depth (m)", float(poi.get("depthM", 0.0)), 0.0, 100.0)]
	edit_fields("Edit observed POI", fields, func(values: Dictionary) -> void:
		for key: String in values.keys():
			poi[key] = values[key]
		save_pois()
		refresh_site()
		map.queue_redraw()
		if lake != null:
			lake.refresh_pois())

func remove_poi(index: int) -> void:
	if index <= 0 or index >= site.pois.size():
		return
	site.pois.remove_at(index)
	save_pois()
	refresh_site()
	map.queue_redraw()
	if lake != null:
		lake.refresh_pois()

func focus_poi(poi: Dictionary) -> void:
	if view_3d and lake != null:
		lake.focus_poi(poi)
		status_label.text = "%s · observed depth %.1f m" % [str(poi["name"]), float(poi["depthM"])]
		return
	var point: Vector2 = map.project(float(poi["latitudeDeg"]), float(poi["longitudeDeg"]))
	map.pan += map.size / 2.0 - point
	map.queue_redraw()
	status_label.text = "%s · observed depth %.1f m" % [str(poi["name"]), float(poi["depthM"])]

func add_tank() -> void:
	snapshot()
	var tank_id: String = BathysPlan.id()
	(plan["tanks"] as Array).append({"id": tank_id, "name": "New tank", "volumeL": 12.0,
		"startGaugeBar": 200.0, "reserveGaugeBar": 50.0, "o2": 0.21, "n2": 0.79, "he": 0.0})
	changed()
	edit_tank((plan["tanks"] as Array).size() - 1)

func edit_tank(index: int) -> void:
	var tank: Dictionary = (plan["tanks"] as Array)[index] as Dictionary
	var fields: Array[Dictionary] = [field("name", "Name", str(tank.get("name", "Tank"))),
		field("volumeL", "Volume (L)", float(tank.get("volumeL", 12.0)), 1.0, 40.0),
		field("startGaugeBar", "Start gauge (bar)", float(tank.get("startGaugeBar", 200.0)), 1.0, 400.0),
		field("reserveGaugeBar", "Reserve gauge (bar)", float(tank.get("reserveGaugeBar", 50.0)), 0.0, 399.0),
		field("o2", "O₂ fraction", float(tank.get("o2", 0.21)), 0.01, 1.0),
		field("n2", "N₂ fraction", float(tank.get("n2", 0.79)), 0.0, 1.0),
		field("he", "He fraction", float(tank.get("he", 0.0)), 0.0, 1.0)]
	edit_fields("Edit cylinder", fields, func(values: Dictionary) -> void:
		snapshot()
		for key: String in values.keys():
			tank[key] = values[key]
		changed())

func choose_initial_gas() -> void:
	edit_fields("Starting gas", [field("initialTankId", "Tank", str(plan.get("initialTankId", "")))], func(values: Dictionary) -> void:
		snapshot()
		plan["initialTankId"] = values["initialTankId"]
		changed(), "initialTankId")

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
