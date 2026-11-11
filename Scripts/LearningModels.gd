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


static func lesson_gas(oxygen_percent: float, helium_percent: float) -> Dictionary:
	var oxygen: float = clampf(oxygen_percent / 100.0, 0, 1)
	var helium: float = clampf(helium_percent / 100.0, 0, 1 - oxygen)
	return {"o2": oxygen, "he": helium, "n2": maxf(0, 1 - oxygen - helium)}

static func oxygen_exposure(depth: float, oxygen_percent: float, minutes: float) -> Dictionary:
	var pressure: float = BathysLessonDiagram.pressure_at(depth) * oxygen_percent / 100
	# Do not extend the app's historical NOAA-style table past its last tabulated row.
	var in_table: bool = pressure <= 1.6 + 1e-9
	var rate: float = BathysPhysics.cns_rate(minf(pressure, 1.6)) if in_table else 0.0
	return {"pp_o2": pressure, "cns_valid": in_table,
		"cns": rate * minutes * 60 if in_table else null,
		"allocation_min": 100 / rate / 60 if rate > 0 else null,
		"otu": BathysPhysics.otu_rate(pressure) * minutes * 60}

static func narcosis_comparison(depth: float, oxygen_percent: float, helium_percent: float, oxygen_narcotic: bool) -> Dictionary:
	var gas: Dictionary = lesson_gas(oxygen_percent, helium_percent)
	var ambient: float = BathysLessonDiagram.pressure_at(depth)
	var fraction: float = gas["n2"] + (float(gas["o2"]) if oxygen_narcotic else 0.0)
	var air_fraction: float = 1.0 if oxygen_narcotic else 0.79
	var equivalent: float = (ambient * fraction / air_fraction - 1) * 10
	return {"pp_n2": ambient * float(gas["n2"]), "fraction": fraction,
		"end_m": maxf(0, equivalent), "below_surface": equivalent < -1e-8,
		"narcotic_pressure": ambient * fraction, "air_fraction": air_fraction}

static func breathing_density(depth: float, oxygen_percent: float, helium_percent: float, temperature: float) -> Dictionary:
	var gas: Dictionary = lesson_gas(oxygen_percent, helium_percent)
	var ambient: float = BathysLessonDiagram.pressure_at(depth)
	var density: float = BathysPhysics.gas_density(gas, ambient, temperature)
	var air: float = BathysPhysics.gas_density({"o2": 0.21, "n2": 0.79, "he": 0.0}, ambient, temperature)
	return {"density": density, "air_density": air, "ratio": density / air, "ambient": ambient}


static func buoyancy(mass_kg: float, volume_l: float, submerged_percent: float, density: float) -> Dictionary:
	var displaced_l: float = volume_l * clampf(submerged_percent / 100, 0, 1)
	var displaced_mass: float = density * displaced_l / 1000
	var buoyant_force: float = displaced_mass * BathysPhysics.G
	var weight: float = mass_kg * BathysPhysics.G
	return {"displaced_l": displaced_l, "displaced_mass": displaced_mass,
		"buoyant_force": buoyant_force, "weight": weight, "net_force": buoyant_force - weight}

static func buoyancy_at_depth(mass_kg: float, rigid_volume_l: float, surface_gas_l: float, depth_m: float, density: float) -> Dictionary:
	var pressure: float = 1.0 + density * BathysPhysics.G * depth_m / 100000
	var gas_volume: float = surface_gas_l / pressure
	var result: Dictionary = buoyancy(mass_kg, rigid_volume_l + gas_volume, 100, density)
	result["gas_volume_l"] = gas_volume
	result["pressure_bar"] = pressure
	return result
