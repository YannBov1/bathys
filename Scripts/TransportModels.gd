class_name BathysTransportModels
extends RefCounted

const R: float = 8.314462618
const SIGMA: float = 5.670374419e-8
const MASS := [0.0319988, 0.0280134, 0.004002602]
const MU300 := [20.7e-6, 17.8e-6, 19.9e-6]
const SUTHERLAND := [139.0, 107.0, 79.4]

static func gas(temperature: float, oxygen: float = 21, helium: float = 0, pressure: float = 1) -> Dictionary:
	var t: float = temperature + 273.15
	var x: Array[float] = [oxygen / 100, maxf(0, 100 - oxygen - helium) / 100, helium / 100]
	var mu: Array[float] = []
	var k: Array[float] = []
	var molar_mass: float = 0
	var cp_molar: float = 0
	for i: int in 3:
		mu.append(MU300[i] * pow(t / 300, 1.5) * (300 + SUTHERLAND[i]) / (t + SUTHERLAND[i]))
		var cp: float = (2.5 if i == 2 else 3.5) * R
		# Classical Eucken: translational plus rotational energy transport.
		k.append(mu[i] * (cp + 1.25 * R) / MASS[i])
		molar_mass += x[i] * MASS[i]
		cp_molar += x[i] * cp
	var mixed_mu: float = 0
	var mixed_k: float = 0
	for i: int in 3:
		var denominator: float = 0
		for j: int in 3:
			var phi: float = pow(1 + sqrt(mu[i] / mu[j]) * pow(MASS[j] / MASS[i], 0.25), 2) / sqrt(8 * (1 + MASS[i] / MASS[j]))
			denominator += x[j] * phi
		mixed_mu += x[i] * mu[i] / denominator
		mixed_k += x[i] * k[i] / denominator
	return {"mu": mixed_mu, "k": mixed_k, "cp": cp_molar / molar_mass,
		"rho": pressure * 100000 * molar_mass / (R * t), "cp_molar": cp_molar, "molar_mass": molar_mass}

static func water(temperature: float) -> Dictionary:
	var relative: float = (temperature + 273.15) / 300
	# IAPWS supplementary liquid-water correlation at 0.1 MPa.
	var mu: float = 1e-6 * (280.68 * pow(relative, -1.9) + 511.45 * pow(relative, -7.7) + 61.131 * pow(relative, -19.6) + 0.45903 * pow(relative, -40))
	return {"mu": mu, "k": 0.6, "cp": 4184.0, "rho": BathysLearningModels.water_properties(temperature, 0)["density"]}

static func fluid(params: Dictionary) -> Dictionary:
	if int(params.get("medium", 0)) == 0: return water(params.get("temperature", 20))
	var mixture: bool = int(params.get("medium", 0)) == 2
	return gas(params.get("temperature", 20), params.get("oxygen", 21) if mixture else 21, params.get("helium", 0) if mixture else 0, 1 + float(params.get("depth", 0)) / 10)

static func shear(params: Dictionary) -> Dictionary:
	var properties: Dictionary = fluid(params)
	var gap: float = float(params["gap"]) / 1000
	var stress: float = properties["mu"] * float(params["speed"]) / gap
	return {"properties": properties, "stress": stress, "force": stress * 0.02, "nu": properties["mu"] / properties["rho"]}

static func pipe(params: Dictionary) -> Dictionary:
	var properties: Dictionary = fluid(params)
	var d: float = float(params["diameter"]) / 1000
	var q: float = float(params["flow"]) / 60000
	var velocity: float = q / (PI * d * d / 4)
	var re: float = properties["rho"] * velocity * d / properties["mu"]
	var laminar: float = 64 / maxf(0.0001, re)
	# Smooth-pipe Haaland approximation, blended only for illustration in transition.
	var turbulent: float = pow(-1.8 * log(6.9 / maxf(4000, re)) / log(10), -2)
	var fraction: float = clampf((re - 2000) / 2000, 0, 1)
	var friction: float = lerpf(laminar, turbulent, fraction)
	var pressure: float = friction * float(params["length"]) / d * properties["rho"] * velocity * velocity / 2
	return {"properties": properties, "velocity": velocity, "re": re, "fraction": fraction,
		"regime": "Laminar" if re < 2000 else ("Turbulent" if re > 4000 else "Transition"), "pressure": pressure, "friction": friction}

