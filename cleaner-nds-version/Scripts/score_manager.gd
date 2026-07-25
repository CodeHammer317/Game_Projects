extends Node

signal score_changed(score: int)
signal high_score_changed(high_score: int)
signal points_awarded(points: int, total_score: int, reason: StringName)

const SAVE_PATH: String = "user://arcade_score.cfg"
const SAVE_SECTION: String = "arcade"
const HIGH_SCORE_KEY: String = "high_score"
const MAX_SCORE: int = 99_999_999

var score: int = 0
var high_score: int = 0

var _awarded_source_ids: Dictionary = {}


func _ready() -> void:
	_load_high_score()
	score_changed.emit(score)
	high_score_changed.emit(high_score)


func start_new_run() -> void:
	score = 0
	_awarded_source_ids.clear()
	score_changed.emit(score)


func add_points(points: int, reason: StringName = &"gameplay") -> int:
	if points <= 0:
		return score

	score = mini(score + points, MAX_SCORE)
	points_awarded.emit(points, score, reason)
	score_changed.emit(score)

	if score > high_score:
		high_score = score
		high_score_changed.emit(high_score)
		_save_high_score()

	return score


func award_once(source: Object, points: int, reason: StringName = &"gameplay") -> bool:
	if source == null or not is_instance_valid(source) or points <= 0:
		return false

	var source_id := source.get_instance_id()
	if _awarded_source_ids.has(source_id):
		return false

	_awarded_source_ids[source_id] = true
	add_points(points, reason)
	return true


func award_enemy(enemy: Object, points: int) -> bool:
	return award_once(enemy, points, &"enemy")


func award_pickup(pickup: Object, points: int) -> bool:
	return award_once(pickup, points, &"pickup")


func format_score(value: int) -> String:
	return "%08d" % clampi(value, 0, MAX_SCORE)


func _load_high_score() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)

	if error == ERR_FILE_NOT_FOUND:
		high_score = 0
		return

	if error != OK:
		push_warning("ScoreManager: unable to load resident high score. Error: %s" % error)
		high_score = 0
		return

	high_score = clampi(
		int(config.get_value(SAVE_SECTION, HIGH_SCORE_KEY, 0)),
		0,
		MAX_SCORE
	)


func _save_high_score() -> void:
	var config := ConfigFile.new()
	config.set_value(SAVE_SECTION, HIGH_SCORE_KEY, high_score)

	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("ScoreManager: unable to save resident high score. Error: %s" % error)
