class_name BathysLakeViewport
extends SubViewportContainer

signal poi_clicked(poi: Dictionary)
signal terrain_clicked(lat: float, lon: float, depth: float, interpolated: bool)
signal pick_rejected(message: String)

const AQUA := Color("72e9dd")
const AMBER := Color("ffb96f")
const BG := Color("071c29")

var site: BathysSite
var waterline: float = 478.5
var mesh_reference: float = 478.5
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var terrain_root: Node3D
var route_root: Node3D
var gpx_root: Node3D
var marker_root: Node3D
var diver: MeshInstance3D
var hud: Control
var labels: Array[Label] = []
var label_leaders: Array[Line2D] = []
var markers: Array[Dictionary] = []
var target: Vector3 = Vector3(40.0, -16.0, 40.0)
var distance: float = 155.0
var yaw: float = 0.35
var pitch: float = 0.62
var dragging: bool = false
var panning: bool = false
var moved: bool = false
var last_mouse: Vector2 = Vector2.ZERO
var mouse_origin: Vector2 = Vector2.ZERO
var triangle_count: int = 0
var navigation := BathysMapGesture.new()

func _ready() -> void:
	name = "3D lake view"
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	navigation.single_drag.connect(orbit_pixels)
	navigation.pan.connect(pan_pixels)
	navigation.magnify.connect(func(factor: float, _at: Vector2) -> void: zoom_by(factor))
	navigation.rotate.connect(func(angle: float) -> void: yaw += angle; update_camera())
	navigation.tap.connect(pick)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	resized.connect(update_labels)
	viewport = SubViewport.new()
	viewport.name = "Compatibility 3D viewport"
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(800, 600)
	add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	camera = Camera3D.new()
	camera.current = true
	camera.near = 0.1
	camera.far = 3000.0
	world.add_child(camera)
	var environment := WorldEnvironment.new()
	var atmosphere := Environment.new()
	atmosphere.background_mode = Environment.BG_COLOR
	atmosphere.background_color = BG
	atmosphere.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	atmosphere.ambient_light_color = Color("a6cdd0")
	atmosphere.ambient_light_energy = 0.8
	environment.environment = atmosphere
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, -35.0)
	sun.light_energy = 1.35
	sun.shadow_enabled = false
	world.add_child(sun)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.clip_contents = true
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(hud)
	var credit := Label.new()
	credit.text = "NavSurf 2015 · © swisstopo SWISSIMAGE"
	credit.add_theme_font_size_override("font_size", 10)
	credit.add_theme_color_override("font_color", Color("91b6b9"))
	credit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(credit)
	credit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	credit.position = Vector2(8, -20)
	update_camera()

func _process(_delta: float) -> void:
	update_labels()

func material(color: Color, unshaded: bool = true) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if unshaded:
		mat.no_depth_test = true
	return mat

func terrain_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://Shaders/TerrainRelief.gdshader")
	return mat

func load_site(value: BathysSite, chosen_waterline: float) -> void:
	site = value
	waterline = chosen_waterline
	var manifest: Dictionary = BathysSite.read_json("res://Data/terrain_tiles.json")
	mesh_reference = float(manifest.get("waterlineReferenceM", value.waterline))
	triangle_count = int(manifest.get("triangles", 0))
	terrain_root = Node3D.new()
	terrain_root.name = "Prepared NavSurf lakebed"
	world.add_child(terrain_root)
	var mat: ShaderMaterial = terrain_material()
	for item: Variant in manifest.get("tiles", []):
		var entry: Dictionary = item as Dictionary
		var mesh: ArrayMesh = load(str(entry["path"])) as ArrayMesh
		if mesh == null:
			push_error("Missing prepared terrain tile: " + str(entry["path"]))
			continue
		var instance := MeshInstance3D.new()
		instance.name = str(entry["path"]).get_file()
		instance.mesh = mesh
		instance.material_override = mat
		terrain_root.add_child(instance)
	terrain_root.position.y = mesh_reference - waterline
	route_root = Node3D.new()
	route_root.name = "Planned route"
	world.add_child(route_root)
	gpx_root = Node3D.new()
	gpx_root.name = "GPX map overlays"
	world.add_child(gpx_root)
	marker_root = Node3D.new()
	marker_root.name = "Observed POIs"
	world.add_child(marker_root)
	var diver_mesh := SphereMesh.new()
	diver_mesh.radius = 1.7
	diver_mesh.height = 3.4
	diver = MeshInstance3D.new()
	diver.name = "Playback diver"
	diver.mesh = diver_mesh
	diver.material_override = material(Color("ff6676"))
	world.add_child(diver)
	refresh_pois()
	reset_view()
	print("BATHYS_TERRAIN_TRIANGLES=", triangle_count)