static func heat_transfer(params: Dictionary, stage: int) -> Dictionary:
	var hot: float = float(params.get("hot", 45)) if stage == 2 else 32.0
	var cold: float = float(params.get("temperature", 10))
	var area: float = float(params.get("area", 0.02))
	var selected: Dictionary = params.duplicate()
	selected["temperature"] = (hot + cold) / 2
	selected["depth"] = 0
	var properties: Dictionary = fluid(selected)
	var q: float = 0
	var h: float = 0
	if stage == 0:
		q = properties["k"] * area * (hot - cold) / (float(params["gap"]) / 1000)
	elif stage == 1:
		var diameter: float = 0.1
		var re: float = properties["rho"] * float(params["speed"]) * diameter / properties["mu"]
		var pr: float = properties["cp"] * properties["mu"] / properties["k"]
		var nu: float = 0.3 + 0.62 * sqrt(re) * pow(pr, 1.0 / 3) / pow(1 + pow(0.4 / pr, 2.0 / 3), 0.25) * pow(1 + pow(re / 282000, 0.625), 0.8)
		h = nu * properties["k"] / diameter
		q = h * area * (hot - cold)
	else:
		q = float(params["emissivity"]) * SIGMA * area * (pow(hot + 273.15, 4) - pow(cold + 273.15, 4))
	return {"properties": properties, "heat": q, "h": h, "hot": hot}

static func material(params: Dictionary) -> Dictionary:
	match int(params.get("material", 0)):
		0: return water(20)
		1: return {"k": 237.0, "cp": 900.0, "rho": 2700.0}
		2: return {"k": 401.0, "cp": 385.0, "rho": 8960.0}
	return gas(20, params.get("oxygen", 21), params.get("helium", 0))

static func thermal_properties(params: Dictionary, stage: int) -> Dictionary:
	var properties: Dictionary = material(params)
	var mass: float = 0.05 if int(params["basis"]) == 0 else properties["rho"] * 0.00005
	var capacity: float = mass * properties["cp"]
	return {"properties": properties, "mass": mass, "capacity": capacity,
		"rise": float(params["energy"]) / capacity,
		"heat": properties["k"] * 0.02 * 20 / (float(params["gap"]) / 1000),
		"diffusivity": properties["k"] / (properties["rho"] * properties["cp"])}

static func sound_speed(temperature: float, salinity: float, depth_m: float) -> float:
	# Coppens (1981), NPL: T/10 and depth in kilometres.
	var t: float = temperature / 10
	var d: float = depth_m / 1000
	var s: float = salinity - 35
	return 1449.05 + 45.7 * t - 5.21 * t * t + 0.23 * t * t * t + (1.333 - 0.126 * t + 0.009 * t * t) * s + (16.23 + 0.253 * t) * d + (0.213 - 0.1 * t) * d * d + (0.016 + 0.0002 * s) * s * t * d

static func absorption(frequency_khz: float, temperature: float = 20, depth_m: float = 10) -> float:
	# Ainslie–McColm; fixed S=35 and pH=8, depth in kilometres.
	var f2: float = frequency_khz * frequency_khz
	var boric: float = 0.78 * exp(temperature / 26)
	var magnesium: float = 42 * exp(temperature / 17)
	var d: float = depth_m / 1000
	return 0.106 * boric * f2 / (boric * boric + f2) + 0.52 * (1 + temperature / 43) * exp(-d / 6) * magnesium * f2 / (magnesium * magnesium + f2) + 0.00049 * exp(-temperature / 27 - d / 17) * f2

static func sound(params: Dictionary, stage: int) -> Dictionary:
	var temperature: float = params["temperature"]
	var c: float = sound_speed(temperature, params["salinity"], params["depth"] if stage == 0 else 0)
	var air: Dictionary = gas(temperature)
	var air_c: float = sqrt(1.4 * R * (temperature + 273.15) / air["molar_mass"])
	var rho: float = BathysLearningModels.water_properties(temperature, params["salinity"])["density"]
	var z: float = rho * c
	var other: float = air["rho"] * air_c if int(params["boundary"]) == 0 else (z if int(params["boundary"]) == 1 else 7850 * 5900.0)
	var reflection: float = pow((other - z) / (other + z), 2)
	var range_m: float = params["range"]
	var alpha: float = absorption(params["frequency"], temperature)
	var spread: float = 20 * log(maxf(1, range_m)) / log(10)
	var bearing: float = deg_to_rad(params["bearing"])
	var source := Vector2(sin(bearing), -cos(bearing)) * range_m
	var delay_distance: float = source.distance_to(Vector2(-0.09, 0)) - source.distance_to(Vector2(0.09, 0))
	return {"c": c, "air_c": air_c, "z": z, "z2": other, "reflection": reflection, "transmission": 1 - reflection,
		"water_ms": range_m / c * 1000, "air_ms": range_m / air_c * 1000,
		"alpha": alpha, "spread": spread, "absorption": alpha * maxf(0, range_m - 1) / 1000,
		"loss": spread + alpha * maxf(0, range_m - 1) / 1000,
		"delay_water": delay_distance / c * 1e6, "delay_air": delay_distance / air_c * 1e6}
