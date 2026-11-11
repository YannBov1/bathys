class_name BathysThermalModels
extends RefCounted

const R: float = BathysPhysics.R
const GAS_NAMES := ["Air · dry 21/79", "Nitrogen · N₂", "Helium · He"]
# Same dry species, critical constants, acentric factors and zero-kij mixing as Physics.gd.
const TC := [154.5994, 126.192, 5.1953]
const PC := [5046410.5, 3395800.4, 228322.8]
const OMEGA := [0.0222, 0.0372, -0.38354]

static func fractions(gas: int) -> Array:
	return [[0.21, 0.79, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]][clampi(gas, 0, 2)]

static func cp_ideal(gas: int) -> float:
	return R * (2.5 if gas == 2 else 3.5)

static func charles(celsius: float) -> Dictionary:
	var kelvin: float = celsius + 273.15
	return {"kelvin": kelvin, "volume": kelvin / 293.15, "ratio": kelvin / 293.15,
		"speed": sqrt(kelvin / 293.15), "moles": 100 / (R * 293.15)}

static func ideal(p: Dictionary) -> Dictionary:
	var kelvin: float = float(p["temperature"]) + 273.15
	var n: float = p["amount"]
	var pressure: float = p["pressure"]
	var volume: float = p["volume"]
	if int(p["solve"]) == 0: pressure = n * R * kelvin / (100 * volume)
	else: volume = n * R * kelvin / (100 * pressure)
	return {"kelvin": kelvin, "pressure": pressure, "volume": volume, "moles": n,
		"pv": pressure * volume * 100, "nrt": n * R * kelvin}

static func parameters(gas: int, kelvin: float) -> Array[float]:
	var x: Array = fractions(gas)
	var root: float = 0
	var derivative: float = 0
	var b: float = 0
	for i: int in 3:
		var k: float = 0.37464 + 1.54226 * OMEGA[i] - 0.26992 * OMEGA[i] * OMEGA[i]
		var a0: float = 0.45724 * pow(R * TC[i], 2) / PC[i]
		var q: float = 1 + k * (1 - sqrt(kelvin / TC[i]))
		root += float(x[i]) * sqrt(a0) * q
		derivative += float(x[i]) * sqrt(a0) * (-k / (2 * sqrt(kelvin * TC[i])))
		b += float(x[i]) * 0.07780 * R * TC[i] / PC[i]
	return [root * root, b, 2 * root * derivative]

static func real(gas: int, pressure_bar: float, kelvin: float) -> Dictionary:
	var p: float = pressure_bar * 100000
	var terms: Array[float] = parameters(gas, kelvin)
	var a: float = terms[0]
	var b: float = terms[1]
	var aa: float = a * p / pow(R * kelvin, 2)
	var bb: float = b * p / (R * kelvin)
	# In the supported single-phase domain (T >= 180 K), all species are supercritical.
	# The unique physical root lies between B and 1+B; attraction lowers it from 1+B.
	var lo: float = bb
	var hi: float = 1 + bb
	for i: int in 42:
		var z: float = (lo + hi) / 2
		var f: float = z * z * z - (1 - bb) * z * z + (aa - 3 * bb * bb - 2 * bb) * z - (aa * bb - bb * bb - bb * bb * bb)
		if f < 0: lo = z
		else: hi = z
	var z: float = (lo + hi) / 2
	var ideal_volume: float = R * kelvin / p
	var volume: float = z * ideal_volume
	var log_term: float = log((z + (1 + sqrt(2)) * bb) / (z + (1 - sqrt(2)) * bb))
	var departure: float = R * kelvin * (z - 1) + (kelvin * terms[2] - a) / (2 * sqrt(2) * b) * log_term
	return {"z": z, "molar_l": volume * 1000, "ideal_l": ideal_volume * 1000,
		"moles_12l": 0.012 / volume, "ideal_moles_12l": 0.012 / ideal_volume,
		"h": cp_ideal(gas) * (kelvin - 293.15) + departure, "h_departure": departure}

static func throttle_temperature(gas: int, pin: float, pout: float, tin: float) -> float:
	if absf(pin - pout) < 1e-10: return tin
	var target: float = real(gas, pin, tin)["h"]
	var lo: float = 180
	var hi: float = 450
	if target < float(real(gas, pout, lo)["h"]) or target > float(real(gas, pout, hi)["h"]): return NAN
	for i: int in 33:
		var mid: float = (lo + hi) / 2
		if float(real(gas, pout, mid)["h"]) < target: lo = mid
		else: hi = mid
	return (lo + hi) / 2

static func mu_jt(gas: int, pressure: float, kelvin: float) -> float:
	var ht: float = (float(real(gas, pressure, kelvin + 0.02)["h"]) - float(real(gas, pressure, kelvin - 0.02)["h"])) / 0.04
	var hp: float = (float(real(gas, pressure + 0.001, kelvin)["h"]) - float(real(gas, pressure - 0.001, kelvin)["h"])) / 0.002
	return -hp / ht

static func cooling(gas: int, pin: float, pout: float, tin: float, process: int) -> Dictionary:
	pout = clampf(pout, 1, pin)
	var cp: float = cp_ideal(gas)
	var gamma: float = cp / (cp - R)
	var tout: float = tin
	if process == 0: tout = throttle_temperature(gas, pin, pout, tin)
	elif process == 2: tout = tin * pow(pout / pin, (gamma - 1) / gamma)
	return {"tin": tin, "tout": tout, "delta": tout - tin, "pin": pin, "pout": pout,
		"mu": mu_jt(gas, pin, tin) if process == 0 else 0.0,
		"work": cp * (tin - tout) if process == 2 else 0.0,
		"h_error": float(real(gas, pout, tout)["h"]) - float(real(gas, pin, tin)["h"]) if process == 0 and is_finite(tout) else 0.0}
