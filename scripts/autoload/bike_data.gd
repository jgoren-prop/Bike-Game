extends Node
class_name BikeDataClass

## Provides fixed bike stats for rage game - single challenging bike

# Fixed rage bike stats (1-10 scale) - designed to be challenging
const RAGE_BIKE_STATS: Dictionary = {
	"name": "Rage Bike",
	"top_speed": 4.5,        # Lower than starter - requires precision
	"acceleration": 5.0,     # Moderate - builds momentum slowly
	"handling": 5.5,         # Sluggish - harder to control
	"stability": 4.0,        # Low - easy to tip over (key rage mechanic)
	"jump_efficiency": 5.0   # Average - jumps require precision
}


func get_stats() -> Dictionary:
	return RAGE_BIKE_STATS.duplicate()


# Legacy compatibility - redirects to fixed stats
func get_effective_stats() -> Dictionary:
	return get_stats()
