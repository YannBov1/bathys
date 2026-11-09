class_name BathysPlan
extends RefCounted

static func default_route_settings() -> Dictionary:
	return {"sacLPerMin": 18.0, "speedMPerMin": 12.0}

static func route_defaults_for(plan: Dictionary) -> Dictionary:
	var defaults: Dictionary = default_route_settings()
	var supplied: Variant = plan.get("routeDefaults", {})
	if supplied is Dictionary:
		for key: String in defaults:
			if supplied.has(key):
				defaults[key] = supplied[key]
	return defaults

static func validate_route_defaults(defaults: Dictionary) -> String:
	for key: String in default_route_settings():
		var value: Variant = defaults.get(key)
		if not (value is int or value is float) or not is_finite(float(value)):
			return "Route defaults must be finite numbers."
	if float(defaults["sacLPerMin"]) < 1 or float(defaults["sacLPerMin"]) > 100:
		return "Default SAC must be 1–100 L/min."
	if float(defaults["speedMPerMin"]) < 1 or float(defaults["speedMPerMin"]) > 60:
		return "Default swim speed must be 1–60 m/min."
	return ""

static func default_limits() -> Dictionary:
	return {"ppO2Min": 0.16, "ppO2WorkingMax": 1.4, "ppO2Max": 1.6,
		"densityWarning": 5.2, "densityMax": 6.2, "endMax": 30.0}

static func limits_for(plan: Dictionary) -> Dictionary:
	var limits: Dictionary = default_limits()
	var supplied: Variant = plan.get("limits", {})
	if supplied is Dictionary:
		for key: String in limits:
			if supplied.has(key):
				limits[key] = supplied[key]
	return limits

static func validate_limits(limits: Dictionary) -> String:
	for key: String in default_limits():
		var value: Variant = limits.get(key)
		if not (value is float or value is int) or not is_finite(float(value)):
			return "Gas limits must be finite numbers."
	if float(limits["ppO2Min"]) < 0.01 or float(limits["ppO2Max"]) > 3.0 or float(limits["ppO2Min"]) >= float(limits["ppO2WorkingMax"]) or float(limits["ppO2WorkingMax"]) > float(limits["ppO2Max"]):
		return "ppO₂ limits must satisfy 0.01 ≤ minimum < working maximum ≤ maximum ≤ 3 bar."
	if float(limits["densityWarning"]) <= 0 or float(limits["densityWarning"]) > float(limits["densityMax"]) or float(limits["densityMax"]) > 20:
		return "Density warning must be positive and no greater than the maximum (up to 20 g/L)."
	if float(limits["endMax"]) < 1 or float(limits["endMax"]) > 100:
		return "Maximum END must be between 1 and 100 m."
	return ""

static func id() -> String:
	return "%08x%08x" % [randi(), randi()]

static func waypoint_at_poi(poi: Dictionary) -> Dictionary:
	return {"id": id(), "name": str(poi.get("name", "Waypoint")), "poiId": str(poi.get("id", "")),
		"latitudeDeg": float(poi.get("latitudeDeg", 0.0)), "longitudeDeg": float(poi.get("longitudeDeg", 0.0)),
		"targetDepthM": float(poi.get("depthM", 0.0)), "kind": "travel", "speedMPerMin": 12.0,
		"sacLPerMin": 18.0, "holdSeconds": 180.0, "tankId": ""}

static func hold(name: String = "Hold", seconds: float = 180.0) -> Dictionary:
	return {"id": id(), "name": name, "poiId": null, "latitudeDeg": 0.0, "longitudeDeg": 0.0,
		"targetDepthM": 0.0, "kind": "hold", "speedMPerMin": 12.0,
		"sacLPerMin": 18.0, "holdSeconds": seconds, "tankId": ""}

static func gas_switch(tank_id: String, name: String = "Gas switch") -> Dictionary:
	return {"id": id(), "name": name, "poiId": null, "latitudeDeg": 0.0, "longitudeDeg": 0.0,
		"targetDepthM": 0.0, "kind": "switch", "speedMPerMin": 12.0,
		"sacLPerMin": 18.0, "holdSeconds": 180.0, "tankId": tank_id}

static func empty(site: BathysSite) -> Dictionary:
	var plan: Dictionary = example(site)
	plan["name"] = "Untitled scenario"
	plan["waypoints"] = []
	plan["tanks"] = []
	plan["initialTankId"] = ""
	return plan

