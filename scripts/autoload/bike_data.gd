extends Node
class_name BikeDataClass

## Manages bike ownership, selection, stats, and upgrades

const UPGRADE_TIER_COSTS: Array[int] = [150, 450, 1200, 3000, 7500]
const UPGRADE_EFFECT_PER_TIER: float = 0.5
const MAX_UPGRADE_TIER: int = 5

# Base stats for each bike (1-10 scale)
const BIKE_STATS: Dictionary = {
	"starter": {
		"name": "Starter",
		"top_speed": 6.0,
		"acceleration": 6.0,
		"handling": 6.0,
		"stability": 6.0,
		"jump_efficiency": 6.0,
		"cost": 0
	},
	"needle": {
		"name": "Needle",
		"top_speed": 5.0,
		"acceleration": 6.0,
		"handling": 9.0,
		"stability": 6.0,
		"jump_efficiency": 6.0,
		"cost": 600
	},
	"rocket": {
		"name": "Rocket",
		"top_speed": 9.0,
		"acceleration": 7.0,
		"handling": 4.0,
		"stability": 5.0,
		"jump_efficiency": 7.0,
		"cost": 2500
	},
	"tankette": {
		"name": "Tankette",
		"top_speed": 6.0,
		"acceleration": 5.0,
		"handling": 6.0,
		"stability": 9.0,
		"jump_efficiency": 5.0,
		"cost": 1500
	}
}

var owned_bikes: Array[String] = ["starter"]
var selected_bike: String = "starter"
var upgrade_tiers: Dictionary = {
	"top_speed": 0,
	"acceleration": 0,
	"handling": 0,
	"stability": 0,
	"jump_efficiency": 0
}

signal bike_selected(bike_id: String)
signal bike_purchased(bike_id: String)
signal upgrade_purchased(category: String, new_tier: int)


func get_base_stats(bike_id: String) -> Dictionary:
	if bike_id in BIKE_STATS:
		return BIKE_STATS[bike_id].duplicate()
	return BIKE_STATS["starter"].duplicate()


func get_effective_stats() -> Dictionary:
	var base: Dictionary = get_base_stats(selected_bike)
	var effective: Dictionary = {}

	effective["top_speed"] = base["top_speed"] + (upgrade_tiers["top_speed"] * UPGRADE_EFFECT_PER_TIER)
	effective["acceleration"] = base["acceleration"] + (upgrade_tiers["acceleration"] * UPGRADE_EFFECT_PER_TIER)
	effective["handling"] = base["handling"] + (upgrade_tiers["handling"] * UPGRADE_EFFECT_PER_TIER)
	effective["stability"] = base["stability"] + (upgrade_tiers["stability"] * UPGRADE_EFFECT_PER_TIER)
	effective["jump_efficiency"] = base["jump_efficiency"] + (upgrade_tiers["jump_efficiency"] * UPGRADE_EFFECT_PER_TIER)

	return effective


func select_bike(bike_id: String) -> bool:
	if bike_id not in owned_bikes:
		return false
	selected_bike = bike_id
	bike_selected.emit(bike_id)
	return true


func purchase_bike(bike_id: String) -> bool:
	if bike_id in owned_bikes:
		return false
	if bike_id not in BIKE_STATS:
		return false

	var cost: int = BIKE_STATS[bike_id]["cost"]
	if not Economy.spend(cost):
		return false

	owned_bikes.append(bike_id)
	bike_purchased.emit(bike_id)
	return true


func get_upgrade_cost(tier: int) -> int:
	if tier < 0 or tier >= UPGRADE_TIER_COSTS.size():
		return -1
	return UPGRADE_TIER_COSTS[tier]


func purchase_upgrade(category: String) -> bool:
	if category not in upgrade_tiers:
		return false

	var current_tier: int = upgrade_tiers[category]
	if current_tier >= MAX_UPGRADE_TIER:
		return false

	var cost: int = get_upgrade_cost(current_tier)
	if cost < 0 or not Economy.spend(cost):
		return false

	upgrade_tiers[category] = current_tier + 1
	upgrade_purchased.emit(category, upgrade_tiers[category])
	return true


func is_bike_owned(bike_id: String) -> bool:
	return bike_id in owned_bikes


func get_all_bike_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in BIKE_STATS.keys():
		ids.append(key)
	return ids
