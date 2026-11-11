extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(lake: BathysLakeViewport, suffix: String) -> void:
	for i: int in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://Screenshots/terrain-" + suffix + ".png")

func run() -> void:
	root.size = Vector2i(1280, 900)
	var site := BathysSite.new()
	if not site.load_packaged(): quit(1); return
	var lake := BathysLakeViewport.new()
	lake.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(lake)
	lake.load_site(site, site.waterline)
	lake.diver.hide()
	var tag: String = "before" if "--baseline" in OS.get_cmdline_user_args() else "relief"
	await capture(lake, tag)
	lake.yaw = -0.7
	lake.pitch = 0.85
	lake.distance = 210
	lake.update_camera()
	await capture(lake, tag + "-orbit")
	print("TERRAIN_RENDER: ", tag, " triangles=", lake.triangle_count)
	lake.queue_free()
	await process_frame
	quit(0)