static func example(site: BathysSite) -> Dictionary:
	var a: Dictionary = site.pois[1]
	var b: Dictionary = site.pois[2]
	var route: Array = [waypoint_at_poi(a), waypoint_at_poi(b)]
	var explore: Dictionary = hold("Explore Doll", 480.0)
	route.append(explore)
	var ascend: Dictionary = waypoint_at_poi(b)
	ascend["id"] = id()
	ascend["name"] = "Ascend to 18 m"
	ascend["poiId"] = null
	ascend["targetDepthM"] = 18.0
	route.append(ascend)
	route.append(gas_switch("stage", "Switch to Stage"))
	route.append(hold("Hold after switch · 18 m", 30.0))
	var six: Dictionary = ascend.duplicate(true)
	six["id"] = id()
	six["name"] = "Ascend to 6 m"
	six["targetDepthM"] = 6.0
	six["sacLPerMin"] = 16.0
	route.append(six)
	var safety: Dictionary = hold("Safety hold · 6 m", 180.0)
	safety["sacLPerMin"] = 16.0
	route.append(safety)
	route.append(waypoint_at_poi(site.pois[0]))
	var plan: Dictionary = {"name": "Lac des Îles exploration", "environment": {
		"waterlineAltitudeNf02M": site.waterline, "salinityGPerKg": 0.0, "surfaceTempC": 18.0,
		"tempDropCPerM": 0.2, "minTempC": 5.0},
		"tanks": [{"id": "back", "name": "Back gas", "volumeL": 12.0, "startGaugeBar": 220.0,
			"reserveGaugeBar": 50.0, "o2": 0.28, "n2": 0.72, "he": 0.0},
			{"id": "stage", "name": "Stage", "volumeL": 7.0, "startGaugeBar": 180.0,
				"reserveGaugeBar": 40.0, "o2": 0.50, "n2": 0.50, "he": 0.0}],
		"waypoints": route, "initialTankId": "back", "gfLow": 0.30, "gfHigh": 0.85,
		"descentMPerMin": 18.0, "ascentMPerMin": 9.0}
	anchor_holds(plan, site)
	return plan

static func from_json(value: String, site: BathysSite) -> Dictionary:
	var parsed: Variant = JSON.parse_string(value)
	if not parsed is Dictionary:
		return {}
	var plan: Dictionary = parsed as Dictionary
	var env: Dictionary = plan.get("environment", {}) as Dictionary
	if not env.has("waterlineAltitudeNf02M"):
		env["waterlineAltitudeNf02M"] = env.get("waterSurfaceElevationNf02M", site.waterline)
	env.erase("waterSurfaceElevationNf02M")
	env.erase("altitudeM")
	plan["environment"] = env
	migrate_legacy_gas_assignments(plan)
	anchor_holds(plan, site)
	return plan

static func migrate_legacy_gas_assignments(plan: Dictionary) -> void:
	var tanks: Array = plan.get("tanks", []) as Array
	var route: Array = plan.get("waypoints", []) as Array
	if tanks.is_empty():
		return
	var initial: String = str(plan.get("initialTankId", ""))
	if initial.is_empty():
		initial = str((tanks[0] as Dictionary).get("id", ""))
		for item: Variant in route:
			var waypoint: Dictionary = item as Dictionary
			if str(waypoint.get("kind", "travel")) != "switch" and not str(waypoint.get("tankId", "")).is_empty():
				initial = str(waypoint["tankId"])
				break
		plan["initialTankId"] = initial
	var active: String = initial
	var migrated: Array = []
	for item: Variant in route:
		var waypoint: Dictionary = item as Dictionary
		if str(waypoint.get("kind", "travel")) == "switch":
			active = str(waypoint.get("tankId", ""))
			migrated.append(waypoint)
			continue
		var assigned: String = str(waypoint.get("tankId", ""))
		if not assigned.is_empty() and assigned != active:
			var tank_name: String = assigned
			for tank_item: Variant in tanks:
				var tank: Dictionary = tank_item as Dictionary
				if str(tank.get("id", "")) == assigned:
					tank_name = str(tank.get("name", assigned))
			migrated.append(gas_switch(assigned, "Switch to " + tank_name))
			active = assigned
		waypoint["tankId"] = ""
		migrated.append(waypoint)
	plan["waypoints"] = migrated

static func anchor_holds(plan: Dictionary, site: BathysSite) -> void:
	if site.pois.is_empty():
		return
	var latitude: float = float(site.pois[0].get("latitudeDeg", site.origin_lat))
	var longitude: float = float(site.pois[0].get("longitudeDeg", site.origin_lon))
	var depth: float = 0.0
	for item: Variant in plan.get("waypoints", []):
		var waypoint: Dictionary = item as Dictionary
		match str(waypoint.get("kind", "travel")):
			"switch":
				continue
			"hold":
				waypoint["latitudeDeg"] = latitude
				waypoint["longitudeDeg"] = longitude
				waypoint["targetDepthM"] = depth
				waypoint["poiId"] = null
			_:
				latitude = float(waypoint.get("latitudeDeg", latitude))
				longitude = float(waypoint.get("longitudeDeg", longitude))
				depth = float(waypoint.get("targetDepthM", depth))

