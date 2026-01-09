extends GutTest
## Unit tests for BikeData autoload

var _bike_data: BikeDataClass


func before_each() -> void:
	_bike_data = BikeDataClass.new()


func after_each() -> void:
	_bike_data.free()


# === STATS INITIALIZATION TESTS ===

func test_rage_bike_stats_has_all_required_keys() -> void:
	var stats: Dictionary = _bike_data.get_stats()
	assert_has(stats, "name", "Stats should have 'name' key")
	assert_has(stats, "top_speed", "Stats should have 'top_speed' key")
	assert_has(stats, "acceleration", "Stats should have 'acceleration' key")
	assert_has(stats, "handling", "Stats should have 'handling' key")
	assert_has(stats, "stability", "Stats should have 'stability' key")
	assert_has(stats, "jump_efficiency", "Stats should have 'jump_efficiency' key")


func test_rage_bike_name_is_correct() -> void:
	var stats: Dictionary = _bike_data.get_stats()
	assert_eq(stats["name"], "Rage Bike", "Bike name should be 'Rage Bike'")


func test_stats_are_within_1_to_10_scale() -> void:
	var stats: Dictionary = _bike_data.get_stats()
	var numeric_stats: Array = ["top_speed", "acceleration", "handling", "stability", "jump_efficiency"]
	
	for stat_name in numeric_stats:
		var value: float = stats[stat_name]
		assert_gte(value, 1.0, "%s should be >= 1.0" % stat_name)
		assert_lte(value, 10.0, "%s should be <= 10.0" % stat_name)


func test_rage_bike_has_challenging_stats() -> void:
	# The rage bike should have lower stats to be challenging
	var stats: Dictionary = _bike_data.get_stats()
	assert_lt(stats["stability"], 5.0, "Stability should be low for rage mechanic")
	assert_lt(stats["top_speed"], 6.0, "Top speed should be moderate")


# === STATS RETRIEVAL TESTS ===

func test_get_stats_returns_duplicate() -> void:
	var stats1: Dictionary = _bike_data.get_stats()
	var stats2: Dictionary = _bike_data.get_stats()
	stats1["top_speed"] = 999.0
	assert_ne(stats2["top_speed"], 999.0, "Modifying returned stats should not affect original")


func test_get_effective_stats_returns_same_as_get_stats() -> void:
	var stats: Dictionary = _bike_data.get_stats()
	var effective_stats: Dictionary = _bike_data.get_effective_stats()
	assert_eq(stats, effective_stats, "get_effective_stats should return same as get_stats")


# === SPECIFIC STAT VALUE TESTS ===

func test_rage_bike_top_speed_value() -> void:
	var stats: Dictionary = _bike_data.get_stats()
	assert_eq(stats["top_speed"], 4.5, "Top speed should be 4.5")


func test_rage_bike_acceleration_value() -> void:
	var stats: Dictionary = _bike_data.get_stats()
	assert_eq(stats["acceleration"], 5.0, "Acceleration should be 5.0")


func test_rage_bike_handling_value() -> void:
	var stats: Dictionary = _bike_data.get_stats()
	assert_eq(stats["handling"], 5.5, "Handling should be 5.5")


func test_rage_bike_stability_value() -> void:
	var stats: Dictionary = _bike_data.get_stats()
	assert_eq(stats["stability"], 4.0, "Stability should be 4.0")


func test_rage_bike_jump_efficiency_value() -> void:
	var stats: Dictionary = _bike_data.get_stats()
	assert_eq(stats["jump_efficiency"], 5.0, "Jump efficiency should be 5.0")
