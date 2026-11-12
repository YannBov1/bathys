class_name BathysGpxOverlay
extends RefCounted

const MAX_BYTES := 10 * 1024 * 1024
const MAX_POINTS := 100000
const MAX_VERTICES := 250000
const COLORS := [Color("b9a0ff"), Color("ff88b2"), Color("8ed5ff"), Color("c5df7a")]

static func parse(text: String) -> Dictionary:
	var failure := {"error": "Could not read this GPX file."}
	if text.strip_edges().is_empty(): return failure
	if text.to_utf8_buffer().size() > MAX_BYTES: return {"error": "GPX file is too large (maximum 10 MB)."}
	if text.to_upper().contains("<!DOCTYPE"): return failure
	var xml := XMLParser.new()
	if xml.open_buffer(text.to_utf8_buffer()) != OK: return failure
	var stack: Array[String] = []
	var segments: Array[PackedFloat64Array] = []
	var points := PackedFloat64Array()
	var current := PackedFloat64Array()
	var count: int = 0
	var rooted: bool = false
	var skipped: int = 0
	while true:
		var error: Error = xml.read()
		if error == ERR_FILE_EOF: break
		if error != OK: return failure
		if xml.get_node_type() == XMLParser.NODE_ELEMENT:
			var full: String = xml.get_node_name()
			var tag: String = full.get_slice(":", full.get_slice_count(":") - 1)
			var parent: String = stack[-1].get_slice(":", stack[-1].get_slice_count(":") - 1) if not stack.is_empty() else ""
			if stack.is_empty():
				if rooted or tag != "gpx": return failure
				rooted = true
			if tag in ["trkseg", "rte"]:
				if not current.is_empty(): segments.append(current)
				current = PackedFloat64Array()
			if (tag == "trkpt" and parent == "trkseg") or (tag == "rtept" and parent == "rte") or (tag == "wpt" and parent == "gpx"):
				count += 1
				if count > MAX_POINTS: return {"error": "GPX file has too many points (maximum 100,000)."}
				var lat_text: String = xml.get_named_attribute_value_safe("lat")
				var lon_text: String = xml.get_named_attribute_value_safe("lon")
				var lat: float = lat_text.to_float()
				var lon: float = lon_text.to_float()
				if not lat_text.is_valid_float() or not lon_text.is_valid_float() or not is_finite(lat) or not is_finite(lon) or absf(lat) > 90 or absf(lon) > 180:
					skipped += 1
					if not current.is_empty(): segments.append(current)
					current = PackedFloat64Array()
				elif tag == "wpt": points.append_array(PackedFloat64Array([lat, lon]))
				elif current.size() < 2 or current[-2] != lat or current[-1] != lon: current.append_array(PackedFloat64Array([lat, lon]))
			if not xml.is_empty(): stack.append(full)
		elif xml.get_node_type() == XMLParser.NODE_ELEMENT_END:
			if stack.is_empty() or stack[-1] != xml.get_node_name(): return failure
			var tag: String = stack.pop_back().get_slice(":", xml.get_node_name().get_slice_count(":") - 1)
			if tag in ["trkseg", "rte"]:
				if not current.is_empty(): segments.append(current)
				current = PackedFloat64Array()
	if not rooted or not stack.is_empty(): return failure
	if not current.is_empty(): segments.append(current)
	if segments.is_empty() and points.is_empty(): return {"error": "No valid track, route or waypoint coordinates were found."}
	return {"segments": segments, "points": points, "point_count": count - skipped, "skipped": skipped, "error": ""}

static func grid_at(site: BathysSite, local: Vector2) -> Vector2:
	var survey: PackedFloat64Array = site.local_to_survey(local.x, local.y)
	return Vector2((survey[0] - site.min_e) / site.spacing, (site.max_n - survey[1]) / site.spacing)

static func triangle_at(site: BathysSite, grid: Vector2) -> Dictionary:
	var x: int = floori(grid.x)
	var y: int = floori(grid.y)
	var lower: bool = grid.y - y >= grid.x - x
	var nw: float = site.cell_elevation(x, y)
	var se: float = site.cell_elevation(x + 1, y + 1)
	var side: float = site.cell_elevation(x, y + 1) if lower else site.cell_elevation(x + 1, y)
	if is_nan(nw) or is_nan(se) or is_nan(side): return {}
	return {"x": x, "y": y, "nw": nw, "se": se, "side": side, "lower": lower}

static func elevation(triangle: Dictionary, grid: Vector2) -> float:
	var x: float = grid.x - float(triangle["x"])
	var y: float = grid.y - float(triangle["y"])
	if triangle["lower"]: return (1 - y) * triangle["nw"] + (y - x) * triangle["side"] + x * triangle["se"]
	return (1 - x) * triangle["nw"] + (x - y) * triangle["side"] + y * triangle["se"]

