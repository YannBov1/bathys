class_name BathysSimulation
extends RefCounted

static func tank_by_id(tanks: Array[Dictionary], tank_id: String) -> Dictionary:
	for tank: Dictionary in tanks:
		if str((tank["spec"] as Dictionary).get("id", "")) == tank_id:
			return tank
	return {}

static func capture(frames: Array[Dictionary], tanks: Array[Dictionary], model: BathysTissue,
		env: Dictionary, time_s: float, lat: float, lon: float, depth: float, tank_id: String,
		gf: float, ndl: Variant, tts: Variant, first_stop: Variant, cns: float, otu: float, used: float) -> void:
	var tank: Dictionary = tank_by_id(tanks, tank_id)
	var gas: Dictionary = tank["spec"] as Dictionary
	var surface: float = BathysPhysics.surface_bar(env)
	var ambient: float = BathysPhysics.ambient_bar(env, depth)
	var ceiling: PackedFloat64Array = model.ceiling(gf)
	var gauges: Array[float] = []
	for state: Dictionary in tanks:
		gauges.append(float(state["absoluteBar"]) - surface)
	frames.append({"timeS": time_s, "latitudeDeg": lat, "longitudeDeg": lon, "depthM": depth,
		"ambientBar": ambient, "tankId": tank_id, "tankGaugeBar": gauges,
		"ceilingM": BathysPhysics.depth_at_bar(env, ceiling[0]), "controllingCompartment": int(ceiling[1]),
		"leadingGf": model.leading_gf(), "currentGf": gf, "ndlS": ndl, "ttsS": tts,
		"firstStopM": first_stop, "cnsPercent": cns, "otu": otu,
		"ppO2Bar": float(gas.get("o2", 0.21)) * ambient,
		"densityGPerL": BathysPhysics.gas_density(gas, ambient, BathysPhysics.water_temp(env, depth)),
		"endM": BathysPhysics.end_m(gas, ambient), "waterTempC": BathysPhysics.water_temp(env, depth),
		"usedSurfaceL": used, "tissueN2Bar": model.n2.duplicate(), "tissueHeBar": model.he.duplicate()})

