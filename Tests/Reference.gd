extends SceneTree

var passed: int = 0
var failed: int = 0

func near(actual: float, expected: float, tolerance: float, label: String) -> void:
	if absf(actual - expected) <= tolerance:
		passed += 1
		print("PASS ", label, " difference=", actual - expected)
	else:
		failed += 1
		push_error("FAIL " + label + ": " + str(actual) + " vs " + str(expected)
			+ ", difference " + str(actual - expected) + ", tolerance " + str(tolerance))

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)

func compare_frame(actual: Dictionary, expected: Dictionary, label: String) -> void:
	for field: String in ["timeS", "latitudeDeg", "longitudeDeg", "depthM", "ambientBar",
		"ceilingM", "leadingGf", "currentGf", "cnsPercent", "otu", "ppO2Bar",
		"densityGPerL", "endM", "waterTempC", "usedSurfaceL"]:
		near(float(actual[field]), float(expected[field]), 1e-8, label + " " + field)
	for field: String in ["ndlS", "ttsS", "firstStopM"]:
		if expected[field] == null:
			check(actual[field] == null, label + " " + field + " null")
		else:
			near(float(actual[field]), float(expected[field]), 1e-8, label + " " + field)
	check(str(actual["tankId"]) == str(expected["tankId"]), label + " tank ID")
	check(int(actual["controllingCompartment"]) == int(expected["controllingCompartment"]), label + " controlling compartment")
	var actual_gauges: Array = actual["tankGaugeBar"] as Array
	var expected_gauges: Array = expected["tankGaugeBar"] as Array
	for i: int in actual_gauges.size():
		near(float(actual_gauges[i]), float(expected_gauges[i]), 1e-7, label + " gauge " + str(i))
	var actual_n: PackedFloat64Array = actual["tissueN2Bar"] as PackedFloat64Array
	var actual_h: PackedFloat64Array = actual["tissueHeBar"] as PackedFloat64Array
	var expected_n: Array = expected["tissueN2Bar"] as Array
	var expected_h: Array = expected["tissueHeBar"] as Array
	for i: int in 16:
		near(actual_n[i], float(expected_n[i]), 1e-10, label + " tissue N2 " + str(i))
		near(actual_h[i], float(expected_h[i]), 1e-10, label + " tissue He " + str(i))

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var source: BathysSite = BathysSite.new()
	check(source.load_packaged(), "packaged site and grid load")
	check(source.measured_count == 439564 and source.interpolated_count == 2184, "measured and interpolated counts")
	var reference: Dictionary = BathysSite.read_json("res://Tests/python_reference.json")
	var env: Dictionary = {"waterlineAltitudeNf02M": 500.0, "salinityGPerKg": 0.0,
		"surfaceTempC": 18.0, "minTempC": 18.0, "tempDropCPerM": 0.0}
	near(BathysPhysics.surface_bar(env), float(reference["surfaceBar500m"]), 1e-12, "ISA surface pressure vs Python")
	near(BathysPhysics.water_density(env, 10.0), float(reference["freshwaterDensity18C"]), 1e-9, "water density vs Python")
	near(BathysPhysics.depth_at_bar(env, BathysPhysics.ambient_bar(env, 28.0)), 28.0, 0.0001, "pressure inversion")
	var gas: Dictionary = {"o2": 0.28, "n2": 0.72, "he": 0.0}
	near(BathysPhysics.gas_density(gas, 3.0, 15.0), float(reference["densityGPerL"]), 1e-8, "Peng-Robinson density vs Python")
	near(BathysPhysics.cns_rate(0.84) * 600.0, float(reference["cnsPercent"]), 1e-8, "NOAA CNS vs Python")
	near(BathysPhysics.otu_rate(0.84) * 600.0, float(reference["otu"]), 1e-8, "OTU vs Python")
	var tank: Dictionary = {"volumeL": 12.0, "startGaugeBar": 200.0, "reserveGaugeBar": 2.0,
		"o2": 0.28, "n2": 0.72, "he": 0.0}
	near(BathysPhysics.consume_tank(tank, 201.0, 100.0, 3.0, 1.0, 20.0),
		float(reference["tankAfterAbsoluteBar"]), 1e-7, "tank mass balance vs Python")
	var model := BathysTissue.new(1.0)
	for item: Variant in reference["tissueSamples"]:
		var sample: Dictionary = item as Dictionary
		model.advance(float(sample["ambientBar"]), float(sample["seconds"]), gas)
		var ceiling: PackedFloat64Array = model.ceiling(0.85)
		near(model.n2[0], float(sample["n2FastBar"]), 1e-10, "fast N2 tissue")
		near(model.n2[15], float(sample["n2SlowBar"]), 1e-10, "slow N2 tissue")
		near(ceiling[0], float(sample["ceilingBar"]), 1e-10, "ZH-L16C ceiling")
		check(int(ceiling[1]) == int(sample["compartment"]), "controlling compartment")
	var plan: Dictionary = BathysPlan.example(source)
	check(BathysPlan.validate(plan) == "", "example plan validation")
	var source_pois: Array[Dictionary] = BathysPoiStore.clone_pois(source.pois)
	var edited_pois: Array[Dictionary] = BathysPoiStore.clone_pois(source.pois)
	for i: int in range(edited_pois.size() - 1, -1, -1):
		if str(edited_pois[i]["id"]) == "doll":
			edited_pois.remove_at(i)
	for poi: Dictionary in edited_pois:
		if str(poi["id"]) == "tribute":
			poi["name"] = "Edited Tribute"
	edited_pois.append({"id": "custom", "name": "Custom POI", "latitudeDeg": source.origin_lat,
		"longitudeDeg": source.origin_lon, "depthM": 0.0, "spreadM": null})
	var future_source: Array[Dictionary] = BathysPoiStore.clone_pois(source.pois)
	future_source.append({"id": "future", "name": "Future POI", "latitudeDeg": source.origin_lat,
		"longitudeDeg": source.origin_lon, "depthM": 0.0, "spreadM": null})
	var merged: Array[Dictionary] = BathysPoiStore.merge(BathysPoiStore.save(source_pois, edited_pois), future_source)
	var ids: Array[String] = []
	var tribute_name: String = ""
	for poi: Dictionary in merged:
		ids.append(str(poi["id"]))
		if str(poi["id"]) == "tribute":
			tribute_name = str(poi["name"])
	check("doll" not in ids and "custom" in ids and "future" in ids and tribute_name == "Edited Tribute", "POI edits/deletion and offline addition merge")
	var renamed_source: Array[Dictionary] = BathysPoiStore.clone_pois(source.pois)
	renamed_source[1]["id"] = "new_tribute_id"
	renamed_source[1]["name"] = "Renamed offline"
	renamed_source[1]["latitudeDeg"] = float(renamed_source[1]["latitudeDeg"]) + 0.0001
	var renamed: Array[Dictionary] = BathysPoiStore.merge(BathysPoiStore.save(source_pois, edited_pois), renamed_source)
	check(str(renamed[1]["id"]) == "new_tribute_id" and str(renamed[1]["name"]) == "Edited Tribute" and
		absf(float(renamed[1]["latitudeDeg"]) - float(renamed_source[1]["latitudeDeg"])) < 1e-12, "POI source rename and independent UI edit")
	var old_plan: Dictionary = plan.duplicate(true)
	(old_plan["environment"] as Dictionary).erase("waterlineAltitudeNf02M")
	(old_plan["environment"] as Dictionary)["waterSurfaceElevationNf02M"] = 477.2
	(old_plan["environment"] as Dictionary)["altitudeM"] = 500.0
	var migrated: Dictionary = BathysPlan.from_json(JSON.stringify(old_plan), source)
	near(float((migrated["environment"] as Dictionary)["waterlineAltitudeNf02M"]), 477.2, 1e-9, "legacy waterline migration")
	var empty: Dictionary = plan.duplicate(true)
	empty["waypoints"] = []
	check(BathysPlan.validate(empty, false) == "", "empty route remains saveable")
	var hold_plan: Dictionary = plan.duplicate(true)
	var hold_route: Array = hold_plan["waypoints"] as Array
	var moved_hold: Dictionary = hold_route[2] as Dictionary
	hold_route.remove_at(2)
	hold_route.insert(1, moved_hold)
	BathysPlan.anchor_holds(hold_plan, source)
	near(float(moved_hold["targetDepthM"]), float((hold_route[0] as Dictionary)["targetDepthM"]), 1e-12, "reordered hold inherits depth")
	(hold_route[0] as Dictionary)["targetDepthM"] = 20.0
	BathysPlan.anchor_holds(hold_plan, source)
	near(float(moved_hold["targetDepthM"]), 20.0, 1e-12, "hold follows preceding depth edit")
	var reference_altitude: float = (1.0 - pow(1.0 / 1.01325, 1.0 / 5.25588)) / 2.25577e-5
	var planner_env: Dictionary = {"waterlineAltitudeNf02M": reference_altitude, "salinityGPerKg": 0.0,
		"surfaceTempC": 20.0, "minTempC": 20.0, "tempDropCPerM": 0.0}
	var short_dive := BathysTissue.new(1.0)
	short_dive.advance(3.0, 120.0, gas)
	short_dive.advance(3.0, 1200.0, gas)
	var short_projection: Dictionary = BathysDeco.calculate(short_dive, planner_env, gas, 0.3, 0.85, 9.0)
	var python_planner: Dictionary = reference["plannerAt20m20min"] as Dictionary
	near(float(short_projection["ndlS"]), float(python_planner["ndlS"]), 120.0, "NDL vs Python planner (existing tolerance)")
	near(float(short_projection["ttsS"]), float(python_planner["ttsS"]), 10.0, "TTS vs Python planner (existing tolerance)")
	var result: Dictionary = BathysSimulation.run(source, plan)
	check(str(result.get("error", "")) == "", "example simulation: " + str(result.get("error", "")))
	if str(result.get("error", "")) == "":
		var frames: Array[Dictionary] = []
		for frame: Variant in result["frames"]:
			frames.append(frame as Dictionary)
		check(frames.size() > 1000, "one-second frames")
		var last: Dictionary = frames[-1]
		check(float(last["depthM"]) < 0.001 and float(last["ceilingM"]) < 0.001, "clear surface")
		var switch_index: int = -1
		for i: int in frames.size():
			if str(frames[i]["tankId"]) == "stage":
				switch_index = i
				break
		check(switch_index > 0, "gas switch frame")
		if switch_index > 0:
			var before: Dictionary = frames[switch_index - 1]
			var after: Dictionary = frames[switch_index]
			near(float(after["timeS"]), float(before["timeS"]), 1e-12, "gas switch zero time")
			near(float(after["depthM"]), float(before["depthM"]), 1e-12, "gas switch zero depth change")
			near(float((after["tissueN2Bar"] as PackedFloat64Array)[0]), float((before["tissueN2Bar"] as PackedFloat64Array)[0]), 1e-12, "gas switch tissue conservation")
			check(BathysSimulation.frame_index_at(frames, float(after["timeS"])) == switch_index, "scrub selects switched gas")
		var cs: Dictionary = BathysSite.read_json("res://Tests/reference_frames.json")
		near(float(result["durationS"]), float(cs["durationS"]), 1e-8, "C# route duration")
		check(frames.size() == int(cs["frameCount"]), "C# frame count")
		check(switch_index == int(cs["switchIndex"]), "C# switch index")
		compare_frame(frames[switch_index - 1], cs["beforeSwitch"] as Dictionary, "C# before switch")
		compare_frame(frames[switch_index], cs["afterSwitch"] as Dictionary, "C# after switch")
		for entry: Variant in cs["cases"]:
			var case: Dictionary = entry as Dictionary
			var index: int = BathysSimulation.frame_index_at(frames, float(case["queryTimeS"]))
			check(index == int(case["frameIndex"]), "C# scrub index at " + str(case["queryTimeS"]))
			compare_frame(frames[index], case["frame"] as Dictionary, "C# scrub " + str(case["queryTimeS"]))
	print("REFERENCE_CHECKS passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)
