extends Area2D
class_name Checkpoint

@export var target_group: StringName = &"player"
@export var respawn_manager_path: NodePath
@export var spawn_point_path: NodePath
@export var activate_once: bool = false

var _is_active: bool = false

@onready var spawn_point: Node2D = get_node_or_null(spawn_point_path) as Node2D
@onready var respawn_manager: RespawnManager = get_node_or_null(respawn_manager_path) as RespawnManager


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if activate_once and _is_active:
		return

	if not body.is_in_group(target_group):
		return

	var manager := _get_respawn_manager()
	if manager == null:
		if body.has_method("set_fallback_respawn_position"):
			var target := spawn_point if spawn_point != null else self
			body.set_fallback_respawn_position(target.global_position)
			_is_active = true
			return

		push_warning("Checkpoint: no RespawnManager or compatible player fallback found.")
		return

	var target := spawn_point if spawn_point != null else self
	manager.set_checkpoint(target)
	_is_active = true


func _get_respawn_manager() -> RespawnManager:
	if respawn_manager != null and is_instance_valid(respawn_manager):
		return respawn_manager

	return get_tree().get_first_node_in_group("respawn_manager") as RespawnManager
