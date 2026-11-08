class_name BathysDeco
extends RefCounted

static func gf_at(depth: float, first: float, low: float, high: float) -> float:
	return high if first <= 0.0 else high + clampf(depth / first, 0.0, 1.0) * (low - high)

static func ascent_clear(from: BathysTissue, env: Dictionary, gas: Dictionary, start_m: float,
		target_m: float, gf: float, rate: float, first_stop_m: float = -1.0, gf_low: float = 0.0) -> Dictionary:
	var result: BathysTissue = from.clone()
	var duration: float = (start_m - target_m) / rate * 60.0
	if duration <= 0.0:
		var chosen_gf: float = gf_at(start_m, first_stop_m, gf_low, gf) if first_stop_m >= 0.0 else gf
		return {"clear": result.ceiling(chosen_gf)[0] <= result.ambient_bar + 1e-9, "model": result}
	var steps: int = ceili(duration / 5.0)
	for k: int in range(1, steps + 1):
		var elapsed: float = minf(duration, k * 5.0)
		var previous: float = minf(duration, (k - 1) * 5.0)
		var depth: float = clampf(start_m + (target_m - start_m) * elapsed / duration, 0.0, maxf(start_m, target_m))
		result.advance(BathysPhysics.ambient_bar(env, depth), elapsed - previous, gas)
		var current_gf: float = gf_at(depth, first_stop_m, gf_low, gf) if first_stop_m >= 0.0 else gf
		if result.ceiling(current_gf)[0] > result.ambient_bar + 1e-9:
			return {"clear": false, "model": result}
	return {"clear": true, "model": result}

static func calculate(live: BathysTissue, env: Dictionary, gas: Dictionary,
		gf_low: float, gf_high: float, ascent_rate: float) -> Dictionary:
	var current: float = BathysPhysics.depth_at_bar(env, live.ambient_bar)
	if current < 0.01:
		return {"ndlS": null, "ttsS": 0.0, "firstStopM": null, "currentGf": gf_high}
	var ndl: Variant = null
	if live.ceiling(gf_high)[0] > BathysPhysics.surface_bar(env) + 1e-9:
		ndl = 0.0
	else:
		var lo: float = 0.0
		var hi: float = 5940.0
		var trial: BathysTissue = live.clone()
		trial.advance(trial.ambient_bar, hi, gas)
		if trial.ceiling(gf_high)[0] > BathysPhysics.surface_bar(env) + 1e-9:
			for i: int in 7:
				var mid: float = (lo + hi) / 2.0
				trial = live.clone()
				trial.advance(trial.ambient_bar, mid, gas)
				if trial.ceiling(gf_high)[0] <= BathysPhysics.surface_bar(env) + 1e-9:
					lo = mid
				else:
					hi = mid
			ndl = floorf(lo / 60.0) * 60.0
	var direct: Dictionary = ascent_clear(live, env, gas, current, 0.0, gf_high, ascent_rate)
	if bool(direct["clear"]) and ndl != 0.0:
		return {"ndlS": ndl, "ttsS": current / ascent_rate * 60.0, "firstStopM": null, "currentGf": gf_high}
	var stop: float = minf(current, maxf(3.0, ceilf(BathysPhysics.depth_at_bar(env, live.ceiling(gf_low)[0]) / 3.0) * 3.0))
	var work: BathysTissue = live.clone()
	while stop < current - 0.001:
		var check: Dictionary = ascent_clear(live, env, gas, current, stop, gf_low, ascent_rate)
		work = check["model"] as BathysTissue
		if bool(check["clear"]):
			break
		stop = minf(current, stop + 3.0)
	if stop >= current - 0.001:
		work = live.clone()
	var first: float = stop
	var tts: float = (current - stop) / ascent_rate * 60.0
	var stop_count: int = 0
	while stop > 0.001 and stop_count < 60:
		var next: float = maxf(0.0, ceilf(stop / 3.0 - 1e-9) * 3.0 - 3.0)
		if next >= stop:
			next = 0.0
		var holds: int = 0
		var next_model: BathysTissue = work
		while true:
			var check: Dictionary = ascent_clear(work, env, gas, stop, next, gf_high, ascent_rate, first, gf_low)
			next_model = check["model"] as BathysTissue
			if bool(check["clear"]):
				break
			work.advance(work.ambient_bar, 60.0, gas)
			tts += 60.0
			holds += 1
			if holds > 2880:
				return {"ndlS": 0.0, "ttsS": null, "firstStopM": first, "currentGf": gf_at(current, first, gf_low, gf_high)}
		work = next_model
		tts += (stop - next) / ascent_rate * 60.0
		stop = next
		stop_count += 1
	return {"ndlS": 0.0, "ttsS": tts, "firstStopM": first, "currentGf": gf_at(current, first, gf_low, gf_high)}
