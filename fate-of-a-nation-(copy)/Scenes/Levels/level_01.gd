extends Node2D
class_name Level01

@export var player_scene: PackedScene
@export var enemy_basic_scene: PackedScene
@export var powerup_scene: PackedScene

@export var starting_lane_left: float = 175.0
@export var starting_lane_right: float = 440.0
@export var max_lane_left: float = 160.0
@export var max_lane_right: float = 480.0
@export var lane_widen_amount: float = 0.0

@export var spawn_interval: float = 1.1
@export var min_spawn_interval: float = 0.35
@export var spawn_interval_drop: float = 0.05

var player: Player = null
var current_lane_left: float = 0.0
var current_lane_right: float = 0.0
var enemies_spawned: int = 0

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var enemy_spawn_area: Node2D = $EnemySpawnArea
@onready var enemy_container: Node2D = $EnemyContainer
@onready var powerup_container: Node2D = $PowerupContainer
@onready var lose_line: Area2D = $LoseLine
@onready var enemy_spawn_timer: Timer = $EnemySpawnTimer
@onready var camera_shake: CameraShake = $Camera2D


func _ready() -> void:
	current_lane_left = starting_lane_left
	current_lane_right = starting_lane_right
	await get_tree().create_timer(1.0).timeout

	var camera: CameraShake = get_tree().get_first_node_in_group("camera_shake") as CameraShake

	

	GameState.start_level(1)

	_spawn_player()
	_setup_enemy_timer()
	_connect_signals()


func _spawn_player() -> void:
	if player_scene == null:
		push_warning("Level_01: player_scene is not assigned.")
		return

	var new_player: Node = player_scene.instantiate()
	add_child(new_player)

	player = new_player as Player

	if player == null:
		push_warning("Level_01: spawned player is not a Player.")
		return

	player.global_position = player_spawn.global_position
	player.lane_left_limit = current_lane_left
	player.lane_right_limit = current_lane_right


func _setup_enemy_timer() -> void:
	if enemy_spawn_timer == null:
		return

	enemy_spawn_timer.wait_time = spawn_interval
	enemy_spawn_timer.one_shot = false

	if not enemy_spawn_timer.timeout.is_connected(_on_enemy_spawn_timer_timeout):
		enemy_spawn_timer.timeout.connect(_on_enemy_spawn_timer_timeout)

	enemy_spawn_timer.start()


func _connect_signals() -> void:
	if lose_line != null:
		if not lose_line.body_entered.is_connected(_on_lose_line_body_entered):
			lose_line.body_entered.connect(_on_lose_line_body_entered)

		if not lose_line.area_entered.is_connected(_on_lose_line_area_entered):
			lose_line.area_entered.connect(_on_lose_line_area_entered)

	if not GameState.powerup_earned.is_connected(_on_powerup_earned):
		GameState.powerup_earned.connect(_on_powerup_earned)

	if not GameState.killstreak_changed.is_connected(_on_killstreak_changed):
		GameState.killstreak_changed.connect(_on_killstreak_changed)


func _on_enemy_spawn_timer_timeout() -> void:
	spawn_enemy()


func spawn_enemy() -> void:
	if GameState.is_game_over:
		return

	if enemy_basic_scene == null:
		push_warning("Level_01: enemy_basic_scene is not assigned.")
		return

	var enemy: Node = enemy_basic_scene.instantiate()
	enemy_container.add_child(enemy)

	enemy.global_position = _get_random_spawn_position()

	enemies_spawned += 1
	_update_spawn_speed()


func _get_random_spawn_position() -> Vector2:
	var spawn_y: float = enemy_spawn_area.global_position.y
	var spawn_x: float = randf_range(current_lane_left, current_lane_right)

	return Vector2(spawn_x, spawn_y)


func _update_spawn_speed() -> void:
	if enemy_spawn_timer == null:
		return

	if enemies_spawned % 8 != 0:
		return

	var new_wait_time: float = enemy_spawn_timer.wait_time - spawn_interval_drop

	if new_wait_time < min_spawn_interval:
		new_wait_time = min_spawn_interval

	enemy_spawn_timer.wait_time = new_wait_time


func _on_killstreak_changed(new_killstreak: int) -> void:
	if new_killstreak <= 0:
		return

	if new_killstreak % 5 != 0:
		return

	_widen_lane()


func _widen_lane() -> void:
	current_lane_left -= lane_widen_amount
	current_lane_right += lane_widen_amount

	if current_lane_left < max_lane_left:
		current_lane_left = max_lane_left

	if current_lane_right > max_lane_right:
		current_lane_right = max_lane_right

	if player != null:
		player.lane_left_limit = current_lane_left
		player.lane_right_limit = current_lane_right


func _on_powerup_earned(killstreak: int) -> void:
	call_deferred("spawn_powerup")


func spawn_powerup() -> void:
	if powerup_scene == null:
		push_warning("Level_01: powerup_scene is not assigned.")
		return

	var powerup: Node = powerup_scene.instantiate()
	powerup_container.add_child(powerup)

	var powerup_x: float = randf_range(current_lane_left, current_lane_right)
	var powerup_y: float = player_spawn.global_position.y - 96.0

	powerup.global_position = Vector2(powerup_x, powerup_y)


func _on_lose_line_body_entered(body: Node) -> void:
	_check_enemy_breakthrough(body)


func _on_lose_line_area_entered(area: Area2D) -> void:
	_check_enemy_breakthrough(area)


func _check_enemy_breakthrough(node: Node) -> void:
	if GameState.is_game_over:
		return

	if node == null:
		return

	if node is EnemyBasic:
		GameState.trigger_game_over("The enemy broke through the final line.")
		return

	var parent: Node = node.get_parent()

	if parent is EnemyBasic:
		GameState.trigger_game_over("The enemy broke through the final line.")
		
		
func shake_camera(strength: float = 0.35) -> void:
	if camera_shake == null:
		camera_shake = get_tree().get_first_node_in_group("camera_shake") as CameraShake

	if camera_shake == null:
		print("Level_01: No CameraShake found.")
		return

	camera_shake.shake(strength)
