class_name BathysUnderwaterOptics
extends RefCounted

const WATER_KEYS := ["IB", "II", "III", "1C", "3C", "5C"]
const MATERIALS: int = 10
var data: Dictionary = {}
var wavelengths: Array = []
var daylight: Array = []
var cmf: Array = []
var normalization: float = 1.0

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://Data/Optics/water_spectra.dat")) as Dictionary
	wavelengths = data["wavelength_nm"]
	daylight = data["d65"]
	cmf = data["cmf_xyz"]
	normalization = 0
	for i: int in wavelengths.size(): normalization += float(daylight[i]) * float(cmf[i][1]) * 5 / PI

static func phase_hg(cosine: float, g: float) -> float:
	return (1 - g * g) / (4 * PI * pow(maxf(1e-12, 1 + g * g - 2 * g * clampf(cosine, -1, 1)), 1.5))

static func cone_fraction(g: float, half_angle: float) -> float:
	if absf(g) < 1e-7: return (1 - cos(half_angle)) / 2
	return clampf((1 - g * g) / (2 * g) * (1 / (1 - g) - 1 / sqrt(1 + g * g - 2 * g * cos(half_angle))), 0, 1)

static func halo_sigma_fraction(g: float, cone: float, distance: float) -> float:
	var moment: float = 0
	var probability: float = 0
	for i: int in 48:
		var angle: float = cone * (i + 0.5) / 48
		var weight: float = phase_hg(cos(angle), g) * sin(angle)
		probability += weight
		moment += angle * angle * weight
	# Uniform scattering position along the path; a two-metre-wide synthetic plane.
	return distance * sqrt(moment / maxf(probability, 1e-30) / 6) / 2

static func reflectance(material: int, wavelength: float) -> float:
	match material:
		0: return 0.09
		1: return 0.75
		2: return 0.02 + 0.65 / (1 + exp(-(wavelength - 590) / 12))
		3: return 0.02 + 0.68 / (1 + exp(-(wavelength - 550) / 10))
		4: return 0.02 + 0.7 / (1 + exp(-(wavelength - 505) / 10))
		5: return 0.02 + 0.62 * exp(-0.5 * pow((wavelength - 535) / 30, 2))
		6: return 0.02 + 0.58 / (1 + exp(-(wavelength - 435) / 10)) / (1 + exp((wavelength - 575) / 10))
		7: return 0.02 + 0.5 * exp(-0.5 * pow((wavelength - 450) / 27, 2))
		8: return 0.004
		_: return 0.18

func xyz_weight(index: int) -> Vector3:
	var row: Array = cmf[index]
	return Vector3(row[0], row[1], row[2]) * (5 / normalization)

static func linear_rgb(xyz: Vector3) -> Vector3:
	return Vector3(3.2404542 * xyz.x - 1.5371385 * xyz.y - 0.4985314 * xyz.z,
		-0.9692660 * xyz.x + 1.8760108 * xyz.y + 0.0415560 * xyz.z,
		0.0556434 * xyz.x - 0.2040259 * xyz.y + 1.0572252 * xyz.z)

func water(parameters: Dictionary) -> Dictionary:
	return data["waters"][WATER_KEYS[int(parameters.get("water", 2))]] as Dictionary

static func path_ambient(a: float, b: float, irradiance: float, distance: float, g: float, diffuse: float) -> PackedFloat64Array:
	var c: float = a + b
	# A direct overhead component plus a uniform downwelling hemisphere.
	# Their angular weights are assumptions, not measured Jerlov phase functions.
	var source: float = b * irradiance * ((1 - diffuse) * phase_hg(0, g) + diffuse / (2 * PI))
	var infinity: float = source / c if c > 1e-12 else 0
	return PackedFloat64Array([infinity * (1 - exp(-c * distance)), infinity])

static func lamp_target(c: float, distance: float, baseline: float, power: float) -> float:
	var length: float = sqrt(distance * distance + baseline * baseline)
	return power * exp(-c * length) / maxf(0.0625, length * length) * (distance / length if length > 1e-9 else 1)

static func lamp_backscatter(a: float, b: float, distance: float, baseline: float, power: float, g: float) -> float:
	if power <= 0 or distance <= 0 or b <= 0: return 0
	var c: float = a + b
	var target_length: float = sqrt(distance * distance + baseline * baseline)
	var total: float = 0
	for step: int in 48:
		var s: float = distance * (step + 0.5) / 48
		var length: float = sqrt(s * s + baseline * baseline)
		var cosine: float = clampf((distance * s + baseline * baseline) / maxf(1e-12, target_length * length), -1, 1)
		var beam: float = exp(-0.5 * pow(acos(cosine) / deg_to_rad(15), 2))
		var phase: float = phase_hg(-s / maxf(length, 1e-12), g)
		total += power * beam / maxf(0.0625, length * length) * exp(-c * (length + s)) * b * phase
	return total * distance / 48