func set_waterline(value: float) -> void:
	if gpx_root != null: gpx_root.position.y += waterline - value
	waterline = value
	if terrain_root != null:
		terrain_root.position.y = mesh_reference - waterline

func set_gpx_overlays(overlays: Array[Dictionary]) -> void:
	if gpx_root == null: return
	for child: Node in gpx_root.get_children():
		gpx_root.remove_child(child)
		child.queue_free()
	# Prepared coordinates share the import waterline; later waterline edits move this root.
	for item: Dictionary in overlays:
		if not item["visible"]: continue
		var parent := Node3D.new()
		parent.name = str(item["name"]).validate_node_name()
		parent.position.y = float(item["waterline"]) - waterline - gpx_root.position.y
		gpx_root.add_child(parent)
		var paths: Array = item["geometry"]["paths"].duplicate()
		for point: Vector3 in item["geometry"]["markers"]:
			paths.append(PackedVector3Array([point - Vector3(0.8, 0, 0), point + Vector3(0.8, 0, 0)]))
			paths.append(PackedVector3Array([point - Vector3(0, 0, 0.8), point + Vector3(0, 0, 0.8)]))
		gpx_ribbon(paths, 0.65, BG, parent, -0.015)
		gpx_ribbon(paths, 0.32, item["color"], parent, 0)

func gpx_ribbon(paths: Array, radius: float, color: Color, parent: Node3D, lift: float) -> void:
	var mesh := ImmediateMesh.new()
	var started: bool = false
	for path: PackedVector3Array in paths:
		for i: int in range(1, path.size()):
			var a: Vector3 = path[i - 1] + Vector3.UP * lift
			var b: Vector3 = path[i] + Vector3.UP * lift
			var direction := Vector3(b.x - a.x, 0, b.z - a.z)
			if direction.length_squared() < 1e-10: continue
			if not started:
				mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
				started = true
			var side: Vector3 = direction.normalized().cross(Vector3.UP) * radius
			for point: Vector3 in [a - side, a + side, b - side, b - side, a + side, b + side]: mesh.surface_add_vertex(point)
	if not started: return
	mesh.surface_end()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var mat: StandardMaterial3D = material(color)
	mat.no_depth_test = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = mat
	parent.add_child(instance)

func world_at(lat: float, lon: float, depth: float) -> Vector3:
	var local: PackedFloat64Array = site.to_local(lat, lon)
	return Vector3(local[0], -depth, -local[1])

func refresh_pois() -> void:
	if site == null or marker_root == null:
		return
	for child: Node in marker_root.get_children():
		child.queue_free()
	for caption: Label in labels:
		caption.queue_free()
	for leader: Line2D in label_leaders:
		leader.queue_free()
	labels.clear()
	label_leaders.clear()
	markers.clear()
	for index: int in site.pois.size():
		var poi: Dictionary = site.pois[index]
		var p: Vector3 = world_at(float(poi["latitudeDeg"]), float(poi["longitudeDeg"]), float(poi["depthM"]))
		var sphere := SphereMesh.new()
		sphere.radius = 1.8 if index == 0 else 1.4
		sphere.height = sphere.radius * 2.0
		var instance := MeshInstance3D.new()
		instance.mesh = sphere
		instance.position = p
		instance.material_override = material(AMBER if index == 0 else AQUA)
		marker_root.add_child(instance)
		var caption := Label.new()
		caption.text = str(poi["name"])
		caption.add_theme_font_size_override("font_size", 13)
		caption.add_theme_color_override("font_color", AMBER if index == 0 else AQUA)
		caption.add_theme_color_override("font_outline_color", Color("092531"))
		caption.add_theme_constant_override("outline_size", 3)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var leader := Line2D.new()
		leader.width = 1.0
		leader.default_color = Color(0.45, 0.8, 0.78, 0.45)
		leader.antialiased = true
		hud.add_child(leader)
		label_leaders.append(leader)
		hud.add_child(caption)
		labels.append(caption)
		markers.append({"poi": poi, "position": p})
	update_labels()

