extends CanvasLayer
class_name HUD

@onready var score_label: Label = $ScoreLabel
@onready var killstreak_label: Label = $KillstreakLabel
@onready var level_label: Label = $LevelLabel
@onready var game_over_panel: Panel = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/GameOverLabel
@onready var restart_label: Label = $GameOverPanel/RestartLabel


func _ready() -> void:
	_connect_signals()
	_refresh_all()

	if game_over_panel != null:
		game_over_panel.visible = false


func _process(delta: float) -> void:
	if not GameState.is_game_over:
		return

	if Input.is_action_just_pressed("shoot"):
		GameState.reset_game()
		get_tree().reload_current_scene()


func _connect_signals() -> void:
	if not GameState.score_changed.is_connected(_on_score_changed):
		GameState.score_changed.connect(_on_score_changed)

	if not GameState.killstreak_changed.is_connected(_on_killstreak_changed):
		GameState.killstreak_changed.connect(_on_killstreak_changed)

	if not GameState.level_changed.is_connected(_on_level_changed):
		GameState.level_changed.connect(_on_level_changed)

	if not GameState.game_over_triggered.is_connected(_on_game_over_triggered):
		GameState.game_over_triggered.connect(_on_game_over_triggered)


func _refresh_all() -> void:
	_on_score_changed(GameState.score)
	_on_killstreak_changed(GameState.killstreak)
	_on_level_changed(GameState.current_level)


func _on_score_changed(new_score: int) -> void:
	if score_label == null:
		return

	score_label.text = "SCORE: " + str(new_score)


func _on_killstreak_changed(new_killstreak: int) -> void:
	if killstreak_label == null:
		return

	killstreak_label.text = "STREAK: " + str(new_killstreak)


func _on_level_changed(new_level: int) -> void:
	if level_label == null:
		return

	level_label.text = "LEVEL: " + str(new_level)


func _on_game_over_triggered(reason: String) -> void:
	if game_over_panel != null:
		game_over_panel.visible = true

	if game_over_label != null:
		game_over_label.text = "GAME OVER\n" + reason

	if restart_label != null:
		restart_label.text = "PRESS SHOOT TO RESTART"
