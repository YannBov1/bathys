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

static func cylinder_buoyancy_preset(index: int) -> Dictionary:
	return cylinder_buoyancy_state(index < 2, 200.0 if index % 2 == 0 else 50.0)

static func cylinder_buoyancy_state(steel: bool, gauge_bar: float) -> Dictionary:
	# Body masses: Faber 232 bar / 171 mm (2023), Luxfer P3080V (2022).
	var pressure: float = clampf(gauge_bar, 0, 200)
	var bare_mass: float = 13.3 if steel else 16.5
	var metal_density: float = 7.85 if steel else 2.70 # kg/L
	var valve_mass: float = 0.6
	var valve_l: float = valve_mass / 8.4
	var external_l: float = 12 + bare_mass / metal_density + valve_l
	var gas_mass: float = BathysPhysics.gas_density({"o2": 0.21, "n2": 0.79, "he": 0.0}, pressure + 1, 20) * 0.012
	return {"mass": bare_mass + valve_mass + gas_mass, "volume": external_l,
		"gas_mass": gas_mass, "bare_mass": bare_mass, "valve_mass": valve_mass, "valve_l": valve_l,
		"tare": bare_mass + valve_mass, "pressure": pressure, "steel": steel,
		"length": 0.65 if steel else 0.612}

static func cylinder_trim(cylinder: Dictionary, water_density: float) -> Dictionary:
	# Axial positions relative to the body neck. Uniform body/gas assumptions,
	# not measured centres of a particular cylinder or a calibrated harness.
	var body_x: float = float(cylinder["length"]) / 2
	var valve_x: float = -0.03
	var pivot_x: float = 0.07
	var volume: float = cylinder["volume"]
	var mass: float = cylinder["mass"]
	var cm: float = ((mass - float(cylinder["valve_mass"])) * body_x + float(cylinder["valve_mass"]) * valve_x) / mass
	var cb: float = ((volume - float(cylinder["valve_l"])) * body_x + float(cylinder["valve_l"]) * valve_x) / volume
	var force: Dictionary = buoyancy(mass, volume, 100, water_density)
	var moment: float = float(force["buoyant_force"]) * (cb - pivot_x) - float(force["weight"]) * (cm - pivot_x)
	# Weak elastic support gives finite illustrative attitudes. This is not a
	# prediction of rigging angles: tau(theta) = tau0 cos(theta) - k sin(theta).
	var stiffness: float = 3.0 # N m
	return {"cm": cm, "cb": cb, "pivot": pivot_x, "moment": moment,
		"stiffness": stiffness, "angle_deg": rad_to_deg(atan2(moment, stiffness)),
		"net_force": force["net_force"]}

static func buoyancy_at_depth(mass_kg: float, rigid_volume_l: float, surface_gas_l: float, depth_m: float, density: float) -> Dictionary:
	var pressure: float = 1.0 + density * BathysPhysics.G * depth_m / 100000
	var gas_volume: float = surface_gas_l / pressure
	var result: Dictionary = buoyancy(mass_kg, rigid_volume_l + gas_volume, 100, density)
	result["gas_volume_l"] = gas_volume
	result["pressure_bar"] = pressure
	return result
