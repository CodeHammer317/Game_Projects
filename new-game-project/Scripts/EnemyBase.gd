extends CharacterBody2D
class_name EnemyBase

# -------------------------
# MOVEMENT
# -------------------------
@export var gravity: float = 900.0
@export var patrol_speed: float = 40.0
@export var patrol_distance: float = 80.0
@export var accel: float = 400.0

# -------------------------
# COMBAT
# -------------------------
@export var bullet_scene: PackedScene
@export var fire_range: float = 160.0
@export var fire_cooldown: float = 1.2
@export var use_line_of_sight: bool = false

# Optional: if your player group is actually "players", change this once here
@export var target_group: StringName = &"player"

# -------------------------
# STATE
# -------------------------
var _start_position: Vector2
var _patrol_direction: int = -1
var _fire_timer: float = 0.0
var _target: Node2D = null

# -------------------------
# NODES
# -------------------------
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var muzzle: Node2D = get_node_or_null("Muzzle")

# -------------------------
# LIFECYCLE
# -------------------------
func _ready() -> void:
	_start_position = global_position

	if hurtbox and not hurtbox.damaged.is_connected(_on_hurtbox_damaged):
		hurtbox.damaged.connect(_on_hurtbox_damaged)

	if health and not health.damaged.is_connected(_on_health_damaged):
		health.damaged.connect(_on_health_damaged)

	if health and not health.died.is_connected(_on_died):
		health.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	_fire_timer = maxf(_fire_timer - delta, 0.0)

	if not is_on_floor():
		velocity.y += gravity * delta

	_target = _get_best_target()

	_face_target()

	if _can_attack_target(_target):
		velocity.x = move_toward(velocity.x, 0.0, accel * delta)
		_try_fire_at_target()
	else:
		_process_patrol(delta)

	move_and_slide()

# -------------------------
# TARGETING
# -------------------------
func _get_best_target() -> Node2D:
	var candidates = get_tree().get_nodes_in_group(target_group)
	var best: Node2D = null
	var best_dist_sq := INF

	for node in candidates:
		if not is_instance_valid(node):
			continue
		if not (node is Node2D):
			continue

		var candidate = node as Node2D
		var dist_sq = global_position.distance_squared_to(candidate.global_position)

		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = candidate

	return best

func _can_attack_target(target: Node2D) -> bool:
	if target == null:
		return false
	if not is_instance_valid(target):
		return false

	var dist_sq := global_position.distance_squared_to(target.global_position)
	if dist_sq > fire_range * fire_range:
		return false

	if use_line_of_sight and not _has_line_of_sight(target):
		return false

	return true

func _has_line_of_sight(target: Node2D) -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	query.exclude = [self]
	var result := space_state.intersect_ray(query)

	if result.is_empty():
		return true

	var collider = result.get("collider")
	return collider == target

# -------------------------
# PATROL
# -------------------------
func _process_patrol(delta: float) -> void:
	var offset_x := global_position.x - _start_position.x

	if offset_x <= -patrol_distance:
		_patrol_direction = 1
	elif offset_x >= patrol_distance:
		_patrol_direction = -1

	var target_speed := float(_patrol_direction) * patrol_speed
	velocity.x = move_toward(velocity.x, target_speed, accel * delta)

	_face_patrol_direction()

func _face_patrol_direction() -> void:
	if sprite == null:
		return
	sprite.flip_h = _patrol_direction < 0

# -------------------------
# FACING
# -------------------------
func _face_target() -> void:
	if sprite == null:
		return
	if _target == null or not is_instance_valid(_target):
		return

	sprite.flip_h = _target.global_position.x < global_position.x

# -------------------------
# FIRING
# -------------------------
func _try_fire_at_target() -> void:
	if bullet_scene == null:
		return
	if _target == null or not is_instance_valid(_target):
		return
	if _fire_timer > 0.0:
		return

	var bullet = bullet_scene.instantiate()
	if bullet == null:
		return

	var spawn_position = global_position
	if muzzle:
		spawn_position = muzzle.global_position

	var direction = (_target.global_position - spawn_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.LEFT if sprite and sprite.flip_h else Vector2.RIGHT

	get_tree().current_scene.add_child(bullet)

	if bullet is Node2D:
		bullet.global_position = spawn_position

	if "instigator" in bullet:
		bullet.instigator = self

	if bullet.has_method("launch"):
		bullet.launch(direction)

	_fire_timer = fire_cooldown
	_on_fire()

func _on_fire() -> void:
	pass

# -------------------------
# DAMAGE FLOW
# -------------------------
func _on_hurtbox_damaged(info: DamageInfo) -> void:
	if health:
		health.apply_damage(info)

func _on_health_damaged(info: DamageInfo) -> void:
	velocity += info.knockback
	_on_hit_effects(info)

func _on_died() -> void:
	_on_death_effects()
	queue_free()

func _on_hit_effects(_info: DamageInfo) -> void:
	pass

func _on_death_effects() -> void:
	pass