func update_labels() -> void:
	if camera == null or not camera.is_inside_tree():
		return
	hud.size = size
	var occupied: Array[Rect2] = []
	for index: int in markers.size():
		var p: Vector3 = markers[index]["position"] as Vector3
		var label_node: Label = labels[index]
		if camera.is_position_behind(p):
			label_node.visible = false
			label_leaders[index].visible = false
			continue
		var screen: Vector2 = camera.unproject_position(p)
		label_node.visible = screen.x >= 0.0 and screen.y >= 0.0 and screen.x < size.x and screen.y < size.y
		var caption_size: Vector2 = label_node.get_minimum_size()
		var anchor: Vector2 = screen + Vector2(8, -16)
		anchor.x = clampf(anchor.x, 4, maxf(4, size.x - caption_size.x - 4))
		for attempt: int in 14:
			var bounds := Rect2(anchor, caption_size).grow(3)
			var collides: bool = false
			for prior: Rect2 in occupied:
				if bounds.intersects(prior):
					collides = true
					break
			if not collides:
				break
			anchor.y -= caption_size.y + 4
		anchor.y = clampf(anchor.y, 4, maxf(4, size.y - caption_size.y - 4))
		label_node.position = anchor
		if label_node.visible:
			occupied.append(Rect2(anchor, caption_size).grow(3))
		var leader: Line2D = label_leaders[index]
		leader.visible = label_node.visible and screen.distance_to(anchor) > 24
		leader.points = PackedVector2Array([screen, anchor + Vector2(0, caption_size.y / 2)])

func line_between(a: Vector3, b: Vector3, color: Color, radius: float, parent: Node3D) -> void:
	var delta: Vector3 = b - a
	if delta.length() < 0.3:
		return
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = delta.length()
	cylinder.radial_segments = 6
	var instance := MeshInstance3D.new()
	instance.mesh = cylinder
	instance.position = (a + b) / 2.0
	instance.quaternion = Quaternion(Vector3.UP, delta.normalized())
	instance.material_override = material(color)
	parent.add_child(instance)

func set_route(route: Array[Dictionary]) -> void:
	if site == null or route_root == null:
		return
	for child: Node in route_root.get_children():
		child.queue_free()
	var prior: Dictionary = site.pois[0]
	var lat: float = float(prior["latitudeDeg"])
	var lon: float = float(prior["longitudeDeg"])
	var depth: float = 0.0
	for waypoint: Dictionary in route:
		if str(waypoint.get("kind", "travel")) == "switch":
			continue
		var next_lat: float = float(waypoint.get("latitudeDeg", lat))
		var next_lon: float = float(waypoint.get("longitudeDeg", lon))
		var next_depth: float = float(waypoint.get("targetDepthM", depth))
		var a: Vector3 = world_at(lat, lon, depth)
		var b: Vector3 = world_at(next_lat, next_lon, next_depth)
		line_between(a, b, AMBER, 0.35, route_root)
		var dot_mesh := SphereMesh.new()
		dot_mesh.radius = 1.5
		dot_mesh.height = 3.0
		var dot := MeshInstance3D.new()
		dot.mesh = dot_mesh
		dot.position = b
		dot.material_override = material(AMBER)
		route_root.add_child(dot)
		lat = next_lat
		lon = next_lon
		depth = next_depth

func set_diver(lat: float, lon: float, depth: float) -> void:
	if diver != null and site != null:
		diver.position = world_at(lat, lon, depth)

func update_camera() -> void:
	if camera == null:
		return
	camera.position = target + Vector3(sin(yaw) * cos(pitch) * distance,
		sin(pitch) * distance, cos(yaw) * cos(pitch) * distance)
	camera.look_at(target, Vector3.UP)
	update_labels()

