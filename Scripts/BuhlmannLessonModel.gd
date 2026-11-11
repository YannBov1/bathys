class_name BathysBuhlmannLessonModel
extends RefCounted

const AIR := {"o2": 0.21, "n2": 0.79, "he": 0.0}

static func loaded_tissues(depth_m: float, minutes: float) -> BathysTissue:
	var model := BathysTissue.new(1.0)
	# An instantaneous pressure step isolates constant-pressure gas exchange.
	model.ambient_bar = BathysLessonDiagram.pressure_at(depth_m)
	model.advance(model.ambient_bar, minutes * 60.0, AIR)
	return model

static func snapshot(depth_m: float, minutes: float, test_depth_m: float,
		wait_minutes: float, low: float, high: float, ascent: bool) -> Dictionary:
	var loaded: BathysTissue = loaded_tissues(depth_m, minutes)
	var low_ceiling: float = maxf(0, (loaded.ceiling(low)[0] - 1.0) * 10)
	# This frozen-tissue anchor is a teaching example, not a computed first stop.
	var anchor: float = ceilf(low_ceiling / 3.0) * 3.0 if low_ceiling > 1e-8 else 0.0
	var model: BathysTissue = loaded.clone()
	if ascent:
		model.ambient_bar = BathysLessonDiagram.pressure_at(test_depth_m)
		model.advance(model.ambient_bar, wait_minutes * 60.0, AIR)
	var gf: float = BathysDeco.gf_at(test_depth_m, anchor, low, high) if ascent else low
	var ceiling: PackedFloat64Array = model.ceiling(gf)
	var ceiling_m: float = maxf(0, (ceiling[0] - 1.0) * 10)
	return {"model": model, "loaded": loaded, "anchor_m": anchor, "gf": gf,
		"ceiling_m": ceiling_m, "controller": int(ceiling[1]) if ceiling_m > 1e-8 else 0,
		"inspired": (model.ambient_bar - BathysPhysics.WATER_VAPOUR_BAR) * 0.79}

# Sample the defined pressure-step profile without changing its exposure/wait lengths.
static func at_time(depth_m: float, minutes: float, test_depth_m: float,
		wait_minutes: float, low: float, high: float, ascent: bool, cursor_minutes: float) -> Dictionary:
	var total: float = minutes + (wait_minutes if ascent else 0)
	var elapsed: float = clampf(cursor_minutes, 0, total)
	var waiting: bool = ascent and elapsed >= minutes
	var exposure_elapsed: float = minf(elapsed, minutes)
	var wait_elapsed: float = maxf(0, elapsed - minutes) if waiting else 0
	var sampled: Dictionary = snapshot(depth_m, exposure_elapsed, test_depth_m, wait_elapsed, low, high, waiting)
	sampled["ascent_phase"] = waiting
	sampled["depth_m"] = test_depth_m if waiting else depth_m
	sampled["exposure_elapsed"] = exposure_elapsed
	sampled["wait_elapsed"] = wait_elapsed
	sampled["cursor_min"] = elapsed
	return sampled
