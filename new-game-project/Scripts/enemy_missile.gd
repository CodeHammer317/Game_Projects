# File: scripts/EnemyMissile.gd
extends Area2D

@export var speed: float = 360.0
@export var turn_rate_deg: float = 45.0
@export var damage: int = 1
@export var lifetime: float = 1.0

var target: Node2D
var _velocity: Vector2 = Vector2.ZERO
var _time_left: float = 0.0


func _ready() -> void:
	_time_left = lifetime
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func launch(initial_dir: Vector2, target_node: Node2D) -> void:
	if initial_dir == Vector2.ZERO:
		initial_dir = Vector2.RIGHT

	_velocity = initial_dir.normalized() * speed
	target = target_node


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()
		return

	# Homing
	if target != null and is_instance_valid(target):
		var desired_dir = (target.global_position - global_position).normalized()
		var current_dir = _velocity.normalized()

		var max_turn = deg_to_rad(turn_rate_deg) * delta
		var angle_diff = current_dir.angle_to(desired_dir)
		angle_diff = clamp(angle_diff, -max_turn, max_turn)

		var new_dir = current_dir.rotated(angle_diff)
		_velocity = new_dir * speed

	# Rotate visually
	rotation = _velocity.angle()

	# Move
	global_position += _velocity * delta


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if "take_damage" in body:
			body.call("take_damage", damage)
		queue_free()
		return

	if body is StaticBody2D or body is TileMap:
		queue_free()
