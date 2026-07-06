extends Node
class_name RespawnManager

signal checkpoint_changed(position: Vector2)

@export var player_path: NodePath
@export var default_spawn_path: NodePath
@export var fade_rect_path: NodePath
@export var respawn_delay: float = 0.25
@export var fade_duration: float = 0.18
@export var bind_spawned_players: bool = true

var player: Player = null
var current_spawn_position: Vector2 = Vector2.ZERO
var _is_respawning: bool = false

@onready var default_spawn: Node2D = get_node_or_null(default_spawn_path) as Node2D
@onready var fade_rect: ColorRect = get_node_or_null(fade_rect_path) as ColorRect


func _ready() -> void:
	add_to_group("respawn_manager")
	_initialize_spawn_position()
	_bind_configured_player()

	if bind_spawned_players:
		var tree := get_tree()
		if not tree.node_added.is_connected(_on_node_added):
			tree.node_added.connect(_on_node_added)
		call_deferred("_bind_first_player")


func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null and tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)

	_disconnect_player()


func set_checkpoint(checkpoint: Node2D) -> void:
	if checkpoint == null:
		return

	set_checkpoint_position(checkpoint.global_position)


func set_checkpoint_position(spawn_position: Vector2) -> void:
	current_spawn_position = spawn_position
	checkpoint_changed.emit(current_spawn_position)


func respawn_player(target_player: Player = null) -> void:
	var respawn_target := target_player if target_player != null else player
	if respawn_target == null or not is_instance_valid(respawn_target):
		return

	if _is_respawning:
		return

	_run_respawn(respawn_target)


func _initialize_spawn_position() -> void:
	if default_spawn != null:
		current_spawn_position = default_spawn.global_position


func _bind_configured_player() -> void:
	if player_path.is_empty():
		return

	var configured_player := get_node_or_null(player_path) as Player
	if configured_player != null:
		set_player(configured_player)


func _bind_first_player() -> void:
	if player != null:
		return

	var grouped_player := get_tree().get_first_node_in_group("player") as Player
	if grouped_player != null:
		set_player(grouped_player)


func set_player(new_player: Player) -> void:
	if player == new_player:
		return

	_disconnect_player()
	player = new_player

	if player == null:
		return

	player.auto_respawn_on_death = false

	if not player.respawn_ready.is_connected(_on_player_respawn_ready):
		player.respawn_ready.connect(_on_player_respawn_ready)

	if default_spawn == null and current_spawn_position == Vector2.ZERO:
		current_spawn_position = player.global_position


func _disconnect_player() -> void:
	if is_instance_valid(player):
		if player.respawn_ready.is_connected(_on_player_respawn_ready):
			player.respawn_ready.disconnect(_on_player_respawn_ready)

	player = null


func _on_node_added(node: Node) -> void:
	if player != null:
		return

	if node is Player:
		_bind_player_when_ready(node as Player)


func _bind_player_when_ready(new_player: Player) -> void:
	if not new_player.is_node_ready():
		await new_player.ready

	if player == null and is_inside_tree() and is_instance_valid(new_player):
		set_player(new_player)


func _on_player_respawn_ready(dead_player: Player) -> void:
	respawn_player(dead_player)


func _run_respawn(respawn_target: Player) -> void:
	_is_respawning = true

	respawn_target.set_control_locked(true)

	if respawn_delay > 0.0:
		await get_tree().create_timer(respawn_delay).timeout

	await _fade_out()

	if is_instance_valid(respawn_target):
		respawn_target.respawn_at(current_spawn_position)

	await _fade_in()

	_is_respawning = false


func _fade_out() -> void:
	if fade_rect == null:
		return

	fade_rect.visible = true
	fade_rect.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, fade_duration)
	await tween.finished


func _fade_in() -> void:
	if fade_rect == null:
		return

	fade_rect.visible = true
	fade_rect.modulate.a = 1.0

	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, fade_duration)
	await tween.finished

	fade_rect.visible = false
