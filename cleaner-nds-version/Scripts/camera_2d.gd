extends Camera2D
class_name SimpleCamera

@export var target_path: NodePath
@export var look_ahead_distance: float = 24.0
@export var look_ahead_lerp_speed: float = 8.0
@export var vertical_offset: float = -8.0
@export var use_position_smoothing: bool = true
@export var smoothing_speed: float = 7.0

var _target: Node2D = null
var _look_offset_x: float = 0.0


func _ready() -> void:
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node2D

	position_smoothing_enabled = use_position_smoothing
	position_smoothing_speed = smoothing_speed
	enabled = true

	CombatFX.register_camera(self)


func _physics_process(delta: float) -> void:
	if _target == null:
		return

	var desired_look: float = 0.0

	if _target.has_method("is_facing_left") and _target.is_facing_left():
		desired_look = -look_ahead_distance
	elif _target.has_method("is_facing_left"):
		desired_look = look_ahead_distance
	else:
		if _target is CharacterBody2D:
			var body := _target as CharacterBody2D
			if body.velocity.x < -1.0:
				desired_look = -look_ahead_distance
			elif body.velocity.x > 1.0:
				desired_look = look_ahead_distance

	_look_offset_x = move_toward(_look_offset_x, desired_look, look_ahead_lerp_speed * 60.0 * delta)

	global_position = Vector2(
		_target.global_position.x + _look_offset_x,
		_target.global_position.y + vertical_offset
	)
	
