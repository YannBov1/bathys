class_name BathysMetricGraph
extends Control

signal seek_requested(time_s: float)

var frames: Array[Dictionary] = []
var metric: String = "depth"
var current_time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b2330"))
	if frames.is_empty():
		return
	var duration: float = maxf(1.0, float(frames[-1]["timeS"]))
	var plot: Rect2 = Rect2(38.0, 13.0, maxf(10.0, size.x - 50.0), maxf(10.0, size.y - 34.0))
	for i: int in 5:
		var y: float = plot.position.y + plot.size.y * i / 4.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(0.5, 0.7, 0.75, 0.2), 1.0)
	var key: String = {"depth": "depthM", "tts": "ttsS", "ndl": "ndlS", "cns": "cnsPercent", "otu": "otu"}.get(metric, "depthM")
	var maximum: float = 1.0
	for frame: Dictionary in frames:
		if frame.get(key) != null:
			maximum = maxf(maximum, float(frame[key]))
		if metric == "depth":
			maximum = maxf(maximum, float(frame["ceilingM"]))
	var points := PackedVector2Array()
	var ceiling_points := PackedVector2Array()
	for frame: Dictionary in frames:
		if frame.get(key) == null:
			if points.size() > 1:
				draw_polyline(points, Color("72e9dd"), 2.0, true)
			points.clear()
			continue
		var x: float = plot.position.x + float(frame["timeS"]) / duration * plot.size.x
		var y: float = plot.end.y - float(frame[key]) / maximum * plot.size.y
		points.append(Vector2(x, y))
		if metric == "depth":
			ceiling_points.append(Vector2(x, plot.end.y - float(frame["ceilingM"]) / maximum * plot.size.y))
	if points.size() > 1:
		draw_polyline(points, Color("72e9dd"), 2.0, true)
	if ceiling_points.size() > 1:
		draw_polyline(ceiling_points, Color("ffb96f"), 2.0, true)
	var cursor_x: float = plot.position.x + clampf(current_time / duration, 0.0, 1.0) * plot.size.x
	draw_line(Vector2(cursor_x, plot.position.y), Vector2(cursor_x, plot.end.y), Color("ff6676"), 1.5)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(5.0, 23.0), "%.0f" % maximum, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f5fbf7"))
	draw_string(font, Vector2(7.0, plot.end.y), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f5fbf7"))
	draw_string(font, Vector2(plot.position.x, size.y - 6.0), "0 min", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f5fbf7"))
	draw_string(font, Vector2(plot.end.x - 45.0, size.y - 6.0), "%.1f min" % (duration / 60.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f5fbf7"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not frames.is_empty():
		var x: float = clampf(((event as InputEventMouseButton).position.x - 38.0) / maxf(10.0, size.x - 50.0), 0.0, 1.0)
		seek_requested.emit(x * float(frames[-1]["timeS"]))
		accept_event()
