extends SceneTree

# Routine asset sizing only; the original generated artwork is preserved.
func _initialize() -> void:
	var master := Image.load_from_file("res://Assets/Brand/bathys-master.png")
	if master == null:
		push_error("Bathys master logo is missing.")
		quit(1)
		return
	for edge: int in [256, 512]:
		var asset: Image = master.duplicate() as Image
		asset.resize(edge, edge, Image.INTERPOLATE_LANCZOS)
		var result: Error = asset.save_png("res://Assets/Brand/bathys-%d.png" % edge)
		if result != OK:
			push_error("Could not prepare logo size %d." % edge)
			quit(1)
			return
	print("Prepared Bathys logo sizes; master transparency: ", master.detect_alpha())
	var preset := ConfigFile.new()
	if preset.load("res://export_presets.cfg") == OK:
		preset.set_value("preset.0.options", "html/head_include", FileAccess.get_file_as_string("res://Assets/Brand/loading-head.html"))
		preset.save("res://export_presets.cfg")
	quit()