static func clip_grid(site: BathysSite, a: Vector2, b: Vector2) -> Vector2:
	var bounds := Vector2(0, 1)
	for axis: int in 2:
		var end: float = (site.width if axis == 0 else site.height) - 1.00001
		var delta: float = b[axis] - a[axis]
		if absf(delta) < 1e-8:
			if a[axis] < 0 or a[axis] > end: return Vector2(1, 0)
		else:
			var first: float = -a[axis] / delta
			var last: float = (end - a[axis]) / delta
			bounds.x = maxf(bounds.x, minf(first, last))
			bounds.y = minf(bounds.y, maxf(first, last))
	return bounds

static func add_cuts(cuts: Array[float], a: float, b: float, bounds: Vector2) -> void:
	if absf(b - a) < 1e-8: return
	var first: float = lerpf(a, b, bounds.x)
	var last: float = lerpf(a, b, bounds.y)
	for line: int in range(floori(minf(first, last)) + 1, ceili(maxf(first, last))):
		var at: float = (line - a) / (b - a)
		if at > bounds.x + 1e-7 and at < bounds.y - 1e-7: cuts.append(at)

static func prepare(data: Dictionary, site: BathysSite, waterline: float) -> Dictionary:
	var paths: Array[PackedVector3Array] = []
	var markers := PackedVector3Array()
	var outside: bool = false
	var vertex_count: int = 0
	for source: PackedFloat64Array in data["segments"]:
		var path := PackedVector3Array()
		if source.size() == 2:
			var local: PackedFloat64Array = site.to_local(source[0], source[1])
			var grid: Vector2 = grid_at(site, Vector2(local[0], local[1]))
			var triangle: Dictionary = triangle_at(site, grid)
			if triangle.is_empty(): outside = true
			else: markers.append(Vector3(local[0], elevation(triangle, grid) - waterline + 1, -local[1]))
		for i: int in range(2, source.size(), 2):
			var start: PackedFloat64Array = site.to_local(source[i - 2], source[i - 1])
			var finish: PackedFloat64Array = site.to_local(source[i], source[i + 1])
			var a := Vector2(start[0], start[1])
			var b := Vector2(finish[0], finish[1])
			var ga: Vector2 = grid_at(site, a)
			var gb: Vector2 = grid_at(site, b)
			var bounds: Vector2 = clip_grid(site, ga, gb)
			if bounds.x > 0 or bounds.y < 1: outside = true
			if bounds.x > bounds.y:
				if path.size() > 1: paths.append(path)
				path = PackedVector3Array()
				continue
			var cuts: Array[float] = [bounds.x, bounds.y]
			# Split on both grid axes and the NW–SE mesh diagonal, following each actual triangle.
			add_cuts(cuts, ga.x, gb.x, bounds)
			add_cuts(cuts, ga.y, gb.y, bounds)
			add_cuts(cuts, ga.x - ga.y, gb.x - gb.y, bounds)
			cuts.sort()
			for j: int in range(1, cuts.size()):
				if cuts[j] - cuts[j - 1] < 1e-7: continue
				var triangle: Dictionary = triangle_at(site, ga.lerp(gb, (cuts[j] + cuts[j - 1]) / 2))
				if triangle.is_empty():
					outside = true
					if path.size() > 1: paths.append(path)
					path = PackedVector3Array()
					continue
				for t: float in [cuts[j - 1], cuts[j]]:
					var local: Vector2 = a.lerp(b, t)
					var point := Vector3(local.x, elevation(triangle, ga.lerp(gb, t)) - waterline + 1, -local.y)
					if path.is_empty() or not path[-1].is_equal_approx(point):
						path.append(point)
						vertex_count += 1
						if vertex_count > MAX_VERTICES: return {"error": "GPX geometry is too complex to display."}
			if bounds.y < 1:
				if path.size() > 1: paths.append(path)
				path = PackedVector3Array()
		if path.size() > 1: paths.append(path)
	for i: int in range(0, data["points"].size(), 2):
		var local: PackedFloat64Array = site.to_local(data["points"][i], data["points"][i + 1])
		var grid: Vector2 = grid_at(site, Vector2(local[0], local[1]))
		var triangle: Dictionary = triangle_at(site, grid)
		if triangle.is_empty(): outside = true
		else: markers.append(Vector3(local[0], elevation(triangle, grid) - waterline + 1, -local[1]))
	return {"paths": paths, "markers": markers, "outside": outside, "error": ""}
