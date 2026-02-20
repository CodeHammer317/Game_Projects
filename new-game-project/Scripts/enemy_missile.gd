# File: scripts/EnemyMissile.gd
extends Area2D

@export var speed: float = 360.0
@export var turn_rate_deg: float = 45.0   # max degrees per second this missile can turn
@export var damage: int = 12
@export var lifetime: float = 2.0

var target: Node2D
var _velocity: Vector2 = Vector2.ZERO
var _time_left: float = 0.0

func _ready() -> void:
	_time_left = lifetime
	if not self.body_entered.is_connected(_on_body_entered):
		self.body_entered.connect(_on_body_entered)

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

	# Homing: rotate _velocity toward (target - position) with a clamped turn rate
	var have_target := target != null
	if have_target:
		if not is_instance_valid(target):
			target = null
		else:
			# Desired direction
			var desired := (target.global_position - global_position)
			if desired != Vector2.ZERO:
				desired = desired.normalized()
				var current_angle := _velocity.angle()
				var desired_angle := desired.angle()
				var max_step := deg_to_rad(turn_rate_deg) * delta

				var new_angle := _rotate_toward(current_angle, desired_angle, max_step)
				var speed_mag := _velocity.length()
				_velocity = Vector2.RIGHT.rotated(new_angle) * speed_mag

	# Move
	position += _velocity * delta

func _rotate_toward(current_angle: float, target_angle: float, max_step: float) -> float:
	var diff := wrapf(target_angle - current_angle, -PI, PI)
	if diff > max_step:
		diff = max_step
	else:
		if diff < -max_step:
			diff = -max_step
	return current_angle + diff

func _on_body_entered(body: Node) -> void:
	# Collide with world or players
	var is_player := false
	if body.is_in_group("player"):
		is_player = true

	if is_player:
		# Deliver damage if the player supports it
		if "take_damage" in body:
			body.call("take_damage", damage)
		queue_free()
		return

	# If it's world (StaticBody2D/TileMap colliders), explode and free
	if body is StaticBody2D or body is TileMap:
		queue_free()
