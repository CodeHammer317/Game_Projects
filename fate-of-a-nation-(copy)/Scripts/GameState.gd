extends Node

signal score_changed(new_score: int)
signal high_score_changed(new_high_score: int)
signal killstreak_changed(new_killstreak: int)
signal level_changed(new_level: int)
signal game_over_triggered(reason: String)
signal powerup_earned(killstreak: int)

const SAVE_PATH: String = "user://save_data.cfg"

var score: int = 0
var high_score: int = 0
var killstreak: int = 0
var current_level: int = 1
var is_game_over: bool = false

var kills_total: int = 0
var kills_this_level: int = 0

var points_per_kill: int = 100
var killstreak_bonus_amount: int = 10

var powerup_streak_interval: int = 10
var last_powerup_streak: int = 0


func _ready() -> void:
	load_save()


func reset_game() -> void:
	score = 0
	killstreak = 0
	current_level = 1
	is_game_over = false

	kills_total = 0
	kills_this_level = 0
	last_powerup_streak = 0

	score_changed.emit(score)
	high_score_changed.emit(high_score)
	killstreak_changed.emit(killstreak)
	level_changed.emit(current_level)


func start_level(level_number: int) -> void:
	current_level = level_number
	is_game_over = false

	kills_this_level = 0
	killstreak = 0
	last_powerup_streak = 0

	level_changed.emit(current_level)
	killstreak_changed.emit(killstreak)


func add_kill(enemy_point_value: int = -1) -> void:
	if is_game_over:
		return

	var base_points: int = points_per_kill

	if enemy_point_value >= 0:
		base_points = enemy_point_value

	kills_total += 1
	kills_this_level += 1
	killstreak += 1

	var bonus_points: int = killstreak * killstreak_bonus_amount
	var total_points: int = base_points + bonus_points

	score += total_points

	score_changed.emit(score)
	killstreak_changed.emit(killstreak)

	_check_high_score()
	_check_powerup_reward()


func reset_killstreak() -> void:
	if killstreak == 0:
		return

	killstreak = 0
	last_powerup_streak = 0
	killstreak_changed.emit(killstreak)


func add_score(amount: int) -> void:
	if is_game_over:
		return

	if amount <= 0:
		return

	score += amount
	score_changed.emit(score)
	_check_high_score()


func trigger_game_over(reason: String = "The enemy broke through.") -> void:
	if is_game_over:
		return

	is_game_over = true
	reset_killstreak()
	_check_high_score()

	game_over_triggered.emit(reason)


func _check_high_score() -> void:
	if score <= high_score:
		return

	high_score = score
	high_score_changed.emit(high_score)
	save_game()


func save_game() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("scores", "high_score", high_score)
	config.save(SAVE_PATH)


func load_save() -> void:
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(SAVE_PATH)

	if error != OK:
		high_score = 0
		return

	high_score = int(config.get_value("scores", "high_score", 0))
	high_score_changed.emit(high_score)


func _check_powerup_reward() -> void:
	if powerup_streak_interval <= 0:
		return

	if killstreak < powerup_streak_interval:
		return

	if killstreak % powerup_streak_interval != 0:
		return

	if killstreak == last_powerup_streak:
		return

	last_powerup_streak = killstreak
	powerup_earned.emit(killstreak)
	
