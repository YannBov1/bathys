extends SceneTree
var failures: int = 0
var passed: int = 0
func check(value: bool, message: String) -> void:
	if value: passed += 1
	else: failures += 1; push_error(message)
func near(actual: float, expected: float, relative: float, message: String) -> void:
	check(absf(actual - expected) <= relative * maxf(1e-12, absf(expected)), message + " actual=" + str(actual) + " expected=" + str(expected))
func _initialize() -> void:
	var m := BathysTransportModels
	near(m.water(20)["mu"], 0.0010016, 0.001, "water viscosity matches atmospheric 20°C reference")
	check(m.water(0)["mu"] > m.water(20)["mu"] and m.water(35)["mu"] < m.water(20)["mu"], "warm water is less viscous")
	near(m.gas(26.85, 0, 0)["mu"], 17.8e-6, 1e-12, "nitrogen 300 K viscosity anchor")
	near(m.gas(26.85, 0, 100)["mu"], 19.9e-6, 1e-12, "helium 300 K viscosity anchor")
	check(m.gas(35)["mu"] > m.gas(0)["mu"], "warm dilute gas becomes more viscous")
	near(m.gas(20, 21, 0, 7)["rho"], m.gas(20)["rho"] * 7, 1e-12, "ideal density scales with absolute pressure")
	near(m.gas(20, 21, 0, 7)["mu"], m.gas(20)["mu"], 1e-12, "dilute dynamic viscosity is independent of pressure in this model")
	for oxygen: float in [0, 21, 50, 100]:
		for helium: float in [0, (100 - oxygen) / 2, 100 - oxygen]:
			var gas: Dictionary = m.gas(20, oxygen, helium)
			for key: String in ["mu", "k", "rho", "cp"]: check(is_finite(gas[key]) and gas[key] > 0, "mixture property positive: " + key)
	var p: Dictionary = {"medium": 0, "temperature": 20.0, "speed": 0.2, "gap": 5.0, "diameter": 10.0, "flow": 0.1, "length": 0.3, "hot": 45.0, "area": 0.02, "emissivity": 0.95, "material": 0, "basis": 0, "energy": 100.0, "oxygen": 21.0, "helium": 0.0}
	var shear: Dictionary = m.shear(p)
	p["speed"] = 0.4
	near(m.shear(p)["force"], shear["force"] * 2, 1e-12, "Couette drag doubles with plate speed")
	p["gap"] = 10
	near(m.shear(p)["force"], shear["force"], 1e-12, "doubling gap halves shear at the new speed")
	var pipe: Dictionary = m.pipe(p)
	var expected: float = 128 * m.water(20)["mu"] * 0.3 * (0.1 / 60000) / (PI * pow(0.01, 4))
	near(pipe["pressure"], expected, 1e-12, "laminar Darcy relation reduces to Poiseuille")
	check(pipe["regime"] == "Laminar", "small flow is laminar")
	p["flow"] = 0.2
	near(m.pipe(p)["pressure"], expected * 2, 1e-12, "laminar pressure loss scales linearly with volume flow")
	p["flow"] = 0.1
	p["diameter"] = 20
	near(m.pipe(p)["pressure"], expected / 16, 1e-12, "doubling diameter gives the laminar fourth-power effect")
	p["diameter"] = 10
	p["flow"] = 20
	check(m.pipe(p)["regime"] == "Turbulent", "large water flow is turbulent")
	p["gap"] = 5
	var water_heat: float = m.heat_transfer(p, 0)["heat"]
	p["gap"] = 10
	near(m.heat_transfer(p, 0)["heat"], water_heat / 2, 1e-12, "slab conduction inversely proportional to thickness")
	p["gap"] = 5
	p["medium"] = 1
	check(water_heat > m.heat_transfer(p, 0)["heat"] * 20, "water layer conducts much more heat than the same air layer")
	var air_convection: float = m.heat_transfer(p, 1)["heat"]
	p["medium"] = 0
	check(m.heat_transfer(p, 1)["heat"] > air_convection, "forced water crossflow transfers more heat than air at equal conditions")
	var heat: float = m.heat_transfer(p, 1)["heat"]
	p["speed"] = 0.8
	check(m.heat_transfer(p, 1)["heat"] > heat, "forced convection increases with speed")
	heat = m.heat_transfer(p, 2)["heat"]
	p["emissivity"] = 0.475
	near(m.heat_transfer(p, 2)["heat"], heat / 2, 1e-12, "radiation proportional to emissivity")
	p["temperature"] = 45
	near(m.heat_transfer(p, 2)["heat"], 0, 1e-12, "equal surface temperatures give zero net radiation")
	p["temperature"] = 20
	var stored: Dictionary = m.thermal_properties(p, 0)
	near(stored["capacity"], 0.05 * 4184, 1e-12, "50 g water storage heat capacity")
	near(stored["rise"], 100 / (0.05 * 4184), 1e-12, "temperature rise uses Q divided by sample heat capacity")
	p["material"] = 3
	var air: Dictionary = m.thermal_properties(p, 0)
	p["oxygen"] = 0
	p["helium"] = 100
	var helium: Dictionary = m.thermal_properties(p, 0)
	check(helium["rise"] < air["rise"] and helium["properties"]["k"] > air["properties"]["k"] * 5, "helium mass-specific storage and conductivity are distinct")
	p["basis"] = 1
	helium = m.thermal_properties(p, 0)
	p["oxygen"] = 21
	p["helium"] = 0
	air = m.thermal_properties(p, 0)
	check(helium["rise"] > air["rise"], "equal initial gas volume reverses the heat-storage comparison")
	near(m.sound_speed(0, 35, 0), 1449.05, 1e-12, "Coppens zero-temperature seawater reference")
	near(m.sound_speed(20, 35, 0), 1521.45, 1e-12, "Coppens 20°C seawater reference")
	near(m.sound_speed(20, 0, 0), 1482.355, 1e-12, "Coppens freshwater reference")
	check(m.sound_speed(20, 35, 1000) - m.sound_speed(20, 35, 0) < 30, "Coppens depth converted from metres to kilometres")
	var sound_p: Dictionary = {"temperature": 20.0, "salinity": 0.0, "depth": 10.0, "boundary": 0, "range": 10.0, "frequency": 10.0, "bearing": 55.0}
	var sound: Dictionary = m.sound(sound_p, 0)
	check(sound["water_ms"] < sound["air_ms"] / 4, "water arrival is more than four times earlier over the same path")
	near(sound["reflection"] + sound["transmission"], 1, 1e-12, "reflection energy balance")
	check(sound["reflection"] > 0.99, "large water-air impedance mismatch")
	sound_p["boundary"] = 1
	near(m.sound(sound_p, 1)["reflection"], 0, 1e-12, "matched water has no reflection")
	sound_p["range"] = 1
	near(m.sound(sound_p, 2)["loss"], 0, 1e-12, "one-metre level reference has no propagation loss")
	sound_p["range"] = 10
	near(m.sound(sound_p, 2)["spread"], 20, 1e-12, "spherical spreading costs 20 dB per tenfold range")
	check(m.absorption(100) > m.absorption(1) and m.absorption(1) > 0, "higher-frequency seawater absorption")
	sound_p["range"] = 10
	var cue: Dictionary = m.sound(sound_p, 3)
	sound_p["bearing"] = 125
	near(m.sound(sound_p, 3)["delay_water"], cue["delay_water"], 1e-10, "front-back mirrored sources have the same geometric timing cue")
	check(absf(cue["delay_water"]) < absf(cue["delay_air"]) and absf(cue["delay_water"]) <= 0.18 / cue["c"] * 1e6, "water timing cue respects physical ear spacing")
	for angle: float in [0, 180]:
		sound_p["bearing"] = angle
		near(m.sound(sound_p, 3)["delay_water"], 0, 1e-12, "centred source reaches both point receivers together")
	print("TRANSPORT MODEL checks=", passed, " failures=", failures)
	quit(1 if failures else 0)
