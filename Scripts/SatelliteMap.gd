class_name BathysSatelliteMap
extends Control

signal poi_clicked(poi: Dictionary)
signal terrain_clicked(lat: float, lon: float, depth: float, interpolated: bool)
signal pick_rejected(message: String)

const INK := Color("f5fbf7")
const AQUA := Color("72e9dd")
const AMBER := Color("ffb96f")
const BG := Color("071c29")

var site: BathysSite
var route: Array[Dictionary] = []
var show_bathymetry: bool = false:
	set(value):
		show_bathymetry = value
		queue_redraw()
var image: Texture2D
var overlay: Texture2D
var zoom: int = 18
var tile_x: int = 0
var tile_y: int = 0
var crop_left: int = 0
var crop_top: int = 0
var magnification: float = 1.0
var pan: Vector2 = Vector2.ZERO
var press: Vector2 = Vector2.ZERO
var last: Vector2 = Vector2.ZERO
var dragging: bool = false
var moved: bool = false
var diver_lat: float = NAN
var diver_lon: float = NAN

func set_waterline(elevation: float) -> void:
	if site == null or absf(site.waterline - elevation) < 1e-6:
		return
	site.waterline = elevation
	var pixels := PackedByteArray()
	pixels.resize(site.width * site.height * 4)
	var stops: Array[Color] = [Color("45b4a8"), Color("258a90"), Color("125d74"), Color("0a3e5c"), Color("06253e")]
	var limits: Array[float] = [0.0, 10.0, 20.0, 30.0, 45.0]
	for y: int in site.height:
		for x: int in site.width:
			var elevation_cell: float = site.cell_elevation(x, y)
			if is_nan(elevation_cell):
				continue
			var depth: float = maxf(0.0, elevation - elevation_cell)
			var band: int = 3
			for i: int in 4:
				if depth < limits[i + 1]:
					band = i
					break
			var fraction: float = clampf((depth - limits[band]) / (limits[band + 1] - limits[band]), 0.0, 1.0)
			var color: Color = stops[band].lerp(stops[band + 1], fraction)
			var phase: float = fposmod(depth, 5.0)
			var contour: float = 0.83 if minf(phase, 5.0 - phase) < 0.18 else 1.0
			var offset: int = (y * site.width + x) * 4
			pixels[offset] = roundi(color.r * contour * 255.0)
			pixels[offset + 1] = roundi(color.g * contour * 255.0)
			pixels[offset + 2] = roundi(color.b * contour * 255.0)
			pixels[offset + 3] = 248
	var raster: Image = Image.create_from_data(site.width, site.height, false, Image.FORMAT_RGBA8, pixels)
	overlay = ImageTexture.create_from_image(raster)
	queue_redraw()

func _ready() -> void:
	name = "Offline satellite map"
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)
	var meta: Dictionary = BathysSite.read_json("res://Data/site_satellite.json")
	zoom = int(meta.get("zoom", 18))
	tile_x = int(meta.get("tileXMin", 0))
	tile_y = int(meta.get("tileYMin", 0))
	crop_left = int(meta.get("cropLeftPx", 0))
	crop_top = int(meta.get("cropTopPx", 0))
	image = load("res://Data/site_satellite.jpg") as Texture2D
	overlay = load("res://Data/bathymetry_default.png") as Texture2D

func image_size() -> Vector2:
	return image.get_size() if image != null else Vector2(2560, 1280)

func map_scale() -> float:
	var dimensions: Vector2 = image_size()
	return maxf(0.01, minf((size.x - 22.0) / dimensions.x, (size.y - 22.0) / dimensions.y)) * magnification

func map_origin() -> Vector2:
	return (size - image_size() * map_scale()) / 2.0 + pan

func project(lat: float, lon: float) -> Vector2:
	var tiles: float = pow(2.0, zoom)
	var radians: float = deg_to_rad(lat)
	var px: float = ((lon + 180.0) / 360.0 * tiles - tile_x) * 256.0 - crop_left
	var py: float = ((1.0 - asinh(tan(radians)) / PI) / 2.0 * tiles - tile_y) * 256.0 - crop_top
	return map_origin() + Vector2(px, py) * map_scale()

func unproject(screen: Vector2) -> PackedFloat64Array:
	var p: Vector2 = (screen - map_origin()) / map_scale()
	var tiles: float = pow(2.0, zoom)
	var x: float = tile_x + (p.x + crop_left) / 256.0
	var y: float = tile_y + (p.y + crop_top) / 256.0
	return PackedFloat64Array([rad_to_deg(atan(sinh(PI * (1.0 - 2.0 * y / tiles)))), x / tiles * 360.0 - 180.0])

func reset_view() -> void:
	magnification = 1.0
	pan = Vector2.ZERO
	queue_redraw()

func set_route(value: Array[Dictionary]) -> void:
	route = value
	queue_redraw()

func set_diver(lat: float, lon: float) -> void:
	diver_lat = lat
	diver_lon = lon
	queue_redraw()