static func run(site: BathysSite, plan: Dictionary, yield_tree: SceneTree = null, cancelled: Callable = Callable()) -> Dictionary:
	var batch_started: int = Time.get_ticks_usec()
	var validation: String = BathysPlan.validate(plan)
	if not validation.is_empty():
		return {"error": validation, "frames": [], "legs": []}
	var limits: Dictionary = BathysPlan.limits_for(plan)
	var minimum_pp: float = float(limits["ppO2Min"])
	var maximum_pp: float = float(limits["ppO2Max"])
	var env: Dictionary = plan["environment"] as Dictionary
	var surface: float = BathysPhysics.surface_bar(env)
	var tanks: Array[Dictionary] = []
	for entry: Variant in plan["tanks"]:
		var spec: Dictionary = entry as Dictionary
		tanks.append({"spec": spec, "absoluteBar": float(spec.get("startGaugeBar", 200.0)) + surface})
	var frames: Array[Dictionary] = []
	var legs: Array[Dictionary] = []
	var model := BathysTissue.new(surface)
	var time_s: float = 0.0
	var depth: float = 0.0
	var cns: float = 0.0
	var otu: float = 0.0
	var used: float = 0.0
	var lat: float = float(site.pois[0].get("latitudeDeg", site.origin_lat))
	var lon: float = float(site.pois[0].get("longitudeDeg", site.origin_lon))
	var ndl: Variant = null
	var tts: Variant = 0.0
	var first_stop: Variant = null
	var gf: float = float(plan.get("gfHigh", 0.85))
	var tank_id: String = str(plan.get("initialTankId", ""))
	capture(frames, tanks, model, env, time_s, lat, lon, depth, tank_id, gf, ndl, tts, first_stop, cns, otu, used)
	var projection_counter: int = 0
	for event_index: int in (plan["waypoints"] as Array).size():
		var item: Variant = plan["waypoints"][event_index]
		if cancelled.is_valid() and bool(cancelled.call()):
			return {"cancelled": true}
		var waypoint: Dictionary = item as Dictionary
		var kind: String = str(waypoint.get("kind", "travel"))
		if kind == "switch":
			var next_tank: Dictionary = tank_by_id(tanks, str(waypoint.get("tankId", "")))
			var next_spec: Dictionary = next_tank["spec"] as Dictionary
			var ambient: float = BathysPhysics.ambient_bar(env, depth)
			var pp: float = float(next_spec.get("o2", 0.21)) * ambient
			if pp < minimum_pp or pp > maximum_pp:
				return {"error": "%s: ppO₂ %.2f bar at %.1f m is outside %.2f–%.2f." % [waypoint.get("name", "Gas switch"), pp, depth, minimum_pp, maximum_pp], "frames": frames, "legs": legs, "eventIndex": event_index}
			if float(next_tank["absoluteBar"]) <= maxf(ambient, float(next_spec.get("reserveGaugeBar", 0.0)) + surface):
				return {"error": "Switched tank cannot deliver gas above its reserve.", "frames": frames, "legs": legs, "eventIndex": event_index}
			tank_id = str(waypoint["tankId"])
			legs.append({"name": waypoint.get("name", "Gas switch"), "kind": "switch", "distanceM": 0.0,
				"bearingTrueDeg": 0.0, "startDepthM": depth, "targetDepthM": depth,
				"durationS": 0.0, "tankId": tank_id})
			var switched: Dictionary = BathysDeco.calculate(model, env, next_spec,
				float(plan["gfLow"]), float(plan["gfHigh"]), float(plan["ascentMPerMin"]))
			ndl = switched["ndlS"]
			tts = switched["ttsS"]
			first_stop = switched["firstStopM"]
			gf = float(switched["currentGf"])
			projection_counter = 0
			capture(frames, tanks, model, env, time_s, lat, lon, depth, tank_id, gf, ndl, tts, first_stop, cns, otu, used)
			if yield_tree != null and Time.get_ticks_usec() - batch_started >= 8000:
				await yield_tree.process_frame
				if cancelled.is_valid() and bool(cancelled.call()):
					return {"cancelled": true}
				batch_started = Time.get_ticks_usec()
			continue
		var target_lat: float = float(waypoint.get("latitudeDeg", lat))
		var target_lon: float = float(waypoint.get("longitudeDeg", lon))
		var target_depth: float = float(waypoint.get("targetDepthM", depth))
		var leg: PackedFloat64Array = BathysSite.leg(lat, lon, target_lat, target_lon)
		if kind == "hold" and (absf(target_depth - depth) > 0.01 or leg[0] > 0.5):
			return {"error": "A hold must stay at the preceding position and depth.", "frames": frames, "legs": legs, "eventIndex": event_index}
		var start_lat: float = lat
		var start_lon: float = lon
		var start_depth: float = depth
		var vertical_rate: float = float(plan["descentMPerMin"]) if target_depth >= depth else float(plan["ascentMPerMin"])
		var duration: float = float(waypoint.get("holdSeconds", 180.0)) if kind == "hold" else maxf(
			leg[0] / float(waypoint.get("speedMPerMin", 12.0)) * 60.0,
			absf(target_depth - depth) / vertical_rate * 60.0)
		if kind == "travel" and duration < 1.0:
			duration = 1.0
		if time_s + duration > 14400.0:
			return {"error": "Plan exceeds four hours.", "frames": frames, "legs": legs, "eventIndex": event_index}
		legs.append({"name": waypoint.get("name", "Waypoint"), "kind": kind, "distanceM": leg[0],
			"bearingTrueDeg": leg[1], "startDepthM": start_depth, "targetDepthM": target_depth,
			"durationS": duration, "tankId": tank_id})
		var tank: Dictionary = tank_by_id(tanks, tank_id)
		var gas: Dictionary = tank["spec"] as Dictionary
		var start_pp: float = float(gas.get("o2", 0.21)) * BathysPhysics.ambient_bar(env, depth)
		if start_pp < minimum_pp or start_pp > maximum_pp:
			return {"error": "Active gas ppO₂ is outside %.2f–%.2f bar." % [minimum_pp, maximum_pp], "frames": frames, "legs": legs, "eventIndex": event_index}
		var steps: int = ceili(duration)
		for k: int in range(1, steps + 1):
			var elapsed: float = minf(duration, k)
			var prior: float = minf(duration, k - 1)
			var dt: float = elapsed - prior
			if dt <= 0.0:
				continue
			var fraction: float = 1.0 if kind == "hold" else elapsed / duration
			var new_lat: float = start_lat if kind == "hold" else start_lat + (target_lat - start_lat) * fraction
			var new_lon: float = start_lon if kind == "hold" else start_lon + (target_lon - start_lon) * fraction
			var new_depth: float = target_depth if kind == "hold" else start_depth + (target_depth - start_depth) * fraction
			new_depth = clampf(new_depth, 0.0, maxf(start_depth, target_depth))
			var old_ambient: float = BathysPhysics.ambient_bar(env, depth)
			var new_ambient: float = BathysPhysics.ambient_bar(env, new_depth)
			var pp: float = float(gas.get("o2", 0.21)) * new_ambient
			if pp < minimum_pp or pp > maximum_pp:
				return {"error": "%s: ppO₂ %.2f bar at %.1f m is outside %.2f–%.2f." % [waypoint.get("name", "Waypoint"), pp, new_depth, minimum_pp, maximum_pp], "frames": frames, "legs": legs, "eventIndex": event_index}
			var surface_l: float = float(waypoint.get("sacLPerMin", 18.0)) * (old_ambient + new_ambient) / (2.0 * surface) * dt / 60.0
			if maxf(depth, new_depth) > 0.001:
				var absolute: float = BathysPhysics.consume_tank(gas, float(tank["absoluteBar"]), surface_l,
					new_ambient, surface, float(env.get("surfaceTempC", 18.0)))
				if is_nan(absolute):
					return {"error": "%s falls below its reserve." % str(gas.get("name", "Tank")), "frames": frames, "legs": legs, "eventIndex": event_index}
				tank["absoluteBar"] = absolute
				used += surface_l
			model.advance(new_ambient, dt, gas)
			if new_depth > 0.001:
				cns += BathysPhysics.cns_rate(pp) * dt
			else:
				cns *= exp(-log(2.0) * dt / 5400.0)
			otu += BathysPhysics.otu_rate(pp) * dt
			depth = new_depth
			lat = new_lat
			lon = new_lon
			time_s += dt
			projection_counter += 1
			if projection_counter >= 30 or k == steps:
				var projection: Dictionary = BathysDeco.calculate(model, env, gas,
					float(plan["gfLow"]), float(plan["gfHigh"]), float(plan["ascentMPerMin"]))
				ndl = projection["ndlS"]
				tts = projection["ttsS"]
				first_stop = projection["firstStopM"]
				gf = float(projection["currentGf"])
				projection_counter = 0
			capture(frames, tanks, model, env, time_s, lat, lon, depth, tank_id, gf, ndl, tts, first_stop, cns, otu, used)
			if yield_tree != null and Time.get_ticks_usec() - batch_started >= 8000:
				await yield_tree.process_frame
				if cancelled.is_valid() and bool(cancelled.call()):
					return {"cancelled": true}
				batch_started = Time.get_ticks_usec()
	if float(frames[-1]["depthM"]) < 0.01 and float(frames[-1]["ceilingM"]) > 0.01:
		return {"error": "The route surfaces with a ceiling. Add ascent holds.", "frames": frames, "legs": legs}
	return {"error": "", "frames": frames, "legs": legs, "durationS": time_s}

static func frame_index_at(frames: Array[Dictionary], time_s: float) -> int:
	var target: float = clampf(time_s, 0.0, float(frames[-1]["timeS"]))
	var lo: int = 0
	var hi: int = frames.size() - 1
	while lo < hi:
		var mid: int = (lo + hi + 1) / 2
		if float(frames[mid]["timeS"]) <= target:
			lo = mid
		else:
			hi = mid - 1
	return lo
