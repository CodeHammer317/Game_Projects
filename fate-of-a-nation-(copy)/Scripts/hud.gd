extends CanvasLayer
class_name HUD

@onready var health_bar: TextureProgressBar = $HealthBar
@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var killstreak_label: Label = $VBoxContainer/KillstreakLabel
@onready var high_score_label: Label = $VBoxContainer/HighScoreLabel
@onready var level_label: Label = $VBoxContainer/LevelLabel
@onready var game_over_panel: Panel = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/GameOverLabel
@onready var restart_label: Label = $GameOverPanel/RestartLabel
@export var low_health_threshold: int = 3
@export var low_health_pulse_speed: float = 6.0
@export var low_health_min_alpha: float = 0.45

var _health_bar_normal_modulate: Color = Color.WHITE
var _is_low_health: bool = false
var player: Node = null
var _is_player_connected: bool = false

func _ready() -> void:
	print("HUD READY STARTED")
	if health_bar != null:
		_health_bar_normal_modulate = health_bar.modulate
	
	var attempts: int = 0

	while player == null and attempts < 60:
		player = get_tree().get_first_node_in_group("player")

		if player != null:
			break

		attempts += 1
		await get_tree().process_frame

	print("PLAYER GROUP COUNT:", get_tree().get_nodes_in_group("player").size())
	print("PLAYER FOUND:", player)

	if player == null:
		push_warning("HUD: Player not found.")
	else:
		print("HUD found player:", player.name)
	_update_player_connection()
	_connect_signals()
	_refresh_all()

	if game_over_panel != null:
		game_over_panel.visible = false


func _process(delta: float) -> void:
	_update_player_connection()
	_update_low_health_pulse(delta)

	if not GameState.is_game_over:
		return

	if Input.is_action_just_pressed("shoot"):
		GameState.reset_game()
		get_tree().reload_current_scene()


func _connect_signals() -> void:
	if player != null:
		if player.has_signal("health_changed"):
			if not player.health_changed.is_connected(_on_player_health_changed):
				player.health_changed.connect(_on_player_health_changed)

			if "current_health" in player:
				if "max_health" in player:
					_on_player_health_changed(player.current_health, player.max_health)
		else:
			push_warning("HUD: Player does not have health_changed signal.")

	if not GameState.score_changed.is_connected(_on_score_changed):
		GameState.score_changed.connect(_on_score_changed)

	if not GameState.high_score_changed.is_connected(_on_high_score_changed):
		GameState.high_score_changed.connect(_on_high_score_changed)

	if not GameState.killstreak_changed.is_connected(_on_killstreak_changed):
		GameState.killstreak_changed.connect(_on_killstreak_changed)

	if not GameState.level_changed.is_connected(_on_level_changed):
		GameState.level_changed.connect(_on_level_changed)

	if not GameState.game_over_triggered.is_connected(_on_game_over_triggered):
		GameState.game_over_triggered.connect(_on_game_over_triggered)


func _refresh_all() -> void:
	if player != null:
		if "current_health" in player:
			if "max_health" in player:
				_on_player_health_changed(player.current_health, player.max_health)

	_on_score_changed(GameState.score)
	_on_high_score_changed(GameState.high_score)
	_on_killstreak_changed(GameState.killstreak)
	_on_level_changed(GameState.current_level)


func _on_player_health_changed(current_health: int, max_health: int) -> void:
	print("HUD HEALTH:", current_health, "/", max_health)

	if health_bar == null:
		push_warning("HUD: HealthBar not found.")
		return

	var old_value: float = health_bar.value

	health_bar.min_value = 0
	health_bar.max_value = max_health
	health_bar.value = current_health

	if current_health < old_value:
		_flash_health_bar_red()

	if current_health > 0 and current_health <= low_health_threshold:
		_is_low_health = true
	else:
		_is_low_health = false
	health_bar.modulate = _health_bar_normal_modulate


func _on_score_changed(new_score: int) -> void:
	if score_label == null:
		return

	score_label.text = "SCORE: " + str(new_score)


func _on_high_score_changed(new_high_score: int) -> void:
	if high_score_label == null:
		return

	high_score_label.text = "HIGH: " + str(new_high_score)


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
func _flash_health_bar_red() -> void:
	if health_bar == null:
		return

	var tween: Tween = create_tween()
	health_bar.modulate = Color.RED
	tween.tween_property(health_bar, "modulate", _health_bar_normal_modulate, 0.18)


func _update_low_health_pulse(delta: float) -> void:
	if health_bar == null:
		return

	if not _is_low_health:
		return

	var pulse: float = (sin(Time.get_ticks_msec() * 0.001 * low_health_pulse_speed) + 1.0) * 0.5
	var alpha: float = lerp(low_health_min_alpha, 1.0, pulse)

	var c: Color = Color.RED
	c.a = alpha
	health_bar.modulate = c
func _update_player_connection() -> void:
	if player != null:
		if is_instance_valid(player):
			return

	player = get_tree().get_first_node_in_group("player")
	_is_player_connected = false

	if player == null:
		return

	if player.has_signal("health_changed"):
		if not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)

		_is_player_connected = true

		if "current_health" in player:
			if "max_health" in player:
				_on_player_health_changed(player.current_health, player.max_health)