func label(value: String, at: Vector2, font_size: int = 12, color: Color = INK) -> void:
	var font: Font = ThemeDB.fallback_font
	draw_string_outline(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, BG)
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("123844"))
	if image != null:
		draw_texture_rect(image, Rect2(map_origin(), image_size() * map_scale()), false)
	if site == null:
		return
	if show_bathymetry and overlay != null:
		var half: float = site.spacing / 2.0
		var nw: PackedFloat64Array = BathysSite.lv95_to_wgs84(site.min_e - half, site.max_n + half)
		var ne: PackedFloat64Array = BathysSite.lv95_to_wgs84(site.min_e + half, site.max_n + half)
		var sw: PackedFloat64Array = BathysSite.lv95_to_wgs84(site.min_e - half, site.max_n - half)
		var corner: Vector2 = project(nw[0], nw[1])
		var east: Vector2 = project(ne[0], ne[1])
		var south: Vector2 = project(sw[0], sw[1])
		draw_set_transform_matrix(Transform2D(east - corner, south - corner, corner))
		draw_texture_rect(overlay, Rect2(Vector2.ZERO, overlay.get_size()), false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	var previous_lat: float = float(site.pois[0].get("latitudeDeg", site.origin_lat))
	var previous_lon: float = float(site.pois[0].get("longitudeDeg", site.origin_lon))
	for waypoint: Dictionary in route:
		if str(waypoint.get("kind", "travel")) == "switch":
			continue
		var lat: float = float(waypoint.get("latitudeDeg", previous_lat))
		var lon: float = float(waypoint.get("longitudeDeg", previous_lon))
		var a: Vector2 = project(previous_lat, previous_lon)
		var b: Vector2 = project(lat, lon)
		draw_line(a, b, BG, 5.0, true)
		draw_line(a, b, AMBER, 2.5, true)
		draw_circle(b, 6.0, BG)
		draw_circle(b, 4.0, AMBER)
		previous_lat = lat
		previous_lon = lon
	for i: int in site.pois.size():
		var poi: Dictionary = site.pois[i]
		var p: Vector2 = project(float(poi.get("latitudeDeg", 0.0)), float(poi.get("longitudeDeg", 0.0)))
		var marker_color: Color = AMBER if i == 0 else AQUA
		draw_circle(p, 8.0, BG)
		draw_circle(p, 5.0, marker_color)
		var title: String = str(poi.get("name", "Point"))
		if i > 0:
			title += " · %.1f m" % float(poi.get("depthM", 0.0))
		var text_size: Vector2 = ThemeDB.fallback_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		var pos: Vector2 = p + Vector2(10.0, -10.0)
		if pos.x + text_size.x > size.x:
			pos.x = p.x - text_size.x - 12.0
		draw_rect(Rect2(pos - Vector2(3.0, 12.0), text_size + Vector2(6.0, 6.0)), Color(0.018, 0.09, 0.13, 0.82))
		label(title, pos, 12, marker_color if i == 0 else INK)
	if not is_nan(diver_lat):
		var diver: Vector2 = project(diver_lat, diver_lon)
		draw_arc(diver, 10.0, 0.0, TAU, 30, Color("ff6676"), 2.5)
		draw_circle(diver, 3.0, Color("ff6676"))
	label("N ↑", Vector2(size.x - 55.0, 27.0), 16, AMBER)
	var metres_per_pixel: float = cos(deg_to_rad(site.origin_lat)) * 2.0 * PI * 6378137.0 / (256.0 * pow(2.0, zoom))
	var bar_length: float = 25.0 / metres_per_pixel * map_scale()
	var anchor: Vector2 = Vector2(16.0, size.y - 27.0)
	draw_line(anchor, anchor + Vector2(bar_length, 0.0), BG, 7.0)
	draw_line(anchor, anchor + Vector2(bar_length, 0.0), INK, 4.0)
	label("25 m", anchor + Vector2(bar_length / 2.0 - 13.0, -8.0), 11)
	label("NavSurf 2015 measured/interpolated bathymetry · © swisstopo SWISSIMAGE" if show_bathymetry else "© swisstopo SWISSIMAGE", Vector2(12.0, size.y - 7.0), 10)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.pressed and (mouse.button_index == MOUSE_BUTTON_WHEEL_UP or mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var before: Vector2 = (mouse.position - map_origin()) / map_scale()
			magnification = clampf(magnification * (1.16 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.16), 0.6, 8.0)
			pan = mouse.position - (size - image_size() * map_scale()) / 2.0 - before * map_scale()
			queue_redraw()
			accept_event()
			return
		if mouse.button_index == MOUSE_BUTTON_LEFT or mouse.button_index == MOUSE_BUTTON_RIGHT or mouse.button_index == MOUSE_BUTTON_MIDDLE:
			if mouse.pressed:
				dragging = true
				moved = false
				press = mouse.position
				last = mouse.position
			elif dragging:
				dragging = false
				if not moved and mouse.button_index == MOUSE_BUTTON_LEFT:
					click_map(mouse.position)
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if motion.position.distance_to(press) > 4.0:
			moved = true
		if moved:
			pan += motion.position - last
			queue_redraw()
		last = motion.position
		accept_event()

func click_map(point: Vector2) -> void:
	for poi: Dictionary in site.pois:
		if project(float(poi.get("latitudeDeg", 0.0)), float(poi.get("longitudeDeg", 0.0))).distance_to(point) < 13.0:
			poi_clicked.emit(poi)
			return
	var geo: PackedFloat64Array = unproject(point)
	var sample: Dictionary = site.sample_near(geo[0], geo[1])
	if sample.is_empty():
		pick_rejected.emit("No measured or interpolated lakebed at this position.")
	else:
		terrain_clicked.emit(geo[0], geo[1], float(sample["depthM"]), bool(sample["isInterpolated"]))
