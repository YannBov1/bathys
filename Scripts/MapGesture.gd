class_name BathysMapGesture
extends RefCounted

signal single_drag(delta: Vector2)
signal pan(delta: Vector2)
signal magnify(factor: float, center: Vector2)
signal rotate(angle: float)
signal tap(position: Vector2)

const TAP_SLOP := 8.0
var touches: Dictionary = {}
var origins: Dictionary = {}
var moved: bool = false
var multiple: bool = false
var gesture_frame: int = -1
var gesture_signature: String = ""

static func wheel_pan(event: InputEventMouseButton) -> Vector2:
	var direction := Vector2.ZERO
	match event.button_index:
		MOUSE_BUTTON_WHEEL_LEFT: direction.x = -1
		MOUSE_BUTTON_WHEEL_RIGHT: direction.x = 1
		MOUSE_BUTTON_WHEEL_UP: direction.y = -1
		MOUSE_BUTTON_WHEEL_DOWN: direction.y = 1
	return direction * 32 * clampf(absf(event.factor), 0.01, 8)

func clear() -> void:
	touches.clear()
	origins.clear()
	moved = false
	multiple = false
	gesture_frame = -1
	gesture_signature = ""

func accept_native_gesture(event: InputEventGesture) -> bool:
	# Godot 4.7.2 Input::_parse_input_event_impl dispatches gestures in its
	# gesture branch and again at its final dispatch. Consume each adjacent
	# pair once, preserving multiple identical original samples in a frame.
	if int(Engine.get_version_info()["hex"]) != 0x040702: return true
	var signature: String = str([event.get_class(), event.position, event.factor if event is InputEventMagnifyGesture else event.delta, event.shift_pressed, event.alt_pressed, event.ctrl_pressed, event.meta_pressed])
	var frame: int = Engine.get_process_frames()
	if frame == gesture_frame and signature == gesture_signature:
		gesture_signature = ""
		return false
	gesture_frame = frame
	gesture_signature = signature
	return true

func pair() -> PackedVector2Array:
	var ids: Array = touches.keys()
	ids.sort()
	return PackedVector2Array([touches[ids[0]], touches[ids[1]]])

func handle(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed:
			if touches.is_empty(): clear()
			touches[event.index] = event.position
			origins[event.index] = event.position
			multiple = multiple or touches.size() > 1
		elif touches.has(event.index):
			var tapped: bool = not event.canceled and not moved and not multiple and event.position.distance_to(origins[event.index]) <= TAP_SLOP
			touches.erase(event.index)
			origins.erase(event.index)
			if touches.is_empty():
				clear()
				if tapped: tap.emit(event.position)
		return true
	if event is InputEventScreenDrag:
		if not touches.has(event.index): return true
		var old_position: Vector2 = touches[event.index]
		var before: PackedVector2Array = pair() if touches.size() >= 2 else PackedVector2Array()
		touches[event.index] = event.position
		if event.position.distance_to(origins[event.index]) > TAP_SLOP: moved = true
		if touches.size() == 1:
			if moved or multiple: single_drag.emit(event.position - old_position)
		else:
			var after: PackedVector2Array = pair()
			pan.emit((after[0] + after[1] - before[0] - before[1]) / 2)
			var old_span: Vector2 = before[1] - before[0]
			var new_span: Vector2 = after[1] - after[0]
			if old_span.length() > 12 and new_span.length() > 12:
				magnify.emit(new_span.length() / old_span.length(), (after[0] + after[1]) / 2)
				rotate.emit(old_span.angle_to(new_span))
		return true
	return false
