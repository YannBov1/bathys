class_name BathysLearningModels
extends RefCounted

static func partial_pressures(depth_m: float, oxygen_percent: float, helium_percent: float) -> Dictionary:
	var oxygen: float = clampf(oxygen_percent / 100.0, 0, 1)
	var helium: float = clampf(helium_percent / 100.0, 0, 1 - oxygen)
	var nitrogen: float = maxf(0, 1 - oxygen - helium)
	var total: float = BathysLessonDiagram.pressure_at(depth_m)
	return {"total": total, "o2": oxygen * total, "n2": nitrogen * total, "he": helium * total}

static func equilibrium(pressure_bar: float) -> float:
	# Normalised example: k = 1 reference concentration per bar, at fixed temperature.
	return maxf(0, pressure_bar)

static func dissolved(pressure_bar: float, half_times: float) -> float:
	# Separate illustrative exchange model; Henry's law alone supplies no time scale.
	var target: float = equilibrium(pressure_bar)
	return target + (1.0 - target) * pow(0.5, maxf(0, half_times))

static func water_properties(temperature_c: float, salinity: float) -> Dictionary:
	# Reuse the app's EOS-80 surface-density approximation. Its salinity entry
	# approximates practical salinity as g/kg; this is not TEOS-10 Absolute Salinity.
	var env: Dictionary = {"surfaceTempC": temperature_c, "minTempC": temperature_c,
		"tempDropCPerM": 0.0, "salinityGPerKg": salinity}
	var density: float = BathysPhysics.water_density(env, 0)
	return {"density": density, "metres_per_bar": 100000.0 / (density * BathysPhysics.G),
		"pressure_at_10m": density * BathysPhysics.G * 10.0 / 100000.0}
