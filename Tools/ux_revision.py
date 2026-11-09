from pathlib import Path
p=Path('Scripts/Main.gd')
s=p.read_text()
s=s.replace('var site: BathysSite','''var metric_cards: Dictionary = {}
var visible_metrics: Array[String] = ["depthM"]
var metric_grid: GridContainer
var metrics_menu: PopupMenu
var inspection: PopupPanel
var saved_state: String = ""
var save_state_label: Label
var summary_label: Label
var feedback_label: Label
var content_box: BoxContainer
var header_box: BoxContainer
var center_panel: PanelContainer
var left_panel: PanelContainer
var right_panel: PanelContainer
var selected_event: int = -1
var site: BathysSite''',1)
a=s.index('\tplan = BathysPlan.example(site)'); b=s.index('\tbuild_ui()',a)
s=s[:a]+'\tplan = BathysPlan.empty(site)\n\tsaved_state = JSON.stringify(plan)\n'+s[b:]
s=s.replace('\tcall_deferred("show_3d")','\tget_viewport().size_changed.connect(adapt_layout)\n\tcall_deferred("adapt_layout")')
s=s.replace('node.focus_mode = Control.FOCUS_NONE','node.focus_mode = Control.FOCUS_ALL')
s=s.replace('var root := VBoxContainer.new()\n\troot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)', '''var page_scroll := ScrollContainer.new()
	page_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(page_scroll)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL''')
s=s.replace('\tadd_child(root)','\tpage_scroll.add_child(root)',1)
s=s.replace('var heading := HBoxContainer.new()','var heading := BoxContainer.new()\n\theader_box = heading',1)
s=s.replace('\theading.add_child(make_label("SION · SWITZERLAND  •  EDUCATIONAL MODEL", 11, BathysUiStyle.MUTED))','''	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(identity)
	var plan_name := LineEdit.new()
	plan_name.text = str(plan.get("name", "Untitled scenario"))
	plan_name.name = "PlanName"
	plan_name.placeholder_text = "Scenario name"
	plan_name.text_changed.connect(func(value: String) -> void: plan["name"] = value; update_saved_state())
	identity.add_child(plan_name)
	save_state_label = make_label("New scenario · saved plans are opened with Load", 12, BathysUiStyle.MUTED)
	identity.add_child(save_state_label)''')
s=s.replace('var content := HBoxContainer.new()','var content := BoxContainer.new()\n\tcontent_box = content',1)
s=s.replace('var tanks_panel: PanelContainer = BathysUiStyle.panel()','var tanks_panel: PanelContainer = BathysUiStyle.panel()\n\tleft_panel = tanks_panel',1)
s=s.replace('var center: PanelContainer = BathysUiStyle.panel()','var center: PanelContainer = BathysUiStyle.panel()\n\tcenter_panel = center',1)
s=s.replace('var right: PanelContainer = BathysUiStyle.panel(BathysUiStyle.PANEL, 4)','var right: PanelContainer = BathysUiStyle.panel(BathysUiStyle.PANEL, 4)\n\tright_panel = right',1)
s=s.replace('\tview_bar.add_child(view_title)','\tview_title.visible = false\n\tview_bar.add_child(view_title)',1)
s=s.replace('\tplayback.add_child(live_heading)','''	summary_label = BathysUiStyle.wrapped("Start by inspecting the map, then add a waypoint and a tank.", 14)
	playback.add_child(summary_label)
	feedback_label = BathysUiStyle.wrapped("", 14, AMBER)
	feedback_label.visible = false
	playback.add_child(feedback_label)
	playback.add_child(live_heading)''',1)
s=s.replace('\tlive_heading.add_child(telemetry_label)','\ttelemetry_label.visible = false\n\tlive_heading.add_child(telemetry_label)')
s=s.replace('var cards := HBoxContainer.new()\n\tplayback.add_child(cards)','''var metrics_row := HBoxContainer.new()
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
	metrics_menu.id_pressed.connect(toggle_metric)''')
