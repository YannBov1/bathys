class_name BathysPhysics
extends RefCounted

const R := 8.314462618
const G := 9.80665
const WATER_VAPOUR_BAR := 0.0627
const HALF_LIFE_S := 5400.0
const CNS_LIMITS := [
	[0.6, 43200.0], [0.7, 34200.0], [0.8, 27000.0],
	[0.9, 21600.0], [1.0, 18000.0], [1.1, 14400.0],
	[1.2, 12600.0], [1.3, 10800.0], [1.4, 9000.0],
	[1.5, 7200.0], [1.6, 2700.0], [1.65, 400.0]]

static func surface_bar(env: Dictionary) -> float:
	return 1.01325 * pow(1.0 - 2.25577e-5 * float(env.get("waterlineAltitudeNf02M", 478.5)), 5.25588)

static func water_temp(env: Dictionary, depth: float) -> float:
	return maxf(float(env.get("minTempC", 5.0)), float(env.get("surfaceTempC", 18.0)) - depth * float(env.get("tempDropCPerM", 0.2)))

static func water_density(env: Dictionary, depth: float) -> float:
	var t: float = water_temp(env, depth)
	var s: float = float(env.get("salinityGPerKg", 0.0))
	var pure: float = 999.842594 + 6.793952e-2 * t - 9.095290e-3 * t * t + 1.001685e-4 * pow(t, 3) - 1.120083e-6 * pow(t, 4) + 6.536332e-9 * pow(t, 5)
	var b: float = 0.824493 - 4.0899e-3 * t + 7.6438e-5 * t * t - 8.2467e-7 * pow(t, 3) + 5.3875e-9 * pow(t, 4)
	var c: float = -5.72466e-3 + 1.0227e-4 * t - 1.6546e-6 * t * t
	return pure + b * s + c * pow(s, 1.5) + 4.8314e-4 * s * s

static func ambient_bar(env: Dictionary, depth: float) -> float:
	var p: float = surface_bar(env)
	var count: int = ceili(maxf(0.0, depth))
	for i: int in count:
		var h: float = minf(1.0, depth - i)
		p += water_density(env, i + h / 2.0) * G * h / 100000.0
	return p

static func depth_at_bar(env: Dictionary, pressure: float) -> float:
	if pressure <= surface_bar(env):
		return 0.0
	var lo: float = 0.0
	var hi: float = 150.0
	for i: int in 28:
		var mid: float = (lo + hi) / 2.0
		if ambient_bar(env, mid) < pressure:
			lo = mid
		else:
			hi = mid
	return (lo + hi) / 2.0

static func molar_mass(gas: Dictionary) -> float:
	return float(gas.get("o2", 0.21)) * 31.9988 + float(gas.get("n2", 0.79)) * 28.0134 + float(gas.get("he", 0.0)) * 4.002602

static func gas_pressure_at_volume(volume: float, kelvin: float, a: float, b: float) -> float:
	return R * kelvin / (volume - b) - a / (volume * volume + 2.0 * volume * b - b * b)

static func gas_density(gas: Dictionary, pressure_bar: float, temperature_c: float) -> float:
	if pressure_bar <= 0.0:
		return 0.0
	var fractions: Array[float] = [float(gas.get("o2", 0.21)), float(gas.get("n2", 0.79)), float(gas.get("he", 0.0))]
	var critical_t: Array[float] = [154.5994, 126.192, 5.1953]
	var critical_p: Array[float] = [5046410.5, 3395800.4, 228322.8]
	var omega: Array[float] = [0.0222, 0.0372, -0.38354]
	var kelvin: float = temperature_c + 273.15
	var p: float = pressure_bar * 100000.0
	var root_a: float = 0.0
	var b: float = 0.0
	for i: int in 3:
		if fractions[i] <= 0.0:
			continue
		var kappa: float = 0.37464 + 1.54226 * omega[i] - 0.26992 * omega[i] * omega[i]
		var ai: float = 0.45724 * pow(R * critical_t[i], 2) / critical_p[i] * pow(1.0 + kappa * (1.0 - sqrt(kelvin / critical_t[i])), 2)
		var bi: float = 0.07780 * R * critical_t[i] / critical_p[i]
		root_a += fractions[i] * sqrt(ai)
		b += fractions[i] * bi
	var a: float = root_a * root_a
	var low: float = b * (1.0 + 1e-10)
	var high: float = maxf(2.0 * R * kelvin / p, 2.0 * b)
	for i: int in 100:
		if gas_pressure_at_volume(high, kelvin, a, b) <= p:
			break
		high *= 2.0
	for i: int in 80:
		var mid: float = (low + high) / 2.0
		if gas_pressure_at_volume(mid, kelvin, a, b) > p:
			low = mid
		else:
			high = mid
	var volume: float = (low + high) / 2.0
	var z: float = p * volume / (R * kelvin)
	return p * molar_mass(gas) / 1000.0 / (R * kelvin * z)

static func end_m(gas: Dictionary, ambient: float) -> float:
	return maxf(0.0, (ambient * (float(gas.get("o2", 0.21)) + float(gas.get("n2", 0.79))) - 1.0) * 10.0)

static func cns_rate(pp_o2: float) -> float:
	if pp_o2 <= 0.5:
		return 0.0
	if pp_o2 >= 1.65:
		return 0.25
	if pp_o2 < 0.6:
		return (pp_o2 - 0.5) / 0.1 * 100.0 / 43200.0
	for i: int in CNS_LIMITS.size() - 1:
		if pp_o2 <= CNS_LIMITS[i + 1][0]:
			var f: float = (pp_o2 - CNS_LIMITS[i][0]) / (CNS_LIMITS[i + 1][0] - CNS_LIMITS[i][0])
			return 100.0 / (CNS_LIMITS[i][1] + f * (CNS_LIMITS[i + 1][1] - CNS_LIMITS[i][1]))
	return 0.25

static func otu_rate(pp_o2: float) -> float:
	var ata: float = pp_o2 / 1.01325
	return 0.0 if ata <= 0.5 else pow((ata - 0.5) / 0.5, 5.0 / 6.0) / 60.0

static func consume_tank(tank: Dictionary, absolute_bar: float, surface_l: float, ambient: float, surface: float, temperature: float) -> float:
	var volume: float = float(tank.get("volumeL", 12.0))
	var remaining: float = gas_density(tank, absolute_bar, temperature) * volume - gas_density(tank, surface, temperature) * surface_l
	var minimum: float = maxf(ambient, float(tank.get("reserveGaugeBar", 50.0)) + surface)
	if remaining < gas_density(tank, minimum, temperature) * volume - 1e-8:
		return NAN
	var lo: float = minimum
	var hi: float = absolute_bar
	for i: int in 38:
		var mid: float = (lo + hi) / 2.0
		if gas_density(tank, mid, temperature) * volume < remaining:
			lo = mid
		else:
			hi = mid
	return (lo + hi) / 2.0