func reset_view() -> void:
	navigation.clear()
	dragging = false
	panning = false
	target = Vector3(40.0, -16.0, 40.0)
	distance = 155.0
	yaw = 0.35
	pitch = 0.62
	update_camera()

func focus_poi(poi: Dictionary) -> void:
	var position: Vector3 = world_at(float(poi["latitudeDeg"]), float(poi["longitudeDeg"]), 10.0)
	target = position
	distance = 130.0
	update_camera()

func _gui_input(event: InputEvent) -> void:
	if navigation.handle(event):
		dragging = false
		panning = false
		accept_event()
		return
	if event is InputEventMagnifyGesture:
		if navigation.accept_native_gesture(event) and navigation.touches.is_empty(): zoom_by(event.factor)
		accept_event()
		return
	if event is InputEventPanGesture:
		if navigation.accept_native_gesture(event) and navigation.touches.is_empty():
			if event.alt_pressed: orbit_pixels(event.delta * 12)
			else: pan_pixels(-event.delta * 12)
		accept_event()
		return
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1:
		accept_event()
		return
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.pressed and mouse.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			var amount: float = clampf(absf(mouse.factor), 0.01, 8)
			if mouse.shift_pressed or mouse.button_index in [MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
				pan_pixels(BathysMapGesture.wheel_pan(mouse))
			else: zoom_by(pow(1.16, amount * (1 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else -1)))
			accept_event()
			return
		if mouse.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mouse.pressed:
				dragging = mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.shift_pressed
				panning = mouse.button_index != MOUSE_BUTTON_LEFT or mouse.shift_pressed
				moved = false
				last_mouse = mouse.position
				mouse_origin = mouse.position
			else:
				if mouse.button_index == MOUSE_BUTTON_LEFT and dragging and not moved:
					pick(mouse.position)
				dragging = false
				panning = false
			accept_event()
			return
	if event is InputEventMouseMotion and (dragging or panning):
		var mouse: InputEventMouseMotion = event as InputEventMouseMotion
		var delta: Vector2 = mouse.position - last_mouse
		last_mouse = mouse.position
		if mouse.position.distance_to(mouse_origin) > 6:
			moved = true
		if moved:
			if dragging and not mouse.shift_pressed: orbit_pixels(delta)
			else: pan_pixels(delta)
		accept_event()

func orbit_pixels(delta: Vector2) -> void:
	yaw -= delta.x * 0.006
	pitch = clampf(pitch + delta.y * 0.006, 0.16, 1.53)
	update_camera()

func pan_pixels(delta: Vector2) -> void:
	var scale: float = distance / maxf(1, size.y) * 1.6
	target -= camera.global_transform.basis.x * delta.x * scale
	target += camera.global_transform.basis.y * delta.y * scale
	update_camera()

func zoom_by(factor: float) -> void:
	if not is_finite(factor) or factor <= 0: return
	distance = clampf(distance / factor, 22, 1250)
	update_camera()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_VISIBILITY_CHANGED, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		navigation.clear()
		dragging = false
		panning = false

func pick(mouse: Vector2) -> void:
	if site == null:
		return
	for marker: Dictionary in markers:
		var p: Vector3 = marker["position"] as Vector3
		if not camera.is_position_behind(p) and camera.unproject_position(p).distance_to(mouse) < 15.0:
			poi_clicked.emit(marker["poi"] as Dictionary)
			return
	var origin: Vector3 = camera.project_ray_origin(mouse)
	var direction: Vector3 = camera.project_ray_normal(mouse)
	var along: float = 0.0
	while along < 1800.0:
		var p: Vector3 = origin + direction * along
		var sample: Dictionary = site.nearest_local(p.x, -p.z)
		if not sample.is_empty() and p.y <= float(sample["elevationNf02M"]) - waterline:
			var geo: PackedFloat64Array = BathysSite.lv95_to_wgs84(float(sample["eastingM"]), float(sample["northingM"]))
			terrain_clicked.emit(geo[0], geo[1], maxf(0.0, waterline - float(sample["elevationNf02M"])), bool(sample["isInterpolated"]))
			return
		along += 0.5
	pick_rejected.emit("No surveyed bed was hit by this ray.")
