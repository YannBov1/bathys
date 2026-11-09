from pathlib import Path
p=Path('Scripts/Main.gd');s=p.read_text()
s=s.replace('var selected_event: int = -1','var selected_event: int = -1\nvar inspection_location: Dictionary = {}\nvar inspection_interpolated: bool = false')
s=s.replace('\theading.add_child(make_button("SAVE PLAN", save_plan))','\theading.add_child(make_button("NEW", new_plan))\n\theading.add_child(make_button("SAVE PLAN", save_plan))')
s=s.replace('\tinspection = PopupPanel.new()','\tinspection_location = location.duplicate(true)\n\tinspection_interpolated = interpolated\n\tinspection = PopupPanel.new()',1)
a=s.index('\tbody.add_child(make_button("Add waypoint"');b=s.index('\n\tbody.add_child(make_button("Close"',a)
s=s[:a]+'\tbody.add_child(make_button("Add waypoint", add_inspected_waypoint))'+s[b:]
s += '''
func add_inspected_waypoint() -> void:
	if inspection_location.is_empty():
		return
	snapshot()
	var waypoint: Dictionary = BathysPlan.waypoint_at_poi(inspection_location)
	if not inspection_location.has("id"):
		waypoint["poiId"] = null
		waypoint["name"] = "Interpolated waypoint" if inspection_interpolated else "Survey waypoint"
	(plan["waypoints"] as Array).append(waypoint)
	if is_instance_valid(inspection):
		inspection.hide()
	changed(true)

func new_plan() -> void:
	snapshot()
	plan = BathysPlan.empty(site)
	playback_time = 0
	var name_input := find_child("PlanName", true, false) as LineEdit
	name_input.text = str(plan["name"])
	changed()
'''
# Error location metadata leaves all successful numerical results unchanged.
p.write_text(s)
p=Path('Scripts/Core/Simulation.gd');s=p.read_text();s=s.replace('for item: Variant in plan["waypoints"]:\n','for event_index: int in (plan["waypoints"] as Array).size():\n\t\tvar item: Variant = plan["waypoints"][event_index]\n',1)
a=s.index('\tfor event_index:');b=s.index('\n\tif float(frames[-1]',a)
chunk=s[a:b].replace('"frames": frames, "legs": legs}', '"frames": frames, "legs": legs, "eventIndex": event_index}')
s=s[:a]+chunk+s[b:];p.write_text(s)
p=Path('Scripts/Main.gd');s=p.read_text().replace('var selected_event: int = -1','var selected_event: int = -1')
s=s.replace('\tfeedback_label.visible = false\n\tif not (plan','\tfeedback_label.visible = false\n\tselected_event = -1\n\tif not (plan',1)
s=s.replace('\t\tfeedback_label.visible = true\n\t\tsummary_label.text', '''		feedback_label.visible = true
		selected_event = int(result.get("eventIndex", -1))
		if selected_event >= 0:
			feedback_label.text = "Event %d · " % (selected_event + 1) + feedback_label.text
			var route: Array = plan["waypoints"]
			expanded_routes[str(route[selected_event]["id"])] = true
		refresh_route()
		summary_label.text''',1)
s=s.replace('\t\tcard.name = "Route_" + str(index)','\t\tif index == selected_event:\n\t\t\tcard.add_theme_stylebox_override("panel", BathysUiStyle.box(Color("44323a"), AMBER))\n\t\tcard.name = "Route_" + str(index)',1)
s=s.replace('\tupdate_route_summaries()\n\ttissue_scale_bar', '\trefresh_route()\n\ttissue_scale_bar',1) # remove prior error highlight after successful result
# field tooltips
s=s.replace('\tinput.name = key\n\tinput.min_value', '''	input.name = key
	var help: Dictionary = {"sacLPerMin": "Surface air consumption: gas used per minute at surface pressure.", "gfLow": "Gradient factor used for deeper decompression stops. Low must not exceed High.", "gfHigh": "Gradient factor approaching the surface. High must be at least Low.", "waterlineAltitudeNf02M": "Illustrative lake elevation in the NF02 datum; affects depth and atmospheric pressure.", "reserveGaugeBar": "Simulation stops if this tank would fall below its reserve.", "targetDepthM": "Depth below the selected waterline, independent of lakebed depth."}
	input.tooltip_text = str(help.get(key, caption.capitalize() + " (" + suffix + ")"))
	input.min_value''',1)
s=s.replace('JavaScriptBridge.download_buffer(bytes, "bathys-plan.json", "application/json")','JavaScriptBridge.download_buffer(bytes, str(plan.get("name", "bathys-plan")).validate_filename() + ".json", "application/json")')
p.write_text(s)
# Disable canvas scaling so text and layout use real viewport size.
p=Path('project.godot');s=p.read_text().replace('window/stretch/mode="canvas_items"','window/stretch/mode="disabled"');p.write_text(s)
# Existing tests explicitly choose their fixture now that production startup is empty.
for filename in ['Tests/UiSmoke.gd','Tests/Responsiveness.gd']:
 p=Path(filename);s=p.read_text();s=s.replace('\troot.add_child(app)\n','\troot.add_child(app)\n\tapp.plan = BathysPlan.example(app.site)\n\tapp.refresh_all()\n\tapp.request_simulation()\n')
 if 'Responsiveness' in filename:
  s=s.replace('app.on_poi_clicked(site.pois[1])','app.on_poi_clicked(site.pois[1])\n\tapp.add_inspected_waypoint()').replace('app.on_poi_clicked(site.pois[2])','app.on_poi_clicked(site.pois[2])\n\tapp.add_inspected_waypoint()')
 p.write_text(s)
