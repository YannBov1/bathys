from pathlib import Path
p=Path('Scripts/Main.gd');s=p.read_text()
s=s.replace('inline_number(grid, "n2", "N₂", tank, 0, 100, 1, "%", 100)','var nitrogen := inline_number(grid, "n2", "N₂ (BALANCE)", tank, 0, 100, 1, "%", 100)\n\t\tnitrogen.editable = false')
s=s.replace('Fractions must total 100%. Change one, then balance another.','Set oxygen and helium; nitrogen fills the remaining percentage automatically.')
s=s.replace('\ttarget[key] = value\n\tif key in', '''	target[key] = value
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
	if key in''',1)
s=s.replace('body.add_child(make_label("Depth %.1f m" % float(location.get("depthM", 0)), 16))','body.add_child(make_label(("Reference depth %.1f m" if location.has("id") else "Lakebed depth %.1f m") % float(location.get("depthM", 0)), 16))')
s=s.replace('Depth uses the illustrative waterline. Survey: NavSurf 2015. POI positions may be approximate.','Survey: NavSurf 2015. Lakebed depths use the illustrative waterline; POI depths are reference observations and positions may be approximate.')
s=s.replace('\tsummary_label.text = "SCENARIO · %.1f min · max depth %.1f m · %d route events" % [float(result["durationS"])/60, maximum_depth, legs.size()]','''	var reserve_summary: String = ""
	var end_pressures: Array = frames[-1]["tankGaugeBar"]
	for i: int in (plan["tanks"] as Array).size():
		var tank: Dictionary = plan["tanks"][i]
		reserve_summary += " · %s ends %.0f bar (reserve %.0f)" % [str(tank["name"]), float(end_pressures[i]), float(tank["reserveGaugeBar"])]
	summary_label.text = "SCENARIO · %.1f min · max depth %.1f m · %d events%s" % [float(result["durationS"])/60, maximum_depth, legs.size(), reserve_summary]''')
# Undo also restores the editable scenario title.
s=s.replace('\tplan = BathysPlan.from_json(source.pop_back(), site)','\tplan = BathysPlan.from_json(source.pop_back(), site)\n\t(find_child("PlanName", true, false) as LineEdit).text = str(plan.get("name", "Untitled scenario"))')
p.write_text(s)
p=Path('Scripts/MetricGraph.gd');s=p.read_text().replace('\tmouse_filter = Control.MOUSE_FILTER_STOP','\tfocus_mode = Control.FOCUS_ALL\n\ttooltip_text = "Click or drag to seek. Focus and use Left/Right to move 10 seconds."\n\tmouse_filter = Control.MOUSE_FILTER_STOP',1)
s=s.replace('func _gui_input(event: InputEvent) -> void:\n','''func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not frames.is_empty():
		if event.keycode in [KEY_LEFT, KEY_RIGHT]:
			seek_requested.emit(clampf(current_time + (-10 if event.keycode == KEY_LEFT else 10), 0, float(frames[-1]["timeS"])))
			accept_event()
		return
''',1);p.write_text(s)
