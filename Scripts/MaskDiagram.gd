class_name BathysMaskDiagram
extends BathysThermalDiagram

func adapt() -> void:
	custom_minimum_size.y = 940 if comparison_visible and size.x < 660 else (470 if comparison_visible else 350)
	tooltip_text = "Drag the real object in the ray view to change its distance" if comparison_visible else "Drag the target on the distance rail"
	queue_redraw()

func section(index: int) -> Rect2:
	if not comparison_visible: return Rect2(Vector2.ZERO, size)
	if size.x < 660: return Rect2(0, index * 470, size.x, 470)
	return Rect2(index * size.x / 2, 0, size.x / 2, size.y)

func scene_scale() -> float:
	return minf((section(0).size.x - 64) / float(result["actual"]), 175 / float(params["height"]))

func manipulate(at: Vector2) -> void:
	if not comparison_visible:
		if at.y > 45 and at.y < 145: parameter_changed.emit("distance", clampf(0.5 + (at.x - 75) / maxf(1, size.x - 115) * 2.5, 0.5, 3))
		return
	if result.is_empty() or not section(0).has_point(at) or at.y < 75 or at.y > 295: return
	var distance: float = (at.x - 30) / scene_scale() - (float(params["gap"]) + float(params["thickness"])) / 1000
	parameter_changed.emit("distance", clampf(distance, 0.5, 3))

func _draw() -> void:
	draw_style_box(BathysUiStyle.box(Color("08232f"), BathysUiStyle.EDGE, 10, 0), Rect2(Vector2.ZERO, size))
	if result.is_empty(): return
	if not comparison_visible:
		angular_view()
		return
	world_view()
	interface_view()

func world_view() -> void:
	var area: Rect2 = section(0)
	wrapped_words(Vector2(16, 25), "Real rays and straight-line edge projection", area.size.x - 32, INK, 12)
	var scale: float = scene_scale()
	var eye := Vector2(30, 190)
	var inner_x: float = eye.x + float(params["gap"]) / 1000 * scale
	var outer_x: float = inner_x + float(params["thickness"]) / 1000 * scale
	var object_x: float = eye.x + float(result["actual"]) * scale
	var apparent_x: float = eye.x + float(result["apparent"]) * scale
	var half_height: float = float(params["height"]) * scale / 2
	draw_rect(Rect2(outer_x, 78, area.size.x - outer_x - 12, 215), Color("0b3747"))
	draw_rect(Rect2(inner_x, 78, outer_x - inner_x, 215), Color("537488"))
	draw_line(Vector2(inner_x, 78), Vector2(inner_x, 293), VIOLET, 1)
	draw_line(Vector2(outer_x, 78), Vector2(outer_x, 293), VIOLET, 1)
	draw_dashed_line(eye, Vector2(area.size.x - 16, eye.y), Color(MUTED, 0.4), 1, 5)
	for sign_y: float in [-1, 1]:
		var a := Vector2(inner_x, eye.y + sign_y * float(result["air_y"]) * scale)
		var g := Vector2(outer_x, eye.y + sign_y * float(result["glass_y"]) * scale)
		var o := Vector2(object_x, eye.y + sign_y * half_height)
		var virtual := Vector2(apparent_x, eye.y + sign_y * half_height)
		draw_dashed_line(eye, o, Color(MUTED, 0.45), 1, 5)
		draw_dashed_line(a, virtual, Color(AMBER, 0.7), 1.5, 4)
		arrow(o, g, AQUA, 2)
		draw_line(g, a, VIOLET, 2)
		draw_line(a, eye, AMBER, 2)
	draw_rect(Rect2(object_x - 3, eye.y - half_height, 6, 2 * half_height), AQUA)
	draw_rect(Rect2(apparent_x - 3, eye.y - half_height, 6, 2 * half_height), AMBER, false, 1.5)
	draw_circle(eye, 4, INK)
	words(eye + Vector2(-14, 27), "Eye", INK, 11)
	words(Vector2(maxf(16, inner_x - 4), 65), "Mask", VIOLET, 11)
	words(Vector2(16, 322), "Solid: real target", AQUA, 11)
	words(Vector2(16, 343), "Outline: edge back-projection", AMBER, 11)
	wrapped_words(Vector2(16, 372), "Same physical height. A closer straight-line projection gives a larger angular size.", area.size.x - 32, INK, 12)
	wrapped_words(Vector2(16, 425), "Grey rays: all-air reference. Amber dashes: how incoming rays are extended by the eye.", area.size.x - 32, MUTED, 11)

