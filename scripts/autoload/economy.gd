extends Node
class_name EconomyClass

## Handles wallet, pot, and all money transactions

const REWARD_CURVE: Array[int] = [0, 1, 3, 8, 20, 50, 120, 300, 750]
const BASE_POT_UNIT: int = 100

var wallet: int = 0
var pot: int = 0

signal wallet_changed(new_amount: int)
signal pot_changed(new_amount: int)


func calculate_pot_for_stage(stage: int) -> int:
	if stage < 0 or stage >= REWARD_CURVE.size():
		return 0
	return BASE_POT_UNIT * REWARD_CURVE[stage]


func set_pot_for_stage(stage: int) -> void:
	pot = calculate_pot_for_stage(stage)
	pot_changed.emit(pot)


func cash_out() -> void:
	var amount: int = pot
	wallet += pot
	wallet_changed.emit(wallet)
	pot = 0
	pot_changed.emit(pot)
	# Track earnings and save
	GameManager.total_earnings += amount
	SaveManager.save_game()


func lose_pot() -> void:
	pot = 0
	pot_changed.emit(pot)


func can_afford(cost: int) -> bool:
	return wallet >= cost


func spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	wallet -= cost
	wallet_changed.emit(wallet)
	SaveManager.save_game()
	return true


func add_to_wallet(amount: int) -> void:
	wallet += amount
	wallet_changed.emit(wallet)