s=s.replace('\t\tcards.add_child(card)','''		cards.add_child(card)
		metric_cards[str(entry[1])] = card
		card.visible = str(entry[1]) in visible_metrics''',1)
s=s.replace('stack.add_child(make_label(str(entry[0]), 10, BathysUiStyle.MUTED))','''var metric_title := HBoxContainer.new()
		stack.add_child(metric_title)
		var caption := make_label(str(entry[0]), 12, BathysUiStyle.MUTED)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		metric_title.add_child(caption)
		var remove := make_button("×", func() -> void: toggle_metric(metric_cards.keys().find(str(entry[1]))))
		remove.tooltip_text = "Hide readout"
		metric_title.add_child(remove)''')
s=s.replace('\tplayback.add_child(extra_label)','''	var details_toggle := CheckButton.new()
	details_toggle.text = "More simulation details"
	details_toggle.toggled.connect(func(enabled: bool) -> void: extra_label.visible = enabled)
	playback.add_child(details_toggle)
	extra_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	extra_label.visible = false
	playback.add_child(extra_label)''')
s=s.replace('var jump := make_button(metric.to_upper(), func() -> void: plot_scroll.scroll_vertical = int(chart.position.y))','''chart.visible = metric == "depth"
		var jump := make_button(metric.to_upper(), func() -> void:
			for item: BathysMetricGraph in graphs:
				item.visible = item.metric == metric)''')
s=s.replace('\troot.add_child(warning)','\twarning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART\n\troot.add_child(warning)')
s=s.replace('Click a POI or surveyed bed to add','Click a point to inspect')
s=s.replace('Wheel to zoom · Click to add','Wheel to zoom · Click to inspect')
s=s.replace('Click terrain or a marker to append. Small gap fills are marked as interpolated. Ctrl+Z undo · Ctrl+Y redo.','Inspect a map point, then choose Add waypoint. Use + between events to insert a hold or gas switch. The route starts at Dive entrance. Ctrl+Z undo · Ctrl+Y redo.')
a=s.index('\tvar actions := HBoxContainer.new()',s.index('func refresh_route')); b=s.index('\tvar history :=',a)
s=s[:a]+s[b:]
s=s.replace('\tfor index: int in route.size():','''	if route.is_empty():
		route_list.add_child(BathysUiStyle.wrapped("Your route is empty. Inspect the map to choose your first destination."))
	add_insertion_slot(0)
	for index: int in route.size():''',1)
s=s.replace('\t\tif kind == "switch":\n\t\t\tdetails.free()','\t\tadd_insertion_slot(index + 1)\n\t\tif kind == "switch":\n\t\t\tdetails.free()',1)
s=s.replace('\ttank_list.add_child(make_label("START GAS", 10, BathysUiStyle.MUTED))','''	if (plan["tanks"] as Array).is_empty():
		tank_list.add_child(BathysUiStyle.wrapped("No gases selected. Add a tank and enter its mix and pressures to simulate your route."))
	tank_list.add_child(make_label("START GAS", 10, BathysUiStyle.MUTED))''')
s=s.replace('\t(plan["tanks"] as Array).append({"id": tank_id,','\tif (plan["tanks"] as Array).is_empty():\n\t\tplan["initialTankId"] = tank_id\n\t(plan["tanks"] as Array).append({"id": tank_id,')
s=s.replace('\tif tank_id == str(plan["initialTankId"]):','\tif tank_id == str(plan["initialTankId"]) and tanks.size() > 1:',1)
s=s.replace('\tif tanks.size() < 2:\n\t\treturn\n','',1)
s=s.replace('plan["initialTankId"] = (tanks[0] as Dictionary)["id"]','plan["initialTankId"] = (tanks[0] as Dictionary)["id"] if not tanks.is_empty() else ""')
s=s.replace('func on_poi_clicked(poi: Dictionary) -> void:\n\tsnapshot()\n\t(plan["waypoints"] as Array).append(BathysPlan.waypoint_at_poi(poi))\n\tchanged(true)','''func on_poi_clicked(poi: Dictionary) -> void:
	inspect_location(poi, false)''')
