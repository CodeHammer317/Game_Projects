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




'''extends Area2D

@export var speed: float = 220.0
@export var acceleration: float = 180.0
@export var max_speed: float = 420.0
@export var damage: int = 1
@export var knockback: float = 120.0
@export var lifetime: float = 5.0

@export var homing_enabled: bool = false
@export var turn_rate_deg: float = 180.0

# Collide against World (layer 1)
@export var world_collision_mask: int = 1

@export var explosion_scene: PackedScene

var velocity: Vector2 = Vector2.ZERO
var target: Node2D = null
var _space_state

func _ready() -> void:
	_space_state = get_world_2d().direct_space_state
	var t: Timer = $LifeTimer
	t.wait_time = lifetime
	t.one_shot = true
	t.start()

func launch(direction: Vector2) -> void:
	var dir: Vector2 = direction
	if dir.length() == 0.0:
		dir = Vector2.RIGHT
	dir = dir.normalized()
	velocity = dir * speed
	rotation = dir.angle()

func set_target(node: Node2D) -> void:
	target = node

func _physics_process(delta: float) -> void:
	# Optional homing
	if homing_enabled == true and target != null and is_instance_valid(target):
		var to_target: Vector2 = target.global_position - global_position
		if to_target.length() > 0.01:
			var desired: float = to_target.angle()
			var current: float = rotation
			var max_step: float = deg_to_rad(turn_rate_deg) * delta
			var diff: float = wrapf(desired - current, -PI, PI)
			if diff > max_step:
				diff = max_step
			if diff < -max_step:
				diff = -max_step
			rotation = current + diff

	# Accelerate and clamp
	var cur: float = velocity.length()
	cur = cur + acceleration * delta
	if cur > max_speed:
		cur = max_speed

	var dir_vec: Vector2 = Vector2.RIGHT.rotated(rotation)
	velocity = dir_vec * cur

	# Raycast vs World to avoid tunneling
	var from: Vector2 = global_position
	var to: Vector2 = from + velocity * delta

	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collide_with_areas = false
	query.collision_mask = world_collision_mask
	var hit: Dictionary = _space_state.intersect_ray(query)

	if hit.size() > 0:
		_explode(hit.position)
		return

	global_position = to

func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if body.has_method("apply_damage"):
		body.call("apply_damage", damage, global_position, knockback)
	_explode(global_position)

func _on_area_entered(area: Area2D) -> void:
	_explode(global_position)

func _on_LifeTimer_timeout() -> void:
	_explode(global_position)

func _explode(at: Vector2) -> void:
	if explosion_scene != null:
		var e: Node2D = explosion_scene.instantiate()
		e.global_position = at
		get_tree().current_scene.add_child(e)
	queue_free()'''
