class_name BathysExchangeModels
extends RefCounted

static func exchange(p: Dictionary, elapsed: float = -1.0) -> Dictionary:
	# Reference conductance: 1/60 amount units per mmHg per reference interval.
	# Receiver storage: C_rel/60 amount units per mmHg. Neither is a human calibration.
	var conductance: float = float(p["area"]) * float(p["permeability"]) / float(p["thickness"])
	var capacity: float = p["capacity"]
	var time: float = float(p["time"]) if elapsed < 0 else elapsed
	var source: float = p["source"]
	var initial: float = p["initial"]
	var rate: float = conductance / capacity
	var receiver: float = source + (initial - source) * exp(-rate * time)
	var gradient: float = source - receiver
	return {"conductance": conductance, "receiver": receiver, "gradient": gradient,
		"flux": conductance * gradient / 60, "initial_flux": conductance * (source - initial) / 60,
		"transferred": capacity * (receiver - initial) / 60,
		"half_time": log(2) / rate, "fraction": 1 - exp(-rate * time), "rate": rate}
