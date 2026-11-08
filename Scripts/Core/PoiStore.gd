class_name BathysPoiStore
extends RefCounted

static func clone_pois(source: Array[Dictionary]) -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for poi: Dictionary in source:
		copy.append(poi.duplicate(true))
	return copy

static func save(source: Array[Dictionary], current: Array[Dictionary]) -> String:
	var ids: Array[String] = []
	for poi: Dictionary in source:
		ids.append(str(poi.get("id", "")))
	return JSON.stringify({"sourcePoiIds": ids, "sourcePois": source, "pois": current}, "  ")

static func merge(saved_json: String, source: Array[Dictionary]) -> Array[Dictionary]:
	var parsed: Variant = JSON.parse_string(saved_json)
	var legacy_array: bool = parsed is Array
	var saved: Dictionary = {"pois": parsed} if legacy_array else parsed as Dictionary
	if saved.is_empty():
		return clone_pois(source)
	var current: Array = saved.get("pois", []) as Array
	var baseline: Array = saved.get("sourcePois", []) as Array
	var prior_ids: Array = saved.get("sourcePoiIds", []) as Array
	if not baseline.is_empty():
		prior_ids = []
		for item: Variant in baseline:
			prior_ids.append((item as Dictionary).get("id", ""))
	var edited_by_id: Dictionary = {}
	for item: Variant in current:
		var poi: Dictionary = item as Dictionary
		edited_by_id[str(poi.get("id", ""))] = poi
	var result: Array[Dictionary] = []
	var consumed: Dictionary = {}
	for i: int in source.size():
		var incoming: Dictionary = source[i]
		var old: Dictionary = {}
		for item: Variant in baseline:
			var candidate: Dictionary = item as Dictionary
			if str(candidate.get("id", "")) == str(incoming.get("id", "")):
				old = candidate
				break
		if old.is_empty():
			for item: Variant in baseline:
				var candidate: Dictionary = item as Dictionary
				if (str(candidate.get("name", "")) == str(incoming.get("name", "")) and
					absf(float(candidate.get("latitudeDeg", 0.0)) - float(incoming.get("latitudeDeg", 0.0))) < 1e-8 and
					absf(float(candidate.get("longitudeDeg", 0.0)) - float(incoming.get("longitudeDeg", 0.0))) < 1e-8):
					old = candidate
					break
		if old.is_empty() and baseline.size() == source.size() and i < baseline.size():
			var candidate: Dictionary = baseline[i] as Dictionary
			var old_id: String = str(candidate.get("id", ""))
			var still_present: bool = false
			for source_poi: Dictionary in source:
				if str(source_poi.get("id", "")) == old_id:
					still_present = true
			if not still_present:
				old = candidate
		var previous_id: String = str(old.get("id", incoming.get("id", "")))
		if previous_id in prior_ids and not edited_by_id.has(previous_id):
			consumed[previous_id] = true
			continue
		if not old.is_empty() and edited_by_id.has(previous_id):
			consumed[previous_id] = true
			var edited: Dictionary = edited_by_id[previous_id] as Dictionary
			var merged: Dictionary = incoming.duplicate(true)
			for field: String in ["name", "latitudeDeg", "longitudeDeg", "depthM", "spreadM"]:
				if edited.get(field) != old.get(field):
					merged[field] = edited.get(field)
			result.append(merged)
			continue
		if baseline.is_empty():
			var prior: Dictionary = {}
			if edited_by_id.has(str(incoming.get("id", ""))):
				prior = edited_by_id[str(incoming.get("id", ""))] as Dictionary
			else:
				for item: Variant in current:
					var candidate: Dictionary = item as Dictionary
					if (str(candidate.get("name", "")) == str(incoming.get("name", "")) and
						absf(float(candidate.get("latitudeDeg", 0.0)) - float(incoming.get("latitudeDeg", 0.0))) < 1e-8 and
						absf(float(candidate.get("longitudeDeg", 0.0)) - float(incoming.get("longitudeDeg", 0.0))) < 1e-8):
						prior = candidate
						break
			if prior.is_empty() and not legacy_array and prior_ids.size() == source.size() and i < prior_ids.size() and edited_by_id.has(str(prior_ids[i])):
				prior = edited_by_id[str(prior_ids[i])] as Dictionary
			if not prior.is_empty():
				consumed[str(prior.get("id", ""))] = true
				var merged: Dictionary = incoming.duplicate(true)
				merged["depthM"] = prior.get("depthM", incoming.get("depthM", 0.0))
				merged["spreadM"] = prior.get("spreadM", incoming.get("spreadM"))
				result.append(merged)
				continue
		result.append(incoming.duplicate(true))
	for item: Variant in current:
		var poi: Dictionary = item as Dictionary
		var poi_id: String = str(poi.get("id", ""))
		if consumed.has(poi_id) or poi_id in prior_ids:
			continue
		var exists: bool = false
		for result_poi: Dictionary in result:
			if str(result_poi.get("id", "")) == poi_id:
				exists = true
		if not exists:
			result.append(poi.duplicate(true))
	return result
