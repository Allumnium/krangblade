extends RefCounted
## Stateless base construction recipes and nominal work. EconomyRules owns
## discounts, staffing, credit reservations, queue admission and all mutations.

static func base_work(kind: String, level: int) -> float:
	match kind:
		"ship": return 48.0
		"colony_ship": return 102.0
		"fighter": return 36.0
		"miner": return 60.0
		"science_ship": return 90.0
		"scout": return 12.0
		"cruiser": return 90.0
		"destroyer": return 180.0
		"railgun_ship": return 120.0
		"construction_ship": return 48.0
		"yard": return 30.0
		"pds": return 36.0
		"dyson_sphere": return 300.0
		"reinforced_plating", "laser_matrix": return 60.0
		"yard_upgrade": return 15.0 * level
		"production": return 10.0 * level
		"warehouse": return 10.0 + 10.0 * level
		"habitation": return 12.0 + 12.0 * level
		"orbital_housing": return 30.0
	return 1.0

static func base_cost(kind: String, level: int, _crystal_multiplier: float, upgrade_factor: float, warehouse_costs: Array, orbital_housing_cost: Dictionary) -> Dictionary:
	# Explicit prototype values; the final costs/recipes are intentionally undefined.
	match kind:
		"ship": return {"Metals": 50.0}
		"colony_ship": return {"Metals": 150.0, "Organics": 10.0}
		"fighter": return {"Metals": 25.0}
		"miner": return {"Metals": 50.0}
		"science_ship": return {"Metals": 100.0}
		"scout": return {"Metals": 10.0}
		"cruiser": return {"Metals": 200.0, "Crystals": 25.0}
		"destroyer": return {"Metals": 300.0, "Crystals": 75.0}
		"railgun_ship": return {"Metals": 200.0, "Crystals": 50.0}
		"construction_ship": return {"Metals": 40.0}
		"yard":
			match level:
				1: return {"Metals": 50.0}
				2: return {"Metals": 200.0, "Crystals": 75.0}
				3: return {"Metals": 600.0, "Crystals": 250.0}
		"pds": return {"Metals": 50.0, "Crystals": 25.0}
		"dyson_sphere": return {"Metals": 2000.0, "Crystals": 1000.0}
		"reinforced_plating": return {"Metals": 400.0}
		"laser_matrix": return {"Metals": 250.0, "Crystals": 300.0}
		"yard_upgrade": return {"Metals": 25.0 * pow(upgrade_factor, float(maxi(0, level - 1)))}
		"production": return {"Metals": 25.0 * pow(upgrade_factor, float(maxi(0, level - 1)))}
		"warehouse": return warehouse_costs[level - 1].duplicate()
		"habitation":
			var factor: float = pow(3.0, level - 1)
			return {"Metals": 75.0 * factor}
		"orbital_housing": return orbital_housing_cost.duplicate()
	return {}

static func has_queued_job(planet: Dictionary, kind: String, target: String) -> bool:
	for item in planet["queue"]:
		if item["kind"] == kind and item["target"] == target:
			return true
	return false
