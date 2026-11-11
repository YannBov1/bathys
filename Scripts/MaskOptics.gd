class_name BathysMaskOptics
extends RefCounted

static func trace(p: Dictionary) -> Dictionary:
	var water: float = p.get("water_index", 1.333)
	var glass: float = p["glass_index"]
	var air: float = p.get("air_index", 1.0)
	var gap: float = float(p["gap"]) / 1000
	var thickness: float = float(p["thickness"]) / 1000
	var distance: float = p["distance"]
	var half_height: float = float(p["height"]) / 2
	# Conserved optical invariant q = n sin(theta) for parallel interfaces.
	# Positive angles are measured from the common normal, i.e. the horizontal axis.
	var lo: float = 0
	var hi: float = minf(air, minf(glass, water)) * (1 - 1e-12)
	for i: int in 60:
		var q: float = (lo + hi) / 2
		var height: float = gap * q / sqrt(air * air - q * q) + thickness * q / sqrt(glass * glass - q * q) + distance * q / sqrt(water * water - q * q)
		if height < half_height: lo = q
		else: hi = q
	var q: float = (lo + hi) / 2
	var theta_air: float = asin(q / air)
	var theta_glass: float = asin(q / glass)
	var theta_water: float = asin(q / water)
	var actual: float = gap + thickness + distance
	var reference: float = atan(half_height / actual)
	var paraxial: float = gap + thickness * air / glass + distance * air / water
	# Edge-pair construction: extend the rays reaching the eye as straight lines.
	# This is not a claim that a finite-angle flat port has one perfect virtual-image plane.
	var apparent: float = half_height / tan(theta_air) if half_height > 1e-12 else paraxial
	return {"q": q, "theta_air": theta_air, "theta_glass": theta_glass, "theta_water": theta_water,
		"air_y": gap * tan(theta_air), "glass_y": gap * tan(theta_air) + thickness * tan(theta_glass),
		"actual": actual, "apparent": apparent, "paraxial": paraxial,
		"air_angle": 2 * reference, "mask_angle": 2 * theta_air,
		"magnification": theta_air / reference if reference > 1e-12 else actual / paraxial}