a=s.index('\tsnapshot()',s.index('func on_terrain_clicked')); b=s.index('\nfunc add_hold',a)
s=s[:a]+'''	inspect_location({"name": "Surveyed lakebed", "latitudeDeg": lat, "longitudeDeg": lon, "depthM": depth}, interpolated)
'''+s[b:]
s=s.replace('\tstatus_label.text = "Updating simulation…"','\tupdate_saved_state()\n\tstatus_label.text = "Updating simulation…"')
s=s.replace('func changed(route_only: bool = false) -> void:\n','func changed(route_only: bool = false) -> void:\n\tupdate_saved_state()\n')
s=s.replace('\trequest_simulation()\n\nfunc undo()', '\tupdate_saved_state()\n\trequest_simulation()\n\nfunc undo()')
s=s.replace('\tfile.close()\n\tstatus_label.text = "Saved plan to browser storage (user://plan.json)."','\tfile.close()\n\tsaved_state = JSON.stringify(plan)\n\tupdate_saved_state()\n\tstatus_label.text = "Saved on this device. Export a file for a portable backup."')
s=s.replace('\tstatus_label.text = "Plan loaded."','''	saved_state = JSON.stringify(plan)
	update_saved_state()
	var name_input := find_child("PlanName", true, false) as LineEdit
	name_input.text = str(plan.get("name", "Untitled scenario"))
	status_label.text = "Plan loaded."''')
s=s.replace('\tplaying = false\n\tplay_button.text = "PLAY"\n\tplay_button.icon = load("res://Assets/Icons/play.svg")\n\tif not (plan', '''	playing = false
	play_button.text = "PLAY"
	play_button.icon = load("res://Assets/Icons/play.svg")
	feedback_label.visible = false
	if not (plan''',1)
s=s.replace('\t\tstatus_label.text = "Route empty · click the map to add a waypoint"','\t\tsummary_label.text = "Start by inspecting the map, then add a waypoint and a tank."\n\t\tstatus_label.text = "Route empty · inspect the map to begin"')
s=s.replace('\t\tstatus_label.text = str(result["error"])','''		status_label.text = "Simulation needs attention"
		feedback_label.text = str(result["error"]) + " Edit the route or tank settings, then the simulation will update."
		feedback_label.visible = true
		summary_label.text = "Route: %d events · simulation unavailable for current inputs" % (plan["waypoints"] as Array).size()''')
s=s.replace('\tstatus_label.text = "Simulated %d frames in %.2f s · %d route events" % [frames.size(), float(Time.get_ticks_msec() - started) / 1000.0, legs.size()]','''	status_label.text = "Simulation up to date"
	var maximum_depth: float = 0
	for frame: Dictionary in frames:
		maximum_depth = maxf(maximum_depth, float(frame["depthM"]))
	summary_label.text = "SCENARIO · %.1f min · max depth %.1f m · %d route events" % [float(result["durationS"])/60, maximum_depth, legs.size()]''')
p.write_text(s)
# Empty plans remain valid portable drafts, but cannot be simulated without a tank.
p=Path('Scripts/Core/Plan.gd'); s=p.read_text(); pos=s.index('static func example')
s=s[:pos]+'''static func empty(site: BathysSite) -> Dictionary:
	var plan: Dictionary = example(site)
	plan["name"] = "Untitled scenario"
	plan["waypoints"] = []
	plan["tanks"] = []
	plan["initialTankId"] = ""
	return plan

'''+s[pos:]
s=s.replace('if tanks.is_empty():\n\t\treturn "Add at least one tank."','if tanks.is_empty() and require_route:\n\t\treturn "Add a tank and choose its gas mix to simulate this route."')
s=s.replace('if not ids.has(str(plan.get("initialTankId", ""))):','if not tanks.is_empty() and not ids.has(str(plan.get("initialTankId", ""))):')
p.write_text(s)
