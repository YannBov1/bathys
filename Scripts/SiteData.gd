class_name BathysSite
extends RefCounted

const GRID_PATH := "res://Data/survey_grid.dat"
const SITE_PATH := "res://Data/site.json"
const META_PATH := "res://Data/survey_grid.json"
const A := 6378137.0
const E2 := 0.0066943799901413165

var name: String = ""
var origin_lat: float = 0.0
var origin_lon: float = 0.0
var waterline: float = 478.5
var pois: Array[Dictionary] = []
var width: int = 0
var height: int = 0
var min_e: float = 0.0
var max_n: float = 0.0
var spacing: float = 0.5
var measured_count: int = 0
var interpolated_count: int = 0
var grid: PackedByteArray = PackedByteArray()
var origin_survey_e: float = 0.0
var origin_survey_n: float = 0.0
var ee: float = 1.0
var en: float = 0.0
var ne: float = 0.0
var nn: float = 1.0
var inverse_det: float = 1.0

static func read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed as Dictionary
	push_error("Invalid packaged JSON: " + path)
	return {}

func load_packaged() -> bool:
	var source: Dictionary = read_json(SITE_PATH)
	var meta: Dictionary = read_json(META_PATH)
	if source.is_empty() or meta.is_empty():
		return false
	name = str(source.get("name", "Bathys"))
	origin_lat = float(source.get("originLatitudeDeg", 0.0))
	origin_lon = float(source.get("originLongitudeDeg", 0.0))
	waterline = float(source.get("waterSurfaceReferenceM", 478.5))
	for entry: Variant in source.get("pois", []):
		if entry is Dictionary:
			pois.append(entry as Dictionary)
	width = int(meta.get("width", 0))
	height = int(meta.get("height", 0))
	min_e = float(meta.get("minE", 0.0))
	max_n = float(meta.get("maxN", 0.0))
	spacing = float(meta.get("spacingM", 0.5))
	measured_count = int(meta.get("measuredCount", 0))
	interpolated_count = int(meta.get("interpolatedCount", 0))
	grid = FileAccess.get_file_as_bytes(GRID_PATH)
	if grid.size() != 40 + width * height * 4 or grid.slice(0, 8).get_string_from_ascii() != "BATHGRID":
		push_error("Packaged survey grid is missing or corrupt")
		return false
	var origin: PackedFloat64Array = wgs84_to_lv95(origin_lat, origin_lon)
	origin_survey_e = origin[0]
	origin_survey_n = origin[1]
	var east_geo: PackedFloat64Array = lv95_to_wgs84(origin_survey_e + 10.0, origin_survey_n)
	var north_geo: PackedFloat64Array = lv95_to_wgs84(origin_survey_e, origin_survey_n + 10.0)
	var east: PackedFloat64Array = to_local(east_geo[0], east_geo[1])
	var north: PackedFloat64Array = to_local(north_geo[0], north_geo[1])
	ee = east[0] / 10.0
	ne = east[1] / 10.0
	en = north[0] / 10.0
	nn = north[1] / 10.0
	inverse_det = ee * nn - en * ne
	return true

func to_local(lat: float, lon: float) -> PackedFloat64Array:
	var phi: float = deg_to_rad(origin_lat)
	var w: float = sqrt(1.0 - E2 * sin(phi) ** 2)
	var meridional: float = A * (1.0 - E2) / (w ** 3)
	var prime: float = A / w
	return PackedFloat64Array([(lon - origin_lon) * PI / 180.0 * prime * cos(phi),
		(lat - origin_lat) * PI / 180.0 * meridional])

func survey_to_local(e: float, n: float) -> PackedFloat64Array:
	var de: float = e - origin_survey_e
	var dn: float = n - origin_survey_n
	return PackedFloat64Array([ee * de + en * dn, ne * de + nn * dn])

func local_to_survey(east: float, north: float) -> PackedFloat64Array:
	return PackedFloat64Array([(nn * east - en * north) / inverse_det + origin_survey_e,
		(-ne * east + ee * north) / inverse_det + origin_survey_n])

