class_name BathysTissue
extends RefCounted

const N_HALF := [4.0, 8.0, 12.5, 18.5, 27.0, 38.3, 54.3, 77.0, 109.0, 146.0, 187.0, 239.0, 305.0, 390.0, 498.0, 635.0]
const N_A := [1.2599, 1.0, 0.8618, 0.7562, 0.6200, 0.5043, 0.4410, 0.4000, 0.3750, 0.3500, 0.3295, 0.3065, 0.2835, 0.2610, 0.2480, 0.2327]
const N_B := [0.5050, 0.6514, 0.7222, 0.7825, 0.8126, 0.8434, 0.8693, 0.8910, 0.9092, 0.9222, 0.9319, 0.9403, 0.9477, 0.9544, 0.9602, 0.9653]
const H_HALF := [1.51, 3.02, 4.72, 6.99, 10.21, 14.48, 20.53, 29.11, 41.20, 55.19, 70.69, 90.34, 115.29, 147.42, 188.24, 240.03]
const H_A := [1.7424, 1.3830, 1.1919, 1.0458, 0.9220, 0.8205, 0.7305, 0.6502, 0.5950, 0.5545, 0.5333, 0.5189, 0.5181, 0.5176, 0.5172, 0.5119]
const H_B := [0.4245, 0.5747, 0.6527, 0.7223, 0.7582, 0.7957, 0.8279, 0.8553, 0.8757, 0.8903, 0.8997, 0.9073, 0.9122, 0.9171, 0.9217, 0.9267]

var n2: PackedFloat64Array = PackedFloat64Array()
var he: PackedFloat64Array = PackedFloat64Array()
var ambient_bar: float = 1.0
var surface_bar: float = 1.0

func _init(surface: float = 1.0) -> void:
	surface_bar = surface
	ambient_bar = surface
	n2.resize(16)
	he.resize(16)
	for i: int in 16:
		n2[i] = (surface - 0.0627) * 0.79

func clone() -> BathysTissue:
	var result := BathysTissue.new(surface_bar)
	result.n2 = n2.duplicate()
	result.he = he.duplicate()
	result.ambient_bar = ambient_bar
	return result

static func schreiner(pressure: float, inspired: float, rate: float, half_seconds: float, dt: float) -> float:
	var k: float = log(2.0) / half_seconds
	return inspired + rate * (dt - 1.0 / k) + (pressure - inspired + rate / k) * exp(-k * dt)

func advance(new_ambient: float, dt: float, gas: Dictionary) -> void:
	if dt <= 0.0:
		return
	var rate: float = (new_ambient - ambient_bar) / dt
	var n_fraction: float = float(gas.get("n2", 0.79))
	var h_fraction: float = float(gas.get("he", 0.0))
	for i: int in 16:
		n2[i] = schreiner(n2[i], (ambient_bar - 0.0627) * n_fraction, rate * n_fraction, N_HALF[i] * 60.0, dt)
		he[i] = schreiner(he[i], (ambient_bar - 0.0627) * h_fraction, rate * h_fraction, H_HALF[i] * 60.0, dt)
	ambient_bar = new_ambient

static func coefficients(index: int, n: float, h: float) -> PackedFloat64Array:
	var total: float = n + h
	if total <= 0.0:
		return PackedFloat64Array([N_A[index], N_B[index]])
	return PackedFloat64Array([(N_A[index] * n + H_A[index] * h) / total,
		(N_B[index] * n + H_B[index] * h) / total])

func ceiling(gf: float) -> PackedFloat64Array:
	var maximum: float = -INF
	var control: int = 0
	for i: int in 16:
		var total: float = n2[i] + he[i]
		var ab: PackedFloat64Array = coefficients(i, n2[i], he[i])
		var candidate: float = (total - gf * ab[0]) / (1.0 + gf * (1.0 / ab[1] - 1.0))
		if candidate > maximum:
			maximum = candidate
			control = i + 1
	return PackedFloat64Array([maxf(surface_bar, maximum), float(control)])

func leading_gf() -> float:
	var maximum: float = -INF
	for i: int in 16:
		var ab: PackedFloat64Array = coefficients(i, n2[i], he[i])
		maximum = maxf(maximum, (n2[i] + he[i] - ambient_bar) / (ab[0] + ambient_bar * (1.0 / ab[1] - 1.0)))
	return maximum

static func allowed_inert(index: int, n: float, h: float, ambient: float, gf: float) -> float:
	var ab: PackedFloat64Array = coefficients(index, n, h)
	return ambient + gf * (ab[0] + ambient * (1.0 / ab[1] - 1.0))
