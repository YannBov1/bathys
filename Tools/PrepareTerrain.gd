extends SceneTree

func _initialize() -> void:
	call_deferred("build")

func normal_at(site: BathysSite, x: int, y: int, center: float) -> Vector3:
	var east := Vector3.ZERO
	var north := Vector3.ZERO
	var east_height: float = site.cell_elevation(x + 1, y)
	if not is_nan(east_height):
		east += Vector3(site.ee * site.spacing, east_height - center, -site.ne * site.spacing)
	east_height = site.cell_elevation(x - 1, y)
	if not is_nan(east_height):
		east += Vector3(site.ee * site.spacing, center - east_height, -site.ne * site.spacing)
	var north_height: float = site.cell_elevation(x, y - 1)
	if not is_nan(north_height):
		north += Vector3(site.en * site.spacing, north_height - center, -site.nn * site.spacing)
	north_height = site.cell_elevation(x, y + 1)
	if not is_nan(north_height):
		north += Vector3(site.en * site.spacing, center - north_height, -site.nn * site.spacing)
	if east.length_squared() > 0.0001 and north.length_squared() > 0.0001:
		return east.cross(north).normalized()
	return Vector3.UP

func build() -> void:
	var site := BathysSite.new()
	if not site.load_packaged():
		push_error("Grid missing")
		quit(1)
		return
	var output: String = ProjectSettings.globalize_path("res://Data/terrain_tiles")
	DirAccess.make_dir_recursive_absolute(output)
	var tiles: Array[Dictionary] = []
	var total_triangles: int = 0
	var cells: int = roundi(64.0 / site.spacing)
	var tiles_x: int = ceili(float(site.width - 1) / cells)
	var tiles_y: int = ceili(float(site.height - 1) / cells)
	for ty: int in tiles_y:
		for tx: int in tiles_x:
			var vertices := PackedVector3Array()
			var normals := PackedVector3Array()
			var indices := PackedInt32Array()
			var vertex_index: Dictionary = {}
			for local_y: int in range(cells + 1):
				for local_x: int in range(cells + 1):
					var x: int = tx * cells + local_x
					var y: int = site.height - 1 - (ty * cells + local_y)
					var elevation: float = site.cell_elevation(x, y)
					if is_nan(elevation):
						continue
					var e: float = site.min_e + x * site.spacing
					var n: float = site.max_n - y * site.spacing
					var local: PackedFloat64Array = site.survey_to_local(e, n)
					vertex_index[local_y * (cells + 1) + local_x] = vertices.size()
					vertices.append(Vector3(local[0], elevation - site.waterline, -local[1]))
					normals.append(normal_at(site, x, y, elevation))
			for local_y: int in cells:
				for local_x: int in cells:
					var a: int = local_y * (cells + 1) + local_x
					var b: int = a + 1
					var c: int = a + cells + 1
					var d: int = c + 1
					# Tile Y runs north, matching the reference mesh's diagonal.
					if vertex_index.has(a) and vertex_index.has(b) and vertex_index.has(c):
						indices.append_array(PackedInt32Array([vertex_index[a], vertex_index[b], vertex_index[c]]))
					if vertex_index.has(b) and vertex_index.has(c) and vertex_index.has(d):
						indices.append_array(PackedInt32Array([vertex_index[b], vertex_index[d], vertex_index[c]]))
			if indices.is_empty():
				continue
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_INDEX] = indices
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var path: String = "res://Data/terrain_tiles/tile_%02d_%02d.res" % [tx, ty]
			var error: Error = ResourceSaver.save(mesh, path)
			if error != OK:
				push_error("Could not save " + path + ": " + str(error))
				quit(1)
				return
			var triangles: int = indices.size() / 3
			total_triangles += triangles
			tiles.append({"path": path, "triangles": triangles})
	print("Prepared ", tiles.size(), " terrain tiles, ", total_triangles, " triangles")
	var file: FileAccess = FileAccess.open("res://Data/terrain_tiles.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"tiles": tiles, "triangles": total_triangles,
		"waterlineReferenceM": site.waterline, "source": "NavSurf 2015 display grid; measured/interpolated flags remain in survey_grid.dat"}, "  "))
	file.close()
	quit()
