extends GutTest
## Unit tests for Economy autoload

var _economy: EconomyClass


func before_each() -> void:
	_economy = EconomyClass.new()
	_economy.wallet = 0
	_economy.pot = 0


func after_each() -> void:
	_economy.free()


# === REWARD CURVE TESTS ===

func test_reward_curve_has_correct_values() -> void:
	var expected: Array[int] = [0, 1, 3, 8, 20, 50, 120, 300, 750]
	assert_eq(_economy.REWARD_CURVE, expected, "Reward curve should match expected values")


func test_base_pot_unit_is_100() -> void:
	assert_eq(_economy.BASE_POT_UNIT, 100, "Base pot unit should be 100")


# === POT CALCULATION TESTS ===

func test_calculate_pot_for_stage_0_returns_0() -> void:
	var pot: int = _economy.calculate_pot_for_stage(0)
	assert_eq(pot, 0, "Stage 0 pot should be 0 (0 * 100)")


func test_calculate_pot_for_stage_1_returns_100() -> void:
	var pot: int = _economy.calculate_pot_for_stage(1)
	assert_eq(pot, 100, "Stage 1 pot should be 100 (1 * 100)")


func test_calculate_pot_for_stage_5_returns_5000() -> void:
	var pot: int = _economy.calculate_pot_for_stage(5)
	assert_eq(pot, 5000, "Stage 5 pot should be 5000 (50 * 100)")


func test_calculate_pot_for_invalid_stage_returns_0() -> void:
	assert_eq(_economy.calculate_pot_for_stage(-1), 0, "Negative stage should return 0")
	assert_eq(_economy.calculate_pot_for_stage(100), 0, "Stage beyond curve should return 0")


# === WALLET TESTS ===

func test_add_to_wallet_increases_balance() -> void:
	_economy.add_to_wallet(500)
	assert_eq(_economy.wallet, 500, "Wallet should have 500 after adding 500")


func test_add_to_wallet_accumulates() -> void:
	_economy.add_to_wallet(100)
	_economy.add_to_wallet(200)
	assert_eq(_economy.wallet, 300, "Wallet should accumulate additions")


func test_can_afford_returns_true_when_enough_funds() -> void:
	_economy.wallet = 1000
	assert_true(_economy.can_afford(500), "Should afford 500 with 1000 wallet")
	assert_true(_economy.can_afford(1000), "Should afford exact amount")


func test_can_afford_returns_false_when_insufficient() -> void:
	_economy.wallet = 100
	assert_false(_economy.can_afford(500), "Should not afford 500 with 100 wallet")


func test_spend_deducts_from_wallet() -> void:
	_economy.wallet = 1000
	var result: bool = _economy.spend(300)
	assert_true(result, "Spend should return true on success")
	assert_eq(_economy.wallet, 700, "Wallet should be 700 after spending 300")


func test_spend_fails_when_insufficient_funds() -> void:
	_economy.wallet = 100
	var result: bool = _economy.spend(500)
	assert_false(result, "Spend should return false when insufficient funds")
	assert_eq(_economy.wallet, 100, "Wallet should remain unchanged on failed spend")


# === POT TESTS ===

func test_lose_pot_resets_to_zero() -> void:
	_economy.pot = 5000
	_economy.lose_pot()
	assert_eq(_economy.pot, 0, "Pot should be 0 after losing")
