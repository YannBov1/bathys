class_name BathysMetricGraph
extends Control

signal seek_requested(time_s: float)

var frames: Array[Dictionary] = []
var legs: Array[Dictionary] = []
var metric: String = "depth"
var current_time: float = 0.0

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	tooltip_text = "Click or drag to seek. Focus and use Left/Right to move 10 seconds."
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func value_at(frame: Dictionary) -> Variant:
	match metric:
		"depth": return frame["depthM"]
		"tts": return null if frame.get("ttsS") == null else float(frame["ttsS"]) / 60.0
		"ndl": return null if float(frame["depthM"]) < 0.1 else (99.0 if frame.get("ndlS") == null else float(frame["ndlS"]) / 60.0)
		"cns": return frame["cnsPercent"]
		_: return frame["otu"]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b2632"))
	var font: Font = ThemeDB.fallback_font
	var info: Array = {
		"depth": ["DEPTH / DECOMPRESSION CEILING", "m", "62e3d5", 10.0],
		"tts": ["TIME TO SURFACE", "min", "ffb96f", 5.0],
		"ndl": ["NO DECO LIMIT", "min", "79c9f3", 10.0],
		"cns": ["CNS CLOCK", "%", "e0a6ed", 5.0],
		"otu": ["PULMONARY O₂ EXPOSURE", "OTU", "82e1c3", 10.0]
	}[metric]
	var color := Color(str(info[2]))
	draw_string(font, Vector2(11,18), str(info[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("a8c5c8"))
	if frames.size() < 2:
		return
	var plot := Rect2(43,28,maxf(10,size.x-62),maxf(10,size.y-50))
	var duration: float = maxf(1, float(frames[-1]["timeS"]))
	var maximum: float = 99.0 if metric == "ndl" else float(info[3])
	for frame: Dictionary in frames:
		var value: Variant = value_at(frame)
		if value != null:
			maximum = maxf(maximum,float(value))
	maximum = ceilf(maximum/float(info[3]))*float(info[3])
	for i: int in 5:
		var y: float = plot.position.y+plot.size.y*i/4.0
		draw_line(Vector2(plot.position.x,y),Vector2(plot.end.x,y),Color(0.36,0.57,0.61,0.18))
		var x: float = plot.position.x+plot.size.x*i/4.0
		draw_string(font,Vector2(x-9,size.y-5),"%.0f min" % (duration*i/240.0),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("8ba9ae"))
	var points := PackedVector2Array()
	var ceiling := PackedVector2Array()
	for frame: Dictionary in frames:
		var value: Variant = value_at(frame)
		if value == null:
			if points.size()>1:
				draw_polyline(points,color,2,true)
			points.clear()
			continue
		var x: float = plot.position.x+float(frame["timeS"])/duration*plot.size.x
		var fraction: float = float(value)/maximum
		points.append(Vector2(x,plot.position.y+fraction*plot.size.y if metric=="depth" else plot.end.y-fraction*plot.size.y))
		if metric=="depth":
			ceiling.append(Vector2(x,plot.position.y+float(frame["ceilingM"])/maximum*plot.size.y))
	if points.size()>1:
		draw_polyline(points,color,2,true)
	if ceiling.size()>1:
		draw_polyline(ceiling,Color("f9b26e"),1.5,true)
	if metric=="depth":
		var event_time: float = 0
		for leg: Dictionary in legs:
			if str(leg["kind"])=="switch":
				var x: float = plot.position.x+event_time/duration*plot.size.x
				draw_line(Vector2(x,plot.position.y),Vector2(x,plot.end.y),Color(1,0.62,0.38,0.72),1.5)
				draw_string(font,Vector2(x+4,plot.position.y+12),"GAS",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("ffb276"))
			event_time+=float(leg["durationS"])
	var cursor: float = plot.position.x+clampf(current_time/duration,0,1)*plot.size.x
	draw_line(Vector2(cursor,plot.position.y),Vector2(cursor,plot.end.y),Color("e8f4f1"),1.5)
	var current: Dictionary = frames[BathysSimulation.frame_index_at(frames,current_time)]
	var reading: Variant = value_at(current)
	if reading != null:
		var y: float = plot.position.y+float(reading)/maximum*plot.size.y if metric=="depth" else plot.end.y-float(reading)/maximum*plot.size.y
		draw_circle(Vector2(cursor,y),3.5,color)
		var caption: String = "%.1f %s" % [float(reading), str(info[1])]
		draw_string(font,Vector2(size.x-100,18),caption,HORIZONTAL_ALIGNMENT_RIGHT,88,11,color)
	draw_string(font,Vector2(5,plot.position.y+9),"0 m" if metric=="depth" else "%.0f" % maximum,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("8ba9ae"))
	draw_string(font,Vector2(5,plot.end.y),"%.0f m" % maximum if metric=="depth" else "0",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("8ba9ae"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not frames.is_empty():
		if event.keycode in [KEY_LEFT, KEY_RIGHT]:
			seek_requested.emit(clampf(current_time + (-10 if event.keycode == KEY_LEFT else 10), 0, float(frames[-1]["timeS"])))
			accept_event()
		return
	var position: Vector2
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
			return
		position = button.position
	elif event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		position = (event as InputEventMouseMotion).position
	else:
		return
	if not frames.is_empty():
		seek_requested.emit(clampf((position.x-43)/maxf(10,size.x-62),0,1)*float(frames[-1]["timeS"]))
		accept_event()