static func validate(plan: Dictionary, require_route: bool = true) -> String:
	var defaults_error: String = validate_route_defaults(route_defaults_for(plan))
	if not defaults_error.is_empty():
		return defaults_error
	var limits_error: String = validate_limits(limits_for(plan))
	if not limits_error.is_empty():
		return limits_error
	var env: Dictionary = plan.get("environment", {}) as Dictionary
	var altitude: float = float(env.get("waterlineAltitudeNf02M", 478.5))
	if altitude < 0.0 or altitude > 3000.0:
		return "Waterline altitude must be 0–3000 m NF02."
	var salinity: float = float(env.get("salinityGPerKg", 0.0))
	if salinity < 0.0 or salinity > 40.0:
		return "Salinity must be 0–40 g/kg."
	var temp: float = float(env.get("surfaceTempC", 18.0))
	var minimum: float = float(env.get("minTempC", 5.0))
	var drop: float = float(env.get("tempDropCPerM", 0.2))
	if temp < 0.0 or temp > 40.0 or minimum < 0.0 or minimum > temp or drop < 0.0 or drop > 2.0:
		return "Check water temperatures."
	var low: float = float(plan.get("gfLow", 0.3))
	var high: float = float(plan.get("gfHigh", 0.85))
	if low <= 0.0 or low > high or high > 1.0:
		return "Gradient factors must satisfy 0 < low ≤ high ≤ 1."
	var descent: float = float(plan.get("descentMPerMin", 18.0))
	var ascent: float = float(plan.get("ascentMPerMin", 9.0))
	if descent <= 0.0 or descent > 40.0 or ascent <= 0.0 or ascent > 30.0:
		return "Check ascent/descent rates."
	var tanks: Array = plan.get("tanks", []) as Array
	if tanks.is_empty() and require_route:
		return "Add a tank and choose its gas mix to simulate this route."
	var ids: Dictionary = {}
	for entry: Variant in tanks:
		var tank: Dictionary = entry as Dictionary
		var tank_id: String = str(tank.get("id", ""))
		if tank_id.is_empty() or ids.has(tank_id):
			return "Tank IDs must be unique and nonempty."
		ids[tank_id] = true
		if str(tank.get("name", "")).is_empty():
			return "Tank name is required."
		if float(tank.get("volumeL", 0.0)) < 1.0 or float(tank.get("volumeL", 0.0)) > 40.0:
			return "Tank volume must be 1–40 L."
		var start: float = float(tank.get("startGaugeBar", 0.0))
		var reserve: float = float(tank.get("reserveGaugeBar", 0.0))
		if start < 1.0 or start > 400.0 or reserve < 0.0 or reserve >= start:
			return "Check tank pressures."
		var o2: float = float(tank.get("o2", 0.0))
		var n2: float = float(tank.get("n2", 0.0))
		var he: float = float(tank.get("he", 0.0))
		if o2 <= 0.0 or n2 < 0.0 or he < 0.0 or absf(o2 + n2 + he - 1.0) > 0.0001:
			return "Tank gas fractions must sum to 100%."
	if not tanks.is_empty() and not ids.has(str(plan.get("initialTankId", ""))):
		return "Choose a valid starting gas."
	var route: Array = plan.get("waypoints", []) as Array
	if route.size() > 100:
		return "Route is limited to 100 events."
	var spatial: bool = false
	for item: Variant in route:
		var waypoint: Dictionary = item as Dictionary
		var kind: String = str(waypoint.get("kind", "travel"))
		if kind == "switch":
			if not ids.has(str(waypoint.get("tankId", ""))):
				return "Gas switch uses an unknown tank."
			continue
		spatial = true
		if kind != "hold" and kind != "travel":
			return "Unknown route event."
		var depth: float = float(waypoint.get("targetDepthM", 0.0))
		if depth < 0.0 or depth > 100.0:
			return "Target depths must be 0–100 m."
		var sac: float = float(waypoint.get("sacLPerMin", 18.0))
		if sac < 1.0 or sac > 100.0:
			return "SAC must be 1–100 L/min."
		if kind == "hold":
			if float(waypoint.get("holdSeconds", 0.0)) < 1.0 or float(waypoint.get("holdSeconds", 0.0)) > 7200.0:
				return "Hold duration must be 1–7200 s."
		elif float(waypoint.get("speedMPerMin", 0.0)) < 1.0 or float(waypoint.get("speedMPerMin", 0.0)) > 60.0:
			return "Swim speed must be 1–60 m/min."
	if require_route and not spatial:
		return "Add a travel or hold waypoint."
	return ""
