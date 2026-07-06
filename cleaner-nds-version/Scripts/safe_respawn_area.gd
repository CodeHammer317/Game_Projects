extends Area2D
class_name SafeRespawnArea

@export var target_group: StringName = &"player"
@export var respawn_manager_path: NodePath

@onready var respawn_manager: RespawnManager = get_node_or_null(respawn_manager_path) as RespawnManager

var _is_triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _is_triggered:
		return

	if not body.is_in_group(target_group):
		return

	var player := body as Player
	if player == null:
		return

	var manager := _get_respawn_manager()
	if manager == null:
		push_warning("SafeRespawnArea: no RespawnManager found.")
		return

	_is_triggered = true
	manager.respawn_player(player)
	await get_tree().process_frame
	_is_triggered = false


func _get_respawn_manager() -> RespawnManager:
	if respawn_manager != null and is_instance_valid(respawn_manager):
		return respawn_manager

	return get_tree().get_first_node_in_group("respawn_manager") as RespawnManager
