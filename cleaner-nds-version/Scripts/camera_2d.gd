extends Camera2D
class_name SimpleCamera

@export var target_path: NodePath
@export var vertical_offset: float = -8.0
@export var use_position_smoothing: bool = false
@export var snap_to_pixel: bool = true

var target: Node2D = null


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS

	_resolve_target()

	position_smoothing_enabled = use_position_smoothing
	drag_horizontal_enabled = false
	drag_vertical_enabled = false

	enabled = true
	make_current()
	CombatFx.register_camera(self)


func _physics_process(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_resolve_target()

	if target == null:
		return

	var target_position := Vector2(
		target.global_position.x,
		target.global_position.y + vertical_offset
	)

	if snap_to_pixel:
		target_position = target_position.round()

	global_position = target_position


func _resolve_target() -> void:
	if target_path != NodePath():
		target = get_node_or_null(target_path) as Node2D

	if target != null:
		return

	var players := get_tree().get_nodes_in_group(&"player")
	if players.is_empty():
		return

	target = players[0] as Node2D
