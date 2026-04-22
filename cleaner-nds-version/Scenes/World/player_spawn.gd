extends Node2D
class_name PlayerSpawn

@export var player_scene: PackedScene
@export var spawn_marker_path: NodePath
@export var respawn_delay: float = 1.0
@export var auto_spawn_on_ready: bool = true

@export var camera_path: NodePath
@export var fade_rect_path: NodePath

@onready var default_spawn_marker: Marker2D = get_node_or_null(spawn_marker_path) as Marker2D
@onready var camera: SimpleCamera = get_node_or_null(camera_path) as SimpleCamera
@onready var fade_rect: ColorRect = get_node_or_null(fade_rect_path) as ColorRect

var current_spawn_marker: Marker2D = null
var player_instance: Node2D = null
var _is_respawning: bool = false


func _ready() -> void:
	current_spawn_marker = default_spawn_marker

	if auto_spawn_on_ready:
		spawn_player()


func spawn_player() -> void:
	if player_scene == null:
		push_warning("PlayerSpawn: player_scene is not assigned.")
		return

	if current_spawn_marker == null:
		push_warning("PlayerSpawn: current_spawn_marker is null.")
		return

	var new_player := player_scene.instantiate() as Node2D
	if new_player == null:
		push_warning("PlayerSpawn: failed to instantiate player_scene as Node2D.")
		return

	var parent_node: Node = get_tree().current_scene
	if parent_node == null:
		parent_node = self

	parent_node.add_child(new_player)
	new_player.global_position = current_spawn_marker.global_position

	player_instance = new_player
	print("SPAWNED PLAYER AT: ", new_player.global_position)
	_connect_player_signals()
	_attach_camera_to_player()


func respawn_player() -> void:
	if _is_respawning:
		return

	_is_respawning = true

	await _play_fade_out()

	if camera != null:
		camera.clear_target()

	if is_instance_valid(player_instance):
		player_instance.queue_free()
		player_instance = null
		await get_tree().process_frame

	if respawn_delay > 0.0:
		await get_tree().create_timer(respawn_delay).timeout

	spawn_player()

	await _play_fade_in()

	_is_respawning = false


func set_checkpoint(marker: Marker2D) -> void:
	if marker == null:
		push_warning("PlayerSpawn: tried to set a null checkpoint marker.")
		return

	current_spawn_marker = marker


func reset_to_default_checkpoint() -> void:
	current_spawn_marker = default_spawn_marker


func get_player() -> Node2D:
	return player_instance


func _connect_player_signals() -> void:
	if player_instance == null:
		return

	if player_instance.has_signal("died"):
		if not player_instance.died.is_connected(_on_player_died):
			player_instance.died.connect(_on_player_died)


func _on_player_died() -> void:
	respawn_player()


func _attach_camera_to_player() -> void:
	if camera == null:
		return

	if player_instance == null:
		return

	camera.set_target(player_instance)


func _play_fade_out() -> void:
	if fade_rect == null:
		return

	fade_rect.visible = true
	fade_rect.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.2)
	await tween.finished


func _play_fade_in() -> void:
	if fade_rect == null:
		return

	fade_rect.visible = true
	fade_rect.modulate.a = 1.0

	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.2)
	await tween.finished

	fade_rect.visible = false