func interface_view() -> void:
	var area: Rect2 = section(1)
	draw_set_transform(area.position)
	area = Rect2(Vector2.ZERO, area.size)
	wrapped_words(area.position + Vector2(16, 25), "Water → glass → mask air · local ray zoom", area.size.x - 32, INK, 12)
	var mid: float = area.position.x + area.size.x / 2
	var top: float = 86
	draw_rect(Rect2(area.position.x + 16, top, area.size.x / 2 - 36, 100), Color("122a34"))
	draw_rect(Rect2(mid - 20, top, 40, 100), Color("3a536a"))
	draw_rect(Rect2(mid + 20, top, area.size.x / 2 - 36, 100), Color("0b3747"))
	var ta: float = result["theta_air"]
	var tg: float = result["theta_glass"]
	var tw: float = result["theta_water"]
	var inner := Vector2(mid - 20, 138 + 20 * tan(tg))
	var outer := Vector2(mid + 20, 138 - 20 * tan(tg))
	var air_end: Vector2 = inner - Vector2(cos(ta), -sin(ta)) * 65
	var water_end: Vector2 = outer + Vector2(cos(tw), -sin(tw)) * 65
	for pos: Vector2 in [inner, outer]: draw_dashed_line(pos - Vector2(35, 0), pos + Vector2(35, 0), Color(MUTED, 0.55), 1, 4)
	arrow(water_end, outer, AQUA, 2)
	arrow(outer, inner, VIOLET, 2)
	arrow(inner, air_end, AMBER, 2)
	words(Vector2(area.position.x + 24, 74), "Air · n = 1", AMBER, 11)
	words(Vector2(mid - 17, 74), "Glass", VIOLET, 11)
	words(Vector2(mid - 17, 102), "%.3f" % float(params["glass_index"]), VIOLET, 9)
	words(Vector2(mid + 45, 74), "Water · n = 1.333", AQUA, 11)
	words(Vector2(area.position.x + 18, 209), tr("Air %.1f°") % rad_to_deg(ta), AMBER, 11)
	words(Vector2(area.position.x + area.size.x * 0.37, 209), tr("Glass %.1f°") % rad_to_deg(tg), VIOLET, 11)
	words(Vector2(area.position.x + area.size.x * 0.70, 209), tr("Water %.1f°") % rad_to_deg(tw), AQUA, 11)
	wrapped_words(area.position + Vector2(16, 231), "Angles are to the normal. Glass thickness is exaggerated in this inset.", area.size.x - 32, MUTED, 11)
	wrapped_words(area.position + Vector2(16, 282), "Same 60° angular field in both frames", area.size.x - 32, INK, 12)
	var width: float = (area.size.x - 48) / 2
	for i: int in 2:
		var rect := Rect2(area.position.x + 16 + i * (width + 16), 316, width, 110)
		draw_rect(rect, Color("164552"))
		draw_rect(rect, MUTED, false, 1)
		var angle: float = result["air_angle"] if i == 0 else result["mask_angle"]
		var height: float = angle / deg_to_rad(60) * rect.size.y
		var target := Rect2(rect.get_center() - Vector2(height * 0.16, height / 2), Vector2(maxf(1, height * 0.32), height))
		draw_rect(target, AQUA)
		for j: int in 3: draw_line(Vector2(target.position.x, target.position.y + target.size.y * (j + 1) / 4), Vector2(target.end.x, target.position.y + target.size.y * (j + 1) / 4), Color("0b3747"), 1)
		wrapped_words(Vector2(rect.position.x, 305), "Reference in air" if i == 0 else "Through the mask", width, MUTED, 10)
	wrapped_words(area.position + Vector2(16, 450), "Angular height changes; the target does not grow.", area.size.x - 32, MUTED, 11)

	draw_set_transform(Vector2.ZERO)

func angular_view() -> void:
	words(Vector2(16, 26), "Same object · same angular field", INK, 13)
	draw_rect(Rect2(58, 53, size.x - 76, 83), Color("0b3747"))
	draw_line(Vector2(58, 94), Vector2(size.x - 28, 94), MUTED, 1)
	draw_circle(Vector2(30, 94), 4, INK)
	words(Vector2(19, 118), "Eye", MUTED, 11)
	draw_line(Vector2(52, 64), Vector2(52, 124), VIOLET, 3)
	var x: float = 75 + (float(params["distance"]) - 0.5) / 2.5 * (size.x - 115)
	draw_rect(Rect2(x - 4, 73, 8, 42), AQUA)
	grip(Vector2(x, 94))
	words(Vector2(maxf(65, x - 22), 130), "%.2f m" % float(params["distance"]), AQUA, 12)
	var width: float = (size.x - 48) / 2
	for i: int in 2:
		var rect := Rect2(16 + i * (width + 16), 187, width, 139)
		draw_rect(rect, Color("164552"))
		draw_rect(rect, MUTED, false, 1)
		var angle: float = result["air_angle"] if i == 0 else result["mask_angle"]
		var height: float = angle / deg_to_rad(60) * rect.size.y
		var target := Rect2(rect.get_center() - Vector2(height * 0.16, height / 2), Vector2(maxf(1, height * 0.32), height))
		draw_rect(target, AQUA)
		for j: int in 3: draw_line(Vector2(target.position.x, target.position.y + target.size.y * (j + 1) / 4), Vector2(target.end.x, target.position.y + target.size.y * (j + 1) / 4), Color("0b3747"), 1)
		words(Vector2(rect.position.x, 175), "Reference in air" if i == 0 else "Through the mask", INK, 12)
