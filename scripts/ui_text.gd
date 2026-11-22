extends RefCounted
## Shared display labels and read-only rule previews. No simulation state.
const ECONOMY = preload("res://scripts/economy_rules.gd")

static func ship_kind_name(kind: String) -> String:
	if kind == "warp_gate":
		return "Warp Gate"
	if kind == "science_ship":
		return "Science vessel"
	return {"ship": "Freighter", "miner": "Harvester", "colony_ship": "Colony"}.get(kind, kind.replace("_", " ").capitalize())

static func tons(value: float, decimals: int = 1, compact: bool = false) -> String:
	# Stocks and prices share one unit; preserve fractional small values.
	var number: String = ("%.1f" % value).trim_suffix(".0") if decimals == 1 and absf(value) < 1000.0 else "%.0f" % value
	return number + ("" if compact else " ") + "t"

static func compact_amount(value: float) -> String:
	if value >= 1000000000.0:
		return "%.1fB" % (value / 1000000000.0)
	if value >= 1000000.0:
		return "%.1fM" % (value / 1000000.0)
	if value >= 1000.0:
		return "%.1fK" % (value / 1000.0)
	return "%.0f" % value

static func crew_text(crew: float) -> String:
	return "%.0f" % crew

static func roman_level(level: int) -> String:
	if level <= 0:
		return "0"
	var result: String = ""
	for pair in [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"], [50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]:
		while level >= int(pair[0]):
			result += str(pair[1])
			level -= int(pair[0])
	return result

static func blaster_summary(kind: String) -> String:
	return "Blasters ×%d | %.0f dmg ×%d | %.1fs/%.1fs | R%.0f" % [ECONOMY.blaster_count(kind), ECONOMY.BLASTER_DAMAGE, ECONOMY.BLASTER_SHOTS, ECONOMY.BLASTER_BURST, ECONOMY.BLASTER_PAUSE, ECONOMY.LASER_RANGE]

static func capital_weapon_summary(kind: String) -> String:
	return "Lasers ×%d | %.0f dmg | 1s | R%.0f\nMissiles ×%d | %.0f dmg | %.0fs | R%.0f" % [ECONOMY.capital_lasers(kind), ECONOMY.LASER_DAMAGE, ECONOMY.LASER_RANGE, ECONOMY.missile_count(kind), ECONOMY.MISSILE_DAMAGE, ECONOMY.MISSILE_COOLDOWN, ECONOMY.MISSILE_RANGE] + "\n" + blaster_summary(kind)

static func colony_population_requirement() -> String:
	return "Requires %.0f station population" % ECONOMY.COLONY_MIN_ORIGIN_POPULATION

static func ship_stats(kind: String) -> String:
	var details: String = ""
	match kind:
		"ship": details = "Transports resources · Cargo %.0f t" % ECONOMY.CARGO_CAPACITY
		"colony_ship": details = "%s\nSettles a neutral system · %.0f settlers\nFarm %.0f t/s · Cargo %.0f t" % [colony_population_requirement(), ECONOMY.COLONY_POPULATION, ECONOMY.COLONY_FARM_RATE, ECONOMY.COLONY_CAPACITY]
		"scout": details = "Fast reconnaissance · " + blaster_summary(kind)
		"cruiser", "destroyer": details = capital_weapon_summary(kind)
		"fighter": details = blaster_summary(kind)
		"miner": details = "Damage %.0f · Range %.0f · Mining %.0f t/s · Cargo %.0f t" % [ECONOMY.MINER_LASER_DAMAGE, ECONOMY.LASER_RANGE, ECONOMY.MINER_RATE, ECONOMY.MINER_CAPACITY]
		"science_ship": details = "Pulsar collector · 1 antimatter · %.0f s collection" % ECONOMY.SCIENCE_COLLECTION_YEARS
	return "%s\nHP %.0f · Speed %.0f/s · %s\nUpkeep: %.0f GC/yr" % [details, ECONOMY.ship_max_hp(kind), ECONOMY.ship_speed(kind), ECONOMY.size_name(ECONOMY.ship_size(kind)), ECONOMY.ship_upkeep(kind)]

static func system_bonus_text(p: Dictionary) -> String:
	var lines: PackedStringArray = []
	var names: Dictionary = {"Metals": "Metal production", "Crystals": "Crystal production", "Organics": "Organics production"}
	for resource in ECONOMY.ACTIVE_PRODUCTION:
		var percent: int = roundi(ECONOMY.production_modifier(p, resource) * 100.0)
		if percent != 100:
			lines.append("%s %d%%" % [names[resource], percent])
	var advanced: int = roundi(float(p.get("advanced_bonus", 1.0)) * 100.0)
	if advanced != 100:
		lines.append("Advanced manufacturing %d%% (future)" % advanced)
	return "\n".join(lines)

# Preserve meaningful small production increments instead of rounding
# both the reference and local value to the same hundredth of a ton.
static func signed_yield(value: float) -> String:
	if is_zero_approx(value):
		return "+0"
	if absf(value) < 0.0001:
		return "+<0.0001" if value > 0.0 else "−<0.0001"
	var number: String = "%+.4f" % value if absf(value) < 0.001 else ("%+.3f" % value if absf(value) < 0.1 else "%+.2f" % value)
	return number.rstrip("0").trim_suffix(".")

static func economy_building_effect(p: Dictionary, resource: String) -> String:
	if not ECONOMY.production_available(p, resource):
		return "Requires local production deposit" if resource != "Organics" else "Requires planets"
	var preview: Dictionary = p.duplicate()
	var buildings: Dictionary = p.get("buildings", {}).duplicate()
	buildings[resource] = int(buildings.get(resource, 0)) + 1
	preview["buildings"] = buildings
	var actual: float = ECONOMY.rate(preview, resource) - ECONOMY.rate(p, resource)
	# A reference population makes increments comparable; agriculture has
	# nonlinear labor scaling, so describe a reference rather than a ratio.
	var reference: Dictionary = p.duplicate()
	var reference_preview: Dictionary = preview.duplicate()
	for sample in [reference, reference_preview]:
		sample["population"] = ECONOMY.HOME_POPULATION
		sample["eco_population"] = 0.0
		sample["planet_blockaded"] = false
	var base: float = ECONOMY.rate(reference_preview, resource) - ECONOMY.rate(reference, resource)
	var result: String = "Yield: %s t/yr\nReference: %s t/yr %s 10k %s" % [signed_yield(actual), signed_yield(base), "at" if resource == "Organics" else "per", "planetary pop." if resource == "Organics" else "pop."]
	if resource == "Organics":
		result += "\n+%s food-supported population" % compact_amount(ECONOMY.population_capacity(preview) - ECONOMY.population_capacity(p))
	if bool(p.get("planet_blockaded", false)):
		result += "\nPlanetary production blockaded"
	return result