func evaluate(parameters: Dictionary) -> Dictionary:
	var profile: Dictionary = water(parameters)
	var depth: float = parameters.get("depth", 10.0)
	var distance: float = parameters.get("range", 3.0)
	var g: float = parameters.get("g", 0.9)
	var diffuse: float = parameters.get("diffuse", 0.7)
	var cone: float = deg_to_rad(parameters.get("cone", 3.0))
	var power: float = parameters.get("power", 8.0) if bool(parameters.get("torch", false)) else 0
	var baseline: float = parameters.get("baseline", 0.6)
	var fraction: float = cone_fraction(g, cone)
	var direct_xyz: Array[Vector3] = []
	var forward_xyz: Array[Vector3] = []
	var reference_xyz: Array[Vector3] = []
	var object_xyz: Array[Vector3] = []
	for i: int in MATERIALS:
		direct_xyz.append(Vector3.ZERO)
		forward_xyz.append(Vector3.ZERO)
		reference_xyz.append(Vector3.ZERO)
		object_xyz.append(Vector3.ZERO)
	var back_xyz := Vector3.ZERO
	var ambient_y: float = 0
	for i: int in wavelengths.size():
		var a: float = profile["a"][i]
		var b: float = profile["b"][i]
		var c: float = a + b
		var surface: float = daylight[i]
		var ambient: float = surface * exp(-float(profile["kd"][i]) * depth)
		var lamp: float = surface * lamp_target(c, distance, baseline, power)
		var source: float = (ambient + lamp) / PI
		var direct_factor: float = exp(-c * distance)
		var halo_factor: float = exp(-a * distance) * (1 - exp(-b * distance)) * fraction
		var weight: Vector3 = xyz_weight(i)
		var back: float = path_ambient(a, b, ambient, distance, g, diffuse)[0]
		back += surface * lamp_backscatter(a, b, distance, baseline, power, g)
		back_xyz += weight * back
		ambient_y += weight.y * ambient / PI
		for material: int in MATERIALS:
			var reflect: float = reflectance(material, wavelengths[i])
			var object: float = reflect * source
			direct_xyz[material] += weight * object * direct_factor
			forward_xyz[material] += weight * object * halo_factor
			object_xyz[material] += weight * object
			reference_xyz[material] += weight * reflect * surface / PI
	var direct_rgb := PackedVector3Array()
	var forward_rgb := PackedVector3Array()
	var reference_rgb := PackedVector3Array()
	for i: int in MATERIALS:
		direct_rgb.append(linear_rgb(direct_xyz[i]))
		forward_rgb.append(linear_rgb(forward_xyz[i]))
		reference_rgb.append(linear_rgb(reference_xyz[i]))
	return {"direct": direct_rgb, "forward": forward_rgb, "reference": reference_rgb,
		"back": linear_rgb(back_xyz), "sigma": halo_sigma_fraction(g, cone, distance),
		"daylight_y": ambient_y, "transmission_y": direct_xyz[1].y / maxf(1e-30, object_xyz[1].y),
		"veil_share": back_xyz.y / maxf(1e-30, direct_xyz[1].y + forward_xyz[1].y + back_xyz.y),
		"forward_share": forward_xyz[1].y / maxf(1e-30, direct_xyz[1].y + forward_xyz[1].y + back_xyz.y),
		"diagnostic": diagnostic(parameters, distance), "cone_fraction": fraction,
		"back_fraction": 1 - cone_fraction(g, PI / 2)}

func diagnostic(parameters: Dictionary, distance: float) -> Dictionary:
	# CIE Y is a non-negative wideband response. No sRGB gamma/matrix is used here.
	var profile: Dictionary = water(parameters)
	var depth: float = parameters.get("depth", 10.0)
	var g: float = parameters.get("g", 0.9)
	var diffuse: float = parameters.get("diffuse", 0.7)
	var j_white: float = 0
	var j_red: float = 0
	var d_white: float = 0
	var d_red: float = 0
	var back: float = 0
	var back_infinity: float = 0
	for i: int in wavelengths.size():
		var ambient: float = float(daylight[i]) * exp(-float(profile["kd"][i]) * depth)
		var a: float = profile["a"][i]
		var b: float = profile["b"][i]
		var y: float = xyz_weight(i).y
		var source: float = ambient * y / PI
		var transmission: float = exp(-(a + b) * distance)
		j_white += source * reflectance(1, wavelengths[i])
		j_red += source * reflectance(2, wavelengths[i])
		d_white += source * reflectance(1, wavelengths[i]) * transmission
		d_red += source * reflectance(2, wavelengths[i]) * transmission
		var path: PackedFloat64Array = path_ambient(a, b, ambient, distance, g, diffuse)
		back += y * path[0]
		back_infinity += y * path[1]
	if distance <= 1e-9: return {"white": null, "red": null, "back": null}
	return {"white": -log(maxf(1e-30, d_white / maxf(1e-30, j_white))) / distance,
		"red": -log(maxf(1e-30, d_red / maxf(1e-30, j_red))) / distance,
		"back": -log(maxf(1e-30, 1 - back / maxf(1e-30, back_infinity))) / distance}