func nearest_local(east: float, north: float, maximum_distance: float = 0.55) -> Dictionary:
	var survey: PackedFloat64Array = local_to_survey(east, north)
	var ix: int = roundi((survey[0] - min_e) / spacing)
	var iy: int = roundi((max_n - survey[1]) / spacing)
	var radius: int = ceili(maximum_distance / spacing)
	var best: float = maximum_distance * maximum_distance
	var hit: Dictionary = {}
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var x: int = ix + dx
			var y: int = iy + dy
			var elevation: float = cell_elevation(x, y)
			if is_nan(elevation):
				continue
			var e: float = min_e + x * spacing
			var n: float = max_n - y * spacing
			var local: PackedFloat64Array = survey_to_local(e, n)
			var d2: float = (local[0] - east) ** 2 + (local[1] - north) ** 2
			if d2 <= best:
				best = d2
				hit = {"eastingM": e, "northingM": n, "elevationNf02M": elevation,
					"depthM": maxf(0.0, waterline - elevation), "isInterpolated": is_nan(cell_elevation(x, y, false))}
	return hit

func cell_elevation(x: int, y: int, display: bool = true) -> float:
	if x < 0 or y < 0 or x >= width or y >= height:
		return NAN
	var index: int = y * width + x
	var offset: int = 40 + index * 2
	if display:
		offset += width * height * 2
	var encoded: int = grid.decode_u16(offset)
	if encoded == 65535:
		return NAN
	return 400.0 + float(encoded) / 100.0

func sample_near(lat: float, lon: float, radius_m: float = 1.0) -> Dictionary:
	var survey: PackedFloat64Array = wgs84_to_lv95(lat, lon)
	var ix: int = roundi((survey[0] - min_e) / spacing)
	var iy: int = roundi((max_n - survey[1]) / spacing)
	var radius: int = ceili(radius_m / spacing)
	var best: float = radius_m * radius_m
	var hit: Dictionary = {}
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var x: int = ix + dx
			var y: int = iy + dy
			var elevation: float = cell_elevation(x, y)
			if is_nan(elevation):
				continue
			var east: float = min_e + x * spacing
			var north: float = max_n - y * spacing
			var d2: float = (east - survey[0]) ** 2 + (north - survey[1]) ** 2
			if d2 <= best:
				best = d2
				hit = {"elevationNf02M": elevation, "depthM": maxf(0.0, waterline - elevation),
					"isInterpolated": is_nan(cell_elevation(x, y, false)), "eastingM": east, "northingM": north}
	return hit

static func lv95_to_wgs84(e: float, n: float) -> PackedFloat64Array:
	var y: float = (e - 2600000.0) / 1000000.0
	var x: float = (n - 1200000.0) / 1000000.0
	var lon: float = 2.6779094 + 4.728982 * y + 0.791484 * y * x + 0.1306 * y * x * x - 0.0436 * y ** 3
	var lat: float = 16.9023892 + 3.238272 * x - 0.270978 * y * y - 0.002528 * x * x - 0.0447 * y * y * x - 0.0140 * x ** 3
	return PackedFloat64Array([lat * 100.0 / 36.0, lon * 100.0 / 36.0])

static func wgs84_to_lv95(lat: float, lon: float) -> PackedFloat64Array:
	var e: float = 2600000.0
	var n: float = 1200000.0
	for i: int in 8:
		var p: PackedFloat64Array = lv95_to_wgs84(e, n)
		var pe: PackedFloat64Array = lv95_to_wgs84(e + 1.0, n)
		var pn: PackedFloat64Array = lv95_to_wgs84(e, n + 1.0)
		var a: float = pe[1] - p[1]
		var b: float = pn[1] - p[1]
		var c: float = pe[0] - p[0]
		var d: float = pn[0] - p[0]
		var det: float = a * d - b * c
		var dl: float = lon - p[1]
		var dp: float = lat - p[0]
		e += (d * dl - b * dp) / det
		n += (-c * dl + a * dp) / det
	return PackedFloat64Array([e, n])

static func leg(lat1: float, lon1: float, lat2: float, lon2: float) -> PackedFloat64Array:
	var p1: float = deg_to_rad(lat1)
	var p2: float = deg_to_rad(lat2)
	var dp: float = p2 - p1
	var dl: float = deg_to_rad(lon2 - lon1)
	var h: float = sin(dp / 2.0) ** 2 + cos(p1) * cos(p2) * sin(dl / 2.0) ** 2
	var distance: float = 2.0 * 6371008.8 * asin(minf(1.0, sqrt(h)))
	var y: float = sin(dl) * cos(p2)
	var x: float = cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl)
	return PackedFloat64Array([distance, fposmod(rad_to_deg(atan2(y, x)) + 360.0, 360.0)])
